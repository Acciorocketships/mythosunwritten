extends GutTest

func test_all_five_profiles_load_complete() -> void:
	for name: StringName in Helper.BIOME_NAMES:
		var p := BiomeRegistry.profile(name)
		assert_not_null(p, "profile %s exists" % name)
		assert_eq(p.biome_name, name)
		assert_gt(p.fog_density, 0.0)
		assert_gt(p.ambient_energy, 0.0)
		assert_gt(p.foliage_density, 0.0)
		assert_gt(p.tag_weights.size(), 0)
		assert_ne(p.ground_tint, Color.WHITE, "ground tint must be set, not default white")

func test_blend_atmosphere_endpoints_and_midpoint() -> void:
	var pure := {&"meadow": 1.0, &"deep_forest": 0.0, &"highland": 0.0,
			&"blossom_grove": 0.0, &"twilight_marsh": 0.0}
	var a := BiomeRegistry.blend_atmosphere(pure)
	var meadow := BiomeRegistry.profile(&"meadow")
	assert_almost_eq(a[&"fog_density"], meadow.fog_density, 1e-6)
	assert_eq(a[&"fog_color"], meadow.fog_color)
	var half := {&"meadow": 0.5, &"deep_forest": 0.0, &"highland": 0.0,
			&"blossom_grove": 0.0, &"twilight_marsh": 0.5}
	var marsh := BiomeRegistry.profile(&"twilight_marsh")
	var m := BiomeRegistry.blend_atmosphere(half)
	assert_almost_eq(m[&"fog_density"], (meadow.fog_density + marsh.fog_density) * 0.5, 1e-6)

func test_blended_scatter_helpers() -> void:
	var pure_forest := {&"meadow": 0.0, &"deep_forest": 1.0, &"highland": 0.0,
			&"blossom_grove": 0.0, &"twilight_marsh": 0.0}
	var tw := BiomeRegistry.blended_tag_weights(pure_forest)
	assert_gt(tw["tree"], tw["rock"], "deep forest favours trees")
	assert_almost_eq(BiomeRegistry.blended_density(pure_forest),
			BiomeRegistry.profile(&"deep_forest").foliage_density, 1e-6)
