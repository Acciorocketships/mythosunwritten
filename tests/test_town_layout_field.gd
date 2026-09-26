extends GutTest

func test_towns_share_a_continuously_varied_mass_field() -> void:
	var signatures := {}
	for seed_value in range(1, 17):
		var massif := WarrenMassifBuilder.build(seed_value, {}, WarrenVillageScaleProfile.for_id(&"standard"))
		assert_eq(massif.form_id, &"mixture", "one field grammar instead of choosing a named town form")
		assert_true(massif.validate_construction(), massif.last_rejection)
		var heights := {}
		for column: Vector2i in massif.columns: heights[massif.layer_at(column)] = true
		assert_gte(heights.size(), 3)
		signatures[hash(massif.columns)] = true
	assert_eq(signatures.size(), 16)

func test_reclaimed_courts_join_only_real_walk_landings() -> void:
	for seed_value in range(1, 13):
		var source := WarrenMazeSitePlanner.plan(seed_value, {}, WarrenVillageScaleProfile.for_id(&"compact"), &"", false)
		assert_not_null(source)
		if source == null: continue
		var volume := WarrenMazeVolumeAdapter.to_volume_plan(source)
		assert_not_null(volume, WarrenMazeVolumeAdapter.last_failure)

func test_new_room_projection_reserves_its_bracket_below_the_floor() -> void:
	var original := {Vector2i.ZERO: true}
	var candidate := {"origin": Vector3i(0, 6, 0), "columns": {Vector2i.ZERO: true, Vector2i.RIGHT: true}}
	var market := {Vector3i(1, 5, 0): {&"spatial.feature.market.00": true}}
	assert_false(WarrenRoomCompositionPlanner._new_projection_has_clearance(candidate, original, market, {}, {&"house": true}))
	assert_true(WarrenRoomCompositionPlanner._new_projection_has_clearance(candidate, original, {}, {}, {&"house": true}))

func test_retained_boolean_cells_do_not_masquerade_as_tagged_stone() -> void:
	var garden := {Vector3i.ZERO: true, Vector3i.RIGHT: true, Vector3i.BACK: true}
	var missing := Vector3i(1, 0, 1)
	var result := SettlementFabricAssembler.close_borne_turf_corners(garden,
		{missing: true}, {}, {}, {}, {"exposed": {}}, {})
	assert_eq(result, garden)

func test_same_size_budget_contains_both_open_and_dense_fields() -> void:
	var least := 1.0
	var most := 0.0
	var small := 100000
	var large := 0
	var field_script := preload("res://scripts/terrain/features/villages/fabric/WarrenTownField.gd")
	for seed_value in range(1, 129):
		var field := field_script.sample(seed_value, WarrenVillageScaleProfile.for_id(&"grand"))
		var bounds := BuildingDesigner._bounds(field.solid)
		var fill := float(field.solid.size()) / bounds.get_area()
		least = minf(least, fill)
		most = maxf(most, fill)
		small = mini(small, field.solid.size())
		large = maxi(large, field.solid.size())
	assert_lt(least, 0.45, "large towns can have broad gaps between lobes")
	assert_gt(most, 0.65, "dense towns remain in the same distribution")
	assert_gt(large, small * 2, "a size budget must not prescribe one filled footprint")

func test_source_voids_keep_existing_public_route_ownership() -> void:
	# Expanded room/stair envelopes retain source air, including air already
	# claimed by the fine route. Two empty-space owners must not reject a town.
	var source := WarrenMazeSitePlanner.plan(4, {}, WarrenVillageScaleProfile.for_id(&"large"), &"", false)
	var volume := WarrenMazeVolumeAdapter.to_volume_plan(source)
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := WarrenVolumetricSolver.from_volume(volume, -1, program, false, true)
	assert_not_null(spatial, WarrenVolumetricSolver.last_failure)
