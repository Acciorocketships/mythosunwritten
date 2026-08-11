class_name SettlementFabricSolver
extends RefCounted

## One transaction for authored or generated fabric records. The fixed visual
## proof supplies ordinary unit specs from its test fixture; future procedural
## route search will produce the same records and pass through this exact gate.
var _program: SettlementFabricProgram
var failure_reason := ""


func _init(program: SettlementFabricProgram) -> void:
	_program = program


func solve_authored(stable_id: StringName, specs: Array[Dictionary],
		requirements: Dictionary = {}) -> SettlementFabricPlan:
	return _solve(stable_id, null, specs, requirements)


func solve_sectional(stable_id: StringName, realm: SectionalPublicRealmPlan,
		specs: Array[Dictionary], requirements: Dictionary = {},
		embedding: StaggeredFabricEmbeddingPlan = null) \
		-> SettlementFabricPlan:
	return _solve(stable_id, realm, specs, requirements, embedding)


func _solve(stable_id: StringName, realm: SectionalPublicRealmPlan,
		specs: Array[Dictionary], requirements: Dictionary,
		embedding: StaggeredFabricEmbeddingPlan = null) \
		-> SettlementFabricPlan:
	failure_reason = ""
	if _program == null or stable_id.is_empty() or specs.is_empty() \
			or (realm != null and not realm.is_sealed()):
		failure_reason = "missing program, stable id, unit specs, or sealed public realm"
		return null
	var plan := SettlementFabricPlan.new(stable_id)
	if embedding != null and not plan.set_embedding_plan(embedding):
		failure_reason = "could not attach staggered embedding lineage"
		return null
	if realm != null and not plan.set_public_realm(realm):
		failure_reason = "could not attach sectional public realm"
		return null
	for recipe_value: FabricRecipe in _program.recipes():
		if not plan.register_recipe(recipe_value):
			failure_reason = "could not register recipe %s" % recipe_value.recipe_id
			return null
	for spec: Dictionary in specs:
		var unit_value := _unit_from_spec(spec)
		if unit_value == null:
			failure_reason = "invalid unit spec %s" % spec.get("stable_id", "<missing>")
			return null
		if not plan.add_unit(unit_value):
			if bool(spec.get("optional", false)):
				continue
			failure_reason = "rejected unit %s (%s): %s" % [unit_value.stable_id,
				unit_value.recipe_id, plan.last_rejection]
			return null
	var surface_plan := PublicRealmSurfaceSolver.solve(
		StringName("%s/surfaces" % stable_id), realm, plan)
	if surface_plan == null or not plan.set_surface_plan(surface_plan):
		failure_reason = "public-realm surface closure failed"
		return null
	if realm != null:
		var volume_plan := FabricVolumeClassifier.solve(
			StringName("%s/volumes" % stable_id), realm, plan)
		if volume_plan == null or not plan.set_volume_plan(volume_plan):
			failure_reason = "public-realm exterior proof failed: %s" % \
				FabricVolumeClassifier.last_failure
			return null
		var solid_void_plan := FabricSolidVoidClassifier.solve(
			StringName("%s/solid-void" % stable_id), realm, plan)
		if solid_void_plan == null or not plan.set_solid_void_plan(solid_void_plan):
			failure_reason = "solid/void classification failed: %s" % \
				FabricSolidVoidClassifier.last_failure
			return null
	var audit := audit_plan(plan)
	if not _meets_requirements(audit, requirements):
		failure_reason = "composition requirements not met: %s" % audit
		return null
	if not plan.seal(audit):
		failure_reason = "sealed-plan validation failed: %s" % plan.last_rejection
		return null
	return plan


static func unit_spec(stable_id: StringName, recipe_id: StringName,
		origin: Vector3i, yaw_quarters: int = 0,
		parents: Array[StringName] = [],
		bonds: Array[Dictionary] = [],
		public_node_id: StringName = &"",
		visual_seams: Array[StringName] = [], optional: bool = false) -> Dictionary:
	var copied_bonds: Array[Dictionary] = []
	for bond: Dictionary in bonds:
		copied_bonds.append(bond.duplicate())
	var copied_parents: Array[StringName] = []
	copied_parents.assign(parents)
	var copied_visual_seams: Array[StringName] = []
	copied_visual_seams.assign(visual_seams)
	return {
		"stable_id": stable_id,
		"recipe_id": recipe_id,
		"origin": origin,
		"yaw_quarters": yaw_quarters,
		"parents": copied_parents,
		"bonds": copied_bonds,
		"public_node_id": public_node_id,
		"visual_seams": copied_visual_seams,
		"optional": optional,
	}


static func _unit_from_spec(spec: Dictionary) -> FabricUnit:
	var stable_id := StringName(spec.get("stable_id", ""))
	var recipe_id := StringName(spec.get("recipe_id", ""))
	var origin := spec.get("origin", Vector3i()) as Vector3i
	var yaw_quarters := int(spec.get("yaw_quarters", -1))
	var parents: Array[StringName] = []
	for parent: Variant in spec.get("parents", []):
		parents.append(StringName(parent))
	var bonds: Array[Dictionary] = []
	for bond: Dictionary in spec.get("bonds", []):
		bonds.append(bond.duplicate())
	var public_node_id := StringName(spec.get("public_node_id", ""))
	var visual_seams: Array[StringName] = []
	for seam_value: Variant in spec.get("visual_seams", []):
		visual_seams.append(StringName(seam_value))
	var unit_value := FabricUnit.new(stable_id, recipe_id, origin,
		yaw_quarters, parents, bonds, public_node_id, visual_seams)
	return unit_value if unit_value.is_valid() else null


static func audit_plan(plan: SettlementFabricPlan,
		lineage_audit: Dictionary = {}) -> Dictionary:
	## Canonical audit for the final common transaction. Procedural front ends
	## may contribute source-lineage facts, but unit counts, reachability,
	## surfaces, stairs, and visual conflicts are always recomputed here from the
	## exact fabric that will be rendered and collided.
	assert(plan != null)
	var tag_counts: Dictionary = {}
	var market_recipes: Dictionary = {}
	var prefab_assets: Dictionary = {}
	var source_families: Dictionary = {}
	var skywalk_links: Dictionary = {}
	var route_cells := 0
	var unsupported_platforms := 0
	var unsupported_stairs := 0
	var platform_bearing_parents := 0
	for unit_value: FabricUnit in plan.units:
		var recipe_value := plan.recipe(unit_value.recipe_id)
		for tag: StringName in recipe_value.role_tags:
			tag_counts[tag] = int(tag_counts.get(tag, 0)) + 1
		if recipe_value.has_tag(&"route"):
			route_cells += recipe_value.walk_cells.size()
		if recipe_value.has_tag(&"themed_stall"):
			for asset_id: StringName in recipe_value.asset_ids():
				market_recipes[_market_family(asset_id)] = true
		if recipe_value.has_tag(&"prefab_anchor"):
			for asset_id: StringName in recipe_value.asset_ids():
				prefab_assets[asset_id] = true
				source_families[_source_family(asset_id)] = true
		if recipe_value.has_tag(&"skywalk"):
			var link_id := String(unit_value.stable_id)
			for component_suffix in [".arm-a", ".corner", ".arm-b"]:
				link_id = link_id.trim_suffix(component_suffix)
			skywalk_links[link_id] = true
		if recipe_value.has_tag(&"platform"):
			platform_bearing_parents += unit_value.parent_ids.size()
			if unit_value.parent_ids.size() < recipe_value.bearing_parent_count:
				unsupported_platforms += 1
		if recipe_value.has_tag(&"stair") \
				and unit_value.parent_ids.size() < recipe_value.bearing_parent_count:
			unsupported_stairs += 1
	var result := lineage_audit.duplicate(true)
	var connected_visual_conflicts := \
		plan.connected_visual_envelope_conflicts()
	result.merge({
		"unit_count": plan.units.size(),
		"route_cell_count": route_cells,
		"public_walk_unit_count": int(tag_counts.get(&"public_walk", 0)),
		"room_unit_count": int(tag_counts.get(&"room", 0)),
		"generated_building_count": int(tag_counts.get(&"generated_building", 0)),
		"prefab_anchor_count": int(tag_counts.get(&"prefab_anchor", 0)),
		"prefab_asset_count": prefab_assets.size(),
		"prefab_source_family_count": source_families.size(),
		"market_count": int(tag_counts.get(&"market", 0)),
		"market_family_count": market_recipes.size(),
		"outcropping_count": int(tag_counts.get(&"outcropping", 0)),
		"corner_outcropping_count": int(tag_counts.get(&"corner_outcropping", 0)),
		"skywalk_count": int(tag_counts.get(&"skywalk", 0)),
		"skywalk_link_count": skywalk_links.size(),
		"overhead_occupied_count": int(tag_counts.get(&"overhead_occupied", 0)),
		"stair_count": int(tag_counts.get(&"stair", 0)),
		"tent_count": 0,
		"isolated_platform_count": 0,
		"unsupported_platform_count": unsupported_platforms,
		"unsupported_stair_count": unsupported_stairs,
		"platform_bearing_parent_count": platform_bearing_parents,
		"visual_envelope_overlap_count": plan.visual_envelope_conflicts().size(),
		"connected_visual_envelope_conflict_count": \
			connected_visual_conflicts.size(),
		"connected_visual_envelope_conflicts": \
			connected_visual_conflicts.slice(0, mini(
				connected_visual_conflicts.size(), 24)),
	}, true)
	result.merge(_audit_route_shape(plan), true)
	result.merge(_audit_enclosure(plan), true)
	if plan.public_realm != null:
		result.merge(plan.public_realm.audit, true)
	if plan.surface_plan != null:
		result.merge(plan.surface_plan.audit(), true)
	if plan.public_realm != null and plan.surface_plan != null:
		result.merge(_audit_addressed_platform_terminals(plan), true)
		result.merge(_audit_building_reachability(plan), true)
	if plan.volume_plan != null:
		result.merge(plan.volume_plan.audit(), true)
	if plan.solid_void_plan != null:
		result.merge(plan.solid_void_plan.audit(), true)
	if plan.embedding_plan != null:
		result.merge(plan.embedding_plan.audit(), true)
	# Generated transition meshes are authoritative public stairs even though
	# they are not represented by authored stair FabricUnits.
	result["stair_count"] = maxi(int(result.get("stair_count", 0)),
		int(result.get("audited_stair_count", 0)))
	return result


static func _audit_building_reachability(plan: SettlementFabricPlan) \
		-> Dictionary:
	## A valid socket DAG can still leave a visually detached house: bearing
	## bonds prove gravity, not access. Collapse each vertical building stack,
	## then follow only occupied ROOM seams (including skywalks/outcroppings) to
	## a served exterior threshold. Every inhabited stack must reach one.
	var members_by_group: Dictionary = {}
	var group_by_unit: Dictionary = {}
	var room_adjacency: Dictionary = {}
	for unit_value: FabricUnit in plan.units:
		var recipe_value := plan.recipe(unit_value.recipe_id)
		if recipe_value.has_tag(&"room"):
			room_adjacency[unit_value.stable_id] = [] as Array[StringName]
		if not recipe_value.has_tag(&"generated_building") \
				and not recipe_value.has_tag(&"prefab_anchor"):
			continue
		var group_id := _building_group_id(unit_value.stable_id)
		group_by_unit[unit_value.stable_id] = group_id
		if not members_by_group.has(group_id):
			members_by_group[group_id] = [] as Array[StringName]
		(members_by_group[group_id] as Array[StringName]).append(
			unit_value.stable_id)
	# Storeys in one structural stack are one inhabited building even though the
	# future interior circulation has not been authored yet.
	for group_value: Variant in members_by_group:
		var members := members_by_group[group_value] as Array[StringName]
		for left_index in members.size():
			if not room_adjacency.has(members[left_index]):
				continue
			for right_index in range(left_index + 1, members.size()):
				if room_adjacency.has(members[right_index]):
					_add_room_edge(room_adjacency, members[left_index],
						members[right_index])
	for unit_value: FabricUnit in plan.units:
		if not room_adjacency.has(unit_value.stable_id):
			continue
		var recipe_value := plan.recipe(unit_value.recipe_id)
		for bond: Dictionary in unit_value.socket_bonds:
			var own_socket := recipe_value.socket(StringName(bond.own_socket))
			var target_id := StringName(bond.target_unit)
			var target_unit := plan.unit(target_id)
			if own_socket.is_empty() or target_unit == null \
					or not room_adjacency.has(target_id) \
					or int(own_socket.kind) != FabricRecipe.SocketKind.ROOM:
				continue
			var target_recipe := plan.recipe(target_unit.recipe_id)
			var target_socket := target_recipe.socket(
				StringName(bond.target_socket))
			if not target_socket.is_empty() and int(target_socket.kind) == \
					FabricRecipe.SocketKind.ROOM:
				_add_room_edge(room_adjacency, unit_value.stable_id, target_id)
	var served_units: Dictionary = {}
	for entrance: Dictionary in plan.surface_plan.entrance_records:
		if bool(entrance.served):
			served_units[StringName(entrance.unit_id)] = true
	var detached := 0
	for group_value: Variant in members_by_group:
		var reached := false
		var seen: Dictionary = {}
		var frontier: Array[StringName] = []
		for member: StringName in members_by_group[group_value] as Array[StringName]:
			if room_adjacency.has(member):
				frontier.append(member)
				seen[member] = true
		while not frontier.is_empty() and not reached:
			var current: StringName = frontier.pop_back()
			if served_units.has(current):
				reached = true
				break
			for neighbor: StringName in room_adjacency.get(current,
					[] as Array[StringName]) as Array[StringName]:
				if not seen.has(neighbor):
					seen[neighbor] = true
					frontier.append(neighbor)
		if not reached:
			detached += 1
	return {
		"building_stack_count": members_by_group.size(),
		"connected_building_stack_count": members_by_group.size() - detached,
		"detached_building_stack_count": detached,
	}


static func _add_room_edge(adjacency: Dictionary, left: StringName,
		right: StringName) -> void:
	var left_edges := adjacency[left] as Array[StringName]
	var right_edges := adjacency[right] as Array[StringName]
	if not left_edges.has(right):
		left_edges.append(right)
	if not right_edges.has(left):
		right_edges.append(left)


static func _building_group_id(unit_id: StringName) -> StringName:
	var text := String(unit_id)
	var cut := text.length()
	for marker in [".base", ".upper.", ".roof"]:
		var found := text.find(marker)
		if found >= 0:
			cut = mini(cut, found)
	return StringName(text.substr(0, cut))


static func _audit_addressed_platform_terminals(plan: SettlementFabricPlan) \
		-> Dictionary:
	## A public platform with one circulation edge is not an ornamental dead end
	## when it is the forecourt of an inhabited doorway. The earlier graph-only
	## audit could not see thresholds because entrances are compiled with the
	## final surface union. Reconcile the two facts here, after both are frozen.
	var served_landings: Dictionary = {}
	for entrance: Dictionary in plan.surface_plan.entrance_records:
		if bool(entrance.served):
			served_landings[entrance.landing_cell as Vector3i] = true
	var incident_counts: Dictionary = {}
	for node_value: PublicRealmNode in plan.public_realm.nodes:
		incident_counts[node_value.stable_id] = 0
	for edge_value: PublicRealmEdge in plan.public_realm.edges:
		incident_counts[edge_value.from_node_id] = int(
			incident_counts.get(edge_value.from_node_id, 0)) + 1
		incident_counts[edge_value.to_node_id] = int(
			incident_counts.get(edge_value.to_node_id, 0)) + 1
	var platform_count := 0
	var addressed_terminals := 0
	var journey_terminals := 0
	var dead_ends := 0
	var journey_terminal_id := StringName()
	if plan.public_realm != null \
			and not plan.public_realm.primary_itinerary.is_empty():
		journey_terminal_id = plan.public_realm.primary_itinerary.back()
	for node_value: PublicRealmNode in plan.public_realm.nodes:
		if node_value.surface_kind != \
				PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT:
			continue
		platform_count += 1
		if int(incident_counts.get(node_value.stable_id, 0)) >= 2:
			continue
		# The final node of the sealed primary journey is a typed destination,
		# not an ornamental shelf.  It may terminate in an elevated court; every
		# other one-edge platform must still address an inhabited threshold.
		if node_value.stable_id == journey_terminal_id:
			journey_terminals += 1
			continue
		var addressed := false
		for cell: Vector3i in node_value.surface_cells:
			if served_landings.has(cell):
				addressed = true
				break
		if addressed:
			addressed_terminals += 1
		else:
			dead_ends += 1
	return {
		"audited_platform_count": platform_count,
		"addressed_platform_terminal_count": addressed_terminals,
		"primary_journey_platform_terminal_count": journey_terminals,
		"platform_dead_end_count": dead_ends,
	}


static func _meets_requirements(audit: Dictionary,
		requirements: Dictionary) -> bool:
	return requirement_failures(audit, requirements).is_empty()


static func requirement_failures(audit: Dictionary,
		requirements: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	for key: Variant in requirements:
		var metric := StringName(key)
		if not audit.has(metric):
			failures.append("%s is missing" % metric)
			continue
		var rule: Variant = requirements[key]
		if rule is Dictionary:
			if rule.has("min") and float(audit[metric]) < float(rule.min):
				failures.append("%s=%s is below %s" % [metric,
					audit[metric], rule.min])
			if rule.has("max") and float(audit[metric]) > float(rule.max):
				failures.append("%s=%s exceeds %s" % [metric,
					audit[metric], rule.max])
			if rule.has("equals") and audit[metric] != rule.equals:
				failures.append("%s=%s does not equal %s" % [metric,
					audit[metric], rule.equals])
		elif float(audit[metric]) < float(rule):
			failures.append("%s=%s is below %s" % [metric, audit[metric], rule])
	return failures


static func _audit_route_shape(plan: SettlementFabricPlan) -> Dictionary:
	var route_ids: Dictionary = {}
	var adjacency: Dictionary = {}
	var landing_id := StringName()
	for unit_value: FabricUnit in plan.units:
		var recipe_value := plan.recipe(unit_value.recipe_id)
		if not recipe_value.has_tag(&"route"):
			continue
		route_ids[unit_value.stable_id] = unit_value
		adjacency[unit_value.stable_id] = []
		if recipe_value.has_tag(&"route_landing"):
			landing_id = unit_value.stable_id
	for unit_value: FabricUnit in plan.units:
		if not route_ids.has(unit_value.stable_id):
			continue
		var recipe_value := plan.recipe(unit_value.recipe_id)
		for bond: Dictionary in unit_value.socket_bonds:
			var own_socket := recipe_value.socket(StringName(bond.own_socket))
			var target_id := StringName(bond.target_unit)
			if own_socket.is_empty() \
					or int(own_socket.kind) != FabricRecipe.SocketKind.WALK \
					or not route_ids.has(target_id):
				continue
			(adjacency[unit_value.stable_id] as Array).append(target_id)
			(adjacency[target_id] as Array).append(unit_value.stable_id)
	var ordered := _longest_route_from_landing(landing_id, adjacency)
	var max_straight_cells := 0.0
	var max_level_cells := 0.0
	var straight_cells := 0.0
	var level_cells := 0.0
	var previous_direction := Vector3i.ZERO
	var elevation_signs: Array[int] = []
	var elevation_changes := 0
	for index in range(1, ordered.size()):
		var previous := route_ids[ordered[index - 1]] as FabricUnit
		var current := route_ids[ordered[index]] as FabricUnit
		var delta := current.lattice_origin - previous.lattice_origin
		var horizontal := Vector3i(delta.x, 0, delta.z)
		var direction := Vector3i(signi(horizontal.x), 0, signi(horizontal.z))
		var distance := Vector2(horizontal.x, horizontal.z).length()
		if previous_direction == Vector3i.ZERO or direction == previous_direction:
			straight_cells += distance
		else:
			max_straight_cells = maxf(max_straight_cells, straight_cells)
			straight_cells = distance
		previous_direction = direction
		if delta.y == 0:
			level_cells += distance
		else:
			max_level_cells = maxf(max_level_cells, level_cells)
			level_cells = 0.0
			elevation_changes += 1
			var elevation_sign := signi(delta.y)
			if elevation_signs.is_empty() or elevation_signs.back() != elevation_sign:
				elevation_signs.append(elevation_sign)
	max_straight_cells = maxf(max_straight_cells, straight_cells)
	max_level_cells = maxf(max_level_cells, level_cells)
	return {
		"main_route_unit_count": ordered.size(),
		"max_straight_run_m": max_straight_cells * FabricRecipe.CELL_SIZE,
		"max_constant_elevation_run_m": max_level_cells * FabricRecipe.CELL_SIZE,
		"elevation_change_count": elevation_changes,
		"has_up_down_up": _contains_sign_sequence(elevation_signs, [1, -1, 1]),
	}


static func _longest_route_from_landing(landing_id: StringName,
		adjacency: Dictionary) -> Array[StringName]:
	if landing_id.is_empty() or not adjacency.has(landing_id):
		return []
	var parents: Dictionary = {landing_id: StringName()}
	var distance: Dictionary = {landing_id: 0}
	var pending: Array[StringName] = [landing_id]
	var farthest := landing_id
	while not pending.is_empty():
		var current: StringName = pending.pop_front()
		for neighbor: StringName in adjacency[current] as Array:
			if parents.has(neighbor):
				continue
			parents[neighbor] = current
			distance[neighbor] = int(distance[current]) + 1
			pending.append(neighbor)
			if int(distance[neighbor]) > int(distance[farthest]) \
					or (distance[neighbor] == distance[farthest] \
					and String(neighbor) < String(farthest)):
				farthest = neighbor
	var reverse_path: Array[StringName] = []
	var cursor := farthest
	while not cursor.is_empty():
		reverse_path.append(cursor)
		cursor = parents[cursor] as StringName
	reverse_path.reverse()
	return reverse_path


static func _contains_sign_sequence(values: Array[int], sequence: Array[int]) -> bool:
	if sequence.is_empty() or values.size() < sequence.size():
		return false
	for start in range(values.size() - sequence.size() + 1):
		var matches := true
		for offset in sequence.size():
			if values[start + offset] != sequence[offset]:
				matches = false
				break
		if matches:
			return true
	return false


static func _audit_enclosure(plan: SettlementFabricPlan) -> Dictionary:
	var route_walk: Dictionary = {}
	var ground_route_walk: Dictionary = {}
	# Match the construction obligation exactly. Courts, approach landings, and
	# short bridges may expose a guarded edge; counting those as failed facade
	# canyons made the metric disagree with both the grammar and the screenshot.
	# The remaining cells are the actual maze corridor and must be bounded.
	if plan.public_realm != null:
		for node_value: PublicRealmNode in plan.public_realm.nodes:
			if node_value.is_landing \
					or node_value.episode_kind == PublicRealmNode.EpisodeKind.COURT \
					or node_value.episode_kind == PublicRealmNode.EpisodeKind.TERRACE \
					or node_value.episode_kind == PublicRealmNode.EpisodeKind.SHORT_BRIDGE:
				continue
			for cell: Vector3i in node_value.surface_cells:
				route_walk[cell] = node_value.stable_id
				if node_value.surface_kind == \
						PublicRealmSurfacePlan.SurfaceKind.TERRAIN_STREET:
					ground_route_walk[cell] = node_value.stable_id
	else:
		route_walk = plan.transformed_cells(&"walk", &"route")
		ground_route_walk = route_walk.duplicate()
	var occluders := plan.transformed_cells(&"occluder")
	var occupied_overhead: Dictionary = {}
	for unit_value: FabricUnit in plan.units:
		var recipe_value := plan.recipe(unit_value.recipe_id)
		if not recipe_value.has_tag(&"room"):
			continue
		for local_cell: Vector3i in recipe_value.occluder_cells:
			var cell := FabricRecipe.transform_cell(local_cell,
				unit_value.lattice_origin, unit_value.yaw_quarters)
			occupied_overhead[cell] = unit_value.stable_id
	var eligible_sides := 0
	var enclosed_sides := 0
	var overhead_cells := 0
	var covered_route: Dictionary = {}
	var cardinal_sides: Array[Vector3i] = [
		Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK,
	]
	for cell_value: Variant in route_walk:
		var cell := cell_value as Vector3i
		for side: Vector3i in cardinal_sides:
			var neighbor: Vector3i = cell + side
			if route_walk.has(neighbor):
				continue
			eligible_sides += 1
			if occluders.has(neighbor) or occluders.has(neighbor + Vector3i.UP):
				enclosed_sides += 1
		var covered := false
		for rise in range(2, 7):
			var above := cell + Vector3i(0, rise, 0)
			if occupied_overhead.has(above) \
					or (plan.surface_plan != null \
						and plan.surface_plan.has_cell(above)):
				covered = true
				break
		if covered:
			overhead_cells += 1
			covered_route[cell] = true
	var frontage_ratio := float(enclosed_sides) / float(maxi(1, eligible_sides))
	var overhead_ratio := float(overhead_cells) / float(maxi(1, route_walk.size()))
	var uncovered_components := _uncovered_route_components(
		route_walk, covered_route)
	var sightline := _audit_sightlines(route_walk, occluders)
	# Keep the hostile lower-street test separate from the aggregate. Dense upper
	# galleries can contribute many short open rays while the user's actual bad-
	# maze failure is a ground corridor with daylight at both ends. Selection can
	# now reject that precise failure without manufacturing a freestanding prop or
	# overfilling legitimate guarded upper courts.
	var ground_sightline := _audit_sightlines(ground_route_walk, occluders)
	return {
		"eligible_frontage_side_count": eligible_sides,
		"enclosed_frontage_side_count": enclosed_sides,
		"frontage_ratio": frontage_ratio,
		"overhead_route_cell_count": overhead_cells,
		"overhead_route_ratio": overhead_ratio,
		"uncovered_route_component_count": uncovered_components.count,
		"max_uncovered_route_component_size": uncovered_components.maximum,
		"max_uncovered_route_component_cells": uncovered_components.cells,
		"max_sightline_m": sightline.max_cells * FabricRecipe.CELL_SIZE,
		"through_sightline_count": sightline.through_count,
		"ground_max_sightline_m": ground_sightline.max_cells \
			* FabricRecipe.CELL_SIZE,
		"ground_through_sightline_count": ground_sightline.through_count,
	}


static func _uncovered_route_components(route_walk: Dictionary,
		covered_route: Dictionary) -> Dictionary:
	## A ratio alone can hide the objectionable case: most of a route may be
	## covered while one continuous lower street remains open from the roofs to
	## natural ground. Measure those holes as connected same-level components so
	## selection can prefer several short courtyards over one broad shaft.
	var remaining: Dictionary = {}
	for cell_value: Variant in route_walk:
		var cell := cell_value as Vector3i
		if not covered_route.has(cell):
			remaining[cell] = true
	var count := 0
	var maximum := 0
	var maximum_cells := PackedStringArray()
	var cardinal_sides: Array[Vector3i] = [
		Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK,
	]
	while not remaining.is_empty():
		count += 1
		var start: Vector3i = remaining.keys()[0] as Vector3i
		remaining.erase(start)
		var frontier: Array[Vector3i] = [start]
		var component_size := 0
		var component_cells := PackedStringArray()
		while not frontier.is_empty():
			var current: Vector3i = frontier.pop_back()
			component_size += 1
			component_cells.append("%d:%d:%d" % [
				current.x, current.y, current.z])
			for direction: Vector3i in cardinal_sides:
				var neighbor: Vector3i = current + direction
				if remaining.erase(neighbor):
					frontier.append(neighbor)
		component_cells.sort()
		if component_size > maximum:
			maximum = component_size
			maximum_cells = component_cells
	return {"count": count, "maximum": maximum, "cells": maximum_cells}


static func _audit_sightlines(route_walk: Dictionary,
		occluders: Dictionary) -> Dictionary:
	## A see-through failure is a chord through the town, not any view from an
	## edge street toward the surrounding landscape. The former one-sided ray
	## counted every outward-facing perimeter sample as a tunnel through the
	## core, making zero impossible even for a closed maze. Test undirected eye-
	## height chords: both halves must escape the occupied core without hitting
	## substantial building mass. This still catches the user's bad-maze case—a
	## corridor visible from one boundary to the opposite boundary—without
	## rewarding a fake freestanding blocker or demanding a windowless city.
	if route_walk.is_empty():
		return {"max_cells": 0.0, "through_count": 0}
	var minimum := Vector2i(2147483647, 2147483647)
	var maximum := Vector2i(-2147483648, -2147483648)
	for cell_value: Variant in route_walk:
		var cell := cell_value as Vector3i
		minimum.x = mini(minimum.x, cell.x)
		minimum.y = mini(minimum.y, cell.z)
		maximum.x = maxi(maximum.x, cell.x)
		maximum.y = maxi(maximum.y, cell.z)
	minimum -= Vector2i(4, 4)
	maximum += Vector2i(4, 4)
	var max_cells := 0.0
	var through_count := 0
	for cell_value: Variant in route_walk:
		var start_cell := cell_value as Vector3i
		var start := Vector2(start_cell.x + 0.5, start_cell.z + 0.5)
		for ray_index in 12:
			var direction := Vector2.RIGHT.rotated(PI * float(ray_index) / 12.0)
			var forward := _ray_to_core_boundary(start, direction, start_cell.y + 1,
				minimum, maximum, occluders)
			var backward := _ray_to_core_boundary(start, -direction,
				start_cell.y + 1, minimum, maximum, occluders)
			var forward_hit := bool(forward.hit)
			var backward_hit := bool(backward.hit)
			var visible_span := float(forward.distance) + float(backward.distance) \
				if forward_hit == backward_hit else float(forward.distance) \
				if forward_hit else float(backward.distance) if backward_hit else 0.0
			max_cells = maxf(max_cells, visible_span)
			if not forward_hit and not backward_hit \
					and float(forward.distance) + float(backward.distance) >= 8.0:
				through_count += 1
	return {"max_cells": max_cells, "through_count": through_count}


static func _ray_to_core_boundary(start: Vector2, direction: Vector2,
		eye_y: int, minimum: Vector2i, maximum: Vector2i,
		occluders: Dictionary) -> Dictionary:
	var distance := 0.25
	while distance <= 32.0:
		var sample := start + direction * distance
		var sample_xz := Vector2i(floori(sample.x), floori(sample.y))
		if sample_xz.x < minimum.x or sample_xz.x > maximum.x \
				or sample_xz.y < minimum.y or sample_xz.y > maximum.y:
			return {"distance": distance, "hit": false}
		if occluders.has(Vector3i(sample_xz.x, eye_y, sample_xz.y)):
			return {"distance": distance, "hit": true}
		distance += 0.25
	return {"distance": distance, "hit": false}


static func _source_family(asset_id: StringName) -> StringName:
	var value := String(asset_id)
	if value.begins_with("sfv."):
		return &"fantasy_village"
	if value.begins_with("aws."):
		return &"alchemy"
	if value.begins_with("sft."):
		return &"tavern"
	if value.begins_with("sffa."):
		return &"forge"
	return &"other"


static func _market_family(asset_id: StringName) -> StringName:
	var parts := String(asset_id).split(".")
	return StringName(parts[2]) if parts.size() >= 4 else asset_id
