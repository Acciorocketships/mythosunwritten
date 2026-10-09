extends GutTest

const SEED := 2697992464

func test_scrolling_keeps_the_previous_map_until_the_exact_successor_is_complete() -> void:
	var map := BiomeGroundMap.new()
	assert_true(map._prepare(Vector2.ZERO, SEED))
	assert_eq(hash(map._values), 3950268235)
	var old := map._values
	var target := Vector2(BiomeGroundMap.SCROLL, 0)
	var calls := 0
	while not map._prepare(target, SEED):
		assert_eq(map._centre, Vector2.ZERO)
		assert_eq(map._values, old)
		calls += 1
		if calls > BiomeGroundMap.SIDE:
			fail_test("scroll never completed")
			return
	assert_gt(calls, 0, "the rebuild spans frames")
	assert_eq(map._centre, target)
	assert_eq(hash(map._values), 2935280639)
	assert_eq(map._values, BiomeGroundMap.samples(target - Vector2.ONE * BiomeGroundMap.SPAN * 0.5, SEED))

func test_reversing_direction_and_changing_seed_discards_unpublished_rows() -> void:
	var map := BiomeGroundMap.new()
	map._prepare(Vector2.ZERO, SEED)
	map._prepare(Vector2(BiomeGroundMap.SCROLL, 0), SEED)
	assert_false(map._prepare(Vector2.ZERO, SEED))
	assert_true(map._pending_values.is_empty())
	var target := Vector2(-BiomeGroundMap.SCROLL, BiomeGroundMap.SCROLL)
	map._prepare(target, SEED)
	assert_true(map._prepare(target, SEED + 1))
	assert_eq(map._values, BiomeGroundMap.samples(target - Vector2.ONE * BiomeGroundMap.SPAN * 0.5, SEED + 1))
