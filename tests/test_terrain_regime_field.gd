extends GutTest

const SEED := 2697992464

func after_each() -> void:
	TerrainRegimeField.set_force_archetype(&"")

func _points() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in 300:
		out.append(Vector2(fposmod(i * 911.7, 6000.0) - 3000.0, fposmod(i * 577.3, 6000.0) - 3000.0))
	return out

func _snapshot(points: Array[Vector2]) -> Array:
	var out := []
	for p in points:
		var row := [TerrainRegimeField.base_m(SEED, p)]
		for pair: Array in TerrainRegimeField.sample(SEED, p):
			row.append_array([pair[0].archetype, pair[1]])
		out.append(row)
	return out

func test_sampling_is_query_order_independent() -> void:
	var points := _points()
	var forward := _snapshot(points)
	TerrainRegimeField.clear_caches()
	var reversed_points := points.duplicate()
	reversed_points.reverse()
	var backward := _snapshot(reversed_points)
	backward.reverse()
	assert_eq(forward, backward)

func test_threads_agree_with_sequential_sampling() -> void:
	var points := _points()
	var expected := _snapshot(points)
	TerrainRegimeField.clear_caches()
	var workers: Array[Thread] = []
	for i in 3:
		var t := Thread.new()
		assert_eq(t.start(_snapshot.bind(points)), OK)
		workers.append(t)
	for t in workers:
		assert_eq(t.wait_to_finish(), expected)

func test_one_regime_outside_the_border_band() -> void:
	var inside := 0
	for p in _points():
		var s := TerrainRegimeField.sample(SEED, p)
		var total := 0.0
		for pair: Array in s:
			total += float(pair[1])
		assert_almost_eq(total, 1.0, 1e-9)
		assert_gte(float(s[0][1]), float(s[-1][1]), "nearest region weighs most")
		if s.size() > 1:
			inside += 1
		else:
			assert_eq(float(s[0][1]), 1.0)
	assert_gt(inside, 0, "some points fall in a border band")
	assert_lt(inside, 150, "most points have exactly one regime")

func test_region_parameters_respect_catalogue_ranges() -> void:
	for x in range(-4, 5):
		for z in range(-4, 5):
			var r := TerrainRegimeField.region(SEED, Vector2i(x, z))
			assert_has(TerrainRegimeCatalog.ARCHETYPES, r.archetype)
			assert_between(r.scale, 0.6, 1.7)
			var spec: Dictionary = TerrainRegimeCatalog.PARAMS[r.archetype]
			for name: String in spec:
				var lo: float = float(spec[name][0]) * (r.scale if name.ends_with("_m") else 1.0)
				var hi: float = float(spec[name][1]) * (r.scale if name.ends_with("_m") else 1.0)
				assert_between(float(r.params[name]), lo - 1e-6, hi + 1e-6, name)
			assert_almost_eq(r.base_m, float(r.params.base_level_st) * 4.0, 1e-6)

func test_base_is_continuous_across_node_lines() -> void:
	for i in range(-6, 7):
		var x := i * TerrainRegimeField.BASE_NODE
		assert_almost_eq(TerrainRegimeField.base_m(SEED, Vector2(x - 0.01, 77.0)),
			TerrainRegimeField.base_m(SEED, Vector2(x + 0.01, 77.0)), 0.01)

func test_force_archetype_overrides_every_region() -> void:
	TerrainRegimeField.set_force_archetype(&"tableland")
	for p in _points():
		assert_eq(TerrainRegimeField.region_at(SEED, p).archetype, &"tableland")

## The border blend must not depend on which of two equidistant runner-up sites
## is "second": found at (-433, -123.406) where escarpment and karst swapped.
func test_border_blend_is_continuous_where_runner_up_sites_swap() -> void:
	var a := TerrainField.height_m(Vector2(-433.0, -123.4062), SEED, true)
	var b := TerrainField.height_m(Vector2(-433.0, -123.4061), SEED, true)
	assert_lt(absf(a - b), 0.05)
