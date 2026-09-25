extends SceneTree
func _init() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var spatial := frozen.spatial(frozen.read("res://tests/fixtures/september10-skywalk-source.txt"),program)
	var plan := spatial.compiled_fabric_cache()
	var world := Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE*2),Vector3(481.5,12.08,-2066.5))
	var report := {"units":[],"entries":[],"rooms":[]}
	for unit: FabricUnit in plan.units:
		var center := world * unit.transform().origin
		if center.distance_to(Vector3(490.6,20,-2090.7))<22:
			report.units.append({"id":str(unit.stable_id),"recipe":str(unit.recipe_id),"local":str(unit.transform()),"world":str(center)})
	for entry: Dictionary in plan.expanded_placements():
		var pose: Transform3D = world * entry.transform
		var box: AABB = pose * catalog.descriptor(entry.asset_id).measured_aabb
		if box.get_center().distance_to(Vector3(490.6,20,-2090.7))<40:
			report.entries.append({"id":str(entry.stable_id),"asset":str(entry.asset_id),"bounds":[box.position.x,box.position.y,box.position.z,box.end.x,box.end.y,box.end.z],"local":str(entry.transform)})
	for building: WarrenBuildingVolume in spatial.buildings:
		for room: WarrenRoomStamp in building.room_records:
			if (world * (Vector3(room.lattice_origin)*1.5)).distance_to(Vector3(490.6,20,-2090.7))<22:
				report.rooms.append({"id":str(room.stable_id),"kind":str(room.kind),"origin":str(room.lattice_origin),"cells":str(room.private_cells)})
	FileAccess.open("res://docs/qa/2026-09-10-manual/09-roofs/probe-candidate.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	quit()
