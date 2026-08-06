class_name SectionalPublicRealmBuilder
extends RefCounted

## Authored-proof adapter that derives explicit episode cells and seams from
## ordinary unit specs. Production embedding will emit the same plan directly.
static var last_failure := ""


static func from_specs(stable_id: StringName, program: SettlementFabricProgram,
		specs: Array[Dictionary], primary_ids: Array[StringName],
		episode_overrides: Dictionary = {}, cover_overrides: Dictionary = {}) \
		-> SectionalPublicRealmPlan:
	last_failure = ""
	if stable_id.is_empty() or program == null or specs.is_empty() \
			or primary_ids.size() < 2:
		last_failure = "missing builder input"
		return null
	var spec_by_id: Dictionary = {}
	var public_ids: Dictionary = {}
	for spec: Dictionary in specs:
		var unit_id := StringName(spec.get("stable_id", ""))
		var recipe_value := program.recipe(StringName(spec.get("recipe_id", "")))
		if unit_id.is_empty() or recipe_value == null or spec_by_id.has(unit_id):
			last_failure = "invalid or duplicate spec %s" % unit_id
			return null
		spec_by_id[unit_id] = spec
		if recipe_value.has_tag(&"public_walk"):
			if recipe_value.has_tag(&"interior_walk"):
				last_failure = "interior-walk recipe %s cannot enter exterior realm" % \
					recipe_value.recipe_id
				return null
			public_ids[unit_id] = true
	for node_id: StringName in primary_ids:
		if not public_ids.has(node_id):
			last_failure = "primary node %s is not a public unit" % node_id
			return null
	var node_cells: Dictionary = {}
	var node_air_cells: Dictionary = {}
	var cell_owner: Dictionary = {}
	var blocked_cells: Dictionary = {}
	for spec: Dictionary in specs:
		var recipe_value := program.recipe(StringName(spec.recipe_id))
		for local_cell: Vector3i in recipe_value.solid_cells:
			var world_cell := FabricRecipe.transform_cell(local_cell,
				spec.origin as Vector3i, int(spec.yaw_quarters))
			blocked_cells[_cell_key(world_cell)] = StringName(spec.stable_id)
	for unit_id_value: Variant in public_ids:
		var unit_id := unit_id_value as StringName
		var spec := spec_by_id[unit_id] as Dictionary
		var recipe_value := program.recipe(StringName(spec.recipe_id))
		var cells := _transformed_walk_cells(recipe_value, spec)
		node_cells[unit_id] = cells
		node_air_cells[unit_id] = _transformed_public_air_cells(recipe_value, spec)
		for cell: Vector3i in cells:
			var cell_key := _cell_key(cell)
			if cell_owner.has(cell_key):
				last_failure = "public units %s and %s overlap at %s" % [
					cell_owner[cell_key], unit_id, cell]
				return null
			cell_owner[cell_key] = unit_id
	var edge_pairs: Dictionary = {}
	for spec: Dictionary in specs:
		var unit_id := StringName(spec.stable_id)
		if not public_ids.has(unit_id):
			continue
		var recipe_value := program.recipe(StringName(spec.recipe_id))
		for bond: Dictionary in spec.get("bonds", []):
			var own_socket := recipe_value.socket(StringName(bond.own_socket))
			var target_id := StringName(bond.target_unit)
			if own_socket.is_empty() \
					or int(own_socket.kind) != FabricRecipe.SocketKind.WALK \
					or not public_ids.has(target_id):
				continue
			var pair_key := _pair_key(unit_id, target_id)
			if edge_pairs.has(pair_key):
				continue
			edge_pairs[pair_key] = {"from": target_id, "to": unit_id}
	var pair_keys: Array[String] = []
	pair_keys.assign(edge_pairs.keys())
	pair_keys.sort()
	for pair_key: String in pair_keys:
		var pair := edge_pairs[pair_key] as Dictionary
		var from_id := StringName(pair.from)
		var to_id := StringName(pair.to)
		var from_cells := node_cells[from_id] as Array[Vector3i]
		var to_cells := node_cells[to_id] as Array[Vector3i]
		var seams := _disjoint_lane_seams(_adjacent_seams(from_cells, to_cells))
		if seams.size() == 1 and _widen_seam(from_id, to_id, from_cells,
				to_cells, seams[0] as Dictionary, cell_owner, blocked_cells):
			seams = _disjoint_lane_seams(_adjacent_seams(from_cells, to_cells))
		if seams.size() < 2:
			last_failure = "edge %s -> %s has only %d lane seams: %s" % [from_id,
				to_id, seams.size(), seams]
			return null
	for unit_id_value: Variant in public_ids:
		var unit_id := unit_id_value as StringName
		if not _ensure_surface_headroom(node_cells[unit_id] as Array[Vector3i],
				node_air_cells[unit_id] as Array[Vector3i], blocked_cells):
			last_failure = "public unit %s has blocked or incomplete exterior headroom" % \
				unit_id
			return null
	var realm := SectionalPublicRealmPlan.new(stable_id)
	for unit_id_value: Variant in public_ids:
		var unit_id := unit_id_value as StringName
		var spec := spec_by_id[unit_id] as Dictionary
		var recipe_value := program.recipe(StringName(spec.recipe_id))
		var cells := node_cells[unit_id] as Array[Vector3i]
		var air_cells := node_air_cells[unit_id] as Array[Vector3i]
		var primary_index := primary_ids.find(unit_id)
		var entry_y := _minimum_y(cells)
		var exit_y := entry_y
		if primary_index >= 0:
			if primary_index > 0:
				entry_y = _portal_y(unit_id, primary_ids[primary_index - 1],
					spec_by_id, program, entry_y)
			if primary_index + 1 < primary_ids.size():
				exit_y = _portal_y(unit_id, primary_ids[primary_index + 1],
					spec_by_id, program, entry_y)
			else:
				exit_y = entry_y
		var episode_kind := int(episode_overrides.get(unit_id,
			_default_episode_kind(recipe_value)))
		var cover_policy := int(cover_overrides.get(unit_id,
			_default_cover_policy(episode_kind)))
		var node_value := PublicRealmNode.new(unit_id, episode_kind,
			_surface_kind(recipe_value), PublicRealmNode.AirRealm.EXTERIOR,
			cover_policy, cells, air_cells, entry_y, exit_y, true,
			recipe_value.has_tag(&"route_landing"))
		if not node_value.seal() or not realm.add_node(node_value):
			last_failure = "node %s rejected: %s" % [unit_id,
				realm.last_rejection]
			return null
	for pair_key: String in pair_keys:
		var pair := edge_pairs[pair_key] as Dictionary
		var from_id := StringName(pair.from)
		var to_id := StringName(pair.to)
		var from_node := realm.node(from_id)
		var to_node := realm.node(to_id)
		var seams := _disjoint_lane_seams(_adjacent_seams(
			from_node.surface_cells, to_node.surface_cells))
		var edge_value := PublicRealmEdge.new(
			StringName("edge.%s.%s" % [from_id, to_id]), from_id, to_id,
			_transition_kind(from_node, to_node),
			_are_consecutive(from_id, to_id, primary_ids))
		for seam: Dictionary in seams:
			edge_value.add_seam(seam.from_cell as Vector3i,
				seam.to_cell as Vector3i)
		if not realm.add_edge(edge_value):
			last_failure = "could not add edge %s -> %s" % [from_id, to_id]
			return null
	realm.set_primary_itinerary(primary_ids)
	for node_value: PublicRealmNode in realm.nodes:
		for cell: Vector3i in node_value.surface_cells:
			realm.require_classification(cell)
	for spec: Dictionary in specs:
		var recipe_value := program.recipe(StringName(spec.recipe_id))
		for local_cell: Vector3i in recipe_value.daylight_void_cells:
			var cell := FabricRecipe.transform_cell(local_cell,
				spec.origin as Vector3i, int(spec.yaw_quarters))
			realm.add_daylight_void(cell)
			realm.require_classification(cell)
	if not realm.seal():
		last_failure = realm.last_rejection
		return null
	return realm


static func bind_specs(specs: Array[Dictionary], program: SettlementFabricProgram) \
		-> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for source: Dictionary in specs:
		var spec := source.duplicate(true)
		var recipe_value := program.recipe(StringName(spec.get("recipe_id", "")))
		if recipe_value != null and recipe_value.has_tag(&"public_walk"):
			spec["public_node_id"] = StringName(spec.stable_id)
		out.append(spec)
	return out


static func _portal_y(unit_id: StringName, neighbor_id: StringName,
		spec_by_id: Dictionary, program: SettlementFabricProgram,
		fallback: int) -> int:
	var own_spec := spec_by_id[unit_id] as Dictionary
	var own_recipe := program.recipe(StringName(own_spec.recipe_id))
	for bond: Dictionary in own_spec.get("bonds", []):
		if StringName(bond.target_unit) != neighbor_id:
			continue
		var socket := own_recipe.socket(StringName(bond.own_socket))
		if not socket.is_empty() \
				and int(socket.kind) == FabricRecipe.SocketKind.WALK:
			return FabricRecipe.transform_cell(socket.cell as Vector3i,
				own_spec.origin as Vector3i, int(own_spec.yaw_quarters)).y
	var neighbor_spec := spec_by_id[neighbor_id] as Dictionary
	for bond: Dictionary in neighbor_spec.get("bonds", []):
		if StringName(bond.target_unit) != unit_id:
			continue
		var target_socket := own_recipe.socket(StringName(bond.target_socket))
		if not target_socket.is_empty() \
				and int(target_socket.kind) == FabricRecipe.SocketKind.WALK:
			return FabricRecipe.transform_cell(target_socket.cell as Vector3i,
				own_spec.origin as Vector3i, int(own_spec.yaw_quarters)).y
	return fallback


static func _transformed_walk_cells(recipe_value: FabricRecipe,
		spec: Dictionary) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for local_cell: Vector3i in recipe_value.walk_cells:
		out.append(FabricRecipe.transform_cell(local_cell,
			spec.origin as Vector3i, int(spec.yaw_quarters)))
	return out


static func _transformed_public_air_cells(recipe_value: FabricRecipe,
		spec: Dictionary) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for local_cell: Vector3i in recipe_value.public_air_cells:
		out.append(FabricRecipe.transform_cell(local_cell,
			spec.origin as Vector3i, int(spec.yaw_quarters)))
	return out


static func _ensure_surface_headroom(surface_cells: Array[Vector3i],
		air_cells: Array[Vector3i], blocked_cells: Dictionary) -> bool:
	var air_set: Dictionary = {}
	for cell: Vector3i in air_cells:
		air_set[_cell_key(cell)] = true
	for surface_cell: Vector3i in surface_cells:
		for air_cell: Vector3i in [surface_cell, surface_cell + Vector3i.UP]:
			var key := _cell_key(air_cell)
			if blocked_cells.has(key):
				if OS.get_environment("WARREN_ROUTE_DEBUG") == "1":
					print("[warren-route] blocked public air %s by %s" % [
						air_cell, blocked_cells[key]])
				return false
			if not air_set.has(key):
				air_cells.append(air_cell)
				air_set[key] = true
	return true


static func _adjacent_seams(from_cells: Array[Vector3i],
		to_cells: Array[Vector3i]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for from_cell: Vector3i in from_cells:
		for to_cell: Vector3i in to_cells:
			var horizontal := absi(from_cell.x - to_cell.x) \
				+ absi(from_cell.z - to_cell.z)
			if horizontal == 1 and absi(from_cell.y - to_cell.y) <= 1:
				out.append({"from_cell": from_cell, "to_cell": to_cell})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_cell := a.from_cell as Vector3i
		var b_cell := b.from_cell as Vector3i
		if a_cell.y != b_cell.y:
			return a_cell.y < b_cell.y
		if a_cell.z != b_cell.z:
			return a_cell.z < b_cell.z
		return a_cell.x < b_cell.x)
	return out


static func _disjoint_lane_seams(candidates: Array[Dictionary]) \
		-> Array[Dictionary]:
	## Corners can touch the widened two-lane forecourt along a short T. All
	## geometric adjacencies are real, but an edge seam is a one-to-one lane
	## mapping: retaining the T's third cross-edge makes one lane appear twice
	## and PublicRealmEdge correctly rejects it. Stable candidate ordering makes
	## this maximal non-branching selection deterministic.
	var out: Array[Dictionary] = []
	var used_from: Dictionary = {}
	var used_to: Dictionary = {}
	for seam: Dictionary in candidates:
		var from_key := _cell_key(seam.from_cell as Vector3i)
		var to_key := _cell_key(seam.to_cell as Vector3i)
		if used_from.has(from_key) or used_to.has(to_key):
			continue
		used_from[from_key] = true
		used_to[to_key] = true
		out.append(seam)
	return out


static func _widen_seam(from_id: StringName, to_id: StringName,
		from_cells: Array[Vector3i], to_cells: Array[Vector3i],
		seam: Dictionary, cell_owner: Dictionary,
		blocked_cells: Dictionary) -> bool:
	## A public portal is two cells wide even when the authored module socket is
	## represented by one centre-line cell. Claim the matching forecourt cell on
	## both sides here, before nodes are sealed, so every downstream consumer sees
	## the real traversable opening instead of carrying a one-off narrow seam.
	var from_cell := seam.from_cell as Vector3i
	var to_cell := seam.to_cell as Vector3i
	var delta := to_cell - from_cell
	var first_perpendicular := Vector3i(delta.z, 0, -delta.x)
	for perpendicular: Vector3i in [first_perpendicular, -first_perpendicular]:
		var widened_from := from_cell + perpendicular
		var widened_to := to_cell + perpendicular
		if blocked_cells.has(_cell_key(widened_from)) \
				or blocked_cells.has(_cell_key(widened_to)):
			continue
		var from_owner: StringName = cell_owner.get(_cell_key(widened_from),
			StringName()) as StringName
		var to_owner: StringName = cell_owner.get(_cell_key(widened_to),
			StringName()) as StringName
		if not from_owner.is_empty() and from_owner != from_id:
			continue
		if not to_owner.is_empty() and to_owner != to_id:
			continue
		if from_owner.is_empty():
			from_cells.append(widened_from)
			cell_owner[_cell_key(widened_from)] = from_id
		if to_owner.is_empty():
			to_cells.append(widened_to)
			cell_owner[_cell_key(widened_to)] = to_id
		return true
	return false


static func _default_episode_kind(recipe_value: FabricRecipe) -> int:
	if recipe_value.has_tag(&"stair"):
		return PublicRealmNode.EpisodeKind.STAIR_CANYON
	if recipe_value.has_tag(&"elevated_deck_route"):
		return PublicRealmNode.EpisodeKind.EXTERIOR_GALLERY
	if recipe_value.has_tag(&"structural_court"):
		return PublicRealmNode.EpisodeKind.COURT
	if recipe_value.has_tag(&"gallery"):
		return PublicRealmNode.EpisodeKind.EXTERIOR_GALLERY
	if recipe_value.has_tag(&"open_bridge"):
		return PublicRealmNode.EpisodeKind.SHORT_BRIDGE
	return PublicRealmNode.EpisodeKind.STREET


static func _default_cover_policy(episode_kind: int) -> int:
	if episode_kind == PublicRealmNode.EpisodeKind.UNDERCROFT:
		return PublicRealmNode.CoverPolicy.COVERED
	return PublicRealmNode.CoverPolicy.OPEN


static func _surface_kind(recipe_value: FabricRecipe) -> int:
	if recipe_value.has_tag(&"stair"):
		return PublicRealmSurfacePlan.SurfaceKind.STAIR
	if recipe_value.has_tag(&"open_bridge"):
		return PublicRealmSurfacePlan.SurfaceKind.BRIDGE
	if recipe_value.has_tag(&"structural_court") \
			or recipe_value.has_tag(&"platform"):
		return PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT
	return PublicRealmSurfacePlan.SurfaceKind.TERRAIN_STREET


static func _transition_kind(from_node: PublicRealmNode,
		to_node: PublicRealmNode) -> int:
	if from_node.primary_exit_y == to_node.primary_entry_y:
		return PublicRealmEdge.TransitionKind.LEVEL
	return PublicRealmEdge.TransitionKind.HALF_STAIR


static func _are_consecutive(a: StringName, b: StringName,
		primary_ids: Array[StringName]) -> bool:
	var a_index := primary_ids.find(a)
	var b_index := primary_ids.find(b)
	return a_index >= 0 and b_index >= 0 and absi(a_index - b_index) == 1


static func _minimum_y(cells: Array[Vector3i]) -> int:
	var result := 2147483647
	for cell: Vector3i in cells:
		result = mini(result, cell.y)
	return result


static func _pair_key(a: StringName, b: StringName) -> String:
	return "%s|%s" % [a, b] if String(a) < String(b) else "%s|%s" % [b, a]


static func _cell_key(cell: Vector3i) -> String:
	return "%d:%d:%d" % [cell.x, cell.y, cell.z]
