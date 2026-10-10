extends RefCounted


static func build(projected: bool, width: int = 2) -> Dictionary:
	var kit := SuntailBuildingKit.create()
	var room := BuildingMass.new()
	room.stable_id = &"kit.fixture.wall-room"
	for band: int in [0, 2]:
		var st := room.add_storey(
			band, BuildingMass.rect_cells(Rect2i(1, 0, width, 2)), BuildingMass.MATERIAL_TIMBER
		)
		st.pent_colour = &"blue"
	room.storeys[0].openings[BuildingMass.edge_key(Vector2i(1, 0), 3)] = BuildingMass.OPENING_DOOR
	var wall := BuildingMass.new()
	wall.stable_id = &"kit.retained"
	for band: int in [0, 2, 4]:
		var cells := BuildingMass.rect_cells(Rect2i(0, 0, width + 2, 2))
		if band < 4:
			for cell: Vector2i in room.storeys[0].cells:
				cells.erase(cell)
		wall.add_storey(band, cells, BuildingMass.MATERIAL_STONE)["retaining"] = true
	var candidates: Array[Dictionary] = []
	if projected:
		var masses: Array[BuildingMass] = [room, wall]
		candidates = preload("res://scripts/terrain/features/villages/kit/KitRoomProjections.gd").fit(
			masses,
			{},
			kit,
			EnvironmentCatalog.load_default(),
			[],
			[],
			func(_own: StringName, cell: Vector2i, _band: int) -> bool: return cell.y >= 0,
			func(_own: StringName, cell: Vector2i, band: int) -> bool:
				return wall.cells_at_band(band).has(cell)
		)
	var assembler := BuildingKitAssembler.new(kit)
	assembler.external_blocked = func(cell: Vector2i, band: int) -> bool:
		return wall.cells_at_band(band).has(cell)
	var parts := assembler.assemble(room)
	var wall_assembler := BuildingKitAssembler.new(kit)
	wall_assembler.external_blocked = func(cell: Vector2i, band: int) -> bool:
		return room.cells_at_band(band).has(cell)
	parts.append_array(wall_assembler.assemble(wall))
	return {"kit": kit, "room": room, "wall": wall, "parts": parts, "projections": candidates}
