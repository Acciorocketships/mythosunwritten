extends SceneTree

func _init()->void:
	var frozen:=preload("res://tests/fixtures/frozen_maze_source.gd")
	var program:=SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial:=frozen.spatial(frozen.read("res://tests/fixtures/september7-manual-source.txt"),program)
	var fabric:=spatial.compiled_fabric_cache()
	var volume:=spatial.source_volume
	for transition:WarrenVolumeTransition in volume.transitions:
		print("TRANSITION ",transition.stable_id," ",WarrenTransitionSurfaceBuilder._span_endpoints(transition))
	var source:=volume.mass_context.get(&"maze_source_plan") as WarrenMazeSourcePlan
	print("ROUTE ",source.excavation.route)
	print("LANES ",source.excavation.lanes)
	print("SURFACE PATCHES")
	for patch:Dictionary in fabric.surface_plan.patches:
		for cell:Vector3i in patch.cells:
			if cell.y==5: print(patch.kind," ",cell)
	var solids:=fabric.transformed_cells(&"solid")
	var rooms:=fabric.transformed_cells(&"room_volume")
	var walks:=SettlementFabricAssembler.walked_floor_cells(fabric.surface_plan)
	for band in range(4,9):
		print("BAND ",band," x=-2..5 z=-2..6")
		for z in range(-2,7):
			var line:=""
			for x in range(-2,6):
				var cell:=Vector3i(x,band,z)
				line+="W" if walks.has(cell) else "R" if rooms.has(cell) else "S" if solids.has(cell) else "."
			print(z," ",line)
	for building:WarrenBuildingVolume in spatial.buildings:
		for room:WarrenRoomStamp in building.room_records:
			if room.lattice_origin.x in range(-1,5) and room.lattice_origin.z in range(-1,7):
				print("ROOM ",room.stable_id," origin=",room.lattice_origin," threshold=",room.threshold_cell," private=",room.private_cells)
	quit()
