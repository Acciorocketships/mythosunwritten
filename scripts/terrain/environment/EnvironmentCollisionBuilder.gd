class_name EnvironmentCollisionBuilder
extends RefCounted

## Main-thread adapter for structural environment instances. Collision is
## committed before readiness; render-only MultiMeshes may arrive later.
static func commit(parent: Node3D, payload: EnvironmentInstancePayload,
		render_cache: EnvironmentRenderCache, body_name: StringName) -> int:
	var steps := commit_steps(parent, payload, render_cache, body_name)
	for step: Callable in steps.steps:
		step.call()
	return int(steps.count)


## Shapes created per step: a structural-heavy chunk (~300 shapes, ~10 ms)
## spreads over several frames.
const SHAPES_PER_STEP := 64

## commit as main-thread steps; run in order they build exactly commit()'s
## body (same shapes, names and order). Returns {steps, count}.
static func commit_steps(parent: Node3D, payload: EnvironmentInstancePayload,
		render_cache: EnvironmentRenderCache, body_name: StringName) -> Dictionary:
	assert(OS.get_thread_caller_id() == OS.get_main_thread_id())
	assert(parent != null and payload != null and payload.validate() and render_cache != null)
	# [name, shape, transform] per collision shape, in commit order.
	var items: Array = []
	for asset_id: StringName in payload.asset_ids():
		var visual := render_cache.visual(asset_id)
		assert(visual != null)
		if visual.collisions.is_empty():
			continue
		var placements: Array = payload.batches[asset_id].transforms
		var collision_flags: Array = payload.batches[asset_id].get(
			"collision_enabled", [])
		var prefix := String(asset_id).replace(".", "_")
		for placement_index in placements.size():
			if not collision_flags.is_empty() \
					and not bool(collision_flags[placement_index]):
				continue
			var placement := placements[placement_index] as Transform3D
			for collision: EnvironmentCollisionPiece in visual.collisions:
				items.append(["%s_%04d" % [prefix, items.size()], collision.shape,
					placement * collision.local_transform])
	for box: Dictionary in payload.collision_boxes:
		var shape := BoxShape3D.new()
		shape.size = box.size as Vector3
		var stable := String(box.get("stable_id", &""))
		items.append([stable.replace("/", "_") if not stable.is_empty()
			else "GeneratedBox_%04d" % items.size(), shape, box.transform as Transform3D])
	var steps: Array[Callable] = []
	if items.is_empty():
		return {"steps": steps, "count": 0}
	var body := StaticBody3D.new()
	body.name = body_name
	steps.append(func() -> void: parent.add_child(body))
	for first in range(0, items.size(), SHAPES_PER_STEP):
		steps.append(func() -> void:
			for index in range(first, mini(first + SHAPES_PER_STEP, items.size())):
				var shape_node := CollisionShape3D.new()
				shape_node.name = items[index][0]
				shape_node.shape = items[index][1]
				shape_node.transform = items[index][2]
				body.add_child(shape_node))
	return {"steps": steps, "count": items.size()}
