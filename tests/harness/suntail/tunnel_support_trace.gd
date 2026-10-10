extends SceneTree


## Inspect the built support beside a source-planned tunnel room.
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_value := int(args[args.find("--seed") + 1]) if args.has("--seed") else 101
	var profile := (
		StringName(args[args.find("--profile") + 1]) if args.has("--profile") else &"large"
	)
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := WarrenVolumetricSolver.generate(
		seed_value, {}, program, WarrenVillageScaleProfile.for_id(profile)
	)
	assert(spatial != null, WarrenVolumetricSolver.last_failure)
	var source: WarrenMazeSourcePlan = spatial.source_volume.mass_context[&"maze_source_plan"]
	var targets := {}
	for plot: Dictionary in source.plots:
		if plot.kind != WarrenMazeSourcePlan.PLOT_OVER:
			continue
		print("COVER ", plot)
		for jamb: Vector2i in plot.jambs:
			targets[jamb] = true
	for plot: Dictionary in source.plots:
		for column: Vector2i in plot.cells:
			if targets.has(column):
				print("SUPPORT_PLOT ", plot)
				break
	for building: WarrenBuildingVolume in spatial.buildings:
		var touching := false
		for cell: Vector3i in building.private_cells:
			if targets.has(Vector2i(floori(cell.x / 2.0), floori(cell.z / 2.0))):
				touching = true
				break
		if not touching:
			continue
		print("BUILDING ", building.stable_id, " audit=", building.audit)
		for room: WarrenRoomStamp in building.room_records:
			print("ROOM ", room.source_parcel_id, " ", room.audit, " ", room.private_cells)
	for key in spatial.audit:
		if "back_room" in String(key) or "shortened" in String(key):
			print(key, ": ", spatial.audit[key])
	quit()
