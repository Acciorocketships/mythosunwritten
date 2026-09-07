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
	assert_almost_eq(d.sun.light_energy, AtmosphereDirector.SUN_ENERGY, 0.000001,
		"key light remains restrained enough for the shared ground palette")
	assert_almost_eq(d.sun.shadow_opacity, AtmosphereDirector.SUN_SHADOW_OPACITY, 0.000001,
		"low sun keeps readable but non-dominating terrain shadows")
	_free_director(d)

func test_moving_between_biomes_cannot_relight_the_world() -> void:
	var d := _mock_director()
	d._apply_grade()
	var s := FieldTerrainStreamer.new()
	s.world_seed = 2697992464
	d.streamer = s
	var p := Node3D.new()
	add_child_autofree(p)
	d.player = p
	var env := d.environment_node.environment
	var before := [env.fog_density, env.fog_light_color,
		env.ambient_light_color, env.ambient_light_energy,
		(env.sky.sky_material as ProceduralSkyMaterial).sky_top_color]
	for point: Vector3 in [Vector3(48, 0, -1500), Vector3(1200, 0, -900), Vector3.ZERO]:
		p.position = point
		for frame in 30:
			d._process(0.1)
		assert_eq([env.fog_density, env.fog_light_color,
			env.ambient_light_color, env.ambient_light_energy,
			(env.sky.sky_material as ProceduralSkyMaterial).sky_top_color], before,
			"world light and distant biomes must be independent of the observer")
	s.free()
	_free_director(d)
