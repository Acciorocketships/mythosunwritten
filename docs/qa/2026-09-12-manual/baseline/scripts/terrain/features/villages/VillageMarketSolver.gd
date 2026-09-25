class_name VillageMarketSolver
extends RefCounted

## Lays the connected ground market before any building is admitted. Ranked
## orthogonal loops are qualified against the untouched terrain; stall rows
## then grow inward-out from their street samples with exact reviewed bounds.


static func solve(terrain: VillageTerrainView, settlement_id: StringName,
		arrival: Vector2, primary_axis: Vector2, tier: StringName,
		theme: StringName, village_program: VillageProgram) -> VillageMarketPlan:
	assert(terrain != null and not settlement_id.is_empty())
	assert(arrival.is_finite() and primary_axis.is_normalized())
	assert(village_program != null and village_program.market_program != null)
	var program := village_program.market_program
	var last_reason: StringName = &"terrain_topology"
	for topology: Dictionary in program.local_topologies():
		var plan := _solve_topology(terrain, settlement_id, arrival,
			primary_axis, tier, theme, village_program, topology)
		if plan.accepted:
			return plan
		last_reason = plan.reason
	return _rejected(last_reason)


static func _solve_topology(terrain: VillageTerrainView,
		settlement_id: StringName, arrival: Vector2, primary_axis: Vector2,
		tier: StringName, theme: StringName, village_program: VillageProgram,
		topology: Dictionary) -> VillageMarketPlan:
	var plan := VillageMarketPlan.new()
	var nodes: Dictionary = {}
	var local_nodes: Dictionary = topology.nodes
	var node_keys: Array = local_nodes.keys()
	node_keys.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	for key: StringName in node_keys:
		var point := _world(local_nodes[key], arrival, primary_axis)
		var kind := VillageCirculationNode.Kind.ARRIVAL \
			if key == &"arrival" else VillageCirculationNode.Kind.TERRAIN_CONTACT
		var node := VillageCirculationNode.new(key, kind, point,
			terrain.surface_y(point))
		nodes[key] = node
		plan.nodes.append(node)
	for pair: Array in topology.edges:
		var a := nodes[pair[0]] as VillageCirculationNode
		var b := nodes[pair[1]] as VillageCirculationNode
		var link := VillageGroundRouter.best_link(terrain, arrival,
			primary_axis, a, b, [], village_program.elevated_program)
		if link == null:
			return _rejected(StringName("street_%s_%s" % [pair[0], pair[1]]))
		link.stable_key = StringName("market.%s.%s" % [topology.key,
			VillageRouteGeometry.edge_key(&"edge", a.stable_key, b.stable_key)])
		plan.links.append(link)
	_append_streets(plan, settlement_id)
	_append_stalls(plan, terrain, settlement_id, tier, theme,
		village_program)
	if plan.stalls.size() < village_program.market_program.minimum_stalls(tier):
		return _rejected(&"stall_count")
	plan.accepted = true
	plan.reason = &"accepted"
	var rejection := plan.rejection_reason(village_program.market_program, tier)
	if not rejection.is_empty():
		return _rejected(rejection)
	return plan


static func _append_streets(plan: VillageMarketPlan,
		settlement_id: StringName) -> void:
	var walk_network_id := StringName("%s.urban.walk_network" % settlement_id)
	# The market lanes are the first edges of the same public ground compound
	# extended by later house streets and cliff stairs. Shared ownership admits
	# only their own walk-surface/headroom composition in the final 3D proof.
	var ground_owner_id := StringName("%s.ground_circulation" % settlement_id)
	for link: VillageCirculationLink in plan.links:
		for index in range(1, link.samples.size()):
			var a := link.samples[index - 1]
			var b := link.samples[index]
			var a2 := Vector2(a.x, a.z)
			var b2 := Vector2(b.x, b.z)
			if a2.distance_to(b2) <= 0.01:
				continue
			var stable_id := StringName("%s.%s.street.%03d" % [
				settlement_id, link.stable_key, index])
			plan.surfaces.append(FeatureGroundShape.capsule(a2, b2,
				VillageMarketProgram.STREET_HALF_WIDTH,
				FeatureGroundField.WORN_PATH, VillagePlan.SURFACE_PRIORITY,
				stable_id))
			plan.clearances.append(FeatureGroundShape.capsule(a2, b2,
				VillageMarketProgram.STREET_CLEARANCE,
				FeatureGroundField.NATURAL, 0,
				StringName("%s.clearance" % stable_id)))
			var direction := (b2 - a2).normalized()
			var min_y := minf(a.y, b.y)
			var max_y := maxf(a.y, b.y) + TraversalEnvelope.MIN_HEADROOM
			plan.volumes.append(VillageOccupancyVolume.new(
				VillageOccupancy.Role.HEADROOM, (a2 + b2) * 0.5,
				Vector2(a2.distance_to(b2) * 0.5,
					VillageMarketProgram.STREET_HALF_WIDTH), direction.angle(),
				min_y, max_y, StringName("%s.headroom" % stable_id),
				ground_owner_id,
				walk_network_id))


static func _append_stalls(plan: VillageMarketPlan,
		terrain: VillageTerrainView, settlement_id: StringName, tier: StringName,
		theme: StringName, village_program: VillageProgram) -> void:
	var candidates: Array[Dictionary] = []
	for link_index in plan.links.size():
		var link := plan.links[link_index]
		for index in range(VillageMarketProgram.END_CLEARANCE_MODULES,
				link.samples.size() - VillageMarketProgram.END_CLEARANCE_MODULES,
				VillageMarketProgram.STALL_SAMPLE_STRIDE):
			var point := link.samples[index]
			var prior := link.samples[maxi(0, index - 1)]
			var next := link.samples[mini(link.samples.size() - 1, index + 1)]
			var tangent := Vector2(next.x - prior.x, next.z - prior.z)
			if not tangent.normalized().is_normalized():
				continue
			tangent = tangent.normalized()
			for side_sign: int in [-1, 1]:
				candidates.append({
					"link_index": link_index,
					"sample_index": index,
					"side": side_sign,
					"lane_point": Vector2(point.x, point.z),
					"tangent": tangent,
					"distance": Vector2(point.x, point.z).distance_to(
						plan.nodes[0].point),
				})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if float(a.distance) != float(b.distance):
			return float(a.distance) < float(b.distance)
		if int(a.link_index) != int(b.link_index):
			return int(a.link_index) < int(b.link_index)
		if int(a.sample_index) != int(b.sample_index):
			return int(a.sample_index) < int(b.sample_index)
		return int(a.side) < int(b.side))
	var target := village_program.market_program.target_stalls(tier)
	for candidate_index in candidates.size():
		if plan.stalls.size() >= target:
			break
		var candidate := candidates[candidate_index] as Dictionary
		var spec := village_program.market_program.spec_for_index(
			candidate_index)
		var stall := _stall_for_candidate(terrain, settlement_id, spec,
			theme, candidate, plan.stalls, plan.volumes)
		if stall == null:
			continue
		plan.stalls.append(stall)
		plan.entries.append({"asset_id": stall.asset_id,
			"stable_id": stall.stable_key, "transform": stall.transform})
		for attachment: VillageAttachedAssetSpec in spec.attachments:
			plan.entries.append({
				"asset_id": attachment.asset_for_theme(theme),
				"stable_id": StringName("%s.component.%s" % [
					stall.stable_key, attachment.stable_key]),
				"transform": attachment.world_transform(stall.transform),
			})
		plan.volumes.append(stall.solid_volume)
		plan.clearances.append(stall.lot_shape)


static func _stall_for_candidate(terrain: VillageTerrainView,
		settlement_id: StringName, spec: VillageAssetSpec, theme: StringName,
		candidate: Dictionary,
		existing: Array[VillageMarketStall],
		street_volumes: Array[VillageOccupancyVolume]) -> VillageMarketStall:
	var tangent: Vector2 = candidate.tangent
	var side := Vector2(-tangent.y, tangent.x) * float(candidate.side)
	var inward := -side
	var yaw := spec.entrance_outward.angle_to(inward)
	var local_contact_centre := spec.ground_contact_local_rect.get_center()
	var zero_transform := Transform3D(Basis(Vector3.UP, yaw), Vector3.ZERO)
	var zero_contact := spec.world_ground_contact(zero_transform)
	var zero_solid := spec.world_solid(zero_transform)
	var solid_radius := absf(side.dot(Vector2.RIGHT.rotated(
		float(zero_solid.angle)))) * (zero_solid.half_extents as Vector2).x \
		+ absf(side.dot(Vector2.DOWN.rotated(float(zero_solid.angle)))) \
			* (zero_solid.half_extents as Vector2).y
	var solid_offset := ((zero_solid.centre as Vector2) \
		- (zero_contact.centre as Vector2)).dot(side)
	var contact_centre: Vector2 = candidate.lane_point + side * (
		VillageMarketProgram.STREET_HALF_WIDTH + solid_radius - solid_offset \
		+ VillageMarketProgram.STALL_EDGE_GAP)
	var basis := Basis(Vector3.UP, yaw)
	var local_offset := basis * Vector3(local_contact_centre.x, 0.0,
		local_contact_centre.y)
	var origin := contact_centre - Vector2(local_offset.x, local_offset.z)
	var flat_transform := Transform3D(basis,
		Vector3(origin.x, 0.0, origin.y))
	var contact := spec.world_ground_contact(flat_transform)
	var contact_shape := FeatureGroundShape.oriented_rect(contact.centre,
		contact.half_extents, contact.angle)
	var bounds := TerrainSurfaceField.height_bounds(
		terrain.region_covering(contact_shape.bounds()), contact_shape.bounds())
	if bounds.y - bounds.x > spec.max_ground_relief + 0.001:
		return null
	for point: Vector2 in VillageModuleGrid.proof_samples(contact,
			VillageProgram.MODULE):
		if terrain.is_wet(point):
			return null
	var floor_y := bounds.y + VillageTerrainSurvey.FLOOR_GUARD
	var transform := Transform3D(basis, Vector3(origin.x,
		floor_y - spec.entrance_floor_local_y, origin.y))
	var solid := spec.world_solid(transform)
	var lot := spec.world_lot(transform)
	var lot_shape := FeatureGroundShape.oriented_rect(lot.centre,
		lot.half_extents, lot.angle, FeatureGroundField.NATURAL, 0,
		StringName("%s.market.stall.%02d.clearance" % [settlement_id,
			int(candidate.sample_index)]))
	for other: VillageMarketStall in existing:
		if lot_shape.intersects(other.lot_shape,
				VillageMassingProgram.ACCESS_CLEARANCE):
			return null
	var stable_key := StringName("%s.market.stall.%02d.%02d.%d" % [
		settlement_id, int(candidate.link_index),
		int(candidate.sample_index), int(candidate.side)])
	var stall := VillageMarketStall.new()
	stall.stable_key = stable_key
	stall.asset_id = spec.asset_for_theme(theme)
	stall.transform = transform
	stall.floor_y = floor_y
	stall.service_front = spec.world_entrance(transform)
	stall.inward = inward
	stall.lot_shape = lot_shape
	stall.solid_volume = VillageOccupancyVolume.new(
		VillageOccupancy.Role.SOLID, solid.centre, solid.half_extents,
		solid.angle, transform.origin.y + spec.measured_aabb.position.y,
		transform.origin.y + spec.measured_aabb.end.y,
		StringName("%s.solid" % stable_key), stable_key)
	for volume: VillageOccupancyVolume in street_volumes:
		if stall.solid_volume.overlaps(volume):
			return null
	return stall if stall.is_valid() else null


static func _world(local: Vector2, origin: Vector2,
		axis: Vector2) -> Vector2:
	return origin + axis * local.x + Vector2(-axis.y, axis.x) * local.y


static func _rejected(reason: StringName) -> VillageMarketPlan:
	var plan := VillageMarketPlan.new()
	plan.reason = reason
	return plan
