extends SceneTree

func _init() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var spatial := frozen.spatial(frozen.read("res://tests/fixtures/september9-thin-turf-source.txt"),program)
	var report := {"cells":[],"roofs":[],"rooms":[],"audit":spatial.compiled_fabric_cache().audit}
	for y in range(1,6):
		for z in range(-1,3):
			for x in range(1,5):
				var cell := Vector3i(x,y,z)
				report.cells.append({"cell":str(cell),"use":WarrenSpatialGrid.Use.keys()[spatial.grid.use_at(cell)],"owner":str(spatial.grid.owner_name_at(cell)),"reservations":spatial.grid.reservation_bits_at(cell),"floor_claim":spatial.grid.face_claim(cell,Vector3i.DOWN)})
	for building: WarrenBuildingVolume in spatial.buildings:
		for room: WarrenRoomStamp in building.room_records:
			report.rooms.append({"id":str(room.stable_id),"kind":str(room.kind),"origin":str(room.lattice_origin),"cells":str(room.private_cells)})
	for unit: FabricUnit in spatial.compiled_fabric_cache().units:
		if String(unit.recipe_id).begins_with("roof."):
			report.roofs.append({"id":str(unit.stable_id),"recipe":str(unit.recipe_id),"origin":str(unit.lattice_origin)})
	FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("ROOF_PROBE_COMPLETE")
	quit()
