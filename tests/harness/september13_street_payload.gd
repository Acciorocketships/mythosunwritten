extends SceneTree
const DIRECTORY := "res://docs/qa/2026-09-13-manual/19-streets/"
const Frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
func _init() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var source_path := "res://docs/qa/2026-09-13-manual/14-deck-purpose/current-source.txt"
	var old: Dictionary = FileAccess.open("res://docs/qa/2026-09-13-manual/14-deck-purpose/before-payload.bin",FileAccess.READ).get_var()
	for after: bool in [false,true]:
		var source := Frozen.read(source_path,false)
		WarrenMazeSitePlanner.finish_public_destinations(source)
		if after: WarrenMazeSitePlanner.finish_ground_streets(source)
		source.finish_construction()
		var spatial := Frozen.spatial(source,program)
		var fabric := spatial.compiled_fabric_cache()
		var payload := SettlementFabricAssembler.payload(fabric)
		payload.append_from(SettlementFabricAssembler.structural_support_payload(fabric))
		payload.append_from(SettlementFabricAssembler.production_surface_bundle(fabric.surface_plan,
			SettlementFabricAssembler.maze_module_footprints(fabric),
			SettlementFabricAssembler.maze_skin_panel_boxes_for(fabric),fabric.planned_plaza_cells))
		FileAccess.open(DIRECTORY+("after" if after else "before")+"-payload.bin",FileAccess.WRITE).store_var({
			"batches":payload.batches,"collision_boxes":payload.collision_boxes,
			"surface_meshes":payload.surface_meshes,"transform":old.transform,
			"walked":SettlementFabricAssembler.walked_floor_cells(fabric.surface_plan)})
	print("STREET_PAYLOAD_READY")
	quit()
