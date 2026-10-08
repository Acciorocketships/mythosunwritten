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

func test_tree_batches_hand_over_to_an_imposter_child() -> void:
	## October 7: past IMPOSTER_DISTANCE a tree tile draws one baked camera-
	## facing card per tree instead of thousands of leaf cards, crossfading per
	## tree in the shaders (complementary dither) inside culling-only ranges.
	var asset_id := &"meadow.oak.01.summer"
	var cache := _cache_for(asset_id)
	var queue := EnvironmentCommitQueue.new(cache, &"Dressing")
	var parent := Node3D.new()
	add_child_autofree(parent)
	var payload := EnvironmentInstancePayload.new()
	var placement := Transform3D(Basis(Vector3.UP, 0.6).scaled(Vector3.ONE * 1.1), Vector3(5, 0, 5))
	payload.add(asset_id, placement, Color(0.9, 0.8, 0.6))
	payload.add(asset_id, Transform3D(Basis(), Vector3(12, 1, 30)), Color(0.7, 0.9, 0.6))
	queue.register_chunk(Vector2i.ZERO, 1)
	queue.enqueue(Vector2i.ZERO, 1, parent, payload)
	queue.drain(64)
	var container := parent.get_node("Dressing") as Node3D
	var near := container.get_child(0) as MultiMeshInstance3D
	var imposter := near.get_node_or_null("Imposter") as MultiMeshInstance3D
	assert_not_null(imposter)
	if imposter == null:
		return
	var global: Dictionary = ProjectSettings.get_setting("shader_globals/tree_imposter_fade")
	assert_eq(global.value, Vector2(EnvironmentCommitQueue.IMPOSTER_DISTANCE, EnvironmentCommitQueue.IMPOSTER_FADE),
		"project.godot's shader global starts at the queue's switch")
	# The node ranges only cull; the crossfade is per tree in the shaders.
	assert_almost_eq(near.visibility_range_end, EnvironmentCommitQueue.imposter_range_end(), 1e-3)
	assert_almost_eq(imposter.visibility_range_begin, EnvironmentCommitQueue.imposter_range_begin(), 1e-3)
	assert_eq(imposter.visibility_range_end, 0.0, "the imposter draws to the horizon")
	assert_gt(near.visibility_range_end, EnvironmentCommitQueue.IMPOSTER_DISTANCE
		+ EnvironmentCommitQueue.IMPOSTER_FADE + EnvironmentCommitQueue._TILE_HALF_DIAGONAL,
		"the batch draws until its farthest tree has faded out")
	assert_lt(imposter.visibility_range_begin, EnvironmentCommitQueue.IMPOSTER_DISTANCE
		- EnvironmentCommitQueue.IMPOSTER_FADE - EnvironmentCommitQueue._TILE_HALF_DIAGONAL,
		"cards draw from before its nearest tree starts to fade")
	for node: GeometryInstance3D in [near, imposter]:
		assert_eq(node.visibility_range_fade_mode, GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED,
			"FADE_SELF would draw the whole batch translucent at every distance")
	var mesh := near.multimesh.mesh
	var bark := mesh.surface_get_material(0) as ShaderMaterial
	var leaf := mesh.surface_get_material(1) as ShaderMaterial
	assert_eq(bark.shader.resource_path, "res://terrain/environment/materials/tree_bark.gdshader")
	assert_true(leaf.get_shader_parameter("imposter_crossfade"))
	var shadow := near.get_node("LeafShadow") as MultiMeshInstance3D
	assert_true(shadow.multimesh.mesh.surface_get_material(0) is StandardMaterial3D,
		"the shadow proxy keeps the baked bark")
	assert_ne(shadow.multimesh.mesh.surface_get_material(1).get_shader_parameter("imposter_crossfade"), true)
	assert_eq(imposter.multimesh.instance_count, near.multimesh.instance_count)
	# The atlas was captured in asset space (piece transforms included): the
	# card takes the placement itself.
	# (The headless renderer keeps no instance data: read back windowed only.)
	if DisplayServer.get_name() != "headless":
		var piece := cache.visual(asset_id).pieces[0]
		assert_eq(near.multimesh.get_instance_transform(0), placement * piece.local_transform)
		assert_eq(imposter.multimesh.get_instance_transform(0), placement)
		for index in 2:
			assert_eq(imposter.multimesh.get_instance_color(index), near.multimesh.get_instance_color(index))
			assert_eq(imposter.multimesh.get_instance_custom_data(index),
				near.multimesh.get_instance_custom_data(index))
	assert_eq(imposter.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
		"the card would turn to the sun in the shadow pass")
	assert_true(imposter.is_in_group("tactical_preserve_surface"))
	assert_almost_eq(imposter.custom_aabb.get_center(), near.multimesh.get_aabb().get_center(), Vector3.ONE * 1e-4,
		"both ranges are measured to one centre, so the crossfade never leaves a gap")
	var quad := imposter.multimesh.mesh as QuadMesh
	assert_not_null(quad)
	if quad != null:
		assert_eq(quad.size, Vector2.ONE)
	var material := imposter.material_override as ShaderMaterial
	assert_eq(material.shader.resource_path, "res://terrain/environment/materials/tree_imposter.gdshader")
	var imposter_data := cache.visual(asset_id).imposter
	assert_same(material.get_shader_parameter("albedo_atlas"), imposter_data.albedo)
	assert_eq(material.get_shader_parameter("pivot_height"), imposter_data.pivot_height)
	# Every tile of the same tree shares one material.
	assert_same(EnvironmentCommitQueue.imposter_material(imposter_data), material)
	assert_eq(container.get_child_count(), 1, "the card hangs under its batch; Dressing's children are unchanged")
	# Non-tree dressing gets no imposter.
	assert_null(near.get_node_or_null("LeafShadow/Imposter"))

func test_every_placed_tree_keeps_its_imposter_and_crossfades() -> void:
	## Only the legacy LPFV/KayKit canopy shader cannot crossfade; no dressing
	## set places those trees.
	var catalog := EnvironmentCatalog.load_default()
	var cache := EnvironmentRenderCache.new(catalog)
	var index := load("res://terrain/dressing/index.tres") as DressingCatalogIndex
	var trees := 0
	for asset_id: StringName in DressingCompiler.authored_asset_ids(index):
		if not &"tree" in catalog.descriptor(asset_id).tags:
			continue
		var visual := cache.visual(asset_id)
		assert_not_null(visual.imposter, "%s hands over to its imposter" % asset_id)
		trees += 1
		for piece: EnvironmentVisualPiece in visual.pieces:
			for surface in piece.mesh.get_surface_count():
				var material := piece.mesh.surface_get_material(surface) as ShaderMaterial
				assert_not_null(material, "%s surface %d crossfades" % [asset_id, surface])
				if material != null:
					assert_true(material.shader.code.contains("tree_imposter_fade"))
	assert_gt(trees, 20)

func test_tree_crossfade_shaders_survive_the_camera_bubble() -> void:
	## CameraVisibilityBubble rewrites a foreground tree's materials by
	## instrumenting their shader text: each must be one self-contained file.
	var source := StandardMaterial3D.new()
	source.vertex_color_use_as_albedo = true
	var cutout := source.duplicate() as StandardMaterial3D
	cutout.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	cutout.cull_mode = BaseMaterial3D.CULL_DISABLED
	for material: ShaderMaterial in [EnvironmentCommitQueue.crossfade_material(source),
			EnvironmentCommitQueue.crossfade_material(cutout)]:
		var code := CameraVisibilityBubble.instrument(material.shader.code)
		assert_false(code.contains("#include \"res://terrain/environment/materials/tree"))
		assert_eq(code.count("void fragment()"), 1)
		assert_eq(code.count("void vertex()"), 1)
	var cut := EnvironmentCommitQueue.crossfade_material(cutout) as ShaderMaterial
	assert_true(cut.shader.code.contains("ALPHA_SCISSOR_THRESHOLD = alpha_scissor;"))
	assert_true(cut.shader.code.contains("cull_disabled"))


func test_a_second_render_cache_still_hands_trees_over() -> void:
	## Review fix: the crossfade copies live on the ResourceLoader-shared meshes.
	## A second cache (SettlementFabricAssembler builds one per town) must find
	## them in place, not mistake them for unsupported materials and drop the
	## card while the mesh still dithers away.
	var ids: Array[StringName] = [&"meadow.oak.04.summer", &"meadow.birch.05.summer"]
	var first := EnvironmentRenderCache.new(EnvironmentCatalog.load_default())
	assert_true(first.prepare(ids))
	var second := EnvironmentRenderCache.new(EnvironmentCatalog.load_default())
	assert_true(second.prepare(ids))
	for asset_id in ids:
		var a := first.visual(asset_id)
		var b := second.visual(asset_id)
		assert_not_null(b.imposter, "%s keeps its imposter in the second cache" % asset_id)
		for piece_index in b.pieces.size():
			var mesh := b.pieces[piece_index].mesh
			for surface in mesh.get_surface_count():
				var material := mesh.surface_get_material(surface) as ShaderMaterial
				assert_not_null(material)
				if material == null:
					continue
				assert_true(material.has_meta(&"imposter_crossfade"))
				assert_true(material.shader.code.contains("tree_imposter_fade"))
				assert_same(material, a.pieces[piece_index].mesh.surface_get_material(surface),
					"one copy per mesh surface, made once")
				var baked: Material = material.get_meta(&"baked_material")
				assert_false(baked.has_meta(&"imposter_crossfade"), "the original is the bake's")

func test_every_piece_fades_at_the_placement_distance() -> void:
	## Review fix: a piece may sit offset from the placement (none of today's
	## imposter trees has one: their offset transforms are trunk collisions).
	## Each piece's crossfade copy carries the placement origin in its own
	## mesh space, so every piece and the card measure one distance.
	var source := cache_material(&"meadow.oak.04.summer")
	var bark := StandardMaterial3D.new()
	bark.vertex_color_use_as_albedo = true
	var placement := Transform3D(Basis(Vector3.UP, 1.1).scaled(Vector3.ONE * 1.2), Vector3(40, 3, -7))
	var locals := [Transform3D(Basis().scaled(Vector3.ONE * 1.3), Vector3.ZERO),
		Transform3D(Basis(Vector3.UP, 2.0).scaled(Vector3.ONE * 1.3), Vector3(-0.08, 1.49, 0.09))]
	for local: Transform3D in locals:
		var offset := local.affine_inverse().origin
		for material: Material in [source, bark]:
			var copy := EnvironmentCommitQueue.crossfade_material(material, offset) as ShaderMaterial
			var carried: Vector3 = copy.get_shader_parameter("imposter_origin_offset")
			# The shader: MODEL_MATRIX (= placement * local) * vec4(offset, 1).
			assert_almost_eq((placement * local) * carried, placement.origin, Vector3.ONE * 1e-3,
				"a piece at %s fades at the placement" % local.origin)
	var visual := EnvironmentVisual.new()
	for local: Transform3D in locals:
		var piece := EnvironmentVisualPiece.new()
		var mesh := ArrayMesh.new()
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, bark)
		piece.mesh = mesh
		piece.local_transform = local
		visual.pieces.append(piece)
	assert_true(EnvironmentRenderCache._crossfade_tree(visual))
	for piece: EnvironmentVisualPiece in visual.pieces:
		var carried: Vector3 = (piece.mesh.surface_get_material(0) as ShaderMaterial) \
			.get_shader_parameter("imposter_origin_offset")
		assert_almost_eq((placement * piece.local_transform) * carried, placement.origin, Vector3.ONE * 1e-3)
	for path in ["res://terrain/environment/materials/painted_leaf.gdshader",
			"res://terrain/environment/materials/tree_bark.gdshader"]:
		assert_true((load(path) as Shader).code.contains(
			"(MODEL_MATRIX * vec4(imposter_origin_offset, 1.0)).xyz"), path)

## The bake's leaf material of a tree (behind its crossfade copy).
func cache_material(asset_id: StringName) -> Material:
	var mesh := _cache_for(asset_id).visual(asset_id).pieces[0].mesh
	return mesh.surface_get_material(1).get_meta(&"baked_material")

func test_bark_with_an_unreproduced_feature_keeps_no_imposter() -> void:
	## Review fix: tree_bark.gdshader mirrors only what the baked bark uses; any
	## other StandardMaterial3D feature must keep the mesh (no card) rather
	## than draw a wrong copy.
	var base := StandardMaterial3D.new()
	base.vertex_color_use_as_albedo = true
	base.roughness = 0.85
	assert_true(EnvironmentCommitQueue.can_crossfade(base))
	var changes := {
		"vertex_color_use_as_albedo": false, "vertex_color_is_srgb": true,
		"uv1_scale": Vector3(2, 2, 2), "uv1_offset": Vector3(0.1, 0, 0), "uv1_triplanar": true,
		"cull_mode": BaseMaterial3D.CULL_DISABLED,
		"shading_mode": BaseMaterial3D.SHADING_MODE_UNSHADED,
		"texture_filter": BaseMaterial3D.TEXTURE_FILTER_NEAREST,
		"rim_enabled": true, "backlight_enabled": true, "detail_enabled": true,
		"emission_enabled": true, "metallic": 0.5,
		"transparency": BaseMaterial3D.TRANSPARENCY_ALPHA,
	}
	for property: String in changes:
		var material := base.duplicate() as StandardMaterial3D
		material.set(property, changes[property])
		assert_false(EnvironmentCommitQueue.can_crossfade(material), "rejects %s" % property)
	var ao := base.duplicate() as StandardMaterial3D
	ao.ao_enabled = true
	ao.ao_texture = PlaceholderTexture2D.new()
	assert_true(EnvironmentCommitQueue.can_crossfade(ao))
	ao.ao_on_uv2 = true
	assert_false(EnvironmentCommitQueue.can_crossfade(ao), "rejects ao_on_uv2")
	# A visual with one such surface drops its imposter.
	var visual := EnvironmentVisual.new()
	var piece := EnvironmentVisualPiece.new()
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var rim := base.duplicate() as StandardMaterial3D
	rim.rim_enabled = true
	mesh.surface_set_material(0, rim)
	piece.mesh = mesh
	visual.pieces.append(piece)
	assert_false(EnvironmentRenderCache._crossfade_tree(visual))
	assert_same(mesh.surface_get_material(0), rim, "nothing is swapped")
