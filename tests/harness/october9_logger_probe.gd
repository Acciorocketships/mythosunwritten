extends SceneTree

class StreamerStub:
	extends Node
	var world_seed := 2697992464
	var player := Node3D.new()
	var last_frame_sections := {"probe": 17}
	func streaming_profile_snapshot() -> Dictionary:
		return {"probe": true}

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var streamer := StreamerStub.new()
	root.add_child(streamer)
	streamer.add_child(streamer.player)
	var logger := preload("res://scripts/terrain/diagnostics/ManualJudgingLogger.gd").new()
	logger.streamer = streamer
	streamer.add_child(logger)
	# Establish a preceding frame before injecting a stall between frames.
	await create_timer(0.2).timeout
	OS.delay_msec(180)
	await create_timer(1.2).timeout
	var path := logger._file.get_path_absolute()
	logger.free()
	var found_hitch := false
	var found_second := false
	for line in FileAccess.get_file_as_string(path).split("\n",false):
		var record: Dictionary = JSON.parse_string(line)
		if record.type != "second": continue
		found_second = true
		for hitch in record.hitches:
			if hitch.frame_ms >= 170.0:
				found_hitch = true
				if OS.get_name() == "macOS":
					assert(hitch.thread_cpu_ms != null and hitch.thread_cpu_ms < hitch.frame_ms - 100.0, "logger distinguishes sleeping from CPU work")
	assert(found_second and found_hitch, "Logger must retain the full 180 ms wall-clock stall")
	print("LOGGER_PROBE_PASS ", path)
	quit()
