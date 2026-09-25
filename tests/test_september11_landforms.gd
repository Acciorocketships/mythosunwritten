extends GutTest

func test_production_terrain_has_room_for_large_mountains() -> void:
	assert_gte(TerrainWorldTuning.HEIGHTFIELD_AMPLITUDE,96.0,
		"The former 32 m ceiling cannot produce large mountains")
	var highest := 0.0
	for z in range(-80,81,2):
		for x in range(-80,81,2):
			var p := Vector3(x*72,0,z*72)
			highest = maxf(highest,HeightfieldPlan.height01(p,2697992464)*TerrainWorldTuning.HEIGHTFIELD_AMPLITUDE)
	assert_gt(highest,60.0,"Real production geography must realize the taller range")

func test_larger_height_range_retains_frequent_physical_headwaters() -> void:
	for seed_value: int in [991177,2697992464,314159]:
		var water := TerrainWorldTuning.make_water(seed_value)
		var count := 0
		for z in range(-4,5):
			for x in range(-4,5): count += int(water.has_source(Vector2i(x,z)))
		assert_gte(count,30,"Retain the existing 81-district river-density minimum")

func test_biome_relief_and_shapes_are_distinct_and_continuous() -> void:
	var means: Dictionary = {}
	for biome: StringName in Helper.BIOME_NAMES:
		var total := 0.0
		var choices: Dictionary = {}
		for z in range(-8,9):
			for x in range(-8,9):
				var p := Vector3(x*127,0,z*131)
				var a := LandformField.height01(p,2697992464,{biome:1.0})
				total += a*TerrainWorldTuning.HEIGHTFIELD_AMPLITUDE
				var b := LandformField.height01(p+Vector3(.01,0,.01),2697992464,{biome:1.0})
				assert_almost_eq(a,b,.001)
				assert_between(a,0.0,.999,"No clipped flat mountain tops")
		means[biome] = total/289
	assert_gt(means.highland,means.meadow*3)
	assert_gt(means.amber_heath,means.twilight_marsh*3)
	assert_gt(means.deep_forest,means.jade_wetlands*1.5)
	assert_gt(LandformField.shape(7,Vector2.ZERO),LandformField.shape(7,Vector2(0,.6))+.6)
	assert_gt(LandformField.shape(8,Vector2(.6,.55)),LandformField.shape(8,Vector2(.18,.55))+.2)
	assert_gt(LandformField.shape(8,Vector2(.18,.55)),LandformField.shape(8,Vector2(.18,0))+.25)
