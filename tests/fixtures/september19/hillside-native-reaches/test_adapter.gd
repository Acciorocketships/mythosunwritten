extends GutTest
const PLAN = preload("res://tests/fixtures/september19/hillside-native-reaches/reach_plan.gd")

func _plan():
	var plan = PLAN.new(1,128,32)
	for z in range(-10,11):
		for x in range(-10,11): plan._trace_cache[Vector3i(x,z,0)] = null
	for cell: Vector2i in [Vector2i.ZERO,Vector2i(1,0)]:
		var trace := RiverTrace.new()
		trace.source_cell = cell
		trace.priority = 100 if cell == Vector2i.ZERO else 20
		trace.points = PackedVector2Array([Vector2(450,300),Vector2(500,300),Vector2(530,300)]) if cell == Vector2i.ZERO else PackedVector2Array([Vector2(510,300),Vector2(620,300),Vector2(740,300),Vector2(860,300),Vector2(920,300)])
		for point in trace.points:
			trace.beds.append(12.0 if cell == Vector2i.ZERO else 4.0)
			trace.widths.append(15.0)
		trace.source_pool = PondStamp.new(trace.points[0],10,1,4,2.5)
		trace.pond = PondStamp.new(trace.points[-1],10,2,2,3.5)
		plan._trace_cache[Vector3i(cell.x,cell.y,0)] = trace
		plan._has_source_cache[cell] = true
	return plan

func test_composed_trace_keeps_source_pool_and_actual_receiving_terminal() -> void:
	var plan = _plan()
	var original: RiverTrace = plan.river_for(Vector2i.ZERO,0)
	var receiver: RiverTrace = plan.river_for(Vector2i(1,0),0)
	var composed: RiverTrace = plan.river_for(Vector2i.ZERO,2)
	assert_same(composed.source_pool,original.source_pool)
	assert_same(composed.pond,receiver.pond)
	assert_eq(composed.points.size(),7)
	assert_eq(composed.points[-1],receiver.points[-1])
	assert_eq(composed.widths.size(),composed.points.size())
	assert_eq(composed.beds.size(),composed.points.size())
	assert_true(plan.rejected_routes.is_empty())
	plan._study = null

func test_region_discovery_keeps_a_borrowed_reach_outside_source_raw_bounds() -> void:
	var plan = _plan()
	var original: RiverTrace = plan.river_for(Vector2i.ZERO,0)
	var region_rect := Rect2(Vector2(768,0),Vector2(768,768)).grow(WaterPlan.BANK_FEATHER+WaterPlan.W_MAX)
	assert_false(original.bounds().grow(WaterPlan.BANK_FEATHER).intersects(region_rect),"Old raw-prefix filter excludes this source")
	var record: Dictionary = plan._region_for(Vector2i(1,0))
	var found := false
	for trace: RiverTrace in record.rivers:
		if trace.source_cell == Vector2i.ZERO: found=true
	assert_true(found,"Source's supplied receiving reach crosses the owner boundary")
	assert_true(record.buckets.has(Vector2i(38,12)))
	assert_true(plan.rejected_routes.is_empty())
	plan._study = null

func test_adjacent_region_query_order_keeps_identical_composed_paths() -> void:
	var forward = _plan()
	var a: Dictionary = _paths(forward._region_for(Vector2i.ZERO))
	var b: Dictionary = _paths(forward._region_for(Vector2i(1,0)))
	var reverse = _plan()
	assert_eq(_paths(reverse._region_for(Vector2i(1,0))),b)
	assert_eq(_paths(reverse._region_for(Vector2i.ZERO)),a)
	assert_eq(a[Vector2i.ZERO],b[Vector2i.ZERO])
	forward._study = null
	reverse._study = null

func _paths(region: Dictionary) -> Dictionary:
	var paths: Dictionary = {}
	for trace: RiverTrace in region.rivers:
		paths[trace.source_cell] = [trace.points,trace.beds,trace.widths]
	return paths
