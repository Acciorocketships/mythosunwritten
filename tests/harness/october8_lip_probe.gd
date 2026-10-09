extends RefCounted
func run(review:Node)->void:
	var water:WaterFieldContext=review._inputs[Vector2i(0,5)].water
	var rows:Array=[]
	for z in range(2080,2131):
		var p:=Vector2(120,z*.5)
		var query:=PhysicsRayQueryParameters3D.create(Vector3(p.x,400,p.y),Vector3(p.x,-100,p.y))
		var hit:Dictionary=review._camera.get_world_3d().direct_space_state.intersect_ray(query)
		rows.append({"x":p.x,"z":p.y,"ground":TerrainTileField.surface_y(water._region,p.x,p.y),"water":WaterField.level_at(water._ctx,p),"rendered":hit.position.y if not hit.is_empty() else null})
	FileAccess.open(review._output_dir+"/lip-section.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	var region:HeightfieldRegion=water._region
	FileAccess.open("/tmp/oct8-lip-fixture.var",FileAccess.WRITE).store_var({"storeys":region._storeys,"levels":region._levels,"carved":region._carved,"native":region.native_control_heights,"water":water._ctx.fill,"base":water._ctx.fill_base})
	print("LIP_SECTION done")
