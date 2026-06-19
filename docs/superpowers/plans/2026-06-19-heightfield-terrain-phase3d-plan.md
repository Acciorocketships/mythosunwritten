# Heightfield Terrain — Batching, Water & Cutover Fixes (Phase 3d) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Make the heightfield path fast enough to run live (batch the per-region plan computation), restore water/banks on heightfield tiles, and stop emergent ground-lateral expansion fighting the plan — so the cutover can be turned on.

**Architecture:** Add `HeightfieldPlan.compute_region(cx,cz,radius)` that runs the storey clamp and the level clamp **once per region** (instead of rebuilding huge windows per cell), returning a `HeightfieldRegion` with O(1) `storey_at/level_at/surface_height/tile_plan` lookups whose values are **provably equal** to the per-cell reference. `place_region` computes a region only when there are new cells to place. Then: run `WaterRule` on placed ground tiles so water/banks form; suppress ground laterals when the flag is on.

**Tech Stack:** Godot 4.5 typed GDScript, GUT. The batching is unit-tested for exactness (batched == reference) and re-benchmarked.

---

## Background (measured)

The current reference path is ~31 ms per `surface_height` call → ~79 s to build a radius-8 region, ~4.8 s per tile of movement (see `tests/harness/hf_bench.gd`). Cause: each cell rebuilds a ~2,400-cell window + clamp from scratch; a region recomputes overlapping windows 289×. Batching computes each clamp once for the whole region.

Window margins (from Phases 1–2): the storey clamp influence is ≤ `max_storeys`; the level clamp reach is ≤ `LEVELS_PER_STOREY`; cliff-distance scans ≤ `_CLIFF_SEARCH_MAX`. So to get final values over the place block `[c ± radius]` **and its neighbours** `[c ± (radius+1)]` (needed for variant descriptors), compute the storey clamp over `[c ± (radius + 1 + LEVELS_PER_STOREY + _CLIFF_SEARCH_MAX + max_storeys)]`.

## File Structure

- Create: `scripts/terrain/heightfield/HeightfieldRegion.gd` — immutable precomputed storey/level maps with `storey_at/level_at/surface_height/tile_plan`.
- Modify: `scripts/terrain/heightfield/HeightfieldPlan.gd` — `compute_region()`.
- Modify: `scripts/terrain/heightfield/HeightfieldInstantiator.gd` — `place_region` uses a region; relax `placement_for_cell` param.
- Modify: `scripts/terrain/TerrainGenerator.gd` — run `WaterRule` on placed ground tiles; suppress ground laterals when the flag is on.
- Modify: `tests/harness/hf_bench.gd` — benchmark the batched region build.
- Tests: `tests/test_heightfield_region.gd`, additions to existing suites.

## Conventions

- Single suite: `/Applications/Godot.app/Contents/MacOS/Godot -d -s --path "$PWD" addons/gut/gut_cmdln.gd -gdir=res://tests -gconfig=res://tests/gutconfig.json -gselect=<file>.gd`
- Full suite: drop `-gselect`. GUT fails a test on any `push_error`.

---

### Task 1: `HeightfieldRegion` + `compute_region` (batched, provably == reference)

**Files:**
- Create: `scripts/terrain/heightfield/HeightfieldRegion.gd`
- Modify: `scripts/terrain/heightfield/HeightfieldPlan.gd`
- Test: `tests/test_heightfield_region.gd`

- [ ] **Step 1: Write the failing tests** — create `tests/test_heightfield_region.gd`:

```gdscript
extends GutTest

# Phase 3d: batched region computation must equal the per-cell reference path.

func test_region_storey_and_level_match_reference() -> void:
	var plan: HeightfieldPlan = HeightfieldPlan.new(4242, 48.0, 8, "mean")
	var region: HeightfieldRegion = plan.compute_region(7, -3, 4)
	for cz in range(-4, 5):
		for cx in range(-4, 5):
			var rcx: int = 7 + cx
			var rcz: int = -3 + cz
			assert_eq(region.storey_at(rcx, rcz), plan.storey_at(rcx, rcz),
				"batched storey == reference at (%d,%d)" % [rcx, rcz])
			assert_eq(region.level_at(rcx, rcz), plan.level_at(rcx, rcz),
				"batched level == reference at (%d,%d)" % [rcx, rcz])

func test_region_surface_height_and_tile_plan_match_reference() -> void:
	var plan: HeightfieldPlan = HeightfieldPlan.new(99, 60.0, 10, "mean")
	var region: HeightfieldRegion = plan.compute_region(0, 0, 3)
	for cz in range(-3, 4):
		for cx in range(-3, 4):
			assert_almost_eq(region.surface_height(cx, cz), plan.surface_height(cx, cz), 0.0001,
				"batched surface_height == reference at (%d,%d)" % [cx, cz])
			var rtp: Dictionary = region.tile_plan(cx, cz)
			var ptp: Dictionary = plan.tile_plan(cx, cz)
			assert_eq(rtp["storey"], ptp["storey"], "tile_plan storey matches")
			assert_eq(rtp["level"], ptp["level"], "tile_plan level matches")

func test_region_covers_one_tile_of_neighbours_beyond_radius() -> void:
	# Descriptors need each placed cell's neighbours, so the region must be valid
	# one tile beyond `radius`.
	var plan: HeightfieldPlan = HeightfieldPlan.new(4242, 48.0, 8, "mean")
	var region: HeightfieldRegion = plan.compute_region(0, 0, 2)
	assert_eq(region.storey_at(3, 0), plan.storey_at(3, 0), "neighbour ring (radius+1) is valid")
```

- [ ] **Step 2: Run, confirm FAIL** (`HeightfieldRegion` / `compute_region` unknown):
```
/Applications/Godot.app/Contents/MacOS/Godot -d -s --path "$PWD" addons/gut/gut_cmdln.gd -gdir=res://tests -gconfig=res://tests/gutconfig.json -gselect=test_heightfield_region.gd
```

- [ ] **Step 3: Create `scripts/terrain/heightfield/HeightfieldRegion.gd`:**

```gdscript
class_name HeightfieldRegion
extends RefCounted

## Precomputed storey/level maps over a region, with the same read interface as
## HeightfieldPlan (storey_at/level_at/surface_height/tile_plan) but O(1) lookups.
## Built by HeightfieldPlan.compute_region; values equal the per-cell reference.

const STOREY_HEIGHT: float = 4.0
const LEVEL_HEIGHT: float = 0.5

var _storeys: Dictionary  # Vector2i -> int
var _levels: Dictionary   # Vector2i -> int


func _init(storeys: Dictionary, levels: Dictionary) -> void:
	_storeys = storeys
	_levels = levels


func storey_at(cx: int, cz: int) -> int:
	return int(_storeys.get(Vector2i(cx, cz), 0))


func level_at(cx: int, cz: int) -> int:
	return int(_levels.get(Vector2i(cx, cz), 0))


func surface_height(cx: int, cz: int) -> float:
	return float(storey_at(cx, cz)) * STOREY_HEIGHT + float(level_at(cx, cz)) * LEVEL_HEIGHT


func tile_plan(cx: int, cz: int) -> Dictionary:
	var s: int = storey_at(cx, cz)
	var l: int = level_at(cx, cz)
	return {"storey": s, "level": l, "height": float(s) * STOREY_HEIGHT + float(l) * LEVEL_HEIGHT}
```

- [ ] **Step 4: Add `compute_region` to `scripts/terrain/heightfield/HeightfieldPlan.gd`** (append at end):

```gdscript
## Batched region computation: runs the storey clamp and level clamp ONCE for the
## whole [center +/- radius] block (plus the margins that make values final), then
## returns a HeightfieldRegion of O(1) lookups equal to the per-cell reference.
## Replaces ~radius^2 redundant window rebuilds with two clamps.
func compute_region(center_cx: int, center_cz: int, radius: int) -> HeightfieldRegion:
	var place_r: int = radius + 1                       # placed cells + neighbour ring
	var level_r: int = place_r + LEVELS_PER_STOREY      # level-clamp reach
	var storey_final_r: int = level_r + _CLIFF_SEARCH_MAX
	var storey_outer: int = storey_final_r + max_storeys

	# 1. Storeys: quantize the outer window, clamp once.
	var targets: Dictionary = {}
	for dz in range(-storey_outer, storey_outer + 1):
		for dx in range(-storey_outer, storey_outer + 1):
			var cell: Vector2i = Vector2i(center_cx + dx, center_cz + dz)
			targets[cell] = quantize_storey(raw_height(cell.x, cell.y))
	var storeys: Dictionary = clamp_field(targets)

	# 2. Pre-clamp level L0 over the level window (detail capped by the cliff ramp).
	var l0: Dictionary = {}
	for dz in range(-level_r, level_r + 1):
		for dx in range(-level_r, level_r + 1):
			var cell: Vector2i = Vector2i(center_cx + dx, center_cz + dz)
			var s: int = int(storeys[cell])
			var residual: float = raw_height(cell.x, cell.y) - float(s) * STOREY_HEIGHT
			var detail: int = clampi(_round_mode(residual / LEVEL_HEIGHT), 0, LEVELS_PER_STOREY - 1)
			var cliff_cap: int = _cliff_distance_in(cell, storeys, _CLIFF_SEARCH_MAX) - 1
			l0[cell] = clampi(mini(detail, cliff_cap), 0, LEVELS_PER_STOREY - 1)

	# 3. Storey-masked level clamp once.
	var levels: Dictionary = _clamp_levels(l0, storeys)
	return HeightfieldRegion.new(storeys, levels)
```

- [ ] **Step 5: Run, confirm PASS** (3 region tests). The batched values must equal the reference — if any mismatch, a margin is too tight; report the failing cell, do not loosen the assertion.

- [ ] **Step 6: Commit:**
```bash
git add scripts/terrain/heightfield/HeightfieldRegion.gd scripts/terrain/heightfield/HeightfieldPlan.gd tests/test_heightfield_region.gd
git commit -m "feat(terrain): batched compute_region (storey/level clamp once per region)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Use the region in `place_region` + re-benchmark

**Files:**
- Modify: `scripts/terrain/heightfield/HeightfieldInstantiator.gd`
- Modify: `tests/harness/hf_bench.gd`
- Modify: `tests/test_heightfield_instantiator.gd`

- [ ] **Step 1: Write the failing test** — append to `tests/test_heightfield_instantiator.gd`:

```gdscript
func test_place_region_uses_batched_region_and_matches_per_cell() -> void:
	# place_region (now batched) must place the same tiles at the same heights as
	# the per-cell placements() path.
	var lib: TerrainModuleLibrary = _library()
	var plan: HeightfieldPlan = _stepped_plan()
	var parent: Node3D = Node3D.new()
	add_child_autofree(parent)
	var placer: HeightfieldInstantiator = HeightfieldInstantiator.new()
	placer.place_region(plan, lib, parent, 0, 0, 2)
	# Every placed tile sits at the plan's surface height for its cell.
	for child in parent.get_children():
		var t: Transform3D = (child as Node3D).transform
		var cx: int = int(round(t.origin.x / HeightfieldPlan.TILE))
		var cz: int = int(round(t.origin.z / HeightfieldPlan.TILE))
		assert_almost_eq(t.origin.y, plan.surface_height(cx, cz), 0.01,
			"batched placement height matches the plan at (%d,%d)" % [cx, cz])
```

- [ ] **Step 2: Run, confirm it still passes (or fails only if integration is wrong)** — this guards the refactor.

- [ ] **Step 3: Refactor `place_region` to compute one region for the new cells.** In `scripts/terrain/heightfield/HeightfieldInstantiator.gd`, replace `place_region` with:

```gdscript
func place_region(
	plan: HeightfieldPlan, library: TerrainModuleLibrary, parent: Node3D,
	center_cx: int, center_cz: int, place_radius: int
) -> Array[TerrainModuleInstance]:
	# Collect cells not yet placed; if none, this frame is free.
	var new_cells: Array[Vector2i] = []
	for dz in range(-place_radius, place_radius + 1):
		for dx in range(-place_radius, place_radius + 1):
			var cell: Vector2i = Vector2i(center_cx + dx, center_cz + dz)
			if not _placed.has(cell):
				new_cells.append(cell)
	var spawned: Array[TerrainModuleInstance] = []
	if new_cells.is_empty():
		return spawned
	# Batch the plan computation for the whole region exactly once.
	var region: HeightfieldRegion = plan.compute_region(center_cx, center_cz, place_radius)
	for cell in new_cells:
		var rec: Dictionary = placement_for_cell(region, cell.x, cell.y)
		var inst: TerrainModuleInstance = spawn_placement(rec, library, parent)
		_placed[cell] = inst
		if inst != null:
			spawned.append(inst)
	return spawned
```

- [ ] **Step 4: Relax `placement_for_cell` / `_neighbour_heights` first param** so a `HeightfieldRegion` (same read interface) works. Change their signatures from `plan: HeightfieldPlan` to `plan` (untyped), and add a one-line doc: `# `plan` is anything with tile_plan(cx,cz) + surface_height(cx,cz): HeightfieldPlan or HeightfieldRegion.` Leave the bodies unchanged (they call `plan.tile_plan` / `plan.surface_height` / `plan.raw_height`? — NOTE: `_neighbour_heights` calls `plan.surface_height` only; `placement_for_cell` calls `plan.tile_plan`. Neither calls `raw_height`, so a region works.) Confirm by reading the two functions.

- [ ] **Step 5: Run the instantiator suite, confirm PASS** (15 tests). All prior placement tests must still pass (they pass a `HeightfieldPlan`, which still satisfies the calls).

- [ ] **Step 6: Re-benchmark.** Replace the region-build timing in `tests/harness/hf_bench.gd` with the batched path. Replace the `placement_for_cell x289` block with:

```gdscript
	# --- batched region build (radius 8) + per-cell descriptor reads ---
	var t2: int = Time.get_ticks_usec()
	var region: HeightfieldRegion = plan.compute_region(100, 100, 8)
	var t3: int = Time.get_ticks_usec()
	print("[bench] compute_region radius-8 (one batched clamp pair): %.1f ms" % [float(t3 - t2) / 1000.0])
	var t4: int = Time.get_ticks_usec()
	for dz in range(-8, 9):
		for dx in range(-8, 9):
			HeightfieldInstantiator.placement_for_cell(region, 100 + dx, 100 + dz)
	var t5: int = Time.get_ticks_usec()
	print("[bench] 289 descriptor reads from region: %.1f ms" % [float(t5 - t4) / 1000.0])
```
Run it and record the numbers:
```
/Applications/Godot.app/Contents/MacOS/Godot --headless -s --path "$PWD" res://tests/harness/hf_bench.gd
```
Report the before (≈79,000 ms) vs after (compute_region + 289 reads) numbers.

- [ ] **Step 7: Commit:**
```bash
git add scripts/terrain/heightfield/HeightfieldInstantiator.gd tests/harness/hf_bench.gd tests/test_heightfield_instantiator.gd
git commit -m "perf(terrain): place_region builds one batched region (not per-cell windows)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Suppress ground laterals when the flag is on

**Files:**
- Modify: `scripts/terrain/TerrainGenerator.gd`
- Modify: `tests/test_heightfield_cutover.gd`

Rationale: with the heightfield as the sole structural+base source (placed in a moving region around the player), emergent ground-lateral expansion is redundant and can double-place ground at the region edge. Suppress it when the flag is on.

- [ ] **Step 1: Write the failing test** — append to `tests/test_heightfield_cutover.gd`:

```gdscript
func test_ground_laterals_suppressed_under_heightfield() -> void:
	var gen = _make_generator(true)
	var lib: TerrainModuleLibrary = TerrainModuleLibrary.new()
	lib.init()
	var ground: TerrainModuleInstance = _spawn(lib, "ground-plain")
	assert_true(gen._is_structural_socket(ground, "front"), "ground laterals are structural under heightfield")
	gen.free()
```
(NOTE: this CHANGES the earlier `test_is_structural_socket_classifies_seeds_vs_decoration` expectation that `ground front` is false. UPDATE that earlier test's ground-front assertion to `assert_true(... , ...)` with a comment that ground laterals are suppressed under the heightfield, since the heightfield now owns the base plane.)

- [ ] **Step 2: Run, confirm FAIL.**

- [ ] **Step 3: Update `_is_structural_socket`** in `scripts/terrain/TerrainGenerator.gd` so ground-plain cardinal laterals are also structural:
```gdscript
func _is_structural_socket(piece: TerrainModuleInstance, socket_name: String) -> bool:
	if piece.def.tags.has("level") or piece.def.tags.has("cliff"):
		return socket_name in ["front", "back", "left", "right", "topcenter"]
	if piece.def.tags.has("ground-plain"):
		# Under the heightfield, the moving place-region is the sole base-plane
		# source; emergent ground laterals would double-place at the region edge.
		return socket_name in ["front", "back", "left", "right", "topcenter"]
	return false
```

- [ ] **Step 4: Run cutover suite, confirm PASS. Then FULL suite (flag off — ground laterals still active when off, base plane unaffected).** Report totals.

- [ ] **Step 5: Commit:**
```bash
git add scripts/terrain/TerrainGenerator.gd tests/test_heightfield_cutover.gd
git commit -m "feat(terrain): suppress ground laterals under heightfield (plan owns the base plane)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Water/banks on heightfield ground tiles

**Files:**
- Modify: `scripts/terrain/TerrainGenerator.gd`
- Modify: `tests/test_heightfield_cutover.gd`

Approach: after placing the region, run the rule pipeline **only on the placed ground tiles**. `WaterRule.matches` fires on `ground`-family tiles and swaps water / retiles banks; `LevelEdgeRule`/`CliffEdgeRule` only match `level`/`cliff` tiles, so they will NOT retile the heightfield's structural variants. WaterRule may replace a ground tile with a water/bank tile — update `_placed` so eviction removes the live instance.

- [ ] **Step 1: Write the failing test** — append to `tests/test_heightfield_cutover.gd`:

```gdscript
func test_heightfield_ground_becomes_water_in_water_field() -> void:
	# Find a cell whose position is water per the field, then confirm a heightfield
	# ground tile placed there is converted by WaterRule.
	var gen = _make_generator(true)
	add_child_autofree(gen)
	gen.init_for_test()
	gen.HEIGHTFIELD_PLACE_RADIUS = 3
	# Park near a known water cell for this seed; search a small area for one.
	var seed: int = gen.world_seed
	var water_cell := Vector2i(99999, 99999)
	for cz in range(-30, 30):
		for cx in range(-30, 30):
			if Helper.is_water(Vector3(cx * 24.0, 0, cz * 24.0), seed):
				water_cell = Vector2i(cx, cz)
				break
		if water_cell.x != 99999:
			break
	assert_true(water_cell.x != 99999, "found a water cell for this seed")
	gen._drive_heightfield_structure(Vector3(water_cell.x * 24.0, 0, water_cell.y * 24.0))
	# A water tile now occupies that column.
	var box: AABB = AABB(Vector3(water_cell.x * 24.0 - 1, -6, water_cell.y * 24.0 - 1), Vector3(2, 12, 2))
	var has_water: bool = false
	for hit in gen.terrain_index.query_box(box):
		if hit is TerrainModuleInstance and hit.def.tags.has("water"):
			has_water = true
	assert_true(has_water, "heightfield ground in the water field is converted to water")
	gen.free()
```

- [ ] **Step 2: Run, confirm FAIL.**

- [ ] **Step 3: Run WaterRule on placed ground tiles.** In `_drive_heightfield_structure`, after the `register_piece`/`add_piece_to_queue` loop, add a pass that runs the existing rule pipeline on placed GROUND tiles (so WaterRule fires; edge rules are inert on ground):
```gdscript
	for inst in spawned:
		if inst != null and inst.def.tags.has("ground"):
			_run_rules_for_existing_piece(inst)
```
If WaterRule replacing a tile desyncs `_placed`, update `_placed` to the replacement. Simplest robust handling: after the rules pass, the instantiator's `_placed[cell]` may point at a freed instance; since eviction calls `remove_piece` which no-ops on an already-removed piece, verify `remove_piece` is null/none-safe. If `remove_piece` errors on a freed piece, add a guard (`if piece == null or not is_instance_valid(piece.root): return`) at the top of `remove_piece`. Confirm by reading `remove_piece`.

- [ ] **Step 4: Run cutover suite, confirm PASS. Then FULL suite (flag off).** Report totals.

- [ ] **Step 5: Re-render the screenshot harness** (`tests/harness/heightfield_shot.tscn`) and confirm water now appears with the flag on. (Visual check; record the result.)

- [ ] **Step 6: Commit:**
```bash
git add scripts/terrain/TerrainGenerator.gd tests/test_heightfield_cutover.gd
git commit -m "feat(terrain): run WaterRule on heightfield ground tiles (water/banks restored)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage:** Batching → Tasks 1–2 (with an exactness test: batched == reference, the key safety net). Live perf gating (no recompute when no new cells) → Task 2's `new_cells` early-return. Ground-lateral conflict → Task 3. Water/banks → Task 4. Re-benchmark → Task 2 Step 6.

**Placeholder scan:** Complete code in all tasks; Task 4's `_placed`/`remove_piece` robustness is spelled out with a concrete guard and a "read it to confirm" instruction.

**Type consistency:** `HeightfieldRegion` exposes the same `storey_at/level_at/surface_height/tile_plan` as `HeightfieldPlan`, so relaxing `placement_for_cell`'s first param lets either work. `compute_region` returns a `HeightfieldRegion`. Margins reuse the real consts (`LEVELS_PER_STOREY`, `_CLIFF_SEARCH_MAX`, `max_storeys`).

**Risks:** (1) Batched-vs-reference exactness depends on the margin arithmetic — the Task 1 test checks every region cell against the reference, so an off-by-one margin fails loudly. (2) Task 4's WaterRule-on-ground assumes edge rules are inert on ground tiles (true: they match only level/cliff tags) — verify during implementation. (3) WaterRule replacements vs `_placed`/eviction — handled via a null/validity guard in `remove_piece`.
