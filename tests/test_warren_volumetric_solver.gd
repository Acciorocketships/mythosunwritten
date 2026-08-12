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


func test_touching_landmarks_share_one_explicit_party_wall() -> void:
	var left := _rank_fixture_landmark(&"anchor.a", Vector3i.ZERO,
		{Vector3i.ZERO: true}, {})
	left.merge({"feature_id": &"landmark.a", "source_family": &"fixture",
		"body": {Vector3i.ZERO: true},
		"clearance": {Vector3i.ZERO: true},
		"bearing_cells": {Vector3i.ZERO: true},
		"entrance_cell": Vector3i.ZERO,
		"skywalk_socket_faces": {}}, true)
	var right := _rank_fixture_landmark(&"anchor.b", Vector3i.RIGHT,
		{Vector3i.RIGHT: true}, {})
	right.merge({"feature_id": &"landmark.b", "source_family": &"fixture",
		"body": {Vector3i.RIGHT: true},
		"clearance": {Vector3i.RIGHT: true},
		"bearing_cells": {Vector3i.RIGHT: true},
		"entrance_cell": Vector3i.RIGHT,
		"skywalk_socket_faces": {}}, true)
	assert_true(WarrenVolumetricSolver._landmark_candidates_compatible(
		left, right), "touching measured bodies should enter the joint transaction")
	var landmarks := [left, right] as Array[Dictionary]
	WarrenVolumetricSolver._annotate_landmark_party_walls(landmarks)
	var left_faces := left.party_wall_faces as Dictionary
	var right_faces := right.party_wall_faces as Dictionary
	assert_has(left_faces, Vector3i.ZERO)
	assert_has(right_faces, Vector3i.RIGHT)
	var left_owner := StringName((left_faces[Vector3i.ZERO] \
		as Dictionary)[Vector3i.RIGHT])
	assert_eq(left_owner, StringName((right_faces[Vector3i.RIGHT] \
		as Dictionary)[Vector3i.LEFT]))
	var grid := WarrenSpatialGrid.new(Vector3i(-1, -1, -1),
		Vector3i(4, 3, 3))
	assert_true(WarrenVolumetricSolver._reserve_landmark_preplans(grid,
		landmarks), grid.last_rejection)
	var seam := grid.face_claim(Vector3i.ZERO, Vector3i.RIGHT)
	assert_eq(int(seam.kind), WarrenSpatialGrid.FaceKind.PARTY_WALL)
	assert_eq(StringName(seam.owner_id), left_owner)


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
	assert_eq(WarrenVolumetricSolver._court_owned_tall_tower_failures(
		[&"unrelated", &"parcel"], first), [&"parcel"] as Array[StringName],
		"one independently fatal court lineage memoizes a mixed failure")
	assert_true(WarrenVolumetricSolver._court_owned_tall_tower_failures(
		[&"unrelated"], first).is_empty(),
		"an unrelated tower failure leaves other landmark sets searchable")


func test_exact_room_preflight_cache_keys_structural_facts_not_palette() -> void:
	var court := {"forced_offsets": {&"court": {1: Vector2i.ZERO}},
		"body": {Vector3i.ZERO: true}, "clearance": {},
		"priority_cells": {}}
	var first_landmarks := [{"feature_id": &"landmark.0",
		"recipe_id": &"palette.blue",
		"protected_cells": {Vector3i(4, 0, 0): true}}] as Array[Dictionary]
	var recoloured_landmarks := [{"feature_id": &"landmark.0",
		"recipe_id": &"palette.orange",
		"protected_cells": {Vector3i(4, 0, 0): true}}] as Array[Dictionary]
	var skywalk := {"forced_offsets": {&"room": {1: Vector2i.LEFT}},
		"priority_cells": {Vector3i(2, 2, 0): &"room"},
		"landmark_transition_owner_ids": [&"transition.room"],
		"reservations": [{"components": [{"recipe_id": &"skywalk.3.blue",
			"origin": Vector3i(2, 2, 0), "yaw_quarters": 0}],
			"owner_parcel_ids": [&"room", &"landmark.0"],
			"reserved_cells": {Vector3i(2, 2, 0): true},
			"visual_clearance_cells": {Vector3i(2, 3, 0): true}}]}
	var first_key := WarrenVolumetricSolver._exact_room_preflight_key(court,
		first_landmarks, skywalk)
	assert_eq(first_key, WarrenVolumetricSolver._exact_room_preflight_key(
		court, recoloured_landmarks, skywalk),
		"a palette-only prefab change reuses the exact structural proof")
	var moved_landmarks := recoloured_landmarks.duplicate(true) \
		as Array[Dictionary]
	moved_landmarks[0]["protected_cells"] = {Vector3i(5, 0, 0): true}
	assert_ne(first_key, WarrenVolumetricSolver._exact_room_preflight_key(
		court, moved_landmarks, skywalk),
		"a changed protected volume must receive a fresh exact preflight")
	var shifted_skywalk := skywalk.duplicate(true)
	shifted_skywalk["forced_offsets"] = {&"room": {1: Vector2i.RIGHT}}
	assert_ne(first_key, WarrenVolumetricSolver._exact_room_preflight_key(
		court, recoloured_landmarks, shifted_skywalk),
		"a changed room obligation must receive a fresh exact preflight")


func test_balcony_measured_bounds_yield_to_existing_outcrop_supports() -> void:
	var program := _program()
	var support_recipe := program.recipe(&"outcrop.support.diagonal.2")
	var balcony_recipe := program.recipe(
		&"balcony.bracketed.left.blue.planted")
	assert_not_null(support_recipe)
	assert_not_null(balcony_recipe)
	var outcrop := WarrenFeatureReservation.new(&"outcrop.fixture",
		&"room_outcropping")
	assert_true(outcrop.add_construction_record(
		&"outcrop.support.diagonal.2", Vector3i.ZERO, 0,
		&"cantilever_support"))
	var same_place := FabricRecipe.lattice_transform(Vector3i.ZERO, 0) \
		* balcony_recipe.local_clearance_bounds
	assert_true(WarrenSpatialFeatureSolver
		._feature_bounds_overlap_existing_features(same_place,
			[outcrop] as Array[WarrenFeatureReservation], program),
		"a balcony must yield to a committed measured support envelope")
	var distant := FabricRecipe.lattice_transform(Vector3i(100, 0, 0), 0) \
		* balcony_recipe.local_clearance_bounds
	assert_false(WarrenSpatialFeatureSolver
		._feature_bounds_overlap_existing_features(distant,
			[outcrop] as Array[WarrenFeatureReservation], program))


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


func test_room_support_accepts_one_measured_corner_brace_but_not_floating_mass() \
		-> void:
	var grid := WarrenSpatialGrid.new(Vector3i(-8, 0, -8),
		Vector3i(16, 8, 16))
	var upper_record := WarrenRoomCompositionPlanner._record(&"slim",
		Vector3i(0, WarrenSpatialGrid.STOREY_CELLS, 0), 0, 1, 2)
	var columns := upper_record.columns as Dictionary
	var ordered: Array[Vector2i] = []
	ordered.assign(columns.keys())
	ordered.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.x < b.x if a.x != b.x else a.y < b.y)
	var claimed: Dictionary = {}
	for index in ordered.size() - 1:
		var column := ordered[index]
		claimed[Vector3i(column.x, WarrenSpatialGrid.STOREY_CELLS - 1,
			column.y)] = &"bearing"
	assert_true(WarrenRoomCompositionPlanner
		._floorplate_transition_is_structurally_legible(columns, {},
			WarrenSpatialGrid.STOREY_CELLS, claimed, grid),
		"one unsupported corner on a 7/8-borne room is a measured bracket case")
	assert_false(WarrenRoomCompositionPlanner
		._floorplate_transition_is_structurally_legible(columns, {},
			WarrenSpatialGrid.STOREY_CELLS, {}, grid),
		"a room with no mass beneath it must never pass as a cantilever")

	var upper := _unsealed_room_for_geometry(&"corner", &"slim",
		Vector3i(0, WarrenSpatialGrid.STOREY_CELLS, 0))
	var anchor := ordered[0]
	var geometry := {"valid": true, "direction": Vector2i.RIGHT,
		"depth_cells": 1, "attachment_columns": [anchor],
		"bearing_columns": [anchor, anchor + Vector2i.DOWN]}
	var supports := WarrenSpatialFeatureSolver._cantilever_support_records(
		upper, geometry)
	assert_eq(supports.size(), 1,
		"the native two-brace course must widen from the borne neighbor")


func test_wrap_balcony_requires_a_side_wall_contact() -> void:
	var grid := WarrenSpatialGrid.new(Vector3i.ZERO, Vector3i(6, 6, 6))
	var endpoint := Vector3i(1, 2, 2)
	var return_contact := Vector3i(3, 2, 0)
	var building_cells: Array[Vector3i] = [endpoint, return_contact]
	var room := grid.begin_transaction(&"building.wrap")
	assert_true(room.assign_use(building_cells,
		WarrenSpatialGrid.Use.PRIVATE_VOLUME, &"building.wrap"))
	assert_true(room.commit(), room.last_rejection)
	var body := {
		Vector3i(1, 2, 1): true,
		Vector3i(2, 2, 1): true,
		Vector3i(2, 2, 0): true,
	}
	var contacts := WarrenSpatialFeatureSolver._balcony_return_contact_cells(
		grid, body, &"building.wrap", endpoint, Vector3i.FORWARD, 2)
	assert_eq(contacts, [return_contact] as Array[Vector3i],
		"the L return must physically meet the owning side wall")
	assert_true(WarrenSpatialFeatureSolver._balcony_return_contact_cells(
		grid, body, &"another.building", endpoint, Vector3i.FORWARD, 2).is_empty(),
		"a neighboring unrelated facade cannot fake a balcony return")
	var straight_body := {endpoint + Vector3i.FORWARD: true}
	assert_true(WarrenSpatialFeatureSolver._balcony_return_contact_cells(
		grid, straight_body, &"building.wrap", endpoint,
		Vector3i.FORWARD, 2).is_empty(),
		"the doorway face alone must not qualify a straight shelf as a wrap")


func test_only_macroscopic_or_lean_to_shoulders_are_roofable() -> void:
	var compound := {
		Vector2i(0, 0): true, Vector2i(1, 0): true,
		Vector2i(0, 1): true, Vector2i(1, 1): true,
		Vector2i(2, 0): true, Vector2i(3, 0): true,
	}
	assert_true(WarrenRoomCompositionPlanner._component_has_gabled_partition(
		compound, 0),
		"a complete 3 x 3 m crown with one native strip is a finite roof assembly")
	var branching := {
		Vector2i(0, 0): true, Vector2i(1, 0): true,
		Vector2i(2, 0): true, Vector2i(1, -1): true,
		Vector2i(1, 1): true, Vector2i(1, 2): true,
	}
	assert_false(WarrenRoomCompositionPlanner._component_has_gabled_partition(
		branching, 0),
		"a branching voxel shelf has no authored macroscopic roof vocabulary")


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


func test_registered_optional_crown_terminates_above_a_complete_house() \
		-> void:
	var blocks: Array[Dictionary] = []
	for storey in 4:
		blocks.append(_composition_test_record(&"building", Vector3i(0,
			storey * WarrenSpatialGrid.STOREY_CELLS, 0), 0, storey))
	var lineages := {
		&"shaft": {"blocks": blocks, "required_through_block": -1,
			"paired_primary": false, "paired_secondary": false},
	}
	var result := WarrenRoomCompositionPlanner \
		._truncate_registered_crowns(lineages)
	assert_eq(int(result.lineage_count), 1)
	assert_eq(int(result.storey_count), 2)
	assert_eq((((lineages[&"shaft"] as Dictionary).blocks) as Array).size(), 2,
		"an unsolved centered suffix should become a roofline after two storeys")


func test_registered_crown_keeps_required_interface_and_bearer() -> void:
	var required_blocks: Array[Dictionary] = []
	for storey in 4:
		required_blocks.append(_composition_test_record(&"building", Vector3i(0,
			storey * WarrenSpatialGrid.STOREY_CELLS, 0), 0, storey))
	var required_third := required_blocks[2] as Dictionary
	required_third["forced"] = true
	required_blocks[2] = required_third
	var required_lineages := {
		&"required": {"blocks": required_blocks, "required_through_block": 2,
			"paired_primary": false, "paired_secondary": false},
	}
	var required_result := WarrenRoomCompositionPlanner \
		._truncate_registered_crowns(required_lineages)
	assert_eq(int(required_result.storey_count), 0)
	assert_eq((((required_lineages[&"required"] as Dictionary).blocks) \
		as Array).size(), 4,
		"a required third-storey interface must never be hidden by a roof")

	var bearing_blocks: Array[Dictionary] = []
	for storey in 4:
		bearing_blocks.append(_composition_test_record(&"building", Vector3i(0,
			storey * WarrenSpatialGrid.STOREY_CELLS, 0), 0, storey))
	var child := _composition_test_record(&"tower", Vector3i(0,
		4 * WarrenSpatialGrid.STOREY_CELLS, 0), 0, 4)
	child["support_parent_lineage_id"] = &"bearing"
	child["support_parent_source_block_index"] = 2
	var bearing_lineages := {
		&"bearing": {"blocks": bearing_blocks, "required_through_block": -1,
			"paired_primary": false, "paired_secondary": false},
		&"child": {"blocks": [child], "required_through_block": 0,
			"paired_primary": false, "paired_secondary": true},
	}
	var bearing_result := WarrenRoomCompositionPlanner \
		._truncate_registered_crowns(bearing_lineages)
	assert_eq(int(bearing_result.storey_count), 0)
	assert_eq((((bearing_lineages[&"bearing"] as Dictionary).blocks) \
		as Array).size(), 4,
		"a crown that bears another lineage must remain structural mass")

	var implicit_bearing_blocks: Array[Dictionary] = []
	for storey in 4:
		implicit_bearing_blocks.append(_composition_test_record(&"building",
			Vector3i(0, storey * WarrenSpatialGrid.STOREY_CELLS, 0), 0,
			storey))
	var implicit_child := _composition_test_record(&"tower", Vector3i(0,
		4 * WarrenSpatialGrid.STOREY_CELLS, 0), 0, 4)
	var implicit_lineages := {
		&"bearing": {"blocks": implicit_bearing_blocks,
			"required_through_block": -1, "paired_primary": false,
			"paired_secondary": false},
		&"implicit_child": {"blocks": [implicit_child],
			"required_through_block": 0, "paired_primary": false,
			"paired_secondary": true},
	}
	var implicit_result := WarrenRoomCompositionPlanner \
		._truncate_registered_crowns(implicit_lineages)
	assert_eq(int(implicit_result.storey_count), 0)
	assert_eq((((implicit_lineages[&"bearing"] as Dictionary).blocks) \
		as Array).size(), 4,
		"implicit cross-lineage bearing must survive crown termination")


func test_three_storey_narrow_lineage_requires_one_occupied_annex() -> void:
	var blocks: Array[Dictionary] = []
	for storey in 3:
		blocks.append(_composition_test_record(&"tower", Vector3i(0,
			storey * WarrenSpatialGrid.STOREY_CELLS, 0), 0, storey))
	var lineages := {
		&"narrow": {"blocks": blocks, "required_through_block": 2,
			"paired_primary": false, "paired_secondary": false},
	}
	var audit := WarrenRoomCompositionPlanner._audit(lineages, 3, 0, 0, 0, 0)
	var targets := audit.tower_relief_annex_target_by_lineage as Dictionary
	assert_eq(int(targets.get(&"narrow", 0)),
		WarrenSpatialFeatureSolver.MIN_TOWER_ANNEXES_PER_THREE_STOREY_LINEAGE,
		"a three-storey narrow house needs one real side-room composition")
	assert_true(WarrenRoomCompositionPlanner \
		._unresolved_overlong_tower_runs(audit).is_empty(),
		"the one-annex three-storey contract must survive to exact construction")


func test_market_protection_includes_the_full_public_aisle_headroom() -> void:
	var floor := Vector3i(4, 2, -3)
	var protected := WarrenVolumetricSolver._protected_owners_with_market({}, {
		"feature_id": &"market",
		"backing_parcel_id": &"backing",
		"reserved_cells": {},
		"visual_clearance_cells": {},
		"public_cells": {floor: true},
	})
	for y_offset in WarrenVolumePlan.HEADROOM_BANDS:
		var air := floor + Vector3i.UP * y_offset
		assert_true((protected.get(air, {}) as Dictionary).has(&"market"),
			"market aisle headroom must be protected during exact room preflight")


func test_paired_registration_relief_repartitions_two_locked_upper_rooms() \
		-> void:
	var grid := WarrenSpatialGrid.new(Vector3i(-12, 0, -12),
		Vector3i(24, 4, 24))
	var left_lower := _composition_test_record(&"building",
		Vector3i(-2, 0, 0), 0, 0)
	var left_upper := _composition_test_record(&"building",
		Vector3i(-2, WarrenSpatialGrid.STOREY_CELLS, 0), 0, 1)
	var right_lower := _composition_test_record(&"building",
		Vector3i(2, 0, 0), 0, 0)
	var right_upper := _composition_test_record(&"building",
		Vector3i(2, WarrenSpatialGrid.STOREY_CELLS, 0), 0, 1)
	var lineages := {
		&"left": {"blocks": [left_lower, left_upper] as Array[Dictionary],
			"required_through_block": -1, "paired_primary": false,
			"paired_secondary": false},
		&"right": {"blocks": [right_lower, right_upper] as Array[Dictionary],
			"required_through_block": -1, "paired_primary": false,
			"paired_secondary": false},
	}
	var before_registered := \
		WarrenRoomCompositionPlanner._registered_facade_plane_count(
			left_lower.columns as Dictionary,
			left_upper.columns as Dictionary) \
		+ WarrenRoomCompositionPlanner._registered_facade_plane_count(
			right_lower.columns as Dictionary,
			right_upper.columns as Dictionary)
	var relieved := WarrenRoomCompositionPlanner \
		._relieve_paired_registered_lineages(lineages, grid, {}, 73)
	assert_gt(relieved, 0,
		"a party-wall pair must be able to trade its upper occupied volume")
	var left_blocks := (lineages[&"left"] as Dictionary).blocks \
		as Array[Dictionary]
	var right_blocks := (lineages[&"right"] as Dictionary).blocks \
		as Array[Dictionary]
	var new_left := left_blocks[1] as Dictionary
	var new_right := right_blocks[1] as Dictionary
	var after_registered := \
		WarrenRoomCompositionPlanner._registered_facade_plane_count(
			(left_blocks[0] as Dictionary).columns as Dictionary,
			new_left.columns as Dictionary) \
		+ WarrenRoomCompositionPlanner._registered_facade_plane_count(
			(right_blocks[0] as Dictionary).columns as Dictionary,
			new_right.columns as Dictionary)
	assert_lt(after_registered, before_registered,
		"the atomic exchange must lower the actual world-space facade metric")
	assert_eq(WarrenRoomCompositionPlanner._intersection_size(
		new_left.columns as Dictionary, new_right.columns as Dictionary), 0,
		"the two complete replacement rooms must remain disjoint")
	assert_true(bool(new_left.get("paired_registration_relief", false)))
	assert_true(bool(new_right.get("paired_registration_relief", false)))
	assert_lte(int(WarrenRoomCompositionPlanner.last_pair_diagnostic \
		.get("peak_frontier_count", -1)),
		WarrenRoomCompositionPlanner.MAX_PAIRED_RELIEF_FRONTIER,
		"the exact pair exchange must retain a hard bounded frontier")
	assert_lte(int(WarrenRoomCompositionPlanner.last_pair_diagnostic \
		.get("examined_pair_count", -1)),
		WarrenRoomCompositionPlanner.MAX_PAIRED_RELIEF_PAIR_CHECKS,
		"nested exact candidate solves must have a fixed work budget")


func test_paired_registration_relief_sees_half_storey_phase_overlap() -> void:
	var grid := WarrenSpatialGrid.new(Vector3i(-12, 0, -12),
		Vector3i(24, 6, 24))
	var left_lower := _composition_test_record(&"building",
		Vector3i(-2, 0, 0), 0, 0)
	var left_upper := _composition_test_record(&"building",
		Vector3i(-2, 2, 0), 0, 1)
	var right_lower := _composition_test_record(&"building",
		Vector3i(2, 1, 0), 0, 0)
	var right_upper := _composition_test_record(&"building",
		Vector3i(2, 3, 0), 0, 1)
	var lineages := {
		&"left": {"blocks": [left_lower, left_upper] as Array[Dictionary],
			"required_through_block": -1, "paired_primary": false,
			"paired_secondary": false},
		&"right": {"blocks": [right_lower, right_upper] as Array[Dictionary],
			"required_through_block": -1, "paired_primary": false,
			"paired_secondary": false},
	}
	var relieved := WarrenRoomCompositionPlanner \
		._relieve_paired_registered_lineages(lineages, grid, {}, 91)
	assert_gt(relieved, 0,
		"rooms sharing only one fine Y slice still need one atomic 3D repair")
	assert_eq(int(WarrenRoomCompositionPlanner._lineage_overlap_audit(
		lineages).overlap_cell_count), 0)
	assert_lte(int(WarrenRoomCompositionPlanner.last_pair_diagnostic.get(
		"examined_pair_count", -1)),
		WarrenRoomCompositionPlanner.MAX_PAIRED_RELIEF_PAIR_CHECKS)


func test_addressed_room_recomposition_accepts_second_measured_door_phase() \
		-> void:
	var current := {"address_threshold": Vector3i(0, 2, 0),
		"address_frontage": Vector3i.BACK,
		"address_expandable": true,
		"feature_endpoint_constraints": []}
	assert_true(WarrenRoomCompositionPlanner._candidate_matches_address(
		&"tower", Vector3i(0, 2, 0), 0, current),
		"the phase-zero room remains a valid exact public address")
	assert_true(WarrenRoomCompositionPlanner._candidate_matches_address(
		&"tower", Vector3i(1, 2, 0), 0, current),
		"a one-cell step must select the authored phase-one doorway")
	assert_false(WarrenRoomCompositionPlanner._candidate_matches_address(
		&"tower", Vector3i(2, 2, 0), 0, current),
		"the finite doorway vocabulary cannot excuse an arbitrary shift")
	assert_true(WarrenRoomCompositionPlanner._block_allows_recomposition({
		"bearing_forced": true,
		"address_expandable": false,
		"feature_endpoint_constraints": [],
		"court_contact_columns": {},
	}), "the bearer below an exact doorway may reshape while keeping support")


func test_cantilever_support_assignment_can_revise_an_earlier_course() -> void:
	var bad_early := {"bounds": [AABB(Vector3.ZERO, Vector3(2.0, 2.0, 2.0))],
		"records": [], "analysis": {}, "diagonal_count": 1}
	var safe_early := {"bounds": [AABB(Vector3(5.0, 0.0, 0.0),
		Vector3(2.0, 2.0, 2.0))], "records": [], "analysis": {},
		"diagonal_count": 0}
	var later := {"bounds": [AABB(Vector3(1.0, 0.0, 0.0),
		Vector3(2.0, 2.0, 2.0))], "records": [], "analysis": {},
		"diagonal_count": 1}
	var entries: Array[Dictionary] = [
		{"key": "early", "options": [bad_early, safe_early]},
		{"key": "later", "options": [later]},
	]
	var state := {"visited_node_count": 0, "peak_assigned_count": 0}
	var assignments := WarrenSpatialFeatureSolver \
		._assign_cantilever_supports(entries, state)
	assert_eq(assignments.size(), 2,
		"mandatory support courses must be chosen as one compatible transaction")
	assert_eq(int((assignments.early as Dictionary).diagonal_count), 0,
		"the solver must revise an earlier diagonal when a later support needs it")
	assert_lte(int(state.visited_node_count),
		WarrenSpatialFeatureSolver.MAX_CANTILEVER_SUPPORT_ASSIGNMENT_NODES)


func test_collinear_cantilever_courses_share_one_structural_frame() -> void:
	var lower_record := {"recipe_id": &"outcrop.support.diagonal.2",
		"origin": Vector3i(3, 4, 7), "yaw_quarters": 1}
	var upper_record := {"recipe_id": &"outcrop.support.bracketed.2",
		"origin": Vector3i(3, 6, 8), "yaw_quarters": 1}
	var entries: Array[Dictionary] = [
		{"key": "lower", "options": [{"bounds": [AABB(Vector3.ZERO,
			Vector3(2.0, 3.5, 2.0))], "records": [lower_record]}]},
		{"key": "upper", "options": [{"bounds": [AABB(Vector3(0.0, 2.5,
			0.0), Vector3(2.0, 3.5, 2.0))], "records": [upper_record]}]},
	]
	var state := {"visited_node_count": 0, "peak_assigned_count": 0}
	var assignments := WarrenSpatialFeatureSolver \
		._assign_cantilever_supports(entries, state)
	assert_eq(assignments.size(), 2,
		"adjacent same-plane courses should form one continuous timber frame")
	var crossing := upper_record.duplicate()
	crossing["yaw_quarters"] = 2
	assert_true(WarrenSpatialFeatureSolver._cantilever_supports_share_frame(
		lower_record, crossing),
		"perpendicular support courses meet at an explicit timber joint")


func _composition_test_record(kind: StringName, origin: Vector3i, yaw: int,
		storey: int) -> Dictionary:
	var record := WarrenRoomCompositionPlanner._record(kind, origin, yaw,
		storey, storey + 1)
	record["forced"] = false
	record["merged"] = false
	record["source_block_index"] = storey
	record["original_kind"] = kind
	record["original_origin"] = origin
	record["original_yaw_quarters"] = yaw
	record["home_origin"] = origin
	record["home_columns"] = (record.columns as Dictionary).duplicate()
	record["address_expandable"] = false
	record["feature_endpoint_constraints"] = []
	return record


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
	assert_true(plan.audit.has("market_overhead_public_floor_seam_count"),
		"an optional upper-route/canopy seam remains explicitly audited")
	assert_eq(int(plan.audit.prefab_landmark_count),
		WarrenSpatialFeatureSolver.TARGET_PREFAB_LANDMARKS)
	assert_eq(int(plan.audit.enclosed_skywalk_count),
		WarrenSpatialFeatureSolver.TARGET_SKYWALKS)
	assert_eq(int(plan.audit.tower_annex_count),
		int(plan.audit.required_tower_annex_count),
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
		int(plan.audit.required_tower_annex_count),
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
	var annex_targets := plan.audit.tower_relief_annex_target_by_lineage \
		as Dictionary
	for source_value: Variant in annex_targets.keys():
		var source_id := StringName(source_value)
		assert_eq(int(annex_source_counts.get(source_id, 0)),
			int(annex_targets[source_value]),
			"each residual narrow shaft needs its required compound-room events")
		var storeys := annex_storeys_by_source[source_id] as Array
		if int(annex_targets[source_value]) >= 2:
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
		assert_true(bool(balcony.audit.balcony_wraparound),
			"one-door straight shelves are not circulation or destinations")
		assert_gte(int(balcony.audit.balcony_return_contact_cell_count), 1,
			"every balcony must turn back into an inhabited side wall")
		assert_eq(int(balcony.audit.balcony_usable_depth_cells), 2)
		assert_eq(int(balcony.audit.balcony_door_count), 1)
		assert_eq(int(balcony.audit.balcony_guard_segment_count), 6)
		assert_eq(balcony.audit.balcony_support_kind, &"bracket_cantilever")
		assert_eq(balcony.reserved_cells.size(), 6)
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
		assert_gte(int(outcrop.audit.outcrop_attachment_span_cells), 1)
		assert_gte(float(outcrop.audit.outcrop_bearing_ratio), 0.5)
		assert_gt(outcrop.construction_records.size(), 0)
		assert_eq(outcrop.construction_records.size(),
			int(outcrop.audit.outcrop_support_course_count))
		for record: Dictionary in outcrop.construction_records:
			assert_has([
				&"outcrop.support.bracketed.1",
				&"outcrop.support.bracketed.2",
				&"outcrop.support.diagonal.1",
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
