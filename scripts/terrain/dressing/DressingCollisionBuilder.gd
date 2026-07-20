class_name DressingCollisionBuilder
extends RefCounted

## Main-thread adapter for structural dressing. Visual MultiMeshes may arrive
## later, but collision is committed before the chunk becomes ready, so a
## player can never enter an object while its physics proxy is still pending.
static func commit(parent: Node3D, payload: DressingPayload,
		render_cache: EnvironmentRenderCache) -> int:
	assert(OS.get_thread_caller_id() == OS.get_main_thread_id())
	assert(parent != null and payload != null and render_cache != null)
	var body: StaticBody3D
	var count := 0
	for asset_id: StringName in payload.asset_ids():
		var visual := render_cache.visual(asset_id)
		assert(visual != null)
		if visual.collisions.is_empty():
			continue
		if body == null:
			body = StaticBody3D.new()
			body.name = "DressingCollision"
			parent.add_child(body)
		var placements: Array = payload.batches[asset_id].transforms
		for placement: Transform3D in placements:
			for collision: EnvironmentCollisionPiece in visual.collisions:
				var shape_node := CollisionShape3D.new()
				shape_node.name = "%s_%04d" % [String(asset_id).replace(".", "_"), count]
				shape_node.shape = collision.shape
				shape_node.transform = placement * collision.local_transform
				body.add_child(shape_node)
				count += 1
	return count
