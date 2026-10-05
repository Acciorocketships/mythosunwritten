extends Node3D

## Production-streamed visual review, including features, water and nature.
## Example: godot --path /Users/ryko/story res://tests/harness/atmosphere_review.tscn
##   -- --x 672 --z 96 --capture /tmp/cherryveil.png

const WORLD := preload("res://scenes/world.tscn")
const REVIEW_POSITION := Vector3(48.0, 30.0, -1500.0)
const SHORE_REVIEW_POSITION := Vector3(-672.0, 30.0, -3360.0)
const REVIEW_SEED := 2697992464
const TIMEOUT_SECONDS := 3600.0

var _capture_path := "/tmp/atmosphere-review.png"
var _review_actor: CharacterBody3D
var _review_position := REVIEW_POSITION
var _camera_offset := Vector3(28.0, 19.0, 34.0)
var _measure := false
var _sweep := false
var _orbit := false
var _snapshot_path := ""
var _freeze_time := -1.0
var _gi := "quality"
var _quality := 1
var _disable_fog := false
var _disable_glow := false
var _capture_view: SubViewport
var _last_draw_usec := 0
var _forced_draws := 0
var _live_travel_end := Vector2.INF

func _ready() -> void:
	_read_args()
	_setup_capture_view()
	var world := WORLD.instantiate()
	var player := world.get_node("Characters/Character") as CharacterBody3D
	_review_actor = player
	var streamer := world.get_node("FieldTerrain") as FieldTerrainStreamer
	# Configure the detached scene before any _ready callback can start the
	# worker. Exactly one chunk ring makes both the capture and its counters
	# bit-reproducible instead of racing the normal radius-3 stream.
	streamer.SEED_OVERRIDE = REVIEW_SEED
	streamer.CHUNK_RADIUS = 1
	streamer.KEEP_RADIUS = 1
	streamer.MAX_BUILD_PER_FRAME = 3
	player.position = _review_position
	(world.get_node("AtmosphereDirector") as AtmosphereDirector).quality = _quality
	_capture_view.add_child(world)
	_run.call_deferred(world, player)

func _setup_capture_view() -> void:
	# An always-updating offscreen target survives native window occlusion.
	_capture_view = SubViewport.new()
	_capture_view.size = Vector2i(get_viewport().get_visible_rect().size)
	_capture_view.own_world_3d = true
	_capture_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_capture_view)
	_last_draw_usec = Time.get_ticks_usec()
	RenderingServer.frame_post_draw.connect(_record_draw)

func _record_draw() -> void:
	_last_draw_usec = Time.get_ticks_usec()

func _process(_dt: float) -> void:
	if _capture_view != null and Time.get_ticks_usec() - _last_draw_usec > 2000000:
		_forced_draws += 1
		RenderingServer.force_draw(false)
		print("[atmosphere-review] recovered idle draw loop, count=", _forced_draws)

func _physics_process(_dt: float) -> void:
	# Let gravity find the real ground/water, but do not let river current move
	# the review into another chunk while its neighbours are still loading.
	if is_instance_valid(_review_actor):
		_review_actor.position.x = _review_position.x
		_review_actor.position.z = _review_position.z
		_review_actor.velocity.x = 0.0
		_review_actor.velocity.z = 0.0

func _read_args() -> void:
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == "--capture" and index + 1 < args.size():
			_capture_path = args[index + 1]
		elif args[index] == "--x" and index + 1 < args.size():
			_review_position.x = float(args[index + 1])
		elif args[index] == "--z" and index + 1 < args.size():
			_review_position.z = float(args[index + 1])
		elif args[index] == "--wide":
			_camera_offset = Vector3(60.0, 38.0, 74.0)
		elif args[index] == "--shore":
			_review_position = SHORE_REVIEW_POSITION
		elif args[index] == "--quality" and index + 1 < args.size():
			_quality = clampi(int(args[index + 1]), 0, 2)
		elif args[index] == "--sweep":
			_sweep = true
		elif args[index] == "--orbit":
			_orbit = true
		elif args[index] == "--snapshot" and index + 1 < args.size():
			_snapshot_path = args[index + 1]
		elif args[index] == "--freeze-time" and index + 1 < args.size():
			_freeze_time = maxf(0.0, float(args[index + 1]))
		elif args[index] == "--measure":
			_measure = true
		elif args[index] == "--live-travel-end" and index + 1 < args.size():
			var coordinates := args[index + 1].split(",")
			assert(coordinates.size() == 2, "Live travel endpoint is world x,z")
			_live_travel_end = Vector2(float(coordinates[0]), float(coordinates[1]))
		elif args[index] == "--gi" and index + 1 < args.size():
			_gi = args[index + 1]
		elif args[index] == "--no-fog":
			_disable_fog = true
		elif args[index] == "--no-glow":
			_disable_glow = true

func _run(world: Node3D, player: Node3D) -> void:
	var streamer := world.get_node("FieldTerrain") as FieldTerrainStreamer
	var started := Time.get_ticks_msec()
	while not _streaming_ready(streamer):
		if float(Time.get_ticks_msec() - started) / 1000.0 > TIMEOUT_SECONDS:
			push_error("Dressing review timed out waiting for streamed batches")
			get_tree().quit(1)
			return
		await get_tree().create_timer(0.1).timeout
	await get_tree().create_timer(8.0).timeout

	var batch_count := 0
	var instance_count := 0
	var collision_count := 0
	for chunk_node: Node3D in streamer._built.values():
		var dressing := chunk_node.get_node_or_null("Dressing") as Node3D
		if dressing != null:
			for child: Node in dressing.get_children():
				var batch := child as MultiMeshInstance3D
				if batch != null and batch.multimesh != null:
					batch_count += 1
					instance_count += batch.multimesh.instance_count
		var collision_body := chunk_node.get_node_or_null("DressingCollision") as StaticBody3D
		if collision_body != null:
			collision_count += collision_body.get_child_count()
	if batch_count == 0 or instance_count == 0:
		push_error("Streamed review produced no dressing batches")
		get_tree().quit(1)
		return
	if collision_count == 0:
		push_error("Streamed review produced no dressing collision shapes")
		get_tree().quit(1)
		return

	set_physics_process(false)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	(world.get_node("CoordOverlay") as CanvasLayer).visible = false
	(world.get_node("ReviewTeleporter") as CanvasLayer).visible = false
	var camera := world.get_node("Camera3D") as Camera3D
	camera.set_physics_process(false)
	camera.fov = 48.0 if _camera_offset.length() > 90.0 else 52.0
	var focus := player.global_position + Vector3.UP * (4.0 if _camera_offset.length() > 90.0 else 2.0)
	camera.global_position = focus + _camera_offset
	camera.look_at(focus, Vector3.UP)
	var director := world.get_node("AtmosphereDirector") as AtmosphereDirector
	# The review camera just moved away from the gameplay camera position.
	# Refresh immersion before disabling the director, including its private
	# environment override when the player stood in water during streaming.
	director._underwater.update_view()
	director.set_process(false)
	var environment := director.environment_node.environment
	if _freeze_time >= 0.0:
		RenderingServer.global_shader_parameter_set("review_visual_time", _freeze_time)
		_freeze_nodes(world, camera)
		var ripples := world.get_node_or_null("WaterRipples")
		if ripples != null:
			ripples.set_process(false)
			_freeze_viewports(ripples)
	var base_path := _capture_path.get_basename()
	if not _snapshot_path.is_empty():
		var snapshot_helper := load("res://tests/harness/september9_render_fixture.gd")
		var saved: Error = snapshot_helper.save_world(world, _snapshot_path, {"review_visual_time": _freeze_time})
		if saved != OK:
			push_error("Could not save lighting snapshot: %s" % _snapshot_path)
			get_tree().quit(1)
			return
		print("[atmosphere-review] saved snapshot: ", _snapshot_path)
	var variants := ["selected"]
	if _sweep:
		variants = ["standard", "economical", "high", "ssil", "sdfgi", "combined", "no-fog", "no-glow"]
	for variant: String in variants:
		if _sweep:
			_quality = 0 if variant == "economical" else (2 if variant == "high" else 1)
			director.set_quality(_quality)
			_gi = "ssil" if variant == "high" else variant
			_disable_fog = variant == "no-fog"
			_disable_glow = variant == "no-glow"
			_capture_path = base_path + "-" + variant + ".png"
		if _gi != "quality":
			environment.ssil_enabled = _gi == "ssil" or _gi == "combined"
			environment.sdfgi_enabled = _gi == "sdfgi" or _gi == "combined"
		environment.fog_enabled = not _disable_fog
		environment.volumetric_fog_enabled = _quality > 0 and not _disable_fog
		environment.glow_enabled = not _disable_glow
		for unused in 30:
			await RenderingServer.frame_post_draw
		if _measure:
			await _measure_render(camera, environment)
		var captured_image: Image = camera.get_viewport().get_texture().get_image()
		if captured_image == null or captured_image.save_png(_capture_path) != OK:
			push_error("Could not capture streamed dressing review: %s" % _capture_path)
			get_tree().quit(1)
			return
		print("[atmosphere-review] %d batches, %d instances, %d collision shapes -> %s" % [
			batch_count, instance_count, collision_count, _capture_path])
		_save_scene_report(camera, director._mood_weights, {
			"position": var_to_str(player.global_position), "source": "live production",
			"dressing_batches": batch_count, "dressing_instances": instance_count,
			"collision_shapes": collision_count})
		if _orbit and (not _sweep or variant == "standard" or variant == "high"):
			await _capture_orbit(camera, focus, director)
	if _live_travel_end.is_finite():
		assert(_freeze_time < 0.0, "Live travel requires unfrozen shaders and water")
		if not await _capture_live_travel(player, camera, director, streamer):
			get_tree().quit(1)
			return
	print("[atmosphere-review] grass ", streamer._grass_streamer.stats())
	RenderingServer.global_shader_parameter_set("review_visual_time", -1.0)
	get_tree().quit()

## Move the observer through the real streamed world. XZ is scripted, gravity and
## water remain live. This validates rendering/streaming, not walkability or AI.
func _capture_live_travel(player: Node3D, camera: Camera3D,
		director: AtmosphereDirector, streamer: FieldTerrainStreamer) -> bool:
	var start := Vector2(player.global_position.x, player.global_position.z)
	var seconds := maxf(1.0, start.distance_to(_live_travel_end) / 10.0)
	var count := ceili(seconds * 60.0)
	var offset := camera.global_position - player.global_position
	var records: Array[Dictionary] = []
	player.process_mode = Node.PROCESS_MODE_INHERIT
	set_physics_process(true)
	director.set_process(true)
	for frame in count + 1:
		var point := start.lerp(_live_travel_end, float(frame) / count)
		_review_position.x = point.x
		_review_position.z = point.y
		await get_tree().physics_frame
		camera.global_position = player.global_position + offset
		camera.look_at(player.global_position + Vector3.UP * 2.0)
		await RenderingServer.frame_post_draw
		if frame % 120 != 0 and frame != count:
			continue
		var path := "%s-live-%04d.png" % [_capture_path.get_basename(), frame]
		assert(camera.get_viewport().get_texture().get_image().save_png(path) == OK)
		records.append({"frame": frame, "position": var_to_str(player.global_position),
			"weights": director._mood_weights.duplicate(), "chunks": streamer._built.size(),
			"grass": streamer._grass_streamer.stats(), "image": path})
	# Let the destination's real terrain/grass queues finish, with the same bound
	# as startup, rather than declaring success on a loading-frontier screenshot.
	var began := Time.get_ticks_msec()
	while not _streaming_ready(streamer):
		if (Time.get_ticks_msec() - began) / 1000.0 > TIMEOUT_SECONDS:
			push_error("Live lighting travel timed out waiting for destination streaming")
			return false
		await get_tree().create_timer(0.1).timeout
	await get_tree().create_timer(9.0).timeout
	camera.global_position = player.global_position + offset
	camera.look_at(player.global_position + Vector3.UP * 2.0)
	await RenderingServer.frame_post_draw
	var settled := _capture_path.get_basename() + "-live-settled.png"
	assert(camera.get_viewport().get_texture().get_image().save_png(settled) == OK)
	var file := FileAccess.open(_capture_path.get_basename() + "-live.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"kind": "live scripted observer travel",
		"frames": records, "settled_image": settled,
		"settled_grass": streamer._grass_streamer.stats()}, "\t"))
	print("[atmosphere-review] live travel settled: ", settled)
	return true

func _save_scene_report(camera: Camera3D, weights: Dictionary, context: Dictionary) -> void:
	var report := {
		"seed": REVIEW_SEED, "biome_weights": weights,
		"camera_transform": var_to_str(camera.global_transform), "camera_fov": camera.fov,
		"resolution": var_to_str(camera.get_viewport().size),
		"quality": _quality, "visual_time": _freeze_time}
	report.merge(context, true)
	var file := FileAccess.open(_capture_path.get_basename() + "-scene.json", FileAccess.WRITE)
	if file == null:
		push_error("Could not write lighting scene report: " + _capture_path)
		return
	file.store_string(JSON.stringify(report, "\t"))
	print("[atmosphere-review] scene context ", JSON.stringify(report))

func _capture_orbit(camera: Camera3D, focus: Vector3, director: AtmosphereDirector) -> void:
	var original := camera.global_transform
	var offset := camera.global_position - focus
	var frames: Array[Dictionary] = []
	# Move through 90 degrees over 180 rendered frames. Sampling every 15th
	# frame retains temporal history between images instead of teleporting.
	# With --freeze-time, this isolates camera-induced trails from scene motion.
	for frame in 181:
		var angle := deg_to_rad(float(frame) * 0.5)
		camera.global_position = focus + offset.rotated(Vector3.UP, angle)
		camera.look_at(focus, Vector3.UP)
		director._underwater.update_view()
		await RenderingServer.frame_post_draw
		if frame % 15 != 0:
			continue
		var path := "%s-orbit-%03d.png" % [_capture_path.get_basename(), frame]
		var frame_image := camera.get_viewport().get_texture().get_image()
		if frame_image == null or frame_image.save_png(path) != OK:
			push_error("Could not save orbit frame: %s" % path)
			get_tree().quit(1)
			return
		frames.append({"frame": frame, "camera": var_to_str(camera.global_transform), "image": path})
	var report := FileAccess.open(_capture_path.get_basename() + "-orbit.json", FileAccess.WRITE)
	if report != null:
		report.store_string(JSON.stringify({"freeze_time": _freeze_time, "frames": frames}, "\t"))
	camera.global_transform = original
	director._underwater.update_view()
	print("[atmosphere-review] orbit saved: ", _capture_path.get_basename())

func _freeze_nodes(node: Node, camera: Camera3D) -> void:
	if node is GPUParticles3D:
		var particles := node as GPUParticles3D
		particles.use_fixed_seed = true
		particles.seed = String(particles.get_path()).hash()
		particles.preprocess = 0.0
		particles.speed_scale = 0.0
		particles.restart(true)
		particles.request_particles_process(_freeze_time)
	elif node is SpiritOrb:
		(node as SpiritOrb).elapsed = _freeze_time
		node._process(0.0)
		node.set_process(false)
	elif node.get_script() == preload("res://scripts/terrain/biome/SmallSpiritOrbs.gd"):
		node.sample(_freeze_time, node.to_local(camera.global_position))
		node.set_process(false)
	for child: Node in node.get_children():
		_freeze_nodes(child, camera)

func _freeze_viewports(node: Node) -> void:
	if node is SubViewport:
		(node as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED
	for child: Node in node.get_children():
		_freeze_viewports(child)

func _measure_render(camera: Camera3D, environment: Environment) -> void:
	var viewport := camera.get_viewport().get_viewport_rid()
	# Metal may return zero GPU timestamps. Uncapped frame intervals still
	# provide an end-to-end throughput measure, explicitly distinct from GPU time.
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(viewport, true)
	# Warm pipelines and temporal effects before collecting steady-state data.
	for frame in 120:
		await RenderingServer.frame_post_draw
	var cpu: Array[float] = []
	var gpu: Array[float] = []
	var frame_intervals: Array[float] = []
	var forced_at_start := _forced_draws
	var previous := Time.get_ticks_usec()
	for frame in 240:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		frame_intervals.append(float(now - previous) / 1000.0)
		previous = now
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport))
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport))
	cpu.sort()
	gpu.sort()
	frame_intervals.sort()
	var report := {
		"seed": REVIEW_SEED, "position": var_to_str(_review_position),
		"camera": var_to_str(camera.global_transform), "fov": camera.fov,
		"resolution": var_to_str(camera.get_viewport().get_visible_rect().size),
		"adapter": RenderingServer.get_video_adapter_name(),
		"biome_weights": Helper.biome_weights5(_review_position, REVIEW_SEED),
		"vsync_mode": DisplayServer.window_get_vsync_mode(), "max_fps": Engine.max_fps,
		"msaa": camera.get_viewport().msaa_3d, "fog_length_m": environment.volumetric_fog_length,
		"screen_space_aa": camera.get_viewport().screen_space_aa,
		"render_scale": camera.get_viewport().scaling_3d_scale,
		"upscale_mode": camera.get_viewport().scaling_3d_mode,
		"quality": _quality, "gi": _gi, "freeze_time": _freeze_time,
		"ssil": environment.ssil_enabled, "sdfgi": environment.sdfgi_enabled, "fog": environment.volumetric_fog_enabled,
		"ssao": environment.ssao_enabled,
		"glow": environment.glow_enabled, "samples": gpu.size(),
		"cpu_render_median_ms": cpu[120], "cpu_render_p95_ms": cpu[228],
		"gpu_median_ms": gpu[120], "gpu_p95_ms": gpu[228],
		"gpu_timing_available": gpu[120] > 0.0,
		"frame_median_ms": frame_intervals[120], "frame_p95_ms": frame_intervals[228],
		"forced_draws_during_measurement": _forced_draws - forced_at_start,
		"frame_timing_valid": _forced_draws == forced_at_start,
	}
	var file := FileAccess.open(_capture_path.get_basename() + ".json", FileAccess.WRITE)
	if file == null:
		push_error("Could not write atmosphere timing report")
		return
	file.store_string(JSON.stringify(report, "\t"))
	print("[atmosphere-timing] ", JSON.stringify(report))

func _streaming_ready(streamer: FieldTerrainStreamer) -> bool:
	if streamer == null or streamer.player == null:
		return false
	var centre := FieldTerrainStreamer.chunk_of(streamer.player.global_position)
	for z in range(-1, 2):
		for x in range(-1, 2):
			if not streamer._built.has(centre + Vector2i(x, z)):
				return false
	return streamer._built.size() == 9 \
		and streamer._dressing_queue != null \
		and streamer._dressing_queue.pending_count() == 0 \
		and _grass_ready(streamer)

func _grass_ready(streamer: FieldTerrainStreamer) -> bool:
	if streamer._grass_work == null or streamer._grass_streamer == null:
		return false
	var work := streamer._grass_work.stats()
	return work.queued == 0 and work.active_tile == "" and work.completed_waiting == 0 \
		and streamer._grass_streamer.pending_count() == 0
