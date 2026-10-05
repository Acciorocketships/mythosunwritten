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
	d._underwater = preload("res://scripts/camera/UnderwaterView.gd").new()
	d.add_child(d._underwater)
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
	assert_null(d.camera.attributes, "Depth of field is removed until the camera redesign")
	assert_eq(d.sun.light_color, AtmosphereDirector.SUN_COLOR, "warm key light")
	assert_almost_eq(d.sun.light_energy, AtmosphereDirector.SUN_ENERGY, 0.000001,
		"key light remains restrained enough for the shared ground palette")
	assert_almost_eq(d.sun.shadow_opacity, AtmosphereDirector.SUN_SHADOW_OPACITY, 0.000001,
		"low sun keeps readable but non-dominating terrain shadows")
	_free_director(d)

func test_biome_lighting_changes_gradually_without_rotating_shadows() -> void:
	var d := _mock_director()
	d._apply_grade()
	var meadow := {&"meadow":1.0}
	var moonfen := {&"twilight_marsh":1.0}
	d._update_mood(0.0,meadow)
	var before := d.sun.light_energy
	var direction := d.sun.rotation
	d._update_mood(1.0/60.0,moonfen)
	assert_lt(d.sun.light_energy,before)
	assert_gt(d.sun.light_energy,before*0.99,"A single frame cannot abruptly relight the scene")
	for i in 600: d._update_mood(0.05,moonfen)
	assert_almost_eq(d.sun.light_energy,BiomeRegistry.profile(&"twilight_marsh").sun_energy,0.0001)
	assert_eq(d.sun.rotation,direction,"Biome mood does not swing shadow direction")
	assert_null(d.camera.attributes,"Mood changes cannot restore camera blur")
	_free_director(d)

func test_mood_response_is_independent_of_frame_partition() -> void:
	var a := _mock_director()
	var b := _mock_director()
	a._apply_grade()
	b._apply_grade()
	a._update_mood(0.0,{&"meadow":1.0})
	b._update_mood(0.0,{&"meadow":1.0})
	a._update_mood(3.0,{&"twilight_marsh":1.0})
	for i in 180: b._update_mood(1.0/60.0,{&"twilight_marsh":1.0})
	assert_almost_eq(a.sun.light_energy,b.sun.light_energy,0.00001)
	assert_almost_eq(a.environment_node.environment.ambient_light_energy,b.environment_node.environment.ambient_light_energy,0.00001)
	_free_director(a)
	_free_director(b)

func test_quality_switch_clears_expensive_effects() -> void:
	var d := _mock_director()
	var viewport := SubViewport.new()
	add_child_autofree(viewport)
	viewport.add_child(d.camera)
	d._apply_grade()
	d.set_quality(2)
	assert_true(d.environment_node.environment.ssil_enabled)
	assert_eq(viewport.msaa_3d, Viewport.MSAA_4X)
	d.set_quality(0)
	assert_eq(viewport.msaa_3d, Viewport.MSAA_DISABLED)
	assert_eq(viewport.screen_space_aa, Viewport.SCREEN_SPACE_AA_FXAA)
	assert_false(d.environment_node.environment.ssil_enabled)
	assert_false(d.environment_node.environment.sdfgi_enabled)
	assert_false(d.environment_node.environment.volumetric_fog_enabled)
	d._update_mood(0.0, {&"twilight_marsh": 1.0})
	assert_lt(d._underwater.light_gain, 0.35,
		"Twilight lighting reaches underwater scattering as well as the surface shader")
	assert_false(d.environment_node.environment.volumetric_fog_enabled,
		"Biome updates cannot override the selected quality budget")
	assert_true(d.environment_node.environment.fog_enabled,
		"Low quality retains distance atmosphere")
	d.set_quality(1)
	assert_eq(viewport.msaa_3d, Viewport.MSAA_2X)
	assert_eq(viewport.screen_space_aa, Viewport.SCREEN_SPACE_AA_DISABLED,
		"Returning to standard must remove the economical tier's blur pass")
	_free_director(d)

func test_biome_shapes_blend_continuously_and_keep_distinct_vertical_moods() -> void:
	var forest := BiomeRegistry.blend_atmosphere({&"deep_forest": 1.0})
	var marsh := BiomeRegistry.blend_atmosphere({&"twilight_marsh": 1.0})
	var mix := BiomeRegistry.blend_atmosphere({&"deep_forest": 0.5, &"twilight_marsh": 0.5})
	assert_true(forest.has(&"mist_shape") and marsh.has(&"mist_shape"))
	if not forest.has(&"mist_shape"): return
	assert_gt(forest[&"mist_shape"].r, marsh[&"mist_shape"].r,
		"Forest haze rises into the canopy; marsh mist hugs the water")
	assert_eq(mix[&"mist_shape"], (forest[&"mist_shape"] + marsh[&"mist_shape"]) * 0.5)
	assert_gt(marsh[&"mist_shape"].a, forest[&"mist_shape"].a,
		"Twilight mist has more ambient glow than the shaft-lit forest")
