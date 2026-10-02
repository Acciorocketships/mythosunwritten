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

## A real jump does not shrink when re-sampled finer; a steep riser does.
func _assert_continuous_along(from: Vector2, to: Vector2, step: float) -> void:
	var n := int(from.distance_to(to) / step)
	var dir := (to - from).normalized()
	var prev := TerrainField.height_m(from, SEED, true)
	for i in range(1, n + 1):
		var p := from + dir * (i * step)
		var h := TerrainField.height_m(p, SEED, true)
		var d := absf(h - prev)
		if d > 0.5:
			var fine := 0.0
			var q_prev := prev
			for k in range(1, 65):
				var q := TerrainField.height_m(p - dir * step + dir * (k * step / 64.0), SEED, true)
				fine = maxf(fine, absf(q - q_prev))
				q_prev = q
			assert_lt(fine, d * 0.5, "jump of %.2f m at %s does not shrink when refined" % [d, p])
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
