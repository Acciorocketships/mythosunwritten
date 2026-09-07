extends SceneTree
func _init() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var args := OS.get_cmdline_user_args()
	var cell := Vector2i(82,-205) if args.size()<2 else Vector2i(int(args[0]),int(args[1]))
	var seed_value := VillagePlan.warren_seed_for_cell(2697992464,cell)
	var profile := WarrenVillageScaleProfile.select(seed_value)
	var maze := WarrenMazeSitePlanner.plan(seed_value,{},profile)
	var volume := WarrenMazeVolumeAdapter.to_volume_plan(maze)
	var spatial := WarrenVolumetricSolver.from_volume(volume,-1,program,false)
	print("STRUCTURE spatial=", spatial != null," failure=",WarrenVolumetricSolver.last_failure)
	if spatial == null:
		quit(1)
		return
	for building: WarrenBuildingVolume in spatial.buildings:
		for room: WarrenRoomStamp in building.room_records:
			if String(room.stable_id).contains("house.025") or String(room.stable_id).contains("house.002"):
				print("STRUCTURE room=",room.stable_id," origin=",room.lattice_origin," recipe=",room.kind," terrain_bearing=",room.terrain_bearing," parent=",room.support_parent_parcel_id," flat=",room.flat_roof," addressed=",room.addressed," cells=",room.private_cells)
	var rooms: Array[WarrenRoomStamp] = []
	for building: WarrenBuildingVolume in spatial.buildings:
		rooms.append_array(building.room_records)
	for closure: Dictionary in WarrenSpatialFabricCompiler.required_roof_closure_options_for_rooms(spatial.grid,rooms,program,seed_value):
		if (closure.options as Array).is_empty():
			print("EMPTY CLOSURE ",closure)
	var owners: Dictionary = {}
	for room: WarrenRoomStamp in rooms:
		for cell_value: Vector3i in room.private_cells: owners[cell_value]=room.stable_id
	var faces := WarrenSpatialFabricCompiler._roof_faces_by_room(spatial,owners)
	for room: WarrenRoomStamp in rooms:
		if not String(room.stable_id).contains("house.025.part01"): continue
		print("ROOF FACES ",faces.get(room.stable_id)," full=",WarrenSpatialFabricCompiler._is_full_roof_plate(room,faces[room.stable_id])," air=",WarrenSpatialFabricCompiler._touches_public_air(spatial.grid,faces[room.stable_id]))
		var options := WarrenSpatialFabricCompiler._full_roof_candidates(room,seed_value)
		for id: StringName in WarrenSpatialFabricCompiler._terminal_tight_gable_recipe_ids(room,seed_value): options.append({"recipe_id":id,"yaw_offset":0})
		for option: Dictionary in options:
			var recipe := program.recipe(option.recipe_id)
			var yaw := posmod(room.yaw_quarters+int(option.yaw_offset),4)
			var origin := WarrenSpatialFabricCompiler._phase_aligned_full_roof_origin(room,recipe,yaw)
			var unit := FabricUnit.new(&"debug",recipe.recipe_id,origin,yaw)
			print("ROOF OPTION ",recipe.recipe_id," bounds=",unit.transform()*recipe.local_clearance_bounds," air=",WarrenSpatialFabricCompiler._unit_public_air_conflicts(spatial.grid,unit,recipe))
	var fabric := WarrenSpatialFabricCompiler.solve(spatial,program)
	print("STRUCTURE accepted=",fabric != null," reason=",WarrenSpatialFabricCompiler.last_failure)
	quit()
