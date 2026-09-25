extends SceneTree
const Frozen=preload("res://tests/fixtures/frozen_maze_source.gd")
func _init()->void:
 var label:="before"
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--label="):label=arg.trim_prefix("--label=")
 var program:=SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
 var fabric:=Frozen.spatial(Frozen.read("res://docs/qa/2026-09-18-manual/83-cliff-fresh-world/town-P02/current-source.txt"),program).compiled_fabric_cache()
 var payload:=SettlementFabricAssembler.payload(fabric)
 payload.append_from(SettlementFabricAssembler.structural_support_payload(fabric))
 payload.append_from(SettlementFabricAssembler.production_surface_bundle(fabric.surface_plan,SettlementFabricAssembler.maze_module_footprints(fabric),SettlementFabricAssembler.maze_skin_panel_boxes_for(fabric),fabric.planned_plaza_cells))
 var old:Dictionary=FileAccess.open("res://docs/qa/2026-09-18-manual/83-cliff-fresh-world/town-P02/before-payload.bin",FileAccess.READ).get_var()
 var data:={"batches":payload.batches,"collision_boxes":payload.collision_boxes,"surface_meshes":payload.surface_meshes,"transform":old.transform,"walked":SettlementFabricAssembler.walked_floor_cells(fabric.surface_plan)}
 var output:="res://docs/qa/2026-09-19-manual/91-masonry-joints/payloads"
 DirAccess.make_dir_recursive_absolute(output)
 FileAccess.open(output.path_join(label+"-payload.bin"),FileAccess.WRITE).store_var(data)
 FileAccess.open(output.path_join(label+"-skin.txt"),FileAccess.WRITE).store_string(var_to_str(SettlementFabricAssembler.maze_ground_skin_transaction(fabric)))
 print("SOFFIT_PAYLOAD ",label," assets=",payload.batches.size())
 quit()
