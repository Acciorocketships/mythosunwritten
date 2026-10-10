extends GutTest


func test_broad_supported_court_uses_available_room_frontages():
	var plan := WarrenMazeSitePlanner.plan(
		31, {}, WarrenVillageScaleProfile.for_id(&"large"), &"", false
	)
	assert_not_null(plan)
	if plan == null:
		return
	var found := false
	for plot: Dictionary in plan.plots:
		if plot.id != &"plaza.00":
			continue
		found = true
		var cells: Dictionary = {}
		for cell: Vector2i in plot.cells:
			cells[cell] = true
		var bounds := BuildingDesigner._bounds(cells)
		assert_gte(
			mini(bounds.size.x, bounds.size.y), 3, "Use the available broad court, not a 2x2 pocket"
		)
	assert_true(found)


func test_court_walk_is_deck_while_its_inner_bed_stays_turf():
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := WarrenVolumetricSolver.generate(
		31, {}, program, WarrenVillageScaleProfile.for_id(&"large")
	)
	assert_not_null(spatial, WarrenVolumetricSolver.last_failure)
	if spatial == null:
		return
	var fabric := spatial.compiled_fabric_cache()
	var ground := SettlementFabricAssembler.maze_ground_skin_transaction(fabric)
	var payload := SettlementFabricAssembler.production_surface_bundle(
		fabric.surface_plan, ground.footprints, [], fabric.planned_plaza_cells
	)
	var deck := {}
	for mesh: Dictionary in payload.surface_meshes:
		if not mesh.get("structural_plank", false):
			continue
		for cell: Vector3i in mesh.get("logical_cells", []):
			deck[cell] = true
	var walking := 0
	for support: Vector3i in fabric.planned_plaza_cells:
		var cell := support + Vector3i.UP
		if fabric.surface_plan.has_cell(cell):
			walking += 1
			assert_false(ground.capped_ground.has(support), "A walked court cell is not lawn")
			assert_true(deck.has(cell), "Every walked court cell has continuous deck skin")
		else:
			assert_true(ground.capped_ground.has(support), "The unwalked planting bed keeps turf")
	assert_gt(walking, 0)


func test_broad_court_keeps_three_same_level_inhabited_sides():
	_assert_inhabited_sides(31, &"large")


func test_deeper_court_keeps_three_same_level_inhabited_sides():
	_assert_inhabited_sides(53, &"grand")


func _assert_inhabited_sides(seed_value: int, profile: StringName):
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := WarrenVolumetricSolver.generate(
		seed_value, {}, program, WarrenVillageScaleProfile.for_id(profile)
	)
	assert_not_null(spatial, WarrenVolumetricSolver.last_failure)
	if spatial == null:
		return
	var fabric := spatial.compiled_fabric_cache()
	var built := KitVillageBuildings.build(spatial, fabric, SuntailBuildingKit.create())
	var source: WarrenMazeSourcePlan = spatial.source_volume.mass_context[&"maze_source_plan"]
	var court: Dictionary = {}
	for plot: Dictionary in source.plots:
		if plot.id == &"plaza.00":
			court = plot
	assert_false(court.is_empty())
	if court.is_empty():
		return
	var footprint := {}
	for column: Vector2i in court.cells:
		for dx in 2:
			for dz in 2:
				footprint[column * 2 + Vector2i(dx, dz)] = true
	var inhabited := {}
	for house: BuildingMass in built.houses:
		for storey: Dictionary in house.storeys:
			if (
				int(storey.floor_band) <= int(court.floor)
				and int(storey.floor_band) + 2 > int(court.floor)
			):
				for column: Vector2i in storey.cells:
					inhabited[column] = true
	var enclosed_sides := 0
	for direction: Vector2i in BuildingMass.DIRS:
		var edge := 0
		var fronts := 0
		for column: Vector2i in footprint:
			if footprint.has(column + direction):
				continue
			edge += 1
			fronts += int(inhabited.has(column + direction))
		if fronts * 2 > edge:
			enclosed_sides += 1
	assert_gte(
		enclosed_sides, 3, "A broad interior square must keep the house frontages used to admit it"
	)
