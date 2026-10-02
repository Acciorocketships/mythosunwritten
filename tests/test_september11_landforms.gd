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
	for seed_value: int in [991177,2697992464,314159,42,1,77777,123456789]:
		var water := TerrainWorldTuning.make_water(seed_value)
		var count := 0
		for z in range(-4,5):
			for x in range(-4,5): count += int(water.has_source(Vector2i(x,z)))
		assert_gte(count,30,"seed %d: retain the existing 81-district river-density minimum" % seed_value)

func test_archetypes_have_distinct_elevations() -> void:
	var means: Dictionary = {}
	for a: StringName in [&"low_flats", &"rolling_downs", &"highland_massif", &"tableland"]:
		TerrainRegimeField.set_force_archetype(a)
		var total := 0.0
		for z in range(-8, 9):
			for x in range(-8, 9):
				total += TerrainField.height_m(Vector2(x * 127 + 2000, z * 131), 2697992464, true)
		means[a] = total / 289.0
	TerrainRegimeField.set_force_archetype(&"")
	assert_gt(means.highland_massif, means.low_flats + 30.0)
	assert_gt(means.tableland, means.low_flats + 12.0)
	assert_gt(means.rolling_downs, means.low_flats)
