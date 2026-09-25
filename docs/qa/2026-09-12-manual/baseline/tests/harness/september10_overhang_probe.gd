extends SceneTree
func _init() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var spatial := WarrenVolumetricSolver.solve(6357506428441529412,{},program,WarrenVillageScaleProfile.for_id(WarrenVillageScaleProfile.STANDARD)) if "--review-seed" in OS.get_cmdline_user_args() else frozen.spatial(frozen.read("res://tests/fixtures/september10-stone-source.txt"),program)
	for feature: WarrenFeatureReservation in spatial.features:
		if feature.kind == &"facade_bay": print("BAY ",feature.stable_id," ",feature.audit," records ",feature.construction_records)
	for feature: WarrenFeatureReservation in spatial.features:
		if feature.kind != &"facade_bay": continue
		for building: WarrenBuildingVolume in spatial.buildings:
			for room: WarrenRoomStamp in building.room_records:
				if room.stable_id != feature.audit.annex_room_id: continue
				var missing := []
				for cell: Vector3i in room.private_cells:
					if cell.y != room.lattice_origin.y or cell + (feature.audit.annex_endpoint_facing as Vector3i) in room.private_cells: continue
					if spatial.grid.use_at(cell+Vector3i.DOWN) not in [4,5]: missing.append(cell)
				print("BAY_UNBORNE_EDGE ",feature.stable_id," ",missing)
	for building: WarrenBuildingVolume in spatial.buildings:
		for room: WarrenRoomStamp in building.room_records:
			if String(room.source_parcel_id).contains("house.006"):
				print("ROOM ",room.stable_id," origin ",room.lattice_origin," yaw ",room.yaw_quarters," audit ",room.audit," cells ",room.private_cells)
	for x in range(4,10):
		for z in range(1,4):
			print("BELOW ",Vector3i(x,1,z)," ",spatial.grid.use_at(Vector3i(x,1,z)))
	quit()
