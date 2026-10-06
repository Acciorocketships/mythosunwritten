extends GutTest

func test_fallback_keeps_supported_tower_in_finished_fabric() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := WarrenVolumetricSolver.generate(31, {}, program,
		WarrenVillageScaleProfile.for_id(&"large"))
	assert_not_null(spatial, WarrenVolumetricSolver.last_failure)
	if spatial == null: return
	var towers := 0
	for unit: FabricUnit in spatial.compiled_fabric_cache().units:
		if String(unit.recipe_id).begins_with("anchor.z_native.turret."):
			towers += 1
	assert_gt(towers, 0, "A supported native corner-tower house survives final construction")
