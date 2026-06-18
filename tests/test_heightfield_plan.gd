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
