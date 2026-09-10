extends GutTest

func _stream() -> FieldTerrainStreamer:
	var stream := FieldTerrainStreamer.new()
	stream._feature_program = FeatureProgram.compile(EnvironmentCatalog.load_default())
	stream._startup_completion_emitted = true
	stream._telemetry.enabled = true
	return stream

func test_stationary_frames_keep_request_ownership_without_resubmission() -> void:
	var stream := _stream()
	var centre := Vector2i(1, -7)
	var origin := Vector2(287.4, -1238.0)
	stream._request_neighborhood(centre, origin, false)
	var requests: int = stream._telemetry.snapshot().counts.chunk_requests
	var jobs := stream._jobs.duplicate(true)
	for frame in 60:
		stream._request_neighborhood(centre, origin, false)
	assert_eq(stream._jobs, jobs, "owned jobs stay queued exactly once")
	assert_eq(stream._telemetry.snapshot().counts.chunk_requests, requests,
		"unchanged desired terrain must not resubmit its complete feature halo every frame")
	stream.free()

func test_crossing_a_chunk_boundary_requests_the_new_frontier() -> void:
	var stream := _stream()
	stream._request_neighborhood(Vector2i(1, -7), Vector2(287.4, -1238), false)
	assert_false(stream._queued.has(Vector2i(1, -12)))
	stream._request_neighborhood(Vector2i(1, -8), Vector2(287.4, -1344.1), false)
	assert_true(stream._queued.has(Vector2i(1, -12)), "new frontier's outer feature halo is owned")
	assert_true(stream._queued[Vector2i(1, -11)].build_terrain)
	stream.free()

func test_startup_handoff_requests_normal_radius_without_player_motion() -> void:
	var stream := _stream()
	stream._startup_support_chunks = [Vector2i(1, -7)]
	stream._request_neighborhood(Vector2i(1, -7), Vector2(287.4, -1238), true)
	assert_eq(stream._jobs.size(), 1)
	stream._request_neighborhood(Vector2i(1, -7), Vector2(287.4, -1238), false)
	assert_true(stream._queued.has(Vector2i(1, -10)))
	assert_true(stream._queued[Vector2i(1, -10)].build_terrain)
	stream.free()
