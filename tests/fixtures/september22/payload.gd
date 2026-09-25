extends SceneTree
## Compiles a frozen town source through the current code into a town-local payload.
## Usage: -s payload.gd -- --town=town-e --name=before
const FROZEN=preload("res://tests/fixtures/frozen_maze_source.gd")
func _init()->void:
	var town:="town-e"; var name:="current"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--town="):town=arg.trim_prefix("--town=")
		if arg.begins_with("--name="):name=arg.trim_prefix("--name=")
	var dir:="res://docs/qa/2026-09-22-manual/"+town
	var program:=SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var saved:Dictionary=FileAccess.open(dir.path_join("payload.bin"),FileAccess.READ).get_var()
	var source:=FROZEN.read(dir.path_join("source.txt"))
	var fabric:=FROZEN.spatial(source,program).compiled_fabric_cache()
	var payload:=SettlementFabricAssembler.payload(fabric)
	payload.append_from(SettlementFabricAssembler.structural_support_payload(fabric))
	payload.append_from(SettlementFabricAssembler.production_surface_bundle(fabric.surface_plan,SettlementFabricAssembler.maze_module_footprints(fabric),SettlementFabricAssembler.maze_skin_panel_boxes_for(fabric),fabric.planned_plaza_cells))
	FileAccess.open(dir.path_join(name+".bin"),FileAccess.WRITE).store_var({"batches":payload.batches,"collision_boxes":payload.collision_boxes,"surface_meshes":payload.surface_meshes,"transform":saved.transform})
	var audit:=fabric.audit
	var keys:=audit.keys().filter(func(k):return String(k).begins_with("continuous_roof"))
	var brief:={}
	for k in keys: brief[k]=audit[k]
	FileAccess.open(dir.path_join(name+"-audit.json"),FileAccess.WRITE).store_string(JSON.stringify(brief,"  "))
	print("PAYLOAD ",town," ",name," ",brief)
	quit()
