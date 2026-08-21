extends SceneTree

## Cold-solve profile of ONE production village. Answers "where does a village
## solve actually spend its time" by running the real production entry point
## (`WarrenVolumetricSolver.solve`) with the existing SKYWALK_TIMING trace on,
## then reporting the per-attempt and per-stage breakdown.
##
## This deliberately bypasses `WarrenSolutionPinCache`: a pinned re-seal only
## measures the winning candidate, not the search that found it.
##
##   Godot --headless --path . -s res://tests/harness/warren_solve_profile.gd -- \
##     --city-seed 166029932451774690 --scale compact
##
## The pinned production village of world seed 2697992464 at super cell (0,-1)
## is city seed 166029932451774690, scale compact (it sealed at attempt 11).

const DEFAULT_CITY_SEED := 166029932451774690


func _init() -> void:
	var city_seed := DEFAULT_CITY_SEED
	var scale_id := WarrenVillageScaleProfile.COMPACT
	var rank_probe := true
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == "--city-seed" and index + 1 < args.size():
			city_seed = int(args[index + 1])
		elif args[index] == "--scale" and index + 1 < args.size():
			scale_id = StringName(args[index + 1])
		elif args[index] == "--no-rank-probe":
			rank_probe = false

	var catalog_started := Time.get_ticks_msec()
	var catalog := EnvironmentCatalog.load_default()
	var catalog_ms := Time.get_ticks_msec() - catalog_started

	var program_started := Time.get_ticks_msec()
	var program := SettlementFabricProgram.compile(catalog)
	var program_ms := Time.get_ticks_msec() - program_started

	var profile := WarrenVillageScaleProfile.for_id(scale_id)
	print("PROFILE setup city_seed=%d scale=%s catalog_ms=%d program_ms=%d" % [
		city_seed, String(scale_id), catalog_ms, program_ms])

	# One attempt's frontier + ranking measured on its own. `_solve_frontier`
	# never times the proxy ranking, so without this the ranking cost hides in
	# the unaccounted remainder of every attempt.
	if rank_probe:
		var order := WarrenVolumetricSolver._production_attempt_order(city_seed)
		print("PROFILE attempt_order_size=%d" % order.size())
		if not order.is_empty():
			var probe_attempt: int = order[0]
			var bore_started := Time.get_ticks_msec()
			var frontier := WarrenTownSolver.mass_first_attempt_frontier(
				city_seed, probe_attempt, {}, profile)
			var bore_ms := Time.get_ticks_msec() - bore_started
			var rank_started := Time.get_ticks_msec()
			var ranked := WarrenVolumetricSolver._ranked_precomposition_variants(
				frontier, program)
			var rank_ms := Time.get_ticks_msec() - rank_started
			print(("PROFILE rank_probe attempt=%d bore_ms=%d candidates=%d " \
				+ "rank_ms=%d ranked_pairs=%d") % [probe_attempt, bore_ms,
				frontier.size(), rank_ms, ranked.size()])

	WarrenVolumetricSolver.diagnostic_trace_skywalk_timing = true
	var solve_started := Time.get_ticks_msec()
	var plan := WarrenVolumetricSolver.solve(city_seed, {}, program, profile)
	var solve_ms := Time.get_ticks_msec() - solve_started
	WarrenVolumetricSolver.diagnostic_trace_skywalk_timing = false

	print("PROFILE solve total_ms=%d sealed=%s" % [solve_ms, str(plan != null)])
	if plan != null:
		print("PROFILE selected attempt=%s excavation_attempts=%s frontier=%s probes=%s" % [
			str(plan.audit.get("production_selected_attempt", -1)),
			str(plan.audit.get("production_excavation_attempt_count", -1)),
			str(plan.audit.get("production_staged_frontier_count", -1)),
			str(plan.audit.get("route_court_variant_probe_count", -1))])
	else:
		print("PROFILE failure=%s" % WarrenVolumetricSolver.last_failure.left(600))
	quit()
