extends GutTest

static var _program_cache: SettlementFabricProgram


func _program() -> SettlementFabricProgram:
	if _program_cache == null:
		_program_cache = SettlementFabricProgram.compile(
			EnvironmentCatalog.load_default())
	return _program_cache


func test_landmark_skywalk_ranking_factorization_matches_exact_union() -> void:
	var skywalks: Array[Dictionary] = [
		{"pair_key": "a", "reservation": {"owner_parcel_ids": [&"p0"]},
			"body": {Vector3i(0, 0, 0): true}, "clearance": {},
			"priority_cells": {}},
		{"pair_key": "b", "reservation": {"owner_parcel_ids": [&"p1"]},
			"body": {}, "clearance": {Vector3i(10, 0, 0): true},
			"priority_cells": {}},
		{"pair_key": "c", "reservation": {"owner_parcel_ids": [&"p2"]},
			"body": {}, "clearance": {},
			"priority_cells": {Vector3i(20, 0, 0): &"p2"}},
	]
	var landmark_a := _rank_fixture_landmark(&"anchor.a", Vector3i.ZERO,
		{Vector3i(0, 0, 0): true}, {})
	var landmark_b := _rank_fixture_landmark(&"anchor.b", Vector3i(3, 0, 0),
		{Vector3i(10, 0, 0): true}, {&"p2": true})
	var sets: Array[Dictionary] = [
		_rank_fixture_set(&"a", [landmark_a] as Array[Dictionary]),
		_rank_fixture_set(&"b", [landmark_b] as Array[Dictionary]),
		_rank_fixture_set(&"ab", [landmark_a, landmark_b] \
			as Array[Dictionary]),
	]
	WarrenVolumetricSolver._rank_landmark_sets_for_skywalks(sets,
		skywalks, 1)
	for landmark_set: Dictionary in sets:
		var protected := WarrenVolumetricSolver._landmark_set_protected_cells(
			landmark_set.reservations as Array[Dictionary])
		var blocked := WarrenVolumetricSolver._landmark_set_blocker_parcels(
			landmark_set.reservations as Array[Dictionary])
		var exact_count := 0
		var exact_pairs: Dictionary = {}
		for skywalk: Dictionary in skywalks:
			if not WarrenVolumetricSolver._skywalk_candidate_avoids_landmarks(
					skywalk, protected, blocked):
				continue
			exact_count += 1
			exact_pairs[String(skywalk.pair_key)] = true
		assert_eq(int(landmark_set.skywalk_candidate_count), exact_count,
			"factored candidate count must equal the complete union test")
		assert_eq(int(landmark_set.skywalk_pair_count), exact_pairs.size(),
			"factored pair diversity must equal the complete union test")


func test_landmark_candidate_corpus_key_is_order_independent_and_exact() \
		-> void:
	var first := _rank_fixture_landmark(&"anchor.a", Vector3i.ZERO, {}, {})
	var second := _rank_fixture_landmark(&"anchor.b", Vector3i(3, 0, 0), {}, {})
	assert_eq(WarrenVolumetricSolver._landmark_candidate_corpus_key(
		[first, second] as Array[Dictionary]),
		WarrenVolumetricSolver._landmark_candidate_corpus_key(
			[second, first] as Array[Dictionary]))
	var moved := _rank_fixture_landmark(&"anchor.b", Vector3i(4, 0, 0), {}, {})
	assert_ne(WarrenVolumetricSolver._landmark_candidate_corpus_key(
		[first, second] as Array[Dictionary]),
		WarrenVolumetricSolver._landmark_candidate_corpus_key(
			[first, moved] as Array[Dictionary]),
		"a geometrically different candidate frontier must never reuse pairs")


func test_landmark_embeddedness_counts_only_surviving_city_mass() -> void:
	var landmark_cells := {Vector3i.ZERO: true}
	var protected_owners := {
		Vector3i(1, 0, 0): {&"east.house": true},
		Vector3i(0, 1, 2): {&"south.house": true},
		Vector3i(-1, 0, 0): {&"spatial.feature.market.00": true},
		Vector3i(0, 0, -1): {&"removed.house": true},
	}
	var audit := WarrenVolumetricSolver._landmark_embeddedness(
		landmark_cells, protected_owners, {&"removed.house": true})
	assert_eq(int(audit.side_count), 2,
		"only independently surviving houses embed a landmark side")
	assert_eq(int(audit.nearest_gap), 1)
	assert_eq((audit.owner_ids as Array).size(), 2)
	assert_has(audit.owner_ids, &"east.house")
	assert_has(audit.owner_ids, &"south.house")


func test_landmark_ranking_prefers_city_contact_before_parcel_preservation() \
		-> void:
	var detached := _rank_fixture_set(&"detached", [
		_rank_fixture_landmark(&"anchor.detached", Vector3i.ZERO, {}, {})] \
			as Array[Dictionary])
	detached.merge({"minimum_city_contact_side_count": 1,
		"city_contact_side_count": 1, "city_contact_score": 3,
		"maximum_city_gap": 4}, true)
	var embedded := _rank_fixture_set(&"embedded", [
		_rank_fixture_landmark(&"anchor.embedded", Vector3i(3, 0, 0), {}, {
			&"replaced.a": true, &"replaced.b": true})] as Array[Dictionary])
	embedded.merge({"minimum_city_contact_side_count": 3,
		"city_contact_side_count": 3, "city_contact_score": 12,
		"maximum_city_gap": 1, "displaced_parcel_count": 2}, true)
	var sets := [detached, embedded] as Array[Dictionary]
	WarrenVolumetricSolver._rank_landmark_sets_for_skywalks(sets,
		[] as Array[Dictionary], 0)
	assert_eq(StringName(sets[0].stable_id), &"embedded",
		"a landmark knit into the town outranks an open-lawn satellite")


func test_landmark_skywalk_coverage_counts_distinct_external_buildings() \
		-> void:
	var first := {"reservation": {"owner_parcel_ids": [
		&"spatial.feature.landmark.00", &"parcel.a"]}}
	var repeated := {"reservation": {"owner_parcel_ids": [
		&"parcel.b", &"spatial.feature.landmark.00"]}}
	var second := {"reservation": {"owner_parcel_ids": [
		&"spatial.feature.landmark.01", &"parcel.c"]}}
	var internal := {"reservation": {"owner_parcel_ids": [
		&"parcel.d", &"parcel.e"]}}
	assert_eq(WarrenVolumetricSolver._skywalk_landmark_coverage(
		[first, repeated, internal] as Array[Dictionary]).size(), 1,
		"two links into one landmark do not integrate the other landmark")
	assert_eq(WarrenVolumetricSolver._skywalk_landmark_coverage(
		[first, repeated, second, internal] as Array[Dictionary]).size(), 2,
		"each independently attached landmark contributes exactly once")


func test_landmark_transition_owners_are_deduplicated_and_stable() -> void:
	var landmarks := [
		{"transition_owner_ids": [&"parcel.z", &"parcel.a"]},
		{"transition_owner_ids": [&"parcel.a", &"parcel.m"]},
	] as Array[Dictionary]
	assert_eq(WarrenVolumetricSolver._landmark_transition_owner_ids(landmarks),
		[&"parcel.a", &"parcel.m", &"parcel.z"] as Array[StringName],
		"landmark integration must preserve the same deterministic house set")


func test_room_pair_repair_never_drops_required_transition_house() -> void:
	var room := _unsealed_room_for_geometry(&"current.room", &"current",
		Vector3i.ZERO)
	room.source_parcel_id = &"current"
	var rejection := {"prior_id": &"unit.prior"}
	var prior_records := {&"unit.prior": {
		"source_parcel_id": &"prior"}}
	var displaced: Dictionary = {}
	assert_eq(WarrenVolumetricSolver._displace_optional_room_pair_parcel(
		room, rejection, prior_records, displaced, {&"current": true}),
		&"prior", "the optional neighbor yields to a required current house")
	assert_has(displaced, &"prior")
	displaced.clear()
	assert_eq(WarrenVolumetricSolver._displace_optional_room_pair_parcel(
		room, rejection, prior_records, displaced,
		{&"current": true, &"prior": true}), &"",
		"two required transition houses must reject the whole feature state")
	assert_true(displaced.is_empty())


func test_skywalk_tower_risk_matches_three_storey_repetition_gate() -> void:
	var parcel := WarrenBuildingParcel.new(&"tower", [Vector2i.ZERO], 0, 8,
		Vector3i.ZERO, Vector2i.ZERO, Vector2i.DOWN)
	var stationary: Array[Dictionary] = [{"forced_offsets": {
		parcel.stable_id: {1: Vector2i.ZERO}}}]
	var three_storeys: Array[Dictionary] = [{"parcel": parcel,
		"kind": &"tower", "storeys": 3}]
	assert_gt(WarrenVolumetricSolver._skywalk_combination_tower_risk(
		stationary, three_storeys), 0,
		"a three-storey stationary endpoint predicts the exact visual rejection")
	var two_storeys: Array[Dictionary] = [{"parcel": parcel,
		"kind": &"tower", "storeys": 2}]
	assert_eq(WarrenVolumetricSolver._skywalk_combination_tower_risk(
		stationary, two_storeys), 0,
		"the permitted two-storey stack does not receive tower risk")


func test_court_tower_memo_keys_only_the_forced_structural_obligation() -> void:
	var first := {"forced_offsets": {&"parcel": {1: Vector2i.ZERO}},
		"body": {Vector3i.ZERO: true}}
	var visual_alternative := {"forced_offsets": {
		&"parcel": {1: Vector2i.ZERO}},
		"body": {Vector3i(9, 9, 9): true}}
	var different_block := {"forced_offsets": {
		&"parcel": {2: Vector2i.ZERO}}}
	assert_eq(WarrenVolumetricSolver._feature_forced_offset_key(first),
		WarrenVolumetricSolver._feature_forced_offset_key(visual_alternative),
		"cantilever visuals sharing one exact endpoint obligation reuse proof")
	assert_ne(WarrenVolumetricSolver._feature_forced_offset_key(first),
		WarrenVolumetricSolver._feature_forced_offset_key(different_block),
		"a different room block remains in the complete geometric frontier")


func test_room_outcropping_geometry_requires_one_bounded_bearing_facade() -> void:
	var lower := _unsealed_room_for_geometry(&"lower", &"building",
		Vector3i.ZERO)
	var integrated := _unsealed_room_for_geometry(&"integrated", &"building",
		Vector3i(1, WarrenSpatialGrid.STOREY_CELLS, 0))
	var valid := WarrenSpatialFeatureSolver._room_cantilever_geometry(lower,
		integrated)
	assert_true(bool(valid.valid))
	assert_eq(valid.direction, Vector2i.RIGHT)
	assert_eq(int(valid.depth_cells), 1)
	assert_eq(int(valid.extension_column_count), 4)
	assert_eq(int(valid.attachment_span_cells), 4)
	assert_eq(int(valid.bearing_column_count), 12)
	assert_almost_eq(float(valid.bearing_ratio), 0.75, 0.0001)
	var supports := WarrenSpatialFeatureSolver._cantilever_support_records(
		integrated, valid)
	assert_eq(supports.size(), 2,
		"the four-column bearing edge receives two native 3 m courses")
	for support: Dictionary in supports:
		assert_eq(StringName(support.recipe_id),
			&"outcrop.support.bracketed.2")
		assert_eq(FabricRecipe.transform_direction(Vector3i.BACK,
			int(support.yaw_quarters)), Vector3i.RIGHT,
			"every unscaled bracket projects beneath the unsupported room")

	var glued_corner := _unsealed_room_for_geometry(&"glued", &"building",
		Vector3i(1, WarrenSpatialGrid.STOREY_CELLS, 1))
	var corner_result := WarrenSpatialFeatureSolver._room_cantilever_geometry(
		lower, glued_corner)
	assert_false(bool(corner_result.valid),
		"a diagonally glued upper box is not one integrated facade jetty")
	assert_eq(StringName(corner_result.rejection), &"multiple_facades")

	var floating := _unsealed_room_for_geometry(&"floating", &"building",
		Vector3i(3, WarrenSpatialGrid.STOREY_CELLS, 0))
	var floating_result := WarrenSpatialFeatureSolver._room_cantilever_geometry(
		lower, floating)
	assert_false(bool(floating_result.valid))
	assert_eq(StringName(floating_result.rejection), &"projection_too_deep")


func _unsealed_room_for_geometry(stable_id: StringName, kind: StringName,
		origin: Vector3i) -> WarrenRoomStamp:
	var room := WarrenRoomStamp.new(stable_id, &"source", kind, origin, 0,
		origin.y / WarrenSpatialGrid.STOREY_CELLS, origin.y == 0, false)
	room.private_cells.assign(WarrenRoomStamp.expected_private_cells(kind,
		origin, 0))
	return room


func test_one_storey_composition_records_truncate_only_unrequired_tower_crown() \
		-> void:
	var three_storeys: Array[Dictionary] = []
	for storey in 3:
		three_storeys.append({"kind": &"tower", "start_storey": storey,
			"end_storey": storey + 1})
	var second_storey_required := {
		&"lineage": {"blocks": three_storeys.duplicate(true),
			"required_through_block": 1, "paired_primary": false,
			"paired_secondary": false},
	}
	assert_eq(WarrenRoomCompositionPlanner._truncate_unpaired_towers(
		second_storey_required), 1)
	assert_eq((((second_storey_required[&"lineage"] as Dictionary).blocks) \
		as Array).size(), 2,
		"a forced second storey must not protect an optional third storey")

	var third_storey_required := {
		&"lineage": {"blocks": three_storeys.duplicate(true),
			"required_through_block": 2, "paired_primary": false,
			"paired_secondary": false},
	}
	assert_eq(WarrenRoomCompositionPlanner._truncate_unpaired_towers(
		third_storey_required), 0)
	assert_eq((((third_storey_required[&"lineage"] as Dictionary).blocks) \
		as Array).size(), 3,
		"a real third-storey interface must remain for recomposition or rejection")


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
	assert_gte(int(plan.audit.courtyard_daylight_macro_column_count),
		WarrenElevatedFrontageSolver.MIN_COURTYARD_DAYLIGHT_COLUMNS)
	assert_gte(int(plan.audit.courtyard_upper_route_cell_count),
		WarrenSpatialFeatureSolver.MIN_COURT_UPPER_ROUTE_CELLS,
		"the upper courtyard crossing must contain actual walk floors")
	assert_gte(int(plan.audit.composed_courtyard_side_count),
		WarrenSpatialFeatureSolver.MIN_COURT_SIDE_COUNT,
		"the final 3D room composition must preserve the promised court walls")
	assert_eq(int(plan.audit.covered_market_count), 1)
	assert_lte(int(plan.audit.market_open_horizon_max_cells),
		WarrenVolumetricSolver.MAX_MARKET_OPEN_HORIZON_CELLS,
		"the covered bazaar must be embedded in the inhabited street maze")
	assert_gt(int(plan.audit.market_overhead_public_floor_seam_count), 0,
		"the reviewed bazaar should sit beneath an upper public route")
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
	assert_eq(int(plan.audit.unresolved_integrated_cantilever_count), 0,
		"every structural floorplate projection needs a measured load path")
	assert_eq(int(plan.audit.unsupported_perimeter_parcel_count), 0,
		"no buildable-frontier house may survive without a sealed load path")
	assert_almost_eq(float(plan.audit.perimeter_load_path_ratio), 1.0, 0.0001)
	assert_eq(int(plan.audit.grounded_perimeter_parcel_count) \
		+ int(plan.audit.gateway_supported_perimeter_parcel_count),
		int(plan.audit.perimeter_parcel_count),
		"edge houses must either reach terrain or be one typed covered gateway")
	assert_gte(float(plan.audit.overhead_route_ratio),
		WarrenVolumetricSolver.MIN_PRODUCTION_OVERHEAD_ROUTE_RATIO)
	assert_lte(int(plan.audit.through_sightline_count),
		WarrenVolumetricSolver.MAX_PRODUCTION_THROUGH_SIGHTLINES)
	assert_lte(int(plan.audit.ground_through_sightline_count),
		WarrenVolumetricSolver.MAX_PRODUCTION_GROUND_THROUGH_SIGHTLINES)
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
	var gateway_supports: Array[WarrenFeatureReservation] = []
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
			&"frontier_gateway_support":
				gateway_supports.append(feature)
	assert_eq(gateway_supports.size(),
		int(plan.audit.gateway_supported_perimeter_parcel_count))
	for gateway: WarrenFeatureReservation in gateway_supports:
		assert_true(bool(gateway.audit.gateway_is_terrain_anchored))
		assert_eq(gateway.construction_records.size(), 1)
		assert_true(StringName(gateway.construction_records[0].recipe_id) in [
			&"outcrop.support.bracketed.2", &"outcrop.support.diagonal.2"])
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
		assert_true(bool(outcrop.audit.outcrop_is_integrated_cantilever))
		assert_gte(int(outcrop.audit.outcrop_room_footprint_column_count), 4)
		assert_gte(int(outcrop.audit.outcrop_extension_column_count), 1)
		assert_between(int(outcrop.audit.outcrop_projection_depth_cells), 1, 2)
		assert_gte(int(outcrop.audit.outcrop_attachment_span_cells), 2)
		assert_gte(float(outcrop.audit.outcrop_bearing_ratio), 0.5)
		assert_gt(outcrop.construction_records.size(), 0)
		assert_eq(outcrop.construction_records.size(),
			int(outcrop.audit.outcrop_support_course_count))
		for record: Dictionary in outcrop.construction_records:
			assert_has([
				&"outcrop.support.bracketed.2",
				&"outcrop.support.diagonal.2",
			], StringName(record.recipe_id))
		outcrop_owners[StringName(outcrop.endpoints[0].owner_id)] = true
	assert_gte(outcrop_owners.size(),
		WarrenSpatialFeatureSolver.TARGET_ROOM_OUTCROPPINGS)


func _rank_fixture_landmark(recipe_id: StringName, origin: Vector3i,
		protected: Dictionary, blockers: Dictionary) -> Dictionary:
	return {"recipe_id": recipe_id, "origin": origin, "yaw_quarters": 0,
		"landing_cell": origin, "protected_cells": protected,
		"blocker_parcels": blockers}


func _rank_fixture_set(stable_id: StringName,
		reservations: Array[Dictionary]) -> Dictionary:
	return {"stable_id": stable_id, "reservations": reservations,
		"distinct_source_families": false, "displaced_parcel_count": 0,
		"protected_cell_count": 0, "separation_squared": 0,
		"footprint_area": 0.0, "tie": String(stable_id).hash()}
