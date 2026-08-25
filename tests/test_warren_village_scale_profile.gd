extends GutTest


func test_scale_distribution_boundaries_are_exact() -> void:
	assert_eq(WarrenVillageScaleProfile.from_roll(0).scale_id,
		WarrenVillageScaleProfile.COMPACT)
	assert_eq(WarrenVillageScaleProfile.from_roll(5499).scale_id,
		WarrenVillageScaleProfile.COMPACT)
	assert_eq(WarrenVillageScaleProfile.from_roll(5500).scale_id,
		WarrenVillageScaleProfile.STANDARD)
	assert_eq(WarrenVillageScaleProfile.from_roll(8499).scale_id,
		WarrenVillageScaleProfile.STANDARD)
	assert_eq(WarrenVillageScaleProfile.from_roll(8500).scale_id,
		WarrenVillageScaleProfile.LARGE)
	assert_eq(WarrenVillageScaleProfile.from_roll(9699).scale_id,
		WarrenVillageScaleProfile.LARGE)
	assert_eq(WarrenVillageScaleProfile.from_roll(9700).scale_id,
		WarrenVillageScaleProfile.GRAND)
	assert_eq(WarrenVillageScaleProfile.from_roll(9999).scale_id,
		WarrenVillageScaleProfile.GRAND)


func test_scale_budgets_grow_monotonically_without_weakening_integrity() -> void:
	var profiles: Array[WarrenVillageScaleProfile] = []
	for id: StringName in WarrenVillageScaleProfile.IDS:
		var profile := WarrenVillageScaleProfile.for_id(id)
		assert_not_null(profile)
		assert_true(profile.validate())
		assert_eq(profile.requires_covered_market,
			profile.scale_id in [WarrenVillageScaleProfile.LARGE,
				WarrenVillageScaleProfile.GRAND],
			"the covered bazaar is a city obligation; villages take one "
			+ "only when their ground street actually holds it")
		profiles.append(profile)
	for index in range(1, profiles.size()):
		var smaller := profiles[index - 1]
		var larger := profiles[index]
		assert_gt(larger.radius_cells, smaller.radius_cells)
		assert_gte(larger.route_cell_range.x, smaller.route_cell_range.x)
		assert_gte(larger.lane_budget, smaller.lane_budget)
		assert_gte(larger.room_volume_budget.x,
			smaller.room_volume_budget.x)
		assert_gt(larger.room_volume_budget.y,
			smaller.room_volume_budget.y)
		assert_gt(larger.residual_room_budget,
			smaller.residual_room_budget)
		assert_gt(larger.residual_kind_budget,
			smaller.residual_kind_budget)
		assert_gte(larger.skywalk_range.x, smaller.skywalk_range.x)
		assert_gte(larger.landmark_range.x, smaller.landmark_range.x)
		assert_gte(larger.minimum_inhabited_overhead_ratio,
			smaller.minimum_inhabited_overhead_ratio)
	for profile: WarrenVillageScaleProfile in profiles:
		assert_gte(profile.skywalk_range.x, 1)
		assert_eq(profile.cantilever_range, Vector2i.ZERO,
			"production pauses diagonal/full-room outcroppings until their basic " \
			+ "shell and roof joins pass visual review")
	assert_eq([profiles[0].skywalk_range.x, profiles[1].skywalk_range.x,
		profiles[2].skywalk_range.x, profiles[3].skywalk_range.x],
		[1, 1, 2, 3],
		"village-scale towns keep a modest occupied-link floor")
	assert_eq([profiles[2].skywalk_range.y, profiles[3].skywalk_range.y],
		[3, 4],
		"large and grand towns request an extra link; the sealed occluder "
		+ "ranking keeps it only when it adds distinct inhabited route cover")
	assert_eq(profiles[0].landmark_range, Vector2i(4, 4),
		"even a compact village composes around four complete authored buildings")
	assert_eq(profiles[1].landmark_range, Vector2i(4, 5),
		"a standard village tries a fifth building without dropping below four")
	assert_eq(profiles[2].landmark_range, Vector2i(5, 6))
	assert_eq(profiles[3].landmark_range, Vector2i(6, 8))
	assert_false(profiles[0].requires_elevated_courtyard)
	assert_false(profiles[1].requires_elevated_courtyard)
	assert_true(profiles[2].requires_elevated_courtyard)
	assert_true(profiles[3].requires_elevated_courtyard)
	assert_eq(WarrenVillageScaleProfile.review_fixture().scale_id,
		WarrenVillageScaleProfile.LARGE)


func test_scale_selection_is_seed_stable_and_small_biased() -> void:
	var counts: Dictionary = {}
	var deterministic := true
	for seed in 10000:
		var first := WarrenVillageScaleProfile.select(seed)
		var repeated := WarrenVillageScaleProfile.select(seed)
		deterministic = deterministic and first.deterministic_signature() \
			== repeated.deterministic_signature()
		counts[first.scale_id] = int(counts.get(first.scale_id, 0)) + 1
	assert_true(deterministic)
	assert_between(int(counts.get(WarrenVillageScaleProfile.COMPACT, 0)),
		5200, 5800)
	assert_between(int(counts.get(WarrenVillageScaleProfile.STANDARD, 0)),
		2700, 3300)
	assert_between(int(counts.get(WarrenVillageScaleProfile.LARGE, 0)),
		950, 1450)
	assert_between(int(counts.get(WarrenVillageScaleProfile.GRAND, 0)),
		180, 420)
	assert_gt(int(counts.get(WarrenVillageScaleProfile.COMPACT, 0)),
		int(counts.get(WarrenVillageScaleProfile.LARGE, 0))
		+ int(counts.get(WarrenVillageScaleProfile.GRAND, 0)))


func test_final_village_feature_contract_is_scale_aware() -> void:
	for id: StringName in WarrenVillageScaleProfile.IDS:
		var profile := WarrenVillageScaleProfile.for_id(id)
		var audit := _contract_audit(profile)
		assert_true(VillageUrbanFabricPlan._scale_feature_contract_matches(audit),
			"%s must survive the production validator with its own budget" % id)
		var old_large_contract := audit.duplicate(true)
		old_large_contract["elevated_courtyard_count"] = 1
		old_large_contract["prefab_landmark_count"] = \
			WarrenSpatialFeatureSolver.TARGET_PREFAB_LANDMARKS
		old_large_contract["enclosed_skywalk_count"] = \
			WarrenSpatialFeatureSolver.TARGET_SKYWALKS
		if id in [WarrenVillageScaleProfile.COMPACT,
				WarrenVillageScaleProfile.STANDARD]:
			assert_false(VillageUrbanFabricPlan \
				._scale_feature_contract_matches(old_large_contract),
				"smaller towns must not be silently promoted to the showcase contract")
	var compact := WarrenVillageScaleProfile.for_id(
		WarrenVillageScaleProfile.COMPACT)
	var forged := {
		"scale_profile_id": compact.scale_id,
		"scale_profile_signature": compact.deterministic_signature(),
		"elevated_courtyard_count": 0,
		"covered_market_count": 1,
		"prefab_landmark_count": 0,
		"enclosed_skywalk_count": compact.skywalk_range.x,
		"usable_balcony_count": compact.balcony_range.x,
		"room_outcropping_count": compact.cantilever_range.x,
	}
	forged["scale_profile_signature"] = "forged"
	assert_false(VillageUrbanFabricPlan._scale_feature_contract_matches(forged),
		"the final audit must retain the exact selected size contract")


func test_production_overhead_guidance_uses_the_selected_scale_contract() -> void:
	# Guidance values, not gates (see WarrenVolumetricSolver notes): a compact
	# town keeps its own reviewed overhead target; larger route programs are
	# steered toward more overhead coverage; legacy audits fall back to the
	# reviewed large-town value.
	var audit := {"scale_profile_id": WarrenVillageScaleProfile.COMPACT}
	assert_lt(WarrenVolumetricSolver.minimum_production_overhead_ratio(audit),
		WarrenVolumetricSolver.MIN_PRODUCTION_OVERHEAD_ROUTE_RATIO,
		"a compact town keeps its own smaller reviewed ratio")
	audit["scale_profile_id"] = WarrenVillageScaleProfile.STANDARD
	assert_gt(WarrenVolumetricSolver.minimum_production_overhead_ratio(audit),
		0.30, "larger route programs are steered toward more overhead coverage")
	audit.erase("scale_profile_id")
	assert_eq(WarrenVolumetricSolver.minimum_production_overhead_ratio(audit),
		WarrenVolumetricSolver.MIN_PRODUCTION_OVERHEAD_ROUTE_RATIO,
		"legacy and malformed audits retain the reviewed large-town value")


func test_production_alley_guidance_is_corpus_measured_per_scale() -> void:
	assert_eq(WarrenVolumetricSolver.minimum_production_alley_ratio(
		{"scale_profile_id": WarrenVillageScaleProfile.STANDARD}), 0.30,
		"the pinned village fixture's measured corpus floor")
	assert_eq(WarrenVolumetricSolver.minimum_production_alley_ratio(
		{"scale_profile_id": WarrenVillageScaleProfile.COMPACT}), 0.0,
		"unmeasured scales carry no floor")
	assert_eq(WarrenVolumetricSolver.minimum_production_alley_ratio({}), 0.0,
		"legacy audits without a scale contract carry no floor")


static func _contract_audit(profile: WarrenVillageScaleProfile) -> Dictionary:
	## The audit a town of this size profile ships when it meets every floor
	## exactly. Shared by the scale-aware contract test and the floor/ceiling
	## boundary test below so the two cannot drift apart.
	return {
		"scale_profile_id": profile.scale_id,
		"scale_profile_signature": profile.deterministic_signature(),
		"elevated_courtyard_count": int(profile.requires_elevated_courtyard),
		"courtyard_daylight_macro_column_count":
			WarrenElevatedFrontageSolver.MIN_COURTYARD_DAYLIGHT_COLUMNS \
			if profile.requires_elevated_courtyard else 0,
		"courtyard_underbuilt_macro_column_count":
			WarrenElevatedFrontageSolver.MIN_COURTYARD_UNDERBUILT_COLUMNS \
				if profile.requires_elevated_courtyard else 0,
		"covered_market_count": int(profile.requires_covered_market),
		"prefab_landmark_count": profile.landmark_range.x,
		"enclosed_skywalk_count": profile.skywalk_range.x,
		"usable_balcony_count": profile.balcony_range.x,
		"room_outcropping_count": profile.cantilever_range.x,
	}


func test_quota_floors_relax_only_downward() -> void:
	## TASK D2 REVIEW, IMPORTANT 2, restated for the one-pass pipeline (task
	## F1). The richness contract's three properties used to live only in a
	## comment. A FLOOR a one-pass town falls short of is an audit fact rather
	## than a refusal; a CEILING it exceeds is not a shortfall and stays hard;
	## an ABSENT count is a broken transaction, not a shortfall, and fails.
	##
	## TASK F3. `_meets_quota_floor(measured, floor_value, advisory)` was
	## called with a literal `true` at its only call site, which reduced it to
	## `_quota_count_is_measured` -- "the count must be present". It is
	## collapsed to that, and this test now walks EVERY relaxed floor rather
	## than the landmark one alone, so the collapse is pinned by the whole set
	## it applies to instead of by one representative.
	var compact := WarrenVillageScaleProfile.for_id(
		WarrenVillageScaleProfile.COMPACT)
	assert_true(VillageUrbanFabricPlan._scale_feature_contract_matches(
		_contract_audit(compact)),
		"a town that meets every floor exactly must be accepted")
	for relaxed_key: String in ["covered_market_count",
			"prefab_landmark_count", "enclosed_skywalk_count",
			"usable_balcony_count", "room_outcropping_count"]:
		var audit := _contract_audit(compact)
		audit[relaxed_key] = 0
		assert_true(VillageUrbanFabricPlan._scale_feature_contract_matches(
			audit),
			"a one-pass town's %s shortfall is an audit fact, not a refusal" \
				% relaxed_key)
		audit.erase(relaxed_key)
		assert_false(VillageUrbanFabricPlan._scale_feature_contract_matches(
			audit),
			"an absent %s is a broken transaction, not a shortfall" \
				% relaxed_key)
	# The ceilings beside those floors are untouched by the collapse.
	for ceiling: Array in [["prefab_landmark_count",
				compact.landmark_range.y + 1],
			["enclosed_skywalk_count", compact.skywalk_range.y + 1],
			["covered_market_count", 2]]:
		var audit := _contract_audit(compact)
		audit[String(ceiling[0])] = int(ceiling[1])
		assert_false(VillageUrbanFabricPlan._scale_feature_contract_matches(
			audit),
			"an excess over the %s ceiling was never a shortfall" \
				% String(ceiling[0]))
	# TASK F4. The courtyard terms USED to be the exception here -- "the counts
	# whose shortfall nothing publishes, which is the whole reason the relaxation
	# stops there". Something publishes them now (`elevated_courtyards`,
	# `courtyard_bridge_houses`, `composed_courtyard_sides`), so the count joins
	# the relaxed set on the condition the old comment itself named, and this
	# test walks the whole family rather than the one representative.
	var large := WarrenVillageScaleProfile.for_id(
		WarrenVillageScaleProfile.LARGE)
	var courtyard_audit := _contract_audit(large)
	assert_true(VillageUrbanFabricPlan._scale_feature_contract_matches(
		courtyard_audit), "a large town meeting every floor must be accepted")
	var courtless := _contract_audit(large)
	courtless["elevated_courtyard_count"] = 0
	courtless["courtyard_daylight_macro_column_count"] = 0
	courtless["courtyard_underbuilt_macro_column_count"] = 0
	assert_true(VillageUrbanFabricPlan._scale_feature_contract_matches(
		courtless),
		"a courtless large town's shortfall is an audit fact, not a refusal")
	courtless.erase("elevated_courtyard_count")
	assert_false(VillageUrbanFabricPlan._scale_feature_contract_matches(
		courtless),
		"an absent courtyard count is a broken transaction, not a shortfall")
	# The ceiling beside that floor is untouched: a compact town carrying a court
	# is a town promoted past its own size contract, which was never a shortfall.
	var promoted := _contract_audit(compact)
	promoted["elevated_courtyard_count"] = 1
	assert_false(VillageUrbanFabricPlan._scale_feature_contract_matches(
		promoted),
		"an excess over the elevated_courtyard_count ceiling is not a shortfall")
	# A town that DOES have a court still meets both column floors: there the
	# numbers measure a real thing rather than an absence, so they stay hard.
	for column_key: String in ["courtyard_daylight_macro_column_count",
			"courtyard_underbuilt_macro_column_count"]:
		var short_columns := _contract_audit(large)
		short_columns[column_key] = 1
		assert_false(VillageUrbanFabricPlan._scale_feature_contract_matches(
			short_columns),
			"a town WITH a court still owes %s" % column_key)
