extends "res://tests/harness/suntail/building_gallery.gd"
## Compare native hood courses on a real room under retained masonry.
func _run() -> void:
	get_root().size=Vector2i(1400,1000)
	for legacy in [true,false]:
		var width := 4 if OS.get_cmdline_user_args().has("--wide") else 2
		var kit := SuntailBuildingKit.create()
		if legacy:
			for role: StringName in [&"wallhood.middle",&"wallhood.left",&"wallhood.right"]:kit.roles.erase(role)
		var room := BuildingMass.new()
		room.stable_id=&"study.room"
		var floor := room.add_storey(0,BuildingMass.rect_cells(Rect2i(1,0,width,2)),BuildingMass.MATERIAL_TIMBER)
		floor.pent_colour=&"blue"
		floor.openings[BuildingMass.edge_key(Vector2i(1,0),3)]=BuildingMass.OPENING_DOOR
		var backing := BuildingMass.new()
		backing.stable_id=&"study.wall"
		var lower := BuildingMass.rect_cells(Rect2i(0,0,width+2,2))
		for cell:Vector2i in floor.cells:lower.erase(cell)
		backing.add_storey(0,lower,BuildingMass.MATERIAL_STONE)["retaining"]=true
		backing.add_storey(2,BuildingMass.rect_cells(Rect2i(0,0,width+2,2)),BuildingMass.MATERIAL_STONE)["retaining"]=true
		var a := BuildingKitAssembler.new(kit)
		a.external_blocked=func(cell:Vector2i,band:int)->bool:return backing.cells_at_band(band).has(cell)
		var parts := a.assemble(room)
		var wall_a := BuildingKitAssembler.new(kit)
		wall_a.external_blocked=func(cell:Vector2i,band:int)->bool:return room.cells_at_band(band).has(cell)
		parts.append_array(wall_a.assemble(backing))
		var payload := EnvironmentInstancePayload.new()
		BuildingKitAssembler.append_to_payload(parts,Transform3D.IDENTITY,payload)
		var stage := _stage()
		await _commit(stage,payload)
		var name := "legacy" if legacy else "shallow"
		await _shoot(stage,Vector3(width+10,7,-13),Vector3(width+2,2.5,0),name+"-front",50)
		await _shoot(stage,Vector3(width+2,2,-10),Vector3(width+2,2,0),name+"-street",65)
		stage.queue_free()
		await process_frame
	quit()
