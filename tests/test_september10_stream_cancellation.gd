extends GutTest

const Nodes = preload("res://tests/test_path_plan_nodes.gd")

func test_abandoned_context_does_not_publish_a_partial_plan() -> void:
	var fixture = Nodes.new()
	var plan: PathPlan = fixture._plan()
	var key := Vector2i.ZERO
	var result := plan.context_for(key, func() -> bool: return true)
	assert_null(result, "a cancelled caller must not complete unrelated road planning")
	assert_false(plan._contexts.has(key), "never cache cancellation as a completed context")
	assert_eq(plan.stats().node_builds, 0, "cancel before starting the next expensive operation")
	fixture.free()

func test_cancelled_road_context_does_not_evict_a_completed_cache_entry() -> void:
	var fixture = Nodes.new()
	var plan: PathPlan = fixture._plan()
	var context := FeatureContext.new(Rect2(Vector2.ZERO, Vector2.ONE * 192),
		FeatureGroundField.new([], [], 0.0), EnvironmentInstancePayload.new())
	for i in PathProgram.CONTEXT_CACHE_CAP:
		plan._contexts[Vector2i(i, 0)] = context
		plan._context_stamps[Vector2i(i, 0)] = i
	assert_null(plan.context_for(Vector2i(-10, -10), func() -> bool: return true))
	assert_eq(plan._contexts.size(), PathProgram.CONTEXT_CACHE_CAP,
		"only a completed replacement needs a cache slot")
	fixture.free()

func test_interrupted_context_resumes_from_complete_atomic_caches() -> void:
	var fixture = Nodes.new()
	var plan: PathPlan = fixture._plan()
	var checks := [0]
	var interrupted := plan.context_for(Vector2i.ZERO, func() -> bool:
		checks[0] += 1
		return checks[0] >= 4)
	assert_null(interrupted)
	assert_gt(plan.stats().node_builds, 0, "already completed node decisions remain reusable")
	assert_false(plan._contexts.has(Vector2i.ZERO))
	var resumed := plan.context_for(Vector2i.ZERO)
	var reference: PathPlan = fixture._plan()
	var expected := reference.context_for(Vector2i.ZERO)
	assert_eq(resumed.connection_masks, expected.connection_masks)
	assert_eq(resumed.node_cells, expected.node_cells)
	assert_eq(resumed.placements().batches, expected.placements().batches)
	fixture.free()

func test_teleport_releases_only_work_outside_the_complete_keep_halo() -> void:
	var stream := FieldTerrainStreamer.new()
	stream._feature_program = FeatureProgram.compile(EnvironmentCatalog.load_default())
	stream._startup_completion_emitted = true
	stream._profile_player_chunk = Vector2i(2, -11)
	stream._active_job = {"kind": &"chunk", "chunk": Vector2i(8, 0)}
	assert_true(stream._worker_should_cancel(), "reported obsolete road job must relinquish worker")
	stream._active_job.chunk = Vector2i(1, -12)
	assert_false(stream._worker_should_cancel(), "the new location still needs its feature halo")
	stream._active_job.chunk = stream._profile_player_chunk + Vector2i(stream.KEEP_RADIUS + stream._feature_program.geometry_halo, 0)
	assert_false(stream._worker_should_cancel(), "retain the complete conservative feature reach")
	stream._exit = true
	assert_true(stream._worker_should_cancel(), "shutdown also stops between atomic operations")
	stream.free()

class FixedSettlement extends SettlementPlan:
	func site_for(_key: Vector2i) -> Dictionary:
		return {"id": &"steep", "cell": Vector2i.ZERO}

class SteepPath extends PathPlan:
	func _ground(point: Vector2) -> float:
		return 100.0 if point.x > 0.0 else 0.0

func test_rejected_steep_road_site_does_not_solve_unneeded_water_domains() -> void:
	var fixture = Nodes.new()
	var source: PathPlan = fixture._plan()
	var steep := SteepPath.new(4242, source._water_plan, source._fields,
		source._program, source._program.query_margin,
		FixedSettlement.new(4242, source._water_plan))
	assert_true(steep.node_for(Vector2i.ZERO).is_empty())
	assert_eq(source._fields.water_build_count, 0,
		"support span alone rejects this site before expensive exact water construction")
	fixture.free()

func test_unsupported_roadside_prop_does_not_solve_water_before_rejection() -> void:
	var fixture = Nodes.new()
	var source: PathPlan = fixture._plan()
	var plan := SteepPath.new(4242, source._water_plan, source._fields,
		source._program, source._program.query_margin, source._settlements)
	var reservations: Array[Rect2] = []
	var occupied: Array[Rect2] = []
	var payload := EnvironmentInstancePayload.new()
	assert_false(plan._try_prop(Rect2(Vector2.ZERO, Vector2.ONE * 192),
		&"sfv.light_pole.001", Vector2i.ZERO, Vector2i.DOWN, false, "lamp",
		reservations, occupied, payload))
	assert_eq(source._fields.water_build_count, 0, "native support alone rejects the placement")
	fixture.free()

class EmptyPaths extends PathPlan:
	func context_for(chunk: Vector2i, _cancelled := Callable()) -> FeatureContext:
		return FeatureContext.new(Rect2(Vector2(chunk) * 192.0, Vector2.ONE * 192.0),
			FeatureGroundField.new([], [], 0.0), EnvironmentInstancePayload.new())

class AbsentEndpointPath extends PathPlan:
	var node_requests: Array[Vector2i] = []
	func _coarse_pairs(_query: Rect2) -> Array[Array]:
		return [[Vector2i.ZERO, Vector2i.RIGHT]]
	func node_for(key: Vector2i) -> Dictionary:
		node_requests.append(key)
		return {}

func test_absent_endpoint_does_not_materialize_its_irrelevant_partner() -> void:
	var fixture = Nodes.new()
	var source: PathPlan = fixture._plan()
	var plan := AbsentEndpointPath.new(4242, source._water_plan, source._fields,
		source._program, source._program.query_margin, source._settlements)
	var context := plan.context_for(Vector2i.ZERO)
	assert_true(context.connection_masks.is_empty())
	assert_eq(plan.node_requests, [Vector2i.ZERO], "a route cannot exist after its first endpoint is absent")
	fixture.free()

class BridgeInteriorHill extends PathPlan:
	var exact_queries := 0
	func _ground(point: Vector2) -> float:
		return 100.0 if point.x > 6.0 and point.x < 42.0 else 0.0
	func _exact_wet_intervals(_a: Vector2, _b: Vector2) -> Array[Vector2]:
		exact_queries += 1
		return []

func test_terrain_rejected_bridge_does_not_start_exact_water_queries() -> void:
	var fixture = Nodes.new()
	var source: PathPlan = fixture._plan()
	var plan := BridgeInteriorHill.new(4242, source._water_plan, source._fields,
		source._program, source._program.query_margin, source._settlements)
	assert_true(plan._profile_bridge({"a": Vector2i.ZERO, "b": Vector2i(2, 0)}).is_empty())
	assert_eq(plan.exact_queries, 0, "the existing complete terrain-span rejection precedes hydraulic work")
	fixture.free()

class EmptyFeatures extends WorldFeaturePlan:
	func _records_affecting(_core: Rect2) -> Array[VillageRecord]:
		return []

func test_full_feature_cache_evicts_one_old_context_and_preserves_recent_work() -> void:
	var fixture = Nodes.new()
	var source: PathPlan = fixture._plan()
	var program := FeatureProgram.compile(EnvironmentCatalog.load_default())
	var features := EmptyFeatures.new(4242, source._water_plan, source._fields,
		program, source._settlements)
	features._paths = EmptyPaths.new(4242, source._water_plan, source._fields,
		source._program, program.query_margin, source._settlements)
	for i in WorldFeaturePlan.CONTEXT_CACHE_CAP:
		features.context_for(Vector2i(i, 0))
	var warm := features.context_for(Vector2i.ZERO)
	features.context_for(Vector2i(1000, 0))
	assert_eq(features._contexts.size(), WorldFeaturePlan.CONTEXT_CACHE_CAP,
		"crossing capacity must not discard the whole warm world")
	assert_same(features._contexts.get(Vector2i.ZERO), warm)
	assert_false(features._contexts.has(Vector2i(1, 0)), "only the least recently used context leaves")
	fixture.free()

func test_return_teleport_during_cancellation_cannot_lose_its_request() -> void:
	var stream := FieldTerrainStreamer.new()
	stream._feature_program = FeatureProgram.compile(EnvironmentCatalog.load_default())
	stream._startup_completion_emitted = true
	var centre := Vector2i(8, 0)
	stream._profile_player_chunk = centre
	stream._requested_centre = centre
	stream._requested_startup = false
	var job := stream._new_job(centre, true, true, 0, 0)
	stream._active_job = job
	# The old callback observed a far-away player, but they returned before
	# its cancelled result reached the main thread. Active ownership already
	# suppressed their equivalent request.
	stream._publish_worker_result({}, job)
	stream._drain_results(centre)
	stream._request_neighborhood(centre, Vector2(centre) * 192.0, false)
	assert_true(stream._queued.has(centre), "the abandoned active owner must release the request")
	if stream._queued.has(centre):
		assert_true(stream._queued[centre].build_terrain)
		assert_true(stream._queued[centre].build_features)
	stream.free()

func test_feature_followup_cannot_lend_its_urgent_priority_to_distant_terrain() -> void:
	var stream := FieldTerrainStreamer.new()
	stream._feature_program = FeatureProgram.compile(EnvironmentCatalog.load_default())
	stream._startup_completion_emitted = true
	var centre := Vector2i(8, -3)
	stream._profile_player_chunk = centre
	stream._queue_lod_origin = Vector2(1618, -571)
	var distant := Vector2i(9, -2)
	var active := stream._new_job(distant, false, true, 0, 0)
	stream._active_job = active
	# Its feature dependency belongs to the current chunk, but its terrain
	# does not. Repeated feature requests had promoted this pending terrain.
	stream._followups[distant] = stream._new_job(distant, true, false, 0, 0)
	stream._request_job_locked(Vector2i(8, -4), true, false, 1, 1)
	stream._publish_worker_result({"kind": &"chunk", "chunk": distant,
		"build_features": true, "build_terrain": false,
		"feature_generation": 1, "terrain_generation": 1}, active)
	var next := stream._take_job_locked()
	assert_eq(next.chunk, Vector2i(8, -4), "ground 5 m ahead must precede terrain 217 m away")
	assert_eq(stream._queued[distant].priority_tier, 3,
		"terrain followup no longer owns the completed feature's urgent priority")
	stream.free()

func test_far_teleport_waits_for_surrounding_ground_before_releasing_player() -> void:
	var stream := FieldTerrainStreamer.new()
	stream._feature_program = FeatureProgram.compile(EnvironmentCatalog.load_default())
	stream._startup_completion_emitted = true
	stream._observe_stream_position(Vector3(475, 21, -2077))
	var destination := Vector3(1618, 12, -571)
	stream._observe_stream_position(destination)
	var centre := FieldTerrainStreamer.chunk_of(destination)
	stream._built[centre] = null
	for key: Vector2i in stream._feature_halo_keys(centre):
		stream._feature_ready[key] = 1; stream._feature_generation[key] = 1
	assert_false(stream._arrival_support_ready(), "current ground alone ends 5 m from the return location")
	assert_true(stream._arrival_support_chunks.has(Vector2i(8, -4)))
	assert_true(stream.startup_loading_complete(), "arrival does not restart or unlatch startup")
	for chunk: Vector2i in FieldTerrainStreamer.support_chunks_at(destination):
		stream._built[chunk] = null
		for key: Vector2i in stream._feature_halo_keys(chunk):
			stream._feature_ready[key] = 1; stream._feature_generation[key] = 1
	assert_true(stream._arrival_support_ready())
	assert_true(stream._arrival_support_chunks.is_empty())
	stream._built.clear(); stream.free()

func test_ordinary_chunk_crossing_does_not_start_a_teleport_gate() -> void:
	var stream := FieldTerrainStreamer.new()
	stream._observe_stream_position(Vector3(1618, 12, -575.9))
	stream._observe_stream_position(Vector3(1618, 12, -576.1))
	assert_true(stream._arrival_support_chunks.is_empty())
	assert_true(stream._arrival_support_ready())
	stream.free()
