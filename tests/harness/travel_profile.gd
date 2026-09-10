extends Node

## Actual character input + real production streaming. Optional traverse mode
## separately stresses chunk scheduling when cliffs stop the walking route.
const WORLD := preload("res://scenes/world.tscn")
var _world: Node3D
var _player: CharacterBody3D
var _streamer: FieldTerrainStreamer
var _seconds := 180.0
var _mode := "walk"
var _ablate := false
var _render_only := false
var _report_path := "/private/tmp/travel-profile.json"
var _seed := 2697992464
var _phase := "startup"
var _frames: Dictionary = {}
var _samples: Array[Dictionary] = []
var _last_usec := 0
var _last_sample := 0
var _start := 0
var _run_start := 0
var _distance := 0.0
var _last_position := Vector3.ZERO
var _frozen_seconds := 0.0
var _log: FileAccess
var _running := false
var _x := 0.5
var _z := 0.5

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--seconds" and i + 1 < args.size(): _seconds = float(args[i + 1])
		if args[i] == "--mode" and i + 1 < args.size(): _mode = args[i + 1]
		if args[i] == "--report" and i + 1 < args.size(): _report_path = args[i + 1]
		if args[i] == "--seed" and i + 1 < args.size(): _seed = int(args[i + 1])
		if args[i] == "--x" and i + 1 < args.size(): _x = float(args[i + 1])
		if args[i] == "--z" and i + 1 < args.size(): _z = float(args[i + 1])
		if args[i] == "--ablate": _ablate = true
		if args[i] == "--render-only": _render_only = true; _seconds = 0.0; _ablate = true
	_log = FileAccess.open(_report_path + ".jsonl", FileAccess.WRITE)
	_start = Time.get_ticks_msec()
	_last_usec = Time.get_ticks_usec()
	if not Helper.is_headless():
		get_window().size = Vector2i(1280, 720)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	else:
		Engine.max_fps = 60
	_world = WORLD.instantiate()
	_player = _world.get_node("Characters/Character")
	_streamer = _world.get_node("FieldTerrain")
	_streamer.SEED_OVERRIDE = _seed
	_streamer.PROFILE_STREAMING = true
	_player.position = Vector3(_x, 32.0, _z)
	add_child(_world)
	_last_position = _player.global_position
	_run.call_deferred()

func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	if not _frames.has(_phase): _frames[_phase] = []
	_frames[_phase].append(float(now - _last_usec) / 1000.0)
	_last_usec = now
	if _running:
		_distance += Vector2(_player.global_position.x - _last_position.x,
			_player.global_position.z - _last_position.z).length()
		_last_position = _player.global_position
		if _streamer._player_frozen: _frozen_seconds += delta
		if _mode == "traverse":
			# Diagnostic traversal deliberately bypasses obstacles, never terrain
			# generation/readiness. Real walking is a separate measured run.
			_player.position.z -= 10.0 * delta
			_player.position.y = 32.0
			_player.velocity = Vector3.ZERO
		elif int(Time.get_ticks_msec() / 1000) % 4 == 0:
			Input.action_press(&"jump")
		else:
			Input.action_release(&"jump")
	if Time.get_ticks_msec() - _last_sample < 1000: return
	_last_sample = Time.get_ticks_msec()
	var snapshot := _streamer.streaming_profile_snapshot()
	var rid := get_viewport().get_viewport_rid()
	var sample := {"elapsed_ms": _last_sample - _start, "phase": _phase,
		"position": [_player.position.x, _player.position.y, _player.position.z],
		"distance": _distance, "frozen_seconds": _frozen_seconds,
		"queued": snapshot.queued, "built": snapshot.built,
		"pending": snapshot.pending_terrain, "active": str(snapshot.active_job),
		"counts": snapshot.counts, "field_cache": snapshot.field_cache,
		"cpu_process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"render_cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(rid) if not Helper.is_headless() else 0.0,
		"render_gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(rid) if not Helper.is_headless() else 0.0,
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC)}
	_samples.append(sample)
	_log.store_line(JSON.stringify(sample))
	_log.flush()
	if _samples.size() % 10 == 0:
		print("TRAVEL ", JSON.stringify(sample))

func _run() -> void:
	while not _streamer.startup_loading_complete():
		if Time.get_ticks_msec() - _start > 300000:
			_finish("startup_timeout")
			return
		await get_tree().create_timer(0.1).timeout
	if _render_only:
		_phase = "scene_ready"
		var centre := FieldTerrainStreamer.chunk_of(_player.position)
		var started := Time.get_ticks_msec()
		while true:
			var complete := true
			for chunk: Vector2i in _streamer.desired_chunks(centre, 1):
				complete = complete and _streamer._built.has(chunk) and _streamer._feature_square_ready(chunk)
			if complete and _streamer._dressing_queue.pending_count() == 0: break
			if Time.get_ticks_msec() - started > 600000:
				_finish("scene_timeout")
				return
			await get_tree().create_timer(0.2).timeout
	_phase = _mode
	_running = true
	_run_start = Time.get_ticks_msec()
	_last_position = _player.position
	if _mode == "walk": Input.action_press(&"forward")
	while Time.get_ticks_msec() - _run_start < _seconds * 1000:
		await get_tree().create_timer(0.1).timeout
	_running = false
	Input.action_release(&"forward")
	Input.action_release(&"jump")
	if _ablate and not Helper.is_headless(): await _render_probe()
	_finish("complete")

func _render_probe() -> void:
	_phase = "settling"
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	(_world.get_node("Camera3D") as Camera3D).set_physics_process(false)
	# End generation for this diagnostic scene, then wait for its one active
	# job to finish. No frame-rate comparison overlaps background generation.
	_streamer.set_process(false)
	if _render_only:
		_phase = "worker_active"
		await get_tree().create_timer(10.0).timeout
		_phase = "settling"
	_streamer._mutex.lock()
	_streamer._jobs.clear()
	_streamer._queued.clear()
	_streamer._grass_queued.clear()
	_streamer._followups.clear()
	_streamer._mutex.unlock()
	var wait_start := Time.get_ticks_msec()
	while not _streamer.streaming_profile_snapshot().active_job.is_empty():
		if Time.get_ticks_msec() - wait_start > 300000: return
		await get_tree().create_timer(0.1).timeout
	var env := (_world.get_node("WorldEnvironment") as WorldEnvironment).environment
	var camera := _world.get_node("Camera3D") as Camera3D
	var sun := _world.get_node("DirectionalLight3D") as DirectionalLight3D
	var attrs := camera.attributes
	var fog := env.volumetric_fog_enabled
	var glow := env.glow_enabled
	var ao := env.ssao_enabled
	var shadows := sun.shadow_enabled
	var ripples := _world.get_node("WaterRipples")
	for variant in ["full", "no_grass", "full_repeat", "no_atmosphere", "no_nature", "no_water", "no_shadows", "half_resolution", "full_final"]:
		_streamer._grass_root.visible = variant != "no_grass"
		for node: Node3D in _streamer._built.values():
			var nature := node.get_node_or_null("Dressing") as Node3D
			if nature != null: nature.visible = variant != "no_nature"
			var fx := node.get_node_or_null("BiomeFx") as Node3D
			if fx != null: fx.visible = variant != "no_atmosphere"
			var water := node.get_node_or_null("Water") as Node3D
			if water != null: water.visible = variant != "no_water"
		ripples.set_process(variant != "no_water")
		env.volumetric_fog_enabled = fog and variant != "no_atmosphere"
		env.glow_enabled = glow and variant != "no_atmosphere"
		env.ssao_enabled = ao and variant != "no_atmosphere"
		camera.attributes = null if variant == "no_atmosphere" else attrs
		sun.shadow_enabled = shadows and variant != "no_shadows"
		get_viewport().scaling_3d_scale = 0.5 if variant == "half_resolution" else 1.0
		_phase = "settling"
		await get_tree().create_timer(2.0).timeout
		_phase = variant
		await get_tree().create_timer(8.0).timeout
		if variant == "full_final":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(_report_path.get_basename() + ".png")

static func summary(values: Array) -> Dictionary:
	if values.is_empty(): return {}
	var sorted := values.duplicate()
	sorted.sort()
	var sum := 0.0
	for value: float in values: sum += value
	return {"frames": values.size(), "mean_ms": sum / values.size(),
		"p50_ms": sorted[int((sorted.size() - 1) * 0.5)],
		"p95_ms": sorted[int((sorted.size() - 1) * 0.95)],
		"p99_ms": sorted[int((sorted.size() - 1) * 0.99)], "max_ms": sorted.back()}

func _finish(status: String) -> void:
	_running = false
	Input.action_release(&"forward")
	Input.action_release(&"jump")
	var summaries: Dictionary = {}
	for phase: String in _frames: summaries[phase] = summary(_frames[phase])
	var result := {"status": status, "seed": _seed, "mode": _mode,
		"render_only": _render_only, "headless": Helper.is_headless(), "resolution": str(get_viewport().get_visible_rect().size),
		"adapter": RenderingServer.get_video_adapter_name() if not Helper.is_headless() else "headless",
		"distance": _distance, "frozen_seconds": _frozen_seconds, "frames": summaries,
		"streaming": _streamer.streaming_profile_snapshot(), "samples": _samples}
	var file := FileAccess.open(_report_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  "))
	file.close()
	print("TRAVEL_RESULT ", status, " distance=", _distance, " frames=", JSON.stringify(summaries), " -> ", _report_path)
	get_tree().quit(0 if status == "complete" else 1)
