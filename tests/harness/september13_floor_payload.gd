extends SceneTree
func _init() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var spatial := frozen.spatial(frozen.read("res://docs/qa/2026-09-13-manual/09-upper-wall/current-source.txt"),program)
	var fabric := spatial.compiled_fabric_cache()
	var payload := SettlementFabricAssembler.payload(fabric)
	payload.append_from(SettlementFabricAssembler.structural_support_payload(fabric))
	payload.append_from(SettlementFabricAssembler.production_surface_bundle(fabric.surface_plan,SettlementFabricAssembler.maze_module_footprints(fabric),SettlementFabricAssembler.maze_skin_panel_boxes_for(fabric),fabric.planned_plaza_cells))
	var old: Dictionary = FileAccess.open("res://docs/qa/2026-09-13-manual/38-floor/before-payload.bin",FileAccess.READ).get_var()
	var entries := []
	for entry: Dictionary in fabric.expanded_placements():
		entries.append({"id":str(entry.stable_id),"asset":str(entry.asset_id),"transform":str(old.transform * entry.transform)})
	FileAccess.open("res://docs/qa/2026-09-13-manual/38-floor/entries.json",FileAccess.WRITE).store_string(JSON.stringify(entries,"  "))
	var result := {"batches_identical":old.batches == payload.batches,"collision_boxes_identical":old.collision_boxes == payload.collision_boxes,"changed_meshes":[],"unchanged_meshes":0}
	for i in payload.surface_meshes.size():
		if old.surface_meshes[i] == payload.surface_meshes[i]: result.unchanged_meshes += 1
		else: result.changed_meshes.append({"index":i,"before_vertices":old.surface_meshes[i].vertices.size(),"after_vertices":payload.surface_meshes[i].vertices.size()})
	var path := "res://docs/qa/2026-09-13-manual/38-floor/"
	FileAccess.open(path+"payload-comparison.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	FileAccess.open(path+"after-payload.bin",FileAccess.WRITE).store_var({"batches":payload.batches,"collision_boxes":payload.collision_boxes,"surface_meshes":payload.surface_meshes,"transform":old.transform,"walked":SettlementFabricAssembler.walked_floor_cells(fabric.surface_plan)})
	print("UPPER_WALL_PAYLOAD ",result)
	quit()
