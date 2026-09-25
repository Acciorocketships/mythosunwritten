extends SceneTree

## Cold-solve profile of ONE production village. Answers "where does a village
## solve actually spend its time" by running the real production entry point
## (`WarrenVolumetricSolver.solve`) with the existing SKYWALK_TIMING trace on,
## then reporting the per-stage breakdown the sealed plan carries.
##
##   Godot --headless --path . -s res://tests/harness/warren_solve_profile.gd -- \
##     --city-seed 166029932451774690 --scale compact
##
## The pinned production village of world seed 2697992464 at super cell (0,-1)
## is city seed 166029932451774690, scale compact.

const DEFAULT_CITY_SEED := 166029932451774690


func _init() -> void:
	var city_seed := DEFAULT_CITY_SEED
	var scale_id := WarrenVillageScaleProfile.COMPACT
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == "--city-seed" and index + 1 < args.size():
			city_seed = int(args[index + 1])
		elif args[index] == "--scale" and index + 1 < args.size():
			scale_id = StringName(args[index + 1])

	var catalog_started := Time.get_ticks_msec()
	var catalog := EnvironmentCatalog.load_default()
	var catalog_ms := Time.get_ticks_msec() - catalog_started

	var program_started := Time.get_ticks_msec()
	var program := SettlementFabricProgram.compile(catalog)
	var program_ms := Time.get_ticks_msec() - program_started

	var profile := WarrenVillageScaleProfile.for_id(scale_id)
	print("PROFILE setup city_seed=%d scale=%s catalog_ms=%d program_ms=%d" % [
		city_seed, String(scale_id), catalog_ms, program_ms])

	WarrenVolumetricSolver.diagnostic_trace_skywalk_timing = true
	var solve_started := Time.get_ticks_msec()
	var plan := WarrenVolumetricSolver.solve(city_seed, {}, program, profile)
	var solve_ms := Time.get_ticks_msec() - solve_started
	WarrenVolumetricSolver.diagnostic_trace_skywalk_timing = false

	print("PROFILE solve total_ms=%d sealed=%s" % [solve_ms, str(plan != null)])
	if plan != null:
		print("PROFILE stages %s" % str(plan.audit.get("maze_stage_ms", {})))
	else:
		print("PROFILE failure=%s" % WarrenVolumetricSolver.last_failure.left(600))
	quit()
