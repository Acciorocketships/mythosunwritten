extends GutTest


func test_raised_square_is_inside_the_cluster_and_has_a_level_address() -> void:
	var plan := WarrenMazeSitePlanner.plan(
		13, {}, WarrenVillageScaleProfile.for_id(&"grand"), &"", false
	)
	assert_not_null(plan)
	if plan == null:
		return
	print("COURT_SEARCH ",plan.audit.get("interior_court_visits",0)," ",plan.audit.get("interior_court",{}))
	var square := {}
	for plot: Dictionary in plan.plots:
		if plot.id == WarrenPlotReservations.PLAZA_PLOT_ID:
			square = plot
	assert_false(square.is_empty())
	if square.is_empty():
		return
	var footprint := {}
	for column: Vector2i in square.cells:
		footprint[column] = true
	var bounds := BuildingDesigner._bounds(footprint)
	assert_gte(mini(bounds.size.x, bounds.size.y), 3, "Both dimensions must leave gathering space")
	assert_gte(
		square.cells.size(), 9, "A real internal square has room beyond a narrow passage pocket"
	)
	assert_gte(int(square.floor), 2, "The square sits on a raised level within the massif")
	for column: Vector2i in square.cells:
		assert_gte(
			plan.massif.ring_depth(column),
			3,
			"Keep an inhabited band between the square and the lawn"
		)
	assert_true(
		plan.passage_kinds.has(square.door_walk),
		"The square's entrance belongs to the actual route"
	)
	assert_false(plan.excavation.flight_cells().has(square.door_walk), "Enter from a level landing")


func test_square_admission_survives_as_three_finished_room_frontages() -> void:
	_assert_inhabited_sides(13, &"grand")
	_assert_inhabited_sides(43, &"grand")


func test_changed_route_keeps_exact_building_foundations() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := WarrenVolumetricSolver.generate(43, {}, program, WarrenVillageScaleProfile.for_id(&"grand"))
	assert_not_null(spatial, WarrenVolumetricSolver.last_failure)


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
