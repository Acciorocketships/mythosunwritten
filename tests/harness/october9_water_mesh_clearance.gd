extends RefCounted
var scan_rect := Rect2(-42, 1134, 24, 21)
var scan_step := 0.5


func run(review: Node) -> void:
	const WATER_LAYER := 1 << 20
	var bodies: Array[StaticBody3D] = []
	var meshes: Array[MeshInstance3D] = []
	for root: Node in review.get_tree().get_nodes_in_group("water_surface"):
		var node := root.get_node_or_null("WaterSheet") as MeshInstance3D
		if node == null or node.mesh == null:
			continue
		var bounds: AABB = node.global_transform * node.mesh.get_aabb()
		if not (
			Rect2(
				Vector2(bounds.position.x, bounds.position.z), Vector2(bounds.size.x, bounds.size.z)
			)
			. intersects(scan_rect)
		):
			continue
		var body := StaticBody3D.new()
		body.collision_layer = WATER_LAYER
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		shape.shape = node.mesh.create_trimesh_shape()
		shape.shape.backface_collision = true
		body.add_child(shape)
		review.add_child(body)
		body.global_transform = node.global_transform
		bodies.append(body)
		meshes.append(node)
	if bodies.is_empty():
		push_error("Water mesh clearance probe found no WaterSheet meshes")
		return
	await review.get_tree().physics_frame
	await review.get_tree().physics_frame
	var space: PhysicsDirectSpaceState3D = review.get_world_3d().direct_space_state
	var failures := []
	var checked := 0
	var minimum := INF
	for zi in int(scan_rect.size.y / scan_step) + 1:
		for xi in int(scan_rect.size.x / scan_step) + 1:
			var p := scan_rect.position + Vector2(xi, zi) * scan_step
			var chunk := FieldTerrainStreamer.chunk_of(Vector3(p.x, 0, p.y))
			if not review._streamer._built.has(chunk):
				continue
			var water: WaterFieldContext = review._streamer._fields.water(chunk)
			var level := water.level_at(p)
			if not is_finite(level):
				continue
			var start := Vector3(p.x, 1000, p.y)
			var finish := Vector3(p.x, -500, p.y)
			var ground := space.intersect_ray(PhysicsRayQueryParameters3D.create(start, finish, 1))
			if ground.is_empty() or not str(ground.collider.get_path()).ends_with("/Body"):
				continue
			if level - ground.position.y < .15:
				continue
			checked += 1
			var surface := space.intersect_ray(
				PhysicsRayQueryParameters3D.create(start, finish, WATER_LAYER)
			)
			var clearance: float = (
				surface.position.y - ground.position.y if not surface.is_empty() else -INF
			)
			minimum = minf(minimum, clearance)
			if clearance < .02:
				failures.append(
					{
						"at": str(p),
						"field_depth": level - ground.position.y,
						"mesh_depth": clearance if is_finite(clearance) else null,
						"ground": ground.position.y,
						"triangles": _triangles_at(meshes, p, water) if failures.size() < 20 else []
					}
				)
	for body: StaticBody3D in bodies:
		body.free()
	(
		FileAccess
		. open(review._output_dir + "/water-mesh-clearance.json", FileAccess.WRITE)
		. store_string(
			JSON.stringify(
				{
					"bodies": bodies.size(),
					"checked": checked,
					"min_depth": minimum if is_finite(minimum) else null,
					"failures": failures
				},
				"  "
			)
		)
	)
	print(
		"WATER_MESH_CLEARANCE bodies=",
		bodies.size(),
		" checked=",
		checked,
		" failures=",
		failures.size(),
		" min=",
		minimum
	)


func _triangles_at(meshes: Array[MeshInstance3D], p: Vector2, water: WaterFieldContext) -> Array:
	var rows := []
	for mesh: MeshInstance3D in meshes:
		for si in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(si)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var ids: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for ti in range(0, ids.size(), 3):
				var a: Vector3 = mesh.global_transform * verts[ids[ti]]
				var b: Vector3 = mesh.global_transform * verts[ids[ti + 1]]
				var c: Vector3 = mesh.global_transform * verts[ids[ti + 2]]
				if not Geometry2D.is_point_in_polygon(
					p, PackedVector2Array([Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z)])
				):
					continue
				var points := []
				for v: Vector3 in [a, b, c]:
					var level := water.level_at(Vector2(v.x, v.z))
					points.append(
						{"position": str(v), "field_level": level if is_finite(level) else null}
					)
				rows.append(points)
	return rows
