# Heightfield Terrain — Level Tier (Phase 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the sub-storey level (0.5m terrace) tier to `HeightfieldPlan`, so the numerical plan produces both 4m cliffs and 0.5m terraces while guaranteeing every adjacent pair of cells differs in height by exactly 0, 0.5, or 4 metres.

**Architecture:** Within each storey plateau, a cell gets a terrace `level` in `[0, 7]` derived from the sub-storey residual height. Two rules keep faces clean: (1) a cell that cardinally touches a different storey is pinned to level 0 (so both sides of a cliff sit at level 0 and the drop is exactly 4m), with levels ramping inward via a distance-to-cliff cap; (2) a storey-masked trickle-down clamp keeps same-storey neighbours within one level of each other. Both rules reuse Phase 1's monotone-clamp pattern. Still pure numerical (no tile instantiation — that is Phase 3).

**Tech Stack:** Godot 4.5 typed GDScript, GUT — tests under `tests/`.

---

## Scope and Phasing

This is **Phase 2 of 4** (see `docs/superpowers/specs/2026-06-17-heightfield-terrain-design.md`). Phase 1 delivered the storey (cliff) tier in `scripts/terrain/heightfield/HeightfieldPlan.gd`. This phase adds the level tier to the same class. Tile instantiation + variant mapping + streaming (Phase 3) and the cutover that removes the emergent rules (Phase 4) remain future plans. As in Phase 1, **no changes are made to the live generator** — this is pure additive numerical work validated by GUT tests.

## File Structure

- Modify: `scripts/terrain/heightfield/HeightfieldPlan.gd` — add level-tier constants, a shared rounding helper, and the level methods. The class's single responsibility ("the numerical terrain plan") covers both tiers; keeping them together is intentional cohesion. If after this phase the file feels overgrown, Phase 3 can extract a `LevelField` helper — do not split preemptively here.
- Modify: `tests/test_heightfield_plan.gd` — append level-tier tests.

## Existing Phase-1 API (already present, do not rewrite)

`HeightfieldPlan` (extends RefCounted) currently has: consts `TILE=24.0`, `STOREY_HEIGHT=4.0`, `_CARDINALS`; vars `world_seed`, `height_amplitude`, `max_storeys`, `aggregation`, `_raw_override`; methods `_init`, `set_raw_height_override`, `raw_height`, `quantize_storey`, static `clamp_field`, `storey_margin`, `storey_at`, `surface_height`, `tile_plan`. `quantize_storey` currently inlines the min/mean/max `match`; Task 1 extracts that into a shared `_round_mode` helper (behaviour-preserving) so the level tier can reuse it.

## Conventions

- Run the heightfield suite from `/Users/ryko/story`:
```
/Applications/Godot.app/Contents/MacOS/Godot -d -s --path "$PWD" addons/gut/gut_cmdln.gd -gdir=res://tests -gconfig=res://tests/gutconfig.json -gselect=test_heightfield_plan.gd
```
- Run the FULL suite (regression) by dropping `-gselect`. GUT exits 0 only when all tests pass.
- Append new tests to the end of the test file; do not modify Phase-1 tests.

---

### Task 1: Shared rounding helper + level constants + residual/detail level

**Files:**
- Modify: `scripts/terrain/heightfield/HeightfieldPlan.gd`
- Modify: `tests/test_heightfield_plan.gd`

- [ ] **Step 1: Write the failing tests** — append to the END of `tests/test_heightfield_plan.gd`:

```gdscript
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
```

- [ ] **Step 2: Run, confirm FAIL** (`detail_level` not found):
```
/Applications/Godot.app/Contents/MacOS/Godot -d -s --path "$PWD" addons/gut/gut_cmdln.gd -gdir=res://tests -gconfig=res://tests/gutconfig.json -gselect=test_heightfield_plan.gd
```

- [ ] **Step 3a: Refactor `quantize_storey` to use a shared `_round_mode`.** In `scripts/terrain/heightfield/HeightfieldPlan.gd`, REPLACE the existing `quantize_storey` function (the one containing the `match aggregation:` block) with these two functions:

```gdscript
## Apply the aggregation rounding mode to a quotient: min=floor (hug valleys),
## max=ceil (build up), mean/unknown=nearest. Shared by storey and level quantization.
func _round_mode(q: float) -> int:
	match aggregation:
		"min":
			return floori(q)
		"max":
			return ceili(q)
		_:
			return roundi(q)


## Quantize a height (metres) to an integer storey index, clamped to [0, max_storeys].
func quantize_storey(h: float) -> int:
	return clampi(_round_mode(h / STOREY_HEIGHT), 0, max_storeys)
```

- [ ] **Step 3b: Add level constants.** Directly under the existing `const STOREY_HEIGHT: float = 4.0` line, add:

```gdscript
const LEVEL_HEIGHT: float = 0.5
# 4.0 / 0.5. Level saturates at LEVELS_PER_STOREY - 1 (=7), so a full storey is
# always a single cliff, never a stack of 8 level tiles.
const LEVELS_PER_STOREY: int = 8
```

- [ ] **Step 3c: Add residual + detail level.** Append to the END of `scripts/terrain/heightfield/HeightfieldPlan.gd`:

```gdscript
## Sub-storey height (metres) of the raw field above this cell's clamped storey base.
func residual_height(cx: int, cz: int) -> float:
	return raw_height(cx, cz) - float(storey_at(cx, cz)) * STOREY_HEIGHT


## Quantized sub-storey terrace index in [0, LEVELS_PER_STOREY - 1], using the same
## aggregation rounding as the storey tier.
func detail_level(cx: int, cz: int) -> int:
	var r: float = residual_height(cx, cz)
	return clampi(_round_mode(r / LEVEL_HEIGHT), 0, LEVELS_PER_STOREY - 1)
```

- [ ] **Step 4: Run, confirm PASS.** Expected: 20 tests passing (17 prior + 3 new), 0 failing.

- [ ] **Step 5: Commit:**
```bash
git add scripts/terrain/heightfield/HeightfieldPlan.gd tests/test_heightfield_plan.gd
git commit -m "feat(terrain): residual + detail-level quantization (shared rounding)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Distance-to-cliff (static, on a storey map)

**Files:**
- Modify: `scripts/terrain/heightfield/HeightfieldPlan.gd`
- Modify: `tests/test_heightfield_plan.gd`

- [ ] **Step 1: Write the failing tests** — append to the END of `tests/test_heightfield_plan.gd`:

```gdscript
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
```

- [ ] **Step 2: Run, confirm FAIL** (`_cliff_distance_in` / `_NO_CLIFF` not found).

- [ ] **Step 3: Implement.** Append to the END of `scripts/terrain/heightfield/HeightfieldPlan.gd`:

```gdscript
# Search radius for the nearest different storey. Levels saturate at
# LEVELS_PER_STOREY - 1, so a cliff farther than LEVELS_PER_STOREY tiles can never
# affect a cell's level — no need to look past it.
const _CLIFF_SEARCH_MAX: int = LEVELS_PER_STOREY
const _NO_CLIFF: int = 999

## Cardinal (Manhattan) distance from `cell` to the nearest cell in `storeys` whose
## storey differs, searched out to `max_r`. Returns _NO_CLIFF if none within range.
## Pure function of the supplied storey map.
static func _cliff_distance_in(cell: Vector2i, storeys: Dictionary, max_r: int) -> int:
	var s0: int = storeys[cell]
	for r in range(1, max_r + 1):
		for dx in range(-r, r + 1):
			var rem: int = r - absi(dx)
			var dzs: Array = [0] if rem == 0 else [rem, -rem]
			for dz in dzs:
				var nb: Vector2i = cell + Vector2i(dx, dz)
				if storeys.has(nb) and storeys[nb] != s0:
					return r
	return _NO_CLIFF
```

- [ ] **Step 4: Run, confirm PASS.** Expected: 23 tests passing, 0 failing.

- [ ] **Step 5: Commit:**
```bash
git add scripts/terrain/heightfield/HeightfieldPlan.gd tests/test_heightfield_plan.gd
git commit -m "feat(terrain): distance-to-cliff over a storey map

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Storey-masked level clamp (static)

**Files:**
- Modify: `scripts/terrain/heightfield/HeightfieldPlan.gd`
- Modify: `tests/test_heightfield_plan.gd`

- [ ] **Step 1: Write the failing tests** — append to the END of `tests/test_heightfield_plan.gd`:

```gdscript
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
```

- [ ] **Step 2: Run, confirm FAIL** (`_clamp_levels` not found).

- [ ] **Step 3: Implement.** Append to the END of `scripts/terrain/heightfield/HeightfieldPlan.gd`:

```gdscript
## Monotone trickle-down clamp for the level field, masked by storey: a cell is
## lowered to at most one level above its lowest SAME-storey cardinal neighbour.
## Cross-storey neighbours impose no constraint — that transition is a cliff,
## owned by the storey tier. Same unique-fixpoint / order-independence properties
## as clamp_field. `levels` and `storeys` share keys.
static func _clamp_levels(levels: Dictionary, storeys: Dictionary) -> Dictionary:
	var out: Dictionary = levels.duplicate()
	var changed: bool = true
	while changed:
		changed = false
		for cell in out.keys():
			var here: int = out[cell]
			var s: int = storeys[cell]
			for d in _CARDINALS:
				var nb: Vector2i = cell + d
				if not out.has(nb):
					continue
				if storeys[nb] != s:
					continue
				var cap: int = out[nb] + 1
				if here > cap:
					here = cap
					changed = true
			out[cell] = here
	return out
```

- [ ] **Step 4: Run, confirm PASS.** Expected: 25 tests passing, 0 failing.

- [ ] **Step 5: Commit:**
```bash
git add scripts/terrain/heightfield/HeightfieldPlan.gd tests/test_heightfield_plan.gd
git commit -m "feat(terrain): storey-masked level clamp

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: `level_at` — assemble detail + cliff pin + clamp over a window

**Files:**
- Modify: `scripts/terrain/heightfield/HeightfieldPlan.gd`
- Modify: `tests/test_heightfield_plan.gd`

- [ ] **Step 1: Write the failing tests** — append to the END of `tests/test_heightfield_plan.gd`:

```gdscript
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
```

- [ ] **Step 2: Run, confirm FAIL** (`level_at` / `level_margin` / `_build_storey_map` not found).

- [ ] **Step 3: Implement.** Append to the END of `scripts/terrain/heightfield/HeightfieldPlan.gd`:

```gdscript
## Window radius over which the level field is assembled and clamped around a
## query cell. The masked clamp and the cliff-distance ramp both reach at most
## LEVELS_PER_STOREY tiles, so this margin makes a cell's level final.
func level_margin() -> int:
	return LEVELS_PER_STOREY


## Final (clamped) storeys over [cx +/- radius]. Quantizes a window padded by
## max_storeys (the clamp's influence distance) so the inner `radius` storeys are
## settled, then runs the storey clamp once. Reused by level_at to avoid per-cell
## storey windows.
func _build_storey_map(cx: int, cz: int, radius: int) -> Dictionary:
	var outer: int = radius + max_storeys
	var targets: Dictionary = {}
	for dz in range(-outer, outer + 1):
		for dx in range(-outer, outer + 1):
			var cell: Vector2i = Vector2i(cx + dx, cz + dz)
			targets[cell] = quantize_storey(raw_height(cell.x, cell.y))
	return clamp_field(targets)


## Final terrace level in [0, LEVELS_PER_STOREY - 1] for a cell. Builds a settled
## storey map over the window, derives a pre-clamp level for each cell (the detail
## terrace capped by the ramp from the nearest cliff: a cell touching a different
## storey is pinned to 0), then runs the storey-masked level clamp and returns the
## center. Reference implementation; production batches this over chunks.
func level_at(cx: int, cz: int) -> int:
	var lm: int = level_margin()
	var storeys: Dictionary = _build_storey_map(cx, cz, lm + _CLIFF_SEARCH_MAX)
	var l0: Dictionary = {}
	for dz in range(-lm, lm + 1):
		for dx in range(-lm, lm + 1):
			var cell: Vector2i = Vector2i(cx + dx, cz + dz)
			var s: int = storeys[cell]
			var residual: float = raw_height(cell.x, cell.y) - float(s) * STOREY_HEIGHT
			var detail: int = clampi(_round_mode(residual / LEVEL_HEIGHT), 0, LEVELS_PER_STOREY - 1)
			var cliff_cap: int = _cliff_distance_in(cell, storeys, _CLIFF_SEARCH_MAX) - 1
			l0[cell] = clampi(mini(detail, cliff_cap), 0, LEVELS_PER_STOREY - 1)
	var leveled: Dictionary = _clamp_levels(l0, storeys)
	return leveled[Vector2i(cx, cz)]
```

- [ ] **Step 4: Run, confirm PASS.** Expected: 28 tests passing, 0 failing. (Note: `level_at` builds sizable windows; this suite may take noticeably longer than Phase 1 — that is expected for the reference implementation.)

- [ ] **Step 5: Commit:**
```bash
git add scripts/terrain/heightfield/HeightfieldPlan.gd tests/test_heightfield_plan.gd
git commit -m "feat(terrain): level_at (detail + cliff-edge pin + masked clamp)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: Combined surface height + the full 0/0.5/4 invariant

**Files:**
- Modify: `scripts/terrain/heightfield/HeightfieldPlan.gd`
- Modify: `tests/test_heightfield_plan.gd`

- [ ] **Step 1: Write the failing tests** — append to the END of `tests/test_heightfield_plan.gd`:

```gdscript
func test_surface_height_combines_storey_and_level() -> void:
	# Flat 1.7m field: storey 0 (height 0) + level 3 (1.5m) = 1.5m. Far from any
	# cliff so the level is the full detail terrace.
	var plan: HeightfieldPlan = HeightfieldPlan.new(1, 100.0, 8, "mean")
	plan.set_raw_height_override(func(cx: int, cz: int) -> float: return 1.7)
	assert_almost_eq(plan.surface_height(0, 0), 1.5, 0.0001, "0 storeys + 3 levels = 1.5m")

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
```

- [ ] **Step 2: Run, confirm FAIL** — `test_surface_height_combines_storey_and_level` fails because the existing `surface_height` returns storey-only height (1.0 ≠ 1.5... actually storey 0 ⇒ 0.0), and `tile_plan` has no `"level"` key.

- [ ] **Step 3: Update `surface_height` and `tile_plan`.** In `scripts/terrain/heightfield/HeightfieldPlan.gd`, REPLACE the existing `surface_height` and `tile_plan` functions (the Phase-1 versions returning storey-only height) with:

```gdscript
## Rendered surface height (metres): storey tier (4m steps) plus level tier (0.5m).
func surface_height(cx: int, cz: int) -> float:
	return float(storey_at(cx, cz)) * STOREY_HEIGHT + float(level_at(cx, cz)) * LEVEL_HEIGHT


## Read API for downstream instantiation: storey index, terrace level, and the
## combined world height.
func tile_plan(cx: int, cz: int) -> Dictionary:
	var s: int = storey_at(cx, cz)
	var l: int = level_at(cx, cz)
	return {"storey": s, "level": l, "height": float(s) * STOREY_HEIGHT + float(l) * LEVEL_HEIGHT}
```

- [ ] **Step 4: Run, confirm PASS.** Expected: 31 tests passing, 0 failing.

- [ ] **Step 5: Update the Phase-1 storey-only invariant test, which now legitimately sees 0.5m terraces.** The Phase-1 test `test_invariant_adjacent_surface_differs_by_0_or_4` asserted diffs of only 0 or 4 — now false because `surface_height` includes levels. RENAME it and widen its assertion to the full invariant. Find `func test_invariant_adjacent_surface_differs_by_0_or_4()` and replace its body's assertion line

```gdscript
				assert_true(diff < 0.001 or absf(diff - 4.0) < 0.001,
					"adjacent surface heights differ by 0 or 4m (got %.2f at %d,%d)" % [diff, cx, cz])
```

with

```gdscript
				assert_true(diff < 0.001 or absf(diff - 0.5) < 0.001 or absf(diff - 4.0) < 0.001,
					"adjacent surface heights differ by 0, 0.5, or 4m (got %.3f at %d,%d)" % [diff, cx, cz])
```

and rename the function to `func test_storey_region_still_satisfies_the_full_invariant() -> void:`. Also reduce its loop range from `range(-6, 7)` to `range(-3, 4)` on both `cz` and `cx` (level_at makes the wider region slow). Re-run `-gselect` and confirm still passing.

- [ ] **Step 6: Run the FULL suite (regression) — do not skip:**
```
/Applications/Godot.app/Contents/MacOS/Godot -d -s --path "$PWD" addons/gut/gut_cmdln.gd -gdir=res://tests -gconfig=res://tests/gutconfig.json
```
Report overall totals (scripts / tests / passing / failing). All must pass; the leaked-RID lines printed at engine shutdown are normal teardown noise from scene-instantiating tests, not failures.

- [ ] **Step 7: Commit:**
```bash
git add scripts/terrain/heightfield/HeightfieldPlan.gd tests/test_heightfield_plan.gd
git commit -m "feat(terrain): combined storey+level surface height and full invariant

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage (Phase 2 scope):**
- Level (0.5m) tier within plateaus → Tasks 1 (detail) + 4 (level_at).
- Residual quantization → Task 1.
- Distance-to-cliff edge pinning (cliff faces stay exactly 4m: both sides pinned to level 0) → Tasks 2 + 4.
- Per-storey level clamp (terraces stay ≤1 level apart) → Tasks 3 + 4.
- Full `0 / 0.5 / 4` invariant → Task 5. Tile instantiation, streaming, and cutover remain Phases 3–4 (out of scope).
- Aggregation knob applies to levels too (shared `_round_mode`) → Task 1.

**Placeholder scan:** No TBD/TODO. Every code step shows complete code; every run step states the command and expected counts. The two functions replaced (`quantize_storey` in Task 1; `surface_height`/`tile_plan` in Task 5) are called out as replacements with full new bodies.

**Type/name consistency:** Methods defined once and referenced consistently: `_round_mode`, `residual_height`, `detail_level`, static `_cliff_distance_in`, consts `_CLIFF_SEARCH_MAX`/`_NO_CLIFF`, static `_clamp_levels`, `level_margin`, `_build_storey_map`, `level_at`, updated `surface_height`/`tile_plan`. The Task-4 window-independence helper calls `plan._build_storey_map`, `plan._round_mode`, and the statics with the same signatures defined in Tasks 1–4. `mini`/`absi`/`clampi`/`floori`/`ceili`/`roundi` are Godot 4 globals. Level values are bounded to `[0, LEVELS_PER_STOREY - 1]` everywhere they are produced.

**Risk note:** `level_at`'s window margins (`level_margin` + `_CLIFF_SEARCH_MAX`, padded by `max_storeys` for the storey clamp) are the subtle part. The window-independence test (Task 4) and the full-invariant test (Task 5) are the empirical guards — if a margin is too tight, those tests fail rather than silently producing gaps. The per-task spec/quality reviews and TDD will surface any such issue during execution.
