class_name VillageBuildingSupportSolver
extends RefCounted

## Chooses support from terrain opportunity, never semantic building role.
## Natural perches receive a fixed perimeter foundation; retained perches
## receive one compact rock core. Both paths return the same atomic contract.


static func solve(terrain: VillageTerrainView, stable_id: StringName,
		placement: VillageMassingPlacement, spec: VillageAssetSpec,
		program: VillageProgram,
		reserved_volumes: Array[VillageOccupancyVolume] = []
		) -> VillageBuildingSupportPlan:
	assert(terrain != null and not stable_id.is_empty())
	assert(placement != null and spec != null and program != null)
	var transform := placement.building_transform(spec)
	var contact := spec.world_ground_contact(transform)
	for point: Vector2 in VillageModuleGrid.proof_samples(contact,
			VillageProgram.MODULE):
		if terrain.is_wet(point):
			return _rejected(stable_id,
				VillageBuildingSupportPlan.Mode.NATURAL_FOUNDATION, &"water")
	if not placement.perch.is_naturally_supported():
		return VillageRockCoreSolver.solve(terrain, stable_id, placement,
			spec, program, reserved_volumes)
	return _natural_foundation(terrain, stable_id, placement, spec, program,
		transform, contact, reserved_volumes)


static func _natural_foundation(terrain: VillageTerrainView,
		stable_id: StringName, placement: VillageMassingPlacement,
		spec: VillageAssetSpec, program: VillageProgram,
		transform: Transform3D, contact: Dictionary,
		reserved_volumes: Array[VillageOccupancyVolume]
		) -> VillageBuildingSupportPlan:
	var plan := VillageBuildingSupportPlan.new()
	plan.stable_id = stable_id
	plan.mode = VillageBuildingSupportPlan.Mode.NATURAL_FOUNDATION
	plan.floor_y = placement.floor_y
	if not spec.requires_foundation():
		plan.terrain_bounds = Vector2(placement.perch.minimum_y,
			placement.perch.maximum_y)
		plan.accepted = true
		plan.reason = &"accepted"
		assert(plan.validate())
		return plan
	var interior := spec.world_interior(transform)
	var request := FoundationRequest.new(stable_id, contact.centre,
		contact.half_extents, contact.angle, interior.centre,
		interior.half_extents, interior.angle, placement.entrance,
		placement.entrance_ground_contact, program.foundation_max_depth,
		program.foundation_asset_id, program.foundation_module_width,
		program.foundation_module_depth, program.foundation_module_height,
		program.foundation_max_burial, VillageTerrainSurvey.FLOOR_GUARD,
		TraversalEnvelope.MIN_APERTURE_WIDTH, Vector2.RIGHT,
		program.foundation_local_bottom_y, placement.floor_y)
	for point: Vector2 in FoundationSolver.water_probes(request):
		if terrain.is_wet(point):
			return _rejected(stable_id, plan.mode, &"water")
	var region := terrain.region_covering(request.bounds_xz())
	var solved := FoundationSolver.solve(request, region)
	if not bool(solved.accepted):
		return _rejected(stable_id, plan.mode,
			StringName("foundation_%s" % String(solved.reason)))
	if not is_equal_approx(float(solved.floor_y), placement.floor_y):
		return _rejected(stable_id, plan.mode, &"floor_moved")
	plan.terrain_bounds = solved.terrain_bounds
	plan.pieces.assign(solved.foundation_pieces)
	plan.volumes.assign(solved.volumes)
	var conflict := VillageOccupancy.first_cross_conflict(plan.volumes,
		reserved_volumes)
	if not conflict.is_empty():
		var existing := conflict.existing as VillageOccupancyVolume
		return _rejected(stable_id, plan.mode,
			StringName("occupancy_%s" % String(existing.stable_id)))
	plan.accepted = true
	plan.reason = &"accepted"
	assert(plan.validate())
	return plan


static func _rejected(stable_id: StringName,
		mode: VillageBuildingSupportPlan.Mode,
		reason: StringName) -> VillageBuildingSupportPlan:
	var plan := VillageBuildingSupportPlan.new()
	plan.stable_id = stable_id
	plan.mode = mode
	plan.reason = reason
	assert(plan.validate())
	return plan
