extends GutTest


func test_built_back_room_keeps_its_host_identity_for_a_supported_cover() -> void:
	var grid := WarrenSpatialGrid.new(Vector3i(-4, 0, -4), Vector3i(10, 8, 10))
	var stone: Array[Vector3i] = []
	for macro: Vector2i in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT]:
		for band in [1, 2, 3]:
			stone.append_array(
				WarrenVolumetricSolver._fine_square(Vector3i(macro.x, band, macro.y))
			)
	var transaction := grid.begin_transaction(&"bearing")
	transaction.assign_use(stone, WarrenSpatialGrid.Use.STRUCTURAL_VOLUME, &"bearing")
	assert_true(grid.commit_transaction(transaction))
	var room := WarrenRoomStamp.new(
		&"back.room", &"maze.back.21", &"tower", Vector3i(2, 4, 0), 0, 0, true, false
	)
	room.audit["back_room_parcel_id"] = &"parcel.house"
	var building := WarrenBuildingVolume.new(&"back", 4)
	building.room_records.append(room)
	var record := {
		"crown": 2,
		"floor": 4,
		"jambs": [Vector2i.LEFT, Vector2i.RIGHT],
		"parcel_id": &"parcel.house"
	}
	var columns: Array[Vector2i] = [Vector2i.ZERO]
	var owners := {Vector3i(2, 4, 0): &"back"}
	assert_true(
		WarrenVolumetricSolver._over_passage_is_borne(
			grid, record, columns, 4, {&"back": building}, owners
		),
		"A constructed back room belongs to the original house"
	)
	room.audit["back_room_parcel_id"] = &"parcel.other"
	assert_false(
		WarrenVolumetricSolver._over_passage_is_borne(
			grid, record, columns, 4, {&"back": building}, owners
		),
		"An unrelated neighboring room is not the host"
	)
	room.audit["back_room_parcel_id"] = &"parcel.house"
	assert_false(
		WarrenVolumetricSolver._over_passage_is_borne(
			grid, record, columns, 4, {&"back": building}, {}
		),
		"Identity alone cannot invent an adjacent occupied room"
	)


func test_recovered_covers_do_not_displace_an_independent_street_skywalk() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := WarrenVolumetricSolver.generate(
		31, {}, program, WarrenVillageScaleProfile.for_id(&"large")
	)
	assert_not_null(spatial, WarrenVolumetricSolver.last_failure)
	if spatial == null:
		return
	var private_cells := WarrenVolumetricSolver.building_private_cells(spatial.buildings)
	for column: Vector2i in [Vector2i(2, 0), Vector2i(2, 1)]:
		var room_cells := 0
		for cell: Vector3i in WarrenVolumetricSolver._fine_square(Vector3i(column.x, 8, column.y)):
			room_cells += int(private_cells.has(cell))
		assert_eq(
			room_cells,
			4,
			"The original host's back room must continue wholly over the planned bore"
		)
	var spans := SettlementFabricAssembler.maze_skywalk_spans(spatial.compiled_fabric_cache())
	var retained := false
	for span: Dictionary in spans:
		if span.cell == Vector3i(-3, 4, 4) and span.step == Vector3i.RIGHT and bool(span.enclosed):
			retained = true
	assert_true(
		retained, "A newly possible upper bridge must not spend the old street crossing's quota"
	)


func test_skywalks_do_not_cross_the_native_tunnel_crown_skin() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := WarrenVolumetricSolver.generate(
		8, {}, program, WarrenVillageScaleProfile.for_id(&"grand")
	)
	assert_not_null(spatial, WarrenVolumetricSolver.last_failure)
	if spatial == null:
		return
	var built := KitVillageBuildings.build(
		spatial, spatial.compiled_fabric_cache(), SuntailBuildingKit.create()
	)
	var native_crowns := {}
	for mass: BuildingMass in built.masses:
		if mass.stable_id != &"kit.tunnel-ceilings":
			continue
		for floor: Dictionary in mass.storeys:
			for column: Vector2i in floor.cells:
				for rise in int(floor.get("bands", 2)):
					native_crowns[Vector3i(column.x, int(floor.floor_band) + rise, column.y)] = true
	assert_false(native_crowns.is_empty(), "The fixture must include real native tunnel ceilings")
	assert_eq(
		native_crowns.size(),
		spatial.compiled_fabric_cache().passage_crown_cells.size(),
		"Compiler occupancy and native crown construction must agree"
	)
	var intersections: Array[Vector3i] = []
	for span: Dictionary in SettlementFabricAssembler.maze_skywalk_spans(
		spatial.compiled_fabric_cache()
	):
		for lane: Vector3i in SettlementFabricAssembler._skywalk_candidate_lanes(span):
			for offset in range(1, int(span.gap) + 1):
				for rise in range(3):
					var cell: Vector3i = (
						lane + (span.step as Vector3i) * offset + Vector3i.UP * rise
					)
					if native_crowns.has(cell):
						intersections.append(cell)
	assert_eq(
		intersections,
		[] as Array[Vector3i],
		"A native stone tunnel ceiling remains solid even if the legacy roof adapter hid its occupancy"
	)
