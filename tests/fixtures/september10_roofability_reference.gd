extends RefCounted

static func count(rooms: Array[WarrenRoomStamp],
		occupied: Dictionary) -> int:
	var defects := 0
	for room: WarrenRoomStamp in rooms:
		var top_y := room.lattice_origin.y \
			+ WarrenSpatialGrid.STOREY_CELLS - 1
		var exposed: Dictionary = {}
		var upper_columns: Dictionary = {}
		for occupied_cell_value: Variant in occupied.keys():
			var occupied_cell := occupied_cell_value as Vector3i
			if occupied_cell.y == top_y + 1:
				upper_columns[Vector2i(occupied_cell.x, occupied_cell.z)] = true
		for cell: Vector3i in room.private_cells:
			if cell.y == top_y and not occupied.has(cell + Vector3i.UP):
				exposed[Vector2i(cell.x, cell.z)] = true
		for component: Dictionary in WarrenRoomCompositionPlanner \
				._column_components(exposed):
			defects += int(not WarrenRoomCompositionPlanner \
				._shoulder_component_is_roofable(component, upper_columns, top_y))
	return defects

