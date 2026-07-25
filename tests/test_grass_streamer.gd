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
	assert_eq(tiles.size(), 52)
	var requested: Dictionary = {}
	for tile: Vector2i in tiles:
		requested[tile] = true
	var all_covered := true
	for z in range(-144, 145, 3):
		for x in range(-144, 145, 3):
			var point := Vector2(x, z)
			if point.length() >= GrassStreamer.GRASS_RADIUS:
				continue
			all_covered = all_covered and requested.has(GrassField.tile_of(point))
	assert_true(all_covered,
		"every point inside the fade belongs to a requested tile")

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
