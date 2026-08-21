extends SceneTree

## Does MODE_MAZE seal ANY town yet? Runs the real production entry point over a
## seed corpus and reports seal/failure and wall-clock per seed. The maze source
## itself is cheap, so a rejection is usually fast; a slow rejection means the
## composition ran and failed downstream.
##
##   Godot --headless --path . -s res://tests/harness/warren_maze_mode_sweep.gd -- \
##     --seeds 1,2,3,4,5,6,7,8,9 --mode maze

func _init() -> void:
	var seeds: Array[int] = []
	var mode := WarrenTownSolver.MODE_MAZE
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == "--seeds" and index + 1 < args.size():
			for token: String in args[index + 1].split(",", false):
				seeds.append(int(token.strip_edges()))
		elif args[index] == "--mode" and index + 1 < args.size():
			mode = StringName(args[index + 1])
	if seeds.is_empty():
		seeds = [1, 2, 3, 4, 5, 6, 7, 8, 9]

	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	WarrenTownSolver.GENERATION_MODE = mode
	print("SWEEP mode=%s seeds=%d" % [String(mode), seeds.size()])

	var sealed_count := 0
	var total_ms := 0
	for city_seed: int in seeds:
		var profile := WarrenVillageScaleProfile.select(city_seed)
		var started := Time.get_ticks_msec()
		var plan := WarrenVolumetricSolver.solve(city_seed, {}, program, profile)
		var elapsed := Time.get_ticks_msec() - started
		total_ms += elapsed
		if plan != null:
			sealed_count += 1
			print("SWEEP seed=%d scale=%s ms=%d SEALED rooms=%s" % [city_seed,
				String(profile.scale_id), elapsed,
				str(plan.audit.get("room_storey_kind_counts", {}))])
		else:
			print("SWEEP seed=%d scale=%s ms=%d FAILED %s" % [city_seed,
				String(profile.scale_id), elapsed,
				WarrenVolumetricSolver.last_failure.left(160)])
	print("SWEEP RESULT mode=%s sealed=%d/%d total_ms=%d" % [String(mode),
		sealed_count, seeds.size(), total_ms])
	quit()
