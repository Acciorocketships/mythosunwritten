extends GutTest

func test_repeated_pending_requests_do_not_resort_or_duplicate_work() -> void:
	var s := FieldTerrainStreamer.new()
	s.PROFILE_STREAMING = true
	s._telemetry.enabled = true
	for x in 7: s._request_job_locked(Vector2i(x, 0), true, true, x)
	var before: int = s._telemetry.snapshot().times[&"queue/sort"].count
	for frame in 60:
		for x in 7: s._request_job_locked(Vector2i(x, 0), true, true, x)
	assert_eq(s._jobs.size(), 7)
	assert_eq(s._telemetry.snapshot().times[&"queue/sort"].count, before)
	s.free()

func test_worker_handoff_still_owns_completed_components() -> void:
	var s := FieldTerrainStreamer.new()
	s._terrain_generation[Vector2i.ZERO] = 1
	s._feature_generation[Vector2i.ZERO] = 1
	s._done.append(s._new_job(Vector2i.ZERO, true, true, 0))
	assert_false(s._request_job_locked(Vector2i.ZERO, true, true, 0))
	assert_true(s._jobs.is_empty(), "a result arriving during request scheduling must not be rebuilt")
	# Stale results do not suppress a new generation.
	s._terrain_generation[Vector2i.ZERO] = 2
	assert_true(s._request_job_locked(Vector2i.ZERO, true, true, 0))
	assert_true(s._jobs[0].build_terrain)
	assert_false(s._jobs[0].build_features)
	s.free()

func test_travel_rebases_priorities_and_cancels_abandoned_chunks() -> void:
	var s := FieldTerrainStreamer.new()
	s._startup_completion_emitted = true
	s._request_job_locked(Vector2i.ZERO, true, true, 0, 0)
	s._request_job_locked(Vector2i(3, 0), true, true, 3, 3)
	s._request_job_locked(Vector2i(-4, 0), true, true, 4, 3)
	s._refresh_job_priorities_locked(Vector2i(3, 0), Vector2(600, 12))
	assert_eq(s._jobs[0].chunk, Vector2i(3, 0))
	assert_eq(s._queued[Vector2i.ZERO].priority_distance, 3)
	assert_eq(s._queued[Vector2i.ZERO].priority_tier, 3)
	assert_false(s._queued.has(Vector2i(-4, 0)))
	s.free()

func test_near_feature_dependency_does_not_wait_for_far_terrain() -> void:
	var s := FieldTerrainStreamer.new()
	s._startup_completion_emitted = true
	s._profile_player_chunk = Vector2i.ZERO
	s._request_job_locked(Vector2i(2, 0), true, true, 0, 0)
	var job := s._take_job_locked()
	assert_true(job.build_features)
	assert_false(job.build_terrain)
	assert_true(s._followups[Vector2i(2, 0)].build_terrain)
	assert_eq(s._followups[Vector2i(2, 0)].priority_distance, 2)
	s.free()

func test_widening_chunk_work_preserves_grass_with_the_same_parent() -> void:
	var s := FieldTerrainStreamer.new()
	s._request_job_locked(Vector2i.ZERO, true, false, 4, 3)
	s._request_grass_job_locked(Vector2i.ZERO, 1, 4000)
	s._request_job_locked(Vector2i.ZERO, false, true, 1, 3)
	assert_eq(s._jobs.filter(func(job): return job.kind == &"grass").size(), 1)
	assert_eq(s._jobs.filter(func(job): return job.kind == &"chunk").size(), 1)
	assert_true(s._queued[Vector2i.ZERO].build_features)
	s.free()

func test_travel_rebases_and_cancels_components_waiting_behind_active_work() -> void:
	var s := FieldTerrainStreamer.new()
	s._startup_completion_emitted = true
	var chunk := Vector2i(2,0)
	s._active_job = s._new_job(chunk, false, true, 0, 0)
	s._request_job_locked(chunk, true, false, 0, 0)
	s._refresh_job_priorities_locked(Vector2i.ZERO, Vector2.ZERO)
	assert_eq(s._followups[chunk].priority_distance, 2)
	assert_eq(s._followups[chunk].priority_tier, 3)
	s._refresh_job_priorities_locked(Vector2i(-4,0), Vector2(-768,0))
	assert_false(s._followups.has(chunk), "completion must not restore abandoned terrain work")
	s.free()
