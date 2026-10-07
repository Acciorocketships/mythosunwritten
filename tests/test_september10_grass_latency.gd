extends GutTest

func _fixture() -> Dictionary:
	var catalog := EnvironmentCatalog.load_default()
	var cache := EnvironmentRenderCache.new(catalog)
	var program := GrassProgram.compile(load("res://terrain/grass/settings.tres"),catalog,cache)
	var region := HeightfieldPlan.new(4242,1.0,1,"mean").compute_region(4,4,12)
	var water := WaterFieldContext.new()
	water._ctx = {"ponds":[],"rivers":[],"buckets":{},"region":region}
	water._region = region
	water._coverage = Rect2(Vector2(-192,-192),Vector2(576,576))
	water._shore_limit = program.shore_distance_limit
	water._shore_curves_ready = true
	return {"program":program,"cache":cache,"sampling":GrassSamplingContext.detached(region,water)}

func test_visible_grass_finishes_while_the_terrain_planner_is_occupied() -> void:
	var f := _fixture()
	var stream := FieldTerrainStreamer.new()
	stream._grass_streamer = GrassStreamer.new(f.program,f.cache)
	stream._grass_streamer.begin_frame(Vector2(12,12))
	stream._grass_work = GrassWorkQueue.new(f.program,4242)
	stream._grass_work.update_origin(Vector2(12,12))
	var ground := Node3D.new()
	ground.set_meta(&"grass_sampling",f.sampling)
	stream._built[Vector2i.ZERO] = ground
	stream._active_job = stream._new_job(Vector2i(3,-13),false,true,3,3)
	for frame in 5: stream._queue_grass_jobs(Vector2(12,12))
	var began := Time.get_ticks_msec()
	while not stream._grass_streamer._pending_tiles.has(Vector2i.ZERO) and Time.get_ticks_msec()-began < 5000:
		await get_tree().create_timer(.01).timeout
		for result: Dictionary in stream._grass_work.drain_results():
			stream._grass_streamer.accept_result(result.tile,result.generation,result.grass,result.compute_usec)
	assert_true(stream._grass_streamer._pending_tiles.has(Vector2i.ZERO),
		"the occupied terrain planner cannot hold up a tile over committed ground")
	assert_true(stream._jobs.is_empty(),"grass never enters the terrain queue")
	assert_eq(stream._active_job.chunk,Vector2i(3,-13))
	var item: Dictionary = stream._grass_streamer._pending.filter(func(r):return r.tile==Vector2i.ZERO)[0]
	var expected := GrassField.compute(f.program,4242,Vector2i.ZERO,f.sampling.region,f.sampling.water)
	assert_eq(item.payload.batches,expected.batches,"threaded placement retains exact ordinary buffers")
	stream._grass_work.stop()
	stream._built.clear()
	ground.free()
	stream.free()

func test_teleport_cancels_queued_visual_work_and_shutdown_releases_sampling_data() -> void:
	var f := _fixture()
	var work := GrassWorkQueue.new(f.program,4242)
	var sampling: GrassSamplingContext = f.sampling
	var witness := weakref(sampling)
	work.update_origin(Vector2(12,12))
	assert_false(work.request(Vector2i(1000,1000),1,sampling),"unrequested distant tiles cannot enlarge the queue")
	for x in 4:
		assert_true(work.request(Vector2i(x,0),1,sampling))
	work.update_origin(Vector2(10000,10000))
	assert_eq(work.stats().queued,0)
	work.stop()
	f.clear()
	sampling = null
	assert_null(witness.get_ref(),"a stopped queue cannot retain private terrain or water samples")

func test_idle_worker_does_not_keep_the_last_evicted_ground_sampler() -> void:
	var f := _fixture()
	var work := GrassWorkQueue.new(f.program,4242)
	var sampling: GrassSamplingContext = f.sampling
	var witness := weakref(sampling)
	work.update_origin(Vector2(12,12))
	assert_true(work.request(Vector2i.ZERO,1,sampling))
	var began := Time.get_ticks_msec()
	while work.stats().completed_waiting == 0 and Time.get_ticks_msec()-began < 5000:
		await get_tree().create_timer(.01).timeout
	assert_eq(work.drain_results().size(),1)
	f.clear()
	sampling = null
	assert_null(witness.get_ref(),"an idle visual worker must release the detached source after publication")
	work.stop()

func test_two_tiles_compute_at_once() -> void:
	var f := _fixture()
	var work := GrassWorkQueue.new(f.program, 4242)
	work.update_origin(Vector2(12, 12))
	assert_true(work.request(Vector2i(0, 0), 1, f.sampling))
	assert_true(work.request(Vector2i(1, 0), 1, f.sampling))
	var began := Time.get_ticks_msec()
	var peak := 0
	while peak < 2 and Time.get_ticks_msec() - began < 2000:
		peak = maxi(peak, work.active_count())
		await get_tree().create_timer(0.002).timeout
	assert_eq(peak, 2, "both workers pick up a tile")
	work.stop()
