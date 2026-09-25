extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var world := load("res://docs/qa/2026-09-13-manual/09-upper-wall/before/world.scn").instantiate() as Node3D
	root.add_child(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	root.size = Vector2i(1716,1033)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.fov = 75
	var feet := Vector3(916.1,16,-410.1)
	var pivot := feet+Vector3.UP*CameraMouseView.PIVOT_HEIGHT
	var crosshair := Vector3(945.6,16.5,-401.2)
	var backward := (pivot-crosshair).normalized()
	camera.global_position = ReviewCam.solve_cam(feet,crosshair,Vector2(backward.x,backward.z).length()*CameraMouseView.BOOM_LENGTH,
		CameraMouseView.PIVOT_HEIGHT+backward.y*CameraMouseView.BOOM_LENGTH,CameraMouseView.PIVOT_HEIGHT)
	camera.look_at(pivot)
	camera.make_current()
	await process_frame
	await process_frame
	print("ROOF_CAMERA ", camera.global_transform, " VIEWPORT ", root.get_visible_rect())
	var triangle_cache := {}
	var results := []
	for node: Node in world.find_children("*","MultiMeshInstance3D",true,false):
		if "roof" in node.name.to_lower():
			print("ROOF_NODE ",node.name," visible=",node.is_visible_in_tree()," count=",node.multimesh.instance_count," faces=",node.multimesh.mesh.get_faces().size()," transform=",node.global_transform," first=",node.multimesh.get_instance_transform(0))
	for pixel: Vector2 in [Vector2(739,137),Vector2(532,319),Vector2(739,121)]:
		var origin := camera.project_ray_origin(pixel)
		var ray := camera.project_ray_normal(pixel)
		var hits := []
		for node: Node in world.find_children("*","GeometryInstance3D",true,false):
			if not (node is MeshInstance3D or node is MultiMeshInstance3D): continue
			if not node.is_visible_in_tree(): continue
			var mesh: Mesh = node.mesh if node is MeshInstance3D else node.multimesh.mesh
			if mesh == null: continue
			var count: int = node.multimesh.instance_count if node is MultiMeshInstance3D else 1
			for index in count:
				var transform: Transform3D = node.global_transform * node.multimesh.get_instance_transform(index) if node is MultiMeshInstance3D else node.global_transform
				var inverse := transform.affine_inverse()
				var local_origin := inverse * origin
				var local_ray := inverse.basis * ray
				if mesh.get_aabb().intersects_ray(local_origin,local_ray) == null: continue
				if not triangle_cache.has(mesh): triangle_cache[mesh] = mesh.get_faces()
				var triangles: PackedVector3Array = triangle_cache[mesh]
				var nearest := INF
				var point := Vector3.ZERO
				for i in range(0,triangles.size(),3):
					var hit = Geometry3D.ray_intersects_triangle(local_origin,local_ray,triangles[i],triangles[i+1],triangles[i+2])
					if hit != null:
						var candidate: Vector3 = transform * hit
						if origin.distance_to(candidate) < nearest:
							nearest = origin.distance_to(candidate)
							point = candidate
				if nearest == INF: continue
				var owner: Variant = node.get_meta("tactical_owner_rect") if node.has_meta("tactical_owner_rect") else null
				if node is MultiMeshInstance3D and node.multimesh.use_custom_data: owner = node.multimesh.get_instance_custom_data(index)
				hits.append({"distance":nearest,"point":str(point),"node":str(node.get_path()),"instance":index,"owner":str(owner),"parent":str(node.global_transform),"groups":node.get_groups()})
		hits.sort_custom(func(a,b):return a.distance<b.distance)
		results.append({"pixel":str(pixel),"hits":hits.slice(0,16)})
	FileAccess.open("res://docs/qa/2026-09-13-manual/09-upper-wall/missing-panel-rays.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	quit()
