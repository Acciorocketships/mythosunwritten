extends GutTest

const SEED := 2697992464

func after_each() -> void:
	TerrainRegimeField.set_force_archetype(&"")

## Rivers trace the smooth field, so it must carry each regime's large-scale
## shape (massif spines, escarpment stairs, valley troughs), not only the base.
func test_smooth_field_carries_regime_macro_relief() -> void:
	TerrainRegimeField.set_force_archetype(&"highland_massif")
	var lo := INF
	var hi := -INF
	for i in 400:
		var p := Vector2(3000.0 + (i % 20) * 30.0, (i / 20) * 30.0)
		var smooth := TerrainField.height_m(p, SEED, false)
		var detail := TerrainField.height_m(p, SEED, true)
		lo = minf(lo, smooth)
		hi = maxf(hi, smooth)
		assert_lt(absf(smooth - detail), 16.0, "smooth field approximates the rendered one")
	assert_gt(hi - lo, 12.0, "massif spines are visible to rivers")

func test_height01_is_bounded_and_spawn_is_flat() -> void:
	# The clearing is flat at its surroundings' level (2026-10-04: no longer 0).
	assert_almost_eq(HeightfieldPlan.height01(Vector3(40, 0, -30), SEED), HeightfieldPlan.height01(Vector3.ZERO, SEED), 1e-6)
	assert_almost_eq(HeightfieldPlan.height01(Vector3.ZERO, SEED) * TerrainField.REF_AMPLITUDE, TerrainField.spawn_level_m(SEED), 1e-3)
	for z in range(-30, 31, 3):
		for x in range(-30, 31, 3):
			var h := HeightfieldPlan.height01(Vector3(x * 97.0, 0, z * 89.0), SEED)
			assert_between(h, 0.0, 1.0)

func test_no_archetype_clips_at_the_amplitude() -> void:
	for a: StringName in TerrainRegimeCatalog.ARCHETYPES:
		TerrainRegimeField.set_force_archetype(a)
		var top := 0.0
		for z in range(-20, 21):
			for x in range(-20, 21):
				top = maxf(top, TerrainField.height_m(Vector2(x * 61.0 + 3000.0, z * 59.0), SEED, true))
		assert_lt(top, TerrainField.REF_AMPLITUDE - 0.5, "%s stays under the ceiling" % a)

## A real jump survives bisection down to half a micrometre; a steep riser
## (terraces are near-vertical but continuous) shrinks to nothing.
func _assert_continuous_along(from: Vector2, to: Vector2, step: float) -> void:
	var n := int(from.distance_to(to) / step)
	var dir := (to - from).normalized()
	var prev := TerrainField.height_m(from, SEED, true)
	for i in range(1, n + 1):
		var p := from + dir * (i * step)
		var h := TerrainField.height_m(p, SEED, true)
		if absf(h - prev) > 0.05:
			var a := p - dir * step
			var b := p
			var ha := prev
			var hb := h
			for k in 20:
				var m := (a + b) * 0.5
				var hm := TerrainField.height_m(m, SEED, true)
				if absf(hm - ha) >= absf(hb - hm):
					b = m
					hb = hm
				else:
					a = m
					ha = hm
			assert_lt(absf(hb - ha), 0.01, "jump of %.3f m at %s" % [absf(hb - ha), a])
		prev = h

func test_field_is_continuous_across_regions_and_setpieces() -> void:
	for line in [[Vector2(-2600, 211), Vector2(2600, 211)], [Vector2(-433, -2600), Vector2(-433, 2600)],
			[Vector2(-1800, -1700), Vector2(1900, 1650)]]:
		_assert_continuous_along(line[0], line[1], 0.5)

func test_relief_now_survives_storey_quantization() -> void:
	var plan := TerrainWorldTuning.make_heightfield(SEED)
	var structured := 0
	var windows := 0
	for wz in range(-40, 40, 5):
		for wx in range(-40, 40, 5):
			var lo := 999
			var hi := -999
			for j in 4:
				for i in 4:
					var s := plan.storey_at(wx * 4 + i + 200, wz * 4 + j + 200)
					lo = mini(lo, s)
					hi = maxi(hi, s)
			windows += 1
			structured += int(hi > lo)
	assert_gt(float(structured) / windows, 0.4, "most 48 m windows hold a storey change")

## Reported in final review: the origin region was unconstrained, so several
## seeds had 30-40 m peaks and cliffs within 180 m of spawn (baseline 5-12 m).
## Since 2026-10-04 the spawn clearing sits at its surroundings' level, not
## at zero, so the ring is measured from the spawn's own height.
func test_spawn_surroundings_stay_gentle_on_every_seed() -> void:
	for seed_value: int in [42, 77777, 123456789, 991177, 2697992464, 1, 314159]:
		var spawn := HeightfieldPlan.height01(Vector3.ZERO, seed_value) * TerrainField.REF_AMPLITUDE
		var worst := 0.0
		for k in 64:
			var p := Vector2.from_angle(k * TAU / 64.0) * 180.0
			worst = maxf(worst, absf(HeightfieldPlan.height01(Vector3(p.x, 0, p.y), seed_value) * TerrainField.REF_AMPLITUDE - spawn))
		assert_lte(worst, 16.0, "seed %d: ring at 180 m stays within four storeys of spawn" % seed_value)

## Owner judging pass 2026-10-04 (found while checking it): on two of five
## seeds spawn stood in 1.2 m of water. The spawn clearing was flattened to
## height 0 and the large-scale layers faded to 0 round it, while lowlands now
## stand 24 m and more: spawn was a bowl that rivers ended in. The clearing
## must not sit in a bowl: the smooth field at spawn is within one storey of
## the median ground 400 m out or above it (hills may stand round spawn; the
## water itself is checked by test_september13_water_origin).
func test_spawn_is_not_a_pit() -> void:
	for seed_value: int in [42, 77777, 123456789, 991177, 2697992464, 1, 314159]:
		var spawn := HeightfieldPlan.height01(Vector3.ZERO, seed_value, false) * TerrainField.REF_AMPLITUDE
		var ring: Array[float] = []
		for k in 32:
			var p := Vector2.from_angle(k * TAU / 32.0) * 400.0
			ring.append(HeightfieldPlan.height01(Vector3(p.x, 0, p.y), seed_value, false) * TerrainField.REF_AMPLITUDE)
		ring.sort()
		assert_gte(spawn, ring[16] - 4.0, "seed %d: spawn %.1f m, median ground 400 m out %.1f m" % [seed_value, spawn, ring[16]])

## Owner review 2026-10-02: relief stayed "within the same few levels". Median
## relief over nine 500 m windows per archetype (before the mid-scale feature
## layer: rolling 13 m, ridge 21, escarpment 40, terraced 25, karst 17,
## tableland 24, massif 30, flats 5).
const MIN_RELIEF_500 := {&"rolling_downs": 30.0, &"ridge_and_pass": 45.0,
	&"escarpment_country": 45.0, &"terraced_valleys": 40.0, &"karst_hollows": 45.0,
	&"tableland": 45.0, &"highland_massif": 45.0, &"low_flats": 16.0}

func test_every_archetype_has_mid_scale_relief() -> void:
	for a: StringName in MIN_RELIEF_500:
		TerrainRegimeField.set_force_archetype(a)
		var ranges: Array[float] = []
		for wz in 3:
			for wx in 3:
				var lo := INF
				var hi := -INF
				for z in 21:
					for x in 21:
						var h := TerrainField.height_m(Vector2(9000.0 + wx * 600.0 + x * 24.0,
							600.0 + wz * 600.0 + z * 24.0), SEED, true)
						lo = minf(lo, h)
						hi = maxf(hi, h)
				ranges.append(hi - lo)
		ranges.sort()
		assert_gt(ranges[4], float(MIN_RELIEF_500[a]), "%s median relief per 500 m" % a)

## ...and wide areas of the map sit at very different elevations.
func test_wide_areas_differ_in_elevation() -> void:
	var means: Array[float] = []
	for k in 12:
		var total := 0.0
		for z in range(-4, 5):
			for x in range(-4, 5):
				total += TerrainField.height_m(Vector2(3000.0 + k * 1500.0 + x * 100.0, 4000.0 + z * 100.0), SEED, false)
		means.append(total / 81.0)
	assert_gt(means.max() - means.min(), 24.0, "1 km areas along an 18 km transect differ by six storeys or more")

## Owner review 2026-10-03: "large-scale height variation, where some parts of
## the map are higher than others". 3 km areas along a 40 km transect sit at
## mean elevations at least 60 m (15 storeys) apart.
func test_highlands_and_lowlands_across_the_map() -> void:
	var means: Array[float] = []
	for k in 14:
		var total := 0.0
		for z in range(-3, 4):
			for x in range(-3, 4):
				total += TerrainField.height_m(Vector2(4000.0 + k * 3000.0 + x * 400.0, -6000.0 + z * 400.0), SEED, false)
		means.append(total / 49.0)
	assert_gt(means.max() - means.min(), 60.0, "3 km areas differ by fifteen storeys or more")

## Owner review 2026-10-03 (second pass): a 96 m rise over ~1.5 km did not
## read even across the edge. Upland fronts rise over about 700 m: where the
## front is half way up, the elevation layer climbs at least 0.13 m per metre
## (104 m / 700 m averages 0.15).
func test_upland_fronts_rise_within_about_700_m() -> void:
	var slopes: Array[float] = []
	for z in range(-60, 61):
		for x in range(-60, 61):
			var p := Vector2(x * 200.0 + 37.0, z * 200.0 + 11.0)
			if p.length() < 3000.0:
				continue
			var u := TerrainField.upland01(SEED, p)
			if u < 0.4 or u > 0.6:
				continue
			var gx := TerrainField.elevation_m(SEED, p + Vector2(10, 0)) - TerrainField.elevation_m(SEED, p - Vector2(10, 0))
			var gz := TerrainField.elevation_m(SEED, p + Vector2(0, 10)) - TerrainField.elevation_m(SEED, p - Vector2(0, 10))
			slopes.append(Vector2(gx, gz).length() / 20.0)
	slopes.sort()
	assert_gt(slopes.size(), 20, "the window crosses upland fronts")
	# Owner review 2026-10-04: "amplify the change in elevation, it is not very
	# noticeable in-game": the front climbs at least 0.21 m per metre (was 0.13).
	assert_gt(slopes[slopes.size() / 2], 0.21, "median front slope")

## ...and highlands are not flat tables: their interiors swell toward broad
## high ground and lowlands dip into basins, so the large-scale layer varies
## inside each. The whole layer spans at least 220 m (140 m before the
## October 4 amplification).
func test_highlands_swell_and_lowlands_dip() -> void:
	var high: Array[float] = []
	var low: Array[float] = []
	for z in range(-60, 61):
		for x in range(-60, 61):
			var p := Vector2(x * 200.0 + 37.0, z * 200.0 + 11.0)
			if p.length() < 3000.0:
				continue
			var u := TerrainField.upland01(SEED, p)
			if u > 0.98:
				high.append(TerrainField.elevation_m(SEED, p))
			elif u < 0.02:
				low.append(TerrainField.elevation_m(SEED, p))
	assert_gt(_std(high), 8.0, "highland interiors vary")
	assert_gt(_std(low), 5.0, "lowlands vary")
	assert_gt(high.max() - low.min(), 220.0, "the layer spans 220 m")

func _std(a: Array[float]) -> float:
	var m := 0.0
	for v in a: m += v
	m /= maxf(1.0, a.size())
	var s := 0.0
	for v in a: s += (v - m) * (v - m)
	return sqrt(s / maxf(1.0, a.size()))

## Owner review 2026-10-04: "when I first spawned the terrain was very flat ...
## if this is the case in many places, I would like to fix it." Share of 96 m
## patches whose relief is under one storey (4 m): at most 13% between 400 m
## and 1.5 km from spawn and at most 8% from 1.5 to 10 km out (2026-10-03:
## about 22% and 12%; the low flats alone 31%). Measured 2026-10-04 on five
## seeds: 5-12% near spawn (seed 42, spawn on a broad lowland plain, 12.3%) and
## 6-8% beyond.
func _flat_share(seed_value: int, r_lo: float, r_hi: float, samples: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var flat := 0
	for n in samples:
		var r := sqrt(lerpf(r_lo * r_lo, r_hi * r_hi, rng.randf()))
		var c := Vector2.from_angle(rng.randf() * TAU) * r
		var lo := INF
		var hi := -INF
		for j in 5:
			for i in 5:
				var h := HeightfieldPlan.height01(Vector3(c.x - 48 + i * 24, 0, c.y - 48 + j * 24), seed_value)
				lo = minf(lo, h)
				hi = maxf(hi, h)
		flat += int((hi - lo) * TerrainField.REF_AMPLITUDE < 4.0)
	return float(flat) / samples

func test_little_ground_is_flat_near_spawn_or_beyond() -> void:
	for seed_value: int in [SEED, 42]:
		assert_lte(_flat_share(seed_value, 400.0, 1500.0, 300), 0.13, "seed %d: flat share near spawn" % seed_value)
		assert_lte(_flat_share(seed_value, 1500.0, 10000.0, 900), 0.08, "seed %d: flat share beyond" % seed_value)
