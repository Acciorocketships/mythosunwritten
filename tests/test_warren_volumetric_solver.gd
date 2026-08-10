extends GutTest

static var _program_cache: SettlementFabricProgram


func _program() -> SettlementFabricProgram:
	if _program_cache == null:
		_program_cache = SettlementFabricProgram.compile(
			EnvironmentCatalog.load_default())
	return _program_cache


func test_seed_seven_becomes_a_sealed_fine_grid_town() -> void:
	var plan := WarrenVolumetricSolver.solve(7, {}, _program())
	assert_not_null(plan, WarrenVolumetricSolver.last_failure)
	if plan == null:
		return
	assert_true(plan.is_sealed())
	assert_eq(int(plan.audit.allocatable_cell_count), 0)
	assert_gte(int(plan.audit.building_count), 10)
	assert_gte(int(plan.audit.public_route_floor_count), 20)
	assert_gte(int(plan.audit.route_vertical_span_bands), 8)
	assert_eq(int(plan.audit.unclassified_public_private_face_count), 0)
	assert_eq(int(plan.audit.missing_roof_face_count), 0)
	assert_eq(int(plan.audit.elevated_courtyard_count), 1)
	assert_eq(int(plan.audit.enclosed_skywalk_count),
		WarrenSpatialFeatureSolver.TARGET_SKYWALKS)
	assert_gte(int(plan.audit.room_outcropping_count),
		WarrenSpatialFeatureSolver.TARGET_ROOM_OUTCROPPINGS)
	assert_not_null(plan.construction_plan)
	assert_gt(int(plan.construction_plan.audit.roof_region_count), 0)
	for building: WarrenBuildingVolume in plan.buildings:
		assert_lte(int(building.audit.longest_identical_floorplate_run),
			WarrenBuildingVolume.MAX_IDENTICAL_FLOORPLATE_RUN)
		assert_gt(building.room_records.size(), 0)
		for room: WarrenRoomStamp in building.room_records:
			assert_true(room.is_sealed())
			assert_true(room.kind in WarrenRoomStamp.KINDS)
	_assert_composed_spatial_features(plan)


func test_volumetric_solve_is_deterministic() -> void:
	var first := WarrenVolumetricSolver.solve(7, {}, _program())
	var repeated := WarrenVolumetricSolver.solve(7, {}, _program())
	assert_not_null(first, WarrenVolumetricSolver.last_failure)
	assert_not_null(repeated, WarrenVolumetricSolver.last_failure)
	if first != null and repeated != null:
		assert_eq(first.deterministic_signature(),
			repeated.deterministic_signature())


func _assert_composed_spatial_features(plan: WarrenSpatialPlan) -> void:
	var courts: Array[WarrenFeatureReservation] = []
	var skywalks: Array[WarrenFeatureReservation] = []
	var outcroppings: Array[WarrenFeatureReservation] = []
	for feature: WarrenFeatureReservation in plan.features:
		match feature.kind:
			&"third_storey_courtyard":
				courts.append(feature)
			&"enclosed_skywalk":
				skywalks.append(feature)
			&"room_outcropping":
				outcroppings.append(feature)
	assert_eq(courts.size(), 1)
	if not courts.is_empty():
		var court := courts[0]
		assert_gte(int(court.audit.courtyard_floor_cell_count), 16)
		assert_gte(int(court.audit.courtyard_addressed_side_count), 3)
		assert_gte(int(court.audit.courtyard_below_route_cell_count), 4)
		assert_gte(int(court.audit.courtyard_upper_route_cell_count), 2)
	assert_eq(skywalks.size(), WarrenSpatialFeatureSolver.TARGET_SKYWALKS)
	var endpoint_pairs: Dictionary = {}
	var corner_count := 0
	for skywalk: WarrenFeatureReservation in skywalks:
		assert_eq(skywalk.endpoints.size(), 2)
		assert_gte(skywalk.construction_records.size(), 1)
		assert_gte(int(skywalk.audit.skywalk_lower_public_column_count), 2)
		assert_gte(int(skywalk.audit.skywalk_offset_endpoint_count), 1)
		var pair_key := String(skywalk.audit.skywalk_endpoint_pair_key)
		assert_false(endpoint_pairs.has(pair_key),
			"two skywalks reused the same exact endpoint pair")
		endpoint_pairs[pair_key] = true
		corner_count += int(skywalk.audit.skywalk_kind == &"corner")
		var owner_ids: Dictionary = {}
		for endpoint: Dictionary in skywalk.endpoints:
			var owner_id := StringName(endpoint.owner_id)
			owner_ids[owner_id] = true
			var building: WarrenBuildingVolume
			for candidate: WarrenBuildingVolume in plan.buildings:
				if candidate.stable_id == owner_id:
					building = candidate
					break
			assert_not_null(building)
			if building != null:
				assert_true(building.feature_ids.has(skywalk.stable_id))
		assert_eq(owner_ids.size(), 2)
		for cell: Vector3i in skywalk.reserved_cells:
			assert_eq(plan.grid.use_at(cell),
				WarrenSpatialGrid.Use.PRIVATE_VOLUME)
			assert_eq(plan.grid.owner_name_at(cell), skywalk.stable_id)
	assert_gte(corner_count, 1,
		"the seed-seven proof should retain a visibly turning skywalk")
	assert_gte(outcroppings.size(),
		WarrenSpatialFeatureSolver.TARGET_ROOM_OUTCROPPINGS)
	var outcrop_owners: Dictionary = {}
	for outcrop: WarrenFeatureReservation in outcroppings:
		assert_eq(outcrop.endpoints.size(), 1)
		assert_gte(int(outcrop.audit.outcrop_room_footprint_column_count), 4)
		assert_gte(int(outcrop.audit.outcrop_extension_column_count), 1)
		outcrop_owners[StringName(outcrop.endpoints[0].owner_id)] = true
	assert_gte(outcrop_owners.size(),
		WarrenSpatialFeatureSolver.TARGET_ROOM_OUTCROPPINGS)
