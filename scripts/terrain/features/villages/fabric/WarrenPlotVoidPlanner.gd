class_name WarrenPlotVoidPlanner
extends RefCounted

## Compiles a coupled coarse plot/void decision into ordinary settlement-fabric
## units. This planner owns no render resources and introduces no alternate
## collision or support rules: every candidate still passes through the common
## SettlementFabricSolver transaction.
var failure_reason := ""
const MAX_GRAMMAR_ATTEMPTS := 96
const MASSING_BEAM_WIDTH := 4
const MASSING_FRONTIER_SIZE := 8
const MAX_COARSE_ROUTE_SPAN_CELLS := 17
# Compare at least two complete structural survivors. If their best result
# still has a severe open-corridor or overhead failure, admit up to four more bounded
# alternatives; ordinary seeds retain the cheaper search. This gives the exact
# visual ranker a meaningful choice without reopening the former near-duplicate
# exhaustive search for every settlement.
const MIN_STRUCTURAL_FALLBACKS := 2
const MAX_STRUCTURAL_FALLBACKS := 6
const SEVERE_SIGHTLINE_COUNT := 50


func solve(program: SettlementFabricProgram, world_seed: int = 0,
		requirements: Dictionary = {}) -> SettlementFabricPlan:
	failure_reason = ""
	if program == null:
		failure_reason = "missing settlement fabric program"
		return null
	var last_rejection := "no coarse route candidate"
	var compact_candidates: Array[Dictionary] = []
	var expanded_candidates: Array[Dictionary] = []
	var seen_geometry: Dictionary = {}
	for attempt in MAX_GRAMMAR_ATTEMPTS:
		var grammar_started := Time.get_ticks_msec()
		var grammar := WarrenPlotVoidGrammar.build(world_seed, attempt)
		if grammar == null or not grammar.validate():
			_trace_attempt(world_seed, attempt, grammar_started,
				"coarse route rejected")
			continue
		var coarse_bounds := grammar.coarse_route_bounds()
		var geometry_signature := grammar.geometry_signature()
		if seen_geometry.has(geometry_signature):
			continue
		seen_geometry[geometry_signature] = true
		var grammar_record := {"attempt": attempt, "grammar": grammar,
			"bounds": coarse_bounds,
			"seed_rank": _seeded_geometry_rank(geometry_signature, world_seed)}
		if coarse_bounds.size.x <= MAX_COARSE_ROUTE_SPAN_CELLS \
				and coarse_bounds.size.y <= MAX_COARSE_ROUTE_SPAN_CELLS:
			compact_candidates.append(grammar_record)
		else:
			expanded_candidates.append(grammar_record)
	# Compactness orders the bounded search but never invalidates a seed. If all
	# compact routes lose exact frontage/support/overhead tests, the broader
	# deterministic candidates remain legal fallbacks.
	compact_candidates.sort_custom(_coarse_candidate_less)
	expanded_candidates.sort_custom(_coarse_candidate_less)
	compact_candidates.append_array(expanded_candidates)
	var best_fallback: SettlementFabricPlan
	var best_fallback_grammar: WarrenPlotVoidPlan
	var structurally_valid_count := 0
	for candidate_record: Dictionary in compact_candidates:
		var attempt := int(candidate_record.attempt)
		var grammar := candidate_record.grammar as WarrenPlotVoidPlan
		var attempt_started := Time.get_ticks_msec()
		var candidate := _solve_grammar(program, world_seed, requirements,
			grammar)
		if candidate != null:
			candidate.audit["maze_grammar_attempt"] = attempt
			candidate.audit["maze_route_signature"] = \
				grammar.geometry_signature().sha256_text()
			candidate.audit["maze_canonical_route_signature"] = \
				grammar.canonical_coarse_route_signature().sha256_text()
			candidate.audit["construction_signature"] = \
				candidate.construction_signature()
			if _meets_visual_targets(candidate.audit):
				candidate.audit["visual_quality_target_met"] = true
				_trace_attempt(world_seed, attempt, attempt_started, "accepted")
				return candidate
			structurally_valid_count += 1
			if best_fallback == null or _visual_candidate_better(candidate,
					best_fallback):
				best_fallback = candidate
				best_fallback_grammar = grammar
			_trace_attempt(world_seed, attempt, attempt_started,
				"structurally valid visual fallback")
			if structurally_valid_count >= MAX_STRUCTURAL_FALLBACKS \
					or (structurally_valid_count >= MIN_STRUCTURAL_FALLBACKS \
						and not _has_severe_visual_failure(
							best_fallback.audit)):
				break
			continue
		last_rejection = failure_reason
		_trace_attempt(world_seed, attempt, attempt_started, failure_reason)
	if best_fallback != null:
		best_fallback.audit["visual_quality_target_met"] = false
		best_fallback.audit["visual_quality_fallback_count"] = \
			structurally_valid_count
		# The signature and attempt already identify the selected candidate. Keep
		# this assertion local so later refactors cannot accidentally return the
		# last candidate examined instead of the deterministically ranked one.
		assert(String(best_fallback.audit.get("maze_route_signature", "")) == \
			best_fallback_grammar.geometry_signature().sha256_text())
		failure_reason = ""
		return best_fallback
	failure_reason = "bounded maze search exhausted %d candidates; last: %s" % [
		MAX_GRAMMAR_ATTEMPTS, last_rejection]
	return null


static func _coarse_candidate_less(a: Dictionary, b: Dictionary) -> bool:
	var a_size := (a.bounds as Rect2i).size
	var b_size := (b.bounds as Rect2i).size
	var a_span := maxi(a_size.x, a_size.y)
	var b_span := maxi(b_size.x, b_size.y)
	if a_span != b_span:
		return a_span < b_span
	var a_area := a_size.x * a_size.y
	var b_area := b_size.x * b_size.y
	if a_area != b_area:
		return a_area < b_area
	var a_aspect := absi(a_size.x - a_size.y)
	var b_aspect := absi(b_size.x - b_size.y)
	if a_aspect != b_aspect:
		return a_aspect < b_aspect
	# Vertical schedule families make the selected geometry seed-specific before
	# this ordering runs. The hash now breaks genuinely equivalent compactness
	# ties without sacrificing enclosure just to obtain variation.
	if int(a.seed_rank) != int(b.seed_rank):
		return int(a.seed_rank) < int(b.seed_rank)
	return int(a.attempt) < int(b.attempt)


static func _seeded_geometry_rank(signature: String, world_seed: int) -> int:
	var hash_value := world_seed ^ 0x6d2b79f5
	for byte in signature.to_utf8_buffer():
		hash_value = int((hash_value ^ int(byte)) * 16777619) & 0x7fffffff
	return hash_value


static func _meets_visual_targets(audit: Dictionary) -> bool:
	return float(audit.get("frontage_ratio", 0.0)) >= 0.40 \
		and float(audit.get("overhead_route_ratio", 0.0)) >= 0.15 \
		and int(audit.get("skywalk_link_count", 0)) >= 2 \
		and int(audit.get("through_sightline_count", 2147483647)) <= 20 \
		and int(audit.get("solid_void_core_width_cells", 2147483647)) <= 24 \
		and int(audit.get("solid_void_core_depth_cells", 2147483647)) <= 24


static func _has_severe_visual_failure(audit: Dictionary) -> bool:
	return float(audit.get("overhead_route_ratio", 0.0)) < 0.15 \
		or int(audit.get("through_sightline_count", 2147483647)) \
			> SEVERE_SIGHTLINE_COUNT


static func _visual_candidate_better(candidate: SettlementFabricPlan,
		incumbent: SettlementFabricPlan) -> bool:
	var candidate_audit := candidate.audit
	var incumbent_audit := incumbent.audit
	var candidate_violation := _visual_target_violation(candidate_audit)
	var incumbent_violation := _visual_target_violation(incumbent_audit)
	if not is_equal_approx(candidate_violation, incumbent_violation):
		return candidate_violation < incumbent_violation
	var candidate_score := _visual_quality_score(candidate_audit)
	var incumbent_score := _visual_quality_score(incumbent_audit)
	if not is_equal_approx(candidate_score, incumbent_score):
		return candidate_score > incumbent_score
	return String(candidate_audit.get("maze_route_signature", "")) \
		< String(incumbent_audit.get("maze_route_signature", ""))


static func _visual_target_violation(audit: Dictionary) -> float:
	var frontage := float(audit.get("frontage_ratio", 0.0))
	var overhead := float(audit.get("overhead_route_ratio", 0.0))
	var sightlines := int(audit.get("through_sightline_count", 2147483647))
	var width := int(audit.get("solid_void_core_width_cells", 2147483647))
	var depth := int(audit.get("solid_void_core_depth_cells", 2147483647))
	var skywalk_links := int(audit.get("skywalk_link_count", 0))
	return maxf(0.0, (0.40 - frontage) / 0.40) \
		+ maxf(0.0, (0.15 - overhead) / 0.15) \
		+ maxf(0.0, float(2 - skywalk_links) / 2.0) \
		+ maxf(0.0, float(sightlines - 20) / 20.0) \
		+ maxf(0.0, float(maxi(width, depth) - 24) / 24.0)


static func _visual_quality_score(audit: Dictionary) -> float:
	var width := int(audit.get("solid_void_core_width_cells", 2147483647))
	var depth := int(audit.get("solid_void_core_depth_cells", 2147483647))
	return float(audit.get("frontage_ratio", 0.0)) * 600.0 \
		+ minf(float(audit.get("overhead_route_ratio", 0.0)), 0.40) * 300.0 \
		- float(audit.get("through_sightline_count", 2147483647)) * 3.0 \
		- float(maxi(width, depth)) * 6.0 \
		- float(absi(width - depth)) * 2.0 \
		+ float(mini(int(audit.get("building_stack_count", 0)), 15)) * 2.0 \
		+ float(mini(int(audit.get("skywalk_link_count", 0)), 3)) * 30.0 \
		+ float(mini(int(audit.get("half_level_neighbor_pair_count", 0)), 16))


static func _trace_attempt(world_seed: int, attempt: int,
		started_msec: int, result: String) -> void:
	if OS.get_environment("WARREN_TIMING_DEBUG") != "1":
		return
	print("[warren-plot-timing] seed=%d attempt=%d %dms %s" % [world_seed,
		attempt, Time.get_ticks_msec() - started_msec, result])


func _solve_grammar(program: SettlementFabricProgram, world_seed: int,
		requirements: Dictionary, grammar: WarrenPlotVoidPlan) \
		-> SettlementFabricPlan:
	failure_reason = ""
	var stage_started := Time.get_ticks_msec()
	var specs: Array[Dictionary] = []
	var by_id: Dictionary = {}
	var itinerary: Array[StringName] = []
	if not _compile_route(program, grammar, specs, by_id, itinerary):
		return null
	if not grammar.occupied_plots.is_empty() \
			and not StaggeredFabricCompiler.append_proposals(program,
				grammar.occupied_plots, specs, by_id):
		failure_reason = "could not compile grammar-owned occupied plots"
		return null
	var episode_overrides: Dictionary = {}
	var cover_overrides: Dictionary = {}
	for node_id: StringName in grammar.covered_node_ids:
		episode_overrides[node_id] = PublicRealmNode.EpisodeKind.UNDERCROFT
		cover_overrides[node_id] = PublicRealmNode.CoverPolicy.COVERED
	var realm := SectionalPublicRealmBuilder.from_specs(
		&"warren.plot-void.realm", program, specs, itinerary,
		episode_overrides, cover_overrides)
	if realm == null:
		failure_reason = SectionalPublicRealmBuilder.last_failure
		return null
	var solver := SettlementFabricSolver.new(program)
	var seed_plan := solver.solve_sectional(&"warren.plot-void.seed", realm,
		SectionalPublicRealmBuilder.bind_specs(specs, program))
	if seed_plan == null:
		failure_reason = solver.failure_reason
		return null
	_trace_stage(world_seed, grammar, "route-seed", stage_started)
	# The inhabited alley is the primary ground-use decision. Source-pack houses
	# are deliberately admitted only after its stocked frontages and surrounding
	# modular mass have survived the common transaction; reserving a large prefab
	# first routinely erased one side of the market before the beam could see it.
	stage_started = Time.get_ticks_msec()
	var market_frontier := StaggeredFabricEmbedder.solve_frontier(
		&"warren.plot-void.market", seed_plan.solid_void_plan,
		seed_plan.public_realm.air_claims(),
		WarrenRisingRingPlanner._occupied_or_occluding_cells(seed_plan),
		seed_plan.transformed_cells(&"inhabited"), MASSING_BEAM_WIDTH, 2,
		program, seed_plan.transformed_visual_clearance_bounds(), true,
		MASSING_FRONTIER_SIZE, &"global_set", world_seed,
		_market_zone_cells(grammar, seed_plan), {}, 2)
	_trace_stage(world_seed, grammar, "market-frontier", stage_started)
	stage_started = Time.get_ticks_msec()
	var market_seed_found := false
	for market_embedding: StaggeredFabricEmbeddingPlan in market_frontier:
		if int(market_embedding.audit().proposed_market_frontage_count) < 2:
			continue
		var market_specs: Array[Dictionary] = []
		market_specs.assign(specs)
		var market_by_id := by_id.duplicate()
		if not StaggeredFabricCompiler.append_specs(program, market_embedding,
				market_specs, market_by_id):
			continue
		var market_realm := SectionalPublicRealmBuilder.from_specs(
			&"warren.plot-void.market-realm", program, market_specs, itinerary,
			episode_overrides, cover_overrides)
		if market_realm == null:
			continue
		var market_plan := solver.solve_sectional(&"warren.plot-void.market-seed",
			market_realm, SectionalPublicRealmBuilder.bind_specs(market_specs,
				program), {}, market_embedding)
		if market_plan == null:
			continue
		# The authored house is selected against the occupied market rather than
		# claiming its site first. Try the bounded market alternatives until both
		# ground uses coexist in one exact transaction.
		market_plan = WarrenRisingRingPlanner._append_ground_prefab_anchors(
			program, solver, market_realm, market_plan, market_specs,
			market_by_id, world_seed, _market_zone_cells(grammar, market_plan), 1)
		if int(market_plan.audit.get("prefab_anchor_count", 0)) < 1:
			continue
		specs = market_specs
		by_id = market_by_id
		realm = market_realm
		seed_plan = market_plan
		market_seed_found = true
		break
	if not market_seed_found:
		failure_reason = "no exact two-stall alley coexists with an authored house"
		return null
	_trace_stage(world_seed, grammar, "market-exact", stage_started)
	stage_started = Time.get_ticks_msec()
	var frontier := StaggeredFabricEmbedder.solve_frontier(
		&"warren.plot-void.embedding", seed_plan.solid_void_plan,
		seed_plan.public_realm.air_claims(),
		WarrenRisingRingPlanner._occupied_or_occluding_cells(seed_plan),
		seed_plan.transformed_cells(&"inhabited"), MASSING_BEAM_WIDTH, 28, program,
		seed_plan.transformed_visual_clearance_bounds(), false,
		MASSING_FRONTIER_SIZE,
		# The beam preserves disjoint facade-pair potential explicitly, so eight
		# complete results supply the exact overhead gate without retaining a second
		# tier of near-duplicate massings.
		&"global_set", world_seed, {}, _terminal_zone_cells(grammar, seed_plan),
		0, 1)
	_trace_stage(world_seed, grammar, "massing-frontier", stage_started)
	stage_started = Time.get_ticks_msec()
	var selection := WarrenRisingRingPlanner._select_embedding_frontier(program,
		solver, frontier, specs, by_id, itinerary, episode_overrides,
		cover_overrides, world_seed, true)
	var embedding: StaggeredFabricEmbeddingPlan
	var plan: SettlementFabricPlan
	if selection.is_empty():
		if grammar.occupied_plots.is_empty():
			failure_reason = "no complete massing frontier preserves a viable skywalk"
			return null
		# A complete grammar-owned motif may intentionally leave no legal infill
		# candidate. Attach an empty search lineage rather than treating "nothing
		# more fits" as a failure or rerunning a second construction authority.
		embedding = _empty_embedding(seed_plan)
		if embedding == null:
			failure_reason = "could not seal empty optional-infill lineage"
			return null
		plan = solver.solve_sectional(&"warren.plot-void.grammar", realm,
			SectionalPublicRealmBuilder.bind_specs(specs, program), {}, embedding)
		if plan == null:
			failure_reason = solver.failure_reason
			return null
	else:
		var selected_specs: Array[Dictionary] = []
		selected_specs.assign(selection.specs as Array)
		specs = selected_specs
		by_id = selection.by_id as Dictionary
		realm = selection.realm as SectionalPublicRealmPlan
		embedding = selection.embedding as StaggeredFabricEmbeddingPlan
		plan = selection.plan as SettlementFabricPlan
	_trace_stage(world_seed, grammar, "massing-exact", stage_started)
	stage_started = Time.get_ticks_msec()
	plan = WarrenRisingRingPlanner._append_overhead_transactionally(program,
		solver, realm, plan, embedding, specs, by_id, world_seed)
	_trace_stage(world_seed, grammar, "overhead-exact", stage_started)
	var effective_requirements := requirements.duplicate(true)
	# These are construction invariants, not aesthetic targets. A caller may add
	# stricter thresholds but cannot opt out of continuous landings or inhabited
	# reachability for a particular seed.
	for hard_metric: StringName in [
		&"stair_endpoint_gap_count",
		&"stair_endpoint_missing_landing_count",
		&"stair_to_stair_edge_count",
		&"platform_dead_end_count",
		&"isolated_platform_count",
		&"unsupported_platform_count",
		&"unsupported_stair_count",
		&"unserved_entrance_count",
		&"detached_building_stack_count",
	]:
		effective_requirements[hard_metric] = {"max": 0}
	for minimum_metric: StringName in [
		&"building_stack_count",
		&"market_count",
		&"skywalk_link_count",
		&"outcropping_count",
	]:
		# Seven inhabited stacks is the common village contract. Denser results are
		# preferred by the visual ranker, but raising this hard floor to nine made
		# some seeds throw away fully connected 16--20-room towns merely because
		# several rooms shared one structural stack.
		var minimum := 1
		if minimum_metric == &"building_stack_count":
			minimum = 7
		elif minimum_metric == &"market_count":
			minimum = 2
		elif minimum_metric == &"skywalk_link_count":
			minimum = 1
		effective_requirements[minimum_metric] = {"min": minimum}
	# Every branch above returns a sealed exact transaction. Re-solving the same
	# specs here used to rebuild occupancy, public surfaces, exterior volumes, and
	# the solid/void field solely to apply scalar requirements to the audit it had
	# already computed. Keep one construction authority and validate that sealed
	# audit directly; this is both cheaper and rules out disagreement between an
	# accepted overhead transaction and an unnecessary final reconstruction.
	# Enclosure and compactness are compared across complete candidates by
	# `solve()`. They are intentionally not hard requirements: a seed must never
	# lose its entire connected town merely because its best bounded candidate is
	# a few percentage points shy of an aesthetic target.
	var requirement_failures := SettlementFabricSolver.requirement_failures(
		plan.audit, effective_requirements)
	if not requirement_failures.is_empty():
		failure_reason = "composition requirements not met: %s" % \
			[", ".join(requirement_failures)]
		return null
	return plan


static func _trace_stage(world_seed: int, grammar: WarrenPlotVoidPlan,
		stage: String, started_msec: int) -> void:
	if OS.get_environment("WARREN_STAGE_TIMING") != "1":
		return
	print("[warren-stage] seed=%d grammar=%s stage=%s elapsed_ms=%d" % [
		world_seed, grammar.geometry_signature().sha256_text().left(10), stage,
		Time.get_ticks_msec() - started_msec])


static func _empty_embedding(plan: SettlementFabricPlan) \
		-> StaggeredFabricEmbeddingPlan:
	if plan == null or plan.solid_void_plan == null:
		return null
	var solid_void := plan.solid_void_plan
	var result := StaggeredFabricEmbeddingPlan.new(&"warren.plot-void.optional")
	var covered: Dictionary = {}
	var initial_bounded := solid_void.boundary_obligations.size() \
		- solid_void.unbounded_obligations.size()
	return result if result.seal([], covered,
		solid_void.unbounded_obligations.size(), initial_bounded,
		solid_void.boundary_obligations.size()) else null


func _compile_route(program: SettlementFabricProgram,
		grammar: WarrenPlotVoidPlan, specs: Array[Dictionary], by_id: Dictionary,
		itinerary: Array[StringName]) -> bool:
	for index in grammar.route_steps.size():
		var step := grammar.route_steps[index]
		var stable_id := StringName(step.stable_id)
		if index == 0:
			WarrenRisingRingPlanner._put(specs, by_id,
				SettlementFabricSolver.unit_spec(stable_id,
					StringName(step.recipe_id), step.origin as Vector3i,
					int(step.yaw_quarters)))
		elif step.has("origin"):
			var parents: Array[StringName] = []
			for parent_value: Variant in step.get("parents", []):
				parents.append(StringName(parent_value))
			var bonds: Array[Dictionary] = []
			for bond: Dictionary in step.get("bonds", []):
				bonds.append(bond.duplicate())
			WarrenRisingRingPlanner._put(specs, by_id,
				SettlementFabricSolver.unit_spec(stable_id,
					StringName(step.recipe_id), step.origin as Vector3i,
					int(step.yaw_quarters), parents, bonds))
		else:
			var parent_id := StringName(step.parent_id)
			if not by_id.has(parent_id) \
					or program.recipe(StringName(step.recipe_id)) == null:
				failure_reason = "plot/void route references a missing recipe or parent"
				return false
			WarrenRisingRingPlanner._chain(program, specs, by_id, itinerary,
				stable_id, StringName(step.recipe_id), parent_id,
				StringName(step.own_socket), StringName(step.parent_socket),
				int(step.yaw_quarters), bool(step.get("bearing_parent", false)))
			# _chain appends the itinerary entry itself.
			continue
		if bool(step.get("primary", true)):
			itinerary.append(stable_id)
	return true


static func _market_zone_cells(grammar: WarrenPlotVoidPlan,
		plan: SettlementFabricPlan) -> Dictionary:
	var market_ids: Dictionary = {}
	for node_id: StringName in grammar.market_node_ids:
		market_ids[node_id] = true
	var out: Dictionary = {}
	for unit_value: FabricUnit in plan.units:
		if not market_ids.has(unit_value.stable_id):
			continue
		var recipe_value := plan.recipe(unit_value.recipe_id)
		for local_cell: Vector3i in recipe_value.walk_cells:
			out[FabricRecipe.transform_cell(local_cell,
				unit_value.lattice_origin, unit_value.yaw_quarters)] = true
	return out


static func _terminal_zone_cells(grammar: WarrenPlotVoidPlan,
		plan: SettlementFabricPlan) -> Dictionary:
	## The public climb may terminate only at an inhabited threshold. Feeding this
	## exact final surface into the beam preserves at least one doorway candidate;
	## the common continuity audit remains the hard authority after compilation.
	var out: Dictionary = {}
	if grammar.route_steps.is_empty():
		return out
	var terminal_id := StringName(grammar.route_steps.back().stable_id)
	var terminal_unit := plan.unit(terminal_id)
	if terminal_unit == null:
		return out
	var recipe_value := plan.recipe(terminal_unit.recipe_id)
	for local_cell: Vector3i in recipe_value.walk_cells:
		out[FabricRecipe.transform_cell(local_cell,
			terminal_unit.lattice_origin, terminal_unit.yaw_quarters)] = true
	return out
