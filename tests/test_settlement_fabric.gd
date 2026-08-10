extends GutTest

const FoldedProof = preload("res://tests/fixtures/warren_folded_proof.gd")
var _compiled_program: SettlementFabricProgram
var _folded_plan: SettlementFabricPlan


func _program() -> SettlementFabricProgram:
	if _compiled_program == null:
		_compiled_program = SettlementFabricProgram.compile(
			EnvironmentCatalog.load_default())
	return _compiled_program


func _folded_proof() -> SettlementFabricPlan:
	if _folded_plan == null:
		_folded_plan = FoldedProof.solve(_program())
	return _folded_plan


func _route_specs() -> Array[Dictionary]:
	return [
		SettlementFabricSolver.unit_spec(&"route.entry", &"route.landing",
			Vector3i.ZERO),
		SettlementFabricSolver.unit_spec(&"route.east", &"route.corner",
			Vector3i(2, 0, 0), 0, [], [
				FabricUnit.bond(&"walk.west", &"route.entry", &"walk.east"),
			]),
		SettlementFabricSolver.unit_spec(&"route.north", &"route.corner",
			Vector3i(2, 0, -2), 0, [], [
				FabricUnit.bond(&"walk.south", &"route.east", &"walk.north"),
			]),
	]


func _route_plan() -> SettlementFabricPlan:
	var program := _program()
	return SettlementFabricSolver.new(program).solve_authored(
		&"warren.test.route", _route_specs())


func _sectional_route() -> SectionalPublicRealmPlan:
	var realm := SectionalPublicRealmPlan.new(&"warren.test.sectional.realm")
	var entry_cells := FabricRecipe.box_cells(Vector3i(-1, 0, -1),
		Vector3i(2, 1, 2))
	var turn_cells := FabricRecipe.box_cells(Vector3i(1, 0, -1),
		Vector3i(2, 1, 2))
	var exit_cells := FabricRecipe.box_cells(Vector3i(1, 0, -3),
		Vector3i(2, 1, 2))
	var nodes: Array[PublicRealmNode] = [
		PublicRealmNode.new(&"episode.entry", PublicRealmNode.EpisodeKind.STREET,
			PublicRealmSurfacePlan.SurfaceKind.TERRAIN_STREET,
			PublicRealmNode.AirRealm.EXTERIOR,
			PublicRealmNode.CoverPolicy.OPEN, entry_cells,
			_air_for_surfaces(entry_cells), 0, 0, true, true),
		PublicRealmNode.new(&"episode.turn", PublicRealmNode.EpisodeKind.UNDERCROFT,
			PublicRealmSurfacePlan.SurfaceKind.TERRAIN_STREET,
			PublicRealmNode.AirRealm.EXTERIOR,
			PublicRealmNode.CoverPolicy.COVERED, turn_cells,
			_air_for_surfaces(turn_cells), 0, 0, true),
		PublicRealmNode.new(&"episode.exit", PublicRealmNode.EpisodeKind.TERRACE,
			PublicRealmSurfacePlan.SurfaceKind.TERRAIN_STREET,
			PublicRealmNode.AirRealm.EXTERIOR,
			PublicRealmNode.CoverPolicy.OPEN, exit_cells,
			_air_for_surfaces(exit_cells), 0, 0, true),
	]
	for node_value: PublicRealmNode in nodes:
		assert_true(node_value.seal())
		assert_true(realm.add_node(node_value))
	var first := PublicRealmEdge.new(&"edge.entry.turn", &"episode.entry",
		&"episode.turn", PublicRealmEdge.TransitionKind.LEVEL)
	first.add_seam(Vector3i(0, 0, -1), Vector3i(1, 0, -1))
	first.add_seam(Vector3i(0, 0, 0), Vector3i(1, 0, 0))
	assert_true(realm.add_edge(first))
	var second := PublicRealmEdge.new(&"edge.turn.exit", &"episode.turn",
		&"episode.exit", PublicRealmEdge.TransitionKind.LEVEL)
	second.add_seam(Vector3i(1, 0, -1), Vector3i(1, 0, -2))
	second.add_seam(Vector3i(2, 0, -1), Vector3i(2, 0, -2))
	assert_true(realm.add_edge(second))
	realm.set_primary_itinerary([
		&"episode.entry", &"episode.turn", &"episode.exit",
	])
	for node_value: PublicRealmNode in nodes:
		for cell: Vector3i in node_value.surface_cells:
			realm.require_classification(cell)
	realm.require_classification(Vector3i(0, 1, -2))
	realm.add_daylight_void(Vector3i(0, 1, -2))
	assert_true(realm.seal(), realm.last_rejection)
	return realm


func _air_for_surfaces(cells: Array[Vector3i]) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for cell: Vector3i in cells:
		out.append(cell)
		out.append(cell + Vector3i.UP)
	return out


func test_surface_audit_distinguishes_narrow_gallery_from_broad_plaza() -> void:
	var gallery := PublicRealmSurfacePlan.new(&"test.gallery")
	for z in 8:
		for x in 2:
			assert_true(gallery.add_claim(Vector3i(x, 2, z),
				PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT,
				&"gallery"))
	assert_eq(int(gallery.audit().structural_court_interior_cell_count), 0,
		"a long two-lane route is path-like even when its total area is large")
	var plaza := PublicRealmSurfacePlan.new(&"test.plaza")
	for z in 4:
		for x in 4:
			assert_true(plaza.add_claim(Vector3i(x, 2, z),
				PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT,
				&"plaza"))
	assert_eq(int(plaza.audit().structural_court_interior_cell_count), 4,
		"a broad empty floor has an interior independent of its perimeter")


func test_surface_audit_detects_plaza_split_across_public_claim_kinds() -> void:
	var surfaces := PublicRealmSurfacePlan.new(&"test.mixed_plaza")
	for z in 4:
		for x in 4:
			var kind := PublicRealmSurfacePlan.SurfaceKind.TERRAIN_STREET \
				if x < 2 else PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT
			assert_true(surfaces.add_claim(Vector3i(x, 0, z), kind,
				&"mixed.owner"))
	assert_eq(int(surfaces.audit().structural_court_interior_cell_count), 0,
		"neither claim family alone contains a plaza interior")
	assert_eq(int(surfaces.audit().exterior_public_interior_cell_count), 4,
		"the combined exterior public floor must still expose the plaza")
	assert_eq(int(surfaces.audit().max_exterior_public_interior_component_size),
		4, "the broad interior is one connected plaza rather than scattered turns")


func _sectional_route_specs() -> Array[Dictionary]:
	return [
		SettlementFabricSolver.unit_spec(&"route.entry", &"route.landing",
			Vector3i.ZERO, 0, [], [], &"episode.entry"),
		SettlementFabricSolver.unit_spec(&"route.east", &"route.corner",
			Vector3i(2, 0, 0), 0, [], [
				FabricUnit.bond(&"walk.west", &"route.entry", &"walk.east"),
			], &"episode.turn"),
		SettlementFabricSolver.unit_spec(&"route.north", &"route.corner",
			Vector3i(2, 0, -2), 0, [], [
				FabricUnit.bond(&"walk.south", &"route.east", &"walk.north"),
			], &"episode.exit"),
	]


func test_program_compiles_one_common_recipe_vocabulary() -> void:
	var program := _program()
	var catalog := EnvironmentCatalog.load_default()
	assert_not_null(program)
	assert_not_null(program.recipe(&"route.landing"))
	assert_not_null(program.recipe(&"room.base.rock"))
	assert_null(program.recipe(&"room.bay.base.rock"),
		"a wide, shallow mass is an attachment, never a standalone house recipe")
	assert_null(program.recipe(&"roof.bay.blue"))
	assert_not_null(program.recipe(&"room.stair_house.blue"))
	var micro := program.recipe(&"room.micro.terrain.blue")
	assert_not_null(micro)
	assert_eq(micro.entrances.size(), 1,
		"a visible micro-house door must be a real circulation address")
	assert_gt(micro.headroom_cells.size(), 0)
	assert_gt(micro.inhabited_cells.size(), 0)
	assert_gt(micro.local_bounds.size.z, micro.local_bounds.size.x,
		"the smallest standalone house must render narrow/deep, never sideways")
	assert_almost_eq(micro.local_bounds.size.z, 6.486891, 0.001)
	assert_almost_eq(micro.local_bounds.size.x, 3.468661, 0.001)
	var slim_base := program.recipe(&"room.slim.base.rock")
	var slim_upper := program.recipe(&"room.slim.upper.address.blue")
	var slim_roof := program.recipe(&"roof.slim.blue")
	assert_not_null(slim_base)
	assert_not_null(slim_upper)
	assert_not_null(slim_roof)
	var stone_upper := program.recipe(&"room.slim.upper.address.stone")
	assert_not_null(stone_upper)
	assert_eq(stone_upper.entrances.size(), 1)
	assert_true(stone_upper.has_tag(&"room"))
	assert_false(stone_upper.has_tag(&"terrain_bearing"),
		"masonry is a facade construction family, not permission for an upper room to bear on terrain")
	assert_gt(slim_base.local_bounds.size.z, slim_base.local_bounds.size.x,
		"stackable infill must remain narrow/deep in its canonical frame")
	assert_eq(slim_upper.entrances.size(), 1)
	assert_true(slim_roof.has_tag(&"roof"))
	assert_true(slim_roof.has_tag(&"ridge_z"))
	assert_gt(slim_roof.local_bounds.size.z, slim_roof.local_bounds.size.x,
		"the townhouse roof ridge must follow its long parcel axis")
	assert_gt(slim_roof.placements.size(), 0,
		"a narrow townhouse still terminates in a real pitched roof")
	assert_not_null(program.recipe(&"stair.facade.full.terrain.orange"))
	assert_not_null(program.recipe(&"court.supported.12x6"))
	assert_not_null(program.recipe(&"outcrop.blue"))
	var corner_left := program.recipe(&"outcrop.corner.left.blue")
	var corner_right := program.recipe(&"outcrop.corner.right.blue")
	assert_not_null(corner_left)
	assert_not_null(corner_right)
	assert_true(corner_left.has_tag(&"corner_outcropping"))
	assert_true(corner_right.has_tag(&"corner_outcropping"))
	assert_ne(corner_left.socket(&"room.back").cell,
		corner_right.socket(&"room.back").cell,
		"opposite corner bays must frame into opposite halves of the facade")
	for outcrop: FabricRecipe in [corner_left, corner_right]:
		var roof_placements := 0
		var left_wall := Vector3.INF
		var right_wall := Vector3.INF
		for placement: Dictionary in outcrop.placements:
			if String(placement.id).begins_with("roof"):
				roof_placements += 1
			elif StringName(placement.id) == &"left":
				left_wall = (placement.transform as Transform3D).origin
			elif StringName(placement.id) == &"right":
				right_wall = (placement.transform as Transform3D).origin
		assert_gt(roof_placements, 0,
			"every occupied projection must compile a real roof")
		assert_false(left_wall.is_equal_approx(Vector3.INF))
		assert_false(right_wall.is_equal_approx(Vector3.INF))
		assert_lte(absf(right_wall.x - left_wall.x), 3.1,
			"the textured side panels must close the one-module bay shell")
		assert_gt(outcrop.local_bounds.size.x, outcrop.local_bounds.size.z,
			"an outcropping is a broad shallow facade bay, not a pasted-on cube")
		# The complete gable's conservative clearance shell adds roughly 5 cm
		# beyond its 3.66 m authored eave span. It is still a shallow facade bay,
		# well below the six-metre depth of an independent room.
		assert_lte(outcrop.local_bounds.size.z, 3.80,
			"occupied bays may not protrude an entire room depth from the parent")
	assert_not_null(program.recipe(&"outcrop.half.blue"))
	assert_not_null(program.recipe(&"skywalk.6.orange"))
	assert_not_null(program.recipe(&"anchor.prefab.00"))
	assert_eq(SettlementFabricProgram.PREFAB_ANCHORS.size(), 10)
	for index in SettlementFabricProgram.MARKET_STALLS.size():
		assert_not_null(program.recipe(StringName("market.stall.%02d" % index)))
		var market_asset := SettlementFabricProgram.MARKET_STALLS[index]
		assert_true(catalog.descriptor(market_asset).tags.has(&"stocked_market"),
			"the compiled market vocabulary may contain only reviewed populated prefabs")
	for empty_canopy: StringName in [
		&"sfm.stall.alchemy.001", &"sfm.stall.forge.001",
		&"sfm.stall.butcher.001", &"sfm.stall.butcher.003",
		&"sfm.stall.blue.007", &"sfm.stall.orange.006",
		&"sfm.stall.teal.008", &"sfm.stall.neutral.009",
	]:
		assert_false(SettlementFabricProgram.MARKET_STALLS.has(empty_canopy),
			"bare canopy/frame components must never masquerade as markets")
	for asset_id: StringName in program.referenced_asset_ids:
		assert_false(String(asset_id).begins_with("sfbp.tent"), String(asset_id))


func test_module_contracts_pin_floor_facade_and_roof_datums() -> void:
	var program := _program()
	var catalog := EnvironmentCatalog.load_default()
	var room := program.recipe(&"room.base.rock")
	var floor_count := 0
	for placement: Dictionary in room.placements:
		var asset_id := StringName(placement.asset_id)
		var placed_bounds := (placement.transform as Transform3D) * \
			catalog.descriptor(asset_id).measured_aabb
		if asset_id == SettlementFabricProgram.FLOOR:
			floor_count += 1
			assert_almost_eq(placed_bounds.end.y, 0.0, 0.001,
				"every authored floor top is the logical walk plane")
		if StringName(placement.id) == &"front.0":
			assert_almost_eq(placed_bounds.end.z, 2.25, 0.001,
				"the measured facade outer face ends at the half-cell boundary")
	assert_eq(floor_count, 4, "a 6 m room has a complete two-by-two floor")
	assert_lte(room.local_bounds.size.x, 6.10)
	assert_lte(room.local_bounds.size.z, 6.10)

	var roof := program.recipe(&"roof.blue")
	assert_eq(roof.construction_runs.size(), 1)
	var run := roof.construction_runs[0]
	assert_eq(StringName(run.kind), &"roof")
	assert_eq((run.placement_ids as Array).size(), 6)
	assert_almost_eq(float(run.start_seam), -3.0, 0.001)
	assert_almost_eq(float(run.end_seam), 3.0, 0.001)
	assert_almost_eq(float(run.repeat_pitch), 3.0, 0.001)
	var roof_contract := program.module_program.contract(
		SettlementFabricProgram.ROOF_BLUE)
	assert_eq(roof_contract.pair_axis, Vector3i.RIGHT)
	assert_almost_eq(roof_contract.pair_offset, 1.6217227, 0.001)
	var roof_peak_y := -INF
	var gable_peak_y := -INF
	for placement: Dictionary in roof.placements:
		var descriptor := catalog.descriptor(StringName(placement.asset_id))
		var bounds := (placement.transform as Transform3D) * descriptor.measured_aabb
		if StringName(placement.asset_id) == SettlementFabricProgram.GABLE:
			gable_peak_y = maxf(gable_peak_y, bounds.end.y)
		else:
			roof_peak_y = maxf(roof_peak_y, bounds.end.y)
	assert_almost_eq(gable_peak_y, roof_peak_y, 0.001,
		"gable closure peak and repeated roof ridge share one datum")
	assert_false(program.module_program.add_roof_run(
		FabricRecipe.new(&"bad.roof", [&"roof"], 0), &"bad.run",
		SettlementFabricProgram.ROOF_BLUE, SettlementFabricProgram.GABLE,
		Vector3.ZERO, 0.0, 0.0, 5.0),
		"a non-integral roof run is rejected instead of repaired with an offset")

	# The route recipe claims the two cell centres x=-1 and x=0, whose combined
	# corridor spans [-2.25, 0.75]. Both full and repeated half-flight visuals
	# must be centred on that same interval rather than half a cell to its right.
	for stair_id: StringName in [&"stair.full", &"stair.half"]:
		var stair := program.recipe(stair_id)
		var stair_min_x := INF
		var stair_max_x := -INF
		for placement: Dictionary in stair.placements:
			var descriptor := catalog.descriptor(StringName(placement.asset_id))
			var bounds := (placement.transform as Transform3D) * \
				descriptor.measured_aabb
			stair_min_x = minf(stair_min_x, bounds.position.x)
			stair_max_x = maxf(stair_max_x, bounds.end.x)
		assert_almost_eq((stair_min_x + stair_max_x) * 0.5, -0.75, 0.03,
			"stair collision/visual lanes share the public corridor centre")
		assert_lte(absf(stair_min_x - -2.25), 0.05)
		assert_lte(absf(stair_max_x - 0.75), 0.05)


func test_circulation_recipes_express_section_changes_and_local_ground() -> void:
	var program := _program()
	var prefab := program.recipe(&"anchor.prefab.00")
	assert_true(prefab.has_tag(&"terrain_bearing"))
	assert_gt(prefab.terrain_bearing_cells.size(), 0)
	for bearing_cell: Vector3i in prefab.terrain_bearing_cells:
		assert_eq(bearing_cell.y, 0)
	var prefab_xz: Dictionary = {}
	for bearing_cell: Vector3i in prefab.terrain_bearing_cells:
		prefab_xz[Vector2i(bearing_cell.x, bearing_cell.z)] = true
	assert_eq(prefab_xz.size(), prefab.terrain_bearing_cells.size(),
		"a prefab declares one complete, non-dilated load footprint")
	var prefab_bounds := prefab.local_clearance_bounds
	var bounding_cell_count := ceili(prefab_bounds.size.x / FabricRecipe.CELL_SIZE) \
		* ceili(prefab_bounds.size.z / FabricRecipe.CELL_SIZE)
	assert_lt(prefab.terrain_bearing_cells.size(), bounding_cell_count,
		"authored feet do not turn the prefab's complete eave bounds into terrain")

	var stair_house := program.recipe(&"room.stair_house.blue")
	assert_true(stair_house.has_tag(&"circulation_building"))
	assert_true(stair_house.has_tag(&"interior_walk"))
	assert_false(stair_house.has_tag(&"public_walk"))
	assert_eq((stair_house.socket(&"walk.low").cell as Vector3i).y, 0)
	assert_eq((stair_house.socket(&"walk.high").cell as Vector3i).y, 4)
	assert_gt(stair_house.solid_cells.size(), 0)
	assert_gt(stair_house.walk_cells.size(), 0)
	assert_eq(stair_house.public_air_cells.size(), 0)

	var exterior_stair := program.recipe(&"stair.facade.full.terrain.orange")
	assert_true(exterior_stair.has_tag(&"exterior_stair"))
	assert_true(exterior_stair.has_tag(&"public_walk"))
	assert_false(exterior_stair.has_tag(&"interior_walk"))
	assert_eq((exterior_stair.socket(&"walk.low").cell as Vector3i).y, 0)
	assert_eq((exterior_stair.socket(&"walk.high").cell as Vector3i).y, 2)
	assert_eq(exterior_stair.entrances.size(), 1,
		"the occupied stair facade needs one real external address")
	var stair_entrance := exterior_stair.entrances[0] as Dictionary
	assert_eq(stair_entrance.cell as Vector3i, Vector3i(1, 0, 0))
	assert_eq(stair_entrance.facing as Vector3i, Vector3i.RIGHT)
	assert_true(exterior_stair.walk_cells.has(Vector3i(2, 0, 0)),
		"the east doorway must meet the low stair tread at equal elevation")
	for air_cell: Vector3i in exterior_stair.public_air_cells:
		assert_false(exterior_stair.inhabited_cells.has(air_cell),
			"facade stair air remains outside the inhabited envelope")

	var court := program.recipe(&"court.supported.12x6")
	assert_true(court.has_tag(&"structural_court"))
	assert_true(court.has_tag(&"topology_only"))
	assert_false(court.has_tag(&"terrain_bearing"))
	assert_true(court.terrain_bearing_cells.is_empty())
	assert_eq(court.bearing_parent_count, 2)
	assert_eq(court.placements.size(), 0)
	assert_eq(court.walk_cells.size(), 31)
	assert_eq(court.daylight_void_cells.size(), 1)
	assert_false(court.walk_cells.has(court.daylight_void_cells[0]))

	var addressed_room := program.recipe(&"room.base.rock")
	var closed_upper := program.recipe(&"room.upper.blue")
	assert_eq(addressed_room.entrances.size(), 1)
	assert_true(closed_upper.entrances.is_empty())
	assert_true(closed_upper.solid_cells.has(Vector3i(-1, 0, 1)),
		"an unaddressed upper storey must not retain a fake open door")


func test_deferred_passage_surface_stays_private_but_reaches_its_portals() -> void:
	var passage := _program().recipe(&"room.passage.blue")
	assert_true(passage.has_tag(&"interior_walk"))
	assert_false(passage.has_tag(&"public_walk"))
	assert_true(passage.public_air_cells.is_empty())
	for socket_id: StringName in [
			&"walk.north", &"walk.south", &"walk.east", &"walk.west"]:
		var socket := passage.socket(socket_id)
		assert_true(passage.walk_cells.has(socket.cell as Vector3i),
			"%s must terminate on the claimed public surface" % socket_id)
		assert_false(passage.solid_cells.has(socket.cell as Vector3i),
			"%s must remain a clear opening" % socket_id)


func test_occupied_skywalk_is_private_overhead_mass() -> void:
	var skywalk := _program().recipe(&"skywalk.6.orange")
	assert_true(skywalk.has_tag(&"interior_walk"))
	assert_false(skywalk.has_tag(&"public_walk"))
	assert_true(skywalk.public_air_cells.is_empty())
	assert_gt(skywalk.inhabited_cells.size(), 0)
	assert_false(skywalk.socket(&"room.west").is_empty())
	assert_false(skywalk.socket(&"room.east").is_empty())
	assert_true(skywalk.placements.any(func(value: Dictionary) -> bool:
		return String(value.id).begins_with("floor.")),
		"a private occupied skywalk still owns a real floor")


func test_exterior_builder_rejects_deferred_interior_route_units() -> void:
	var program := _program()
	var specs: Array[Dictionary] = [
		SettlementFabricSolver.unit_spec(&"route.entry", &"route.landing",
			Vector3i.ZERO),
		SettlementFabricSolver.unit_spec(&"interior.stair",
			&"room.stair_house.terrain.orange", Vector3i(10, 0, 0)),
	]
	assert_null(SectionalPublicRealmBuilder.from_specs(&"interior.rejected",
		program, specs, [&"route.entry", &"interior.stair"]))
	assert_true(SectionalPublicRealmBuilder.last_failure.contains(
		"is not a public unit"))


func test_public_node_requires_full_exterior_headroom() -> void:
	var surface_cells: Array[Vector3i] = [Vector3i.ZERO]
	var incomplete_air: Array[Vector3i] = [Vector3i.ZERO]
	var node_value := PublicRealmNode.new(&"bad.headroom",
		PublicRealmNode.EpisodeKind.STREET,
		PublicRealmSurfacePlan.SurfaceKind.TERRAIN_STREET,
		PublicRealmNode.AirRealm.EXTERIOR,
		PublicRealmNode.CoverPolicy.OPEN, surface_cells, incomplete_air,
		0, 0, true, true)
	assert_false(node_value.seal())


func test_volume_proof_rejects_occupied_and_disconnected_public_air() -> void:
	var air_claims := {
		Vector3i.ZERO: {"owners": [&"entry"]},
		Vector3i.UP: {"owners": [&"entry"]},
	}
	var occupied := {Vector3i.UP: &"room"}
	var overlap := FabricVolumePlan.new(&"volume.overlap")
	assert_false(overlap.seal(air_claims, [Vector3i.ZERO], occupied, {}))
	assert_eq(overlap.occupied_air_overlaps, [Vector3i.UP])

	air_claims[Vector3i(20, 0, 20)] = {"owners": [&"island"]}
	var disconnected := FabricVolumePlan.new(&"volume.disconnected")
	assert_false(disconnected.seal(air_claims, [Vector3i.ZERO], {}, {}))
	assert_eq(disconnected.unreachable_air_cells, [Vector3i(20, 0, 20)])

	var occupied_probe := FabricVolumePlan.new(&"volume.occupied_probe")
	assert_true(occupied_probe.seal({
		Vector3i.ZERO: {"owners": [&"entry"]},
		Vector3i.UP: {"owners": [&"entry"]},
	}, [Vector3i.ZERO], {Vector3i(4, 1, 0): &"wall"}, {}))
	assert_true(occupied_probe.has_occupied_cell(Vector3i(4, 1, 0)))
	assert_false(occupied_probe.has_occupied_cell(Vector3i.UP))


func test_folded_route_uses_socket_bonds_and_reaches_one_landing() -> void:
	var plan := _route_plan()
	assert_not_null(plan)
	assert_true(plan.is_sealed())
	assert_true(plan.validate())
	assert_eq(plan.audit.public_walk_unit_count, 3)
	assert_eq(plan.audit.tent_count, 0)
	assert_eq(plan.audit.isolated_platform_count, 0)


func test_disconnected_public_walk_is_rejected() -> void:
	var specs := _route_specs()
	specs.append(SettlementFabricSolver.unit_spec(&"route.orphan",
		&"route.corner", Vector3i(20, 0, 20)))
	var plan := SettlementFabricSolver.new(_program()).solve_authored(
		&"warren.test.orphan", specs)
	assert_null(plan)


func test_solid_or_headroom_overlap_is_rejected_during_construction() -> void:
	var specs := _route_specs()
	specs.append(SettlementFabricSolver.unit_spec(&"route.overlap",
		&"route.corner", Vector3i(2, 0, 0), 0, [], [
			FabricUnit.bond(&"walk.west", &"route.entry", &"walk.east"),
		]))
	var plan := SettlementFabricSolver.new(_program()).solve_authored(
		&"warren.test.overlap", specs)
	assert_null(plan)


func test_visual_rejection_rolls_back_staged_semantic_claims() -> void:
	var plan := SettlementFabricPlan.new(&"warren.test.visual-rollback")
	var catalog := EnvironmentCatalog.load_default()
	var recipe_value := FabricRecipe.new(&"test.visual-rollback",
		[&"generated_building"], 0)
	recipe_value.add_placement(&"floor", SettlementFabricProgram.FLOOR)
	recipe_value.solid_cells.append(Vector3i.ZERO)
	var visual_bounds := catalog.descriptor(
		SettlementFabricProgram.FLOOR).measured_aabb
	assert_true(recipe_value.set_local_clearance_bounds(
		visual_bounds.grow(0.5)))
	assert_true(recipe_value.seal(catalog), recipe_value.last_rejection)
	assert_true(plan.register_recipe(recipe_value))
	var left := FabricUnit.new(&"room.left", recipe_value.recipe_id,
		Vector3i.ZERO, 0)
	assert_true(plan.add_unit(left), plan.last_rejection)
	var unseamed := FabricUnit.new(&"room.right", recipe_value.recipe_id,
		Vector3i(1, 0, 0), 0)
	assert_false(plan.add_unit(unseamed),
		"adjacent authored facade envelopes require an explicit party-wall seam")
	assert_true(plan.last_rejection.contains("visual envelope"),
		plan.last_rejection)
	var retry := FabricUnit.new(&"room.right", recipe_value.recipe_id,
		Vector3i(1, 0, 0), 0, [], [], &"", [&"room.left"])
	assert_true(plan.add_unit(retry),
		"the rejected attempt must not retain ghost semantic claims: %s" \
			% plan.last_rejection)
	assert_eq(plan.units.size(), 2)


func test_stacked_room_requires_the_declared_bearing_parent_socket() -> void:
	var specs := _route_specs()
	specs.append(SettlementFabricSolver.unit_spec(&"room.base",
		&"room.base.rock", Vector3i(8, 0, 0)))
	specs.append(SettlementFabricSolver.unit_spec(&"room.upper",
		&"room.upper.blue", Vector3i(8, 2, 0), 0, [&"room.base"], [
			FabricUnit.bond(&"bearing.bottom", &"room.base", &"bearing.top"),
		]))
	var plan := SettlementFabricSolver.new(_program()).solve_authored(
		&"warren.test.stack", specs)
	assert_not_null(plan)
	assert_true(plan.validate())

	var invalid_specs := _route_specs()
	invalid_specs.append(SettlementFabricSolver.unit_spec(&"room.base",
		&"room.base.rock", Vector3i(8, 0, 0)))
	invalid_specs.append(SettlementFabricSolver.unit_spec(&"room.upper",
		&"room.upper.blue", Vector3i(8, 2, 0), 0, [&"room.base"]))
	assert_null(SettlementFabricSolver.new(_program()).solve_authored(
		&"warren.test.unsupported", invalid_specs))


func test_enclosed_skywalk_requires_two_independent_bearing_ends() -> void:
	var program := _program()
	var plan := SettlementFabricPlan.new(&"warren.test.span")
	for recipe_value: FabricRecipe in program.recipes():
		assert_true(plan.register_recipe(recipe_value))
	var left := FabricUnit.new(&"room.left", &"room.base.rock",
		Vector3i(-3, 2, 0), 0)
	var right := FabricUnit.new(&"room.right", &"room.base.rock",
		Vector3i(3, 2, 0), 0)
	assert_true(plan.add_unit(left))
	assert_true(plan.add_unit(right))
	var span := FabricUnit.new(&"skywalk", &"skywalk.3.blue",
		Vector3i(0, 2, 0), 0, [&"room.left", &"room.right"], [
			FabricUnit.bond(&"bearing.west", &"room.left", &"bearing.east"),
			FabricUnit.bond(&"bearing.east", &"room.right", &"bearing.west"),
		])
	assert_true(plan.add_unit(span))

	var invalid := FabricUnit.new(&"bad.skywalk", &"skywalk.3.blue",
		Vector3i(0, 6, 0), 0, [&"room.left"], [
			FabricUnit.bond(&"bearing.west", &"room.left", &"bearing.east"),
		])
	assert_false(plan.add_unit(invalid))


func test_composite_recipes_expand_to_stable_asset_placements() -> void:
	var plan := _route_plan()
	var placements := plan.expanded_placements()
	assert_eq(placements.size(), 0,
		"topology-only route units never emit independent floor assets")
	assert_not_null(plan.surface_plan)
	assert_eq(plan.surface_plan.claim_count(), 12)
	assert_eq(plan.surface_plan.mesh_payloads.size(), 1)
	var payload := SettlementFabricAssembler.payload(plan)
	assert_eq(payload.instance_count, 0)
	assert_true(payload.validate())


func test_sectional_plan_binds_units_and_seals_one_surface_union() -> void:
	var realm := _sectional_route()
	var solver := SettlementFabricSolver.new(_program())
	var plan := solver.solve_sectional(&"warren.test.sectional", realm,
		_sectional_route_specs())
	assert_not_null(plan, solver.failure_reason)
	if plan == null:
		return
	assert_true(plan.validate())
	assert_eq(plan.public_realm.deterministic_signature(),
		realm.deterministic_signature())
	assert_eq(int(plan.audit.public_realm_node_count), 3)
	assert_eq(int(plan.audit.unclassified_interval_count), 0)
	assert_eq(int(plan.audit.visual_envelope_overlap_count), 0)
	assert_true(plan.visual_envelope_conflicts().is_empty())
	assert_eq(int(plan.audit.unreachable_exterior_air_count), 0)
	assert_eq(int(plan.audit.public_air_occupied_overlap_count), 0)
	assert_not_null(plan.solid_void_plan)
	assert_true(plan.solid_void_plan.is_sealed())
	assert_gt(int(plan.audit.exterior_air_cell_count), 0)
	assert_eq(plan.surface_plan.claim_count(), 12)
	assert_eq(plan.expanded_placements().size(), 0)


func test_sectional_surface_rejects_an_unclassified_required_interval() -> void:
	# Deliberately require one interval that neither surface nor another
	# classification owns.
	var surface := PublicRealmSurfacePlan.new(&"surface.unclassified")
	assert_true(surface.add_claim(Vector3i.ZERO,
		PublicRealmSurfacePlan.SurfaceKind.TERRAIN_STREET, &"owner"))
	assert_false(surface.seal([Vector3i(50, 2, 50)]))
	assert_eq(surface.unclassified_required_cells, [Vector3i(50, 2, 50)])


func test_minimum_requirements_reject_incomplete_visual_slice() -> void:
	var plan := SettlementFabricSolver.new(_program()).solve_authored(
		&"warren.test.requirements", _route_specs(), {
			&"skywalk_count": 2,
			&"outcropping_count": 4,
			&"market_family_count": 4,
		})
	assert_null(plan)


func test_plot_void_stairs_have_square_landings_and_no_disconnected_flights() \
		-> void:
	var plan := WarrenPlotVoidPlanner.new().solve(_program(), 0)
	assert_not_null(plan)
	if plan == null:
		return
	assert_eq(int(plan.audit.stair_endpoint_gap_count), 0,
		"both player-width stair lanes must physically meet their neighbors")
	assert_eq(int(plan.audit.stair_endpoint_missing_landing_count), 0,
		"every stair end must meet a level two-by-two landing")
	assert_eq(int(plan.audit.stair_to_stair_edge_count), 0,
		"successive flights must be separated by a square landing")
	assert_eq(int(plan.audit.platform_dead_end_count), 0,
		"every elevated platform must continue into a stair, path, or entrance")
	assert_eq(int(plan.audit.isolated_platform_count), 0)
	assert_eq(int(plan.audit.unsupported_platform_count), 0)
	assert_eq(int(plan.audit.unsupported_stair_count), 0)
	assert_eq(int(plan.audit.stair_count), 7,
		"the reviewed through-route must keep all seven external flights")
	assert_gte(int(plan.audit.vertical_span_cells), 5,
		"the route must climb through more than one token upper floor")
	assert_eq(int(plan.audit.detached_building_stack_count), 0,
		"every inhabited stack must reach a served path through occupied seams")
	assert_eq(int(plan.audit.connected_building_stack_count),
		int(plan.audit.building_stack_count))
	assert_gte(int(plan.audit.skywalk_link_count), 1,
		"the inhabited circulation graph must include an occupied skywalk link")
	assert_eq(int(plan.audit.prefab_anchor_count), 1,
		"one source-pack building must participate in the coupled massing")
	assert_gte(int(plan.audit.market_count), 2)
	assert_gte(int(plan.audit.market_family_count), 2,
		"the alley must use varied stocked market prefabs")
	for proposal: Dictionary in plan.embedding_plan.barrier_proposals:
		assert_ne(StringName(proposal.kind), &"bay",
			"a shallow facade bay must never become a sideways standalone house")
		if StringName(proposal.kind) == &"slim":
			var cells := StaggeredFabricCompiler.proposal_occupied_cells(proposal)
			var minimum := Vector2i(2147483647, 2147483647)
			var maximum := Vector2i(-2147483648, -2147483648)
			for cell: Vector3i in cells:
				minimum = minimum.min(Vector2i(cell.x, cell.z))
				maximum = maximum.max(Vector2i(cell.x, cell.z))
			var footprint := maximum - minimum + Vector2i.ONE
			assert_ne(footprint.x, footprint.y,
				"the townhouse proposal must retain its narrow/deep footprint")


func test_seed_changes_the_actual_maze_geometry() -> void:
	var signatures: Dictionary = {}
	var canonical_signatures: Dictionary = {}
	# Cover every low-bit sectional family: four route motifs, two ordinary
	# turn phases, and four vertical profiles. A seed may not merely recolour or
	# cardinally rotate a shared town.
	for world_seed in 32:
		var grammar: WarrenPlotVoidPlan
		for attempt in 64:
			grammar = WarrenPlotVoidGrammar.build(world_seed, attempt)
			if grammar != null:
				break
		assert_not_null(grammar)
		if grammar == null:
			continue
		var signature := grammar.geometry_signature()
		assert_false(signatures.has(signature),
			"seeds must not be cosmetic variants of one underlying route")
		signatures[signature] = true
		var canonical := grammar.canonical_coarse_route_signature()
		assert_false(canonical_signatures.has(canonical),
			"seed %d must not reuse seed %s under a cardinal rotation" % [
				world_seed, canonical_signatures.get(canonical, "none")])
		canonical_signatures[canonical] = world_seed
	assert_eq(signatures.size(), 32)
	assert_eq(canonical_signatures.size(), 32)


func test_seeded_maze_grammar_always_interposes_square_stair_landings() -> void:
	## This cheap property corpus guards the construction rule before the slower
	## exact fabric transaction: every flight ends at a full two-by-two corner
	## module, and another flight can attach only through that landing.
	for world_seed in 64:
		var grammar: WarrenPlotVoidPlan
		for attempt in WarrenPlotVoidPlanner.MAX_GRAMMAR_ATTEMPTS:
			grammar = WarrenPlotVoidGrammar.build(world_seed, attempt)
			if grammar != null:
				break
		assert_not_null(grammar, "seed %d must produce a route grammar" % world_seed)
		if grammar == null:
			continue
		for index in grammar.route_steps.size():
			var step := grammar.route_steps[index]
			if not String(step.recipe_id).begins_with("stair."):
				continue
			assert_lt(index + 1, grammar.route_steps.size())
			if index + 1 >= grammar.route_steps.size():
				continue
			var landing := grammar.route_steps[index + 1]
			assert_true(StringName(landing.recipe_id) in [
				&"route.corner", &"deck.corner",
			], "seed %d stair %s needs a square landing" % [
				world_seed, step.stable_id])
			assert_eq(StringName(landing.parent_id), StringName(step.stable_id))
			if index + 2 < grammar.route_steps.size() \
					and String(grammar.route_steps[index + 2].recipe_id).begins_with(
						"stair."):
				assert_eq(StringName(grammar.route_steps[index + 2].parent_id),
					StringName(landing.stable_id),
					"turning flights must join through their square landing")


func test_folded_visual_proof_passes_the_common_transaction() -> void:
	var plan: SettlementFabricPlan = _folded_proof()
	assert_not_null(plan)
	if plan == null:
		return
	assert_true(plan.is_sealed())
	assert_eq(int(plan.audit.tent_count), 0)
	assert_eq(int(plan.audit.isolated_platform_count), 0)
	assert_gte(int(plan.audit.stair_count), 2)
	# Skywalk construction has dedicated bearing/seam tests above, while the
	# procedural plot-void planner applies the per-town skywalk minimum. This
	# older folded fixture proves its route/court transaction only.
	assert_gte(int(plan.audit.vertical_span_cells), 6)
	assert_gte(int(plan.audit.sectional_elevation_change_count), 6)
	assert_true(bool(plan.audit.primary_has_court))
	assert_gte(int(plan.audit.primary_exterior_stair_count), 5)
	assert_eq(int(plan.audit.public_interior_node_count), 0)
	assert_eq(int(plan.audit.unreachable_exterior_air_count), 0)
	assert_eq(int(plan.audit.public_air_occupied_overlap_count), 0)
	assert_not_null(plan.solid_void_plan)
	assert_true(plan.solid_void_plan.is_sealed())
	assert_not_null(plan.embedding_plan)
	assert_true(plan.embedding_plan.validate())
	assert_gt(int(plan.audit.proposed_closed_boundary_count), 0)
	assert_lt(int(plan.audit.unbounded_route_side_count),
		int(plan.audit.boundary_obligation_count),
		"compiled occupied barriers must close part of the public boundary")
	assert_gt(int(plan.audit.building_base_band_count), 2)
	assert_gte(int(plan.audit.structural_court_cell_count), 31)
	assert_eq(int(plan.audit.stair_endpoint_gap_count), 0)
	assert_eq(int(plan.audit.platform_dead_end_count), 0)
	assert_eq(int(plan.audit.daylight_void_cell_count), 1)
	assert_eq(int(plan.audit.daylight_void_bounded_edge_count), 4)
	assert_eq(int(plan.audit.daylight_void_unbounded_edge_count), 0)
	assert_eq(int(plan.audit.unsupported_platform_count), 0)
	assert_eq(int(plan.audit.unsupported_stair_count), 0)
	assert_gte(int(plan.audit.platform_bearing_parent_count), 2)
	assert_gt(int(plan.audit.served_entrance_count), 0)
	assert_eq(int(plan.audit.unserved_entrance_count), 0)
	assert_gt(int(plan.audit.served_structural_entrance_count), 0)
	assert_eq(int(plan.audit.entrance_guard_conflict_count), 0)
	assert_gte(int(plan.audit.derived_guard_segment_count), 4)
	assert_false(plan.surface_plan.guard_mesh_payload.is_empty())
	assert_gt((plan.surface_plan.guard_mesh_payload.collision_faces \
		as PackedVector3Array).size(), 0)
	assert_eq(int(plan.audit.unclassified_interval_count), 0)
	var surface_visuals := SettlementFabricAssembler.surface_visual_payload(
		plan.surface_plan)
	assert_true(surface_visuals.validate())
	assert_gt(surface_visuals.instance_count, 0)
	assert_true(surface_visuals.asset_ids().has(
		SettlementFabricAssembler.PLANK_FLOOR))
	assert_false(SettlementFabricAssembler.renders_generated_surface_underlay(
		PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT),
		"authored platform boards must not reveal a dark duplicate mesh below")
	assert_false(SettlementFabricAssembler.renders_generated_surface_underlay(
		PublicRealmSurfacePlan.SurfaceKind.BRIDGE))
	assert_true(SettlementFabricAssembler.renders_generated_surface_underlay(
		PublicRealmSurfacePlan.SurfaceKind.TERRAIN_STREET))


func test_staggered_embedder_closes_route_sides_without_entering_public_air() \
		-> void:
	var plan: SettlementFabricPlan = _folded_proof()
	assert_not_null(plan)
	if plan == null:
		return
	var proposal := plan.embedding_plan
	assert_not_null(proposal)
	if proposal == null:
		return
	assert_true(proposal.validate())
	assert_gt(int(proposal.audit().proposed_barrier_count), 0)
	assert_gt(int(proposal.audit().proposed_closed_boundary_count), 0)
	assert_gt(int(proposal.audit().proposed_base_band_count), 1)
	# The addressed court stack now owns one of the height bands that used to be
	# emitted by this pass. Staggering is a completed-city invariant, not an
	# implementation detail of one particular solver phase.
	assert_gt(int(plan.audit.half_level_neighbor_pair_count), 0)
	assert_gte(int(proposal.audit().proposed_storey_variant_count), 1,
		"the filler may prune tall variants near measured overhang envelopes")
	assert_gt(int(proposal.audit().proposed_market_frontage_count), 0)
	var public_air := plan.public_realm.air_claims()
	for barrier: Dictionary in proposal.barrier_proposals:
		if StringName(barrier.kind) == &"market":
			assert_eq(int(barrier.storeys), 0)
		else:
			assert_true(int(barrier.storeys) >= 1 and int(barrier.storeys) <= 4)
		var support_mode := StringName(barrier.support_mode)
		assert_true(support_mode == &"grounded_stack" \
			or support_mode == &"retained_half_perch")
		assert_eq((barrier.origin as Vector3i).y, 0 \
			if support_mode == &"grounded_stack" else 1)
		for cell: Vector3i in barrier.occupied_cells as Array[Vector3i]:
			assert_false(public_air.has(cell))


func test_critical_review_succeeds_by_reporting_current_visual_issues() -> void:
	var plan: SettlementFabricPlan = _folded_proof()
	assert_not_null(plan)
	if plan == null:
		return
	var failures := SettlementFabricSolver.requirement_failures(plan.audit,
		FoldedProof.REVIEW_TARGETS)
	assert_gt(failures.size(), 0, "review should find an issue in the current slice")
	assert_true(failures.any(func(value: String) -> bool:
		return value.begins_with("frontage_ratio=")))
	assert_true(failures.any(func(value: String) -> bool:
		return value.begins_with("overhead_route_ratio=")))
	assert_true(failures.any(func(value: String) -> bool:
		return value.begins_with("through_sightline_count=")))
	# The compact-cap pass brought both core dimensions under their review cap;
	# keep that gain pinned while the issue-seeking review continues to require
	# enclosure, overhead, and sightline failures until the coupled maze lands.
	assert_false(failures.any(func(value: String) -> bool:
		return value.begins_with("solid_void_core_width_cells=") \
			or value.begins_with("solid_void_core_depth_cells=")))
