extends GutTest

class FlatWater extends WaterPlan:
	var test_height:=16.0
	func noise_h(_p:Vector2)->float:return test_height

func _receiver()->RiverTrace:
	var receiver:=RiverTrace.new()
	receiver.points=PackedVector2Array([Vector2(200,200)])
	receiver.widths=PackedFloat32Array([6])
	receiver.beds=PackedFloat32Array([12])
	receiver.pond=PondStamp.new(Vector2.ZERO,60,4242,4,3.5)
	return receiver

func test_a_dry_flank_inside_a_lake_footprint_is_not_a_join()->void:
	var plan:=FlatWater.new(17,160,40)
	plan.test_height=80.0
	var receiver:=_receiver()
	var index:=plan._index_neighbour_rivers([receiver])
	assert_null(plan._join_target(Vector2.ZERO,90,index),"the pond does not excavate the high flank, so the river must continue")
	plan.test_height=16.0
	assert_eq(plan._join_target(Vector2.ZERO,20,index),receiver,"the submerged basin accepts the same approach")

func test_retained_land_inside_a_lake_is_not_a_receiver()->void:
	var plan:=FlatWater.new(17,160,40)
	var receiver:=_receiver()
	receiver.pond.island_radius=24
	assert_null(plan._join_target(Vector2.ZERO,20,plan._index_neighbour_rivers([receiver])),"a dry island cannot end the incoming river")

func test_a_join_hands_the_flow_to_the_receiving_water_level()->void:
	var plan:=FlatWater.new(17,160,40)
	var receiver:=_receiver()
	assert_almost_eq(plan._receiving_bed(Vector2.ZERO,40,receiver)+WaterField.SURFACE_RIDE,receiver.pond.surface_y(),0.00001,"a lake join reaches the lake's own surface")
	assert_eq(plan._receiving_bed(Vector2(200,200),40,receiver),12.0,"a channel join reaches the receiving bed")
	assert_true(is_inf(plan._receiving_bed(Vector2(200,200),8,receiver)),"a higher channel is not a receiver")

func test_added_join_descent_is_distributed_instead_of_cutting_one_deep_step()->void:
	var points:=PackedVector2Array();var beds:=PackedFloat32Array()
	for i in 12:points.append(Vector2(i*12,0));beds.append(43.5)
	var result:=WaterPlan._fit_join_beds(points,beds,27.5)
	assert_eq(result[-1],27.5)
	assert_eq(result[0],beds[0],"distant upstream bed is unchanged")
	for i in range(1,result.size()):
		assert_lte(result[i],result[i-1],"the handoff remains downhill")
		assert_lte(result[i-1]-result[i],3.00001,"the added descent cannot introduce a multi-storey terminal step")
	assert_eq(beds[-1],43.5,"junction fitting cannot mutate the raw walk")

func test_spring_outlet_bed_stays_below_its_pool_until_the_land_descends()->void:
	var trace:=RiverTrace.new()
	trace.source_pool=PondStamp.new(Vector2.ZERO,26,11,23,3.5)
	trace.beds=PackedFloat32Array([95.5,95.5,91.5,87.5,83.5])
	WaterPlan._fit_source_bed(trace)
	for i in 3:
		assert_almost_eq(trace.beds[i]+WaterField.SURFACE_RIDE,91.0,0.00001,"the outlet cannot dam its own spring")
	assert_eq(trace.beds[3],87.5,"the naturally descending reach is unchanged")
	assert_eq(trace.beds[4],83.5)
