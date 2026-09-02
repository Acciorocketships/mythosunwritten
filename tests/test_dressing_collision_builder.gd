extends GutTest

func test_collision_shapes_commit_atomically_under_one_chunk_body() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var cache := EnvironmentRenderCache.new(catalog)
	var ids: Array[StringName] = [&"kaykit.tree.01"]
	assert_true(cache.prepare(ids))
	var payload := EnvironmentInstancePayload.new()
	var placement := Transform3D(Basis(Vector3.UP, 0.7).scaled(Vector3.ONE * 1.1),
		Vector3(12.0, 4.0, 18.0))
	payload.add(&"kaykit.tree.01", placement, Color.WHITE)
	var parent := Node3D.new()
	add_child_autofree(parent)
	var shape_count := EnvironmentCollisionBuilder.commit(parent, payload, cache,
		&"DressingCollision")
	var visual := cache.visual(&"kaykit.tree.01")
	assert_eq(shape_count, visual.collisions.size())
	var body := parent.get_node("DressingCollision") as StaticBody3D
	assert_not_null(body)
	assert_eq(body.get_child_count(), shape_count)
	var committed := body.get_child(0) as CollisionShape3D
	assert_not_null(committed)
	assert_eq(committed.transform, placement * visual.collisions[0].local_transform)

func test_visual_only_payload_creates_no_empty_physics_body() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var cache := EnvironmentRenderCache.new(catalog)
	var ids: Array[StringName] = [&"kaykit.bush.01"]
	assert_true(cache.prepare(ids))
	var payload := EnvironmentInstancePayload.new()
	payload.add(&"kaykit.bush.01", Transform3D.IDENTITY, Color.WHITE)
	var parent := Node3D.new()
	add_child_autofree(parent)
	assert_eq(EnvironmentCollisionBuilder.commit(parent, payload, cache,
		&"DressingCollision"), 0)
	assert_false(parent.has_node("DressingCollision"))


func test_per_instance_collision_mask_and_generated_box_are_committed() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var cache := EnvironmentRenderCache.new(catalog)
	var ids: Array[StringName] = [&"kaykit.tree.01"]
	assert_true(cache.prepare(ids))
	var payload := EnvironmentInstancePayload.new()
	payload.add(&"kaykit.tree.01", Transform3D.IDENTITY, Color.WHITE,
		&"visual-only-tree", false)
	var box_transform := Transform3D(Basis.IDENTITY, Vector3(2.0, 1.0, 3.0))
	payload.add_collision_box(box_transform, Vector3(2.5, 2.0, 0.2),
		&"generated/barrier")
	assert_true(payload.validate())
	var parent := Node3D.new()
	add_child_autofree(parent)
	assert_eq(EnvironmentCollisionBuilder.commit(parent, payload, cache,
		&"DressingCollision"), 1)
	var body := parent.get_node("DressingCollision") as StaticBody3D
	assert_not_null(body)
	assert_eq(body.get_child_count(), 1)
	var committed := body.get_child(0) as CollisionShape3D
	assert_eq(committed.transform, box_transform)
	assert_eq((committed.shape as BoxShape3D).size, Vector3(2.5, 2.0, 0.2))
