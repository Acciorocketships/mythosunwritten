extends GutTest

## Layout changes may change how many tiers fit. These flat-ground examples
## must keep their court on the highest generated tier; the nested example
## additionally proves a court at four storeys, not only a low terrace.
func _assert_upper_tier(source: WarrenMazeSourcePlan, floor_band: int) -> void:
	var highest := 0
	for column: Vector2i in source.massif.platform_columns():
		highest = maxi(highest,source.massif.bearing_at(column))
	assert_gte(highest,4,"exercise a genuinely raised district")
	assert_eq(floor_band,highest,"the square is on the highest available tier")
	if source.world_seed==13:
		assert_gte(floor_band,8,"the nested fixture still exercises a four-storey courtyard")

func test_upper_courtyard_reserved_before_streets_survives_the_layout() -> void:
	for job: Array in [[13,&"grand"],[58,&"large"],[58,&"grand"]]:
		var profile := WarrenVillageScaleProfile.for_id(job[1])
		var source := WarrenMazeSitePlanner.plan(job[0],{},profile,&"",false)
		assert_not_null(source)
		if source == null: continue
		var held: Dictionary = source.audit.get("preselected_plaza",{})
		assert_false(held.is_empty(),"exercise a selected early courtyard")
		if held.is_empty(): continue
		_assert_upper_tier(source,int(held.floor))
		var found := false
		for plot: Dictionary in source.plots:
			if plot.id != WarrenPlotReservations.PLAZA_PLOT_ID: continue
			found = true
			assert_eq(plot.cells,held.cells,"later streets preserve the whole square")
			assert_eq(plot.floor,held.floor,"the court stays on its selected tier")
			for column: Vector2i in plot.cells:
				assert_true(source.plot_support_ok(column,plot.floor))
		assert_true(found)

func test_upper_courtyards_build_with_support_and_clear_public_air() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	for job: Array in [[13,&"grand"],[58,&"large"],[58,&"grand"]]:
		var spatial := WarrenVolumetricSolver.generate(job[0],{},program,
			WarrenVillageScaleProfile.for_id(job[1]))
		assert_not_null(spatial,WarrenVolumetricSolver.last_failure)
		if spatial == null: continue
		var source := spatial.source_volume.mass_context[&"maze_source_plan"] as WarrenMazeSourcePlan
		var fabric := spatial.compiled_fabric_cache()
		for plot: Dictionary in source.plots:
			if plot.id != WarrenPlotReservations.PLAZA_PLOT_ID: continue
			_assert_upper_tier(source,int(plot.floor))
			for column: Vector2i in plot.cells:
				for dx in 2:
					for dz in 2:
						var cell := Vector3i(column.x*2+dx,plot.floor,column.y*2+dz)
						assert_true(fabric.surface_plan.has_cell(cell) or fabric.planned_plaza_planting_cells.has(cell+Vector3i.DOWN),
							"every court cell has a declared walking or planting use")
		var built := KitVillageBuildings.build(spatial,fabric,SuntailBuildingKit.create())
		assert_true((built.payload as EnvironmentInstancePayload).validate())
		assert_eq(int(KitFloatingMassAudit.audit(spatial,fabric,built.masses).count),0)
		var air := preload("res://tests/fixtures/kit_roof_public_air_audit.gd").audit(built,SuntailBuildingKit.create())
		assert_eq(int(air.intrusions),0,"court and streets retain full headroom")
