extends RefCounted

func run(review: Node) -> void:
	var excluded: Array[RID] = []
	for body: StaticBody3D in review.find_children("DressingCollision", "StaticBody3D", true, false):
		excluded.append(body.get_rid())
	var rows: Array[Dictionary] = []
	var nearest := INF
	var best := Vector3.ZERO
	var space: PhysicsDirectSpaceState3D = review.get_world_3d().direct_space_state
	for node: MultiMeshInstance3D in review.find_children("*", "MultiMeshInstance3D", true, false):
		if node.name == &"LeafShadow" or node.multimesh == null or node.multimesh.mesh == null: continue
		var path: String = node.multimesh.mesh.resource_path
		if not path.contains("farm_sapling_"): continue
		for i in node.multimesh.instance_count:
			var t := node.global_transform * node.multimesh.get_instance_transform(i)
			var at := t.origin
			var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 200, at - Vector3.UP * 200, 1)
			ray.exclude = excluded
			var hit := space.intersect_ray(ray)
			if hit.is_empty(): continue
			rows.append({"asset": path, "at": str(at), "root_above_ground": at.y - (hit.position as Vector3).y})
			var distance := at.distance_squared_to(review._at)
			if distance < nearest: nearest = distance; best = at
	var file := FileAccess.open(review._output_dir + "/sapling-roots.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(rows, "  ")); file.close()
	var old_views: Array[Dictionary] = review._views.duplicate()
	review._views.clear()
	var bush := Vector3(-222.0464, 62.416, 1328.914)
	review._views.append({"id": "bush_no_grass", "position": bush + Vector3(6, 4, 9), "target": bush + Vector3.UP, "fov": 45.0})
	if nearest < INF:
		review._views.append({"id": "sapling_no_grass", "position": best + Vector3(10, 8, 15), "target": best + Vector3.UP * 4, "fov": 50.0})
	var grass_visible: bool = review._streamer._grass_root.visible
	review._streamer._grass_root.visible = false
	await review._capture_all(24)
	review._streamer._grass_root.visible = grass_visible
	review._views = old_views
	print("VEGETATION_ROOT_AUDIT saplings=", rows.size())
