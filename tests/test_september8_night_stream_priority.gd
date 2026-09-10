extends GutTest

func test_nearest_missing_bank_wins_equal_chunk_ring() -> void:
	var stream := FieldTerrainStreamer.new()
	stream._startup_completion_emitted=true
	stream._grass_runtime_enabled=true
	var origin := Vector2(1148.6,407.9)
	var centre := Vector2i(5,2)
	stream._queue_lod_origin=origin
	for chunk in [Vector2i(5,1),Vector2i(6,1),Vector2i(6,2)]:
		stream._request_job_locked(chunk,true,true,1,stream._terrain_priority_tier(chunk,centre,origin))
	stream._refresh_job_priorities_locked(centre,origin)
	assert_eq(stream._jobs[0].chunk,Vector2i(6,2),"the bank 3.4 metres away must precede terrain 23.9 metres away")
	stream.free()

func test_near_terrain_priority_does_not_depend_on_dense_grass() -> void:
	var stream := FieldTerrainStreamer.new()
	stream._grass_runtime_enabled=false
	assert_eq(stream._terrain_priority_tier(Vector2i(6,2),Vector2i(5,2),Vector2(1148.6,407.9)),1,"near ground stays ahead of visual dressing when dense grass is disabled")
	stream.free()

func test_running_toward_border_prefetches_before_sideways_neighbour() -> void:
	var stream := FieldTerrainStreamer.new()
	stream._startup_completion_emitted=true
	var origin := Vector2(1056,407.9)
	var centre := Vector2i(5,2)
	stream._queue_lod_origin=origin
	stream._queue_travel_offset=Vector2(120,0)
	for chunk in [Vector2i(5,1),Vector2i(6,1),Vector2i(6,2)]:
		stream._request_job_locked(chunk,true,true,1,stream._terrain_priority_tier(chunk,centre,origin))
	stream._refresh_job_priorities_locked(centre,origin)
	assert_eq(stream._jobs[0].chunk,Vector2i(6,2))
	stream._queue_travel_offset=Vector2.ZERO
	stream._refresh_job_priorities_locked(centre,origin)
	assert_eq(stream._jobs[0].chunk,Vector2i(5,1),"stopping removes the old travel preference")
	stream.free()

func test_activation_dependency_inherits_approaching_terrain_urgency() -> void:
	var stream := FieldTerrainStreamer.new()
	stream._startup_completion_emitted=true
	stream._feature_program=FeatureProgram.compile(EnvironmentCatalog.load_default())
	stream._profile_player_chunk=Vector2i(5,2)
	stream._queue_lod_origin=Vector2(1056,407.9)
	stream._queue_travel_offset=Vector2(120,0)
	stream._request_job_locked(Vector2i(6,2),true,false,1,1)
	stream._request_job_locked(Vector2i(6,1),true,false,1,1)
	stream._request_job_locked(Vector2i(7,2),false,true,1,1)
	assert_eq(stream._jobs[0].chunk,Vector2i(7,2),"prepare the approaching chunk's activation dependency before another terrain job can block it")
	stream.free()

func test_terrain_request_queues_complete_halo_before_worker_wake() -> void:
	var stream := FieldTerrainStreamer.new()
	stream._feature_program=FeatureProgram.compile(EnvironmentCatalog.load_default())
	var chunk := Vector2i(6,2)
	var wakes := stream._request_terrain_dependencies_locked(chunk,1,1)
	var keys := stream._feature_halo_keys(chunk)
	assert_eq(wakes,keys.size())
	assert_eq(stream._jobs.size(),keys.size())
	for key: Vector2i in keys:
		assert_true(stream._queued.has(key))
		assert_true(stream._queued[key].build_features)
		assert_eq(stream._queued[key].build_terrain,key==chunk)
	assert_eq(stream._request_terrain_dependencies_locked(chunk,1,1),0,"repeat requests preserve the one existing wake per job")
	stream.free()

func test_equal_ring_dependency_splits_off_unneeded_terrain() -> void:
	var stream := FieldTerrainStreamer.new()
	stream._startup_completion_emitted=true
	stream._feature_program=FeatureProgram.compile(EnvironmentCatalog.load_default())
	stream._profile_player_chunk=Vector2i(5,2)
	stream._queue_lod_origin=Vector2(1056,407.9)
	stream._queue_travel_offset=Vector2(120,0)
	stream._request_job_locked(Vector2i(6,2),true,false,1,1)
	stream._request_job_locked(Vector2i(6,1),true,true,1,1)
	var job := stream._take_job_locked()
	assert_eq(job.chunk,Vector2i(6,1))
	assert_true(job.build_features)
	assert_false(job.build_terrain,"nearby dependency's unrelated terrain must not block the approaching bank")
	assert_true(stream._followups.has(Vector2i(6,1)))
	stream.free()
