extends RefCounted

## Inspect paths on the actual collision sheet, then follow them using the
## production character. Run in cliff_site_review at (-192, 0, 960), radius 1.
const Features = preload("res://scripts/terrain/heightfield/LandformFeatures.gd")
const STEP := 3.0
const SIDE := 101


class RouteController:
	extends CharacterController
	var direction := Vector2.ZERO

	func get_move_vector(_body: CharacterBody3D, _delta: float) -> Vector2:
		return direction


func run(review: Node) -> void:
	var character = review._character
	var streamer = review._streamer
	var original = character.controller
	var original_position: Vector3 = character.global_position
	var original_process: bool = streamer.is_processing()
	var original_physics: bool = streamer.is_physics_processing()
	streamer.set_process(false)
	streamer.set_physics_process(false)
	streamer._freeze_player(false)
	character.set_physics_process(false)
	var controller := RouteController.new()
	character.controller = controller
	var space: PhysicsDirectSpaceState3D = review.get_world_3d().direct_space_state
	var excluded: Array[RID] = [character.get_rid()]
	for body: StaticBody3D in review.find_children(
		"DressingCollision", "StaticBody3D", true, false
	):
		excluded.append(body.get_rid())
	var results := []
	for cell: Vector2i in [Vector2i(-2, 4), Vector2i(-1, 4)]:
		var feature: Dictionary = Features.local_candidate(2697992464, cell)
		assert(not feature.is_empty())
		var base: Vector2 = feature.pos - Vector2.ONE * STEP * (SIDE - 1) * 0.5
		var heights := PackedFloat32Array()
		heights.resize(SIDE * SIDE)
		heights.fill(INF)
		var walkable := PackedByteArray()
		walkable.resize(heights.size())
		for z in SIDE:
			for x in SIDE:
				var p := base + Vector2(x, z) * STEP
				if not streamer._built.has(FieldTerrainStreamer.chunk_of(Vector3(p.x, 0, p.y))):
					continue
				var query := PhysicsRayQueryParameters3D.create(
					Vector3(p.x, 1000, p.y), Vector3(p.x, -500, p.y), 1
				)
				query.exclude = excluded
				var hit := space.intersect_ray(query)
				if hit.is_empty():
					continue
				var index := z * SIDE + x
				heights[index] = hit.position.y
				walkable[index] = int(hit.normal.y >= cos(character.floor_max_angle))
		var a: Vector2
		var b: Vector2
		if feature.hollow:
			a = feature.pos + Vector2(feature.offset, -55).rotated(feature.angle)
			b = feature.pos + Vector2(feature.offset, 45).rotated(feature.angle)
		else:
			a = feature.pos + feature.nodes[0].rotated(feature.angle)
			b = feature.pos + feature.nodes[2].rotated(feature.angle)
		var start := _nearest(a, base, walkable)
		var finish := _nearest(b, base, walkable)
		var path := _path(start, finish, heights, walkable)
		var row := {
			"cell": str(cell),
			"kind": "hollow_bridge" if feature.hollow else "clustered_crests",
			"feature": str(feature.pos),
			"path_nodes": path.size(),
			"grid_step": STEP
		}
		if not path.is_empty():
			var points := PackedVector3Array()
			for index: int in path:
				var p := base + Vector2(index % SIDE, index / SIDE) * STEP
				points.append(Vector3(p.x, heights[index], p.y))
			row.merge(await _walk(review, character, controller, points))
		results.append(row)
		print("BATTLE_ROUTE ", JSON.stringify(row))
	controller.direction = Vector2.ZERO
	character.controller = original
	character.global_position = original_position
	character.velocity = Vector3.ZERO
	streamer.set_process(original_process)
	streamer.set_physics_process(original_physics)
	FileAccess.open(review._output_dir + "/battle-routes.json", FileAccess.WRITE).store_string(
		JSON.stringify(results, "  ")
	)


func _nearest(p: Vector2, base: Vector2, walkable: PackedByteArray) -> int:
	var best := -1
	var distance := 36.0
	for index in walkable.size():
		if walkable[index] == 0:
			continue
		var q := base + Vector2(index % SIDE, index / SIDE) * STEP
		var d := p.distance_squared_to(q)
		if d < distance:
			distance = d
			best = index
	return best


func _path(
	start: int, finish: int, heights: PackedFloat32Array, walkable: PackedByteArray
) -> Array:
	if start < 0 or finish < 0:
		return []
	var parent := {start: -1}
	var queue: Array[int] = [start]
	var cursor := 0
	while cursor < queue.size() and not parent.has(finish):
		var index := queue[cursor]
		cursor += 1
		var at := Vector2i(index % SIDE, index / SIDE)
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dz == 0:
					continue
				var next := at + Vector2i(dx, dz)
				if next.x < 0 or next.y < 0 or next.x >= SIDE or next.y >= SIDE:
					continue
				var ni := next.y * SIDE + next.x
				if walkable[ni] == 0 or parent.has(ni):
					continue
				if absf(heights[ni] - heights[index]) > STEP * Vector2(dx, dz).length() * 0.9:
					continue
				parent[ni] = index
				queue.append(ni)
	if not parent.has(finish):
		return []
	var path := []
	var index := finish
	while index >= 0:
		path.append(index)
		index = parent[index]
	path.reverse()
	return path


func _walk(
	review: Node, character, controller: RouteController, points: PackedVector3Array
) -> Dictionary:
	character.global_position = points[0] + Vector3.UP * 0.1
	character.velocity = Vector3.ZERO
	controller.direction = Vector2.ZERO
	for tick in 30:
		await review.get_tree().physics_frame
		character._physics_process(1.0 / 60.0)
	var next := 1
	var trace := []
	for tick in 2400:
		var delta: Vector3 = points[next] - character.global_position
		if Vector2(delta.x, delta.z).length() < 0.8:
			next += 1
			if next == points.size():
				break
			delta = points[next] - character.global_position
		controller.direction = Vector2(delta.x, delta.z).normalized()
		await review.get_tree().physics_frame
		character._physics_process(1.0 / 60.0)
		if tick % 30 == 0:
			trace.append(str(character.global_position))
	controller.direction = Vector2.ZERO
	return {
		"passed": next == points.size(),
		"waypoints_reached": next,
		"end": str(character.global_position),
		"target": str(points[-1]),
		"trace": trace
	}
