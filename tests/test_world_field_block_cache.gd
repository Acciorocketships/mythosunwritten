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
		expected[key] = forward.region(key).surface_height(key.x * 8, key.y * 8)
	keys.reverse()
	for key: Vector2i in keys:
		assert_almost_eq(reverse.region(key).surface_height(key.x * 8, key.y * 8),
			expected[key], 0.0001)
	assert_lte(forward.size(), 2)
	assert_lte(reverse.size(), 2)
