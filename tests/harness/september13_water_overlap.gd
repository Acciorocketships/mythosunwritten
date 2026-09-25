extends SceneTree
func _init()->void:_run.call_deferred()
func _run()->void:
	root.size=Vector2i(1280,800)
	var folder:="res://docs/qa/2026-09-13-manual/22-water/diagnostic-before/P39"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--source="):folder=arg.trim_prefix("--source=")
	var scene:Node3D=(load(folder+"/geometry.scn") as PackedScene).instantiate()
	root.add_child(scene)
	var camera:=Camera3D.new();root.add_child(camera);camera.fov=75
	var feet:=Vector3(829.8,16,341.5);var cross:=Vector3(830.4,16,346.4)
	var target:=feet+Vector3.UP*CameraMouseView.PIVOT_HEIGHT
	var backward:=(target-cross).normalized()
	camera.position=ReviewCam.solve_cam(feet,cross,Vector2(backward.x,backward.z).length()*CameraMouseView.BOOM_LENGTH,
		CameraMouseView.PIVOT_HEIGHT+backward.y*CameraMouseView.BOOM_LENGTH,CameraMouseView.PIVOT_HEIGHT)
	camera.look_at(target)
	await process_frame
	var rows:=[]
	for pixel:Vector2 in [Vector2(480,369),Vector2(515,372),Vector2(578,384),Vector2(600,400),Vector2(618,394),Vector2(640,420),Vector2(590,410)]:
		var dir:=camera.project_ray_normal(pixel)
		var nearest:Dictionary={}
		for node:MeshInstance3D in scene.find_children("*","MeshInstance3D",true,false):
			var role:="water" if node.is_in_group("tactical_preserve_surface") else "terrain"
			for surface in node.mesh.get_surface_count():
				var arrays:=node.mesh.surface_get_arrays(surface)
				var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
				if role=="water" and "--trough" in OS.get_cmdline_user_args():
					vertices=vertices.duplicate()
					for vi in vertices.size():vertices[vi]-=arrays[Mesh.ARRAY_NORMAL][vi]*arrays[Mesh.ARRAY_COLOR][vi].r*1.4
				var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
				if indices.is_empty():
					indices.resize(vertices.size());for i in indices.size():indices[i]=i
				for i in range(0,indices.size(),3):
					var a:=node.global_transform*vertices[indices[i]];var b:=node.global_transform*vertices[indices[i+1]];var c:=node.global_transform*vertices[indices[i+2]]
					var hit:Variant=Geometry3D.ray_intersects_triangle(camera.position,dir,a,b,c)
					if hit==null:continue
					var distance:=camera.position.distance_to(hit)
					if nearest.has(role) and distance>=nearest[role].distance:continue
					nearest[role]={"distance":distance,"hit":str(hit),"triangle":[str(a),str(b),str(c)]}
		for node:MultiMeshInstance3D in scene.find_children("*","MultiMeshInstance3D",true,false):
			var mm:=node.multimesh
			for instance in mm.instance_count:
				var transform:=node.global_transform*mm.get_instance_transform(instance)
				if not (transform*mm.mesh.get_aabb()).grow(.01).intersects_ray(camera.position,dir):continue
				for surface in mm.mesh.get_surface_count():
					var arrays:=mm.mesh.surface_get_arrays(surface)
					var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
					var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
					if indices.is_empty():
						indices.resize(vertices.size());for i in indices.size():indices[i]=i
					for i in range(0,indices.size(),3):
						var a:=transform*vertices[indices[i]];var b:=transform*vertices[indices[i+1]];var c:=transform*vertices[indices[i+2]]
						var hit:Variant=Geometry3D.ray_intersects_triangle(camera.position,dir,a,b,c)
						if hit==null:continue
						var distance:=camera.position.distance_to(hit)
						if nearest.has("native") and distance>=nearest.native.distance:continue
						nearest.native={"node":str(node.name),"distance":distance,"hit":str(hit),"triangle":[str(a),str(b),str(c)]}
		var row:={"pixel":str(pixel),"nearest":nearest};rows.append(row);print("OVERLAP ",JSON.stringify(row))
	FileAccess.open(folder+"/overlap.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	quit()
