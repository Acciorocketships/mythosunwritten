extends SceneTree
## Lightweight finished-town tower admission diagnostics, without rendering.
func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var cities := "7:standard,13:large,43:grand"
	if args.has("--cities"):
		cities = args[args.find("--cities") + 1]
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	for city: String in cities.split(","):
		var fields := city.split(":")
		var spatial := WarrenVolumetricSolver.generate(int(fields[0]), {}, program,
			WarrenVillageScaleProfile.for_id(StringName(fields[1])))
		if spatial == null:
			push_error("Town %s failed: %s" % [city, WarrenVolumetricSolver.last_failure])
			quit(1)
			return
		var built := KitVillageBuildings.build(spatial, spatial.compiled_fabric_cache(),
			SuntailBuildingKit.create())
		print("TOWER_ADMISSION ", city, " ", built.roof_audit.towers)
	quit()
