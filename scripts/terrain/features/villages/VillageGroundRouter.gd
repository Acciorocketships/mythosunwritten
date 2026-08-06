class_name VillageGroundRouter
extends RefCounted

## Bounded cardinal routing for terrain streets and fixed public stairs. The
## search operates on the 1.5 m construction lattice and validates water,
## traversal, obstacle headroom, and stair decomposition before returning an
## edge to the topology solver.
const SAMPLE_STEP := VillageProgram.MODULE
const STREET_HALF_WIDTH := VillageProgram.MODULE * 0.5
const ROUTE_DETOUR := VillageProgram.ALLEY_WIDTHS[-1] * 2.0
const MAX_SEARCH_STATES := 4096
const TURN_COST := VillageProgram.MODULE * 0.4


static func best_link(terrain: VillageTerrainView, origin: Vector2,
		primary_axis: Vector2, a: VillageCirculationNode,
		b: VillageCirculationNode,
		placements: Array[VillageMassingPlacement],
		vocabulary: VillageElevatedProgram,
		reserved_volumes: Array[VillageOccupancyVolume] = []
		) -> VillageCirculationLink:
	var direct := direct_link(terrain, origin, primary_axis, a, b,
		placements, vocabulary, reserved_volumes)
	return direct if direct != null else searched_link(terrain, origin,
		primary_axis, a, b, placements, vocabulary, reserved_volumes)


static func direct_link(terrain: VillageTerrainView, origin: Vector2,
		primary_axis: Vector2, a: VillageCirculationNode,
		b: VillageCirculationNode,
		placements: Array[VillageMassingPlacement],
		vocabulary: VillageElevatedProgram,
		reserved_volumes: Array[VillageOccupancyVolume] = []
		) -> VillageCirculationLink:
	var street := _direct_street(terrain, origin, primary_axis,
		a, b, placements, reserved_volumes)
	if street != null:
		return street
	return _direct_stair(terrain, origin, primary_axis,
		a, b, placements, vocabulary, reserved_volumes)


static func searched_link(terrain: VillageTerrainView, origin: Vector2,
		primary_axis: Vector2, a: VillageCirculationNode,
		b: VillageCirculationNode,
		placements: Array[VillageMassingPlacement],
		vocabulary: VillageElevatedProgram,
		reserved_volumes: Array[VillageOccupancyVolume] = []
		) -> VillageCirculationLink:
	var controls := _search_controls(terrain, origin, primary_axis,
		a, b, placements, null, reserved_volumes)
	if not controls.is_empty():
		var street := _street_for_controls(terrain, controls,
			a, b, placements, reserved_volumes)
		if street != null:
			return street
	controls = _search_controls(terrain, origin, primary_axis,
		a, b, placements, vocabulary, reserved_volumes)
	return null if controls.is_empty() else _stair_for_controls(terrain,
		controls, a, b, placements, vocabulary, reserved_volumes)


static func _direct_street(terrain: VillageTerrainView,
		origin: Vector2, primary_axis: Vector2,
		a: VillageCirculationNode, b: VillageCirculationNode,
		placements: Array[VillageMassingPlacement],
		reserved_volumes: Array[VillageOccupancyVolume]
		) -> VillageCirculationLink:
	var valid: Array[VillageCirculationLink] = []
	for controls: Array[Vector2] in _orthogonal_controls(
			origin, primary_axis, a.point, b.point):
		var link := _street_for_controls(terrain, controls, a, b, placements,
			reserved_volumes)
		if link != null:
			valid.append(link)
	valid.sort_custom(VillageRouteGeometry.link_less)
	return null if valid.is_empty() else valid[0]


static func _street_for_controls(terrain: VillageTerrainView,
		controls: Array[Vector2], a: VillageCirculationNode,
		b: VillageCirculationNode,
		placements: Array[VillageMassingPlacement],
		reserved_volumes: Array[VillageOccupancyVolume]
		) -> VillageCirculationLink:
	var samples := _ground_samples(terrain,
		VillageRouteGeometry.sample_polyline_2d(controls, SAMPLE_STEP))
	if samples.is_empty() or VillageRouteGeometry.path_hits_solids(
			samples, placements, a.owner_key, b.owner_key, STREET_HALF_WIDTH) \
			or VillageRouteGeometry.path_hits_volumes(samples,
				reserved_volumes, STREET_HALF_WIDTH):
		return null
	var link := VillageCirculationLink.new(
		VillageRouteGeometry.edge_key(&"street", a.stable_key, b.stable_key),
		VillageCirculationLink.Kind.GROUND_STREET,
		a.stable_key, b.stable_key)
	for point: Vector2 in controls:
		link.control_points.append(VillageRouteGeometry.point3(point,
			terrain.surface_y(point)))
	link.samples = samples
	link.length = VillageRouteGeometry.polyline_length(samples)
	return link


static func _direct_stair(terrain: VillageTerrainView,
		origin: Vector2, primary_axis: Vector2,
		a: VillageCirculationNode, b: VillageCirculationNode,
		placements: Array[VillageMassingPlacement],
		vocabulary: VillageElevatedProgram,
		reserved_volumes: Array[VillageOccupancyVolume]
		) -> VillageCirculationLink:
	var valid: Array[VillageCirculationLink] = []
	for controls: Array[Vector2] in _orthogonal_controls(
			origin, primary_axis, a.point, b.point):
		var link := _stair_for_controls(terrain, controls,
			a, b, placements, vocabulary, reserved_volumes)
		if link != null:
			valid.append(link)
	valid.sort_custom(VillageRouteGeometry.link_less)
	return null if valid.is_empty() else valid[0]


static func _stair_for_controls(terrain: VillageTerrainView,
		controls: Array[Vector2], a: VillageCirculationNode,
		b: VillageCirculationNode,
		placements: Array[VillageMassingPlacement],
		vocabulary: VillageElevatedProgram,
		reserved_volumes: Array[VillageOccupancyVolume]
		) -> VillageCirculationLink:
	var samples_2d := VillageRouteGeometry.sample_polyline_2d(
		controls, SAMPLE_STEP)
	var samples: Array[Vector3] = []
	var transitions: Array[VillageStairTransition] = []
	var stair_count := 0
	for point: Vector2 in samples_2d:
		if terrain.may_be_wet(point):
			return null
		var sample := VillageRouteGeometry.point3(point,
			terrain.surface_y(point))
		if not samples.is_empty():
			var delta := sample.y - samples[-1].y
			if not TraversalEnvelope.step_is_legal(delta):
				var transition := VillageStairSolver.transition(absf(delta),
					vocabulary, VillageMassingProgram.MAX_PUBLIC_STAIR_SEGMENTS)
				if transition.is_empty():
					return null
				stair_count += int(transition.count)
				transitions.append(VillageStairTransition.new(samples.size(),
					int(transition.count), delta,
					float(transition.residual) * signf(delta)))
		samples.append(sample)
	if stair_count == 0 or stair_count \
			> VillageMassingProgram.MAX_PUBLIC_STAIR_SEGMENTS:
		return null
	var horizontal_length := VillageRouteGeometry.polyline_length_2d(samples_2d)
	if horizontal_length < float(stair_count) * vocabulary.stair_module_run \
			+ VillageProgram.MODULE * 2.0 \
			or VillageRouteGeometry.path_hits_solids(samples, placements,
				a.owner_key, b.owner_key, STREET_HALF_WIDTH) \
			or VillageRouteGeometry.path_hits_volumes(samples,
				reserved_volumes, STREET_HALF_WIDTH):
		return null
	var stair_intervals := VillageRouteGeometry.ground_stair_intervals(
		samples, transitions, vocabulary.stair_module_run)
	if stair_intervals.size() != transitions.size():
		return null
	var link := VillageCirculationLink.new(
		VillageRouteGeometry.edge_key(&"terrain_stair",
			a.stable_key, b.stable_key),
		VillageCirculationLink.Kind.GROUND_STAIR,
		a.stable_key, b.stable_key)
	for point: Vector2 in controls:
		link.control_points.append(VillageRouteGeometry.point3(point,
			terrain.surface_y(point)))
	link.samples = samples
	link.length = VillageRouteGeometry.polyline_length(samples)
	link.stair_count = stair_count
	link.stair_transitions = transitions
	link.stair_intervals = stair_intervals
	for transition: VillageStairTransition in transitions:
		if absf(transition.residual_step) > absf(link.residual_step):
			link.residual_step = transition.residual_step
	return link


static func _orthogonal_controls(origin: Vector2, axis: Vector2,
		a: Vector2, b: Vector2) -> Array[Array]:
	var local_a := _to_local(a, origin, axis)
	var local_b := _to_local(b, origin, axis)
	var middle := (local_a + local_b) * 0.5
	var local_routes: Array = [
		[local_a, Vector2(local_b.x, local_a.y), local_b],
		[local_a, Vector2(local_a.x, local_b.y), local_b],
		[local_a, Vector2(middle.x, local_a.y),
			Vector2(middle.x, local_b.y), local_b],
		[local_a, Vector2(local_a.x, middle.y),
			Vector2(local_b.x, middle.y), local_b],
	]
	var out: Array[Array] = []
	for route: Array in local_routes:
		var controls: Array[Vector2] = []
		for value: Variant in route:
			var point := _from_local(value as Vector2, origin, axis)
			if controls.is_empty() or point.distance_to(controls[-1]) > 0.01:
				controls.append(point)
		if controls.size() >= 2:
			out.append(controls)
	return out


static func _search_controls(terrain: VillageTerrainView,
		origin: Vector2, primary_axis: Vector2,
		a: VillageCirculationNode, b: VillageCirculationNode,
		placements: Array[VillageMassingPlacement],
		vocabulary: VillageElevatedProgram = null,
		reserved_volumes: Array[VillageOccupancyVolume] = []
		) -> Array[Vector2]:
	var local_a := _to_local(a.point, origin, primary_axis)
	var local_b := _to_local(b.point, origin, primary_axis)
	var minimum := Vector2(minf(local_a.x, local_b.x),
		minf(local_a.y, local_b.y)) - Vector2.ONE * ROUTE_DETOUR
	var maximum := Vector2(maxf(local_a.x, local_b.x),
		maxf(local_a.y, local_b.y)) + Vector2.ONE * ROUTE_DETOUR
	var minimum_cell := Vector2i(floori(minimum.x / VillageProgram.MODULE),
		floori(minimum.y / VillageProgram.MODULE))
	var maximum_cell := Vector2i(ceili(maximum.x / VillageProgram.MODULE),
		ceili(maximum.y / VillageProgram.MODULE))
	var start_centre := Vector2i(roundi(local_a.x / VillageProgram.MODULE),
		roundi(local_a.y / VillageProgram.MODULE))
	var goal_centre := Vector2i(roundi(local_b.x / VillageProgram.MODULE),
		roundi(local_b.y / VillageProgram.MODULE))
	var starts: Array[Vector2i] = []
	var goals: Dictionary = {}
	for z_offset in range(-2, 3):
		for x_offset in range(-2, 3):
			var start := start_centre + Vector2i(x_offset, z_offset)
			var start_world := _grid_world(start, origin, primary_axis)
			var start_samples := _search_samples(terrain,
				VillageRouteGeometry.sample_polyline_2d(
					[a.point, start_world], SAMPLE_STEP), vocabulary)
			if not start_samples.is_empty() \
					and not VillageRouteGeometry.path_hits_solids(start_samples,
						placements, a.owner_key, a.owner_key, STREET_HALF_WIDTH) \
					and not VillageRouteGeometry.path_hits_volumes(start_samples,
						reserved_volumes, STREET_HALF_WIDTH):
				starts.append(start)
			var goal := goal_centre + Vector2i(x_offset, z_offset)
			var goal_world := _grid_world(goal, origin, primary_axis)
			var goal_samples := _search_samples(terrain,
				VillageRouteGeometry.sample_polyline_2d(
					[goal_world, b.point], SAMPLE_STEP), vocabulary)
			if not goal_samples.is_empty() \
					and not VillageRouteGeometry.path_hits_solids(goal_samples,
						placements, b.owner_key, b.owner_key, STREET_HALF_WIDTH) \
					and not VillageRouteGeometry.path_hits_volumes(goal_samples,
						reserved_volumes, STREET_HALF_WIDTH):
				goals[goal] = true
	if starts.is_empty() or goals.is_empty():
		return []
	var queue := PriorityQueue.new()
	var best: Dictionary = {}
	var came_from: Dictionary = {}
	var state_cells: Dictionary = {}
	var state_directions: Dictionary = {}
	for cell: Vector2i in starts:
		var key := _search_key(cell, 4)
		var cost := a.point.distance_to(_grid_world(cell, origin, primary_axis))
		if best.has(key) and float(best[key]) <= cost:
			continue
		best[key] = cost
		came_from[key] = &""
		state_cells[key] = cell
		state_directions[key] = 4
		queue.push({"key": key, "cost": cost}, cost + _heuristic(cell, goals))
	var directions: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN,
		Vector2i.LEFT, Vector2i.UP]
	var final_key := &""
	var expanded := 0
	while not queue.is_empty() and expanded < MAX_SEARCH_STATES:
		var item: Dictionary = queue.pop()
		var key: StringName = item.key
		var cost := float(item.cost)
		if cost > float(best.get(key, INF)) + 0.0001:
			continue
		var cell: Vector2i = state_cells[key]
		var prior_direction := int(state_directions[key])
		if goals.has(cell):
			final_key = key
			break
		expanded += 1
		for direction_index in directions.size():
			var next := cell + directions[direction_index]
			if next.x < minimum_cell.x or next.x > maximum_cell.x \
					or next.y < minimum_cell.y or next.y > maximum_cell.y:
				continue
			var edge_samples := _search_samples(terrain,
				VillageRouteGeometry.sample_polyline_2d([
					_grid_world(cell, origin, primary_axis),
					_grid_world(next, origin, primary_axis)], SAMPLE_STEP),
				vocabulary)
			if edge_samples.is_empty() \
					or VillageRouteGeometry.path_hits_solids(edge_samples,
						placements, &"", &"", STREET_HALF_WIDTH) \
					or VillageRouteGeometry.path_hits_volumes(edge_samples,
						reserved_volumes, STREET_HALF_WIDTH):
				continue
			var next_cost := cost + VillageProgram.MODULE
			if prior_direction != 4 and prior_direction != direction_index:
				next_cost += TURN_COST
			var next_key := _search_key(next, direction_index)
			if next_cost >= float(best.get(next_key, INF)) - 0.0001:
				continue
			best[next_key] = next_cost
			came_from[next_key] = key
			state_cells[next_key] = next
			state_directions[next_key] = direction_index
			queue.push({"key": next_key, "cost": next_cost}, next_cost \
				+ _heuristic(next, goals))
	queue.free()
	if final_key.is_empty():
		return []
	var reversed_cells: Array[Vector2i] = []
	var cursor := final_key
	while not cursor.is_empty():
		reversed_cells.append(state_cells[cursor])
		cursor = came_from[cursor]
	reversed_cells.reverse()
	var raw: Array[Vector2] = [a.point]
	for cell: Vector2i in reversed_cells:
		raw.append(_grid_world(cell, origin, primary_axis))
	raw.append(b.point)
	return _simplify(raw)


static func _ground_samples(terrain: VillageTerrainView,
		points: Array[Vector2]) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for point: Vector2 in points:
		if terrain.may_be_wet(point):
			return []
		var sample := VillageRouteGeometry.point3(point, terrain.surface_y(point))
		if not out.is_empty() and not TraversalEnvelope.step_is_legal(
				sample.y - out[-1].y):
			return []
		out.append(sample)
	return out


static func _search_samples(terrain: VillageTerrainView,
		points: Array[Vector2],
		vocabulary: VillageElevatedProgram) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for point: Vector2 in points:
		if terrain.may_be_wet(point):
			return []
		var sample := VillageRouteGeometry.point3(point,
			terrain.surface_y(point))
		if not out.is_empty():
			var delta := sample.y - out[-1].y
			if not TraversalEnvelope.step_is_legal(delta):
				if vocabulary == null or VillageStairSolver.transition(
						absf(delta), vocabulary,
						VillageMassingProgram.MAX_PUBLIC_STAIR_SEGMENTS
						).is_empty():
					return []
		out.append(sample)
	return out


static func _simplify(points: Array[Vector2]) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for point: Vector2 in points:
		if not out.is_empty() and point.distance_to(out[-1]) <= 0.01:
			continue
		while out.size() >= 2:
			var prior := out[-1] - out[-2]
			var next := point - out[-1]
			if absf(prior.cross(next)) > 0.001 or prior.dot(next) <= 0.0:
				break
			out.pop_back()
		out.append(point)
	return out


static func _search_key(cell: Vector2i, direction: int) -> StringName:
	return StringName("%d:%d:%d" % [cell.x, cell.y, direction])


static func _heuristic(cell: Vector2i, goals: Dictionary) -> float:
	var best := INF
	for goal: Vector2i in goals:
		best = minf(best, float(absi(goal.x - cell.x) \
			+ absi(goal.y - cell.y)) * VillageProgram.MODULE)
	return best


static func _grid_world(cell: Vector2i, origin: Vector2,
		axis: Vector2) -> Vector2:
	return _from_local(Vector2(cell) * VillageProgram.MODULE, origin, axis)


static func _to_local(point: Vector2, origin: Vector2,
		axis: Vector2) -> Vector2:
	var offset := point - origin
	var side := Vector2(-axis.y, axis.x)
	return Vector2(offset.dot(axis), offset.dot(side))


static func _from_local(point: Vector2, origin: Vector2,
		axis: Vector2) -> Vector2:
	return origin + axis * point.x + Vector2(-axis.y, axis.x) * point.y
