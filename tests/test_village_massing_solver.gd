extends GutTest


func _terraced_region() -> HeightfieldRegion:
	var storeys: Dictionary = {}
	var levels: Dictionary = {}
	for z in range(-10, 11):
		for x in range(-10, 11):
			var cell := Vector2i(x, z)
			storeys[cell] = 0 if x <= -1 else (1 if x == 0 else 2)
			levels[cell] = 0
	return HeightfieldRegion.new(storeys, levels)


func test_default_program_compiles_dense_semantic_rosters() -> void:
	var program := VillageProgram.compile({}, EnvironmentCatalog.load_default())
	assert_not_null(program)
	assert_not_null(program.massing_program)
	assert_eq(program.massing_slots_for_tier(&"village").size(), 10)
	assert_eq(program.massing_slots_for_tier(&"town").size(), 15)
	assert_eq(program.massing_program.minimum_buildings(&"village"), 7)
	assert_eq(program.massing_program.minimum_buildings(&"town"), 10)


func test_terraced_massing_is_compact_dense_and_deterministic() -> void:
	var program := VillageProgram.compile({}, EnvironmentCatalog.load_default())
	var a := VillageMassingSolver.solve(VillageTerrainView.from_region(
		_terraced_region()),
		Vector2.ZERO, Vector2.RIGHT, program, &"village")
	var b := VillageMassingSolver.solve(VillageTerrainView.from_region(
		_terraced_region()),
		Vector2.ZERO, Vector2.RIGHT, program, &"village")
	assert_true(a.accepted, String(a.reason))
	assert_true(a.validate(program.massing_program, &"village"))
	assert_gte(a.placements.size(),
		program.massing_program.minimum_buildings(&"village"))
	assert_lte(a.core_radius, VillageMassingProgram.CORE_RADIUS)
	assert_lte(a.mean_nearest_distance,
		VillageMassingProgram.MAX_LINK_RADIUS)
	assert_gte(a.elevation_band_count,
		VillageMassingProgram.MIN_ELEVATION_BANDS)
	assert_gt(a.half_rise_count, 0)
	assert_gte(a.terrain_support_ratio,
		VillageMassingProgram.MIN_TERRAIN_SUPPORT_RATIO)
	assert_gte(a.platformizable_pair_count,
		VillageMassingProgram.MIN_PLATFORMIZABLE_PAIRS)
	assert_gt(a.natural_ratio, 0.0,
		"the solve must retain naturally supported buildings where they fit")
	assert_eq(_signature(a), _signature(b))
	for index in a.placements.size():
		assert_false(a.placements[index].solid_shape().intersects(
			FeatureGroundShape.circle(Vector2.ZERO,
				VillageMassingProgram.ARRIVAL_RADIUS),
			VillageMassingProgram.BUILDING_GAP),
			"the route landing must remain public space")
		for prior in index:
			assert_false(a.placements[index].overlaps(
				a.placements[prior], VillageMassingProgram.BUILDING_GAP))


func test_legacy_flat_massing_rejects_atomically_instead_of_faking_levels() -> void:
	var storeys: Dictionary = {}
	var levels: Dictionary = {}
	for z in range(-8, 9):
		for x in range(-8, 9):
			storeys[Vector2i(x, z)] = 0
			levels[Vector2i(x, z)] = 0
	var program := VillageProgram.compile({}, EnvironmentCatalog.load_default())
	var plan := VillageMassingSolver.solve(VillageTerrainView.from_region(
		HeightfieldRegion.new(storeys, levels)), Vector2.ZERO, Vector2.RIGHT,
		program, &"village")
	assert_false(plan.accepted,
		"the retired terrain-massing fixture may not manufacture fake relief")
	assert_false(plan.reason.is_empty())
	assert_true(plan.placements.is_empty(),
		"a rejected legacy solve cannot leak a partial town")
	assert_eq(plan.building_count, 0)


func test_reported_seed_exposes_a_viable_compact_terrain_led_core() -> void:
	var seed_value := 2697992464
	var water_plan := TerrainWorldTuning.make_water(seed_value)
	var heightfield := TerrainWorldTuning.make_heightfield(seed_value,
		water_plan)
	var feature_program := FeatureProgram.compile(
		EnvironmentCatalog.load_default())
	var fields := WorldFieldBlockCache.new(heightfield, water_plan,
		feature_program.query_margin, feature_program.shore_distance_limit,
		feature_program.field_cache_cap)
	var settlements := SettlementPlan.new(seed_value, water_plan)
	var site := settlements.site_for(Vector2i(0, -1))
	assert_false(site.is_empty())
	var centre := Vector2(site.cell) * TerrainSurfaceField.TILE
	var tier := VillageProgram.production_tier(0.5)
	var plan := VillageMassingSolver.solve(VillageTerrainView.from_fields(fields),
		centre, Vector2.RIGHT,
		feature_program.villages, tier)
	assert_true(plan.accepted, "%s (%d/%d buildings, %d bands, %d half rises, %.2f natural)" % [
		String(plan.reason), plan.building_count, plan.required_building_count,
		plan.elevation_band_count, plan.half_rise_count, plan.natural_ratio])
	assert_gte(plan.placements.size(),
		feature_program.villages.massing_program.minimum_buildings(tier))
	assert_lte(plan.core_radius, VillageMassingProgram.CORE_RADIUS)
	assert_lte(plan.mean_nearest_distance,
		VillageMassingProgram.MAX_LINK_RADIUS)


func _signature(plan: VillageMassingPlan) -> PackedStringArray:
	var out: PackedStringArray = []
	for placement: VillageMassingPlacement in plan.placements:
		out.append("%s@%s/f%d" % [placement.stable_key,
			placement.perch.candidate_key, placement.facade_index])
	return out
