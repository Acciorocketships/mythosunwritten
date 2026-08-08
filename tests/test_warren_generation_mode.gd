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
## Mass-first now reaches ranked parcel plans: every arcaded candidate is
## partitioned into terraced houses by WarrenSolidPartitioner and clears the
## same construction gate route-first candidates do. It does not yet reach a
## composed town -- see test_mass_first_reports_which_stage_consumed_the_corpus
## for the one stage that still consumes the corpus and why that is a route
## model conflict rather than a gate to relax.

const MASS_FIRST_SEED := 11

## Boring one massif twelve times costs ~11s, so the frontier is built once and
## shared. Volumes are sealed and immutable; partition_parcels() builds fresh
## parcels per call, so sharing them couples nothing.
var _frontier_cache: Dictionary = {}


func after_each() -> void:
	## A leaked flag would silently convert every later suite in the same
	## process to mass-first, so restore it even when an assertion failed.
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_ROUTE_FIRST


func _frontier(world_seed: int) -> Array[WarrenVolumePlan]:
	if not _frontier_cache.has(world_seed):
		_frontier_cache[world_seed] = WarrenTownSolver.mass_first_frontier(
			world_seed)
	return _frontier_cache[world_seed] as Array[WarrenVolumePlan]


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
		# A third criterion joined these two once WarrenExcavationVolumeAdapter
		# was corrected to register walk cells one per bored MOVE (matching
		# WarrenPublicRealmCarver's own convention) instead of one per carved
		# CELL: walk_cell_count now measures the same quantity
		# MIN_ROUTE_CELLS gates on, and a STAIR/RAMP spends 2-3 cells per move,
		# so it is no longer guaranteed to clear 22 just because
		# WarrenExcavationCarver's own cell-length family (30-36) does.
		assert_true(int(volume.audit.ramp_transition_count) < 1 \
			or float(volume.audit.addressed_walk_ratio) < 0.55 \
			or int(volume.audit.walk_cell_count) \
				< WarrenPublicRealmCarver.MIN_ROUTE_CELLS,
			"rejection is one of the three criteria excavation does not " \
			+ "guarantee (walk_cells=%d ramps=%d addressed=%.2f)" % [
			int(volume.audit.walk_cell_count),
			int(volume.audit.ramp_transition_count),
			float(volume.audit.addressed_walk_ratio)])


func test_mass_first_reports_which_stage_consumed_the_corpus() -> void:
	## Mass-first mode must fail loudly and specifically, never silently. This
	## pins wherever the corpus is currently lost, so the test -- not a later
	## reader re-instrumenting the pipeline by hand -- is what announces that
	## the boundary moved.
	##
	## It is no longer the walk/surface collision this test used to pin:
	## WarrenExcavationVolumeAdapter now registers walk cells one per bored
	## move (matching WarrenPublicRealmCarver's own route-first convention --
	## a STAIR/RAMP's intermediate stride cell is real frontage
	## (has_frontage()) but never a walk_cells graph node), so
	## WarrenVolumePublicRealmAdapter no longer sees two claimants for the
	## same surface. Four of six measured seeds (3, 4, 5, 6) now compose full
	## towns end to end for the first time.
	##
	## Seed 1 specifically is still consumed, one stage further on: its
	## (now smaller, since walk_cell_count measures moves rather than cells --
	## see test_the_topology_gate_still_rejects_excavated_routes) frontier has
	## exactly one gated, arcaded, partitioned candidate, and that candidate's
	## urban core keeps an unclassified 3 m aperture that WarrenTownPlan.seal()
	## refuses -- a real, shared production gate (also route-first's own) that
	## nothing about the walk/frontage model touches. This is genuinely new
	## territory: no mass-first candidate had ever reached this gate before.
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_MASS_FIRST
	var towns := WarrenTownSolver.ranked_candidates(MASS_FIRST_SEED, {}, null, 4)
	if not towns.is_empty():
		for town: WarrenTownPlan in towns:
			assert_true(town.is_sealed(), "ranked town is sealed")
			assert_true(WarrenPublicRealmCarver.passes_topology_gate(
				town.volume), "ranked volume meets the route-first bar")
			for parcel: WarrenBuildingParcel in town.parcels.parcels:
				assert_string_starts_with(String(parcel.stable_id),
					"parcel.solid.", "a composed mass-first town is built " \
					+ "from the partitioned solid")
		return
	assert_string_contains(WarrenTownSolver.last_failure, "urban core retains")
	assert_string_contains(WarrenTownSolver.last_failure, "unclassified")


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


func test_mass_first_parcels_are_the_solid_the_streets_were_cut_from() -> void:
	## Task 6's deliverable. Every candidate the frontier produces must yield a
	## sealed parcel plan whose houses are the partitioned leftover solid, not
	## envelopes a packing search fitted around a route. The stable-id prefix is
	## the only fact that distinguishes the two authors, so it is asserted
	## directly rather than inferred from a count.
	##
	## The flag is deliberately not flipped here: both seams are excavated
	## geometry in and parcels out, independent of the mode. Which of the two
	## parcel stages the flag selects is
	## test_mass_first_reports_which_stage_consumed_the_corpus's business.
	var frontier := _frontier(MASS_FIRST_SEED)
	assert_gt(frontier.size(), 0, WarrenTownSolver.last_failure)
	for volume: WarrenVolumePlan in frontier:
		var parcels := WarrenTownSolver.partition_parcels(volume)
		# Not "most candidates partition": the partitioner's ownership
		# guarantee makes a complete partition structural, so a null here is a
		# broken guarantee rather than ordinary attrition.
		assert_not_null(parcels, "%s: %s" % [volume.stable_id,
			WarrenTownSolver.last_partition_failure])
		if parcels == null:
			continue
		assert_true(parcels.is_sealed(), parcels.last_rejection)
		assert_eq(parcels.source, volume,
			"the plan is sealed against the volume it was partitioned from")
		assert_gte(parcels.parcels.size(), WarrenTownSolver.MIN_COMPLETE_PARCELS,
			"a mass-first candidate is a town, not a hamlet")
		# The floors of the route-first construction gate, restated so this
		# stage is judged on the bar the shipped pipeline already applies.
		assert_gte(int(parcels.audit.base_band_count), 3,
			"terraced houses stand on several datums")
		assert_gte(int(parcels.audit.footprint_family_count), 3,
			"the partition uses several footprint families")
		assert_eq(int(parcels.audit.visually_short_parcel_count), 0,
			"production forbids visually short houses outright")
		for parcel: WarrenBuildingParcel in parcels.parcels:
			assert_string_starts_with(String(parcel.stable_id), "parcel.solid.",
				"every house was partitioned out of the standing solid")


func test_mass_first_streets_run_between_walls_somebody_owns() -> void:
	## The point of the whole mode: an excavated street must read as a canyon.
	## Audited against the volume's OWN total negative space -- the bore plus
	## the arcade and gallery void carved after it -- because a house resting on
	## a column the arcade undermined is not a wall, and neither is one the
	## partition put inside the arcade.
	##
	## `unowned` being empty is already a production gate, so the teeth here are
	## the two facts production does not check: that the emptiness is not vacuous
	## (a partition of nothing but kerbs would also report zero unowned walls),
	## and that the street it walls actually climbs.
	var frontier := _frontier(MASS_FIRST_SEED)
	assert_gt(frontier.size(), 0, WarrenTownSolver.last_failure)
	for volume: WarrenVolumePlan in frontier:
		var parcels := WarrenTownSolver.partition_parcels(volume)
		if parcels == null:
			continue
		var massif := volume.mass_context.get(&"massif") as WarrenMassif
		var bore := volume.mass_context.get(&"excavation") as WarrenExcavation
		assert_not_null(massif, "the frontier variant still names its massif")
		assert_not_null(bore, "the frontier variant still names its bore")
		var excavation := WarrenExcavationVolumeAdapter.excavation_for_volume(
			bore, volume)
		assert_not_null(excavation, WarrenExcavationVolumeAdapter.last_failure)
		if excavation == null:
			continue
		var audit := WarrenSolidPartitioner.street_wall_audit(parcels.parcels,
			excavation, massif)
		assert_eq((audit["unowned"] as Array[Vector3i]).size(), 0,
			"%s leaves a hole in a street wall" % volume.stable_id)
		# Measured across seeds 1/3/4/5/6/9 the owned share never fell below
		# 0.47; a third is well clear of that and still refuses a partition
		# which trimmed the street to kerbs instead of walling it.
		assert_gte(int(audit["owned_count"]) * 3, int(audit["wall_count"]),
			"at least a third of the street walls are owned outright")
		var low := 1 << 30
		var high := -(1 << 30)
		for cell: Vector3i in volume.primary_itinerary:
			low = mini(low, cell.y)
			high = maxi(high, cell.y)
		assert_gte(high - low, 8, "an excavated street climbs at least 8 bands")


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
		# The parcel stage is mode-switched too, and the author of a house is
		# the one fact that can prove which branch ran. Route-first houses come
		# from the packing search and must keep coming from it.
		for parcel: WarrenBuildingParcel in town.parcels.parcels:
			assert_string_starts_with(String(parcel.stable_id),
				"parcel.candidate.",
				"route-first houses still come from the packing search")
