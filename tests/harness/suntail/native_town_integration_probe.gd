extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var cities := (
		args[args.find("--cities") + 1]
		if args.has("--cities")
		else "7:standard,31:large,13:large,43:grand,58:large,101:large,103:grand,211:grand"
	)
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	assert(program != null)
	var rows: Array[Dictionary] = []
	for city: String in cities.split(","):
		var bits := city.split(":")
		var spatial := WarrenVolumetricSolver.generate(
			int(bits[0]), {}, program, WarrenVillageScaleProfile.for_id(StringName(bits[1]))
		)
		var row := {
			"city": city,
			"accepted": [],
			"selected": [],
			"native_instances": 0,
			"projecting_window_bays": 0
		}
		if spatial == null:
			row.failure = WarrenVolumetricSolver.last_failure
		else:
			var source: WarrenMazeSourcePlan = (
				spatial.source_volume.mass_context[&"maze_source_plan"]
			)
			for record: Dictionary in source.audit.get("plot_outcomes", {}).get("assets", []):
				if String(record.get("kind_id", &"")).begins_with("anchor.z_native."):
					row.selected.append(record.kind_id)
			for feature: WarrenFeatureReservation in spatial.features:
				if KitVillageBuildings._native_landmark(feature):
					row.accepted.append(
						{
							"id": feature.stable_id,
							"recipe": feature.audit.landmark_recipe_id,
							"entrance": str(feature.audit.landmark_entrance_cell)
						}
					)
			if not row.accepted.is_empty():
				var fabric := spatial.compiled_fabric_cache()
				var kit_result := KitVillageBuildings.build(
					spatial, fabric, SuntailBuildingKit.create()
				)
				var kept := KitVillageBuildings.legacy_payload_without(
					fabric, kit_result.replaced_units
				)
				for id in kept.asset_ids():
					if id == &"pure_village.native.window_5_2":
						row.projecting_window_bays += kept.batches[id].transforms.size()
					if (
						String(id).begins_with("pure_village.native.")
						or String(id).begins_with("pure_village.arcade.")
					):
						row.native_instances += kept.batches[id].transforms.size()
				row.generic_native_masses = 0
				for mass: BuildingMass in kit_result.houses:
					for feature: Dictionary in row.accepted:
						if mass.stable_id == StringName("kit." + String(feature.id)):
							row.generic_native_masses += 1
		if args.has("--diagnostics"):
			row.landmark_diagnostics = (
				WarrenVolumetricSolver.last_preplan_landmark_diagnostic.duplicate(true)
			)
		rows.append(row)
		print("NATIVE_TOWN ", row)
	var output := (
		args[args.find("--output") + 1]
		if args.has("--output")
		else "/tmp/native-town-integration.json"
	)
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(rows, "  "))
	quit()
