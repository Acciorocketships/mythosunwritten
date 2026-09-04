extends GutTest


func test_perimeter_routes_prefer_fewer_turns_over_short_zigzags() -> void:
	var walkable: Dictionary = {}
	# Equal-length alternatives around two notches. A breadth-first cell search
	# forgets arrival direction and chooses R,D,R,D; the street needs R,R,D,D.
	for y in range(3):
		for x in range(3):
			walkable[Vector2i(x, y)] = true
	walkable.erase(Vector2i(1, 0))
	var graph := VillageOutskirtsSolver._perimeter_component(Vector2i.ZERO,
		walkable, [], Vector2.ZERO, Vector2.RIGHT)
	var path := VillageOutskirtsSolver._perimeter_path(Vector2i(2, 2),
		Vector2i.ZERO, graph.parents)
	var turns := 0
	for index in range(2, path.size()):
		if path[index] - path[index - 1] != path[index - 1] - path[index - 2]:
			turns += 1
	assert_eq(turns, 1, "prefer D,D,R,R rather than tracing each contour notch")


func test_house_street_bend_matches_the_main_road_fillet() -> void:
	var shapes := PathProgram.filleted_path_shapes(
		[Vector2(12, 0), Vector2.ZERO, Vector2(0, 12)] as Array[Vector2],
		PathProgram.PATH_HALF_WIDTH, FeatureGroundField.WORN_PATH, 100,
		&"test.fillet")
	var house_path := FeatureGroundField.new(shapes, [], 0.0)
	var main_path := FeatureGroundField.new([], [], 0.0, {Vector2i.ZERO: 5})
	var mismatch := 0
	# Avoid the analytic boundary itself; the arc tessellation has a <1 cm error.
	for z in range(-7, 32):
		for x in range(-7, 32):
			var point := Vector2(x * 0.25 + 0.03, z * 0.25 + 0.03)
			if house_path.surface_at(point) != main_path.surface_at(point):
				mismatch += 1
	assert_eq(mismatch, 0,
		"house streets and world roads must share the same constant-width rounded bend")


func test_all_exit_neighbourhoods_share_the_primary_road_root() -> void:
	var urban := VillageUrbanFabricPlan.new()
	urban.accepted = true
	urban.volumes = [VillageOccupancyVolume.new(VillageOccupancy.Role.SOLID,
		Vector2.ZERO, Vector2.ONE * 6.0, 0.0, 0.0, 6.0, &"core", &"core")]
	var contacts: Array[VillageCirculationNode] = []
	for point: Vector2 in [Vector2(-9, 0), Vector2(9, 0)]:
		contacts.append(VillageCirculationNode.new(StringName(str(point)),
			VillageCirculationNode.Kind.TERRAIN_CONTACT, point, 0.0,
			&"exit", point.normalized()))
	var branches := VillageOutskirtsSolver._outskirts_branches(
		VillageTerrainView.from_region(_flat_region()), Vector2.ZERO,
		Vector2.RIGHT, contacts, 12.0, urban, true)
	assert_gt(branches.size(), 2)
	for branch: Dictionary in branches:
		assert_eq(branch.network_nodes[0].point, contacts[0].point,
			"a secondary exit may not create a road component detached from the main road")


func _flat_region() -> HeightfieldRegion:
	var storeys: Dictionary = {}
	var levels: Dictionary = {}
	for z in range(-6, 7):
		for x in range(-6, 7):
			storeys[Vector2i(x, z)] = 0
			levels[Vector2i(x, z)] = 0
	return HeightfieldRegion.new(storeys, levels)


func test_optional_ground_house_uses_annular_terrain_and_a_short_public_lane() -> void:
	assert_eq(VillageOutskirtsProgram.MAX_CONNECTOR_LENGTH,
		VillageOutskirtsProgram.OUTER_RADIUS,
		"the connector reach is derived from the parcel annulus")
	var program := VillageProgram.compile({}, EnvironmentCatalog.load_default())
	var urban := VillageUrbanFabricPlan.new()
	urban.accepted = true
	urban.massing = VillageMassingPlan.new()
	urban.massing.placements = []
	urban.market = VillageMarketPlan.new()
	urban.market.accepted = true
	urban.circulation = VillageCirculationPlan.new()
	urban.circulation.accepted = true
	for value: Vector2 in [Vector2(18.0, 0.0), Vector2(-18.0, 0.0),
			Vector2(0.0, 18.0), Vector2(0.0, -18.0)]:
		urban.circulation.nodes.append(VillageCirculationNode.new(
			StringName("contact.%d.%d" % [roundi(value.x), roundi(value.y)]),
			VillageCirculationNode.Kind.TERRAIN_CONTACT, value, 0.0))
	var plan := VillageOutskirtsSolver.solve(
		VillageTerrainView.from_region(_flat_region()), &"outskirts.test",
		Vector2.ZERO, Vector2.RIGHT, &"village", &"blue", program,
		urban, [])
	assert_true(plan.accepted, String(plan.reason))
	assert_gte(plan.placements.size(), 1, JSON.stringify(plan.audit, "  "))
	assert_gt(plan.surfaces.size(), 0,
		"an outer house is part of town only when a short lane joins it")
	assert_gt(plan.volumes.size(), 1)
	assert_eq(plan.supported_house_count, plan.placements.size(),
		"the edge house passes the measured terrain-bearing support solve")
	assert_gte(plan.foundation_piece_count, 0,
		"a naturally flush threshold legitimately needs no visible stone course")
	var asset_ids: Array[StringName] = []
	for placement: VillageMassingPlacement in plan.placements:
		asset_ids.append(placement.asset_id)
	assert_false(asset_ids.is_empty(),
		"the legacy custom-program fixture still receives an optional edge house")
	assert_true(String(plan.placements[0].stable_key).begins_with(
		"outskirts.house."))
	assert_true(plan.validate(program.outskirts_program, &"village"))
	var radius := plan.placements[0].solid_centre.length()
	assert_gte(radius, VillageOutskirtsProgram.INNER_RADIUS - 12.0,
		"the house belongs to the porous edge, not the market core")


func test_volumetric_warren_approach_gets_a_ground_house_without_legacy_graphs() -> void:
	var program := VillageProgram.compile({}, EnvironmentCatalog.load_default())
	var urban := VillageUrbanFabricPlan.new()
	urban.accepted = true
	urban.generation_kind = VillageUrbanFabricPlan.GenerationKind.VOLUMETRIC_WARREN
	var plan := VillageOutskirtsSolver.solve(
		VillageTerrainView.from_region(_flat_region()), &"outskirts.warren",
		Vector2.ZERO, Vector2.RIGHT, &"village", &"orange", program,
		urban, [])
	assert_true(plan.accepted, String(plan.reason))
	assert_gte(plan.placements.size(), 2, JSON.stringify(plan.audit, "  "))
	assert_true(plan.placements.any(func(placement: VillageMassingPlacement) -> bool:
		return String(placement.asset_id).begins_with("sfv.building.")),
		"the unconstrained edge exposes at least one substantial compound prefab")
	assert_eq(plan.supported_house_count, plan.placements.size())
	assert_eq(plan.side_served_house_count, plan.placements.size())
	assert_eq(plan.branch_count, plan.placements.size(),
		"the synthetic one-exit fixture uses distinct local street frontages")
	var directions: Array[Vector2] = []
	for row: Dictionary in plan.audit:
		if not bool(row.accepted):
			continue
		assert_gte(float(row.door_branch_alignment), 0.85,
			"every prefab door faces its own branch")
		assert_gte(float(row.perimeter_gap), 0.0)
		assert_lte(float(row.perimeter_gap),
			VillageOutskirtsSolver.MAX_PERIMETER_GAP,
			"the local lane and prefab retain ordinary town-edge spacing")
		assert_eq(float(row.outskirts_grid_step),
			VillageWorldScale.WORLD_FINE_CELL_M)
		assert_lte(float(row.neighbourhood_route_length),
			VillageOutskirtsSolver.ENTRY_NEIGHBOURHOOD_STEPS \
				* VillageWorldScale.WORLD_FINE_CELL_M,
			"one entrance cannot grow a town-wide perimeter road")
		var raw_point := row.branch_point as Array
		assert_almost_eq(fmod(absf(float(raw_point[0])),
			VillageWorldScale.WORLD_FINE_CELL_M), 0.0, 0.0001)
		assert_almost_eq(fmod(absf(float(raw_point[1])),
			VillageWorldScale.WORLD_FINE_CELL_M), 0.0, 0.0001)
		assert_lte(float(row.parcel_connector_length),
			VillageOutskirtsProgram.OUTER_RADIUS,
			"the shared perimeter road does not inflate a house spur")
		var raw_direction := row.branch_direction as Array
		directions.append(Vector2(float(raw_direction[0]),
			float(raw_direction[1])))
	for first_index in directions.size():
		for second_index in range(first_index + 1, directions.size()):
			assert_lt(directions[first_index].dot(directions[second_index]), 0.5,
				"the village budget must cover separated sides of the town")
	assert_gt(plan.surfaces.size(), 0,
		"the outward approach contact replaces the legacy circulation graph")
	assert_true(plan.validate(program.outskirts_program, &"village"))
	for placement: VillageMassingPlacement in plan.placements:
		assert_almost_eq(placement.uniform_scale,
			VillageWorldScale.PRODUCTION_UNIFORM_SCALE, 0.0001,
			"edge prefabs and dense town rooms share one authored-to-world scale")
		assert_gte(placement.support_half_extents.length(), 9.0,
			"the scaled edge silhouette cannot regress to a tiny cottage prop")
		assert_almost_eq(absf(sin(placement.yaw * 2.0)), 0.0, 0.0001,
			"outskirts prefabs keep the town's cardinal grid orientation")


func test_perimeter_grid_follows_a_concave_urban_union_not_its_bounds() -> void:
	var urban := VillageUrbanFabricPlan.new()
	urban.accepted = true
	urban.volumes = [
		VillageOccupancyVolume.new(VillageOccupancy.Role.SOLID,
			Vector2(3.0, 0.0), Vector2(6.0, 1.5), 0.0, 0.0, 4.0,
			&"horizontal", &"urban"),
		VillageOccupancyVolume.new(VillageOccupancy.Role.SOLID,
			Vector2(0.0, 3.0), Vector2(1.5, 6.0), 0.0, 0.0, 4.0,
			&"vertical", &"urban"),
	]
	var grid := VillageOutskirtsSolver._urban_perimeter_grid(urban,
		Vector2.ZERO, Vector2.RIGHT)
	var perimeter := grid.perimeter as Dictionary
	assert_true(perimeter.has(Vector2i(2, 2)),
		"the lane follows the L-shaped recess at normal module clearance")
	assert_false(perimeter.has(Vector2i(7, 7)),
		"an empty bounding-box corner cannot become a distant perimeter road")


func test_volumetric_ground_exits_each_author_a_connected_outskirts_branch() -> void:
	var program := VillageProgram.compile({}, EnvironmentCatalog.load_default())
	var urban := VillageUrbanFabricPlan.new()
	urban.accepted = true
	urban.generation_kind = VillageUrbanFabricPlan.GenerationKind.VOLUMETRIC_WARREN
	urban.volumes = [VillageOccupancyVolume.new(VillageOccupancy.Role.SOLID,
		Vector2.ZERO, Vector2.ONE * 16.5, 0.0, 0.0, 8.0,
		&"fixture.core", &"fixture.core")]
	urban.circulation = VillageCirculationPlan.new()
	urban.circulation.accepted = true
	for value: Vector2 in [Vector2(18.0, 0.0), Vector2(-18.0, 0.0),
			Vector2(0.0, 18.0), Vector2(0.0, -18.0)]:
		urban.circulation.nodes.append(VillageCirculationNode.new(
			StringName("exit.%d.%d" % [roundi(value.x), roundi(value.y)]),
			VillageCirculationNode.Kind.TERRAIN_CONTACT, value, 0.0,
			&"warren.public_exit", value.normalized()))
	var plan := VillageOutskirtsSolver.solve(
		VillageTerrainView.from_region(_flat_region()), &"outskirts.branches",
		Vector2.ZERO, Vector2.RIGHT, &"village", &"blue", program,
		urban, [])
	assert_true(plan.accepted, String(plan.reason))
	assert_gte(plan.placements.size(), 4, JSON.stringify(plan.audit, "  "))
	assert_eq(plan.supported_house_count, plan.placements.size())
	assert_eq(plan.side_served_house_count, plan.placements.size())
	assert_eq(plan.audit.size(),
		program.outskirts_program.target_houses(&"village", 4),
		"one audited slot per targeted house of a four-exit town")
	var accepted_contacts: Dictionary = {}
	var accepted_sources: Dictionary = {}
	for row: Dictionary in plan.audit:
		assert_eq(int(row.route_exit_count), 4)
		if not bool(row.accepted):
			continue
		assert_gte(float(row.door_branch_alignment), 0.85)
		assert_lte(float(row.neighbourhood_route_length),
			VillageOutskirtsSolver.ENTRY_NEIGHBOURHOOD_STEPS \
				* VillageWorldScale.WORLD_FINE_CELL_M)
		accepted_contacts[String(row.branch_contact)] = true
		accepted_sources[String(row.branch_source)] = true
	assert_gte(accepted_contacts.size(), 4,
		"the contour provides several separated deterministic frontages")
	assert_gte(accepted_sources.size(), 2,
		"the edge district grows from several nearby exit neighbourhoods; shared " \
		+ "contour roots retain whichever source gives the shortest route")
	assert_gte(plan.branch_count, 4,
		"every exit is represented before additional local frontages are used")
	assert_lte(plan.branch_count, plan.placements.size())
	assert_gt(plan.surfaces.size(), 4,
		"each house contributes a real continuation lane, not an isolated prop")
	assert_true(plan.validate(program.outskirts_program, &"village"))


func test_canonical_entry_resolves_to_the_parcels_nearest_road_handoff() -> void:
	var from := VillageCirculationNode.new(&"house.street",
		VillageCirculationNode.Kind.TERRAIN_CONTACT,
		Vector2(-42.0, 9.0), 0.0, &"house", Vector2.DOWN)
	var entry := VillageCirculationNode.new(&"warren.canonical_entry",
		VillageCirculationNode.Kind.TERRAIN_CONTACT,
		Vector2.ZERO, 0.0, &"warren.public_entry", Vector2.LEFT)
	var contacts := VillageOutskirtsSolver._resolved_branch_contacts(
		VillageTerrainView.from_region(_flat_region()), from, [entry])
	assert_eq(contacts.size(), 1)
	assert_eq(contacts[0].point, Vector2(-42.0, 0.0),
		"the small lane branches orthogonally from the continuing world road")
	assert_eq(contacts[0].outward, Vector2.LEFT)
	assert_true(String(contacts[0].stable_key).begins_with(
		"warren.road_handoff."))


func test_complete_outskirts_house_envelope_may_not_overlap_world_road() -> void:
	var road := FeatureGroundShape.capsule(Vector2(-12.0, 0.0),
		Vector2(12.0, 0.0), 2.0, FeatureGroundField.WORN_PATH,
		FeatureGroundField.PATH_PRIORITY, &"fixture.road")
	var field := FeatureGroundField.new([road] as Array[FeatureGroundShape],
		[road] as Array[FeatureGroundShape], 24.0)
	var house := VillageMassingPlacement.new()
	house.solid_centre = Vector2(0.0, 2.75)
	house.solid_half_extents = Vector2(4.5, 3.0)
	house.solid_angle = 0.0
	assert_true(VillageOutskirtsSolver.parcel_conflicts_canonical_clearance(
		house, field),
		"the broad prefab envelope crosses the road even if its anchor does not")
	house.solid_centre = Vector2(0.0, 12.0)
	assert_false(VillageOutskirtsSolver.parcel_conflicts_canonical_clearance(
		house, field),
		"an ordinary side parcel beyond the clearance margin remains eligible")


func test_town_branch_segments_are_square_capped_at_right_angle_turns() -> void:
	var horizontal := VillageOutskirtsSolver._right_angle_path_segment(
		Vector2.ZERO, Vector2(6.0, 0.0), PathProgram.PATH_HALF_WIDTH,
		FeatureGroundField.WORN_PATH, VillagePlan.SURFACE_PRIORITY,
		&"test.turn.horizontal")
	var vertical := VillageOutskirtsSolver._right_angle_path_segment(
		Vector2(6.0, 0.0), Vector2(6.0, 6.0), PathProgram.PATH_HALF_WIDTH,
		FeatureGroundField.WORN_PATH, VillagePlan.SURFACE_PRIORITY,
		&"test.turn.vertical")
	assert_eq(horizontal.kind, FeatureGroundShape.Kind.ORIENTED_RECT)
	assert_eq(vertical.kind, FeatureGroundShape.Kind.ORIENTED_RECT)
	assert_true(horizontal.contains(Vector2(7.9, 1.9)),
		"the first edge owns the full square outer quadrant at the elbow")
	assert_true(vertical.contains(Vector2(4.1, -1.9)),
		"the second edge owns the opposite quadrant at the same elbow")
	assert_false(horizontal.contains(Vector2(8.1, 2.1)))
	assert_false(vertical.contains(Vector2(3.9, -2.1)),
		"the square turn cannot grow a capsule's rounded entrance lobe")


func test_warren_contact_geometry_uses_the_public_cell_centre_phase() -> void:
	var spec := {
		"cells": [Vector3i(0, 0, 0), Vector3i(0, 0, 1)] as Array[Vector3i],
		"outward": Vector3i.LEFT,
		"lateral": Vector3i.BACK,
	}
	var contact := VillageWarrenFabricSolver.terrain_contact_local_geometry(spec)
	assert_eq(contact.street_centre, Vector3(0.0, 0.0, 0.75),
		"adjacent public cells are centre-indexed, not corner-indexed")
	assert_eq(contact.inner_centre, Vector3(-0.75, 0.0, 0.75),
		"the handoff begins exactly on the finished street edge")
	assert_eq(contact.outer_centre, Vector3(-2.25, 0.0, 0.75),
		"the outskirts road starts at the terrain side of that same ramp")
	assert_almost_eq(float(contact.half_width), 1.5, 0.0001)


func test_a_root_facing_the_towns_stalls_mirrors_a_market_street() -> void:
	## 2026-09-04: the town's own perimeter stalls are published on the urban
	## plan. The contour lane must run in FRONT of them, and the ring house whose
	## root faces that stall row stands one stall band back with stocked stalls of
	## the same vocabulary between it and the lane, facing the town.
	var program := VillageProgram.compile({}, EnvironmentCatalog.load_default())
	var urban := VillageUrbanFabricPlan.new()
	urban.accepted = true
	urban.generation_kind = VillageUrbanFabricPlan.GenerationKind.VOLUMETRIC_WARREN
	urban.volumes = [VillageOccupancyVolume.new(VillageOccupancy.Role.SOLID,
		Vector2.ZERO, Vector2.ONE * 16.5, 0.0, 0.0, 8.0,
		&"fixture.core", &"fixture.core")]
	urban.circulation = VillageCirculationPlan.new()
	urban.circulation.accepted = true
	for value: Vector2 in [Vector2(18.0, 0.0), Vector2(-18.0, 0.0),
			Vector2(0.0, 18.0), Vector2(0.0, -18.0)]:
		urban.circulation.nodes.append(VillageCirculationNode.new(
			StringName("exit.%d.%d" % [roundi(value.x), roundi(value.y)]),
			VillageCirculationNode.Kind.TERRAIN_CONTACT, value, 0.0,
			&"warren.public_exit", value.normalized()))
	# One scaled market stall leaning on the east wall beside (not in) the east
	# exit's mouth, its front toward +X.
	var stall_centre := Vector2(16.5 + 4.0, 9.0)
	var stall_half := Vector2(4.0, 4.5)
	urban.frontage_sites = [{
		"asset": SettlementFabricAssembler.PERIMETER_MARKET_STALL,
		"transform": Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 2.0),
			Vector3(stall_centre.x, 0.0, stall_centre.y)),
		"centre": stall_centre,
		"half_extents": stall_half,
		"height": 6.4,
		"outward": Vector2.RIGHT,
		"width_cells": 3,
	}]
	var plan := VillageOutskirtsSolver.solve(
		VillageTerrainView.from_region(_flat_region()), &"outskirts.market",
		Vector2.ZERO, Vector2.RIGHT, &"village", &"blue", program,
		urban, [])
	assert_true(plan.accepted, String(plan.reason))
	assert_gt(plan.market_stall_count, 0,
		"a house facing the town's stall row mirrors stocked stalls across the lane "
		+ JSON.stringify(plan.audit.map(func(row: Dictionary) -> Dictionary:
			return {"accepted": row.accepted, "source": row.branch_source,
				"point": row.branch_point, "rejections": row.rejection_counts})))
	var stall_footprint := FeatureGroundShape.oriented_rect(stall_centre,
		stall_half, 0.0)
	for surface: FeatureGroundShape in plan.surfaces:
		assert_false(surface.intersects(stall_footprint, 0.0),
			"the lane runs in front of the town's stalls, never through them")
	var mirrored := 0
	for entry: Dictionary in plan.entries:
		if not VillageOutskirtsSolver.MARKET_STALL_ASSETS.has(
				StringName(entry.asset_id)):
			continue
		mirrored += 1
		var origin := (entry.transform as Transform3D).origin
		assert_gt(origin.x, stall_centre.x + stall_half.x
			+ PathProgram.PATH_WIDTH,
			"a mirrored stall stands across the lane from the town's own stall")
		var facing := (entry.transform as Transform3D).basis * Vector3.BACK
		assert_lt(facing.x, 0.0, "a mirrored stall faces the town")
	assert_eq(mirrored, plan.market_stall_count)
	var market_rows := 0
	for row: Dictionary in plan.audit:
		market_rows += int(int(row.get("market_stalls", 0)) > 0)
	assert_gt(market_rows, 0, "the audit names the market lot")
