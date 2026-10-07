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
	var shadow := instance.get_node_or_null("CanopyShadow") as MultiMeshInstance3D
	assert_not_null(shadow, "Production tree commits attach their porous shadow representation")
	if shadow != null:
		assert_same(shadow.multimesh, instance.multimesh)
		assert_eq(shadow.transform, Transform3D.IDENTITY)

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

func test_trees_batch_per_foliage_tile_so_each_tile_culls_and_picks_its_lod() -> void:
	## October 6: a chunk-wide tree batch always touched the camera, so every
	## crown in the chunk drew all its leaf cards. Trees and bushes batch per
	## 48 m world square; other dressing keeps one batch per chunk.
	var cache := _cache_for(&"meadow.oak.04.summer")
	var queue := EnvironmentCommitQueue.new(cache, &"Dressing")
	var parent := Node3D.new()
	add_child_autofree(parent)
	var payload := EnvironmentInstancePayload.new()
	for x: float in [5.0, 20.0, 60.0, 100.0, 150.0]:
		payload.add(&"meadow.oak.04.summer", Transform3D(Basis(), Vector3(x, 0.0, 10.0)), Color.WHITE)
	queue.register_chunk(Vector2i.ZERO, 1)
	queue.enqueue(Vector2i.ZERO, 1, parent, payload)
	var pieces := cache.visual(&"meadow.oak.04.summer").pieces.size()
	# x 5 and 20 share tile 0; 60, 100 and 150 fall in tiles 1, 2 and 3.
	assert_eq(queue.pending_count(), 4 * pieces)
	var total := 0
	for item: Dictionary in queue._items:
		var xs: Array = item.transforms.map(func(t: Transform3D) -> int:
			return floori(t.origin.x / EnvironmentCommitQueue.FOLIAGE_TILE))
		assert_eq(xs.min(), xs.max(), "one batch holds one tile")
		total += item.transforms.size()
	assert_eq(total, 5 * pieces)

func test_painted_trees_cast_their_sun_shadow_from_the_baked_stand_in() -> void:
	## October 6: four shadow cascades of full crowns cost a dense forest most
	## of its frame. The visible batch casts none; a shadow-only proxy with an
	## eighth of the leaf cards repeats its instances.
	var cache := _cache_for(&"meadow.oak.04.summer")
	var queue := EnvironmentCommitQueue.new(cache, &"Dressing")
	var parent := Node3D.new()
	add_child_autofree(parent)
	var payload := EnvironmentInstancePayload.new()
	payload.add(&"meadow.oak.04.summer", Transform3D(Basis(), Vector3(4.0, 0.0, 4.0)), Color.WHITE)
	payload.add(&"meadow.oak.04.summer", Transform3D(Basis(), Vector3(9.0, 0.0, 2.0)), Color.WHITE)
	queue.register_chunk(Vector2i.ZERO, 1)
	queue.enqueue(Vector2i.ZERO, 1, parent, payload)
	queue.drain(16)
	var instance := parent.get_node("Dressing").get_child(0) as MultiMeshInstance3D
	assert_eq(instance.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	var proxy := instance.get_node_or_null("LeafShadow") as MultiMeshInstance3D
	assert_not_null(proxy)
	if proxy == null:
		return
	assert_eq(proxy.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
	assert_eq(proxy.multimesh.instance_count, 2)
	for index in 2:
		assert_eq(proxy.multimesh.get_instance_transform(index),
			instance.multimesh.get_instance_transform(index), "same instances")
		assert_eq(proxy.multimesh.get_instance_color(index),
			instance.multimesh.get_instance_color(index), "same tints")
	var visible_leaf := instance.multimesh.mesh.surface_get_arrays(1)[Mesh.ARRAY_INDEX] as PackedInt32Array
	var shadow_leaf := proxy.multimesh.mesh.surface_get_arrays(1)[Mesh.ARRAY_INDEX] as PackedInt32Array
	assert_almost_eq(float(shadow_leaf.size()) / float(visible_leaf.size()), 0.125, 0.04,
		"the stand-in keeps the last leaf LOD's eighth of the cards")
	var shadow_mesh := proxy.multimesh.mesh
	assert_eq(shadow_mesh.get_surface_count(), instance.multimesh.mesh.get_surface_count() + 1,
		"plus one opaque crown blob for the wide cascades")
	var blob := shadow_mesh.surface_get_material(shadow_mesh.get_surface_count() - 1) as ShaderMaterial
	assert_eq(blob.shader.resource_path, "res://terrain/environment/materials/leaf_shadow_blob.gdshader")
	var leaf := instance.multimesh.mesh.surface_get_material(1) as ShaderMaterial
	var width := RegEx.create_from_string("shadow_card_cascade_width = ([0-9.]+);")
	var blob_width := width.search(blob.shader.code)
	var leaf_width := width.search(leaf.shader.code)
	assert_not_null(blob_width)
	assert_not_null(leaf_width)
	if blob_width != null and leaf_width != null:
		assert_eq(blob_width.get_string(1), leaf_width.get_string(1),
			"cards and blob split the cascades at one width")


func test_dressing_grass_and_flowers_end_with_the_grass_ring() -> void:
	var full := GrassStreamer.FULL_RADIUS
	var edge := GrassStreamer.GRASS_RADIUS
	GrassStreamer.set_radii(70.0, 100.0)
	var bounds := AABB(Vector3.ZERO, Vector3.ONE)
	var range_end := EnvironmentCommitQueue.visibility_range([&"nature", &"grass"], bounds)
	GrassStreamer.set_radii(full, edge)
	assert_almost_eq(range_end, 100.0 + 6.0 + EnvironmentCommitQueue._TILE_HALF_DIAGONAL, 0.01,
		"sparse grass/flower dressing fades with the dense carpet, not at a fixed 90 m")
