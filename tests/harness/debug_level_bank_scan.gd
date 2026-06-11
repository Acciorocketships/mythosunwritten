extends SceneTree
## Headless reproduction scan for the level/hill-at-water-edge missing-wall bug.
## Generates terrain along a spiral through the water belt (>220u from origin),
## then audits every base tile near water:
##   - WALL-MISMATCH: a land tile's bank variant disagrees with its actual
##     water-facing sides (e.g. plain ground directly beside water = no wall).
##   - OVER-BANK: any level or hill piece overlapping a bank tile's column.
##
## Run with: godot --headless --path . -s res://tests/harness/debug_level_bank_scan.gd

const SEEDS: Array[int] = [11, 22, 33, 44, 55, 66, 77, 88]


func _init() -> void:
	for s in SEEDS:
		_run_seed(s)
	quit()


func _run_seed(seed_value: int) -> void:
	seed(seed_value)
	var Generator: Script = load("res://scripts/terrain/TerrainGenerator.gd")
	var gen: Variant = Generator.new()
	gen.player = Node3D.new()
	gen.terrain_parent = Node3D.new()
	root.add_child(gen.player)
	root.add_child(gen.terrain_parent)
	gen._ready()  # library init + start tile (gen itself stays out of tree)

	# Spiral outward through the water belt so banks form at many angles and
	# the frontier gets revisited from different directions.
	var angle: float = 0.0
	var radius: float = 0.0
	while radius < 420.0:
		angle += 0.05
		radius += 0.55
		gen.player.global_position = Vector3(cos(angle), 0.0, sin(angle)) * radius
		for i in range(4):
			gen.load_terrain()

	_scan(gen, seed_value)

	root.remove_child(gen.player)
	root.remove_child(gen.terrain_parent)
	gen.player.free()
	gen.terrain_parent.free()
	gen.free()


func _scan(gen: Variant, seed_value: int) -> void:
	var rule: WaterRule = WaterRule.new()
	var counts: Dictionary = {}
	var violations: int = 0
	var water_adjacent_tops: Dictionary = {}
	for module in gen.terrain_index.all_modules.keys():
		if not (module is TerrainModuleInstance):
			continue
		var piece: TerrainModuleInstance = module
		for family in ["ground-plain", "bank", "water", "level", "hill"]:
			if piece.def.tags.has(family):
				counts[family] = counts.get(family, 0) + 1

		# Base tiles near water must carry the bank variant matching their
		# actual water-facing sides. A mismatch means a missing/misplaced wall.
		if piece.def.tags.has("ground") and not piece.def.tags.has("water"):
			var missing: Array[String] = rule._water_sides_for_piece(
				piece, gen.socket_index, gen.terrain_index, gen.world_seed
			)
			var expected: String = rule._tag_for_missing_sockets(missing)
			var actual: String = rule._current_bank_tag(piece.def)
			if actual == "":
				actual = "(untagged:%s)" % str(piece.def.tags.tags)
			if expected != actual:
				violations += 1
				# Distinguish persistent violations (every water side is an
				# actually-generated water piece — the rule should have fixed
				# this) from frontier-pending ones (field positions whose water
				# tile has not been generated yet).
				var placed_sides: Array[String] = []
				for socket_name in rule.CARDINAL_SOCKETS:
					if rule._water_at_cardinal(piece, socket_name, gen.socket_index, gen.world_seed):
						placed_sides.append(socket_name)
				for socket_name in rule.DIAGONAL_SOCKETS:
					if rule._get_diagonal_water_piece(piece, socket_name, gen.terrain_index, gen.world_seed) != null:
						placed_sides.append(socket_name)
				var kind: String = "PENDING"
				if not placed_sides.is_empty():
					kind = "PERSISTENT"
				print("[seed %d] WALL-MISMATCH-%s at %s actual=%s expected=%s water_sides=%s placed_water_sides=%s" % [
					seed_value, kind, str(piece.transform.origin), actual, expected,
					str(missing), str(placed_sides)
				])
			# Track what stands on tiles that touch water (for the report below).
			if not missing.is_empty():
				var o: Vector3 = piece.transform.origin
				var box: AABB = AABB(o + Vector3(-11.5, 0.05, -11.5), Vector3(23, 6, 23))
				for hit in gen.terrain_index.query_box(box):
					if not (hit is TerrainModuleInstance) or hit == piece:
						continue
					for fam in ["level", "hill"]:
						if hit.def.tags.has(fam):
							var key: String = fam + " on " + actual
							water_adjacent_tops[key] = water_adjacent_tops.get(key, 0) + 1

		# Nothing structural may overlap a bank tile's column.
		if piece.def.tags.has("bank"):
			var bo: Vector3 = piece.transform.origin
			var bank_box: AABB = AABB(bo + Vector3(-11.5, 0.05, -11.5), Vector3(23, 6, 23))
			for hit in gen.terrain_index.query_box(bank_box):
				if not (hit is TerrainModuleInstance) or hit == piece:
					continue
				if hit.def.tags.has("level") or hit.def.tags.has("hill"):
					violations += 1
					print("[seed %d] OVER-BANK bank at %s topper=%s at %s" % [
						seed_value, str(bo), str(hit.def.tags.tags), str(hit.transform.origin)
					])
	print("[seed %d] counts=%s toppers_at_water=%s violations=%d" % [
		seed_value, str(counts), str(water_adjacent_tops), violations
	])
