extends SceneTree

## How far does MODE_MAZE actually get before a gate discards the town?
## Walks the solid-first pipeline stage by stage and reports what EXISTS at
## each step, so "the carver makes nothing" can be told apart from "the carver
## makes a town that a downstream feature requirement then throws away".
##
##   Godot --headless --path . -s res://tests/harness/warren_maze_stage_probe.gd -- \
##     --seeds 1,2,3,4,5,6,7,8,9

func _init() -> void:
	var seeds: Array[int] = []
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == "--seeds" and index + 1 < args.size():
			for token: String in args[index + 1].split(",", false):
				seeds.append(int(token.strip_edges()))
	if seeds.is_empty():
		seeds = [1, 2, 3, 4, 5, 6, 7, 8, 9]

	var program := SettlementFabricProgram.compile(
		EnvironmentCatalog.load_default())

	for city_seed: int in seeds:
		var profile := WarrenVillageScaleProfile.select(city_seed)
		var line := "STAGE seed=%d scale=%s" % [city_seed,
			String(profile.scale_id)]

		var massif := WarrenMassifBuilder.build(city_seed, {}, profile)
		if massif == null:
			print(line + " massif=REJECTED")
			continue
		line += " massif=ok"

		var maze := WarrenMazeCarver.carve(city_seed, massif, profile)
		if maze == null:
			print(line + " carve=REJECTED:" + WarrenMazeCarver.last_failure.left(70))
			continue
		line += " carve=ok"

		var volume := WarrenMazeVolumeAdapter.to_volume_plan(maze)
		if volume == null:
			print(line + " adapt=REJECTED:" \
				+ WarrenMazeVolumeAdapter.last_failure.left(70))
			continue
		line += " adapt=ok"

		# The parcels ARE the buildings: this is the "substitute groups of grid
		# cells for houses" step. If this succeeds, a town physically exists.
		var parcels := WarrenTownSolver.partition_parcels(volume, -1, program)
		if parcels == null:
			print(line + " parcels=REJECTED:" \
				+ WarrenTownSolver.last_partition_failure.left(70))
			continue
		line += " parcels=%d" % parcels.parcels.size()

		var plan := WarrenVolumetricSolver.from_volume(volume, -1, program,
			profile.requires_elevated_courtyard)
		if plan == null:
			print(line + " compose=REJECTED:" \
				+ WarrenVolumetricSolver.last_failure.left(90))
			continue
		var room_count := 0
		for building: WarrenBuildingVolume in plan.buildings:
			room_count += building.room_records.size()
		line += " buildings=%d rooms=%d" % [plan.buildings.size(), room_count]

		var fabric := WarrenSpatialFabricCompiler.solve(plan, program)
		if fabric == null:
			print(line + " fabric=REJECTED:" \
				+ WarrenSpatialFabricCompiler.last_failure.left(90))
			continue
		print(line + " fabric=ok SEALED")
	quit()
