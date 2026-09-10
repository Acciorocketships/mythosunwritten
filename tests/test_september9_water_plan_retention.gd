extends GutTest

class IndexedWater extends WaterPlan:
	var fixture:RiverTrace
	func river_for(sc:Vector2i,_depth:int=JOIN_DEPTH,_start:float=-1.0,_end:float=-1.0)->RiverTrace:
		return fixture if sc==Vector2i.ZERO else null

class CheapWater extends WaterPlan:
	var trace_calls:Dictionary={}
	func _trace(sc:Vector2i,_depth:int,_start:float=-1.0,_end:float=-1.0)->RiverTrace:
		trace_calls[sc]=int(trace_calls.get(sc,0))+1
		return null
	func _ascend(point:Vector2)->Vector2:return point
	func _has_source_uncached(sc:Vector2i)->bool:return posmod(sc.x+sc.y,2)==0

func test_regional_indexes_are_bounded_and_rebuild_identical_source_ownership()->void:
	var water:=IndexedWater.new(19,32,8)
	var trace:=RiverTrace.new()
	trace.points=PackedVector2Array([Vector2(-24,24),Vector2(24,24),Vector2(96,24)])
	trace.beds=PackedFloat32Array([4,4,4])
	trace.widths=PackedFloat32Array([20,20,20])
	water.fixture=trace
	var first:=water._region_for(Vector2i.ZERO).duplicate(true)
	assert_false(first.buckets.is_empty(),"the retained comparison contains actual indexed source samples")
	for i in 300:water._region_for(Vector2i(i+20,20))
	assert_lte(water._region_cache.size(),256,"regional carve indexes cannot grow with an endless journey")
	assert_false(water._region_cache.has(Vector2i.ZERO))
	assert_eq(water._region_for(Vector2i.ZERO),first,"evicted indexes rebuild the same sample ownership and order")

func test_source_and_trace_memos_are_bounded_without_losing_recent_entries()->void:
	var water:=CheapWater.new(20,32,8)
	var hot:=Vector2i(8299,43)
	for i in 8300:
		var cell:=Vector2i(i,43)
		water.river_for(cell,0)
		water.source_pos(cell)
		water.has_source(cell)
	assert_lte(water._trace_cache.size(),8192)
	assert_lte(water._source_pos_cache.size(),8192)
	assert_lte(water._has_source_cache.size(),8192)
	water.river_for(hot,0)
	assert_eq(water.trace_calls[hot],1,"recently computed empty traces remain cached")
	var expected:=water._jitter_pos(Vector2i(0,43))
	assert_eq(water.source_pos(Vector2i(0,43)),expected)
	assert_false(water.has_source(Vector2i(0,43)))
