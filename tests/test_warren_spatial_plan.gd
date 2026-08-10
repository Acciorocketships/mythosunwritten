extends GutTest


func _assign(grid: WarrenSpatialGrid, owner: StringName, cells: Array[Vector3i],
		use: int) -> bool:
	var tx := grid.begin_transaction(owner)
	return tx.assign_use(cells, use, owner) and tx.commit()


func _offset_four_storey_cells() -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for y in range(8):
		var offset_x := 1 if y >= 4 else 0
		for x in range(2):
			for z in range(2):
				out.append(Vector3i(x + offset_x, y, z))
	return out


func _constant_four_storey_cells() -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for y in range(8):
		for x in range(2):
			for z in range(2):
				out.append(Vector3i(x, y, z))
	return out


func _add_tower_rooms(building: WarrenBuildingVolume,
		grid: WarrenSpatialGrid, origins: Array[Vector3i],
		addressed_index: int = -1, threshold := Vector3i(2147483647,
			2147483647, 2147483647),
		frontage := Vector3i.ZERO) -> bool:
	for index in origins.size():
		var addressed := index == addressed_index
		var room := WarrenRoomStamp.new(StringName("%s.room%02d" % [
			building.stable_id, index]), &"fixture.parcel", &"tower",
			origins[index], 0, index, index == 0, addressed,
			threshold if addressed else Vector3i(2147483647, 2147483647,
				2147483647), frontage if addressed else Vector3i.ZERO)
		if not room.add_private_cells(WarrenRoomStamp.expected_private_cells(
				&"tower", origins[index], 0)) \
				or not room.seal(grid, building.stable_id) \
				or not building.add_room(room):
			return false
	return true


func test_building_volume_refuses_a_four_storey_extrusion() -> void:
	var grid := WarrenSpatialGrid.new(Vector3i(-1, 0, -1),
		Vector3i(5, 10, 4))
	var cells := _constant_four_storey_cells()
	assert_true(_assign(grid, &"building.tower", cells,
		WarrenSpatialGrid.Use.PRIVATE_VOLUME))
	var building := WarrenBuildingVolume.new(&"building.tower", 0)
	assert_true(building.add_private_cells(cells))
	assert_true(_add_tower_rooms(building, grid, [Vector3i(1, 0, 1),
		Vector3i(1, 2, 1), Vector3i(1, 4, 1), Vector3i(1, 6, 1)] \
		as Array[Vector3i]))
	assert_false(building.seal(grid))
	assert_true(building.last_rejection.contains("floorplate"),
		building.last_rejection)


func test_building_volume_accepts_a_room_scale_upper_offset() -> void:
	var grid := WarrenSpatialGrid.new(Vector3i(-1, 0, -1),
		Vector3i(6, 10, 4))
	var cells := _offset_four_storey_cells()
	assert_true(_assign(grid, &"building.chaotic", cells,
		WarrenSpatialGrid.Use.PRIVATE_VOLUME))
	assert_true(_assign(grid, &"route", [Vector3i(0, 0, -1),
		Vector3i(0, 1, -1)] as Array[Vector3i],
		WarrenSpatialGrid.Use.PUBLIC_AIR))
	var building := WarrenBuildingVolume.new(&"building.chaotic", 0)
	assert_true(building.add_private_cells(cells))
	assert_true(_add_tower_rooms(building, grid, [Vector3i(1, 0, 1),
		Vector3i(1, 2, 1), Vector3i(2, 4, 1), Vector3i(2, 6, 1)] \
		as Array[Vector3i], 0, Vector3i(0, 0, 0), Vector3i.FORWARD))
	assert_true(building.add_threshold(Vector3i(0, 0, 0),
		Vector3i(0, 0, -1)))
	assert_true(building.seal(grid), building.last_rejection)
	assert_eq(int(building.audit.storey_count), 4)
	assert_eq(int(building.audit.longest_identical_floorplate_run), 2)
	assert_gte(float(building.audit.minimum_composition_break_ratio), 0.25)


func test_support_graph_requires_every_node_to_reach_terrain() -> void:
	var supported := WarrenSupportGraph.new()
	assert_true(supported.add_node(&"room.lower"))
	assert_true(supported.add_node(&"room.upper"))
	assert_true(supported.mark_terrain_root(&"room.lower"))
	assert_true(supported.add_edge(&"room.upper", &"room.lower"))
	assert_true(supported.seal([&"room.lower", &"room.upper"] \
		as Array[StringName]), supported.last_rejection)

	var floating := WarrenSupportGraph.new()
	assert_true(floating.add_node(&"room.lower"))
	assert_true(floating.add_node(&"room.upper"))
	assert_true(floating.add_edge(&"room.upper", &"room.lower"))
	assert_false(floating.seal([&"room.upper"] as Array[StringName]))

	var cycle := WarrenSupportGraph.new()
	assert_true(cycle.add_node(&"a"))
	assert_true(cycle.add_node(&"b"))
	assert_true(cycle.add_edge(&"a", &"b"))
	assert_true(cycle.add_edge(&"b", &"a"))
	assert_false(cycle.seal([&"a", &"b"] as Array[StringName]))


func _simple_plan(leave_allocatable: bool = false,
		omit_facade: bool = false) -> WarrenSpatialPlan:
	var grid := WarrenSpatialGrid.new(Vector3i(-1, 0, -2),
		Vector3i(5, 5, 5))
	var route_floor := [Vector3i(0, 0, 0), Vector3i(1, 0, 0)] \
		as Array[Vector3i]
	var route_air := [Vector3i(0, 0, 0), Vector3i(0, 1, 0),
		Vector3i(1, 0, 0), Vector3i(1, 1, 0)] as Array[Vector3i]
	assert_true(_assign(grid, &"route", route_air,
		WarrenSpatialGrid.Use.PUBLIC_AIR))
	var building_cells := [Vector3i(0, 0, 1), Vector3i(0, 1, 1),
		Vector3i(1, 0, 1), Vector3i(1, 1, 1), Vector3i(0, 0, 2),
		Vector3i(0, 1, 2), Vector3i(1, 0, 2), Vector3i(1, 1, 2)] \
		as Array[Vector3i]
	assert_true(_assign(grid, &"building.01", building_cells,
		WarrenSpatialGrid.Use.PRIVATE_VOLUME))
	if leave_allocatable:
		assert_true(_assign(grid, &"massif", [Vector3i(2, 0, 2)] \
			as Array[Vector3i], WarrenSpatialGrid.Use.ALLOCATABLE))

	var shell := grid.begin_transaction(&"shell")
	for floor_cell: Vector3i in route_floor:
		assert_true(shell.claim_face(floor_cell, Vector3i.DOWN,
			WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR, &"route"))
	assert_true(shell.claim_face(Vector3i(0, 0, 1), Vector3i.FORWARD,
		WarrenSpatialGrid.FaceKind.DOOR, &"building.01"))
	if not omit_facade:
		assert_true(shell.claim_face(Vector3i(1, 0, 1), Vector3i.FORWARD,
			WarrenSpatialGrid.FaceKind.FACADE, &"building.01"))
	assert_true(shell.claim_face(Vector3i(0, 1, 1), Vector3i.FORWARD,
		WarrenSpatialGrid.FaceKind.FACADE, &"building.01"))
	assert_true(shell.claim_face(Vector3i(1, 1, 1), Vector3i.FORWARD,
		WarrenSpatialGrid.FaceKind.FACADE, &"building.01"))
	for roof_cell: Vector3i in [Vector3i(0, 1, 1), Vector3i(1, 1, 1),
			Vector3i(0, 1, 2), Vector3i(1, 1, 2)]:
		assert_true(shell.claim_face(roof_cell, Vector3i.UP,
			WarrenSpatialGrid.FaceKind.ROOF, &"building.01"))
	assert_true(shell.commit(), shell.last_rejection)

	var building := WarrenBuildingVolume.new(&"building.01", 0)
	assert_true(building.add_private_cells(building_cells))
	assert_true(_add_tower_rooms(building, grid, [Vector3i(1, 0, 2)] \
		as Array[Vector3i], 0, Vector3i(0, 0, 1), Vector3i.FORWARD))
	assert_true(building.add_threshold(Vector3i(0, 0, 1),
		Vector3i(0, 0, 0)))
	assert_true(building.seal(grid), building.last_rejection)
	var supports := WarrenSupportGraph.new()
	assert_true(supports.add_node(&"building.01"))
	assert_true(supports.mark_terrain_root(&"building.01"))
	assert_true(supports.seal([&"building.01"] as Array[StringName]))

	var plan := WarrenSpatialPlan.new(&"spatial.fixture", 17, grid)
	for cell: Vector3i in route_floor:
		assert_true(plan.add_route_floor(cell))
	assert_true(plan.add_building(building))
	assert_true(plan.set_support_graph(supports))
	return plan


func test_spatial_plan_seals_one_authoritative_volume() -> void:
	var plan := _simple_plan()
	assert_true(plan.seal(Vector3i(0, 0, 0)), plan.last_rejection)
	assert_true(plan.is_sealed())
	assert_not_null(plan.construction_plan)
	assert_true(plan.construction_plan.is_sealed())
	assert_eq(int(plan.construction_plan.audit.source_face_count), 10)
	assert_eq(int(plan.construction_plan.audit.door_region_count), 1)
	assert_eq(plan.construction_plan.regions_for_kind(
		WarrenSpatialGrid.FaceKind.ROOF).size(), 1,
		"adjacent coplanar roof faces merge into one construction region")
	assert_eq(int(plan.audit.public_route_floor_count), 2)
	assert_eq(int(plan.audit.building_count), 1)
	assert_eq(int(plan.audit.unclassified_public_private_face_count), 0)
	assert_eq(int(plan.audit.allocatable_cell_count), 0)


func test_spatial_plan_rejects_leftover_mass_and_missing_interfaces() -> void:
	var leftover := _simple_plan(true)
	assert_false(leftover.seal(Vector3i(0, 0, 0)))
	assert_true(leftover.last_rejection.contains("allocatable"),
		leftover.last_rejection)

	var open_wall := _simple_plan(false, true)
	assert_false(open_wall.seal(Vector3i(0, 0, 0)))
	assert_true(open_wall.last_rejection.contains("interface"),
		open_wall.last_rejection)
