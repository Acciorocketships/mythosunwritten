extends GutTest
const FIXTURE := preload("res://tests/fixtures/wall_front_projection.gd")
const PROJECTION := preload("res://scripts/terrain/features/villages/kit/KitRoomProjections.gd")


func test_upper_front_is_a_closed_supported_room_extension() -> void:
	var f := FIXTURE.build(true)
	assert_eq(f.projections.size(), 1)
	var upper: Dictionary = f.room.storeys[1]
	var slots := BuildingKitAssembler.storey_slots(upper)
	for slot: Dictionary in slots:
		if slot.dir == 3:
			assert_almost_eq(float(slot.centre.y), -.325, .00001)
		else:
			assert_eq(
				float(slot.wall_offset), 0.0, "Other room faces stay on their original boundaries"
			)
	assert_false(
		f.room.storeys[0].has("wall_offsets"), "The lower door and its street keep their position"
	)
	var catalog := EnvironmentCatalog.load_default()
	var floors := 0
	var returns := 0
	var brackets := 0
	for part: Dictionary in f.parts:
		var box: AABB = part.transform * catalog.descriptor(part.asset_id).measured_aabb
		if part.role == &"frontage.floor":
			floors += 1
			assert_almost_eq(box.position.z, -.65, .0001)
			assert_almost_eq(
				box.end.z, 0.0, .0001, "Floor and ceiling meet the original room without a slot"
			)
			assert_true(catalog.descriptor(part.asset_id).collision_piece_count > 0)
		if part.role == &"frontage.return":
			returns += 1
			assert_almost_eq(box.position.z, -.65, .0001)
			assert_almost_eq(box.end.z, 0.0, .0001)
			assert_almost_eq(box.position.y, 3.0, .0001)
			assert_almost_eq(box.end.y, 6.0, .0001)
		if part.role == &"bracket.small":
			brackets += 1
	assert_eq(floors, 4, "Two native floor strips and two native ceiling strips")
	assert_eq(returns, 2, "Both side returns are closed")
	assert_eq(brackets, 3, "Brackets bear on the lower wall's module joints")


func test_new_front_yields_whole_to_an_upper_route() -> void:
	var f := FIXTURE.build(false)
	var air := (
		preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd")
		. box_volume(AABB(Vector3(2, 3, -.7), Vector3(4, 3, .7)))
	)
	air["open"] = true
	var masses: Array[BuildingMass] = [f.room, f.wall]
	var result := PROJECTION.fit(
		masses,
		{},
		f.kit,
		EnvironmentCatalog.load_default(),
		[air],
		[],
		func(_own: StringName, cell: Vector2i, _band: int) -> bool: return cell.y >= 0,
		func(_own: StringName, cell: Vector2i, band: int) -> bool:
			return f.wall.cells_at_band(band).has(cell)
	)
	assert_true(result.is_empty())
	assert_false(
		f.room.storeys[1].has("wall_offsets"), "Refusal leaves the complete original facade"
	)


func test_long_front_keeps_recessed_shoulders() -> void:
	var f := FIXTURE.build(true, 6)
	assert_eq(f.projections.size(), 1)
	var front: Dictionary = f.room.storeys[1].projections[0]
	assert_between(front.edges.size(), 2, 3)
	for edge: Vector3i in front.edges:
		assert_between(
			edge.x, 2, 5, "The original six-bay front keeps a flush shoulder at each end"
		)


func test_neighboring_upper_room_rejects_the_extension_without_cutting_it() -> void:
	var f := FIXTURE.build(false)
	var neighbor := BuildingMass.new()
	neighbor.stable_id = &"kit.neighbor"
	neighbor.add_storey(
		2, BuildingMass.rect_cells(Rect2i(1, -1, 2, 1)), BuildingMass.MATERIAL_TIMBER
	)
	var masses: Array[BuildingMass] = [f.room, f.wall, neighbor]
	var result := PROJECTION.fit(
		masses,
		{},
		f.kit,
		EnvironmentCatalog.load_default(),
		[],
		[],
		func(_own: StringName, cell: Vector2i, _band: int) -> bool: return cell.y >= 0,
		func(_own: StringName, cell: Vector2i, band: int) -> bool:
			return f.wall.cells_at_band(band).has(cell)
	)
	assert_true(result.is_empty())
	assert_false(f.room.storeys[1].has("wall_offsets"))
	assert_eq(neighbor.storeys[0].cells.size(), 2)


func test_generated_fronts_preserve_room_bearing_and_public_air() -> void:
	var kit := SuntailBuildingKit.create()
	var c := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(c)
	var total := 0
	for seed_value: int in [13, 58, 67]:
		var spatial := WarrenVolumetricSolver.generate(
			seed_value, {}, program, WarrenVillageScaleProfile.for_id(&"large")
		)
		assert_not_null(spatial, WarrenVolumetricSolver.last_failure)
		if spatial == null:
			continue
		var fabric := spatial.compiled_fabric_cache()
		var built := KitVillageBuildings.build(spatial, fabric, kit)
		assert_true(built.payload.validate())
		assert_eq(int(KitFloatingMassAudit.audit(spatial, fabric, built.masses).count), 0)
		var air := (
			preload("res://scripts/terrain/features/villages/kit/KitPublicClearance.gd")
			. build(spatial, fabric, kit)
		)
		for projection: Dictionary in built.room_projections:
			total += 1
			assert_false(
				(
					preload("res://scripts/terrain/features/villages/kit/KitPublicClearance.gd")
					. intersects_air(projection.envelope, Transform3D.IDENTITY, air)
				)
			)
		assert_eq(
			int(
				(
					preload("res://tests/fixtures/kit_roof_public_air_audit.gd")
					. audit(built, kit)
					. intrusions
				)
			),
			0
		)
	assert_gt(
		total,
		0,
		"Real generated towns, not just a staged fixture, must gain an inhabited projection"
	)


func test_ordinary_tall_house_gets_one_closed_middle_storey_bay() -> void:
	var f := FIXTURE.build(false)
	f.room.stable_id = &"kit.fixture.house"
	f.room.add_storey(4, f.room.storeys[0].cells.duplicate(), BuildingMass.MATERIAL_TIMBER)
	f.room.storeys[1].default_opening = BuildingMass.OPENING_PLAIN
	var masses: Array[BuildingMass] = [f.room]
	var projections := PROJECTION.fit(
		masses,
		{&"fixture.house": f.kit},
		f.kit,
		EnvironmentCatalog.load_default(),
		[],
		[],
		func(_own: StringName, cell: Vector2i, _band: int) -> bool: return cell.y >= 0,
		func(_own: StringName, _cell: Vector2i, _band: int) -> bool: return false
	)
	assert_eq(projections.size(), 1, "An ordinary house is eligible without a wall-room name")
	if projections.size() != 1:
		return
	assert_eq(projections[0].band, 2, "Bearing below and an upper room close the middle bay")
	assert_false(f.room.storeys[0].has("wall_offsets"))
	assert_false(f.room.storeys[2].has("wall_offsets"), "No exposed flat cap on the top floor")
	for edge: Vector3i in f.room.storeys[1].projections[0].edges:
		assert_eq(f.room.storeys[1].openings[edge], BuildingMass.OPENING_WINDOW, "Projecting fronts keep a window in each bay")
	var parts := BuildingKitAssembler.new(f.kit).assemble(f.room)
	assert_eq(
		parts.filter(func(p: Dictionary) -> bool: return p.role == &"frontage.return").size(), 2
	)
	assert_eq(
		parts.filter(func(p: Dictionary) -> bool: return p.role == &"frontage.floor").size(), 4
	)
	assert_eq(
		parts.filter(func(p: Dictionary) -> bool: return p.role == &"bracket.small").size(), 3
	)


func test_projecting_room_respects_its_own_lower_wing_roof() -> void:
	var f := FIXTURE.build(false)
	f.room.stable_id = &"kit.fixture.house"
	f.room.add_storey(4, f.room.storeys[0].cells.duplicate(), BuildingMass.MATERIAL_TIMBER)
	var wing := Rect2i(1, -2, 2, 2)
	f.room.storeys[0].cells.merge(BuildingMass.rect_cells(wing))
	f.room.add_roof(wing, 0, 2, &"blue")
	var masses: Array[BuildingMass] = [f.room]
	var projections := PROJECTION.fit(
		masses,
		{&"fixture.house": f.kit},
		f.kit,
		EnvironmentCatalog.load_default(),
		[],
		[],
		func(_own: StringName, cell: Vector2i, _band: int) -> bool: return cell.y >= 0,
		func(_own: StringName, _cell: Vector2i, _band: int) -> bool: return false
	)
	assert_true(projections.is_empty(), "A lower roof of the same house is still a real obstacle")
	assert_false(f.room.storeys[1].has("wall_offsets"))

func test_frontage_can_use_clear_bays_beside_a_door() -> void:
	var f := FIXTURE.build(false,4)
	var edge := Vector3i(1,0,3)
	f.room.storeys[1].openings[edge] = BuildingMass.OPENING_DOOR
	var masses: Array[BuildingMass] = [f.room,f.wall]
	var projections := PROJECTION.fit(masses,{},f.kit,EnvironmentCatalog.load_default(),[],[],
		func(_own:StringName,cell:Vector2i,_band:int)->bool:return cell.y>=0,
		func(_own:StringName,cell:Vector2i,band:int)->bool:return f.wall.cells_at_band(band).has(cell))
	assert_eq(projections.size(),1,"A door at one end must not prevent a clear smaller projecting room")
	assert_eq(f.room.storeys[1].openings[edge],BuildingMass.OPENING_DOOR)
	if projections.is_empty():return
	var projection:Dictionary=f.room.storeys[1].projections[0]
	assert_false(projection.edges.has(edge))
	assert_gte(projection.edges.size(),2)


func test_tall_house_relief_reaches_two_distinct_faces_without_repeated_stacks() -> void:
	var kit := SuntailBuildingKit.create()
	var house := BuildingMass.new()
	house.stable_id = &"kit.tall.fixture"
	for band in [0,2,4,6,8]:
		house.add_storey(band,BuildingMass.rect_cells(Rect2i(0,0,4,4)),BuildingMass.MATERIAL_TIMBER)
	var masses: Array[BuildingMass] = [house]
	var projections := PROJECTION.fit(masses,{&"tall.fixture":kit},kit,EnvironmentCatalog.load_default(),[],[],
		func(_own:StringName,_cell:Vector2i,_band:int)->bool:return false,
		func(_own:StringName,_cell:Vector2i,_band:int)->bool:return false)
	assert_eq(projections.size(),2,"A tall house can relieve a second face rather than spending all relief on one facade")
	if projections.size()!=2:return
	assert_ne(projections[0].dir,projections[1].dir,"Do not recreate a repeated vertical apartment grid")
	assert_false((projections[0].envelope as AABB).intersects(projections[1].envelope),"Complete supported projections stay disjoint")
	assert_false(house.storeys[0].has("wall_offsets"),"Ground entrances remain flush")
	assert_false(house.storeys[-1].has("wall_offsets"),"The top floor cannot acquire an uncapped projection")
