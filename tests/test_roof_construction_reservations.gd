extends GutTest

func test_roof_gardens_respect_reserved_ground_frame_columns() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var seed_value := VillagePlan.warren_seed_for_cell(2697992464, Vector2i(116, -241))
	var spatial := WarrenVolumetricSolver.solve(seed_value, {}, program,
		WarrenVillageScaleProfile.select(seed_value))
	assert_not_null(spatial, WarrenVolumetricSolver.last_failure)
	if spatial != null:
		assert_eq(WarrenSpatialFabricCompiler.validation_errors(
			spatial.compiled_fabric_cache()), PackedStringArray())

func test_interstitial_infill_leaves_the_required_roof_space_open() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var seed_value := VillagePlan.warren_seed_for_cell(2697992464, Vector2i(-17, -12))
	var spatial := WarrenVolumetricSolver.solve(seed_value, {}, program,
		WarrenVillageScaleProfile.select(seed_value))
	assert_not_null(spatial, WarrenVolumetricSolver.last_failure)
	if spatial != null:
		assert_eq(WarrenSpatialFabricCompiler.validation_errors(
			spatial.compiled_fabric_cache()), PackedStringArray())

func test_connected_roof_retains_its_declared_eave_flashing() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var seed_value := VillagePlan.warren_seed_for_cell(2697992464, Vector2i(8, -143))
	var spatial := WarrenVolumetricSolver.solve(seed_value, {}, program,
		WarrenVillageScaleProfile.select(seed_value))
	assert_not_null(spatial, WarrenVolumetricSolver.last_failure)
	if spatial != null:
		assert_eq(WarrenSpatialFabricCompiler.validation_errors(
			spatial.compiled_fabric_cache()), PackedStringArray())

func test_compound_roof_plate_with_a_square_return_gets_complete_roofing() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var seed_value := VillagePlan.warren_seed_for_cell(2697992464, Vector2i(-10, 17))
	var spatial := WarrenVolumetricSolver.solve(seed_value, {}, program,
		WarrenVillageScaleProfile.select(seed_value))
	assert_not_null(spatial, WarrenVolumetricSolver.last_failure)
	if spatial != null:
		assert_eq(WarrenSpatialFabricCompiler.validation_errors(
			spatial.compiled_fabric_cache()), PackedStringArray())

func test_joined_roof_preserves_only_the_named_market_canopy_seam() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var seed_value := VillagePlan.warren_seed_for_cell(2697992464, Vector2i(16, -201))
	var spatial := WarrenVolumetricSolver.solve(seed_value, {}, program,
		WarrenVillageScaleProfile.select(seed_value))
	assert_not_null(spatial, WarrenVolumetricSolver.last_failure)
	if spatial == null: return
	var plan := spatial.compiled_fabric_cache()
	assert_eq(WarrenSpatialFabricCompiler.validation_errors(plan), PackedStringArray())

	# The current town remains part of the integration check above. Preserve
	# the original canopy/roof junction independently of street-layout changes.
	var fixture := SettlementFabricPlan.new(&"canopy-junction")
	var roof_recipe := program.recipe(&"roof.partial.gable.orange.2.negative")
	var market_recipe := program.recipe(&"market.covered.02.garden")
	assert_true(fixture.register_recipe(roof_recipe))
	assert_true(fixture.register_recipe(market_recipe))
	var market := FabricUnit.new(&"market", market_recipe.recipe_id,
		Vector3i(5, 0, -8), 1)
	var roof := FabricUnit.new(&"roof", roof_recipe.recipe_id,
		Vector3i(2, 2, -6), 0, [], [], &"", [&"market"])
	fixture._by_id[roof.stable_id] = roof
	fixture._by_id[market.stable_id] = market
	var canopy_bounds := AABB()
	for index in market_recipe.placements.size():
		if StringName(market_recipe.placements[index].id) == &"canopy":
			canopy_bounds = market.transform() * market_recipe.placement_bounds[index]
	# Actual connected end section from the original (16,-201) town.
	var realized_roof := AABB(Vector3(2.25, 3.0, -9.75), Vector3(3.0, 2.0588875, 0.75))
	assert_true(SettlementFabricPlan._aabb_overlaps_volume(realized_roof, canopy_bounds))
	assert_eq(market_recipe.roof_flashing_placement_ids, [&"canopy"] as Array[StringName])
	assert_true(fixture._continuous_component_has_measured_roof_junction(
		{roof.stable_id: true}, realized_roof, market, market_recipe, canopy_bounds, &"canopy"))
	assert_false(fixture._continuous_component_has_measured_roof_junction(
		{roof.stable_id: true}, realized_roof, market, market_recipe, canopy_bounds, &"stocked.counter"),
		"the canopy connection never grants clearance to its furniture")
	roof.visual_seam_ids.clear()
	assert_false(fixture._continuous_component_has_measured_roof_junction(
		{roof.stable_id: true}, realized_roof, market, market_recipe, canopy_bounds, &"canopy"),
		"nearby roofs need an explicit construction seam")


func test_connected_roof_uses_actual_component_clearance() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var seed_value := VillagePlan.warren_seed_for_cell(2697992464, Vector2i(52, -210))
	var spatial := WarrenVolumetricSolver.solve(seed_value, {}, program,
		WarrenVillageScaleProfile.select(seed_value))
	assert_not_null(spatial, WarrenVolumetricSolver.last_failure)
	if spatial != null:
		assert_eq(WarrenSpatialFabricCompiler.validation_errors(
			spatial.compiled_fabric_cache()), PackedStringArray())

func test_roofs_leave_space_for_ground_bearing_frames() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var seed_value := VillagePlan.warren_seed_for_cell(2697992464, Vector2i(80, -43))
	var spatial := WarrenVolumetricSolver.solve(seed_value, {}, program,
		WarrenVillageScaleProfile.select(seed_value))
	assert_not_null(spatial, WarrenVolumetricSolver.last_failure)
	if spatial != null:
		assert_eq(WarrenSpatialFabricCompiler.validation_errors(
			spatial.compiled_fabric_cache()), PackedStringArray())

func test_joined_bridge_crown_uses_the_free_transverse_eave_space() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var seed_value := VillagePlan.warren_seed_for_cell(2697992464, Vector2i(142, -78))
	var spatial := WarrenVolumetricSolver.solve(seed_value, {}, program,
		WarrenVillageScaleProfile.select(seed_value))
	assert_not_null(spatial, WarrenVolumetricSolver.last_failure)
	if spatial != null:
		assert_eq(WarrenSpatialFabricCompiler.validation_errors(
			spatial.compiled_fabric_cache()), PackedStringArray())

func test_bridge_crown_role_cannot_be_overridden_by_neighbor_silhouette() -> void:
	var room := WarrenRoomStamp.new(&"bridge.end", &"parcel", &"tower", Vector3i.ZERO, 0, 0, true, false)
	room.private_cells = WarrenRoomStamp.expected_private_cells(&"tower", Vector3i.ZERO, 0)
	room.audit["bridge_party_roof_yaw_quarters"] = 1
	var reserved := WarrenSpatialFabricCompiler._full_roof_candidates(room, 12)
	var realized := WarrenSpatialFabricCompiler._full_roof_candidates(room, 12, {"flat_roof": true})
	assert_eq(realized, reserved, "the source's party-seam crown is a construction obligation")
	assert_eq(realized.size(), 1)
	assert_true(String(realized[0].recipe_id).contains(".party."))
	assert_eq(int(realized[0].yaw_offset), 1)

func test_slim_bridge_endpoint_keeps_its_finite_party_profile() -> void:
	var room := WarrenRoomStamp.new(&"bridge.end", &"parcel", &"slim", Vector3i.ZERO, 0, 0, true, false)
	room.private_cells = WarrenRoomStamp.expected_private_cells(&"slim", Vector3i.ZERO, 0)
	room.audit["bridge_endpoint_roof"] = true
	var reserved := WarrenSpatialFabricCompiler._full_roof_candidates(room, 12)
	var realized := WarrenSpatialFabricCompiler._full_roof_candidates(room, 12, {"flat_roof": true})
	assert_eq(realized, reserved)
	assert_eq(realized.size(), 1)
	assert_true(String(realized[0].recipe_id).begins_with("roof.terminal.tight.slim."))
	assert_eq(int(realized[0].yaw_offset), 0)

func test_prospective_party_contacts_do_not_depend_on_emitted_grid_faces() -> void:
	var grid := WarrenSpatialGrid.new(Vector3i(-8, -2, -8), Vector3i(16, 16, 16))
	var room := WarrenRoomStamp.new(&"room", &"parcel", &"tower", Vector3i.ZERO, 0, 0, true, false)
	room.private_cells = WarrenRoomStamp.expected_private_cells(&"tower", Vector3i.ZERO, 0)
	var owners: Dictionary = {}
	for cell: Vector3i in room.private_cells: owners[cell] = room.stable_id
	for cell: Vector3i in WarrenRoomStamp.expected_private_cells(&"tower", Vector3i(2, 0, 0), 0):
		owners[cell] = &"neighbor"
	owners[Vector3i(6, 0, 0)] = &"unrelated"
	var contacts := WarrenSpatialFabricCompiler._party_wall_allowed_room_ids_for_grid(grid, room, owners)
	assert_has(contacts, &"neighbor")
	assert_does_not_have(contacts, &"unrelated")
	room.audit["roof_party_allowed_room_ids"] = [&"bridge"]
	contacts = WarrenSpatialFabricCompiler._party_wall_allowed_room_ids_for_grid(grid, room, owners)
	assert_does_not_have(contacts, &"neighbor", "a role-specific endpoint keeps its explicit party-plane contract")

func test_terminal_roof_domain_starts_with_the_house_crown() -> void:
	var room := WarrenRoomStamp.new(&"house", &"parcel", &"tower", Vector3i.ZERO, 0, 0, true, false)
	var ordinary := WarrenSpatialFabricCompiler._full_roof_candidates(room, 12)
	var domain := WarrenSpatialFabricCompiler._pitched_roof_domain(room, 12,
		{"flat_roof": true}, true, true)
	assert_eq(domain[0], ordinary[0],
		"terminal classification must not make the tight fallback precede the authored house crown")
	var seen: Dictionary = {}
	for choice: Dictionary in domain:
		var key := "%s/%d" % [choice.recipe_id, int(choice.yaw_offset)]
		assert_false(seen.has(key), "a roof choice appears only once")
		seen[key] = true

func test_terminal_roof_domain_preserves_the_bridge_seam_role() -> void:
	for kind: StringName in [&"tower", &"slim"]:
		var room := WarrenRoomStamp.new(&"bridge.end", &"parcel", kind, Vector3i.ZERO, 0, 0, true, false)
		room.audit["bridge_endpoint_roof"] = true
		if kind == &"tower": room.audit["bridge_party_roof_yaw_quarters"] = 1
		assert_eq(WarrenSpatialFabricCompiler._pitched_roof_domain(room, 12,
			{"flat_roof": true}, true, true),
			WarrenSpatialFabricCompiler._full_roof_candidates(room, 12),
			"generic terminal alternatives cannot replace the endpoint's reserved party profile")
