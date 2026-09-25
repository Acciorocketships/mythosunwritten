extends SceneTree

func _init() -> void:
	WarrenSpatialFabricCompiler.diagnostic_trace_timing = true
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var cases := ["1/standard", "2/standard", "3/standard", "3/large",
		"5/standard", "7/grand", "9/standard", "11/large"]
	if not OS.get_cmdline_user_args().is_empty():
		cases.assign(OS.get_cmdline_user_args())
	for key: String in cases:
		var seed := int(key.get_slice("/", 0))
		var profile := WarrenVillageScaleProfile.for_id(StringName(key.get_slice("/", 1)))
		var spatial := WarrenVolumetricSolver.solve(seed, {}, program, profile)
		if spatial == null:
			print("CITY_COMPILE ", key, " FAILED ", WarrenVolumetricSolver.last_failure)
			continue
		var landmarks: Array = []
		for feature: WarrenFeatureReservation in spatial.features:
			if feature.kind == &"prefab_landmark":
				landmarks.append(feature.audit.get("landmark_recipe_id", "missing"))
		print("CITY_COMPILE ", key, " SEALED prefabs=", landmarks,
			" buildings=", spatial.buildings.size())
		print("CITY_PREFAB ", key, " ", JSON.stringify(
			WarrenVolumetricSolver.last_preplan_landmark_diagnostic))
	quit()
