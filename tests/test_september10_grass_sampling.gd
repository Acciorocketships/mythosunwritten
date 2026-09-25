extends GutTest

const Sampling = preload("res://scripts/terrain/grass/GrassSamplingContext.gd")

func test_detached_sampling_does_not_retain_plans_or_share_mutable_grade_caches() -> void:
	var plan := HeightfieldPlan.new(4242,1.0,1,"mean")
	var base := plan.compute_region(4,4,8)
	var grade := TerrainGradePatch.new(&"test",{Vector2i.ZERO:2.0,Vector2i(1,0):3.0},Vector2.ZERO,3.0)
	var extended := grade.with_fixed_extension({Vector2i.ZERO:2.0,Vector2i(1,0):3.0,Vector2i(2,0):3.0})
	var region := base.with_terrain_grades([extended])
	var water := WaterFieldContext.new()
	water._ctx = {"ponds":[],"rivers":[],"buckets":{},"region":base}
	water._region = base
	water._coverage = Rect2(Vector2(-48,-48),Vector2(288,288))
	water._shore_limit = 0.3
	water._shore_curves_ready = true
	var copy := Sampling.detached(region,water)
	assert_null(copy.region.plan,"a grass sampler cannot retain the canonical planning cache")
	assert_null(copy.water._region.plan)
	assert_not_same(copy.region,region)
	assert_not_same(copy.water,water)
	assert_not_same(copy.region.terrain_grades[0],extended)
	assert_not_same(copy.region.terrain_grades[0]._continuous_source,grade)
	var unchanged := true
	for z in range(-14,15):
		for x in range(-14,15):
			var p := Vector2(x,z)*0.73
			var actual := TerrainSurfaceField.surface_y(copy.region,p.x,p.y)
			unchanged = unchanged and actual == TerrainSurfaceField.surface_y(region,p.x,p.y)
	assert_true(unchanged,"private caches preserve the exact continuous ground field")
	copy.region.terrain_grades[0]._surface_cache.clear()
	assert_false(extended._surface_cache.is_empty(),"private cache mutation cannot change the canonical cache")

func test_detached_water_keeps_completed_fine_shores_without_source_or_memo_ownership() -> void:
	var region := HeightfieldRegion.new({}, {})
	var water := WaterFieldContext.new()
	water._region = region
	water._coverage = Rect2(Vector2.ZERO,Vector2.ONE*192)
	water._shore_limit = 0.3
	water._shore_curves = [{"pts":PackedVector2Array([Vector2(48,0),Vector2(48,192)]),"closed":false}]
	water._shore_curves_ready = true
	var side := WaterField.FILL_M+1
	var levels := PackedFloat32Array()
	levels.resize(side*side)
	levels.fill(-INF)
	for z in side:
		for x in side:
			if x < 9: levels[z*side+x] = 0.6+float(z)*.001
	water._ctx = {"region":region,"ponds":[RefCounted.new()],"rivers":[],"buckets":{},
		"water":RefCounted.new(),"fill_base":Vector2.ZERO,"fill":{"levels":levels}}
	var sub_side := WaterField.FILL_SUB_M+1
	var sub_levels := PackedFloat32Array()
	sub_levels.resize(sub_side*sub_side)
	sub_levels.fill(-INF)
	var sub_ground := PackedFloat32Array()
	sub_ground.resize(sub_side*sub_side)
	sub_ground.fill(INF)
	for z in range(3,25):
		sub_levels[z*sub_side+15] = 0.45
		sub_ground[z*sub_side+15] = 0.0
	water._ctx.fill["sub_levels"] = sub_levels
	water._ctx.fill["sub_ground"] = sub_ground
	var copy := Sampling.detached(region,water)
	assert_eq(copy.water.has_sources(),water.has_sources())
	assert_false(copy.water._ctx.has("water"),"canonical hydraulic planning is not retained")
	assert_false(copy.water._ctx.has("dry_ground"),"lazy terrain memo belongs to one worker only")
	var same := true
	for z in range(2,191,3):
		for x in range(42,58):
			var point := Vector2(x+.17,z+.31)
			same = same and WaterField.level_at(copy.water._ctx,point)==WaterField.level_at(water._ctx,point)
			same = same and copy.water.shore_distance_at(point)==water.shore_distance_at(point)
	assert_true(same,"wet/dry shore interpolation is bit-identical over the detached arrays")
