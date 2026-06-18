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
	assert_eq(plan.quantize_storey(6.0), 2, "6.0m (=1.5 storeys) rounds half-up to 2")

func test_quantize_storey_min_floors_and_max_ceils() -> void:
	var lo: HeightfieldPlan = HeightfieldPlan.new(1, 32.0, 8, "min")
	var hi: HeightfieldPlan = HeightfieldPlan.new(1, 32.0, 8, "max")
	assert_eq(lo.quantize_storey(3.9), 0, "min => floor(3.9/4) = 0")
	assert_eq(hi.quantize_storey(0.1), 1, "max => ceil(0.1/4) = 1")
	assert_eq(hi.quantize_storey(4.0), 1, "max => ceil(4.0/4) = 1 at an exact storey boundary")
	assert_eq(lo.quantize_storey(4.0), 1, "min => floor(4.0/4) = 1 at an exact storey boundary")

func test_quantize_storey_clamps_to_max_storeys() -> void:
	var plan: HeightfieldPlan = HeightfieldPlan.new(1, 1000.0, 3, "mean")
	assert_eq(plan.quantize_storey(999.0), 3, "clamped to max_storeys")
	assert_eq(plan.quantize_storey(-5.0), 0, "never below 0")


# Build a Dictionary[Vector2i,int] from a row-major 2D array. rows[0] is z=0.
func _grid(rows: Array) -> Dictionary:
	var out: Dictionary = {}
	for z in range(rows.size()):
		var row: Array = rows[z]
		for x in range(row.size()):
			out[Vector2i(x, z)] = int(row[x])
	return out

func test_clamp_leaves_gentle_field_untouched() -> void:
	# Neighbours already differ by <=1: clamp is a no-op.
	var targets: Dictionary = _grid([[0, 1, 2], [1, 2, 3], [2, 3, 4]])
	var out: Dictionary = HeightfieldPlan.clamp_field(targets)
	assert_eq(out, targets, "already-valid field is unchanged")

func test_clamp_trickles_a_spike_into_a_staircase() -> void:
	# A lone storey-4 spike surrounded by 0s must trickle down to <=1 per step.
	var targets: Dictionary = _grid([
		[0, 0, 0, 0, 0],
		[0, 0, 0, 0, 0],
		[0, 0, 4, 0, 0],
		[0, 0, 0, 0, 0],
		[0, 0, 0, 0, 0],
	])
	var out: Dictionary = HeightfieldPlan.clamp_field(targets)
	# Center can be at most 1 above its (now-clamped) neighbours.
	assert_eq(out[Vector2i(2, 2)], 1, "spike clamped to one step above neighbours")
	# Every adjacent pair now differs by <=1.
	for cell in out.keys():
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			var nb: Vector2i = cell + d
			if out.has(nb):
				assert_true(absi(out[cell] - out[nb]) <= 1,
					"adjacent storeys differ by <=1 after clamp")

func test_clamp_is_order_independent() -> void:
	# Same input via two different key insertion orders => identical fixpoint.
	var a: Dictionary = _grid([[0, 5, 0], [5, 5, 5], [0, 5, 0]])
	var b: Dictionary = {}
	# Insert in reverse order.
	var keys: Array = a.keys()
	keys.reverse()
	for k in keys:
		b[k] = a[k]
	assert_eq(HeightfieldPlan.clamp_field(a), HeightfieldPlan.clamp_field(b),
		"clamp result independent of key order")

func test_clamp_checkerboard_order_matches_rowmajor() -> void:
	# A non-monotonic sweep order (even-parity cells, then odd) must still reach
	# the same unique fixpoint as the row-major order.
	var a: Dictionary = _grid([[0, 5, 0], [5, 5, 5], [0, 5, 0]])
	var checker: Dictionary = {}
	for parity in [0, 1]:
		for cell in a.keys():
			if (cell.x + cell.y) % 2 == parity:
				checker[cell] = a[cell]
	assert_eq(HeightfieldPlan.clamp_field(a), HeightfieldPlan.clamp_field(checker),
		"clamp fixpoint is independent of (checkerboard) sweep order")

func test_clamp_handles_degenerate_inputs() -> void:
	assert_eq(HeightfieldPlan.clamp_field({}), {}, "empty field clamps to empty")
	var single: Dictionary = {Vector2i(3, 7): 5}
	assert_eq(HeightfieldPlan.clamp_field(single), single,
		"single cell with no neighbours is unchanged")


func test_storey_at_quantizes_a_clamp_stable_ramp() -> void:
	# Spec intent: storeys = round(H / 4). When H rises exactly one storey (4m)
	# per tile in x, the quantized field is already a valid staircase, so the
	# trickle-down clamp is a no-op and storey_at reads the quantized storey off
	# directly: storey_at(cx, _) == cx. (The literal 2x3 example from the spec,
	# tested in isolation, would instead be legitimately trickled DOWN by the
	# clamp because it is surrounded by lower ground — quantization is verified
	# by the quantize_storey tests; this checks storey_at on a clamp-stable field.)
	var plan: HeightfieldPlan = HeightfieldPlan.new(1, 1000.0, 16, "mean")
	plan.set_raw_height_override(func(cx: int, cz: int) -> float:
		return float(cx) * HeightfieldPlan.STOREY_HEIGHT)
	assert_eq(plan.storey_at(0, 0), 0, "H=0m => storey 0")
	assert_eq(plan.storey_at(3, 2), 3, "H=12m => storey 3")
	assert_eq(plan.storey_at(7, -4), 7, "H=28m => storey 7")

func test_storey_at_is_window_independent() -> void:
	# The clamp propagates at most max_storeys tiles, so the default margin
	# yields the same value as a deliberately larger manual window.
	var plan: HeightfieldPlan = HeightfieldPlan.new(4242, 48.0, 8, "mean")
	var cx: int = 6
	var cz: int = -3
	var from_method: int = plan.storey_at(cx, cz)
	# Manual clamp over a window 4 tiles wider than the plan's margin.
	var m: int = plan.storey_margin() + 4
	var targets: Dictionary = {}
	for dz in range(-m, m + 1):
		for dx in range(-m, m + 1):
			var cell: Vector2i = Vector2i(cx + dx, cz + dz)
			targets[cell] = plan.quantize_storey(plan.raw_height(cell.x, cell.y))
	var wider: Dictionary = HeightfieldPlan.clamp_field(targets)
	assert_eq(from_method, wider[Vector2i(cx, cz)],
		"storey_at value is final regardless of window size")

func test_storey_at_lowers_a_spike_through_the_full_pipeline() -> void:
	# Integration: a lone tall column (well above max_storeys) surrounded by flat
	# ground must be trickled DOWN by storey_at to exactly one storey above its
	# neighbours — exercising quantize -> clamp where the clamp actively lowers
	# the queried cell (not the no-op ramp case).
	var plan: HeightfieldPlan = HeightfieldPlan.new(1, 100.0, 8, "mean")
	plan.set_raw_height_override(func(cx: int, cz: int) -> float:
		return 40.0 if (cx == 0 and cz == 0) else 0.0)
	assert_eq(plan.storey_at(0, 0), 1, "lone spike trickled to one storey above flat neighbours")
	assert_eq(plan.storey_at(5, 0), 0, "flat ground away from the spike stays at storey 0")


func test_surface_height_is_storey_times_4() -> void:
	var plan: HeightfieldPlan = HeightfieldPlan.new(1, 100.0, 8, "min")
	plan.set_raw_height_override(func(cx: int, cz: int) -> float: return 8.0)
	assert_almost_eq(plan.surface_height(0, 0), 8.0, 0.0001, "storey 2 => 8.0m")

func test_tile_plan_reports_storey_and_height() -> void:
	var plan: HeightfieldPlan = HeightfieldPlan.new(1, 100.0, 8, "min")
	plan.set_raw_height_override(func(cx: int, cz: int) -> float: return 4.0)
	var tp: Dictionary = plan.tile_plan(0, 0)
	assert_eq(tp["storey"], 1, "4.0m => storey 1")
	assert_almost_eq(tp["height"], 4.0, 0.0001, "height = storey * 4")

func test_invariant_adjacent_surface_differs_by_0_or_4() -> void:
	# Over a seeded region, the storey clamp guarantees adjacent cells differ by
	# at most one storey, so rendered surface heights differ by exactly 0 or 4m
	# (the Phase-1 invariant; levels add 0.5 in Phase 2).
	var plan: HeightfieldPlan = HeightfieldPlan.new(4242, 48.0, 8, "mean")
	for cz in range(-6, 7):
		for cx in range(-6, 7):
			var here: float = plan.surface_height(cx, cz)
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				var diff: float = absf(here - plan.surface_height(cx + d.x, cz + d.y))
				assert_true(diff < 0.001 or absf(diff - 4.0) < 0.001,
					"adjacent surface heights differ by 0 or 4m (got %.2f at %d,%d)" % [diff, cx, cz])


func test_detail_level_quantizes_residual_above_the_storey_base() -> void:
	# Flat field at 1.7m: storey 0 (mean: round(1.7/4)=0), residual 1.7m,
	# detail level = round(1.7/0.5) = 3.
	var plan: HeightfieldPlan = HeightfieldPlan.new(1, 100.0, 8, "mean")
	plan.set_raw_height_override(func(cx: int, cz: int) -> float: return 1.7)
	assert_eq(plan.detail_level(0, 0), 3, "residual 1.7m => 3 half-metre terraces")

func test_detail_level_caps_below_a_full_storey() -> void:
	# A column far above its (clamped) storey must not produce 8+ stacked levels;
	# detail level saturates at LEVELS_PER_STOREY - 1 = 7 (a full storey is a cliff).
	var plan: HeightfieldPlan = HeightfieldPlan.new(1, 1000.0, 8, "mean")
	plan.set_raw_height_override(func(cx: int, cz: int) -> float: return 100.0)
	assert_eq(plan.detail_level(0, 0), 7, "detail level never reaches a full storey")

func test_quantize_storey_still_correct_after_refactor() -> void:
	# Guards the _round_mode extraction: storey quantization is unchanged.
	var plan: HeightfieldPlan = HeightfieldPlan.new(1, 32.0, 8, "mean")
	assert_eq(plan.quantize_storey(6.1), 2, "6.1m still rounds to storey 2 after refactor")
