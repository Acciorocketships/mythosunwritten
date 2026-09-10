extends SceneTree
func _init() -> void:
 var program:=SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
 var frozen:=preload("res://tests/fixtures/frozen_maze_source.gd")
 var rows:Array=[]
 for label in ["east","offset","thin-turf"]:
  var source:=frozen.read("res://tests/fixtures/september9-%s-source.txt"%label)
  var spatial:=frozen.spatial(source,program)
  var fabric:=spatial.compiled_fabric_cache()
  var contacts:Array=[]
  for spec in VillageWarrenFabricSolver.terrain_contact_specs(spatial,fabric):
   var geometry:=VillageWarrenFabricSolver.terrain_contact_local_geometry(spec)
   contacts.append({"spec":str(spec),"geometry":str(geometry)})
  var tunnels:Array=[]
  for p in source.excavation.public_cells():
   if source.passage_kinds.get(p)==&"tunnel":tunnels.append(str(p))
  rows.append({"source":label,"contacts":contacts,"tunnels":tunnels,"kinds":str(source.passage_kinds)})
 FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
 print(rows)
 quit()
