extends SceneTree
const FROZEN := preload("res://tests/fixtures/frozen_maze_source.gd")
func _init() -> void: call_deferred("_run")
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_value := int(args[0]) if not args.is_empty() else 1
	var scale := StringName(args[1]) if args.size() > 1 else &"compact"
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var source := WarrenMazeSitePlanner.plan(seed_value, {}, WarrenVillageScaleProfile.for_id(scale), &"", false)
	var volume := WarrenMazeVolumeAdapter.to_volume_plan(source)
	if volume == null:
		print("VOLUME_FAIL ", WarrenMazeVolumeAdapter.last_failure)
		quit(1)
		return
	var spatial := FROZEN.spatial(source, program)
	var built := KitVillageBuildings.build(spatial, spatial.compiled_fabric_cache(), SuntailBuildingKit.create())
	for mass: BuildingMass in built.masses:
		var floors: Array = []
		var loggias := 0
		for storey: Dictionary in mass.storeys:
			floors.append([storey.floor_band, storey.cells.size(), BuildingDesigner._bounds(storey.cells)])
			loggias += int(storey.get("loggia", false))
		print("MASS ", mass.stable_id, " floors=", floors, " decks=", mass.decks.size(), " loggias=", loggias)
	quit()
