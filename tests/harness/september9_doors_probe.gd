extends SceneTree
func _init() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var spatial := frozen.spatial(frozen.read("res://tests/fixtures/september9-east-source.txt"),program)
	var fabric := spatial.compiled_fabric_cache()
	var report := {"rooms":[],"entrances":fabric.surface_plan.entrance_records,"units":[]}
	for building: WarrenBuildingVolume in spatial.buildings:
		for room: WarrenRoomStamp in building.room_records:
			report.rooms.append({"building":str(building.stable_id),"id":str(room.stable_id),
				"origin":str(room.lattice_origin),"kind":str(room.kind),"yaw":room.yaw_quarters,
				"addressed":room.addressed,"threshold":str(room.threshold_cell),
				"frontage":str(room.frontage_direction),"private_cells":room.private_cells.map(func(c:Vector3i)->String:return str(c))})
	for unit: FabricUnit in fabric.units:
		if String(unit.stable_id).contains(".room"):
			report.units.append({"id":str(unit.stable_id),"recipe":str(unit.recipe_id),
				"suppressed":unit.suppressed_placement_ids})
	report["panels"] = []
	for entry: Dictionary in fabric.expanded_placements():
		if not String(entry.asset_id).begins_with("sfv.fabric.wall.") and not String(entry.stable_id).begins_with("facade-run-joint/"): continue
		var box: AABB = entry.bounds
		if absf(box.position.y-6.0)>0.06 or box.end.z < -6.0 or box.position.z > -3.5: continue
		report.panels.append({"id":str(entry.stable_id),"asset":str(entry.asset_id),"bounds":str(box),"transform":str(entry.transform)})
	FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	quit()
