# Heightfield Terrain — Numerical Plan Core (Phase 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a deterministic, churn-free numerical terrain plan — a continuous height field quantized into cliff storeys with a trickle-down clamp — validated entirely by pure unit tests before any tile instantiation.

**Architecture:** A standalone `HeightfieldPlan` class (no scene/Node dependencies) samples a continuous height `H(cell)` from the existing macro-density noise, quantizes it to integer cliff storeys, and runs a monotone trickle-down clamp so adjacent cells never differ by more than one storey. Because the result is a pure function of `(world_seed, cell)`, a tile's planned height is final before it is ever placed — the anti-churn guarantee. This phase covers the storey (cliff) tier only; the level (0.5m) tier, tile instantiation, and cutover are deferred to follow-up plans.

**Tech Stack:** Godot 4.5 typed GDScript, GUT (Godot Unit Test) — tests under `tests/`, run via the `godot-test` alias.

---

## Scope and Phasing

The full spec (`docs/superpowers/specs/2026-06-17-heightfield-terrain-design.md`) is a large rewrite. Per the writing-plans scope check it is split into independently shippable plans:

- **Phase 1 (this plan)** — Numerical plan core: `H → storey quantize → trickle-down clamp → storey_at`, with invariant, determinism, and convergence tests. Produces correct, churn-free chunky-cliff heights, fully validated, with zero changes to the live generator.
- **Phase 2 (next plan)** — Level (0.5m) tier: residual quantization, distance-to-cliff edge pinning, per-storey level clamp, the full `0 / 0.5 / 4` invariant.
- **Phase 3 (next plan)** — Tile instantiation: map plan cells → tiles, variant selection from plan neighbour-deltas (reuse `LEVEL_VARIANT_TABLE` / `CLIFF_VARIANT_TABLE` assets), plan-radius vs place-radius streaming.
- **Phase 4 (next plan)** — Cutover: remove `CliffEdgeRule` / `LevelEdgeRule` / `ClusterFillRule` retiling, wire `burst_harness` to assert zero structural churn, keep `WaterRule` + decorations, screenshot tuning.

Each phase gets its own plan written once the prior phase is validated.

## File Structure

- Create: `scripts/terrain/heightfield/HeightfieldPlan.gd` — the numerical plan (one responsibility: position → quantized, clamped storey). No Node/scene deps so it is unit-testable in isolation and reusable by the future chunked generator.
- Create: `tests/test_heightfield_plan.gd` — GUT test suite for the plan.

Reused (read-only this phase):
- `scripts/core/Helper.gd` — `Helper.macro_density01(pos, world_seed)` is the continuous source field (already deterministic per seed, faded near origin).

## Conventions

- Cells are integer grid coordinates; world position of a cell = `Vector3(cx * 24, 0, cz * 24)`. Tiles are 24u (`TILE`).
- A "storey" is one 4m cliff step (`STOREY_HEIGHT`).
- Run a single test file with:

```
/Applications/Godot.app/Contents/MacOS/Godot -d -s --path "$PWD" addons/gut/gut_cmdln.gd -gdir=res://tests -gconfig=res://tests/gutconfig.json -gselect=test_heightfield_plan.gd
```

(The repo aliases the godot-test base command; the full binary path is used here because the alias is not available non-interactively. Expected PASS output ends with a GUT summary line like `N passing`.)

---

### Task 1: Scaffold `HeightfieldPlan` with the height source

**Files:**
- Create: `scripts/terrain/heightfield/HeightfieldPlan.gd`
- Test: `tests/test_heightfield_plan.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/test_heightfield_plan.gd`:

```gdscript
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/Applications/Godot.app/Contents/MacOS/Godot -d -s --path "$PWD" addons/gut/gut_cmdln.gd -gdir=res://tests -gconfig=res://tests/gutconfig.json -gselect=test_heightfield_plan.gd`
Expected: FAIL — `HeightfieldPlan` is not a known class (parse/identifier error).

- [ ] **Step 3: Write minimal implementation**

Create `scripts/terrain/heightfield/HeightfieldPlan.gd`:

```gdscript
class_name HeightfieldPlan
extends RefCounted

## Deterministic, churn-free numerical terrain plan. A continuous height field
## H(cell) is quantized into integer cliff storeys and trickle-down clamped so
## adjacent cells never differ by more than one storey. The result is a pure
## function of (world_seed, cell), so a tile's planned height is final before it
## is ever instantiated — the anti-churn guarantee.
##
## Phase 1: storey (cliff) tier only. See
## docs/superpowers/specs/2026-06-17-heightfield-terrain-design.md.

const TILE: float = 24.0
const STOREY_HEIGHT: float = 4.0

var world_seed: int
var height_amplitude: float   # metres; macro field [0,1] -> [0, amplitude]
var max_storeys: int          # caps column height -> bounds clamp margin
var aggregation: String       # "min" (floor) | "mean" (nearest) | "max" (ceil)

var _raw_override: Callable = Callable()


func _init(
	p_world_seed: int,
	p_height_amplitude: float = 32.0,
	p_max_storeys: int = 8,
	p_aggregation: String = "mean"
) -> void:
	world_seed = p_world_seed
	height_amplitude = p_height_amplitude
	max_storeys = p_max_storeys
	aggregation = p_aggregation


## Replace the noise source with a synthetic field for tests. fn(cx, cz) -> float.
func set_raw_height_override(fn: Callable) -> void:
	_raw_override = fn


## Continuous height (metres) at a tile cell.
func raw_height(cx: int, cz: int) -> float:
	if _raw_override.is_valid():
		return _raw_override.call(cx, cz)
	var pos: Vector3 = Vector3(float(cx) * TILE, 0.0, float(cz) * TILE)
	return Helper.macro_density01(pos, world_seed) * height_amplitude
```

- [ ] **Step 4: Run test to verify it passes**

Run: `/Applications/Godot.app/Contents/MacOS/Godot -d -s --path "$PWD" addons/gut/gut_cmdln.gd -gdir=res://tests -gconfig=res://tests/gutconfig.json -gselect=test_heightfield_plan.gd`
Expected: PASS — 3 passing.

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/heightfield/HeightfieldPlan.gd tests/test_heightfield_plan.gd
git commit -m "feat(terrain): scaffold HeightfieldPlan height source

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Quantize height to storeys (aggregation knob)

**Files:**
- Modify: `scripts/terrain/heightfield/HeightfieldPlan.gd`
- Test: `tests/test_heightfield_plan.gd`

- [ ] **Step 1: Write the failing test**

Append to `tests/test_heightfield_plan.gd`:

```gdscript
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/Applications/Godot.app/Contents/MacOS/Godot -d -s --path "$PWD" addons/gut/gut_cmdln.gd -gdir=res://tests -gconfig=res://tests/gutconfig.json -gselect=test_heightfield_plan.gd`
Expected: FAIL — `quantize_storey` not found (invalid call).

- [ ] **Step 3: Write minimal implementation**

Append to `scripts/terrain/heightfield/HeightfieldPlan.gd`:

```gdscript
## Quantize a height (metres) to an integer storey index, using the aggregation
## rounding mode (min=floor hugs valleys, max=ceil builds up, mean=nearest),
## clamped to [0, max_storeys].
func quantize_storey(h: float) -> int:
	var q: float = h / STOREY_HEIGHT
	var s: int
	match aggregation:
		"min":
			s = floori(q)
		"max":
			s = ceili(q)
		_:
			s = roundi(q)
	return clampi(s, 0, max_storeys)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `/Applications/Godot.app/Contents/MacOS/Godot -d -s --path "$PWD" addons/gut/gut_cmdln.gd -gdir=res://tests -gconfig=res://tests/gutconfig.json -gselect=test_heightfield_plan.gd`
Expected: PASS — 6 passing.

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/heightfield/HeightfieldPlan.gd tests/test_heightfield_plan.gd
git commit -m "feat(terrain): quantize height to storeys with aggregation knob

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Trickle-down clamp (monotone, order-independent)

**Files:**
- Modify: `scripts/terrain/heightfield/HeightfieldPlan.gd`
- Test: `tests/test_heightfield_plan.gd`

- [ ] **Step 1: Write the failing test**

Append to `tests/test_heightfield_plan.gd`:

```gdscript
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/Applications/Godot.app/Contents/MacOS/Godot -d -s --path "$PWD" addons/gut/gut_cmdln.gd -gdir=res://tests -gconfig=res://tests/gutconfig.json -gselect=test_heightfield_plan.gd`
Expected: FAIL — `clamp_field` not found.

- [ ] **Step 3: Write minimal implementation**

Append to `scripts/terrain/heightfield/HeightfieldPlan.gd`:

```gdscript
const _CARDINALS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
]

## Monotone trickle-down clamp: repeatedly lower each cell to at most one storey
## above its lowest cardinal neighbour, until nothing changes. The operation
## only lowers and is bounded below by the input, so it terminates; the fixpoint
## (each cell <= min_neighbour + 1) is unique regardless of sweep order. `targets`
## maps Vector2i(cx, cz) -> storey; returns a new clamped map.
static func clamp_field(targets: Dictionary) -> Dictionary:
	var out: Dictionary = targets.duplicate()
	var changed: bool = true
	while changed:
		changed = false
		for cell in out.keys():
			var here: int = out[cell]
			for d in _CARDINALS:
				var nb: Vector2i = cell + d
				if not out.has(nb):
					continue
				var cap: int = out[nb] + 1
				if here > cap:
					here = cap
					changed = true
			out[cell] = here
	return out
```

- [ ] **Step 4: Run test to verify it passes**

Run: `/Applications/Godot.app/Contents/MacOS/Godot -d -s --path "$PWD" addons/gut/gut_cmdln.gd -gdir=res://tests -gconfig=res://tests/gutconfig.json -gselect=test_heightfield_plan.gd`
Expected: PASS — 9 passing.

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/heightfield/HeightfieldPlan.gd tests/test_heightfield_plan.gd
git commit -m "feat(terrain): trickle-down storey clamp (monotone, order-independent)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: `storey_at` over a window + margin (determinism)

**Files:**
- Modify: `scripts/terrain/heightfield/HeightfieldPlan.gd`
- Test: `tests/test_heightfield_plan.gd`

- [ ] **Step 1: Write the failing test**

Append to `tests/test_heightfield_plan.gd`:

```gdscript
func test_storey_at_matches_spec_2x3_example() -> void:
	# Spec worked example: H = [[8,8],[5,4],[2,0]] (z=0 is the 8-row) must
	# quantize to storeys [[2,2],[1,1],[0,0]] under floor (min) aggregation.
	var plan: HeightfieldPlan = HeightfieldPlan.new(1, 100.0, 8, "min")
	var field: Dictionary = {
		Vector2i(0, 0): 8.0, Vector2i(1, 0): 8.0,
		Vector2i(0, 1): 5.0, Vector2i(1, 1): 4.0,
		Vector2i(0, 2): 2.0, Vector2i(1, 2): 0.0,
	}
	plan.set_raw_height_override(func(cx: int, cz: int) -> float:
		return field.get(Vector2i(cx, cz), 0.0))
	assert_eq(plan.storey_at(0, 0), 2, "A => storey 2")
	assert_eq(plan.storey_at(1, 1), 1, "D => storey 1")
	assert_eq(plan.storey_at(0, 2), 0, "E => storey 0")

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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/Applications/Godot.app/Contents/MacOS/Godot -d -s --path "$PWD" addons/gut/gut_cmdln.gd -gdir=res://tests -gconfig=res://tests/gutconfig.json -gselect=test_heightfield_plan.gd`
Expected: FAIL — `storey_at` / `storey_margin` not found.

- [ ] **Step 3: Write minimal implementation**

Append to `scripts/terrain/heightfield/HeightfieldPlan.gd`:

```gdscript
## Clamp influence fans out one storey per tile, and storeys are capped at
## max_storeys, so a window margin of max_storeys guarantees the center cell's
## clamped value equals the global (infinite-window) result.
func storey_margin() -> int:
	return max_storeys


## Final clamped storey for a cell. Reference implementation: builds a window of
## quantized targets and clamps it. (Production will batch this over chunks; the
## per-cell window here is for correctness/validation, not the hot path.)
func storey_at(cx: int, cz: int) -> int:
	var m: int = storey_margin()
	var targets: Dictionary = {}
	for dz in range(-m, m + 1):
		for dx in range(-m, m + 1):
			var cell: Vector2i = Vector2i(cx + dx, cz + dz)
			targets[cell] = quantize_storey(raw_height(cell.x, cell.y))
	var clamped: Dictionary = clamp_field(targets)
	return clamped[Vector2i(cx, cz)]
```

- [ ] **Step 4: Run test to verify it passes**

Run: `/Applications/Godot.app/Contents/MacOS/Godot -d -s --path "$PWD" addons/gut/gut_cmdln.gd -gdir=res://tests -gconfig=res://tests/gutconfig.json -gselect=test_heightfield_plan.gd`
Expected: PASS — 11 passing.

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/heightfield/HeightfieldPlan.gd tests/test_heightfield_plan.gd
git commit -m "feat(terrain): window-margin storey_at with determinism guarantee

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: Surface height + tile read API + the storey invariant

**Files:**
- Modify: `scripts/terrain/heightfield/HeightfieldPlan.gd`
- Test: `tests/test_heightfield_plan.gd`

- [ ] **Step 1: Write the failing test**

Append to `tests/test_heightfield_plan.gd`:

```gdscript
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/Applications/Godot.app/Contents/MacOS/Godot -d -s --path "$PWD" addons/gut/gut_cmdln.gd -gdir=res://tests -gconfig=res://tests/gutconfig.json -gselect=test_heightfield_plan.gd`
Expected: FAIL — `surface_height` / `tile_plan` not found.

- [ ] **Step 3: Write minimal implementation**

Append to `scripts/terrain/heightfield/HeightfieldPlan.gd`:

```gdscript
## Rendered surface height (metres) for a cell.
func surface_height(cx: int, cz: int) -> float:
	return float(storey_at(cx, cz)) * STOREY_HEIGHT


## Read API for downstream instantiation: the storey index and its world height.
## (Phase 2 will add a "level" field and a fractional height contribution.)
func tile_plan(cx: int, cz: int) -> Dictionary:
	var s: int = storey_at(cx, cz)
	return {"storey": s, "height": float(s) * STOREY_HEIGHT}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `/Applications/Godot.app/Contents/MacOS/Godot -d -s --path "$PWD" addons/gut/gut_cmdln.gd -gdir=res://tests -gconfig=res://tests/gutconfig.json -gselect=test_heightfield_plan.gd`
Expected: PASS — 14 passing.

- [ ] **Step 5: Run the FULL suite to confirm no regressions**

Run: `/Applications/Godot.app/Contents/MacOS/Godot -d -s --path "$PWD" addons/gut/gut_cmdln.gd -gdir=res://tests -gconfig=res://tests/gutconfig.json`
Expected: PASS — existing suites plus the 14 new tests, no failures.

- [ ] **Step 6: Commit**

```bash
git add scripts/terrain/heightfield/HeightfieldPlan.gd tests/test_heightfield_plan.gd
git commit -m "feat(terrain): surface height, tile read API, storey invariant test

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage (Phase 1 scope):**
- Height field `H(x,z)` from biome-scaled noise → Task 1 (`raw_height`).
- Per-tier quantization (storey tier) → Task 2 (`quantize_storey`), aggregation knob included.
- Trickle-down clamp, monotone potential, order-independent → Task 3 (`clamp_field`).
- Plan-radius/place-radius churn-freedom (numerical margin) → Task 4 (`storey_margin`, `storey_at`, window-independence test).
- Invariant (storey tier: 0 or 4) → Task 5. The full `0 / 0.5 / 4` invariant, central/edge rule, level tier, instantiation, and cutover are explicitly deferred to Phases 2–4 (see Scope and Phasing).

**Placeholder scan:** No TBD/TODO; every code step shows complete code; every run step shows the command and expected result. Deferred work is named as future plans, not inline gaps.

**Type/name consistency:** `raw_height`, `set_raw_height_override`, `quantize_storey`, `clamp_field`, `storey_margin`, `storey_at`, `surface_height`, `tile_plan` are defined once and referenced consistently. `clamp_field` is `static` and is called as `HeightfieldPlan.clamp_field(...)` in tests. Constants `TILE`, `STOREY_HEIGHT`, `_CARDINALS` are defined before use.
