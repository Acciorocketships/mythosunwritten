extends GutTest


func test_measured_room_units_preserve_every_spatial_stamp() -> void:
	var program := SettlementFabricProgram.compile(
		EnvironmentCatalog.load_default())
	assert_not_null(program)
	var spatial := WarrenVolumetricSolver.solve(7, {}, program)
	assert_not_null(spatial, WarrenVolumetricSolver.last_failure)
	if program == null or spatial == null:
		return
	var realm := WarrenSpatialPublicRealmAdapter.from_spatial(spatial)
	assert_not_null(realm, WarrenSpatialPublicRealmAdapter.last_failure)
	var units := WarrenSpatialFabricCompiler.compile_room_units(spatial, program)
	assert_gt(units.size(), 0, WarrenSpatialFabricCompiler.last_failure)
	assert_gt(int(WarrenSpatialFabricCompiler.last_audit \
		.selected_facade_phase_b_count), 0,
		"some upper storeys should retain the alternate authored facade phase")
	assert_gt(int(WarrenSpatialFabricCompiler.last_audit \
		.facade_phase_a_count), 0,
		"the town should not synchronize onto one facade phase")
	assert_gt(int(WarrenSpatialFabricCompiler.last_audit \
		.physical_support_redirect_count), 0,
		"offset upper rooms must bind to their actual 3D bearing parent")
	assert_eq(int(WarrenSpatialFabricCompiler.last_audit \
		.desired_facade_phase_b_count),
		int(WarrenSpatialFabricCompiler.last_audit \
			.selected_facade_phase_b_count) \
			+ int(WarrenSpatialFabricCompiler.last_audit \
				.facade_phase_fallback_count))
	var expected := 0
	for building: WarrenBuildingVolume in spatial.buildings:
		expected += building.room_records.size()
	assert_eq(units.size(), expected)
	var fabric := SettlementFabricPlan.new(&"spatial.room-proof")
	for recipe: FabricRecipe in program.recipes():
		assert_true(fabric.register_recipe(recipe))
	for unit: FabricUnit in units:
		assert_true(fabric.add_unit(unit), fabric.last_rejection)
	var features := WarrenSpatialFabricCompiler.compile_feature_units(spatial,
		program, units)
	assert_gt(features.size(), 0, WarrenSpatialFabricCompiler.last_failure)
	var expected_feature_units := 0
	var expected_feature_cells := 0
	var constructed_features := 0
	var constructed_skywalks := 0
	var constructed_markets := 0
	var constructed_balconies := 0
	var constructed_tower_annexes := 0
	var constructed_landmarks := 0
	for feature: WarrenFeatureReservation in spatial.features:
		if feature.construction_records.is_empty():
			continue
		constructed_features += 1
		constructed_skywalks += int(feature.kind == &"enclosed_skywalk")
		constructed_markets += int(feature.kind == &"covered_market")
		constructed_balconies += int(feature.kind == &"balcony")
		constructed_tower_annexes += int(feature.kind == &"tower_annex")
		constructed_landmarks += int(feature.kind == &"prefab_landmark")
		expected_feature_units += feature.construction_records.size()
		expected_feature_cells += feature.reserved_cells.size()
	assert_eq(features.size(), expected_feature_units)
	assert_eq(int(WarrenSpatialFabricCompiler.last_audit \
		.realized_constructed_feature_count), constructed_features)
	assert_eq(int(WarrenSpatialFabricCompiler.last_audit.skywalk_feature_count),
		constructed_skywalks)
	assert_eq(int(WarrenSpatialFabricCompiler.last_audit \
		.covered_market_feature_count), constructed_markets)
	assert_eq(constructed_markets, 1)
	assert_eq(int(WarrenSpatialFabricCompiler.last_audit \
		.balcony_feature_count), constructed_balconies)
	assert_gte(constructed_balconies,
		WarrenSpatialFeatureSolver.TARGET_BALCONIES)
	assert_eq(int(WarrenSpatialFabricCompiler.last_audit \
		.tower_annex_feature_count), constructed_tower_annexes)
	assert_eq(constructed_tower_annexes,
		spatial.audit.tall_tower_only_lineage_ids.size() \
			* WarrenSpatialFeatureSolver.MIN_TOWER_ANNEXES_PER_TALL_LINEAGE)
	assert_eq(int(WarrenSpatialFabricCompiler.last_audit \
		.prefab_landmark_feature_count), constructed_landmarks)
	assert_eq(constructed_landmarks,
		WarrenSpatialFeatureSolver.TARGET_PREFAB_LANDMARKS)
	assert_eq(int(WarrenSpatialFabricCompiler.last_audit \
		.feature_reserved_cell_count), expected_feature_cells)
	for feature_unit: FabricUnit in features:
		var feature_recipe := program.recipe(feature_unit.recipe_id)
		assert_true(feature_recipe.has_tag(&"skywalk") \
			or feature_recipe.has_tag(&"covered_market") \
			or feature_recipe.has_tag(&"balcony") \
			or feature_recipe.has_tag(&"outcropping") \
			or feature_recipe.has_tag(&"prefab_anchor"))
		assert_true(fabric.add_unit(feature_unit), fabric.last_rejection)
	var roofs := WarrenSpatialFabricCompiler.compile_roof_units(spatial,
		program, units, features)
	assert_gt(roofs.size(), 0, WarrenSpatialFabricCompiler.last_failure)
	assert_eq(WarrenSpatialFabricCompiler.last_audit.source_roof_face_count,
		WarrenSpatialFabricCompiler.last_audit.realized_roof_face_count)
	assert_eq(int(WarrenSpatialFabricCompiler.last_audit.roof_unit_count),
		roofs.size())
	assert_gt(int(WarrenSpatialFabricCompiler.last_audit.pitched_roof_count), 0)
	assert_gt(int(WarrenSpatialFabricCompiler.last_audit.rejected_pitched_count), 0)
	assert_gt(int(WarrenSpatialFabricCompiler.last_audit.setback_cap_unit_count), 0)
	assert_gt(int(WarrenSpatialFabricCompiler.last_audit \
		.setback_terrace_unit_count), 0,
		"exposed setback ledges should receive measured terrace treatments")
	assert_lt(int(WarrenSpatialFabricCompiler.last_audit \
		.setback_terrace_unit_count),
		int(WarrenSpatialFabricCompiler.last_audit.setback_cap_unit_count),
		"terraces must remain varied rather than railing every roof edge")
	assert_eq(int(WarrenSpatialFabricCompiler.last_audit \
		.setback_terrace_fallback_count), 0)
	for roof: FabricUnit in roofs:
		assert_true(fabric.add_unit(roof), fabric.last_rejection)
	var sealed := WarrenSpatialFabricCompiler.solve(spatial, program)
	assert_not_null(sealed, WarrenSpatialFabricCompiler.last_failure)
	if sealed != null:
		assert_true(sealed.is_sealed())
		assert_eq(sealed.audit.generation_source, &"spatial_volumetric_warren")
		assert_gt(int(sealed.audit.selected_facade_phase_b_count), 0)
		assert_eq(sealed.visual_envelope_conflicts().size(), 0)
