extends PathPlan

## Frozen complete incident-route evaluation before the September 10 loading optimization.
func _build_context(chunk: Vector2i, cancelled := Callable()) -> FeatureContext:
	if cancelled.is_valid() and cancelled.call(): return null
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
		if cancelled.is_valid() and cancelled.call(): return null
		var pair: Array = relevant_pairs[pair_index]
		var pair_start := lerpf(0.03, 0.28,
			float(pair_index) / maxf(float(relevant_pairs.size()), 1.0))
		var pair_end := lerpf(0.03, 0.28,
			float(pair_index + 1) / maxf(float(relevant_pairs.size()), 1.0))
		var pair_mid := (pair_start + pair_end) * 0.5
		_set_water_progress_span(chunk, pair_start, pair_mid)
		var node_a := node_for(pair[0])
		if cancelled.is_valid() and cancelled.call(): return null
		# A missing endpoint already rules out this pair. Its remote partner
		# may require a complete hydraulic domain, but cannot change that fact.
		if node_a.is_empty():
			_report_context_progress(chunk, pair_end)
			continue
		_set_water_progress_span(chunk, pair_mid, pair_end)
		var node_b := node_for(pair[1])
		if node_b.is_empty():
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
			if cancelled.is_valid() and cancelled.call(): return null
			var other := node_for(endpoint.sc + direction)
			if not other.is_empty():
				var route := route_for(endpoint.node, other)
				if not route.is_empty():
					materialized[String(route.key)] = route
			route_step += 1
			_report_context_progress(chunk, lerpf(0.28, 0.88,
				float(route_step) / float(route_steps)))
	if cancelled.is_valid() and cancelled.call(): return null
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


func accepted_mask_for_node(super_cell: Vector2i) -> int:
	if _accepted_masks.has(super_cell):
		_touch(_accepted_mask_stamps, super_cell)
		return int(_accepted_masks[super_cell])
	_evict_lru(_accepted_masks, _accepted_mask_stamps,
		_program.NODE_CACHE_CAP)
	var node := node_for(super_cell)
	var mask := 0
	if not node.is_empty():
		for direction: Vector2i in _DIRS:
			var other_super := super_cell + direction
			var other := node_for(other_super)
			if other.is_empty():
				continue
			var route := route_for(node, other)
			if route.is_empty():
				continue
			var backbone := _chosen_route_key(super_cell) == String(route.key) \
				or _chosen_route_key(other_super) == String(route.key)
			var loop := _roll(_hash(PathProgram.SALT_LOOP,
				[route.node_a.cell.x, route.node_a.cell.y,
				route.node_b.cell.x, route.node_b.cell.y])) \
				< PathProgram.LOOP_EDGE_PROBABILITY
			if backbone or loop:
				mask |= _route_endpoint_mask(route, node.cell)
	_accepted_masks[super_cell] = mask
	_touch(_accepted_mask_stamps, super_cell)
	return mask


func _chosen_route_key(super_cell: Vector2i) -> String:
	if _chosen_routes.has(super_cell):
		_touch(_chosen_route_stamps, super_cell)
		return String(_chosen_routes[super_cell])
	_evict_lru(_chosen_routes, _chosen_route_stamps,
		_program.NODE_CACHE_CAP)
	var node := node_for(super_cell)
	var chosen := ""
	var chosen_rank := ""
	if not node.is_empty():
		for direction: Vector2i in _DIRS:
			var other := node_for(super_cell + direction)
			if other.is_empty():
				continue
			var route := route_for(node, other)
			if route.is_empty():
				continue
			var rank := _route_rank(route)
			if chosen.is_empty() or rank < chosen_rank:
				chosen = String(route.key)
				chosen_rank = rank
	_chosen_routes[super_cell] = chosen
	_touch(_chosen_route_stamps, super_cell)
	return chosen

