extends "res://tests/harness/september10_stream_teleports.gd"

## Production readiness after abandoning several actual teleport destinations.
## Freeze the already integrated scene only AFTER the game releases movement;
## the six views inspect that exact handoff, not a later fully loaded world.
const PIN := Vector3(1618, 12, -571)
const CROSSHAIR := Vector3(1617.7, 12.2, -570.9)
var _output := "/private/tmp/stream-return"

func _ready() -> void:
	super._ready()
	get_window().size = Vector2i(1718, 1035)
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--output": _output = args[i + 1]
	DirAccess.make_dir_recursive_absolute(_output)

func _run() -> void:
	while not _stream.startup_loading_complete():
		if Time.get_ticks_msec() - _start > 900000: _finish("startup_timeout"); return
		await get_tree().create_timer(.2).timeout
	_startup_ms = Time.get_ticks_msec() - _start
	for point: Vector3 in [Vector3(475, 21, -2077), Vector3(892, 9, -1828), Vector3(268, 8, -359)]:
		_site += 1; _phase = "transient"; _hold = true; _hold_position = point
		_player.position = point; _player.velocity = Vector3.ZERO
		await get_tree().create_timer(10).timeout
	_site += 1; _phase = "return"; _hold_position = PIN; _player.position = PIN
	var returned := Time.get_ticks_msec()
	for i in 3: await get_tree().process_frame
	while _stream._player_frozen:
		if Time.get_ticks_msec() - returned > 900000: _finish("return_timeout"); return
		await get_tree().create_timer(.05).timeout
	var ready_ms := Time.get_ticks_msec() - returned
	var built := _stream._built.keys()
	_world.process_mode = Node.PROCESS_MODE_DISABLED
	_phase = "capture"
	var camera := _world.get_node("Camera3D") as Camera3D
	camera.set("target", null); camera.fov = 75.0
	var visibility: CameraVisibilityBubble = camera.get("_visibility")
	if visibility != null: visibility.clear()
	var director := _world.find_child("AtmosphereDirector", true, false) as AtmosphereDirector
	if director != null:
		director._mood_weights.clear()
		director._update_mood(0.0, Helper.biome_weights5(PIN, _stream.world_seed))
	var position := ReviewCam.solve_cam(PIN, CROSSHAIR)
	var relative := position - PIN
	var poses := {"exact": position,
		"near_left": PIN + relative.rotated(Vector3.UP, deg_to_rad(-8)),
		"near_right": PIN + relative.rotated(Vector3.UP, deg_to_rad(8)),
		"jitter_0": position, "jitter_1": position + Vector3(.015, 0, 0)}
	var solver := CameraObstructionSolver.new()
	var excluded: Array[RID] = [_player.get_rid()]
	var pivot := solver.resolve_ceiling(camera.get_world_3d().direct_space_state, PIN, 1.35, 5.0, excluded)
	var horizontal := relative; horizontal.y = 0
	poses["gameplay_camera"] = solver.resolve_boom(camera.get_world_3d().direct_space_state, pivot, pivot + horizontal, excluded)
	for label: String in poses:
		camera.global_position = poses[label]; camera.look_at(PIN, Vector3.UP)
		camera.force_update_transform()
		for orb in _world.find_children("SpiritOrb*", "Node3D", true, false):
			if orb is SpiritOrb:
				orb.elapsed = 0.0; orb._process(0.0)
		for batch in _world.find_children("SmallSpiritOrbs*", "Node3D", true, false):
			batch.sample(0.0, batch.to_local(camera.global_position))
		for i in 4: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_output + "/11_orbs_streaming_" + label + ".png")
	FileAccess.open(_output + "/11_orbs_streaming_camera.json", FileAccess.WRITE).store_string(JSON.stringify({
		"seed": 2697992464, "player": str(PIN), "crosshair": str(CROSSHAIR),
		"reconstructed_camera": str(position), "original_precision_recoverable": false,
		"poses": poses, "ready_msec": ready_ms, "startup_msec": _startup_ms,
		"built_at_release": built, "capture_event": "production movement release after return teleport"}, "  "))
	_finish("complete")
