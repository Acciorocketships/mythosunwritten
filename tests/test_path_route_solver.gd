extends GutTest

const Solver := preload("res://scripts/terrain/features/PathRouteSolver.gd")

func _record(edges: Dictionary, heights: PackedInt32Array,
		budget := 20, turn_cost := 2.0) -> Dictionary:
	var order: Array[int] = []
	for i in heights.size():
		order.append(i)
	return {"start": 0, "goal": heights.size() - 1, "heights": heights,
		"edges": edges, "order": order, "vertical_budget": budget,
		"turn_cost": turn_cost, "pair_hash": 17}

func _edge(to: int, direction: int, variation: int, cost: float,
		bridge := "") -> Dictionary:
	return {"to": to, "dir": direction, "variation": variation, "cost": cost,
		"bridge_key": bridge, "connections": [{"a": Vector2i.ZERO, "b": Vector2i.RIGHT}]}

func test_selects_lowest_cost_monotone_path_and_charges_turns() -> void:
	# 0 -> 1 -> 3 is cheaper before its turn; 0 -> 2 -> 3 remains straight.
	var result := Solver.solve(_record({
		0: [_edge(1, 0, 0, 1.0), _edge(2, 1, 0, 2.0)],
		1: [_edge(3, 1, 0, 1.0)], 2: [_edge(3, 1, 0, 2.0)],
	}, PackedInt32Array([0, 0, 0, 0]), 20, 3.0))
	assert_almost_eq(result.cost, 4.0, 0.0001)
	assert_eq(result.edges[0].to, 2)

func test_vertical_variation_budget_is_symmetric() -> void:
	var heights := PackedInt32Array([0, 4, 0, -4, 0])
	var edges := {
		0: [_edge(1, 0, 4, 1.0), _edge(3, 1, 4, 1.0)],
		1: [_edge(2, 0, 4, 1.0)], 3: [_edge(4, 1, 4, 1.0)],
		2: [_edge(4, 0, 0, 1.0)],
	}
	assert_true(Solver.solve(_record(edges, heights, 3)).is_empty(),
		"both ascent and descent consume the same budget")
	assert_false(Solver.solve(_record(edges, heights, 8)).is_empty())

func test_bridge_macro_edge_is_reconstructed_atomically() -> void:
	var bridge := _edge(2, 0, 2, 5.0, "bridge-key")
	bridge.connections = [
		{"a": Vector2i(0, 0), "b": Vector2i(1, 0)},
		{"a": Vector2i(1, 0), "b": Vector2i(2, 0)},
	]
	var result := Solver.solve(_record({0: [bridge]},
		PackedInt32Array([0, 0, 0])))
	assert_eq(result.edges.size(), 1)
	assert_eq(result.edges[0].bridge_key, "bridge-key")
	assert_eq(result.edges[0].connections.size(), 2)

func test_one_value_variation_formula_matches_ascent_and_descent() -> void:
	for a in range(-2, 3):
		for b in range(-2, 3):
			for c in range(-2, 3):
				for d in range(-2, 3):
					var sequence := [a, b, c, d]
					var up := 0
					var down := 0
					var variation := 0
					for i in sequence.size() - 1:
						var delta: int = sequence[i + 1] - sequence[i]
						up += maxi(delta, 0)
						down += maxi(-delta, 0)
						variation += absi(delta)
					assert_eq((variation + absi(d - a)) / 2, maxi(up, down))

func test_dominance_solver_matches_exhaustive_small_dags() -> void:
	for variant in 32:
		var heights := PackedInt32Array([0, variant % 4, (variant / 2) % 5,
			(variant / 3) % 6, (variant / 5) % 4, (variant / 7) % 5])
		var edges := {
			0: [_edge(1, 0, absi(heights[1]), 1.1 + (variant % 3)),
				_edge(3, 1, absi(heights[3]), 1.7)],
			1: [_edge(2, 0, absi(heights[2] - heights[1]), 1.2),
				_edge(4, 1, absi(heights[4] - heights[1]), 2.3)],
			2: [_edge(5, 1, absi(heights[5] - heights[2]), 1.4)],
			3: [_edge(4, 0, absi(heights[4] - heights[3]), 1.6)],
			4: [_edge(5, 0, absi(heights[5] - heights[4]), 1.8)],
		}
		var record := _record(edges, heights, 12, 0.75)
		var solved := Solver.solve(record)
		var oracle := _oracle(record, 0, -1, 0, 0.0)
		assert_eq(solved.is_empty(), is_inf(oracle))
		if not solved.is_empty():
			assert_almost_eq(float(solved.cost), oracle, 0.0001)

func _oracle(record: Dictionary, cell: int, previous_direction: int,
		variation: int, cost: float) -> float:
	if cell == int(record.goal):
		return cost
	var best := INF
	for edge: Dictionary in record.edges.get(cell, []):
		var next_variation := variation + int(edge.variation)
		if next_variation + absi(int(record.heights[edge.to]) \
				- int(record.heights[record.start])) > int(record.vertical_budget) * 2:
			continue
		var next_cost := cost + float(edge.cost)
		if previous_direction >= 0 and previous_direction != int(edge.dir):
			next_cost += float(record.turn_cost)
		best = minf(best, _oracle(record, edge.to, edge.dir,
			next_variation, next_cost))
	return best
