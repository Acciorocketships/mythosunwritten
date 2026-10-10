extends GutTest


func _fixture(street: bool, blocked: bool = false) -> Dictionary:
	var grid := WarrenSpatialGrid.new(Vector3i(-4, 0, -4), Vector3i(12, 10, 12))
	var buildings: Array[WarrenBuildingVolume] = []
	for x in [0, 3]:
		var room := WarrenRoomStamp.new(
			StringName("room.%d" % x),
			StringName("house.%d" % x),
			&"tower",
			Vector3i(x, 4, 0),
			0,
			0,
			true,
			false
		)
		room.private_cells = [Vector3i(x, 4, 0), Vector3i(x, 5, 0)]
		var building := WarrenBuildingVolume.new(StringName("building.%d" % x), 4)
		building.room_records.append(room)
		buildings.append(building)
	if street:
		var faces: Array[Dictionary] = []
		for x in [1, 2]:
			faces.append(
				{
					"cell": Vector3i(x, 0, 0),
					"direction": Vector3i.DOWN,
					"kind": WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR,
					"owner_id": &"street"
				}
			)
		grid._apply_faces(faces)
	if blocked:
		grid._apply_assignments(
			{
				grid.index_for(Vector3i(1, 4, 0)):
				{"use": WarrenSpatialGrid.Use.STRUCTURAL_VOLUME, "owner_id": &"wall"}
			}
		)
	return {"grid": grid, "buildings": buildings}


func test_complete_street_crossing_protects_its_whole_shell() -> void:
	var f := _fixture(true)
	var envelopes := WarrenSpatialFeatureSolver._prospective_street_crossing_envelopes(
		f.grid, f.buildings
	)
	assert_eq(envelopes.size(), 1)
	if envelopes.is_empty():
		return
	assert_true(
		envelopes[0].intersects(AABB(Vector3(1.5, 6, 0), Vector3(1.5, 3, 1.5))),
		"A bay in the first gallery cell must yield"
	)
	assert_false(
		envelopes[0].intersects(AABB(Vector3(1.5, 12, 0), Vector3(1.5, 3, 1.5))),
		"A separate upper bay can remain"
	)


func test_opposing_rooms_without_a_street_do_not_reserve_a_crossing() -> void:
	var f := _fixture(false)
	assert_true(
		(
			WarrenSpatialFeatureSolver
			. _prospective_street_crossing_envelopes(f.grid, f.buildings)
			. is_empty()
		)
	)


func test_occupied_span_does_not_take_optional_facade_space() -> void:
	var f := _fixture(true, true)
	assert_true(
		(
			WarrenSpatialFeatureSolver
			. _prospective_street_crossing_envelopes(f.grid, f.buildings)
			. is_empty()
		)
	)


func test_upper_walk_and_incomplete_endpoint_prevent_a_prospect() -> void:
	var f := _fixture(true)
	var faces: Array[Dictionary] = [
		{
			"cell": Vector3i(1, 5, 0),
			"direction": Vector3i.DOWN,
			"kind": WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR,
			"owner_id": &"upper.street"
		}
	]
	f.grid._apply_faces(faces)
	assert_true(
		(
			WarrenSpatialFeatureSolver
			. _prospective_street_crossing_envelopes(f.grid, f.buildings)
			. is_empty()
		),
		"A crossing cannot consume an upper route"
	)
	f = _fixture(true)
	f.buildings[1].room_records[0].private_cells.pop_back()
	assert_true(
		(
			WarrenSpatialFeatureSolver
			. _prospective_street_crossing_envelopes(f.grid, f.buildings)
			. is_empty()
		),
		"Both endpoints must contain a full room storey"
	)
