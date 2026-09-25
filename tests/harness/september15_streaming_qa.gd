extends "res://tests/harness/travel_profile.gd"

## Real southward character input. Survey mode is a separate 10m/s scheduling
## stress: it crosses obstacles but obeys the production readiness freeze.
class SouthController extends CharacterController:
	func get_move_vector(_character: CharacterBody3D, _delta: float) -> Vector2:
		return Vector2(0, -1)
	func wants_jump(_character: CharacterBody3D, _delta: float) -> bool:
		return Input.is_action_just_pressed(&"jump")
	func jump_held(_character: CharacterBody3D, _delta: float) -> bool:
		return Input.is_action_pressed(&"jump")

var _events_file: FileAccess
var _event_serial := 0
var _event_sample := 0
var _photo_taken := false
var _capturing := false

func _ready() -> void:
	if "--baseline-water" in OS.get_cmdline_user_args():
		var stream_script := load("res://scripts/terrain/field/FieldTerrainStreamer.gd") as GDScript
		stream_script.source_code = FileAccess.get_file_as_string("res://docs/qa/2026-09-15-manual/02-streaming/FieldTerrainStreamer-pre-yield.gd.txt")
		assert(stream_script.reload(true) == OK)
		var landscape := load("res://scripts/terrain/heightfield/LandformField.gd") as GDScript
		landscape.source_code = FileAccess.get_file_as_string("res://docs/qa/2026-09-15-manual/02-streaming/LandformField-pre-owner-cache.gd.txt")
		assert(landscape.reload(true) == OK)
		var planner := load("res://scripts/terrain/water/WaterPlan.gd") as GDScript
		planner.source_code = FileAccess.get_file_as_string("res://docs/qa/2026-09-15-manual/02-streaming/WaterPlan-pre-sample-cache.gd.txt")
		assert(planner.reload(true) == OK)
		var script := load("res://scripts/terrain/water/WaterField.gd") as GDScript
		script.source_code = FileAccess.get_file_as_string("res://docs/qa/2026-09-15-manual/02-streaming/WaterField-before.gd.txt")
		assert(script.reload(true) == OK)
	WaterField.profile_source_cost = true
	Engine.max_fps = 60
	super._ready()
	_player.controller = SouthController.new()
	_events_file = FileAccess.open(_report_path + ".events.jsonl", FileAccess.WRITE)
	if not Helper.is_headless():
		get_window().size = Vector2i(1920, 1080)
	if _mode == "survey": _player.process_mode = Node.PROCESS_MODE_DISABLED

func _process(delta: float) -> void:
	if _capturing: return
	super._process(delta)
	if _mode == "survey":
		# Keep the diagnostic movement out of real character physics while
		# reporting its actual travel velocity to production lookahead.
		_player.process_mode = Node.PROCESS_MODE_DISABLED
		_player.velocity = Vector3(0,0,-10)
		if _running and not _streamer._player_frozen:
			_player.position.z -= 10.0 * delta
			_player.position.y = 44.0
	if _events_file == null or Time.get_ticks_msec() - _event_sample < 1000: return
	_event_sample = Time.get_ticks_msec()
	var state := _streamer.streaming_profile_snapshot()
	state["worker"] = _streamer.worker_progress_snapshot()
	for event: Dictionary in state.recent_events:
		if int(event.serial) <= _event_serial: continue
		_events_file.store_line(JSON.stringify(event))
		_event_serial = int(event.serial)
	state.erase("recent_events")
	state.erase("recent_starts")
	state.erase("times")
	state["event"] = "sample"
	state["msec"] = _event_sample
	state["position"] = str(_player.position)
	state["phase"] = _phase
	_events_file.store_line(JSON.stringify(state))
	_events_file.flush()
	if "--capture-photo" in OS.get_cmdline_user_args() and _running and not _photo_taken and _player.position.z < -377.2:
		_photo_taken = true
		_capture_photo.call_deferred()

func _capture_photo() -> void:
	if Helper.is_headless(): return
	_capturing = true
	var started := Time.get_ticks_msec()
	var camera := _world.get_node("Camera3D") as Camera3D
	var previous_camera := camera.global_transform
	var previous_player := _player.global_transform
	var previous_mode := _world.process_mode
	for body: Node in _world.find_children("*","CollisionObject3D",true,false):
		body.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	_world.process_mode = Node.PROCESS_MODE_DISABLED
	var reviewer := preload("res://tests/harness/september13_visibility_qa.gd").new()
	reviewer._freeze_material_clocks(_world)
	reviewer.free()
	_player.anim_tree.active = false
	for layer: CanvasLayer in _world.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	var feet := Vector3(-530.6,44,-377.2)
	var aim := Vector3(-528.3,44,-381.7)
	_player.global_position = feet
	var space := camera.get_world_3d().direct_space_state
	var obstruction := CameraObstructionSolver.new()
	var excluded: Array[RID] = [_player.get_rid()]
	var pivot := obstruction.resolve_ceiling(space,feet,1.0,CameraMouseView.PIVOT_HEIGHT,excluded)
	var backward := (pivot-aim).normalized()
	var eye := ReviewCam.solve_cam(feet,aim,Vector2(backward.x,backward.z).length()*CameraMouseView.BOOM_LENGTH,
		pivot.y-feet.y+backward.y*CameraMouseView.BOOM_LENGTH,pivot.y-feet.y)
	var poses := []
	for angle: float in [0,-8,8]:
		camera.fov = 75
		var desired := pivot+(eye-pivot).rotated(Vector3.UP,deg_to_rad(angle))
		camera.global_position = obstruction.resolve_boom(space,pivot,desired,excluded)
		camera.look_at(pivot)
		await get_tree().process_frame
		RenderingServer.force_draw(false)
		get_viewport().get_texture().get_image().save_png(_report_path + ".P05_%d.png" % int(angle))
		poses.append({"angle":angle,"camera":str(camera.global_transform),"pivot":str(pivot)})
	FileAccess.open(_report_path + ".P05.json",FileAccess.WRITE).store_string(JSON.stringify({
		"player_at_capture": str(_player.position), "poses": poses,
		"photo_overlay_player": str(feet), "photo_overlay_crosshair":str(aim),
		"elapsed_msec":Time.get_ticks_msec()-_run_start,
		"streaming":_streamer.streaming_profile_snapshot()},"  "))
	camera.global_transform = previous_camera
	_player.global_transform = previous_player
	_world.process_mode = previous_mode
	var pause_msec := Time.get_ticks_msec()-started
	_run_start += pause_msec
	_last_usec = Time.get_ticks_usec()
	_capturing = false

func _run() -> void:
	while not _streamer.startup_loading_complete():
		if Time.get_ticks_msec() - _start > 900000:
			_finish("startup_timeout"); return
		await get_tree().create_timer(.1).timeout
	if "--photo-only" in OS.get_cmdline_user_args():
		# Separate visual control: never include camera pauses in timed travel.
		_phase = "photo"
		await get_tree().create_timer(5.0).timeout
		while _streamer._feature_queue.pending_count() > 0 or _streamer._dressing_queue.pending_count() > 0:
			await get_tree().process_frame
		await _capture_photo()
		_finish("complete")
		return
	_phase = _mode
	_running = true
	_run_start = Time.get_ticks_msec()
	_last_position = _player.position
	while Time.get_ticks_msec() - _run_start < _seconds * 1000:
		await get_tree().create_timer(.1).timeout
	_finish("complete")
