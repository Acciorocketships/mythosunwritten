extends GutTest


func _terraced_region() -> HeightfieldRegion:
	var storeys: Dictionary = {}
	var levels: Dictionary = {}
	for z in range(-12, 13):
		for x in range(-12, 13):
			var cell := Vector2i(x, z)
			storeys[cell] = 0 if x <= -1 else (1 if x == 0 else 2)
			levels[cell] = 0
	return HeightfieldRegion.new(storeys, levels)


func test_terraced_fabric_gets_local_streets_and_aerial_links() -> void:
	var program := VillageProgram.compile({}, EnvironmentCatalog.load_default())
	var terrain := VillageTerrainView.from_region(_terraced_region())
	var market := VillageMarketSolver.solve(terrain, &"circulation.test",
		Vector2.ZERO, Vector2.RIGHT, &"village", &"blue", program)
	assert_true(market.accepted, String(market.reason))
	var massing := VillageMassingSolver.solve(terrain, Vector2.ZERO,
		Vector2.RIGHT, program, &"village", market.volumes)
	assert_true(massing.accepted, String(massing.reason))
	var plan := VillageCirculationSolver.solve(terrain, Vector2.ZERO,
		Vector2.RIGHT, massing, program.elevated_program, market)
	assert_true(plan.accepted, "%s: %d streets, %d aerial, %d platforms" % [
		String(plan.reason), plan.ground_street_count,
		plan.aerial_link_count, plan.platforms.size()])
	assert_true(plan.validate(massing))
	assert_gte(plan.ground_street_count,
		ceili(float(massing.placements.size()) \
			* VillageMassingProgram.MIN_GROUND_STREET_RATIO),
		"each terrain band must carry a useful street component")
	assert_gte(plan.aerial_link_count,
		VillageMassingProgram.MIN_AERIAL_LINKS)
	assert_gt(plan.curved_link_count, 0)
	assert_lte(plan.maximum_aerial_length,
		VillageMassingProgram.MAX_LINK_RADIUS)
	for platform: VillagePlatformRegion in plan.platforms:
		assert_gte(platform.frontage_keys.size(), 2)
	for link: VillageCirculationLink in plan.links:
		assert_true(link.is_valid(), String(link.stable_key))
		if link.kind == VillageCirculationLink.Kind.GROUND_STAIR:
			assert_false(link.stair_transitions.is_empty(),
				"public stairs must preserve their exact discontinuities")
			assert_eq(link.stair_intervals.size(),
				link.stair_transitions.size(),
				"routing freezes every non-overlapping authored stair run")
		elif link.is_aerial() and link.stair_count > 0:
			assert_eq(link.stair_intervals.size(), 1,
				"a stepped aerial route freezes its facade-clear flight")


func test_ground_stair_intervals_reject_transitions_without_physical_run() -> void:
	var crowded_samples: Array[Vector3] = [Vector3(0.0, 0.0, 0.0),
		Vector3(0.5, 4.0, 0.0), Vector3(1.0, 8.0, 0.0),
		Vector3(12.0, 8.0, 0.0)]
	var crowded: Array[VillageStairTransition] = [
		VillageStairTransition.new(1, 1, 4.0, 0.0),
		VillageStairTransition.new(2, 1, 4.0, 0.0),
	]
	assert_true(VillageRouteGeometry.ground_stair_intervals(
		crowded_samples, crowded, 1.5).is_empty(),
		"individually stairable cliff edges cannot claim the same route run")
	var spaced_samples: Array[Vector3] = [Vector3(0.0, 0.0, 0.0),
		Vector3(1.5, 4.0, 0.0), Vector3(6.0, 4.0, 0.0),
		Vector3(7.5, 8.0, 0.0), Vector3(12.0, 8.0, 0.0)]
	var spaced: Array[VillageStairTransition] = [
		VillageStairTransition.new(1, 1, 4.0, 0.0),
		VillageStairTransition.new(3, 1, 4.0, 0.0),
	]
	assert_eq(VillageRouteGeometry.ground_stair_intervals(
		spaced_samples, spaced, 1.5).size(), 2)


func test_aerial_stair_interval_reserves_both_facade_departures() -> void:
	var interval := VillageRouteGeometry.aerial_stair_interval(
		24.0, 6.0, 7.5, 4.5)
	assert_eq(interval, [Vector2(9.0, 15.0)])
	assert_true(VillageRouteGeometry.aerial_stair_interval(
		17.9, 6.0, 7.5, 4.5).is_empty())


func test_rejected_massing_cannot_emit_orphan_circulation() -> void:
	var program := VillageProgram.compile({}, EnvironmentCatalog.load_default())
	var plan := VillageCirculationSolver.solve(
		VillageTerrainView.from_region(_terraced_region()), Vector2.ZERO,
		Vector2.RIGHT, VillageMassingPlan.new(), program.elevated_program)
	assert_false(plan.accepted)
	assert_eq(plan.reason, &"massing")
	assert_true(plan.nodes.is_empty())
	assert_true(plan.links.is_empty())


func test_reported_seed_has_one_connected_multilevel_street_graph() -> void:
	var seed_value := 2697992464
	var water_plan := TerrainWorldTuning.make_water(seed_value)
	var heightfield := TerrainWorldTuning.make_heightfield(seed_value,
		water_plan)
	var feature_program := FeatureProgram.compile(
		EnvironmentCatalog.load_default())
	var fields := WorldFieldBlockCache.new(heightfield, water_plan,
		feature_program.query_margin,
		feature_program.shore_distance_limit,
		feature_program.field_cache_cap)
	var site := SettlementPlan.new(seed_value, water_plan).site_for(
		Vector2i(0, -1))
	assert_false(site.is_empty())
	var arrival := Vector2(site.cell) * TerrainSurfaceField.TILE
	var terrain := VillageTerrainView.from_fields(fields)
	var tier := VillageProgram.production_tier(0.5)
	var urban := VillageUrbanFabricSolver.solve(terrain,
		&"settlement.reported.circulation", arrival, Vector2.RIGHT, tier,
		&"blue", feature_program.villages)
	assert_true(urban.accepted, "%s\n%s" % [String(urban.reason),
		JSON.stringify(urban.candidate_audit, "  ")])
	if not urban.accepted:
		return
	var massing := urban.massing
	var plan := urban.circulation
	assert_true(plan.accepted,
		"%s: %d streets, %d aerial, %d platforms" % [String(plan.reason),
			plan.ground_street_count, plan.aerial_link_count,
			plan.platforms.size()])
	assert_true(plan.validate(massing))
	assert_gte(plan.platforms.size(), 1,
		"the accepted fabric must contain inhabited shared public ground")
	assert_gte(plan.aerial_link_count,
		VillageMassingProgram.MIN_AERIAL_LINKS)
	assert_lte(plan.maximum_aerial_length,
		VillageMassingProgram.MAX_LINK_RADIUS)
