extends SceneTree
func _init() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	for item in [[1,&"compact"],[2,&"compact"],[3,&"standard"],[4,&"standard"]]:
		var plan := WarrenVolumetricSolver.solve(item[0],{},program,WarrenVillageScaleProfile.for_id(item[1]))
		print("COMPACT_JOIN_FAILURE ",item," ","PASS" if plan!=null else WarrenVolumetricSolver.last_failure)
	quit()
