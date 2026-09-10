extends Node3D

## Exact-camera visual regression harness for the village issues reported on
## 2026-09-04. Every pin is copied from the F3 player/crosshair overlay in the
## corresponding annotated screenshot. ReviewCam reconstructs the gameplay
## orbit camera; the two nearby views expose defects hidden by one silhouette.
##
##   Godot --path . res://tests/harness/village_reported_qa.tscn -- \
##     --spot terrain_handoff_wedge --output /tmp/village-before

const WORLD_SEED := 2697992464
const WAIT_HARD_TIMEOUT_SECONDS := 900.0
const IDLE_SETTLE_SECONDS := 3.0
const DEFAULT_OUTPUT := "/tmp/mythos-village-reported-qa"

# [stable id, source image filename, exact player position, exact crosshair]
const SPOTS: Array[Array] = [
	["terrain_handoff_wedge", "Screenshot 2026-09-04 at 4.47.25 PM.png",
		Vector3(238.1, 4.0, 316.6), Vector3(237.8, 4.2, 316.6)],
	["orphan_stone_cell", "Screenshot 2026-09-04 at 4.53.10 PM.png",
		Vector3(253.4, 9.9, 289.5), Vector3(253.7, 10.1, 289.3)],
	["diagonal_gap_facade_planes", "Screenshot 2026-09-04 at 4.50.23 PM.png",
		Vector3(286.3, 5.1, 291.4), Vector3(286.4, 5.4, 291.7)],
	["elevated_turf_supports", "Screenshot 2026-09-04 at 4.49.52 PM.png",
		Vector3(237.5, 17.0, 294.2), Vector3(237.4, 17.8, 293.1)],
	["planters_in_walkway", "Screenshot 2026-09-04 at 4.49.25 PM.png",
		Vector3(247.3, 17.0, 299.1), Vector3(247.0, 17.4, 299.3)],
	["door_behind_railing", "Screenshot 2026-09-04 at 4.49.13 PM.png",
		Vector3(258.8, 11.0, 315.3), Vector3(259.2, 11.3, 315.4)],
	["double_ground_sheet", "Screenshot 2026-09-04 at 4.46.44 PM.png",
		Vector3(251.0, 4.0, 278.7), Vector3(251.8, 4.2, 278.3)],
	["facade_plane_jut", "Screenshot 2026-09-04 at 4.48.59 PM.png",
		Vector3(262.8, 5.0, 336.0), Vector3(263.0, 5.2, 336.3)],
	["turf_lip_corner", "Screenshot 2026-09-04 at 4.48.41 PM.png",
		Vector3(282.3, 8.1, 345.2), Vector3(282.6, 8.3, 345.5)],
]

var _output_dir := DEFAULT_OUTPUT
var _spot: Array = SPOTS[0]
var _capture_all := false
var _streamer: FieldTerrainStreamer
var _character: CharacterBody3D
var _camera: Camera3D


func _spots() -> Array:
	return SPOTS


func _ready() -> void:
	Engine.max_fps = 30
	_read_args()
	get_window().size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(_output_dir)
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	_streamer = world.find_child("FieldTerrain", true, false) \
		as FieldTerrainStreamer
	_character = world.find_child("Character", true, false) as CharacterBody3D
	assert(_streamer != null and _character != null)
	_streamer.SEED_OVERRIDE = WORLD_SEED
	_streamer.CHUNK_RADIUS = 1
	_streamer.KEEP_RADIUS = 2
	_streamer.GRASS_ENABLED = false
	_character.position = Vector3(_spot[2]) + Vector3.UP * 4.0
	_character.velocity = Vector3.ZERO
	_character.set_physics_process(false)
	add_child(world)
	_run.call_deferred()


func _read_args() -> void:
	_spot = _spots()[0]
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		var next := args[index + 1] if index + 1 < args.size() else ""
		match args[index]:
			"--all":
				_capture_all = true
			"--spot":
				for candidate: Array in _spots():
					if String(candidate[0]) == next:
						_spot = candidate
						break
			"--output":
				_output_dir = next


func _run() -> void:
	await get_tree().create_timer(5.0).timeout
	_camera = get_viewport().get_camera_3d()
	assert(_camera != null)
	_camera.set("target", null)
	_camera.set_physics_process(false)
	_camera.set_process(false)
	_character.velocity = Vector3.ZERO
	_character.set_physics_process(false)
	var ready := await _wait_for_site()
	var capture_spots: Array = _spots() if _capture_all else [_spot]
	for capture_spot: Array in capture_spots:
		await _capture_spot(capture_spot)
	print("[village_reported_qa] captures=%d ready=%s output=%s" % [
		capture_spots.size(), ready, _output_dir])
	get_tree().quit(0 if ready else 2)


func _capture_spot(spot: Array) -> void:
	_character.global_position = Vector3(spot[2])
	var exact_camera := ReviewCam.solve_cam(Vector3(spot[2]), Vector3(spot[3]))
	var relative := exact_camera - Vector3(spot[2])
	for view: Array in [["exact", 0.0], ["near_left", -deg_to_rad(8.0)],
			["near_right", deg_to_rad(8.0)]]:
		_camera.global_position = Vector3(spot[2]) \
			+ relative.rotated(Vector3.UP, float(view[1]))
		_camera.look_at(Vector3(spot[2]), Vector3.UP)
		_camera.force_update_transform()
		for unused in 3:
			await get_tree().process_frame
		await _shot("%s_%s" % [String(spot[0]), String(view[0])])
	print("[village_reported_qa] source=", String(spot[1]))


func _wait_for_site() -> bool:
	var centre_chunk := FieldTerrainStreamer.chunk_of(Vector3(_spot[2]))
	var wanted: Array = _streamer.desired_chunks(centre_chunk, 1)
	var started := Time.get_ticks_msec()
	var idle_since := -1
	while true:
		_character.global_position = Vector3(_spot[2])
		var elapsed := float(Time.get_ticks_msec() - started) / 1000.0
		if elapsed >= WAIT_HARD_TIMEOUT_SECONDS:
			push_error("Village visual QA timed out; missing=%s" % _missing(wanted))
			return false
		var missing := _missing(wanted)
		var progress := _streamer.worker_progress_snapshot()
		var active := bool(progress.get("active", false)) \
			and StringName(progress.get("phase", &"idle")) != &"idle"
		if missing.is_empty() and _streamer.startup_loading_complete() \
				and not active:
			if idle_since < 0:
				idle_since = Time.get_ticks_msec()
			elif float(Time.get_ticks_msec() - idle_since) / 1000.0 \
					>= IDLE_SETTLE_SECONDS:
				return true
		else:
			idle_since = -1
		await get_tree().create_timer(0.25).timeout
	return false


func _missing(wanted: Array) -> Array:
	var out: Array = []
	for chunk: Vector2i in wanted:
		if not _streamer._built.has(chunk) \
				or not _streamer._feature_square_ready(chunk):
			out.append(chunk)
	return out


func _shot(name: String) -> void:
	RenderingServer.force_draw()
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [_output_dir, name]
	assert(image != null and image.save_png(path) == OK)
	print("[village_reported_qa] captured ", path,
		" camera=", _camera.global_position)
