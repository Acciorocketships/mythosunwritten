extends GutTest
const STUDY = preload("res://tests/fixtures/september19/hillside-reach-corpus/terminal_reach_study.gd")
const PREVIOUS_TEST = preload("res://tests/fixtures/september19/hillside-retained-network/test_reach_study.gd")

func test_an_existing_terminal_lake_is_not_bypassed_by_a_nearby_channel() -> void:
	var plan := WaterPlan.new(1,128,32)
	for z in range(-10,11):
		for x in range(-10,11): plan._trace_cache[Vector3i(x,z,0)] = null
	var a := RiverTrace.new()
	a.source_cell = Vector2i.ZERO
	a.priority = 100
	a.points = PackedVector2Array([Vector2.ZERO,Vector2(12,0)])
	a.beds = PackedFloat32Array([4.,4.])
	a.widths = PackedFloat32Array([1.,1.])
	a.pond = PondStamp.new(Vector2(12,0),10,1,2,3.5)
	var b := RiverTrace.new()
	b.source_cell = Vector2i(1,0)
	b.priority = 300
	b.points = PackedVector2Array([Vector2(12,0),Vector2(24,0)])
	b.beds = PackedFloat32Array([4.,4.])
	b.widths = PackedFloat32Array([1.,1.])
	for trace in [a,b]:
		plan._trace_cache[Vector3i(trace.source_cell.x,trace.source_cell.y,0)] = trace
	var route: Dictionary = STUDY.new(plan).route(a.source_cell)
	assert_true(route.jumps.is_empty(),"Already arrived at the source route's actual lake")
	assert_eq(route.terminal_owner,"(0, 0)")
	assert_eq(route.terminal_station,1)
	assert_eq(route.termination,"native_terminal")

func test_terminal_rule_preserves_newly_supplied_downstream_reaches() -> void:
	var fixture := PREVIOUS_TEST.new()
	var study := STUDY.new(fixture._plan())
	var diverted: Dictionary = study.route(Vector2i(1,0))
	var tributary: Dictionary = study.route(Vector2i(0,0))
	assert_eq(diverted.terminal_owner,"(2, 0)")
	assert_eq(tributary.jumps[0].to_station,2)
	assert_eq(tributary.terminal_owner,"(1, 0)")
	assert_eq(tributary.terminal_station,3)
	assert_eq(tributary.termination,"native_terminal")
	fixture.free()

func test_terminal_rule_preserves_equal_level_precedence_and_query_order() -> void:
	var fixture := PREVIOUS_TEST.new()
	var forward := STUDY.new(fixture._plan(true))
	var a: Dictionary = forward.route(Vector2i(0,0))
	var b: Dictionary = forward.route(Vector2i(1,0))
	var reverse := STUDY.new(fixture._plan(true))
	assert_eq(reverse.route(Vector2i(1,0)),b)
	assert_eq(reverse.route(Vector2i(0,0)),a)
	assert_true(a.jumps.is_empty())
	fixture.free()
