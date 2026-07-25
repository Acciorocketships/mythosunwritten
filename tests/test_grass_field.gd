extends GutTest

const TILE := Vector2i.ZERO
const CORE := Rect2(Vector2.ZERO, Vector2.ONE * GrassField.TILE_WORLD)

func _program() -> GrassProgram:
	var settings := load("res://terrain/grass/settings.tres") as GrassSettings
	var catalog := EnvironmentCatalog.load_default()
	var cache := EnvironmentRenderCache.new(catalog)
	return GrassProgram.compile(settings, catalog, cache)

func _settings_copy() -> GrassSettings:
	return (load("res://terrain/grass/settings.tres") as GrassSettings).duplicate(true)

func _dry_context(region: HeightfieldRegion, coverage: Rect2,
		shore_limit: float) -> WaterFieldContext:
	var context := WaterFieldContext.new()
	context._ctx = {"ponds": [], "rivers": [], "buckets": {}, "region": region}
	context._region = region
	context._coverage = coverage
	context._shore_limit = shore_limit
	context._shore_curves_ready = true
	return context

func _flat_inputs(program: GrassProgram) -> Dictionary:
	var plan := HeightfieldPlan.new(4242, 1.0, 1, "mean")
	var region := plan.compute_region(4, 4, 12)
	var water := _dry_context(region, CORE.grow(4.0),
		program.shore_distance_limit)
	return {"region": region, "water": water}

func test_compiler_keeps_the_baked_asset_in_resource_free_metadata() -> void:
	var program := _program()
	assert_not_null(program)
	assert_eq(program.grass_seed_version, 3,
		"the deliberate broad-patch lattice reshuffle has its own seed version")
	assert_eq(program.variant_asset_ids,
		[&"stylized_grass.collection_05"])
	assert_eq(program.referenced_asset_ids.size(), 1)
	for asset_id: StringName in program.referenced_asset_ids:
		var metadata: Dictionary = program.assets[asset_id]
		assert_false(_contains_resource(metadata),
			"worker metadata contains no render resource: %s" % asset_id)
		var bounds: AABB = metadata.descriptor_aabb
		assert_between(bounds.size.y, 1.17, 1.18,
			"the authored patch bakes to the reviewed standing scale")
		assert_gt(maxf(bounds.size.x, bounds.size.z), 3.0,
			"the bake spreads blade roots beyond the source clump")
		assert_gt(float(metadata.footprint_radius), 1.0,
			"path qualification owns the broad Collection 5 footprint, not only its root")
		assert_false(bool(metadata.has_albedo_texture),
			"Collection 5's value structure comes from blade normals, not a texture")

func test_baked_collection_5_is_one_1244_triangle_runtime_mesh() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var cache := EnvironmentRenderCache.new(catalog)
	var asset_id := &"stylized_grass.collection_05"
	assert_true(cache.prepare([asset_id]))
	var visual := cache.visual(asset_id)
	assert_not_null(visual)
	assert_eq(visual.pieces.size(), 1)
	var mesh: ArrayMesh = visual.pieces[0].mesh
	assert_not_null(mesh)
	assert_eq(mesh.get_surface_count(), 1)
	var arrays := mesh.surface_get_arrays(0)
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var roots: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	assert_eq(indices.size() / 3, 1244,
		"the bake preserves all 311 blades with four triangles per ribbon")
	assert_eq(roots.size(), vertices.size(),
		"every retained vertex carries its blade's stable local root")
	assert_eq(roots.size(), 311 * 6)
	var roots_are_shared_per_blade := true
	var unique_roots: Dictionary = {}
	for blade_index in 311:
		var root := roots[blade_index * 6]
		unique_roots[root] = true
		for vertex_offset in range(1, 6):
			roots_are_shared_per_blade = roots_are_shared_per_blade \
				and roots[blade_index * 6 + vertex_offset] == root
	assert_true(roots_are_shared_per_blade,
		"one trample coordinate is shared by one blade, not the whole patch")
	assert_gte(unique_roots.size(), 200,
		"authored blade groups retain local roots instead of one patch-wide sample")
	for dependency: String in ResourceLoader.get_dependencies(
			catalog.descriptor(asset_id).visual_path):
		assert_false(dependency.contains("res://assets/Grass/"),
			"runtime visuals remain independent of ignored source-pack files")

func test_compiler_rejects_invalid_authored_settings() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var cache := EnvironmentRenderCache.new(catalog)
	var settings := _settings_copy()
	settings.coverage_by_biome.erase(&"meadow")
	assert_null(GrassProgram.compile(settings, catalog, cache))
	assert_push_error("exactly the canonical biome IDs")

	settings = _settings_copy()
	settings.scale_range = Vector2(1.2, 0.8)
	assert_null(GrassProgram.compile(settings, catalog, cache))
	assert_push_error("finite, ordered, and positive")

	settings = _settings_copy()
	settings.variant_asset_ids.append(settings.variant_asset_ids[0])
	assert_null(GrassProgram.compile(settings, catalog, cache))
	assert_push_error("must be non-empty and unique")

func test_projected_smooth_fields_are_bit_identical_on_tile_seams() -> void:
	var program := _program()
	var left := GrassField._bake_tile_fields(program, Vector2.ZERO, 4242)
	var right := GrassField._bake_tile_fields(program,
		Vector2(GrassField.TILE_WORLD, 0.0), 4242)
	for z in GrassField.FIELD_SIDE:
		var a: Dictionary = left[z * GrassField.FIELD_SIDE + GrassField.FIELD_SIDE - 1]
		var b: Dictionary = right[z * GrassField.FIELD_SIDE]
		assert_eq(a, b, "world-aligned projection agrees across the tile seam")

func test_carpet_curve_preserves_empty_ground_and_saturates_viable_habitat() -> void:
	assert_eq(GrassField.carpet_coverage(0.0), 0.0)
	assert_eq(GrassField.carpet_coverage(GrassField.CARPET_EDGE_LOW), 0.0)
	assert_eq(GrassField.carpet_coverage(GrassField.CARPET_EDGE_HIGH), 1.0)
	assert_eq(GrassField.carpet_coverage(1.0), 1.0)
	assert_eq(GrassField.carpet_coverage(0.19), 0.0,
		"weak habitat cannot linger as isolated repeated patches")
	assert_gt(GrassField.carpet_coverage(0.45), 0.7,
		"open marsh habitat becomes a closed carpet")
	assert_eq(GrassField._coverage_edge_scale(0.0),
		GrassField.COVERAGE_EDGE_MIN_SCALE)
	assert_almost_eq(GrassField._coverage_edge_scale(1.0), 1.0, 0.0001)
	assert_between(GrassField._coverage_edge_scale(0.5),
		GrassField.COVERAGE_EDGE_MIN_SCALE, 1.0,
		"all ecological bed margins use the same proportional scale taper")

func test_field_is_deterministic_grounded_and_capped_at_one_batch() -> void:
	var program := _program()
	var inputs := _flat_inputs(program)
	var a := GrassField.compute(program, 4242, TILE, inputs.region, inputs.water)
	var b := GrassField.compute(program, 4242, TILE, inputs.region, inputs.water)
	assert_true(a.validate())
	assert_eq(a.asset_ids(), b.asset_ids())
	assert_lte(a.batches.size(), 1)
	assert_gt(a.instance_count, 0)
	for asset_id: StringName in a.asset_ids():
		var batch: Dictionary = a.batches[asset_id]
		assert_true(batch.buffer == b.batches[asset_id].buffer,
			"the packed output is bit-identical")
		var count: int = batch.count
		var ranks_are_exact := true
		var every_instance_is_grounded := true
		for index in count:
			var offset := index * GrassPayload.FLOATS_PER_INSTANCE
			var rank: float = batch.buffer[offset + 17]
			ranks_are_exact = ranks_are_exact and is_equal_approx(rank,
				float(index) / float(count))
			var x: float = batch.buffer[offset + 3]
			var y: float = batch.buffer[offset + 7]
			var z: float = batch.buffer[offset + 11]
			every_instance_is_grounded = every_instance_is_grounded \
				and x >= CORE.position.x and x < CORE.end.x \
				and z >= CORE.position.y and z < CORE.end.y \
				and absf(y - TerrainSurfaceField.surface_y(
					inputs.region, x, z)) <= 0.001
		assert_true(ranks_are_exact, "dropout ranks follow packed sort order")
		assert_true(every_instance_is_grounded,
			"every packed origin lies in the tile and on the field")

func test_dropout_rank_is_an_exact_nested_prefix() -> void:
	var program := _program()
	var inputs := _flat_inputs(program)
	var payload := GrassField.compute(program, 4242, TILE,
		inputs.region, inputs.water)
	for asset_id: StringName in payload.asset_ids():
		var batch: Dictionary = payload.batches[asset_id]
		var count: int = batch.count
		for density: float in [0.0, 0.01, 0.2, 0.5, 0.999, 1.0]:
			var visible := 0
			for index in count:
				if batch.buffer[index * GrassPayload.FLOATS_PER_INSTANCE + 17] < density:
					visible += 1
			assert_eq(visible, int(ceil(count * density)))

func test_path_reservation_removes_the_carpet_without_special_case_stamps() -> void:
	var program := _program()
	var inputs := _flat_inputs(program)
	var paths := PathContext.new(CORE, [CORE], [CORE],
		EnvironmentInstancePayload.new(), GrassProgram.FEATURE_CLEARANCE)
	var payload := GrassField.compute(program, 4242, TILE,
		inputs.region, inputs.water, paths)
	assert_eq(payload.instance_count, 0)

func test_path_corridor_rejects_the_complete_patch_footprint() -> void:
	var program := _program()
	var inputs := _flat_inputs(program)
	var corridor := Rect2(Vector2(10.0, -4.0), Vector2(4.0, 32.0))
	var paths := PathContext.new(CORE, [corridor], [],
		EnvironmentInstancePayload.new(), GrassProgram.FEATURE_CLEARANCE)
	var payload := GrassField.compute(program, 4242, TILE,
		inputs.region, inputs.water, paths)
	assert_gt(payload.instance_count, 0, "only the path shoulder is cleared")
	for asset_id: StringName in payload.asset_ids():
		var asset: Dictionary = program.assets[asset_id]
		var piece_scale := (asset.piece_transform as Transform3D).basis.get_scale().x
		var batch: Dictionary = payload.batches[asset_id]
		for index in int(batch.count):
			var offset := index * GrassPayload.FLOATS_PER_INSTANCE
			var x: float = batch.buffer[offset + 3]
			var final_basis := Basis(
				Vector3(batch.buffer[offset], batch.buffer[offset + 4],
					batch.buffer[offset + 8]),
				Vector3(batch.buffer[offset + 1], batch.buffer[offset + 5],
					batch.buffer[offset + 9]),
				Vector3(batch.buffer[offset + 2], batch.buffer[offset + 6],
					batch.buffer[offset + 10]))
			var placement_scale := final_basis.get_scale().x / piece_scale
			var actual_radius := float(asset.footprint_radius) * placement_scale \
				+ GrassField.PATH_FOOTPRINT_CLEARANCE
			assert_true(x + actual_radius <= corridor.position.x \
					or x - actual_radius >= corridor.end.x,
				"no authored blade footprint reaches over the rendered path")

func test_slope_surface_returns_normal_and_area_compensation() -> void:
	var program := _program()
	var storeys: Dictionary = {Vector2i.ZERO: 1}
	var region := HeightfieldRegion.new(storeys, {})
	var water := _dry_context(region, CORE.grow(4.0),
		program.shore_distance_limit)
	var sample := GrassField._qualified_surface(program, Vector2(6.0, 0.0),
		region, water, null, 1.0, {})
	assert_false(sample.is_empty())
	var normal: Vector3 = sample.normal
	assert_lt(normal.y, 0.999, "ordinary ramp grass follows a real hill normal")
	assert_gt(float(sample.area_extra), 0.0,
		"projected lattice adds the hill's missing surface area")
	var basis := GrassField._surface_basis(normal)
	assert_almost_eq(basis.y.dot(normal), 1.0, 0.0001,
		"instance local up is the terrain normal")
	assert_almost_eq(basis.determinant(), 1.0, 0.0001,
		"the surface frame remains an orthonormal rotation")

func test_slopes_receive_more_patches_than_the_same_flat_habitat() -> void:
	var program := _program()
	var flat := HeightfieldRegion.new({}, {})
	var slope := HeightfieldRegion.new({Vector2i.ZERO: 1}, {})
	var flat_water := _dry_context(flat, CORE.grow(4.0),
		program.shore_distance_limit)
	var slope_water := _dry_context(slope, CORE.grow(4.0),
		program.shore_distance_limit)
	var flat_payload := GrassField.compute(program, 4242, TILE, flat, flat_water)
	var slope_payload := GrassField.compute(program, 4242, TILE, slope, slope_water)
	assert_gt(slope_payload.instance_count, flat_payload.instance_count,
		"surface-area lattice supplies additional anchors on the ordinary ramp")

func test_exposed_cliff_lip_reduces_the_uniform_patch_scale() -> void:
	var region := HeightfieldRegion.new({Vector2i.ZERO: 3}, {})
	var footprint_radius := 1.4
	var centre_scale := GrassField._cliff_scale(
		region, Vector2.ZERO, footprint_radius)
	var lip_scale := GrassField._cliff_scale(
		region, Vector2(11.0, 0.0), footprint_radius)
	var lower_side_scale := GrassField._cliff_scale(
		region, Vector2(13.0, 0.0), footprint_radius)
	assert_almost_eq(centre_scale, 1.0, 0.0001)
	assert_almost_eq(lip_scale, GrassField.CLIFF_EDGE_MIN_SCALE, 0.0001)
	assert_almost_eq(lower_side_scale, 1.0, 0.0001,
		"the cliff foot remains the ordinary carpet and meets the wall")
	assert_lt(lip_scale, centre_scale,
		"upper ledge patches become proportionally smaller toward the wall")
	assert_almost_eq(1.0 + GrassField._density_extra(lip_scale, 0.0),
		1.0 / (lip_scale * lip_scale), 0.0001,
		"the reviewed lip scale receives exact inverse-area compensation")
	assert_almost_eq(1.0 + GrassField._density_extra(0.8, 0.25),
		1.25 / (0.8 * 0.8), 0.0001,
		"moderate slope and edge compensation still compose exactly")
	assert_almost_eq(1.0 + GrassField._density_extra(0.5, 0.25),
		GrassField.MAX_DENSITY_MULTIPLIER, 0.0001,
		"extreme combined compensation stops at the shared visual bound")
	assert_eq(GrassField._supplement_weight(2.4, 1), 1.0)
	assert_eq(GrassField._supplement_weight(2.4, 2), 1.0)
	assert_almost_eq(GrassField._supplement_weight(2.4, 3), 0.4, 0.0001)
	assert_eq(GrassField._supplement_weight(2.4, 4), 0.0)

func test_cliff_footprint_reaches_the_wall_without_a_clearance_band() -> void:
	var program := _program()
	var region := HeightfieldRegion.new({Vector2i.ZERO: 3}, {})
	var water := _dry_context(region, CORE.grow(4.0),
		program.shore_distance_limit)
	var near_wall := GrassField._qualified_surface(program,
		Vector2(13.0, 0.0), region, water, null, 1.4)
	var almost_touching_lower := GrassField._qualified_surface(program,
		Vector2(12.2, 0.0), region, water, null, 1.4)
	var almost_touching_upper := GrassField._qualified_surface(program,
		Vector2(11.8, 0.0), region, water, null, 1.4)
	var sub_blade_remnant := GrassField._qualified_surface(program,
		Vector2(11.9, 0.0), region, water, null, 1.4)
	assert_false(near_wall.is_empty(),
		"lower grass no longer reserves a complete patch-width band")
	assert_false(almost_touching_lower.is_empty(),
		"lower grass retains its ordinary patch and reaches the opaque wall")
	assert_false(almost_touching_upper.is_empty(),
		"the same continuous rule reaches the upper lip")
	assert_true(sub_blade_remnant.is_empty(),
		"only a sub-10%-scale remnant is discarded at the exact boundary")
	for sample: Dictionary in [near_wall, almost_touching_lower,
			almost_touching_upper]:
		assert_almost_eq((sample.normal as Vector3).y, 1.0, 0.0001,
			"a vertical discontinuity does not become a false terrain grade")
	assert_almost_eq(float(almost_touching_lower.physical_edge_scale),
		1.0, 0.0001,
		"the lower side does not become a visible clearance band")
	var final_radius := 1.4 * float(almost_touching_upper.physical_edge_scale)
	assert_lte(final_radius + GrassField.CLIFF_FOOTPRINT_MARGIN, 0.2001,
		"the final broad patch fits its own side instead of crossing the wall")

func test_cliff_lip_supplements_are_dense_but_bounded() -> void:
	var program := _program()
	var flat := HeightfieldRegion.new({}, {})
	var cliff := HeightfieldRegion.new({Vector2i.ZERO: 3}, {})
	var flat_water := _dry_context(flat, CORE.grow(4.0),
		program.shore_distance_limit)
	var cliff_water := _dry_context(cliff, CORE.grow(4.0),
		program.shore_distance_limit)
	var flat_payload := GrassField.compute(program, 4242, TILE, flat, flat_water)
	var cliff_payload := GrassField.compute(program, 4242, TILE, cliff, cliff_water)
	assert_gt(cliff_payload.instance_count, flat_payload.instance_count,
		"the narrow cliff-top strip gains patches as each patch becomes smaller")

func test_packed_instance_matches_godot_multimesh_layout() -> void:
	var transform := Transform3D(Basis(Vector3.UP, 0.73).scaled(Vector3.ONE * 1.17),
		Vector3(4.0, 5.0, 6.0))
	var color := Color(0.2, 0.3, 0.4, 0.5)
	var custom := Color(1.2, 0.25, 0.0, 0.0)
	var buffer := PackedFloat32Array()
	buffer.resize(GrassPayload.FLOATS_PER_INSTANCE)
	GrassField._write_instance(buffer, 0, transform, color, custom.r, custom.g)
	var expected := PackedFloat32Array([
		transform.basis.x.x, transform.basis.y.x, transform.basis.z.x,
		transform.origin.x,
		transform.basis.x.y, transform.basis.y.y, transform.basis.z.y,
		transform.origin.y,
		transform.basis.x.z, transform.basis.y.z, transform.basis.z.z,
		transform.origin.z,
		color.r, color.g, color.b, color.a,
		custom.r, custom.g, custom.b, custom.a,
	])
	assert_eq(buffer, expected)

func test_worker_field_has_no_render_or_resource_loading_calls() -> void:
	var source := FileAccess.get_file_as_string(
		"res://scripts/terrain/grass/GrassField.gd")
	for forbidden: String in ["load(", "preload(", "RenderingServer",
			"MultiMesh", "MeshInstance3D", "ArrayMesh", "ImageTexture"]:
		assert_false(source.contains(forbidden),
			"pure GrassField must not reference %s" % forbidden)

static func _contains_resource(value: Variant) -> bool:
	if value is Resource or value is Node or value is Mesh or value is Material \
			or value is Texture2D or value is PackedScene or value is Shape3D:
		return true
	if value is Array:
		for item: Variant in value:
			if _contains_resource(item):
				return true
	elif value is Dictionary:
		for item: Variant in value.values():
			if _contains_resource(item):
				return true
	return false
