class_name VillageUrbanFabricSolver
extends RefCounted

## Orchestrates one bounded, atomic terrain-led village transaction. Producer
## solvers remain independently testable; this class only composes their typed
## outputs and performs the final cross-system occupancy proof.
const STREET_HALF_WIDTH := VillageProgram.MODULE * 0.5
const STREET_CLEARANCE := STREET_HALF_WIDTH + 0.5


static func solve(terrain: VillageTerrainView, settlement_id: StringName,
		arrival: Vector2, primary_axis: Vector2, tier: StringName,
		theme: StringName, program: VillageProgram) -> VillageUrbanFabricPlan:
	assert(terrain != null and not settlement_id.is_empty())
	assert(arrival.is_finite() and primary_axis.is_normalized())
	assert(program != null and VillageProgram.THEMES.has(theme))
	var market := VillageMarketSolver.solve(terrain, settlement_id, arrival,
		primary_axis, tier, theme, program)
	if not market.accepted:
		var market_rejected := VillageUrbanFabricPlan.new()
		market_rejected.market = market
		return _rejected(market_rejected,
			StringName("market_%s" % String(market.reason)))
	var massings := VillageMassingSolver.solve_candidates(terrain, arrival,
		primary_axis, program, tier, market.volumes)
	if massings.is_empty():
		var rejected := VillageUrbanFabricPlan.new()
		rejected.market = market
		rejected.massing = VillageMassingSolver.solve(terrain, arrival,
			primary_axis, program, tier, market.volumes)
		rejected.candidate_audit.append({"massing":
			rejected.massing.candidate_audit})
		return _rejected(rejected,
			StringName("massing_%s" % String(rejected.massing.reason)))
	var last_rejection: VillageUrbanFabricPlan
	var candidate_audit: Array[Dictionary] = []
	for massing: VillageMassingPlan in massings:
		var candidate := _solve_candidate(terrain, settlement_id, arrival,
			primary_axis, tier, theme, program, market, massing)
		candidate_audit.append({
			"building_count": massing.building_count,
			"elevation_band_count": massing.elevation_band_count,
			"half_rise_count": massing.half_rise_count,
			"terrain_support_ratio": massing.terrain_support_ratio,
			"reason": candidate.reason,
			"ground_candidates": candidate.circulation.ground_candidate_count \
				if candidate.circulation != null else 0,
			"ground_links": candidate.circulation.ground_street_count \
				if candidate.circulation != null else 0,
			"aerial_candidates": candidate.circulation.aerial_candidate_count \
				if candidate.circulation != null else 0,
			"aerial_candidate_edges": \
				candidate.circulation.aerial_candidate_edges \
				if candidate.circulation != null else [],
			"components": candidate.circulation.disconnected_components \
				if candidate.circulation != null else [],
		})
		candidate.candidate_audit.assign(candidate_audit)
		if candidate.accepted:
			return candidate
		last_rejection = candidate
	last_rejection.candidate_audit.assign(candidate_audit)
	return last_rejection


static func _solve_candidate(terrain: VillageTerrainView,
		settlement_id: StringName, arrival: Vector2, primary_axis: Vector2,
		tier: StringName, theme: StringName, program: VillageProgram,
		market: VillageMarketPlan,
		massing: VillageMassingPlan) -> VillageUrbanFabricPlan:
	var plan := VillageUrbanFabricPlan.new()
	plan.market = market
	plan.massing = massing
	plan.entries.append_array(market.entries)
	plan.volumes.append_array(market.volumes)
	plan.surfaces.append_array(market.surfaces)
	plan.clearances.append_array(market.clearances)
	plan.circulation = VillageCirculationSolver.solve(terrain, arrival,
		primary_axis, plan.massing, program.elevated_program, market)
	if not plan.circulation.accepted:
		return _rejected(plan,
			StringName("circulation_%s" % String(plan.circulation.reason)))
	plan.route_stairs = VillageRouteStairFabricSolver.solve(settlement_id,
		plan.circulation, program.elevated_program)
	if not plan.route_stairs.accepted:
		return _rejected(plan, StringName("route_stairs_%s" \
			% String(plan.route_stairs.reason)))
	var support_exclusions: Array[Dictionary] = []
	var railing_exclusions: Array[Dictionary] = []
	var openings: Array[FeatureGroundShape] = []
	var support_reservations: Array[VillageOccupancyVolume] = []
	for volume: VillageOccupancyVolume in market.volumes:
		support_reservations.append(volume)
	for volume: VillageOccupancyVolume in plan.route_stairs.volumes:
		support_reservations.append(volume)
	for placement: VillageMassingPlacement in plan.massing.placements:
		var owner := StringName("%s.urban.%s" % [settlement_id,
			placement.stable_key])
		support_reservations.append(_building_solid_volume(owner, placement))
	for volume: VillageOccupancyVolume in market.volumes:
		support_exclusions.append({
			"shape": FeatureGroundShape.oriented_rect(volume.centre,
				volume.half_extents, volume.angle),
			"min_y": volume.y_range.x,
			"max_y": volume.y_range.y,
		})
	for placement: VillageMassingPlacement in plan.massing.placements:
		var stable_id := StringName("%s.urban.%s" % [settlement_id,
			placement.stable_key])
		var spec := program.assets[placement.asset_id] as VillageAssetSpec
		var support := VillageBuildingSupportSolver.solve(terrain, stable_id,
			placement, spec, program, support_reservations)
		if not support.accepted:
			return _rejected(plan, StringName("support_%s_%s" % [
				placement.stable_key, support.reason]))
		var skirt := VillageSkirtDeckSolver.solve(terrain, stable_id,
			placement, spec, support)
		if not skirt.accepted:
			return _rejected(plan, StringName("skirt_%s_%s" % [
				placement.stable_key, skirt.reason]))
		plan.supports.append(support)
		support_reservations.append_array(support.volumes)
		plan.skirts.append(skirt)
		plan.natural_building_count += 1 \
			if placement.perch.is_naturally_supported() else 0
		plan.retained_building_count += 0 \
			if placement.perch.is_naturally_supported() else 1
		if support.mode == VillageBuildingSupportPlan.Mode.ROCK_CORE:
			plan.rock_piece_count += support.pieces.size()
		else:
			plan.foundation_piece_count += support.pieces.size()
		plan.entries.append_array(support.pieces)
		plan.volumes.append_array(support.volumes)
		_building(plan, stable_id, placement, spec, theme)
		if not support.core.is_empty():
			support_exclusions.append({"shape":
				FeatureGroundShape.oriented_rect(support.core.centre,
					support.core.half_extents, float(support.core.angle)),
				"min_y": support.terrain_bounds.x,
				"max_y": placement.floor_y})
		var building_exclusion := {"shape": placement.solid_shape(),
			"min_y": placement.solid_min_y,
			"max_y": placement.solid_max_y}
		# A route may legitimately pass above a lower roof, but its independent
		# timber posts cannot descend through that occupied shell. Feed the same
		# 3D building envelope to support selection and railing clipping.
		support_exclusions.append(building_exclusion)
		railing_exclusions.append(building_exclusion)
		openings.append(placement.access_shape())
	for volume: VillageOccupancyVolume in plan.route_stairs.volumes:
		var exclusion := {"shape": FeatureGroundShape.oriented_rect(
			volume.centre, volume.half_extents, volume.angle),
			"min_y": volume.y_range.x, "max_y": volume.y_range.y}
		support_exclusions.append(exclusion)
		railing_exclusions.append(exclusion)
	var cells := VillageTimberCellCompiler.compile(settlement_id,
		plan.circulation, plan.skirts, plan.massing.placements,
		plan.route_stairs)
	plan.timber = VillageTimberFabricSolver.solve(terrain, settlement_id,
		cells, program.elevated_program, support_exclusions,
		railing_exclusions, openings)
	if not plan.timber.accepted:
		return _rejected(plan,
			StringName("timber_%s" % String(plan.timber.reason)))
	plan.entries.append_array(plan.timber.entries)
	plan.volumes.append_array(plan.timber.volumes)
	plan.entries.append_array(plan.route_stairs.entries)
	plan.volumes.append_array(plan.route_stairs.volumes)
	plan.clearances.append_array(plan.route_stairs.clearances)
	plan.public_stair_count = plan.route_stairs.stair_count
	var stairs := _entrance_stairs(settlement_id, plan.massing.placements,
		program.elevated_program)
	plan.entries.append_array(stairs.entries)
	plan.volumes.append_array(stairs.volumes)
	plan.entrance_stair_count = int(stairs.count)
	var ground := _ground_fabric(terrain, settlement_id, plan.circulation)
	if not bool(ground.accepted):
		return _rejected(plan,
			StringName("ground_%s" % String(ground.reason)))
	plan.surfaces.append_array(ground.surfaces)
	plan.clearances.append_array(ground.clearances)
	_append_elevated_clearances(plan, settlement_id)
	var occupancy := VillageOccupancy.new()
	var conflict := occupancy.first_conflict(plan.volumes)
	if not conflict.is_empty():
		var candidate := conflict.candidate as VillageOccupancyVolume
		var existing := conflict.existing as VillageOccupancyVolume
		return _rejected(plan, StringName("occupancy_%s[%s]_%s[%s]" % [
			candidate.stable_id, candidate.owner_id,
			existing.stable_id, existing.owner_id]))
	assert(occupancy.add_all(plan.volumes))
	plan.accepted = true
	plan.reason = &"accepted"
	assert(plan.validate(program, tier))
	return plan


static func _building(plan: VillageUrbanFabricPlan, stable_id: StringName,
		placement: VillageMassingPlacement, spec: VillageAssetSpec,
		theme: StringName) -> void:
	var transform := placement.building_transform(spec)
	plan.entries.append({"asset_id": spec.asset_for_theme(theme),
		"stable_id": stable_id, "transform": transform})
	for attachment: VillageAttachedAssetSpec in spec.attachments:
		plan.entries.append({"asset_id": attachment.asset_for_theme(theme),
			"stable_id": StringName("%s.component.%s" % [stable_id,
				attachment.stable_key]),
			"transform": attachment.world_transform(transform)})
	plan.volumes.append(_building_solid_volume(stable_id, placement))
	plan.volumes.append(VillageOccupancyVolume.new(
		VillageOccupancy.Role.HEADROOM,
		placement.entrance + placement.entrance_outward * 1.1,
		Vector2(1.1, placement.access_half_width),
		placement.entrance_outward.angle(), placement.floor_y,
		placement.floor_y + TraversalEnvelope.MIN_HEADROOM,
		StringName("%s.access" % stable_id), stable_id))
	var lot := spec.world_lot(transform)
	plan.clearances.append(FeatureGroundShape.oriented_rect(lot.centre,
		lot.half_extents, lot.angle, FeatureGroundField.NATURAL, 0,
		StringName("%s.clearance" % stable_id)))
	plan.buildings.append({"stable_id": stable_id,
		"key": placement.stable_key, "asset_id": placement.asset_id,
		"transform": transform, "floor_y": placement.floor_y,
		"natural": placement.perch.is_naturally_supported(),
		"entrance": placement.entrance,
		"entrance_outward": placement.entrance_outward})


static func _building_solid_volume(stable_id: StringName,
		placement: VillageMassingPlacement) -> VillageOccupancyVolume:
	return VillageOccupancyVolume.new(VillageOccupancy.Role.SOLID,
		placement.solid_centre, placement.solid_half_extents,
		placement.solid_angle, placement.solid_min_y,
		placement.solid_max_y, StringName("%s.solid" % stable_id), stable_id)


static func _entrance_stairs(settlement_id: StringName,
		placements: Array[VillageMassingPlacement],
		vocabulary: VillageElevatedProgram) -> Dictionary:
	var entries: Array[Dictionary] = []
	var volumes: Array[VillageOccupancyVolume] = []
	for placement: VillageMassingPlacement in placements:
		if placement.entrance_stair_count <= 0:
			continue
		var low := placement.entrance_ground_contact
		var high_direction := -placement.entrance_outward
		var yaw := Vector2.UP.angle() - high_direction.angle()
		var basis := Basis(Vector3.UP, yaw)
		var point := low
		var segment_y := placement.entrance_stair_base_y
		var owner := StringName("%s.urban.%s" % [settlement_id,
			placement.stable_key])
		var walk_network_id := StringName("%s.urban.walk_network" \
			% settlement_id)
		for index in placement.entrance_stair_count:
			var stable_id := StringName("%s.urban.%s.entrance_stair.%02d" % [
				settlement_id, placement.stable_key, index])
			var local_contact := Vector3(
				vocabulary.stair_aabb.get_center().x,
				vocabulary.stair_aabb.position.y,
				vocabulary.stair_aabb.end.z)
			entries.append({"asset_id": vocabulary.stair_asset_id,
				"stable_id": stable_id,
				"transform": Transform3D(basis,
					Vector3(point.x, segment_y, point.y)
						- basis * local_contact)})
			var centre := point + high_direction \
				* vocabulary.stair_module_run * 0.5
			volumes.append(VillageOccupancyVolume.new(
				VillageOccupancy.Role.WALK_SURFACE, centre,
				Vector2(vocabulary.stair_module_run,
					vocabulary.stair_aabb.size.x) * 0.5,
				high_direction.angle(), segment_y,
				segment_y + vocabulary.stair_aabb.size.y,
				StringName("%s.walk" % stable_id), owner,
				walk_network_id))
			point += high_direction * vocabulary.stair_module_run
			segment_y += vocabulary.stair_aabb.size.y
	return {"entries": entries, "volumes": volumes,
		"count": entries.size()}


static func _ground_fabric(terrain: VillageTerrainView,
		settlement_id: StringName,
		circulation: VillageCirculationPlan) -> Dictionary:
	var surfaces: Array[FeatureGroundShape] = []
	var clearances: Array[FeatureGroundShape] = []
	for link: VillageCirculationLink in circulation.links:
		if String(link.stable_key).begins_with("market."):
			continue
		if link.kind != VillageCirculationLink.Kind.GROUND_STREET \
				and link.kind != VillageCirculationLink.Kind.GROUND_STAIR:
			continue
		for index in range(1, link.samples.size()):
			var a := link.samples[index - 1]
			var b := link.samples[index]
			for sample_index in 3:
				var point3 := a.lerp(b, float(sample_index) / 2.0)
				if terrain.is_wet(Vector2(point3.x, point3.z)):
					return {"accepted": false, "reason": &"water",
						"surfaces": [], "clearances": []}
			var a2 := Vector2(a.x, a.z)
			var b2 := Vector2(b.x, b.z)
			var stable_id := StringName("%s.%s.ground.%03d" % [
				settlement_id, link.stable_key, index])
			surfaces.append(FeatureGroundShape.capsule(a2, b2,
				STREET_HALF_WIDTH, FeatureGroundField.WORN_PATH,
				VillagePlan.SURFACE_PRIORITY, stable_id))
			clearances.append(FeatureGroundShape.capsule(a2, b2,
				STREET_CLEARANCE, FeatureGroundField.NATURAL, 0,
				StringName("%s.clearance" % stable_id)))
	return {"accepted": true, "reason": &"accepted",
		"surfaces": surfaces, "clearances": clearances}


static func _append_elevated_clearances(plan: VillageUrbanFabricPlan,
		settlement_id: StringName) -> void:
	for platform: VillagePlatformRegion in plan.circulation.platforms:
		for index in platform.cell_centres.size():
			plan.clearances.append(FeatureGroundShape.oriented_rect(
				platform.cell_centres[index],
				Vector2.ONE * VillageProgram.MODULE * 0.5, platform.yaw,
				FeatureGroundField.NATURAL, 0,
				StringName("%s.%s.clearance.%03d" % [settlement_id,
					platform.stable_key, index])))
	for link: VillageCirculationLink in plan.circulation.links:
		if not link.is_aerial():
			continue
		for index in range(1, link.samples.size()):
			var a := link.samples[index - 1]
			var b := link.samples[index]
			plan.clearances.append(FeatureGroundShape.capsule(
				Vector2(a.x, a.z), Vector2(b.x, b.z),
				VillageProgram.MODULE * 0.5, FeatureGroundField.NATURAL, 0,
				StringName("%s.%s.clearance.%03d" % [settlement_id,
					link.stable_key, index])))
	for skirt: VillageSkirtDeckPlan in plan.skirts:
		for cell: VillageTimberCell in skirt.cells:
			if cell.under_building:
				continue
			plan.clearances.append(FeatureGroundShape.oriented_rect(cell.centre,
				Vector2.ONE * VillageProgram.MODULE * 0.5, cell.yaw,
				FeatureGroundField.NATURAL, 0,
				StringName("%s.clearance" % cell.stable_id)))


static func _rejected(plan: VillageUrbanFabricPlan,
		reason: StringName) -> VillageUrbanFabricPlan:
	plan.reason = reason
	plan.entries.clear()
	plan.volumes.clear()
	plan.surfaces.clear()
	plan.clearances.clear()
	plan.buildings.clear()
	plan.supports.clear()
	plan.skirts.clear()
	return plan
