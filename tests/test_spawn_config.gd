extends GutTest

## Tests for TerrainSpawnConfig gating: filter_for_category + category_for_y.

func _dist(d: Dictionary) -> Distribution:
	var typed: Dictionary[String, float] = {}
	for k in d:
		typed[k] = d[k]
	return Distribution.new(typed)


func test_slope_drops_hill_sizes() -> void:
	var d := _dist({"point": 0.85, "8x8x2": 0.1, "4x4x4": 0.05})
	var out := TerrainSpawnConfig.filter_for_category(d, "slope")
	assert_false(out.dist.has("8x8x2"), "hill size 8x8x2 should be dropped on a slope")
	assert_false(out.dist.has("4x4x4"), "hill size 4x4x4 should be dropped on a slope")
	assert_true(out.dist.has("point"), "point foliage must survive on a slope")
	assert_almost_eq(out.dist["point"], 1.0, 0.0001, "surviving dist must renormalise to 1")


func test_slope_drops_structure_tags() -> void:
	var d := _dist({"grass": 0.3, "rock": 0.2, "hill": 0.05, "cliff-base-side": 0.3})
	var out := TerrainSpawnConfig.filter_for_category(d, "slope")
	assert_false(out.dist.has("hill"), "hill tag should be dropped on a slope")
	assert_false(out.dist.has("cliff-base-side"), "seed tag should be dropped on a slope")
	assert_true(out.dist.has("grass"), "foliage tag must survive on a slope")
	assert_true(out.dist.has("rock"), "foliage tag must survive on a slope")
	var total := 0.0
	for k in out.dist.keys():
		total += out.dist[k]
	assert_almost_eq(total, 1.0, 0.0001, "surviving foliage weights must renormalise to 1")


func test_level_returns_dist_unchanged() -> void:
	var d := _dist({"point": 0.85, "8x8x2": 0.15})
	var out := TerrainSpawnConfig.filter_for_category(d, "level")
	assert_same(out, d, "level category must return the same distribution object untouched")


func test_filter_never_empties_a_dist() -> void:
	var d := _dist({"8x8x2": 1.0})  # nothing but a structure
	var out := TerrainSpawnConfig.filter_for_category(d, "slope")
	assert_true(out.has_positive_weight(), "filter must never produce an unsamplable dist")


func test_category_for_y() -> void:
	assert_eq(TerrainSpawnConfig.category_for_y(0.0), "level", "plateau sockets at y~0 are level")
	assert_eq(TerrainSpawnConfig.category_for_y(-2.0), "slope", "sockets dropped below the plateau are slope")
	assert_eq(TerrainSpawnConfig.category_for_y(-0.5), "level", "boundary value is level (strict <)")
