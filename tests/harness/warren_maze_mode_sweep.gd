extends SceneTree

## Does MODE_MAZE seal ANY town yet? Runs the real production entry point over a
## seed corpus and reports seal/failure and wall-clock per seed. The maze source
## itself is cheap, so a rejection is usually fast; a slow rejection means the
## composition ran and failed downstream.
##
##   Godot --headless --path . -s res://tests/harness/warren_maze_mode_sweep.gd -- \
##     --seeds 1,2,3,4,5,6,7,8,9 --mode maze
##
## --constructive switches to the slice-1 exit-criteria matrix instead: for
## every seed x {compact, standard} it runs the real constructive pipeline --
## WarrenMazeSitePlanner.plan() -> WarrenMazeVolumeAdapter.to_volume_plan() ->
## WarrenMazeBlockPartitioner.partition() -- and reports the metrics the
## slice-1 exit criteria are measured against (see docs/superpowers/plans/
## 2026-08-20-constructive-maze-slice1.md, "Slice-1 measured results"). --mode
## is irrelevant to this path and is accepted (and ignored) in either order.
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
	## Runs the real one-pass constructive pipeline for one (seed, scale) cell
	## of the matrix -- WarrenMazeSitePlanner.plan() (massif -> carve -> reserve
	## -> stamp -> seal) then, only if that sealed, WarrenMazeVolumeAdapter and
	## WarrenMazeBlockPartitioner (the same production entry points the
	## constructive debug view and the translator tests exercise) -- and
	## reports the amended slice-1 exit metrics (see the controller amendments
	## recorded in docs/superpowers/plans/2026-08-20-constructive-maze-slice1.md,
	## "Slice-1 measured results").
	var profile := WarrenVillageScaleProfile.for_id(scale_id)
	var plan := WarrenMazeSitePlanner.plan(city_seed, {}, profile)
	if plan == null:
		var reason := WarrenMazeSitePlanner.last_failure
		var colon := reason.find(":")
		var stage := reason.left(colon) if colon >= 0 else "unknown"
		return {"sealed": false, "translated": false,
			"line": "SWEEP seed=%d scale=%s sealed=false stage=%s reason=%s" % [
				city_seed, String(scale_id), stage, reason.left(160)]}

	var volume := WarrenMazeVolumeAdapter.to_volume_plan(plan)
	if volume == null:
		return {"sealed": true, "translated": false,
			"line": "SWEEP seed=%d scale=%s sealed=true stage=adapter reason=%s" % [
				city_seed, String(scale_id),
				WarrenMazeVolumeAdapter.last_failure.left(160)]}

	var parcels := WarrenMazeBlockPartitioner.partition(plan, volume)
	if parcels == null:
		return {"sealed": true, "translated": false,
			"line": "SWEEP seed=%d scale=%s sealed=true stage=partition reason=%s" % [
				city_seed, String(scale_id),
				WarrenMazeBlockPartitioner.last_failure.left(160)]}

	var lineage_hints := parcels.audit.get("maze_lineage_hints", {}) as Dictionary
	var median_lineage := _median(_lineage_footprint_totals(lineage_hints,
		parcels.parcels))
	var ownership := float(parcels.audit.get("maze_owned_solid_ratio", 0.0))
	var breakdown := parcels.audit.get("maze_ownership_breakdown", {}) as Dictionary
	var foundation_column_count := \
		(plan.audit.get("foundation_columns", {}) as Dictionary).size()
	var signature := plan.deterministic_signature().sha256_text().left(12)
	return {"sealed": true, "translated": true,
		"line": ("SWEEP seed=%d scale=%s sealed=true translated=true parcels=%d "
			+ "median_lineage=%d ownership=%.4f breakdown=%s "
			+ "foundation_columns=%d signature=%s") % [
			city_seed, String(scale_id), parcels.parcels.size(), median_lineage,
			ownership, _format_breakdown(breakdown), foundation_column_count,
			signature]}


func _lineage_footprint_totals(lineage_hints: Dictionary,
		parcels: Array[WarrenBuildingParcel]) -> Array[int]:
	## Groups translated parcels by their shared lineage (an L-pair's two
	## claims, or any other claim family the stamp pass tagged with a common
	## lineage_hint) and sums each group's footprint column count -- the
	## amended exit metric is median LINEAGE footprint, not median per-claim
	## footprint (a stamped L-pair is one building split into two claims, and
	## the old per-claim median counted it as two small buildings). A parcel
	## with no lineage_hint is its own singleton lineage.
	var totals: Dictionary = {}
	for parcel: WarrenBuildingParcel in parcels:
		var stable_id := String(parcel.stable_id)
		var hint := StringName(lineage_hints.get(stable_id, &""))
		var group_key := String(hint) if not hint.is_empty() else stable_id
		totals[group_key] = int(totals.get(group_key, 0)) + parcel.footprint.size()
	var out: Array[int] = []
	out.assign(totals.values())
	return out


func _median(values: Array[int]) -> int:
	## Upper-middle element, not an even-count average -- a report-only
	## approximation (matches the convention this codebase already uses for
	## footprint medians in test_warren_maze_constructive.gd), fine for a
	## sweep metric but not a precise statistical median.
	if values.is_empty():
		return 0
	var sorted_values := values.duplicate()
	sorted_values.sort()
	return sorted_values[sorted_values.size() / 2]


func _format_breakdown(breakdown: Dictionary) -> String:
	return "claimed=%s,reserved=%s,buildable_unclaimed=%s,unbuildable=%s" % [
		breakdown.get("claimed", 0), breakdown.get("reserved", 0),
		breakdown.get("buildable_unclaimed", 0), breakdown.get("unbuildable", 0)]
