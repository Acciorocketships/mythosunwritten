extends GutTest
## Cheap early rejections in the volumetric warren search. Each rule here
## exists because profiling showed the search spending most of its time fully
## composing and compiling towns that a count check then rejected, or carving
## survivors that the very next gate discarded.


# --- enclosure and size metrics are guidance, never a production gate --------

func test_no_post_composition_quality_gate_exists() -> void:
	# Sightline counts, overhead ratio, alley-bounded ratio and the inhabited
	# room range describe the look towns should read with. They shape the
	# precomposition ranking; none of them may throw away a fully composed and
	# compiled town. Profiling (docs §8.8) showed ~70 % of village-scale
	# composition time spent on towns rejected by exactly these checks.
	assert_false(WarrenVolumetricSolver.new().has_method(
		"production_quality_failure"),
		"the post-composition quality gate was removed; metrics are guidance")


func test_guidance_minimums_remain_available_for_ranking_and_audits() -> void:
	assert_eq(WarrenVolumetricSolver.minimum_production_alley_ratio(
		{"scale_profile_id": WarrenVillageScaleProfile.STANDARD}), 0.30)
	assert_eq(WarrenVolumetricSolver.minimum_production_overhead_ratio({}),
		WarrenVolumetricSolver.MIN_PRODUCTION_OVERHEAD_ROUTE_RATIO)


static var _program_cache: SettlementFabricProgram


func _program() -> SettlementFabricProgram:
	if _program_cache == null:
		_program_cache = SettlementFabricProgram.compile(
			EnvironmentCatalog.load_default())
	return _program_cache


func test_ranking_keeps_sources_whatever_their_sightline_proxy() -> void:
	# City seed 3910114991003307946 (standard), attempt 11: one source volume
	# whose precomposition proxy counts 101 through sightlines. Enclosure is
	# guidance, so ranking must still offer all eight of its partition variants
	# (ordered by the score, which already penalises that proxy).
	var city_seed := 3910114991003307946
	var profile := WarrenVillageScaleProfile.for_id(
		WarrenVillageScaleProfile.STANDARD)
	var frontier := WarrenTownSolver.mass_first_attempt_frontier(city_seed, 11,
		{}, profile)
	assert_eq(frontier.size(), 1, "fixture attempt must still carve one volume")
	var ranked := WarrenVolumetricSolver._ranked_precomposition_variants(
		frontier, _program())
	assert_eq(ranked.size(), WarrenVolumetricSolver.MAX_PARTITION_VARIANTS)


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
