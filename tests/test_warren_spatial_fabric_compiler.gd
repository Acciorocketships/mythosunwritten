extends GutTest


func test_roof_gate_checks_the_candidate_full_3d_solid_volume() -> void:
	var grid := WarrenSpatialGrid.new(Vector3i(-2, 0, -2),
		Vector3i(5, 5, 5))
	var transaction := grid.begin_transaction(&"test.elevated-route-air")
	assert_true(transaction.assign_use([Vector3i(0, 2, 0)] as Array[Vector3i],
		WarrenSpatialGrid.Use.PUBLIC_AIR, &"route.air"))
	assert_true(transaction.commit())
	var recipe := FabricRecipe.new(&"test.two-band-roof", [&"roof"], 0)
	recipe.solid_cells = [Vector3i.ZERO,
		Vector3i.UP * 2] as Array[Vector3i]
	var unit := FabricUnit.new(&"test.roof", recipe.recipe_id,
		Vector3i.ZERO, 0)
	assert_true(WarrenSpatialFabricCompiler._unit_touches_public_air(grid,
		unit, recipe),
		"a clear first band must not hide a taller gable entering route air")
	unit.lattice_origin = Vector3i.RIGHT
	assert_false(WarrenSpatialFabricCompiler._unit_touches_public_air(grid,
		unit, recipe))


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
	var expected_portals := _expected_feature_portals(spatial)
	assert_gt((expected_portals.rooms as Dictionary).size(), 0,
		"the reviewed seed must exercise topology-driven room portals")
	assert_eq(int(WarrenSpatialFabricCompiler.last_audit \
		.feature_portal_room_count),
		(expected_portals.rooms as Dictionary).size())
	assert_eq(int(WarrenSpatialFabricCompiler.last_audit \
		.feature_portal_opening_count),
		(expected_portals.openings as Dictionary).size())
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
	var portal_unit_count := 0
	for unit: FabricUnit in units:
		var room_id := StringName(String(unit.stable_id).trim_prefix(
			"spatial.fabric."))
		var room_recipe := program.recipe(unit.recipe_id)
		var expected_portal := (expected_portals.rooms as Dictionary).has(room_id)
		assert_eq(room_recipe.has_tag(&"feature_portal"), expected_portal,
			"only rooms named by sealed balcony/skywalk endpoints may open")
		portal_unit_count += int(room_recipe.has_tag(&"feature_portal"))
	assert_eq(portal_unit_count,
		(expected_portals.rooms as Dictionary).size())
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
	var constructed_courtyard_bridges := 0
	var constructed_markets := 0
	var constructed_balconies := 0
	var constructed_outcropping_supports := 0
	var constructed_frontier_gateway_supports := 0
	var constructed_tower_annexes := 0
	var constructed_landmarks := 0
	for feature: WarrenFeatureReservation in spatial.features:
		if feature.construction_records.is_empty():
			continue
		constructed_features += 1
		constructed_skywalks += int(feature.kind == &"enclosed_skywalk")
		constructed_courtyard_bridges += int(
			feature.kind == &"courtyard_bridge_house")
		constructed_markets += int(feature.kind == &"covered_market")
		constructed_balconies += int(feature.kind == &"balcony")
		constructed_outcropping_supports += int(
			feature.kind == &"room_outcropping")
		constructed_frontier_gateway_supports += int(
			feature.kind == &"frontier_gateway_support")
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
		.courtyard_bridge_house_feature_count), constructed_courtyard_bridges)
	assert_eq(constructed_courtyard_bridges, 1,
		"the elevated court must have one measured occupied cantilever wall")
	assert_eq(int(WarrenSpatialFabricCompiler.last_audit \
		.covered_market_feature_count), constructed_markets)
	assert_eq(constructed_markets, 1)
	assert_eq(int(WarrenSpatialFabricCompiler.last_audit \
		.balcony_feature_count), constructed_balconies)
	assert_gte(constructed_balconies,
		WarrenSpatialFeatureSolver.TARGET_BALCONIES)
	assert_eq(int(WarrenSpatialFabricCompiler.last_audit \
		.room_outcropping_support_feature_count),
		constructed_outcropping_supports)
	assert_gte(constructed_outcropping_supports,
		WarrenSpatialFeatureSolver.TARGET_ROOM_OUTCROPPINGS)
	assert_eq(int(WarrenSpatialFabricCompiler.last_audit \
		.frontier_gateway_support_feature_count),
		constructed_frontier_gateway_supports)
	assert_eq(int(WarrenSpatialFabricCompiler.last_audit \
		.tower_annex_feature_count), constructed_tower_annexes)
	assert_eq(constructed_tower_annexes,
		int(spatial.audit.required_tower_annex_count))
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
			or feature_recipe.has_tag(&"cantilever_support") \
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
	assert_gt(int(WarrenSpatialFabricCompiler.last_audit \
		.dormered_pitched_roof_count), 0,
		"the accepted town should retain integrated roof dormers")
	assert_gt(int(WarrenSpatialFabricCompiler.last_audit.rejected_pitched_count), 0)
	assert_gt(int(WarrenSpatialFabricCompiler.last_audit.setback_cap_unit_count), 0)
	assert_gt(int(WarrenSpatialFabricCompiler.last_audit \
		.setback_terrace_unit_count), 0,
		"exposed setback ledges should receive measured terrace treatments")
	assert_gt(int(WarrenSpatialFabricCompiler.last_audit \
		.setback_terrace_unit_count) * 2,
		int(WarrenSpatialFabricCompiler.last_audit.setback_cap_unit_count),
		"measured rail terraces should dominate bare upper-storey shelves")
	assert_lt(int(WarrenSpatialFabricCompiler.last_audit \
		.setback_terrace_unit_count),
		int(WarrenSpatialFabricCompiler.last_audit.setback_cap_unit_count),
		"terraces must remain varied rather than railing every roof edge")
	assert_eq(int(WarrenSpatialFabricCompiler.last_audit \
		.setback_plain_cap_unit_count),
		int(WarrenSpatialFabricCompiler.last_audit.setback_cap_unit_count) \
			- int(WarrenSpatialFabricCompiler.last_audit \
				.setback_terrace_unit_count) \
			- int(WarrenSpatialFabricCompiler.last_audit \
				.setback_garden_unit_count))
	assert_gt(int(WarrenSpatialFabricCompiler.last_audit \
		.setback_dressed_unit_count),
		int(WarrenSpatialFabricCompiler.last_audit.setback_terrace_unit_count),
		"enclosed setback bands should gain measured roof gardens")
	assert_eq(int(WarrenSpatialFabricCompiler.last_audit \
		.setback_terrace_fallback_count), 0)
	assert_eq(int(WarrenSpatialFabricCompiler.last_audit \
		.bare_flat_roof_count), 0,
		"collision pressure must not turn a roof into an undressed plank cube")
	for roof: FabricUnit in roofs:
		var roof_recipe := program.recipe(roof.recipe_id)
		for local_cell: Vector3i in roof_recipe.solid_cells:
			var world_cell := FabricRecipe.transform_cell(local_cell,
				roof.lattice_origin, roof.yaw_quarters)
			assert_ne(spatial.grid.use_at(world_cell),
				WarrenSpatialGrid.Use.PUBLIC_AIR,
				"measured roof volume may not enter an elevated route's headroom")
		assert_true(fabric.add_unit(roof), fabric.last_rejection)
	var sealed := WarrenSpatialFabricCompiler.solve(spatial, program)
	assert_not_null(sealed, WarrenSpatialFabricCompiler.last_failure)
	if sealed != null:
		assert_true(sealed.is_sealed())
		assert_eq(sealed.audit.generation_source, &"spatial_volumetric_warren")
		assert_eq(int(sealed.audit.detached_building_stack_count), 0,
			"spatial private-parent chains must all reach served thresholds")
		assert_eq(int(sealed.audit.building_stack_count),
			spatial.buildings.size() \
				+ int(spatial.audit.spatial_prefab_landmark_building_count))
		assert_eq(int(sealed.audit.spatial_missing_private_parent_count), 0)
		assert_gt(int(sealed.audit.legacy_unit_group_detached_building_stack_count),
			0, "the legacy grouping remains visible as a non-authoritative diagnostic")
		assert_gt(int(sealed.audit.selected_facade_phase_b_count), 0)
		assert_eq(sealed.visual_envelope_conflicts().size(), 0)


func _expected_feature_portals(spatial: WarrenSpatialPlan) -> Dictionary:
	var rooms: Dictionary = {}
	var openings: Dictionary = {}
	for feature: WarrenFeatureReservation in spatial.features:
		if feature.construction_records.is_empty():
			continue
		if feature.kind == &"balcony":
			var room_id := StringName(feature.audit.get("balcony_room_id", &""))
			var facing := feature.audit.get("balcony_endpoint_facing",
				Vector3i.ZERO) as Vector3i
			_add_expected_portal(rooms, openings, room_id, facing)
		elif feature.kind == &"courtyard_bridge_house":
			_add_expected_portal(rooms, openings, StringName(feature.audit.get(
				"courtyard_bridge_house_room_id", &"")), feature.audit.get(
				"courtyard_bridge_house_endpoint_facing",
				Vector3i.ZERO) as Vector3i)
		elif feature.kind == &"enclosed_skywalk":
			for binding_value: Variant in feature.audit.get(
					"skywalk_endpoint_bindings", []):
				var binding := binding_value as Dictionary
				if StringName(binding.get("endpoint_kind", &"room")) != &"room":
					continue
				_add_expected_portal(rooms, openings,
					StringName(binding.get("room_id", &"")),
					binding.get("facing", Vector3i.ZERO) as Vector3i)
	return {"rooms": rooms, "openings": openings}


func _add_expected_portal(rooms: Dictionary, openings: Dictionary,
		room_id: StringName, facing: Vector3i) -> void:
	assert_false(room_id.is_empty())
	assert_eq(absi(facing.x) + absi(facing.z), 1)
	assert_eq(facing.y, 0)
	rooms[room_id] = true
	openings["%s/%d:%d" % [room_id, facing.x, facing.z]] = true
