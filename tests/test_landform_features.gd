extends GutTest

## Mid-scale structured landforms (owner review 2026-10-02: the first pass "reads
## as noise"; wanted basins with an island, peak clusters with ridges, sheer
## mesas, tall rolling hills).

const SEED := 2697992464
const ST := 4.0

func after_each() -> void:
	TerrainRegimeField.set_force_archetype(&"")

func _max_params(kind: StringName) -> Dictionary:
	var out := {}
	var spec: Dictionary = TerrainRegimeCatalog.FEATURE_PARAMS[kind]
	for name: String in spec:
		out[name] = float(spec[name][1])
	return out

func _mid_params(kind: StringName) -> Dictionary:
	var out := {}
	var spec: Dictionary = TerrainRegimeCatalog.FEATURE_PARAMS[kind]
	for name: String in spec:
		out[name] = (float(spec[name][0]) + float(spec[name][1])) * 0.5
	return out

func _h(kind: StringName, q: Dictionary, local: Vector2) -> float:
	var v := LandformFeatures.shape(kind, q, local, 7)
	return v.x - v.y

func test_every_kind_fits_the_neighbourhood_and_vanishes_at_its_radius() -> void:
	for kind: StringName in TerrainRegimeCatalog.FEATURE_PARAMS:
		var q := _max_params(kind)
		var r := LandformFeatures.footprint_radius(kind, q)
		assert_lte(r, LandformFeatures.MAX_RADIUS, String(kind))
		for i in 24:
			var v := LandformFeatures.shape(kind, q, Vector2.from_angle(i * TAU / 24.0) * r, 7)
			assert_almost_eq(v.x, 0.0, 1e-4, "%s raise at edge" % kind)
			assert_almost_eq(v.y, 0.0, 1e-4, "%s cut at edge" % kind)

func test_basin_is_a_hollow_with_an_island_above_its_floor() -> void:
	var q := _mid_params(&"basin")
	q.island = 1.0
	var radius: float = q.radius_m
	var lowest := INF
	var rim := -INF
	for i in 41:
		for j in 41:
			var p := Vector2(i - 20, j - 20) / 20.0 * radius
			var h := _h(&"basin", q, p)
			lowest = minf(lowest, h)
			if p.length() > 0.5 * radius:
				rim = maxf(rim, h)
	assert_lt(lowest, -3.0 * ST, "the floor sinks at least three storeys")
	assert_gt(rim, lowest + 3.0 * ST, "a rim stands over the floor")
	assert_gt(_h(&"basin", q, Vector2.ZERO), lowest + 3.0 * ST, "the island rises clear of the floor")
	q.island = 0.0
	# The floor tilts (up to 30% deeper on one side), so the centre is floor
	# but not necessarily its lowest point.
	assert_lt(_h(&"basin", q, Vector2.ZERO), 0.7 * lowest, "no island: the centre is floor")

func test_peak_cluster_has_separate_summits_joined_by_lower_ridges() -> void:
	var q := _mid_params(&"peak_cluster")
	q.peaks = 3.0
	var summits := LandformFeatures.cluster_summits(q, 7)
	assert_eq(summits.size(), 3)
	for i in summits.size():
		var a: Vector2 = summits[i]
		var b: Vector2 = summits[(i + 1) % summits.size()]
		var top := minf(_h(&"peak_cluster", q, a), _h(&"peak_cluster", q, b))
		var saddle := _h(&"peak_cluster", q, (a + b) * 0.5)
		assert_lt(saddle, top - 2.0 * ST, "a saddle between summits %d and %d" % [i, (i + 1) % 3])
		assert_gt(saddle, 0.35 * top, "the ridge carries between summits %d and %d" % [i, (i + 1) % 3])
	var off: Vector2 = Vector2.from_angle(1.0) * q.radius_m * 0.8
	assert_lt(_h(&"peak_cluster", q, off), 0.5 * _h(&"peak_cluster", q, summits[0]), "flanks fall away")

func test_mesa_has_a_flat_top_and_a_sheer_edge() -> void:
	var q := _mid_params(&"mesa")
	q.tier = 0.0
	var top := _h(&"mesa", q, Vector2.ZERO)
	assert_almost_eq(_h(&"mesa", q, Vector2(q.radius_m * 0.1, 0)), top, 0.5, "flat top")
	assert_gte(top, 5.0 * ST, "a tall mesa")
	# Somewhere on the rim the ground drops at least three storeys within 12 m.
	var sheer := 0.0
	for i in 64:
		var dir := Vector2.from_angle(i * TAU / 64.0)
		var prev := _h(&"mesa", q, dir * 0.0)
		for k in range(1, int(q.radius_m * 1.6)):
			var here := _h(&"mesa", q, dir * float(k))
			var back := _h(&"mesa", q, dir * maxf(float(k) - 12.0, 0.0))
			sheer = maxf(sheer, back - here)
			prev = here
	assert_gt(sheer, 3.0 * ST, "a sheer cliff on the rim")

func test_ridge_has_a_pass_below_its_crest() -> void:
	var q := _mid_params(&"ridge")
	var crest := 0.0
	var lowest := INF
	for i in range(-80, 81):
		var u: float = i / 100.0 * q.half_length_m
		var h := _h(&"ridge", q, Vector2(u, 0))
		crest = maxf(crest, h)
		if absf(u) < 0.6 * q.half_length_m:
			lowest = minf(lowest, h)
	assert_gt(crest, 5.0 * ST, "a tall crest")
	assert_lt(lowest, crest - 2.0 * ST, "a pass cuts the crest")
	assert_lt(_h(&"ridge", q, Vector2(0, q.half_width_m * 1.2)), 0.25 * crest, "narrow across")

func test_hill_is_a_tall_rounded_hill() -> void:
	var q := _mid_params(&"hill")
	var top := _h(&"hill", q, Vector2.ZERO)
	assert_gt(top, 3.0 * ST)
	# Broad, not a spike: a few percent of the footprint stands above half the
	# summit height (a lone elongated ellipse gives ~5%, a spike under 1%).
	var high := 0
	var total := 0
	for i in 41:
		for j in 41:
			var p: Vector2 = Vector2(i - 20, j - 20) / 20.0 * q.radius_m
			if p.length() > q.radius_m:
				continue
			total += 1
			high += int(_h(&"hill", q, p) >= 0.5 * top)
	assert_gt(float(high) / total, 0.03, "a broad hill")

## Owner review 2026-10-03: features read as perfectly circular bumps and
## divots. Each outline (where the feature reaches half its centre value) must
## vary by at least 25% in radius round the feature, for several seeds.
func test_outlines_are_not_circular() -> void:
	for kind: StringName in [&"hill", &"peak", &"mesa", &"basin"]:
		var q := _mid_params(kind)
		q.island = 0.0
		for salt in [7, 8, 9, 10]:
			var centre := LandformFeatures.shape(kind, q, Vector2.ZERO, salt)
			var c := centre.x - centre.y
			var lo := INF
			var hi := 0.0
			for i in 32:
				var dir := Vector2.from_angle(i * TAU / 32.0)
				var r := 0.0
				while r < q.radius_m * 1.4:
					var v := LandformFeatures.shape(kind, q, dir * r, salt)
					if absf(v.x - v.y) < 0.5 * absf(c):
						break
					r += 2.0
				lo = minf(lo, r)
				hi = maxf(hi, r)
			assert_gt(hi, 1.25 * lo, "%s (salt %d) outline radius varies %.0f..%.0f m" % [kind, salt, lo, hi])

func test_valley_cuts_a_long_trough() -> void:
	var q := _mid_params(&"valley")
	var floor_at := _h(&"valley", q, Vector2(0, 0))
	assert_lt(floor_at, -3.0 * ST)
	assert_almost_eq(_h(&"valley", q, Vector2(q.half_length_m * 0.5, 0)), floor_at, 2.0, "long floor")
	assert_gt(_h(&"valley", q, Vector2(0, q.floor_half_m + q.side_m)), floor_at + 3.0 * ST, "valley sides")

func test_candidates_are_order_independent_and_sampling_is_continuous() -> void:
	var cells: Array[Vector2i] = []
	for z in range(-6, 7):
		for x in range(8, 21):
			cells.append(Vector2i(x, z))
	var forward := []
	for c in cells:
		forward.append(LandformFeatures.candidate(SEED, c))
	LandformFeatures.clear_caches()
	var backward := []
	for i in range(cells.size() - 1, -1, -1):
		backward.push_front(LandformFeatures.candidate(SEED, cells[i]))
	assert_eq(forward, backward)
	assert_gt(forward.filter(func(a): return not a.is_empty()).size(), 60, "features are dense")
	# Across cell lines the sample never jumps.
	for k in range(9, 20):
		for z in [133.0, -811.0, 1500.5]:
			var x := k * LandformFeatures.CELL
			var a := LandformFeatures.sample(SEED, Vector2(x - 1e-3, z))
			var b := LandformFeatures.sample(SEED, Vector2(x + 1e-3, z))
			assert_lt((a - b).length(), 0.05, "no jump at (%s, %s)" % [x, z])

func test_no_feature_near_spawn() -> void:
	for z in range(-3, 3):
		for x in range(-3, 3):
			var c := LandformFeatures.candidate(SEED, Vector2i(x, z))
			if not c.is_empty():
				assert_gt(c.pos.length() - c.radius, LandformFeatures.SPAWN_CLEAR_M - 1e-3)

## Found by the field continuity test (1547.1, 211): the peak's rounded summit
## left 0.6% of its height at the profile edge, then dropped to zero.
func test_peak_profile_reaches_zero_at_its_edge() -> void:
	var q := _mid_params(&"peak")
	for i in 32:
		var dir := Vector2.from_angle(i * TAU / 32.0)
		var lo := 0.0
		var hi: float = q.radius_m
		# Find where the profile ends along this direction, then step across it.
		for k in 40:
			var mid := (lo + hi) * 0.5
			if LandformFeatures.shape(&"peak", q, dir * mid, 7).x > 0.0: lo = mid
			else: hi = mid
		assert_lt(LandformFeatures.shape(&"peak", q, dir * lo, 7).x, 0.01, "no ledge at the edge (%d)" % i)

## River sources climb to summits and need the slope to vanish there: pointed
## cone tips and V crests stalled 30 of 81 district climbs (2026-10-02).
func test_summits_and_crests_are_rounded() -> void:
	var q := _mid_params(&"peak_cluster")
	q.peaks = 3.0
	for s: Vector2 in LandformFeatures.cluster_summits(q, 7):
		var g := (_h(&"peak_cluster", q, s + Vector2(0.5, 0)) - _h(&"peak_cluster", q, s - Vector2(0.5, 0))) / 1.0
		assert_lt(absf(g), 0.05, "a cluster summit is rounded")
	var r := _mid_params(&"ridge")
	var u: float = 0.75 * r.half_length_m * 0.5
	var across := (_h(&"ridge", r, Vector2(u, 0.5)) - _h(&"ridge", r, Vector2(u, -0.5)))
	var crest_v := 0.0
	# Locate the crest across the ridge at u, then check it is flat there.
	var best := -INF
	for k in range(-100, 101):
		var h := _h(&"ridge", r, Vector2(u, k * 0.5))
		if h > best:
			best = h
			crest_v = k * 0.5
	var g2 := _h(&"ridge", r, Vector2(u, crest_v + 0.5)) - _h(&"ridge", r, Vector2(u, crest_v - 0.5))
	assert_lt(absf(g2), 0.1, "a ridge crest is rounded")
