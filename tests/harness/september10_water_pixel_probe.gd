extends SceneTree
func _init()->void:
	_run.call_deferred()
func _run()->void:
	root.size=Vector2i(1718,1034)
	var stage:=Node3D.new();root.add_child(stage)
	var camera:=Camera3D.new();stage.add_child(camera);camera.fov=75;camera.current=true
	var water:=TerrainWorldTuning.make_water(2697992464)
	var plan:=TerrainWorldTuning.make_heightfield(2697992464,water)
	var fields:=WorldFieldBlockCache.new(plan,water,0,0,64)
	var result:=[]
	for spec in [["15",Vector3(892.5,8.6,-1828.3),Vector3(892.8,8.9,-1828.6),Vector2i(4,-10),[Vector2(150,360),Vector2(300,350),Vector2(450,350),Vector2(1200,210)]],
			["16",Vector3(678.8,12.6,-1744.2),Vector3(678.6,12.9,-1744.5),Vector2i(3,-9),[Vector2(760,90),Vector2(950,135),Vector2(1050,160),Vector2(1400,180)]]]:
		var field:=fields.water(spec[3]);var ctx:=field.raw_context()
		var mesh:=WaterSkin.build(water,spec[3],ctx.region,field)
		var verts:PackedVector3Array=mesh.arrays[Mesh.ARRAY_VERTEX]
		var indices:PackedInt32Array=mesh.arrays[Mesh.ARRAY_INDEX]
		camera.position=ReviewCam.solve_cam(spec[1],spec[2]);camera.look_at(spec[1]);camera.force_update_transform()
		await process_frame
		for pixel:Vector2 in spec[4]:
			var direction:=camera.project_ray_normal(pixel)
			var best:=INF;var found:Dictionary={}
			for i in range(0,indices.size(),3):
				var a:=verts[indices[i]];var b:=verts[indices[i+1]];var c:=verts[indices[i+2]]
				var hit:Variant=Geometry3D.ray_intersects_triangle(camera.position,direction,a,b,c)
				if hit==null or camera.position.distance_to(hit)>=best:continue
				best=camera.position.distance_to(hit)
				found={"photo":spec[0],"pixel":str(pixel),"point":str(hit),"triangle":[str(a),str(b),str(c)],"samples":[]}
				for p:Vector3 in [hit,a,b,c]:found.samples.append({"point":str(p),"ground":TerrainTileField.surface_y(ctx.region,p.x,p.z),"water":str(WaterField.level_at(ctx,Vector2(p.x,p.z)))})
			result.append(found)
			print("WATER_PIXEL ",JSON.stringify(found))
	FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	quit()
