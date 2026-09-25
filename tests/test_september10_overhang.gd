extends GutTest
const Frozen = preload("res://tests/fixtures/frozen_maze_source.gd")

func test_photographed_entrance_does_not_stack_a_bay_on_a_room_cantilever() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := Frozen.spatial(Frozen.read("res://tests/fixtures/september10-stone-source.txt"),program)
	assert_not_null(spatial)
	if spatial == null: return
	var parent: WarrenRoomStamp
	for building: WarrenBuildingVolume in spatial.buildings:
		for room: WarrenRoomStamp in building.room_records:
			if room.stable_id == &"spatial.parcel.maze.house.006.part01.room00": parent=room
	assert_not_null(parent,"Keep the original upper room and its supported connection")
	if parent == null: return
	# The September 11 room-composition repair can replace this historical
	# two-cell jetty with a fully borne compact room. Its stable ID is not proof
	# that the former projecting east face still exists.
	assert_gt(parent.private_cells.size(),0)
	var offending := 0
	var bays := 0
	for feature: WarrenFeatureReservation in spatial.features:
		if feature.kind != &"facade_bay": continue
		bays += 1
		if feature.audit.annex_room_id == parent.stable_id:
			var facing: Vector3i = feature.audit.annex_endpoint_facing
			for cell: Vector3i in parent.private_cells:
				if cell.y != parent.lattice_origin.y or parent.private_cells.has(cell+facing):
					continue
				var below := cell+Vector3i.DOWN
				var actual_mass := spatial.grid.use_at(below) == WarrenSpatialGrid.Use.PRIVATE_VOLUME
				var actual_structure := spatial.grid.use_at(below) == WarrenSpatialGrid.Use.STRUCTURAL_VOLUME \
					and not bool(spatial.grid.reservation_bits_at(below)&WarrenSpatialGrid.Reservation.ROOF_CLEARANCE)
				offending += int(not actual_mass and not actual_structure)
	assert_eq(offending,0,"Every added bay edge must have immediate real lower bearing, even when the original room is recomposed")
	assert_gt(bays,0,"Supported facades may still receive complete native bays")

func test_bay_bearing_rejects_partial_edges_and_empty_roof_bands_in_four_orientations() -> void:
	for yaw in 4:
		var room := WarrenRoomStamp.new(&"room", &"source", &"slim",Vector3i(0,2,0),yaw,1,false,false,Vector3i(2147483647,2147483647,2147483647),Vector3i.ZERO,0,&"lower",0)
		room.add_private_cells(WarrenRoomStamp.expected_private_cells(&"slim",room.lattice_origin,yaw))
		var facing := FabricRecipe.transform_direction(Vector3i.BACK,yaw)
		var edge: Array[Vector3i] = []
		for cell: Vector3i in room.private_cells:
			if cell.y == 2 and not cell+facing in room.private_cells: edge.append(cell+Vector3i.DOWN)
		assert_eq(edge.size(),2)
		for condition in ["empty","half","mass","structure","roof"]:
			var grid := WarrenSpatialGrid.new(Vector3i(-8,-2,-8),Vector3i(17,12,17))
			var tx := grid.begin_transaction(&"bearing")
			var cells: Array[Vector3i] = edge.slice(0,1) if condition == "half" else edge
			if condition != "empty":
				assert_true(tx.assign_use(cells,WarrenSpatialGrid.Use.PRIVATE_VOLUME if condition in ["half","mass"] else WarrenSpatialGrid.Use.STRUCTURAL_VOLUME,&"bearing"))
				if condition == "roof": assert_true(tx.reserve(cells,WarrenSpatialGrid.Reservation.ROOF_CLEARANCE,&"bearing"))
				assert_true(tx.commit())
			assert_eq(WarrenSpatialFeatureSolver._room_face_has_lower_bearing(grid,room,facing),condition in ["mass","structure"],"Only complete real lower mass supports the bay face: %s yaw %d"%[condition,yaw])
