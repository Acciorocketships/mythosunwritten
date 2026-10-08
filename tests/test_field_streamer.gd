extends GutTest
const Streamer := preload("res://scripts/terrain/field/FieldTerrainStreamer.gd")


static func _contains_scene_or_server_resource(value: Variant) -> bool:
	if value is Node or value is Mesh or value is Shape3D \
			or value is Material or value is MultiMesh:
		return true
	if value is Array:
		for item: Variant in value:
			if _contains_scene_or_server_resource(item):
				return true
	elif value is Dictionary:
		for item: Variant in value.values():
			if _contains_scene_or_server_resource(item):
				return true
	elif value is EnvironmentInstancePayload:
		var payload := value as EnvironmentInstancePayload
		return _contains_scene_or_server_resource(payload.batches) \
			or _contains_scene_or_server_resource(payload.collision_boxes) \
			or _contains_scene_or_server_resource(payload.surface_meshes)
	return false


func test_chunk_of_world_pos():
	# 192-unit chunks: world x in [0,192) → chunk 0; [192,384) → chunk 1; negative rounds down.
	assert_eq(Streamer.chunk_of(Vector3(10, 0, 10)), Vector2i(0, 0))
	assert_eq(Streamer.chunk_of(Vector3(200, 0, 10)), Vector2i(1, 0))
	assert_eq(Streamer.chunk_of(Vector3(-5, 0, -5)), Vector2i(-1, -1))

func test_startup_environment_resolves_visible_chunk_seams() -> void:
	assert_eq(Streamer.support_chunks_at(Vector3.ZERO), [
		Vector2i(-1,-1),Vector2i(-1,0),Vector2i(-1,1),
		Vector2i(0,-1),Vector2i.ZERO,Vector2i(0,1),
		Vector2i(1,-1),Vector2i(1,0),Vector2i(1,1),
	])
	assert_eq(Streamer.support_chunks_at(Streamer.DEFAULT_SPAWN_POSITION),
		Streamer.support_chunks_at(Vector3.ZERO),
		"the production camera cannot reveal an unbuilt origin quadrant")
	assert_eq(Streamer.support_chunks_at(Vector3(96.0, 0.0, 96.0)).size(),9,
		"even a centred spawn needs the surrounding travel buffer")

func test_startup_progress_counts_only_integrated_support_chunks() -> void:
	var s := Streamer.new()
	s._startup_support_chunks = Streamer.support_chunks_at(Vector3.ZERO)
	assert_eq(s.startup_loading_progress(), 0.0)
	assert_false(s.startup_loading_complete())
	for index in s._startup_support_chunks.size()-1:
		s._built[s._startup_support_chunks[index]] = true
	assert_almost_eq(s.startup_loading_progress(), 8.0/9.0,0.000001)
	assert_false(s.startup_loading_complete())
	s._built[s._startup_support_chunks[-1]] = true
	assert_eq(s.startup_loading_progress(), 1.0)
	assert_true(s.startup_loading_complete())
	s.free()

func test_startup_completion_stays_latched_after_support_chunk_eviction() -> void:
	var s := Streamer.new()
	s._startup_support_chunks = Streamer.support_chunks_at(Vector3.ZERO)
	for chunk: Vector2i in s._startup_support_chunks:
		s._built[chunk] = true
	s._emit_startup_loading_progress()
	assert_true(s._startup_completion_emitted)
	for chunk: Vector2i in s._startup_support_chunks:
		s._built.erase(chunk)
	assert_true(s.startup_loading_complete(),
		"evicting old spawn chunks must not reactivate the startup gate")
	assert_eq(s.startup_loading_progress(), 1.0,
		"completed startup progress must never regress after eviction")
	s.free()

func test_shared_cold_plan_progress_is_not_diluted_across_feature_blocks() -> void:
	var s := Streamer.new()
	s._startup_support_chunks = Streamer.support_chunks_at(Vector3.ZERO)
	# Any non-empty production feature set selects the explicit phase weights.
	s._startup_feature_keys = [Vector2i.ZERO]
	s._on_cold_planning_progress(0.5)
	assert_almost_eq(s.startup_loading_progress(),
		0.5 * Streamer.STARTUP_COLD_PLAN_WEIGHT, 0.0001,
		"the one shared network build owns its measured global startup share")
	s._on_cold_planning_progress(0.25)
	assert_almost_eq(s.startup_loading_progress(),
		0.5 * Streamer.STARTUP_COLD_PLAN_WEIGHT, 0.0001,
		"worker callbacks cannot make loading progress run backwards")
	s.free()

func test_desired_chunks_within_radius():
	var s := Streamer.new()
	var want := s.desired_chunks(Vector2i(0, 0), 1)
	assert_eq(want.size(), 9, "3x3 block for radius 1")
	assert_true(Vector2i(0, 0) in want)
	assert_true(Vector2i(1, 1) in want)
	s.free()

func test_background_builds_populate_radius():
	var s := Streamer.new()
	s.CHUNK_RADIUS = 1
	s.KEEP_RADIUS = 2
	# Hold integration until the test has inspected the worker hand-off.
	s.MAX_BUILD_PER_FRAME = 0
	s.SEED_OVERRIDE = 4242
	var parent := Node3D.new()
	var player := Node3D.new()
	add_child_autofree(parent)
	add_child_autofree(player)
	s.terrain_parent = parent
	s.player = player
	# Deferred free (like the real game frees the streamer) so _exit_tree joins
	# the worker thread before the node is deleted; a synchronous free() can't
	# succeed while the worker is parked in a live call frame on the node.
	add_child_autoqfree(s)
	s.set_process(false)
	# The spawn chunk is no longer built synchronously (a cold build blocked
	# the first frame for ~10s — the owner's grey startup screen). Instead the
	# player is HELD until the worker delivers their chunk.
	assert_eq(player.process_mode, Node.PROCESS_MODE_DISABLED,
		"player held from _ready until the spawn chunk lands")
	s._mutex.lock()
	assert_true(s._request_job_locked(Vector2i.ZERO, true, true, 0))
	s._mutex.unlock()
	s._sem.post()
	# A chunk job publishes TWO results: the feature placements the moment they
	# are planned, and (PARALLEL_TAILS) the terrain tail later, from the pool.
	var payload_deadline := Time.get_ticks_msec() + 180_000
	var first_payload: Dictionary = {}
	var feature_payload: Dictionary = {}
	while (first_payload.is_empty() or feature_payload.is_empty()) \
			and Time.get_ticks_msec() < payload_deadline:
		s._mutex.lock()
		for r: Dictionary in s._done:
			if r.get("kind", &"") != &"chunk":
				continue
			if r.has("terrain") and first_payload.is_empty():
				first_payload = r
			if r.has("features") and feature_payload.is_empty():
				feature_payload = r
		s._mutex.unlock()
		if first_payload.is_empty() or feature_payload.is_empty():
			await wait_seconds(0.25)
	assert_false(first_payload.is_empty(), "worker produced a terrain chunk payload")
	assert_true(feature_payload.get("features") is EnvironmentInstancePayload,
		"the terrain request carries its feature block in its own worker result")
	if not first_payload.is_empty():
		assert_true(first_payload.terrain is Dictionary,
			"terrain crosses the worker boundary as CPU-side data, never a Node")
		assert_true(first_payload.water is Dictionary,
			"water crosses the worker boundary as CPU-side data, never a Node")
		assert_true(first_payload.dressing is EnvironmentInstancePayload,
			"dressing crosses the worker boundary as a typed CPU payload")
		assert_true(first_payload.storeys is PackedInt32Array)
		assert_eq(first_payload.storeys.size(), TerrainChunkMesher.POINTS_PER_CHUNK ** 2,
			"one storey per lattice point the chunk owns (16 k .. 16 k + 15)")
		assert_true(first_payload.points is PackedFloat32Array)
		assert_eq(first_payload.points.size(), TerrainChunkMesher.POINTS_PER_CHUNK ** 2 * 2,
			"(height, graded) per owned lattice point")
		assert_false(_contains_scene_or_server_resource(first_payload.terrain),
			"terrain worker payload has no scene/render/physics resources")
		assert_false(_contains_scene_or_server_resource(first_payload.water),
			"water worker payload has no scene/render/physics resources")
		assert_false(_contains_scene_or_server_resource(first_payload.dressing),
			"dressing worker payload has IDs, transforms and colours only")
	if not feature_payload.is_empty():
		assert_false(_contains_scene_or_server_resource(feature_payload.features),
			"feature worker payload has IDs, transforms and colours only")
	s.MAX_BUILD_PER_FRAME = 4
	s.set_process(true)
	# the whole 3x3 radius arrives from the background thread
	var deadline := Time.get_ticks_msec() + 60_000
	while s._built.size() < 9 and Time.get_ticks_msec() < deadline:
		await wait_seconds(0.25)
	assert_eq(s._built.size(), 9, "radius-1 ring built in the background")
	for c in s._built:
		assert_true(is_instance_valid(s._built[c]), "chunk node alive: %s" % str(c))
	assert_eq(player.process_mode, Node.PROCESS_MODE_INHERIT,
		"player released once their chunk landed")

func test_feature_halo_is_one_sorted_nine_key_square() -> void:
	var s := Streamer.new()
	s._feature_program = FeatureProgram.compile(EnvironmentCatalog.load_default())
	var keys := s._feature_halo_keys(Vector2i(-2, 3))
	assert_eq(keys.size(), 9)
	assert_eq(keys[0], Vector2i(-3, 2))
	assert_eq(keys[-1], Vector2i(-1, 4))
	var unique: Dictionary = {}
	for key: Vector2i in keys:
		unique[key] = true
	assert_eq(unique.size(), 9)
	s.free()

func test_queued_feature_request_widens_existing_terrain_job() -> void:
	var s := Streamer.new()
	s._feature_program = FeatureProgram.compile(EnvironmentCatalog.load_default())
	assert_true(s._request_job_locked(Vector2i.ZERO, true, false, 2))
	assert_false(s._request_job_locked(Vector2i.ZERO, false, true, 1))
	assert_eq(s._jobs.size(), 1)
	assert_true(s._jobs[0].build_terrain)
	assert_true(s._jobs[0].build_features)
	assert_eq(s._jobs[0].priority_distance, 1)
	s.free()

func test_worker_priorities_protect_current_and_upcoming_ground() -> void:
	var s := Streamer.new()
	assert_true(s._request_job_locked(Vector2i(8, 8), true, true, 1, 3))
	assert_true(s._request_job_locked(Vector2i(1, 0), true, true, 1, 1))
	assert_true(s._request_job_locked(Vector2i.ZERO, true, true, 0, 0))
	assert_eq(s._jobs.map(func(job: Dictionary) -> int:
		return int(job.priority_tier)), [0, 1, 3])
	s.free()

func test_grass_requests_wait_for_their_committed_parent_terrain() -> void:
	var cache := EnvironmentRenderCache.new(EnvironmentCatalog.load_default())
	var s := Streamer.new()
	s._grass_streamer = GrassStreamer.new(GrassProgram.new(),cache)
	s._grass_streamer.begin_frame(Vector2(96,96))
	s._queue_grass_jobs(Vector2(96,96))
	assert_true(s._grass_streamer._requested.is_empty(),"missing ground cannot submit visual sampling work")
	s.free()

func test_collidable_dressing_becomes_shape_accurate_static_trample_stamps() -> void:
	var s := Streamer.new()
	s._dressing_program = DressingProgram.new()
	s._dressing_program.ground_stencil_by_asset[&"test.rock"] = PackedVector2Array([
		Vector2(-1.0, -0.5), Vector2(1.0, -0.5),
		Vector2(1.0, 0.5), Vector2(-1.0, 0.5),
	])
	var payload := EnvironmentInstancePayload.new()
	payload.add(&"test.rock", Transform3D(Basis.IDENTITY.scaled(Vector3(2.0, 1.0, 0.5)),
		Vector3(7.0, 2.0, -9.0)), Color.WHITE)
	payload.add(&"test.flower", Transform3D.IDENTITY, Color.WHITE)
	var stamps := s._dressing_trample_stamps(payload)
	assert_eq(stamps.size(), 1, "only collidable ground footprints suppress grass")
	assert_eq(stamps[0].position, Vector3(7.0, 2.0, -9.0))
	assert_eq(stamps[0].points, PackedVector2Array([
		Vector2(5.0, -9.25), Vector2(9.0, -9.25),
		Vector2(9.0, -8.75), Vector2(5.0, -8.75),
	]))
	assert_almost_eq(stamps[0].radius, Vector2(2.0, 0.25).length(), 0.001)
	s.free()

func test_static_dressing_publishes_a_persistent_layer_separate_from_footsteps() -> void:
	var s := Streamer.new()
	s._trample_field = TrampleField.new()
	s._trample_field._initialize(Vector2.ZERO)
	s._dressing_trample_by_chunk[Vector2i.ZERO] = [{
		"position": Vector3.ZERO,
		"points": PackedVector2Array([
			Vector2(-1.0, -1.0), Vector2(1.0, -1.0),
			Vector2(1.0, 1.0), Vector2(-1.0, 1.0),
		]),
		"radius": sqrt(2.0),
	}]
	s._static_trample_dirty = true
	s._refresh_static_dressing()
	assert_gt(s._trample_field.static_strength(Vector2.ZERO), 0.99)
	assert_eq(s._trample_field.effective_strength(Vector2.ZERO), 0.0,
		"structural crushing must not rewrite the recovering player image")
	s._trample_field.free()
	s.free()

func test_empty_feature_result_becomes_ready_without_scene_resources() -> void:
	var s := Streamer.new()
	s._feature_program = FeatureProgram.compile(EnvironmentCatalog.load_default())
	s._feature_generation[Vector2i.ZERO] = 1
	s._commit_feature_result({"chunk": Vector2i.ZERO, "feature_generation": 1,
		"features": EnvironmentInstancePayload.new()}, Vector2i.ZERO)
	assert_eq(s._feature_ready[Vector2i.ZERO], 1)
	assert_false(s._feature_nodes.has(Vector2i.ZERO))
	s.free()

func test_loaded_storeys_use_committed_snapshots_across_signed_chunk_edges() -> void:
	var s := Streamer.new()
	var side := TerrainChunkMesher.POINTS_PER_CHUNK
	for chunk: Vector2i in [Vector2i(-1, -1), Vector2i.ZERO, Vector2i(1, 1)]:
		var values := PackedInt32Array()
		values.resize(side * side)
		var points := PackedFloat32Array()
		points.resize(side * side * 2)
		for z in side:
			for x in side:
				values[z * side + x] = (chunk.x + 2) * 1000 + (chunk.y + 2) * 100 \
					+ z * side + x
				points[(z * side + x) * 2] = float(values[z * side + x]) * 0.5
				points[(z * side + x) * 2 + 1] = float((x + z) % 2)
		s._storey_snapshots[chunk] = values
		s._point_snapshots[chunk] = points
	# Chunk k owns lattice points 16 k .. 16 k + 15 (12 m apart).
	assert_eq(s.loaded_storey_at(Vector2i(-16, -16)), 1100)
	assert_eq(s.loaded_storey_at(Vector2i(-1, -1)), 1355)
	assert_eq(s.loaded_storey_at(Vector2i.ZERO), 2200)
	assert_eq(s.loaded_storey_at(Vector2i(15, 15)), 2455)
	assert_eq(s.loaded_storey_at(Vector2i(16, 16)), 3300)
	assert_null(s.loaded_storey_at(Vector2i(32, 0)))
	assert_eq(s.loaded_point_at(Vector2i(-1, -1)), Vector2(677.5, 0.0))
	assert_eq(s.loaded_point_at(Vector2i(15, 14)), Vector2(1219.5, 1.0))
	assert_eq(s.loaded_point_at(Vector2i(16, 16)), Vector2(1650.0, 0.0))
	assert_null(s.loaded_point_at(Vector2i(0, -17)))
	s.free()

func test_coord_overlay_never_reads_worker_owned_plan() -> void:
	var source := FileAccess.get_file_as_string(
		"res://scripts/terrain/tools/CoordOverlay.gd")
	assert_false(source.contains("_plan"))
	assert_true(source.contains("loaded_storey_at"))

func test_coord_overlay_reads_the_tile_under_the_crosshair() -> void:
	var s := Streamer.new()
	var side := TerrainChunkMesher.POINTS_PER_CHUNK
	var storeys := PackedInt32Array()
	storeys.resize(side * side)
	var points := PackedFloat32Array()
	points.resize(side * side * 2)
	# Chunk (-1, 0): point (-2, 3) storey 2 level 0, (-1, 3) storey 2 level 1,
	# (-2, 4) storey 3 level 0, (-1, 4) storey 5 level 2; everything else flat 0.
	for entry: Array in [[Vector2i(-2, 3), 2, 0], [Vector2i(-1, 3), 2, 1],
			[Vector2i(-2, 4), 3, 0], [Vector2i(-1, 4), 5, 2]]:
		var local: Vector2i = entry[0] - Vector2i(-1, 0) * side
		storeys[local.y * side + local.x] = entry[1]
		points[(local.y * side + local.x) * 2] = float(entry[1] * 4 + entry[2])
	s._storey_snapshots[Vector2i(-1, 0)] = storeys
	s._point_snapshots[Vector2i(-1, 0)] = points
	var overlay := preload("res://scripts/terrain/tools/CoordOverlay.gd")
	# World (-20.5, 40.0) lies in tile floor(v / 12) = (-2, 3).
	var lines: Array[String] = overlay.tile_lines(s, Vector2(-20.5, 40.0))
	assert_eq(lines[0], "tile (-2, 3)  corners storey/level (+z down):")
	assert_eq(lines[1], "   a s2/l0  b s2/l1")
	assert_eq(lines[2], "   d s3/l0  c s5/l2")
	assert_eq(lines[3], "  edges: -z a-b level   +x b-c cliff   +z d-c cliff   -x a-d slope")
	# A tile whose +x corners are in an unloaded chunk reports them missing.
	var edge: Array[String] = overlay.tile_lines(s, Vector2(-1.0, 40.0))
	assert_eq(edge[1], "   a s2/l1  b --/-")
	assert_eq(edge[3], "  edges: (corners not loaded)")
	s.free()
