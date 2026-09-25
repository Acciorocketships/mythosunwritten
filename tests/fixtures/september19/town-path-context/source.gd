extends SceneTree
const ROOT="res://docs/qa/2026-09-19-manual/106-town-path-context/"
const FROZEN=preload("res://tests/fixtures/frozen_maze_source.gd")
func _init()->void:
 var source:=FROZEN.read("res://docs/qa/2026-09-18-manual/83-cliff-fresh-world/town-P02/current-source.txt")
 var program:=SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
 var spatial:=FROZEN.spatial(source,program)
 var fabric:=spatial.compiled_fabric_cache()
 var pose:Transform3D=FileAccess.open("res://docs/qa/2026-09-18-manual/83-cliff-fresh-world/town-P02/before-payload.bin",FileAccess.READ).get_var().transform
 var skin:=SettlementFabricAssembler.maze_ground_skin_transaction(fabric)
 var report:Dictionary={"transform":str(pose),"nearby":{},"entrances":fabric.surface_plan.entrance_records,"excavation_route":str(source.excavation.route),"excavation_lanes":str(source.excavation.lanes)}
 for kind:String in ["retained","walked","garden","bearing","solids","paved"]:
  var cells:Array=[]
  for cell:Vector3i in skin[kind]:
   var world:Vector3=pose*(Vector3(cell)*FabricRecipe.CELL_SIZE)
   if Vector2(world.x+1046,world.z-1066).length()>20:continue
   cells.append({"cell":str(cell),"world":str(world),"value":str(skin[kind][cell])})
  report.nearby[kind]=cells
 FileAccess.open(ROOT+"source.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("TOWN_PATH_SOURCE ",report.nearby.size()," categories saved")
 quit()
