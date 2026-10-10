extends GutTest

func _trace(source: Vector2i, points: PackedVector2Array, bed: float, joined: bool) -> RiverTrace:
	var trace := RiverTrace.new()
	trace.source_cell = source
	trace.points = points
	trace.beds.resize(points.size()); trace.beds.fill(bed)
	trace.widths.resize(points.size()); trace.widths.fill(10.0)
	trace.joined = joined
	return trace

func test_high_priority_branch_drains_into_a_lower_terminal_channel() -> void:
	var plan := WaterPlan.new(99,480.0,120)
	var branch := _trace(Vector2i(0,0),PackedVector2Array([
		Vector2(1000,1000),Vector2(1020,1000),Vector2(1040,1000),Vector2(1060,1000)]),40,true)
	branch.priority = 100
	var root := _trace(Vector2i(1,0),PackedVector2Array([Vector2(1040,990),Vector2(1040,1010)]),8,false)
	root.priority = 1
	var joined := plan._join_terminal_receiver(branch,[root])
	assert_eq(joined.points.size(),3,"the river ends at its first physical confluence")
	assert_eq(joined.beds[-1],8.0,"the outlet hands off to the receiver's real datum")
	assert_eq(branch.beds[0],40.0,"published first-pass traces remain immutable")
	assert_eq(root.beds[0],8.0,"the terminal channel is not changed by the incoming branch")
	for i in range(1,joined.beds.size()):
		assert_lte(joined.beds[i],joined.beds[i-1])
		assert_lte(joined.beds[i-1]-joined.beds[i],5.0001,"the extra approach descends gradually")

func test_joined_receivers_and_uphill_water_are_not_terminal_handoffs() -> void:
	var plan := WaterPlan.new(99,480.0,120)
	var branch := _trace(Vector2i(0,0),PackedVector2Array([Vector2(1000,1000),Vector2(1020,1000)]),40,true)
	var receiver := _trace(Vector2i(1,0),PackedVector2Array([Vector2(1000,1000),Vector2(1000,1020)]),8,true)
	assert_true(is_same(plan._join_terminal_receiver(branch,[receiver]),branch),"branches cannot redirect to other branches and create dependency cycles")
	receiver.joined = false
	receiver.beds.fill(48.0)
	assert_true(is_same(plan._join_terminal_receiver(branch,[receiver]),branch),"water never joins uphill")

func test_terminal_roots_never_redirect_to_each_other() -> void:
	var plan := WaterPlan.new(99,480.0,120)
	var root := _trace(Vector2i.ZERO,PackedVector2Array([Vector2(1000,1000),Vector2(1020,1000)]),40,false)
	var receiver := _trace(Vector2i(1,0),PackedVector2Array([Vector2(1000,990),Vector2(1000,1010)]),8,false)
	assert_same(plan._join_terminal_receiver(root,[receiver]),root)

func test_photographed_hillside_branch_joins_the_first_lower_channel() -> void:
	var plan := TerrainWorldTuning.make_water(2697992464)
	var original := plan._priority_river_for(Vector2i(0,2),WaterPlan.JOIN_DEPTH)
	var root := plan.river_for(Vector2i(-1,0))
	var branch := plan.river_for(Vector2i(0,2))
	assert_true(original.points.size() > branch.points.size(),"the redundant uphill loop is removed")
	assert_lt(branch.points[-1].distance_to(Vector2(617,1627)),2.0,"first physical confluence, before the photographed hillside")
	assert_almost_eq(branch.beds[-1],15.5,0.001)
	assert_same(root,plan._priority_river_for(Vector2i(-1,0),WaterPlan.JOIN_DEPTH),"the receiving root remains the first-pass river")
	assert_same(branch,plan.river_for(Vector2i(0,2)),"published corrected trace is memoized")

class FlatBankPlan extends WaterPlan:
	func noise_h(_point: Vector2) -> float: return 80.0

func test_receiver_excavation_cannot_leave_a_high_branch_over_a_missing_bank() -> void:
	var plan := FlatBankPlan.new(99,480.0,120)
	var branch := _trace(Vector2i.ZERO,PackedVector2Array([Vector2(1000,1000),Vector2(1020,1000),Vector2(1040,1000)]),60,true)
	branch.beds[-1] = 8.0
	var receiver := _trace(Vector2i(1,0),PackedVector2Array([Vector2(900,1030),Vector2(1200,1030)]),8,false)
	var contained := plan._contain_terminal_banks(branch,[receiver])
	assert_lt(contained.beds[0],branch.beds[0],"lower-channel excavation is included in the bank survey")
	assert_eq(branch.beds[0],60.0,"the original shared trace is immutable")
	assert_eq(receiver.beds[0],8.0,"bank reconciliation cannot alter the receiving root")
	for bed in contained.beds: assert_gte(bed,8.0,"the branch cannot descend beneath its receiving outlet")
