extends Node3D

## End-to-end dense-grass review and hardware profile over the real shared
## terrain worker:
##   godot --path /Users/ryko/story res://tests/harness/grass_streaming_qa.tscn \
##     -- --capture /tmp/mythos-grass-streamed.png

const WORLD := preload("res://scenes/world.tscn")
const REVIEW_POSITION := Vector3(48.0, 30.0, -1500.0)
const REVIEW_SEED := 2697992464
const TIMEOUT_SECONDS := 180.0
const PERF_FRAMES := 180
const TEMPORAL_CAPTURE_FRAMES := 30

var _capture_path := "/tmp/mythos-grass-streamed.png"
var _grass_enabled := true
var _review_position := REVIEW_POSITION
var _natural_lighting := false
var _perf_frames := PERF_FRAMES
var _camera_offset := Vector3(14.0, 7.5, 18.0)

func _ready() -> void:
	_read_args()
	var world := WORLD.instantiate()
	var player := world.get_node("Characters/Character") as Node3D
	var streamer := world.get_node("FieldTerrain") as FieldTerrainStreamer
	streamer.SEED_OVERRIDE = REVIEW_SEED
	streamer.CHUNK_RADIUS = 1
	streamer.KEEP_RADIUS = 2
	streamer.MAX_BUILD_PER_FRAME = 3
	streamer.GRASS_ENABLED = _grass_enabled
	player.position = _review_position
	add_child(world)
	_run.call_deferred(world, player, streamer)

func _read_args() -> void:
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == "--capture" and index + 1 < args.size():
			_capture_path = args[index + 1]
		elif args[index] == "--no-grass":
			_grass_enabled = false
		elif args[index] == "--clip-site":
			# Position and atmosphere from the short user-captured glitch clip.
			_review_position = Vector3(41.5, 0.0, -12.7)
			_natural_lighting = true
		elif args[index] == "--screenshot-site":
			# Seed and meadow position from the user's bright-ground review frame.
			_review_position = Vector3(-174.7, 4.0, 315.7)
			_natural_lighting = true
		elif args[index] == "--position" and index + 3 < args.size():
			_review_position = Vector3(float(args[index + 1]),
				float(args[index + 2]), float(args[index + 3]))
			_natural_lighting = true
		elif args[index] == "--camera-offset" and index + 3 < args.size():
			_camera_offset = Vector3(float(args[index + 1]),
				float(args[index + 2]), float(args[index + 3]))
		elif args[index] == "--quick":
			_perf_frames = 30

func _run(world: Node3D, player: Node3D,
		streamer: FieldTerrainStreamer) -> void:
	var started := Time.get_ticks_msec()
	while not _grass_ready(player, streamer):
		if float(Time.get_ticks_msec() - started) / 1000.0 > TIMEOUT_SECONDS:
			push_error("Grass review timed out waiting for the shared worker")
			get_tree().quit(1)
			return
		await get_tree().create_timer(0.1).timeout

	player.process_mode = Node.PROCESS_MODE_DISABLED
	var atmosphere := world.get_node("AtmosphereDirector")
	var environment_node := world.get_node("WorldEnvironment") as WorldEnvironment
	var sun := world.get_node("DirectionalLight3D") as DirectionalLight3D
	if not _natural_lighting:
		atmosphere.process_mode = Node.PROCESS_MODE_DISABLED
		environment_node.environment.fog_enabled = false
		environment_node.environment.volumetric_fog_enabled = false
		environment_node.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment_node.environment.ambient_light_color = Color("dce7dc")
		environment_node.environment.ambient_light_energy = 0.9
		sun.rotation_degrees = Vector3(-52.0, -35.0, 0.0)
		sun.light_energy = 1.25
	(world.get_node("CoordOverlay") as CanvasLayer).visible = false
	(world.get_node("ReviewTeleporter") as CanvasLayer).visible = false

	# Stamp a diagonal trail through the close review frame using the same public
	# API future actors will call.
	var trail_from := player.global_position + Vector3(-7.0, 0.0, -4.0)
	var trail_to := player.global_position + Vector3(7.0, 0.0, 4.0)
	if _grass_enabled:
		streamer._trample_field.stamp_segment(trail_from, trail_to,
			TrampleField.PLAYER_RADIUS, 1.0)

	var camera := world.get_node("Camera3D") as Camera3D
	camera.set_physics_process(false)
	camera.fov = 55.0
	var focus := player.global_position + Vector3.UP * 0.5
	camera.global_position = focus + _camera_offset
	camera.look_at(focus, Vector3.UP)
	# Let deferred shader/material uploads and the last streamed terrain frame
	# settle before sampling the steady-state frame budget.
	await get_tree().create_timer(3.0).timeout

	var process_sum_ms := 0.0
	var process_max_ms := 0.0
	var draw_calls_max := 0
	var primitives_max := 0
	for _frame in _perf_frames:
		await get_tree().process_frame
		var process_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		process_sum_ms += process_ms
		process_max_ms = maxf(process_max_ms, process_ms)
		draw_calls_max = maxi(draw_calls_max, int(Performance.get_monitor(
			Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		primitives_max = maxi(primitives_max, int(Performance.get_monitor(
			Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))

	RenderingServer.force_draw()
	await get_tree().process_frame
	var captured := get_viewport().get_texture().get_image()
	if captured == null or captured.save_png(_capture_path) != OK:
		push_error("Could not capture streamed grass review: %s" % _capture_path)
		get_tree().quit(1)
		return
	for _frame in TEMPORAL_CAPTURE_FRAMES:
		await get_tree().process_frame
	RenderingServer.force_draw()
	await get_tree().process_frame
	var later_path := _capture_path.get_basename() + "-later.png"
	var captured_later := get_viewport().get_texture().get_image()
	if captured_later == null or captured_later.save_png(later_path) != OK:
		push_error("Could not capture later grass review frame: %s" % later_path)
		get_tree().quit(1)
		return

	var stats := streamer._grass_streamer.stats() if _grass_enabled else {}
	var variants: Dictionary = {}
	if _grass_enabled:
		for tile_node: Node in streamer._grass_root.get_children():
			for batch_node: Node in tile_node.get_children():
				variants[String(batch_node.get_meta(&"grass_asset_id", &""))] = true
	var variant_ids: Array = variants.keys()
	variant_ids.sort()
	var report := {
		"adapter": RenderingServer.get_video_adapter_name(),
		"elapsed_ms": Time.get_ticks_msec() - started,
		"stats": stats,
		"variants": variant_ids,
		"cpu_process_average_ms": process_sum_ms / float(_perf_frames),
		"cpu_process_max_ms": process_max_ms,
		"draw_calls_max": draw_calls_max,
		"primitives_max": primitives_max,
		"captures": [_capture_path, later_path],
	}
	var report_path := _capture_path.get_basename() + ".json"
	var report_file := FileAccess.open(report_path, FileAccess.WRITE)
	if report_file != null:
		report_file.store_string(JSON.stringify(report, "  ", true))
	print("[grass_review] adapter=%s elapsed_ms=%d stats=%s variants=%s cpu_process_avg_ms=%.3f cpu_process_max_ms=%.3f draw_calls_max=%d primitives_max=%d capture=%s" % [
		RenderingServer.get_video_adapter_name(),
		Time.get_ticks_msec() - started, str(stats), str(variant_ids),
		process_sum_ms / float(_perf_frames), process_max_ms,
		draw_calls_max, primitives_max, "%s,%s" % [_capture_path, later_path]])
	get_tree().quit()

func _grass_ready(player: Node3D, streamer: FieldTerrainStreamer) -> bool:
	if streamer == null or not streamer.startup_loading_complete():
		return false
	if not _grass_enabled:
		return streamer._built.size() == 9 \
			and streamer._dressing_queue.pending_count() == 0
	if streamer._grass_streamer == null:
		return false
	var origin := Vector2(player.global_position.x, player.global_position.z)
	var all_desired_built := true
	for tile: Vector2i in GrassStreamer.desired_tiles(origin):
		all_desired_built = all_desired_built \
			and streamer._grass_streamer._built.has(tile)
	return all_desired_built and streamer._grass_streamer.pending_count() == 0 \
		and streamer._grass_queued.is_empty()
