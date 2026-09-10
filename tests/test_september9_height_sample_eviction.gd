extends GutTest

func test_one_new_cell_does_not_discard_the_whole_warm_height_field()->void:
	var plan:=HeightfieldPlan.new(2697992464)
	var hot:=Vector2i(HeightfieldPlan._SAMPLE_CACHE_MAX-10,0)
	var counts:Dictionary={"hot":0}
	plan.set_raw_height_override(func(x:int,z:int)->float:
		if Vector2i(x,z)==hot: counts.hot+=1
		return float(posmod(x+z,31)))
	for i in HeightfieldPlan._SAMPLE_CACHE_MAX: plan.raw_height(i,0)
	assert_eq(counts.hot,1)
	plan.raw_height(HeightfieldPlan._SAMPLE_CACHE_MAX,0)
	assert_eq(plan.raw_height(hot.x,hot.y),float(posmod(hot.x,31)))
	assert_eq(counts.hot,1,"inserting one new cell must retain recently warmed cells")
	assert_lte(plan._samples.size(),HeightfieldPlan._SAMPLE_CACHE_MAX)
	plan.set_raw_height_override(func(_x:int,_z:int)->float:return 7.0)
	assert_eq(plan.raw_height(hot.x,hot.y),7.0,"changing the field invalidates the cache normally")

class ExtremeCarve extends RefCounted:
	func carve_at_cell(_x:int,_z:int)->float: return 10000000000000000.0

func test_original_height_reuses_the_exact_input_before_carve_subtraction()->void:
	var calls:Dictionary={"count":0}
	var plan:=HeightfieldPlan.new(2697992464)
	plan.set_raw_height_override(func(_x:int,_z:int)->float:
		calls.count+=1
		return 1.125)
	plan.set_water_plan(ExtremeCarve.new())
	plan.raw_height(4,-3)
	assert_eq(plan.uncarved_height(4,-3),1.125,"retain the exact original, even where subtraction loses its low bits")
	assert_eq(calls.count,1,"the original terrain query reuses the prepared raw input")
	plan.set_raw_height_override(func(_x:int,_z:int)->float:return 2.25)
	assert_eq(plan.uncarved_height(4,-3),2.25,"ordinary source invalidation also refreshes the original input")

func test_uncarved_region_matches_independent_original_terrain()->void:
	var water:=TerrainWorldTuning.make_water(2697992464)
	var plan:=TerrainWorldTuning.make_heightfield(2697992464,water)
	var original:=TerrainWorldTuning.make_heightfield(2697992464,null)
	var reused:=TerrainWorldTuning.make_heightfield(2697992464,null)
	reused.set_raw_height_override(plan.uncarved_height)
	for cell:Vector2i in [Vector2i(2,-65),Vector2i(8,-76),Vector2i(-14,-20)]:
		plan.compute_region(cell.x,cell.y,5)
		var expected:=original.compute_region(cell.x,cell.y,5)
		var actual:=reused.compute_region(cell.x,cell.y,5)
		assert_eq(actual._storeys,expected._storeys,"unchanged original quantized/clamped storeys")
		assert_eq(actual._levels,expected._levels,"unchanged original terrace levels")
