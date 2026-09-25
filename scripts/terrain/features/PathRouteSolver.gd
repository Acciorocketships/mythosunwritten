extends RefCounted

## Bounded nonnegative-cost graph search. PathPlan owns all world decisions;
## this helper knows only dense indices, lower bounds, and legal edge records.
## An optional provider computes a cell once when it reaches the frontier.
static func solve(record: Dictionary) -> Dictionary:
	var start: int = record.start
	var goal: int = record.goal
	var heights: PackedInt32Array = record.heights
	var edges: Dictionary = record.edges
	var budget: int = record.vertical_budget
	var turn_cost: float = record.turn_cost
	var start_h := heights[start]
	var estimate: PackedFloat64Array = record.get("estimate", PackedFloat64Array())
	var provider: Callable = record.get("edge_provider", Callable())
	var states: Array[Dictionary] = [{
		"cell": start, "dir": -1, "variation": 0, "cost": 0.0,
		"prev": -1, "edge": {}, "tie": 0,
		"priority": estimate[start] if not estimate.is_empty() else 0.0,
	}]
	var at_cell: Dictionary = {start: [0]}
	var pending: Array[int] = [0]
	var settled: Dictionary = {}
	while not pending.is_empty():
		var state_index := _pop(pending, states)
		var state: Dictionary = states[state_index]
		var cell: int = state.cell
		if not at_cell.get(cell, []).has(state_index):
			continue
		var label := Vector3i(cell, int(state.dir), int(state.variation))
		if settled.has(label):
			continue
		settled[label] = true
		if cell == goal:
			break
		if not edges.has(cell) and provider.is_valid():
			edges[cell] = provider.call(cell)
		for edge: Dictionary in edges.get(cell, []):
			var to: int = edge.to
			var variation := int(state.variation) + int(edge.variation)
			if (variation + absi(heights[to] - start_h)) > budget * 2:
				continue
			if settled.has(Vector3i(to, int(edge.dir), variation)):
				continue
			var cost := float(state.cost) + float(edge.cost)
			if int(state.dir) >= 0 and int(state.dir) != int(edge.dir):
				cost += turn_cost
			var candidate := {
				"cell": to, "dir": int(edge.dir), "variation": variation,
				"cost": cost, "prev": state_index, "edge": edge,
				"tie": _tie(record.pair_hash, state, edge),
				"priority": cost + (estimate[to] if not estimate.is_empty() else 0.0),
			}
			if _insert_non_dominated(states, at_cell, candidate):
				_push(pending, states.size() - 1, states)
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
			if float(state.cost) == float(candidate.cost) \
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
	if float(a.cost) != float(b.cost):
		return float(a.cost) < float(b.cost)
	if int(a.tie) != int(b.tie):
		return int(a.tie) < int(b.tie)
	if int(a.variation) != int(b.variation):
		return int(a.variation) < int(b.variation)
	return int(a.prev) < int(b.prev)

static func _tie(pair_hash: int, state: Dictionary, edge: Dictionary) -> int:
	return Helper._mix64(pair_hash ^ Helper._mix64(int(state.cell)) \
		^ Helper._mix64(int(edge.to) * 7 + int(edge.dir)))

static func _push(heap: Array[int], value: int, states: Array[Dictionary]) -> void:
	heap.append(value)
	var child := heap.size() - 1
	while child > 0:
		var parent := (child - 1) / 2
		if not _queue_less(states[value], states[heap[parent]]): break
		heap[child] = heap[parent]
		child = parent
	heap[child] = value

static func _pop(heap: Array[int], states: Array[Dictionary]) -> int:
	var result := heap[0]
	var last: int = heap.pop_back()
	if heap.is_empty(): return result
	var parent := 0
	while parent * 2 + 1 < heap.size():
		var child := parent * 2 + 1
		if child + 1 < heap.size() and _queue_less(states[heap[child + 1]], states[heap[child]]):
			child += 1
		if not _queue_less(states[heap[child]], states[last]): break
		heap[parent] = heap[child]
		parent = child
	heap[parent] = last
	return result

static func _queue_less(a: Dictionary, b: Dictionary) -> bool:
	if float(a.priority) != float(b.priority):
		return float(a.priority) < float(b.priority)
	return _state_less(a, b)
