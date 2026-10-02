extends GutTest

const SEED := 2697992464

func _grid() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for z in range(-12, 13):
		for x in range(-12, 13):
			out.append(Vector2(x * 37.3 + 0.17, z * 41.9 - 0.31))
	return out

func test_noise_primitives_are_deterministic_and_bounded() -> void:
	for p in _grid():
		var h := ReliefPrimitives.hummock(p, SEED, 90.0, 3)
		assert_eq(h, ReliefPrimitives.hummock(p, SEED, 90.0, 3))
		assert_between(h, 0.0, 1.0)
		var r := ReliefPrimitives.ridged(p, SEED, 200.0, 4, 2.0)
		assert_between(r, 0.0, 1.0)
		assert_between(ReliefPrimitives.pass_mod(p, SEED, 300.0, 0.6), 0.4, 1.0)
		assert_between(ReliefPrimitives.gully(p, SEED, 40.0, Vector2(0.6, 0.8)), -1.0, 1.0)
		assert_between(ReliefPrimitives.sites_bump(p, SEED, 120.0, 0.5, 60.0, 0.3), 0.0, 1.0)

func test_wavelengths_scale_the_domain() -> void:
	for p in _grid():
		assert_almost_eq(ReliefPrimitives.hummock(p * 2.0, SEED, 180.0, 3),
			ReliefPrimitives.hummock(p, SEED, 90.0, 3), 1e-6)
		assert_almost_eq(ReliefPrimitives.ridged(p * 3.0, SEED, 600.0, 4, 2.0),
			ReliefPrimitives.ridged(p, SEED, 200.0, 4, 2.0), 1e-6)

func test_terrace_treads_land_on_step_multiples() -> void:
	var previous := -INF
	for i in 4000:
		var h := i * 0.013
		var t := ReliefPrimitives.terrace(h, 8.0, 0.15)
		var k := floorf(h / 8.0)
		assert_between(t, k * 8.0, (k + 1.0) * 8.0)
		if h / 8.0 - k < 0.85:
			assert_eq(t, k * 8.0, "tread is flat at a step multiple (h=%f)" % h)
		assert_gte(t, previous, "terrace is monotone")
		previous = t

func test_sites_bump_is_continuous() -> void:
	var prev := ReliefPrimitives.sites_bump(Vector2(-600, 13), SEED, 100.0, 0.6, 90.0, 0.2)
	for i in range(1, 4800):
		var v := ReliefPrimitives.sites_bump(Vector2(-600 + i * 0.25, 13), SEED, 100.0, 0.6, 90.0, 0.2)
		assert_lt(absf(v - prev), 0.03, "no jump at x=%f" % (-600 + i * 0.25))
		prev = v

func test_worley_distances_are_ordered_and_continuous() -> void:
	var prev := ReliefPrimitives.worley(Vector2(-400, 7), SEED, 80.0)
	for i in range(1, 3200):
		var w := ReliefPrimitives.worley(Vector2(-400 + i * 0.25, 7), SEED, 80.0)
		assert_lte(w.x, w.y)
		assert_lt(absf((w.y - w.x) - (prev.y - prev.x)), 0.51, "F2-F1 continuous")
		prev = w

## Reported in final review: the Gaussian window was cut off at the 3x3 block,
## so gully jumped ~0.04 at every kernel-cell line (e.g. x = 1800, seed 123).
func test_gully_is_continuous_across_kernel_cells() -> void:
	var down := Vector2(0.3, 1.0)
	for k in range(-20, 21):
		for z in [285.07, -133.3, 17.9]:
			var x := k * 50.0
			var a := ReliefPrimitives.gully(Vector2(x - 1e-4, z), 123, 50.0, down)
			var b := ReliefPrimitives.gully(Vector2(x + 1e-4, z), 123, 50.0, down)
			assert_lt(absf(a - b), 1e-3, "gully jump at (%s, %s)" % [x, z])
