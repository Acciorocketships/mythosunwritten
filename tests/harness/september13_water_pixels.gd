extends SceneTree
func _init()->void: _run.call_deferred()
func _run()->void:
	root.size=Vector2i(1280,800)
	var id:="P12"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--spot="): id=arg.trim_prefix("--spot=")
	var folder:="res://docs/qa/2026-09-13-manual/22-water/diagnostic-before/"+id
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder+"/audit.json"))
	var scene:Node3D=(load(folder+"/geometry.scn") as PackedScene).instantiate()
	root.add_child(scene)
	var camera:=Camera3D.new()
	root.add_child(camera)
	camera.fov=75
	var feet:=Vector3(data.spot.player[0],data.spot.player[1],data.spot.player[2])
	var cross:=Vector3(data.spot.crosshair[0],data.spot.crosshair[1],data.spot.crosshair[2])
	var target:=feet+Vector3.UP*CameraMouseView.PIVOT_HEIGHT
	var backward:=(target-cross).normalized()
	camera.position=ReviewCam.solve_cam(feet,cross,Vector2(backward.x,backward.z).length()*CameraMouseView.BOOM_LENGTH,
		CameraMouseView.PIVOT_HEIGHT+backward.y*CameraMouseView.BOOM_LENGTH,CameraMouseView.PIVOT_HEIGHT)
	camera.look_at(target)
	await physics_frame
	await physics_frame
	var water:=TerrainWorldTuning.make_water(2697992464)
	var fields:=WorldFieldBlockCache.new(TerrainWorldTuning.make_heightfield(2697992464,water),water,26,0,64)
	var rows:=[]
	var pixels:Array=[Vector2(500,312),Vector2(500,316),Vector2(540,302),Vector2(470,301),Vector2(400,285)] if id=="P12" else [Vector2(578,384),Vector2(600,400),Vector2(650,400),Vector2(560,420)]
	for pixel:Vector2 in pixels:
		var dir:=camera.project_ray_normal(pixel)
		var best:=INF
		var record:Dictionary={"pixel":str(pixel)}
		for node:MeshInstance3D in scene.find_children("*","MeshInstance3D",true,false):
			if not node.is_in_group("tactical_preserve_surface"): continue
			var arrays:=node.mesh.surface_get_arrays(0)
			var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			for i in range(0,indices.size(),3):
				var a:=node.global_transform*vertices[indices[i]]
				var b:=node.global_transform*vertices[indices[i+1]]
				var c:=node.global_transform*vertices[indices[i+2]]
				var hit:Variant=Geometry3D.ray_intersects_triangle(camera.position,dir,a,b,c)
				if hit==null or camera.position.distance_to(hit)>=best:continue
				best=camera.position.distance_to(hit)
				record={"pixel":str(pixel),"hit":hit,"triangle":[a,b,c]}
		if record.has("hit"):
			record["samples"]=[]
			for q:Vector3 in [record.hit]+record.triangle:
				var p:=Vector2(q.x,q.z)
				var field:=fields.water_at(p)
				record.samples.append({"point":str(q),"ground":TerrainSurfaceField.surface_y(field._region,p.x,p.y),"raw_water":str(WaterField.level_at(field._ctx,p)),"wet_water":str(field.level_at(p))})
		print("WATER_PIXEL ",JSON.stringify(record))
		rows.append(record)
	FileAccess.open(folder+"/pixels.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	quit()
