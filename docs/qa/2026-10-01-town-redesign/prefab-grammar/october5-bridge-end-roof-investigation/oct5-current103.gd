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
 quit()
