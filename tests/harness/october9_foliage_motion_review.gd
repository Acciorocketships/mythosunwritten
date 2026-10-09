extends RefCounted


## Actual painted tree, several medium-distance moving views. The saved poses
## record actual eye distance if avoiding terrain raises the camera.
func run(review: Node) -> void:
	var chosen: Dictionary = {}
	var best := INF
	for node: MultiMeshInstance3D in review.find_children("*", "MultiMeshInstance3D", true, false):
		if node.name == &"LeafShadow" or node.multimesh == null or node.multimesh.mesh == null:
			continue
		var mesh: Mesh = node.multimesh.mesh
		var path := mesh.resource_path
		if not path.contains("meadow_") or path.contains("bush"):
			continue
		for i in node.multimesh.instance_count:
			var transform := node.global_transform * node.multimesh.get_instance_transform(i)
			var bounds: AABB = transform * mesh.get_aabb()
			if bounds.size.y < 10.0 or maxf(bounds.size.x, bounds.size.z) < 5.0:
				continue
			var target := (
				bounds.position
				+ Vector3(bounds.size.x * .5, bounds.size.y * .68, bounds.size.z * .5)
			)
			var distance := Vector2(target.x, target.z).distance_to(
				Vector2(review._at.x, review._at.z)
			)
			if distance < best:
				best = distance
				chosen = {
					"target": target,
					"asset": path,
					"root": transform.origin,
					"height": bounds.size.y
				}
	if chosen.is_empty():
		push_error("No loaded painted tree for foliage review")
		return
	var space: PhysicsDirectSpaceState3D = review.get_world_3d().direct_space_state
	var excluded: Array[RID] = []
	for body: StaticBody3D in review.find_children(
		"DressingCollision", "StaticBody3D", true, false
	):
		excluded.append(body.get_rid())
	var old: Array[Dictionary] = review._views.duplicate()
	review._views.clear()
	var poses := []
	for distance: float in [40.0, 80.0, 100.0, 120.0]:
		for angle: float in [-.025, 0.0, .025]:
			var direction := Vector2.LEFT.rotated(angle)
			var target: Vector3 = chosen.target
			var eye := target + Vector3(direction.x * distance, 8, direction.y * distance)
			var blocked := true
			for attempt in 12:
				var query := PhysicsRayQueryParameters3D.create(eye, target, 1)
				query.exclude = excluded
				if space.intersect_ray(query).is_empty():
					blocked = false
					break
				eye.y += 4.0
			if blocked:
				poses.append({"distance": distance, "angle": angle, "error": "terrain obstructed"})
				continue
			var id := "tree_%d_angle_%d" % [distance, roundi(angle * 1000)]
			review._views.append({"id": id, "position": eye, "target": target, "fov": 60.0})
			poses.append(
				{
					"id": id,
					"camera": str(eye),
					"target": str(target),
					"actual_distance": eye.distance_to(target)
				}
			)
	await review._capture_all(51)
	review._views = old
	chosen.target = str(chosen.target)
	chosen.root = str(chosen.root)
	(
		FileAccess
		. open(review._output_dir + "/foliage-motion-review.json", FileAccess.WRITE)
		. store_string(JSON.stringify({"tree": chosen, "poses": poses}, "  "))
	)
	print("FOLIAGE_MOTION_REVIEW ", JSON.stringify(chosen), " views=", poses.size())
