extends GutTest

func _trace(drop:float)->RiverTrace:
	var trace:=RiverTrace.new()
	trace.points=PackedVector2Array([Vector2(0,0),Vector2(48,0)])
	trace.widths=PackedFloat32Array([6,6])
	trace.beds=PackedFloat32Array([12,12-drop])
	return trace

func test_a_steep_channel_cannot_claim_an_unrelated_excavation_beyond_its_banks()->void:
	var trace:=_trace(12)
	var water:=WaterPlan.new(17,160,40)
	var eligible:=PackedFloat32Array();eligible.resize(17*17);eligible.fill(20.0)
	var heads:=WaterField._carved_flow_ceilings({"water":water,"rivers":[trace]},null,Vector2(-24,-48),17,eligible)
	assert_true(is_finite(heads[8*17+8]),"the flowing core retains its projected head")
	assert_eq(heads[4*17+8],-INF,"a narrow steep reach has no broad bank excavation allowance")
	assert_eq(heads[12*17+8],-INF,"the rule applies on both sides of the channel")

func test_a_gentle_reach_keeps_its_actual_broad_bank_allowance()->void:
	var trace:=_trace(0)
	var water:=WaterPlan.new(17,160,40)
	var eligible:=PackedFloat32Array();eligible.resize(17*17);eligible.fill(20.0)
	var heads:=WaterField._carved_flow_ceilings({"water":water,"rivers":[trace]},null,Vector2(-24,-48),17,eligible)
	assert_true(is_finite(heads[4*17+8]),"a broad carved bank can carry a connected river join")
	assert_true(is_finite(heads[12*17+8]))
