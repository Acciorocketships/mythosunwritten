extends SceneTree
func _init() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var spatial := frozen.spatial(frozen.read("res://docs/qa/2026-09-13-manual/07-platform/current-source.txt"),program)
	var fabric := spatial.compiled_fabric_cache()
	var skin := SettlementFabricAssembler.maze_ground_skin_transaction(fabric)
	print("SKIN_KEYS ",skin.keys())
	print("SUSPENDED ",skin.suspended_plaza)
	var path := "res://docs/qa/2026-09-13-manual/42-lawn-strips/"
	FileAccess.open(path+"skin.txt",FileAccess.WRITE).store_string(var_to_str(skin))
	var payload := SettlementFabricAssembler.payload(fabric)
	payload.append_from(SettlementFabricAssembler.structural_support_payload(fabric))
	payload.append_from(SettlementFabricAssembler.production_surface_bundle(fabric.surface_plan,SettlementFabricAssembler.maze_module_footprints(fabric),SettlementFabricAssembler.maze_skin_panel_boxes_for(fabric),fabric.planned_plaza_cells))
	var reference:Dictionary = FileAccess.open("res://docs/qa/2026-09-13-manual/07-platform/after-payload.bin",FileAccess.READ).get_var()
	var phase := "after" if "--after" in OS.get_cmdline_user_args() else "before"
	FileAccess.open(path+phase+"-payload.bin",FileAccess.WRITE).store_var({"batches":payload.batches,"collision_boxes":payload.collision_boxes,"surface_meshes":payload.surface_meshes,"transform":reference.transform,"walked":SettlementFabricAssembler.walked_floor_cells(fabric.surface_plan)})
	quit()
