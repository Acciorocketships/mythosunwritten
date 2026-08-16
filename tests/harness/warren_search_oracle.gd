# tests/harness/warren_search_oracle.gd
# Before/after oracle for WarrenVolumetricSolver.solve: for each city seed it
# prints whether the unbudgeted production search seals, which candidate it
# selected, the plan's deterministic signature, and wall time. Diff two runs
# to prove a solver speed change altered no outcome it was not meant to.
#
#   Godot --headless --path . -s res://tests/harness/warren_search_oracle.gd \
#     -- [--city-seeds a,b:standard,c] [--world-seeds x,y] [--label name]
#
# --world-seeds are mapped through the production corpus' flat frame exactly
# like production_warren_seed_corpus.gd; --city-seeds go straight to solve(),
# with an optional ":profile" override (default: the production selection).
extends SceneTree

const Corpus = preload("res://tests/harness/production_warren_seed_corpus.gd")
const DEFAULT_WORLD_SEEDS: Array[int] = [4242, 991177, 3046246887, 2697992464]
## Spawn-halo seeds from the profiling report plus the two settlements
## recorded as sealing in production (2026-08-12 remediation doc).
const DEFAULT_CITY_SEEDS: Array[String] = [
	"166029932451774690", "3910114991003307946", "6357506428441529412",
	"3613595803240038080:standard", "7:standard"]


func _init() -> void:
	var world_seeds: Array[int] = DEFAULT_WORLD_SEEDS.duplicate()
	var city_seeds: Array[String] = DEFAULT_CITY_SEEDS.duplicate()
	var label := "oracle"
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == "--world-seeds" and index + 1 < args.size():
			world_seeds.clear()
			for value: String in args[index + 1].split(",", false):
				world_seeds.append(int(value))
		elif args[index] == "--city-seeds" and index + 1 < args.size():
			city_seeds.clear()
			for value: String in args[index + 1].split(",", false):
				city_seeds.append(value)
		elif args[index] == "--label" and index + 1 < args.size():
			label = args[index + 1]
	var catalog := EnvironmentCatalog.load_default()
	var program := VillageProgram.compile({}, catalog)
	assert(program != null and program.settlement_fabric_program != null)
	var frame: VillageFrame = Corpus._flat_frame()
	var rows: Array[Dictionary] = []
	for world_seed: int in world_seeds:
		var village_plan := VillagePlan.new(world_seed, program)
		rows.append(_solve_row(label, "world:%d" % world_seed,
			village_plan._warren_seed(frame), program))
	for spec: String in city_seeds:
		var parts := spec.split(":", false)
		var override: WarrenVillageScaleProfile = null
		if parts.size() > 1:
			override = WarrenVillageScaleProfile.for_id(StringName(parts[1]))
		rows.append(_solve_row(label, "city", int(parts[0]), program, override))
	print("ORACLE_JSON ", JSON.stringify(rows))
	quit()


func _solve_row(label: String, origin: String, city_seed: int,
		program: VillageProgram,
		profile_override: WarrenVillageScaleProfile = null) -> Dictionary:
	var profile := profile_override if profile_override != null \
		else WarrenVillageScaleProfile.select(city_seed)
	var started := Time.get_ticks_msec()
	var plan := WarrenVolumetricSolver.solve(city_seed, {},
		program.settlement_fabric_program, profile)
	var elapsed := Time.get_ticks_msec() - started
	var row := {
		"label": label,
		"origin": origin,
		"city_seed": city_seed,
		"scale": String(profile.scale_id),
		"accepted": plan != null,
		"ms": elapsed,
	}
	if plan != null:
		row["attempt"] = plan.audit.get("production_selected_attempt", -1)
		row["source_id"] = String(plan.audit.get(
			"production_selected_source_id", ""))
		row["variant"] = plan.audit.get("production_selected_variant", -1)
		row["signature"] = plan.deterministic_signature().sha256_text()
	else:
		row["failure"] = WarrenVolumetricSolver.last_failure.left(160)
	print("ORACLE %s %s city=%d scale=%s accepted=%s ms=%d attempt=%s source=%s variant=%s sig=%s" % [
		label, origin, city_seed, row.scale, str(row.accepted), elapsed,
		str(row.get("attempt", "")), row.get("source_id", ""),
		str(row.get("variant", "")), str(row.get("signature", "")).left(12)])
	return row
