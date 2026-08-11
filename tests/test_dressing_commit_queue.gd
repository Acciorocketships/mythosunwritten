extends GutTest

func _cache() -> EnvironmentRenderCache:
	var cache := EnvironmentRenderCache.new(EnvironmentCatalog.load_default())
	var ids: Array[StringName] = [&"lpfv.tree.01"]
	assert_true(cache.prepare(ids))
	return cache

func _cache_for(asset_id: StringName) -> EnvironmentRenderCache:
	var cache := EnvironmentRenderCache.new(EnvironmentCatalog.load_default())
	var ids: Array[StringName] = [asset_id]
	assert_true(cache.prepare(ids))
	return cache

func test_one_asset_piece_commits_one_coloured_multimesh_batch() -> void:
	var cache := _cache()
	var queue := EnvironmentCommitQueue.new(cache, &"Dressing")
	var parent := Node3D.new()
	add_child_autofree(parent)
	var payload := EnvironmentInstancePayload.new()
	var placement := Transform3D(Basis(Vector3.UP, 0.4), Vector3(3.0, 2.0, 5.0))
	payload.add(&"lpfv.tree.01", placement, Color(0.4, 0.7, 0.5))
	queue.register_chunk(Vector2i.ZERO, 4)
	queue.enqueue(Vector2i.ZERO, 4, parent, payload)
	var queued: Dictionary = queue._items[0]
	var piece := cache.visual(&"lpfv.tree.01").pieces[0]
	assert_eq(EnvironmentCommitQueue.compose_transforms(queued.transforms, piece)[0],
		placement * piece.local_transform)
	assert_eq(queued.colors[0], Color(0.4, 0.7, 0.5))
	assert_eq(queue.drain(1), 1)
	var container := parent.get_node("Dressing") as Node3D
	assert_eq(container.get_child_count(), 1)
	var instance := container.get_child(0) as MultiMeshInstance3D
	assert_not_null(instance)
	assert_eq(instance.multimesh.instance_count, 1)

func test_palette_piece_commits_material_without_instance_colour_channel() -> void:
	var asset_id := &"lpfv.fabric.roof.compact.slate.03"
	var cache := _cache_for(asset_id)
	var queue := EnvironmentCommitQueue.new(cache, &"Dressing")
	var parent := Node3D.new()
	add_child_autofree(parent)
	var payload := EnvironmentInstancePayload.new()
	payload.add(asset_id, Transform3D.IDENTITY, Color(1.0, 0.0, 0.8))
	queue.register_chunk(Vector2i.ZERO, 1)
	queue.enqueue(Vector2i.ZERO, 1, parent, payload)
	assert_eq(queue.drain(1), 1)
	var piece := cache.visual(asset_id).pieces[0]
	var instance := parent.get_node("Dressing").get_child(0) as MultiMeshInstance3D
	assert_not_null(instance)
	assert_false(instance.multimesh.use_colors,
		"the instance colour channel would overwrite the palette material input")
	assert_same(instance.material_override, piece.material_override)

func test_stale_generation_is_discarded_without_touching_the_chunk() -> void:
	var queue := EnvironmentCommitQueue.new(_cache(), &"Dressing")
	var parent := Node3D.new()
	add_child_autofree(parent)
	var payload := EnvironmentInstancePayload.new()
	payload.add(&"lpfv.tree.01", Transform3D.IDENTITY, Color.WHITE)
	queue.register_chunk(Vector2i.ZERO, 1)
	queue.enqueue(Vector2i.ZERO, 1, parent, payload)
	queue.invalidate_chunk(Vector2i.ZERO)
	assert_eq(queue.drain(1), 0)
	assert_false(parent.has_node("Dressing"))

func test_batch_budget_is_exact() -> void:
	var queue := EnvironmentCommitQueue.new(_cache(), &"Dressing")
	var parent := Node3D.new()
	add_child_autofree(parent)
	var payload := EnvironmentInstancePayload.new()
	payload.add(&"lpfv.tree.01", Transform3D.IDENTITY, Color.WHITE)
	queue.register_chunk(Vector2i.ZERO, 1)
	queue.enqueue(Vector2i.ZERO, 1, parent, payload)
	assert_eq(queue.drain(0), 0)
	assert_eq(queue.pending_count(), 1)
	assert_eq(queue.drain(1), 1)

func test_stable_ids_are_validated_and_ignored_by_render_commit() -> void:
	var queue := EnvironmentCommitQueue.new(_cache(), &"Visuals")
	var parent := Node3D.new()
	add_child_autofree(parent)
	var payload := EnvironmentInstancePayload.new()
	payload.add(&"lpfv.tree.01", Transform3D.IDENTITY, Color.WHITE, &"feature:17")
	assert_true(payload.validate())
	assert_eq(payload.batches[&"lpfv.tree.01"].ids, [&"feature:17"])
	queue.register_chunk(Vector2i.ZERO, 1)
	queue.enqueue(Vector2i.ZERO, 1, parent, payload)
	assert_eq(queue.drain(1), 1)
	assert_true(parent.has_node("Visuals"))

	var malformed := EnvironmentInstancePayload.new()
	malformed.batches[&"lpfv.tree.01"] = {
		"transforms": [Transform3D.IDENTITY], "colors": [Color.WHITE], "ids": [&"a", &"b"]}
	malformed.instance_count = 1
	assert_false(malformed.validate())
