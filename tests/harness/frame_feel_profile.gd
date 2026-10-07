extends Node

## How smooth does the game FEEL? The real world scene and streamer, the close
## (over-the-shoulder) camera, and scripted input: stand, turn the view at a
## constant rate, run, run while turning. Every displayed frame logs its
## interval, CPU (process/physics/render) and GPU time, how many physics ticks
## ran in it, and how far the camera actually turned. A camera that only moves
## on physics ticks shows up as frames whose turn is far from rate * interval
## ("judder"), even when the frame rate is fine.
##   Godot --path . res://tests/harness/frame_feel_profile.tscn -- \
##     [--seed N] [--phase-seconds 8] [--report /tmp/feel.json] [--size 1920x1080]
##     [--no-vsync] [--turn-deg 120] [--x X --z Z] [--ablate]
## --ablate then holds a slow turn and switches one render feature off at a
## time (ablate_* phases), so each feature's cost is the difference from the
## ablate_full phases before and after.
const WORLD := preload("res://scenes/world.tscn")
const PHASES := ["idle", "turn", "run", "run_turn", "idle_end"]
const ABLATIONS := ["full", "no_shadows", "no_fog", "no_ssao", "no_msaa", "no_glow", "no_grass",
	"no_water", "no_dressing", "no_cliff_sheet", "no_terrain_mesh", "half_res", "full_end"]

var _world: Node3D
var _player: CharacterBody3D
var _streamer: FieldTerrainStreamer
var _rig: Node
var _camera: Camera3D
var _seed := 2697992464
var _phase_seconds := 8.0
var _turn_rate := deg_to_rad(120.0)
var _report_path := "/private/tmp/frame-feel.json"
var _phase := "startup"
var _frames: Array[Dictionary] = []
var _last_usec := 0
var _ticks := 0
var _last_yaw := 0.0
var _last_cam := Vector3.ZERO
var _turning := false
var _start := 0
var _x := 0.5
var _z := 0.5
var _ablate := false
var _all_phases: Array = PHASES.duplicate()


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var size := Vector2i.ZERO
	var vsync := true
	for i in args.size():
		var next := args[i + 1] if i + 1 < args.size() else ""
		match args[i]:
			"--seed": _seed = int(next)
			"--phase-seconds": _phase_seconds = float(next)
			"--report": _report_path = next
			"--turn-deg": _turn_rate = deg_to_rad(float(next))
			"--size": size = Vector2i(int(next.split("x")[0]), int(next.split("x")[1]))
			"--no-vsync": vsync = false
			"--x": _x = float(next)
			"--z": _z = float(next)
			"--ablate": _ablate = true
	if size != Vector2i.ZERO: get_window().size = size
	if not vsync: DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_start = Time.get_ticks_msec()
	_world = WORLD.instantiate()
	_player = _world.get_node("Characters/Character")
	_streamer = _world.get_node("FieldTerrain")
	_rig = _world.get_node("Camera3D")
	_camera = _rig as Camera3D
	_streamer.SEED_OVERRIDE = _seed
	_player.position = Vector3(_x, 32.0, _z)
	add_child(_world)
	process_priority = -1000          # sample before the game's own _process
	process_physics_priority = -1000
	_run.call_deferred()


func _physics_process(_delta: float) -> void:
	_ticks += 1


func _process(delta: float) -> void:
	if _turning:
		# The real input path: mouse motion through the rig's look handler,
		# delivered before the game's own _process this frame.
		var pixels := _turn_rate * delta / _gain()
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(pixels, 0.0)
		_rig._apply_look_motion(motion.relative)
	var now := Time.get_ticks_usec()
	var rid := get_viewport().get_viewport_rid()
	var forward := -_camera.global_basis.z
	var yaw := atan2(forward.x, forward.z)
	if _last_usec != 0 and _phase in _all_phases:
		_frames.append({"phase": _phase, "dt": (now - _last_usec) / 1000.0, "ticks": _ticks,
			"turn": absf(wrapf(yaw - _last_yaw, -PI, PI)),
			"cam_move": _camera.global_position.distance_to(_last_cam),
			"process": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			"physics": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			"render_cpu": RenderingServer.viewport_get_measured_render_time_cpu(rid),
			"gpu": RenderingServer.viewport_get_measured_render_time_gpu(rid),
			"draws": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"prims": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			"objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)})
	_ticks = 0
	_last_usec = now
	_last_yaw = yaw
	_last_cam = _camera.global_position


func _gain() -> float:
	return _rig.drag_radians_per_pixel(get_viewport().get_visible_rect().size, _camera.fov,
		_camera.keep_aspect == Camera3D.KEEP_WIDTH) * _rig.mouse_sensitivity


func _run() -> void:
	while not _streamer.startup_loading_complete():
		await get_tree().create_timer(0.2).timeout
	print("FEEL ready after %.1f s" % ((Time.get_ticks_msec() - _start) / 1000.0))
	await get_tree().create_timer(3.0).timeout
	for phase: String in PHASES:
		_phase = phase
		_turning = phase in ["turn", "run_turn"]
		if phase.begins_with("run"): Input.action_press(&"forward")
		else: Input.action_release(&"forward")
		await get_tree().create_timer(_phase_seconds).timeout
	_turning = false
	Input.action_release(&"forward")
	if _ablate: await _run_ablations()
	_finish()


func _run_ablations() -> void:
	var env := (_world.get_node("WorldEnvironment") as WorldEnvironment).environment
	var sun := _world.get_node("DirectionalLight3D") as DirectionalLight3D
	var vp := get_viewport()
	var saved := {"shadow": sun.shadow_enabled, "fog": env.volumetric_fog_enabled,
		"ssao": env.ssao_enabled, "msaa": vp.msaa_3d, "glow": env.glow_enabled}
	_turn_rate = deg_to_rad(20.0)
	_turning = true
	for name: String in ABLATIONS:
		var phase := "ablate_" + name
		_all_phases.append(phase)
		sun.shadow_enabled = saved.shadow and name != "no_shadows"
		env.volumetric_fog_enabled = saved.fog and name != "no_fog"
		env.ssao_enabled = saved.ssao and name != "no_ssao"
		env.glow_enabled = saved.glow and name != "no_glow"
		vp.msaa_3d = Viewport.MSAA_DISABLED if name == "no_msaa" else saved.msaa
		vp.scaling_3d_scale = 0.5 if name == "half_res" else 1.0
		_streamer._grass_root.visible = name != "no_grass"
		for chunk: Node3D in _streamer._built.values():
			for child: Node in chunk.get_children():
				if child is Node3D:
					var n := String(child.name)
					var hide := (name == "no_water" and n.begins_with("Water")) \
						or (name == "no_dressing" and n.begins_with("Dressing")) \
						or (name == "no_cliff_sheet" and (n.contains("Cliff") or n.contains("Slope"))) \
						or (name == "no_terrain_mesh" and n == "Surface")
					(child as Node3D).visible = not hide
		_phase = "settle"
		await get_tree().create_timer(1.5).timeout
		_phase = phase
		await get_tree().create_timer(4.0).timeout
	_turning = false


static func _stats(values: Array) -> Dictionary:
	if values.is_empty(): return {}
	var sorted := values.duplicate()
	sorted.sort()
	var sum := 0.0
	for value: float in values: sum += value
	return {"mean": snappedf(sum / values.size(), 0.01),
		"p50": snappedf(sorted[int((sorted.size() - 1) * 0.5)], 0.01),
		"p95": snappedf(sorted[int((sorted.size() - 1) * 0.95)], 0.01),
		"p99": snappedf(sorted[int((sorted.size() - 1) * 0.99)], 0.01),
		"max": snappedf(sorted.back(), 0.01)}


func _finish() -> void:
	var summary := {}
	for phase: String in _all_phases:
		var rows := _frames.filter(func(r: Dictionary) -> bool: return r.phase == phase)
		if rows.is_empty(): continue
		var pick := func(key: String) -> Array: return rows.map(func(r: Dictionary) -> float: return float(r[key]))
		var tick_hist := {}
		var judder: Array = []
		for r: Dictionary in rows:
			tick_hist[r.ticks] = tick_hist.get(r.ticks, 0) + 1
			if phase in ["turn", "run_turn"]:
				# Relative error of the displayed turn against the frame's own
				# interval: 0 = perfectly even motion, 1 = a frozen frame.
				var expect: float = _turn_rate * r.dt / 1000.0
				judder.append(absf(r.turn - expect) / maxf(expect, 1e-6))
		summary[phase] = {"frames": rows.size(), "dt": _stats(pick.call("dt")),
			"process": _stats(pick.call("process")), "physics": _stats(pick.call("physics")),
			"render_cpu": _stats(pick.call("render_cpu")), "gpu": _stats(pick.call("gpu")),
			"draws": _stats(pick.call("draws")), "prims": _stats(pick.call("prims")),
			"physics_ticks_per_frame": tick_hist, "turn_error": _stats(judder)}
	var result := {"seed": _seed, "viewport": str(get_viewport().get_visible_rect().size),
		"window": str(get_window().size), "screen_scale": DisplayServer.screen_get_scale(),
		"refresh": DisplayServer.screen_get_refresh_rate(),
		"vsync": DisplayServer.window_get_vsync_mode(), "max_fps": Engine.max_fps,
		"physics_tps": Engine.physics_ticks_per_second,
		"interpolation": ProjectSettings.get_setting("physics/common/physics_interpolation", false),
		"adapter": RenderingServer.get_video_adapter_name(), "summary": summary}
	var file := FileAccess.open(_report_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  "))
	file.close()
	var raw := FileAccess.open(_report_path.get_basename() + ".frames.json", FileAccess.WRITE)
	raw.store_string(JSON.stringify(_frames))
	raw.close()
	print("FEEL_RESULT ", JSON.stringify(result))
	get_tree().quit(0)
