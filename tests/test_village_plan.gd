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

func _dry_water(region: HeightfieldRegion) -> WaterFieldContext:
	var water := WaterFieldContext.new()
	water._ctx = {"ponds": [], "rivers": [], "buckets": {}, "region": region}
	water._region = region
	water._coverage = Rect2(-Vector2.ONE * 384.0, Vector2.ONE * 768.0)
	water._shore_limit = 0.0
	return water

func _frame(mask := 1) -> VillageFrame:
	var storeys: Dictionary = {}
	var levels: Dictionary = {}
	for z in range(-24, 25):
		for x in range(-24, 25):
			storeys[Vector2i(x, z)] = 0
			levels[Vector2i(x, z)] = 0
	var region := HeightfieldRegion.new(storeys, levels)
	var masks := {Vector2i.ZERO: mask}
	var ground := FeatureGroundField.new([], [], 4.5, masks)
	var context := FeatureContext.new(Rect2(-Vector2.ONE * 192.0,
		Vector2.ONE * 384.0), ground, EnvironmentInstancePayload.new(), masks)
	return VillageFrame.build({"id": &"settlement.plan.test",
		"cell": Vector2i.ZERO}, context, region, _dry_water(region))

func test_record_is_deterministic_sealed_and_reserves_each_accepted_lot() -> void:
	var program := VillageProgram.compile({}, EnvironmentCatalog.load_default())
	var frame := _frame()
	# Use the first pinned production-corpus seed so this independent
	# recomputation test remains representative without selecting a known slow
	# search tail twice.
	var a := VillagePlan.new(4242, program).record_for(frame)
	var b := VillagePlan.new(4242, program).record_for(frame)
	assert_not_null(a)
	assert_not_null(b)
	assert_true(a.validate(program))
	assert_gt(a.payload.instance_count, 0)
	assert_eq(a.payload.batches, b.payload.batches,
		"independent recomputation must produce the same semantic placements")
	assert_eq(a.tier, b.tier)
	assert_eq(a.theme, b.theme)
	assert_eq(a.street_axis, b.street_axis)
	assert_eq(a.urban_fabric.reason, b.urban_fabric.reason)
	assert_eq(a.urban_fabric.buildings, b.urban_fabric.buildings)
	assert_eq(a.prop_results.size(),
		program.prop_slots_for_tier(a.tier).size(),
		"standalone props retain their own complete acceptance audit")
	var accepted_props := 0
	for result: StringName in a.prop_results.values():
		assert_false(result.is_empty())
		accepted_props += 1 if result == &"accepted" else 0
	assert_true(a.street_axis.is_normalized())
	assert_true(a.urban_fabric.accepted, String(a.urban_fabric.reason))
	assert_true(a.urban_fabric.validate(program, a.tier))
	assert_eq(a.urban_fabric.generation_kind,
		VillageUrbanFabricPlan.GenerationKind.VOLUMETRIC_WARREN)
	assert_between(a.urban_fabric.terrain_entrance_lift_m, 0.0,
		TraversalEnvelope.MAX_PLANNED_STEP,
		"the town landing must meet the world path without an inferred stair")
	assert_gte(a.urban_fabric.buildings.size(),
		7)
	var audit := a.urban_fabric.fabric_audit
	assert_gt(int(audit.terrain_street_cell_count), 0)
	assert_gte(int(audit.vertical_span_cells), 3)
	assert_gt(int(audit.stair_count), 0)
	assert_gte(int(audit.skywalk_link_count), 1)
	assert_eq(int(audit.detached_building_stack_count), 0)
	assert_eq(int(audit.stair_endpoint_gap_count), 0)
	assert_eq(int(audit.stair_endpoint_missing_landing_count), 0)
	assert_eq(int(audit.stair_to_stair_edge_count), 0)
	assert_gt(a.surface_shapes.size(), 0)
	assert_gte(a.clearance_shapes.size(),
		a.urban_fabric.clearances.size() + accepted_props,
		"the complete dense fabric and accepted props reserve their geometry")
	assert_gte(a.occupancy.size(), a.urban_fabric.volumes.size(),
		"the record carries the exact typed occupancy of the transaction")
	var occupancy_roles: Dictionary = {}
	for volume: VillageOccupancyVolume in a.occupancy:
		occupancy_roles[volume.role] = true
	for required_role in [VillageOccupancy.Role.SOLID,
			VillageOccupancy.Role.WALK_SURFACE,
			VillageOccupancy.Role.HEADROOM,
			VillageOccupancy.Role.WALK_GUARD,
			VillageOccupancy.Role.GROUND_EXCLUSIVE]:
		assert_true(occupancy_roles.has(required_role),
			"sectional production preserves every typed occupancy role")
	assert_gt(a.urban_fabric.volumes.size(), 10,
		"production occupancy comes from coalesced sealed cells, not one broad proxy")
	var accepted_markets := 0
	var catalog := EnvironmentCatalog.load_default()
	for asset_id: StringName in SettlementFabricProgram.MARKET_STALLS:
		var count := int((a.payload.batches.get(asset_id, {}) \
			as Dictionary).get("transforms", []).size())
		accepted_markets += count
		if count > 0:
			assert_has(catalog.descriptor(asset_id).tags, &"stocked_market")
	assert_gte(accepted_markets, 2,
		"the market alley uses stocked prefab stalls, never empty tent shells")
	for result: StringName in a.prop_results.values():
		assert_eq(result, &"generated_fabric_owned")
	for asset_id: StringName in a.payload.asset_ids():
		var local_aabb: AABB = program.runtime_aabbs[asset_id]
		for transform: Transform3D in a.payload.batches[asset_id].transforms:
			var world_aabb := transform * local_aabb
			assert_true(a.bounds.grow(0.001).has_point(Vector2(
				world_aabb.position.x, world_aabb.position.z)))
			assert_true(a.bounds.grow(0.001).has_point(Vector2(
				world_aabb.end.x, world_aabb.end.z)),
				"sealed bounds include complete composite geometry, not only anchors")

func test_dormant_frame_never_materializes_village_content() -> void:
	var program := VillageProgram.compile({}, EnvironmentCatalog.load_default())
	assert_null(VillagePlan.new(91, program).record_for(_frame(0)))

func test_reported_seed_builds_an_inhabited_dense_multilevel_village() -> void:
	var seed_value := 2697992464
	var water := TerrainWorldTuning.make_water(seed_value)
	var heightfield := TerrainWorldTuning.make_heightfield(seed_value, water)
	var feature_program := FeatureProgram.compile(
		EnvironmentCatalog.load_default())
	assert_not_null(feature_program)
	var fields := WorldFieldBlockCache.new(heightfield, water,
		feature_program.query_margin, feature_program.shore_distance_limit,
		feature_program.field_cache_cap)
	var settlements := SettlementPlan.new(seed_value, water)
	var world := WorldFeaturePlan.new(seed_value, water, fields,
		feature_program, settlements)
	var frame := world.frame_for(Vector2i(0, -1))
	assert_not_null(frame)
	var record := world.village_plan().record_for(frame)
	assert_not_null(record)
	assert_eq(record.stable_id, &"settlement.29bc5c240c52f84a")
	assert_true(VillageProgram.PRODUCTION_TIERS.has(record.tier))
	assert_true(record.urban_fabric.accepted,
		String(record.urban_fabric.reason))
	if not record.urban_fabric.accepted:
		return
	assert_eq(record.urban_fabric.generation_kind,
		VillageUrbanFabricPlan.GenerationKind.VOLUMETRIC_WARREN)
	var audit := record.urban_fabric.fabric_audit
	assert_gte(int(audit.building_stack_count), 7)
	assert_gte(int(audit.vertical_span_cells), 3)
	assert_gt(int(audit.stair_count), 0)
	assert_eq(int(audit.enclosed_skywalk_count),
		WarrenSpatialFeatureSolver.TARGET_SKYWALKS)
	assert_eq(int(audit.covered_market_count), 1)
	assert_eq(int(audit.elevated_courtyard_count), 1)
	assert_eq(int(audit.courtyard_bridge_house_count), 1)
	assert_gte(int(audit.courtyard_bridge_house_lower_public_column_count), 2)
	assert_gte(int(audit.courtyard_below_route_cell_count),
		WarrenSpatialFeatureSolver.MIN_COURT_BELOW_ROUTE_CELLS)
	assert_gte(int(audit.courtyard_upper_route_cell_count),
		WarrenSpatialFeatureSolver.MIN_COURT_UPPER_ROUTE_CELLS)
	assert_gte(int(audit.courtyard_daylight_macro_column_count),
		WarrenElevatedFrontageSolver.MIN_COURTYARD_DAYLIGHT_COLUMNS)
	assert_gt(int(audit.courtyard_daylight_air_cell_count), 0,
		"the in-game court keeps a typed open-air shaft through final validation")
	assert_eq(int(audit.prefab_landmark_count),
		WarrenSpatialFeatureSolver.TARGET_PREFAB_LANDMARKS)
	assert_gte(int(audit.usable_balcony_count),
		WarrenSpatialFeatureSolver.TARGET_BALCONIES)
	assert_gte(int(audit.room_outcropping_count),
		WarrenSpatialFeatureSolver.TARGET_ROOM_OUTCROPPINGS)
	assert_eq(int(audit.detached_building_stack_count), 0)
	assert_eq(int(audit.stair_endpoint_gap_count), 0)
	assert_eq(int(audit.stair_endpoint_missing_landing_count), 0)
	assert_gte(record.payload.instance_count, 200,
		"the reported site cannot regress to a tent-and-spit payload")
