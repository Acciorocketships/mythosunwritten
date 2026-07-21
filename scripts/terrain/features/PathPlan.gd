class_name PathPlan
extends RefCounted

const PATH_SEED_VERSION := 1
const _SOLVER := preload("res://scripts/terrain/features/PathRouteSolver.gd")
const _NO_NODE := &"__path_node_absent__"
const _DIRS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
const _BITS := {Vector2i.RIGHT: 1, Vector2i.LEFT: 2, Vector2i.DOWN: 4, Vector2i.UP: 8}

var _world_seed: int
var _water_plan: WaterPlan
var _fields: WorldFieldBlockCache
var _program: PathProgram
var _settlements: SettlementPlan
var _context_margin: float

var _nodes: Dictionary = {}
var _node_stamps: Dictionary = {}
var _routes: Dictionary = {}
var _route_stamps: Dictionary = {}
var _bridge_raw_cache: Dictionary = {}
var _bridge_raw_stamps: Dictionary = {}
var _bridge_resolved_cache: Dictionary = {}
var _bridge_resolved_stamps: Dictionary = {}
var _contexts: Dictionary = {}
var _context_stamps: Dictionary = {}
var _planning_points: Dictionary = {}
var _planning_point_stamps: Dictionary = {}
var _site_defs: Dictionary = {}
var _clock := 0
var _progress_callback := Callable()
var _planning_progress_callback := Callable()
var _active_progress_chunk := Vector2i.ZERO
var _active_progress_valid := false
var _water_progress_start := 0.0
var _water_progress_end := 0.0
var _stats := {
	"node_queries": 0, "node_builds": 0, "route_queries": 0,
	"route_solves": 0, "route_exact_failures": 0,
	"bridge_profiles": 0, "context_builds": 0, "evictions": 0,
}

func _init(world_seed: int, water_plan: WaterPlan, fields: WorldFieldBlockCache,
		program: PathProgram, context_margin: float,
		settlements: SettlementPlan) -> void:
	assert(water_plan != null and fields != null and program != null and settlements != null)
	assert(is_finite(context_margin) and context_margin >= program.query_margin)
	_world_seed = world_seed
	_water_plan = water_plan
	_fields = fields
	_program = program
	_settlements = settlements
	_context_margin = context_margin
	_water_plan.set_planning_progress_callback(
		Callable(self, "_on_water_planning_progress"))

func context_for(chunk: Vector2i) -> PathContext:
	if _contexts.has(chunk):
		_touch(_context_stamps, chunk)
		_report_context_progress(chunk, 1.0)
		return _contexts[chunk]
	_evict_lru(_contexts, _context_stamps, _program.CONTEXT_CACHE_CAP)
	var context := _build_context(chunk)
	_contexts[chunk] = context
	_touch(_context_stamps, chunk)
	_stats.context_builds += 1
	return context

func set_progress_callback(callback: Callable) -> void:
	_progress_callback = callback

func set_planning_progress_callback(callback: Callable) -> void:
	_planning_progress_callback = callback

func _report_context_progress(chunk: Vector2i, progress: float) -> void:
	if _progress_callback.is_valid():
		_progress_callback.call(chunk, clampf(progress, 0.0, 1.0))

func _set_water_progress_span(chunk: Vector2i, start: float, end: float) -> void:
	_active_progress_chunk = chunk
	_active_progress_valid = true
	_water_progress_start = start
	_water_progress_end = end

func _on_water_planning_progress(progress: float) -> void:
	if _planning_progress_callback.is_valid():
		_planning_progress_callback.call(clampf(progress, 0.0, 1.0))
	if _active_progress_valid:
		_report_context_progress(_active_progress_chunk,
			lerpf(_water_progress_start, _water_progress_end, progress))

func node_for(super_cell: Vector2i) -> Dictionary:
	_stats.node_queries += 1
	if _nodes.has(super_cell):
		_touch(_node_stamps, super_cell)
		return _public_node(_nodes[super_cell])
	_evict_lru(_nodes, _node_stamps, _program.NODE_CACHE_CAP)
	var node := _compute_node(super_cell)
	_nodes[super_cell] = node
	_touch(_node_stamps, super_cell)
	_stats.node_builds += 1
	return _public_node(node)

func route_for(node_a: Dictionary, node_b: Dictionary) -> Dictionary:
	_stats.route_queries += 1
	if node_a.is_empty() or node_b.is_empty():
		return {}
	var sc_a := _super_of(node_a.cell)
	var sc_b := _super_of(node_b.cell)
	if absi(sc_a.x - sc_b.x) + absi(sc_a.y - sc_b.y) != 1:
		return {}
	var ordered := [node_a, node_b]
	if String(node_b.id) < String(node_a.id):
		ordered = [node_b, node_a]
	var pair_key := "%s|%s" % [ordered[0].id, ordered[1].id]
	if _routes.has(pair_key):
		_touch(_route_stamps, pair_key)
		return (_routes[pair_key] as Dictionary).duplicate(true)
	_evict_lru(_routes, _route_stamps, _program.ROUTE_CACHE_CAP)
	var route := _compute_route(ordered[0], ordered[1], pair_key)
	_routes[pair_key] = route
	_touch(_route_stamps, pair_key)
	return route.duplicate(true)

func bridge_site(site_key: Variant) -> Dictionary:
	var key := String(site_key.key) if site_key is Dictionary else String(site_key)
	if key.is_empty() or not _site_defs.has(key):
		return {}
	if _bridge_resolved_cache.has(key):
		_touch(_bridge_resolved_stamps, key)
		return (_bridge_resolved_cache[key] as Dictionary).duplicate(true)
	_evict_lru(_bridge_resolved_cache, _bridge_resolved_stamps,
		_program.BRIDGE_CACHE_CAP)
	var raw := _bridge_raw(_site_defs[key])
	var resolved := raw
	if not raw.is_empty():
		for other_def: Dictionary in _nearby_site_defs(_site_defs[key]):
			if String(other_def.key) == key:
				continue
			var other := _bridge_raw(other_def)
			if other.is_empty() or not (raw.footprint as Rect2).intersects(other.footprint, true):
				continue
			if _rank_bridge(other) < _rank_bridge(raw):
				resolved = {}
				break
	_bridge_resolved_cache[key] = resolved
	_touch(_bridge_resolved_stamps, key)
	return resolved.duplicate(true)

func stats() -> Dictionary:
	var out := _stats.duplicate()
	out["node_cache"] = _nodes.size()
	out["route_cache"] = _routes.size()
	out["bridge_raw_cache"] = _bridge_raw_cache.size()
	out["bridge_resolved_cache"] = _bridge_resolved_cache.size()
	out["context_cache"] = _contexts.size()
	out["planning_point_cache"] = _planning_points.size()
	return out

# ---------------------------------------------------------------------------
# Nodes

func _compute_node(super_cell: Vector2i) -> Dictionary:
	var site := _settlements.site_for(super_cell)
	if site.is_empty():
		return _absent_node()
	var lo := INF
	var hi := -INF
	for point: Vector2 in _node_support_samples(site.cell):
		var height := _ground(point)
		lo = minf(lo, height)
		hi = maxf(hi, height)
		var water := _fields.water_at(point)
		if water.is_wet(point):
			return _absent_node()
	if hi - lo > PathProgram.NODE_MAX_SUPPORT_SPAN:
		return _absent_node()
	return {"id": site.id, "cell": site.cell}

func _node_support_samples(cell: Vector2i) -> Array[Vector2]:
	var centre := Vector2(cell) * TerrainSurfaceField.TILE
	var half := PathProgram.NODE_SUPPORT_SIZE * 0.5
	return [centre, centre + Vector2(-half, -half), centre + Vector2(half, -half),
		centre + Vector2(-half, half), centre + Vector2(half, half)]

# ---------------------------------------------------------------------------
# Bridges

func _site_from_start(cell: Vector2i, direction: Vector2i) -> Dictionary:
	if _planning_distance(cell) <= 0.0:
		return {}
	for steps in range(2, _program.bridge_lookahead_cells + 1):
		var far_cell := cell + direction * steps
		if _planning_distance(far_cell) <= 0.0:
			continue
		var intervals := _planning_intervals_cells(cell, far_cell)
		if intervals.is_empty() or intervals[-1].y >= 0.999:
			continue
		if _planning_intervals_cells(cell, cell + direction).is_empty():
			continue
		var lo := cell
		var hi := far_cell
		if _cell_less(hi, lo):
			var swap := lo
			lo = hi
			hi = swap
		var axis := 0 if direction.x != 0 else 1
		var key := "%d:%d,%d:%d,%d" % [axis, lo.x, lo.y, hi.x, hi.y]
		var site := {"key": key, "axis": axis, "a": lo, "b": hi}
		_site_defs[key] = site
		return site
	return {}

func _bridge_raw(site: Dictionary) -> Dictionary:
	var key := String(site.key)
	if _bridge_raw_cache.has(key):
		_touch(_bridge_raw_stamps, key)
		return _bridge_raw_cache[key]
	_evict_lru(_bridge_raw_cache, _bridge_raw_stamps, _program.BRIDGE_CACHE_CAP)
	_stats.bridge_profiles += 1
	var result := _profile_bridge(site)
	_bridge_raw_cache[key] = result
	_touch(_bridge_raw_stamps, key)
	return result

func _profile_bridge(site: Dictionary) -> Dictionary:
	var a_cell: Vector2i = site.a
	var b_cell: Vector2i = site.b
	var a := Vector2(a_cell) * TerrainSurfaceField.TILE
	var b := Vector2(b_cell) * TerrainSurfaceField.TILE
	var forward := (b - a).normalized()
	var lateral := Vector2(-forward.y, forward.x)
	var metrics: Dictionary = _program.bridge
	var contacts: PackedVector3Array = metrics.deck_contacts
	var ground_a := _ground(a)
	var ground_b := _ground(b)
	if absf(ground_b - ground_a) > PathProgram.BRIDGE_BANK_SPAN_MAX:
		return {}
	var yaw := atan2(forward.x, forward.y)
	var pitch := -atan2(ground_b - ground_a,
		maxf(0.001, absf(contacts[1].z - contacts[0].z)))
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
	var contact_a := basis * contacts[0]
	var contact_b := basis * contacts[1]
	var origin := Vector3((a.x + b.x) * 0.5,
		((ground_a - contact_a.y) + (ground_b - contact_b.y)) * 0.5,
		(a.y + b.y) * 0.5)
	var transform := Transform3D(basis, origin)
	var wa := transform * contacts[0]
	var wb := transform * contacts[1]
	if absf(wa.y - _ground(Vector2(wa.x, wa.z))) > PathProgram.BRIDGE_END_STEP_MAX \
		or absf(wb.y - _ground(Vector2(wb.x, wb.z))) > PathProgram.BRIDGE_END_STEP_MAX:
		return {}
	var wet_levels := PackedFloat32Array()
	for offset: float in metrics.lateral_offsets:
		var line_a := a + lateral * offset
		var line_b := b + lateral * offset
		var intervals := _exact_wet_intervals(line_a, line_b)
		if intervals.is_empty():
			return {}
		if (intervals[-1].y - intervals[0].x) * line_a.distance_to(line_b) \
			+ float(metrics.dry_landing_total) > float(metrics.usable_span) + 0.001:
			return {}
		for interval: Vector2 in intervals:
			if interval.y - interval.x > float(metrics.usable_span) / a.distance_to(b) + 0.001:
				return {}
			for t in [interval.x, (interval.x + interval.y) * 0.5, interval.y]:
				var p := line_a.lerp(line_b, t)
				var water := _fields.water_at(p)
				var level := water.level_at(p)
				if not is_nan(level):
					wet_levels.append(level)
	for field: String in ["landing_samples", "support_samples"]:
		for local: Vector3 in metrics[field]:
			var world := transform * local
			var p := Vector2(world.x, world.z)
			if _fields.water_at(p).is_wet(p):
				return {}
			if absf(_ground(p) - world.y) > 1.25:
				return {}
	if wet_levels.is_empty():
		return {}
	var water_lo := wet_levels[0]
	var water_hi := wet_levels[0]
	for level: float in wet_levels:
		water_lo = minf(water_lo, level)
		water_hi = maxf(water_hi, level)
	if water_hi - water_lo > PathProgram.BRIDGE_WATER_SPREAD_MAX \
		or origin.y + float(metrics.underside_height) - water_hi \
		< float(metrics.dynamic_clearance):
		return {}
	var beneath_lo := INF
	var beneath_hi := -INF
	for i in 9:
		var h := _ground(a.lerp(b, float(i) / 8.0))
		beneath_lo = minf(beneath_lo, h)
		beneath_hi = maxf(beneath_hi, h)
	if beneath_hi - beneath_lo > PathProgram.BRIDGE_TERRAIN_GRADE_MAX:
		return {}
	var footprint := _transformed_rect(metrics.footprint, transform)
	var connections: Array[Dictionary] = []
	var step := (b_cell - a_cell).sign()
	var cursor := a_cell
	while cursor != b_cell:
		var next := cursor + step
		connections.append({"a": cursor, "b": next})
		cursor = next
	return {"key": String(site.key), "axis": int(site.axis), "a": a_cell,
		"b": b_cell, "transform": transform, "footprint": footprint,
		"connections": connections,
		"variation": int(ceil(absf(ground_b - ground_a))),
		"priority": _hash(PathProgram.SALT_BRIDGE,
			[a_cell.x, a_cell.y, b_cell.x, b_cell.y])}

func _nearby_site_defs(site: Dictionary) -> Array[Dictionary]:
	var out: Dictionary = {String(site.key): site}
	var centre: Vector2i = (site.a + site.b) / 2
	var radius := _program.bridge_lookahead_cells + 1
	for z in range(centre.y - radius, centre.y + radius + 1):
		for x in range(centre.x - radius, centre.x + radius + 1):
			for direction: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN,
					Vector2i.LEFT, Vector2i.UP]:
				var other := _site_from_start(Vector2i(x, z), direction)
				if not other.is_empty():
					out[String(other.key)] = other
	var values: Array[Dictionary] = []
	values.assign(out.values())
	values.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.key) < String(b.key))
	return values

func _rank_bridge(bridge: Dictionary) -> String:
	return "%020d:%s" % [int(bridge.priority) & 0x7FFFFFFFFFFFFFFF, bridge.key]

# ---------------------------------------------------------------------------
# Routes

func _compute_route(a: Dictionary, b: Dictionary, pair_key: String) -> Dictionary:
	var record := _route_record(a.cell, b.cell, pair_key)
	if record.is_empty():
		return {}
	_stats.route_solves += 1
	var solved: Dictionary = _SOLVER.solve(record)
	if solved.is_empty():
		return {}
	if not _validate_route_exact(solved.edges):
		_stats.route_exact_failures += 1
		return {}
	var connections: Array[Dictionary] = []
	var bridge_keys: Dictionary = {}
	for edge: Dictionary in solved.edges:
		connections.append_array(edge.connections)
		if not String(edge.bridge_key).is_empty():
			bridge_keys[String(edge.bridge_key)] = true
	var bridges: Array[String] = []
	bridges.assign(bridge_keys.keys())
	bridges.sort()
	return {"key": pair_key, "node_a": a, "node_b": b,
		"cost": solved.cost, "connections": connections,
		"bridges": bridges, "pair_hash": _hash(PathProgram.SALT_ROUTE,
			[a.cell.x, a.cell.y, b.cell.x, b.cell.y])}

func _route_record(start_cell: Vector2i, goal_cell: Vector2i, pair_key: String) -> Dictionary:
	var min_cell := Vector2i(mini(start_cell.x, goal_cell.x), mini(start_cell.y, goal_cell.y))
	var max_cell := Vector2i(maxi(start_cell.x, goal_cell.x), maxi(start_cell.y, goal_cell.y))
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
		var directions: Array[Vector2i] = []
		if cell.x != goal_cell.x:
			directions.append(Vector2i(signi(goal_cell.x - cell.x), 0))
		if cell.y != goal_cell.y:
			directions.append(Vector2i(0, signi(goal_cell.y - cell.y)))
		var cell_edges: Array[Dictionary] = []
		for direction: Vector2i in directions:
			var next := cell + direction
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
			if _manhattan(far, goal_cell) >= _manhattan(cell, goal_cell) \
				or far.x < min_cell.x or far.y < min_cell.y \
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
	return {"start": _local_index(start_cell, min_cell, width),
		"goal": _local_index(goal_cell, min_cell, width), "heights": heights,
		"edges": edges, "order": order,
		"vertical_budget": PathProgram.ROUTE_VERTICAL_BUDGET_UNITS,
		"turn_cost": PathProgram.ROUTE_TURN_COST,
		"pair_hash": _hash(PathProgram.SALT_ROUTE,
			[start_cell.x, start_cell.y, goal_cell.x, goal_cell.y]),
		"pair_key": pair_key}

func _validate_route_exact(edges: Array[Dictionary]) -> bool:
	for edge: Dictionary in edges:
		if not String(edge.bridge_key).is_empty():
			continue
		for connection: Dictionary in edge.connections:
			var a := Vector2(connection.a) * TerrainSurfaceField.TILE
			var b := Vector2(connection.b) * TerrainSurfaceField.TILE
			var side := Vector2(-(b - a).normalized().y, (b - a).normalized().x) \
				* PathProgram.PATH_WIDTH * 0.5
			for offset: Vector2 in [Vector2.ZERO, side, -side]:
				if not _exact_wet_intervals(a + offset, b + offset).is_empty():
					return false
			var steps := maxi(1, int(ceil(a.distance_to(b) / TerrainChunkMesher.STEP)))
			for i in steps:
				var centre := a.lerp(b, (float(i) + 0.5) / float(steps))
				for offset: Vector2 in [side * 0.5, -side * 0.5]:
					var point := centre + offset
					if _fields.water_at(point).is_wet(point):
						return false
	return true

# ---------------------------------------------------------------------------
# Network projection and contextual props

func _build_context(chunk: Vector2i) -> PathContext:
	_report_context_progress(chunk, 0.01)
	var core := Rect2(Vector2(chunk) * TerrainChunkMesher.CHUNK_WORLD,
		Vector2.ONE * TerrainChunkMesher.CHUNK_WORLD)
	var query := core.grow(_context_margin + _program.max_horizontal_footprint_radius)
	var relevant_pairs := _coarse_pairs(query)
	_report_context_progress(chunk, 0.03)
	var materialized: Dictionary = {}
	var relevant_keys: Dictionary = {}
	var endpoint_nodes: Dictionary = {}
	for pair_index in relevant_pairs.size():
		var pair: Array = relevant_pairs[pair_index]
		var pair_start := lerpf(0.03, 0.28,
			float(pair_index) / maxf(float(relevant_pairs.size()), 1.0))
		var pair_end := lerpf(0.03, 0.28,
			float(pair_index + 1) / maxf(float(relevant_pairs.size()), 1.0))
		var pair_mid := (pair_start + pair_end) * 0.5
		_set_water_progress_span(chunk, pair_start, pair_mid)
		var node_a := node_for(pair[0])
		_set_water_progress_span(chunk, pair_mid, pair_end)
		var node_b := node_for(pair[1])
		if node_a.is_empty() or node_b.is_empty():
			_report_context_progress(chunk, pair_end)
			continue
		var key := _pair_key(node_a, node_b)
		relevant_keys[key] = true
		endpoint_nodes[String(node_a.id)] = {"node": node_a, "sc": pair[0]}
		endpoint_nodes[String(node_b.id)] = {"node": node_b, "sc": pair[1]}
		_report_context_progress(chunk, pair_end)
	# Complete every relevant endpoint's four-route feasibility before ranking.
	var endpoints: Array = endpoint_nodes.values()
	var route_steps := maxi(1, endpoints.size() * _DIRS.size())
	var route_step := 0
	for endpoint: Dictionary in endpoints:
		for direction: Vector2i in _DIRS:
			var other := node_for(endpoint.sc + direction)
			if not other.is_empty():
				var route := route_for(endpoint.node, other)
				if not route.is_empty():
					materialized[String(route.key)] = route
			route_step += 1
			_report_context_progress(chunk, lerpf(0.28, 0.88,
				float(route_step) / float(route_steps)))
	_report_context_progress(chunk, 0.90)
	var chosen_by_node: Dictionary = {}
	for route: Dictionary in materialized.values():
		for node: Dictionary in [route.node_a, route.node_b]:
			var id := String(node.id)
			if not chosen_by_node.has(id) \
				or _route_rank(route) < _route_rank(chosen_by_node[id]):
				chosen_by_node[id] = route
	var accepted: Array[Dictionary] = []
	for key: String in relevant_keys:
		if not materialized.has(key):
			continue
		var route: Dictionary = materialized[key]
		var backbone: bool = chosen_by_node.get(String(route.node_a.id), {}).get("key", "") == key \
			or chosen_by_node.get(String(route.node_b.id), {}).get("key", "") == key
		if backbone or _roll(_hash(PathProgram.SALT_LOOP,
				[route.node_a.cell.x, route.node_a.cell.y,
				route.node_b.cell.x, route.node_b.cell.y])) \
			< PathProgram.LOOP_EDGE_PROBABILITY:
			accepted.append(route)
	accepted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.key) < String(b.key))
	_report_context_progress(chunk, 0.95)
	var context := _project_context(core, accepted)
	_report_context_progress(chunk, 1.0)
	_active_progress_valid = false
	return context

func _project_context(core: Rect2, routes: Array[Dictionary]) -> PathContext:
	var masks: Dictionary = {}
	var nodes: Dictionary = {}
	var bridge_cells: Dictionary = {}
	var cell_routes: Dictionary = {}
	var bridges: Dictionary = {}
	for route: Dictionary in routes:
		for node: Dictionary in [route.node_a, route.node_b]:
			nodes[node.cell] = true
		for connection: Dictionary in route.connections:
			_add_connection(masks, connection.a, connection.b)
			for cell: Vector2i in [connection.a, connection.b]:
				if not cell_routes.has(cell):
					cell_routes[cell] = {}
				cell_routes[cell][String(route.key)] = true
		for bridge_key: String in route.bridges:
			var bridge := bridge_site(bridge_key)
			if not bridge.is_empty():
				bridges[bridge_key] = bridge
				for connection: Dictionary in bridge.connections:
					bridge_cells[connection.a] = true
					bridge_cells[connection.b] = true
	var corridors: Array[Rect2] = []
	for cell: Vector2i in masks:
		var centre := Vector2(cell) * TerrainSurfaceField.TILE
		var mask: int = masks[cell]
		for direction: Vector2i in _DIRS:
			if (mask & int(_BITS[direction])) != 0:
				corridors.append(_connection_rect(centre, direction))
		if nodes.has(cell):
			corridors.append(Rect2(centre - Vector2.ONE * PathProgram.PLAZA_RADIUS,
				Vector2.ONE * PathProgram.PLAZA_SIZE))
		elif PathContext._has_join(mask):
			corridors.append(Rect2(centre - Vector2.ONE * PathProgram.JUNCTION_SIZE * 0.5,
				Vector2.ONE * PathProgram.JUNCTION_SIZE))
	var reservations := corridors.duplicate()
	var payload := EnvironmentInstancePayload.new()
	var occupied: Array[Rect2] = []
	# Canonical bridges are shared by every contributing route.
	var bridge_keys: Array[String] = []
	bridge_keys.assign(bridges.keys())
	bridge_keys.sort()
	for key: String in bridge_keys:
		var bridge: Dictionary = bridges[key]
		reservations.append(bridge.footprint)
		occupied.append(bridge.footprint)
		if WorldFieldBlockCache.key_of(Vector2(bridge.transform.origin.x,
				bridge.transform.origin.z)) == WorldFieldBlockCache.key_of(core.position):
			payload.add(&"sfv.bridge.001", bridge.transform, Color.WHITE,
				_stable_id("bridge", _site_values(bridge)))
	_place_arches(core, routes, masks, nodes, bridge_cells,
		reservations, occupied, payload)
	_place_lamps(core, routes, masks, nodes, bridge_cells, cell_routes,
		reservations, occupied, payload)
	return PathContext.new(core.grow(_context_margin), corridors, reservations,
		payload, _program.maximum_clearance, masks, nodes, bridge_cells)

func _place_arches(core: Rect2, routes: Array[Dictionary], masks: Dictionary,
		nodes: Dictionary, bridge_cells: Dictionary, reservations: Array[Rect2],
		occupied: Array[Rect2], payload: EnvironmentInstancePayload) -> void:
	# Place from the route endpoint, not the merged mask. Two routes may share
	# their first arm and split before the gate distance; a mask walk sees that
	# branch and used to abandon the exit entirely. Endpoint walks instead put
	# one gate on every resulting physical road, while a shared segment key
	# collapses routes that are still the same road at the chosen distance.
	var exits: Array[Dictionary] = []
	for route: Dictionary in routes:
		var forward := _ordered_route_cells(route)
		if forward.size() <= PathProgram.VILLAGE_GATE_MIN_STEPS:
			continue
		exits.append({"node": forward[0], "cells": forward,
			"key": "%s:a" % route.key})
		var reverse: Array[Vector2i] = forward.duplicate()
		reverse.reverse()
		exits.append({"node": reverse[0], "cells": reverse,
			"key": "%s:b" % route.key})
	exits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _cell_less(a.node, b.node) if a.node != b.node \
			else String(a.key) < String(b.key))
	var claimed_segments: Dictionary = {}
	var large_gate_points: Array[Vector2] = []
	for exit: Dictionary in exits:
		var cells: Array[Vector2i] = exit.cells
		var final_step := mini(PathProgram.VILLAGE_GATE_SEARCH_STEPS,
			cells.size() - 1)
		for step in range(PathProgram.VILLAGE_GATE_MIN_STEPS, final_step + 1):
			var a: Vector2i = cells[step - 1]
			var b: Vector2i = cells[step]
			var direction := b - a
			if absi(direction.x) + absi(direction.y) != 1 \
					or bridge_cells.has(a) or bridge_cells.has(b):
				continue
			var segment_key := _connection_key(a, b)
			if claimed_segments.has(segment_key):
				break
			var offset := Vector2(direction) * TerrainSurfaceField.HALF
			var anchor := Vector2(a) * TerrainSurfaceField.TILE + offset
			var asset: StringName = &"sfv.arch.001" if _roll(_hash(
				PathProgram.SALT_ARCH, [a.x, a.y, b.x, b.y, 1])) < 0.5 \
				else &"sfv.arch.002"
			if _try_prop(core, asset, a, direction, false, "village_gate",
					reservations, occupied, payload, offset):
				claimed_segments[segment_key] = true
				large_gate_points.append(anchor)
				break

	# The small arch marks a fuzzy dominant-biome threshold, not every local
	# flip inside an ecotone. Build all crossings first, suppress the village
	# approach zone, then use stable-priority spacing so nearby oscillations
	# collapse to one readable marker.
	var node_list: Array[Vector2i] = []
	node_list.assign(nodes.keys())
	node_list.sort_custom(_cell_less)
	var candidates: Array[Dictionary] = []
	var cells: Array[Vector2i] = []
	cells.assign(masks.keys())
	cells.sort_custom(_cell_less)
	for cell: Vector2i in cells:
		for direction: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
			if (int(masks[cell]) & int(_BITS[direction])) == 0:
				continue
			var other := cell + direction
			if bridge_cells.has(cell) or bridge_cells.has(other):
				continue
			var start := Vector2(cell) * TerrainSurfaceField.TILE
			var end := Vector2(other) * TerrainSurfaceField.TILE
			var start_biome := _biome_at(start)
			if start_biome == _biome_at(end):
				continue
			var lo := 0.0
			var hi := 1.0
			for _step in 8:
				var mid := (lo + hi) * 0.5
				if _biome_at(start.lerp(end, mid)) == start_biome:
					lo = mid
				else:
					hi = mid
			var offset := Vector2(direction) * TerrainSurfaceField.TILE \
				* (lo + hi) * 0.5
			var point := start + offset
			var near_village := false
			for node: Vector2i in node_list:
				if point.distance_to(Vector2(node) * TerrainSurfaceField.TILE) \
						< PathProgram.BIOME_GATE_VILLAGE_CLEARANCE:
					near_village = true
					break
			if near_village:
				continue
			candidates.append({"cell": cell, "direction": direction,
				"offset": offset, "point": point,
				"priority": _hash(PathProgram.SALT_ARCH,
					[cell.x, cell.y, direction.x, direction.y, 2])})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ap := int(a.priority) & 0x7FFFFFFFFFFFFFFF
		var bp := int(b.priority) & 0x7FFFFFFFFFFFFFFF
		if ap != bp:
			return ap < bp
		if a.cell != b.cell:
			return _cell_less(a.cell, b.cell)
		return _dir_index(a.direction) < _dir_index(b.direction))
	var accepted_points: Array[Vector2] = large_gate_points.duplicate()
	for candidate: Dictionary in candidates:
		var point: Vector2 = candidate.point
		var too_close := false
		for accepted: Vector2 in accepted_points:
			if point.distance_to(accepted) < PathProgram.BIOME_GATE_MIN_SPACING:
				too_close = true
				break
		if too_close:
			continue
		if _try_prop(core, &"sfv.entrance_arch.001", candidate.cell,
				candidate.direction, true, "biome_gate", reservations, occupied,
				payload, candidate.offset):
			accepted_points.append(point)

func _place_lamps(core: Rect2, routes: Array[Dictionary], masks: Dictionary,
		nodes: Dictionary, bridge_cells: Dictionary, cell_routes: Dictionary,
		reservations: Array[Rect2], occupied: Array[Rect2],
		payload: EnvironmentInstancePayload) -> void:
	var claimed: Dictionary = {}
	for cell: Vector2i in cell_routes:
		var keys: Array[String] = []
		keys.assign(cell_routes[cell].keys())
		keys.sort()
		claimed[cell] = keys[0]
	for route: Dictionary in routes:
		var ordered_cells := _ordered_route_cells(route)
		var accepted: Array[Vector2i] = []
		for cell: Vector2i in ordered_cells:
			if claimed.get(cell, "") != String(route.key) or nodes.has(cell) \
				or bridge_cells.has(cell) or not _straight_mask(masks.get(cell, 0)):
				continue
			var rank := _hash(PathProgram.SALT_LAMP, [cell.x, cell.y, 0])
			if _roll(rank) >= PathProgram.LAMP_KEEP_PROBABILITY:
				continue
			var axis := _axis_direction(masks[cell])
			var prev := cell - axis
			var next := cell + axis
			if (_lamp_candidate(prev, route.key, masks, nodes, bridge_cells, claimed) \
					and _hash(PathProgram.SALT_LAMP, [prev.x, prev.y, 0]) < rank) \
				or (_lamp_candidate(next, route.key, masks, nodes, bridge_cells, claimed) \
					and _hash(PathProgram.SALT_LAMP, [next.x, next.y, 0]) < rank):
				continue
			accepted.append(cell)
		var phase := int(_hash(PathProgram.SALT_LAMP,
			[route.node_a.cell.x, route.node_a.cell.y,
			route.node_b.cell.x, route.node_b.cell.y]) & 1)
		for i in accepted.size():
			var cell := accepted[i]
			var direction := _axis_direction(masks[cell])
			var side := Vector2i(-direction.y, direction.x) * (-1 if (i + phase) % 2 else 1)
			_try_prop(core, &"sfv.light_pole.001", cell, -side, false,
				"lamp", reservations, occupied, payload, Vector2(side) * 4.5)

func _lamp_candidate(cell: Vector2i, route_key: String, masks: Dictionary,
		nodes: Dictionary, bridge_cells: Dictionary, claimed: Dictionary) -> bool:
	return claimed.get(cell, "") == route_key and not nodes.has(cell) \
		and not bridge_cells.has(cell) and _straight_mask(masks.get(cell, 0)) \
		and _roll(_hash(PathProgram.SALT_LAMP, [cell.x, cell.y, 0])) \
		< PathProgram.LAMP_KEEP_PROBABILITY

func _try_prop(core: Rect2, asset_id: StringName, cell: Vector2i,
		route_direction: Vector2i, allow_corridor_legs: bool, feature_type: String,
		reservations: Array[Rect2], occupied: Array[Rect2],
		payload: EnvironmentInstancePayload, offset := Vector2.ZERO) -> bool:
	var metrics: Dictionary = _program.assets[asset_id]
	var anchor := Vector2(cell) * TerrainSurfaceField.TILE + offset
	var yaw := atan2(float(route_direction.x), float(route_direction.y))
	var basis := Basis(Vector3.UP, yaw)
	var transform := Transform3D(basis, Vector3(anchor.x, _ground(anchor), anchor.y))
	var footprint := _transformed_rect(metrics.footprint, transform)
	for prior: Rect2 in occupied:
		if footprint.intersects(prior, true):
			return false
	var samples: Array[Vector2] = [anchor]
	if metrics.has("leg_centres"):
		for local: Vector2 in metrics.leg_centres:
			var p3 := transform * Vector3(local.x, 0.0, local.y)
			samples.append(Vector2(p3.x, p3.z))
	else:
		for corner: Vector2 in _rect_corners(metrics.footprint):
			var p3 := transform * Vector3(corner.x, 0.0, corner.y)
			samples.append(Vector2(p3.x, p3.z))
	var base_h := _ground(anchor)
	for point: Vector2 in samples:
		if _fields.water_at(point).is_wet(point) or absf(_ground(point) - base_h) > 0.5:
			return false
	if not allow_corridor_legs and float(metrics.get("opening", INF)) \
		< PathProgram.PATH_WIDTH + 0.5:
		return false
	reservations.append(footprint)
	occupied.append(footprint)
	if WorldFieldBlockCache.key_of(anchor) == WorldFieldBlockCache.key_of(core.position):
		payload.add(asset_id, transform, Color.WHITE,
			_stable_id(feature_type, [cell.x, cell.y,
				route_direction.x, route_direction.y]))
	return true

func _biome_at(point: Vector2) -> StringName:
	return Helper.biome_at(Vector3(point.x, 0.0, point.y), _world_seed)

# ---------------------------------------------------------------------------
# Exact-water segments and geometry helpers

func _exact_wet_intervals(a: Vector2, b: Vector2) -> Array[Vector2]:
	var splits: Array[float] = [0.0, 1.0]
	var delta := b - a
	for axis in 2:
		var av := a[axis]
		var bv := b[axis]
		if is_equal_approx(av, bv):
			continue
		var lo := minf(av, bv)
		var hi := maxf(av, bv)
		var boundary: float = (floor(lo / TerrainChunkMesher.CHUNK_WORLD) + 1.0) \
			* TerrainChunkMesher.CHUNK_WORLD
		while boundary < hi - 0.0001:
			splits.append((boundary - av) / (bv - av))
			boundary += TerrainChunkMesher.CHUNK_WORLD
	splits.sort()
	var out: Array[Vector2] = []
	for i in splits.size() - 1:
		var t0 := splits[i]
		var t1 := splits[i + 1]
		var p0 := a.lerp(b, t0)
		var p1 := a.lerp(b, t1)
		var context := _fields.water_at(a.lerp(b, (t0 + t1) * 0.5))
		for interval: Vector2 in context.wet_intervals(p0, p1):
			var mapped := Vector2(lerpf(t0, t1, interval.x),
				lerpf(t0, t1, interval.y))
			if not out.is_empty() and mapped.x <= out[-1].y + 0.00001:
				out[-1] = Vector2(out[-1].x, maxf(out[-1].y, mapped.y))
			else:
				out.append(mapped)
	return out

func _ground(point: Vector2) -> float:
	return TerrainSurfaceField.surface_y(_fields.region_at(point), point.x, point.y)

func _planning_distance(cell: Vector2i) -> float:
	if _planning_points.has(cell):
		_touch(_planning_point_stamps, cell)
		return float(_planning_points[cell])
	_evict_lru(_planning_points, _planning_point_stamps,
		_program.PLANNING_POINT_CACHE_CAP)
	var point := Vector2(cell) * TerrainSurfaceField.TILE
	var value := _water_plan.planning_signed_distance(point)
	_planning_points[cell] = value
	_touch(_planning_point_stamps, cell)
	return value

func _planning_intervals_cells(a_cell: Vector2i, b_cell: Vector2i) -> Array[Vector2]:
	var a := Vector2(a_cell) * TerrainSurfaceField.TILE
	var b := Vector2(b_cell) * TerrainSurfaceField.TILE
	var length := a.distance_to(b)
	# WaterPlan's source-distance field is conservatively 2-Lipschitz. Cached
	# graph-point distances therefore prove the common dry edge without asking
	# the adaptive interval walker to resample the same endpoints.
	if minf(_planning_distance(a_cell), _planning_distance(b_cell)) \
		> 2.0 * length + WaterPlan.PATH_INTERVAL_TOLERANCE:
		return []
	return _water_plan.planning_intervals(a, b)

func _coarse_pairs(query: Rect2) -> Array[Array]:
	var min_sc := Vector2i(int(floor(query.position.x / WaterPlan.SUPER)) - 1,
		int(floor(query.position.y / WaterPlan.SUPER)) - 1)
	var max_sc := Vector2i(int(floor(query.end.x / WaterPlan.SUPER)) + 1,
		int(floor(query.end.y / WaterPlan.SUPER)) + 1)
	var out: Array[Array] = []
	for z in range(min_sc.y, max_sc.y + 1):
		for x in range(min_sc.x, max_sc.x + 1):
			var sc := Vector2i(x, z)
			for direction: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
				var box := _possible_pair_rect(sc, direction)
				if box.intersects(query, true):
					out.append([sc, sc + direction])
	out.sort_custom(func(a: Array, b: Array) -> bool:
		return _cell_less(a[0], b[0]) or (a[0] == b[0] and _cell_less(a[1], b[1])))
	return out

func _possible_pair_rect(sc: Vector2i, direction: Vector2i) -> Rect2:
	var a0 := sc * PathProgram.SUPER_CELLS + Vector2i(8, 8)
	var a1 := sc * PathProgram.SUPER_CELLS + Vector2i(23, 23)
	var other := sc + direction
	var b0 := other * PathProgram.SUPER_CELLS + Vector2i(8, 8)
	var b1 := other * PathProgram.SUPER_CELLS + Vector2i(23, 23)
	var lo := Vector2(Vector2i(mini(a0.x, b0.x), mini(a0.y, b0.y))) \
		* TerrainSurfaceField.TILE
	var hi := Vector2(Vector2i(maxi(a1.x, b1.x), maxi(a1.y, b1.y))) \
		* TerrainSurfaceField.TILE
	return Rect2(lo, hi - lo).grow(_program.max_horizontal_footprint_radius)

static func _connection_rect(centre: Vector2, direction: Vector2i) -> Rect2:
	var half_width := PathProgram.PATH_WIDTH * 0.5
	var half_length := TerrainSurfaceField.HALF
	if direction.x != 0:
		return Rect2(centre + Vector2(minf(0.0, direction.x * half_length), -half_width),
			Vector2(half_length, PathProgram.PATH_WIDTH))
	return Rect2(centre + Vector2(-half_width, minf(0.0, direction.y * half_length)),
		Vector2(PathProgram.PATH_WIDTH, half_length))

static func _add_connection(masks: Dictionary, a: Vector2i, b: Vector2i) -> void:
	var d := b - a
	assert(absi(d.x) + absi(d.y) == 1)
	masks[a] = int(masks.get(a, 0)) | int(_BITS[d])
	masks[b] = int(masks.get(b, 0)) | int(_BITS[-d])

static func _connection_key(a: Vector2i, b: Vector2i) -> String:
	var lo := a
	var hi := b
	if _cell_less(hi, lo):
		lo = b
		hi = a
	return "%d,%d:%d,%d" % [lo.x, lo.y, hi.x, hi.y]

static func _transformed_rect(rect: Rect2, transform: Transform3D) -> Rect2:
	var first := true
	var lo := Vector2.ZERO
	var hi := Vector2.ZERO
	for corner: Vector2 in _rect_corners(rect):
		var point := transform * Vector3(corner.x, 0.0, corner.y)
		var p := Vector2(point.x, point.z)
		if first:
			lo = p
			hi = p
			first = false
		else:
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
			hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	return Rect2(lo, hi - lo)

static func _rect_corners(rect: Rect2) -> Array[Vector2]:
	return [rect.position, Vector2(rect.end.x, rect.position.y),
		Vector2(rect.position.x, rect.end.y), rect.end]

static func _straight_mask(mask: int) -> bool:
	return mask == 3 or mask == 12

static func _axis_direction(mask: int) -> Vector2i:
	return Vector2i.RIGHT if mask == 3 else Vector2i.DOWN

static func _ordered_route_cells(route: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = [route.node_a.cell]
	var current: Vector2i = route.node_a.cell
	for connection: Dictionary in route.connections:
		if connection.a == current:
			current = connection.b
		elif connection.b == current:
			current = connection.a
		else:
			# Connections are reconstructed in route order, but retain a stable
			# fallback for synthetic tests that hand the plan an unordered route.
			current = connection.b
		out.append(current)
	return out

# ---------------------------------------------------------------------------
# Deterministic keys and bounded-cache mechanics

func _hash(salt: int, values: Array) -> int:
	var h := Helper._mix64(_world_seed ^ PATH_SEED_VERSION ^ salt)
	for value: Variant in values:
		h = Helper._mix64(h ^ Helper._mix64(int(value)))
	return h

static func _roll(value: int) -> float:
	return float(value & 0x7FFFFFFF) / float(0x80000000)

func _stable_id(kind: String, values: Array) -> StringName:
	var salt := PathProgram.SALT_ARCH
	match kind:
		"bridge": salt = PathProgram.SALT_BRIDGE
		"lamp": salt = PathProgram.SALT_LAMP
		"village_gate", "biome_gate": salt = PathProgram.SALT_ARCH
	return StringName("path.%s.%016x" % [kind, _hash(salt, values) & 0x7FFFFFFFFFFFFFFF])

static func _site_values(bridge: Dictionary) -> Array:
	return [bridge.axis, bridge.a.x, bridge.a.y, bridge.b.x, bridge.b.y]

static func _super_of(cell: Vector2i) -> Vector2i:
	return Vector2i(int(floor(float(cell.x) / PathProgram.SUPER_CELLS)),
		int(floor(float(cell.y) / PathProgram.SUPER_CELLS)))

static func _pair_key(a: Dictionary, b: Dictionary) -> String:
	return "%s|%s" % [a.id, b.id] if String(a.id) < String(b.id) \
		else "%s|%s" % [b.id, a.id]

static func _route_rank(route: Dictionary) -> String:
	return "%020.6f:%020d:%s" % [float(route.cost),
		int(route.pair_hash) & 0x7FFFFFFFFFFFFFFF, String(route.key)]

static func _absent_node() -> Dictionary:
	return {"id": _NO_NODE, "cell": Vector2i.ZERO}

static func _public_node(node: Dictionary) -> Dictionary:
	return {} if node.id == _NO_NODE else node.duplicate()

static func _local_index(cell: Vector2i, minimum: Vector2i, width: int) -> int:
	return (cell.y - minimum.y) * width + cell.x - minimum.x

static func _dir_index(direction: Vector2i) -> int:
	return _DIRS.find(direction)

static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

static func _cell_less(a: Vector2i, b: Vector2i) -> bool:
	return a.x < b.x or (a.x == b.x and a.y < b.y)

func _touch(stamps: Dictionary, key: Variant) -> void:
	_clock += 1
	stamps[key] = _clock

func _evict_lru(cache: Dictionary, stamps: Dictionary, cap: int) -> void:
	if cache.size() < cap:
		return
	var keys := cache.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool:
		var sa := int(stamps.get(a, 0))
		var sb := int(stamps.get(b, 0))
		return sa < sb or (sa == sb and str(a) < str(b)))
	var victim: Variant = keys[0]
	cache.erase(victim)
	stamps.erase(victim)
	_stats.evictions += 1
