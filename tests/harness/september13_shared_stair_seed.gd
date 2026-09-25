extends SceneTree
func _init() -> void:
 var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
 var result := WarrenVolumetricSolver.solve(3,{},program,WarrenVillageScaleProfile.for_id(&"standard"))
 print("SHARED_SEED3 ",result," ",WarrenVolumetricSolver.last_failure)
 quit()
