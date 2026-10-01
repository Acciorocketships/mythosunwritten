extends GutTest

# HeightfieldPlan.LOWPASS_M: separable (1,2,1)/4 tent over the natural field,
# applied before the water carve (the carve itself is never filtered).

const SEED := 4242
const AMP := 32.0

class _Carve extends RefCounted:
	func carve_at(x: float, z: float) -> float:
		return 3.0 + 0.01 * x - 0.02 * z

func after_each() -> void:
	HeightfieldPlan.LOWPASS_M = 0.0

func _unfiltered(i: int, j: int) -> float:
	return HeightfieldPlan.height01(Vector3(12.0 * i, 0.0, 12.0 * j), SEED, true) * AMP

func _tent(i: int, j: int, r: float) -> float:
	var sum := 0.0
	var w := [1.0, 2.0, 1.0]
	for a in 3:
		for b in 3:
			var pos := Vector3(12.0 * i + (a - 1) * r, 0.0, 12.0 * j + (b - 1) * r)
			sum += w[a] * w[b] * HeightfieldPlan.height01(pos, SEED, true)
	return sum / 16.0 * AMP

func test_off_reproduces_unfiltered_field() -> void:
	HeightfieldPlan.LOWPASS_M = 0.0
	var plan := HeightfieldPlan.new(SEED, AMP)
	for i in range(-6, 7, 3):
		for j in range(-6, 7, 3):
			assert_eq(plan.raw_height(i, j), _unfiltered(i, j), "off is exact at %d,%d" % [i, j])
			assert_eq(plan.uncarved_height(i, j), _unfiltered(i, j))

func test_filter_is_tent_average_at_nine_offsets() -> void:
	HeightfieldPlan.LOWPASS_M = 12.0
	var plan := HeightfieldPlan.new(SEED, AMP)
	var differs := false
	for i in range(-6, 7, 3):
		for j in range(-6, 7, 3):
			assert_almost_eq(plan.raw_height(i, j), _tent(i, j, 12.0), 1e-4, "tent at %d,%d" % [i, j])
			assert_almost_eq(plan.uncarved_height(i, j), _tent(i, j, 12.0), 1e-4)
			if absf(plan.raw_height(i, j) - _unfiltered(i, j)) > 1e-3:
				differs = true
	assert_true(differs, "the filter changes the field somewhere")

func test_carve_is_not_filtered() -> void:
	HeightfieldPlan.LOWPASS_M = 12.0
	var plan := HeightfieldPlan.new(SEED, AMP)
	var carve := _Carve.new()
	plan.set_water_plan(carve)
	for p: Vector2i in [Vector2i(2, -3), Vector2i(-5, 4), Vector2i(0, 0)]:
		var expected := _tent(p.x, p.y, 12.0) - carve.carve_at(12.0 * p.x, 12.0 * p.y)
		assert_almost_eq(plan.raw_height(p.x, p.y), expected, 1e-4, "carve applied once, unfiltered")
		assert_almost_eq(plan.uncarved_height(p.x, p.y), _tent(p.x, p.y, 12.0), 1e-4)

func test_natural01_matches_height01_when_off() -> void:
	var pos := Vector3(130.0, 0.0, -75.0)
	assert_eq(HeightfieldPlan.natural01(pos, SEED), HeightfieldPlan.height01(pos, SEED, true))
