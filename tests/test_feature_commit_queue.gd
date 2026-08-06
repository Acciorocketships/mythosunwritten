extends GutTest

func _payload(asset_id: StringName) -> EnvironmentInstancePayload:
	var payload := EnvironmentInstancePayload.new()
	payload.add(asset_id, Transform3D.IDENTITY, Color.WHITE,
		&"feature.test.placement")
	return payload

func test_assets_and_collision_are_staged_before_readiness() -> void:
	var cache := EnvironmentRenderCache.new(EnvironmentCatalog.load_default())
	var queue := FeatureCommitQueue.new(cache)
	var parent := Node3D.new()
	add_child_autofree(parent)
	var asset_id := &"sfv.light_pole.001"
	queue.enqueue(Vector2i.ZERO, 3, parent, _payload(asset_id))
	assert_false(cache.is_prepared(asset_id),
		"enqueue carries ids and plain transforms without eager resource loading")
	assert_true(queue.drain(1, 0, 0, 100000).is_empty())
	assert_true(cache.is_prepared(asset_id))
	assert_eq(parent.get_child_count(), 0,
		"a detached block cannot become ready before collision finishes")
	var events: Array[Dictionary] = []
	for _iteration in 64:
		events = queue.drain(0, 1, 0, 100000)
		if not events.is_empty():
			break
	assert_eq(events.size(), 1)
	var block := events[0].node as Node3D
	assert_not_null(block)
	assert_eq(block.get_parent(), parent)
	var body := block.get_node_or_null("FeatureCollision") as StaticBody3D
	assert_not_null(body)
	assert_eq(body.get_child_count(),
		cache.visual(asset_id).collisions.size())
	assert_false(block.has_node("Visuals"),
		"visual batches remain independent from collision readiness")
	queue.drain(0, 0, 16, 100000)
	assert_true(block.has_node("Visuals"))

func test_empty_blocks_become_explicit_ready_records_without_nodes() -> void:
	var queue := FeatureCommitQueue.new(EnvironmentRenderCache.new(
		EnvironmentCatalog.load_default()))
	var parent := Node3D.new()
	add_child_autofree(parent)
	queue.enqueue(Vector2i(2, -1), 7, parent,
		EnvironmentInstancePayload.new())
	var events := queue.drain(0, 0, 0)
	assert_eq(events.size(), 1)
	assert_eq(events[0].chunk, Vector2i(2, -1))
	assert_null(events[0].node)
	assert_eq(parent.get_child_count(), 0)

func test_invalidation_discards_a_detached_partial_commit() -> void:
	var cache := EnvironmentRenderCache.new(EnvironmentCatalog.load_default())
	var queue := FeatureCommitQueue.new(cache)
	var parent := Node3D.new()
	add_child_autofree(parent)
	var chunk := Vector2i(4, 5)
	queue.enqueue(chunk, 1, parent, _payload(&"sfv.arch.001"))
	queue.drain(1, 1, 0, 100000)
	assert_gt(queue.pending_count(), 0)
	queue.invalidate_chunk(chunk)
	assert_eq(queue.pending_count(), 0)
	assert_eq(parent.get_child_count(), 0)
	assert_true(queue.drain(1, 100, 100, 100000).is_empty())
