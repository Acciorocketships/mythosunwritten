extends SceneTree
func _init() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var spatial := frozen.spatial(frozen.read("res://docs/qa/2026-09-13-manual/13-floating-lawn/current-source.txt"),program)
	var fabric := spatial.compiled_fabric_cache()
	var skin := SettlementFabricAssembler.maze_ground_skin_transaction(fabric)
	var report := {"plaza":str(fabric.planned_plaza_cells.keys()),"suspended":str(skin.suspended_plaza.keys()),"caps":[],"patches":fabric.surface_plan.patches,"audit":fabric.audit}
	for cell: Vector3i in skin.capped_ground:
		if cell.y <= 0: continue
		report.caps.append({"cell":str(cell),"retained_below":skin.retained.has(cell+Vector3i.DOWN),"solid_below":skin.solids.has(cell+Vector3i.DOWN),"base":fabric.surface_plan.support_base_at(cell+Vector3i.UP),"use_below":spatial.grid.use_at(cell+Vector3i.DOWN),"owner_below":spatial.grid.owner_name_at(cell+Vector3i.DOWN),"source_support":spatial.source_volume.envelope.bearing_at(Vector2i(floori(cell.x/2.0),floori(cell.z/2.0)))})
	var source: WarrenMazeSourcePlan=spatial.source_volume.mass_context[&"maze_source_plan"]
	report["bearings"] = []
	for direction: Vector3i in [Vector3i.RIGHT,Vector3i.LEFT,Vector3i.FORWARD,Vector3i.BACK]:
		var ray := []
		for distance in range(1,12):
			var cell := Vector3i(0,2,0)+direction*distance
			ray.append({"cell":str(cell),"use":spatial.grid.use_at(cell),"owner":spatial.grid.owner_name_at(cell),"retained":skin.retained.has(cell),"solid":skin.solids.has(cell),"crown":skin.retained.has(cell+Vector3i.UP),"built_crown":skin.solids.has(cell+Vector3i.UP)})
		report.bearings.append(ray)
	report["plots"]=source.plots
	FileAccess.open("res://docs/qa/2026-09-13-manual/13-floating-lawn/support.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("LAWN_SUPPORT ",report.plaza," suspended=",report.suspended," caps=",report.caps)
	quit()
