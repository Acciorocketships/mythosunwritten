# Focused, self-driving visual regression harness for the owner's 2026-07-16
# level-terrace lip screenshots. A review site is defined only by the exact F3
# player/crosshair pair. ReviewCam.solve_cam reconstructs the original orbit
# angle; never replace these with hand-authored camera transforms.
extends Node3D

const OUT := "/tmp/mythos-level-lips-qa"
const WORLD_SEED := 2697992464

# [name, exact reported player position, exact reported crosshair position]
const SPOTS: Array = [
	["level_lip_61_exact", Vector3(31.0, 4.1, -1455.6),
		Vector3(30.8, 4.3, -1455.3)],
	["level_lip_64_exact", Vector3(34.0, 4.0, -1532.3),
		Vector3(33.9, 4.2, -1532.7)],
]

var _character: CharacterBody3D
var _camera: Camera3D


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(OUT)
	var world: Node3D = load("res://scenes/world.tscn").instantiate()
	var initial_spot := _requested_spot()
	if initial_spot.is_empty():
		initial_spot = SPOTS[0]
	var streamer := world.find_child("FieldTerrain", true, false) as FieldTerrainStreamer
	streamer.SEED_OVERRIDE = WORLD_SEED
	var initial_character := world.find_child("Character", true, false) as CharacterBody3D
	initial_character.position = Vector3(initial_spot[1]) + Vector3.UP * 8.0
	add_child(world)
	_run.call_deferred()


func _requested_spot() -> Array:
	var user_args := OS.get_cmdline_user_args()
	if user_args.size() < 2 or user_args[0] != "--spot":
		return []
	for spot: Array in SPOTS:
		if spot[0] == user_args[1]:
			return spot
	return []


func _wait_ground_neighbourhood(pos: Vector3, timeout_s: float) -> void:
	var streamer := find_child("FieldTerrain", true, false) as FieldTerrainStreamer
	var centre := FieldTerrainStreamer.chunk_of(pos)
	var started := Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - started) / 1000.0 < timeout_s:
		var built: Dictionary = streamer.get("_built")
		var complete := true
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				if not built.has(centre + Vector2i(dx, dz)):
					complete = false
		if complete:
			await get_tree().create_timer(1.0).timeout
			return
		await get_tree().create_timer(0.5).timeout
	push_error("Incomplete 3x3 terrain neighbourhood at level-lip pin %s" % pos)


func _shot(name: String) -> void:
	RenderingServer.force_draw()
	get_viewport().get_texture().get_image().save_png(OUT + "/" + name + ".png")
	print("[level_lips_qa] shot ", name, " cam=", _camera.global_position)


func _run() -> void:
	await get_tree().create_timer(5.0).timeout
	_character = find_child("Character", true, false) as CharacterBody3D
	_camera = get_viewport().get_camera_3d()
	_camera.set("target", null)
	_camera.set_physics_process(false)
	_camera.set_process(false)
	var only_spot := ""
	var user_args := OS.get_cmdline_user_args()
	if user_args.size() >= 2 and user_args[0] == "--spot":
		only_spot = user_args[1]
	for spot: Array in SPOTS:
		if not only_spot.is_empty() and spot[0] != only_spot:
			continue
		_character.velocity = Vector3.ZERO
		_character.global_position = Vector3(spot[1]) + Vector3.UP * 8.0
		_character.set_physics_process(false)
		await _wait_ground_neighbourhood(spot[1], 90.0)
		_character.global_position = spot[1]
		var exact_camera := ReviewCam.solve_cam(spot[1], spot[2])
		var relative := exact_camera - Vector3(spot[1])
		for view: Array in [["exact", 0.0], ["near_left", -deg_to_rad(8.0)],
				["near_right", deg_to_rad(8.0)]]:
			_camera.global_position = Vector3(spot[1]) \
				+ relative.rotated(Vector3.UP, float(view[1]))
			_camera.look_at(Vector3(spot[1]), Vector3.UP)
			_camera.force_update_transform()
			await get_tree().process_frame
			_shot(String(spot[0]) + "_" + String(view[0]))
	print("[level_lips_qa] done: ", OUT)
	get_tree().quit()
