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
