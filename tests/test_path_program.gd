extends GutTest

func _contains_resource(value: Variant) -> bool:
	if value is Resource:
		return true
	if value is Array:
		for child: Variant in value:
			if _contains_resource(child):
				return true
	elif value is Dictionary:
		for child: Variant in value.values():
			if _contains_resource(child):
				return true
	elif value is PathProgram:
		return _contains_resource((value as PathProgram).assets)
	return false

func _catalog_without(asset_id: StringName) -> EnvironmentCatalog:
	var source := load(EnvironmentCatalog.DEFAULT_INDEX_PATH) as EnvironmentCatalogIndex
	var index := EnvironmentCatalogIndex.new()
	for descriptor: EnvironmentAssetDescriptor in source.descriptors:
		if descriptor.id != asset_id:
			index.descriptors.append(descriptor)
	return EnvironmentCatalog.from_index(index)

func _catalog_with(asset_id: StringName, change: Callable) -> EnvironmentCatalog:
	var source := load(EnvironmentCatalog.DEFAULT_INDEX_PATH) as EnvironmentCatalogIndex
	var index := EnvironmentCatalogIndex.new()
	for descriptor: EnvironmentAssetDescriptor in source.descriptors:
		var copied := descriptor.duplicate(true) as EnvironmentAssetDescriptor
		if copied.id == asset_id:
			change.call(copied)
		index.descriptors.append(copied)
	return EnvironmentCatalog.from_index(index)

func test_compiles_sorted_resource_free_feature_metrics() -> void:
	var program := PathProgram.compile(EnvironmentCatalog.load_default())
	assert_not_null(program)
	assert_eq(program.referenced_asset_ids, PathProgram.ASSET_IDS)
	assert_false(_contains_resource(program))
	assert_eq(program.feature_halo, 1)
	assert_eq(program.bridge_lookahead_cells, 3)
	assert_eq(program.FIELD_CACHE_CAP, 192)
	assert_eq(program.CONTEXT_CACHE_CAP, 96)
	assert_almost_eq(program.bridge.usable_span, 57.6, 0.001)
	assert_almost_eq(program.bridge.opening, 4.58, 0.001)
	assert_lte(program.query_margin + program.shore_distance_limit,
		WaterField.FILL_MARGIN * WaterField.FILL_STEP - WaterContour.MARGIN)
	assert_false(program.assets[&"sfv.light_pole.001"].has("light"),
		"v1 lamps are emissive-only and compile no Light3D description")

func test_missing_asset_fails_compilation() -> void:
	assert_null(PathProgram.compile(_catalog_without(&"sfv.bridge.001")))
	assert_push_error("missing: sfv.bridge.001")

func test_missing_tag_or_collision_fails_compilation() -> void:
	var catalog := _catalog_with(&"sfv.bridge.001",
		func(descriptor: EnvironmentAssetDescriptor) -> void:
			descriptor.tags.erase(&"bridge"))
	assert_null(PathProgram.compile(catalog))
	assert_push_error("lacks required feature tags")
	catalog = _catalog_with(&"sfv.bridge.001",
		func(descriptor: EnvironmentAssetDescriptor) -> void:
			descriptor.collision_piece_count = 0)
	assert_null(PathProgram.compile(catalog))
	assert_push_error("lacks finite collision/bounds")

func test_missing_metric_and_invalid_bridge_sample_fail() -> void:
	var authored := PathProgram._authored_metrics()
	authored.assets.erase(&"sfv.arch.002")
	assert_null(PathProgram.compile(EnvironmentCatalog.load_default(), authored))
	assert_push_error("lacks authored placement metrics")
	authored = PathProgram._authored_metrics()
	authored.assets[&"sfv.bridge.001"].support_samples = PackedVector3Array([
		Vector3(1000.0, 0.0, 0.0)])
	assert_null(PathProgram.compile(EnvironmentCatalog.load_default(), authored))
	assert_push_error("support_samples lies outside")

func test_invalid_metric_shape_vector_and_footprint_fail_compilation() -> void:
	var authored := PathProgram._authored_metrics()
	authored.assets[&"sfv.bridge.001"].deck_contacts = PackedVector3Array([
		Vector3(0.0, 0.18, -28.8)])
	assert_null(PathProgram.compile(EnvironmentCatalog.load_default(), authored))
	assert_push_error("deck_contacts has an invalid sample count")
	authored = PathProgram._authored_metrics()
	authored.assets[&"sfv.light_pole.001"].arm_direction = Vector2(NAN, 0.0)
	assert_null(PathProgram.compile(EnvironmentCatalog.load_default(), authored))
	assert_push_error("arm direction must be unit length")
	authored = PathProgram._authored_metrics()
	authored.assets[&"sfv.arch.001"].footprint = Rect2(Vector2(20.0, 20.0),
		Vector2.ONE)
	assert_null(PathProgram.compile(EnvironmentCatalog.load_default(), authored))
	assert_push_error("footprint lies outside measured bounds")

func test_invalid_water_margin_and_footprint_halo_fail() -> void:
	var authored := PathProgram._authored_metrics()
	authored.query_margin = 31.0
	assert_null(PathProgram.compile(EnvironmentCatalog.load_default(), authored))
	assert_push_error("water query margin exceeds")
	authored = PathProgram._authored_metrics()
	authored.assets[&"sfv.bridge.001"].footprint = Rect2(-Vector2.ONE * 250.0,
		Vector2.ONE * 500.0)
	var wide_catalog := _catalog_with(&"sfv.bridge.001",
		func(descriptor: EnvironmentAssetDescriptor) -> void:
			descriptor.measured_aabb = AABB(-Vector3(250.0, 0.0, 250.0),
				Vector3(500.0, 2.0, 500.0)))
	assert_null(PathProgram.compile(wide_catalog, authored))
	assert_push_error("footprint requires halo")

func test_manifest_uses_explicit_vector_scales() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(
		"res://tools/environment_bake/manifests/fantasy_village_features.json"))
	assert_true(parsed is Dictionary)
	assert_eq(parsed.default_scale, [2.0, 2.0, 2.0])
	for entry: Dictionary in parsed.assets:
		assert_true(entry.scale is Array)
		assert_eq(entry.scale.size(), 3)
		if entry.id != "sfv.bridge.001":
			assert_eq(entry.scale, [2.0, 2.0, 2.0])
	assert_eq(parsed.assets.filter(func(entry: Dictionary) -> bool:
		return entry.id == "sfv.bridge.001")[0].scale, [1.2, 1.0, 6.0])
	assert_eq(parsed.assets.filter(func(entry: Dictionary) -> bool:
		return entry.id == "sfv.arch.002")[0].fallback_albedo_texture,
		"res://assets/FantasyVillageFBX/SFV_TEXTURE_ORANGE.png")

func test_large_arches_have_baked_atlas_materials() -> void:
	var cache := EnvironmentRenderCache.new(EnvironmentCatalog.load_default())
	var asset_ids: Array[StringName] = [&"sfv.arch.001", &"sfv.arch.002"]
	assert_true(cache.prepare(asset_ids))
	for asset_id: StringName in asset_ids:
		var visual := cache.visual(asset_id)
		for piece: EnvironmentVisualPiece in visual.pieces:
			for surface_index in piece.mesh.get_surface_count():
				var material := piece.mesh.surface_get_material(surface_index) \
					as StandardMaterial3D
				assert_not_null(material, "%s uses a standard material" % asset_id)
				assert_not_null(material.albedo_texture,
					"%s keeps its authored colour atlas" % asset_id)

func test_collision_primitives_preserve_walkable_openings() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var cache := EnvironmentRenderCache.new(catalog)
	assert_true(cache.prepare(PathProgram.ASSET_IDS))
	var bridge := cache.visual(&"sfv.bridge.001")
	assert_eq(bridge.collisions.size(), 5)
	for collision: EnvironmentCollisionPiece in bridge.collisions:
		var bounds := collision.local_transform * collision.shape.get_debug_mesh().get_aabb()
		assert_gte(bounds.position.y, -0.05,
			"bridge collision never hangs below the deck into the channel")
	for asset_id: StringName in [&"sfv.arch.001", &"sfv.arch.002",
			&"sfv.entrance_arch.001"]:
		var opening: float = PathProgram.compile(catalog).assets[asset_id].opening
		var visual := cache.visual(asset_id)
		assert_eq(visual.collisions.size(),
			12 if asset_id != &"sfv.entrance_arch.001" else 2)
		var collision_bounds := AABB()
		var first := true
		var clear_volume := AABB(Vector3(-opening * 0.5, 0.0, -1.0),
			Vector3(opening, 2.2, 2.0))
		for collision: EnvironmentCollisionPiece in visual.collisions:
			var bounds := collision.local_transform * collision.shape.get_debug_mesh().get_aabb()
			assert_false(bounds.intersects(clear_volume),
				"arch collision leaves a character-height passage clear")
			collision_bounds = bounds if first else collision_bounds.merge(bounds)
			first = false
		if asset_id != &"sfv.entrance_arch.001":
			var visual_bounds: AABB = catalog.descriptor(asset_id).measured_aabb
			assert_gte(collision_bounds.end.y, visual_bounds.end.y - 0.1,
				"large-arch collision reaches the roof ridge")
			assert_lte(absf(collision_bounds.position.x - visual_bounds.position.x), 0.1)
			assert_lte(absf(collision_bounds.end.x - visual_bounds.end.x), 0.1)
			assert_lte(absf(collision_bounds.position.z - visual_bounds.position.z), 0.2)
			assert_lte(absf(collision_bounds.end.z - visual_bounds.end.z), 0.2)
	var pole := cache.visual(&"sfv.light_pole.001")
	assert_eq(pole.collisions.size(), 1)
	var pole_bounds := pole.collisions[0].local_transform \
		* pole.collisions[0].shape.get_debug_mesh().get_aabb()
	assert_lt(maxf(absf(pole_bounds.position.x), absf(pole_bounds.end.x)), 0.4)
	assert_lt(maxf(absf(pole_bounds.position.z), absf(pole_bounds.end.z)), 0.4)
