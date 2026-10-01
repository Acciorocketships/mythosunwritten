extends GutTest

class DryWaterPlan extends WaterPlan:
	func _init() -> void:
		super(12, 1.0, 1)
	func bodies_near(_center_cell: Vector2i, _radius_cells: int) -> Dictionary:
		return {"ponds": [], "rivers": []}

func _cache(capacity := 4) -> WorldFieldBlockCache:
	var water := DryWaterPlan.new()
	var plan := HeightfieldPlan.new(12, 1.0, 1, "mean", 1)
	plan.set_raw_height_override(func(_x: int, _z: int) -> float: return 0.0)
	return WorldFieldBlockCache.new(plan, water, 0.0, 0.0, capacity)

func test_half_open_key_ownership_including_negative_borders() -> void:
	for boundary in [-192.0, 0.0, 192.0]:
		assert_eq(WorldFieldBlockCache.key_of(Vector2(boundary, boundary)),
			Vector2i(int(floor(boundary / 192.0)), int(floor(boundary / 192.0))))
		assert_eq(WorldFieldBlockCache.key_of(Vector2(boundary - 0.001, boundary - 0.001)),
			Vector2i(int(floor((boundary - 0.001) / 192.0)),
				int(floor((boundary - 0.001) / 192.0))))
		assert_eq(WorldFieldBlockCache.key_of(Vector2(boundary + 0.001, boundary + 0.001)),
			Vector2i(int(floor((boundary + 0.001) / 192.0)),
				int(floor((boundary + 0.001) / 192.0))))

func test_region_and_water_are_independently_lazy_and_reused() -> void:
	var cache := _cache()
	var first := cache.region(Vector2i.ZERO)
	assert_eq(cache.region_build_count, 1)
	assert_eq(cache.water_build_count, 0)
	assert_false(cache.has_water(Vector2i.ZERO))
	assert_same(cache.region(Vector2i.ZERO), first)
	var water := cache.water(Vector2i.ZERO)
	assert_eq(cache.region_build_count, 1)
	assert_eq(cache.water_build_count, 1)
	assert_same(cache.water(Vector2i.ZERO), water)
	assert_same(water.raw_context().region, first)

func test_eviction_is_bounded_and_rebuild_is_value_identical() -> void:
	var cache := _cache(2)
	var before := cache.region(Vector2i(-1, 0))
	var signature := [before.storey_at(-8, 0), before.level_at(-8, 0)]
	cache.region(Vector2i.ZERO)
	cache.region(Vector2i.ONE)
	assert_eq(cache.size(), 2)
	assert_eq(cache.eviction_count, 1)
	var rebuilt := cache.region(Vector2i(-1, 0))
	assert_eq([rebuilt.storey_at(-8, 0), rebuilt.level_at(-8, 0)], signature)
	assert_eq(cache.size(), 2)

func test_reverse_query_order_has_identical_values() -> void:
	var keys := [Vector2i(-1, -1), Vector2i.ZERO, Vector2i(1, 1)]
	var forward := _cache(2)
	var reverse := _cache(2)
	var expected: Dictionary = {}
	for key: Vector2i in keys:
		expected[key] = forward.region(key).surface_height(key.x * 16, key.y * 16)
	keys.reverse()
	for key: Vector2i in keys:
		assert_almost_eq(reverse.region(key).surface_height(key.x * 16, key.y * 16),
			expected[key], 0.0001)
	assert_lte(forward.size(), 2)
	assert_lte(reverse.size(), 2)

func test_miss_observer_identifies_hidden_field_work_without_rebuilding_hits() -> void:
	var cache := _cache()
	var events: Array = []
	cache.profile_callback = func(stage: StringName, kind: StringName, key: Vector2i, elapsed: int):
		events.append([stage, kind, key, elapsed])
	var first := cache.water(Vector2i(-1, 2))
	assert_same(cache.water(Vector2i(-1, 2)), first)
	assert_eq(events.size(), 4)
	assert_eq(events[0].slice(0, 3), [&"begin", &"region", Vector2i(-1, 2)])
	assert_eq(events[1].slice(0, 3), [&"end", &"region", Vector2i(-1, 2)])
	assert_eq(events[2].slice(0, 3), [&"begin", &"water", Vector2i(-1, 2)])
	assert_eq(events[3].slice(0, 3), [&"end", &"water", Vector2i(-1, 2)])
	assert_gte(events[1][3], 0)
	assert_gte(events[3][3], 0)

## A 192 m block owns lattice points 16 k .. 16 k + 15 (12 m apart). Its
## region is certified over those points plus a 96 m (8 point) margin.
func test_block_region_certifies_its_points_with_a_96_m_margin() -> void:
	var cache := _cache(8)
	for key: Vector2i in [Vector2i.ZERO, Vector2i(-1, 0), Vector2i(2, -3)]:
		var region := cache.region(key)
		assert_eq(region.certified_points,
			Rect2i(key * 16 - Vector2i(8, 8), Vector2i(33, 33)), "block %s" % key)
		# Every tile corner of the block's 192 m sheet is a surface point.
		for corner: Vector2i in [key * 16, key * 16 + Vector2i(16, 0),
				key * 16 + Vector2i(0, 16), key * 16 + Vector2i(16, 16)]:
			assert_true(region.has_surface_point(corner.x, corner.y),
				"block %s tile corner %s" % [key, corner])


## A tile depends only on its four corners: a rectangle is covered when every
## tile corner floor(x0 / 12) .. floor(x1 / 12) + 1 is a surface point.
func test_region_covering_reads_every_tile_corner_of_the_rectangle() -> void:
	var cache := _cache(8)
	var inside := Rect2(10.0, 10.0, 170.0, 170.0)
	assert_same(cache.region_covering(inside), cache.region(Vector2i.ZERO),
		"a rectangle inside the block reuses the block region")
	for rect: Rect2 in [inside, Rect2(-150.0, -150.0, 520.0, 480.0),
			Rect2(-1000.0, 37.0, 12.0, 0.0), Rect2(95.9, -300.0, 700.0, 36.0)]:
		var region := cache.region_covering(rect)
		for j in range(floori(rect.position.y / 12.0), floori(rect.end.y / 12.0) + 2):
			for i in range(floori(rect.position.x / 12.0), floori(rect.end.x / 12.0) + 2):
				if not region.has_surface_point(i, j):
					fail_test("%s misses tile corner (%d, %d)" % [rect, i, j])
					return
		var bounds := TerrainTileField.height_bounds(region, rect)
		assert_true(is_finite(bounds.x) and bounds.x <= bounds.y, "%s bounds" % rect)
