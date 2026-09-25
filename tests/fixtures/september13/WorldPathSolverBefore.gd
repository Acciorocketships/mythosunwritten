extends RefCounted

## Bounded monotone-DAG dynamic program. PathPlan owns all world decisions;
## this helper knows only dense integer indices and precomputed legal edges.
static func solve(record: Dictionary) -> Dictionary:
	var start: int = record.start
	var goal: int = record.goal
	var heights: PackedInt32Array = record.heights
	var edges: Dictionary = record.edges
	var budget: int = record.vertical_budget
	var turn_cost: float = record.turn_cost
	var start_h := heights[start]
	var states: Array[Dictionary] = [{
		"cell": start, "dir": -1, "variation": 0, "cost": 0.0,
		"prev": -1, "edge": {}, "tie": 0,
	}]
	var at_cell: Dictionary = {start: [0]}
	var order: Array[int] = []
	order.assign(record.order)
	for cell: int in order:
		var incoming: Array = at_cell.get(cell, []).duplicate()
		for state_index: int in incoming:
			var state: Dictionary = states[state_index]
			for edge: Dictionary in edges.get(cell, []):
				var to: int = edge.to
				var variation := int(state.variation) + int(edge.variation)
				if (variation + absi(heights[to] - start_h)) > budget * 2:
					continue
				var cost := float(state.cost) + float(edge.cost)
				if int(state.dir) >= 0 and int(state.dir) != int(edge.dir):
					cost += turn_cost
				var candidate := {
					"cell": to, "dir": int(edge.dir), "variation": variation,
					"cost": cost, "prev": state_index, "edge": edge,
					"tie": _tie(record.pair_hash, state, edge),
				}
				if _insert_non_dominated(states, at_cell, candidate):
					pass
	var winners: Array = at_cell.get(goal, [])
	if winners.is_empty():
		return {}
	winners.sort_custom(func(a: int, b: int) -> bool:
		return _state_less(states[a], states[b]))
	var winner: int = winners[0]
	var path_edges: Array[Dictionary] = []
	while int(states[winner].prev) >= 0:
		path_edges.push_front(states[winner].edge)
		winner = int(states[winner].prev)
	return {"cost": float(states[winners[0]].cost),
		"variation": int(states[winners[0]].variation), "edges": path_edges}

static func _insert_non_dominated(states: Array[Dictionary], at_cell: Dictionary,
		candidate: Dictionary) -> bool:
	var key: int = candidate.cell
	var existing: Array = at_cell.get(key, [])
	var keep: Array[int] = []
	for index: int in existing:
		var state: Dictionary = states[index]
		if int(state.dir) == int(candidate.dir):
			if is_equal_approx(float(state.cost), float(candidate.cost)) \
				and int(state.variation) == int(candidate.variation):
				if _state_less(candidate, state):
					continue
				return false
			if float(state.cost) <= float(candidate.cost) \
				and int(state.variation) <= int(candidate.variation):
				return false
			if float(candidate.cost) <= float(state.cost) \
				and int(candidate.variation) <= int(state.variation):
				continue
		keep.append(index)
	var new_index := states.size()
	states.append(candidate)
	keep.append(new_index)
	at_cell[key] = keep
	return true

static func _state_less(a: Dictionary, b: Dictionary) -> bool:
	if not is_equal_approx(float(a.cost), float(b.cost)):
		return float(a.cost) < float(b.cost)
	if int(a.tie) != int(b.tie):
		return int(a.tie) < int(b.tie)
	if int(a.variation) != int(b.variation):
		return int(a.variation) < int(b.variation)
	return int(a.prev) < int(b.prev)

static func _tie(pair_hash: int, state: Dictionary, edge: Dictionary) -> int:
	return Helper._mix64(pair_hash ^ Helper._mix64(int(state.cell)) \
		^ Helper._mix64(int(edge.to) * 7 + int(edge.dir)))
