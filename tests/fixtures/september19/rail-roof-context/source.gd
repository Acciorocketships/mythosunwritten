extends SceneTree
const ROOT = "res://docs/qa/2026-09-19-manual/108-rail-roof-context"
func _init() -> void:
 var target:=ROOT.path_join("after") if "--after" in OS.get_cmdline_user_args() else ROOT
 DirAccess.make_dir_recursive_absolute(target)
 var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
 var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
 var spatial := frozen.spatial(frozen.read("res://docs/qa/2026-09-16-manual/05-town-rails/current-source.txt"),program)
 var fabric := spatial.compiled_fabric_cache()
 var payload := SettlementFabricAssembler.payload(fabric)
 payload.append_from(SettlementFabricAssembler.structural_support_payload(fabric))
 payload.append_from(SettlementFabricAssembler.production_surface_bundle(fabric.surface_plan,SettlementFabricAssembler.maze_module_footprints(fabric),SettlementFabricAssembler.maze_skin_panel_boxes_for(fabric),fabric.planned_plaza_cells))
 var before_path := ROOT.path_join("payload.bin") if "--after" in OS.get_cmdline_user_args() else "res://docs/qa/2026-09-16-manual/14-rail-fragments/after-payload.bin"
 var old: Dictionary = FileAccess.open(before_path,FileAccess.READ).get_var()
 var changed: Array = []
 for i in mini(old.surface_meshes.size(),payload.surface_meshes.size()):
  if old.surface_meshes[i] != payload.surface_meshes[i]: changed.append(i)
 var report := {"batches_identical":old.batches==payload.batches,"boxes_identical":old.collision_boxes==payload.collision_boxes,"mesh_count_before":old.surface_meshes.size(),"mesh_count_after":payload.surface_meshes.size(),"changed_meshes":changed}
 FileAccess.open(target.path_join("payload.bin"),FileAccess.WRITE).store_var({"batches":payload.batches,"collision_boxes":payload.collision_boxes,"surface_meshes":payload.surface_meshes,"transform":old.transform,"walked":SettlementFabricAssembler.walked_floor_cells(fabric.surface_plan)})
 FileAccess.open(target.path_join("source-comparison.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("RAIL_ROOF_CURRENT ",report)
 quit()
