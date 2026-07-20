extends GutTest

const INDEX_PATH := "res://terrain/environment/catalog/index.tres"
const CharacterMovement := preload("res://characters/character.gd")

func test_default_catalogue_is_sorted_unique_and_contains_the_curated_lpfv_trees() -> void:
	var catalog := EnvironmentCatalog.load_default()
	assert_not_null(catalog)
	var ids := catalog.ids()
	assert_gt(ids.size(), 20, "active KayKit resources and the LPFV tree wave are catalogued")
	var strings: Array[String] = []
	for asset_id: StringName in ids:
		strings.append(String(asset_id))
	var sorted := strings.duplicate()
	sorted.sort()
	assert_eq(strings, sorted, "catalogue order is explicit and stable")
	for i in 9:
		assert_true(catalog.has(StringName("lpfv.tree.%02d" % (i + 1))),
			"LPFV Tree_%02d is present" % (i + 1))
	assert_false(catalog.has(&"lpfv.tree.10"), "the sparse conifer is removed")
	assert_false(catalog.has(&"lpfv.tree.blossom_01"), "the broken transparent pink variant is removed")
	assert_false(catalog.has(&"kaykit.tree.02"), "the block-canopy KayKit tree is removed")
	assert_false(catalog.has(&"kaykit.tree.04"), "the sparse KayKit conifer is removed")

func test_descriptors_are_lightweight_and_visuals_are_string_paths() -> void:
	var catalog := EnvironmentCatalog.load_default()
	for asset_id: StringName in catalog.ids():
		var descriptor := catalog.descriptor(asset_id)
		assert_true(descriptor.visual_path.begins_with("res://terrain/environment/visuals/"))
		for property: Dictionary in descriptor.get_property_list():
			var value = descriptor.get(property["name"])
			assert_false(value is Mesh or value is Material or value is Texture2D \
				or value is Shape3D or value is PackedScene,
				"descriptor %s contains no heavy runtime resource" % String(asset_id))

func test_render_cache_loads_only_requested_visuals() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var cache := EnvironmentRenderCache.new(catalog)
	var requested: Array[StringName] = [&"kaykit.tree.01", &"lpfv.tree.01"]
	assert_true(cache.prepare(requested))
	assert_eq(cache.prepared_ids(), requested, "catalogue-only visuals remain unloaded")
	for asset_id: StringName in requested:
		var visual := cache.visual(asset_id)
		assert_not_null(visual)
		assert_gt(visual.pieces.size(), 0)
		for piece: EnvironmentVisualPiece in visual.pieces:
			assert_not_null(piece.mesh)

func test_generated_runtime_resources_have_no_source_pack_dependencies() -> void:
	var pending: Array[String] = [INDEX_PATH]
	var seen: Dictionary = {}
	while not pending.is_empty():
		var path: String = pending.pop_back()
		if seen.has(path):
			continue
		seen[path] = true
		for dependency: String in ResourceLoader.get_dependencies(path):
			assert_false(dependency.contains("res://assets/"),
				"runtime resource is self-contained: %s -> %s" % [path, dependency])
			var marker := dependency.find("res://")
			if marker >= 0:
				pending.append(dependency.substr(marker))
	# visual_path is deliberately a string, so traverse those roots explicitly.
	var catalog := EnvironmentCatalog.load_default()
	for asset_id: StringName in catalog.ids():
		pending.append(catalog.descriptor(asset_id).visual_path)
	while not pending.is_empty():
		var path: String = pending.pop_back()
		if seen.has(path):
			continue
		seen[path] = true
		for dependency: String in ResourceLoader.get_dependencies(path):
			assert_false(dependency.contains("res://assets/"),
				"runtime resource is self-contained: %s -> %s" % [path, dependency])
			var marker := dependency.find("res://")
			if marker >= 0:
				pending.append(dependency.substr(marker))

func test_every_visual_has_finite_valid_instance_colour_pieces() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var cache := EnvironmentRenderCache.new(catalog)
	assert_true(cache.prepare(catalog.ids()))
	for asset_id: StringName in catalog.ids():
		var descriptor := catalog.descriptor(asset_id)
		assert_true(descriptor.measured_aabb.position.is_finite())
		assert_true(descriptor.measured_aabb.size.is_finite())
		assert_gt(descriptor.measured_aabb.size.length_squared(), 0.0)
		var visual := cache.visual(asset_id)
		assert_gt(visual.pieces.size(), 0)
		for piece: EnvironmentVisualPiece in visual.pieces:
			assert_true(piece.local_transform.is_finite())
			assert_gt(piece.mesh.get_surface_count(), 0)
			for surface_index in piece.mesh.get_surface_count():
				assert_gt(piece.mesh.surface_get_array_len(surface_index), 0)
				var material := piece.mesh.surface_get_material(surface_index)
				assert_not_null(material)
				if descriptor.supports_instance_color:
					var standard := material as StandardMaterial3D
					var shader_material := material as ShaderMaterial
					assert_true(standard != null or shader_material != null,
						"instance-colour visual uses a supported material: %s" % asset_id)
					if standard != null:
						assert_true(standard.vertex_color_use_as_albedo,
							"instance colour is enabled: %s" % asset_id)
					elif shader_material != null:
						assert_not_null(shader_material.shader)
						assert_true(shader_material.shader.code.contains("COLOR.rgb"),
							"variant shader preserves instance colour: %s" % asset_id)

func test_environment_runtime_roots_do_not_name_source_packs() -> void:
	var roots: Array[String] = [
		"res://scripts/terrain/environment",
		"res://scripts/terrain/dressing",
		"res://terrain/environment",
		"res://terrain/dressing",
	]
	for root: String in roots:
		_scan_text_tree_for_source_paths(root)
	_assert_text_file_source_free("res://terrain/materials/forest.tres")
	_assert_text_file_source_free("res://scripts/terrain/field/CliffDressing.gd")
	_assert_text_file_source_free("res://scripts/terrain/field/FieldTerrainStreamer.gd")
	_assert_text_file_source_free("res://scripts/terrain/tools/SlopeAtlas.gd")

func test_bake_preserves_legacy_scale_and_normalises_new_pack_scale() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var cache := EnvironmentRenderCache.new(catalog)
	var expected_scale := {
		&"kaykit.bush.01": 4.0,
		&"kaykit.grass.01": 1.0,
		&"kaykit.rock.01": 3.0,
		&"kaykit.tree.01": 2.5,
		&"lpfv.tree.01": 3.25,
		&"lpfv.mushroom.01": 3.25,
		&"sfv.lily_pad.02": 1.5,
	}
	for asset_id: StringName in expected_scale:
		var scale := cache.visual(asset_id).pieces[0].local_transform.basis.get_scale()
		assert_almost_eq(scale.x, expected_scale[asset_id], 0.0001, String(asset_id))
		assert_almost_eq(scale.y, expected_scale[asset_id], 0.0001, String(asset_id))
		assert_almost_eq(scale.z, expected_scale[asset_id], 0.0001, String(asset_id))
	assert_gt(catalog.descriptor(&"lpfv.tree.01").measured_aabb.size.y, 16.0,
		"new trees share the established world scale instead of reading as miniatures")

func test_structural_visuals_carry_baked_collision_without_polluting_metadata() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var cache := EnvironmentRenderCache.new(catalog)
	for asset_id: StringName in [&"kaykit.tree.01", &"kaykit.rock.01",
			&"lpfv.tree.01", &"lpfv.big_rock.01", &"lpfv.log.01"]:
		var descriptor := catalog.descriptor(asset_id)
		var visual := cache.visual(asset_id)
		assert_gt(descriptor.collision_piece_count, 0, "%s advertises collision" % asset_id)
		assert_eq(visual.collisions.size(), descriptor.collision_piece_count)
		for collision: EnvironmentCollisionPiece in visual.collisions:
			assert_not_null(collision.shape)
			assert_true(collision.local_transform.is_finite())
	assert_eq(catalog.descriptor(&"kaykit.bush.01").collision_piece_count, 0)
	assert_true(cache.visual(&"kaykit.bush.01").collisions.is_empty())

func test_every_rigid_nature_asset_has_only_simple_convex_collision() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var cache := EnvironmentRenderCache.new(catalog)
	assert_true(cache.prepare(catalog.ids()))
	var rigid_tags: Array[StringName] = [&"tree", &"rock", &"deadwood"]
	for asset_id: StringName in catalog.ids():
		var descriptor := catalog.descriptor(asset_id)
		var is_rigid := false
		for tag: StringName in rigid_tags:
			is_rigid = is_rigid or descriptor.tags.has(tag)
		if not is_rigid:
			continue
		var visual := cache.visual(asset_id)
		assert_gt(visual.collisions.size(), 0,
			"rigid nature asset %s cannot silently lose collision" % asset_id)
		for collision: EnvironmentCollisionPiece in visual.collisions:
			var shape := collision.shape
			assert_true(shape is ConvexPolygonShape3D or shape is BoxShape3D \
				or shape is CapsuleShape3D or shape is CylinderShape3D \
				or shape is SphereShape3D,
				"%s uses only a simple convex shape, never trimesh collision" % asset_id)

func test_new_pack_rigid_assets_use_one_shape_per_rigid_component() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var cache := EnvironmentRenderCache.new(catalog)
	var rigid_tags: Array[StringName] = [&"tree", &"rock", &"deadwood"]
	var rock_clusters := {
		&"lpfv.rock.07": 2,
		&"lpfv.rock.08": 2,
		&"lpfv.rock.09": 2,
		&"lpfv.tree.02": 4,
	}
	for asset_id: StringName in catalog.ids():
		if not String(asset_id).begins_with("lpfv."):
			continue
		var descriptor := catalog.descriptor(asset_id)
		var is_rigid := false
		for tag: StringName in rigid_tags:
			is_rigid = is_rigid or descriptor.tags.has(tag)
		if not is_rigid:
			continue
		var expected_count := int(rock_clusters.get(asset_id, 1))
		assert_eq(cache.visual(asset_id).collisions.size(), expected_count,
			"%s uses its reviewed primitive assembly" % asset_id)

func test_lpfv_tree_collisions_are_close_fitting_lower_trunk_capsules() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var cache := EnvironmentRenderCache.new(catalog)
	for tree_index in 9:
		var asset_id := StringName("lpfv.tree.%02d" % (tree_index + 1))
		var visual := cache.visual(asset_id)
		var expected_count := 4 if asset_id == &"lpfv.tree.02" else 1
		assert_eq(visual.collisions.size(), expected_count,
			"%s uses only its reviewed lower-trunk capsule assembly" % asset_id)
		for collision: EnvironmentCollisionPiece in visual.collisions:
			assert_true(collision.shape is CapsuleShape3D,
				"%s uses smooth close-fitting lower-trunk primitives" % asset_id)
			if not collision.shape is CapsuleShape3D:
				continue
			var capsule := collision.shape as CapsuleShape3D
			var scale := collision.local_transform.basis.get_scale().x
			assert_gte(capsule.radius * scale,
				catalog.descriptor(asset_id).measured_aabb.size.y * 0.012,
				"%s lower-trunk collider cannot collapse to a line" % asset_id)
	for asset_id: StringName in [&"lpfv.tree.03", &"lpfv.tree.09"]:
		var visual := cache.visual(asset_id)
		var collision: EnvironmentCollisionPiece = visual.collisions[0]
		var collision_bounds := collision.local_transform \
			* collision.shape.get_debug_mesh().get_aabb()
		assert_lte(collision_bounds.size.y,
			catalog.descriptor(asset_id).measured_aabb.size.y * 0.23,
			"%s stops below its first major fork" % asset_id)
	var tree_two_visual := cache.visual(&"lpfv.tree.02")
	var tree_two_bounds := AABB()
	var tree_two_piece_bounds: Array[AABB] = []
	for collision: EnvironmentCollisionPiece in tree_two_visual.collisions:
		var piece_bounds := collision.local_transform \
			* collision.shape.get_debug_mesh().get_aabb()
		tree_two_bounds = piece_bounds if tree_two_piece_bounds.is_empty() \
			else tree_two_bounds.merge(piece_bounds)
		tree_two_piece_bounds.append(piece_bounds)
	assert_lte(tree_two_bounds.size.y,
		catalog.descriptor(&"lpfv.tree.02").measured_aabb.size.y * 0.4,
		"tree 2 covers its broad lower trunk without reaching the canopy fork")
	assert_gte(tree_two_bounds.size.x, 1.8,
		"tree 2 collider remains substantial relative to its broad trunk")
	var capsule_axis_ends: Array[Array] = []
	for collision: EnvironmentCollisionPiece in tree_two_visual.collisions:
		var capsule := collision.shape as CapsuleShape3D
		var cap_offset := capsule.height * 0.5 - capsule.radius
		capsule_axis_ends.append([
			collision.local_transform * Vector3(0.0, -cap_offset, 0.0),
			collision.local_transform * Vector3(0.0, cap_offset, 0.0),
		])
	for joint_index in capsule_axis_ends.size() - 1:
		var lower_end := capsule_axis_ends[joint_index][1] as Vector3
		var upper_start := capsule_axis_ends[joint_index + 1][0] as Vector3
		assert_almost_eq(lower_end.distance_to(upper_start), 0.0, 0.001,
			"tree 2 capsules share the exact same cap centre at each joint")

func test_new_pack_collision_never_strays_far_outside_the_visible_asset() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var cache := EnvironmentRenderCache.new(catalog)
	var rigid_tags: Array[StringName] = [&"tree", &"rock", &"deadwood"]
	for asset_id: StringName in catalog.ids():
		if not String(asset_id).begins_with("lpfv."):
			continue
		var descriptor := catalog.descriptor(asset_id)
		var is_rigid := false
		for tag: StringName in rigid_tags:
			is_rigid = is_rigid or descriptor.tags.has(tag)
		if not is_rigid:
			continue
		for collision: EnvironmentCollisionPiece in cache.visual(asset_id).collisions:
			var collision_bounds := collision.local_transform \
				* collision.shape.get_debug_mesh().get_aabb()
			var visual_bounds := descriptor.measured_aabb
			var tolerance := maxf(0.06, maxf(visual_bounds.size.x,
				maxf(visual_bounds.size.y, visual_bounds.size.z)) * 0.03)
			for axis in 3:
				assert_gte(collision_bounds.position[axis],
					visual_bounds.position[axis] - tolerance,
					"%s collider starts outside visible axis %d" % [asset_id, axis])
				assert_lte(collision_bounds.end[axis], visual_bounds.end[axis] + tolerance,
					"%s collider ends outside visible axis %d" % [asset_id, axis])

func test_lpfv_logs_use_one_flat_ended_rotated_cylinder() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var cache := EnvironmentRenderCache.new(catalog)
	for log_index in 3:
		var asset_id := StringName("lpfv.log.%02d" % (log_index + 1))
		var visual := cache.visual(asset_id)
		assert_eq(visual.collisions.size(), 1)
		assert_true(visual.collisions[0].shape is CylinderShape3D,
			"%s has flat ends and no capsule overhang" % asset_id)
		var axis := visual.collisions[0].local_transform.basis.y.normalized()
		assert_lt(absf(axis.y), 0.5,
			"%s rotates the cylinder onto the fallen log instead of leaving it upright" % asset_id)

func test_fallen_branch_uses_one_rotated_smooth_capsule() -> void:
	var cache := EnvironmentRenderCache.new(EnvironmentCatalog.load_default())
	var collision: EnvironmentCollisionPiece = cache.visual(&"lpfv.branch.01").collisions[0]
	assert_true(collision.shape is CapsuleShape3D)
	assert_lt(absf(collision.local_transform.basis.y.normalized().y), 0.5,
		"the branch capsule follows the mesh's long axis")

func test_stumps_are_flat_topped_cylinders_aligned_to_the_visible_cut() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var cache := EnvironmentRenderCache.new(catalog)
	for stump_index in 4:
		var asset_id := StringName("lpfv.stump.%02d" % (stump_index + 1))
		var descriptor := catalog.descriptor(asset_id)
		var visual := cache.visual(asset_id)
		assert_eq(visual.collisions.size(), 1, "%s needs one simple collider" % asset_id)
		var collision: EnvironmentCollisionPiece = visual.collisions[0]
		assert_true(collision.shape is CylinderShape3D,
			"%s has a genuinely flat walkable top" % asset_id)
		if collision.shape is CylinderShape3D:
			var cylinder := collision.shape as CylinderShape3D
			var top := collision.local_transform * Vector3(0.0, cylinder.height * 0.5, 0.0)
			assert_lte(top.y, descriptor.measured_aabb.end.y + 0.01,
				"%s collider cannot rise above the visible asset" % asset_id)
			if stump_index < 2:
				assert_almost_eq(top.y, descriptor.measured_aabb.end.y, 0.03,
					"%s collider top matches the undecorated cut" % asset_id)
			else:
				assert_lt(top.y, descriptor.measured_aabb.end.y - 0.1,
					"%s ignores grass above the walkable wood cut" % asset_id)

func test_rock_colliders_cannot_end_in_a_single_point() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var cache := EnvironmentRenderCache.new(catalog)
	for asset_id: StringName in catalog.ids():
		if not String(asset_id).begins_with("lpfv.") \
			or not String(asset_id).contains("rock"):
			continue
		var visual := cache.visual(asset_id)
		assert_gt(visual.collisions.size(), 0, "%s has solid collision" % asset_id)
		for collision: EnvironmentCollisionPiece in visual.collisions:
			assert_true(collision.shape is BoxShape3D \
				or collision.shape is ConvexPolygonShape3D,
				"%s is a close box or a flattened convex rock" % asset_id)
			if collision.shape is ConvexPolygonShape3D:
				var points := (collision.shape as ConvexPolygonShape3D).points
				var top_y := -INF
				for point: Vector3 in points:
					top_y = maxf(top_y, (collision.local_transform * point).y)
				var top_points := 0
				for point: Vector3 in points:
					if absf((collision.local_transform * point).y - top_y) <= 0.01:
						top_points += 1
				assert_gte(top_points, 3,
					"%s has a planar top face instead of a physics spike" % asset_id)
	var second_kaykit_rock := cache.visual(&"kaykit.rock.02").collisions[0]
	assert_true(second_kaykit_rock.shape is ConvexPolygonShape3D,
		"KayKit rock 2 replaces the oversized authored sphere with a fitted hull")
	var kaykit_points := (second_kaykit_rock.shape as ConvexPolygonShape3D).points
	var kaykit_top := -INF
	for point: Vector3 in kaykit_points:
		kaykit_top = maxf(kaykit_top,
			(second_kaykit_rock.local_transform * point).y)
	var kaykit_top_points := 0
	for point: Vector3 in kaykit_points:
		if absf((second_kaykit_rock.local_transform * point).y - kaykit_top) <= 0.01:
			kaykit_top_points += 1
	assert_gte(kaykit_top_points, 3, "KayKit rock 2 also has a planar top face")

func test_walkover_colliders_stay_below_the_character_step_at_largest_spawn_scale() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var cache := EnvironmentRenderCache.new(catalog)
	var dressing_index := load("res://terrain/dressing/index.tres") as DressingCatalogIndex
	var max_spawn_scale_by_asset: Dictionary = {}
	for dressing_set: DressingSet in dressing_index.sets:
		for choice: DressingChoice in dressing_set.choices:
			var spawn_scale := dressing_set.scale_range.y * choice.scale_multiplier
			max_spawn_scale_by_asset[choice.asset_id] = maxf(spawn_scale,
				float(max_spawn_scale_by_asset.get(choice.asset_id, 0.0)))
	for asset_id: StringName in catalog.ids():
		var descriptor := catalog.descriptor(asset_id)
		if not descriptor.tags.has(&"walkover"):
			continue
		assert_true(max_spawn_scale_by_asset.has(asset_id),
			"walk-over asset %s is exercised by an active population" % asset_id)
		var bottom := INF
		var top := -INF
		for collision: EnvironmentCollisionPiece in cache.visual(asset_id).collisions:
			var bounds := collision.local_transform \
				* collision.shape.get_debug_mesh().get_aabb()
			bottom = minf(bottom, bounds.position.y)
			top = maxf(top, bounds.end.y)
		var largest_height := (top - bottom) * float(max_spawn_scale_by_asset[asset_id])
		assert_lte(largest_height, CharacterMovement.DEFAULT_MAX_STEP_HEIGHT,
			"%s remains step-able at its largest authored instance scale" % asset_id)

func test_reviewed_kaykit_colliders_preserve_the_primitive_policy() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var cache := EnvironmentRenderCache.new(catalog)
	var first_rock := cache.visual(&"kaykit.rock.01")
	assert_eq(first_rock.collisions.size(), 3,
		"the first rock preserves the user's authored proxy")
	for collision: EnvironmentCollisionPiece in first_rock.collisions:
		assert_true(collision.shape is CylinderShape3D,
			"the restored first-rock proxy keeps its authored cylinders")
	for asset_id: StringName in catalog.ids():
		if not String(asset_id).begins_with("kaykit.tree") \
				and not String(asset_id).begins_with("kaykit.rock"):
			continue
		var visual := cache.visual(asset_id)
		assert_gt(visual.collisions.size(), 0)
		if String(asset_id).begins_with("kaykit.rock"):
			assert_lte(visual.collisions.size(), 8,
				"the reviewed rock primitive mix remains bounded")
		else:
			assert_eq(visual.collisions.size(), 1,
				"the restored authored tree uses one snag-free trunk proxy")
			assert_true(visual.collisions[0].shape is CapsuleShape3D,
				"%s preserves the original smooth capsule" % asset_id)
		var expected_scale := 2.5 if String(asset_id).begins_with("kaykit.tree") else 3.0
		for collision: EnvironmentCollisionPiece in cache.visual(asset_id).collisions:
			assert_true(collision.shape is ConvexPolygonShape3D \
				or collision.shape is BoxShape3D or collision.shape is CylinderShape3D \
				or collision.shape is CapsuleShape3D or collision.shape is SphereShape3D,
				"existing rigid assets preserve the reviewed primitive mix")
			var scale := collision.local_transform.basis.get_scale()
			assert_almost_eq(scale.x, expected_scale, 0.0001,
				"%s collision keeps its legacy wrapper scale" % asset_id)
			assert_almost_eq(scale.y, expected_scale, 0.0001,
				"%s collision keeps its legacy wrapper scale" % asset_id)
			assert_almost_eq(scale.z, expected_scale, 0.0001,
				"%s collision keeps its legacy wrapper scale" % asset_id)

func _scan_text_tree_for_source_paths(root: String) -> void:
	var directory := DirAccess.open(root)
	assert_not_null(directory, "runtime root exists: %s" % root)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var path := root.path_join(entry)
		if directory.current_is_dir():
			if not entry.begins_with("."):
				_scan_text_tree_for_source_paths(path)
		elif entry.get_extension() in ["gd", "tres", "tscn", "godot"]:
			_assert_text_file_source_free(path)
		entry = directory.get_next()
	directory.list_dir_end()

func _assert_text_file_source_free(path: String) -> void:
	assert_false(FileAccess.get_file_as_string(path).contains("res://assets/"),
		"environment runtime is source-pack independent: %s" % path)
