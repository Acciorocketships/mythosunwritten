extends SceneTree

## Slow exact corpus for the procedural warren.  The cheap grammar property
## tests prove local rules for many seeds; this harness compiles complete towns
## and records the construction that actually survives every occupancy,
## support, entrance, stair, and overhead transaction.
const DEFAULT_SEEDS: Array[int] = [0, 1, 2, 3]
const ZERO_METRICS: Array[StringName] = [
	&"stair_endpoint_gap_count",
	&"stair_endpoint_missing_landing_count",
	&"stair_to_stair_edge_count",
	&"platform_dead_end_count",
	&"isolated_platform_count",
	&"unsupported_platform_count",
	&"unsupported_stair_count",
	&"unserved_entrance_count",
	&"detached_building_stack_count",
	&"visual_envelope_overlap_count",
]

var _seeds: Array[int] = DEFAULT_SEEDS.duplicate()
var _output := "/tmp/mythos-warren-seed-corpus.json"


func _init() -> void:
	_read_args()
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	assert(program != null)
	var started := Time.get_ticks_msec()
	var rows: Array[Dictionary] = []
	var failures: Array[String] = []
	var route_signatures: Dictionary = {}
	var canonical_route_signatures: Dictionary = {}
	var construction_signatures: Dictionary = {}
	for world_seed: int in _seeds:
		var seed_started := Time.get_ticks_msec()
		var planner := WarrenPlotVoidPlanner.new()
		var plan := planner.solve(program, world_seed)
		if plan == null:
			failures.append("seed %d: %s" % [world_seed,
				planner.failure_reason])
			rows.append({
				"seed": world_seed,
				"accepted": false,
				"failure": planner.failure_reason,
				"elapsed_ms": Time.get_ticks_msec() - seed_started,
			})
			continue
		var audit := plan.audit
		var seed_failures: Array[String] = []
		for metric: StringName in ZERO_METRICS:
			if int(audit.get(metric, -1)) != 0:
				seed_failures.append("%s=%s" % [metric, audit.get(metric)])
		for metric: StringName in [
			&"building_stack_count", &"market_count", &"skywalk_link_count",
			&"outcropping_count",
		]:
			var minimum := 7 if metric == &"building_stack_count" \
				else 2 if metric == &"market_count" else 1
			if int(audit.get(metric, 0)) < minimum:
				seed_failures.append("%s=%s below %d" % [metric,
					audit.get(metric), minimum])
		for proposal: Dictionary in plan.embedding_plan.barrier_proposals:
			if StringName(proposal.kind) == &"bay":
				seed_failures.append("standalone wide bay %s" % proposal)
		var route_signature := String(audit.maze_route_signature)
		var canonical_route_signature := String(
			audit.maze_canonical_route_signature)
		var construction_signature := String(audit.construction_signature)
		if route_signatures.has(route_signature):
			seed_failures.append("route repeats seed %d" % int(
				route_signatures[route_signature]))
		if canonical_route_signature.is_empty():
			seed_failures.append("missing canonical route signature")
		elif canonical_route_signatures.has(canonical_route_signature):
			seed_failures.append(
				"route repeats seed %d after rotation normalization" % int(
					canonical_route_signatures[canonical_route_signature]))
		if construction_signatures.has(construction_signature):
			seed_failures.append("construction repeats seed %d" % int(
				construction_signatures[construction_signature]))
		route_signatures[route_signature] = world_seed
		canonical_route_signatures[canonical_route_signature] = world_seed
		construction_signatures[construction_signature] = world_seed
		for issue: String in seed_failures:
			failures.append("seed %d: %s" % [world_seed, issue])
		rows.append(_row(world_seed, plan, seed_failures,
			Time.get_ticks_msec() - seed_started))
		print(("[warren_seed_corpus] seed=%d accepted=%s route=%s build=%s " \
			+ "stacks=%d skywalks=%d issues=%d elapsed_ms=%d") % [
			world_seed, seed_failures.is_empty(), route_signature.left(10),
			construction_signature.left(10), int(audit.building_stack_count),
			int(audit.skywalk_link_count), seed_failures.size(),
			Time.get_ticks_msec() - seed_started])
	var report := {
		"schema_version": 1,
		"seeds": _seeds,
		"accepted": failures.is_empty(),
		"elapsed_ms": Time.get_ticks_msec() - started,
		"unique_route_signature_count": route_signatures.size(),
		"unique_canonical_route_signature_count":
			canonical_route_signatures.size(),
		"unique_construction_signature_count": construction_signatures.size(),
		"failures": failures,
		"per_seed": rows,
	}
	DirAccess.make_dir_recursive_absolute(_output.get_base_dir())
	var file := FileAccess.open(_output, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("[warren_seed_corpus] accepted=%s seeds=%d output=%s" % [
		failures.is_empty(), _seeds.size(), _output])
	quit(0 if failures.is_empty() else 1)


func _read_args() -> void:
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == "--output" and index + 1 < args.size():
			_output = args[index + 1]
		elif args[index] == "--seeds" and index + 1 < args.size():
			_seeds.clear()
			for value: String in args[index + 1].split(",", false):
				_seeds.append(int(value))
	assert(not _seeds.is_empty())


static func _row(world_seed: int, plan: SettlementFabricPlan,
		failures: Array[String], elapsed_ms: int) -> Dictionary:
	var audit := plan.audit
	return {
		"seed": world_seed,
		"accepted": failures.is_empty(),
		"failures": failures,
		"elapsed_ms": elapsed_ms,
		"maze_grammar_attempt": audit.maze_grammar_attempt,
		"maze_route_signature": audit.maze_route_signature,
		"maze_canonical_route_signature":
			audit.maze_canonical_route_signature,
		"construction_signature": audit.construction_signature,
		"unit_count": audit.unit_count,
		"building_stack_count": audit.building_stack_count,
		"connected_building_stack_count": audit.connected_building_stack_count,
		"market_count": audit.market_count,
		"market_family_count": audit.market_family_count,
		"skywalk_link_count": audit.skywalk_link_count,
		"outcropping_count": audit.outcropping_count,
		"corner_outcropping_count": audit.corner_outcropping_count,
		"frontage_ratio": audit.frontage_ratio,
		"overhead_route_ratio": audit.overhead_route_ratio,
		"through_sightline_count": audit.through_sightline_count,
		"stair_count": audit.stair_count,
		"stair_endpoint_gap_count": audit.stair_endpoint_gap_count,
		"stair_endpoint_missing_landing_count": \
			audit.stair_endpoint_missing_landing_count,
		"stair_to_stair_edge_count": audit.stair_to_stair_edge_count,
		"platform_dead_end_count": audit.platform_dead_end_count,
		"detached_building_stack_count": audit.detached_building_stack_count,
		"visual_quality_target_met": audit.visual_quality_target_met,
	}
