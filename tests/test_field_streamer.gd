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
		return _contains_scene_or_server_resource((value as EnvironmentInstancePayload).batches)
	return false


func test_chunk_of_world_pos():
	# 192-unit chunks: world x in [0,192) → chunk 0; [192,384) → chunk 1; negative rounds down.
	assert_eq(Streamer.chunk_of(Vector3(10, 0, 10)), Vector2i(0, 0))
	assert_eq(Streamer.chunk_of(Vector3(200, 0, 10)), Vector2i(1, 0))
	assert_eq(Streamer.chunk_of(Vector3(-5, 0, -5)), Vector2i(-1, -1))

func test_spawn_corner_resolves_to_four_support_quadrants() -> void:
	assert_eq(Streamer.support_chunks_at(Vector3.ZERO), [
		Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i.ZERO,
	])
	assert_eq(Streamer.support_chunks_at(Vector3(96.0, 0.0, 96.0)), [Vector2i.ZERO],
		"a player away from seams needs only the chunk beneath their footprint")

func test_startup_progress_counts_only_integrated_support_chunks() -> void:
	var s := Streamer.new()
	s._startup_support_chunks = Streamer.support_chunks_at(Vector3.ZERO)
	assert_eq(s.startup_loading_progress(), 0.0)
	assert_false(s.startup_loading_complete())
	for index in 3:
		s._built[s._startup_support_chunks[index]] = true
	assert_eq(s.startup_loading_progress(), 0.75)
	assert_false(s.startup_loading_complete())
	s._built[s._startup_support_chunks[3]] = true
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
	var payload_deadline := Time.get_ticks_msec() + 60_000
	var has_payload := false
	while not has_payload and Time.get_ticks_msec() < payload_deadline:
		s._mutex.lock()
		has_payload = not s._done.is_empty()
		s._mutex.unlock()
		if has_payload:
			break
		await wait_seconds(0.25)
	s._mutex.lock()
	var first_payload: Dictionary = s._done[0] if not s._done.is_empty() else {}
	s._mutex.unlock()
	assert_false(first_payload.is_empty(), "worker produced a chunk payload")
	if not first_payload.is_empty():
		assert_true(first_payload.terrain is Dictionary,
			"terrain crosses the worker boundary as CPU-side data, never a Node")
		assert_true(first_payload.water is Dictionary,
			"water crosses the worker boundary as CPU-side data, never a Node")
		assert_true(first_payload.dressing is EnvironmentInstancePayload,
			"dressing crosses the worker boundary as a typed CPU payload")
		assert_true(first_payload.features is EnvironmentInstancePayload,
			"the terrain request carries its feature block in the same worker job")
		assert_true(first_payload.storeys is PackedInt32Array)
		assert_eq(first_payload.storeys.size(), TerrainChunkMesher.CELLS_PER_CHUNK ** 2)
		assert_false(_contains_scene_or_server_resource(first_payload.terrain),
			"terrain worker payload has no scene/render/physics resources")
		assert_false(_contains_scene_or_server_resource(first_payload.water),
			"water worker payload has no scene/render/physics resources")
		assert_false(_contains_scene_or_server_resource(first_payload.dressing),
			"dressing worker payload has IDs, transforms and colours only")
		assert_false(_contains_scene_or_server_resource(first_payload.features),
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
	s._path_program = PathProgram.compile(EnvironmentCatalog.load_default())
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
	s._path_program = PathProgram.compile(EnvironmentCatalog.load_default())
	assert_true(s._request_job_locked(Vector2i.ZERO, true, false, 2))
	assert_false(s._request_job_locked(Vector2i.ZERO, false, true, 1))
	assert_eq(s._jobs.size(), 1)
	assert_true(s._jobs[0].build_terrain)
	assert_true(s._jobs[0].build_features)
	assert_eq(s._jobs[0].priority_distance, 1)
	s.free()

func test_empty_feature_result_becomes_ready_without_scene_resources() -> void:
	var s := Streamer.new()
	s._path_program = PathProgram.compile(EnvironmentCatalog.load_default())
	s._feature_generation[Vector2i.ZERO] = 1
	s._commit_feature_result({"chunk": Vector2i.ZERO, "feature_generation": 1,
		"features": EnvironmentInstancePayload.new()}, Vector2i.ZERO)
	assert_eq(s._feature_ready[Vector2i.ZERO], 1)
	assert_false(s._feature_nodes.has(Vector2i.ZERO))
	s.free()

func test_loaded_storeys_use_committed_snapshots_across_signed_chunk_edges() -> void:
	var s := Streamer.new()
	var side := TerrainChunkMesher.CELLS_PER_CHUNK
	for chunk: Vector2i in [Vector2i(-1, -1), Vector2i.ZERO, Vector2i(1, 1)]:
		var values := PackedInt32Array()
		values.resize(side * side)
		for z in side:
			for x in side:
				values[z * side + x] = (chunk.x + 2) * 1000 + (chunk.y + 2) * 100 \
					+ z * side + x
		s._storey_snapshots[chunk] = values
	assert_eq(s.loaded_storey_at(Vector2i(-8, -8)), 1100)
	assert_eq(s.loaded_storey_at(Vector2i(-1, -1)), 1163)
	assert_eq(s.loaded_storey_at(Vector2i.ZERO), 2200)
	assert_eq(s.loaded_storey_at(Vector2i(7, 7)), 2263)
	assert_eq(s.loaded_storey_at(Vector2i(8, 8)), 3300)
	assert_null(s.loaded_storey_at(Vector2i(16, 0)))
	s.free()

func test_coord_overlay_never_reads_worker_owned_plan() -> void:
	var source := FileAccess.get_file_as_string(
		"res://scripts/terrain/tools/CoordOverlay.gd")
	assert_false(source.contains("_plan"))
	assert_true(source.contains("loaded_storey_at"))
