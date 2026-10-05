extends GutTest

func _texture(color: Color) -> ImageTexture:
	var pixels := Image.create_empty(13, 13, false, Image.FORMAT_RGBAF)
	pixels.fill(color)
	return ImageTexture.create_from_image(pixels)

func test_thin_local_mist_survives_renderer_density_cutoff() -> void:
	if Helper.is_headless():
		pending("Fog integration requires the Forward+ renderer")
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256, 256)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color.BLACK
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	world.environment.volumetric_fog_enabled = true
	world.environment.volumetric_fog_density = 0.0
	world.environment.volumetric_fog_length = 80.0
	viewport.add_child(world)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.position = Vector3(0, 5, 20)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-25, -20, 0)
	sun.light_volumetric_fog_energy = 20.0
	viewport.add_child(sun)
	var volume := FogVolume.new()
	volume.size = Vector3(192, 160, 192)
	var material := ShaderMaterial.new()
	material.shader = load("res://terrain/materials/biome_mist.gdshader")
	material.set_shader_parameter("atmosphere_field", _texture(Color(1, 1, 1, 0.001)))
	material.set_shader_parameter("ground_field", _texture(Color(0, 0, 0, 1)))
	material.set_shader_parameter("mist_shape_field", _texture(Color(1000, 1000, 0, 0)))
	material.set_shader_parameter("chunk_origin", Vector2(-96, -96))
	volume.material = material
	viewport.add_child(volume)
	for frame in 90:
		await RenderingServer.frame_post_draw
	var pixels := viewport.get_texture().get_image()
	var brightness := 0.0
	for y in range(64, 193, 16):
		for x in range(64, 193, 16):
			brightness += pixels.get_pixel(x, y).get_luminance()
	brightness /= 81.0
	assert_gt(brightness, 0.02,
		"Sub-.001 local mist must still scatter light instead of disappearing")
	var dimmest := INF
	var brightest := 0.0
	for frame in 24:
		camera.position.x += 0.05
		await RenderingServer.frame_post_draw
		pixels = viewport.get_texture().get_image()
		var sample := 0.0
		for y in range(80, 177, 16):
			for x in range(80, 177, 16):
				sample += pixels.get_pixel(x, y).get_luminance()
		sample /= 49.0
		dimmest = minf(dimmest, sample)
		brightest = maxf(brightest, sample)
	assert_lt(brightest - dimmest, 0.03,
		"Precision dithering must not produce broad brightness pulses during camera travel")
	# Fog emission is radiance: Godot applies density during integration. With
	# every external light disabled this catches accidental density-squaring.
	sun.light_volumetric_fog_energy = 0.0
	material.set_shader_parameter("atmosphere_field", _texture(Color(1, 1, 1, 0.02)))
	material.set_shader_parameter("mist_shape_field", _texture(Color(1000, 1000, 0, 0.8)))
	for frame in 90:
		await RenderingServer.frame_post_draw
	pixels = viewport.get_texture().get_image()
	brightness = 0.0
	for y in range(64, 193, 16):
		for x in range(64, 193, 16):
			brightness += pixels.get_pixel(x, y).get_luminance()
	brightness /= 81.0
	assert_gt(brightness, 0.02, "Atmospheric glow must survive the renderer's emission packing")
	viewport.free()
	for frame in 60:
		await RenderingServer.frame_post_draw
