class_name EnvironmentCollisionBuilder
extends RefCounted

## Main-thread adapter for structural environment instances. Collision is
## committed before readiness; render-only MultiMeshes may arrive later.
static func commit(parent: Node3D, payload: EnvironmentInstancePayload,
		render_cache: EnvironmentRenderCache, body_name: StringName) -> int:
	assert(OS.get_thread_caller_id() == OS.get_main_thread_id())
	assert(parent != null and payload != null and payload.validate() and render_cache != null)
	var body: StaticBody3D
	var count := 0
	for asset_id: StringName in payload.asset_ids():
		var visual := render_cache.visual(asset_id)
		assert(visual != null)
		if visual.collisions.is_empty():
			continue
		if body == null:
			body = StaticBody3D.new()
			body.name = body_name
			parent.add_child(body)
		var placements: Array = payload.batches[asset_id].transforms
		var collision_flags: Array = payload.batches[asset_id].get(
			"collision_enabled", [])
		for placement_index in placements.size():
			if not collision_flags.is_empty() \
					and not bool(collision_flags[placement_index]):
				continue
			var placement := placements[placement_index] as Transform3D
			for collision: EnvironmentCollisionPiece in visual.collisions:
				var shape_node := CollisionShape3D.new()
				shape_node.name = "%s_%04d" % [String(asset_id).replace(".", "_"), count]
				shape_node.shape = collision.shape
				shape_node.transform = placement * collision.local_transform
				body.add_child(shape_node)
				count += 1
	for box: Dictionary in payload.collision_boxes:
		if body == null:
			body = StaticBody3D.new()
			body.name = body_name
			parent.add_child(body)
		var shape := BoxShape3D.new()
		shape.size = box.size as Vector3
		var shape_node := CollisionShape3D.new()
		var stable := String(box.get("stable_id", &""))
		shape_node.name = stable.replace("/", "_") if not stable.is_empty() \
			else "GeneratedBox_%04d" % count
		shape_node.shape = shape
		shape_node.transform = box.transform as Transform3D
		body.add_child(shape_node)
		count += 1
	return count
