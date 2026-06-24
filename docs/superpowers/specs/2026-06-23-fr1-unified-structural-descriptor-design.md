# FR-1: Unify the structural descriptor + fold water into the field

**Date:** 2026-06-23
**Status:** Design — part 1 of 3 in the field-driven terrain rewrite
(**FR-1 unify descriptor + water** → FR-2 unify mesh layer → FR-3 field-driven
decoration scatter + delete socket engine).

## Why

The terrain system runs two parallel variant systems for the same idea — "which
sides of a tile are walls, given which neighbours are lower." The heightfield
computes it from the height field (`HeightfieldVariant`); `WaterRule` re-derives
it from a *separate* water field at runtime, with its own duplicate
`CANONICAL_MISSING_BY_TAG`, `BANK_TAG_ORDER`, and `_rotation_steps_to_align_canonical`.
Banks literally reuse the cliff scenes (`load_bank_variant` loads `cliff/%s.tscn`),
and `HeightfieldVariant.cell_descriptor` already picks family by drop magnitude.
So level, cliff, and bank are one thing — "a surface that drops to a neighbour" —
differing only by **drop height** and **what's at the bottom** (land vs water).

FR-1 makes that explicit: one cell-descriptor and one variant catalog cover
ground/level/cliff/water/bank, with water folded into the height field as a
material so banks and water fall out of the *same* placement pass. This deletes
`WaterRule` entirely and the duplicate variant machinery.

## Goal

- Fold water into `HeightfieldPlan` as part of the field, so a cell's descriptor
  carries `material ∈ {land, water}` and water's surface/floor heights. Water is
  **multi-elevation** — it exists wherever a deterministic *water-table* field
  sits above the land surface, at any quantized level (valley pools, plateau
  lakes), not only at y≈0. ("Water only at the base plane" was itself a special
  case; the general rule removes it.)
- Generalize `HeightfieldVariant.cell_descriptor` to emit a uniform descriptor —
  `(surface_height, material, edge_bitmask, corner_depths, drop_height)` — instead
  of a `(family, variant_tag)` string pair. "level vs cliff" becomes the
  `drop_height` parameter; "bank" becomes "a land cell whose edge faces a water
  cell, dropping to the water floor."
- Collapse the parallel variant tables (`LEVEL_VARIANT_TABLE`, `CLIFF_VARIANT_TABLE`,
  `BANK_VARIANT_TABLE`, `WaterRule.CANONICAL_MISSING_BY_TAG`) into the **one**
  canonical catalog of ~15 rotational wall-subset orbits already in
  `HeightfieldVariant.CANONICAL_MISSING_BY_TAG`.
- **Delete `WaterRule`** (rules/WaterRule.gd, ~490 lines) and its consumers in the
  rule pipeline; banks/water are placed by `HeightfieldInstantiator.place_region`
  in the same pass as cliffs.

**Scope boundary:** FR-1 unifies the *selection rule and descriptor*, NOT the mesh
generation. It still selects from the existing authored/generated meshes via a
single `(canonical_shape, drop_height, material) → scene` map. Replacing authored
scenes with generated meshes is FR-2.

## The uniform descriptor

`cell_descriptor(plan, cell)` returns, per cell, purely from the field:
- `surface_height: float` — walkable Y (water: the water-plane Y; its floor sits
  below).
- `material: int` — `LAND` or `WATER` (from the folded water field).
- `edge_bitmask: int` — 8 bits: for each of 4 cardinals, "neighbour is lower"
  (a wall) ; for each of 4 diagonals, "inner-corner notch" (lower AND both
  adjoining cardinals connected) — exactly `missing_from_heights` today.
- `drop_height: float` — the step magnitude to the lower neighbours (≈0.5 → fine
  step, ≈4 → storey), driving which mesh profile/parameter is used.
- `corner_depths` — per-corner drop in storeys, for the 2-storey diagonal ramp
  case (the legitimately-hard understack geometry); a richer bitmask, not bespoke
  instantiator code.

From this, the **one** variant rule `variant_for(edge_bitmask) → (canonical_shape,
rotation_steps)` (the existing `variant_for_missing` + `_rotation_steps_to_align`)
chooses the shape; the family is no longer in the tag — it is the `drop_height` +
`material` parameters carried alongside.

## Water as a field (multi-elevation)

The general rule, with no y=0 special case:

- **Land surface** `H(cell)` — the heightfield's quantized terrain, computed and
  trickle-down-clamped exactly as today (water does not feed the land clamp;
  material-overlay, not competing height).
- **Water table** `T(cell)` — a deterministic, smoothly-varying field giving the
  water-*surface* elevation in each region, quantized to the same step grid so
  water surfaces align with terraces. Derived from the existing river/lake
  footprint noise (`Helper.is_water`'s `_is_water_raw` river+lake fields),
  reinterpreted as a per-region water level rather than a y=0 boolean.
- **A cell is water iff `T(cell) > H(cell)`** — the table is above the land, so
  the land there is submerged. The water surface renders at `T(cell)`; the floor
  is `H(cell)`; depth = `T − H`. This yields water at ANY elevation: terrain that
  dips below the local table becomes a valley river/pool; a basin whose floor sits
  below a high regional table becomes a plateau lake.
- **A bank is not a special tile type**: it is a *land* cell adjacent to a water
  cell whose land surface is above the water table — the shore wall drops from the
  land down to the water surface. The same `cell_descriptor` + `variant_for` pass
  that produces cliff/level edges produces bank edges (drop = land − water
  surface, material = water-facing) — no rule, no second pass.
- The "field-water position not yet generated" lookahead `WaterRule` needed
  (`_field_water_near`) disappears: the descriptor reads `T` and `H` (pure fields),
  so it is correct before any tile exists.
- **Spawn clear-radius:** shrink/remove `WATER_CLEAR_RADIUS`/`_FADE` so water is
  visible near the start (the user wants to see/verify it). Keep just enough of a
  guard that the spawn tile itself isn't underwater (e.g. ensure `H(spawn) ≥
  T(spawn)` at the origin cell), or drop it entirely and let spawn pick a dry
  cell.

**Tuning to resolve in planning:** the exact `T` formulation (amplitude, how
river channels vs lake basins map to table elevation, how `T` correlates with the
macro-density field so lakes sit in lowlands and rivers carve channels) and
whether water surfaces snap to storey or level granularity. The *model* above is
fixed; the field tuning is a knob.

## What gets deleted

- `scripts/terrain/rules/WaterRule.gd` (entire file) and its registration in
  `TerrainGenerationRuleLibrary`.
- `BANK_VARIANT_TABLE` and `load_bank_variant`/`load_water_and_bank_modules` as a
  separate path (banks/water become descriptor outputs).
- `WaterRule.CANONICAL_MISSING_BY_TAG`, `BANK_TAG_ORDER`, the two-ring
  reclassification, `_structures_above`, `_create_water_replacement`,
  `_piece_counts_as_water`.
- The `TerrainGenerator` rule-pipeline hooks that exist only to run WaterRule
  after placement (`_run_rules_*`, `_process_rule_rechecks`,
  `_apply_piece_updates_after_placement`) — to the extent they have no other
  consumer. (If FR-1 lands before FR-3, leave any hook still used by the deco
  engine; FR-3 removes the rest.)

## What is kept / extended

- `HeightfieldPlan` (+ the water field), `HeightfieldVariant` (the one catalog +
  `cell_descriptor` generalized), `HeightfieldInstantiator.place_region`/
  `spawn_placement`/`evict_placed_outside`, `HeightfieldFacing`.
- The authored/generated meshes (cliff `slope/`, level `level/`, the sheer
  `cliff/` scenes banks reuse) — selected via the unified `(shape, drop, material)`
  map until FR-2 replaces them with generated meshes.
- `TerrainIndex` for gameplay/eviction queries.

## Risks

- **Multi-elevation water is a new feature, not just a refactor.** The water-table
  field `T` is new; tuning it so lakes/rivers look natural (not water clinging to
  hillsides or filling implausible spots) is the main creative risk. Mitigate:
  correlate `T` with the macro-density/lowland field so water gravitates to basins
  and channels; iterate visually with the clear-radius removed so it's on screen.
- **Bank orientation / rotation parity.** `WaterRule` had careful
  canonical-rotation alignment; the unified `variant_for` must produce the wall
  oriented to face the water. Guard with a test asserting bank shape+rotation for
  representative land/water neighbourhoods (porting `test_water_rule`'s
  orientation cases to the descriptor).
- **Land terracing unaffected.** Water is a material overlay (`T` vs `H`), not a
  competing height in the land clamp — so land terraces exactly as today. (This is
  the resolved design choice, not an open question.)
- **Waterfalls / adjacent water at different tables.** Two adjacent water regions
  at different table heights, or water meeting a multi-storey cliff, can produce a
  water-on-water step or a tall submerged wall. Decide in planning whether to clamp
  `T` between neighbours (smooth shorelines) or allow stepped water; default: clamp
  `T` with the same ≤1-step trickle-down so water surfaces terrace like land.
- **Eviction/idempotence of water tiles.** WaterRule-swapped tiles previously
  escaped the placed-set (a known minor leak). Field-driven water tiles are placed
  by `place_region` and evicted normally — this *fixes* that leak.

## Testing / verification

- Replace `tests/test_water_rule.gd` with `tests/test_water_descriptor.gd`:
  for representative land/water neighbourhoods, assert `cell_descriptor` yields a
  bank edge with the correct shape + rotation facing the water, and a water tile
  for water cells. Port the meaningful bank-variant orientation cases.
- Extend `test_heightfield_variant` / `test_heightfield_coverage` for the unified
  descriptor (every variant still has a mesh; water/bank cells covered).
- New `tests/test_water_table.gd`: `T > H ⇒ water`, water surface at `T`, depth
  `T − H`; a basin below a high table becomes a lake; the `T` trickle-down clamp
  keeps adjacent water surfaces within one step.
- Full GUT suite green (with `test_water_rule` removed/replaced).
- **Visual (primary, since water is new on-screen):** with the clear-radius
  removed, run the game and confirm water appears near spawn; shorelines have
  banks; lakes pool in basins and rivers run in channels; water at a raised
  elevation (a plateau basin) renders correctly; no water clinging to slopes or
  floating. Iterate the `T` tuning here.

## Dependencies

Precedes FR-3 (deleting `WaterRule` removes one of the two socket-engine
consumers, so FR-3 can then delete the engine). FR-2 builds on FR-1's unified
descriptor (it generates the meshes the descriptor selects).
