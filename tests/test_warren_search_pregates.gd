extends GutTest
## Cheap early rejections in the volumetric warren search. Each rule here
## exists because profiling showed the search spending most of its time fully
## composing and compiling towns that a count check then rejected, or carving
## survivors that the very next gate discarded.


# --- precomposition sightline pre-gate ---------------------------------------

func test_precomposition_pregate_rejects_proxy_far_above_sightline_cap() -> void:
	var audit := {
		"through_sightline_count": WarrenVolumetricSolver \
			.MAX_PRODUCTION_THROUGH_SIGHTLINES \
			+ WarrenVolumetricSolver.PRECOMPOSITION_SIGHTLINE_MARGIN + 1,
		"ground_through_sightline_count": 0,
	}
	var reason := WarrenVolumetricSolver.precomposition_pregate_failure(audit)
	assert_false(reason.is_empty(), "proxy above cap + margin must be rejected")
	assert_string_contains(reason, "through sightlines")


func test_precomposition_pregate_keeps_proxy_within_margin_of_cap() -> void:
	# The proxy over-predicts the compiled count by up to a few dozen; a source
	# volume inside the margin must still reach composition.
	var audit := {
		"through_sightline_count": WarrenVolumetricSolver \
			.MAX_PRODUCTION_THROUGH_SIGHTLINES \
			+ WarrenVolumetricSolver.PRECOMPOSITION_SIGHTLINE_MARGIN,
		"ground_through_sightline_count": 500,
	}
	assert_eq(WarrenVolumetricSolver.precomposition_pregate_failure(audit), "",
		"at the threshold, and any ground count, the source is kept")


func test_precomposition_pregate_ignores_ground_sightlines() -> void:
	# The ground proxy under-predicts (observed 6 -> 92 compiled), so it must
	# never reject on its own.
	var audit := {"through_sightline_count": 0,
		"ground_through_sightline_count": 999}
	assert_eq(WarrenVolumetricSolver.precomposition_pregate_failure(audit), "")


static var _program_cache: SettlementFabricProgram


func _program() -> SettlementFabricProgram:
	if _program_cache == null:
		_program_cache = SettlementFabricProgram.compile(
			EnvironmentCatalog.load_default())
	return _program_cache


func test_ranking_drops_source_volumes_that_fail_the_sightline_pregate() -> void:
	# Fixture from profiling: city seed 3910114991003307946 (standard), attempt
	# 11 yields one source volume whose precomposition proxy counted 101
	# through sightlines against a cap of 48. Every one of its eight partition
	# variants was fully composed and compiled (~7.6 s each) and then rejected
	# with 74-91 compiled sightlines. The pre-gate must drop the whole source
	# before ranking returns any variant.
	var city_seed := 3910114991003307946
	var profile := WarrenVillageScaleProfile.for_id(
		WarrenVillageScaleProfile.STANDARD)
	var frontier := WarrenTownSolver.mass_first_attempt_frontier(city_seed, 11,
		{}, profile)
	assert_eq(frontier.size(), 1, "fixture attempt must still carve one volume")
	var ranked := WarrenVolumetricSolver._ranked_precomposition_variants(
		frontier, _program())
	assert_eq(ranked.size(), 0, "pre-gated source contributes no variants")
	assert_string_contains(
		WarrenVolumetricSolver.last_precomposition_pregate_failure,
		"through sightlines")


# --- per-source topology-bound failure memo -----------------------------------

func test_sightline_failure_far_over_cap_is_topology_bound() -> void:
	# Observed per source volume: 91/74/91, 104/80/104, 93/93/93/89, 97/97/97
	# compiled through sightlines across partition variants. A wide miss on one
	# variant predicts the same miss on the rest of that source's variants.
	var audit := {"through_sightline_count": int(ceil(
		WarrenVolumetricSolver.MAX_PRODUCTION_THROUGH_SIGHTLINES \
		* WarrenVolumetricSolver.TOPOLOGY_BOUND_SIGHTLINE_RATIO)) + 1,
		"ground_through_sightline_count": 0}
	assert_true(WarrenVolumetricSolver.is_topology_bound_quality_failure(audit))


func test_ground_sightline_failure_is_never_topology_bound() -> void:
	# Counter-example from the oracle: city seed 3613595803240038080, attempt 0,
	# source ...gallery0 — variant 4 compiled 35 ground through sightlines
	# (cap 20) while variant 3 sealed at or under the cap. Ground daylight
	# depends on which rooms a variant places at street level, so it must
	# never retire a source's remaining variants.
	var audit := {"through_sightline_count": 0,
		"ground_through_sightline_count": 999}
	assert_false(WarrenVolumetricSolver.is_topology_bound_quality_failure(audit))


func test_narrow_sightline_miss_is_not_topology_bound() -> void:
	# 50 vs cap 48 sat next to 96 and 117 on the same source; a near miss says
	# nothing reliable about sibling variants, so they must still be tried.
	var audit := {"through_sightline_count": WarrenVolumetricSolver \
		.MAX_PRODUCTION_THROUGH_SIGHTLINES + 2,
		"ground_through_sightline_count": 0}
	assert_false(WarrenVolumetricSolver.is_topology_bound_quality_failure(audit))


func test_other_quality_failures_are_not_topology_bound() -> void:
	# Overhead / alley ratios vary with room choices; never memoise those.
	var audit := {"through_sightline_count": 0,
		"ground_through_sightline_count": 0, "overhead_route_ratio": 0.0}
	assert_false(WarrenVolumetricSolver.is_topology_bound_quality_failure(audit))


# --- gate-aware excavation selection ------------------------------------------

const COMPACT_FIXTURE_SEED := 166029932451774690


func test_carve_ranked_returns_sealed_survivors_best_first_with_carve_as_head() -> void:
	# Fixture from profiling: attempt 0 of this compact seed keeps two of its
	# 256 bores. carve() must remain exactly the head of the ranked list.
	var profile := WarrenVillageScaleProfile.for_id(
		WarrenVillageScaleProfile.COMPACT)
	var massif := WarrenMassifBuilder.build(COMPACT_FIXTURE_SEED, {}, profile)
	var ranked := WarrenExcavationCarver.carve_ranked(COMPACT_FIXTURE_SEED,
		massif, profile, 8)
	assert_eq(ranked.size(), 2, "both survivors seal")
	var single := WarrenExcavationCarver.carve(COMPACT_FIXTURE_SEED, massif,
		profile)
	assert_not_null(single)
	assert_eq(single.route, ranked[0].route, "carve() is the ranked head")
	assert_ne(ranked[0].route, ranked[1].route, "ranked candidates differ")


func test_frontier_takes_first_gate_passing_bore_when_the_best_fails() -> void:
	# Attempt 5 of this seed keeps four bores; the score-best two fail the
	# topology gate ("walk cells 11 < 12", "ramp transitions 0 < 1") and the
	# third passes it and survives every later stage. Before this change the
	# attempt was a guaranteed ~0.7 s miss and this seed never produced a
	# frontier candidate in any of its 12 attempts.
	var profile := WarrenVillageScaleProfile.for_id(
		WarrenVillageScaleProfile.COMPACT)
	var frontier := WarrenTownSolver.mass_first_attempt_frontier(
		COMPACT_FIXTURE_SEED, 5, {}, profile)
	assert_eq(frontier.size(), 1, WarrenTownSolver.last_failure)


func test_selected_attempt_rebuild_re_derives_the_same_gate_passing_bore() -> void:
	# The staged frontier and the selected-attempt rebuild must pick the same
	# ranked survivor, or a pinned town would re-derive a different bore.
	var profile := WarrenVillageScaleProfile.for_id(
		WarrenVillageScaleProfile.COMPACT)
	var staged := WarrenTownSolver.mass_first_frontier(COMPACT_FIXTURE_SEED, {},
		profile)
	var selected := WarrenTownSolver.mass_first_attempt_frontier(
		COMPACT_FIXTURE_SEED, 5, {}, profile)
	assert_eq(selected.size(), 1)
	var selected_id := selected[0].stable_id
	var found := false
	for volume: WarrenVolumePlan in staged:
		if volume.stable_id == selected_id:
			found = true
			assert_eq(volume.primary_itinerary, selected[0].primary_itinerary,
				"same bore, same itinerary")
	assert_true(found, "staged frontier contains the selected attempt's volume")
