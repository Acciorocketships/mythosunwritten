extends GutTest
## Wall-free ground collides through HeightMapShape3D tiles (cheap to build)
## and the rest through a residual trimesh. Together they must be the same
## surface as the complete trimesh sheet: every vertical ray hits both at the
## same height, on flat ground, slopes and beside cliff walls.
const Mesher := preload("res://scripts/terrain/field/TerrainChunkMesher.gd")
const Plan := preload("res://scripts/terrain/heightfield/HeightfieldPlan.gd")

func _plan():
	return Plan.new(7, 56.0, 12, "mean")

func _region(plan, chunk: Vector2i) -> HeightfieldRegion:
	var centre := chunk * Mesher.POINTS_PER_CHUNK + Vector2i.ONE * (Mesher.POINTS_PER_CHUNK / 2)
	return plan.compute_region(centre.x, centre.y, Mesher.POINTS_PER_CHUNK)

static func _points(heights: Callable) -> HeightfieldRegion:
	var storeys := {}
	var levels := {}
	for j in range(-24, 41):
		for i in range(-24, 57):
			var h: float = heights.call(i, j)
			storeys[Vector2i(i, j)] = floori(h / 4.0)
			levels[Vector2i(i, j)] = floori(fposmod(h, 4.0))
	return HeightfieldRegion.new(storeys, levels)

## A plateau with a three-storey wall and outer corner, a slope bump, an E2
## cliff end and a level step (the mesher tests' mixed case).
static func _mixed_region() -> HeightfieldRegion:
	return _points(func(i: int, j: int) -> float:
		if i <= 7 and j <= 9:
			if i == 3 and j == 3: return 16.0
			return 12.0
		if i == 8 and j == 10: return 4.0
		if i >= 20: return 1.0
		return 0.0)

func _hit_heights(body: Node3D, points: Array[Vector2]) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var space := body.get_world_3d().direct_space_state
	for p: Vector2 in points:
		var query := PhysicsRayQueryParameters3D.create(Vector3(p.x, 2000.0, p.y),
			Vector3(p.x, -2000.0, p.y))
		query.collision_mask = 1 << 19
		var hit := space.intersect_ray(query)
		out.append(hit.position.y if not hit.is_empty() else NAN)
	return out

func _body(shapes: Array[CollisionShape3D]) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1 << 19
	body.collision_mask = 0
	for shape: CollisionShape3D in shapes:
		body.add_child(shape)
	add_child_autofree(body)
	return body

func test_heightmap_tiles_and_residual_equal_the_full_sheet() -> void:
	var plan = _plan()
	var mesher := Mesher.new()
	mesher.set_seed(7)
	mesher.prepare_resources()
	var total_tiles := 0
	var total_residual := 0
	var compared := 0
	var cases: Array = [[Vector2i(0, 0), _mixed_region()]]
	for chunk: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 2), Vector2i(3, -2)]:
		cases.append([chunk, _region(plan, chunk)])
	for case: Array in cases:
		var chunk: Vector2i = case[0]
		var data: Dictionary = mesher.compute_chunk(chunk, case[1])
		total_tiles += (data.collision_heightmaps as Array).size()
		total_residual += (data.collision_trimesh_faces as PackedVector3Array).size()
		var full := CollisionShape3D.new()
		var full_shape := ConcavePolygonShape3D.new()
		full_shape.set_faces(data.collision_faces)
		full.shape = full_shape
		var reference := _body([full])
		var node: Node3D = mesher.commit_chunk(data)
		add_child_autofree(node)
		var composite := node.find_child("Body", true, false) as StaticBody3D
		# Only the ground shapes take part (walls/rocks are separate shapes).
		for child: Node in composite.get_children():
			var shape := child as CollisionShape3D
			if shape != null and shape.name != "CollisionShape3D" \
					and not String(shape.name).begins_with("GroundTile"):
				shape.disabled = true
		composite.collision_layer = 1 << 19
		var points: Array[Vector2] = []
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(chunk) + compared
		var o := Vector2(chunk) * Mesher.CHUNK_WORLD
		for i in 1500:
			points.append(o + Vector2(rng.randf_range(0.01, 191.99), rng.randf_range(0.01, 191.99)))
		# Lattice lines and wall lines are where a split or offset would show.
		for i in 300:
			points.append(o + Vector2(2.0 * rng.randi_range(0, 95) + 0.001, rng.randf_range(0.01, 191.99)))
		await wait_physics_frames(2)
		reference.collision_layer = 1 << 19
		composite.collision_layer = 0
		await wait_physics_frames(2)
		var expected := _hit_heights(reference, points)
		reference.collision_layer = 0
		composite.collision_layer = 1 << 19
		await wait_physics_frames(2)
		var actual := _hit_heights(composite, points)
		for i in points.size():
			if is_nan(expected[i]):
				continue
			compared += 1
			assert_almost_eq(actual[i], expected[i], 0.0005,
				"chunk %s point %s" % [chunk, points[i]])
		reference.collision_layer = 0
	gut.p("heightmap tiles=%d residual tris=%d compared=%d" % [total_tiles, total_residual / 3, compared])
	assert_gt(total_tiles, 0, "some ground became heightmap tiles")
	assert_gt(total_residual, 0, "wall/graded ground stays trimesh")
	assert_gt(compared, 6000)
