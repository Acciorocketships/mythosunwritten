extends SceneTree
func _init() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var spatial := frozen.spatial(frozen.read("res://docs/qa/2026-09-13-manual/04-path/source.txt"),program)
	var fabric := spatial.compiled_fabric_cache()
	var payload := SettlementFabricAssembler.payload(fabric)
	payload.append_from(SettlementFabricAssembler.structural_support_payload(fabric))
	payload.append_from(SettlementFabricAssembler.production_surface_bundle(fabric.surface_plan,SettlementFabricAssembler.maze_module_footprints(fabric),SettlementFabricAssembler.maze_skin_panel_boxes_for(fabric),fabric.planned_plaza_cells))
	var old: Dictionary = FileAccess.open("res://docs/qa/2026-09-13-manual/04-path/after-payload.bin",FileAccess.READ).get_var()
	var result := {"batches":old.batches == payload.batches,"surface_meshes":old.surface_meshes == payload.surface_meshes,"collision_boxes":old.collision_boxes == payload.collision_boxes}
	print("FINAL_PAYLOAD ",result)
	FileAccess.open("res://docs/qa/2026-09-13-manual/04-path/final-payload-comparison.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	quit()
