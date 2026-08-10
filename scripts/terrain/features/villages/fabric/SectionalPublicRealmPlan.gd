class_name SectionalPublicRealmPlan
extends RefCounted

## Immutable topology for one continuous three-dimensional public realm.
## The primary itinerary is ordered intentionally: graph reachability alone
## cannot substitute for the required spatial journey.
var stable_id: StringName
var air_realm: PublicRealmNode.AirRealm
var nodes: Array[PublicRealmNode] = []
var edges: Array[PublicRealmEdge] = []
var primary_itinerary: Array[StringName] = []
var required_classification_cells: Array[Vector3i] = []
var daylight_void_cells: Array[Vector3i] = []
## Exterior air that belongs to the sealed negative-space volume but is not the
## two-cell sweep directly above one surface claim (portal flare, tunnel crown,
## court side volume, and similar authored void). It never invents a floor.
var supplemental_air_cells: Array[Vector3i] = []
var audit: Dictionary = {}
var _node_by_id: Dictionary = {}
var _surface_owner: Dictionary = {}
var _air_owners: Dictionary = {}
var _air_cell_by_key: Dictionary = {}
var _daylight_void_set: Dictionary = {}
var _sealed := false
var last_rejection := ""


func _init(p_stable_id: StringName,
		p_air_realm: PublicRealmNode.AirRealm = \
		PublicRealmNode.AirRealm.EXTERIOR) -> void:
	stable_id = p_stable_id
	air_realm = p_air_realm


func add_node(node_value: PublicRealmNode) -> bool:
	last_rejection = ""
	if _sealed or node_value == null or not node_value.is_sealed() \
			or node_value.air_realm != air_realm \
			or _node_by_id.has(node_value.stable_id):
		last_rejection = "invalid or duplicate public-realm node"
		return false
	if air_realm == PublicRealmNode.AirRealm.EXTERIOR \
			and node_value.surface_kind == \
			PublicRealmSurfacePlan.SurfaceKind.INTERIOR_PASSAGE:
		last_rejection = "interior passage surface is illegal in exterior realm"
		return false
	for cell: Vector3i in node_value.surface_cells:
		var key := _cell_key(cell)
		if _surface_owner.has(key):
			last_rejection = "surface cell %s is shared by %s and %s" % [key,
				_surface_owner[key], node_value.stable_id]
			return false
	for cell: Vector3i in node_value.surface_cells:
		_surface_owner[_cell_key(cell)] = node_value.stable_id
	for cell: Vector3i in node_value.air_cells:
		var key := _cell_key(cell)
		_air_cell_by_key[key] = cell
		var owners: Array[StringName] = []
		if _air_owners.has(key):
			owners.assign(_air_owners[key] as Array)
		if not owners.has(node_value.stable_id):
			owners.append(node_value.stable_id)
			owners.sort_custom(func(a: StringName, b: StringName) -> bool:
				return String(a) < String(b))
		_air_owners[key] = owners
	nodes.append(node_value)
	_node_by_id[node_value.stable_id] = node_value
	return true


func add_supplemental_air(cell: Vector3i,
		owner_id: StringName = &"supplemental.exterior_air") -> bool:
	if _sealed or owner_id.is_empty():
		return false
	var key := _cell_key(cell)
	if _air_cell_by_key.has(key):
		return true
	_air_cell_by_key[key] = cell
	_air_owners[key] = [owner_id] as Array[StringName]
	supplemental_air_cells.append(cell)
	return true


func add_edge(edge_value: PublicRealmEdge) -> bool:
	if _sealed or edge_value == null:
		return false
	edges.append(edge_value)
	return true


func set_primary_itinerary(node_ids: Array[StringName]) -> void:
	assert(not _sealed)
	primary_itinerary.assign(node_ids)


func require_classification(cell: Vector3i) -> void:
	assert(not _sealed)
	required_classification_cells.append(cell)


func add_daylight_void(cell: Vector3i) -> void:
	assert(not _sealed)
	daylight_void_cells.append(cell)


func seal() -> bool:
	last_rejection = ""
	if _sealed or stable_id.is_empty() or nodes.size() < 2 \
			or primary_itinerary.size() < 2:
		last_rejection = "missing stable id, nodes, or primary itinerary"
		return false
	var edge_ids: Dictionary = {}
	for edge_value: PublicRealmEdge in edges:
		if edge_value == null or edge_ids.has(edge_value.stable_id) \
				or not edge_value.seal(_node_by_id):
			last_rejection = "invalid or duplicate edge %s (%s -> %s, kind=%s, seams=%s)" % [
				"<null>" if edge_value == null else edge_value.stable_id,
				"<null>" if edge_value == null else edge_value.from_node_id,
				"<null>" if edge_value == null else edge_value.to_node_id,
				"<null>" if edge_value == null else edge_value.transition_kind,
				[] if edge_value == null else edge_value.seams,
			]
			return false
		edge_ids[edge_value.stable_id] = true
	var itinerary_ids: Dictionary = {}
	var landing_count := 0
	for node_id: StringName in primary_itinerary:
		if not _node_by_id.has(node_id) or itinerary_ids.has(node_id):
			last_rejection = "primary itinerary contains a missing or duplicate node"
			return false
		itinerary_ids[node_id] = true
		if (_node_by_id[node_id] as PublicRealmNode).is_landing:
			landing_count += 1
	if landing_count != 1 or not (_node_by_id[primary_itinerary[0]] \
			as PublicRealmNode).is_landing:
		last_rejection = "primary itinerary must start at its single landing"
		return false
	for index in range(primary_itinerary.size() - 1):
		if not _has_primary_edge(primary_itinerary[index],
				primary_itinerary[index + 1]):
			last_rejection = "primary itinerary has no edge between %s and %s" % [
				primary_itinerary[index], primary_itinerary[index + 1]]
			return false
	if not _all_nodes_connected():
		last_rejection = "public realm is disconnected"
		return false
	var required_seen: Dictionary = {}
	for cell: Vector3i in required_classification_cells:
		var key := _cell_key(cell)
		if required_seen.has(key):
			last_rejection = "duplicate required classification cell %s" % key
			return false
		required_seen[key] = true
	for cell: Vector3i in daylight_void_cells:
		var key := _cell_key(cell)
		if _daylight_void_set.has(key) or _surface_owner.has(key):
			last_rejection = "invalid daylight void cell %s" % key
			return false
		_daylight_void_set[key] = true
	if not _all_supplemental_air_reaches_node_air():
		last_rejection = "supplemental public air is disconnected from route air"
		return false
	audit = _build_audit()
	_sealed = true
	return true


func validate() -> bool:
	return _sealed and stable_id != StringName() and nodes.size() >= 2 \
		and air_realm >= PublicRealmNode.AirRealm.EXTERIOR \
		and air_realm <= PublicRealmNode.AirRealm.INTERIOR \
		and primary_itinerary.size() >= 2 and _all_nodes_connected()


func is_sealed() -> bool:
	return _sealed


func node(node_id: StringName) -> PublicRealmNode:
	return _node_by_id.get(node_id) as PublicRealmNode


func surface_claims() -> Dictionary:
	var out: Dictionary = {}
	for node_value: PublicRealmNode in nodes:
		for cell: Vector3i in node_value.surface_cells:
			out[cell] = {
				"kind": node_value.surface_kind,
				"owner": node_value.stable_id,
			}
	return out


func air_claims() -> Dictionary:
	var out: Dictionary = {}
	for key_value: Variant in _air_cell_by_key.keys():
		var key := String(key_value)
		var cell := _air_cell_by_key[key] as Vector3i
		var owners: Array[StringName] = []
		owners.assign(_air_owners[key] as Array)
		out[cell] = {"owners": owners}
	return out


func landing_air_cells() -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for node_value: PublicRealmNode in nodes:
		if node_value.is_landing:
			out.assign(node_value.air_cells)
			break
	return out


func is_daylight_void(cell: Vector3i) -> bool:
	return _daylight_void_set.has(_cell_key(cell))


func deterministic_signature() -> String:
	var parts: Array[String] = []
	for node_value: PublicRealmNode in nodes:
		var surface_parts := PackedStringArray()
		var air_parts := PackedStringArray()
		for cell: Vector3i in node_value.surface_cells:
			surface_parts.append(_cell_key(cell))
		for cell: Vector3i in node_value.air_cells:
			air_parts.append(_cell_key(cell))
		surface_parts.sort()
		air_parts.sort()
		parts.append("N:%s:%d:%d:%d:%d:%d:S[%s]:A[%s]" % [node_value.stable_id,
			node_value.episode_kind, node_value.primary_entry_y,
			node_value.primary_exit_y, node_value.air_realm,
			node_value.cover_policy, ",".join(surface_parts),
			",".join(air_parts)])
	for edge_value: PublicRealmEdge in edges:
		parts.append("E:%s:%s:%s:%d" % [edge_value.stable_id,
			edge_value.from_node_id, edge_value.to_node_id,
			edge_value.transition_kind])
	parts.append("P:%s" % ",".join(PackedStringArray(primary_itinerary)))
	var daylight_parts := PackedStringArray()
	for cell: Vector3i in daylight_void_cells:
		daylight_parts.append(_cell_key(cell))
	daylight_parts.sort()
	parts.append("D:%s" % ",".join(daylight_parts))
	var supplemental_parts := PackedStringArray()
	for cell: Vector3i in supplemental_air_cells:
		supplemental_parts.append(_cell_key(cell))
	supplemental_parts.sort()
	parts.append("A+:%s" % ",".join(supplemental_parts))
	return "|".join(PackedStringArray(parts))


func _all_supplemental_air_reaches_node_air() -> bool:
	if supplemental_air_cells.is_empty():
		return true
	var node_air: Dictionary = {}
	for node_value: PublicRealmNode in nodes:
		for cell: Vector3i in node_value.air_cells:
			node_air[_cell_key(cell)] = true
	var reached: Dictionary = node_air.duplicate()
	var pending: Array[Vector3i] = []
	for node_value: PublicRealmNode in nodes:
		pending.append_array(node_value.air_cells)
	while not pending.is_empty():
		var cell: Vector3i = pending.pop_back()
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD, Vector3i.BACK]:
			var neighbor := cell + direction
			var key := _cell_key(neighbor)
			if _air_cell_by_key.has(key) and not reached.has(key):
				reached[key] = true
				pending.append(neighbor)
	for cell: Vector3i in supplemental_air_cells:
		if not reached.has(_cell_key(cell)):
			return false
	return true


func _has_primary_edge(a: StringName, b: StringName) -> bool:
	for edge_value: PublicRealmEdge in edges:
		if edge_value.is_primary and edge_value.connects(a, b):
			return true
	return false


func _all_nodes_connected() -> bool:
	if nodes.is_empty():
		return false
	var adjacency: Dictionary = {}
	for node_value: PublicRealmNode in nodes:
		adjacency[node_value.stable_id] = []
	for edge_value: PublicRealmEdge in edges:
		if not adjacency.has(edge_value.from_node_id) \
				or not adjacency.has(edge_value.to_node_id):
			return false
		(adjacency[edge_value.from_node_id] as Array).append(edge_value.to_node_id)
		(adjacency[edge_value.to_node_id] as Array).append(edge_value.from_node_id)
	var reached: Dictionary = {}
	var pending: Array[StringName] = [nodes[0].stable_id]
	while not pending.is_empty():
		var current: StringName = pending.pop_back()
		if reached.has(current):
			continue
		reached[current] = true
		for neighbor: StringName in adjacency[current] as Array:
			if not reached.has(neighbor):
				pending.append(neighbor)
	return reached.size() == nodes.size()


func _build_audit() -> Dictionary:
	var elevations: Array[int] = []
	var elevation_signs: Array[int] = []
	var court_on_primary := false
	var covered_on_primary := 0
	var exterior_stair_on_primary := 0
	var min_y := 2147483647
	var max_y := -2147483648
	for index in primary_itinerary.size():
		var node_value := _node_by_id[primary_itinerary[index]] as PublicRealmNode
		if elevations.is_empty():
			elevations.append(node_value.primary_entry_y)
		elevations.append(node_value.primary_exit_y)
		court_on_primary = court_on_primary \
			or node_value.episode_kind == PublicRealmNode.EpisodeKind.COURT
		if node_value.cover_policy == PublicRealmNode.CoverPolicy.COVERED:
			covered_on_primary += 1
		if node_value.episode_kind == PublicRealmNode.EpisodeKind.STAIR_CANYON:
			exterior_stair_on_primary += 1
	for node_value: PublicRealmNode in nodes:
		min_y = mini(min_y, node_value.min_y())
		max_y = maxi(max_y, node_value.max_y())
	var change_count := 0
	for index in range(1, elevations.size()):
		var delta := elevations[index] - elevations[index - 1]
		if delta == 0:
			continue
		change_count += 1
		var sign_value := signi(delta)
		if elevation_signs.is_empty() or elevation_signs.back() != sign_value:
			elevation_signs.append(sign_value)
	var result := {
		"public_realm_node_count": nodes.size(),
		"public_realm_edge_count": edges.size(),
		"primary_episode_count": primary_itinerary.size(),
		"public_surface_cell_count": _surface_owner.size(),
		"vertical_span_cells": max_y - min_y,
		"sectional_elevation_change_count": change_count,
		"sectional_has_up_down_up": _contains_sign_sequence(elevation_signs,
			[1, -1, 1]),
		"public_air_claim_count": _air_owners.size(),
		"supplemental_public_air_count": supplemental_air_cells.size(),
		"public_interior_node_count": 0 \
			if air_realm == PublicRealmNode.AirRealm.EXTERIOR else nodes.size(),
		"primary_covered_episode_count": covered_on_primary,
		"primary_exterior_stair_count": exterior_stair_on_primary,
		"primary_has_court": court_on_primary,
		"level_changing_loop_count": _level_changing_loop_count(),
		"daylight_void_cell_count": daylight_void_cells.size(),
	}
	result.merge(_alignment_audit(), true)
	return result


func _alignment_audit() -> Dictionary:
	## Graph reachability is too weak for visible circulation. A stair is aligned
	## only when two player-width lanes meet both its lowest and highest tread;
	## a structural platform must participate in the route rather than terminate
	## as an ornamental shelf.
	var stair_count := 0
	var aligned_stair_count := 0
	var stair_endpoint_gap_count := 0
	var stair_endpoint_missing_landing_count := 0
	var stair_to_stair_edge_count := 0
	var platform_count := 0
	var platform_dead_end_count := 0
	var platform_connection_seam_count := 0
	for node_value: PublicRealmNode in nodes:
		var incident: Array[PublicRealmEdge] = []
		for edge_value: PublicRealmEdge in edges:
			if edge_value.from_node_id == node_value.stable_id \
					or edge_value.to_node_id == node_value.stable_id:
				incident.append(edge_value)
		if node_value.episode_kind == PublicRealmNode.EpisodeKind.STAIR_CANYON:
			stair_count += 1
			var low_lanes := 0
			var high_lanes := 0
			var low_y := node_value.min_y()
			var high_y := node_value.max_y()
			var low_has_landing := false
			var high_has_landing := false
			for edge_value: PublicRealmEdge in incident:
				var neighbor_id := edge_value.to_node_id \
					if edge_value.from_node_id == node_value.stable_id \
					else edge_value.from_node_id
				var neighbor := _node_by_id.get(neighbor_id) as PublicRealmNode
				if neighbor != null and neighbor.episode_kind == \
						PublicRealmNode.EpisodeKind.STAIR_CANYON \
						and String(node_value.stable_id) < String(neighbor_id):
					stair_to_stair_edge_count += 1
				for seam: Dictionary in edge_value.seams:
					var stair_cell := seam.from_cell as Vector3i \
						if edge_value.from_node_id == node_value.stable_id \
						else seam.to_cell as Vector3i
					var neighbor_cell := seam.to_cell as Vector3i \
						if edge_value.from_node_id == node_value.stable_id \
						else seam.from_cell as Vector3i
					if stair_cell.y == low_y:
						low_lanes += 1
						low_has_landing = low_has_landing or (neighbor != null \
							and neighbor.episode_kind != \
								PublicRealmNode.EpisodeKind.STAIR_CANYON \
							and _has_square_landing(neighbor, neighbor_cell))
					if stair_cell.y == high_y:
						high_lanes += 1
						high_has_landing = high_has_landing or (neighbor != null \
							and neighbor.episode_kind != \
								PublicRealmNode.EpisodeKind.STAIR_CANYON \
							and _has_square_landing(neighbor, neighbor_cell))
			if low_lanes < 2:
				stair_endpoint_gap_count += 1
			if high_lanes < 2:
				stair_endpoint_gap_count += 1
			if low_lanes >= 2 and high_lanes >= 2:
				aligned_stair_count += 1
			if not low_has_landing:
				stair_endpoint_missing_landing_count += 1
			if not high_has_landing:
				stair_endpoint_missing_landing_count += 1
		if node_value.surface_kind == \
				PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT:
			platform_count += 1
			if incident.size() < 2:
				platform_dead_end_count += 1
			for edge_value: PublicRealmEdge in incident:
				platform_connection_seam_count += edge_value.seams.size()
	return {
		"audited_stair_count": stair_count,
		"aligned_stair_count": aligned_stair_count,
		"stair_endpoint_gap_count": stair_endpoint_gap_count,
		"stair_endpoint_missing_landing_count":
			stair_endpoint_missing_landing_count,
		"stair_to_stair_edge_count": stair_to_stair_edge_count,
		"audited_platform_count": platform_count,
		"platform_dead_end_count": platform_dead_end_count,
		"platform_connection_seam_count": platform_connection_seam_count,
		"continuous_sectional_path_count": 1 if stair_count > 0 \
			and stair_endpoint_gap_count == 0 \
			and stair_endpoint_missing_landing_count == 0 \
			and stair_to_stair_edge_count == 0 and _all_nodes_connected() else 0,
	}


func _has_square_landing(node_value: PublicRealmNode,
		seam_cell: Vector3i) -> bool:
	## A visible turn needs a level two-by-two patch, not merely two graph seams.
	## Test every possible corner containing the seam so this is independent of
	## route orientation and works for both terrain and structural landings.
	for offset_x in [-1, 0]:
		for offset_z in [-1, 0]:
			var corner := seam_cell + Vector3i(offset_x, 0, offset_z)
			var complete := true
			for dz in 2:
				for dx in 2:
					if not node_value.has_cell(corner + Vector3i(dx, 0, dz)):
						complete = false
						break
				if not complete:
					break
			if complete:
				return true
	return false


func _level_changing_loop_count() -> int:
	var count := 0
	for edge_value: PublicRealmEdge in edges:
		if edge_value.is_primary:
			continue
		var from_node := _node_by_id[edge_value.from_node_id] as PublicRealmNode
		var to_node := _node_by_id[edge_value.to_node_id] as PublicRealmNode
		if from_node.primary_exit_y != to_node.primary_entry_y \
				or edge_value.transition_kind != PublicRealmEdge.TransitionKind.LEVEL:
			count += 1
	return count


static func _contains_sign_sequence(values: Array[int], sequence: Array[int]) -> bool:
	if values.size() < sequence.size():
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


static func _cell_key(cell: Vector3i) -> String:
	return "%d:%d:%d" % [cell.x, cell.y, cell.z]
