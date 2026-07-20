extends GutTest

func _cache() -> EnvironmentRenderCache:
	var cache := EnvironmentRenderCache.new(EnvironmentCatalog.load_default())
	var ids: Array[StringName] = [&"lpfv.tree.01"]
	assert_true(cache.prepare(ids))
	return cache

func test_one_asset_piece_commits_one_coloured_multimesh_batch() -> void:
	var cache := _cache()
	var queue := DressingCommitQueue.new(cache)
	var parent := Node3D.new()
	add_child_autofree(parent)
	var payload := DressingPayload.new()
	var placement := Transform3D(Basis(Vector3.UP, 0.4), Vector3(3.0, 2.0, 5.0))
	payload.add(&"lpfv.tree.01", placement, Color(0.4, 0.7, 0.5))
	queue.register_chunk(Vector2i.ZERO, 4)
	queue.enqueue(Vector2i.ZERO, 4, parent, payload)
	var queued: Dictionary = queue._items[0]
	var piece := cache.visual(&"lpfv.tree.01").pieces[0]
	assert_eq(DressingCommitQueue.compose_transforms(queued.transforms, piece)[0],
		placement * piece.local_transform)
	assert_eq(queued.colors[0], Color(0.4, 0.7, 0.5))
	assert_eq(queue.drain(1), 1)
	var container := parent.get_node("Dressing") as Node3D
	assert_eq(container.get_child_count(), 1)
	var instance := container.get_child(0) as MultiMeshInstance3D
	assert_not_null(instance)
	assert_eq(instance.multimesh.instance_count, 1)

func test_stale_generation_is_discarded_without_touching_the_chunk() -> void:
	var queue := DressingCommitQueue.new(_cache())
	var parent := Node3D.new()
	add_child_autofree(parent)
	var payload := DressingPayload.new()
	payload.add(&"lpfv.tree.01", Transform3D.IDENTITY, Color.WHITE)
	queue.register_chunk(Vector2i.ZERO, 1)
	queue.enqueue(Vector2i.ZERO, 1, parent, payload)
	queue.invalidate_chunk(Vector2i.ZERO)
	assert_eq(queue.drain(1), 0)
	assert_false(parent.has_node("Dressing"))

func test_batch_budget_is_exact() -> void:
	var queue := DressingCommitQueue.new(_cache())
	var parent := Node3D.new()
	add_child_autofree(parent)
	var payload := DressingPayload.new()
	payload.add(&"lpfv.tree.01", Transform3D.IDENTITY, Color.WHITE)
	queue.register_chunk(Vector2i.ZERO, 1)
	queue.enqueue(Vector2i.ZERO, 1, parent, payload)
	assert_eq(queue.drain(0), 0)
	assert_eq(queue.pending_count(), 1)
	assert_eq(queue.drain(1), 1)
