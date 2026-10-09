extends GutTest

func test_split_collision_preserves_every_triangle_in_order() -> void:
	var root := Node3D.new()
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for i in 2501:
		var x := float(i % 50)
		var z := float(i / 50)
		vertices.append_array(PackedVector3Array([Vector3(x, 0, z), Vector3(x, 0, z + 0.8), Vector3(x + 0.8, 0, z)]))
		indices.append_array(PackedInt32Array([i * 3, i * 3 + 1, i * 3 + 2]))
	var normals := PackedVector3Array(); normals.resize(vertices.size()); normals.fill(Vector3.UP)
	var colors := PackedColorArray(); colors.resize(vertices.size()); colors.fill(Color.WHITE)
	var skirts: Array = [{"vertices": vertices, "indices": indices, "normals": normals, "colors": colors}]
	var steps := RockSkirt.commit_steps(root, skirts)
	# Execute gathering and collision only; GPU mesh resources are not needed.
	steps[0].call()
	var reconstructed := PackedVector3Array()
	for i in range(2, steps.size()):
		steps[i].call()
	var body := root.get_node("RockSkirtCollision")
	assert_eq(body.get_child_count(), 3)
	for shape_node: CollisionShape3D in body.get_children():
		var faces := (shape_node.shape as ConcavePolygonShape3D).get_faces()
		assert_lte(faces.size(), RockSkirt.COLLISION_TRIANGLES_PER_STEP * 3)
		reconstructed.append_array(faces)
	assert_eq(reconstructed, vertices, "every original face survives with its winding and order")
	root.free()

func test_empty_skirts_create_no_collision_steps() -> void:
	var root := Node3D.new()
	assert_eq(RockSkirt.commit_steps(root, []).size(), 0)
	root.free()
