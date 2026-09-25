extends SceneTree
const PLAN=preload("res://scripts/terrain/features/villages/fabric/FabricCompactRoofJunctionPlan.gd")
func _init()->void:
	var program:=SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var frozen:=preload("res://tests/fixtures/frozen_maze_source.gd")
	var source:="res://docs/qa/2026-09-13-manual/07-platform/current-source.txt"
	var output:="res://docs/qa/2026-09-13-manual/11-roof-joins/admitted-pairs.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--source="): source=arg.trim_prefix("--source=")
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	var spatial:=frozen.spatial(frozen.read(source),program)
	var rooms:Dictionary={}
	var cells:Dictionary={}
	for building:WarrenBuildingVolume in spatial.buildings:
		for room:WarrenRoomStamp in building.room_records:
			rooms[room.stable_id]=room
			for cell:Vector3i in room.private_cells: cells[cell]=room.stable_id
	var neighborhood:=WarrenSpatialFabricCompiler._spatial_roof_neighborhood(spatial,rooms,WarrenSpatialFabricCompiler._roof_faces_by_room(spatial,cells))
	var proposals:Array[Dictionary]=[]
	proposals.assign(neighborhood.proposal_by_room.values())
	var pairs:=PLAN.build(proposals)
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(pairs,"  "))
	print("COMPACT_PAIR_ADMISSION ",pairs)
	for unit: FabricUnit in spatial.compiled_fabric_cache().units:
		if ".valley." in String(unit.recipe_id): print("SELECTED_VALLEY ",unit.stable_id," ",unit.recipe_id)
	quit()
