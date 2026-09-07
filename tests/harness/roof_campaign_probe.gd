extends SceneTree
func _init() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var seed_value := VillagePlan.warren_seed_for_cell(2697992464,Vector2i(-10,-9))
	var maze := WarrenMazeSitePlanner.plan(seed_value,{},WarrenVillageScaleProfile.select(seed_value))
	var volume := WarrenMazeVolumeAdapter.to_volume_plan(maze)
	var spatial := WarrenVolumetricSolver.from_volume(volume,-1,program,false)
	var rooms: Array[WarrenRoomStamp] = []
	var target: WarrenRoomStamp
	for building: WarrenBuildingVolume in spatial.buildings:
		for room: WarrenRoomStamp in building.room_records:
			rooms.append(room)
			if String(room.stable_id).contains("house.015.part01"): target=room
	var closures := WarrenSpatialFabricCompiler.required_roof_closure_options_for_rooms(spatial.grid,rooms,program,seed_value)
	for closure: Dictionary in closures:
		if not String(closure.owner_room_id).contains("maze_bridge_end.01.00.room01"): continue
		print("CLOSURE ",closure)
		for id: StringName in [&"roof.tower.blue",&"roof.terminal.tight.tower.blue"]:
			var recipe := program.recipe(id)
			var origin := WarrenSpatialFabricCompiler._phase_aligned_full_roof_origin(target,recipe,target.yaw_quarters)
			var candidate := FabricUnit.new(&"candidate",id,origin,target.yaw_quarters)
			for option: Dictionary in closure.options:
				var other_recipe := program.recipe(option.recipe_id)
				var other := FabricUnit.new(&"future",option.recipe_id,option.origin,option.yaw_quarters,[],[],&"",[&"candidate"])
				print("PAIR ",id," target=",target.lattice_origin," yaw=",target.yaw_quarters," semantic=",WarrenSpatialFabricCompiler._future_unit_semantic_conflict(candidate,recipe,other,other_recipe)," bounds=",candidate.transform()*recipe.local_clearance_bounds," other=",option.bounds," measured=",SettlementFabricPlan.new(&"probe")._connected_roof_seam_is_measured(candidate,recipe,candidate.transform()*recipe.local_clearance_bounds,other,other_recipe,option.bounds))
	quit()
