class_name VillageOutskirtsSolver
extends RefCounted

## Places sparse ground shelters only after the dense urban transaction is
## sealed. Each admitted shelter includes a proved short connection to the
## existing public graph; failed candidates leave no partial payload.
const SURVEY_LIMIT := 256
const PATH_HALF_WIDTH := VillageProgram.MODULE * 0.5
const PATH_CLEARANCE := PATH_HALF_WIDTH + 0.5


static func solve(terrain: VillageTerrainView, settlement_id: StringName,
		arrival: Vector2, primary_axis: Vector2, tier: StringName,
		theme: StringName, program: VillageProgram,
		urban: VillageUrbanFabricPlan,
		existing_volumes: Array[VillageOccupancyVolume]
		) -> VillageOutskirtsPlan:
	assert(terrain != null and not settlement_id.is_empty())
	assert(arrival.is_finite() and primary_axis.is_normalized())
	if program == null or program.outskirts_program == null \
			or urban == null or not urban.accepted:
		return _rejected(&"urban_fabric")
	var plan := VillageOutskirtsPlan.new()
	var occupancy := VillageOccupancy.new()
	if not occupancy.add_all(existing_volumes):
		return _rejected(&"existing_occupancy")
	var blockers: Array[VillageMassingPlacement] = []
	blockers.assign(urban.massing.placements)
	var contacts := _ground_contacts(urban.circulation)
	var survey_cache: Dictionary = {}
	var target := program.outskirts_program.target_shelters(tier)
	for slot_index in target:
		var spec := program.outskirts_program.spec_for_slot(
			settlement_id, slot_index)
		var footprint := spec.ground_contact_local_rect.size * 0.5
		var footprint_key := "%0.3f:%0.3f" % [footprint.x, footprint.y]
		if not survey_cache.has(footprint_key):
			survey_cache[footprint_key] = VillageTerrainSurvey.discover(
				terrain, arrival, footprint, primary_axis,
				VillageOutskirtsProgram.OUTER_RADIUS, SURVEY_LIMIT,
				VillageOutskirtsProgram.INNER_RADIUS)
		var accepted := false
		var rejection := &"terrain_perches"
		for perch: VillageTerrainPerch in survey_cache[footprint_key]:
			var radius := perch.anchor.distance_to(arrival)
			if radius < VillageOutskirtsProgram.INNER_RADIUS - 0.001 \
					or radius > VillageOutskirtsProgram.OUTER_RADIUS + 0.001 \
					or not perch.is_naturally_supported() \
					or perch.relief > spec.max_ground_relief + 0.001:
				continue
			var slot := VillageMassingSlot.new(StringName(
				"outskirts.shelter.%02d" % slot_index), spec.asset_id)
			for facade_index in 2:
				var placement := VillageMassingPlacement.from_perch(slot,
					spec, perch, facade_index)
				if not placement.configure_entrance(spec, terrain,
						program.elevated_program) \
						or not placement.ground_accessible:
					rejection = &"entrance"
					continue
				var candidate := _candidate(terrain, settlement_id, arrival,
					primary_axis, theme, program, urban, spec, placement,
					contacts, blockers, occupancy)
				if not bool(candidate.accepted):
					rejection = candidate.reason
					continue
				plan.entries.append_array(candidate.entries)
				plan.volumes.append_array(candidate.volumes)
				plan.surfaces.append_array(candidate.surfaces)
				plan.clearances.append_array(candidate.clearances)
				plan.route_stair_count += int(candidate.stair_count)
				plan.placements.append(placement)
				assert(occupancy.add_all(candidate.volumes))
				blockers.append(placement)
				accepted = true
				break
			if accepted:
				break
		plan.audit.append({"slot": slot_index, "asset_id": spec.asset_id,
			"accepted": accepted, "reason": &"accepted" if accepted \
				else rejection})
	plan.accepted = true
	plan.reason = &"accepted"
	assert(plan.validate(program.outskirts_program, tier))
	return plan


static func _candidate(terrain: VillageTerrainView,
		settlement_id: StringName, arrival: Vector2, primary_axis: Vector2,
		theme: StringName, program: VillageProgram,
		urban: VillageUrbanFabricPlan, spec: VillageAssetSpec,
		placement: VillageMassingPlacement,
		contacts: Array[VillageCirculationNode],
		blockers: Array[VillageMassingPlacement], occupancy: VillageOccupancy
		) -> Dictionary:
	var stable_id := StringName("%s.%s" % [settlement_id,
		placement.stable_key])
	var solid := VillageOccupancyVolume.new(VillageOccupancy.Role.SOLID,
		placement.solid_centre, placement.solid_half_extents,
		placement.solid_angle, placement.solid_min_y,
		placement.solid_max_y, StringName("%s.solid" % stable_id), stable_id)
	var access := VillageOccupancyVolume.new(VillageOccupancy.Role.HEADROOM,
		(placement.entrance + placement.entrance_ground_contact) * 0.5,
		Vector2(maxf(placement.entrance.distance_to(
			placement.entrance_ground_contact), VillageProgram.MODULE) * 0.5,
			placement.access_half_width), placement.entrance_outward.angle(),
		placement.access_min_y, placement.access_max_y,
		StringName("%s.access" % stable_id), stable_id)
	for volume: VillageOccupancyVolume in [solid, access]:
		if not occupancy.conflicts(volume).is_empty():
			return {"accepted": false, "reason": &"occupancy"}
	var from := VillageCirculationNode.new(
		StringName("%s.terrain" % placement.stable_key),
		VillageCirculationNode.Kind.TERRAIN_CONTACT,
		placement.street_contact, placement.street_contact_y,
		placement.stable_key, placement.entrance_outward)
	var ordered_contacts := contacts.duplicate()
	ordered_contacts.sort_custom(func(a: VillageCirculationNode,
			b: VillageCirculationNode) -> bool:
		var a_distance := a.point.distance_squared_to(from.point)
		var b_distance := b.point.distance_squared_to(from.point)
		if a_distance != b_distance:
			return a_distance < b_distance
		return String(a.stable_key) < String(b.stable_key))
	var route: VillageCirculationLink
	var all_blockers := blockers.duplicate()
	all_blockers.append(placement)
	for contact: VillageCirculationNode in ordered_contacts:
		if from.point.distance_to(contact.point) \
				> VillageOutskirtsProgram.MAX_CONNECTOR_LENGTH + 0.001:
			continue
		route = VillageGroundRouter.best_link(terrain, arrival,
			primary_axis, from, contact, all_blockers,
			program.elevated_program, urban.market.blocking_volumes())
		if route != null:
			break
	if route == null:
		return {"accepted": false, "reason": &"connector"}
	var route_plan := VillageCirculationPlan.new()
	route_plan.accepted = true
	route_plan.reason = &"accepted"
	route_plan.links.append(route)
	var stairs := VillageRouteStairFabricSolver.solve(settlement_id,
		route_plan, program.elevated_program)
	if not stairs.accepted:
		return {"accepted": false,
			"reason": StringName("stairs_%s" % String(stairs.reason))}
	var building_transform := placement.building_transform(spec)
	var entries: Array[Dictionary] = [{"asset_id":
		spec.asset_for_theme(theme), "stable_id": stable_id,
		"transform": building_transform}]
	entries.append_array(stairs.entries)
	var volumes: Array[VillageOccupancyVolume] = [solid, access]
	volumes.append_array(stairs.volumes)
	var surfaces: Array[FeatureGroundShape] = []
	var clearances: Array[FeatureGroundShape] = []
	var ground_owner := StringName("%s.ground_circulation" % settlement_id)
	var walk_network := StringName("%s.urban.walk_network" % settlement_id)
	for index in range(1, route.samples.size()):
		var a := route.samples[index - 1]
		var b := route.samples[index]
		var a2 := Vector2(a.x, a.z)
		var b2 := Vector2(b.x, b.z)
		if a2.distance_to(b2) <= 0.01:
			continue
		var route_id := StringName("%s.%s.outskirts.%03d" % [
			settlement_id, route.stable_key, index])
		surfaces.append(FeatureGroundShape.capsule(a2, b2,
			PATH_HALF_WIDTH, FeatureGroundField.WORN_PATH,
			VillagePlan.SURFACE_PRIORITY, route_id))
		clearances.append(FeatureGroundShape.capsule(a2, b2,
			PATH_CLEARANCE, FeatureGroundField.NATURAL, 0,
			StringName("%s.clearance" % route_id)))
		volumes.append(VillageOccupancyVolume.new(
			VillageOccupancy.Role.HEADROOM, (a2 + b2) * 0.5,
			Vector2(a2.distance_to(b2) * 0.5, PATH_HALF_WIDTH),
			(b2 - a2).angle(), minf(a.y, b.y),
			maxf(a.y, b.y) + TraversalEnvelope.MIN_HEADROOM,
			StringName("%s.headroom" % route_id), ground_owner,
			walk_network))
	var lot := spec.world_lot(building_transform)
	clearances.append(FeatureGroundShape.oriented_rect(
		lot.centre, lot.half_extents, lot.angle,
		FeatureGroundField.NATURAL, 0,
		StringName("%s.clearance" % stable_id)))
	if not VillageOccupancy.first_cross_conflict(volumes,
			occupancy.volumes()).is_empty():
		return {"accepted": false, "reason": &"route_occupancy"}
	var local := VillageOccupancy.new()
	if not local.add_all(volumes):
		return {"accepted": false, "reason": &"internal_occupancy"}
	return {"accepted": true, "reason": &"accepted", "entries": entries,
		"volumes": volumes, "surfaces": surfaces,
		"clearances": clearances, "stair_count": stairs.stair_count}


static func _ground_contacts(circulation: VillageCirculationPlan
		) -> Array[VillageCirculationNode]:
	var out: Array[VillageCirculationNode] = []
	for node: VillageCirculationNode in circulation.nodes:
		if node.kind == VillageCirculationNode.Kind.ARRIVAL \
				or node.kind == VillageCirculationNode.Kind.TERRAIN_CONTACT:
			out.append(node)
	return out


static func _rejected(reason: StringName) -> VillageOutskirtsPlan:
	var plan := VillageOutskirtsPlan.new()
	plan.reason = reason
	return plan
