extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var cities := args[args.find("--cities")+1] if args.has("--cities") else "7:standard,31:large,103:grand"
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var kit := SuntailBuildingKit.create()
	var report := {}
	for city: String in cities.split(","):
		var bits := city.split(":")
		var spatial := WarrenVolumetricSolver.generate(int(bits[0]), {}, program, WarrenVillageScaleProfile.for_id(StringName(bits[1])))
		assert(spatial != null, WarrenVolumetricSolver.last_failure)
		var built := KitVillageBuildings.build(spatial, spatial.compiled_fabric_cache(), kit)
		var houses: Array[Dictionary] = []
		for mass: BuildingMass in built.houses:
			if not mass.roof_design_trace.is_empty() or args.has("--all-houses"):
				var roof_dimensions: Array[Dictionary] = []
				for roof: Dictionary in mass.roofs:
					var rect: Rect2i = roof.rect
					var axis := int(roof.axis)
					roof_dimensions.append({"rect":rect,"area":rect.get_area(),
						"length":rect.size[axis],"depth":rect.size[1-axis],"axis":axis,
						"eave_band":roof.eave_band})
				houses.append({"id": mass.stable_id, "attempts": mass.roof_design_trace,
					"storeys":mass.storeys.size(),"roof_dimensions":roof_dimensions,"roofs": mass.roofs})
		report[city] = {"houses": houses, "audit": preload("res://tests/fixtures/kit_roof_audit.gd").audit(built, kit), "public_air": preload("res://tests/fixtures/kit_roof_public_air_audit.gd").audit(built, kit)}
		print("ROOF_DECISIONS ", city, " houses=", houses.size(), " audit=", report[city].audit)
	var output := args[args.find("--output")+1] if args.has("--output") else "/tmp/roof-articulation.json"
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	quit()
