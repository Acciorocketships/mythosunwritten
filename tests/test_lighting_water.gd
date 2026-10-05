extends GutTest

class Pool extends WaterSampler:
	func level_at(p: Vector2) -> float:
		return 2.0 if p.length() < 5.0 else NAN

func test_underwater_tracks_live_mood_and_quality_then_restores_air() -> void:
	var stage := Node3D.new()
	add_child(stage)
	var owner := Node.new()
	owner.set_meta("sampler", Pool.new())
	stage.add_child(owner)
	owner.add_to_group("water_surface")
	var camera := Camera3D.new()
	stage.add_child(camera)
	var air := Environment.new()
	air.tonemap_exposure = 1.1
	air.fog_enabled = true
	air.volumetric_fog_enabled = true
	camera.environment = air
	var effect := preload("res://scripts/camera/UnderwaterView.gd").new()
	effect.camera = camera
	effect.world_seed = 2697992464
	stage.add_child(effect)
	camera.position = Vector3(0, 1, 0)
	effect.update_view()
	var submerged := camera.environment
	var day_medium: Color = effect._material.get_shader_parameter("medium_color")
	effect.light_gain = 0.3
	air.ambient_light_color = Color("526b95")
	air.ambient_light_energy = 0.28
	air.glow_intensity = 0.92
	air.ssil_enabled = true
	air.tonemap_exposure = 0.9
	effect.update_view()
	var night_medium: Color = effect._material.get_shader_parameter("medium_color")
	assert_lt(night_medium.srgb_to_linear().g, day_medium.srgb_to_linear().g * 0.4,
		"The underwater overlay cannot retain daylight scattering in a dark biome")
	assert_same(camera.environment, submerged, "Keep the same submerged resource while swimming")
	assert_eq(submerged.ambient_light_color, air.ambient_light_color, "Live biome colour reaches underwater view")
	assert_almost_eq(submerged.ambient_light_energy, 0.28, 0.00001)
	assert_almost_eq(submerged.glow_intensity, 0.92, 0.00001)
	assert_true(submerged.ssil_enabled, "Quality changes reach submerged view")
	assert_almost_eq(submerged.tonemap_exposure, 0.9 * 0.78, 0.00001, "Depth dimming uses current exposure")
	assert_false(submerged.fog_enabled, "Air fog must not double-apply underwater")
	assert_false(submerged.volumetric_fog_enabled)
	camera.position.y = 3.0
	effect.update_view()
	assert_same(camera.environment, air)
	assert_almost_eq(air.tonemap_exposure, 0.9, 0.00001, "Underwater effect never mutates air")
	stage.free()

func test_twilight_water_scattering_dims_with_the_world_light() -> void:
	var day := BiomeRegistry.blend_atmosphere({&"meadow": 1.0})
	var night := BiomeRegistry.blend_atmosphere({&"twilight_marsh": 1.0})
	assert_almost_eq(AtmosphereDirector.water_light_gain(day), 1.0, 0.00001)
	assert_lt(AtmosphereDirector.water_light_gain(night), 0.35,
		"Moonfen foam and body scattering cannot retain daylight brightness")
	assert_gt(AtmosphereDirector.water_light_gain(night), 0.08,
		"Twilight water still has enough fill to read its shape")
