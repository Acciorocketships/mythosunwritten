extends GutTest

func _stream() -> FieldTerrainStreamer:
	var stream := FieldTerrainStreamer.new()
	stream._startup_completion_emitted = true
	stream._profile_player_chunk = Vector2i(-3,-7)
	stream._queue_lod_origin = Vector2(-530.6,-1260)
	stream._queue_travel_offset = Vector2(0,-300)
	stream._active_job = stream._new_job(Vector2i(-5,-9),false,true,2,3)
	stream._request_job_locked(Vector2i(-3,-8),true,true,1,1)
	return stream

func test_background_job_yields_to_newly_urgent_ground_at_a_safe_boundary() -> void:
	var stream := _stream()
	assert_true(stream._worker_should_cancel(),"The photographed route must not wait for a distant 84-second job")
	stream.free()

func test_equal_priority_work_does_not_requeue_itself() -> void:
	var stream := _stream()
	stream._active_job = stream._new_job(Vector2i(-3,-7),true,true,0,0)
	assert_false(stream._worker_should_cancel())
	stream.free()

func test_current_ground_feature_dependency_keeps_its_inherited_priority() -> void:
	var stream := _stream()
	stream._feature_program = FeatureProgram.compile(EnvironmentCatalog.load_default())
	stream._active_job = stream._new_job(Vector2i(-4,-8),false,true,3,3)
	stream._terrain_feature_parents[Vector2i(-3,-7)] = true
	assert_false(stream._worker_should_cancel(),"An off-axis feature needed by current terrain is still urgent")
	stream.free()

func test_yield_merges_followup_without_publishing_a_partial_payload() -> void:
	var stream := _stream()
	var chunk := Vector2i(-5,-9)
	stream._request_job_locked(chunk,true,false,2,3)
	assert_true(stream._worker_should_cancel())
	stream._publish_worker_result({},stream._active_job.duplicate())
	assert_true(stream._done.is_empty(),"Yield is scheduling, not a failed terrain payload")
	assert_eq(stream._jobs.size(),2)
	assert_eq(stream._jobs[0].chunk,Vector2i(-3,-8))
	assert_true(stream._queued[chunk].build_terrain)
	assert_true(stream._queued[chunk].build_features)
	assert_eq(stream._queued[chunk].terrain_generation,1)
	assert_eq(stream._queued[chunk].feature_generation,1)
	stream.free()

func test_startup_keeps_its_complete_dependency_order() -> void:
	var stream := _stream()
	stream._startup_completion_emitted = false
	assert_false(stream._worker_should_cancel())
	stream.free()

func test_obsolete_job_cancellation_does_not_resume_a_previous_yield() -> void:
	var stream := _stream()
	assert_true(stream._worker_should_cancel())
	stream._profile_player_chunk = Vector2i(100, 100)
	assert_true(stream._worker_should_cancel())
	assert_false(stream._active_job_yield_requested)
	stream.free()

func test_sideways_dependency_yields_before_upcoming_ground_becomes_current() -> void:
	var stream := _stream()
	stream._feature_program = FeatureProgram.compile(EnvironmentCatalog.load_default())
	stream._profile_player_chunk = Vector2i(-3, -8)
	stream._queue_lod_origin = Vector2(-530.6, -1500)
	stream._terrain_feature_parents[Vector2i(-4, -8)] = true
	stream._jobs.clear()
	stream._queued.clear()
	stream._request_job_locked(Vector2i(-3, -9), true, false, 1, 1)
	stream._refresh_job_priorities_locked(stream._profile_player_chunk, stream._queue_lod_origin)
	assert_true(stream._worker_should_cancel(), "A lateral neighbor must not hold the worker until the next crossing is already missing")
	stream.free()
