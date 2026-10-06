extends SceneTree
func _init() -> void: call_deferred("_run")
func _run() -> void:
 var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
 for seed_value in [103]:
  var spatial := WarrenVolumetricSolver.generate(seed_value,{},program,WarrenVillageScaleProfile.for_id(&"grand"))
  var built := KitVillageBuildings.build(spatial,spatial.compiled_fabric_cache(),SuntailBuildingKit.create())
  for mass: BuildingMass in built.masses:
   var thin := false
   for roof: Dictionary in mass.roofs:
    if mini(roof.rect.size.x,roof.rect.size.y)<2: thin=true
   if not thin or not String(mass.stable_id).contains("bridge.00.end.1.lower"): continue
   print("THIN_HOST ",seed_value," ",mass.stable_id," ROOFS ",mass.roofs)
   for storey: Dictionary in mass.storeys: print("STOREY ",storey)
   print("DECKS ",mass.decks)
   for z in range(-1,3):
    for x in range(-5,2):
     var p:=Vector3i(x,6,z)
     print("ACCESS ",p," walked=",KitVillageBuildings._walked(spatial.grid,p)," use=",spatial.grid.use_at(p)," above=",spatial.grid.use_at(p+Vector3i.UP))
 quit()
