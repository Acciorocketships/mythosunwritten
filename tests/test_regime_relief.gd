extends GutTest

const SEED := 2697992464

func after_each() -> void:
	TerrainRegimeField.set_force_archetype(&"")

func _region(a: StringName, cell: Vector2i) -> Dictionary:
	TerrainRegimeField.set_force_archetype(a)
	return TerrainRegimeField.region(SEED, cell)

func test_every_archetype_is_deterministic_finite_and_bounded() -> void:
	for a: StringName in TerrainRegimeCatalog.ARCHETYPES:
		var r := _region(a, Vector2i(2, -3))
		var lo := INF
		var hi := -INF
		for i in 400:
			var p: Vector2 = r.site + Vector2(fposmod(i * 37.1, 600.0) - 300.0, fposmod(i * 53.3, 600.0) - 300.0)
			var h := RegimeRelief.relief_m(r, p)
			assert_eq(h, RegimeRelief.relief_m(r, p))
			assert_false(is_nan(h))
			lo = minf(lo, h)
			hi = maxf(hi, h)
		assert_between(lo, -30.0, 60.0, "%s min" % a)
		assert_between(hi, -30.0, 60.0, "%s max" % a)

## Since the mid-scale feature layer (owner review 2026-10-02) the regime relief
## is texture: bounded so it never drowns the structured landforms, yet present.
func test_regime_texture_stays_secondary_to_landforms() -> void:
	for a: StringName in TerrainRegimeCatalog.ARCHETYPES:
		var r := _region(a, Vector2i(1, 1))
		var lo := INF
		var hi := -INF
		for i in 900:
			var p: Vector2 = r.site + Vector2(i % 30, i / 30) * 12.0 - Vector2(180, 180)
			var h := RegimeRelief.relief_m(r, p)
			lo = minf(lo, h)
			hi = maxf(hi, h)
		assert_lt(hi - lo, 20.0, "%s texture spans under five storeys over 360 m" % a)
		if a != &"low_flats":
			assert_gt(hi - lo, 0.5, "%s texture is not flat" % a)

func test_terrace_regimes_use_storey_steps() -> void:
	for a: StringName in TerrainRegimeCatalog.ARCHETYPES:
		var t := RegimeRelief.terrace_of(_region(a, Vector2i(0, 4)))
		if t.x > 0.0:
			assert_almost_eq(fmod(t.x, 4.0), 0.0, 1e-6, "%s step is whole storeys" % a)
			assert_between(t.y, 0.0, 1.0)
	# Only terraced valleys terrace the whole field: terracing a noisy field
	# broke gentle slopes into dashed cliffs (escarpment and tableland terrace
	# only their own stepped component).
	assert_gt(RegimeRelief.terrace_of(_region(&"terraced_valleys", Vector2i(0, 0))).x, 0.0)
	assert_eq(RegimeRelief.terrace_of(_region(&"escarpment_country", Vector2i(0, 0))).x, 0.0)
	assert_eq(RegimeRelief.terrace_of(_region(&"rolling_downs", Vector2i(0, 0))).x, 0.0)

## Owner review 2026-10-03: no lunar speckle. The regime texture holds no
## isolated knobs or pits: no point stands 1.5 m above every point of a 48 m
## ring round it, or 1.5 m below every one (knolls, karst sinks, knobs and
## mounds did, by up to a storey or two). Ridge crests are not knobs: the ring
## meets them again along the crest.
func test_regime_texture_has_no_isolated_knobs_or_pits() -> void:
	for a: StringName in TerrainRegimeCatalog.ARCHETYPES:
		if a in [&"escarpment_country", &"terraced_valleys", &"tableland"]:
			continue  # their steps and plateau cells are structure, not knobs
		var r := _region(a, Vector2i(1, 1))
		var worst := 0.0
		for i in 1600:
			var p: Vector2 = r.site + Vector2(i % 40, i / 40) * 9.0 - Vector2(180, 180)
			var hi := -INF
			var lo := INF
			for k in 8:
				var v := RegimeRelief.relief_m(r, p + Vector2.from_angle(k * TAU / 8.0) * 48.0)
				hi = maxf(hi, v)
				lo = minf(lo, v)
			var h := RegimeRelief.relief_m(r, p)
			worst = maxf(worst, maxf(h - hi, lo - h))
		assert_lt(worst, 1.5, "%s: largest knob or pit" % a)
