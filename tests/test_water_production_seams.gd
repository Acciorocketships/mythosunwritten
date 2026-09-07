extends GutTest

## Current geography, intentionally separate from the frozen historical water
## screenshot fixture. These borders exposed floating 11m planes after the
## geological rebuild, and different downstream levels in adjacent windows.
func test_current_world_shared_borders_have_one_water_surface() -> void:
	var water := TerrainWorldTuning.make_water(2697992464)
	var plan := TerrainWorldTuning.make_heightfield(2697992464, water)
	var fields := WorldFieldBlockCache.new(plan, water, 12, 0, 64)
	var failures: Array = []
	for pair in [[Vector2i(-1,0),Vector2i.ZERO], [Vector2i(-1,-1),Vector2i(0,-1)],
			[Vector2i(1,1),Vector2i(2,1)], [Vector2i(2,1),Vector2i(3,1)]]:
		var a := fields.water(pair[0])
		var b := fields.water(pair[1])
		for along in range(0,193,3):
			for across in [-12,0,12]:
				var point := Vector2(pair[1]) * 192.0 + Vector2(across,along)
				var la := a.level_at(point)
				var lb := b.level_at(point)
				if is_finite(la) != is_finite(lb) or (is_finite(la) and absf(la-lb) > 0.001):
					failures.append({"point":point,"a":la,"b":lb})
	assert_eq(failures, [], "both views must agree inside the shared contour margin")
	assert_false(fields.water(Vector2i(-1,0)).is_wet(Vector2.ZERO),
		"the distant terminal lake must not flood the dry spawn clearing")

func test_reported_player_columns_have_no_overhead_water() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://tests/fixtures/september7_reported_water.json"))
	var water := TerrainWorldTuning.make_water(int(fixture.seed))
	var plan := TerrainWorldTuning.make_heightfield(int(fixture.seed), water)
	var fields := WorldFieldBlockCache.new(plan, water, 12, 0, 64)
	for site: Dictionary in fixture.sites:
		var point := Vector2(site.player[0],site.player[2])
		var chunk := Vector2i((point / 192.0).floor())
		assert_false(fields.water(chunk).is_wet(point),
			"reported dry standing ground must not sit under a floating sheet: " + String(site.name))
