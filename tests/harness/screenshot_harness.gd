extends Node3D
## Screenshot harness for terrain iteration (not a GUT test).
## Boots the real world scene, walks the character in a slow spiral so terrain
## streams in, and saves periodic screenshots (gameplay + overhead) plus
## terrain statistics to /tmp/terrain_shots.
##
## Run with: godot --path . res://tests/harness/screenshot_harness.tscn

const SHOT_DIR: String = "/tmp/terrain_shots"
const SHOT_INTERVAL: float = 8.0
const NUM_SHOTS: int = 10

class WalkController:
	extends CharacterController
	var dir: Vector2 = Vector2.RIGHT

	func get_move_vector(_character: CharacterBody3D, delta: float) -> Vector2:
		dir = dir.rotated(delta * 0.12)
		return dir

	func wants_jump(_character: CharacterBody3D, _delta: float) -> bool:
		return randf() < 0.005

var world: Node3D
var character: CharacterBody3D
var terrain: Node3D
var main_cam: Camera3D
var overhead_cam: Camera3D


func _ready() -> void:
	# Keep the window unoccluded: macOS suspends fully-covered windows
	# (App Nap), which freezes the main loop and hangs the await chain.
	get_window().always_on_top = true
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	world = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	character = world.get_node("Characters/Character")
	terrain = world.get_node("Terrain")
	main_cam = world.get_node("Camera3D")
	overhead_cam = Camera3D.new()
	overhead_cam.far = 600.0
	add_child(overhead_cam)
	character.controller = WalkController.new()
	_run()


func _run() -> void:
	await get_tree().process_frame
	for i in range(NUM_SHOTS):
		await get_tree().create_timer(SHOT_INTERVAL).timeout
		_print_stats(i)
		_scan_invariants(str(i))
		await _capture_from("shot_%02d_gameplay" % i, Vector3.ZERO, Vector3.ZERO, true)
		var center: Vector3 = character.global_position
		await _capture_from("shot_%02d_overhead" % i, center + Vector3(60, 150, 60), center, false)
		await _capture_from("shot_%02d_wide" % i, center + Vector3(0.5, 320, 0.5), center, false)
		var peak: Vector3 = _highest_piece_position()
		if peak != Vector3.INF:
			# Low oblique angle: a terraced mountain reads flat from high above.
			await _capture_from(
				"shot_%02d_mountain" % i, peak + Vector3(55, 14, 55), peak + Vector3(0, 4, 0), false
			)
		var water: Vector3 = _tagged_piece_position("water")
		if water != Vector3.INF:
			await _capture_from("shot_%02d_water" % i, water + Vector3(45, 35, 45), water, false)
			# From low over the water looking back at the land: shows the bank walls.
			var land: Vector3 = _tagged_piece_position("bank")
			if land != Vector3.INF:
				var from_water: Vector3 = water + (water - land).normalized() * 30.0 + Vector3(0, 7, 0)
				await _capture_from("shot_%02d_shore" % i, from_water, land + Vector3(0, -1, 0), false)
	get_tree().quit()


func _capture_from(shot_name: String, cam_pos: Vector3, target: Vector3, use_main: bool) -> void:
	if use_main:
		main_cam.make_current()
	else:
		overhead_cam.global_position = cam_pos
		overhead_cam.look_at(target)
		overhead_cam.make_current()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [SHOT_DIR, shot_name])


func _tagged_piece_position(tag: String) -> Vector3:
	for module in terrain.terrain_index.all_modules.keys():
		if module is TerrainModuleInstance and module.def.tags.has(tag):
			return module.transform.origin
	return Vector3.INF


func _highest_piece_position() -> Vector3:
	var best: Vector3 = Vector3.INF
	var best_y: float = 1.0  # only report genuinely elevated terrain
	for module in terrain.terrain_index.all_modules.keys():
		if not (module is TerrainModuleInstance):
			continue
		var o: Vector3 = module.transform.origin
		if o.y > best_y:
			best_y = o.y
			best = o
	return best


func _print_stats(i: int) -> void:
	var counts: Dictionary = {}
	var total: int = 0
	for module in terrain.terrain_index.all_modules.keys():
		if not (module is TerrainModuleInstance):
			continue
		total += 1
		for family in ["ground", "level", "cliff", "hill", "water", "bank"]:
			if module.def.tags.has(family):
				counts[family] = counts.get(family, 0) + 1
	print("[harness %d] fps=%d pieces=%d queue=%d counts=%s player=%s" % [
		i,
		Engine.get_frames_per_second(),
		total,
		terrain.queue.heap.size(),
		str(counts),
		str(character.global_position),
	])


## Invariant scan: report structural violations that should never persist.
## - a level/cliff tile stacked on a non-center/non-interior support
## - a level-ground tile elevated above ground level (wrong tier)
## - an edge-variant tile whose variant disagrees with its actual neighbours
func _scan_invariants(tag: String) -> void:
	var level_rule: LevelEdgeRule = LevelEdgeRule.new()
	var cliff_rule: CliffEdgeRule = CliffEdgeRule.new()
	var water_rule: WaterRule = WaterRule.new()
	var violations: int = 0
	for module in terrain.terrain_index.all_modules.keys():
		if not (module is TerrainModuleInstance):
			continue
		var piece: TerrainModuleInstance = module
		var o: Vector3 = piece.transform.origin
		if piece.def.tags.has("level-ground") and o.y > 0.6:
			print("[scan %s] WRONG-TIER level-ground %s at %s" % [tag, str(piece.def.tags.tags), str(o)])
			violations += 1
		if piece.def.tags.has("level-stack"):
			var support: TerrainModuleInstance = level_rule._get_support_piece_below(piece, terrain.terrain_index)
			if support == null:
				print("[scan %s] STACK-NO-SUPPORT %s at %s" % [tag, str(piece.def.tags.tags), str(o)])
				violations += 1
			elif not support.def.tags.has("level-center"):
				print("[scan %s] STACK-ON-EDGE %s at %s support=%s" % [tag, str(piece.def.tags.tags), str(o), str(support.def.tags.tags)])
				violations += 1
		if piece.def.tags.has("level"):
			var missing: Array[String] = level_rule._missing_sockets_for_piece(piece, terrain.socket_index, terrain.terrain_index)
			var expected: String = level_rule._tag_for_missing_sockets(missing)
			var actual: String = level_rule._current_level_tag(piece.def)
			if expected != actual:
				print("[scan %s] STALE-LEVEL-VARIANT %s at %s expected=%s missing=%s" % [tag, actual, str(o), expected, str(missing)])
				violations += 1
		if piece.def.tags.has("bank"):
			for above in terrain.terrain_index.query_box(AABB(o + Vector3(-0.5, 0.2, -0.5), Vector3(1, 1, 1))):
				if above is TerrainModuleInstance and above != piece and above.def.tags.has("level"):
					print("[scan %s] LEVEL-ON-BANK at %s" % [tag, str(o)])
					violations += 1
		if piece.def.tags.has("ground") and not piece.def.tags.has("water"):
			# Base tiles must carry the bank variant matching their actual
			# water-facing sides, counted from PLACED water pieces only (field
			# positions not yet generated retile on arrival — not a violation).
			var placed_sides: Array[String] = []
			for socket_name in water_rule.CARDINAL_SOCKETS:
				if water_rule._water_at_cardinal(piece, socket_name, terrain.socket_index, terrain.world_seed):
					placed_sides.append(socket_name)
			if not placed_sides.is_empty():
				var wmissing: Array[String] = water_rule._water_sides_for_piece(
					piece, terrain.socket_index, terrain.terrain_index, terrain.world_seed
				)
				var wexpected: String = water_rule._tag_for_missing_sockets(wmissing)
				var wactual: String = water_rule._current_bank_tag(piece.def)
				if wexpected != wactual:
					print("[scan %s] BANK-WALL-MISMATCH at %s actual=%s expected=%s water_sides=%s" % [
						tag, str(o), wactual, wexpected, str(wmissing)
					])
					violations += 1
		if piece.def.tags.has("cliff"):
			var cmissing: Array[String] = cliff_rule._missing_sockets_for_piece(piece, terrain.socket_index, terrain.terrain_index)
			var cexpected: String = cliff_rule._tag_for_missing_sockets(cmissing)
			var cactual: String = cliff_rule._current_cliff_tag(piece.def)
			if cexpected != cactual:
				print("[scan %s] STALE-CLIFF-VARIANT %s at %s expected=%s" % [tag, cactual, str(o), cexpected])
				violations += 1
	print("[scan %s] violations=%d" % [tag, violations])
