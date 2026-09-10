extends GutTest

func test_biomes_have_distinct_light_levels_and_a_twilight_endpoint() -> void:
	var total := 0.0
	var skies: Dictionary = {}
	for id: StringName in BiomeRegistry.biome_ids():
		var profile := BiomeRegistry.profile(id)
		total += profile.ambient_energy
		skies[profile.sky_top] = true
	assert_gt(skies.size(),4,"Biome skies must have visibly different moods")
	assert_lt(total/7.0,0.65,"Average ambient light is lower than the previous fixed grade")
	assert_lt(BiomeRegistry.profile(&"twilight_marsh").ambient_energy,0.35,"Moonfen reaches twilight")
	assert_gt(BiomeRegistry.profile(&"meadow").ambient_energy,0.65,"Sunwash remains a bright endpoint")
