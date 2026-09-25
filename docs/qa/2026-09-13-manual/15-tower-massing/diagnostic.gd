extends SceneTree
func _init() -> void:
 var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
 var source := preload("res://tests/fixtures/frozen_maze_source.gd").read("res://docs/qa/2026-09-13-manual/15-tower-massing/current-source.txt")
 for z in range(3,9):
  var row := ""
  for x in range(-2,7):
   var col := Vector2i(x,z)
   var owners := []
   for plot: Dictionary in source.plots:
    if (plot.cells as Array).has(col): owners.append(str(plot.id)+"/"+str(plot.floor)+"-"+str(plot.top))
   var streets := []
   for walk: Vector3i in source.excavation.public_cells():
    if Vector2i(walk.x,walk.z)==col: streets.append(walk.y)
   print("COLUMN ",col," mass=",source.massif.columns.get(col)," owners=",owners," street=",streets)
 var volume := WarrenMazeVolumeAdapter.to_volume_plan(source)
 var diagnostic := preload("res://docs/qa/2026-09-13-manual/15-tower-massing/diagnostic_solver.gd")
 var result = diagnostic.from_volume(volume,-1,program,false,true)
 print("TOWER_RESULT ", result != null, " ", diagnostic.last_failure)
 quit()
