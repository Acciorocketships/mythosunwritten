extends GutTest


func test_measured_room_units_preserve_every_spatial_stamp() -> void:
	var program := SettlementFabricProgram.compile(
		EnvironmentCatalog.load_default())
	assert_not_null(program)
	var spatial := WarrenVolumetricSolver.solve(7)
	assert_not_null(spatial, WarrenVolumetricSolver.last_failure)
	if program == null or spatial == null:
		return
	var realm := WarrenSpatialPublicRealmAdapter.from_spatial(spatial)
	assert_not_null(realm, WarrenSpatialPublicRealmAdapter.last_failure)
	var units := WarrenSpatialFabricCompiler.compile_room_units(spatial, program)
	assert_gt(units.size(), 0, WarrenSpatialFabricCompiler.last_failure)
	var expected := 0
	for building: WarrenBuildingVolume in spatial.buildings:
		expected += building.room_records.size()
	assert_eq(units.size(), expected)
	var fabric := SettlementFabricPlan.new(&"spatial.room-proof")
	for recipe: FabricRecipe in program.recipes():
		assert_true(fabric.register_recipe(recipe))
	for unit: FabricUnit in units:
		assert_true(fabric.add_unit(unit), fabric.last_rejection)
	var roofs := WarrenSpatialFabricCompiler.compile_roof_units(spatial,
		program, units)
	assert_gt(roofs.size(), 0, WarrenSpatialFabricCompiler.last_failure)
	assert_eq(roofs.size(), int(spatial.construction_plan.audit.roof_region_count))
	for roof: FabricUnit in roofs:
		assert_true(fabric.add_unit(roof), fabric.last_rejection)
