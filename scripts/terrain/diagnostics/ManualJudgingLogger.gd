extends Node

## One bounded record per second, including the worst frames and streaming
## stage timings. Always active in normal play so a judging pass needs no flags.
class FrameStart:
	extends Node
	var process_started := 0
	var physics_started := 0
	func _process(_dt: float) -> void:
		process_started = Time.get_ticks_usec()
	func _physics_process(_dt: float) -> void:
		physics_started = Time.get_ticks_usec()

var _start: FrameStart
var _physics_usec := 0
var _previous_process_usec := 0
var _previous_physics_usec := 0
var streamer: Node
var _file: FileAccess
var _elapsed := 0.0
var _frames := PackedFloat32Array()
var _hitches: Array = []
var _seconds := 0.0
var _viewport: Viewport
var _previous_sections: Dictionary = {}
var _previous_components: Dictionary = {}
var _last_frame_usec := 0
var _runtime_probe: RefCounted

func _ready() -> void:
	process_priority = 2000
	process_physics_priority = 2000
	if Helper.is_headless():
		set_process(false)
		return
	var directory := "user://judging_logs"
	DirAccess.make_dir_recursive_absolute(directory)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var path := directory.path_join("judging-" + stamp + ".jsonl")
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file == null:
		push_warning("Cannot open judging log: " + path)
		set_process(false)
		return
	if ClassDB.class_exists(&"CSharpScript"):
		var probe_script := load("res://scripts/native/NativeRuntimeProbe.cs") as Script
		if probe_script != null and probe_script.can_instantiate():
			_runtime_probe = probe_script.new()
	_start = FrameStart.new()
	_start.process_priority = -2000
	_start.process_physics_priority = -2000
	add_child(_start)
	_viewport = get_viewport()
	RenderingServer.viewport_set_measure_render_time(_viewport.get_viewport_rid(), true)
	_file.store_line(JSON.stringify({"type": "session", "seed": streamer.world_seed,
		"started": stamp, "engine": Engine.get_version_info(), "schema": 3,
		"system_memory": OS.get_memory_info()}))
	print("[judging-log] " + ProjectSettings.globalize_path(path))

func _physics_process(_dt: float) -> void:
	if _start != null:
		_physics_usec += Time.get_ticks_usec() - _start.physics_started

func _process(_dt: float) -> void:
	if _file == null: return
	# Engine delta can be clamped during a long stall. Log wall time so the
	# manual pass retains the full hitch, including time outside callbacks.
	# Start-to-start aligns this interval with the preceding frame's spans.
	var now := _start.process_started
	if _last_frame_usec == 0:
		_last_frame_usec = now
		return
	var dt := (now - _last_frame_usec) / 1000000.0
	_last_frame_usec = now
	_elapsed += dt
	_seconds += dt
	_frames.append(dt * 1000.0)
	if dt >= 0.05 and _hitches.size() < 32:
		var gpu_ms := RenderingServer.viewport_get_measured_render_time_gpu(_viewport.get_viewport_rid())
		_hitches.append({"at_s": _seconds, "frame_ms": dt * 1000.0,
			"process_ms": _previous_process_usec / 1000.0,
			"physics_ms": _previous_physics_usec / 1000.0,
			"streamer_us": _previous_sections,
			"components_us": _previous_components,
			"gpu_ms": gpu_ms if gpu_ms > 0.0 else null,
			"render_cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(_viewport.get_viewport_rid()),
			"gc_pause_usec": _runtime_probe.PauseUsec() if _runtime_probe != null else null,
			"managed_full_collections": _runtime_probe.FullCollections() if _runtime_probe != null else null})
	_previous_process_usec = Time.get_ticks_usec() - _start.process_started
	_previous_physics_usec = _physics_usec
	_physics_usec = 0
	_previous_sections = streamer.last_frame_sections.duplicate()
	_previous_components = {"water": WaterRippleSim.last_process_usec,
		"water_packets": WaterRippleSim.last_packets_usec, "water_flow": WaterRippleSim.last_flow_usec,
		"atmosphere": AtmosphereDirector.last_process_usec,
		"atmosphere_stages": AtmosphereDirector.last_sections.duplicate()}
	if _elapsed < 1.0: return
	_frames.sort()
	var position: Vector3 = streamer.player.global_position
	_file.store_line(JSON.stringify({"type": "second", "at_s": _seconds,
		"position": [position.x, position.y, position.z], "frames": _frames.size(),
		"fps": _frames.size() / _elapsed, "p50_ms": _frames[_frames.size()/2],
		"p95_ms": _frames[mini(_frames.size()-1, int(_frames.size()*.95))],
		"max_ms": _frames[-1], "hitches": _hitches,
		"memory_mb": Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0,
		"system_memory": OS.get_memory_info(),
		"gc_pause_usec": _runtime_probe.PauseUsec() if _runtime_probe != null else null,
		"managed_heap_bytes": _runtime_probe.HeapBytes() if _runtime_probe != null else null,
		"managed_full_collections": _runtime_probe.FullCollections() if _runtime_probe != null else null,
		"water_sampler_count": WaterRippleSim.last_sampler_count,
		"water_frame_cache_entries": WaterRippleSim.last_frame_cache_entries,
		"vram_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0,
		"texture_mb": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)/1048576.0,
		"buffer_mb": Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)/1048576.0,
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"streaming": streamer.streaming_profile_snapshot()}))
	_file.flush()
	_frames.clear()
	_hitches.clear()
	_elapsed = 0.0

func _exit_tree() -> void:
	if _file != null:
		_file.store_line(JSON.stringify({"type": "end", "at_s": _seconds}))
		_file.close()
