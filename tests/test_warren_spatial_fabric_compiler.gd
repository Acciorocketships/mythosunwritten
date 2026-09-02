extends GutTest

## A committed covered market compiles to a canopy plus its posts; the exact
## module count is a recipe detail, so the scan above bounds it rather than
## pinning it.
const COVERED_MARKET_UNIT_CEILING := 64

## TASK I1. Canopy candidates `_preplan_spatial_market` forms for the pinned
## production city seed. Measured 1 before the size cut and **0** after -- see
## the note at the assertion for why, and for why it is pinned rather than
## relaxed to a `>= 0` that would say nothing.
const PRODUCTION_MARKET_CANDIDATES := 0


static func _tiled_setback_caps(audit: Dictionary) -> int:
	## Public partial crowns may use plank backing only when their exact source
	## face already carries a PUBLIC_FLOOR. Count that narrow case separately
	## from the private weather-roof vocabulary.
	var out := 0
	var recipe_counts := audit.get("maze_partial_plate_tile_recipe_counts",
		{}) as Dictionary
	for recipe_value: Variant in recipe_counts.keys():
		if String(recipe_value).begins_with("roof.setback.cap."):
			out += int(recipe_counts[recipe_value])
	return out


static func _tiled_partial_gables(audit: Dictionary) -> int:
	## Private partial crowns use exact-footprint halves of authored compact
	## gables. Their per-recipe histogram is the authoritative producer census.
	var out := 0
	var recipe_counts := audit.get("maze_partial_plate_tile_recipe_counts",
		{}) as Dictionary
	for recipe_value: Variant in recipe_counts.keys():
		if String(recipe_value).begins_with("roof.partial.gable."):
			out += int(recipe_counts[recipe_value])
	return out


func test_arcade_overhang_adapter_binds_foundation_to_both_room_plates() -> void:
	var program := SettlementFabricProgram.compile(
		EnvironmentCatalog.load_default())
	assert_not_null(program)
	if program == null:
		return
	var upper := FabricUnit.new(&"unit.upper", &"room.slim.upper.blue",
		Vector3i(0, 2, 0), 0)
	var lower := FabricUnit.new(&"unit.lower", &"room.tower.base.rock",
		Vector3i.ZERO, 0)
	var feature := WarrenFeatureReservation.new(&"arcade.fixture",
		&"arcade_overhang_support")
	var foundation_id := SettlementFabricProgram \
		.arcade_overhang_foundation_recipe_id(5)
	assert_true(feature.add_construction_record(
		foundation_id, Vector3i(0, 2, 0), 0,
		&"arcade_stone_foundation"))
	feature.audit = {
		"arcade_upper_room_id": &"room.upper",
		"arcade_lower_room_id": &"room.lower",
		"arcade_support_course_count": 1,
		"arcade_support_face_count": 4,
		"arcade_support_neighbor_room_ids": [&"room.lower"],
	}
	var compiled := WarrenSpatialFabricCompiler \
		._compile_arcade_overhang_supports(feature, program, {
			&"room.upper": upper,
			&"room.lower": lower,
		})
	assert_eq(compiled.size(), 1, WarrenSpatialFabricCompiler.last_failure)
	if compiled.size() != 1:
		return
	var foundation := compiled[0] as FabricUnit
	assert_eq(foundation.recipe_id, foundation_id)
	assert_true(foundation.visual_seam_ids.has(upper.stable_id))
	assert_true(foundation.visual_seam_ids.has(lower.stable_id))


func test_roof_gate_checks_measured_volume_against_exact_finished_headroom() \
		-> void:
	var grid := WarrenSpatialGrid.new(Vector3i(-2, 0, -2),
		Vector3i(5, 5, 5))
	var transaction := grid.begin_transaction(&"test.elevated-route-air")
	assert_true(transaction.assign_use([Vector3i.ZERO, Vector3i.UP] \
		as Array[Vector3i],
		WarrenSpatialGrid.Use.PUBLIC_AIR, &"route.air"))
	assert_true(transaction.claim_face(Vector3i.ZERO, Vector3i.DOWN,
		WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR, &"route.air"))
	assert_true(transaction.commit())
	var recipe := FabricRecipe.new(&"test.measured-roof", [&"roof"], 0)
	recipe.placement_collision_pieces = PackedInt32Array([1])
	# A collider beginning below the shared 2.4 m finished-headroom plane is a
	# real obstruction even though the semantic roof cell is only a coarse band.
	recipe.placement_bounds = [AABB(Vector3(-0.10, 2.20, -0.10),
		Vector3(0.20, 0.40, 0.20))] as Array[AABB]
	var unit := FabricUnit.new(&"test.roof", recipe.recipe_id,
		Vector3i.ZERO, 0)
	assert_true(WarrenSpatialFabricCompiler._unit_touches_public_air(grid,
		unit, recipe),
		"a measured collider may not enter the exact finished body column")
	# A true 3 m storey seam is above the finished clearance and remains legal.
	recipe.placement_bounds = [AABB(Vector3(-0.10, 3.00, -0.10),
		Vector3(0.20, 0.40, 0.20))] as Array[AABB]
	assert_false(WarrenSpatialFabricCompiler._unit_touches_public_air(grid,
		unit, recipe), "a gable beginning at the storey seam must remain legal")
	recipe.placement_bounds = [AABB(Vector3(-0.10, 2.20, -0.10),
		Vector3(0.20, 0.40, 0.20))] as Array[AABB]
	unit.lattice_origin = Vector3i.RIGHT
	assert_false(WarrenSpatialFabricCompiler._unit_touches_public_air(grid,
		unit, recipe))


func test_roof_gate_protects_the_body_lane_but_keeps_a_shallow_eave() -> void:
	var grid := WarrenSpatialGrid.new(Vector3i(-2, 0, -2),
		Vector3i(5, 3, 5))
	var transaction := grid.begin_transaction(&"test.route-body-air")
	assert_true(transaction.assign_use([Vector3i.ZERO] as Array[Vector3i],
		WarrenSpatialGrid.Use.PUBLIC_AIR, &"route.air"))
	assert_true(transaction.claim_face(Vector3i.ZERO, Vector3i.DOWN,
		WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR, &"route.air"))
	assert_true(transaction.commit())
	var recipe := FabricRecipe.new(&"test.collidable-eave", [&"roof"], 0)
	recipe.placement_collision_pieces = PackedInt32Array([1])
	var unit := FabricUnit.new(&"test.eave", recipe.recipe_id,
		Vector3i.ZERO, 0)
	# The cell edge is x = 0.75 m. This 0.25 m eave stays outside the
	# capsule-plus-margin lane and is the safe corner brush the physics review
	# already admits.
	recipe.placement_bounds = [AABB(Vector3(0.50, 0.20, -0.10),
		Vector3(0.25, 0.20, 0.20))] as Array[AABB]
	assert_false(WarrenSpatialFabricCompiler._unit_touches_public_air(grid,
		unit, recipe), "a shallow eave at the route edge must remain legal")
	# Moving the same collider 0.20 m inward crosses the protected body lane.
	recipe.placement_bounds = [AABB(Vector3(0.30, 0.20, -0.10),
		Vector3(0.25, 0.20, 0.20))] as Array[AABB]
	assert_true(WarrenSpatialFabricCompiler._unit_touches_public_air(grid,
		unit, recipe), "a roof collider entering the body lane must be refused")


func test_future_roof_domain_rejects_semantic_overlap_before_commit() -> void:
	var left_recipe := FabricRecipe.new(&"test.future-left", [&"roof"], 0)
	left_recipe.solid_cells = [Vector3i.ZERO] as Array[Vector3i]
	var right_recipe := FabricRecipe.new(&"test.future-right", [&"roof"], 0)
	right_recipe.headroom_cells = [Vector3i.ZERO] as Array[Vector3i]
	var left := FabricUnit.new(&"test.future-left", left_recipe.recipe_id,
		Vector3i.ZERO, 0)
	var right := FabricUnit.new(&"test.future-right", right_recipe.recipe_id,
		Vector3i.ZERO, 0)
	assert_true(WarrenSpatialFabricCompiler._future_unit_semantic_conflict(
		left, left_recipe, right, right_recipe),
		"a selected roof cannot consume a later roof's exact headroom domain")
	right.lattice_origin = Vector3i.RIGHT
	assert_false(WarrenSpatialFabricCompiler._future_unit_semantic_conflict(
		left, left_recipe, right, right_recipe),
		"disjoint roof closures must remain available to the solver")


func test_compound_roof_partition_replaces_cells_with_complete_house_crowns() \
		-> void:
	var faces: Array[Vector3i] = [
		Vector3i(0, 3, 0), Vector3i(1, 3, 0),
		Vector3i(0, 3, 1), Vector3i(1, 3, 1),
		Vector3i(2, 3, 0), Vector3i(3, 3, 0),
	]
	var pieces := WarrenSpatialFabricCompiler._cap_pieces(faces)
	assert_eq(pieces.size(), 2,
		"the L shoulder should become one complete gable plus one native strip")
	if pieces.size() != 2:
		return
	assert_eq(StringName((pieces[0] as Dictionary).kind), &"stamp")
	assert_eq(((pieces[0] as Dictionary).cells as Array).size(), 4)
	assert_eq(StringName((pieces[1] as Dictionary).kind), &"row")
	assert_eq(((pieces[1] as Dictionary).cells as Array).size(), 2)
	var realized: Dictionary = {}
	for piece: Dictionary in pieces:
		for cell: Vector3i in piece.cells as Array[Vector3i]:
			assert_false(realized.has(cell),
				"macroscopic roof pieces may not overlap one another")
			realized[cell] = true
	assert_eq(realized.size(), faces.size())
	for face: Vector3i in faces:
		assert_true(realized.has(face),
			"the replacement partition must preserve every authoritative face")


func test_setback_gable_does_not_exempt_neighboring_room_collisions() -> void:
	var piece := {"kind": &"stamp", "room_kind": &"tower",
		"origin": Vector3i.ZERO, "yaw_quarters": 0,
		"cells": [Vector3i(0, 2, 0), Vector3i(1, 2, 0),
			Vector3i(0, 2, 1), Vector3i(1, 2, 1)] as Array[Vector3i]}
	var room := WarrenRoomStamp.new(&"lower", &"building", &"building",
		Vector3i.ZERO, 0, 0, true, false)
	var placement := WarrenSpatialFabricCompiler._setback_gable_placement(
		piece, room, 7)
	assert_false(placement.is_empty())
	assert_false(placement.has("upper_room_unit_ids"),
		"adjacent rooms are collision obstacles unless an exact roof join names them")
	assert_true(String(placement.recipe_id).contains("dormer"),
		"the detailed gable is attempted before the transaction chooses a fallback")


func test_complete_room_roof_never_uses_a_shallow_seam_piece() -> void:
	var room := WarrenRoomStamp.new(&"roof.probe", &"building", &"tower",
		Vector3i(8, 4, -6), 1, 1, false, false,
		Vector3i(2147483647, 2147483647, 2147483647), Vector3i.ZERO,
		0, &"lower", 0)
	var recipe_ids := WarrenSpatialFabricCompiler \
		._terminal_tight_gable_recipe_ids(room, 2697992464)
	assert_eq(recipe_ids.size(), 1)
	if recipe_ids.is_empty():
		return
	var recipe_id := String(recipe_ids[0])
	assert_true(recipe_id.begins_with("roof.terminal.tight.tower."))
	assert_false(recipe_id.contains(".step."))
	assert_false(recipe_id.contains(".profile."),
		"window-canopy seam pieces cannot discharge a whole room roof obligation")
	assert_not_null(SettlementFabricProgram.compile(
		EnvironmentCatalog.load_default()).recipe(recipe_ids[0]))


func test_rotated_even_cell_roof_preserves_the_room_plate_centre() -> void:
	var program := SettlementFabricProgram.compile(
		EnvironmentCatalog.load_default())
	assert_not_null(program)
	if program == null:
		return
	var room := WarrenRoomStamp.new(&"roof.phase.probe", &"building", &"tower",
		Vector3i(8, 4, -6), 0, 1, false, false,
		Vector3i(2147483647, 2147483647, 2147483647), Vector3i.ZERO,
		0, &"lower", 0)
	assert_true(room.add_private_cells(WarrenRoomStamp.expected_private_cells(
		&"tower", room.lattice_origin, room.yaw_quarters)))
	var roof_recipe := program.recipe(&"roof.terminal.tight.tower.orange")
	assert_not_null(roof_recipe)
	if roof_recipe == null:
		return
	var roof_yaw := 1
	var roof_origin := WarrenSpatialFabricCompiler \
		._phase_aligned_full_roof_origin(room, roof_recipe, roof_yaw)
	var room_min := Vector2(INF, INF)
	var room_max := Vector2(-INF, -INF)
	for cell: Vector3i in room.private_cells:
		room_min = room_min.min(Vector2(cell.x, cell.z))
		room_max = room_max.max(Vector2(cell.x, cell.z))
	var roof_min := Vector2(INF, INF)
	var roof_max := Vector2(-INF, -INF)
	for cell: Vector3i in roof_recipe.solid_cells:
		var placed := FabricRecipe.transform_cell(cell, roof_origin, roof_yaw)
		roof_min = roof_min.min(Vector2(placed.x, placed.z))
		roof_max = roof_max.max(Vector2(placed.x, placed.z))
	assert_eq((roof_min + roof_max) * 0.5, (room_min + room_max) * 0.5,
		"turning an even-cell crown may not move it onto the neighboring half-cell phase")


func test_terminal_setback_names_only_the_neighboring_roof_seam() -> void:
	var own_room_unit := FabricUnit.new(&"room.own", &"room.test",
		Vector3i.ZERO, 0)
	var neighboring_room_unit := FabricUnit.new(&"room.neighbor", &"room.test",
		Vector3i.RIGHT * 2, 0)
	var neighboring_roof := FabricUnit.new(&"roof.neighbor", &"roof.test",
		Vector3i.RIGHT * 2 + Vector3i.UP * 2, 0,
		[neighboring_room_unit.stable_id] as Array[StringName])
	var unrelated_roof := FabricUnit.new(&"roof.unrelated", &"roof.test",
		Vector3i.BACK * 4, 0, [own_room_unit.stable_id] as Array[StringName])
	var seams := WarrenSpatialFabricCompiler \
		._prior_roof_seams_for_neighbor_rooms(
			[neighboring_room_unit.stable_id] as Array[StringName],
			[neighboring_roof, unrelated_roof] as Array[FabricUnit])
	assert_eq(seams, [neighboring_roof.stable_id] as Array[StringName],
		"the typed join closes roof-to-roof without exempting the upper room wall")


func test_setback_wall_seam_comes_from_the_exact_cap_perimeter() -> void:
	var row := [Vector3i(0, 2, 0), Vector3i(1, 2, 0)] as Array[Vector3i]
	var room_by_cell := {
		Vector3i(-1, 3, 0): &"room.left",
		Vector3i(2, 3, 0): &"room.right",
		Vector3i(0, 3, 1): &"room.side",
	}
	var seams := WarrenSpatialFabricCompiler._setback_wall_room_ids(row,
		room_by_cell)
	assert_eq(seams, [&"room.left", &"room.right", &"room.side"] \
		as Array[StringName],
		"only exact upper-wall contacts around the cap may receive flashing")


func test_flashing_allows_a_thin_subcell_join_not_a_deep_overlap() -> void:
	var cap := AABB(Vector3.ZERO, Vector3(3.0, 0.16, 1.5))
	assert_true(WarrenSpatialFabricCompiler._is_shallow_flashing_contact(cap,
		AABB(Vector3(0.0, 0.04, 0.68), Vector3(3.0, 3.0, 3.0))),
		"a 0.82 m facade projection over a 0.16 m cap is typed flashing")
	assert_false(WarrenSpatialFabricCompiler._is_shallow_flashing_contact(cap,
		AABB(Vector3(0.0, 0.04, 0.45), Vector3(3.0, 3.0, 3.0))),
		"more than the half-cell authored allowance remains an overlap")
	assert_false(WarrenSpatialFabricCompiler._is_shallow_flashing_contact(
		AABB(Vector3.ZERO, Vector3(3.0, 1.2, 1.5)),
		AABB(Vector3(0.0, 0.04, 0.68), Vector3(3.0, 3.0, 3.0))),
		"a tall terrace cannot masquerade as thin flashing")


func test_one_parent_shoulder_never_becomes_a_pile_of_sibling_gables() -> void:
	var faces: Array[Vector3i] = [
		Vector3i(0, 3, 0), Vector3i(1, 3, 0),
		Vector3i(0, 3, 1), Vector3i(1, 3, 1),
		Vector3i(2, 3, 1), Vector3i(3, 3, 1),
		Vector3i(2, 3, 2), Vector3i(3, 3, 2),
	]
	var pieces := WarrenSpatialFabricCompiler._cap_pieces(faces)
	var macro_count := 0
	var realized: Dictionary = {}
	for piece: Dictionary in pieces:
		macro_count += int(StringName(piece.kind) == &"stamp")
		for cell: Vector3i in piece.cells as Array[Vector3i]:
			realized[cell] = true
	assert_eq(macro_count, 1,
		"one parent may own one recognizable gable crown, never sibling roof cubes")
	assert_eq(realized.size(), faces.size())


func test_spatial_roofs_admit_only_complete_atomic_t_valleys() -> void:
	assert_true(WarrenSpatialFabricCompiler._spatial_roof_join_supported(
		FabricRoofTopologyPlan.JunctionKind.RIDGE_CONTINUATION))
	assert_false(WarrenSpatialFabricCompiler._spatial_roof_join_supported(
		FabricRoofTopologyPlan.JunctionKind.PARALLEL_VALLEY))
	assert_true(WarrenSpatialFabricCompiler._spatial_roof_join_supported(
		FabricRoofTopologyPlan.JunctionKind.PERPENDICULAR_VALLEY))
	assert_true(WarrenSpatialFabricCompiler._spatial_roof_join_supported(
		FabricRoofTopologyPlan.JunctionKind.STEPPED_EAVE_WALL))


func test_rowhouse_roof_axis_and_join_follow_the_broad_frontage_contract() \
		-> void:
	var proposals: Array[Dictionary] = [
		{"stable_id": &"row.left", "kind": &"row",
			"origin": Vector3i.ZERO, "yaw_quarters": 0, "storeys": 1},
		{"stable_id": &"row.right", "kind": &"row",
			"origin": Vector3i(4, 0, 0), "yaw_quarters": 0, "storeys": 1},
	]
	var topology := FabricRoofTopologyPlan.build(proposals)
	assert_not_null(topology)
	if topology == null:
		return
	assert_eq(int(topology.audit.junction_count), 1)
	var seam := (topology.fact(&"row.left").junctions as Array)[0] \
		as Dictionary
	assert_eq(int(seam.kind),
		FabricRoofTopologyPlan.JunctionKind.RIDGE_CONTINUATION,
		"side-by-side rowhouses continue their local-X ridge")
	assert_false(FabricRoofJunctionModuleTable.build(proposals,
		topology).is_empty(), FabricRoofJunctionModuleTable.last_failure)


func test_measured_room_units_preserve_every_spatial_stamp() -> void:
	var program := SettlementFabricProgram.compile(
		EnvironmentCatalog.load_default())
	assert_not_null(program)
	# Keep this integration fixture on a production survivor that exercises the
	# current roof contract. Seed 8 seals two exact partial gables, one prefab
	# landmark, and eleven facade projections; the former fixture now correctly
	# rejects because no complete gabled closure can avoid its public air.
	var spatial := WarrenVolumetricSolver.solve(8, {}, program,
		WarrenVillageScaleProfile.for_id(WarrenVillageScaleProfile.COMPACT))
	assert_not_null(spatial, WarrenVolumetricSolver.last_failure)
	if program == null or spatial == null:
		return
	# Source bridge sites are seed-dependent and are proved in the carver corpus.
	# This exact production fixture owns the visual ratchet below: its derived
	# two-cell upper crossing must compile into an enclosed house wing without
	# displacing the large reviewed landmark.
	assert_gte(int(spatial.audit.get(
		"spatial_prefab_landmark_building_count", 0)), 1,
		"the source bridge may not displace the large blue-roof landmark")
	for building: WarrenBuildingVolume in spatial.buildings:
		for room: WarrenRoomStamp in building.room_records:
			var bridge_supports := room.audit.get(
				"bridge_support_room_ids", []) as Array
			assert_ne(bridge_supports.size(), 1,
				("residual room %s may be a two-sided skywalk or an ordinary " \
				+ "borne room, never a one-flank 3 m box") % room.stable_id)
			assert_false(bool(room.audit.get(
				"bridge_is_bracketed_jetty", false)),
				"brackets do not turn a full one-cell room into an outcropping")
	var realm := WarrenSpatialPublicRealmAdapter.from_spatial(spatial)
	assert_not_null(realm, WarrenSpatialPublicRealmAdapter.last_failure)
	# The volumetric transaction already ran the exact measured room-envelope
	# gate and sealed its chosen units. Consume that authoritative result here,
	# as production does, rather than asking a later diagnostic pass to choose a
	# second roof/facade campaign for an already sealed town.
	var units := spatial.compiled_room_units_cache()
	var room_audit := spatial.compiled_room_audit_cache()
	assert_gt(units.size(), 0, "the sealed spatial solve lost its room units")
	var expected_portals := _expected_feature_portals(spatial)
	# The shrunken production fixture currently carries no balcony/skywalk
	# portal. Keep its exact zero-capable reconciliation here; the standard
	# planner fixture below supplies the non-vacuous portal coverage.
	assert_eq(int(room_audit \
		.feature_portal_room_count),
		(expected_portals.rooms as Dictionary).size())
	assert_eq(int(room_audit \
		.feature_portal_opening_count),
		(expected_portals.openings as Dictionary).size())
	assert_gt(int(room_audit \
		.selected_facade_phase_b_count), 0,
		"some upper storeys should retain the alternate authored facade phase")
	assert_gt(int(room_audit \
		.facade_phase_a_count), 0,
		"the town should not synchronize onto one facade phase")
	assert_true(room_audit.has(
		"physical_support_redirect_count"),
		"support redirects are corpus-dependent, but the audit must be present")
	assert_eq(int(room_audit \
		.desired_facade_phase_b_count),
		int(room_audit \
			.selected_facade_phase_b_count) \
			+ int(room_audit \
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
	var constructed_arcade_overhang_supports := 0
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
		constructed_arcade_overhang_supports += int(
			feature.kind == &"arcade_overhang_support")
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
	assert_eq(int(WarrenSpatialFabricCompiler.last_audit \
		.covered_market_feature_count), constructed_markets)
	# TASK F1, MEASURED 2026-08-24. This fixture never set the generation
	# mode, so it was building the SEARCHED town for the production city seed
	# while production shipped the one-pass one. Re-pointed at the town that
	# really ships, the hero-feature quotas it pinned (one bazaar, four
	# landmarks) are shortfalls the one-pass path publishes rather than
	# refuses. What stays hard is that the compiler REALIZES exactly what the
	# spatial plan reserved, which the equalities above assert.
	#
	# TASK F1 FIX 1, finding I2. The market floor is ASSERTED here, not
	# printed. Three facts, none of which forbids a future task from building
	# the bazaar back:
	#   1. a direct scan of the compiled units must agree with the audit
	#      counter, so a counter that silently reads zero while units exist
	#      (the roof-counter reading F1 filed as a defect, and F3 measured as
	#      a NAME reading zero about a different set -- see the setback block
	#      below) cannot hide here;
	#   2. every market unit the compiler emitted must be a market feature
	#      the plan reserved -- the compiler may not invent one;
	#   3. a marketless town must DECLARE it. Measured on this seed the town
	#      ships with no bazaar at all, and the only thing that makes that
	#      honest rather than silent is the published shortfall.
	# MEASURED: `_preplan_spatial_market` forms exactly one canopy candidate
	# and its own viability filter drops it (open horizon 10 cells against a
	# compact limit of 4), so no reservation is ever made -- market-ness stops
	# at preplan, not at construction.
	#
	# TASK F3 MEMBER 3, CLASSIFIED HONEST AND PINNED BELOW. There is no repair
	# to make. That 10 is `MARKET_SHELTER_HORIZON_LIMIT_CELLS` itself -- the
	# sight ray walked its whole reach without meeting mass -- so this
	# candidate is not a near miss at a cap tuned for searched towns; it is a
	# bazaar mouth looking straight out of the hill, which is the one thing
	# `_market_shelter_audit` exists to catch. Corpus-wide, only eleven
	# candidates exist across 25 towns, at horizons 2, 4 (x4), 8 and 10 (x5);
	# the lone 8 belongs to a town that already builds its bazaar from a
	# better-ranked 4, so no cap between 5 and 9 gives any town a market it
	# does not already have. `compact` also has
	# `requires_covered_market = false`: this settlement is one of nineteen
	# that ship without a bazaar, and the published shortfall is what makes
	# that honest. The reason so few candidates form at all is
	# `_market_public_aisle`, not the horizon -- a Phase G design question.
	var market_units := 0
	for feature_unit: FabricUnit in features:
		market_units += int(program.recipe(feature_unit.recipe_id)
			.has_tag(&"covered_market"))
	assert_eq(int(WarrenSpatialFabricCompiler.last_audit \
		.covered_market_feature_count), constructed_markets,
		"the covered-market counter must agree with the reserved features")
	assert_lte(market_units, constructed_markets * COVERED_MARKET_UNIT_CEILING,
		"the compiler emitted market units for a market nobody reserved")
	assert_eq(market_units == 0, constructed_markets == 0,
		"a reserved market must compile to units, and units imply a reservation")
	var shortfalls := spatial.audit.get("advisory_shortfalls",
		{}) as Dictionary
	if constructed_markets == 0:
		assert_true(shortfalls.has("covered_market"),
			("the town ships with no bazaar and does not say so; an " \
				+ "undeclared absence is the thing task F3 has to trace"))
		assert_eq(int(shortfalls.get("covered_market", -1)), 0,
			"the published market shortfall must report the real count")
	gut.p("one-pass town: markets=%d market_units=%d shortfall=%s" % [
		constructed_markets, market_units,
		str(shortfalls.get("covered_market", "<none>"))])
	# TASK F3 MEMBER 3. The pin that makes the classification above falsifiable
	# rather than a paragraph: WHY this town has no bazaar, read off the
	# solver's own preplan diagnostic. A future change that gives it one, or
	# that moves the funnel, has to come through here and say so.
	var market_preplan := WarrenVolumetricSolver.last_preplan_market_diagnostic
	assert_eq(int(market_preplan.get("candidate_count", -1)),
		int(market_preplan.get("clearance_fit_count", -2)),
		"every candidate that clears its visual envelope becomes a candidate")
	# TASK I1. This was `> 0` and it is now MEASURED ZERO, which is a change of
	# diagnosis and is pinned as one rather than relaxed. F3 classified this
	# town as "a bazaar mouth looking straight out of the hill" -- one candidate
	# formed and dropped by a saturated sight ray. On the shrunk footprint the
	# production town forms NO canopy candidate at all: the ground street that
	# used to offer one is shorter, and `_preplan_spatial_market` never gets a
	# run of cells to put a canopy over. The town is still marketless and still
	# DECLARES it (the shortfall assertions above are untouched and green); what
	# changed is which stage the market-ness stops at, and this pin is what
	# makes the next reader see that rather than inherit F3's paragraph.
	assert_eq(int(market_preplan.get("candidate_count", -1)),
		PRODUCTION_MARKET_CANDIDATES,
		("this seed forms %d canopy candidates against the pinned %d; the " \
			+ "diagnosis in the note above is about a town that forms exactly " \
			+ "that many") % [int(market_preplan.get("candidate_count", -1)),
			PRODUCTION_MARKET_CANDIDATES])
	var market_previews := market_preplan.get("shelter_preview", []) as Array
	assert_eq(market_previews.size(),
		int(market_preplan.get("candidate_count", -1)),
		"the shelter preview must describe every candidate this town formed")
	for preview: Dictionary in market_previews:
		assert_eq(int(preview.get("open_max", -1)),
			WarrenVolumetricSolver.MARKET_SHELTER_HORIZON_LIMIT_CELLS,
			("this town's bazaar candidate is refused by a SATURATED sight " \
				+ "ray, not by a cap it nearly met; retuning the cap inside " \
				+ "the ray's range cannot admit it"))
	assert_eq(int(market_preplan.get("backing_fit_count", -1)), 0,
		"no candidate reached the backing check, so it explains nothing here")
	gut.p("one-pass town: market candidates=%d open_max=%s limit=%d ray=%d" % [
		int(market_preplan.get("candidate_count", -1)),
		str((market_previews[0] as Dictionary).get("open_max", -1)) \
			if not market_previews.is_empty() else "<no candidate>",
		int(market_preplan.get("open_horizon_limit_cells", -1)),
		WarrenVolumetricSolver.MARKET_SHELTER_HORIZON_LIMIT_CELLS])
	assert_eq(int(WarrenSpatialFabricCompiler.last_audit \
		.balcony_feature_count), constructed_balconies)
	assert_eq(int(WarrenSpatialFabricCompiler.last_audit \
		.room_outcropping_support_feature_count),
		constructed_outcropping_supports)
	assert_eq(int(WarrenSpatialFabricCompiler.last_audit \
		.frontier_gateway_support_feature_count),
		constructed_frontier_gateway_supports)
	assert_eq(int(WarrenSpatialFabricCompiler.last_audit \
		.arcade_overhang_support_feature_count),
		constructed_arcade_overhang_supports)
	assert_eq(int(WarrenSpatialFabricCompiler.last_audit \
		.tower_annex_feature_count), constructed_tower_annexes)
	assert_eq(constructed_tower_annexes,
		int(spatial.audit.tower_annex_count))
	assert_gte(int(spatial.audit.tower_annex_relief_unit_count),
		int(spatial.audit.required_tower_annex_relief_unit_count))
	assert_eq(int(WarrenSpatialFabricCompiler.last_audit \
		.prefab_landmark_feature_count), constructed_landmarks)
	gut.p("one-pass town: landmarks=%d" % constructed_landmarks)
	assert_eq(int(WarrenSpatialFabricCompiler.last_audit \
		.feature_reserved_cell_count), expected_feature_cells)
	for feature_unit: FabricUnit in features:
		var feature_recipe := program.recipe(feature_unit.recipe_id)
		assert_true(feature_recipe.has_tag(&"skywalk") \
			or feature_recipe.has_tag(&"covered_market") \
			or feature_recipe.has_tag(&"balcony") \
			or feature_recipe.has_tag(&"cantilever_support") \
			or feature_recipe.has_tag(&"outcropping") \
			or feature_recipe.has_tag(&"interstitial_join") \
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
	# TASK F1, MEASURED. The dormer / rejected-pitch / setback-cap floors this
	# block pinned describe the SEARCHED town; the one-pass town for this seed
	# measures 0 / 0 / 0 against 7 pitched roofs. Recorded rather than
	# enforced: F1 only deletes, and giving the shipped town its dormers and
	# sheds back is a quality task, not a deletion. The counters must still
	# EXIST -- an absent key is a broken transaction.
	#
	# TASK F3 MEMBER 2, DIAGNOSED. The zero is HONEST -- no eligible dormer is
	# dropped on the way to a unit; the town simply has none to drop. A
	# dormered crown needs three independent facts to coincide: the plot model
	# must have asked this crown for a pitched shell
	# (`plot_prefers_pitched_roof`), the room must be above the ground storey
	# (`_full_roof_recipe_id` gives storey 0 a `.short.` roof), and its
	# `roof_feature` must be 1 or 2. MEASURED on this town under C5d: 40 roofed
	# crowns, 8 asked for a pitched shell, 7 got one, and the 2 crowns whose
	# recipe would have been dormered were ordinary flat crowns that never
	# asked -- the two sets were disjoint by seed, not by rule.
	#
	# TASK H2 IS THE "PHASE G CONVERSATION" THIS NOTE ANTICIPATED, and it
	# happened: `plot_prefers_pitched_roof` no longer asks for a plot strictly
	# above every neighbour and then a coin, it asks for a crown nothing stands
	# on. The pitched population multiplied and the dormers came with it --
	# 4 dormer units across the six-town identity corpus before, 22 after -- so
	# the assertions below are `assert_gte` on the counters EXISTING rather
	# than a pinned zero, and the number they read is now the roofscape's.
	#
	# The 0 setback sheds are the same shape: a shed only exists inside the
	# finite setback vocabulary, and a maze flat crown reaches that vocabulary
	# only when its slab AND its tiling both fail. Corpus-wide
	# `maze_partial_plate_refused_count` is 0 on all 24 towns, 3 towns reach
	# the vocabulary at all (through residual rooms), and 2 of those 3 build
	# sheds when they do.
	for roof_key: String in ["dormered_pitched_roof_count",
			"rejected_pitched_count", "setback_vocabulary_unit_count",
			"setback_cap_recipe_unit_count", "dormered_roof_unit_count"]:
		assert_true(WarrenSpatialFabricCompiler.last_audit.has(roof_key),
			"the roof campaign never measured %s" % roof_key)
	assert_false(WarrenSpatialFabricCompiler.last_audit.has(
		"setback_cap_unit_count"),
		("`setback_cap_unit_count` is the name that caused two independent " \
			+ "misreadings and it is retired; a reader wanting the town's " \
			+ "cap units wants `setback_cap_recipe_unit_count`"))
	gut.p("one-pass town: dormered=%d rejected_pitched=%d setback_units=%d pitched=%d" % [
		int(WarrenSpatialFabricCompiler.last_audit.dormered_pitched_roof_count),
		int(WarrenSpatialFabricCompiler.last_audit.rejected_pitched_count),
		int(WarrenSpatialFabricCompiler.last_audit.setback_vocabulary_unit_count),
		int(WarrenSpatialFabricCompiler.last_audit.pitched_roof_count)])
	assert_eq(int(WarrenSpatialFabricCompiler.last_audit \
		.setback_terrace_unit_count), 0,
		"an inaccessible roof shoulder must never masquerade as a balcony")
	assert_eq(int(WarrenSpatialFabricCompiler.last_audit \
		.setback_plain_cap_unit_count),
		0, "an exposed shoulder must resolve to a gable, lean-to, roof join, " \
			+ "or deliberate large platform, never a modular lid")
	assert_true(WarrenSpatialFabricCompiler.last_audit.has(
		"setback_shed_unit_count"),
		"the roof campaign never measured setback_shed_unit_count")
	gut.p("one-pass town: setback_shed=%d setback_plain_cap=%d setback_terrace=%d" % [
		int(WarrenSpatialFabricCompiler.last_audit.setback_shed_unit_count),
		int(WarrenSpatialFabricCompiler.last_audit.setback_plain_cap_unit_count),
		int(WarrenSpatialFabricCompiler.last_audit.setback_terrace_unit_count)])
	assert_true(WarrenSpatialFabricCompiler.last_audit.has(
		"setback_garden_unit_count"),
		"roof gardens are optional within a sealed roof campaign")
	assert_true(WarrenSpatialFabricCompiler.last_audit.has(
		"setback_terrace_fallback_count"),
		"fallback attempts are diagnostic; only the sealed result is authoritative")
	assert_eq(int(WarrenSpatialFabricCompiler.last_audit \
		.bare_flat_roof_count), 0,
		"collision pressure must not turn a roof into an undressed plank cube")
	assert_eq(int(WarrenSpatialFabricCompiler.last_audit \
		.broken_atomic_roof_neighborhood_count), 0)
	var setback_cap_roofs := 0
	var setback_vocabulary_roofs := 0
	var cap_roofs_from_vocabulary := 0
	var cap_roofs_from_tiling := 0
	var cap_roofs_from_elsewhere := 0
	var partial_gable_roofs := 0
	var partial_gables_from_tiling := 0
	var private_canopy_tiles := 0
	var dormered_roofs := 0
	for roof: FabricUnit in roofs:
		# `_cap_unit` is the only producer of a `.capNN` unit id and every
		# setback piece goes through it; `_tile_flat_plate` is the only
		# producer of a `.tileNN` one. Neither segment can appear in a room id
		# (`spatial.<parcel>.partNN.roomNN`, `spatial.maze_back.NN.roomNN`), so
		# the stable id says WHICH PRODUCER made each unit and the direct scan
		# can be partitioned by it.
		var from_vocabulary := String(roof.stable_id).contains(".cap")
		var from_tiling := String(roof.stable_id).contains(".tile")
		setback_vocabulary_roofs += int(from_vocabulary)
		if String(roof.recipe_id).begins_with("roof.setback.cap."):
			setback_cap_roofs += 1
			cap_roofs_from_vocabulary += int(from_vocabulary)
			cap_roofs_from_tiling += int(from_tiling)
			cap_roofs_from_elsewhere += int(not from_vocabulary \
				and not from_tiling)
		if String(roof.recipe_id).begins_with("roof.partial.gable."):
			partial_gable_roofs += 1
			partial_gables_from_tiling += int(from_tiling)
		if from_tiling and String(roof.recipe_id).begins_with(
				"roof.setback.shed."):
			private_canopy_tiles += 1
		var roof_recipe := program.recipe(roof.recipe_id)
		dormered_roofs += int(roof_recipe.has_tag(&"dormer"))
		assert_true(WarrenSpatialFabricCompiler._unit_public_air_conflicts(
			spatial.grid, roof, roof_recipe).is_empty(),
			"the exact collidable roof shell may not enter a public body lane")
		assert_true(fabric.add_unit(roof), fabric.last_rejection)
	# Producer identity is part of the roof contract. Private `.tileNN` units
	# must be exact compact-gable halves; a cap tile is legal only for the public
	# floor branch. The direct scan and published histogram must reconcile so a
	# later fallback cannot silently reintroduce window canopies or bare boards.
	assert_eq(int(WarrenSpatialFabricCompiler.last_audit \
		.setback_cap_recipe_unit_count), setback_cap_roofs,
		"the town's roof.setback.cap.* units must equal a direct scan")
	assert_eq(int(WarrenSpatialFabricCompiler.last_audit \
		.setback_vocabulary_unit_count), setback_vocabulary_roofs,
		"the setback vocabulary's unit count must equal a direct scan of the " \
			+ "units it produced")
	assert_eq(int(WarrenSpatialFabricCompiler.last_audit \
		.dormered_roof_unit_count), dormered_roofs,
		"the town's dormered roof units must equal a direct scan")
	assert_gte(int(WarrenSpatialFabricCompiler.last_audit \
		.dormered_roof_unit_count),
		int(WarrenSpatialFabricCompiler.last_audit \
			.dormered_pitched_roof_count),
		"the whole-town dormer scan must contain the pitched campaign's own")
	assert_eq(cap_roofs_from_elsewhere, 0,
		("every roof.setback.cap.* unit is made by `_cap_unit` or " \
			+ "`_tile_flat_plate` and says so in its stable id; a third " \
			+ "producer would hide here"))
	assert_eq(cap_roofs_from_vocabulary + cap_roofs_from_tiling,
		setback_cap_roofs,
		"the two producers must partition the cap-recipe scan exactly")
	assert_eq(cap_roofs_from_tiling,
		_tiled_setback_caps(WarrenSpatialFabricCompiler.last_audit),
		"the tiling's published histogram must equal its own units")
	assert_eq(partial_gables_from_tiling, partial_gable_roofs,
		"every partial gable must come from the exact crown-tiling transaction")
	assert_eq(partial_gables_from_tiling,
		_tiled_partial_gables(WarrenSpatialFabricCompiler.last_audit),
		"the partial-gable histogram must equal the selected units")
	assert_gt(partial_gable_roofs, 0,
		"the pinned partial-crown fixture must exercise real gable halves")
	assert_eq(private_canopy_tiles, 0,
		"a window canopy is not a legal private weather roof")
	assert_eq(cap_roofs_from_vocabulary,
		int(WarrenSpatialFabricCompiler.last_audit \
			.setback_plain_cap_unit_count) \
			+ int(WarrenSpatialFabricCompiler.last_audit \
				.maze_lid_repair_cap_count),
		("the vocabulary's own cap units are its plain caps plus its " \
			+ "lid-repaired strips, and nothing else takes that recipe there"))
	assert_lte(cap_roofs_from_vocabulary, setback_vocabulary_roofs,
		"the vocabulary's cap units are a subset of its units")
	assert_eq(int(WarrenSpatialFabricCompiler.last_audit \
		.maze_partial_plate_refused_count), 0,
		"the complete private/public roof vocabulary must close every partial crown")
	gut.p("one-pass town: cap_recipe_units=%d of %d roofs (vocabulary=%d tiling=%d other=%d) partial_gables=%d setback_units=%d dormered_units=%d" % [
		setback_cap_roofs, roofs.size(), cap_roofs_from_vocabulary,
		cap_roofs_from_tiling, cap_roofs_from_elsewhere,
		partial_gable_roofs, setback_vocabulary_roofs, dormered_roofs])
	var sealed := WarrenSpatialFabricCompiler.solve(spatial, program)
	assert_not_null(sealed, WarrenSpatialFabricCompiler.last_failure)
	if sealed != null:
		for feature: WarrenFeatureReservation in spatial.features:
			if feature.kind != &"room_overhang_support" \
					or StringName(feature.audit.get(
						"overhang_support_material", &"")) != &"timber":
				continue
			for record: Dictionary in feature.construction_records:
				assert_true(String(record.recipe_id).begins_with(
					"outcrop.support.bracketed."),
					("ordinary room jetty %s must use a compact wall bracket; " \
					+ "a storey-height diagonal reads as a dangling pole") \
					% feature.stable_id)
		assert_true(sealed.is_sealed())
		assert_eq(sealed.audit.generation_source, &"spatial_volumetric_warren")
		assert_lte(int(sealed.audit.get(
			"maze_skin_max_consecutive_facade_storeys", 99)), 1,
			"no retained face may read as a multi-storey white/timber wall")
		assert_eq(int(sealed.audit.get(
			"maze_skin_tall_course_mismatch_count", -1)), 0,
			"tall faces must alternate authored stone and facade courses")
		assert_gt(int(sealed.audit.get(
			"maze_tall_bank_masonry_panel_count", 0)), 0,
			"tall facade courses must be interrupted by stone siding")
		var facade_projections := int(sealed.audit.get(
			"maze_facade_bay_count", 0)) + int(sealed.audit.get(
				"maze_facade_bump_out_count", 0))
		assert_gte(facade_projections, 8,
			"the fixed city must materially break up its flat facade planes")
		assert_eq(int(sealed.audit.get(
			"maze_facade_outcrop_bracket_count", -1)),
			2 * facade_projections,
			"every facade projection must carry two connected supports")
		assert_eq(int(sealed.audit.get(
			"maze_green_cap_jut_over_air_count", -1)), 0,
			"no grass panel may extend over an unsupported gap")
		assert_eq(int(sealed.audit.get("maze_garden_rim_deficit", -1)), 0,
			"every grass-panel edge must receive its aligned lip")
		# TASK F3 MEMBER 6. Retained stone is mass NOBODY built in. The plan's
		# own `set_retained_terrace` guard says so and, with its key type
		# fixed, enforces it -- but a guard that rejects the whole town is a
		# last resort, so the compiler must not offer it an overlap in the
		# first place. Asserted as the disjointness it is, over the whole
		# channel: the D1 `step/3/standard` row used to lay six plinth-span
		# cells straight through two houses' `roof.flat.*` crowns, and nothing
		# anywhere would have said so.
		var built_solid := sealed.transformed_cells(&"solid")
		var terrace_overlap := 0
		for terrace_value: Variant in sealed.retained_terrace_cells.keys():
			terrace_overlap += int(built_solid.has(terrace_value))
		assert_eq(terrace_overlap, 0,
			"the retained hill may not claim a cell the fabric built in")
		assert_eq(int(sealed.audit.retained_foundation_built_in_cell_count),
			0, "no plinth cell on this town is inside built mass")
		assert_gt(sealed.retained_terrace_cells.size(), 0,
			"this seed must still retain a hill for the check above to mean something")
		assert_gt(int(sealed.audit.foundation_building_count), 0,
			"the reviewed terrain relief must exercise retained stone courses")
		assert_eq(int(sealed.audit.foundation_closed_shell_count),
			int(sealed.audit.foundation_building_count),
			"every retained base must close its complete four-sided perimeter")
		assert_eq(int(sealed.audit.foundation_incomplete_shell_count), 0)
		assert_eq(int(sealed.audit.foundation_missing_face_count), 0)
		assert_eq(int(sealed.audit.foundation_floating_column_count), 0,
			"a 3 m foundation module must reach the stamped natural ground")
		assert_eq(int(sealed.audit.foundation_rendered_face_count),
			int(sealed.audit.foundation_expected_face_count))
		assert_gt(int(sealed.audit.modular_box_room_count), 0,
			"the reviewed seed must exercise compact modular construction")
		assert_eq(int(sealed.audit.modular_box_room_count),
			int(sealed.audit.modular_box_roofed_house_count) \
				+ int(sealed.audit.modular_box_support_course_count) \
				+ int(sealed.audit.modular_box_skywalk_count),
			"every 3 m cuboid must be a roofed house, a borne stack course, " \
				+ "or a typed two-ended skywalk")
		assert_eq(int(sealed.audit.enclosed_skywalk_count),
			int(sealed.audit.modular_box_skywalk_count),
			"the sealed richness audit must count the maze bridge it built")
		assert_eq(int(sealed.audit.collision_flattened_roof_component_count), 0,
			"a measured roof collision must reject construction, never flatten it")
		assert_eq(int(sealed.audit.modular_box_partial_bearing_count), 0,
			"a 3 m room may not become a bracketed box jutting from a facade")
		assert_eq(int(sealed.audit.modular_box_roofless_house_count), 0)
		assert_eq(int(sealed.audit.modular_box_unclassified_count), 0)
		assert_eq(int(sealed.audit.orphan_exterior_door_module_count), 0,
			"a visible facade door must be an entrance or typed private portal")
		assert_eq(int(sealed.audit.entrance_surface_gap_count), 0,
			"every exterior door must open onto an exact rendered floor claim")
		assert_eq(int(sealed.audit.unserved_entrance_count), 0)
		assert_eq(int(sealed.audit.missing_source_route_floor_count), 0,
			"spatial construction may not drop a floor owned by the bore")
		assert_eq(int(sealed.audit.transition_mesh_count),
			int(spatial.source_volume.audit.ramp_transition_count)
				+ int(spatial.source_volume.audit.stair_transition_count),
			"every logical vertical transition needs visible collision geometry")
		assert_gt(int(sealed.audit.transition_triangle_count), 0,
			"the reviewed spatial seed must realize its connected climbs")
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


func test_typed_balcony_endpoint_drives_the_exact_room_portal_mask() -> void:
	# Portal reduction is a topology adapter, so exercise its exact typed input
	# directly instead of depending on an aesthetic feature quota in one random
	# production town. A valid town may legitimately roll no balcony at all.
	var source := WarrenSpatialPlan.new(&"portal.fixture", 23,
		WarrenSpatialGrid.new(Vector3i(-4, 0, -4), Vector3i(9, 5, 9)))
	var room := WarrenRoomStamp.new(&"portal.room", &"portal.building",
		&"tower", Vector3i.ZERO, 0, 0, true, false)
	var feature := WarrenFeatureReservation.new(&"portal.balcony", &"balcony")
	assert_true(feature.add_reserved_cells([Vector3i(0, 0, -2)] \
		as Array[Vector3i]))
	assert_true(feature.add_endpoint(Vector3i(0, 0, -1), room.stable_id))
	assert_true(feature.add_construction_record(&"balcony.bracketed.left.blue",
		Vector3i(0, 0, -2), 0))
	feature.audit = {"balcony_room_id": room.stable_id,
		"balcony_endpoint_facing": Vector3i.FORWARD}
	source.features.append(feature)
	var masks := WarrenSpatialFabricCompiler._feature_portal_masks(source,
		{room.stable_id: room})
	assert_eq(masks.size(), 1)
	assert_eq(int(masks.get(room.stable_id, 0)),
		SettlementFabricProgram.FEATURE_PORTAL_NORTH,
		"the authored north balcony opens only the room's north centre bay")


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
