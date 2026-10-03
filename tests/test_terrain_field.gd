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
	assert_eq(HeightfieldPlan.height01(Vector3.ZERO, SEED), 0.0)
	assert_eq(HeightfieldPlan.height01(Vector3(40, 0, -30), SEED), 0.0)
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
func test_spawn_surroundings_stay_gentle_on_every_seed() -> void:
	for seed_value: int in [42, 77777, 123456789, 991177, 2697992464, 1, 314159]:
		var top := 0.0
		for k in 64:
			var p := Vector2.from_angle(k * TAU / 64.0) * 180.0
			top = maxf(top, HeightfieldPlan.height01(Vector3(p.x, 0, p.y), seed_value) * TerrainField.REF_AMPLITUDE)
		assert_lte(top, 16.0, "seed %d: ring at 180 m stays within four storeys" % seed_value)

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
	assert_gt(slopes[slopes.size() / 2], 0.13, "median front slope")

## ...and highlands are not flat tables: their interiors swell toward broad
## high ground and lowlands dip into basins, so the large-scale layer varies
## inside each. The whole layer spans at least 140 m.
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
	assert_gt(high.max() - low.min(), 140.0, "the layer spans 140 m")

func _std(a: Array[float]) -> float:
	var m := 0.0
	for v in a: m += v
	m /= maxf(1.0, a.size())
	var s := 0.0
	for v in a: s += (v - m) * (v - m)
	return sqrt(s / maxf(1.0, a.size()))
