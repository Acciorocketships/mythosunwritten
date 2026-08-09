class_name WarrenAssetCompiler
extends RefCounted

const FLEXIBLE_ORANGE_ROOF_CAP_RATIO := 0.65
## The facade families an UPPER storey may draw from. Rock is deliberately
## absent: every stack already builds its ground storey from `room.*.base.rock`
## (StaggeredFabricCompiler picks that recipe unconditionally), so admitting
## &"stone" here clads the whole house in masonry -- measured at ten contiguous
## bands of house-rock on seed 8, which is the "multiple storeys of stone wall
## read as a tower" the round-5 review rejected.
##
## Capping the family table rather than the recipes keeps the rock upper-storey
## vocabulary compiled and available to any later stage that wants ONE course,
## and leaves the reviewed wood-over-stone junction exactly where it was: at the
## top of the ground storey.
##
## `amber` is the third timber family added by the vocabulary wiring wave. Two
## colours left the streetscape graph-colouring with no move on a degree-2
## neighbourhood -- every third house had to repeat one of its neighbours -- and
## pushed the largest-family share hard against
## WarrenBuiltTownSolver.TARGET_MAX_LARGEST_FACADE_FAMILY_RATIO. Its modules are
## disjoint from the other two pools (see SettlementFabricProgram), so it is a
## different authored wall rather than a re-phased one.
const UPPER_FACADE_FAMILIES: Array[StringName] = [&"blue", &"orange", &"amber"]

## Situational recipe selection for already-sealed roofed parcels. It never
## scales a prefab or changes parcel geometry to make an asset fit.
static var last_failure := ""


static func solve(town: WarrenTownPlan,
		program: SettlementFabricProgram) -> WarrenAssetPlan:
	last_failure = ""
	if town == null or not town.is_sealed() or program == null:
		last_failure = "missing sealed town or compiled vocabulary"
		return null
	var proposals: Array[Dictionary] = []
	for parcel: WarrenBuildingParcel in town.parcels.parcels:
		var proposal := WarrenParcelConstruction.proposal(parcel)
		if proposal.is_empty():
			last_failure = "no construction profile for parcel %s" % parcel.stable_id
			return null
		proposals.append(proposal)
	var roof_topology := FabricRoofTopologyPlan.build(proposals)
	if roof_topology == null:
		last_failure = "could not classify the parcel roof neighborhood"
		return null
	if not _assign_neighborhood_styles(proposals, roof_topology,
			int(town.volume.world_seed)):
		last_failure = FabricRoofJunctionModuleTable.last_failure
		return null
	var tower_seams := _party_wall_seams(proposals)
	var units: Array[FabricUnit] = []
	for proposal: Dictionary in proposals:
		var components := StaggeredFabricCompiler.proposal_components(proposal)
		if components.is_empty():
			last_failure = "proposal %s has no recipe expansion" % proposal.stable_id
			return null
		var parent_id := &""
		var roof_id := &""
		var proposal_prefix := StringName("volume.%s" % proposal.stable_id)
		for component: Dictionary in components:
			var role := StringName(component.role)
			var stable_id := StringName("%s.%s" % [proposal_prefix, role])
			var parents: Array[StringName] = []
			var bonds: Array[Dictionary] = []
			if role == &"roof":
				roof_id = stable_id
			if String(role).begins_with("roof.trim."):
				if roof_id.is_empty():
					last_failure = "roof seam precedes its bearing roof"
					return null
				parents.append(roof_id)
				var side_name := "negative" \
					if int(component.roof_junction_side) \
						== FabricRoofTopologyPlan.Side.EAVE_NEGATIVE \
					else "positive"
				bonds.append(FabricUnit.bond(&"bearing.bottom", roof_id,
					StringName("bearing.junction.eave.%s" % side_name)))
			elif not parent_id.is_empty():
				parents.append(parent_id)
				bonds.append(FabricUnit.bond(&"bearing.bottom", parent_id,
					&"bearing.top"))
			var seams: Array[StringName] = []
			seams.assign(tower_seams.get(StringName(proposal.stable_id), []) \
				as Array)
			var unit_value := FabricUnit.new(stable_id,
				StringName(component.recipe_id), component.origin as Vector3i,
				int(component.yaw_quarters), parents, bonds, &"", seams)
			units.append(unit_value)
			if not String(role).begins_with("roof.trim."):
				parent_id = stable_id
	var result := WarrenAssetPlan.new(
		StringName("%s.assets" % town.stable_id), town, program)
	if not result.seal(proposals, units):
		last_failure = result.last_rejection
		return null
	return result


static func parcels_are_visually_compatible(left: WarrenBuildingParcel,
		right: WarrenBuildingParcel,
		program: SettlementFabricProgram,
		cache: Dictionary = {}) -> bool:
	## Exact construction broad phase used while parcels are still proposals.
	## Logical occupancy remains the parcelizer's authority; this contract adds
	## only the compiled vocabulary's measured visual clearance. Deliberate
	## tower party walls are the sole overlap exception because their complete
	## authored stack owns that semantic seam.
	if left == null or right == null or program == null:
		return false
	var left_proposal := _cached_proposal(left, cache)
	var right_proposal := _cached_proposal(right, cache)
	if left_proposal.is_empty() or right_proposal.is_empty():
		return false
	# Face-adjacent roofs must have a complete construction rule before the
	# parcel pair can enter the beam.  This keeps partial valleys and unsupported
	# perpendicular intersections out of the selected town instead of discovering
	# them only after every building has been packed.
	var pair_topology := FabricRoofTopologyPlan.build(
		[left_proposal, right_proposal])
	if pair_topology == null:
		return false
	if int(pair_topology.audit.junction_count) > 0 \
			and FabricRoofJunctionModuleTable.build(
				[left_proposal, right_proposal], pair_topology).is_empty():
		return false
	if StaggeredFabricCompiler.classified_roof_seam_compatible(left_proposal,
			right_proposal):
		return true
	var left_bounds := _cached_proposal_component_bounds(left, program, cache)
	var right_bounds := _cached_proposal_component_bounds(right, program, cache)
	if left_bounds.is_empty() or right_bounds.is_empty():
		return false
	for left_value: Variant in left_bounds:
		var left_box := left_value as AABB
		for right_value: Variant in right_bounds:
			var right_box := right_value as AABB
			if SettlementFabricPlan._aabb_overlaps_volume(left_box, right_box):
				return false
	return true


static func skywalk_opportunity_count(parcels: WarrenParcelPlan,
		program: SettlementFabricProgram) -> int:
	## Cheap construction-aware topology rank. It counts only exact authored
	## straight-link socket relationships; the later overhead transaction remains
	## authoritative for swept occupancy, measured envelopes, and public air.
	if parcels == null or not parcels.is_sealed() or program == null:
		return 0
	var endpoints: Array[Dictionary] = []
	for parcel: WarrenBuildingParcel in parcels.parcels:
		endpoints.append_array(_parcel_room_endpoints(parcel, program))
	var result := 0
	for left_index in endpoints.size():
		var left := endpoints[left_index]
		for right_index in range(left_index + 1, endpoints.size()):
			var right := endpoints[right_index]
			if left.parcel_id == right.parcel_id \
					or (left.cell as Vector3i).y != (right.cell as Vector3i).y \
					or (left.facing as Vector3i) != -(right.facing as Vector3i):
				continue
			var forward := left.facing as Vector3i
			var delta := (right.cell as Vector3i) - (left.cell as Vector3i)
			var distance: int = delta.x * forward.x + delta.y * forward.y \
				+ delta.z * forward.z
			if distance >= 3 and distance <= 7 and posmod(distance, 2) == 1 \
					and delta == forward * distance:
				result += 1
	return result


static func parcels_form_skywalk_opportunity(left: WarrenBuildingParcel,
		right: WarrenBuildingParcel,
		program: SettlementFabricProgram) -> bool:
	if left == null or right == null or program == null:
		return false
	for left_endpoint: Dictionary in _parcel_room_endpoints(left, program):
		for right_endpoint: Dictionary in _parcel_room_endpoints(right, program):
			if _endpoints_form_straight_link(left_endpoint, right_endpoint):
				return true
	return false


static func parcels_may_form_skywalk(left: WarrenBuildingParcel,
		right: WarrenBuildingParcel, program: SettlementFabricProgram,
		cache: Dictionary = {}) -> bool:
	## Socket-level broad phase for the exact straight/corner reservation below.
	## It deliberately ignores air and visual envelopes, but proves that two
	## upper-room sockets have compatible height/facing and can reach one another
	## within the maximum authored arm plus the corner module. Recipe expansion is
	## then paid only for plausible pairs.
	if left == null or right == null:
		return false
	var left_endpoints := _parcel_room_endpoints(left, program, cache)
	var right_endpoints := _parcel_room_endpoints(right, program, cache)
	var left_heights := _parcel_endpoint_heights(left, program, cache)
	var right_heights := _parcel_endpoint_heights(right, program, cache)
	var shares_height := false
	for height: Variant in left_heights.keys():
		if right_heights.has(height):
			shares_height = true
			break
	if not shares_height:
		return false
	for left_endpoint: Dictionary in left_endpoints:
		for right_endpoint: Dictionary in right_endpoints:
			if _endpoints_form_straight_link(left_endpoint, right_endpoint):
				return true
			var left_cell := left_endpoint.cell as Vector3i
			var right_cell := right_endpoint.cell as Vector3i
			var left_facing := left_endpoint.facing as Vector3i
			var right_facing := right_endpoint.facing as Vector3i
			var facing_dot: int = left_facing.x * right_facing.x \
				+ left_facing.z * right_facing.z
			if left_cell.y != right_cell.y or facing_dot != 0:
				continue
			var delta := right_cell - left_cell
			var left_run: int = delta.x * left_facing.x \
				+ delta.z * left_facing.z
			var right_run: int = -delta.x * right_facing.x \
				- delta.z * right_facing.z
			if left_run >= 1 and left_run <= 10 \
					and right_run >= 1 and right_run <= 10:
				return true
	return false


static func skywalk_reservation(left: WarrenBuildingParcel,
		right: WarrenBuildingParcel, program: SettlementFabricProgram,
		public_air: Dictionary, cache: Dictionary = {}) -> Dictionary:
	if left == null or right == null or program == null \
			or public_air.is_empty():
		return {}
	for left_endpoint: Dictionary in _parcel_room_endpoints(left, program, cache):
		for right_endpoint: Dictionary in _parcel_room_endpoints(right, program,
				cache):
			if not _endpoints_form_straight_link(left_endpoint, right_endpoint):
				continue
			var forward := left_endpoint.facing as Vector3i
			var delta := (right_endpoint.cell as Vector3i) \
				- (left_endpoint.cell as Vector3i)
			var distance: int = delta.x * forward.x + delta.z * forward.z
			var segments: int = (distance - 1) / 2
			var recipe_id := &"skywalk.3.blue" if segments == 1 \
				else &"skywalk.6.orange" if segments == 2 else &"skywalk.9.blue"
			var recipe_value := program.recipe(recipe_id)
			var yaw := _yaw_for_facing(Vector3i.LEFT, -forward)
			if recipe_value == null or yaw < 0:
				continue
			var own_socket := recipe_value.socket(&"room.west")
			if own_socket.is_empty():
				continue
			var origin := (left_endpoint.cell as Vector3i) + forward \
				- FabricRecipe.transform_cell(own_socket.cell as Vector3i,
					Vector3i.ZERO, yaw)
			var inhabited := _transformed_cells(recipe_value.inhabited_cells,
				origin, yaw)
			for cell: Vector3i in _transformed_cells(recipe_value.solid_cells,
					origin, yaw):
				if not inhabited.has(cell):
					inhabited.append(cell)
			var public_air_clear := true
			for cell: Vector3i in inhabited:
				if public_air.has(cell):
					public_air_clear = false
					break
			if not public_air_clear:
				continue
			var reserved: Dictionary = {}
			for cell: Vector3i in _transformed_cells(recipe_value.solid_cells,
					origin, yaw):
				reserved[cell] = true
			for cell: Vector3i in _transformed_cells(recipe_value.headroom_cells,
					origin, yaw):
				reserved[cell] = true
			return {
				"kind": &"straight",
				"recipe_id": recipe_id,
				"origin": origin,
				"yaw_quarters": yaw,
				"components": [{"recipe_id": recipe_id, "origin": origin,
					"yaw_quarters": yaw}],
				"reserved_cells": reserved,
				"visual_bounds": [FabricRecipe.lattice_transform(origin, yaw) \
					* recipe_value.local_clearance_bounds],
				"owner_endpoints": [_owner_endpoint(left, left_endpoint),
					_owner_endpoint(right, right_endpoint)],
			}
	return _corner_skywalk_reservation(left, right, program, public_air, cache)


static func parcel_preserves_skywalk_reservation(
		parcel: WarrenBuildingParcel, reservation: Dictionary,
		program: SettlementFabricProgram, cache: Dictionary = {}) -> bool:
	if parcel == null or reservation.is_empty() or program == null:
		return false
	var owner_endpoint := _reservation_owner_endpoint(parcel, reservation)
	if not owner_endpoint.is_empty():
		return _parcel_preserves_owned_skywalk_endpoint(parcel, owner_endpoint,
			reservation, program, cache)
	var reserved := reservation.reserved_cells as Dictionary
	var bridge_bounds: Array[AABB] = []
	bridge_bounds.assign(reservation.visual_bounds as Array)
	var proposal := _cached_proposal(parcel, cache)
	for component: Dictionary in \
			StaggeredFabricCompiler.proposal_components(proposal):
		var recipe_value := program.recipe(StringName(component.recipe_id))
		if recipe_value == null:
			return false
		for local_cell: Vector3i in recipe_value.solid_cells:
			if reserved.has(FabricRecipe.transform_cell(local_cell,
					component.origin as Vector3i, int(component.yaw_quarters))):
				return false
		for local_cell: Vector3i in recipe_value.headroom_cells:
			if reserved.has(FabricRecipe.transform_cell(local_cell,
					component.origin as Vector3i, int(component.yaw_quarters))):
				return false
		var bounds := FabricRecipe.lattice_transform(
			component.origin as Vector3i, int(component.yaw_quarters)) \
			* recipe_value.local_clearance_bounds
		for bridge_box: AABB in bridge_bounds:
			if SettlementFabricPlan._aabb_overlaps_volume(bounds, bridge_box):
				return false
	return true


static func _parcel_preserves_owned_skywalk_endpoint(
		parcel: WarrenBuildingParcel, owner_endpoint: Dictionary,
		reservation: Dictionary, program: SettlementFabricProgram,
		cache: Dictionary) -> bool:
	var matched_component := -1
	var proposal := _cached_proposal(parcel, cache)
	var components := StaggeredFabricCompiler.proposal_components(proposal)
	for component_index in components.size():
		var component := components[component_index] as Dictionary
		var recipe_value := program.recipe(StringName(component.recipe_id))
		if recipe_value == null:
			return false
		for socket: Dictionary in recipe_value.sockets:
			if int(socket.kind) != FabricRecipe.SocketKind.ROOM:
				continue
			var cell := FabricRecipe.transform_cell(socket.cell as Vector3i,
				component.origin as Vector3i, int(component.yaw_quarters))
			var facing := FabricRecipe.transform_direction(
				socket.facing as Vector3i, int(component.yaw_quarters))
			if cell == owner_endpoint.cell and facing == owner_endpoint.facing:
				matched_component = component_index
				break
		if matched_component >= 0:
			break
	if matched_component < 0:
		return false
	# Only the room carrying the exact authored endpoint may meet its terminal
	# bridge component. Added storeys, roofs, bays, and every unrelated component
	# retain the ordinary cell and measured-envelope exclusion.
	var reserved := reservation.reserved_cells as Dictionary
	for component_index in components.size():
		var component := components[component_index] as Dictionary
		var recipe_value := program.recipe(StringName(component.recipe_id))
		if recipe_value == null:
			return false
		if component_index != matched_component:
			for local_cell: Vector3i in recipe_value.solid_cells:
				if reserved.has(FabricRecipe.transform_cell(local_cell,
						component.origin as Vector3i,
						int(component.yaw_quarters))):
					return false
			for local_cell: Vector3i in recipe_value.headroom_cells:
				if reserved.has(FabricRecipe.transform_cell(local_cell,
						component.origin as Vector3i,
						int(component.yaw_quarters))):
					return false
		# The reservation was authored against this horizontal slot and its terminal
		# room. Conservative room/roof AABBs deliberately meet the bridge envelope at
		# that semantic seam, so owner variants use exact occupied cells here. Generic
		# non-owners continue to use the broader measured-envelope exclusion above.
	return true


static func _reservation_owner_endpoint(parcel: WarrenBuildingParcel,
		reservation: Dictionary) -> Dictionary:
	for value: Variant in reservation.get("owner_endpoints", []):
		var endpoint := value as Dictionary
		if String(endpoint.get("slot_signature", "")) \
				== parcel.slot_signature():
			return endpoint
	return {}


static func _owner_endpoint(parcel: WarrenBuildingParcel,
		endpoint: Dictionary) -> Dictionary:
	return {
		"slot_signature": parcel.slot_signature(),
		"cell": endpoint.cell,
		"facing": endpoint.facing,
	}


static func _corner_skywalk_reservation(left: WarrenBuildingParcel,
		right: WarrenBuildingParcel, program: SettlementFabricProgram,
		public_air: Dictionary, cache: Dictionary = {}) -> Dictionary:
	var corner_recipe := program.recipe(&"skywalk.corner.orange")
	if corner_recipe == null:
		return {}
	for left_endpoint: Dictionary in _parcel_room_endpoints(left, program, cache):
		for right_endpoint: Dictionary in _parcel_room_endpoints(right, program,
				cache):
			var left_facing := left_endpoint.facing as Vector3i
			var right_facing := right_endpoint.facing as Vector3i
			if (left_endpoint.cell as Vector3i).y \
					!= (right_endpoint.cell as Vector3i).y \
					or left_facing.x * right_facing.x \
						+ left_facing.z * right_facing.z != 0:
				continue
			for corner_yaw in 4:
				var left_socket := _socket_facing(corner_recipe,
					-left_facing, corner_yaw)
				var right_socket := _socket_facing(corner_recipe,
					-right_facing, corner_yaw)
				if left_socket.is_empty() or right_socket.is_empty() \
						or left_socket.id == right_socket.id:
					continue
				for left_distance in [3, 5, 7]:
					var desired_left: Vector3i = (left_endpoint.cell as Vector3i) \
						+ left_facing * left_distance
					var corner_origin := desired_left \
						- FabricRecipe.transform_cell(left_socket.cell as Vector3i,
							Vector3i.ZERO, corner_yaw)
					var right_corner_cell := FabricRecipe.transform_cell(
						right_socket.cell as Vector3i, corner_origin, corner_yaw)
					var right_delta := right_corner_cell \
						- (right_endpoint.cell as Vector3i)
					var right_distance: int = right_delta.x * right_facing.x \
						+ right_delta.z * right_facing.z
					if not [3, 5, 7].has(right_distance) \
							or right_delta != right_facing * right_distance:
						continue
					var left_recipe_id := _cantilever_recipe(
						(left_distance - 1) / 2)
					var right_recipe_id := _cantilever_recipe(
						(right_distance - 1) / 2)
					var left_recipe := program.recipe(left_recipe_id)
					var right_recipe := program.recipe(right_recipe_id)
					var left_yaw := _yaw_for_facing(Vector3i.LEFT, -left_facing)
					var right_yaw := _yaw_for_facing(Vector3i.LEFT, right_facing)
					if left_recipe == null or right_recipe == null \
							or left_yaw < 0 or right_yaw < 0:
						continue
					var left_origin := _attached_origin(left_recipe, &"room.west",
						left_yaw, left_endpoint.cell as Vector3i, left_facing)
					var right_corner_facing := FabricRecipe.transform_direction(
						right_socket.facing as Vector3i, corner_yaw)
					var right_origin := _attached_origin(right_recipe, &"room.west",
						right_yaw, right_corner_cell, right_corner_facing)
					var components: Array[Dictionary] = [
						{"recipe_id": left_recipe_id, "origin": left_origin,
							"yaw_quarters": left_yaw},
						{"recipe_id": &"skywalk.corner.orange",
							"origin": corner_origin, "yaw_quarters": corner_yaw},
						{"recipe_id": right_recipe_id, "origin": right_origin,
							"yaw_quarters": right_yaw},
					]
					var reservation := _component_reservation(components, program,
						public_air)
					if reservation.is_empty() or not _corner_fits_source_stacks(
							reservation, left, right, program, cache):
						continue
					reservation["kind"] = &"corner"
					reservation["recipe_id"] = &"skywalk.corner.orange"
					reservation["origin"] = corner_origin
					reservation["yaw_quarters"] = corner_yaw
					reservation["owner_endpoints"] = [
						_owner_endpoint(left, left_endpoint),
						_owner_endpoint(right, right_endpoint),
					]
					return reservation
	return {}


static func _corner_fits_source_stacks(reservation: Dictionary,
		left: WarrenBuildingParcel, right: WarrenBuildingParcel,
		program: SettlementFabricProgram, cache: Dictionary = {}) -> bool:
	var bridge_bounds: Array[AABB] = []
	bridge_bounds.assign(reservation.get("visual_bounds", []) as Array)
	if bridge_bounds.size() != 3:
		return false
	var left_bounds := _cached_proposal_component_bounds(left, program, cache)
	var right_bounds := _cached_proposal_component_bounds(right, program, cache)
	# Arm zero is semantically framed into the left stack and arm two into the
	# right. Every other bridge/building meeting is an unrelated intersection.
	for index in bridge_bounds.size():
		if index != 0 and _overlaps_any(bridge_bounds[index], left_bounds):
			return false
		if index != 2 and _overlaps_any(bridge_bounds[index], right_bounds):
			return false
	return true
static func _overlaps_any(bounds: AABB, others: Array[AABB]) -> bool:
	for other: AABB in others:
		if SettlementFabricPlan._aabb_overlaps_volume(bounds, other):
			return true
	return false


static func _component_reservation(components: Array[Dictionary],
		program: SettlementFabricProgram, public_air: Dictionary) -> Dictionary:
	var reserved: Dictionary = {}
	var solid: Dictionary = {}
	var walk: Dictionary = {}
	var headroom: Dictionary = {}
	var bounds: Array[AABB] = []
	for component: Dictionary in components:
		var recipe_value := program.recipe(StringName(component.recipe_id))
		var origin := component.origin as Vector3i
		var yaw := int(component.yaw_quarters)
		if recipe_value == null:
			return {}
		for cell: Vector3i in _transformed_cells(recipe_value.solid_cells,
				origin, yaw):
			if solid.has(cell) or walk.has(cell) or headroom.has(cell):
				return {}
			solid[cell] = true
		for cell: Vector3i in _transformed_cells(recipe_value.headroom_cells,
				origin, yaw):
			if solid.has(cell) or headroom.has(cell):
				return {}
			headroom[cell] = true
		for cell: Vector3i in _transformed_cells(recipe_value.walk_cells,
				origin, yaw):
			if solid.has(cell) or walk.has(cell):
				return {}
			walk[cell] = true
		var occupied := _transformed_cells(recipe_value.inhabited_cells,
			origin, yaw)
		for cell: Vector3i in _transformed_cells(recipe_value.solid_cells,
				origin, yaw):
			if not occupied.has(cell):
				occupied.append(cell)
		for cell: Vector3i in occupied:
			if public_air.has(cell):
				return {}
		for cell: Vector3i in solid:
			reserved[cell] = true
		for cell: Vector3i in walk:
			reserved[cell] = true
		for cell: Vector3i in headroom:
			reserved[cell] = true
		bounds.append(FabricRecipe.lattice_transform(origin, yaw) \
			* recipe_value.local_clearance_bounds)
	return {"components": components, "reserved_cells": reserved,
		"visual_bounds": bounds}


static func _socket_facing(recipe_value: FabricRecipe,
		world_facing: Vector3i, yaw: int) -> Dictionary:
	for socket: Dictionary in recipe_value.sockets:
		# End-of-face corner sockets carry corner-wrap bays only; corridor and
		# link planning always addresses the mid-face socket.
		if int(socket.kind) == FabricRecipe.SocketKind.ROOM \
				and not String(StringName(socket.id)).contains(".corner.") \
				and FabricRecipe.transform_direction(socket.facing as Vector3i,
					yaw) == world_facing:
			return socket
	return {}


static func _cantilever_recipe(segments: int) -> StringName:
	return &"skywalk.cantilever.3.blue" if segments == 1 \
		else &"skywalk.cantilever.6.orange" if segments == 2 \
		else &"skywalk.cantilever.9.blue"


static func _attached_origin(recipe_value: FabricRecipe,
		own_socket_id: StringName, yaw: int, target_cell: Vector3i,
		target_facing: Vector3i) -> Vector3i:
	var own_socket := recipe_value.socket(own_socket_id)
	return target_cell + target_facing - FabricRecipe.transform_cell(
		own_socket.cell as Vector3i, Vector3i.ZERO, yaw)


static func _transformed_cells(local_cells: Array[Vector3i],
		origin: Vector3i, yaw: int) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for local_cell: Vector3i in local_cells:
		out.append(FabricRecipe.transform_cell(local_cell, origin, yaw))
	return out


static func _yaw_for_facing(local_facing: Vector3i,
		world_facing: Vector3i) -> int:
	for yaw in 4:
		if FabricRecipe.transform_direction(local_facing, yaw) == world_facing:
			return yaw
	return -1


static func _parcel_room_endpoints(parcel: WarrenBuildingParcel,
		program: SettlementFabricProgram,
		cache: Dictionary = {}) -> Array[Dictionary]:
	var key := _parcel_cache_key(parcel)
	if bool(cache.get(&"enabled", false)) and cache.has(key):
		var cached_entry := cache[key] as Dictionary
		if cached_entry.has(&"endpoints"):
			var cached: Array[Dictionary] = []
			cached.assign(cached_entry[&"endpoints"] as Array)
			return cached
	var out: Array[Dictionary] = []
	var proposal := _cached_proposal(parcel, cache)
	for component: Dictionary in \
			StaggeredFabricCompiler.proposal_components(proposal):
		if not String(StringName(component.role)).begins_with("upper."):
			continue
		var recipe_value := program.recipe(StringName(component.recipe_id))
		if recipe_value == null or recipe_value.has_tag(&"roof"):
			continue
		for socket: Dictionary in recipe_value.sockets:
			if int(socket.kind) != FabricRecipe.SocketKind.ROOM \
					or not String(StringName(socket.id)).begins_with("room.") \
					or String(StringName(socket.id)).contains(".corner."):
				continue
			out.append({
				"parcel_id": parcel.stable_id,
				"cell": FabricRecipe.transform_cell(socket.cell as Vector3i,
					component.origin as Vector3i, int(component.yaw_quarters)),
				"facing": FabricRecipe.transform_direction(
					socket.facing as Vector3i, int(component.yaw_quarters)),
			})
	if bool(cache.get(&"enabled", false)):
		var entry := cache.get(key, {}) as Dictionary
		entry[&"endpoints"] = out
		cache[key] = entry
	return out


static func _parcel_endpoint_heights(parcel: WarrenBuildingParcel,
		program: SettlementFabricProgram, cache: Dictionary) -> Dictionary:
	var key := _parcel_cache_key(parcel)
	if bool(cache.get(&"enabled", false)) and cache.has(key):
		var cached_entry := cache[key] as Dictionary
		if cached_entry.has(&"endpoint_heights"):
			return cached_entry[&"endpoint_heights"] as Dictionary
	var out: Dictionary = {}
	for endpoint: Dictionary in _parcel_room_endpoints(parcel, program, cache):
		out[(endpoint.cell as Vector3i).y] = true
	if bool(cache.get(&"enabled", false)):
		var entry := cache.get(key, {}) as Dictionary
		entry[&"endpoint_heights"] = out
		cache[key] = entry
	return out


static func _endpoints_form_straight_link(left: Dictionary,
		right: Dictionary) -> bool:
	if (left.cell as Vector3i).y != (right.cell as Vector3i).y \
			or (left.facing as Vector3i) != -(right.facing as Vector3i):
		return false
	var forward := left.facing as Vector3i
	var delta := (right.cell as Vector3i) - (left.cell as Vector3i)
	var distance: int = delta.x * forward.x + delta.y * forward.y \
		+ delta.z * forward.z
	return distance >= 3 and distance <= 7 and posmod(distance, 2) == 1 \
		and delta == forward * distance


static func _proposal_component_bounds(proposal: Dictionary,
		program: SettlementFabricProgram) -> Array[AABB]:
	var out: Array[AABB] = []
	for component: Dictionary in \
			StaggeredFabricCompiler.proposal_components(proposal):
		var recipe_value := program.recipe(StringName(component.recipe_id))
		if recipe_value == null:
			return [] as Array[AABB]
		var transform := FabricRecipe.lattice_transform(
			component.origin as Vector3i, int(component.yaw_quarters))
		out.append(transform * recipe_value.local_clearance_bounds)
	return out


static func _style_invariant_proposal_bounds(proposal: Dictionary,
		program: SettlementFabricProgram) -> Array[AABB]:
	## Theme graph-colouring happens after parcel selection, but it is allowed to
	## choose authored roof/facade variants with slightly different measured
	## envelopes. Search therefore qualifies the union of every legal style for
	## the already-fixed geometry. A later colour choice can never make two roofs
	## intersect when the fallback hash happened to test the narrower variant.
	var out: Array[AABB] = []
	for theme: StringName in [&"blue", &"orange", &"amber", &"stone"]:
		for roof_theme: StringName in [&"blue", &"orange"]:
			for facade_phase in 2:
				var styled := proposal.duplicate(true)
				styled["theme"] = theme
				styled["roof_theme"] = roof_theme
				styled["facade_phase"] = facade_phase
				var bounds := _proposal_component_bounds(styled, program)
				if bounds.is_empty():
					return [] as Array[AABB]
				out.append_array(bounds)
	return out


static func _cached_proposal(parcel: WarrenBuildingParcel,
		cache: Dictionary) -> Dictionary:
	if not bool(cache.get(&"enabled", false)):
		return WarrenParcelConstruction.proposal(parcel)
	var key := _parcel_cache_key(parcel)
	var entry := cache.get(key, {}) as Dictionary
	if not entry.has(&"proposal"):
		entry[&"proposal"] = WarrenParcelConstruction.proposal(parcel)
		cache[key] = entry
	return entry[&"proposal"] as Dictionary


static func _cached_proposal_component_bounds(parcel: WarrenBuildingParcel,
		program: SettlementFabricProgram, cache: Dictionary) -> Array[AABB]:
	if not bool(cache.get(&"enabled", false)):
		return _style_invariant_proposal_bounds(
			WarrenParcelConstruction.proposal(parcel), program)
	var key := _parcel_cache_key(parcel)
	var entry := cache.get(key, {}) as Dictionary
	if not entry.has(&"bounds"):
		entry[&"bounds"] = _style_invariant_proposal_bounds(
			_cached_proposal(parcel, cache), program)
		# _cached_proposal may have installed the proposal in a fresh dictionary.
		# Merge into that authoritative entry rather than replacing it.
		var current := cache.get(key, {}) as Dictionary
		current[&"bounds"] = entry[&"bounds"]
		cache[key] = current
		entry = current
	var out: Array[AABB] = []
	out.assign(entry[&"bounds"] as Array)
	return out


static func _parcel_cache_key(parcel: WarrenBuildingParcel) -> StringName:
	return StringName("parcel.%d" % parcel.get_instance_id())


static func _party_wall_seams(proposals: Array[Dictionary]) -> Dictionary:
	## StaggeredFabricCompiler owns the geometric compatibility predicate, but
	## its general embedding adapter deliberately names units `embedding.*`.
	## Volumetric towns use a separate `volume.*` namespace, so derive the actual
	## unit ids here instead of copying or rewriting foreign ids after the fact.
	var out: Dictionary = {}
	for proposal: Dictionary in proposals:
		out[StringName(proposal.stable_id)] = [] as Array[StringName]
	for left_index in proposals.size():
		var left := proposals[left_index]
		for right_index in range(left_index + 1, proposals.size()):
			var right := proposals[right_index]
			if not StaggeredFabricCompiler.classified_roof_seam_compatible(
					left, right):
				continue
			var seams := out[StringName(right.stable_id)] as Array[StringName]
			for component: Dictionary in \
					StaggeredFabricCompiler.proposal_components(left):
				seams.append(StringName("volume.%s.%s" % [
					StringName(left.stable_id), StringName(component.role)]))
	return out


static func _assign_neighborhood_styles(proposals: Array[Dictionary],
		roof_topology: FabricRoofTopologyPlan, world_seed: int) -> bool:
	## A palette hash is not a streetscape composition rule.  Colour and facade
	## phase are graph-coloured over the sealed roof neighbourhood, so a run of
	## adjacent parcels cannot accidentally compile as one repeated house row.
	## Geometry, height, and roof seams remain plan facts; this pass changes no
	## footprint and therefore cannot invalidate the town solve.
	var junction_modules := FabricRoofJunctionModuleTable.build(proposals,
		roof_topology)
	if junction_modules.is_empty():
		return false
	var rules_by_id := junction_modules.rules_by_id as Dictionary
	var by_id: Dictionary = {}
	for proposal: Dictionary in proposals:
		by_id[StringName(proposal.stable_id)] = proposal
	var ids: Array[StringName] = []
	ids.assign(by_id.keys())
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		var a_degree := (roof_topology.fact(a).junctions as Array).size()
		var b_degree := (roof_topology.fact(b).junctions as Array).size()
		return a_degree > b_degree if a_degree != b_degree \
			else String(a) < String(b))
	var assigned: Dictionary = {}
	var theme_counts := {&"blue": 0, &"orange": 0, &"amber": 0, &"stone": 0}
	var forced_orange_roof_count := 0
	for proposal: Dictionary in proposals:
		forced_orange_roof_count += int(_has_forced_orange_roof(proposal))
	# Compact tower and slim roofs currently have two geometry arrangements but
	# both arrangements render genuine orange assets. Reserve those inevitable
	# votes before assigning the flexible square/long roofs; otherwise an early
	# square parcel may choose orange while the counter is still empty and the
	# later forced roofs turn the whole skyline orange again.
	var roof_family_counts := {
		&"blue_tile": 0,
		&"boarded": 0,
		&"orange_tile": forced_orange_roof_count,
	}
	var orange_roof_cap := maxi(forced_orange_roof_count,
		floori(float(proposals.size()) * FLEXIBLE_ORANGE_ROOF_CAP_RATIO))
	for proposal_id: StringName in ids:
		var proposal := by_id[proposal_id] as Dictionary
		var neighbor_theme_counts := {&"blue": 0, &"orange": 0, &"amber": 0,
			&"stone": 0}
		var neighbor_phases: Dictionary = {}
		for seam: Dictionary in roof_topology.fact(proposal_id).junctions as Array:
			var neighbor_id := StringName(seam.neighbor_id)
			if not assigned.has(neighbor_id):
				continue
			var neighbor := assigned[neighbor_id] as Dictionary
			var neighbor_theme := StringName(neighbor.theme)
			neighbor_theme_counts[neighbor_theme] = int(
				neighbor_theme_counts[neighbor_theme]) + 1
			neighbor_phases[int(neighbor.facade_phase)] = true
		var theme := _select_facade_family(proposal, neighbor_theme_counts,
			theme_counts, world_seed)
		var first_phase := posmod(_style_hash(world_seed ^ 0x5f3759df,
			proposal), 2)
		var facade_phase := first_phase
		if neighbor_phases.has(facade_phase) \
				and not neighbor_phases.has(1 - facade_phase):
			facade_phase = 1 - facade_phase
		proposal["theme"] = theme
		var roof_family := _select_roof_family(proposal, roof_topology,
			assigned, roof_family_counts, world_seed)
		if not _has_forced_orange_roof(proposal) \
				and roof_family == &"orange_tile" \
				and int(roof_family_counts[&"orange_tile"]) >= orange_roof_cap:
			roof_family = _non_orange_roof_family(proposal)
		proposal["roof_theme"] = &"orange" if roof_family == &"orange_tile" \
			else &"blue"
		proposal["facade_phase"] = facade_phase
		proposal["roof_signature"] = StringName(
			roof_topology.fact(proposal_id).signature)
		var junction_rules: Array[Dictionary] = []
		junction_rules.assign(rules_by_id[proposal_id] as Array)
		proposal["roof_junction_rules"] = junction_rules
		var trim_sides: Array[int] = []
		for rule: Dictionary in junction_rules:
			if bool(rule.emits_module) \
					and StringName(rule.module_family) == &"eave_seam" \
					and not trim_sides.has(int(rule.side)):
				trim_sides.append(int(rule.side))
		trim_sides.sort()
		proposal["roof_trim_sides"] = trim_sides
		by_id[proposal_id] = proposal
		assigned[proposal_id] = proposal
		theme_counts[theme] = int(theme_counts[theme]) + 1
		if not _has_forced_orange_roof(proposal):
			roof_family_counts[roof_family] = int(
				roof_family_counts[roof_family]) + 1
	for index in proposals.size():
		proposals[index] = by_id[StringName(proposals[index].stable_id)] \
			as Dictionary
	return true


static func _select_facade_family(proposal: Dictionary,
		neighbor_counts: Dictionary, family_counts: Dictionary,
		world_seed: int) -> StringName:
	## The measured construction families compete on the sealed roof-contact
	## graph. Adjacency dominates the global count, then a seed-stable rotation
	## breaks exact ties. This makes the facade a real geometric/material event
	## in the streetscape rather than a tint assigned after clearance.
	##
	## This chooses the UPPER storeys only -- see UPPER_FACADE_FAMILIES for why
	## rock is not among them.
	var families: Array[StringName] = []
	families.assign(UPPER_FACADE_FAMILIES)
	var count := families.size()
	var tie_phase := posmod(_style_hash(world_seed ^ 0x243f6a88,
		proposal), count)
	families.sort_custom(func(left: StringName, right: StringName) -> bool:
		var left_cost := int(neighbor_counts.get(left, 0)) * 8 \
			+ int(family_counts.get(left, 0))
		var right_cost := int(neighbor_counts.get(right, 0)) * 8 \
			+ int(family_counts.get(right, 0))
		if left_cost != right_cost:
			return left_cost < right_cost
		var left_index := posmod(UPPER_FACADE_FAMILIES.find(left) - tie_phase,
			count)
		var right_index := posmod(UPPER_FACADE_FAMILIES.find(right) - tie_phase,
			count)
		return left_index < right_index)
	return families[0]


static func _select_roof_family(proposal: Dictionary,
		roof_topology: FabricRoofTopologyPlan, assigned: Dictionary,
		family_counts: Dictionary, world_seed: int) -> StringName:
	var kind := StringName(proposal.get("kind", ""))
	if kind == &"tower" or kind == &"slim":
		return &"orange_tile"
	var blue_family := &"blue_tile" if kind == &"long" else &"boarded"
	var neighbor_counts := {
		&"blue_tile": 0,
		&"boarded": 0,
		&"orange_tile": 0,
	}
	for seam: Dictionary in roof_topology.fact(
			StringName(proposal.stable_id)).junctions as Array:
		var neighbor := assigned.get(StringName(seam.neighbor_id), {}) \
			as Dictionary
		if neighbor.is_empty():
			continue
		var neighbor_kind := StringName(neighbor.get("kind", ""))
		var neighbor_roof_theme := StringName(neighbor.get("roof_theme", ""))
		var family := &"orange_tile" if neighbor_kind == &"tower" \
			or neighbor_kind == &"slim" or neighbor_roof_theme == &"orange" \
			else &"blue_tile" if neighbor_kind == &"long" else &"boarded"
		neighbor_counts[family] = int(neighbor_counts[family]) + 1
	var blue_cost := int(neighbor_counts[blue_family]) * 8 \
		+ int(family_counts[blue_family])
	var orange_cost := int(neighbor_counts[&"orange_tile"]) * 8 \
		+ int(family_counts[&"orange_tile"])
	if blue_cost != orange_cost:
		return blue_family if blue_cost < orange_cost else &"orange_tile"
	return blue_family if posmod(_style_hash(world_seed ^ 0x6a09e667,
		proposal), 2) == 0 else &"orange_tile"


static func _has_forced_orange_roof(proposal: Dictionary) -> bool:
	var kind := StringName(proposal.get("kind", ""))
	return kind == &"tower" or kind == &"slim"


static func _non_orange_roof_family(proposal: Dictionary) -> StringName:
	return &"blue_tile" if StringName(proposal.get("kind", "")) == &"long" \
		else &"boarded"


static func _style_hash(world_seed: int, proposal: Dictionary) -> int:
	var origin := proposal.origin as Vector3i
	var value := world_seed
	value = int((value ^ (origin.x * 73856093)) * 1099511628211)
	value = int((value ^ (origin.y * 19349663)) * 1099511628211)
	value = int((value ^ (origin.z * 83492791)) * 1099511628211)
	value ^= int(proposal.storeys) * 2654435761
	return value
