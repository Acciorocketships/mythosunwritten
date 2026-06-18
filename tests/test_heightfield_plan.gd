extends GutTest

# ------------------------------------------------------------
# HeightfieldPlan — numerical terrain plan (Phase 1: storeys)
# ------------------------------------------------------------

func test_raw_height_is_deterministic_per_seed() -> void:
	var a: HeightfieldPlan = HeightfieldPlan.new(4242)
	var b: HeightfieldPlan = HeightfieldPlan.new(4242)
	assert_almost_eq(a.raw_height(3, -5), b.raw_height(3, -5), 0.0001,
		"same seed + cell => same height")

func test_raw_height_scales_with_amplitude() -> void:
	# macro_density01 is in [0,1]; raw_height multiplies by amplitude, so it can
	# never exceed the amplitude and is non-negative.
	var plan: HeightfieldPlan = HeightfieldPlan.new(7, 40.0)
	var h: float = plan.raw_height(10, 10)
	assert_true(h >= 0.0 and h <= 40.0, "raw height stays within [0, amplitude]")

func test_raw_height_override_feeds_synthetic_field() -> void:
	var plan: HeightfieldPlan = HeightfieldPlan.new(1)
	plan.set_raw_height_override(func(cx: int, cz: int) -> float: return float(cx) + float(cz) * 0.5)
	assert_almost_eq(plan.raw_height(2, 4), 4.0, 0.0001, "override returns synthetic value")

func test_quantize_storey_mean_rounds_nearest() -> void:
	var plan: HeightfieldPlan = HeightfieldPlan.new(1, 32.0, 8, "mean")
	assert_eq(plan.quantize_storey(0.0), 0, "0m => storey 0")
	assert_eq(plan.quantize_storey(3.9), 1, "3.9m rounds to storey 1")
	assert_eq(plan.quantize_storey(5.0), 1, "5.0m rounds to storey 1")
	assert_eq(plan.quantize_storey(6.1), 2, "6.1m rounds to storey 2")

func test_quantize_storey_min_floors_and_max_ceils() -> void:
	var lo: HeightfieldPlan = HeightfieldPlan.new(1, 32.0, 8, "min")
	var hi: HeightfieldPlan = HeightfieldPlan.new(1, 32.0, 8, "max")
	assert_eq(lo.quantize_storey(3.9), 0, "min => floor(3.9/4) = 0")
	assert_eq(hi.quantize_storey(0.1), 1, "max => ceil(0.1/4) = 1")

func test_quantize_storey_clamps_to_max_storeys() -> void:
	var plan: HeightfieldPlan = HeightfieldPlan.new(1, 1000.0, 3, "mean")
	assert_eq(plan.quantize_storey(999.0), 3, "clamped to max_storeys")
	assert_eq(plan.quantize_storey(-5.0), 0, "never below 0")
