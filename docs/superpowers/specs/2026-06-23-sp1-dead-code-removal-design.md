# SP-1: Reclaim dead heightfield-migration code

**Date:** 2026-06-23
**Status:** Design — part 1 of a 3-sub-project terrain simplification (SP-1 dead code → SP-2 metadata-ize special-cases → SP-3 decompose god-object).

## Background

The terrain structural generation was migrated to be driven solely by the
heightfield (`heightfield/HeightfieldInstantiator.place_region` +
`HeightfieldVariant` + `HeightfieldPlan`). The old emergent socket-expansion
path for *structural* tiles (ground laterals, level/cliff lateral spread,
level/cliff/ground topcenter seeding) is now suppressed to a no-op, gated by a
single function `TerrainGenerator._is_structural_socket()`.

**Crucial correction (from the deletion-map trace):** the socket-expansion
engine is NOT dead. It still places every *decoration* (grass/rock/bush/tree,
hills, hill-stacking) and drives water/bank lateral expansion. Only the
*structural* half is suppressed. So this sub-project deletes only what is
provably dead; it does not touch the live decoration/water engine. The broad
"no special cases / no tags in core" goal is SP-2, not SP-1.

## Goal

Delete everything proven dead by the trace, so the code honestly reflects what
runs — guarded by a characterization-test safety net that also serves SP-2/SP-3.
**SP-1 changes zero runtime behavior.**

## The three live paths SP-1 must not break

- **(A) Heightfield structural placement** — `_drive_heightfield_structure` →
  `HeightfieldInstantiator.place_region`/`spawn_placement`/`evict_placed_outside`.
- **(B) Decoration + water queue** — `add_piece_to_queue` → `_process_socket` →
  `_sample_socket_size` → `_resolve_placement_context` → `_try_place_with_rules`.
  Places grass/rock/bush/tree/hills (incl. hill-stacking via `topcenter`) and
  water/bank lateral expansion. Uses `get_adjacent_from_size` + the test-piece
  library + the fill-probability curves for foliage density/suppression.
- **(C) WaterRule** — swaps placed ground tiles to water/bank variants.

## Phases

### Phase 1 — Characterization safety net (new tests, no code change)

Build on the existing `init_for_test` / `tests/test_heightfield_cutover.gd`
harness. Lock the surviving behavior so later deletions are provably safe and so
SP-2/SP-3 inherit the net. Tests to add (file: `tests/test_terrain_decoration.gd`
unless an existing file fits):

1. **Decoration lands on a surface** — drive a ground tile, run `load_terrain`
   for N frames, assert ≥1 displaceable piece (grass/rock/bush/tree) is placed
   on its top surface.
2. **Hill-stacking** — an `8x8x2` hill seeds a smaller hill from its `topcenter`.
3. **Orphan sweep** — place a ground tile with a hill on it, `remove_piece` the
   ground, run `_purge_orphaned_stacks`, assert the orphaned hill is removed.
4. **Water/bank expansion** — a ground tile adjacent to a water-field cell
   yields a bank tile (extends the existing
   `test_heightfield_ground_becomes_water_in_water_field`).
5. **Cliff-core foliage suppression** — at a high macro-density (core) position,
   ground foliage sockets are suppressed (no displaceable placed).
6. **Heightfield coverage + eviction** — a multi-storey region: place → evict →
   return, asserting no orphaned cliff tiles and no double-placement (extends
   the existing cutover/coverage tests).

If any surviving-path behavior is too integration-heavy to assert
deterministically, assert the nearest deterministic proxy (e.g. that the
relevant socket is enqueued / a candidate module list is non-empty) and note it.

### Phase 2 — Delete zero-caller dead code (guaranteed safe)

Verified to have zero live callers by the trace:

1. `TerrainGenerator.load_start_tile()` — delete the function (no callers; the
   heightfield is the sole initial source, asserted by
   `test_no_start_tile_when_heightfield_on`).
2. `TerrainGenerator._collect_stacked_above()` and its cascade in `add_piece`'s
   `replace_existing` block (the stacked-set collection + the second removal
   loop). Keep the first loop that removes directly-overlapping pieces. The
   cascade is unreachable because only cliff tiles set `replace_existing=true`
   and cliffs are never placed via path B; `HeightfieldInstantiator` bypasses
   `add_piece`.
3. `TerrainGenerator._has_valid_stack_support()` and the `level-stack` /
   `cliff-stack` branches in `_purge_orphaned_stacks` that are its only callers.
   **Keep** the `_support_sweep_pieces` + `_has_surface_support` hill sweep that
   follows (hills placed via path B can be orphaned when the heightfield evicts
   their base — that sweep is the only cascade removal).
4. `TerrainModuleDefinitions.create_24x24x4_test_piece()` and its
   `terrain_modules.append(...)` registration in `TerrainModuleLibrary.load_test_pieces`
   (the `24x24x4` size only exists on suppressed structural sockets and is never
   sampled at runtime; no test instantiates it).

### Phase 3 — Remove dead structural-seed module data (test-guarded)

Delete the suppressed structural-seed *data* so the module definitions reflect
only what is live:

- The `topcenter` SEED size/tag distributions on ground/level/cliff modules
  (structural → suppressed; `_sample_socket_size`/`get_combined_distribution`
  never read them).
- The level/cliff lateral (`front/back/left/right`) `socket_required` /
  `socket_tag_prob` (structural laterals are never enqueued; geometry prevents
  foliage adjacency from reading them).

**Keep (live — do NOT remove):**
- Ground cardinal `socket_required` (`["ground","side"]`) and `socket_tag_prob`
  (`{"ground-plain":1.0}`) — read by `get_required_tags`/`get_combined_distribution`
  during water/bank lateral expansion (path B).
- All water/bank socket data.
- The `socket_suppressed_by` foliage-suppression entries and the `topcenter`
  `socket_fill_prob` value they are derived from (the suppressor prob is baked
  at module-creation time from `topcenter_fill_prob`; removing the seed
  size/tag dicts must not change that value).

**Guard:** Phase-1 tests (esp. #1, #5, #4) must stay green after each data
removal. **If a characterization test breaks on any item, that item is not dead**
— revert that specific removal and record it as an SP-2 follow-up rather than
forcing it. Do Phase 3 last, one module-family at a time, re-running the suite
between removals.

### Phase 4 — Stale comments

Remove the 8 comments referencing the deleted `CliffEdgeRule` / `LevelEdgeRule`
/ `ClusterFillRule`:
`TerrainGenerationRuleLibrary.gd:10`, `rules/WaterRule.gd:12`,
`TerrainModuleDefinitions.gd:457`, `:673`, `:682`,
`TerrainGenerator.gd:935`, `:1132`, `TerrainSpawnConfig.gd:94`.
Where a comment explains live behavior but merely *names* a dead rule, rewrite it
to describe the behavior without the dead name rather than deleting outright.

## Non-goals (SP-1)

No metadata redesign, no removal of live tag-special-cases, no file
decomposition, no placement-mechanic change (the test-piece WFC simplification
is SP-3). `_is_structural_socket` and the fill-probability curves stay — they are
live.

## Testing / verification

- New Phase-1 characterization tests pass before Phase 2 begins and after every
  subsequent deletion.
- Full GUT suite green **with the deleted Cliff*.tscn scenes restored** (the
  working tree's pre-existing scene deletions cause unrelated failures; the
  baseline with scenes present is 188/188). Re-delete the scenes afterward to
  preserve the user's working state.
- Per-file isolated runs for the touched suites
  (`test_heightfield_cutover`, `test_biomes`, `test_water_rule`,
  `test_terrain_module_library`, the new decoration test).

## Risks

- **Phase 3 module-data surgery** is the only behavior-risk; mitigated by doing
  it last, test-guarded, one family at a time, with revert-on-break.
- **Characterization coverage gaps:** the decoration loop is hard to assert
  deterministically; Phase 1 uses the deterministic-proxy fallback where needed,
  accepting that some behavior is locked only loosely. This is acceptable because
  Phase 2 deletions are zero-caller (safe regardless) and Phase 3 is reverted on
  any break.
