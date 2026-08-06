class_name VillageCirculationSolver
extends RefCounted

## Small topology orchestrator. Geometry qualification belongs to the ground
## and aerial routers; this class only assembles semantic contacts, selects a
## minimum connected graph, and enforces the urban-fabric composition gates.
const MAX_ARRIVAL_LINK := VillageMassingProgram.CORE_RADIUS * 1.25
## Ground streets may cross the complete compact core so its porous shelter
## edge can still join the market. Aerial links retain the much shorter local
## radius; vertical fabric therefore cannot turn into long sky bridges.
const MAX_GROUND_LINK := VillageMassingProgram.CORE_RADIUS


static func solve(terrain: VillageTerrainView, arrival: Vector2,
		primary_axis: Vector2, massing: VillageMassingPlan,
		vocabulary: VillageElevatedProgram,
		market: VillageMarketPlan = null) -> VillageCirculationPlan:
	assert(terrain != null and arrival.is_finite())
	assert(primary_axis.is_normalized())
	if massing == null or not massing.accepted or vocabulary == null:
		return _rejected(&"massing")
	var plan := VillageCirculationPlan.new()
	var arrival_node: VillageCirculationNode
	var market_node_keys: Dictionary = {}
	var blocking_volumes: Array[VillageOccupancyVolume] = []
	if market != null:
		if not market.accepted:
			return _rejected(&"market")
		plan.nodes.append_array(market.nodes)
		plan.links.append_array(market.links)
		blocking_volumes = market.blocking_volumes()
		for node: VillageCirculationNode in market.nodes:
			market_node_keys[node.stable_key] = true
			if node.kind == VillageCirculationNode.Kind.ARRIVAL:
				arrival_node = node
	else:
		arrival_node = VillageCirculationNode.new(&"arrival",
			VillageCirculationNode.Kind.ARRIVAL, arrival,
			terrain.surface_y(arrival))
		plan.nodes.append(arrival_node)
	if arrival_node == null:
		return _rejected(&"market_arrival")
	var contact_nodes: Array[VillageCirculationNode] = []
	if market != null:
		contact_nodes.append_array(market.nodes)
	else:
		contact_nodes.append(arrival_node)
	var door_nodes: Array[VillageCirculationNode] = []
	for placement: VillageMassingPlacement in massing.placements:
		var door := VillageCirculationNode.new(
			StringName("%s.door" % placement.stable_key),
			VillageCirculationNode.Kind.DOOR, placement.entrance,
			placement.floor_y, placement.stable_key,
			placement.entrance_outward)
		var contact := VillageCirculationNode.new(
			StringName("%s.terrain" % placement.stable_key),
			VillageCirculationNode.Kind.TERRAIN_CONTACT,
			placement.street_contact,
			placement.street_contact_y, placement.stable_key,
			placement.entrance_outward)
		plan.nodes.append(door)
		door_nodes.append(door)
		if placement.ground_accessible:
			plan.nodes.append(contact)
			contact_nodes.append(contact)
			plan.links.append(_entrance_link(door, contact, placement))
	var pair_candidates: Array[Dictionary] = []
	for index in contact_nodes.size():
		for prior in index:
			var a := contact_nodes[prior]
			var b := contact_nodes[index]
			if market_node_keys.has(a.stable_key) \
					and market_node_keys.has(b.stable_key):
				continue
			var reach := MAX_ARRIVAL_LINK if a.kind \
					== VillageCirculationNode.Kind.ARRIVAL or b.kind \
					== VillageCirculationNode.Kind.ARRIVAL else MAX_GROUND_LINK
			if a.point.distance_to(b.point) > reach + 0.001:
				continue
			pair_candidates.append({"a": a, "b": b,
				"distance": a.point.distance_to(b.point)})
	pair_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if float(a.distance) != float(b.distance):
			return float(a.distance) < float(b.distance)
		return String(VillageRouteGeometry.edge_key(&"pair", a.a.stable_key,
			a.b.stable_key)) < String(VillageRouteGeometry.edge_key(&"pair",
			b.a.stable_key, b.b.stable_key)))
	var ground_candidates: Array[VillageCirculationLink] = []
	for pair: Dictionary in pair_candidates:
		var link := VillageGroundRouter.direct_link(terrain, arrival,
			primary_axis, pair.a, pair.b, massing.placements, vocabulary,
			blocking_volumes)
		if link != null:
			ground_candidates.append(link)
	ground_candidates.sort_custom(VillageRouteGeometry.link_less)
	var existing_ground_links: Array[VillageCirculationLink] = []
	if market != null:
		existing_ground_links.append_array(market.links)
	var direct_tree := _minimum_connectors(contact_nodes, ground_candidates,
		existing_ground_links)
	var ground_parent := _parent_table(contact_nodes)
	for link: VillageCirculationLink in existing_ground_links:
		_union(ground_parent, link.from_key, link.to_key)
	for link: VillageCirculationLink in direct_tree:
		_union(ground_parent, link.from_key, link.to_key)
	for pair: Dictionary in pair_candidates:
		var a := pair.a as VillageCirculationNode
		var b := pair.b as VillageCirculationNode
		if _find(ground_parent, a.stable_key) \
				== _find(ground_parent, b.stable_key):
			continue
		var link := VillageGroundRouter.searched_link(terrain, arrival,
			primary_axis, a, b, massing.placements, vocabulary,
			blocking_volumes)
		if link == null:
			continue
		ground_candidates.append(link)
		_union(ground_parent, link.from_key, link.to_key)
		if _all_joined(ground_parent):
			break
	ground_candidates.sort_custom(VillageRouteGeometry.link_less)
	plan.ground_candidate_count = ground_candidates.size()
	var ground_links := _minimum_connectors(contact_nodes, ground_candidates,
		existing_ground_links)
	for link: VillageCirculationLink in ground_links:
		plan.links.append(link)
	plan.ground_street_count = ground_links.size()
	if plan.ground_street_count < massing.ground_building_count:
		return _rejected(&"ground_streets", plan)
	var platform_result := VillagePlatformSolver.solve(arrival, primary_axis,
		massing.placements, blocking_volumes)
	plan.platform_candidate_count = int(platform_result.candidate_count)
	plan.platforms.assign(platform_result.regions)
	plan.platform_region_count = plan.platforms.size()
	for link: VillageCirculationLink in platform_result.links:
		plan.links.append(link)
	var aerial_candidates := VillageAerialRouter.candidates(door_nodes,
		massing.placements, vocabulary, blocking_volumes)
	plan.aerial_candidate_count = int(platform_result.candidate_count) \
		+ aerial_candidates.size()
	for link: VillageCirculationLink in platform_result.links:
		plan.aerial_candidate_edges.append(_candidate_edge(link))
	for candidate: Dictionary in aerial_candidates:
		plan.aerial_candidate_edges.append(_candidate_edge(
			candidate.link as VillageCirculationLink))
	var selected_pairs: Dictionary = {}
	var selected_endpoint_pairs: Dictionary = {}
	for link: VillageCirculationLink in platform_result.links:
		selected_pairs[link.stable_key] = true
		selected_endpoint_pairs[_endpoint_pair(link)] = true
	var graph_parent := _parent_table(plan.nodes)
	for link: VillageCirculationLink in plan.links:
		_union(graph_parent, link.from_key, link.to_key)
	# Platform regions establish same-floor public ground first. Only then may a
	# curved route join different graph components, normally as a stair between
	# adjacent architectural half-levels.
	for candidate: Dictionary in aerial_candidates:
		if selected_pairs.size() >= VillageMassingProgram.MAX_AERIAL_LINKS:
			break
		var link := candidate.link as VillageCirculationLink
		if _find(graph_parent, link.from_key) \
				== _find(graph_parent, link.to_key):
			continue
		plan.links.append(link)
		selected_pairs[link.stable_key] = true
		selected_endpoint_pairs[_endpoint_pair(link)] = true
		_union(graph_parent, link.from_key, link.to_key)
	if not _all_joined(graph_parent):
		plan.disconnected_components = _components(graph_parent)
		return _rejected(&"circulation_connectivity", plan)
	# Add at most the bounded target of short curved cross-links after the
	# platform/stair graph is already connected. Endpoint-pair identity prevents
	# a decorative route from tracing the same two doors as a platform corridor.
	for candidate: Dictionary in aerial_candidates:
		if selected_pairs.size() >= VillageMassingProgram.MIN_AERIAL_LINKS \
				and _has_curved_link(plan.links):
			break
		var link := candidate.link as VillageCirculationLink
		if selected_pairs.has(link.stable_key) \
				or selected_endpoint_pairs.has(_endpoint_pair(link)) \
				or selected_pairs.size() >= VillageMassingProgram.MAX_AERIAL_LINKS:
			continue
		plan.links.append(link)
		selected_pairs[link.stable_key] = true
		selected_endpoint_pairs[_endpoint_pair(link)] = true
	plan.aerial_link_count = selected_pairs.size()
	for link: VillageCirculationLink in plan.links:
		if not link.is_aerial():
			continue
		if link.kind == VillageCirculationLink.Kind.AERIAL_WALKWAY:
			plan.maximum_aerial_length = maxf(plan.maximum_aerial_length,
				VillageRouteGeometry.polyline_horizontal_length(link.samples))
			plan.curved_link_count += 1
	plan.accepted = true
	plan.reason = &"accepted"
	var rejection := plan.rejection_reason(massing)
	if not rejection.is_empty():
		return _rejected(rejection, plan)
	return plan


static func _endpoint_pair(link: VillageCirculationLink) -> String:
	var endpoints: Array[String] = [String(link.from_key), String(link.to_key)]
	endpoints.sort()
	return "%s|%s" % endpoints


static func _candidate_edge(link: VillageCirculationLink) -> Dictionary:
	return {"key": String(link.stable_key), "kind": link.kind,
		"from": String(link.from_key), "to": String(link.to_key),
		"stair_count": link.stair_count}


static func _has_curved_link(links: Array[VillageCirculationLink]) -> bool:
	for link: VillageCirculationLink in links:
		if link.kind == VillageCirculationLink.Kind.AERIAL_WALKWAY:
			return true
	return false


static func _entrance_link(door: VillageCirculationNode,
		contact: VillageCirculationNode,
		placement: VillageMassingPlacement) -> VillageCirculationLink:
	var link := VillageCirculationLink.new(
		StringName("entrance.%s" % placement.stable_key),
		VillageCirculationLink.Kind.ENTRANCE,
		door.stable_key, contact.stable_key)
	link.control_points = [VillageRouteGeometry.point3(door.point,
		door.surface_y)]
	if placement.entrance_ground_contact.distance_to(contact.point) > 0.01:
		link.control_points.append(VillageRouteGeometry.point3(
			placement.entrance_ground_contact, placement.entrance_ground_y))
	link.control_points.append(VillageRouteGeometry.point3(contact.point,
		contact.surface_y))
	link.samples = [link.control_points[0]]
	for index in range(1, link.control_points.size()):
		var segment := VillageRouteGeometry.linear_samples(
			link.control_points[index - 1], link.control_points[index],
			VillageProgram.MODULE)
		for sample_index in range(1, segment.size()):
			link.samples.append(segment[sample_index])
	link.length = VillageRouteGeometry.polyline_length(link.samples)
	link.stair_count = placement.entrance_stair_count
	link.residual_step = placement.entrance_residual_step
	assert(link.is_valid())
	return link


static func _minimum_tree(nodes: Array[VillageCirculationNode],
		candidates: Array[VillageCirculationLink]
		) -> Array[VillageCirculationLink]:
	var parent := _parent_table(nodes)
	var out: Array[VillageCirculationLink] = []
	for link: VillageCirculationLink in candidates:
		if _find(parent, link.from_key) == _find(parent, link.to_key):
			continue
		_union(parent, link.from_key, link.to_key)
		out.append(link)
		if out.size() == nodes.size() - 1:
			break
	return out


static func _minimum_connectors(nodes: Array[VillageCirculationNode],
		candidates: Array[VillageCirculationLink],
		existing: Array[VillageCirculationLink]
		) -> Array[VillageCirculationLink]:
	var parent := _parent_table(nodes)
	for link: VillageCirculationLink in existing:
		if parent.has(link.from_key) and parent.has(link.to_key):
			_union(parent, link.from_key, link.to_key)
	var out: Array[VillageCirculationLink] = []
	for link: VillageCirculationLink in candidates:
		if _find(parent, link.from_key) == _find(parent, link.to_key):
			continue
		_union(parent, link.from_key, link.to_key)
		out.append(link)
		if _all_joined(parent):
			break
	return out


static func _all_joined(parent: Dictionary) -> bool:
	if parent.is_empty():
		return false
	var first_key: StringName = parent.keys()[0]
	var root := _find(parent, first_key)
	for key: StringName in parent:
		if _find(parent, key) != root:
			return false
	return true


static func _components(parent: Dictionary) -> Array[Array]:
	var by_root: Dictionary = {}
	for key: StringName in parent:
		var root := _find(parent, key)
		if not by_root.has(root):
			by_root[root] = []
		(by_root[root] as Array).append(key)
	var out: Array[Array] = []
	for root: StringName in by_root:
		var component := by_root[root] as Array
		component.sort_custom(func(a: StringName, b: StringName) -> bool:
			return String(a) < String(b))
		out.append(component)
	out.sort_custom(func(a: Array, b: Array) -> bool:
		return String(a[0]) < String(b[0]))
	return out


static func _parent_table(nodes: Array) -> Dictionary:
	var parent: Dictionary = {}
	for value: Variant in nodes:
		var node := value as VillageCirculationNode
		parent[node.stable_key] = node.stable_key
	return parent


static func _find(parent: Dictionary, key: StringName) -> StringName:
	var root := key
	while parent[root] != root:
		root = parent[root]
	var cursor := key
	while parent[cursor] != cursor:
		var next: StringName = parent[cursor]
		parent[cursor] = root
		cursor = next
	return root


static func _union(parent: Dictionary, a: StringName,
		b: StringName) -> void:
	var root_a := _find(parent, a)
	var root_b := _find(parent, b)
	if root_a == root_b:
		return
	if String(root_a) < String(root_b):
		parent[root_b] = root_a
	else:
		parent[root_a] = root_b


static func _rejected(reason: StringName,
		plan: VillageCirculationPlan = null) -> VillageCirculationPlan:
	if plan == null:
		plan = VillageCirculationPlan.new()
	plan.reason = reason
	plan.accepted = false
	plan.nodes.clear()
	plan.links.clear()
	plan.platforms.clear()
	return plan
