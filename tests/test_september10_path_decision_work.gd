extends GutTest
const Nodes = preload("res://tests/test_path_plan_nodes.gd")
const Exhaustive = preload("res://tests/fixtures/September10ExhaustivePathContext.gd")

class SelectedLoop extends PathPlan:
	var route_requests := 0
	var projected: Array[String] = []
	func _coarse_pairs(_query: Rect2) -> Array[Array]:
		return [[Vector2i.ZERO, Vector2i.RIGHT]]
	func node_for(key: Vector2i) -> Dictionary:
		return {"id": str(key), "cell": key * PathProgram.SUPER_CELLS}
	func _hash(_salt: int, _values: Array) -> int:
		return 0
	func route_for(a: Dictionary, b: Dictionary) -> Dictionary:
		route_requests += 1
		return {"key": _pair_key(a, b), "node_a": a, "node_b": b, "cost": 1.0,
			"pair_hash": 0, "connections": [{"a":a.cell,"b":a.cell+(Vector2i(b.cell)-Vector2i(a.cell)).sign()},
				{"a":b.cell,"b":b.cell+(Vector2i(a.cell)-Vector2i(b.cell)).sign()}], "bridges": []}
	func _project_context(core: Rect2, routes: Array[Dictionary]) -> FeatureContext:
		for route: Dictionary in routes: projected.append(route.key)
		return FeatureContext.new(core.grow(_context_margin), FeatureGroundField.new([], [], 0.0),
			EnvironmentInstancePayload.new())

func test_selected_loop_does_not_solve_unrelated_incident_roads() -> void:
	var fixture = Nodes.new()
	var source: PathPlan = fixture._plan()
	var plan := SelectedLoop.new(4242, source._water_plan, source._fields,
		source._program, source._program.query_margin, source._settlements)
	plan.context_for(Vector2i.ZERO)
	assert_eq(plan.projected.size(), 1, "the selected route remains present")
	assert_eq(plan.route_requests, 1, "loop ownership already proves acceptance")
	fixture.free()

func test_selected_loops_supply_the_settlement_mask_without_remote_rankings() -> void:
	var fixture = Nodes.new()
	var source: PathPlan = fixture._plan()
	var plan := SelectedLoop.new(4242, source._water_plan, source._fields,
		source._program, source._program.query_margin, source._settlements)
	assert_eq(plan.accepted_mask_for_node(Vector2i.ZERO), 15)
	assert_eq(plan.route_requests, 4, "the four selected incident loops already determine every mask bit")
	fixture.free()

func test_contexts_match_frozen_exhaustive_route_decisions() -> void:
	var fixture = Nodes.new()
	for seed_value in [4242, 7319, 9320]:
		var source: PathPlan = fixture._plan(seed_value)
		var frozen := Exhaustive.new(seed_value, source._water_plan, source._fields,
			source._program, source._program.query_margin, source._settlements)
		for key: Vector2i in [Vector2i.ZERO, Vector2i(2, 0), Vector2i(-2, -1), Vector2i(0, 2)]:
			print("ROAD_COMPARE_BEGIN seed=",seed_value," key=",key)
			var expected := frozen.context_for(key)
			print("ROAD_COMPARE_ORACLE_DONE seed=",seed_value," key=",key)
			var actual := source.context_for(key)
			print("ROAD_COMPARE_CURRENT_DONE seed=",seed_value," key=",key)
			assert_eq(actual.connection_masks, expected.connection_masks)
			assert_eq(actual.node_cells, expected.node_cells)
			assert_eq(actual.bridge_cells, expected.bridge_cells)
			assert_eq(actual.placements().batches, expected.placements().batches)
		for key: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.LEFT, Vector2i(0, 2)]:
			print("ROAD_MASK_BEGIN seed=",seed_value," key=",key)
			var actual_mask := source.accepted_mask_for_node(key)
			print("ROAD_MASK_CURRENT_DONE seed=",seed_value," key=",key)
			var expected_mask := frozen.accepted_mask_for_node(key)
			print("ROAD_MASK_ORACLE_DONE seed=",seed_value," key=",key)
			assert_eq(actual_mask, expected_mask)
	fixture.free()
