extends SceneTree
## Headless audit for stale decorations: foliage whose host tile was replaced
## (e.g. a cliff grew over the ground tile a tree stood on) or removed.
## Reports, for every displaceable decoration piece:
##   BURIED  — a cliff tile covers the deco's footprint and its plateau top is
##             above the deco origin (the tree pokes out of the plateau).
##   ORPHAN  — no walkable tile directly under the deco origin.
##
## Run with: godot --headless --path . -s res://tests/harness/debug_deco_scan.gd

const SEEDS: Array[int] = [11, 22, 33, 44, 55, 66, 77, 88]
const DECO_TAGS: Array[String] = ["tree", "bush", "grass", "rock"]


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
	gen._ready()

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
	var deco_total: int = 0
	var buried: int = 0
	var orphans: int = 0
	for module in gen.terrain_index.all_modules.keys():
		if not (module is TerrainModuleInstance):
			continue
		var piece: TerrainModuleInstance = module
		var deco_tag: String = ""
		for tag in DECO_TAGS:
			if piece.def.tags.has(tag):
				deco_tag = tag
				break
		if deco_tag == "":
			continue
		deco_total += 1
		var o: Vector3 = piece.transform.origin

		# Any cliff tile whose 24x24 footprint covers this deco and whose
		# walkable top sits above the deco origin?
		var column: AABB = AABB(o + Vector3(-0.1, -1.0, -0.1), Vector3(0.2, 30.0, 0.2))
		var covering_cliff: TerrainModuleInstance = null
		var support_found: bool = false
		for hit in gen.terrain_index.query_box(column):
			if not (hit is TerrainModuleInstance) or hit == piece:
				continue
			var other: TerrainModuleInstance = hit
			var delta: Vector3 = o - other.transform.origin
			if absf(delta.x) > 12.0 or absf(delta.z) > 12.0:
				continue
			if other.def.tags.has("cliff") and other.transform.origin.y > o.y + 0.2:
				covering_cliff = other
			# Walkable support directly below (ground/level/cliff top near deco base).
			if other.transform.origin.y <= o.y + 0.2 and (
				other.def.tags.has("ground") or other.def.tags.has("level")
				or other.def.tags.has("cliff") or other.def.tags.has("hill")
			):
				support_found = true
		if covering_cliff != null:
			buried += 1
			print("[seed %d] BURIED %s at %s under cliff %s at %s" % [
				seed_value, deco_tag, str(o),
				str(covering_cliff.def.tags.tags), str(covering_cliff.transform.origin)
			])
		elif not support_found:
			orphans += 1
			print("[seed %d] ORPHAN %s at %s (no tile below)" % [seed_value, deco_tag, str(o)])
	print("[seed %d] deco_total=%d buried=%d orphans=%d" % [seed_value, deco_total, buried, orphans])
