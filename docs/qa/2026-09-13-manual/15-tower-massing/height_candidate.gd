extends SceneTree
func _init() -> void:
 var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
 var source := preload("res://tests/fixtures/frozen_maze_source.gd").read("res://docs/qa/2026-09-13-manual/15-tower-massing/current-source.txt",false)
 for plot: Dictionary in source.plots:
  if plot.id in [&"house.018", &"house.020"]: plot.top=8
 source.finish_construction()
 var volume := WarrenMazeVolumeAdapter.to_volume_plan(source)
 var diagnostic := preload("res://docs/qa/2026-09-13-manual/15-tower-massing/diagnostic_solver.gd")
 var result = diagnostic.from_volume(volume,-1,program,false,true)
 print("TOWER_RESULT ", result != null, " ", diagnostic.last_failure)
 quit()
