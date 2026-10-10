extends GutTest

func test_native_replacement_keeps_the_complete_garden_bearing_cap():
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := WarrenVolumetricSolver.generate(53, {}, program,
		WarrenVillageScaleProfile.for_id(&"grand"))
	assert_not_null(spatial)
	if spatial == null: return
	var fabric := spatial.compiled_fabric_cache()
	var built := KitVillageBuildings.build(spatial, fabric, SuntailBuildingKit.create(), true, true)
	var retained: BuildingMass
	for mass: BuildingMass in built.masses:
		if mass.stable_id == &"kit.retained": retained = mass
	assert_not_null(retained)
	if retained == null: return
	# The native room ceiling is at band 3; lawn rests on band 4. The old
	# flat-roof renderer owned band 3's side faces and is now replaced.
	for x in [14, 15]:
		for z in range(4, 8):
			var column := Vector2i(x, z)
			assert_true(retained.cells_at_band(3).has(column),
				"A continuous native cap must join the room ceiling to the lawn wall")
			assert_true(retained.cells_at_band(4).has(column))
			assert_false(retained.cells_at_band(2).has(column),
				"The cap cannot fill the inhabited room below")
