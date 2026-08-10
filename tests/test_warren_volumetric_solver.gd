extends GutTest

func test_seed_seven_becomes_a_sealed_fine_grid_town() -> void:
	var plan := WarrenVolumetricSolver.solve(7)
	assert_not_null(plan, WarrenVolumetricSolver.last_failure)
	if plan == null:
		return
	assert_true(plan.is_sealed())
	assert_eq(int(plan.audit.allocatable_cell_count), 0)
	assert_gte(int(plan.audit.building_count), 10)
	assert_gte(int(plan.audit.public_route_floor_count), 20)
	assert_gte(int(plan.audit.route_vertical_span_bands), 8)
	assert_eq(int(plan.audit.unclassified_public_private_face_count), 0)
	assert_eq(int(plan.audit.missing_roof_face_count), 0)
	for building: WarrenBuildingVolume in plan.buildings:
		assert_lte(int(building.audit.longest_identical_floorplate_run),
			WarrenBuildingVolume.MAX_IDENTICAL_FLOORPLATE_RUN)


func test_volumetric_solve_is_deterministic() -> void:
	var first := WarrenVolumetricSolver.solve(7)
	var repeated := WarrenVolumetricSolver.solve(7)
	assert_not_null(first, WarrenVolumetricSolver.last_failure)
	assert_not_null(repeated, WarrenVolumetricSolver.last_failure)
	if first != null and repeated != null:
		assert_eq(first.deterministic_signature(),
			repeated.deterministic_signature())
