extends GutTest

## The mode flag is the migration boundary. route_first must stay exactly the
## pipeline that ships today; mass_first must source its topology frontier from
## excavated massifs and hand it to the same downstream stages rather than a
## parallel set of its own.
##
## Mass-first candidates are held to WarrenPublicRealmCarver's own topology
## gate. That bar is not automatic for excavated geometry -- two of its
## criteria are steered for but never guaranteed by the excavation carver -- so
## these tests prove both that excavated routes can clear it and that it still
## has teeth against them, rather than assuming either.
##
## The frontier stops at WarrenGroundArcadeSolver today (see
## test_mass_first_reports_which_stage_consumed_the_corpus). That is a measured
## structural boundary, not a defect in the wiring: the arcade needs two
## terrain-level route cells at least MIN_BRANCH_SEPARATION_CELLS apart and an
## excavated route touches grade at its portal and its immediate neighbour
## only. Task 5's solid partitioner is where that changes.

const MASS_FIRST_SEED := 1


func after_each() -> void:
	## A leaked flag would silently convert every later suite in the same
	## process to mass-first, so restore it even when an assertion failed.
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_ROUTE_FIRST


func _gated_excavated_volumes(world_seed: int) -> Dictionary:
	## Reproduces exactly what WarrenTownSolver._mass_first_frontier feeds the
	## arcade stage: one massif (deterministic per seed, so built once) bored
	## once per attempt on a perturbed carve seed.
	var massif := WarrenMassifBuilder.build(world_seed)
	assert_not_null(massif, WarrenMassifBuilder.last_failure)
	var passed: Array[WarrenVolumePlan] = []
	var rejected: Array[WarrenVolumePlan] = []
	if massif == null:
		return {"passed": passed, "rejected": rejected}
	for attempt in WarrenTownSolver.MASS_FIRST_EXCAVATION_ATTEMPTS:
		var excavation := WarrenExcavationCarver.carve(world_seed
			+ attempt * WarrenTownSolver.MASS_FIRST_ATTEMPT_STRIDE, massif)
		if excavation == null:
			continue
		var volume := WarrenExcavationVolumeAdapter.to_volume_plan(massif,
			excavation)
		if volume == null:
			continue
		if WarrenPublicRealmCarver.passes_topology_gate(volume):
			passed.append(volume)
		else:
			rejected.append(volume)
	return {"passed": passed, "rejected": rejected}


func test_route_first_default_is_unchanged() -> void:
	assert_eq(WarrenTownSolver.GENERATION_MODE, &"route_first")
	assert_eq(WarrenTownSolver.MODE_ROUTE_FIRST, &"route_first")
	assert_eq(WarrenTownSolver.MODE_MASS_FIRST, &"mass_first")


func test_excavated_topology_clears_the_route_first_quality_bar() -> void:
	## The deliberate decision this task had to make: excavated candidates are
	## held to the same gate route-first candidates pass through, not a private
	## weaker one. This proves excavated routes can clear it at all.
	var probed := _gated_excavated_volumes(MASS_FIRST_SEED)
	var passed: Array[WarrenVolumePlan] = probed.passed
	assert_gt(passed.size(), 0,
		"seed %d must yield gate-passing excavated topology" % MASS_FIRST_SEED)
	for volume: WarrenVolumePlan in passed:
		assert_true(volume.is_sealed(), volume.last_rejection)
		assert_gte(int(volume.audit.walk_cell_count),
			WarrenPublicRealmCarver.MIN_ROUTE_CELLS)
		assert_gte(int(volume.audit.ramp_transition_count), 1)
		assert_gte(float(volume.audit.addressed_walk_ratio), 0.55)
		assert_eq(int(volume.audit.same_datum_route_fold_count), 0)


func test_the_topology_gate_still_rejects_excavated_routes() -> void:
	## ...and that the same gate is not vacuous here. If every excavated route
	## passed it, applying it would be a decision without consequences and the
	## honest implementation would have been to document it as subsumed.
	var probed := _gated_excavated_volumes(MASS_FIRST_SEED)
	var rejected: Array[WarrenVolumePlan] = probed.rejected
	assert_gt(rejected.size(), 0,
		"the gate must reject some excavated routes or it is not a bar")
	for volume: WarrenVolumePlan in rejected:
		# Every rejection must be a real gate criterion, never a seal failure:
		# an unsealed plan can never reach the frontier in the first place.
		assert_true(volume.is_sealed(), volume.last_rejection)
		assert_true(int(volume.audit.ramp_transition_count) < 1 \
			or float(volume.audit.addressed_walk_ratio) < 0.55,
			"rejection is one of the two criteria excavation does not " \
			+ "guarantee (ramps=%d addressed=%.2f)" % [
			int(volume.audit.ramp_transition_count),
			float(volume.audit.addressed_walk_ratio)])


func test_mass_first_reports_which_stage_consumed_the_corpus() -> void:
	## Mass-first mode must fail loudly and specifically, never silently: the
	## frontier reports how many bores carved, adapted, and cleared the gate,
	## and which downstream stage rejected the survivors. This pins the current
	## structural boundary; when Task 5's partitioner moves it, this test is
	## the one that says so.
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_MASS_FIRST
	var towns := WarrenTownSolver.ranked_candidates(MASS_FIRST_SEED, {}, null, 4)
	if not towns.is_empty():
		for town: WarrenTownPlan in towns:
			assert_true(town.is_sealed(), "ranked town is sealed")
			assert_true(WarrenPublicRealmCarver.passes_topology_gate(
				town.volume), "ranked volume meets the route-first bar")
		return
	assert_string_contains(WarrenTownSolver.last_failure,
		"passed the topology gate")
	assert_string_contains(WarrenTownSolver.last_failure, "ground arcade")


func test_mass_first_frontier_is_deterministic() -> void:
	## The frontier varies the carve seed per attempt, so an attempt-dependent
	## identity or an unstable order would surface as a differing corpus here.
	var first := _gated_excavated_volumes(MASS_FIRST_SEED).passed \
		as Array[WarrenVolumePlan]
	var second := _gated_excavated_volumes(MASS_FIRST_SEED).passed \
		as Array[WarrenVolumePlan]
	assert_eq(first.size(), second.size())
	for index in mini(first.size(), second.size()):
		assert_eq(first[index].deterministic_signature(),
			second[index].deterministic_signature(),
			"gated candidate %d is stable across calls" % index)
		assert_eq(String(first[index].stable_id),
			String(second[index].stable_id))


func test_route_first_still_solves_after_a_mass_first_call() -> void:
	## The flag is process-global static state. Restoring it must genuinely
	## restore the shipped path, with route-first identities and no residue
	## from the mass-first call before it.
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_MASS_FIRST
	WarrenTownSolver.ranked_candidates(MASS_FIRST_SEED, {}, null, 1)
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_ROUTE_FIRST
	var towns := WarrenTownSolver.ranked_candidates(MASS_FIRST_SEED, {}, null, 2)
	assert_gt(towns.size(), 0,
		"route-first still solves seed %d: %s" \
		% [MASS_FIRST_SEED, WarrenTownSolver.last_failure])
	for town: WarrenTownPlan in towns:
		assert_string_starts_with(String(town.volume.stable_id),
			"warren.volume.%d." % MASS_FIRST_SEED)
