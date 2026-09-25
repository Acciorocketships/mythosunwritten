extends SceneTree

func _init() -> void:
	WarrenSpatialFabricCompiler.diagnostic_trace_timing="--trace" in OS.get_cmdline_user_args()
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var path := "res://docs/qa/2026-09-13-manual/15-tower-massing/"
	var source := frozen.read(path+"current-source.txt",false)
	preload("res://docs/qa/2026-09-13-manual/15-tower-massing/rejected_lower_massing.gd").finish_house_massing(source)
	source.finish_construction()
	var spatial := frozen.spatial(source,program)
	var fabric := spatial.compiled_fabric_cache()
	var payload := SettlementFabricAssembler.payload(fabric)
	payload.append_from(SettlementFabricAssembler.structural_support_payload(fabric))
	payload.append_from(SettlementFabricAssembler.production_surface_bundle(fabric.surface_plan,
		SettlementFabricAssembler.maze_module_footprints(fabric),
		SettlementFabricAssembler.maze_skin_panel_boxes_for(fabric),fabric.planned_plaza_cells))
	var old: Dictionary=FileAccess.open(path+"before-payload.bin",FileAccess.READ).get_var()
	var output:=path+"after-payload.bin"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	FileAccess.open(output,FileAccess.WRITE).store_var({
		"batches":payload.batches,"collision_boxes":payload.collision_boxes,
		"surface_meshes":payload.surface_meshes,"transform":old.transform,
		"walked":SettlementFabricAssembler.walked_floor_cells(fabric.surface_plan)})
	var facts:=[]
	for feature: WarrenFeatureReservation in spatial.features:
		if feature.kind != &"facade_bay": continue
		facts.append({"id":feature.stable_id,"audit":feature.audit,"records":feature.construction_records})
	FileAccess.open(output.get_basename()+"-features.json",FileAccess.WRITE).store_string(JSON.stringify(facts,"  "))
	print("TOWER_MASSING ",source.audit.get("narrow_house_massing"))
	print("TOWER_PAYLOAD_READY ",facts)
	quit()
