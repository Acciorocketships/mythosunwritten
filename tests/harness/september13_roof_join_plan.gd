extends SceneTree
func _init() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var source:="res://docs/qa/2026-09-13-manual/07-platform/current-source.txt"
	var args := OS.get_cmdline_user_args()
	if "--source" in args: source=args[args.find("--source")+1]
	var spatial := frozen.spatial(frozen.read(source),program)
	var room_by_id := {}
	var room_by_cell := {}
	for building: WarrenBuildingVolume in spatial.buildings:
		for room: WarrenRoomStamp in building.room_records:
			room_by_id[room.stable_id] = room
			for cell: Vector3i in room.private_cells: room_by_cell[cell] = room.stable_id
	var neighborhood := WarrenSpatialFabricCompiler._spatial_roof_neighborhood(spatial,room_by_id,WarrenSpatialFabricCompiler._roof_faces_by_room(spatial,room_by_cell))
	var proposals: Array[Dictionary] = []
	proposals.assign(neighborhood.proposal_by_room.values())
	var topology := FabricRoofTopologyPlan.build(proposals)
	var result := {"topology":topology.facts,"neighborhood":neighborhood,"rooms":[],"units":[],"audit":spatial.compiled_fabric_cache().audit}
	for building: WarrenBuildingVolume in spatial.buildings:
		for room: WarrenRoomStamp in building.room_records:
			result.rooms.append({"id":room.stable_id,"origin":str(room.lattice_origin),"kind":room.kind,"yaw":room.yaw_quarters,"private":str(room.private_cells),"audit":room.audit})
	for unit: FabricUnit in spatial.compiled_fabric_cache().units:
		if "roof" in String(unit.stable_id):
			result.units.append({"id":unit.stable_id,"recipe":unit.recipe_id,"origin":str(unit.lattice_origin),"yaw":unit.yaw_quarters})
	var output := "res://docs/qa/2026-09-13-manual/11-roof-joins/plan.json"
	if "--output" in args: output=args[args.find("--output")+1]
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	quit()
