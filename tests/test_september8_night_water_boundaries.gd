extends GutTest

func test_reported_town_ground_stays_dry_across_chunk_views() -> void:
	var water := TerrainWorldTuning.make_water(2697992464)
	var plan := TerrainWorldTuning.make_heightfield(2697992464,water)
	var fields := WorldFieldBlockCache.new(plan,water,12,0,64)
	for chunk: Vector2i in [Vector2i(9,2),Vector2i(10,2)]:
		var field := fields.water(chunk)
		for z in [432.0,480.0,552.0]:
			assert_false(field.is_wet(Vector2(1920,z)),
				"Photo 17 town ground is dry from either chunk view: %s z=%s" % [chunk,z])
	for chunk: Vector2i in [Vector2i(10,2),Vector2i(11,2),Vector2i(10,3),Vector2i(11,3)]:
		var field := fields.water(chunk)
		for p: Vector2 in [Vector2(2112,576),Vector2(2114.2,582.7)]:
			assert_false(field.is_wet(p),
				"Photo 15 dry land has no sheet suspended above it: %s p=%s" % [chunk,p])
	var divot := fields.water(Vector2i(7,2))
	assert_almost_eq(divot.level_at(Vector2(1482,570)),4.693702,0.001,
		"The previously accepted connected water pocket remains level with its river")
	var lake := fields.water(Vector2i(11,3))
	assert_almost_eq(lake.level_at(Vector2(2280,696)),1.7,0.001,
		"The real terminal lake remains wet at its own datum")
