extends SceneTree
func _init(): call_deferred("run")
func run():
 var program=SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
 var result={}
 for city in ["31:large","53:grand","63:grand","83:grand","103:grand","301:grand"]:
  var split=city.split(":")
  var spatial=WarrenVolumetricSolver.generate(int(split[0]),{},program,WarrenVillageScaleProfile.for_id(StringName(split[1])))
  var built=KitVillageBuildings.build(spatial,spatial.compiled_fabric_cache(),SuntailBuildingKit.create())
  var profiles=[]
  for example in built.roof_audit.towers.get("corner_quadrant_examples",[]):
   for mass in built.houses:
    if mass.stable_id!=example.host: continue
    var floors=[]
    for band in range(int(example.base),int(example.top)):
     var cells=mass.cells_at_band(band)
     var occupied=[]
     for offset in [Vector2i(-1,-1),Vector2i(-1,0),Vector2i(0,-1),Vector2i.ZERO]:
      if cells.has(example.corner+offset): occupied.append(offset)
     floors.append(occupied)
    profiles.append({"site":example,"floors":floors})
  result[city]=profiles
  print(city," ",profiles)
 FileAccess.open("/tmp/tower-corner-profiles.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 quit()
