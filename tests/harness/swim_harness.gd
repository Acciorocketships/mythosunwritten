extends Node3D
## Swim-behavior harness (not a GUT test): finds water, drives the character
## in, and verifies sink / float-on-held-jump / leap-out phases by logging
## the character's height. Saves screenshots per phase to /tmp/terrain_shots.
##
## Run with: godot --path . res://tests/harness/swim_harness.tscn

const SHOT_DIR: String = "/tmp/terrain_shots"

class SwimController:
	extends CharacterController
	var move_dir: Vector2 = Vector2.ZERO
	var hold_jump: bool = false
	var press_jump: bool = false

	func get_move_vector(_c: CharacterBody3D, _dt: float) -> Vector2:
		return move_dir

	func wants_jump(_c: CharacterBody3D, _dt: float) -> bool:
		var fire: bool = press_jump
		press_jump = false
		return fire

	func jump_held(_c: CharacterBody3D, _dt: float) -> bool:
		return hold_jump

var world: Node3D
var character: CharacterBody3D
var terrain: Node3D
var cam: Camera3D
var ctrl: SwimController


func _ready() -> void:
	# Keep the window unoccluded: macOS suspends fully-covered windows
	# (App Nap), which freezes the main loop and hangs the await chain.
	get_window().always_on_top = true
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	world = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	character = world.get_node("Characters/Character")
	terrain = world.get_node("Terrain")
	cam = Camera3D.new()
	cam.far = 600.0
	add_child(cam)
	ctrl = SwimController.new()
	character.controller = ctrl
	_run()


func _run() -> void:
	# Let the world generate until a water tile exists.
	var water: Vector3 = Vector3.INF
	for _i in range(60):
		await get_tree().create_timer(1.0).timeout
		water = _water_center()
		if water != Vector3.INF:
			break
	if water == Vector3.INF:
		print("[swim] FAIL: no water generated")
		get_tree().quit()
		return
	print("[swim] water tile at ", water)

	# Start on the nearest bank, settle, then walk into the water.
	var start_bank: Vector3 = _nearest_bank_center(water)
	if start_bank == Vector3.INF:
		print("[swim] FAIL: no bank near water")
		get_tree().quit()
		return
	character.global_position = start_bank + Vector3(0, 1.0, 0)
	character.velocity = Vector3.ZERO
	await get_tree().create_timer(2.0).timeout
	var into_water: Vector3 = (water - start_bank).normalized()
	ctrl.move_dir = Vector2(into_water.x, into_water.z)
	await get_tree().create_timer(2.0).timeout
	ctrl.move_dir = Vector2.ZERO

	# Phase 1: sink (no input).
	ctrl.hold_jump = false
	var y_start: float = character.global_position.y
	await _watch("sink", 3.0)
	var y_sunk: float = character.global_position.y
	print("[swim] sink: %.2f -> %.2f (%s)" % [
		y_start, y_sunk, "OK slow sink" if y_sunk < y_start - 0.5 and y_sunk > -4.0 else "CHECK"])
	await _shot(water, "swim_1_sunk")

	# Phase 2: hold jump -> float back to the surface and bob there.
	ctrl.hold_jump = true
	await _watch("float", 4.0)
	var y_float: float = character.global_position.y
	print("[swim] float: %.2f (%s)" % [
		y_float, "OK at surface" if absf(y_float - (-1.5)) < 0.35 else "CHECK"])
	await _shot(water, "swim_2_float")

	# Phase 3: swim against the bank and leap out.
	var bank: Vector3 = _nearest_bank_center(water)
	if bank == Vector3.INF:
		print("[swim] no bank found; skipping exit phase")
		get_tree().quit()
		return
	var dir3: Vector3 = (bank - water).normalized()
	ctrl.move_dir = Vector2(dir3.x, dir3.z)
	await get_tree().create_timer(2.5).timeout
	ctrl.press_jump = true
	await get_tree().create_timer(2.0).timeout
	ctrl.move_dir = Vector2.ZERO
	var y_exit: float = character.global_position.y
	print("[swim] exit: y=%.2f at %s (%s)" % [
		y_exit, str(character.global_position),
		"OK on land" if y_exit > -0.6 else "CHECK still in water"])
	await _shot(character.global_position, "swim_3_exit")
	get_tree().quit()


func _watch(label: String, seconds: float) -> void:
	for _i in range(int(seconds * 2)):
		await get_tree().create_timer(0.5).timeout
		print("[swim] %s y=%.2f in_water=%s" % [label, character.global_position.y, character.in_water])


func _shot(target: Vector3, shot_name: String) -> void:
	cam.global_position = target + Vector3(16, 7, 16)
	cam.look_at(character.global_position)
	cam.make_current()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [SHOT_DIR, shot_name])


func _water_center() -> Vector3:
	# Prefer a water tile with a water neighbour (not a 1-tile sliver).
	for module in terrain.terrain_index.all_modules.keys():
		if not (module is TerrainModuleInstance) or not module.def.tags.has("water"):
			continue
		return module.transform.origin
	return Vector3.INF


func _nearest_bank_center(from_pos: Vector3) -> Vector3:
	var best: Vector3 = Vector3.INF
	var best_d: float = INF
	for module in terrain.terrain_index.all_modules.keys():
		if not (module is TerrainModuleInstance) or not module.def.tags.has("bank"):
			continue
		var d: float = module.transform.origin.distance_to(from_pos)
		if d < best_d:
			best_d = d
			best = module.transform.origin
	return best
