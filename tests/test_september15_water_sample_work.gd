extends GutTest

func test_exact_samples_survive_revisits_and_fifo_eviction() -> void:
	var plan := TerrainWorldTuning.make_water(2697992464)
	var first := Vector2(-530.6,-377.2)
	var smooth := HeightfieldPlan.height01(Vector3(first.x,0,first.y),plan.world_seed,false)
	var detail := HeightfieldPlan.height01(Vector3(first.x,0,first.y),plan.world_seed,true)*plan.amplitude
	assert_eq(plan.smooth01(first),smooth)
	assert_eq(plan.noise_h(first),detail)
	for i in WaterPlan.FIELD_SAMPLE_LIMIT+3:
		var p := Vector2(float(i%257)*6.0-750.0,float(i/257)*6.0-1800.0)
		plan.smooth01(p)
		plan.noise_h(p)
	assert_eq(plan._smooth_samples.size(),WaterPlan.FIELD_SAMPLE_LIMIT)
	assert_eq(plan._detail_samples.size(),WaterPlan.FIELD_SAMPLE_LIMIT)
	assert_false(plan._smooth_samples.has(first))
	assert_false(plan._detail_samples.has(first))
	assert_eq(plan.smooth01(first),smooth)
	assert_eq(plan.noise_h(first),detail)
	for p in [Vector2.ZERO,Vector2(.00001,0),Vector2(-530.6001,-377.2),first]:
		assert_eq(plan.smooth01(p),HeightfieldPlan.height01(Vector3(p.x,0,p.y),plan.world_seed,false))
		assert_eq(plan.noise_h(p),HeightfieldPlan.height01(Vector3(p.x,0,p.y),plan.world_seed,true)*plan.amplitude)

func test_plans_do_not_share_samples_across_seeds() -> void:
	var a := TerrainWorldTuning.make_water(2697992464)
	var b := TerrainWorldTuning.make_water(31)
	var p := Vector2(-530.6,-377.2)
	a.smooth01(p)
	a.noise_h(p)
	assert_true(b._smooth_samples.is_empty())
	assert_true(b._detail_samples.is_empty())
	assert_eq(b.smooth01(p),HeightfieldPlan.height01(Vector3(p.x,0,p.y),31,false))
	assert_eq(b.noise_h(p),HeightfieldPlan.height01(Vector3(p.x,0,p.y),31,true)*b.amplitude)

func test_finished_trace_bounds_preserve_full_footprint_without_retaining_trace() -> void:
	var plan := TerrainWorldTuning.make_water(2697992464)
	var trace := RiverTrace.new()
	trace.points = PackedVector2Array([Vector2(-100,20),Vector2(50,-80)])
	trace.widths = PackedFloat32Array([120,26])
	trace.source_pool = PondStamp.new(Vector2(-100,20),26,1,4,2.5)
	trace.pond = PondStamp.new(Vector2(50,-80),140,2,3,3.5)
	var expected := trace.bounds()
	assert_eq(plan._bounds_for(trace),expected)
	assert_eq(plan._bounds_for(trace),expected)
	var reference := weakref(trace)
	trace = null
	assert_null(reference.get_ref(),"The bounds index must not keep evicted river geometry alive")
