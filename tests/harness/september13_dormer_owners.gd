extends SceneTree
func _init() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var spatial := frozen.spatial(frozen.read("res://docs/qa/2026-09-13-manual/09-upper-wall/current-source.txt"),program)
	var fabric := spatial.compiled_fabric_cache()
	var payload := SettlementFabricAssembler.payload(fabric)
	payload.append_from(SettlementFabricAssembler.structural_support_payload(fabric))
	payload.append_from(SettlementFabricAssembler.production_surface_bundle(fabric.surface_plan,SettlementFabricAssembler.maze_module_footprints(fabric),SettlementFabricAssembler.maze_skin_panel_boxes_for(fabric),fabric.planned_plaza_cells))
	var records := []
	for unit: FabricUnit in fabric.units:
		var recipe := program.recipe(unit.recipe_id)
		if recipe == null or not recipe.has_tag(&"dormer"): continue
		records.append({"owner":str(unit.stable_id),"recipe":str(unit.recipe_id),"origin":str(unit.lattice_origin),"yaw":unit.yaw_quarters})
	FileAccess.open("res://docs/qa/2026-09-13-manual/41-dormers/owners.json",FileAccess.WRITE).store_string(JSON.stringify(records,"  "))
	quit()
