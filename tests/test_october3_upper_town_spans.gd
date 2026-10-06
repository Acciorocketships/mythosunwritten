extends GutTest

func test_upper_districts_keep_supported_spans_without_boring_the_plinth() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var kit := SuntailBuildingKit.create()
	for job: Array in [[101,&"large"],[103,&"grand"],[31,&"large"]]:
		var spatial := WarrenVolumetricSolver.generate(job[0],{},program,WarrenVillageScaleProfile.for_id(job[1]))
		assert_not_null(spatial,WarrenVolumetricSolver.last_failure)
		if spatial==null: continue
		var source: WarrenMazeSourcePlan = spatial.source_volume.mass_context[&"maze_source_plan"]
		assert_gt(source.excavation.bridge_spans.size(),0,"Upper-town streets may pass beneath inhabited spans")
		var upper_bores := 0
		for cell: Vector3i in source.excavation.tunnel_cells:
			upper_bores += int(cell.y >= source.massif.bearing_at(Vector2i(cell.x,cell.z)))
		assert_gt(upper_bores,0,"Retain supported bores above the district foundation and in its surrounding mass")
		# Explicit wall through-routes already own bounded openings in the
		# plinth. Upper spans may not introduce any additional excavation.
		var wall_bores := {}
		for lane: Dictionary in source.excavation.lanes:
			if lane.get("feature_kind",&"")!=&"wall_tunnel": continue
			for cell: Vector3i in lane.cells:
				for band in range(cell.y,cell.y+WarrenExcavation.HEADROOM_BANDS):
					wall_bores[Vector3i(cell.x,band,cell.z)]=true
		var holes: Array[Vector3i] = []
		for column: Vector2i in source.massif.platform_columns():
			for band in range(source.massif.base_at(column),source.massif.bearing_at(column)):
				var cell := Vector3i(column.x,band,column.y)
				if not source.solid_at(cell) and not wall_bores.has(cell): holes.append(cell)
		assert_eq(holes,[] as Array[Vector3i],"The upper crossing never excavates district foundations")
		var stamped := 0
		for outcome: Dictionary in spatial.audit.get("maze_bridge_outcomes",[]):
			stamped+=int(outcome.outcome=="stamped")
		assert_gt(stamped,0,"The source span survives room composition")
		var fabric := spatial.compiled_fabric_cache()
		assert_true(fabric.validate(),fabric.last_rejection)
		var built := KitVillageBuildings.build(spatial,fabric,kit)
		assert_eq(KitFloatingMassAudit.audit(spatial,fabric,built.masses).count,0)
		assert_eq(int(preload("res://tests/fixtures/kit_roof_public_air_audit.gd").audit(built,kit).intrusions),0)
