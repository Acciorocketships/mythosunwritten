extends GutTest

func test_collision_shapes_commit_atomically_under_one_chunk_body() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var cache := EnvironmentRenderCache.new(catalog)
	var ids: Array[StringName] = [&"kaykit.tree.01"]
	assert_true(cache.prepare(ids))
	var payload := DressingPayload.new()
	var placement := Transform3D(Basis(Vector3.UP, 0.7).scaled(Vector3.ONE * 1.1),
		Vector3(12.0, 4.0, 18.0))
	payload.add(&"kaykit.tree.01", placement, Color.WHITE)
	var parent := Node3D.new()
	add_child_autofree(parent)
	var shape_count := DressingCollisionBuilder.commit(parent, payload, cache)
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
	var payload := DressingPayload.new()
	payload.add(&"kaykit.bush.01", Transform3D.IDENTITY, Color.WHITE)
	var parent := Node3D.new()
	add_child_autofree(parent)
	assert_eq(DressingCollisionBuilder.commit(parent, payload, cache), 0)
	assert_false(parent.has_node("DressingCollision"))
