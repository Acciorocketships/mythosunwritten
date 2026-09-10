extends GutTest

class CountedPond extends PondStamp:
	var footprint_calls := 0
	func footprint_t(point: Vector2) -> float:
		footprint_calls += 1
		return super.footprint_t(point)

func test_bank_seed_queries_do_not_evaluate_distant_pond_shapes() -> void:
	var river := RiverTrace.new()
	river.source_cell=Vector2i(901,903)
	river.points=PackedVector2Array([Vector2(-36,0),Vector2(36,0)])
	river.beds=PackedFloat32Array([4,4])
	river.widths=PackedFloat32Array([20,20])
	var near_pond := CountedPond.new(Vector2(0,36),12,17,2,3)
	var far_pond := CountedPond.new(Vector2(700,700),60,31,2,3)
	var water := WaterPlan.new(123,32,8)
	var context := {"water":water,"rivers":[river],"ponds":[near_pond,far_pond]}
	var region := HeightfieldRegion.new({}, {})
	var levels := PackedFloat32Array()
	var ground := PackedFloat32Array()
	var channels := PackedFloat32Array()
	levels.resize(17*17);levels.fill(-INF)
	ground.resize(17*17);ground.fill(INF)
	channels.resize(17*17);channels.fill(-INF)
	var queue := PriorityQueue.new()
	WaterField._seed_rivers(context,region,Vector2(-48,-48),17,levels,ground,channels,queue)
	assert_eq(far_pond.footprint_calls,0,"a remote pond cannot overlap any queried bank point")
	assert_gt(near_pond.footprint_calls,0,"nearby actual pond shapes still determine ownership")
	assert_eq(channels[14*17+8],-INF,"the nearby pond owns its bank point at (0,36)")
	assert_ne(channels[2*17+8],-INF,"the opposite dry bank retains its river constraint")
	queue.free()
