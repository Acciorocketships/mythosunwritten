# Constructive Maze — Slice 1b: House Heights, Stacked Claims, Skyline Trim, Readable Debug View

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Houses get realistic heights, upper streets can build above lower houses (tiers), unclaimed built mass above roofs is trimmed away, and the debug view becomes readable (visible path, saturated palette, legend).

**Architecture:** Stamp-pass changes only at the source level (no composition): a per-scale storey budget caps claim height; the claim occupancy map becomes column × band-interval so a column can host stacked claims from different street levels; a post-stamp skyline trim lowers unclaimed built mass. The debug view renders passages as visible corridor voxels with an always-on-top line and bakes a legend into every capture.

**Spec:** `docs/superpowers/specs/2026-08-20-constructive-maze-town-design.md` — Task 1 appends a "House heights, stacked claims, skyline trim" section recording these rules (approved in chat 2026-08-21).

## Global Constraints

- Same as slice 1 (plain lattice data, terrain immutable, streets immutable, determinism, TABS, named files only, carver 7/7 and constructive suite green).
- `WarrenMazeSourcePlan.MIN_HOUSE_BANDS` (4 bands = 2 storeys) remains the minimum house; storey budgets therefore start at 2.
- Skyline trim never touches: passage-hosting columns (their retained mass is tunnel/bridge structure), reservation cells, or any band inside a claim.

---

### Task 1: Storey budget, 3D claim occupancy, skyline trim

**Files:**
- Modify: `scripts/terrain/features/villages/fabric/WarrenMazeStampPass.gd`
- Modify: `scripts/terrain/features/villages/fabric/WarrenMazeSourcePlan.gd` (add `record_trim`, seal validation for trims)
- Modify: `docs/superpowers/specs/2026-08-20-constructive-maze-town-design.md` (append section)
- Test: `tests/test_warren_maze_constructive.gd`

**Interfaces:**
- `WarrenMazeStampPass.STOREY_BUDGET: Dictionary` — `{"compact": Vector2i(2, 3), "standard": Vector2i(2, 3), "large": Vector2i(2, 4), "grand": Vector2i(3, 4)}` (min, max storeys). Per claim the storey count is a seeded roll inside the range: `posmod(Helper._mix64(plan.world_seed ^ Helper._mix64(door_walk.x * 73856093 ^ door_walk.y * 19349663 ^ door_walk.z * 83492791)), max - min + 1) + min`, then `top = min(ceiling-derived top, floor + storeys * WarrenBuildingParcel.STOREY_BANDS)`; the existing MIN_HOUSE_BANDS floor and 1×1 clamp still apply.
- Claim occupancy: replace the 2D `claimed_columns: Dictionary[Vector2i → bool]` with `claimed_intervals: Dictionary[Vector2i → Array[Vector2i]]` (each `Vector2i(floor_band, top_band)` half-open). Reservation cells occupy `Vector2i(-INF-ish, +INF-ish)` (the whole column). `_footprint_available(footprint, floor, top)` = no overlapping interval on any column. Every placement/extension/merge site switches to the interval form; `_column_ceiling(plan, column, floor)` additionally stops at the floor of the lowest claim interval above `floor` in that column.
- Skyline trim (P4.5, called from `stamp()` after lineage grouping, before `derive_foundations`): for each massif column in sorted order — skip if it hosts any passage cell, or is a reservation cell; let `roof` = max claim top on the column (if any); if a claim exists and `effective_top > roof` → `plan.record_trim(column, roof)`; if NO claim exists → `shoulder` = max over 4-neighbours of their claim tops (after trimming, use pre-trim claim tops — deterministic: compute all targets first, then apply); if shoulder exists and `effective_top > shoulder` → `record_trim(column, shoulder)`; else (no claimed neighbour) → `record_trim(column, effective_base)` (unclaimed isolated mass is discarded to terrain, matching the old pipeline's `_discard_unassigned_mass`). Record outcomes in `plan.audit["trim_outcomes"]` (counts by kind).
- `WarrenMazeSourcePlan.record_trim(column: Vector2i, top_band: int) -> bool`: only lowers `top_band` (never raises), keeps the existing `floor_band`/`phase` if an edit exists else creates `{floor_band: effective_base, top_band, phase: &"trim"}`, marks `trimmed: true`; rejects (false + last_rejection) when sealed, when the column hosts a passage cell, or when `top_band < effective_base`. `seal()` validates every trimmed column's top ≥ the max top of any claim on that column (a trim may not cut into a house). Signature covers trims (the `e:` lines already serialize floor/top — add `:t` when trimmed).

- [ ] **Step 1: Failing tests** (add to the constructive test file):
  - `test_claims_respect_the_scale_storey_budget`: seeds 1,3,4,12 compact — every claim's `top_band - floor_band ≤ STOREY_BUDGET.compact.y * STOREY_BANDS` and `≥ MIN_HOUSE_BANDS`; at least one claim per seed is shorter than its column ceiling (proves the cap bites).
  - `test_upper_streets_stack_claims_above_lower_houses`: across seeds 1,3,4,12 compact, at least one column carries two claims with disjoint band intervals (tiers exist); no two claims on one column overlap.
  - `test_skyline_trim_removes_unclaimed_mass_above_roofs`: seed 4 compact sealed plan — for every claimed, non-passage, non-reservation column, `effective_top == max claim top`; for every unclaimed non-passage non-reservation column, `effective_top ≤ max(neighbour claim tops, effective_base)`; `trim_outcomes` non-empty; passage-hosting columns' `effective_top` unchanged vs the pre-trim (stop_after=&"stamp" before trim — expose via a `WarrenMazeStampPass.skyline_trim_enabled` static toggle defaulting true, or compare against the reserve-stage plan's tops for passage columns).
  - `test_seal_rejects_a_trim_that_cuts_into_a_house`: doctor a sealed-to-be plan with a trim below a claim top; seal must fail naming "trim".
- [ ] **Step 2: Red.**
- [ ] **Step 3: Implement** (stamp pass, source plan, spec section).
- [ ] **Step 4: Green** — all existing constructive tests must still pass (median-lineage ≥ 2, pencil clamp, translatability invariants, translator 1:1 and ownership floors — if stacking raises ownership, update the pinned floors UPWARD to the new corrected baselines minus guard and say so). Carver 7/7. Run `warren_maze_mode_sweep.gd --constructive` and paste the new per-seed table (parcels, stacked-column count, median lineage, ownership) into this plan under "Measured results".
- [ ] **Step 5: Commit** — `feat(villages): storey budgets, stacked claims, and skyline trim`.

---

### Task 2: Readable debug view

**Files:**
- Modify: `tests/harness/maze_source_review.gd`

**Requirements:**
- **Passages visible from any angle**: draw each passage cell as a translucent open-corridor voxel (CELL × `WarrenExcavation.HEADROOM_BANDS`·BAND × CELL, alpha ≈ 0.45, spine amber / alley ochre / market teal) AND the polyline with a `no_depth_test` material so it reads through solids; the spine line 2× the alley width.
- **Palette**: houses in one warm family — base hue per lineage drawn from a small fixed ramp of 8 saturated colours (not the pale golden-ratio walk), stacked claims on one column get the same hue at a different lightness per floor; reservations OPAQUE saturated (courtyard green, large-house orange, landmark purple, garden lime, market teal, skywalk blue) with a 0.05 m darker outline box; unclaimed retained solid as a faint translucent grey (alpha 0.18) — it is now rare after trim; foundations dark grey opaque; terrain green quads.
- **Legend baked into every capture**: a `CanvasLayer` with a `Label` (top-left, 22 px, dark backing panel) listing the colour → meaning table plus seed / scale / state / parcel count / stacked columns / ownership. Always on (drop the `--legend` flag's print-only behaviour; keep the flag as a no-op for compatibility).
- Keep the six-phase loop, filenames, index.json, and graceful failure handling.
- [ ] **Step 1: Implement.**
- [ ] **Step 2: Render** `--seeds 4,7,12 --phases all` into a scratch dir and verify by eye: path visible in iso, legend readable, houses read as 2–4 storey blocks with tiers, reservations distinct.
- [ ] **Step 3: Commit** — `feat(villages): readable constructive debug view`.
