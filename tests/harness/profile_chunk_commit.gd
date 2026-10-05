# tests/harness/profile_chunk_commit.gd
# Main-thread cost of integrating terrain chunks, measured WINDOWED so GPU
# uploads and first-use pipeline work are real. Chunks are computed on a worker
# thread without the feature (road/village) layer, which keeps the run free of
# the multi-minute cold road planning; the committed node set is otherwise the
# streamer's. Each commit is split into its steps, then the next frames after
# the chunk is attached are timed (draw-time pipeline/upload work lands there).
#
#   Godot --path . -s res://tests/harness/profile_chunk_commit.gd -- \
#     [--seed=N] [--centre=x,z] [--radius=N]
extends SceneTree

const MESHER_ROCKS := preload("res://scripts/terrain/field/CliffRockDressing.gd")
var _seed := 2697992464
var _centre := Vector2i.ZERO
var _radius := 1
var _chunks: Array[Vector2i] = []
var _skip: PackedStringArray = []
var _serial := false
var _warmup := false
var _shot := ""
var _look_from := Vector3.ZERO
var _look_at := Vector3.ZERO
var _has_look := false
var _warmup_node: Node3D
var _warmup_frames := 0
var _busy_frames: Array[float] = []
var plan: HeightfieldPlan
var water: WaterPlan
var mesher: TerrainChunkMesher
var water_builder: WaterSurfaceBuilder
var dressing_program: DressingProgram
var fields: WorldFieldBlockCache
var render_cache: EnvironmentRenderCache
var _thread: Thread
var _mutex := Mutex.new()
var _ready_items: Array[Dictionary] = []
var _worker_done := false
var _root: Node3D
var _camera: Camera3D
var _frames_after := 0
var _after_label := ""
var _after_max := 0.0
var _last_usec := 0
var _t0 := 0
var _idle_frames: Array[float] = []

func _init() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="): _seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--radius="): _radius = int(arg.trim_prefix("--radius="))
		elif arg == "--serial": _serial = true
		elif arg == "--warmup": _warmup = true
		elif arg.begins_with("--shot="): _shot = arg.trim_prefix("--shot=")
		elif arg.begins_with("--look="):
			# --look=from_x,from_y,from_z,at_x,at_y,at_z (world metres)
			var v := arg.trim_prefix("--look=").split(",")
			_look_from = Vector3(float(v[0]), float(v[1]), float(v[2]))
			_look_at = Vector3(float(v[3]), float(v[4]), float(v[5]))
			_has_look = true
		elif arg.begins_with("--skip="): _skip = arg.trim_prefix("--skip=").split(",")
		elif arg.begins_with("--chunks="):
			for pair: String in arg.trim_prefix("--chunks=").split(";"):
				var xz := pair.split(",")
				_chunks.append(Vector2i(int(xz[0]), int(xz[1])))
		elif arg.begins_with("--centre="):
			var p := arg.trim_prefix("--centre=").split(",")
			_centre = Vector2i(int(p[0]), int(p[1]))
	_t0 = Time.get_ticks_usec()
	water = TerrainWorldTuning.make_water(_seed)
	plan = TerrainWorldTuning.make_heightfield(_seed, water)
	mesher = TerrainChunkMesher.new()
	mesher.set_seed(_seed)
	water_builder = WaterSurfaceBuilder.new()
	var catalog := EnvironmentCatalog.load_default()
	render_cache = EnvironmentRenderCache.new(catalog)
	var index := load("res://terrain/dressing/index.tres") as DressingCatalogIndex
	var visuals := DressingCompiler.authored_asset_ids(index)
	render_cache.prefetch(visuals)
	preload("res://scripts/terrain/field/CliffSlopeRocks.gd").prefetch()
	render_cache.prepare(visuals)
	dressing_program = DressingCompiler.compile(index, catalog)
	fields = WorldFieldBlockCache.new(plan, water, dressing_program.query_margin,
		dressing_program.shore_distance_limit, 64)
	mesher.water_blocks = fields
	CliffDressing.prepare(render_cache)
	CliffDressing.shared_material()
	WaterSurfaceBuilder.sheet_material()
	mesher.prepare_resources()
	_root = Node3D.new()
	root.add_child(_root)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	_root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.shadow_enabled = true
	_root.add_child(sun)
	_camera = Camera3D.new()
	_camera.far = 2000.0
	_root.add_child(_camera)
	var c := Vector3(_centre.x * 192.0 + 96.0, 0.0, _centre.y * 192.0 + 96.0)
	_camera.look_at_from_position(c + Vector3(-180, 160, -180), c, Vector3.UP)
	if _has_look:
		_camera.look_at_from_position(_look_from, _look_at, Vector3.UP)
	if not Helper.is_headless():
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	if _warmup:
		# RenderWarmup: one instance of every prepared visual in front of the
		# camera for a few frames before any chunk is committed.
		_warmup_node = preload("res://scripts/terrain/environment/RenderWarmup.gd").build(
			render_cache, render_cache.prepared_ids())
		_camera.add_child(_warmup_node)
		_warmup_node.position = Vector3(0, 0, -1.0)
		_warmup_frames = 5
	print("[commitprof] ready ms=%.0f" % ((Time.get_ticks_usec() - _t0) / 1000.0))
	_thread = Thread.new()
	_thread.start(_work)
	_last_usec = Time.get_ticks_usec()

func _work() -> void:
	if _chunks.is_empty():
		for dz in range(-_radius, _radius + 1):
			for dx in range(-_radius, _radius + 1):
				_chunks.append(_centre + Vector2i(dx, dz))
	for chunk: Vector2i in _chunks:
		var t := Time.get_ticks_usec()
		var region := fields.region(chunk)
		var water_ctx := fields.water(chunk)
		var terrain := mesher.compute_chunk(chunk, region, water_ctx, null)
		var water_payload := water_builder.compute_chunk(water, chunk, region, water_ctx)
		var core := Rect2(Vector2(chunk) * 192.0, Vector2.ONE * 192.0)
		var dressing := DressingField.compute(dressing_program, _seed, core, region,
			water_ctx, null, terrain.cliff_terraces.ground_reservations)
		print("[commitprof] computed chunk=%d,%d worker_ms=%.0f" % [chunk.x, chunk.y,
			(Time.get_ticks_usec() - t) / 1000.0])
		_mutex.lock()
		_ready_items.append({"chunk": chunk, "terrain": terrain, "water": water_payload,
			"dressing": dressing})
		_mutex.unlock()
	_mutex.lock()
	_worker_done = true
	_mutex.unlock()

static func _faces(a: Variant) -> int:
	return (a as PackedVector3Array).size() / 3 if a is PackedVector3Array else 0

func _process(_delta: float) -> bool:
	var now := Time.get_ticks_usec()
	var frame_ms := (now - _last_usec) / 1000.0
	_last_usec = now
	if _warmup_frames > 0:
		print("[commitprof] warmup frame_ms=%.1f" % frame_ms)
		_warmup_frames -= 1
		if _warmup_frames == 0:
			_warmup_node.queue_free()
		return false
	if _frames_after > 0:
		_after_max = maxf(_after_max, frame_ms)
		_frames_after -= 1
		if _frames_after == 0:
			print("[commitprof]   %s next_frames_max_ms=%.1f" % [_after_label, _after_max])
		return false
	_mutex.lock()
	# --serial: commit only after the worker has finished every chunk, so the
	# frames after each attach are not shared with a busy worker thread.
	var hold := _serial and not _worker_done
	var item: Dictionary = {} if _ready_items.is_empty() or hold else _ready_items.pop_front()
	var done := _worker_done and _ready_items.is_empty()
	_mutex.unlock()
	if hold:
		_busy_frames.append(frame_ms)
	if item.is_empty():
		if done:
			# Steady state with everything attached: separates a per-attach
			# spike from the ordinary cost of drawing the chunks.
			_idle_frames.append(frame_ms)
			if _idle_frames.size() < 240:
				return false
			_thread.wait_to_finish()
			if not _shot.is_empty():
				root.get_texture().get_image().save_png(_shot)
				print("[commitprof] shot ", _shot)
			var sorted := _idle_frames.duplicate()
			sorted.sort()
			var rid := root.get_viewport_rid()
			print("[commitprof] idle frames p50_ms=%.1f p95_ms=%.1f max_ms=%.1f render_cpu_ms=%.2f render_gpu_ms=%.2f draws=%d prims=%d" % [
				sorted[sorted.size() / 2], sorted[int(sorted.size() * 0.95)], sorted.back(),
				RenderingServer.viewport_get_measured_render_time_cpu(rid),
				RenderingServer.viewport_get_measured_render_time_gpu(rid),
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
			if not _busy_frames.is_empty():
				var busy := _busy_frames.duplicate()
				busy.sort()
				print("[commitprof] frames while worker busy (nothing attaching) p50_ms=%.1f p95_ms=%.1f max_ms=%.1f n=%d" % [
					busy[busy.size() / 2], busy[int(busy.size() * 0.95)], busy.back(), busy.size()])
			print("[commitprof] DONE")
			return true
		return false
	var data: Dictionary = item.terrain
	var t := Time.get_ticks_usec()
	var steps := {}
	var surface := mesher._mesh_from_arrays(data.surface_arrays, mesher._ground_tinted_mat())
	steps["surface_mesh"] = Time.get_ticks_usec() - t; t = Time.get_ticks_usec()
	var rocks := MESHER_ROCKS.build(data.get("cliff_terraces", {}), data.world_seed)
	steps["cliff_build"] = Time.get_ticks_usec() - t; t = Time.get_ticks_usec()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(data.collision_faces)
	steps["ground_collision(%d tris)" % _faces(data.collision_faces)] = Time.get_ticks_usec() - t; t = Time.get_ticks_usec()
	var rock_faces: PackedVector3Array = (data.get("cliff_terraces", {}) as Dictionary).get("collision_faces", PackedVector3Array())
	if not rock_faces.is_empty():
		var rock_shape := ConcavePolygonShape3D.new()
		rock_shape.set_faces(rock_faces)
	steps["rock_collision(%d tris)" % (rock_faces.size() / 3)] = Time.get_ticks_usec() - t; t = Time.get_ticks_usec()
	var full := mesher.commit_chunk(data)
	steps["commit_chunk_total"] = Time.get_ticks_usec() - t; t = Time.get_ticks_usec()
	var water_node := water_builder.commit_chunk(item.water)
	if water_node != null: full.add_child(water_node)
	steps["water"] = Time.get_ticks_usec() - t; t = Time.get_ticks_usec()
	EnvironmentCollisionBuilder.commit(full, item.dressing, render_cache, &"DressingCollision")
	RockSkirt.commit(full, item.dressing.ground_skirts)
	steps["dressing_collision"] = Time.get_ticks_usec() - t; t = Time.get_ticks_usec()
	for part: String in _skip:
		match part:
			"collision": full.get_node("Body").free()
			"surface": full.get_node("Surface").free()
			"cliff": full.get_node("CliffRockFormations").free()
			"dressing_collision":
				var n := full.get_node_or_null("DressingCollision")
				if n != null: n.free()
	_root.add_child(full)
	steps["add_child"] = Time.get_ticks_usec() - t; t = Time.get_ticks_usec()
	if not _skip.has("dressing"):
		var queue := EnvironmentCommitQueue.new(render_cache, &"Dressing")
		queue.register_chunk(item.chunk, 1)
		queue.enqueue(item.chunk, 1, full, item.dressing)
		queue.drain(1000000)
	steps["dressing_visuals"] = Time.get_ticks_usec() - t
	surface = null
	rocks.free()
	var line := "[commitprof] commit chunk=%d,%d" % [item.chunk.x, item.chunk.y]
	for k: String in steps: line += " %s=%.1f" % [k, steps[k] / 1000.0]
	print(line)
	_after_label = "chunk=%d,%d" % [item.chunk.x, item.chunk.y]
	_after_max = 0.0
	_frames_after = 3
	return false
