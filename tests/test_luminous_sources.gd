extends GutTest

func test_orb_produces_a_broad_bloom_halo_above_its_sprite() -> void:
	if Helper.is_headless():
		pending("HDR bloom requires the native renderer")
		return
	var view := SubViewport.new()
	view.size = Vector2i(256, 256)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env_node.environment = env
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_hdr_threshold = 1.4
	env.glow_bloom = 0.0
	env.glow_intensity = 0.8
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	for i in 7: env.set_glow_level(i, [0.4, 0.9, 0.65, 0.3, 0.12, 0.0, 0.0][i])
	view.add_child(env_node)
	var camera := Camera3D.new()
	view.add_child(camera)
	camera.position = Vector3(0, 0, 9)
	camera.look_at(Vector3.ZERO)
	var orb := SpiritOrb.create(Vector3.ZERO)
	view.add_child(orb)
	orb.set_process(false)
	orb.get_node("Light").visible = false
	env.glow_enabled = false
	for i in 30: await RenderingServer.frame_post_draw
	var without := view.get_texture().get_image()
	env.glow_enabled = true
	for i in 30: await RenderingServer.frame_post_draw
	var with_glow := view.get_texture().get_image()
	without.save_png("/tmp/orb-without-glow.png")
	with_glow.save_png("/tmp/orb-with-glow.png")
	var difference := 0.0
	var count := 0
	for y in range(80, 176):
		for x in range(80, 176):
			var distance := Vector2(x - 128, y - 128).length()
			if distance > 10 and distance < 38:
				difference += with_glow.get_pixel(x, y).get_luminance() - without.get_pixel(x, y).get_luminance()
				count += 1
	print("[luminous-source] halo lift=", difference / count)
	assert_gt(difference / count, 0.018, "A floating light must visibly bloom beyond its core; a tinted sprite alone is insufficient")
	view.queue_free()
	await get_tree().process_frame
