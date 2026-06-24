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

- Fold `Helper.is_water` into `HeightfieldPlan` as part of the field, so a cell's
  descriptor carries `material ∈ {land, water}` and water's surface/floor heights.
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

## Water as a field

- Add water to `HeightfieldPlan`: a deterministic `material(cell)` from the same
  `Helper.is_water` field already used by `WaterRule`. Water cells get a
  surface_height at the water plane and a floor below; land cells keep their
  quantized surface.
- A **bank** is then not a special tile type: it is a *land* cell whose
  `edge_bitmask` faces a `WATER` neighbour, with `drop_height` = the depth to the
  water floor and a water-facing material on the wall. The same `cell_descriptor`
  + `variant_for` pass that produces cliff edges produces bank edges — no rule,
  no second pass.
- The "field-water position not yet generated" lookahead that `WaterRule` needed
  (`_field_water_near`) disappears: the descriptor reads the field, not placed
  tiles, so it is correct before any tile exists.

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

- **River shape / water gameplay must be preserved.** Folding `is_water` into the
  plan must reproduce the same river footprints. Mitigate: keep the exact
  `Helper.is_water` field; only change *who consumes it* (the descriptor instead
  of a post-pass rule).
- **Bank orientation / rotation parity.** `WaterRule` had careful
  canonical-rotation alignment; the unified `variant_for` must produce the same
  wall orientation facing water. Guard with a test mirroring `test_water_rule`'s
  bank-orientation cases against the new descriptor.
- **Trickle-down clamp vs water.** Decide whether water depth participates in the
  ≤1-step clamp (it should not distort land terracing). Resolve in planning;
  default: water is a material overlay on the land field, not a competing height.
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
- Full GUT suite green (with `test_water_rule` removed/replaced).
- **Visual:** run the game at a seed with rivers; confirm shorelines, banks, and
  water look the same as before (screenshot before/after).

## Dependencies

Precedes FR-3 (deleting `WaterRule` removes one of the two socket-engine
consumers, so FR-3 can then delete the engine). FR-2 builds on FR-1's unified
descriptor (it generates the meshes the descriptor selects).
