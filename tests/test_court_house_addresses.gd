extends GutTest

func test_raised_court_boundary_is_available_to_house_seeding():
	var plan := WarrenMazeSitePlanner.plan(301, {}, WarrenVillageScaleProfile.for_id(&"grand"), &"reserve", false)
	assert_not_null(plan)
	if plan == null: return
	var court: Dictionary = {}
	for plot: Dictionary in plan.plots:
		if plot.id == &"plaza.00": court = plot
	assert_false(court.is_empty())
	if court.is_empty(): return
	assert_gt(int(court.floor), 0)
	var addresses := WarrenPlotPlanner.walk_order(plan)
	var missing := 0
	for column: Vector2i in court.cells:
		if not addresses.has(Vector3i(column.x,int(court.floor),column.y)): missing += 1
	assert_eq(missing, 0, "A connected raised court must seed frontages at its own walking band")

func test_disconnected_courts_do_not_supply_house_addresses():
	var plan := WarrenMazeSitePlanner.plan(301, {}, WarrenVillageScaleProfile.for_id(&"grand"), &"reserve", false)
	assert_not_null(plan)
	if plan == null: return
	assert_false(plan.court_addresses().is_empty())
	for address: Vector3i in plan.court_addresses():
		assert_false(plan.court_addresses().has(address+Vector3i.UP), "No imaginary upper court floor")
	plan.passage_kinds.clear()
	assert_true(plan.court_addresses().is_empty(), "A deck without a public entry is not a house address")

func test_raised_court_houses_translate_with_real_paved_thresholds():
	var source := WarrenMazeSitePlanner.plan(301, {}, WarrenVillageScaleProfile.for_id(&"grand"), &"", false)
	assert_not_null(source, WarrenMazeSitePlanner.last_failure)
	if source == null: return
	var volume := WarrenMazeVolumeAdapter.to_volume_plan(source, false)
	assert_not_null(volume, WarrenMazeVolumeAdapter.last_failure)
	if volume == null: return
	var parcels := WarrenMazeBlockPartitioner.partition(source, volume)
	assert_not_null(parcels, WarrenMazeBlockPartitioner.last_failure)
	if parcels == null: return
	var court_doors := 0
	for parcel: WarrenBuildingParcel in parcels.parcels:
		if source.court_addresses().has(parcel.address_walk_cell):
			court_doors += 1
			var threshold := WarrenParcelConstruction.threshold_cell(parcel)
			var landing := threshold + Vector3i(parcel.frontage_direction.x,0,parcel.frontage_direction.y)
			assert_true(WarrenVolumetricSolver._maze_deck_walk_cells(volume).has(landing))
	assert_gt(court_doors,0,"The raised square supplies at least one finished house address")
