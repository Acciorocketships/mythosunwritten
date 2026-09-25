extends SceneTree

func _init() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var spatial := frozen.spatial(frozen.read("res://tests/fixtures/september11-floating-source.txt"),program)
	var body := {}
	for building: WarrenBuildingVolume in spatial.buildings:
		for room: WarrenRoomStamp in building.room_records:
			if (room.audit.get("bridge_support_room_ids",[]) as Array).size() != 2:
				for cell: Vector3i in room.private_cells: body[cell] = room.stable_id
	var grounded := WarrenSpatialFabricCompiler._ground_connected_mass(spatial,body)
	var rows: Array[Dictionary] = []
	for building: WarrenBuildingVolume in spatial.buildings:
		for room: WarrenRoomStamp in building.room_records:
			if not String(room.stable_id).begins_with("spatial.maze_bridge_end.00"): continue
			for cell: Vector3i in room.private_cells:
				if cell.y != room.lattice_origin.y: continue
				var gap := cell+Vector3i.DOWN
				rows.append({"room":room.stable_id,"cell":cell,"grounded":grounded.has(cell),
					"gap_use":spatial.grid.use_at(gap),"bits":spatial.grid.reservation_bits_at(gap),
					"below":body.get(gap+Vector3i.DOWN,"none"),"below_grounded":grounded.has(gap+Vector3i.DOWN)})
	FileAccess.open("res://docs/qa/2026-09-11-manual/08-skywalk/course-diagnostic.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	quit()
