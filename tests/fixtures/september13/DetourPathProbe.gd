extends PathPlan

# Diagnostic only: same edge qualification in a wider bidirectional domain.
func _route_record(start_cell: Vector2i, goal_cell: Vector2i, pair_key: String) -> Dictionary:
	var min_cell := Vector2i(mini(start_cell.x, goal_cell.x), mini(start_cell.y, goal_cell.y)) - Vector2i.ONE * 4
	var max_cell := Vector2i(maxi(start_cell.x, goal_cell.x), maxi(start_cell.y, goal_cell.y)) + Vector2i.ONE * 4
	var width := max_cell.x - min_cell.x + 1
	var height := max_cell.y - min_cell.y + 1
	var count := width * height
	var heights := PackedInt32Array()
	heights.resize(count)
	var rocky := PackedFloat32Array()
	rocky.resize(count)
	var cells: Array[Vector2i] = []
	cells.resize(count)
	for z in range(min_cell.y, max_cell.y + 1):
		for x in range(min_cell.x, max_cell.x + 1):
			var index := (z - min_cell.y) * width + x - min_cell.x
			var cell := Vector2i(x, z)
			var p := Vector2(cell) * TerrainSurfaceField.TILE
			cells[index] = cell
			heights[index] = int(round(_ground(p)))
			rocky[index] = Helper.biome_rocky01(Vector3(p.x, 0.0, p.y), _world_seed)
	var edges: Dictionary = {}
	for index in count:
		var cell: Vector2i = cells[index]
		var directions: Array[Vector2i] = _DIRS
		var cell_edges: Array[Dictionary] = []
		for direction: Vector2i in directions:
			var next := cell + direction
			if next.x < min_cell.x or next.y < min_cell.y or next.x > max_cell.x or next.y > max_cell.y: continue
			var segment_a := Vector2(cell) * TerrainSurfaceField.TILE
			var segment_b := Vector2(next) * TerrainSurfaceField.TILE
			var intervals := _planning_intervals_cells(cell, next)
			if intervals.is_empty():
				var region := _fields.region_at((segment_a + segment_b) * 0.5)
				if not TerrainSurfaceField.is_walkable_edge(region, cell, direction):
					continue
				var to := _local_index(next, min_cell, width)
				cell_edges.append({"to": to, "dir": _dir_index(direction),
					"variation": absi(heights[to] - heights[index]),
					"cost": absf(float(heights[to] - heights[index])) \
						+ float(rocky[to]) * PathProgram.ROUTE_ROCKY_COST,
					"bridge_key": "", "connections": [{"a": cell, "b": next}]})
				continue
			var site := _site_from_start(cell, direction)
			if site.is_empty():
				continue
			var bridge := bridge_site(site)
			if bridge.is_empty():
				continue
			var far: Vector2i = bridge.b if bridge.a == cell else bridge.a
			if far.x < min_cell.x or far.y < min_cell.y \
				or far.x > max_cell.x or far.y > max_cell.y:
				continue
			var to := _local_index(far, min_cell, width)
			var bridge_connections: Array[Dictionary] = bridge.connections.duplicate(true)
			if bridge.a != cell:
				bridge_connections.reverse()
				for connection: Dictionary in bridge_connections:
					var swap: Vector2i = connection.a
					connection.a = connection.b
					connection.b = swap
			cell_edges.append({"to": to, "dir": _dir_index(direction),
				"variation": int(bridge.variation),
				"cost": PathProgram.ROUTE_BRIDGE_COST + float(bridge.variation),
				"bridge_key": String(bridge.key),
				"connections": bridge_connections})
		if not cell_edges.is_empty():
			edges[index] = cell_edges
	var order: Array[int] = []
	for i in count:
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		var pa := _manhattan(cells[a], start_cell)
		var pb := _manhattan(cells[b], start_cell)
		return pa < pb or (pa == pb and a < b))
	return {"min_cell":min_cell,"width":width,"cells":cells,"start": _local_index(start_cell, min_cell, width),
		"goal": _local_index(goal_cell, min_cell, width), "heights": heights,
		"edges": edges, "order": order,
		"vertical_budget": PathProgram.ROUTE_VERTICAL_BUDGET_UNITS,
		"turn_cost": PathProgram.ROUTE_TURN_COST,
		"pair_hash": _hash(PathProgram.SALT_ROUTE,
			[start_cell.x, start_cell.y, goal_cell.x, goal_cell.y]),
		"pair_key": pair_key}
