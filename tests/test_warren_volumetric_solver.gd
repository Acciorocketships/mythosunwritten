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
	assert_eq(int(plan.audit.covered_market_count), 1)
	assert_eq(int(plan.audit.prefab_landmark_count),
		WarrenSpatialFeatureSolver.TARGET_PREFAB_LANDMARKS)
	assert_eq(int(plan.audit.enclosed_skywalk_count),
		WarrenSpatialFeatureSolver.TARGET_SKYWALKS)
	assert_eq(int(plan.audit.tower_annex_count),
		plan.audit.tall_tower_only_lineage_ids.size() \
			* WarrenSpatialFeatureSolver.MIN_TOWER_ANNEXES_PER_TALL_LINEAGE,
		"annexes are a repair grammar only for residual tall tower lineages")
	assert_gte(int(plan.audit.usable_balcony_count),
		WarrenSpatialFeatureSolver.TARGET_BALCONIES)
	assert_gte(int(plan.audit.balcony_building_count),
		WarrenSpatialFeatureSolver.MIN_BALCONY_BUILDINGS)
	assert_gte(int(plan.audit.room_outcropping_count),
		WarrenSpatialFeatureSolver.TARGET_ROOM_OUTCROPPINGS)
	assert_gte(int(plan.audit.merged_upper_composition_count), 4,
		"at least one upper plate must cross original parcel lineages")
	assert_gte(int(plan.audit.coupled_upper_composition_count), 6,
		"neighboring lineages must exchange upper mass in the 3D solve")
	assert_gte(int(plan.audit.expanded_upper_composition_count), 30,
		"upper rooms should occupy free 3D massif cells beyond their 2D parcels")
	assert_gte(int(plan.audit.upper_recomposition_count), 45,
		"the upper town must be materially recomposed in three dimensions")
	assert_gte(int(plan.audit.varied_room_block_count), 35,
		"many blocks must change footprint, orientation, or room family")
	assert_gte(int(plan.audit.mixed_kind_tall_lineage_count), 10,
		"tall construction must change room size/kind across height")
	assert_eq(plan.audit.tall_tower_only_lineage_ids, [],
		"the primary 3D composition must eliminate every residual tall shaft")
	assert_eq(int(plan.audit.extruded_tall_lineage_count), 0,
		"no tall source lineage may repeat one world-space floorplate")
	assert_eq(plan.audit.extruded_tall_lineage_ids, [],
		"the audit must identify no repeated world-space extrusion")
	assert_lte(int(plan.audit.max_identical_tower_floorplate_run_storeys), 2,
		"interface constraints must not force a repeated multi-storey shaft")
	var consecutive_pairs := int(plan.audit.consecutive_floorplate_pair_count)
	assert_gt(consecutive_pairs, 0)
	assert_lte(int(plan.audit.strongly_registered_floorplate_pair_count) * 2,
		consecutive_pairs,
		"fewer than half of vertical room seams may retain two facade planes")
	assert_lte(int(plan.audit.registered_facade_plane_count) * 2,
		consecutive_pairs * 3,
		"vertical room seams should retain at most 1.5 facade planes on average")
	assert_lte(int(plan.audit.same_ridge_axis_floorplate_pair_count) * 5,
		consecutive_pairs * 3,
		"at least two fifths of consecutive rooms should turn their roof axis")
	assert_not_null(plan.construction_plan)
	assert_gt(int(plan.construction_plan.audit.roof_region_count), 0)
	for building: WarrenBuildingVolume in plan.buildings:
		assert_lte(int(building.audit.longest_identical_floorplate_run),
			WarrenBuildingVolume.MAX_IDENTICAL_FLOORPLATE_RUN)
		assert_gt(building.room_records.size(), 0)
		for threshold: Dictionary in building.thresholds:
			var landing := threshold.public_cell as Vector3i
			assert_has(plan.route_floor_cells, landing,
				"every public doorway must land on an authoritative route floor")
			assert_eq(int(plan.grid.face_claim(landing,
				Vector3i.DOWN).get("kind", -1)),
				WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR)
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
	var markets: Array[WarrenFeatureReservation] = []
	var balconies: Array[WarrenFeatureReservation] = []
	var tower_annexes: Array[WarrenFeatureReservation] = []
	var landmarks: Array[WarrenFeatureReservation] = []
	var outcroppings: Array[WarrenFeatureReservation] = []
	for feature: WarrenFeatureReservation in plan.features:
		match feature.kind:
			&"third_storey_courtyard":
				courts.append(feature)
			&"enclosed_skywalk":
				skywalks.append(feature)
			&"covered_market":
				markets.append(feature)
			&"balcony":
				balconies.append(feature)
			&"tower_annex":
				tower_annexes.append(feature)
			&"prefab_landmark":
				landmarks.append(feature)
			&"room_outcropping":
				outcroppings.append(feature)
	assert_eq(courts.size(), 1)
	if not courts.is_empty():
		var court := courts[0]
		assert_gte(int(court.audit.courtyard_floor_cell_count), 16)
		assert_gte(int(court.audit.courtyard_addressed_side_count), 3)
		assert_gte(int(court.audit.courtyard_below_route_cell_count), 4)
		assert_gte(int(court.audit.courtyard_upper_route_cell_count), 2)
	assert_eq(markets.size(), 1)
	assert_eq(landmarks.size(),
		WarrenSpatialFeatureSolver.TARGET_PREFAB_LANDMARKS)
	var landmark_recipes: Dictionary = {}
	var landmark_ids: Dictionary = {}
	for landmark: WarrenFeatureReservation in landmarks:
		landmark_ids[landmark.stable_id] = landmark
		assert_eq(landmark.endpoints.size(), 1)
		assert_eq(landmark.construction_records.size(), 1)
		assert_gt(landmark.terrain_bearing_cells.size(), 0)
		var recipe_id := StringName(landmark.construction_records[0].recipe_id)
		assert_true(String(recipe_id).begins_with("anchor.prefab."))
		assert_false(landmark_recipes.has(recipe_id),
			"landmarks must use distinct authored prefab recipes")
		landmark_recipes[recipe_id] = true
		assert_true(bool(landmark.audit.landmark_publicly_addressed))
		assert_true(bool(landmark.audit.landmark_terrain_rooted))
		var entrance := landmark.audit.landmark_entrance_cell as Vector3i
		var landing := landmark.audit.landmark_public_landing_cell as Vector3i
		assert_eq(StringName(landmark.endpoints[0].owner_id), landmark.stable_id)
		assert_eq(landmark.endpoints[0].cell as Vector3i, entrance)
		assert_eq(plan.grid.use_at(landing), WarrenSpatialGrid.Use.PUBLIC_AIR)
		assert_eq(int(plan.grid.face_claim(landing, Vector3i.DOWN).kind),
			WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR)
		assert_eq(int(plan.grid.face_claim(entrance, landing - entrance).kind),
			WarrenSpatialGrid.FaceKind.DOOR)
		for cell: Vector3i in landmark.terrain_bearing_cells:
			assert_true(plan.grid.reservation_owned_by(cell,
				WarrenSpatialGrid.Reservation.TERRAIN_BEARING,
				landmark.stable_id))
		for cell: Vector3i in landmark.reserved_cells:
			assert_eq(plan.grid.use_at(cell),
				WarrenSpatialGrid.Use.PRIVATE_VOLUME)
			assert_eq(plan.grid.owner_name_at(cell), landmark.stable_id)
	if not markets.is_empty():
		var market := markets[0]
		assert_gte(market.public_cells.size(), 4)
		assert_eq(market.endpoints.size(), 1)
		assert_eq(market.construction_records.size(), 1)
		assert_true(String(market.construction_records[0].recipe_id) \
			.begins_with("market.covered."))
		assert_eq(int(market.audit.market_stocked_bay_count), 2)
		assert_eq(int(market.audit.market_covered_aisle_cell_count), 4)
		assert_gte(int(market.audit.market_street_entrance_width), 2)
		assert_true(bool(market.audit.market_continuous_canopy))
		for cell: Vector3i in market.public_cells:
			assert_eq(plan.grid.use_at(cell), WarrenSpatialGrid.Use.PUBLIC_AIR)
			assert_true(plan.grid.reservation_owned_by(cell,
				WarrenSpatialGrid.Reservation.CONSTRUCTION_SEAM,
				market.stable_id))
			assert_eq(int(plan.grid.face_claim(cell, Vector3i.DOWN).kind),
				WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR)
		for cell: Vector3i in market.reserved_cells:
			assert_eq(plan.grid.use_at(cell),
				WarrenSpatialGrid.Use.STRUCTURAL_VOLUME)
			assert_eq(plan.grid.owner_name_at(cell), market.stable_id)
	assert_eq(skywalks.size(), WarrenSpatialFeatureSolver.TARGET_SKYWALKS)
	var endpoint_pairs: Dictionary = {}
	var corner_count := 0
	var landmark_link_count := 0
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
		landmark_link_count += int(
			int(skywalk.audit.get("skywalk_landmark_endpoint_count", 0)) > 0)
		var owner_ids: Dictionary = {}
		for endpoint: Dictionary in skywalk.endpoints:
			var owner_id := StringName(endpoint.owner_id)
			owner_ids[owner_id] = true
			if landmark_ids.has(owner_id):
				assert_true((landmark_ids[owner_id] \
					as WarrenFeatureReservation).reserved_cells.has(
						endpoint.cell as Vector3i))
				continue
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
	assert_gte(landmark_link_count, 1,
		"at least one true skywalk must terminate in a landmark socket")
	assert_gte(balconies.size(), WarrenSpatialFeatureSolver.TARGET_BALCONIES)
	assert_eq(tower_annexes.size(),
		plan.audit.tall_tower_only_lineage_ids.size() \
			* WarrenSpatialFeatureSolver.MIN_TOWER_ANNEXES_PER_TALL_LINEAGE,
		"decorative annexes must not substitute for spatial recomposition")
	var annex_source_counts: Dictionary = {}
	var annex_profiles: Dictionary = {}
	var annex_storeys_by_source: Dictionary = {}
	for annex: WarrenFeatureReservation in tower_annexes:
		assert_eq(annex.endpoints.size(), 1)
		assert_eq(annex.construction_records.size(), 1)
		assert_true(String(annex.construction_records[0].recipe_id) \
			.begins_with("outcrop."))
		assert_true(bool(annex.audit.annex_breaks_tower_lineage))
		var source_id := StringName(annex.audit.annex_source_parcel_id)
		annex_source_counts[source_id] = int(annex_source_counts.get(source_id,
			0)) + 1
		var profile_key := String(annex.audit.annex_relief_profile_key)
		assert_false(annex_profiles.has(profile_key),
			"one shaft must not repeat the same authored annex profile")
		annex_profiles[profile_key] = true
		var storey := int(annex.audit.annex_source_storey_index)
		assert_gte(storey, 1)
		if not annex_storeys_by_source.has(source_id):
			annex_storeys_by_source[source_id] = []
		(annex_storeys_by_source[source_id] as Array).append(storey)
		for cell: Vector3i in annex.reserved_cells:
			assert_eq(plan.grid.use_at(cell),
				WarrenSpatialGrid.Use.PRIVATE_VOLUME)
			assert_eq(plan.grid.owner_name_at(cell), annex.stable_id)
	for source_value: Variant in plan.audit.tall_tower_only_lineage_ids:
		var source_id := StringName(source_value)
		assert_eq(int(annex_source_counts.get(source_id, 0)),
			WarrenSpatialFeatureSolver.MIN_TOWER_ANNEXES_PER_TALL_LINEAGE,
			"each residual tall shaft needs two separated compound-room events")
		var storeys := annex_storeys_by_source[source_id] as Array
		assert_gte(absi(int(storeys[0]) - int(storeys[1])), 2,
			"compound annexes need at least one clear storey between them")
	var balcony_owners: Dictionary = {}
	var balcony_facades: Dictionary = {}
	for balcony: WarrenFeatureReservation in balconies:
		assert_eq(balcony.endpoints.size(), 1)
		assert_eq(balcony.construction_records.size(), 1)
		assert_true(String(balcony.construction_records[0].recipe_id) \
			.begins_with("balcony."))
		assert_eq(int(balcony.audit.balcony_usable_width_cells), 2)
		assert_eq(int(balcony.audit.balcony_usable_depth_cells), 1)
		assert_eq(int(balcony.audit.balcony_door_count), 1)
		assert_eq(int(balcony.audit.balcony_guard_segment_count), 4)
		assert_eq(balcony.audit.balcony_support_kind, &"bracket_cantilever")
		assert_eq(balcony.reserved_cells.size(), 4)
		var owner_id := StringName(balcony.audit.balcony_building_id)
		balcony_owners[owner_id] = true
		var facade_key := String(balcony.audit.balcony_facade_key)
		assert_false(balcony_facades.has(facade_key),
			"balconies repeat at equivalent vertical facade coordinates")
		balcony_facades[facade_key] = true
		for cell: Vector3i in balcony.reserved_cells:
			assert_eq(plan.grid.use_at(cell),
				WarrenSpatialGrid.Use.PRIVATE_VOLUME)
			assert_eq(plan.grid.owner_name_at(cell), balcony.stable_id)
	assert_gte(balcony_owners.size(),
		WarrenSpatialFeatureSolver.MIN_BALCONY_BUILDINGS)
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
