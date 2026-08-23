extends SceneTree

## Does MODE_MAZE seal ANY town yet? Runs the real production entry point over a
## seed corpus and reports seal/failure and wall-clock per seed. The maze source
## itself is cheap, so a rejection is usually fast; a slow rejection means the
## composition ran and failed downstream.
##
##   Godot --headless --path . -s res://tests/harness/warren_maze_mode_sweep.gd -- \
##     --seeds 1,2,3,4,5,6,7,8,9 --mode maze
##
## --constructive switches to the plot-model exit-criteria matrix instead: for
## every seed x {compact, standard} it runs the real pipeline --
## WarrenMazeSitePlanner.plan() (massif -> carve -> reserve -> partition ->
## seal) -> WarrenMazeVolumeAdapter.to_volume_plan() ->
## WarrenMazeBlockPartitioner.partition() -- and reports the metrics Phase B is
## measured against (see docs/superpowers/specs/2026-08-21-plot-model-design.md,
## "Success criteria"). --mode is irrelevant to this path and is accepted (and
## ignored) in either order.
##
##   Godot --headless --path . -s res://tests/harness/warren_maze_mode_sweep.gd -- \
##     --seeds 1,2,3,4,5,6,7,8,9,10,11,12 --mode maze --constructive

const CONSTRUCTIVE_SCALES: Array[StringName] = [
	WarrenVillageScaleProfile.COMPACT, WarrenVillageScaleProfile.STANDARD,
]


func _init() -> void:
	var seeds: Array[int] = []
	var mode := WarrenTownSolver.MODE_MAZE
	var constructive := false
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == "--seeds" and index + 1 < args.size():
			for token: String in args[index + 1].split(",", false):
				seeds.append(int(token.strip_edges()))
		elif args[index] == "--mode" and index + 1 < args.size():
			mode = StringName(args[index + 1])
		elif args[index] == "--constructive":
			constructive = true
	if seeds.is_empty():
		seeds = [1, 2, 3, 4, 5, 6, 7, 8, 9]

	if constructive:
		_run_constructive(seeds)
		quit()
		return

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


func _run_constructive(seeds: Array[int]) -> void:
	print("SWEEP constructive seeds=%d scales=%d total=%d" % [seeds.size(),
		CONSTRUCTIVE_SCALES.size(), seeds.size() * CONSTRUCTIVE_SCALES.size()])
	var sealed_count := 0
	var translated_count := 0
	var attempted := 0
	for city_seed: int in seeds:
		for scale_id: StringName in CONSTRUCTIVE_SCALES:
			attempted += 1
			var outcome := _constructive_outcome(city_seed, scale_id)
			if outcome.sealed:
				sealed_count += 1
			if outcome.translated:
				translated_count += 1
			print(String(outcome.line))
	print("SWEEP RESULT constructive sealed=%d/%d translated=%d/%d" % [
		sealed_count, attempted, translated_count, sealed_count])


func _constructive_outcome(city_seed: int, scale_id: StringName) -> Dictionary:
	## Runs the real one-pass pipeline for one (seed, scale) cell of the matrix
	## -- WarrenMazeSitePlanner.plan() (massif -> carve -> reserve -> partition
	## -> seal) then, only if that sealed, WarrenMazeVolumeAdapter and
	## WarrenMazeBlockPartitioner (the same production entry points the debug
	## view and the plot tests exercise) -- and reports the plot-model exit
	## metrics. Every source-side number comes off the sealed plan's own plots
	## and audit; every translated number off the parcel plan's audit.
	var profile := WarrenVillageScaleProfile.for_id(scale_id)
	var plan := WarrenMazeSitePlanner.plan(city_seed, {}, profile)
	if plan == null:
		var reason := WarrenMazeSitePlanner.last_failure
		var colon := reason.find(":")
		var stage := reason.left(colon) if colon >= 0 else "unknown"
		return {"sealed": false, "translated": false,
			"line": "SWEEP seed=%d scale=%s sealed=false stage=%s reason=%s" % [
				city_seed, String(scale_id), stage, reason.left(160)]}

	var source := _source_metrics(plan)
	var volume := WarrenMazeVolumeAdapter.to_volume_plan(plan)
	if volume == null:
		return {"sealed": true, "translated": false,
			"line": "%s translated=false stage=adapter reason=%s" % [
				String(source.line), WarrenMazeVolumeAdapter.last_failure.left(120)]}

	var parcels := WarrenMazeBlockPartitioner.partition(plan, volume)
	if parcels == null:
		return {"sealed": true, "translated": false,
			"line": "%s translated=false stage=partition reason=%s" % [
				String(source.line),
				WarrenMazeBlockPartitioner.last_failure.left(120)]}

	var signature := plan.deterministic_signature().sha256_text().left(12)
	return {"sealed": true, "translated": true,
		"line": ("%s translated=true parcels=%d back_room_cells=%d "
			+ "ownership=%.4f signature=%s") % [
			String(source.line), parcels.parcels.size(),
			int(parcels.audit.get("maze_back_room_cells", 0)),
			float(parcels.audit.get("maze_ownership_ratio", 0.0)), signature]}


func _source_metrics(plan: WarrenMazeSourcePlan) -> Dictionary:
	## The sealed plan's own half of a row: what the plot layer built, and how
	## much of the town's skin it left as bare rock. Counted off `plots` and
	## `plot_facts` directly rather than off the planner's own bookkeeping, so
	## a row reports the town that really sealed.
	var counts: Dictionary = {}
	for kind: StringName in WarrenMazeSourcePlan.PLOT_KINDS:
		counts[kind] = 0
	var tiered := 0
	var house_columns := 0
	for plot: Dictionary in plan.plots:
		var kind := StringName(plot["kind"])
		counts[kind] = int(counts.get(kind, 0)) + 1
		tiered += int(bool(plan.plot_facts(plot).tiered))
		if kind == WarrenMazeSourcePlan.PLOT_HOUSE:
			house_columns += (plot["cells"] as Array).size()
	var houses := int(counts[WarrenMazeSourcePlan.PLOT_HOUSE])
	var exterior := plan.audit.get("exterior_rock_ratio", {}) as Dictionary
	return {"line": ("SWEEP seed=%d scale=%s sealed=true plots=%d houses=%d "
		+ "assets=%d decks=%d bridges=%d tiered=%d mean_footprint=%.2f "
		+ "exterior_rock=%.4f") % [
		plan.world_seed, String(plan.scale_profile.scale_id),
		plan.plots.size(), houses,
		int(counts[WarrenMazeSourcePlan.PLOT_ASSET]),
		int(counts[WarrenMazeSourcePlan.PLOT_DECK]),
		int(counts[WarrenMazeSourcePlan.PLOT_BRIDGE]), tiered,
		float(house_columns) / float(maxi(1, houses)),
		float(exterior.get("ratio", 0.0))]}
