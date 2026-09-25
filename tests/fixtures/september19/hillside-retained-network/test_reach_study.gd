extends GutTest
## These test a detached routing experiment, not production water acceptance.
const STUDY = preload("res://tests/fixtures/september19/hillside-retained-network/reach_study.gd")

func _plan(flat := false) -> WaterPlan:
	var plan := WaterPlan.new(1, 128, 32)
	for z in range(-10, 11):
		for x in range(-10, 11): plan._trace_cache[Vector3i(x,z,0)] = null
	var a := _trace(Vector2i(0,0), 100, [Vector2(0,0),Vector2(12,0),Vector2(24,0),Vector2(36,0)], [12.,12.,12.,12.])
	var b := _trace(Vector2i(1,0), 20, [Vector2(12,24),Vector2(12,12),Vector2(12,0),Vector2(12,-12)], [8.,8.,4.,4.])
	var c := _trace(Vector2i(2,0), 300, [Vector2(12,24),Vector2(24,24)], [0.,0.])
	for t: RiverTrace in [a,b,c]:
		if flat: t.beds.fill(4.0)
		plan._trace_cache[Vector3i(t.source_cell.x,t.source_cell.y,0)] = t
	return plan

func _trace(cell: Vector2i, priority: int, points: Array, beds: Array) -> RiverTrace:
	var trace := RiverTrace.new()
	trace.source_cell = cell
	trace.priority = priority
	for i in points.size():
		trace.points.append(points[i])
		trace.beds.append(beds[i])
		trace.widths.append(1.0)
	return trace

func test_new_tributary_supplies_a_tail_after_its_original_source_diverted() -> void:
	var study := STUDY.new(_plan())
	var b: Dictionary = study.route(Vector2i(1,0))
	var a: Dictionary = study.route(Vector2i(0,0))
	assert_eq(b.jumps[0].from_station, 0, "B's own source immediately joins C")
	assert_eq(b.terminal_owner, "(2, 0)")
	assert_eq(a.jumps[0].from_station, 1)
	assert_eq(a.jumps[0].to_owner, "(1, 0)", "A must still reach B's lower channel")
	assert_eq(a.jumps[0].to_station, 2)
	assert_eq(a.terminal_owner, "(1, 0)")
	assert_eq(a.terminal_station, 3, "The supplied downstream tail remains present")
	assert_eq(a.termination, "native_terminal")
	for i in range(1,a.nodes.size()):
		assert_lte(float(a.nodes[i].bed),float(a.nodes[i-1].bed))

func test_equal_level_contacts_have_stable_precedence_and_query_order() -> void:
	var forward := STUDY.new(_plan(true))
	var a: Dictionary = forward.route(Vector2i(0,0))
	var b: Dictionary = forward.route(Vector2i(1,0))
	var reverse := STUDY.new(_plan(true))
	assert_eq(reverse.route(Vector2i(1,0)), b)
	assert_eq(reverse.route(Vector2i(0,0)), a)
	assert_true(a.jumps.is_empty(), "Lower priority B cannot reverse a level contact")
	assert_eq(a.termination,"native_terminal")
	assert_eq(b.termination,"native_terminal")
