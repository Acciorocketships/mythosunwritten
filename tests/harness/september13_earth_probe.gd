extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var world := load("res://docs/qa/2026-09-12-manual/01-ground/receiver-native/30_heath/world.scn").instantiate() as Node3D
	root.add_child(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	root.size = Vector2i(1716,1033)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.fov = 50
	var feet := Vector3(-419.6,21.9,-660.4)
	camera.global_position = ReviewCam.solve_cam(feet,Vector3(-424.8,28,-653.2),26,16,1)
	camera.look_at(feet+Vector3.UP)
	var triangle_cache := {}
	var results := []
	for pixel: Vector2 in [Vector2(670,440),Vector2(1040,455),Vector2(400,665)]:
		var origin := camera.project_ray_origin(pixel)
		var ray := camera.project_ray_normal(pixel)
		var hits := []
		for node: Node in world.find_children("*","GeometryInstance3D",true,false):
			if not (node is MeshInstance3D or node is MultiMeshInstance3D): continue
			if not node.is_visible_in_tree() or not node.is_in_group("tactical_solid_earth"): continue
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
				var normal := Vector3.ZERO
				for i in range(0,triangles.size(),3):
					var hit = Geometry3D.ray_intersects_triangle(local_origin,local_ray,triangles[i],triangles[i+1],triangles[i+2])
					if hit != null:
						var candidate: Vector3 = transform * hit
						if origin.distance_to(candidate) < nearest:
							nearest = origin.distance_to(candidate)
							point = candidate
							normal = (transform.basis.inverse().transposed() * (triangles[i+2]-triangles[i]).cross(triangles[i+1]-triangles[i])).normalized()
				if nearest == INF: continue
				var owner: Variant = node.get_meta("tactical_owner_rect") if node.has_meta("tactical_owner_rect") else null
				if node is MultiMeshInstance3D and node.multimesh.use_custom_data: owner = node.multimesh.get_instance_custom_data(index)
				hits.append({"normal":str(normal),"distance":nearest,"point":str(point),"node":str(node.get_path()),"instance":index,"owner":str(owner),"parent":str(node.global_transform),"groups":node.get_groups()})
		hits.sort_custom(func(a,b):return a.distance<b.distance)
		results.append({"pixel":str(pixel),"hits":hits.slice(0,16)})
	FileAccess.open("/tmp/sept13-earth-rays.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	quit()
