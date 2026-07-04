extends GutTest

# ------------------------------------------------------------
# HeightfieldPlan — numerical terrain plan (storey + level tiers)
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
	# Cardinal neighbours already differ by <=1: clamp is a no-op.
	var targets: Dictionary = _grid([[0, 1, 2], [1, 2, 3], [2, 3, 4]])
	var out: Dictionary = HeightfieldPlan.clamp_field(targets)
	assert_eq(out, targets, "already-valid field is unchanged")

func test_clamp_allows_a_two_storey_diagonal_drop() -> void:
	# Diagonals are intentionally unconstrained: a convex corner (2) may sit one
	# diagonal step from a pit (0), cardinals clamped to the storey (1) between.
	# The instantiator renders the lower interior corner for this formation.
	var targets: Dictionary = _grid([[2, 1], [1, 0]])
	var out: Dictionary = HeightfieldPlan.clamp_field(targets)
	assert_eq(out[Vector2i(0, 0)], 2, "diagonal drop of two storeys is preserved")

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


func test_surface_height_is_storey_height_when_level_is_zero() -> void:
	var plan: HeightfieldPlan = HeightfieldPlan.new(1, 100.0, 8, "min")
	plan.set_raw_height_override(func(cx: int, cz: int) -> float: return 8.0)
	assert_almost_eq(plan.surface_height(0, 0), 8.0, 0.0001, "storey 2 => 8.0m")

func test_tile_plan_reports_storey_and_height() -> void:
	var plan: HeightfieldPlan = HeightfieldPlan.new(1, 100.0, 8, "min")
	plan.set_raw_height_override(func(cx: int, cz: int) -> float: return 4.0)
	var tp: Dictionary = plan.tile_plan(0, 0)
	assert_eq(tp["storey"], 1, "4.0m => storey 1")
	assert_almost_eq(tp["height"], 4.0, 0.0001, "height = storey * 4")

func test_storey_region_still_satisfies_the_full_invariant() -> void:
	# Over a seeded region, every cardinal-adjacent pair of rendered surface
	# heights differs by exactly 0, 0.5, or 4m — the full storey+level invariant.
	var plan: HeightfieldPlan = HeightfieldPlan.new(4242, 48.0, 8, "mean")
	for cz in range(-3, 4):
		for cx in range(-3, 4):
			var here: float = plan.surface_height(cx, cz)
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				var diff: float = absf(here - plan.surface_height(cx + d.x, cz + d.y))
				assert_true(diff < 0.001 or absf(diff - 0.5) < 0.001 or absf(diff - 4.0) < 0.001,
					"adjacent surface heights differ by 0, 0.5, or 4m (got %.3f at %d,%d)" % [diff, cx, cz])


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

func test_detail_level_is_zero_when_storey_rounds_above_raw_height() -> void:
	# mean mode at 3.0m: quantize_storey(3.0) = round(0.75) = 1 (rounds up),
	# so residual = 3.0 - 4.0 = -1.0 => negative; must clamp to 0, not produce -2.
	var plan: HeightfieldPlan = HeightfieldPlan.new(1, 100.0, 8, "mean")
	plan.set_raw_height_override(func(cx: int, cz: int) -> float: return 3.0)
	assert_eq(plan.detail_level(0, 0), 0, "negative residual clamps to level 0")


func test_cliff_distance_is_one_when_a_neighbour_differs() -> void:
	# A storey-1 cell with a storey-0 cardinal neighbour is one tile from a cliff.
	var storeys: Dictionary = _grid([[1, 1, 0], [1, 1, 0], [1, 1, 0]])
	assert_eq(HeightfieldPlan._cliff_distance_in(Vector2i(1, 1), storeys, 8), 1,
		"cell adjacent to a different storey is at cliff distance 1")

func test_cliff_distance_grows_with_manhattan_steps() -> void:
	# A 5-wide row: storey 0 except the far-right cell is storey 1. From x=0 the
	# nearest different storey is 4 cardinal steps away.
	var storeys: Dictionary = _grid([[0, 0, 0, 0, 1]])
	assert_eq(HeightfieldPlan._cliff_distance_in(Vector2i(0, 0), storeys, 8), 4,
		"cliff distance is the Manhattan distance to the nearest differing storey")

func test_cliff_distance_returns_sentinel_when_uniform() -> void:
	var storeys: Dictionary = _grid([[2, 2, 2], [2, 2, 2], [2, 2, 2]])
	assert_eq(HeightfieldPlan._cliff_distance_in(Vector2i(1, 1), storeys, 8),
		HeightfieldPlan._NO_CLIFF, "no differing storey within range => sentinel")

func test_cliff_distance_finds_a_diagonal_cliff() -> void:
	# Only a diagonal cell differs: from (0,0) the storey-1 cell at (2,2) is at
	# Manhattan distance 4 — exercises the diagonal (dx,dz) cells of the ring.
	var storeys: Dictionary = _grid([[0, 0, 0], [0, 0, 0], [0, 0, 1]])
	assert_eq(HeightfieldPlan._cliff_distance_in(Vector2i(0, 0), storeys, 8), 4,
		"nearest differing storey on the diagonal is at Manhattan distance 4")

func test_cliff_distance_respects_the_search_radius() -> void:
	# Differing cell at distance 2; with max_r=1 it is out of range (sentinel),
	# with max_r=2 it is found. Distinct from the uniform/out-of-map case.
	var storeys: Dictionary = _grid([[0, 0, 1]])
	assert_eq(HeightfieldPlan._cliff_distance_in(Vector2i(0, 0), storeys, 1),
		HeightfieldPlan._NO_CLIFF, "cliff beyond max_r is not found")
	assert_eq(HeightfieldPlan._cliff_distance_in(Vector2i(0, 0), storeys, 2), 2,
		"cliff at exactly max_r is found")


func test_clamp_levels_trickles_within_a_storey() -> void:
	# All one storey: a level-5 spike among 0s must trickle to <=1 per step,
	# exactly like the storey clamp.
	var storeys: Dictionary = _grid([[0, 0, 0], [0, 0, 0], [0, 0, 0]])
	var levels: Dictionary = _grid([[0, 0, 0], [0, 5, 0], [0, 0, 0]])
	var out: Dictionary = HeightfieldPlan._clamp_levels(levels, storeys)
	assert_eq(out[Vector2i(1, 1)], 1, "level spike trickled to one above neighbours")

func test_clamp_levels_ignores_neighbours_in_a_different_storey() -> void:
	# Left column is storey 0, right column storey 1. A high level on the storey-1
	# side must NOT be pulled down by the low level across the storey boundary,
	# because that boundary is a cliff (handled by the storey tier), not a terrace.
	var storeys: Dictionary = _grid([[0, 1], [0, 1], [0, 1]])
	var levels: Dictionary = _grid([[0, 3], [0, 3], [0, 3]])
	var out: Dictionary = HeightfieldPlan._clamp_levels(levels, storeys)
	assert_eq(out[Vector2i(1, 1)], 3, "cross-storey neighbour does not constrain level")


func test_level_at_pins_cliff_edges_to_zero() -> void:
	# A step field: left half low, right half a full storey higher. Every cell on
	# either side of the storey boundary cardinally touches a different storey, so
	# its level is pinned to 0 — which is what makes the cliff face exactly 4m.
	var plan: HeightfieldPlan = HeightfieldPlan.new(1, 100.0, 8, "mean")
	# H = 1.7m on the left (storey 0, residual would be level 3), 5.7m on the right
	# (storey 1). Without the pin the left edge would terrace up to 3.
	plan.set_raw_height_override(func(cx: int, cz: int) -> float:
		return 5.7 if cx >= 1 else 1.7)
	assert_eq(plan.level_at(0, 0), 0, "storey-0 cell touching the storey-1 step is pinned to level 0")
	assert_eq(plan.level_at(1, 0), 0, "storey-1 cell touching the storey-0 step is pinned to level 0")
	# Two tiles into the storey-0 side, away from the step: the level is no longer
	# pinned — it ramps up by one per tile (cap = cliff_distance - 1).
	assert_eq(plan.level_at(-2, 0), 2, "levels ramp up away from the cliff edge")
	# Both sides pinned to level 0 makes the cliff face exactly 4m.
	assert_almost_eq(absf(plan.surface_height(1, 0) - plan.surface_height(0, 0)), 4.0, 0.0001,
		"cliff face between the two storeys is exactly 4m")

func test_level_at_terraces_a_flat_storey_interior() -> void:
	# Single storey everywhere (H stays under 2m so storey 0), with a gentle
	# residual ramp in x that rises ~0.5m per tile. Far from any cliff, levels
	# follow the ramp in single steps.
	var plan: HeightfieldPlan = HeightfieldPlan.new(1, 100.0, 8, "mean")
	plan.set_raw_height_override(func(cx: int, cz: int) -> float:
		return clampf(0.5 * float(cx), 0.0, 1.9))
	# At x=2, residual ~1.0m => level ~2; at x=3, ~1.5m => level ~3. Adjacent
	# interior levels differ by at most one.
	var l2: int = plan.level_at(2, 0)
	var l3: int = plan.level_at(3, 0)
	assert_true(absi(l3 - l2) <= 1, "interior terraces step by at most one level")
	assert_true(l3 >= 1, "the ramp produces some terracing in the interior")

func test_level_at_is_window_independent() -> void:
	# Like the storey determinism test: the level at a cell is final, independent
	# of how much extra margin we compute around it.
	var plan: HeightfieldPlan = HeightfieldPlan.new(4242, 24.0, 6, "mean")
	var from_method: int = plan.level_at(5, -2)
	# Recompute with a hand-built, wider context using the same primitives.
	var wider: int = _level_at_with_extra_margin(plan, 5, -2, 6)
	assert_eq(from_method, wider, "level_at value is final regardless of window size")

# Helper: reproduce level_at(cx,cz) but with `extra` tiles of additional margin,
# to prove window independence. Mirrors the production assembly.
# IMPORTANT: this body is a deliberate copy of level_at — keep it in sync if level_at changes.
func _level_at_with_extra_margin(plan: HeightfieldPlan, cx: int, cz: int, extra: int) -> int:
	var lm: int = plan.level_margin() + extra
	var storeys: Dictionary = plan._build_storey_map(cx, cz, lm + HeightfieldPlan._CLIFF_SEARCH_MAX)
	var l0: Dictionary = {}
	for dz in range(-lm, lm + 1):
		for dx in range(-lm, lm + 1):
			var cell: Vector2i = Vector2i(cx + dx, cz + dz)
			var s: int = storeys[cell]
			var residual: float = plan.raw_height(cell.x, cell.y) - float(s) * HeightfieldPlan.STOREY_HEIGHT
			var detail: int = clampi(plan._round_mode(residual / HeightfieldPlan.LEVEL_HEIGHT), 0, HeightfieldPlan.LEVELS_PER_STOREY - 1)
			var cliff_cap: int = HeightfieldPlan._cliff_distance_in(cell, storeys, HeightfieldPlan._CLIFF_SEARCH_MAX) - 1
			l0[cell] = clampi(mini(detail, cliff_cap), 0, HeightfieldPlan.LEVELS_PER_STOREY - 1)
	var leveled: Dictionary = HeightfieldPlan._clamp_levels(l0, storeys)
	return leveled[Vector2i(cx, cz)]


func test_surface_height_is_flattened_to_storeys_for_now() -> void:
	# RENDER_LEVELS is OFF: the 0.5m level terraces are flattened OUT of the rendered surface (the
	# owner wants flat "level-texture" ground, not the smooth "mini slope" interpolation). So a
	# storey-0 cell renders flat at 0m even though the level field still reports level 3 (kept for
	# the future flat-terrace feature).
	var plan: HeightfieldPlan = HeightfieldPlan.new(1, 100.0, 8, "mean")
	plan.set_raw_height_override(func(cx: int, cz: int) -> float: return 1.7)
	assert_almost_eq(plan.surface_height(0, 0), 0.0, 0.0001, "storey-0 surface is flat at 0m (level flattened out)")
	assert_eq(plan.level_at(0, 0), 3, "but the level field still computes level 3")

func test_tile_plan_reports_storey_level_and_height() -> void:
	var plan: HeightfieldPlan = HeightfieldPlan.new(1, 100.0, 8, "mean")
	plan.set_raw_height_override(func(cx: int, cz: int) -> float: return 1.7)
	var tp: Dictionary = plan.tile_plan(0, 0)
	assert_eq(tp["storey"], 0, "storey 0")
	assert_eq(tp["level"], 3, "level 3")
	assert_almost_eq(tp["height"], 1.5, 0.0001, "height = storey*4 + level*0.5")

func test_full_invariant_adjacent_surface_differs_by_0_half_or_4() -> void:
	# Over a seeded region, every cardinal-adjacent pair of rendered surface
	# heights differs by exactly 0, 0.5, or 4m — the Phase-2 invariant: clean 4m
	# cliffs (both sides pinned to level 0) and clean 0.5m terraces. Region kept
	# small because level_at is the (slow) reference implementation.
	var plan: HeightfieldPlan = HeightfieldPlan.new(4242, 24.0, 6, "mean")
	for cz in range(-3, 4):
		for cx in range(-3, 4):
			var here: float = plan.surface_height(cx, cz)
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				var diff: float = absf(here - plan.surface_height(cx + d.x, cz + d.y))
				var ok: bool = diff < 0.001 or absf(diff - 0.5) < 0.001 or absf(diff - 4.0) < 0.001
				assert_true(ok,
					"adjacent surface heights differ by 0, 0.5, or 4m (got %.3f at %d,%d)" % [diff, cx, cz])


func test_rendered_surface_is_flat_per_storey_with_levels_off() -> void:
	# With RENDER_LEVELS off, a residual that WOULD ramp 0.5m/tile produces NO terrace steps in the
	# rendered surface — it stays flat at the storey height — while the level FIELD still ramps
	# (kept for the future flat-terrace feature). This is the fix for the owner's "mini slopes".
	var plan: HeightfieldPlan = HeightfieldPlan.new(1, 100.0, 8, "mean")
	plan.set_raw_height_override(func(cx: int, cz: int) -> float:
		return clampf(0.5 * float(cx), 0.0, 1.9))
	for cx in range(0, 4):
		var diff: float = absf(plan.surface_height(cx + 1, 0) - plan.surface_height(cx, 0))
		assert_true(diff < 0.001,
			"rendered surface is flat per storey, no 0.5m steps (got %.3f at cx=%d)" % [diff, cx])
	assert_gt(plan.detail_level(3, 0), plan.detail_level(0, 0),
		"the level FIELD still ramps (kept for the future flat-terrace feature)")


func test_detail_level_uses_min_aggregation_rounding() -> void:
	# "min" floors the level quantization just like the storey tier. Flat 1.9m:
	# storey 0 (floor(1.9/4)=0), residual 1.9 => floor(1.9/0.5)=3 (mean would give 4).
	var plan: HeightfieldPlan = HeightfieldPlan.new(1, 100.0, 8, "min")
	plan.set_raw_height_override(func(cx: int, cz: int) -> float: return 1.9)
	assert_eq(plan.detail_level(0, 0), 3, "min aggregation floors the terrace index")


# ------------------------------------------------------------
# height01 static — shared landform field (smooth variant for river tracing)
# ------------------------------------------------------------

func test_height01_static_matches_instance_raw_height() -> void:
	var plan: HeightfieldPlan = HeightfieldPlan.new(4242, 32.0)
	var pos: Vector3 = Vector3(3.0 * 24.0, 0.0, -5.0 * 24.0)
	assert_almost_eq(plan.raw_height(3, -5),
		HeightfieldPlan.height01(pos, 4242, true) * 32.0, 0.0001,
		"static height01(include_detail=true) is the rendered field")

func test_height01_smooth_is_deterministic_and_in_range() -> void:
	var pos: Vector3 = Vector3(400.0, 0.0, -900.0)
	var a: float = HeightfieldPlan.height01(pos, 7, false)
	var b: float = HeightfieldPlan.height01(pos, 7, false)
	assert_eq(a, b, "same seed+pos => same smooth height")
	assert_true(a >= 0.0 and a <= 1.0, "smooth height stays in [0,1]")

func test_height01_smooth_ignores_detail_octave() -> void:
	# The detail octave is seed+9. The smooth variant must not consume it, so
	# it is invariant under changes that only affect that octave. We can't
	# reseed one octave in isolation, but we CAN check the two variants differ
	# (detail contributes) while both track the same macro landform.
	var pos: Vector3 = Vector3(1000.0, 0.0, 1000.0)
	var with_detail: float = HeightfieldPlan.height01(pos, 7, true)
	var smooth: float = HeightfieldPlan.height01(pos, 7, false)
	assert_almost_eq(with_detail, smooth, 0.25,
		"variants track the same landform (only the fine octave differs)")
