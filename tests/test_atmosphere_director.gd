extends GutTest
## AtmosphereDirector grade + easing, exercised directly (headless disables auto _ready/_process).

func _mock_director() -> AtmosphereDirector:
	var d := AtmosphereDirector.new()
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	we.environment = env
	d.environment_node = we
	d.sun = DirectionalLight3D.new()
	d.camera = Camera3D.new()
	return d

func _free_director(d: AtmosphereDirector) -> void:
	d.environment_node.free()
	d.sun.free()
	d.camera.free()
	d.free()

func test_apply_grade_sets_render_stack() -> void:
	var d := _mock_director()
	d._apply_grade()
	var env := d.environment_node.environment
	assert_eq(env.tonemap_mode, Environment.TONE_MAPPER_FILMIC, "filmic tonemap")
	assert_true(env.glow_enabled, "bloom/glow on")
	assert_true(env.fog_enabled, "classic fog on (for the per-biome blend)")
	assert_true(env.volumetric_fog_enabled, "volumetric fog on (pockets supply density)")
	assert_eq(env.ambient_light_source, Environment.AMBIENT_SOURCE_COLOR, "ambient is a fixed colour")
	assert_true(d.camera.attributes is CameraAttributesPractical, "tilt-shift DoF attributes set")
	assert_true((d.camera.attributes as CameraAttributesPractical).dof_blur_far_enabled, "far DoF on")
	assert_eq(d.sun.light_color, AtmosphereDirector.SUN_COLOR, "warm key light")
	_free_director(d)

func test_process_eases_env_toward_biome_blend() -> void:
	var d := _mock_director()
	d._apply_grade()
	var s := FieldTerrainStreamer.new()
	s.world_seed = 991177
	d.streamer = s
	var p := Node3D.new()
	add_child_autofree(p)   # global_position asserts is_inside_tree()
	p.position = Vector3(1200, 0, -900)
	d.player = p
	var env := d.environment_node.environment
	# capture the target the director will chase, then step easing a few times.
	var target := BiomeRegistry.blend_atmosphere(Helper.biome_weights5(p.global_position, s.world_seed))
	var before := absf(env.fog_density - float(target[&"fog_density"]))
	for i in 30:
		d._process(0.1)
	var after := absf(env.fog_density - float(target[&"fog_density"]))
	assert_lt(after, before, "fog_density eased toward the biome blend target")
	s.free()
	_free_director(d)
