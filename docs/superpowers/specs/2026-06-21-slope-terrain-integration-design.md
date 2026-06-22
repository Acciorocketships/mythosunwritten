# Slope ↔ Terrain Integration — Design Spec

**Date:** 2026-06-21
**Status:** Approved (design); executing
**Goal branch:** new branch off `feat/heightfield-terrain` (their correct corner tiling) carrying the slope geometry.

## Problem

Two agents independently solved overlapping terrain-corner problems on diverged branches:
- **`feat/heightfield-terrain`** (other agent): correct heightfield corner tiling — `_understack_corners` spawns an inner-corner tile one tier below each convex corner whose diagonal drops two tiers (fills the "missing interior corner" pits); plus terrace/clamp fixes. Cliffs are **sheer** (loader → `res://terrain/scenes/%s.tscn`).
- **`feat/sloped-cliffs`** (this work): full slope geometry (50% gentler profiles, convex-slab collision, 2×2 component grid, baked slope scenes, loader → `slope/`) + a separate stacked-corner approach (S1–S7: mating C1 profiles + `_stacked_remap` detection) built on the **old** heightfield (pre their fixes), so it still shows the corner defects.

The user wants: **their correct heightfield + my slope geometry.**

## Decisions (confirmed with user)

| Topic | Decision |
| --- | --- |
| Direction | Base on `feat/heightfield-terrain`; re-apply slope geometry on top. |
| Corner geometry | **Keep my mating C1 geometry**: their `understacks` detection drives my stacked scenes. |
| My `_stacked_remap` (S6) | **Drop** — their `understacks` is the equivalent, better-integrated detection. |
| Timing | **Execute now** against current `feat/heightfield-terrain` HEAD (accept staleness risk if they keep committing). |

## Architecture: their detection + my geometry

Their `_understack_corners` already identifies the multi-storey diagonal corner (the cell is a convex corner sitting one tier above a 2-tier diagonal pit). That single detection drives **both** mating halves:

1. **The cell's own corner** (the convex top-half): when `understacks` is non-empty and the cell's variant is `cliff-corner`, spawn my **`CliffCornerStacked`** (mating convex top) instead of the plain corner — i.e. remap `cliff-corner → cliff-corner-stacked`. This replaces my S6 `_stacked_remap` with their detection.
2. **The understacked tile** (the concave bottom-half): `_add_understack_corners` spawns my **`CliffInCornerStacked`** (mating concave bottom) instead of the plain `_INNER_CORNER_SCENE`.

Because the two halves come from one C1 S (my S1 work), the 2-storey corner is continuous.

## Changes

**Port (new files, copied from `feat/sloped-cliffs` final state — low conflict, mostly new):**
- `scripts/terrain/tools/SlopeProfile.gd` (mine: 50% band + mating stacked profiles — overwrites their old 25% copy)
- `scripts/terrain/tools/{SlopeMeshGenerator,SlopeVariantLayout,SlopeAtlas,bake_slope_cliffs}.gd`
- `terrain/gltf/slope/*` (6 components) and `terrain/scenes/slope/*` (14 + 2 stacked)
- `tests/test_slope_*.gd` and `tests/test_slope_tile_continuity.gd`

**Edit (shared files, manual integration):**
- `scripts/terrain/TerrainModuleDefinitions.gd`: loader `load_cliff_variant` → `res://terrain/scenes/slope/%s.tscn`; keep stacked-variant registration (`cliff-corner-stacked`, `cliff-inner-corner-stacked`).
- `scripts/terrain/heightfield/HeightfieldInstantiator.gd` (THEIRS, the base): wire the two composition points above. Do **not** add my S6 `_stacked_remap`. Point `_INNER_CORNER_SCENE` (and keep `_LEVEL_INNER_CORNER_SCENE` as-is — levels are out of scope/sheer) at the sloped mating inner corner; add the `understacks`-non-empty → `cliff-corner-stacked` remap in `placement_for_cell`.

**Do NOT carry:** my S6 commit's `_stacked_remap`/`_open_diagonal`.

## Testing
- Re-bake slope scenes; run slope + heightfield suites green (baseline-aware).
- `test_slope_tile_continuity` should improve markedly (their understacks fill the diagonal pits).
- In-world render: confirm the screenshot defects are gone (no missing-inner-corner holes, no corner-in-the-middle-of-nowhere) AND cliffs are sloped + staircase corners continuous.

## Execution
- Isolated worktree off `feat/heightfield-terrain` (current HEAD), new branch.
- Done directly (conflict-resolution judgment), not subagent-delegated.

## Risk
- Target branch is actively changing — if it moves, re-sync the port. Accepted by user.
