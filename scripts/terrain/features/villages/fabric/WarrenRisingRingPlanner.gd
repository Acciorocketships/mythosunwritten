class_name WarrenRisingRingPlanner
extends RefCounted

## Deterministic orthogonal rising-ring planner. The route is authored as a
## compact grammar motif, while buildings are solved from the resulting
## solid/void obligations. The fixed visual proof and eventual production
## village projection intentionally call this same entry point.

var failure_reason := ""
const EXACT_SELECTION_LIMIT := 2


func solve(program: SettlementFabricProgram, world_seed: int = 0,
		requirements: Dictionary = {}) -> SettlementFabricPlan:
	var timing_started := Time.get_ticks_msec()
	var timing_previous := timing_started
	failure_reason = ""
	if program == null:
		failure_reason = "missing fabric program"
		return null
	var specs: Array[Dictionary] = []
	var by_id: Dictionary = {}
	var itinerary: Array[StringName] = []
	_build_route(program, specs, by_id, itinerary)
	if OS.get_environment("WARREN_ROUTE_DEBUG") == "1":
		for route_id: StringName in itinerary:
			var route_spec := by_id[route_id] as Dictionary
			print("[warren-route] %s %s r%d" % [route_id,
				route_spec.origin, int(route_spec.yaw_quarters)])
	_append_level_changing_loop(specs, by_id)
	if not _append_inhabited_core(program, specs, by_id):
		failure_reason = "could not compile the inhabited climbing core"
		return null
	if not _append_top_court(program, specs, by_id, itinerary, world_seed):
		failure_reason = "could not support the top court"
		return null
	var cover_overrides := {
		&"ring.lower.turn.east": PublicRealmNode.CoverPolicy.COVERED,
	}
	var episode_overrides := {
		&"ring.lower.turn.east": PublicRealmNode.EpisodeKind.UNDERCROFT,
	}
	var realm := SectionalPublicRealmBuilder.from_specs(
		&"warren.rising-ring.seed-realm", program, specs, itinerary,
		episode_overrides, cover_overrides)
	if realm == null:
		failure_reason = SectionalPublicRealmBuilder.last_failure
		return null
	var solver := SettlementFabricSolver.new(program)
	var seed_plan := solver.solve_sectional(&"warren.rising-ring.seed", realm,
		SectionalPublicRealmBuilder.bind_specs(specs, program))
	if seed_plan == null:
		failure_reason = solver.failure_reason
		return null
	# Complete source-pack houses are substantially larger than one modular plot.
	# Reserving the first merely legal one here produced a detached landmark and
	# forced the compact infill to grow around it. They are admitted only after the
	# coupled street/building solve, where failing to fit is preferable to breaking
	# the town's mass. The upcoming plot grammar will treat them as multi-plot
	# alternatives inside that same coupled decision rather than pre-anchors.
	timing_previous = _trace_timing(&"seed", timing_previous)
	# Solve the inhabited street/plot fabric before optional source-pack accents.
	# A large prefab may consume several frontage plots; admitting it first let an
	# optional accent erase the ground market and forced the search to rebuild the
	# whole town for every anchor candidate.  Prefabs now join the accepted fabric
	# through the same transaction later, but they never own its composition.
	var global_frontier := StaggeredFabricEmbedder.solve_frontier(
		&"warren.rising-ring.embedding", seed_plan.solid_void_plan,
		seed_plan.public_realm.air_claims(),
		_occupied_or_occluding_cells(seed_plan),
		seed_plan.transformed_cells(&"inhabited"), 24, 28, program,
		seed_plan.transformed_visual_clearance_bounds(), true, 8,
		&"global_set", world_seed, _market_zone_cells(seed_plan), {}, 2, 2)
	timing_previous = _trace_timing(&"embedding-global", timing_previous)
	# The global library is the canonical frontier.  The older obligation-order
	# search repeatedly recompiles complete candidate geometry at every beam step
	# and differs only by an incidental traversal order; keeping it as a second
	# production search added roughly 100 seconds without adding a distinct
	# construction rule.  Composition diversity belongs in the ranked global
	# frontier and, later, its seed-stable tie breaks.
	var local_frontier: Array[StaggeredFabricEmbeddingPlan] = []
	# Local frontage order tends to preserve the narrow opposing gaps that
	# become inhabited tunnels; global set packing remains the deterministic
	# fallback when a terrain/seed variation invalidates those compositions.
	var embeddings: Array[StaggeredFabricEmbeddingPlan] = []
	embeddings.assign(local_frontier)
	var embedding_signatures: Dictionary = {}
	for candidate: StaggeredFabricEmbeddingPlan in embeddings:
		embedding_signatures[candidate.deterministic_signature()] = true
	for candidate: StaggeredFabricEmbeddingPlan in global_frontier:
		var signature := candidate.deterministic_signature()
		if not embedding_signatures.has(signature):
			embedding_signatures[signature] = true
			embeddings.append(candidate)
	var selection := _select_embedding_frontier(program, solver, embeddings,
		specs, by_id, itinerary, episode_overrides, cover_overrides,
		world_seed)
	timing_previous = _trace_timing(&"embedding-transaction", timing_previous)
	if selection.is_empty():
		failure_reason = "no solid/void embedding survived the complete transaction"
		return null
	var selected_specs: Array[Dictionary] = []
	selected_specs.assign(selection.specs as Array)
	specs = selected_specs
	by_id = selection.by_id as Dictionary
	realm = selection.realm as SectionalPublicRealmPlan
	var embedding := selection.embedding as StaggeredFabricEmbeddingPlan
	var plan := selection.plan as SettlementFabricPlan
	# Source prefabs remain compiled and measured, but are not appended as a
	# post-solve accent. The screenshot review proved that the only surviving
	# placement was an isolated building outside the maze. Multi-plot prefabs will
	# re-enter through the coupled plot grammar, where their occupied footprint
	# can replace modular plots instead of enlarging a completed town.
	timing_previous = _trace_timing(&"prefabs", timing_previous)
	plan = _append_overhead_transactionally(program, solver, realm, plan,
		embedding, specs, by_id, world_seed)
	timing_previous = _trace_timing(&"overhead", timing_previous)
	plan = solver.solve_sectional(&"warren.rising-ring", realm,
		SectionalPublicRealmBuilder.bind_specs(specs, program), requirements,
		embedding)
	if plan == null:
		failure_reason = solver.failure_reason
	_trace_timing(&"final-total-%d" % (Time.get_ticks_msec() - timing_started),
		timing_previous)
	return plan


static func _trace_timing(stage: StringName, previous_msec: int) -> int:
	var now := Time.get_ticks_msec()
	if OS.get_environment("WARREN_TIMING_DEBUG") == "1":
		print("[warren-timing] %s %dms" % [stage, now - previous_msec])
	return now


static func _append_inhabited_core(program: SettlementFabricProgram,
		specs: Array[Dictionary], by_id: Dictionary) -> bool:
	## The middle route is an orthogonal rising ring around this narrow occupied
	## mass. A square party-wall tower closes the inside of the switchback without
	## forcing the public itinerary to detour around a 6 x 6 m square footprint.
	## Its base is one half-band above the lowest market datum, so its second
	## furnished storey is addressed directly by the y=3 gallery.  The route
	## therefore turns because a building is present; it is not a loop around an
	## empty lawn that later hopes an infill search will find the slot.
	return StaggeredFabricCompiler.append_proposals(program, [{
		"stable_id": &"inhabited.climbing-core",
		"kind": &"tower",
		"origin": Vector3i(9, 1, -8),
		"storeys": 4,
		"yaw_quarters": 1,
		"route_y": 3,
		"support_mode": &"terrain_perch",
		"occupied_cells": [],
	}], specs, by_id)


static func _select_embedding_frontier(program: SettlementFabricProgram,
		solver: SettlementFabricSolver,
		embeddings: Array[StaggeredFabricEmbeddingPlan],
		base_specs: Array[Dictionary], base_by_id: Dictionary,
		itinerary: Array[StringName], episode_overrides: Dictionary,
		cover_overrides: Dictionary, world_seed: int,
		require_skywalk: bool = false) -> Dictionary:
	## Ranking heuristics propose complete massings; the actual fabric transaction
	## chooses among that bounded frontier. This keeps skywalk geometry, visual
	## envelopes, public air, and support under one authority instead of mirroring
	## their rules in a second approximate scorer.
	var candidates: Array[Dictionary] = []
	for embedding: StaggeredFabricEmbeddingPlan in embeddings:
		# This hint is computed from all storey facades during the resource-free
		# beam. A zero cannot be rescued by the exact compiler, so do not spend
		# seconds building a transaction whose required skywalk has no endpoints.
		if require_skywalk and embedding.potential_skywalk_pair_count <= 0:
			continue
		var trial_specs: Array[Dictionary] = []
		trial_specs.assign(base_specs)
		var trial_by_id := base_by_id.duplicate()
		if not StaggeredFabricCompiler.append_specs(program, embedding,
				trial_specs, trial_by_id):
			continue
		var trial_realm := SectionalPublicRealmBuilder.from_specs(
			&"warren.rising-ring.frontier-realm", program, trial_specs,
			itinerary, episode_overrides, cover_overrides)
		if trial_realm == null:
			continue
		var trial_plan := solver.solve_sectional(
			&"warren.rising-ring.frontier", trial_realm,
			SectionalPublicRealmBuilder.bind_specs(trial_specs, program), {},
			embedding)
		if trial_plan == null:
			if OS.get_environment("WARREN_EMBED_DEBUG") == "1":
				print("[warren-embedding-transaction] %s: %s" % [
					embedding.deterministic_signature(), solver.failure_reason])
			continue
		var result := {
			"embedding": embedding,
			"specs": trial_specs,
			"by_id": trial_by_id,
			"realm": trial_realm,
			"plan": trial_plan,
		}
		var has_skywalk := _has_viable_skywalk(program, solver,
			trial_realm, trial_plan, embedding, trial_specs, world_seed)
		if require_skywalk and not has_skywalk:
			continue
		result["has_skywalk"] = has_skywalk
		candidates.append(result)
		# The embedding frontier is already ordered by its deterministic beam score,
		# including disjoint facade-pair potential. Exact transactions are expensive,
		# so compare a small bounded set of complete survivors instead of rebuilding
		# every near-duplicate massing. This remains output-deterministic and every
		# returned candidate has still passed the full geometry/support transaction.
		if candidates.size() >= EXACT_SELECTION_LIMIT:
			break
	if candidates.is_empty():
		return {}
	# Beam score is useful during partial construction, but once complete exact
	# massings exist the town-facing metrics are the better ordering. This keeps a
	# single coarse maze from being discarded merely because its first legal
	# massing is open while a later one encloses the same route well.
	candidates.sort_custom(_frontier_result_better)
	if require_skywalk:
		return candidates[0]
	for result: Dictionary in candidates:
		if bool(result.get("has_skywalk", false)):
			return result
	return candidates[0]


static func _frontier_result_better(a: Dictionary, b: Dictionary) -> bool:
	var a_audit := (a.plan as SettlementFabricPlan).audit
	var b_audit := (b.plan as SettlementFabricPlan).audit
	for metric: StringName in [&"frontage_ratio", &"solid_void_frontage_ratio"]:
		var a_value := float(a_audit.get(metric, 0.0))
		var b_value := float(b_audit.get(metric, 0.0))
		if not is_equal_approx(a_value, b_value):
			return a_value > b_value
	var a_sightlines := int(a_audit.get("through_sightline_count", 2147483647))
	var b_sightlines := int(b_audit.get("through_sightline_count", 2147483647))
	if a_sightlines != b_sightlines:
		return a_sightlines < b_sightlines
	var a_span := maxi(int(a_audit.get("solid_void_core_width_cells", 2147483647)),
		int(a_audit.get("solid_void_core_depth_cells", 2147483647)))
	var b_span := maxi(int(b_audit.get("solid_void_core_width_cells", 2147483647)),
		int(b_audit.get("solid_void_core_depth_cells", 2147483647)))
	if a_span != b_span:
		return a_span < b_span
	var a_buildings := int(a_audit.get("building_stack_count", 0))
	var b_buildings := int(b_audit.get("building_stack_count", 0))
	if a_buildings != b_buildings:
		return a_buildings > b_buildings
	return (a.embedding as StaggeredFabricEmbeddingPlan).deterministic_signature() \
		< (b.embedding as StaggeredFabricEmbeddingPlan).deterministic_signature()


static func _has_viable_skywalk(program: SettlementFabricProgram,
		solver: SettlementFabricSolver, realm: SectionalPublicRealmPlan,
		plan: SettlementFabricPlan, embedding: StaggeredFabricEmbeddingPlan,
		specs: Array[Dictionary], world_seed: int) -> bool:
	for first: Dictionary in WarrenOverheadSolver.candidate_specs(program,
			plan, world_seed):
		if StringName(first.category) != &"skywalk":
			continue
		var first_trial := _trial_overhead_candidates(program, solver, realm,
			embedding, specs, [first])
		if first_trial != null:
			return true
	return false


static func _append_prefabs_transactionally(program: SettlementFabricProgram,
		solver: SettlementFabricSolver, realm: SectionalPublicRealmPlan,
		base_plan: SettlementFabricPlan, embedding: StaggeredFabricEmbeddingPlan,
		specs: Array[Dictionary], by_id: Dictionary,
		world_seed: int) -> SettlementFabricPlan:
	var plan := base_plan
	var families := _prefab_families(plan)
	var accepted := _prefab_recipe_ids(plan).size()
	var deferred: Array[Dictionary] = []
	for candidate: Dictionary in WarrenPrefabSolver.candidate_specs(program,
			plan, world_seed):
		if families.has(StringName(candidate.source_family)):
			deferred.append(candidate)
			continue
		var trial := _try_prefab_candidate(program, solver, realm, embedding,
			specs, by_id, candidate)
		if trial == null:
			continue
		plan = trial
		families[StringName(candidate.source_family)] = true
		accepted += 1
		if accepted >= 3:
			return plan
	for candidate: Dictionary in deferred:
		if accepted >= 3:
			break
		var trial := _try_prefab_candidate(program, solver, realm, embedding,
			specs, by_id, candidate)
		if trial != null:
			plan = trial
			accepted += 1
	return plan


static func _append_ground_prefab_anchors(program: SettlementFabricProgram,
		solver: SettlementFabricSolver, realm: SectionalPublicRealmPlan,
		base_plan: SettlementFabricPlan, specs: Array[Dictionary],
		by_id: Dictionary, world_seed: int,
		protected_market_landings: Dictionary,
		max_anchors: int = 2) -> SettlementFabricPlan:
	## This is a bounded coupled ground-plot phase. Every admitted anchor passes
	## the complete fabric transaction immediately; the next candidate frontier
	## is then derived from that sealed result. No approximate prefab rectangle is
	## allowed to reserve space on behalf of geometry which later fails.
	var plan := base_plan
	var families := _prefab_families(plan)
	var accepted_recipes := _prefab_recipe_ids(plan)
	while accepted_recipes.size() < maxi(0, max_anchors):
		var accepted_one := false
		# Prefer a new source pack, then fall back to a distinct authored house
		# from an already-used pack. Asset diversity is a hard construction fact;
		# pack diversity remains an optimization when the compact plot cannot fit a
		# substantially larger source family.
		for require_new_family in [true, false]:
			for candidate: Dictionary in WarrenPrefabSolver.candidate_specs(program,
					plan, world_seed):
				var family := StringName(candidate.source_family)
				var recipe_id := StringName(candidate.recipe_id)
				if accepted_recipes.has(recipe_id) \
						or require_new_family == families.has(family) \
						or protected_market_landings.has(
							candidate.landing_cell as Vector3i):
					continue
				var spec := candidate.spec as Dictionary
				var stable_id := StringName(spec.stable_id)
				if by_id.has(stable_id):
					continue
				specs.append(spec)
				by_id[stable_id] = spec
				var trial := solver.solve_sectional(
					&"warren.rising-ring.ground-anchor-trial", realm,
					SectionalPublicRealmBuilder.bind_specs(specs, program))
				if trial == null:
					by_id.erase(stable_id)
					specs.pop_back()
					continue
				plan = trial
				families[family] = true
				accepted_recipes[recipe_id] = true
				accepted_one = true
				break
			if accepted_one:
				break
		if not accepted_one:
			break
	return plan


static func _prefab_families(plan: SettlementFabricPlan) -> Dictionary:
	var out: Dictionary = {}
	if plan == null:
		return out
	for unit_value: FabricUnit in plan.units:
		var recipe_value := plan.recipe(unit_value.recipe_id)
		if recipe_value == null or not recipe_value.has_tag(&"prefab_anchor"):
			continue
		for asset_id: StringName in recipe_value.asset_ids():
			out[StringName(String(asset_id).get_slice(".", 0))] = true
			break
	return out


static func _prefab_recipe_ids(plan: SettlementFabricPlan) -> Dictionary:
	var out: Dictionary = {}
	if plan == null:
		return out
	for unit_value: FabricUnit in plan.units:
		var recipe_value := plan.recipe(unit_value.recipe_id)
		if recipe_value != null and recipe_value.has_tag(&"prefab_anchor"):
			out[unit_value.recipe_id] = true
	return out


static func _try_prefab_candidate(program: SettlementFabricProgram,
		solver: SettlementFabricSolver,
		realm: SectionalPublicRealmPlan, embedding: StaggeredFabricEmbeddingPlan,
		specs: Array[Dictionary], by_id: Dictionary,
		candidate: Dictionary) -> SettlementFabricPlan:
	var spec := candidate.spec as Dictionary
	var stable_id := StringName(spec.stable_id)
	if by_id.has(stable_id):
		return null
	specs.append(spec)
	by_id[stable_id] = spec
	var trial := solver.solve_sectional(&"warren.rising-ring.prefab-trial",
		realm, SectionalPublicRealmBuilder.bind_specs(specs,
			program), {}, embedding)
	if trial == null:
		by_id.erase(stable_id)
		specs.pop_back()
	return trial


static func _append_overhead_transactionally(program: SettlementFabricProgram,
		solver: SettlementFabricSolver, realm: SectionalPublicRealmPlan,
		base_plan: SettlementFabricPlan, embedding: StaggeredFabricEmbeddingPlan,
		specs: Array[Dictionary], by_id: Dictionary,
		world_seed: int) -> SettlementFabricPlan:
	# Overhead endpoints are derived only from the already sealed inhabited
	# stacks; accepting a bridge or projection never creates another source.
	# Pack the independent candidates against the frozen occupancy/envelopes,
	# then admit the whole set in one exact transaction. The former loop rebuilt
	# every public surface and exterior-air proof after each of up to six pieces.
	var candidates := WarrenOverheadSolver.candidate_specs(program, base_plan,
		world_seed)
	var packed: Array[Dictionary] = []
	var packed_ids: Dictionary = {}
	var counts := {&"skywalk": 0, &"outcrop": 0}
	for phase: StringName in [&"skywalk", &"outcrop"]:
		var limit := 2 if phase == &"skywalk" else 4
		for candidate: Dictionary in candidates:
			if StringName(candidate.category) != phase \
					or packed_ids.has(StringName(candidate.stable_id)) \
					or int(counts[phase]) >= limit:
				continue
			var trial_set: Array[Dictionary] = []
			trial_set.assign(packed)
			trial_set.append(candidate)
			if not WarrenOverheadSolver.candidate_set_passes(program,
					base_plan, trial_set):
				continue
			packed = trial_set
			packed_ids[StringName(candidate.stable_id)] = true
			counts[phase] = int(counts[phase]) + 1
	if int(counts[&"skywalk"]) >= 1 and int(counts[&"outcrop"]) >= 1:
		var packed_trial := _trial_overhead_candidates(program, solver, realm,
			embedding, specs, packed)
		if packed_trial != null:
			for candidate: Dictionary in packed:
				_commit_overhead_candidate(candidate, specs, by_id)
			if OS.get_environment("WARREN_OVERHEAD_DEBUG") == "1":
				print("[warren-overhead-debug] accepted atomic set skywalk=%d outcrop=%d" \
					% [int(counts[&"skywalk"]), int(counts[&"outcrop"])])
			return packed_trial
		elif OS.get_environment("WARREN_OVERHEAD_DEBUG") == "1":
			print("[warren-overhead-debug] atomic set rejected: %s" %
				solver.failure_reason)
	# The broad phase mirrors sealed facts but is intentionally not an admission
	# authority. Retain a bounded exact fallback for any future recipe whose
	# semantic socket/volume interaction cannot be predicted by those facts.
	return _append_overhead_sequential(program, solver, realm, base_plan,
		embedding, specs, by_id, world_seed)


static func _append_overhead_sequential(program: SettlementFabricProgram,
		solver: SettlementFabricSolver, realm: SectionalPublicRealmPlan,
		base_plan: SettlementFabricPlan, embedding: StaggeredFabricEmbeddingPlan,
		specs: Array[Dictionary], by_id: Dictionary,
		world_seed: int) -> SettlementFabricPlan:
	var plan := base_plan
	var used_sources: Dictionary = {}
	var accepted_by_phase := {&"outcrop": 0, &"skywalk": 0}
	# The massing frontier deliberately preserves opposing inhabited sockets.
	# Select an exact occupied link before one-ended projections consume its
	# facades. The helper retains a sequence API so a future denser vocabulary can
	# request a larger network atomically without reverting to greedy commits.
	# Start with one occupied link, then regenerate the candidate set from the
	# newly sealed town in the loop below.  A depth-two exhaustive lookahead made
	# the common case quadratic in full structural transactions (up to 24 x 24)
	# just to protect an optional second link.  Sequential exact commits preserve
	# every geometry invariant and keep the offline generator bounded.
	var network := _viable_skywalk_sequence(program, solver, realm, plan,
		embedding, specs, world_seed, 1)
	if not network.is_empty():
		var network_trial := _trial_overhead_candidates(program, solver, realm,
			embedding, specs, network)
		if network_trial != null:
			for candidate: Dictionary in network:
				_commit_overhead_candidate(candidate, specs, by_id)
				_mark_candidate_sources(candidate, used_sources)
			plan = network_trial
			accepted_by_phase[&"skywalk"] = network.size()
	# With the best atomic network secured, keep filling it to two links before
	# roofed occupied projections consume compatible facade seams.
	while int(accepted_by_phase[&"skywalk"]) < 2 \
			or int(accepted_by_phase[&"outcrop"]) < 4:
		var accepted_one := false
		var phase_order: Array[StringName] = []
		if int(accepted_by_phase[&"skywalk"]) < 2:
			phase_order.append(&"skywalk")
		if int(accepted_by_phase[&"outcrop"]) < 4:
			# A town with one exact link can still accept occupied projections.
			# Keeping outcrops behind an impossible second bridge made otherwise
			# complete massings fail the unrelated outcrop minimum and forced the
			# outer planner to burn through dozens of coarse mazes.
			phase_order.append(&"outcrop")
		for phase: StringName in phase_order:
			var limit := 4 if phase == &"outcrop" else 2
			if int(accepted_by_phase[phase]) >= limit:
				continue
			# Candidate generation depends on the current sealed plan. Never retain a
			# stale snapshot across an accepted construction transaction.
			for candidate: Dictionary in WarrenOverheadSolver.candidate_specs(program,
					plan, world_seed):
				if StringName(candidate.category) != phase \
						or _candidate_source_conflict(candidate, used_sources):
					continue
				var trial := _trial_overhead_candidates(program, solver, realm,
					embedding, specs, [candidate])
				if trial == null:
					if OS.get_environment("WARREN_OVERHEAD_DEBUG") == "1":
						print("[warren-overhead-debug] rejected %s %s: %s" % [
							phase, candidate.stable_id, solver.failure_reason])
					continue
				_commit_overhead_candidate(candidate, specs, by_id)
				plan = trial
				accepted_by_phase[phase] = int(accepted_by_phase[phase]) + 1
				_mark_candidate_sources(candidate, used_sources)
				accepted_one = true
				if OS.get_environment("WARREN_OVERHEAD_DEBUG") == "1":
					print("[warren-overhead-debug] accepted %s %s" % [
						phase, candidate.stable_id])
				break
			if accepted_one:
				break
		if not accepted_one:
			break
	return plan


static func _viable_skywalk_sequence(program: SettlementFabricProgram,
		solver: SettlementFabricSolver, realm: SectionalPublicRealmPlan,
		plan: SettlementFabricPlan, embedding: StaggeredFabricEmbeddingPlan,
		base_specs: Array[Dictionary], world_seed: int, required_count: int,
		used_ids: Dictionary = {}) -> Array[Dictionary]:
	## Bounded exact lookup for the next occupied link. Callers regenerate the
	## candidates after every accepted transaction, so the ordinary production
	## path uses depth one; the sequence API remains useful for focused offline
	## experiments without duplicating construction rules.
	if required_count <= 0:
		return [] as Array[Dictionary]
	var examined := 0
	for candidate: Dictionary in WarrenOverheadSolver.candidate_specs(program,
			plan, world_seed):
		if StringName(candidate.category) != &"skywalk" \
				or used_ids.has(StringName(candidate.stable_id)):
			continue
		examined += 1
		if examined > 24:
			break
		var trial := _trial_overhead_candidates(program, solver, realm,
			embedding, base_specs, [candidate])
		if trial == null:
			continue
		if required_count == 1:
			return [candidate] as Array[Dictionary]
		var trial_specs: Array[Dictionary] = []
		trial_specs.assign(base_specs)
		for candidate_spec: Dictionary in candidate.specs as Array:
			trial_specs.append(candidate_spec)
		var next_used := used_ids.duplicate()
		next_used[StringName(candidate.stable_id)] = true
		var rest := _viable_skywalk_sequence(program, solver, realm, trial,
			embedding, trial_specs, world_seed, required_count - 1, next_used)
		if rest.size() == required_count - 1:
			var result: Array[Dictionary] = [candidate]
			result.append_array(rest)
			return result
	return [] as Array[Dictionary]


static func _trial_overhead_candidates(program: SettlementFabricProgram,
		solver: SettlementFabricSolver, realm: SectionalPublicRealmPlan,
		embedding: StaggeredFabricEmbeddingPlan, base_specs: Array[Dictionary],
		candidates: Array) -> SettlementFabricPlan:
	var trial_specs: Array[Dictionary] = []
	trial_specs.assign(base_specs)
	for candidate: Dictionary in candidates:
		for spec: Dictionary in candidate.specs as Array:
			trial_specs.append(spec)
	return solver.solve_sectional(&"warren.rising-ring.overhead-trial", realm,
		SectionalPublicRealmBuilder.bind_specs(trial_specs, program), {}, embedding)


static func _commit_overhead_candidate(candidate: Dictionary,
		specs: Array[Dictionary], by_id: Dictionary) -> void:
	for spec: Dictionary in candidate.specs as Array:
		var stable_id := StringName(spec.stable_id)
		assert(not by_id.has(stable_id))
		specs.append(spec)
		by_id[stable_id] = spec


static func _candidate_source_conflict(candidate: Dictionary,
		used_sources: Dictionary) -> bool:
	var phase := StringName(candidate.category)
	# A real circulation network may branch at one building, and a Weasley-like
	# stack may project from several distinct facades. Source ownership therefore
	# cannot be a one-use token. Reject only the exact semantic construction;
	# occupied cells, facade sockets, and visual envelopes remain the common
	# authority for whether two candidates can coexist.
	return used_sources.has("%s/candidate/%s" % [phase, candidate.stable_id])


static func _mark_candidate_sources(candidate: Dictionary,
		used_sources: Dictionary) -> void:
	var phase := StringName(candidate.category)
	used_sources["%s/candidate/%s" % [phase, candidate.stable_id]] = true


static func _build_route(program: SettlementFabricProgram,
		specs: Array[Dictionary], by_id: Dictionary,
		itinerary: Array[StringName]) -> void:
	_put(specs, by_id, SettlementFabricSolver.unit_spec(
		&"ring.landing", &"route.landing", Vector3i(-4, 0, 2)))
	itinerary.append(&"ring.landing")
	# The market is a real ground-level alley before the sectional climb. It
	# accumulates four orthogonal turns around occupied frontage, so stalls can
	# line multiple short approaches instead of being scattered beside one flat
	# token street. Later levels fold back above this prelude.
	_chain(program, specs, by_id, itinerary, &"market.east", &"route.straight",
		&"ring.landing", &"walk.west", &"walk.east", 0)
	_chain(program, specs, by_id, itinerary, &"market.turn.north", &"route.corner",
		&"market.east", &"walk.west", &"walk.east", 0)
	_chain(program, specs, by_id, itinerary, &"market.north", &"route.straight",
		&"market.turn.north", &"walk.south", &"walk.north", 0)
	_chain(program, specs, by_id, itinerary, &"market.turn.east", &"route.corner",
		&"market.north", &"walk.south", &"walk.north", 0)
	_chain(program, specs, by_id, itinerary, &"ring.entry", &"route.corner",
		&"market.turn.east", &"walk.west", &"walk.east", 0)
	_chain(program, specs, by_id, itinerary, &"ring.east", &"route.straight",
		&"ring.entry", &"walk.west", &"walk.east", 0)
	_chain(program, specs, by_id, itinerary, &"ring.turn.north", &"route.corner",
		&"ring.east", &"walk.west", &"walk.east", 0)
	_chain(program, specs, by_id, itinerary, &"ring.rise.half", &"stair.half",
		&"ring.turn.north", &"walk.low", &"walk.north", 0, true)
	_chain(program, specs, by_id, itinerary, &"ring.upper.turn.west", &"deck.corner",
		&"ring.rise.half", &"walk.south", &"walk.high", 0)
	_chain(program, specs, by_id, itinerary, &"ring.upper.west", &"deck.straight",
		&"ring.upper.turn.west", &"walk.east", &"walk.west", 0)
	_chain(program, specs, by_id, itinerary, &"ring.upper.turn.north", &"deck.corner",
		&"ring.upper.west", &"walk.east", &"walk.west", 0)
	_chain(program, specs, by_id, itinerary, &"ring.drop.half", &"stair.half",
		&"ring.upper.turn.north", &"walk.high", &"walk.north", 2, true)
	_chain(program, specs, by_id, itinerary, &"ring.lower.turn.east", &"route.corner",
		&"ring.drop.half", &"walk.south", &"walk.low", 0)
	_chain(program, specs, by_id, itinerary, &"ring.rise.full", &"stair.full",
		&"ring.lower.turn.east", &"walk.low", &"walk.east", 3, true)
	_chain(program, specs, by_id, itinerary, &"ring.middle.rise.half", &"stair.half",
		&"ring.rise.full", &"walk.low", &"walk.high", 3, true)
	_chain(program, specs, by_id, itinerary, &"ring.middle.east.approach", &"deck.straight",
		&"ring.middle.rise.half", &"walk.west", &"walk.high", 0)
	_chain(program, specs, by_id, itinerary, &"ring.middle.turn.south", &"deck.corner",
		&"ring.middle.east.approach", &"walk.west", &"walk.east", 0)
	_chain(program, specs, by_id, itinerary, &"ring.middle.south", &"deck.straight",
		&"ring.middle.turn.south", &"walk.east", &"walk.south", 1)
	_chain(program, specs, by_id, itinerary, &"ring.middle.south.2", &"deck.straight",
		&"ring.middle.south", &"walk.east", &"walk.west", 1)
	_chain(program, specs, by_id, itinerary, &"ring.middle.turn.west", &"deck.corner",
		&"ring.middle.south.2", &"walk.north", &"walk.west", 0)
	_chain(program, specs, by_id, itinerary, &"ring.middle.west", &"deck.straight",
		&"ring.middle.turn.west", &"walk.east", &"walk.west", 0)
	_chain(program, specs, by_id, itinerary, &"ring.middle.west.2", &"deck.straight",
		&"ring.middle.west", &"walk.east", &"walk.west", 0)
	_chain(program, specs, by_id, itinerary, &"ring.middle.west.3", &"deck.straight",
		&"ring.middle.west.2", &"walk.east", &"walk.west", 0)
	_chain(program, specs, by_id, itinerary, &"ring.drop.middle", &"stair.half",
		&"ring.middle.west.3", &"walk.high", &"walk.west", 3, true)
	_chain(program, specs, by_id, itinerary, &"ring.return.turn.south", &"deck.corner",
		&"ring.drop.middle", &"walk.east", &"walk.low", 0)
	_chain(program, specs, by_id, itinerary, &"ring.return.south", &"deck.straight",
		&"ring.return.turn.south", &"walk.east", &"walk.south", 1)
	_chain(program, specs, by_id, itinerary, &"ring.return.turn.west", &"deck.corner",
		&"ring.return.south", &"walk.north", &"walk.west", 0)
	_chain(program, specs, by_id, itinerary, &"ring.final.rise", &"stair.full",
		&"ring.return.turn.west", &"walk.low", &"walk.east", 3, true)
	_chain(program, specs, by_id, itinerary, &"ring.high.arrival", &"deck.corner",
		&"ring.final.rise", &"walk.west", &"walk.high", 0)
	_chain(program, specs, by_id, itinerary, &"ring.top.rise", &"stair.full",
		&"ring.high.arrival", &"walk.low", &"walk.north", 0, true)
	_chain(program, specs, by_id, itinerary, &"ring.top.arrival", &"deck.corner",
		&"ring.top.rise", &"walk.south", &"walk.high", 0)
	_chain(program, specs, by_id, itinerary, &"ring.top.north", &"deck.straight",
		&"ring.top.arrival", &"walk.south", &"walk.north", 0)
	_chain(program, specs, by_id, itinerary, &"ring.top.north.2", &"deck.straight",
		&"ring.top.north", &"walk.south", &"walk.north", 0)
	_chain(program, specs, by_id, itinerary, &"ring.top.turn.east", &"deck.corner",
		&"ring.top.north.2", &"walk.south", &"walk.north", 0)
	_chain(program, specs, by_id, itinerary, &"ring.top.east", &"deck.straight",
		&"ring.top.turn.east", &"walk.west", &"walk.east", 0)
	_chain(program, specs, by_id, itinerary, &"ring.top.east.2", &"deck.straight",
		&"ring.top.east", &"walk.west", &"walk.east", 0)


static func _append_top_court(program: SettlementFabricProgram,
		specs: Array[Dictionary], by_id: Dictionary,
		itinerary: Array[StringName], world_seed: int) -> bool:
	var recipe_value := program.recipe(&"court.supported.6x6")
	var court_yaw := 0
	var court_origin := _attached_origin(program, recipe_value, &"walk.west",
		court_yaw, by_id[&"ring.top.east.2"] as Dictionary, &"walk.east")
	var support_ids: Array[StringName] = []
	for support: Dictionary in [
		{"suffix": &"north", "socket": &"bearing.bottom.north"},
		{"suffix": &"south", "socket": &"bearing.bottom.south"},
	]:
		var socket := recipe_value.socket(StringName(support.socket))
		var world_cell := FabricRecipe.transform_cell(socket.cell, court_origin,
			court_yaw)
		var top_id := _add_pier_support_stack(program, specs, by_id,
			StringName("ring.court.support.%s" % support.suffix), world_cell,
			posmod(world_seed + support_ids.size(), 2) == 0)
		if top_id.is_empty():
			return false
		support_ids.append(top_id)
	_put(specs, by_id, SettlementFabricSolver.unit_spec(&"ring.top.court",
		&"court.supported.6x6", court_origin, court_yaw, support_ids, [
			FabricUnit.bond(&"walk.west", &"ring.top.east.2", &"walk.east"),
			FabricUnit.bond(&"bearing.bottom.north", support_ids[0], &"bearing.top"),
			FabricUnit.bond(&"bearing.bottom.south", support_ids[1], &"bearing.top"),
		]))
	itinerary.append(&"ring.top.court")
	return true


static func _append_level_changing_loop(specs: Array[Dictionary],
		by_id: Dictionary) -> void:
	## This half stair occupies the exact unused slot between the entrance arm
	## and the gallery one half-level above it. Both endpoint bonds are physical;
	## because the stair is not in the primary itinerary it proves a genuine
	## alternate level-changing cycle.
	var loop_id := &"ring.loop.stair"
	var parents: Array[StringName] = [&"ring.east"]
	_put(specs, by_id, SettlementFabricSolver.unit_spec(loop_id, &"stair.half",
		Vector3i(4, 0, -4), 0, parents, [
			FabricUnit.bond(&"walk.low", &"ring.east", &"walk.north"),
			FabricUnit.bond(&"bearing.low", &"ring.east", &"bearing.north"),
			FabricUnit.bond(&"walk.high", &"ring.upper.west", &"walk.south"),
		]))


static func _add_pier_support_stack(program: SettlementFabricProgram,
		specs: Array[Dictionary], by_id: Dictionary, prefix: StringName,
		world_bearing_cell: Vector3i, orange: bool) -> StringName:
	var top_origin := world_bearing_cell - Vector3i(0, 2, 0)
	var base_origin := top_origin - Vector3i(0, 2, 0)
	var base_id := StringName("%s.base" % prefix)
	var top_id := StringName("%s.upper" % prefix)
	var base_seams: Array[StringName] = []
	var top_seams: Array[StringName] = []
	if String(prefix).ends_with("south"):
		base_seams.append(&"ring.court.support.north.base")
		top_seams.append(&"ring.court.support.north.upper")
	_put(specs, by_id, SettlementFabricSolver.unit_spec(base_id,
		&"room.pier.base.rock", base_origin, 0, [], [], &"", base_seams,
		false))
	_put(specs, by_id, SettlementFabricSolver.unit_spec(top_id,
		&"room.pier.upper.orange" if orange else &"room.pier.upper.blue",
		top_origin, 0, [base_id], [
			FabricUnit.bond(&"bearing.bottom", base_id, &"bearing.top"),
		], &"", top_seams))
	return top_id


static func _chain(program: SettlementFabricProgram,
		specs: Array[Dictionary], by_id: Dictionary,
		itinerary: Array[StringName], stable_id: StringName,
		recipe_id: StringName, parent_id: StringName,
		own_socket_id: StringName, parent_socket_id: StringName,
		yaw: int, bearing_parent: bool = false) -> void:
	var child_recipe := program.recipe(recipe_id)
	var parent_spec := by_id[parent_id] as Dictionary
	var origin := _attached_origin(program, child_recipe, own_socket_id, yaw,
		parent_spec, parent_socket_id)
	var parents: Array[StringName] = []
	if bearing_parent:
		parents.append(parent_id)
	var bonds: Array[Dictionary] = [
		FabricUnit.bond(own_socket_id, parent_id, parent_socket_id),
	]
	if bearing_parent:
		var bearing_socket := &"bearing.low" if own_socket_id == &"walk.low" \
			else &"bearing.high"
		var target_bearing := StringName("bearing.%s" % String(parent_socket_id).trim_prefix("walk."))
		bonds.append(FabricUnit.bond(bearing_socket, parent_id, target_bearing))
	_put(specs, by_id, SettlementFabricSolver.unit_spec(stable_id, recipe_id,
		origin, yaw, parents, bonds))
	itinerary.append(stable_id)


static func _attached_origin(program: SettlementFabricProgram,
		child_recipe: FabricRecipe, child_socket_id: StringName, child_yaw: int,
		parent_spec: Dictionary, parent_socket_id: StringName) -> Vector3i:
	var parent_recipe := program.recipe(StringName(parent_spec.recipe_id))
	var own_socket := child_recipe.socket(child_socket_id)
	var parent_socket := parent_recipe.socket(parent_socket_id)
	assert(not own_socket.is_empty() and not parent_socket.is_empty())
	var parent_yaw := int(parent_spec.yaw_quarters)
	var parent_cell := FabricRecipe.transform_cell(parent_socket.cell,
		parent_spec.origin as Vector3i, parent_yaw)
	var parent_facing := FabricRecipe.transform_direction(parent_socket.facing,
		parent_yaw)
	assert(FabricRecipe.transform_direction(own_socket.facing, child_yaw) \
		== -parent_facing)
	var rotated_own_cell := FabricRecipe.transform_cell(own_socket.cell,
		Vector3i.ZERO, child_yaw)
	return parent_cell + parent_facing - rotated_own_cell


static func _occupied_or_occluding_cells(plan: SettlementFabricPlan) -> Dictionary:
	# Cell occupancy and exact visual clearance are independent authorities. The
	# embedder receives `transformed_visual_clearance_bounds()` separately; adding
	# its coarse cell raster here inflated eaves and railings into whole forbidden
	# lattice voxels and made a building unable to line a public deck even when
	# the two exact envelopes were disjoint. Keep only semantic mass in this map.
	var out := plan.transformed_cells(&"solid")
	for cell_value: Variant in plan.transformed_cells(&"occluder"):
		out[cell_value as Vector3i] = true
	return out


static func _market_zone_cells(plan: SettlementFabricPlan) -> Dictionary:
	## Markets belong to the deliberately short ground-level prelude. A global
	## `y == 0` test also admitted stalls beside later descents on the far side of
	## the town, reproducing the scattered-prop failure under a different name.
	## The semantic route ids define one contiguous market district; geometry is
	## still derived from their recipe claims rather than hard-coded coordinates.
	var out: Dictionary = {}
	for unit_value: FabricUnit in plan.units:
		var id := String(unit_value.stable_id)
		if not (id == "ring.landing" or id.begins_with("market.")):
			continue
		var recipe_value := plan.recipe(unit_value.recipe_id)
		for local_cell: Vector3i in recipe_value.walk_cells:
			out[FabricRecipe.transform_cell(local_cell,
				unit_value.lattice_origin, unit_value.yaw_quarters)] = true
	return out


static func _put(specs: Array[Dictionary], by_id: Dictionary,
		spec: Dictionary) -> void:
	var stable_id := StringName(spec.stable_id)
	assert(not by_id.has(stable_id))
	specs.append(spec)
	by_id[stable_id] = spec
