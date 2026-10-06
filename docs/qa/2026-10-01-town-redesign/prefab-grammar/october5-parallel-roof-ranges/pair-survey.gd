extends SceneTree
func _init():
 call_deferred("run")
func run():
 var program = SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
 var records = {}
 for city in ["31:large","53:grand","63:grand","83:grand","103:grand","301:grand"]:
  var bits = city.split(":")
  var spatial = WarrenVolumetricSolver.generate(int(bits[0]),{},program,WarrenVillageScaleProfile.for_id(StringName(bits[1])))
  var built = KitVillageBuildings.build(spatial,spatial.compiled_fabric_cache(),SuntailBuildingKit.create())
  var pairs = []
  for ai in built.roofs.size():
   var a = built.roofs[ai]
   for bi in range(ai+1,built.roofs.size()):
    var b = built.roofs[bi]
    if a.axis != b.axis or a.eave_band != b.eave_band: continue
    var ar: Rect2i = a.rect
    var br: Rect2i = b.rect
    if not Rect2(ar).grow(.3).intersects(Rect2(br).grow(.3)): continue
    var owners = []
    for roof in [a,b]:
     for m in built.houses:
      for r in m.roofs:
       if is_same(r,roof): owners.append(str(m.stable_id))
    pairs.append({"a":a,"b":b,"owners":owners})
  records[city] = pairs
  print(city," ",pairs.size())
 var f = FileAccess.open("/tmp/parallel-roofs.json",FileAccess.WRITE)
 f.store_string(JSON.stringify(records,"  "))
 quit()
