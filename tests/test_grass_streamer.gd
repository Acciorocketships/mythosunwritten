extends GutTest

func _program_and_cache() -> Dictionary:
	var settings := load("res://terrain/grass/settings.tres") as GrassSettings
	var catalog := EnvironmentCatalog.load_default()
	var cache := EnvironmentRenderCache.new(catalog)
	var program := GrassProgram.compile(settings, catalog, cache)
	return {"program": program, "cache": cache}

func _payload(program: GrassProgram) -> GrassPayload:
	var plan := HeightfieldPlan.new(4242, 1.0, 1, "mean")
	var region := plan.compute_region(4, 4, 12)
	var water := WaterFieldContext.new()
	water._ctx = {"ponds": [], "rivers": [], "buckets": {}, "region": region}
	water._region = region
	water._coverage = Rect2(Vector2(-4.0, -4.0), Vector2(32.0, 32.0))
	water._shore_limit = program.shore_distance_limit
	water._shore_curves_ready = true
	return GrassField.compute(program, 4242, Vector2i.ZERO, region, water)

func test_intersection_ring_has_no_square_holes_inside_the_fade() -> void:
	var tiles := GrassStreamer.desired_tiles(Vector2.ZERO)
	var expected := 0
	var reach := int(ceil(GrassStreamer.GRASS_RADIUS / GrassField.TILE_WORLD)) + 1
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			if GrassStreamer.distance_to_tile(Vector2.ZERO, Vector2i(dx, dz)) < GrassStreamer.GRASS_RADIUS:
				expected += 1
	assert_eq(tiles.size(), expected)
	assert_eq(expected, 52, "60/84 m ring (update with the default radius)")
	var requested: Dictionary = {}
	for tile: Vector2i in tiles:
		requested[tile] = true
	var all_covered := true
	var span := int(GrassStreamer.GRASS_RADIUS) + 48
	for z in range(-span, span + 1, 3):
		for x in range(-span, span + 1, 3):
			var point := Vector2(x, z)
			if point.length() >= GrassStreamer.GRASS_RADIUS:
				continue
			all_covered = all_covered and requested.has(GrassField.tile_of(point))
	assert_true(all_covered,
		"every point inside the fade belongs to a requested tile")

func test_quality_changes_restore_grass_without_rebuilding_buffers() -> void:
	var fixture := _program_and_cache()
	var grass := GrassStreamer.new(fixture.program, fixture.cache)
	assert_true(grass.has_method("set_density_scale"), "Grass quality needs a reversible render-only density control")
	if not grass.has_method("set_density_scale"): return
	var director := AtmosphereDirector.new()
	director.streamer = FieldTerrainStreamer.new()
	director.streamer._grass_streamer = grass
	director.set_quality(0)
	grass.begin_frame(Vector2(12, 12))
	var generation := grass.mark_requested(Vector2i.ZERO)
	var payload := _payload(fixture.program)
	var original := payload.batches.duplicate(true)
	assert_true(grass.accept_result(Vector2i.ZERO, generation, payload))
	var committed: Array[Dictionary] = []
	for frame in 2: committed.append_array(grass.drain_commits())
	assert_eq(committed.size(), 1)
	if committed.is_empty():
		director.streamer.free()
		director.free()
		return
	var node: Node3D = committed[0].node
	add_child_autofree(node)
	for child: MultiMeshInstance3D in node.get_children():
		var mesh := child.multimesh
		var count := mesh.instance_count
		assert_eq(mesh.visible_instance_count, GrassStreamer.visible_count(count, 0.65), "New tiles inherit economical density")
		director.set_quality(1)
		assert_same(child.multimesh, mesh, "Quality changes keep the existing GPU buffer")
		assert_eq(mesh.visible_instance_count, count, "Standard restores every near instance")
		director.set_quality(0)
		grass.begin_frame(Vector2(90, 12))
		var density := GrassStreamer.density(GrassStreamer.distance_to_tile(Vector2(90, 12), Vector2i.ZERO))
		assert_eq(mesh.visible_instance_count, GrassStreamer.visible_count(count, density * 0.65), "Moving LOD retains the quality cap")
		director.set_quality(2)
		assert_eq(mesh.visible_instance_count, GrassStreamer.visible_count(count, density), "High restores the correct moving LOD")
	assert_eq(payload.batches, original, "Rendering quality never rewrites deterministic worker payloads")
	director.streamer.free()
	director.free()

func test_density_endpoints_and_tile_distance_are_exact() -> void:
	assert_eq(GrassStreamer.density(0.0), 1.0)
	assert_eq(GrassStreamer.density(GrassStreamer.FULL_RADIUS), 1.0)
	assert_eq(GrassStreamer.density(GrassStreamer.GRASS_RADIUS), 0.0)
	assert_eq(GrassStreamer.distance_to_tile(Vector2(12.0, 12.0), Vector2i.ZERO), 0.0)
	assert_eq(GrassStreamer.distance_to_tile(Vector2(-24.0, 12.0), Vector2i.ZERO), 24.0)

func test_nearest_point_cpu_density_is_conservative_for_every_tile_anchor() -> void:
	var origin := Vector2(7.25, -11.5)
	var conservative := true
	for tile: Vector2i in GrassStreamer.desired_tiles(origin):
		var tile_origin := Vector2(tile) * GrassField.TILE_WORLD
		var tile_density := GrassStreamer.density(
			GrassStreamer.distance_to_tile(origin, tile))
		for offset: Vector2 in [Vector2.ZERO,
				Vector2(GrassField.TILE_WORLD, 0.0),
				Vector2(0.0, GrassField.TILE_WORLD),
				Vector2.ONE * GrassField.TILE_WORLD,
				Vector2.ONE * GrassField.TILE_WORLD * 0.5]:
			conservative = conservative and tile_density + 0.000001 >= \
				GrassStreamer.density(origin.distance_to(tile_origin + offset))
	assert_true(conservative,
		"the CPU prefix cannot remove an anchor the shader would retain")

func test_commit_uses_one_buffer_assignment_per_selected_asset() -> void:
	var fixture := _program_and_cache()
	var streamer := GrassStreamer.new(fixture.program, fixture.cache)
	streamer.begin_frame(Vector2(12.0, 12.0))
	var generation := streamer.mark_requested(Vector2i.ZERO)
	var payload := _payload(fixture.program)
	assert_true(streamer.accept_result(Vector2i.ZERO, generation, payload))
	var committed: Array[Dictionary] = []
	for frame in 2:
		committed.append_array(streamer.drain_commits())
	assert_eq(committed.size(), 1)
	var node: Node3D = committed[0].node
	add_child_autofree(node)
	assert_lte(node.get_child_count(), 1)
	for child: Node in node.get_children():
		var instance := child as MultiMeshInstance3D
		assert_not_null(instance)
		assert_eq(instance.multimesh.visible_instance_count,
			instance.multimesh.instance_count,
			"full-density LOD keeps every packed instance")
		var asset_id: StringName = instance.get_meta(&"grass_asset_id")
		var batch: Dictionary = payload.batches[asset_id]
		var expected: AABB = (batch.aabb as AABB).grow(
			float(batch.max_height) * GrassStreamer.MAX_DEFORMATION_RATIO + 0.05)
		assert_eq(instance.multimesh.custom_aabb, expected,
			"custom bounds include the complete deformation contract")
		assert_eq(instance.cast_shadow,
			GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		var material := instance.material_override as ShaderMaterial
		assert_not_null(material)
		assert_true(material.shader.code.contains("render_mode cull_disabled"))
		assert_true(material.shader.code.contains("FAR_DETAIL_START"))
		assert_true(material.shader.code.contains("bend *= grass_detail"),
			"sub-pixel far grass is static instead of temporally grainy")
		assert_true(material.shader.code.contains("CAMERA_POSITION_WORLD"),
			"screen-distant detail follows the camera while population follows the player")
		assert_true(material.shader.code.contains("blade_root_world"),
			"trampling resolves authored root groups instead of the whole patch")
		assert_true(material.shader.code.contains("world_to_local_tangent"),
			"wind and trampling use the slope-oriented instance frame")
		assert_true(material.shader.code.contains("TRAMPLE_BEND = 1.25"))
		assert_true(material.shader.code.contains("TRAMPLE_DROP = 0.95"))
		assert_true(material.shader.code.contains("NORMAL_UP_BIAS = 0.82"),
			"authored shading is softened into the terrain's lighting family")
		assert_true(material.shader.code.contains(
			"mix(1.0, NORMAL_UP_BIAS, grass_detail)"),
			"far cards converge to the terrain normal before the population cutoff")
		assert_true(material.shader.code.contains("if (!FRONT_FACING)"),
			"both sides of every ribbon share one lighting hemisphere")
		assert_true(material.shader.code.contains("blade_tone = mix(1.0, root_tone, grass_detail)"),
			"nearby root groups vary subtly while distant grass remains coherent")
		assert_true(material.shader.code.contains("float tip_gradient"),
			"roots, blade bodies, and tips have readable value separation")
		assert_true(material.shader.code.contains("mix(blade_value, 1.0, root_match)"),
			"the contact row returns exactly to the terrain value")
		assert_true(material.shader.code.contains("mix(1.0, near_value, grass_detail)"),
			"far grass returns to terrain luminance before the population cutoff")
		assert_true(material.shader.code.contains("far_tint = vec3(1.0)"),
			"far grass cannot leave a coloured LOD ring over neutral ground")
		assert_true(material.shader.code.contains("ground_base * COLOR.rgb"),
			"the grass hue comes from the terrain palette rather than the imported teal texture")
		assert_false(material.shader.code.contains("ALBEDO = sampled * COLOR.rgb"))
		assert_same(material.get_shader_parameter(&"ground_palette_texture"),
			CliffDressing.ground_texture(),
			"grass and terrain bind one live palette texture object")
		assert_eq(material.get_shader_parameter(&"ground_palette_uv"),
			CliffDressing.ground_uv(),
			"grass samples the exact same palette island as the terrain sheet")
		assert_false(bool(material.get_shader_parameter(&"source_has_texture")),
			"Collection 5 retains geometric shading without inventing a texture")
		assert_false(material.shader.code.contains("DROPOUT_WIDTH"),
			"far LOD never creates a broad population of tiny partial patches")

func test_stale_generation_cannot_resurrect_an_evicted_tile() -> void:
	var fixture := _program_and_cache()
	var streamer := GrassStreamer.new(fixture.program, fixture.cache)
	streamer.begin_frame(Vector2.ZERO)
	var generation := streamer.mark_requested(Vector2i.ZERO)
	streamer.begin_frame(Vector2(1000.0, 1000.0))
	assert_false(streamer.accept_result(Vector2i.ZERO, generation,
		_payload(fixture.program)))
	assert_eq(streamer.pending_count(), 0)

func test_single_batch_tile_commits_atomically_in_one_frame() -> void:
	var fixture := _program_and_cache()
	var streamer := GrassStreamer.new(fixture.program, fixture.cache)
	streamer.begin_frame(Vector2.ZERO)
	var generation := streamer.mark_requested(Vector2i.ZERO)
	assert_true(streamer.accept_result(Vector2i.ZERO, generation,
		_payload(fixture.program)))
	var committed := streamer.drain_commits()
	assert_eq(committed.size(), 1,
		"the tile attaches in the frame of its one buffer upload")
	add_child_autofree(committed[0].node)
	assert_eq(streamer.pending_count(), 0)
	assert_eq(streamer.built_count(), 1)

func test_stale_result_cannot_clear_a_newer_request() -> void:
	var fixture := _program_and_cache()
	var streamer := GrassStreamer.new(fixture.program, fixture.cache)
	streamer.begin_frame(Vector2.ZERO)
	var stale_generation := streamer.mark_requested(Vector2i.ZERO)
	streamer.begin_frame(Vector2(1000.0, 1000.0))
	streamer.begin_frame(Vector2.ZERO)
	var current_generation := streamer.mark_requested(Vector2i.ZERO)
	assert_gt(current_generation, stale_generation)
	assert_false(streamer.accept_result(Vector2i.ZERO, stale_generation,
		_payload(fixture.program)))
	assert_false(streamer.needs_request(Vector2i.ZERO),
		"the current generation remains tracked after the stale hand-off")


## The CPU prefix only skips patches the shader certainly fades out: it never
## drops below the exact density prefix, and it moves in quarter bands so a
## walking player does not rewrite every fade-ring tile every frame.
func test_visible_count_is_conservative_and_banded() -> void:
	for count in [0, 1, 7, 289, 1000]:
		var distinct := {}
		for step in 101:
			var density := step / 100.0
			var visible := GrassStreamer.visible_count(count, density)
			assert_true(visible >= ceili(count * density) and visible <= count,
				"count=%d density=%.2f" % [count, density])
			distinct[visible] = true
		assert_lte(distinct.size(), 5, "At most one value per quarter band")


## Distant patches draw fewer whole blades through the mesh's own LODs
## (nested subsets of the full patch), never through a mesh swap.
func test_blade_lods_are_nested_whole_blade_subsets() -> void:
	var mesh: Mesh = load("res://terrain/environment/meshes/stylized_grass/stylized_grass_collection_05_piece_00.res")
	var arrays := mesh.surface_get_arrays(0)
	var full: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var previous := {}
	for t in range(0, full.size(), 3): previous[Vector3i(full[t], full[t + 1], full[t + 2])] = true
	for keep: float in GrassStreamer.BLADE_LOD_KEEP:
		var kept := GrassStreamer.thinned_blade_indices(arrays, keep)
		var triangles := {}
		for t in range(0, kept.size(), 3):
			var tri := Vector3i(kept[t], kept[t + 1], kept[t + 2])
			assert_true(previous.has(tri), "LOD %.3f keeps a subset of the coarser-than-it level" % keep)
			triangles[tri] = true
		assert_almost_eq(float(kept.size()) / full.size(), keep, 0.12, "about %.3f of the triangles" % keep)
		previous = triangles
	var lod_mesh := GrassStreamer.blade_lod_mesh(mesh)
	var surfaces: Array = lod_mesh.get("_surfaces")
	assert_eq((surfaces[0] as Dictionary).get("lods", []).size(), GrassStreamer.BLADE_LOD_KEEP.size() * 2,
		"one (edge, indices) pair per blade LOD")

func test_radii_have_one_source_of_truth() -> void:
	var code := (load("res://terrain/grass/grass.gdshader") as Shader).code
	assert_false(code.contains("const float GRASS_RADIUS"), "the shader reads the streamer's radius")
	assert_false(code.contains("const float FULL_RADIUS"), "the shader reads the streamer's radius")
	assert_true(code.contains("global uniform float grass_radius"))
	assert_true(code.contains("global uniform float grass_full_radius"))
	assert_true(ProjectSettings.has_setting("shader_globals/grass_radius"))
	assert_true(ProjectSettings.has_setting("shader_globals/grass_full_radius"))

func test_set_radii_moves_the_whole_ring() -> void:
	var full := GrassStreamer.FULL_RADIUS
	var edge := GrassStreamer.GRASS_RADIUS
	GrassStreamer.set_radii(90.0, 140.0)
	assert_eq(GrassStreamer.density(90.0), 1.0)
	assert_eq(GrassStreamer.density(140.0), 0.0)
	assert_eq(GrassStreamer.keep_radius(), 140.0 + GrassField.TILE_WORLD)
	for tile: Vector2i in GrassStreamer.desired_tiles(Vector2.ZERO):
		assert_lt(GrassStreamer.distance_to_tile(Vector2.ZERO, tile), 140.0)
	GrassStreamer.set_radii(full, edge)

func test_pending_tiles_counts_desired_tiles_not_built() -> void:
	var parts := _program_and_cache()
	var streamer := GrassStreamer.new(parts.program, parts.cache)
	assert_eq(streamer.pending_tiles(), GrassStreamer.desired_tiles(Vector2.ZERO).size(),
		"with nothing built every desired tile is pending")
