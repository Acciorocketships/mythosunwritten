extends GutTest
const Canopy = preload("res://scripts/terrain/biome/CanopyShadows.gd")

func test_leaf_shadow_proxy_shares_population_and_preserves_visible_material() -> void:
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = MultiMesh.new()
	instance.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	instance.multimesh.mesh = BoxMesh.new()
	instance.multimesh.instance_count = 3
	instance.multimesh.visible_instance_count = 2
	var source := ShaderMaterial.new()
	source.shader = load("res://terrain/environment/materials/biome_canopy.gdshader")
	instance.material_override = source
	var proxy := Canopy.attach(instance)
	assert_not_null(proxy, "Solid leaf crowns need a separate porous shadow representation")
	if proxy == null:
		instance.free()
		return
	assert_same(proxy.multimesh, instance.multimesh, "No duplicate instance buffers or worker payloads")
	assert_same(instance.material_override, source, "Visible tree silhouette stays intact")
	assert_same(proxy.get_parent(), instance, "Chunk/visibility lifetime follows its original batch")
	assert_eq(proxy.transform, Transform3D.IDENTITY, "Placement is applied exactly once")
	assert_eq(instance.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	assert_eq(proxy.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
	assert_true(proxy.is_in_group("tactical_preserve_surface"))
	assert_same(Canopy.attach(instance), proxy, "Repeated attachment is idempotent")
	instance.multimesh.visible_instance_count = 1
	assert_eq(proxy.multimesh.visible_instance_count, 1, "Visibility changes cannot leave phantom shadows")
	instance.free()

func test_non_foliage_keeps_its_original_shadow_owner() -> void:
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = MultiMesh.new()
	instance.multimesh.mesh = BoxMesh.new()
	instance.material_override = StandardMaterial3D.new()
	assert_null(Canopy.attach(instance))
	assert_eq(instance.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	assert_eq(instance.get_child_count(), 0)
	instance.free()

func _solid(color: Color) -> ImageTexture:
	var image := Image.create_empty(2, 2, false, Image.FORMAT_RGBAF)
	image.fill(color)
	return ImageTexture.create_from_image(image)

func _brightness(image: Image) -> float:
	var total := 0.0
	for y in range(0, image.get_height(), 4):
		for x in range(0, image.get_width(), 4):
			total += image.get_pixel(x, y).get_luminance()
	return total / float(image.get_width() * image.get_height() / 16)

func test_rendered_leaf_gaps_follow_biome_weight_and_quality() -> void:
	if Helper.is_headless():
		pending("Shadow-map verification requires a native renderer")
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256, 256)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color.BLACK
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.1
	viewport.add_child(environment)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.position = Vector3(12, 15, 18)
	camera.look_at(Vector3(4, 0, 0))
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.rotation_degrees = AtmosphereDirector.SUN_ANGLE_DEG
	viewport.add_child(sun)
	RenderingServer.global_shader_parameter_set("atmosphere_sun_ray", -sun.basis.z)
	RenderingServer.global_shader_parameter_set("canopy_shadow_detail", 1.0)
	var floor_node := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	floor_node.mesh = plane
	viewport.add_child(floor_node)
	var tree := MultiMeshInstance3D.new()
	tree.multimesh = MultiMesh.new()
	tree.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var crown := BoxMesh.new()
	crown.size = Vector3(8, 0.5, 8)
	tree.multimesh.mesh = crown
	tree.multimesh.instance_count = 1
	tree.multimesh.set_instance_transform(0, Transform3D(Basis.IDENTITY, Vector3(0, 6, 0)))
	var material := ShaderMaterial.new()
	material.shader = load("res://terrain/environment/materials/biome_canopy.gdshader")
	material.set_shader_parameter("albedo_texture", _solid(Color(0.1, 0.7, 0.1)))
	tree.material_override = material
	viewport.add_child(tree)
	Canopy.attach(tree)
	var values: Array[float] = []
	for weight in [0.0, 0.5, 1.0]:
		RenderingServer.global_shader_parameter_set("biome_ground_a", _solid(Color(weight, 0, 0, 0)))
		for frame in 30: await RenderingServer.frame_post_draw
		values.append(_brightness(viewport.get_texture().get_image()))
	assert_gte(values[1], values[0] - 0.0001, "Transition cannot add darker shadow holes")
	assert_gt(values[2], values[0] + 0.001, "Forest leaf gaps admit measurable sunlight")
	RenderingServer.global_shader_parameter_set("canopy_shadow_detail", 0.0)
	for frame in 30: await RenderingServer.frame_post_draw
	assert_almost_eq(_brightness(viewport.get_texture().get_image()), values[0], 0.001,
		"Economical restores the original solid crown shadow")
	RenderingServer.global_shader_parameter_set("biome_ground_a", _solid(Color(0, 0, 0, 0)))
	viewport.free()
	for frame in 30: await RenderingServer.frame_post_draw
