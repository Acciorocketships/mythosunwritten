# Mesa Cliff Tier Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an 8m sheer "mesa" cliff tier above the existing 4m storey tier so generation carves dramatic ravines/plateaus, rendered with the authored `terrain/scenes/cliff/` tiles.

**Architecture:** Generalize the heightfield plan's two-tier (storey 4m → level 0.5m) pipeline into three nested tiers (mesa 8m → storey 4m → level 0.5m). Each lower tier is the residual within the upper, pinned to 0 within one tile of the upper's cliffs (a "distance ramp"). The mesa tier uses an **8-way ±1 clamp** (cardinal + diagonal) so every mesa boundary is a uniform single 8m step, which the single-height 8m tiles render with no new geometry. The 4m sloped-cliff and 0.5m level systems are behavior-unchanged.

**Tech Stack:** Godot 4 / GDScript, GUT test framework.

**Spec:** `docs/superpowers/specs/2026-06-23-mesa-cliff-tier-design.md`

**Key files:**
- `scripts/terrain/heightfield/HeightfieldPlan.gd` — three-tier plan math (the bulk of the work)
- `scripts/terrain/heightfield/HeightfieldRegion.gd` — batched read interface (expose mesa)
- `scripts/terrain/heightfield/HeightfieldVariant.gd` — `cliff-tall` family classification
- `scripts/terrain/heightfield/HeightfieldInstantiator.gd` — 8m base-fill / placement
- `scripts/terrain/TerrainModuleDefinitions.gd` — `load_cliff_tall_variants()`
- `terrain/scenes/cliff/*.tscn` — bottom-socket fix to `y=-8`
- `tests/test_heightfield_mesa.gd` (new), plus extensions to existing `test_heightfield_*`

**Vocabulary used throughout (match exactly):**
- `mesa` — integer mesa index (8m units), 8-way clamped.
- `storey_in_mesa` — residual storey within a mesa, `[0, STOREYS_PER_MESA-1]`.
- `abs_storey` (a.k.a. the value `storey_at` returns) = `mesa * STOREYS_PER_MESA + storey_in_mesa`.
- Existing `level` is unchanged and keys on *different abs_storey*.

---

## Task 0: Make the worktree runnable + baseline

The worktree is missing gitignored `addons/` (GUT) and `assets/` (art); tests can't run without them.

**Files:** none (environment setup).

- [ ] **Step 1: Symlink addons and assets from the primary checkout**

```bash
cd /Users/ryko/story/.claude/worktrees/mesa-cliff-tier
ln -sfn /Users/ryko/story/addons addons
ln -sfn /Users/ryko/story/assets assets
```

- [ ] **Step 2: Import the project once (slow — run in background)**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import
```
Expected: completes (first FBX import can take several minutes). Re-run after creating any new `class_name` script so Godot indexes it.

- [ ] **Step 3: Baseline — run the heightfield plan tests**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_heightfield_plan.gd -gexit`
Expected: PASS. (Note: `test_heightfield_interior_corners.gd` has a known pre-existing failure unrelated to this work — do not treat it as a regression.)

- [ ] **Step 4: Commit the copied cliff scenes as the feature's authored tiles**

```bash
git add terrain/scenes/cliff/
git commit -m "feat(terrain): vendor authored 8m sheer cliff tile set (scenes/cliff)"
```

---

## Task 1: Mesa constants + `quantize_mesa` + 8-way clamp

**Files:**
- Modify: `scripts/terrain/heightfield/HeightfieldPlan.gd`
- Test: `tests/test_heightfield_mesa.gd` (create)

- [ ] **Step 1: Write the failing test**

Create `tests/test_heightfield_mesa.gd`:

```gdscript
extends GutTest

# Quantization and the 8-way mesa clamp — the new top tier's primitives.

func _plan() -> HeightfieldPlan:
	# amplitude/max_storeys irrelevant here; we drive raw height via overrides.
	return HeightfieldPlan.new(1234, 64.0, 8, "mean")

func test_quantize_mesa_rounds_to_8m_bands() -> void:
	var p := _plan()
	assert_eq(p.quantize_mesa(0.0), 0)
	assert_eq(p.quantize_mesa(3.9), 0)
	assert_eq(p.quantize_mesa(4.1), 1)   # nearest: 4.1/8 = 0.51 -> 1
	assert_eq(p.quantize_mesa(8.0), 1)
	assert_eq(p.quantize_mesa(15.9), 2)

func test_8way_clamp_constrains_cardinals_and_diagonals() -> void:
	# Center spike of 3 surrounded by 0s must drop to 1: every neighbour
	# (incl. diagonals) within +/-1.
	var targets := {
		Vector2i(-1,-1): 0, Vector2i(0,-1): 0, Vector2i(1,-1): 0,
		Vector2i(-1, 0): 0, Vector2i(0, 0): 3, Vector2i(1, 0): 0,
		Vector2i(-1, 1): 0, Vector2i(0, 1): 0, Vector2i(1, 1): 0,
	}
	var out := HeightfieldPlan.clamp_field_8way(targets)
	assert_eq(out[Vector2i(0,0)], 1)

func test_8way_clamp_blocks_two_deep_diagonal() -> void:
	# A convex corner one diagonal step above a 2-down pit: cardinal-only clamp
	# would leave the diagonal 2 below; 8-way forbids it.
	var targets := {
		Vector2i(0,0): 2, Vector2i(1,0): 1, Vector2i(0,1): 1, Vector2i(1,1): 0,
	}
	var out := HeightfieldPlan.clamp_field_8way(targets)
	# (1,1) is diagonal to (0,0); 8-way caps the gap at 1, so (0,0) lowers to 1.
	assert_eq(out[Vector2i(0,0)], 1)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_heightfield_mesa.gd -gexit`
Expected: FAIL — `quantize_mesa` / `clamp_field_8way` not defined.

- [ ] **Step 3: Add constants, `quantize_mesa`, and the 8-way clamp**

In `HeightfieldPlan.gd`, after the existing storey/level constants (near line 18) add:

```gdscript
const MESA_HEIGHT: float = 8.0
const STOREYS_PER_MESA: int = 2          # 8.0 / 4.0
# Mesa cliffs pin storey_in_mesa to 0 within this many tiles; a storey_in_mesa
# saturates at STOREYS_PER_MESA - 1, so nothing past it can affect a cell.
const _MESA_SEARCH_MAX: int = STOREYS_PER_MESA
```

Add a `max_mesas` field next to `max_storeys` and set it in `_init` after `max_storeys` is assigned:

```gdscript
var max_mesas: int            # column cap in mesa units -> mesa clamp window margin
```
```gdscript
	max_mesas = int(ceil(float(max_storeys) / float(STOREYS_PER_MESA)))
```

Add the quantizer (near `quantize_storey`, ~line 99):

```gdscript
## Quantize a height (metres) to an integer mesa index, clamped to [0, max_mesas].
func quantize_mesa(h: float) -> int:
	return clampi(_round_mode(h / MESA_HEIGHT), 0, max_mesas)
```

Add the 8-way clamp next to `clamp_field` (~line 131). It is `clamp_field` with diagonals added to the neighbour set:

```gdscript
const _ALL8: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]

## Like clamp_field but constrains all 8 neighbours (cardinal + diagonal) to
## within one step. Used for the mesa tier so no two-deep mesa diagonal forms
## (mesa walls are sheer; there is no ramp to bridge a 2-deep diagonal). Same
## monotone-lowering / unique-fixpoint properties as clamp_field.
static func clamp_field_8way(targets: Dictionary) -> Dictionary:
	var out: Dictionary = targets.duplicate()
	var changed: bool = true
	while changed:
		changed = false
		for cell in out.keys():
			var here: int = out[cell]
			for d in _ALL8:
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

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_heightfield_mesa.gd -gexit`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/heightfield/HeightfieldPlan.gd tests/test_heightfield_mesa.gd
git commit -m "feat(terrain): mesa quantize + 8-way clamp primitives"
```

---

## Task 2: Mesa field + mesa-distance ramp + restructured `storey_at`

This replaces `storey_at`'s body (and the helper `_build_storey_map`) with the three-tier computation. `storey_at` still returns the **absolute** storey, so all callers are unaffected.

**Files:**
- Modify: `scripts/terrain/heightfield/HeightfieldPlan.gd`
- Test: `tests/test_heightfield_mesa.gd`

- [ ] **Step 1: Write the failing test**

Append to `tests/test_heightfield_mesa.gd`:

```gdscript
# A raw field that steps cleanly: x<0 -> 0m, 0<=x<3 -> 8m (1 mesa), x>=3 -> 16m.
func _stepped_plan() -> HeightfieldPlan:
	var p := HeightfieldPlan.new(7, 64.0, 8, "mean")
	p.set_raw_height_override(func(cx, cz):
		if cx < 0: return 0.0
		if cx < 3: return 8.0
		return 16.0)
	return p

func test_storey_at_returns_absolute_storey_across_mesas() -> void:
	var p := _stepped_plan()
	assert_eq(p.storey_at(-2, 0), 0, "low ground = abs storey 0")
	assert_eq(p.storey_at(1, 0), 2, "8m mesa = abs storey 2")
	assert_eq(p.storey_at(5, 0), 4, "16m mesa = abs storey 4")

func test_surface_drop_at_mesa_edge_is_8m() -> void:
	var p := _stepped_plan()
	var hi := p.surface_height(0, 0)   # first cell of the 8m mesa
	var lo := p.surface_height(-1, 0)  # last cell of low ground
	assert_almost_eq(hi - lo, 8.0, 0.001, "mesa boundary is a single 8m step")

func test_storey_in_mesa_pinned_zero_next_to_mesa_cliff() -> void:
	# Raw rises smoothly inside a mesa but the cell adjacent to a mesa cliff is
	# pinned to the mesa floor (storey_in_mesa 0) so its face is a clean 8m.
	var p := HeightfieldPlan.new(3, 64.0, 8, "mean")
	p.set_raw_height_override(func(cx, cz):
		if cx <= 0: return 0.0          # low ground
		return 8.0 + float(cx) * 4.0)   # mesa floor 8m + rising storeys inside
	# cx=1 is adjacent to the mesa cliff (cx=0): pinned to mesa floor -> abs storey 2.
	assert_eq(p.storey_at(1, 0), 2, "edge cell pinned to mesa floor")
	# deeper in, storey_in_mesa can rise to its cap (1) -> abs storey 3.
	assert_eq(p.storey_at(3, 0), 3, "interior rises one storey within the mesa")
```

- [ ] **Step 2: Run test to verify it fails**

Run the mesa test file. Expected: FAIL on the new tests (`storey_at` still single-tier).

- [ ] **Step 3: Implement the mesa map, mesa-distance, and restructured storey**

In `HeightfieldPlan.gd` add the mesa analogues of the existing storey/level helpers.

Mesa per-cell map builder (mirror of `_build_storey_map`, using the 8-way clamp):

```gdscript
## Settled mesa indices over [cx +/- radius], padded by max_mesas (the 8-way
## clamp's influence distance) then clamped once. Mirrors _build_storey_map.
func _build_mesa_map(cx: int, cz: int, radius: int) -> Dictionary:
	var outer: int = radius + max_mesas
	var targets: Dictionary = {}
	for dz in range(-outer, outer + 1):
		for dx in range(-outer, outer + 1):
			var cell: Vector2i = Vector2i(cx + dx, cz + dz)
			targets[cell] = quantize_mesa(raw_height(cell.x, cell.y))
	return clamp_field_8way(targets)
```

Mesa-distance (mirror of `_cliff_distance_in`) and diagonal-mesa-cliff (mirror of `_has_diagonal_cliff`):

```gdscript
## Manhattan distance to nearest different-mesa cell, out to max_r; _NO_CLIFF if none.
static func _mesa_distance_in(cell: Vector2i, mesas: Dictionary, max_r: int) -> int:
	var m0: int = mesas[cell]
	for r in range(1, max_r + 1):
		for dx in range(-r, r + 1):
			var rem: int = r - absi(dx)
			var dzs: Array[int] = [0] if rem == 0 else [rem, -rem]
			for dz in dzs:
				var nb: Vector2i = cell + Vector2i(dx, dz)
				if mesas.has(nb) and mesas[nb] != m0:
					return r
	return _NO_CLIFF

static func _has_diagonal_mesa_cliff(mesas: Dictionary, cell: Vector2i) -> bool:
	var m: int = mesas[cell]
	for d in _DIAGONALS:
		var nb: Vector2i = cell + d
		if mesas.has(nb) and mesas[nb] != m:
			return true
	return false
```

Mesa-masked storey-in-mesa clamp (mirror of `_clamp_levels`, masked by mesa):

```gdscript
## Trickle-down clamp for storey_in_mesa, masked by mesa: a cell is lowered to at
## most one above its lowest SAME-mesa cardinal neighbour. Cross-mesa neighbours
## impose no constraint (that transition is the 8m mesa cliff). Mirrors _clamp_levels.
static func _clamp_storeys_in_mesa(sims: Dictionary, mesas: Dictionary) -> Dictionary:
	var out: Dictionary = sims.duplicate()
	var changed: bool = true
	while changed:
		changed = false
		for cell in out.keys():
			var here: int = out[cell]
			var m: int = mesas[cell]
			for d in _CARDINALS:
				var nb: Vector2i = cell + d
				if not out.has(nb):
					continue
				if mesas[nb] != m:
					continue
				var cap: int = out[nb] + 1
				if here > cap:
					here = cap
					changed = true
			out[cell] = here
	return out
```

Now replace `_build_storey_map` so it returns **absolute** storeys via the three-tier pipeline (this is the integration seam every caller already uses):

```gdscript
## Final absolute storeys over [cx +/- radius]. abs_storey = mesa*STOREYS_PER_MESA
## + storey_in_mesa, where storey_in_mesa is the residual within the mesa, pinned
## to 0 within one tile of a mesa cliff (mesa-distance ramp) and saturated at
## STOREYS_PER_MESA - 1, then mesa-masked-clamped. Replaces the former single-tier
## quantize+clamp. Reused by storey_at, level_at, and compute_region.
func _build_storey_map(cx: int, cz: int, radius: int) -> Dictionary:
	var mesas: Dictionary = _build_mesa_map(cx, cz, radius + _MESA_SEARCH_MAX)
	var s0: Dictionary = {}
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var cell: Vector2i = Vector2i(cx + dx, cz + dz)
			var mz: int = mesas[cell]
			var residual: float = raw_height(cell.x, cell.y) - float(mz) * MESA_HEIGHT
			var detail: int = clampi(_round_mode(residual / STOREY_HEIGHT), 0, STOREYS_PER_MESA - 1)
			var mesa_cap: int = _mesa_distance_in(cell, mesas, _MESA_SEARCH_MAX) - 1
			if _has_diagonal_mesa_cliff(mesas, cell):
				mesa_cap = 0
			s0[cell] = clampi(mini(detail, mesa_cap), 0, STOREYS_PER_MESA - 1)
	var sims: Dictionary = _clamp_storeys_in_mesa(s0, mesas)
	var out: Dictionary = {}
	for cell in sims.keys():
		out[cell] = mesas[cell] * STOREYS_PER_MESA + int(sims[cell])
	return out
```

Replace `storey_at` to read from that map (it no longer does its own quantize+clamp):

```gdscript
## Final absolute storey for a cell (mesa*STOREYS_PER_MESA + storey_in_mesa).
func storey_at(cx: int, cz: int) -> int:
	return int(_build_storey_map(cx, cz, 0)[Vector2i(cx, cz)])
```

Replace `storey_margin` so the window covers the mesa clamp + mesa-distance ramp:

```gdscript
## Window margin for a settled absolute storey: the mesa clamp fans out one
## mega-step per tile (capped at max_mesas, applied in mesa units = 2 storeys) and
## the mesa-distance ramp reaches _MESA_SEARCH_MAX. _build_mesa_map already adds
## its own max_mesas pad, so storey_margin only needs the ramp reach.
func storey_margin() -> int:
	return _MESA_SEARCH_MAX
```

> NOTE: `quantize_storey` is now only used by the old code paths being replaced. Leave it defined (a harmless pure helper) unless a later task shows it unused; do not delete in this task to keep the diff focused.

- [ ] **Step 4: Run test to verify it passes**

Run the mesa test file. Expected: PASS. Then run `test_heightfield_plan.gd` to confirm no regression in single-mesa behaviour (heights under 8m are mesa 0, so abs storey == old storey there).
Run: `... -gtest=res://tests/test_heightfield_plan.gd -gexit` — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/heightfield/HeightfieldPlan.gd tests/test_heightfield_mesa.gd
git commit -m "feat(terrain): three-tier storey field (mesa->storey) with mesa-distance ramp"
```

---

## Task 3: Batched `compute_region` parity + margins

`level_at` already calls `_build_storey_map`, so it is correct once Task 2 lands. `compute_region` builds its storey map inline (quantize+clamp) and must be switched to the three-tier pipeline, with the outer window widened for the mesa clamp.

**Files:**
- Modify: `scripts/terrain/heightfield/HeightfieldPlan.gd` (`compute_region`)
- Test: `tests/test_heightfield_region.gd` (extend) or `tests/test_heightfield_mesa.gd`

- [ ] **Step 1: Write the failing test**

Append to `tests/test_heightfield_mesa.gd`:

```gdscript
# Batched region must equal the per-cell reference across a mesa boundary.
func test_compute_region_matches_per_cell_with_mesas() -> void:
	var p := HeightfieldPlan.new(99, 48.0, 8, "mean")  # real noise, multi-mesa
	var region := p.compute_region(0, 0, 4)
	for dz in range(-4, 5):
		for dx in range(-4, 5):
			assert_eq(region.storey_at(dx, dz), p.storey_at(dx, dz),
				"storey mismatch at (%d,%d)" % [dx, dz])
			assert_eq(region.level_at(dx, dz), p.level_at(dx, dz),
				"level mismatch at (%d,%d)" % [dx, dz])
```

- [ ] **Step 2: Run test to verify it fails**

Run the mesa test file. Expected: FAIL — `compute_region` still uses inline single-tier quantize+clamp, diverging from the per-cell reference at mesa boundaries.

- [ ] **Step 3: Switch `compute_region` to the three-tier storey map**

In `compute_region`, widen the outer radius and replace the inline storey build. Change the radius ladder so `storey_outer` covers the mesa pipeline, and build absolute storeys via `_build_storey_map`-equivalent logic using the cache. Concretely, replace the block that computes `targets` + `storeys` (the `quantize_storey` loop and `clamp_field`) with:

```gdscript
	# Absolute-storey map via the three-tier pipeline (mesa -> storey_in_mesa).
	# Outer window must cover: place + level ramp + mesa-distance ramp + mesa clamp.
	var mesa_outer: int = storey_final_r + _MESA_SEARCH_MAX + max_mesas
	var mesa_targets: Dictionary = {}
	for dz in range(-mesa_outer, mesa_outer + 1):
		for dx in range(-mesa_outer, mesa_outer + 1):
			var cell: Vector2i = Vector2i(center_cx + dx, center_cz + dz)
			var qm: int
			if target_cache.has(cell):
				qm = target_cache[cell]
			else:
				qm = quantize_mesa(raw_height(cell.x, cell.y))
				target_cache[cell] = qm
			mesa_targets[cell] = qm
	var mesas: Dictionary = clamp_field_8way(mesa_targets)

	var storey_r2: int = storey_final_r + _MESA_SEARCH_MAX
	var s0: Dictionary = {}
	for dz in range(-storey_r2, storey_r2 + 1):
		for dx in range(-storey_r2, storey_r2 + 1):
			var cell: Vector2i = Vector2i(center_cx + dx, center_cz + dz)
			var mz: int = int(mesas[cell])
			var residual_s: float = raw_height(cell.x, cell.y) - float(mz) * MESA_HEIGHT
			var detail_s: int = clampi(_round_mode(residual_s / STOREY_HEIGHT), 0, STOREYS_PER_MESA - 1)
			var mesa_cap: int = _mesa_distance_in(cell, mesas, _MESA_SEARCH_MAX) - 1
			if _has_diagonal_mesa_cliff(mesas, cell):
				mesa_cap = 0
			s0[cell] = clampi(mini(detail_s, mesa_cap), 0, STOREYS_PER_MESA - 1)
	var sims: Dictionary = _clamp_storeys_in_mesa(s0, mesas)
	var storeys: Dictionary = {}
	for cell in sims.keys():
		storeys[cell] = int(mesas[cell]) * STOREYS_PER_MESA + int(sims[cell])
```

Then update the existing `storey_outer` computation just above so the windows are large enough; set:

```gdscript
	var storey_final_r: int = level_r + _CLIFF_SEARCH_MAX
	# (storey_outer is now superseded by mesa_outer/storey_r2 above; remove the old
	#  `var storey_outer := storey_final_r + max_storeys` line and its targets loop.)
```

**IMPORTANT — cache key change:** `target_cache` now stores **mesa** quantvalues (`quantize_mesa`), not storey quantvalues. The cache is per-instance and only used internally by `compute_region`/`evict_placed_outside`; switching its contents is self-consistent as long as nothing else reads it. Verify `evict_placed_outside` only prunes keys (it does — it filters by distance), so no change needed there. The remainder of `compute_region` (the `l0`/level loop and `_clamp_levels`) is unchanged because it consumes `storeys` (now absolute) exactly as before.

- [ ] **Step 4: Run test to verify it passes**

Run the mesa test file (parity test) and `test_heightfield_region.gd`.
Expected: PASS both.

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/heightfield/HeightfieldPlan.gd tests/test_heightfield_mesa.gd
git commit -m "feat(terrain): batched compute_region parity for mesa tier"
```

---

## Task 4: Expose mesa in `tile_plan` / Region + uniform-face property test

**Files:**
- Modify: `HeightfieldPlan.gd` (`tile_plan`), `HeightfieldRegion.gd`
- Test: `tests/test_heightfield_mesa.gd`

- [ ] **Step 1: Write the failing test**

Append to `tests/test_heightfield_mesa.gd`:

```gdscript
func test_tile_plan_exposes_mesa_and_storey_in_mesa() -> void:
	var p := _stepped_plan()
	var tp := p.tile_plan(1, 0)   # the 8m mesa cell
	assert_eq(int(tp["mesa"]), 1)
	assert_eq(int(tp["storey"]), 2)            # absolute
	assert_eq(int(tp["storey_in_mesa"]), 0)
	assert_almost_eq(float(tp["height"]), 8.0, 0.001)

# The property the whole design rests on: no cell mixes an 8m drop with a
# 4m/0.5m drop on another cardinal edge. Checked over a real multi-mesa field.
func test_no_mixed_height_cardinal_faces() -> void:
	var p := HeightfieldPlan.new(2024, 48.0, 8, "mean")
	var region := p.compute_region(0, 0, 6)
	var EPS := 0.1
	for dz in range(-5, 6):
		for dx in range(-5, 6):
			var h0 := region.surface_height(dx, dz)
			var saw_mesa := false
			var saw_sub := false
			for off in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
				var drop := h0 - region.surface_height(dx + off.x, dz + off.y)
				if drop <= EPS:
					continue
				if absf(drop - HeightfieldPlan.MESA_HEIGHT) < absf(drop - HeightfieldPlan.STOREY_HEIGHT):
					saw_mesa = true
				else:
					saw_sub = true
			assert_false(saw_mesa and saw_sub,
				"mixed-height face at (%d,%d)" % [dx, dz])
```

- [ ] **Step 2: Run test to verify it fails**

Run the mesa test file. Expected: FAIL — `tile_plan` lacks `mesa`/`storey_in_mesa`.

- [ ] **Step 3: Implement**

In `HeightfieldPlan.gd`, add `mesa_at` and extend `tile_plan`:

```gdscript
## Final clamped mesa index for a cell.
func mesa_at(cx: int, cz: int) -> int:
	return int(_build_mesa_map(cx, cz, 0)[Vector2i(cx, cz)])
```
```gdscript
func tile_plan(cx: int, cz: int) -> Dictionary:
	var s: int = storey_at(cx, cz)
	var l: int = level_at(cx, cz)
	var m: int = s / STOREYS_PER_MESA
	return {
		"mesa": m,
		"storey": s,
		"storey_in_mesa": s - m * STOREYS_PER_MESA,
		"level": l,
		"height": float(s) * STOREY_HEIGHT + float(l) * LEVEL_HEIGHT,
	}
```

In `HeightfieldRegion.gd`, add the same keys to its `tile_plan` and a `STOREYS_PER_MESA` const + `mesa_at`:

```gdscript
const STOREYS_PER_MESA: int = 2
```
```gdscript
func mesa_at(cx: int, cz: int) -> int:
	return storey_at(cx, cz) / STOREYS_PER_MESA

func tile_plan(cx: int, cz: int) -> Dictionary:
	var s: int = storey_at(cx, cz)
	var l: int = level_at(cx, cz)
	var m: int = s / STOREYS_PER_MESA
	return {
		"mesa": m,
		"storey": s,
		"storey_in_mesa": s - m * STOREYS_PER_MESA,
		"level": l,
		"height": float(s) * STOREY_HEIGHT + float(l) * LEVEL_HEIGHT,
	}
```

- [ ] **Step 4: Run test to verify it passes**

Run the mesa test file. Expected: PASS (incl. the uniform-face property).

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/heightfield/HeightfieldPlan.gd scripts/terrain/heightfield/HeightfieldRegion.gd tests/test_heightfield_mesa.gd
git commit -m "feat(terrain): expose mesa in tile_plan + uniform-face guard"
```

---

## Task 5: `cliff-tall` family classification in `HeightfieldVariant`

**Files:**
- Modify: `scripts/terrain/heightfield/HeightfieldVariant.gd`
- Test: `tests/test_heightfield_variant.gd` (extend)

- [ ] **Step 1: Write the failing test**

Append to `tests/test_heightfield_variant.gd`:

```gdscript
func test_8m_cardinal_drop_is_cliff_tall_side() -> void:
	# Cell at 8m, front neighbour at 0m (8m drop), others equal.
	var cardinals := {"front": 0.0, "right": 8.0, "back": 8.0, "left": 8.0}
	var diagonals := {"frontright": 0.0, "backright": 8.0, "backleft": 8.0, "frontleft": 0.0}
	var desc := HeightfieldVariant.cell_descriptor(8.0, 2, 0, cardinals, diagonals)
	assert_eq(desc["family"], "cliff-tall")
	assert_eq(desc["variant_tag"], "cliff-tall-side")

func test_4m_drop_still_plain_cliff() -> void:
	var cardinals := {"front": 0.0, "right": 4.0, "back": 4.0, "left": 4.0}
	var diagonals := {"frontright": 0.0, "backright": 4.0, "backleft": 4.0, "frontleft": 0.0}
	var desc := HeightfieldVariant.cell_descriptor(4.0, 1, 0, cardinals, diagonals)
	assert_eq(desc["family"], "cliff")
	assert_eq(desc["variant_tag"], "cliff-side")

func test_flat_mesa_plateau_is_cliff_tall_interior() -> void:
	var flat := {"front": 8.0, "right": 8.0, "back": 8.0, "left": 8.0}
	var fdiag := {"frontright": 8.0, "backright": 8.0, "backleft": 8.0, "frontleft": 8.0}
	# storey 2 == mesa 1, level 0, no drops -> plateau interior.
	var desc := HeightfieldVariant.cell_descriptor(8.0, 2, 0, flat, fdiag)
	assert_eq(desc["family"], "cliff-tall")
	assert_eq(desc["variant_tag"], "cliff-tall-interior")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `... -gtest=res://tests/test_heightfield_variant.gd -gexit`
Expected: FAIL — family is `cliff`, tag `cliff-side`.

- [ ] **Step 3: Implement**

In `HeightfieldVariant.gd` add the mesa constant (near line 12):

```gdscript
const MESA_HEIGHT: float = 8.0
const STOREYS_PER_MESA: int = 2
```

In `cell_descriptor`, extend the drop classification and family selection. Replace the drop loop + family block (lines ~123-145) with:

```gdscript
	var missing: Array[String] = missing_from_heights(h0, cardinals, diagonals, eps)
	var has_mesa_drop: bool = false
	var has_cliff_drop: bool = false
	var has_level_drop: bool = false
	for c in CARDINALS:
		var drop: float = h0 - float(cardinals.get(c, h0))
		if drop > eps:
			# Nearest of {8m mesa, 4m storey, 0.5m level}.
			var d_mesa: float = absf(drop - MESA_HEIGHT)
			var d_storey: float = absf(drop - STOREY_HEIGHT)
			var d_level: float = absf(drop - LEVEL_HEIGHT)
			if d_mesa <= d_storey and d_mesa <= d_level:
				has_mesa_drop = true
			elif d_storey < d_level:
				has_cliff_drop = true
			else:
				has_level_drop = true
	var mesa: int = storey / STOREYS_PER_MESA
	var family: String
	if has_mesa_drop:
		family = "cliff-tall"
	elif has_cliff_drop:
		family = "cliff"
	elif has_level_drop:
		family = "level"
	elif level > 0:
		family = "level"
	elif mesa > 0 and storey == mesa * STOREYS_PER_MESA:
		# Flat surface sitting on a mesa floor (storey_in_mesa 0) => mesa plateau.
		family = "cliff-tall"
	elif storey > 0:
		family = "cliff"
	else:
		family = "ground"
```

Extend the variant-tag mapping (lines ~149-161) to handle `cliff-tall`:

```gdscript
	var v: Dictionary = variant_for_missing(missing)
	var bare: String = v["tag"]
	var variant_tag: String
	if family == "cliff-tall":
		variant_tag = "cliff-tall-interior" if bare == "center" else "cliff-tall-" + bare
	elif family == "cliff":
		variant_tag = "cliff-interior" if bare == "center" else "cliff-" + bare
	else:
		variant_tag = "level-center" if bare == "center" else "level-" + bare
```

> Edge-case note for `test_flat_mesa_plateau`: a flat mesa-floor cell with `storey_in_mesa == 0` and `level == 0` and no drops becomes `cliff-tall-interior`. A flat cell at `storey_in_mesa == 1` (mid-mesa plateau, no drops) falls through to the `storey > 0` branch → `cliff` interior, which is correct (it sits on a 4m sub-step, not a mesa floor).

- [ ] **Step 4: Run test to verify it passes**

Run the variant test file. Expected: PASS. Also re-run `test_heightfield_variant.gd`'s existing tests — Expected: PASS (4m/0.5m behaviour unchanged).

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/heightfield/HeightfieldVariant.gd tests/test_heightfield_variant.gd
git commit -m "feat(terrain): classify 8m drops as cliff-tall family"
```

---

## Task 6: Instantiator — 8m base-fill and `cliff-tall` placement

**Files:**
- Modify: `scripts/terrain/heightfield/HeightfieldInstantiator.gd`
- Test: `tests/test_heightfield_instantiator.gd` (extend)

- [ ] **Step 1: Write the failing test**

Append to `tests/test_heightfield_instantiator.gd`:

```gdscript
func test_cliff_tall_base_fill_drops_8m() -> void:
	# A cliff-tall edge tile gets a flat base plate one MESA (8m) down.
	var inst := autofree(TerrainModuleInstance.new())
	# Build a minimal placement record for a cliff-tall side.
	var rec := {
		"variant_tag": "cliff-tall-side", "family": "cliff-tall",
		"world_x": 0.0, "world_z": 0.0, "origin_y": 8.0, "yaw": 0.0,
		"understacks": [],
	}
	# Use the static base-fill helper indirectly via spawn; assert the plate Y.
	# (If spawn requires a library, this test asserts _add_base_fill math instead.)
	assert_eq(HeightfieldInstantiator._mesa_drop_for_family("cliff-tall"), 8.0)
	assert_eq(HeightfieldInstantiator._mesa_drop_for_family("cliff"), 4.0)
```

> Rationale: a full spawn needs the module library + scenes; the base-fill drop is the new behaviour, so expose and test the drop selector directly (small, deterministic).

- [ ] **Step 2: Run test to verify it fails**

Run: `... -gtest=res://tests/test_heightfield_instantiator.gd -gexit`
Expected: FAIL — `_mesa_drop_for_family` not defined.

- [ ] **Step 3: Implement**

In `HeightfieldInstantiator.gd` add a drop constant and selector, and route `cliff-tall` through base-fill:

```gdscript
const _MESA_DROP: float = 8.0
```
```gdscript
## Base-fill drop (metres) for a walled edge tile of this family.
static func _mesa_drop_for_family(family: String) -> float:
	if family == "cliff-tall":
		return _MESA_DROP
	if family == "cliff":
		return _STOREY_DROP
	return _LEVEL_DROP
```

In `_add_base_fill`, accept `cliff-tall`. Change the family guard and the drop:

```gdscript
static func _add_base_fill(inst: TerrainModuleInstance, family: String, tag: String) -> void:
	if family != "cliff" and family != "level" and family != "cliff-tall":
		return
	if tag.ends_with("interior") or tag.ends_with("center"):
		return
	# (existing cliff "-stacked" two-storey ramp branch stays here, family == "cliff")
	if family == "cliff" and tag.contains("-stacked"):
		var plate: Node3D = _BASE_FILL_SCENE.instantiate()
		plate.position = Vector3(0.0, -2.0 * _STOREY_DROP, 0.0)
		inst.root.add_child(plate)
		return
	var drop: float = _mesa_drop_for_family(family)
	var fill: Node3D = _BASE_FILL_SCENE.instantiate()
	fill.position = Vector3(0.0, -drop, 0.0)
	inst.root.add_child(fill)
```

In `_add_debug_label`, allow the family through:

```gdscript
	if family != "cliff" and family != "level" and family != "cliff-tall":
		return
```

> `placement_for_cell` needs no mesa-specific branching: the descriptor already yields `cliff-tall-*` tags and the correct `origin_y` (the cell surface). The understack/stacked-corner logic is storey-only and the mesa diagonal clamp guarantees no two-deep mesa diagonal, so `cliff-tall` records carry empty `understacks` and `deep_corners` naturally.

- [ ] **Step 4: Run test to verify it passes**

Run the instantiator test file. Expected: PASS. Re-run existing instantiator tests — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/heightfield/HeightfieldInstantiator.gd tests/test_heightfield_instantiator.gd
git commit -m "feat(terrain): 8m base-fill + cliff-tall placement"
```

---

## Task 7: Tile fixes — `bottom` socket to `y=-8`, socket grounding

**Files:**
- Modify: `terrain/scenes/cliff/*.tscn` (14 files)
- Test: `tests/test_cliff_tall_sockets.gd` (create)

- [ ] **Step 1: Write the failing test**

Create `tests/test_cliff_tall_sockets.gd`:

```gdscript
extends GutTest

# Every authored 8m cliff scene must have its `bottom` socket at y=-8 (it sits on
# ground one mesa below) and its top* decoration sockets on the flat plateau top
# (y == 0), so plateau decorations don't float and the tile mates a mesa below.

const DIR := "res://terrain/scenes/cliff/"

func _scene_files() -> Array:
	var out := []
	var d := DirAccess.open(DIR)
	for f in d.get_files():
		if f.ends_with(".tscn"):
			out.append(DIR + f)
	return out

func test_bottom_socket_at_minus_8() -> void:
	for path in _scene_files():
		var root: Node3D = load(path).instantiate()
		var sockets := root.get_node_or_null("Sockets")
		assert_not_null(sockets, "%s has Sockets" % path)
		var bottom := sockets.get_node_or_null("bottom")
		if bottom != null:
			assert_almost_eq(bottom.position.y, -8.0, 0.001,
				"%s bottom socket should be at y=-8" % path)
		root.free()

func test_top_decoration_sockets_on_plateau() -> void:
	for path in _scene_files():
		var root: Node3D = load(path).instantiate()
		var sockets := root.get_node("Sockets")
		for child in sockets.get_children():
			if String(child.name).begins_with("top"):
				assert_almost_eq(child.position.y, 0.0, 0.001,
					"%s %s should sit on the flat plateau top" % [path, child.name])
		root.free()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `... -gtest=res://tests/test_cliff_tall_sockets.gd -gexit`
Expected: FAIL — at least `CliffSide.tscn` has `bottom` at `y=-4`.

- [ ] **Step 3: Fix the bottom sockets**

For each of the 14 scenes in `terrain/scenes/cliff/`, find the `[node name="bottom" type="Marker3D" parent="Sockets"]` transform and set its Y from `-4` to `-8`. The line looks like:
`transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -4, 0)` → change the second-to-last component to `-8`:
`transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -8, 0)`

Audit each file (grep first to see which need it):
```bash
grep -rn 'name="bottom"' terrain/scenes/cliff/   # locate each
grep -rn ', 0, -4, 0)' terrain/scenes/cliff/      # bottom sockets still at -4
```
Apply the edit to every `bottom` marker found at `-4`. If `test_top_decoration_sockets_on_plateau` fails for any tile (a top socket not at y=0), move that marker's Y to `0` (mesa tops are flat, unlike slope tops).

- [ ] **Step 4: Run test to verify it passes**

Run the socket test file. Expected: PASS across all 14 scenes.

- [ ] **Step 5: Commit**

```bash
git add terrain/scenes/cliff/ tests/test_cliff_tall_sockets.gd
git commit -m "fix(terrain): cliff-tall bottom socket to -8 + grounded top sockets"
```

---

## Task 8: Module loading — `load_cliff_tall_variants()`

**Files:**
- Modify: `scripts/terrain/TerrainModuleDefinitions.gd`, `scripts/terrain/TerrainModuleLibrary.gd`
- Test: `tests/test_cliff_tall_modules.gd` (create)

- [ ] **Step 1: Write the failing test**

Create `tests/test_cliff_tall_modules.gd`:

```gdscript
extends GutTest

# Every cliff-tall variant tag resolves to exactly one registered module, loaded
# from terrain/scenes/cliff/.

func test_all_cliff_tall_variant_tags_resolve() -> void:
	var mods := TerrainModuleDefinitions.load_cliff_tall_variants()
	var tags := {}
	for m in mods:
		for t in m.tags.to_array():
			tags[t] = true
	for entry in TerrainModuleDefinitions.CLIFF_VARIANT_TABLE:
		var tall_tag := String(entry[1]).replace("cliff-", "cliff-tall-")
		assert_true(tags.has(tall_tag), "missing module for %s" % tall_tag)
	# Interior + size tag present.
	assert_true(tags.has("cliff-tall"), "cliff-tall base tag present")
	assert_true(tags.has("24x24x8"), "8m size tag present")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `... -gtest=res://tests/test_cliff_tall_modules.gd -gexit`
Expected: FAIL — `load_cliff_tall_variants` not defined.

- [ ] **Step 3: Implement**

In `TerrainModuleDefinitions.gd`, add a loader next to `load_cliff_variants()`. `TerrainModule` is built with a **positional constructor** `TerrainModule.new(scene, bounds, tags, [], socket_size, socket_required, socket_fill_prob, socket_tag_prob, replace_existing, displaceable, socket_suppressed_by)` (see `_build_cliff_tile`'s `return` at ~line 861) — use that exact call, not field assignment.

```gdscript
## Every 8m sheer mesa cliff variant, loaded from terrain/scenes/cliff/. Placed by
## the heightfield path (direct transform), so a single tier suffices (no
## cliff-base/cliff-stack split, no stacked-corner table — the mesa diagonal clamp
## precludes two-deep mesa diagonals).
static func load_cliff_tall_variants() -> Array[TerrainModule]:
	var out: Array[TerrainModule] = []
	for entry in CLIFF_VARIANT_TABLE:
		var scene_name: String = entry[0]
		var variant_tag: String = String(entry[1]).replace("cliff-", "cliff-tall-")
		var scene_path: String = "res://terrain/scenes/cliff/%s.tscn" % scene_name
		out.append(_build_cliff_tall_tile(
			scene_path,
			TagList.new(["cliff-tall", variant_tag, "24x24x8"])
		))
	out.append(_build_cliff_tall_interior_tile())
	return out
```

`_build_cliff_tall_tile` is `_build_cliff_tile` with four substitutions: 8m bounds, `24x24x8` lateral size, `cliff-tall`/`cliff-tall-side` tags, and a fixed ground bottom (no stack tier). Spell it out fully:

```gdscript
static func _build_cliff_tall_tile(scene_path: String, tags: TagList) -> TerrainModule:
	var scene: PackedScene = load(scene_path)
	var bb: AABB = AABB(Vector3(-12, -8, -12), Vector3(24, 8, 24))
	# Plateau-top foliage: identical to ground/cliff tops.
	var surface: Dictionary = surface_spawn_sockets(
		Distribution.new({"24x24x0.5": 1.0}),
		Distribution.new({"cliff-tall-side": 1.0}),
		0.0,
		GROUND_FOLIAGE_FILL_PROB,
		0.0
	)
	var socket_size: Dictionary[String, Distribution] = {
		"front": Distribution.new({"24x24x8": 1.0}),
		"back": Distribution.new({"24x24x8": 1.0}),
		"left": Distribution.new({"24x24x8": 1.0}),
		"right": Distribution.new({"24x24x8": 1.0}),
		"topcenter": Distribution.new({"24x24x0.5": 1.0}),
		"bottom": Distribution.new({"24x24x0.5": 1.0}),
	}
	socket_size.merge(surface["socket_size"])
	var socket_required: Dictionary[String, TagList] = {
		"front": TagList.new(["cliff-tall"]),
		"back": TagList.new(["cliff-tall"]),
		"left": TagList.new(["cliff-tall"]),
		"right": TagList.new(["cliff-tall"]),
		"bottom": TagList.new(["ground"]),
	}
	var socket_fill_prob: Dictionary[String, Variant] = {
		"front": CLIFF_LATERAL_FILL_PROB,
		"back": CLIFF_LATERAL_FILL_PROB,
		"left": CLIFF_LATERAL_FILL_PROB,
		"right": CLIFF_LATERAL_FILL_PROB,
		"frontleft": null,
		"frontright": null,
		"backleft": null,
		"backright": null,
		"bottom": null,
		"topcenter": 0.0,
	}
	socket_fill_prob.merge(surface["socket_fill_prob"])
	socket_fill_prob = _socket_fill_prob_for_scene(scene, socket_fill_prob)
	var cliff_lateral_dist: Distribution = Distribution.new({"cliff-tall-side": 1.0})
	var socket_tag_prob: Dictionary[String, Distribution] = {
		"front": cliff_lateral_dist,
		"back": cliff_lateral_dist,
		"left": cliff_lateral_dist,
		"right": cliff_lateral_dist,
	}
	socket_tag_prob.merge(surface["socket_tag_prob"])
	return TerrainModule.new(
		scene,
		bb,
		tags,
		[],
		socket_size,
		socket_required,
		socket_fill_prob,
		socket_tag_prob,
		CLIFF_REPLACE_EXISTING,
		false,  # displaceable
		surface["socket_suppressed_by"]
	)
```

For the interior, mirror `_build_cliff_interior_module` (~line 725) — it loads `GroundTile.tscn`, claims the full storey volume in its bounds, and seeds its topcenter. Copy its body with two changes: bounds `AABB(Vector3(-12, -8, -12), Vector3(24, 8, 24))` (full 8m volume) and tags `["cliff-tall", "cliff-tall-interior", "ground-type", "24x24x8"]`; its topcenter seed distribution should target `"cliff-tall-side"`:

```gdscript
static func _build_cliff_tall_interior_tile() -> TerrainModule:
	return _build_cliff_interior_like(
		TagList.new(["cliff-tall", "cliff-tall-interior", "ground-type", "24x24x8"]),
		AABB(Vector3(-12, -8, -12), Vector3(24, 8, 24)),
		"cliff-tall-side"
	)
```

> If `_build_cliff_interior_module` is not already parameterized by (tags, bounds, seed-tag), do the minimal refactor to extract `_build_cliff_interior_like(tags, bounds, seed_tag)` from it and have the existing `load_cliff_interior_tile`/`load_cliff_stack_interior_tile` call it with their current values (bounds `AABB(Vector3(-12,-4,-12),Vector3(24,4,24))`, seed `"cliff-stack-side"`). Keep that refactor behavior-identical and covered by the existing cliff-interior tests.

Register the new modules. In `TerrainModuleLibrary.gd`, find where `load_cliff_variants()` results are added to the library (`load_terrain_modules`) and add `load_cliff_tall_variants()` alongside:

```gdscript
	for m in TerrainModuleDefinitions.load_cliff_tall_variants():
		_register(m)   # match the exact registration call used for load_cliff_variants
```

- [ ] **Step 4: Run test to verify it passes**

Re-import (new nothing, but safe) then run the modules test file.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/TerrainModuleDefinitions.gd scripts/terrain/TerrainModuleLibrary.gd tests/test_cliff_tall_modules.gd
git commit -m "feat(terrain): register cliff-tall modules from scenes/cliff"
```

---

## Task 9: Surface continuity at mesa boundaries (integration)

**Files:**
- Test: `tests/test_mesa_tile_continuity.gd` (create)

- [ ] **Step 1: Write the failing/guard test**

Create `tests/test_mesa_tile_continuity.gd` — model on `tests/test_slope_tile_continuity.gd`. Drive a synthetic two-mesa field and assert that the spawned placements form a gap-free surface across the 8m boundary (no vertical discontinuity beyond the intended single 8m face, and the 8m tile's top edge meets the upper plateau and its base meets the lower ground).

```gdscript
extends GutTest

# A mesa boundary must place a cliff-tall edge whose top is at the upper surface
# and whose base-fill sits 8m below (lower ground), with no gap.

func test_mesa_boundary_places_cliff_tall_with_8m_face() -> void:
	var plan := HeightfieldPlan.new(5, 64.0, 8, "mean")
	plan.set_raw_height_override(func(cx, cz):
		return 8.0 if cx >= 0 else 0.0)   # sharp 1-mesa step at x=0
	var rec := HeightfieldInstantiator.placement_for_cell(plan, 0, 0)
	assert_eq(String(rec["variant_tag"]), "cliff-tall-side")
	assert_almost_eq(float(rec["origin_y"]), 8.0, 0.001)
	# The neighbour at x=-1 is plain ground at y=0 (no wall).
	var rec_lo := HeightfieldInstantiator.placement_for_cell(plan, -1, 0)
	assert_eq(String(rec_lo["variant_tag"]), "ground")
	assert_almost_eq(float(rec_lo["origin_y"]), 0.0, 0.001)
```

- [ ] **Step 2: Run test to verify it fails / passes**

Run: `... -gtest=res://tests/test_mesa_tile_continuity.gd -gexit`
Expected: PASS once Tasks 2-6 are in (this is a guard; if it fails, the descriptor/placement wiring has a gap — debug there).

- [ ] **Step 3: (If failing) debug**

Use `superpowers:systematic-debugging`. Most likely culprits: descriptor not emitting `cliff-tall-side` (recheck Task 5 magnitude test), or `origin_y` wrong (recheck `surface_height`).

- [ ] **Step 4: Commit**

```bash
git add tests/test_mesa_tile_continuity.gd
git commit -m "test(terrain): mesa-boundary continuity guard"
```

---

## Task 10: Noise tuning for visible ravines/plateaus

Minimal, visual, iterative. Keep changes isolated to `_height01`.

**Files:**
- Modify: `scripts/terrain/heightfield/HeightfieldPlan.gd` (`_height01`)
- Test: `tests/test_heightfield_mesa.gd` (a coarse "mesas exist" guard)

- [ ] **Step 1: Write a coarse guard test**

Append to `tests/test_heightfield_mesa.gd`:

```gdscript
# Sanity: across a large default-noise region, at least some cells reach mesa >= 1
# (otherwise the tier never triggers and ravines never appear).
func test_default_noise_produces_some_mesas() -> void:
	var p := HeightfieldPlan.new(424242, 48.0, 8, "mean")
	var region := p.compute_region(0, 0, 30)
	var max_mesa := 0
	for dz in range(-30, 31):
		for dx in range(-30, 31):
			max_mesa = maxi(max_mesa, region.mesa_at(dx, dz))
	assert_gte(max_mesa, 1, "default noise should surface at least one mesa")
```

- [ ] **Step 2: Run it**

Run the mesa test file. If it already passes with current `_height01`, the existing amplitude is sufficient — no noise change needed; record that and skip to Step 4. If it fails, proceed.

- [ ] **Step 3: (If needed) nudge the macro band**

In `_height01`, the broad-landform octave (`base`, wavelength 320) drives mesa-scale relief. To make mesas appear more readily without touching biome logic, modestly raise the macro contribution or amplitude — e.g. bias `base` upward or widen the rocky multiplier. Make ONE small change, re-run the guard + the parity/uniform-face tests, and stop as soon as the guard passes. Do not retune further here; visual iteration happens in-engine (Task 11 manual check).

- [ ] **Step 4: Run the full mesa + plan + region tests**

Run `test_heightfield_mesa.gd`, `test_heightfield_plan.gd`, `test_heightfield_region.gd`, `test_heightfield_variant.gd`, `test_heightfield_instantiator.gd`.
Expected: PASS (except the known-baseline `test_heightfield_interior_corners.gd`, which is not run here).

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/heightfield/HeightfieldPlan.gd tests/test_heightfield_mesa.gd
git commit -m "feat(terrain): ensure default noise surfaces mesa relief"
```

---

## Task 11: Manual in-engine verification

**Files:** none (manual).

- [ ] **Step 1:** Launch the project (or the terrain demo scene) and walk the world.
- [ ] **Step 2:** Confirm: gentle areas show grass slopes + level terraces; steep areas show **8m sheer rock walls** forming plateaus/mesas and ravines; mesa edges are clean single 8m faces (no floating decorations, no gaps under the lip, no z-fighting).
- [ ] **Step 3:** If the look needs tuning, iterate ONLY on `_height01` (mesa frequency/amplitude) and re-run Task 10's guard + the parity/uniform-face tests after each change.
- [ ] **Step 4:** Use `superpowers:requesting-code-review` before finishing the branch.

---

## Self-review notes (carried into execution)

- **Spec coverage:** mesa tier math (Tasks 1-4), uniform-face guarantee via mesa-distance ramp (Task 2 + Task 4 property test), `cliff-tall` classification (5), 8m placement/base-fill (6), bottom-socket fix + grounding (7), module wiring (8), continuity (9), minimal noise (10), manual check (11). The diagonal ±1 mesa clamp is realized by `clamp_field_8way` (Task 1) and relied on in Tasks 6/8 (no stacked mesa corners).
- **Type consistency:** `clamp_field_8way`, `quantize_mesa`, `mesa_at`, `_build_mesa_map`, `_mesa_distance_in`, `_has_diagonal_mesa_cliff`, `_clamp_storeys_in_mesa`, `_build_storey_map` (returns absolute storeys), `_mesa_drop_for_family`, `load_cliff_tall_variants`, `_build_cliff_tall_tile`, `_build_cliff_tall_interior_tile` — names used consistently across tasks.
- **Risk to watch in execution:** Task 8's `_build_cliff_tall_tile` must copy the exact socket-dict tail of `_build_cliff_tile` and match `TerrainModule`'s real property names + the library's real registration call — verify against the live code before asserting done (the plan flags both spots).
