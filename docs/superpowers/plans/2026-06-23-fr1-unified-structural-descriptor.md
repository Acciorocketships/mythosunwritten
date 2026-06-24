# FR-1: Unified structural descriptor + multi-elevation water — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Implement task-by-task; each task ends green + committed. Behavior-changing where noted (water becomes multi-elevation); structure-preserving elsewhere.

**Goal:** Make ground/level/cliff/water/bank all emerge from one cell-descriptor over the field, with multi-elevation water (`water_table > land`), and delete `WaterRule`.

**Architecture:** Add a deterministic, quantized, clamped **water-table field** to `HeightfieldPlan`. Generalize `HeightfieldVariant.cell_descriptor` so a side is a wall when the neighbour *surface* (land height OR water-table) is lower, tagging each wall's material (land vs water-facing) and the water cell itself — banks and water tiles fall out of the same pass. The `HeightfieldInstantiator` places water/bank tiles directly; `WaterRule` and its tables are deleted.

**Tech Stack:** Godot 4 / GDScript, GUT tests. Binary `/Applications/Godot.app/Contents/MacOS/Godot`. One test: `… -s addons/gut/gut_cmdln.gd -gtest=res://tests/<f>.gd -gexit`; full suite `-gconfig=res://tests/gutconfig.json`. `--import` after new `class_name`/test files.

**Branch:** `refactor/terrain-field-driven`. Stage specific files; never `*.uid`.

**Grounding (read before starting):** `scripts/terrain/heightfield/HeightfieldPlan.gd` (`raw_height`, `_height01`, `quantize_storey`/`detail_level`, `clamp_field`/`_clamp_levels`, `surface_height`, `compute_region`, `HeightfieldRegion`), `HeightfieldVariant.gd` (`cell_descriptor`, `missing_from_heights`, `CANONICAL_MISSING_BY_TAG`), `HeightfieldInstantiator.gd` (`placement_for_cell`, `spawn_placement`, `place_region`), `scripts/core/Helper.gd` (`is_water`/`_is_water_raw`, `WATER_*` consts), `scripts/terrain/rules/WaterRule.gd`, `scripts/terrain/TerrainGenerator.gd:1047 _drive_heightfield_structure`, `TerrainModuleDefinitions.gd` water/bank loaders.

---

## File structure

- **Modify** `HeightfieldPlan.gd` — add the water-table field + `is_water_cell`/`water_surface`.
- **Modify** `HeightfieldVariant.gd` — `cell_descriptor` emits `material` + water-aware walls; add water/bank variant tags.
- **Modify** `HeightfieldRegion.gd` + `compute_region` — carry the water-table so `placement_for_cell` reads it O(1).
- **Modify** `HeightfieldInstantiator.gd` — place water + bank tiles from the descriptor.
- **Modify** `TerrainGenerator.gd` — drop the per-piece WaterRule run; keep streaming.
- **Modify** `TerrainModuleDefinitions.gd` / `TerrainModuleLibrary.gd` — water/bank modules keyed by the new descriptor tags; delete `BANK_VARIANT_TABLE` parallelism.
- **Modify** `Helper.gd` — shrink `WATER_CLEAR_RADIUS`/`_FADE`; expose the water-table noise source.
- **Delete** `scripts/terrain/rules/WaterRule.gd`, `TerrainGenerationRule.gd`, `TerrainGenerationRuleLibrary.gd` (if no other rule consumer remains after Task 5).
- **Tests** — new `test_water_table.gd`, `test_water_descriptor.gd`; remove `test_water_rule.gd`; extend `test_heightfield_variant`/`_coverage`/`_region`.

---

## Task 1: Water-table field on `HeightfieldPlan`

Water sits wherever a quantized, clamped water-table elevation exceeds the land surface. Model (starting formulation — tuned visually in Task 6): the height field **carves basins** in water-footprint regions, and the water table fills them to the surrounding rim.

**Files:** Modify `HeightfieldPlan.gd`; Test `tests/test_water_table.gd`.

- [ ] **Step 1 — Failing test.** Create `tests/test_water_table.gd`:

```gdscript
extends GutTest
const Plan := preload("res://scripts/terrain/heightfield/HeightfieldPlan.gd")

func _plan() -> Object:
	var p = Plan.new(0, 32.0, 8, "mean")
	return p

func test_water_when_table_above_land() -> void:
	var p = _plan()
	# Override land + table so cell (0,0) is a basin (land 0) under a table at 1 storey.
	p.set_raw_height_override(func(cx, cz): return 0.0 if cx == 0 and cz == 0 else 8.0)
	p.set_water_table_override(func(cx, cz): return 4.0)   # table at +4 (1 storey)
	assert_true(p.is_water_cell(0, 0), "land(0) below table(4) is water")
	assert_false(p.is_water_cell(1, 0), "land(8) above table(4) is dry")
	assert_almost_eq(p.water_surface(0, 0), 4.0, 0.001, "water surface is the table height")

func test_water_table_deterministic() -> void:
	var a = _plan(); var b = _plan()
	for c in [Vector2i(5, 3), Vector2i(-7, 12)]:
		assert_eq(a.water_table(c.x, c.y), b.water_table(c.x, c.y))

func test_water_table_trickle_clamp() -> void:
	# Adjacent water surfaces differ by <= one step (no water waterfalls).
	var p = _plan()
	for cz in range(-3, 4):
		for cx in range(-3, 4):
			for off in [Vector2i(1,0), Vector2i(0,1)]:
				var a := p.water_table(cx, cz)
				var b := p.water_table(cx + off.x, cz + off.y)
				assert_lte(absf(a - b), p.STOREY_HEIGHT + 0.001,
					"water table steps by <= 1 storey between neighbours")
```

- [ ] **Step 2 — Run, expect FAIL** (`set_water_table_override`/`is_water_cell`/`water_surface`/`water_table` undefined).

- [ ] **Step 3 — Implement.** In `HeightfieldPlan.gd`:
  - Add `var _water_table_override: Callable = Callable()` and `func set_water_table_override(fn: Callable) -> void`.
  - Add `func water_table_raw(cx, cz) -> float`: if override valid, call it; else derive a water-surface elevation from the river/lake noise. Starting formula: sample `Helper._is_water_raw`-style wetness as a continuous value `w01 = wetness01(pos)` (extract a `Helper.water_wetness01(pos, seed) -> float` returning the pre-threshold `wetness` from `_is_water_raw`); where `w01 > 0` the table elevation = the local *rim* height (`raw_height` of the cell) so water fills to the surrounding land; where `w01 <= 0` return a sentinel `-INF` (no water). (Carving: also lower `_height01` in wet regions so basins exist — see note.)
  - Add `func water_table(cx, cz) -> int`/`float`: quantize `water_table_raw` to the storey grid (`_round_mode(raw/STOREY_HEIGHT)`) and apply a trickle-down `clamp_field`-style clamp over a small window so adjacent water surfaces differ by ≤1 storey (reuse the static `clamp_field` on a window of water-table targets).
  - Add `func water_surface(cx, cz) -> float`: `water_table(cx,cz) * STOREY_HEIGHT` (the quantized water-plane Y), or `water_table_raw` if continuous water surfaces are preferred — pick the quantized form to match terraced land.
  - Add `func is_water_cell(cx, cz) -> bool`: `water_table_raw(cx,cz) > -1e8 and water_surface(cx,cz) > surface_height(cx,cz) + 1e-4`.
  - **Carving note:** to make natural basins, modify `_height01` to subtract a carve term where wetness is high (e.g. `h -= clampf(w01, 0, 1) * CARVE_DEPTH`), so rivers cut channels the table then fills. Add `const WATER_CARVE_DEPTH := STOREY_HEIGHT` as a starting value (tuned in Task 6). Guard: carving must not push the spawn area underwater (the radial falloff already flattens spawn).

- [ ] **Step 4 — Run, expect PASS** (`--import` first for the new test file).

- [ ] **Step 5 — Commit.** `git add scripts/terrain/heightfield/HeightfieldPlan.gd scripts/core/Helper.gd tests/test_water_table.gd && git commit -m "feat(terrain): water-table field on the heightfield (FR-1)"`

---

## Task 2: `cell_descriptor` emits material + water-aware walls

A side is a wall when the neighbour *surface* (land height OR, if the neighbour is water, its water-surface) is lower than this cell. Walls facing water are bank walls; the cell itself may be water.

**Files:** Modify `HeightfieldVariant.gd`; Test `tests/test_water_descriptor.gd`.

- [ ] **Step 1 — Failing test.** Create `tests/test_water_descriptor.gd`:

```gdscript
extends GutTest
const V := preload("res://scripts/terrain/heightfield/HeightfieldVariant.gd")

func test_water_cell_descriptor() -> void:
	var d := V.cell_descriptor_v2(0.0, 0, 0, {}, {}, {}, true, 0.0)  # this cell IS water
	assert_eq(d["material"], "water")
	assert_eq(d["variant_tag"], "water")

func test_bank_edge_faces_water() -> void:
	# Land cell at height 4; "front" neighbour is water with surface 0 (lower).
	var cardinals := {"front": 0.0, "right": 4.0, "back": 4.0, "left": 4.0}
	var water_nbr := {"front": true, "right": false, "back": false, "left": false}
	var d := V.cell_descriptor_v2(4.0, 1, 0, cardinals, {}, water_nbr, false, 0.0)
	assert_eq(d["material"], "land")
	assert_true(String(d["variant_tag"]).begins_with("bank-"), "land facing lower water => bank edge")
	assert_eq(d["rotation_steps"], 0, "front-facing wall, no rotation")

func test_land_cliff_unchanged() -> void:
	# No water: front neighbour lower land by a storey => cliff-side (regression).
	var cardinals := {"front": 0.0, "right": 4.0, "back": 4.0, "left": 4.0}
	var none := {"front": false, "right": false, "back": false, "left": false}
	var d := V.cell_descriptor_v2(4.0, 1, 0, cardinals, {}, none, false, 0.0)
	assert_eq(d["variant_tag"], "cliff-side")
```

- [ ] **Step 2 — Run, expect FAIL.**

- [ ] **Step 3 — Implement `cell_descriptor_v2`** in `HeightfieldVariant.gd` (new function alongside the old, so existing callers/tests stay green until Task 3 swaps them):
  - Signature: `static func cell_descriptor_v2(h0, storey, level, cardinals: Dictionary, diagonals: Dictionary, water_neighbour: Dictionary, is_water: bool, water_surface: float) -> Dictionary`.
  - If `is_water`: return `{material:"water", variant_tag:"water", rotation_steps:0, origin_y: water_surface, drop_height: 0.0}`.
  - Else (land): compute the wall set with `missing_from_heights` using each neighbour's *effective surface* (the neighbour's land height, or its water-surface if `water_neighbour[c]`). For each wall side, record whether it faces water (`water_neighbour[c]`).
  - `variant_for_missing(missing)` → `(tag, rotation_steps)` (unchanged catalog).
  - Family/material: if ALL wall sides face water → `material:"land"`, `variant_tag:"bank-"+bare`, `drop_height` = land − water-surface. If some walls are land drops → keep the existing land family logic (cliff/level) and tag `"cliff-"/"level-"+bare`. (Mixed land+water walls on one tile: resolve in Task 3 by which dominates; start with "any water-facing wall on an otherwise-flat cell ⇒ bank".)
  - Keep the old `cell_descriptor` intact for now.

- [ ] **Step 4 — Run, expect PASS.**

- [ ] **Step 5 — Commit.** `git add scripts/terrain/heightfield/HeightfieldVariant.gd tests/test_water_descriptor.gd && git commit -m "feat(terrain): water-aware cell descriptor v2 (FR-1)"`

---

## Task 3: Region carries water; instantiator places water + bank tiles

**Files:** Modify `HeightfieldRegion.gd`, `HeightfieldPlan.compute_region`, `HeightfieldInstantiator.gd`; Test extend `tests/test_heightfield_region.gd` + `tests/test_heightfield_instantiator.gd`.

- [ ] **Step 1 — Failing test.** Add to `test_heightfield_instantiator.gd` a test that a water cell yields a `placement_for_cell` record with `variant_tag == "water"` at `origin_y == water_surface`, and a land cell adjacent to water yields a `bank-*` tag. Use `set_raw_height_override` + `set_water_table_override` to construct a deterministic basin.

- [ ] **Step 2 — Run, expect FAIL.**

- [ ] **Step 3 — Implement.**
  - `HeightfieldRegion`: store `_water_table` (Vector2i→float/int) and `_is_water` set; add `water_surface(cx,cz)` and `is_water_cell(cx,cz)`.
  - `HeightfieldPlan.compute_region`: also compute the water-table window (quantize + clamp) and the per-cell `is_water` flag, pass them to `HeightfieldRegion.new(...)`.
  - `HeightfieldInstantiator.placement_for_cell`: build the `water_neighbour` dict (per cardinal, `region.is_water_cell(nb)`), read `region.is_water_cell(cell)` + `region.water_surface(cell)`, and call `cell_descriptor_v2`. Use its `variant_tag`/`origin_y`/`yaw` for placement. (The understack/2-storey logic is land-only; skip it for water cells.)
  - `spawn_placement`: unchanged mechanism — `library.get_by_tags([tag])` now resolves `"water"` → the water module and `"bank-*"` → bank modules (Task 4 registers them by these tags).

- [ ] **Step 4 — Run, expect PASS.**

- [ ] **Step 5 — Commit.** `… -m "feat(terrain): place water + bank tiles from the descriptor (FR-1)"`

---

## Task 4: Register water/bank modules by descriptor tags; delete `BANK_VARIANT_TABLE` parallelism

**Files:** Modify `TerrainModuleDefinitions.gd`, `TerrainModuleLibrary.gd`.

- [ ] **Step 1.** Water module: tag the `WaterTile` module with the bare `"water"` tag the descriptor emits (so `get_by_tags(["water"])` resolves it). Bank modules: register the bank variants (reusing `cliff/%s.tscn`) under `"bank-"+bare` tags matching `cell_descriptor_v2` output (`bank-side`, `bank-corner`, …) — derived from the one canonical catalog, not a separate `BANK_VARIANT_TABLE`. Build bank tags by iterating `HeightfieldVariant.TAG_ORDER` (the single source), not a hand-kept table.
- [ ] **Step 2.** Delete `BANK_VARIANT_TABLE` and fold bank registration into a loop over `TAG_ORDER` (one source of variant shapes).
- [ ] **Step 3 — Verify** `test_heightfield_coverage` (every emittable tag, now incl. `water`/`bank-*`, has a module) passes; add water/bank coverage assertions. (Restore-scenes not needed — banks load from `cliff/`, already present.)
- [ ] **Step 4 — Commit.** `… -m "refactor(terrain): water/bank modules keyed by canonical descriptor tags (FR-1)"`

---

## Task 5: Delete `WaterRule` + the rule pipeline; swap descriptor in; shrink clear-radius

**Files:** Modify `TerrainGenerator.gd`, `Helper.gd`, `HeightfieldVariant.gd`; Delete `rules/WaterRule.gd`, `TerrainGenerationRule.gd`, `TerrainGenerationRuleLibrary.gd`; remove `tests/test_water_rule.gd`.

- [ ] **Step 1.** In `HeightfieldInstantiator`/`placement_for_cell`, replace the old `cell_descriptor` call with `cell_descriptor_v2` everywhere; delete the old `cell_descriptor`. Update `test_heightfield_variant` to the v2 signature (or rename v2 → `cell_descriptor`).
- [ ] **Step 2.** In `TerrainGenerator._drive_heightfield_structure` (~line 1052-1064): remove the `_run_rules_for_existing_piece(inst)` call for base-plane tiles and the rule-pipeline plumbing (`generation_rules`, `_run_rules_on_piece`, `_run_rules_for_existing_piece`, `_process_rule_rechecks`, `_apply_piece_updates_after_placement`) **iff** no remaining consumer (it's WaterRule-only). If FR-3 hasn't run yet and deco still uses a hook, leave only that hook.
- [ ] **Step 3.** Delete `scripts/terrain/rules/WaterRule.gd`, `TerrainGenerationRuleLibrary.gd`, `TerrainGenerationRule.gd`; `grep -rn "WaterRule\|generation_rules\|TerrainGenerationRule" scripts tests` → only intended removals remain. Delete `tests/test_water_rule.gd`.
- [ ] **Step 4.** `Helper.gd`: set `WATER_CLEAR_RADIUS`/`WATER_CLEAR_FADE` small (e.g. `24.0`/`24.0`) so water is visible near spawn but the spawn tile is dry; or remove the fade and instead force the spawn cell dry in `is_water_cell`.
- [ ] **Step 5 — Verify.** Full GUT suite green (with `test_water_rule` gone). `grep` confirms no dangling refs.
- [ ] **Step 6 — Commit.** `… -m "refactor(terrain): delete WaterRule; water/banks are field-driven (FR-1)"`

---

## Task 6: Visual verification + water-table tuning (iterative)

Inherently visual — no unit test pins "looks good"; the done-criteria are explicit.

- [ ] **Step 1 — Run the game** (use the project's run path / `mcp__godot__run_project` or the main scene) at a few seeds; screenshot terrain near spawn and travelling out.
- [ ] **Step 2 — Verify, tuning `WATER_CARVE_DEPTH` + the water-table formula + `WATER_*` scales until:**
  - Water is visible near spawn (clear-radius shrunk) and the spawn tile is dry/walkable.
  - Lakes pool in basins; rivers run in channels; **water appears at more than one elevation** (e.g. a raised basin holds a lake).
  - Shorelines have banks (walls facing the water), correctly oriented.
  - No water clinging to slopes, floating, or flooding the whole map.
- [ ] **Step 3 — Regression.** Full GUT suite green after tuning.
- [ ] **Step 4 — Commit.** `… -m "tune(terrain): water-table field for natural multi-elevation water (FR-1)"`

---

## Self-review notes
- Spec coverage: water-as-field/multi-elevation (T1,T2,T6), unified descriptor incl. banks (T2,T3), delete WaterRule + tables (T4,T5), shrink clear-radius (T5,T6). ✔
- Type consistency: `cell_descriptor_v2(h0, storey, level, cardinals, diagonals, water_neighbour, is_water, water_surface)`; `is_water_cell`, `water_surface`, `water_table` on Plan/Region. Used consistently T1–T5.
- Visual tasks (T6) carry explicit done-criteria, not fake code — correct for creative tuning.
