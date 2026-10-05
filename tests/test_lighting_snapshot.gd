extends GutTest
const SNAPSHOT = preload("res://tests/harness/september9_render_fixture.gd")

func after_all() -> void:
	# Local material references are released when test functions return. Give
	# the native renderer time to retire them before GUT requests engine exit.
	if not Helper.is_headless():
		for frame in 60:
			await RenderingServer.frame_post_draw

func test_native_visibility_material_keeps_texture_resources_when_saved() -> void:
	if Helper.is_headless():
		pending("Native material parameter readback requires a graphical renderer")
		return
	var pixels := Image.create_empty(2, 2, false, Image.FORMAT_RGBA8)
	pixels.fill(Color("628634"))
	var texture := ImageTexture.create_from_image(pixels)
	var source := StandardMaterial3D.new()
	source.albedo_texture = texture
	source.roughness = 0.73
	var adapted := ShaderMaterial.new()
	adapted.shader = Shader.new()
	adapted.shader.code = CameraVisibilityBubble.instrument(load("res://scripts/camera/tactical_standard.gdshader").code)
	var captured := SNAPSHOT.capture_native_adapter(adapted, source)
	assert_eq(captured.get_shader_parameter("texture_albedo"), texture,
		"A server-side texture RID must become a serializable texture Resource")
	assert_almost_eq(float(captured.get_shader_parameter("roughness")), 0.73, 0.0001)
	assert_null(adapted.get_shader_parameter("texture_albedo"), "Live adapter is unchanged")
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = MultiMesh.new()
	var mesh := BoxMesh.new()
	mesh.material = source
	instance.multimesh.mesh = mesh
	instance.material_override = adapted
	SNAPSHOT.restore_native_adapter_parameters(instance, {})
	assert_eq(instance.material_override.get_shader_parameter("texture_albedo"), texture,
		"Snapshot traversal recognizes the visibility include and restores the native palette")
	var custom := ShaderMaterial.new()
	custom.shader = Shader.new()
	custom.shader.code = CameraVisibilityBubble.instrument(load("res://terrain/grass/grass.gdshader").code)
	custom.set_shader_parameter("ground_palette_texture", texture)
	instance.material_override = custom
	SNAPSHOT.restore_native_adapter_parameters(instance, {})
	assert_same(instance.material_override, custom,
		"Custom grass overrides must not inherit their mesh's unused native material parameters")
	assert_eq(custom.get_shader_parameter("ground_palette_texture"), texture)
	instance.free()
	var path := "/tmp/story-lighting-native-material-test.tres"
	assert_eq(ResourceSaver.save(captured, path), OK)
	var restored := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as ShaderMaterial
	var restored_texture := restored.get_shader_parameter("texture_albedo") as Texture2D
	assert_not_null(restored_texture)
	if restored_texture != null:
		assert_eq(restored_texture.get_image().get_pixel(0, 0), pixels.get_pixel(0, 0))
	DirAccess.remove_absolute(path)
	# Let the graphical server retire the temporary native adapter before exit.
	adapted.shader = null
	captured.shader = null
	restored.shader = null
	custom.shader = null
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw

func test_snapshot_keeps_material_field_and_lighting_without_live_scripts() -> void:
	var world := Node3D.new()
	world.name = "World"
	var player := Node3D.new()
	player.position = Vector3(12, 4, 18)
	add_child(player) # Valid global transform without starting a terrain worker.
	var stream := FieldTerrainStreamer.new()
	stream.name = "FieldTerrain"
	stream.player = player
	stream._grass_streamer = GrassStreamer.new(GrassProgram.new(), EnvironmentRenderCache.new(EnvironmentCatalog.new()))
	stream._trample_field = TrampleField.new()
	world.add_child(stream)
	stream.add_child(stream._trample_field)
	var director := AtmosphereDirector.new()
	director.name = "AtmosphereDirector"
	director._mood_weights = {&"twilight_marsh": 1.0}
	director._ground_map._centre = Vector2.ZERO
	for i in 4:
		var pixels := Image.create_empty(2, 2, false, Image.FORMAT_RGBAF)
		pixels.fill(Color(0.125 * i, 0.25, 0.5, 1))
		director._ground_map._maps.append(ImageTexture.create_from_image(pixels))
	world.add_child(director)
	var path := "/tmp/story-lighting-snapshot-test.scn"
	assert_eq(SNAPSHOT.save_world(world, path, {"review_visual_time": 12.0}), OK)
	var restored := (load(path) as PackedScene).instantiate()
	var globals: Dictionary = restored.get_meta("shader_globals")
	var field := globals["biome_surface_map"] as Texture2D
	assert_not_null(field)
	assert_eq(field.get_image().get_pixel(0, 0), Color(0.375, 0.25, 0.5, 1),
		"Numeric material lookup survives binary scene serialization")
	assert_eq(globals["review_visual_time"], 12.0)
	assert_lt(float(globals["atmosphere_water_gain"]), 0.35)
	assert_eq(globals["canopy_shadow_detail"], 1.0)
	assert_almost_eq((globals["atmosphere_sun_ray"] as Vector3).length(), 1.0, 0.00001)
	assert_eq(restored.get_meta("lighting_review").position, player.position)
	assert_null(restored.get_node("FieldTerrain").get_script(), "Replays cannot start a terrain worker")
	assert_null(restored.get_node("AtmosphereDirector").get_script())
	restored.free()
	world.free()
	player.free()
	DirAccess.remove_absolute(path)

func test_water_snapshot_copies_live_buffers_without_mutating_shared_material() -> void:
	if Helper.is_headless():
		pending("Viewport texture readback requires a graphical renderer")
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(8, 8)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var fill := ColorRect.new()
	fill.size = Vector2(8, 8)
	fill.color = Color(0.2, 0.4, 0.6, 1.0)
	viewport.add_child(fill)
	add_child(viewport)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var live := viewport.get_texture()
	var expected := live.get_image().get_pixel(4, 4)
	var material := ShaderMaterial.new()
	material.shader = load("res://terrain/water/water_unified.gdshader")
	material.set_shader_parameter("ripple_tex", live)
	material.set_shader_parameter("packet_tex", live)
	var root := Node3D.new()
	for i in 2:
		var water := MeshInstance3D.new()
		water.name = "Water%d" % i
		water.material_override = material
		root.add_child(water)
		water.owner = root
	SNAPSHOT._freeze_water(root, {})
	var frozen := root.get_child(0).material_override as ShaderMaterial
	assert_ne(frozen, material)
	assert_eq(root.get_child(1).material_override, frozen,
		"One captured material remains shared across water meshes")
	assert_eq(material.get_shader_parameter("ripple_tex"), live,
		"Capture must not replace the running world's simulation texture")
	for parameter: StringName in [&"ripple_tex", &"packet_tex"]:
		var captured := frozen.get_shader_parameter(parameter) as Texture2D
		assert_true(captured is ImageTexture)
		assert_eq(captured.get_image().get_pixel(4, 4), expected)
	var packed := PackedScene.new()
	assert_eq(packed.pack(root), OK)
	var path := "/tmp/story-lighting-water-snapshot-test.scn"
	assert_eq(ResourceSaver.save(packed, path), OK)
	viewport.free()
	root.free()
	var restored := (load(path) as PackedScene).instantiate()
	var saved_material := restored.get_node("Water0").material_override as ShaderMaterial
	for parameter: StringName in [&"ripple_tex", &"packet_tex"]:
		var captured := saved_material.get_shader_parameter(parameter) as Texture2D
		assert_eq(captured.get_image().get_pixel(4, 4), expected,
			"Saved buffers survive after the original simulation viewport is freed")
	restored.free()
	DirAccess.remove_absolute(path)
