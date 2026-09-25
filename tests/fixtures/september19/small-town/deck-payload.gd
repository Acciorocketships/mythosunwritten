extends SceneTree
const OUT := "res://docs/qa/2026-09-19-manual/119-small-town"
const FROZEN=preload("res://tests/fixtures/frozen_maze_source.gd")
func _init()->void:
	var program:=SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var saved:Dictionary=FileAccess.open(OUT.path_join("payload.bin"),FileAccess.READ).get_var()
	for version in ["before","after"]:
		var source:=FROZEN.read(OUT.path_join("source.txt"),false)
		if version=="after":WarrenMazeSitePlanner.finish_public_destinations(source)
		source.finish_construction()
		var spatial:=FROZEN.spatial(source,program)
		var fabric:=spatial.compiled_fabric_cache()
		var payload:=SettlementFabricAssembler.payload(fabric)
		payload.append_from(SettlementFabricAssembler.structural_support_payload(fabric))
		payload.append_from(SettlementFabricAssembler.production_surface_bundle(fabric.surface_plan,SettlementFabricAssembler.maze_module_footprints(fabric),SettlementFabricAssembler.maze_skin_panel_boxes_for(fabric),fabric.planned_plaza_cells))
		FileAccess.open(OUT.path_join("deck-"+version+"-payload.bin"),FileAccess.WRITE).store_var({"batches":payload.batches,"collision_boxes":payload.collision_boxes,"surface_meshes":payload.surface_meshes,"transform":saved.transform,"walked":SettlementFabricAssembler.walked_floor_cells(fabric.surface_plan)})
		print("DECK_SOURCE ",version," route=",source.excavation.route," removed=",source.audit.get("withdrawn_terminal_public_cells",[]))
	quit()
