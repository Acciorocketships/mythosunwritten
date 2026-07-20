extends GutTest

func test_all_five_profiles_load_complete() -> void:
	for name: StringName in Helper.BIOME_NAMES:
		var p := BiomeRegistry.profile(name)
		assert_not_null(p, "profile %s exists" % name)
		assert_eq(p.biome_name, name)
		assert_gte(p.fog_density, 0.0)
		assert_gt(p.ambient_energy, 0.0)
		assert_gt(p.foliage_density, 0.0)
		assert_ne(p.ground_tint, Color.WHITE, "ground tint must be set, not default white")

func test_meadow_and_highland_are_fog_free() -> void:
	# Owner: "it seems that all of the biomes have fog. i do like it in some,
	# but can you make some without fog?" — the clear biomes carry exactly none.
	assert_eq(BiomeRegistry.profile(&"meadow").fog_density, 0.0, "meadow must have no fog")
	assert_eq(BiomeRegistry.profile(&"highland").fog_density, 0.0, "highland must have no fog")
	assert_gt(BiomeRegistry.profile(&"twilight_marsh").fog_density, 0.0, "marsh keeps its fog")
	assert_gt(BiomeRegistry.profile(&"deep_forest").fog_density, 0.0, "forest keeps its fog")
	assert_gt(BiomeRegistry.profile(&"blossom_grove").fog_density, 0.0, "blossom keeps its pink haze")

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

func test_blended_density_uses_the_profile_budget() -> void:
	var pure_forest := {&"meadow": 0.0, &"deep_forest": 1.0, &"highland": 0.0,
			&"blossom_grove": 0.0, &"twilight_marsh": 0.0}
	assert_almost_eq(BiomeRegistry.blended_density(pure_forest),
			BiomeRegistry.profile(&"deep_forest").foliage_density, 1e-6)

func test_biome_id_order_and_density_bound_are_explicit() -> void:
	assert_eq(BiomeRegistry.biome_ids(), Helper.BIOME_NAMES)
	for biome_id: StringName in BiomeRegistry.biome_ids():
		assert_lte(BiomeRegistry.profile(biome_id).foliage_density,
			BiomeRegistry.max_foliage_density())
