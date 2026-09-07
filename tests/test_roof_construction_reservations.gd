extends GutTest

func test_connected_roof_uses_actual_component_clearance() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var seed_value := VillagePlan.warren_seed_for_cell(2697992464, Vector2i(52, -210))
	var spatial := WarrenVolumetricSolver.solve(seed_value, {}, program,
		WarrenVillageScaleProfile.select(seed_value))
	assert_not_null(spatial, WarrenVolumetricSolver.last_failure)
	if spatial != null:
		assert_eq(WarrenSpatialFabricCompiler.validation_errors(
			spatial.compiled_fabric_cache()), PackedStringArray())

func test_roofs_leave_space_for_ground_bearing_frames() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var seed_value := VillagePlan.warren_seed_for_cell(2697992464, Vector2i(80, -43))
	var spatial := WarrenVolumetricSolver.solve(seed_value, {}, program,
		WarrenVillageScaleProfile.select(seed_value))
	assert_not_null(spatial, WarrenVolumetricSolver.last_failure)
	if spatial != null:
		assert_eq(WarrenSpatialFabricCompiler.validation_errors(
			spatial.compiled_fabric_cache()), PackedStringArray())

func test_joined_bridge_crown_uses_the_free_transverse_eave_space() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var seed_value := VillagePlan.warren_seed_for_cell(2697992464, Vector2i(142, -78))
	var spatial := WarrenVolumetricSolver.solve(seed_value, {}, program,
		WarrenVillageScaleProfile.select(seed_value))
	assert_not_null(spatial, WarrenVolumetricSolver.last_failure)
	if spatial != null:
		assert_eq(WarrenSpatialFabricCompiler.validation_errors(
			spatial.compiled_fabric_cache()), PackedStringArray())
