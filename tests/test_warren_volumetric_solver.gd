extends GutTest

static var _program_cache: SettlementFabricProgram


func _program() -> SettlementFabricProgram:
	if _program_cache == null:
		_program_cache = SettlementFabricProgram.compile(
			EnvironmentCatalog.load_default())
	return _program_cache


func test_skywalk_flanks_must_be_opposite_independent_buildings() -> void:
	var west := {"room_id": &"west.room", "building_id": &"west.house"}
	var east := {"room_id": &"east.room", "building_id": &"east.house"}
	assert_true(WarrenVolumetricSolver._bridge_flank_pair_is_two_ended(
		Vector3i.LEFT, Vector3i.RIGHT, west, east),
		"two independent opposite endpoints form a skywalk")
	assert_false(WarrenVolumetricSolver._bridge_flank_pair_is_two_ended(
		Vector3i.LEFT, Vector3i.BACK, west, east),
		"a corner contact is an outcropping, not a skywalk")
	var same_building := {
		"room_id": &"east.wing", "building_id": &"west.house"}
	assert_false(WarrenVolumetricSolver._bridge_flank_pair_is_two_ended(
		Vector3i.LEFT, Vector3i.RIGHT, west, same_building),
		"two wings of one building cannot disguise a cantilever as a skywalk")
	assert_false(WarrenVolumetricSolver._bridge_flank_pair_is_two_ended(
		Vector3i.LEFT, Vector3i.RIGHT, west, west),
		"one room cannot carry both ends")


func test_raw_single_macro_rock_crown_descends_to_a_joined_terrace() -> void:
	var grid := WarrenSpatialGrid.new(Vector3i(-8, -2, -8),
		Vector3i(16, 8, 16))
	var candidates: Array[Vector3i] = []
	var derived: Dictionary = {}
	for macro: Vector3i in [Vector3i(0, 0, 0), Vector3i(0, 1, 0),
			Vector3i(1, 0, 0)]:
		for fine: Vector3i in WarrenVolumetricSolver._fine_square(macro):
			candidates.append(fine)
			derived[fine] = &"derived"
	var result := WarrenVolumetricSolver \
		._release_singleton_unclassified_rock_crowns(grid, candidates, derived)
	assert_eq(int(result.released_cells), 4,
		"the isolated upper course yields as raw terrain")
	assert_eq(int(result.released_derived_cells), 4)
	assert_eq(int(result.released_unroomed_plot_cells), 0)
	assert_eq(int(result.released_roof_band_cells), 0)
	assert_eq(int(result.remaining_crowns), 0)
	assert_eq((result.cells as Array).size(), 8,
		"the two-column lower terrace remains intact")


func test_two_macro_rock_crowns_form_a_ridge_instead_of_being_deleted() -> void:
	var grid := WarrenSpatialGrid.new(Vector3i(-8, -2, -8),
		Vector3i(16, 8, 16))
	var candidates: Array[Vector3i] = []
	var derived: Dictionary = {}
	for macro: Vector3i in [Vector3i(0, 0, 0), Vector3i(1, 0, 0),
			Vector3i(0, 1, 0), Vector3i(1, 1, 0)]:
		for fine: Vector3i in WarrenVolumetricSolver._fine_square(macro):
			candidates.append(fine)
			derived[fine] = &"derived"
	var result := WarrenVolumetricSolver \
		._release_singleton_unclassified_rock_crowns(grid, candidates, derived)
	assert_eq(int(result.released_cells), 0,
		"a connected ridge is legitimate terrain mass")
	assert_eq(int(result.remaining_crowns), 0)
	assert_eq((result.cells as Array).size(), candidates.size())


func test_uncomposed_plot_crown_cannot_survive_as_a_raw_rock_cube() -> void:
	var grid := WarrenSpatialGrid.new(Vector3i(-8, -2, -8),
		Vector3i(16, 8, 16))
	var candidates: Array[Vector3i] = []
	var erodible: Dictionary = {}
	for macro: Vector3i in [Vector3i(0, 0, 0), Vector3i(0, 1, 0),
			Vector3i(1, 0, 0)]:
		for fine: Vector3i in WarrenVolumetricSolver._fine_square(macro):
			candidates.append(fine)
			erodible[fine] = &"unroomed_plot" \
				if macro.y == 1 else &"derived"
	var result := WarrenVolumetricSolver \
		._release_singleton_unclassified_rock_crowns(grid, candidates,
			erodible)
	assert_eq(int(result.released_cells), 4)
	assert_eq(int(result.released_derived_cells), 0)
	assert_eq(int(result.released_unroomed_plot_cells), 4,
		"an unbuilt plot crown is raw mass, not an implicit roofless tower")
	assert_eq(int(result.released_roof_band_cells), 0)
	assert_eq(int(result.remaining_crowns), 0)


func test_unused_plot_roof_band_cannot_survive_as_a_raw_rock_cube() -> void:
	var grid := WarrenSpatialGrid.new(Vector3i(-8, -2, -8),
		Vector3i(16, 8, 16))
	var candidates: Array[Vector3i] = []
	var erodible: Dictionary = {}
	for macro: Vector3i in [Vector3i(0, 0, 0), Vector3i(0, 1, 0),
			Vector3i(1, 0, 0)]:
		for fine: Vector3i in WarrenVolumetricSolver._fine_square(macro):
			candidates.append(fine)
			erodible[fine] = &"stone_roof" \
				if macro.y == 1 else &"derived"
	var result := WarrenVolumetricSolver \
		._release_singleton_unclassified_rock_crowns(grid, candidates,
			erodible)
	assert_eq(int(result.released_cells), 4)
	assert_eq(int(result.released_derived_cells), 0)
	assert_eq(int(result.released_unroomed_plot_cells), 0)
	assert_eq(int(result.released_roof_band_cells), 4,
		"an unused source roof band is raw mass, not an implicit roofed tower")
	assert_eq(int(result.remaining_crowns), 0)


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


func test_balcony_doorway_preserves_an_unrelated_required_roof() -> void:
	var program := _program()
	var room := _unsealed_room_for_geometry(&"balcony.parent", &"slim",
		Vector3i(4, WarrenSpatialGrid.STOREY_CELLS, -8))
	room.source_parcel_id = &"balcony.parent.parcel"
	var facing := Vector3i.FORWARD
	var portal_bit := WarrenSpatialFabricCompiler._portal_bit_for_facing(facing)
	var portal_id := WarrenSpatialFabricCompiler._room_recipe_id(room, 7,
		false, portal_bit)
	var ordinary_id := WarrenSpatialFabricCompiler._room_recipe_id(room, 7,
		false)
	var portal_recipe := program.recipe(portal_id)
	var ordinary_recipe := program.recipe(ordinary_id)
	assert_not_null(portal_recipe)
	assert_not_null(ordinary_recipe)
	var transform := FabricRecipe.lattice_transform(room.lattice_origin,
		room.yaw_quarters)
	var portal_bounds := transform * portal_recipe.local_clearance_bounds
	var ordinary_bounds := transform * ordinary_recipe.local_clearance_bounds
	# Reserve a thin exact gable edge reached by the portal's projecting jamb but
	# not by the closed facade. This is the general geometry that falsified the
	# former deck-only balcony preflight.
	var roof_bounds := AABB(Vector3(portal_bounds.position.x + 0.5,
		portal_bounds.position.y + 0.5, portal_bounds.position.z),
		Vector3(1.0, 1.0, ordinary_bounds.position.z \
			- portal_bounds.position.z + 0.05))
	assert_true(SettlementFabricPlan._aabb_overlaps_volume(portal_bounds,
		roof_bounds))
	assert_false(SettlementFabricPlan._aabb_overlaps_volume(ordinary_bounds,
		roof_bounds))
	var closure: Dictionary = {
		"owner_room_id": &"unrelated.roof.owner",
		"options": [{
			"recipe_id": &"roof.partial.gable.blue.2.negative",
			"origin": Vector3i.ZERO,
			"yaw_quarters": 0,
			"bounds": roof_bounds,
		}] as Array[Dictionary],
		"allowed_room_ids": {},
	}
	assert_eq(WarrenSpatialFeatureSolver
		._balcony_portal_required_roof_conflict(room, facing, 7, program,
			[closure] as Array[Dictionary]), &"unrelated.roof.owner/roof.partial.gable.blue.2.negative",
		"balcony admission must include its mandatory parent-wall doorway")


func test_optional_facade_bay_preserves_one_finite_gable_option() -> void:
	var bay_bounds := AABB(Vector3.ZERO, Vector3.ONE * 2.0)
	var blocked := [{"owner_room_id": &"roof.owner",
		"bounds": [AABB(Vector3.ONE * 0.5, Vector3.ONE)] as Array[AABB]}] \
		as Array[Dictionary]
	assert_eq(WarrenSpatialFeatureSolver._feature_required_roof_conflict(
		bay_bounds, blocked), &"roof.owner")
	var alternative := blocked.duplicate(true) as Array[Dictionary]
	(alternative[0].bounds as Array[AABB]).append(AABB(
		Vector3(10.0, 0.0, 0.0), Vector3.ONE))
	assert_eq(WarrenSpatialFeatureSolver._feature_required_roof_conflict(
		bay_bounds, alternative), &"",
		"an optional bay may remain when any exact authored gable stays free")
	assert_eq(WarrenSpatialFeatureSolver._feature_required_roof_conflict(
		bay_bounds, blocked, &"roof.owner"), &"",
		("a roofed bay may meet its declared parent roof seam; only unrelated " \
			+ "closure domains are collision obligations"))
	var unrelated := blocked.duplicate(true) as Array[Dictionary]
	(unrelated[0] as Dictionary)["owner_room_id"] = &"unrelated.roof"
	assert_eq(WarrenSpatialFeatureSolver._feature_required_roof_conflict(
		bay_bounds, unrelated, &"roof.owner"), &"unrelated.roof",
		"the parent seam never exempts a neighbouring roof")


func test_room_outcropping_geometry_requires_full_scale_diagonal_overlap() -> void:
	var lower := _unsealed_room_for_geometry(&"lower", &"building",
		Vector3i.ZERO)
	var integrated := _unsealed_room_for_geometry(&"integrated", &"building",
		Vector3i(1, WarrenSpatialGrid.STOREY_CELLS, 1))
	var valid := WarrenSpatialFeatureSolver._room_cantilever_geometry(lower,
		integrated)
	assert_true(bool(valid.valid))
	assert_eq(valid.direction, Vector2i.RIGHT)
	assert_eq(valid.projection_directions,
		[Vector2i.RIGHT, Vector2i.DOWN] as Array[Vector2i])
	assert_eq(int(valid.projection_direction_count), 2)
	assert_true(bool(valid.is_diagonal_overlap))
	assert_eq(int(valid.depth_cells), 1)
	assert_eq(int(valid.extension_column_count), 7)
	assert_eq(int(valid.attachment_span_cells), 5)
	assert_eq(int(valid.bearing_column_count), 9)
	assert_eq(int(valid.overlap_column_count), 9)
	assert_almost_eq(float(valid.bearing_ratio), 9.0 / 16.0, 0.0001)
	var supports := WarrenSpatialFeatureSolver._cantilever_support_records(
		integrated, valid)
	assert_eq(supports.size(), 4,
		"both three-column legs receive native 3 m plus 1.5 m courses")
	var support_directions: Dictionary = {}
	for support: Dictionary in supports:
		assert_eq(StringName(support.recipe_id),
			&"outcrop.support.bracketed.2" \
			if String(support.role).ends_with(".00") \
			else &"outcrop.support.bracketed.1")
		support_directions[FabricRecipe.transform_direction(Vector3i.BACK,
			int(support.yaw_quarters))] = true
	assert_true(support_directions.has(Vector3i.RIGHT))
	assert_true(support_directions.has(Vector3i.BACK))

	var glued_end := _unsealed_room_for_geometry(&"glued", &"building",
		Vector3i(1, WarrenSpatialGrid.STOREY_CELLS, 0))
	var end_result := WarrenSpatialFeatureSolver._room_cantilever_geometry(
		lower, glued_end)
	assert_false(bool(end_result.valid),
		"a one-axis room reads as a box glued to the parent's end")
	assert_eq(StringName(end_result.rejection), &"diagonal_overlap_required")

	var floating := _unsealed_room_for_geometry(&"floating", &"building",
		Vector3i(3, WarrenSpatialGrid.STOREY_CELLS, 3))
	var floating_result := WarrenSpatialFeatureSolver._room_cantilever_geometry(
		lower, floating)
	assert_false(bool(floating_result.valid))
	assert_eq(StringName(floating_result.rejection), &"diagonal_overlap_required")


func test_route_spanning_size_change_retains_its_true_projection_and_portal() \
		-> void:
	## Regression fixture from the reviewed town: half of the rotated slim upper
	## plate bears on a tower and half spans an exact 3 m-wide public route.  A
	## footprint mismatch is not a zero-extension setback.
	var lower := WarrenRoomStamp.new(&"lower", &"source", &"tower",
		Vector3i(-2, 0, 11), 3, 0, true, false)
	lower.private_cells.assign(WarrenRoomStamp.expected_private_cells(
		&"tower", lower.lattice_origin, lower.yaw_quarters))
	var upper := WarrenRoomStamp.new(&"upper", &"source", &"slim",
		Vector3i(-2, WarrenSpatialGrid.STOREY_CELLS, 10), 1, 1, false,
		false)
	upper.private_cells.assign(WarrenRoomStamp.expected_private_cells(
		&"slim", upper.lattice_origin, upper.yaw_quarters))
	var mismatch := WarrenSpatialFeatureSolver._room_cantilever_geometry(
		lower, upper)
	assert_false(bool(mismatch.valid))
	assert_eq(StringName(mismatch.rejection), &"full_scale_overlap_required")
	assert_eq(int(mismatch.bearing_column_count), 4)
	assert_eq(int(mismatch.extension_column_count), 4,
		"the unsupported half must survive rejection diagnostics")
	var shallow := WarrenSpatialFeatureSolver \
		._shallow_room_overhang_geometry(lower, upper)
	assert_true(bool(shallow.get("valid", false)),
		"the same full room is a supported overhang, never a facade outcropping")
	assert_eq(int(shallow.depth_cells), 2)
	assert_eq(int(shallow.attachment_span_cells), 2)
	assert_eq(int(shallow.extension_column_count), 4)

	var grid := WarrenSpatialGrid.new(Vector3i(-8, 0, 0),
		Vector3i(16, 6, 20))
	assert_true(WarrenSpatialFeatureSolver._arcade_overhang_geometry(
		lower, upper, grid).is_empty(),
		"an arbitrary empty bay is not automatically a public arcade")
	var extension: Array[Vector2i] = []
	extension.assign(mismatch.extension_columns as Array)
	var public_air: Array[Vector3i] = []
	for column: Vector2i in extension:
		for y in range(upper.lattice_origin.y - WarrenSpatialGrid.STOREY_CELLS,
				upper.lattice_origin.y):
			public_air.append(Vector3i(column.x, y, column.y))
	var carve := grid.begin_transaction(&"public.route")
	assert_true(carve.assign_use(public_air, WarrenSpatialGrid.Use.PUBLIC_AIR,
		&"public.route"))
	for cell: Vector3i in public_air:
		if cell.y == upper.lattice_origin.y - WarrenSpatialGrid.STOREY_CELLS:
			assert_true(carve.claim_face(cell, Vector3i.DOWN,
				WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR, &"public.route"))
	# Continue the route beyond the projection's outer face, so the foundation
	# derives one real arch instead of inventing an opening from empty air.
	var outer_column := extension[0] + Vector2i.LEFT
	var outer_cell := Vector3i(outer_column.x,
		upper.lattice_origin.y - WarrenSpatialGrid.STOREY_CELLS, outer_column.y)
	assert_true(carve.assign_use([outer_cell] as Array[Vector3i],
		WarrenSpatialGrid.Use.PUBLIC_AIR, &"public.route"))
	assert_true(carve.claim_face(outer_cell, Vector3i.DOWN,
		WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR, &"public.route"))
	assert_true(carve.commit(), carve.last_rejection)
	var arcade := WarrenSpatialFeatureSolver._arcade_overhang_geometry(lower,
		upper, grid)
	assert_true(bool(arcade.get("valid", false)))
	assert_eq(int(arcade.depth_cells), 2)
	assert_eq(int(arcade.attachment_span_cells), 2)
	assert_eq((arcade.public_air_cells as Array).size(), 8)
	var record := WarrenSpatialFeatureSolver._arcade_overhang_support_record(
		upper, arcade)
	assert_true(String(record.recipe_id).begins_with(
		"overhang.support.arcade.rock."))
	assert_eq(StringName(record.role), &"arcade_stone_foundation")
	assert_gt(int(record.opening_mask), 0)


func test_room_support_preflight_keeps_one_bracketable_edge_not_floating_mass() \
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
		"a broad room may retain one shallow edge bay for explicit support")
	assert_false(WarrenRoomCompositionPlanner
		._floorplate_transition_is_structurally_legible(columns, {},
			WarrenSpatialGrid.STOREY_CELLS, {}, grid),
		"a room with no mass beneath it must never pass as a cantilever")
	var fully_borne := claimed.duplicate()
	var last_column := ordered[-1]
	fully_borne[Vector3i(last_column.x,
		WarrenSpatialGrid.STOREY_CELLS - 1, last_column.y)] = &"bearing"
	assert_true(WarrenRoomCompositionPlanner
		._floorplate_transition_is_structurally_legible(columns, {},
			WarrenSpatialGrid.STOREY_CELLS, fully_borne, grid),
		"an ordinary room transition needs exact bearing under every column")

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


func test_route_overhang_preflight_requires_native_arcade_floor_phase() -> void:
	var grid := WarrenSpatialGrid.new(Vector3i(-8, 0, -8),
		Vector3i(16, 8, 16))
	var upper_record := WarrenRoomCompositionPlanner._record(&"slim",
		Vector3i(0, 4, 0), 0, 2, 3)
	var columns := upper_record.columns as Dictionary
	var ordered: Array[Vector2i] = []
	ordered.assign(columns.keys())
	ordered.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.x < b.x if a.x != b.x else a.y < b.y)
	var unborne: Dictionary = {}
	var claimed: Dictionary = {}
	# One exact 2 x 2 half of the slim room bears on inhabited mass; the other
	# half spans the route and therefore owes a complete four-sided arcade.
	var minimum_z := 2147483647
	for column: Vector2i in ordered:
		minimum_z = mini(minimum_z, column.y)
	for column: Vector2i in ordered:
		if column.y <= minimum_z + 1:
			claimed[Vector3i(column.x, 3, column.y)] = &"bearing"
		else:
			unborne[column] = true
	assert_eq(unborne.size(), 4)
	var route_cells: Array[Vector3i] = []
	for column_value: Variant in unborne.keys():
		var column := column_value as Vector2i
		for y in range(1, 4):
			route_cells.append(Vector3i(column.x, y, column.y))
	var carve := grid.begin_transaction(&"route.half_phase")
	assert_true(carve.assign_use(route_cells,
		WarrenSpatialGrid.Use.PUBLIC_AIR, &"route.half_phase"))
	for column_value: Variant in unborne.keys():
		var column := column_value as Vector2i
		assert_true(carve.claim_face(Vector3i(column.x, 1, column.y),
			Vector3i.DOWN, WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR,
			&"route.half_phase"))
	assert_true(carve.commit(), carve.last_rejection)
	assert_false(WarrenRoomCompositionPlanner
		._floorplate_transition_is_structurally_legible(columns, {}, 4,
			claimed, grid),
		"a 4.5 m void may not receive a floating or floor-buried 3 m arcade")

	var aligned := WarrenSpatialGrid.new(Vector3i(-8, 0, -8),
		Vector3i(16, 8, 16))
	var aligned_route: Array[Vector3i] = []
	for column_value: Variant in unborne.keys():
		var column := column_value as Vector2i
		for y in range(0, 4):
			aligned_route.append(Vector3i(column.x, y, column.y))
	var aligned_carve := aligned.begin_transaction(&"route.full_courses")
	assert_true(aligned_carve.assign_use(aligned_route,
		WarrenSpatialGrid.Use.PUBLIC_AIR, &"route.full_courses"))
	for column_value: Variant in unborne.keys():
		var column := column_value as Vector2i
		assert_true(aligned_carve.claim_face(Vector3i(column.x, 0, column.y),
			Vector3i.DOWN, WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR,
			&"route.full_courses"))
	assert_true(aligned_carve.commit(), aligned_carve.last_rejection)
	assert_true(WarrenRoomCompositionPlanner
		._floorplate_transition_is_structurally_legible(columns, {}, 4,
			claimed, aligned),
		"two full authored courses may descend to one complete public floor")


func test_macro_merge_bearing_reads_the_current_room_graph() -> void:
	var grid := WarrenSpatialGrid.new(Vector3i(-8, 0, -8),
		Vector3i(16, 8, 16))
	var merged := _composition_test_record(&"building",
		Vector3i(0, WarrenSpatialGrid.STOREY_CELLS, 0), 0, 1)
	# Two diagonal source towers leave two disconnected unsupported corners under
	# the proposed 6 x 6 m plate. An immutable pre-merge snapshot may once have
	# contained other rooms there, but the current graph cannot build one straight
	# bracket course across this footprint.
	var diagonal_lineages := {
		&"northwest": {"blocks": [_composition_test_record(&"tower",
			Vector3i(-1, 0, -1), 0, 0)] as Array[Dictionary]},
		&"southeast": {"blocks": [_composition_test_record(&"tower",
			Vector3i(1, 0, 1), 0, 0)] as Array[Dictionary]},
	}
	assert_false(WarrenRoomCompositionPlanner \
		._merge_plate_has_current_bearing(diagonal_lineages, grid, merged),
		"a macro merge may not survive on source support that has been removed")

	var complete_lineages := {
		&"complete": {"blocks": [_composition_test_record(&"building",
			Vector3i.ZERO, 0, 0)] as Array[Dictionary]},
	}
	assert_true(WarrenRoomCompositionPlanner \
		._merge_plate_has_current_bearing(complete_lineages, grid, merged),
		"the same authored macro remains legal over its complete current parent")
	assert_true(WarrenRoomCompositionPlanner \
		._upper_merge_candidate_is_better({"base_y": 2,
			"tall_tower_relief": 0, "strong_registration_count": 0,
			"registered_facade_plane_count": 0, "height": 1,
			"participant_count": 2, "covered_source_columns": 8,
			"displaced_source_columns": 0, "area": 8, "tie": 10},
			{"base_y": 4, "tall_tower_relief": 99,
				"strong_registration_count": 0,
				"registered_facade_plane_count": 0, "height": 99,
				"participant_count": 4, "covered_source_columns": 24,
				"displaced_source_columns": 0, "area": 24, "tie": 0}),
		"a lower parent transaction must outrank a more dramatic upper merge")


func test_frontier_gateway_uses_final_room_bearing_instead_of_overlapping_braces() \
		-> void:
	var grid := WarrenSpatialGrid.new(Vector3i(-4, 0, -4),
		Vector3i(10, 8, 10))
	var gateway := _unsealed_room_for_geometry(&"gateway", &"slim",
		Vector3i(1, WarrenSpatialGrid.STOREY_CELLS, 0))
	var geometry := WarrenSpatialFeatureSolver._frontier_gateway_geometry(
		gateway, {"bearing_column": Vector2i(0, -1),
			"unsupported_column": Vector2i(0, 0)})
	assert_true(bool(geometry.valid))
	assert_false(WarrenSpatialFeatureSolver._frontier_gateway_is_directly_borne(
		gateway, geometry, grid))
	var bearing_cells: Array[Vector3i] = []
	for x in 2:
		for z in 2:
			bearing_cells.append(Vector3i(x,
				WarrenSpatialGrid.STOREY_CELLS - 1, z))
	var bearing := grid.begin_transaction(&"composed.lower.room")
	assert_true(bearing.assign_use(bearing_cells,
		WarrenSpatialGrid.Use.PRIVATE_VOLUME, &"composed.lower.room"))
	assert_true(bearing.commit(), bearing.last_rejection)
	assert_true(WarrenSpatialFeatureSolver._frontier_gateway_is_directly_borne(
		gateway, geometry, grid),
		"a complete composed room beneath the former span is the load path")
	assert_true(WarrenSpatialFeatureSolver._cantilever_support_records(
		gateway, geometry, grid).is_empty(),
		"decorative brackets must not overlap the room that now bears the bay")


func test_tower_annexes_may_step_across_adjacent_storeys_not_repeat_one_face() \
		-> void:
	var lower := _unsealed_room_for_geometry(&"lower.annex", &"tower",
		Vector3i(0, WarrenSpatialGrid.STOREY_CELLS * 2, 0))
	var upper := _unsealed_room_for_geometry(&"upper.annex", &"tower",
		Vector3i(0, WarrenSpatialGrid.STOREY_CELLS * 3, 0))
	var prior := {"room": upper, "recipe_id": &"outcrop.orange",
		"vertical_facade_key": "1,0/1,0"}
	assert_false(WarrenSpatialFeatureSolver
		._tower_annexes_have_silhouette_separation({"room": lower,
			"recipe_id": &"outcrop.blue",
			"vertical_facade_key": "1,0/1,0"}, prior),
		"adjacent annexes cannot repeat one vertical facade plane")
	assert_true(WarrenSpatialFeatureSolver
		._tower_annexes_have_silhouette_separation({"room": lower,
			"recipe_id": &"outcrop.blue",
			"vertical_facade_key": "0,-1/0,-1"}, prior),
		"a different authored profile on another facade makes a stepped corner")
	assert_true(WarrenSpatialFeatureSolver
		._tower_annexes_have_silhouette_separation({"room": upper,
			"recipe_id": &"outcrop.blue",
			"vertical_facade_key": "0,-1/0,-1"}, prior),
		"two clear perpendicular bays can widen one storey into a macro crown")
	assert_false(WarrenSpatialFeatureSolver
		._tower_annexes_have_silhouette_separation({"room": lower,
			"recipe_id": &"outcrop.orange",
			"vertical_facade_key": "0,-1/0,-1"}, prior),
		"the same prefab profile still reads as repeated modular trim")


func test_structural_outcropping_satisfies_one_tower_relief_obligation() -> void:
	var outcrop := WarrenFeatureReservation.new(&"outcrop", &"room_outcropping")
	outcrop.audit = {"outcrop_source_parcel_id": &"tower.lineage"}
	var reduced := WarrenSpatialFeatureSolver \
		._tower_annex_targets_after_structural_outcroppings({
			&"tower.lineage": 2, &"other.lineage": 1,
		}, [outcrop] as Array[WarrenFeatureReservation])
	assert_eq(int((reduced.targets as Dictionary)[&"tower.lineage"]), 1)
	assert_eq(int((reduced.targets as Dictionary)[&"other.lineage"]), 1)
	assert_eq(int(reduced.satisfied_count), 1,
		"a larger supported room projection must count before decorative annexes")
	var corner := WarrenFeatureReservation.new(&"corner.annex", &"tower_annex")
	corner.audit = {"annex_recipe_id": &"outcrop.capped.corner.left.amber"}
	var flat := WarrenFeatureReservation.new(&"flat.annex", &"tower_annex")
	flat.audit = {"annex_recipe_id": &"outcrop.orange"}
	assert_eq(WarrenSpatialFeatureSolver._tower_annex_relief_units(
		[corner, flat] as Array[WarrenFeatureReservation]), 3,
		"corner macro rooms break two facade planes; flat bays break one")


func test_diagonal_outcrop_quota_uses_upper_tower_rooms_only() -> void:
	var first_room := _unsealed_room_for_geometry(&"tower.a", &"tower",
		Vector3i(0, WarrenSpatialGrid.STOREY_CELLS, 0))
	first_room.source_parcel_id = &"source.a"
	var second_room := _unsealed_room_for_geometry(&"tower.b", &"tower",
		Vector3i(8, WarrenSpatialGrid.STOREY_CELLS * 2, 0))
	second_room.source_parcel_id = &"source.b"
	var wide_room := _unsealed_room_for_geometry(&"wide", &"building",
		Vector3i(16, WarrenSpatialGrid.STOREY_CELLS * 3, 0))
	wide_room.source_parcel_id = &"source.wide"
	var first_building := WarrenBuildingVolume.new(&"building.a", 0)
	first_building.room_records = [first_room] as Array[WarrenRoomStamp]
	var second_building := WarrenBuildingVolume.new(&"building.b", 0)
	second_building.room_records = [second_room] as Array[WarrenRoomStamp]
	var wide_building := WarrenBuildingVolume.new(&"building.wide", 0)
	wide_building.room_records = [wide_room] as Array[WarrenRoomStamp]
	var targets := WarrenSpatialFeatureSolver._diagonal_outcrop_target_pool(
		[first_building, second_building, wide_building] \
			as Array[WarrenBuildingVolume], 91)
	assert_eq(targets.size(), 2)
	assert_eq(int(targets.get(&"source.a", 0)) \
		+ int(targets.get(&"source.b", 0)), 2)
	assert_false(targets.has(&"source.wide"),
		"a tower-sized overlap must not masquerade as full scale on a 6 m room")


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


func test_balcony_support_course_must_meet_the_complete_parent_wall() -> void:
	var program := _program()
	var deep := program.recipe(&"balcony.walkout.deep.left.blue.planted")
	var compact := program.recipe(&"balcony.bracketed.left.blue.planted")
	assert_not_null(deep)
	assert_not_null(compact)
	assert_true(deep.has_tag(&"diagonal_support"))
	assert_false(compact.has_tag(&"diagonal_support"))
	var origin := Vector3i(8, 6, 8)
	var outward := Vector3i.BACK
	var attachment_cells: Array[Vector3i] = []
	for local_cell: Vector3i in deep.walk_cells:
		if local_cell.z == 0:
			attachment_cells.append(FabricRecipe.transform_cell(local_cell,
				origin, 0))
	assert_gt(attachment_cells.size(), 1,
		"the test must exercise the complete wide balcony seam")
	var bearing_cells: Array[Vector3i] = []
	for walk_cell: Vector3i in attachment_cells:
		for drop in 3:
			bearing_cells.append(walk_cell - outward - Vector3i.UP * drop)
	var complete_grid := WarrenSpatialGrid.new(Vector3i.ZERO,
		Vector3i(20, 14, 20))
	var complete_tx := complete_grid.begin_transaction(&"balcony.wall.complete")
	assert_true(complete_tx.assign_use(bearing_cells,
		WarrenSpatialGrid.Use.PRIVATE_VOLUME, &"building.parent"))
	assert_true(complete_tx.commit(), complete_tx.last_rejection)
	assert_true(WarrenSpatialFeatureSolver._balcony_supports_attach_to_parent(
		complete_grid, deep, origin, 0, &"building.parent", outward),
		"every tall brace terminates on the same three-band parent wall")

	var incomplete_grid := WarrenSpatialGrid.new(Vector3i.ZERO,
		Vector3i(20, 14, 20))
	var incomplete := bearing_cells.duplicate()
	incomplete.erase(attachment_cells[-1] - outward - Vector3i.UP * 2)
	var incomplete_tx := incomplete_grid.begin_transaction(
		&"balcony.wall.incomplete")
	assert_true(incomplete_tx.assign_use(incomplete,
		WarrenSpatialGrid.Use.PRIVATE_VOLUME, &"building.parent"))
	assert_true(incomplete_tx.commit(), incomplete_tx.last_rejection)
	assert_false(WarrenSpatialFeatureSolver._balcony_supports_attach_to_parent(
		incomplete_grid, deep, origin, 0, &"building.parent", outward),
		"one dangling lower upright rejects the complete deep balcony")

	var compact_bearing: Array[Vector3i] = []
	for local_cell: Vector3i in compact.walk_cells:
		if local_cell.z == 0:
			compact_bearing.append(FabricRecipe.transform_cell(local_cell,
				origin, 0) - outward)
	var compact_grid := WarrenSpatialGrid.new(Vector3i.ZERO,
		Vector3i(20, 14, 20))
	var compact_tx := compact_grid.begin_transaction(&"balcony.wall.compact")
	assert_true(compact_tx.assign_use(compact_bearing,
		WarrenSpatialGrid.Use.PRIVATE_VOLUME, &"building.parent"))
	assert_true(compact_tx.commit(), compact_tx.last_rejection)
	assert_true(WarrenSpatialFeatureSolver._balcony_supports_attach_to_parent(
		compact_grid, compact, origin, 0, &"building.parent", outward),
		"short brackets need the full seam but no invented lower-storey wall")


func test_only_macroscopic_or_lean_to_shoulders_are_roofable() -> void:
	var compound := {
		Vector2i(0, 0): true, Vector2i(1, 0): true,
		Vector2i(0, 1): true, Vector2i(1, 1): true,
		Vector2i(2, 0): true, Vector2i(3, 0): true,
		Vector2i(4, 0): true, Vector2i(5, 0): true,
	}
	assert_true(WarrenRoomCompositionPlanner._component_has_gabled_partition(
		compound, 0),
		"a complete 3 x 3 m crown with one 6 m strip is a finite roof assembly")
	var skinny_remainder := {
		Vector2i(0, 0): true, Vector2i(1, 0): true,
		Vector2i(0, 1): true, Vector2i(1, 1): true,
		Vector2i(2, 0): true, Vector2i(3, 0): true,
	}
	assert_false(WarrenRoomCompositionPlanner._component_has_gabled_partition(
		skinny_remainder, 0),
		"a 3 m leftover strip would become the loose plank roof seen in review")
	var branching := {
		Vector2i(0, 0): true, Vector2i(1, 0): true,
		Vector2i(2, 0): true, Vector2i(1, -1): true,
		Vector2i(1, 1): true, Vector2i(1, 2): true,
	}
	assert_false(WarrenRoomCompositionPlanner._component_has_gabled_partition(
		branching, 0),
		"a branching voxel shelf has no authored macroscopic roof vocabulary")
	var invalid_transition := WarrenRoomCompositionPlanner \
		._transition_unroofable_shoulder_count({
			"columns": branching, "origin": Vector3i.ZERO, "end_storey": 1,
		}, {
			"columns": {Vector2i(20, 20): true},
			"origin": Vector3i(20, WarrenSpatialGrid.STOREY_CELLS, 20),
			"start_storey": 1,
		})
	assert_eq(invalid_transition, 1,
		"silhouette relief must score an unbuildable shoulder before moving")
	var lower := _composition_test_record(&"building", Vector3i.ZERO, 0, 0)
	var upper := _composition_test_record(&"building",
		Vector3i(0, WarrenSpatialGrid.STOREY_CELLS, 0), 0, 1)
	assert_eq(WarrenRoomCompositionPlanner \
		._transition_unroofable_shoulder_count(lower, upper), 0,
		"an aligned complete macro stack must remain a zero-cost seam")


func test_fast_macro_column_stamp_matches_the_room_contract() -> void:
	var origin := Vector3i(7, 5, -11)
	for kind: StringName in WarrenRoomStamp.KINDS:
		for yaw in 4:
			var expected: Dictionary = {}
			for cell: Vector3i in WarrenRoomStamp.expected_private_cells(kind,
					origin, yaw):
				expected[Vector2i(cell.x, cell.z)] = true
			assert_eq_deep(WarrenRoomCompositionPlanner._stamp_columns(kind,
				origin, yaw), expected)
			var exact := WarrenRoomCompositionPlanner._exact_stamp_for_columns(
				expected, origin.y)
			assert_eq_deep(WarrenRoomCompositionPlanner._stamp_columns(
				StringName(exact.kind), exact.origin as Vector3i,
				int(exact.yaw_quarters)), expected)


func test_macro_merge_rejects_an_unroofable_participant_seam() -> void:
	var lower := _composition_test_record(&"long", Vector3i.ZERO, 0, 0)
	var current := _composition_test_record(&"long",
		Vector3i(0, WarrenSpatialGrid.STOREY_CELLS, 0), 0, 1)
	var lineages := {&"source": {
		"blocks": [lower, current] as Array[Dictionary],
		"required_through_block": -1,
	}}
	var participant: Array[Dictionary] = [{
		"lineage_id": &"source", "source_block_index": 1,
	}]
	assert_true(WarrenRoomCompositionPlanner._merge_transitions_are_roofable(
		lineages, participant, current),
		"a complete aligned macro seam remains admissible")
	var disconnected := _composition_test_record(&"tower",
		Vector3i(0, WarrenSpatialGrid.STOREY_CELLS, 0), 0, 1)
	assert_false(WarrenRoomCompositionPlanner._merge_transitions_are_roofable(
		lineages, participant, disconnected),
		"a merge may not strand its participant on an arbitrary roof shelf")


func test_exact_room_preflight_uses_the_final_skywalk_portal_mask() -> void:
	var room := WarrenRoomStamp.new(&"room.owner.00", &"owner", &"tower",
		Vector3i.ZERO, 0, 0, true, false)
	assert_true(room.add_private_cells(WarrenRoomStamp.expected_private_cells(
		&"tower", Vector3i.ZERO, 0)))
	var endpoint_cell := WarrenSpatialFabricCompiler._portal_cell_for_room(
		&"tower", SettlementFabricProgram.FEATURE_PORTAL_NORTH)
	var skywalk := {
		"owner_parcel_ids": [&"owner", &"spatial.feature.landmark.00"],
		"owner_endpoints": [
			{"cell": endpoint_cell, "facing": Vector3i.FORWARD},
			{"cell": Vector3i(8, 0, 0), "facing": Vector3i.BACK},
		],
	}
	var result := WarrenVolumetricSolver \
		._exact_preflight_feature_portal_masks(
			[{"room": room}] as Array[Dictionary],
			{"optional_absent": true}, [skywalk] as Array[Dictionary])
	assert_true(bool(result.get("valid", false)),
		String(result.get("failure", "")))
	assert_eq(int((result.masks as Dictionary).get(room.stable_id, 0)),
		SettlementFabricProgram.FEATURE_PORTAL_NORTH)
	var ordinary := WarrenSpatialFabricCompiler._room_recipe_id(room, 7, true)
	var portal := WarrenSpatialFabricCompiler._room_recipe_id(room, 7, true,
		SettlementFabricProgram.FEATURE_PORTAL_NORTH)
	assert_ne(portal, ordinary,
		"preflight must measure the doorway-bearing recipe used by final compile")
	assert_not_null(_program().recipe(portal),
		"the resolved endpoint mask must name a finite authored portal recipe")


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


func test_macroscopic_shape_audit_finds_exposed_towers_with_an_exact_slim_cover() \
		-> void:
	var left := _composition_test_record(&"tower", Vector3i.ZERO, 0, 0)
	var right := _composition_test_record(&"tower", Vector3i(2, 0, 0), 0, 0)
	var lineages := {
		&"left": {"blocks": [left] as Array[Dictionary]},
		&"right": {"blocks": [right] as Array[Dictionary]},
	}
	var audit := WarrenRoomCompositionPlanner._macroscopic_shape_audit(
		lineages)
	assert_eq(int(audit.exposed_tower_room_count), 2)
	assert_eq(int(audit.optional_exposed_tower_room_count), 2)
	assert_eq(int(audit.unclaimed_exact_macro_tower_pair_count), 1,
		"two adjacent 2x2 rooms must be reported as one missed 2x4 macro")
	assert_almost_eq(float(audit.macro_private_cell_ratio), 0.0, 0.0001)
	assert_eq(int((audit.room_storey_kind_counts as Dictionary)[&"tower"]), 2)


func test_macroscopic_shape_audit_disposes_two_addressed_towers_as_distinct() \
		-> void:
	var left := _composition_test_record(&"tower", Vector3i.ZERO, 0, 0)
	left["address_threshold"] = Vector3i.ZERO
	left["address_frontage"] = Vector3i.BACK
	left["address_expandable"] = true
	var right := _composition_test_record(&"tower", Vector3i(2, 0, 0), 0, 0)
	right["address_threshold"] = Vector3i(2, 0, 0)
	right["address_frontage"] = Vector3i.BACK
	right["address_expandable"] = true
	var lineages := {
		&"left": {"blocks": [left] as Array[Dictionary]},
		&"right": {"blocks": [right] as Array[Dictionary]},
	}
	var audit := WarrenRoomCompositionPlanner._macroscopic_shape_audit(
		lineages)
	assert_eq(int(audit.unclaimed_exact_macro_tower_pair_count), 0,
		"two real public addresses are not an undispositioned merge defect")
	assert_eq(int(audit.refused_exact_macro_tower_pair_count), 1)
	assert_eq(int((audit.exact_macro_tower_pair_disposition_counts \
		as Dictionary).get(&"distinct_public_addresses", 0)), 1)


func test_macroscopic_shape_audit_disposes_offset_towers_as_a_stepped_join() \
		-> void:
	var lower := _composition_test_record(&"tower", Vector3i.ZERO, 0, 0)
	var raised := _composition_test_record(&"tower", Vector3i(2, 1, 0), 0, 0)
	var lineages := {
		&"lower": {"blocks": [lower] as Array[Dictionary]},
		&"raised": {"blocks": [raised] as Array[Dictionary]},
	}
	var audit := WarrenRoomCompositionPlanner._macroscopic_shape_audit(
		lineages)
	assert_eq(int(audit.unclaimed_exact_macro_tower_pair_count), 0)
	assert_eq(int(audit.refused_exact_macro_tower_pair_count), 1)
	assert_eq(int((audit.exact_macro_tower_pair_disposition_counts \
		as Dictionary).get(&"vertical_phase_conflict", 0)), 1,
		"an absolute half-storey offset needs a stepped join, not a rigid macro")


func test_supported_base_towers_merge_without_losing_upper_addresses() -> void:
	var left_blocks: Array[Dictionary] = []
	var right_blocks: Array[Dictionary] = []
	for storey in 5:
		left_blocks.append(_composition_test_record(&"tower", Vector3i(0,
			storey * WarrenSpatialGrid.STOREY_CELLS, 0), 0, storey))
		right_blocks.append(_composition_test_record(&"tower", Vector3i(2,
			storey * WarrenSpatialGrid.STOREY_CELLS, 0), 0, storey))
	var union := (left_blocks[0].columns as Dictionary).duplicate()
	for column_value: Variant in (right_blocks[0].columns as Dictionary).keys():
		union[column_value] = true
	var macros := WarrenRoomCompositionPlanner \
		._exact_non_tower_stamps_for_columns(union, 0)
	assert_false(macros.is_empty())
	if macros.is_empty():
		return
	var macro := macros[0] as Dictionary
	var kind := StringName(macro.kind)
	var local_phase_zero := Vector3i(0, 0, 1) if kind == &"slim" \
		else Vector3i(-1, 0, 0)
	var addressed_origin := macro.origin as Vector3i
	addressed_origin.y = 3 * WarrenSpatialGrid.STOREY_CELLS
	var frontage := FabricRecipe.transform_direction(Vector3i.BACK,
		int(macro.yaw_quarters))
	for side in 2:
		var blocks := left_blocks if side == 0 else right_blocks
		var threshold := FabricRecipe.transform_cell(local_phase_zero \
			+ Vector3i.LEFT * side, addressed_origin,
			int(macro.yaw_quarters))
		for block_index in blocks.size():
			var block := blocks[block_index] as Dictionary
			block["address_threshold"] = threshold
			block["address_frontage"] = frontage
			block["address_expandable"] = block_index == 3
			blocks[block_index] = block
	var left_base := left_blocks[0] as Dictionary
	left_base["support_parent_lineage_id"] = &"left.bearing"
	left_base["support_parent_source_block_index"] = 0
	left_blocks[0] = left_base
	var right_base := right_blocks[0] as Dictionary
	right_base["support_parent_lineage_id"] = &"right.bearing"
	right_base["support_parent_source_block_index"] = 0
	right_blocks[0] = right_base
	var lineages := {
		&"left": {"blocks": left_blocks, "required_through_block": 3,
			"paired_primary": false, "paired_secondary": false},
		&"right": {"blocks": right_blocks, "required_through_block": 3,
			"paired_primary": false, "paired_secondary": false},
	}
	var grid := WarrenSpatialGrid.new(Vector3i(-8, -2, -8),
		Vector3i(24, 20, 24))
	var selected := WarrenRoomCompositionPlanner._merge_base_tower_pairs(
		lineages, grid, {}, 17)
	assert_eq(selected, 1,
		"an exact supported base pair should use one authored macro room")
	assert_eq(lineages.size(), 2,
		"the secondary lineage must survive for its distinct upper address")
	var addressed_count := 0
	var base_macro_count := 0
	for lineage_value: Variant in lineages.values():
		for block: Dictionary in (lineage_value as Dictionary).blocks \
				as Array[Dictionary]:
			addressed_count += int(WarrenRoomCompositionPlanner \
				._block_has_address_in_band(block))
			base_macro_count += int(int(block.source_block_index) == 0 \
				and StringName(block.kind) != &"tower")
	assert_eq(addressed_count, 2,
		"merging the lower structure must preserve both upper public homes")
	assert_eq(base_macro_count, 1)


func test_unassigned_mass_audit_separates_room_sized_and_thin_trim() -> void:
	var grid := WarrenSpatialGrid.new(Vector3i.ZERO, Vector3i(8, 4, 4))
	var room_sized := FabricRecipe.box_cells(Vector3i.ZERO,
		Vector3i(2, 2, 2))
	var trim := [Vector3i(6, 0, 0), Vector3i(7, 0, 0)] as Array[Vector3i]
	var tx := grid.begin_transaction(&"fixture.mass")
	assert_true(tx.assign_use(room_sized + trim,
		WarrenSpatialGrid.Use.ALLOCATABLE, &"fixture.mass"))
	assert_true(tx.commit(), tx.last_rejection)
	var audit := WarrenVolumetricSolver._unassigned_mass_audit(grid)
	assert_eq(int(audit.trimmed_mass_component_count), 2)
	assert_eq(int(audit.trimmed_mass_room_sized_component_count), 1)
	assert_eq(int(audit.trimmed_mass_room_sized_cell_count), 8)
	assert_eq(int(audit.trimmed_mass_thin_component_count), 1)
	assert_eq(int(audit.discardable_exterior_trim_component_count), 2)
	assert_eq(int(audit.enclosed_residual_component_count), 0)


func test_unassigned_mass_audit_finds_enclosed_rooms_and_one_cell_slits() \
		-> void:
	var grid := WarrenSpatialGrid.new(Vector3i.ZERO, Vector3i(10, 7, 7))
	var enclosed := FabricRecipe.box_cells(Vector3i(2, 2, 2),
		Vector3i(2, 2, 2))
	var shell: Dictionary = {}
	for cell: Vector3i in enclosed:
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD,
				Vector3i.BACK]:
			var neighbor := cell + direction
			if not enclosed.has(neighbor):
				shell[neighbor] = true
	var slit := Vector3i(7, 2, 2)
	var residual_cells := enclosed.duplicate()
	residual_cells.append(slit)
	var residual_tx := grid.begin_transaction(&"fixture.residual")
	assert_true(residual_tx.assign_use(residual_cells,
		WarrenSpatialGrid.Use.ALLOCATABLE, &"fixture.mass"))
	assert_true(residual_tx.commit(), residual_tx.last_rejection)
	var private_cells: Array[Vector3i] = []
	private_cells.assign(shell.keys())
	private_cells.append(slit + Vector3i.LEFT)
	private_cells.append(slit + Vector3i.RIGHT)
	var private_tx := grid.begin_transaction(&"fixture.private")
	assert_true(private_tx.assign_use(private_cells,
		WarrenSpatialGrid.Use.PRIVATE_VOLUME, &"fixture.rooms"))
	assert_true(private_tx.commit(), private_tx.last_rejection)
	var audit := WarrenVolumetricSolver._unassigned_mass_audit(grid)
	assert_eq(int(audit.enclosed_room_sized_residual_component_count), 1)
	assert_eq(int(audit.enclosed_room_sized_residual_cell_count), 8)
	assert_eq(int(audit.one_cell_interstitial_gap_cell_count), 1)
	assert_eq(int(audit.one_cell_interstitial_gap_component_count), 1)


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
