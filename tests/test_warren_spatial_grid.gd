extends GutTest


func _cells(values: Array[Vector3i]) -> Array[Vector3i]:
	return values


func test_fine_grid_uses_one_uniform_fabric_lattice() -> void:
	var grid := WarrenSpatialGrid.new(Vector3i(-2, -1, -3),
		Vector3i(5, 7, 8))
	assert_true(grid.is_valid())
	assert_eq(WarrenSpatialGrid.CELL_SIZE_M, FabricRecipe.CELL_SIZE)
	assert_eq(WarrenSpatialGrid.STOREY_CELLS, 2)
	assert_eq(WarrenSpatialGrid.ROOM_BAY_CELLS, Vector2i(2, 2))
	for cell: Vector3i in [Vector3i(-2, -1, -3), Vector3i.ZERO,
			Vector3i(2, 5, 4)]:
		assert_true(grid.contains(cell))
		assert_eq(grid.cell_for_index(grid.index_for(cell)), cell)
	assert_false(grid.contains(Vector3i(3, 0, 0)))


func test_transactions_are_atomic_and_protect_public_air() -> void:
	var grid := WarrenSpatialGrid.new(Vector3i.ZERO, Vector3i(4, 4, 4))
	var tunnel := _cells([Vector3i(1, 0, 1), Vector3i(1, 1, 1)])
	var envelope := grid.begin_transaction(&"massif")
	assert_true(envelope.assign_use(tunnel,
		WarrenSpatialGrid.Use.ALLOCATABLE, &"massif"))
	assert_true(envelope.commit())

	var carve := grid.begin_transaction(&"route.main")
	assert_true(carve.require_use(tunnel,
		[WarrenSpatialGrid.Use.ALLOCATABLE]))
	assert_true(carve.reserve(tunnel,
		WarrenSpatialGrid.Reservation.PUBLIC_CLEARANCE, &"route.main"))
	assert_true(carve.assign_use(tunnel, WarrenSpatialGrid.Use.PUBLIC_AIR,
		&"route.main"))
	assert_true(carve.claim_face(Vector3i(1, 0, 1), Vector3i.DOWN,
		WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR, &"route.main"))
	assert_true(carve.commit(), carve.last_rejection)
	assert_eq(grid.use_at(Vector3i(1, 0, 1)),
		WarrenSpatialGrid.Use.PUBLIC_AIR)
	assert_eq(grid.owner_name_at(Vector3i(1, 0, 1)), &"route.main")

	var illegal_room := grid.begin_transaction(&"building.01")
	assert_true(illegal_room.assign_use([Vector3i(1, 0, 1)] as Array[Vector3i],
		WarrenSpatialGrid.Use.PRIVATE_VOLUME, &"building.01"))
	assert_false(illegal_room.commit(),
		"an unrelated room may not consume sealed public headroom")
	assert_eq(grid.use_at(Vector3i(1, 0, 1)),
		WarrenSpatialGrid.Use.PUBLIC_AIR,
		"a failed transaction must not partially mutate the grid")


func test_reservations_conflict_by_owner_but_load_channels_can_share() -> void:
	var grid := WarrenSpatialGrid.new(Vector3i.ZERO, Vector3i(3, 3, 3))
	var first := grid.begin_transaction(&"feature.a")
	assert_true(first.reserve([Vector3i.ONE] as Array[Vector3i],
		WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE, &"feature.a"))
	assert_true(first.commit())

	var visual_conflict := grid.begin_transaction(&"feature.b")
	assert_true(visual_conflict.reserve([Vector3i.ONE] as Array[Vector3i],
		WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE, &"feature.b"))
	assert_false(visual_conflict.commit(),
		"unrelated measured envelopes may not overlap")

	var load_a := grid.begin_transaction(&"load.a")
	assert_true(load_a.reserve([Vector3i.ZERO] as Array[Vector3i],
		WarrenSpatialGrid.Reservation.LOAD_CHANNEL, &"load.a"))
	assert_true(load_a.commit())
	var load_b := grid.begin_transaction(&"load.b")
	assert_true(load_b.reserve([Vector3i.ZERO] as Array[Vector3i],
		WarrenSpatialGrid.Reservation.LOAD_CHANNEL, &"load.b"))
	assert_true(load_b.commit(),
		"compatible load paths may share a terrain-bearing column")


func test_opposite_face_queries_address_one_canonical_interface() -> void:
	var grid := WarrenSpatialGrid.new(Vector3i.ZERO, Vector3i(3, 3, 3))
	var tx := grid.begin_transaction(&"building.01")
	assert_true(tx.claim_face(Vector3i(1, 1, 1), Vector3i.RIGHT,
		WarrenSpatialGrid.FaceKind.FACADE, &"building.01"))
	assert_true(tx.commit())
	var from_room := grid.face_claim(Vector3i(1, 1, 1), Vector3i.RIGHT)
	var from_street := grid.face_claim(Vector3i(2, 1, 1), Vector3i.LEFT)
	assert_false(from_room.is_empty())
	assert_eq(from_room, from_street)
	assert_eq(StringName(from_room.owner_id), &"building.01")


func test_sealed_grid_rejects_later_transactions() -> void:
	var grid := WarrenSpatialGrid.new(Vector3i.ZERO, Vector3i(2, 2, 2))
	assert_true(grid.seal())
	var tx := grid.begin_transaction(&"late")
	assert_false(tx.assign_use([Vector3i.ZERO] as Array[Vector3i],
		WarrenSpatialGrid.Use.ALLOCATABLE, &"late"))
	assert_false(tx.commit())
