extends GutTest
func test_district_access_preserves_a_real_tower_house_address() -> void:
	var plan := WarrenMazeSitePlanner.plan(83, {}, WarrenVillageScaleProfile.for_id(&"grand"), &"reserve")
	assert_not_null(plan)
	if plan == null: return
	var towers := 0
	for outcome: Dictionary in WarrenPlotPlanner.outcomes(plan).get("assets", []):
		if String(outcome.get("kind_id", "")).begins_with("anchor.z_native.turret."):
			towers += 1
	assert_gt(towers, 0, "District access must leave the jointly planned native tower-house buildable")

	assert_true(plan.excavation.validate_construction(), plan.excavation.last_rejection)
	var addressed := 0
	for lane: Dictionary in plan.excavation.lanes:
		if not lane.has("landmark_site"): continue
		addressed += 1
		var site: Dictionary = lane.landmark_site
		assert_true(lane.cells.has(site.door), "The reserved house has an actual district-street address")
		for cell: Vector2i in site.cells:
			assert_lt(plan.first_carved_band(cell,site.floor,site.top),0,
				"Later lanes must retain the complete promised tower-house body")
	assert_gt(addressed,0)

func test_infeasible_district_does_not_mutate_existing_routes() -> void:
	var profile := WarrenVillageScaleProfile.for_id(&"grand")
	var source := WarrenMazeSitePlanner.plan(83, {}, profile, &"carve")
	assert_not_null(source)
	if source == null: return
	var before := source.excavation.carved.duplicate(true)
	var lanes := source.excavation.lanes.duplicate(true)
	var reservations := source.excavation.construction_reservations.duplicate(true)
	var result := preload("res://scripts/terrain/features/villages/fabric/WarrenDistrictLandmarkAccess.gd").propose(
		source.massif,source.excavation,profile,[],{}, {})
	assert_true(result.is_empty())
	assert_eq(source.excavation.carved,before)
	assert_eq(source.excavation.lanes,lanes)
	assert_eq(source.excavation.construction_reservations,reservations)

func test_tower_house_keeps_an_inhabited_district_edge() -> void:
	var plan := WarrenMazeSitePlanner.plan(83, {}, WarrenVillageScaleProfile.for_id(&"grand"))
	assert_not_null(plan)
	if plan == null: return
	var sites: Array = []
	for lane: Dictionary in plan.excavation.lanes:
		if lane.has("landmark_site"): sites.append(lane.landmark_site)
	assert_false(sites.is_empty())
	for site: Dictionary in sites:
		var neighbours := {}
		for plot: Dictionary in plan.plots:
			if plot.kind != WarrenMazeSourcePlan.PLOT_HOUSE: continue
			for cell: Vector2i in plot.cells:
				for member: Vector2i in site.cells:
					var delta := (cell-member).abs()
					if delta.x+delta.y <= 2: neighbours[cell]=true
		assert_gte(neighbours.size(),2,"A tower-house must not consume all nearby inhabited district frontage")

func test_reserved_tower_house_survives_finished_fabric() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := WarrenVolumetricSolver.generate(83, {}, program,
		WarrenVillageScaleProfile.for_id(&"grand"))
	assert_not_null(spatial, WarrenVolumetricSolver.last_failure)
	if spatial == null: return
	var native_towers := 0
	for unit: FabricUnit in spatial.compiled_fabric_cache().units:
		if String(unit.recipe_id).begins_with("anchor.z_native.turret."):
			native_towers += 1
	assert_gt(native_towers, 0,
		"The promised native tower-house must survive final spatial admission, not only plot reservation")
