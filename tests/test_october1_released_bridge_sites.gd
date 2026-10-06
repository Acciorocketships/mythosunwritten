extends GutTest

func test_withdrawn_bridge_footprints_return_to_ordinary_houses() -> void:
	var profile := WarrenVillageScaleProfile.for_id(&"compact")
	var source := WarrenMazeSitePlanner.plan(12, {}, profile, &"reserve", false)
	assert_not_null(source)
	if source == null: return
	assert_gt(source.excavation.bridge_spans.size(), 0, "exercise a real selected bridge")
	WarrenPlotPlanner.partition(source, profile, false)
	WarrenMazeSitePlanner.finish_public_destinations(source)
	var released: Array = source.audit.get("withdrawn_bridge_columns", [])
	assert_gt(released.size(), 0, "pruning actually releases a compound")
	var before := source.plots.duplicate(true)
	var public_before := source.passage_cells().duplicate()
	WarrenPlotPlanner.fill_released_bridge_sites(source)
	assert_eq(source.plots.slice(0, before.size()), before, "committed houses and landmarks do not move")
	assert_eq(source.passage_cells(), public_before, "infill uses existing surviving addresses")
	var added := 0
	for plot: Dictionary in source.plots.slice(before.size()):
		added += 1
		assert_eq(plot.kind, WarrenMazeSourcePlan.PLOT_HOUSE)
		assert_true(source.passage_kinds.has(plot.door_walk))
		for column: Vector2i in plot.cells:
			assert_true(released.has(column), "only the withdrawn footprint is reconsidered")
			assert_false(source.massif.is_reserved_ground(column), "gardens remain open")
			assert_true(source.plot_support_ok(column, plot.floor), "ordinary bearing/headroom rules still hold")
	assert_gt(added, 0, "the former foundations beside the street become houses")
	var after := source.plots.duplicate(true)
	var audit_after := source.audit.duplicate(true)
	WarrenPlotPlanner.fill_released_bridge_sites(source)
	assert_eq(source.plots, after, "the bounded pass is idempotent")
	assert_eq(source.audit, audit_after)

func test_reclaimed_houses_survive_full_kit_construction() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := WarrenVolumetricSolver.generate(12, {}, program,
		WarrenVillageScaleProfile.for_id(&"compact"))
	assert_not_null(spatial)
	if spatial == null: return
	var source := spatial.source_volume.mass_context[&"maze_source_plan"] as WarrenMazeSourcePlan
	var successful := 0
	for record: Dictionary in source.audit.plot_outcomes.get("released_bridge_sites", []):
		successful += int(String(record.reason).is_empty())
	assert_gt(successful, 0)
	var fabric := spatial.compiled_fabric_cache()
	var built := KitVillageBuildings.build(spatial, fabric, SuntailBuildingKit.create())
	for record: Dictionary in source.audit.plot_outcomes.released_bridge_sites:
		if not String(record.reason).is_empty(): continue
		var found := false
		for building: WarrenBuildingVolume in spatial.buildings:
			if String(building.stable_id).begins_with("spatial.parcel.maze.%s." % record.id):
				assert_gt(building.private_cells.size(), 0)
				found = true
		assert_true(found, "reclaimed plot %s becomes an inhabited building" % record.id)
	var audit := KitFloatingMassAudit.audit(spatial, fabric, built.masses)
	assert_eq(audit.count, 0)
	var air := preload("res://tests/fixtures/kit_roof_public_air_audit.gd").audit(built, SuntailBuildingKit.create())
	assert_eq(int(air.intrusions), 0, "new infill roofs leave the surviving streets clear")
