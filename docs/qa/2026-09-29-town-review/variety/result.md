# September 29 town review — stream "variety" (photo 11, Town B)

Owner (photo 11, Town B = city 1998423929946073270 compact, world (216,480),
seed 2697992464): "from a distance, it looks like a bunch of the same roof at
the same level, facing in the same direction"; asks for varied heights and
roof directions, and for adjacent buildings to merge into bigger structures.

## What was wrong (measured)

New metric `tests/fixtures/roofline_variety.gd` (per kit-built town, house
masses only): ridge-axis mix, gable- vs eave-fronted houses, touching house
pairs, *twins* (touching pairs whose principal wings are side-by-side copies:
same ridge axis, eave band and depth, offset across the ridge — the sawtooth
row of identical gables), same-ridge-height pairs, compound houses (2+ roof
wings). Corpus harness `tests/harness/suntail/roofline_variety_survey.gd`
(photo towns + seeds 1-6 compact/standard + 1-3 large, 17 towns).

Baseline (71398f7c): 74% of all principal ridges ran along local X (minority
axis share 0.26; Town B 0.19, Town A 0.13), 24% of touching house pairs were
twin gables (Town B 8/43, Town A 4/10), 52% of touching pairs had ridges within
half a storey, only 2% of houses had more than one roof wing.

## Root causes

1. **Planner lots are tiny and built one by one.** A warren "house" is one
   lineage on a one-macro-cell (2x2 module) or 2x4 lot; `KitVillageBuildings`
   designed each lot as its own building, so a row of lots became a row of
   identical little gabled boxes. The kit ignores the planner's ridge axis;
   uniformity came from the kit.
2. **Fixed square tie-break.** `BuildingDesigner._assign_roofs` chose
   `axis = 0 if rect.size.x >= rect.size.y` — every square (2x2) crown, i.e. most
   houses, ran its ridge along X. Hence "facing in the same direction".
3. (Consequence) a deep merged crown whose two-storey-tall roof would enter a
   neighbour's reserved volume fell back to a flat railed deck.

## Fix (kit layer only; planner/mass-field files untouched)

* `KitVillageBuildings.merge_houses` (runs after balcony doors are opened):
  neighbouring lots merge into one compound building by a seeded choice per
  shared wall. Eligible lots: whole storeys on their own base, same storey
  phase, grounds at most one storey apart, sharing at least one full wall
  module of one storey. Stacked one-storey lineages always merge (they are one
  tower). Pairs whose union is one rectangle (the twin-gable configuration)
  always merge and go first, longest shared wall first; other contacts (L/T)
  merge with chance 0.5. Caps: 24 modules, 8 across. A lot touching a building
  that cannot merge (bridge-house on nothing, landmark, split-level room) keeps
  its identity. Occupancy, doors (all kept), bearing and grade remain planner
  facts; only the kit's building identity (walls, roofs, colour) changes.
* Compound roofing: each member's own top is roofed (`storey.roofed`) unless
  another member stands directly on it; crowns under the same lot's upper
  storey keep the existing terrace rule. Members standing on higher ground get
  `storey.grounded` cells (footing course, no soffit/floor beam; the assembler
  honours it). If the whole-crown packing leaves unabsorbable slivers, the
  members' own crowns are packed instead (`crown_parts`).
* `_natural_axis` / `_square_axis`: square crowns choose gable- or eave-to-street
  per house (seeded 50/50 on the door face, `GABLE_FRONT_SHARE`).
* `_double_pile`: a deep crown whose tall roof does not fit becomes parallel
  two-module piles, ridges parallel to the street facade, before falling back
  to a flat terrace.

## Results

Corpus (17 towns), baseline -> after:

| metric | before | after |
|---|---|---|
| minority ridge-axis share (mean per town) | 0.26 | 0.45 |
| twin share of touching pairs | 0.24 (110/467) | 0.15 (54/358) |
| mean longest twin run | 3.06 | 2.00 |
| touching pairs with same ridge height | 0.52 | 0.41 |
| compound houses (2+ wings) | 2% (13) | 20% (99) |
| gable-fronted share | 0.55 | 0.45 |

Town B: minority 0.19 -> 0.50, twins 8/43 -> 1/24, compound 1 -> 7.
Town A: minority 0.13 -> 0.44, twins 4/10 -> 0/6, compound 0 -> 2.

Roof invariants (`roof_defect_survey`, 50 towns): tiny 63 -> 63, gable holes
1 -> 1 (pre-existing, 12:standard), open_exposed 0, eaves_cut 0,
air_unsupported 0. `air_roofs` (roofs sheltering free air, all on posts)
175 -> 284: more one-module roofed lanes where merged ranges abut collinearly
(KitRoofJunctions' existing rule) — supported, but more porch posts.

## Evidence (JPGs on disk only, this directory)

* `townB_p11near_before.jpg` / `townB_p11near_after.jpg` (photo-11 direction,
  closer): the front row of five identical gables becomes an eave-fronted
  range, a gable and a stepped L; `cmpB_p11near.jpg` stacks both.
  `townB_p11_*` is the solved ReviewCam eye (farther than the tactical
  photo camera; same direction).
* `cmpB_orbit0..3.jpg`, `cmpB_top.jpg`, `townB_orbit0/2_*`: the back row of
  five parallel gables becomes two side-gabled houses; orbit 2's sea of
  same-facing gables becomes long side-gabled ranges mixed with gables.
* `cmpc_<town>_<view>.jpg` (top = before, bottom = after) for Town A
  (1260018864828801968 compact), 3 standard, 7 standard, 4 large, 2 compact.
  2 compact: a large flat plank deck is now a pile roof.

## Tests

* New `tests/test_september29_roofline_variety.gd` (6 tests): square crowns mix
  gable/eave fronts; three 4x2 lots become one 4x6 range with one roof; stepped
  compound roofs both parts (no terrace); a lot bearing a bridge-house keeps
  its identity; photo towns (minority > 0.35, twins < 10% of pairs, compound >1,
  roof audit clean); corpus of six towns (twin share < 0.16, minority > 0.38).
  Baseline: the three metric tests fail (0/40 gable-fronted; Town B minority
  0.19, twins 0.19; corpus twins 0.21, minority 0.28); the merge tests do not
  parse (no `merge_houses`). After: 6/6 pass.
* Focused files, baseline vs after, all identical pass counts:
  test_building_kit 8/8, test_kit_roof_junctions 8/8, test_september27_roofs
  5/5, test_september27_town_details 4/4, test_town_architecture 11/11,
  test_town_canopies 2/2, test_town_closures 4/4, test_town_court_enclosure 2/2,
  test_town_depth 4/4.

## Open

* Storey-count variety is still the planner's (massif height field; the
  "edges" stream steps the perimeter down). A storey-and-a-half (top storey
  inside the roof) variant was prototyped and dropped: only 5 houses in 7
  towns qualified (most tops touch a neighbour whose party wall would open).
  Ridge-height variety here comes from merged ranges (4-deep roofs are a storey
  taller) and stepped compounds.
* Residual twins (15%) are mostly at merge-cap boundaries and one-storey
  terrace lots (maze_back) touching a lot that bears another lineage.
* Suntail has one roof pitch and gables only: no hips or pitch variety.
* Long collinear ranges across compounds (KitRoofJunctions' merge) can reach
  12 modules; a long uniform ridge may want a break (ridge step or cross gable)
  in a later pass.

## Integration follow-up (merged with towns-review-2026-09-29 at bc485052)

* Masonry jog (test_september29_town_materials, Town A `kit.retained/k0074 |
  kit.spatial.maze_back.03/k0011`): a merged range ended against a retained
  terrace course; the compound rolled a stone ground storey whose deep panel
  ran on the course's flush wall line. Before merging, the lot at that end
  happened to roll timber. The materials rule (no stone ground storey on the
  retained podium) now also covers ground storeys beside the podium (a
  podium cell cardinally adjacent at the ground band). 5/5.
* Landmarks never merge, so their `own_air` (edges stream) passes through
  unchanged; merged compounds never contain a landmark.
* After the edges merge (lower perimeter storeys) the six-town corpus twin
  share is 0.16 with lot merging and 0.19 with merging disabled (0.21 before
  this review). Thresholds adjusted: corpus twin share < 0.18, photo towns at
  most 2 twin pairs (Town A has only 4-6 touching pairs, so a share is
  unstable).

## Build-order determinism and tiers follow-up (merged c2fd9e33)

* ROOT CAUSE of "Town A's score depends on what ran earlier": `Array.sort()`
  orders StringNames by their interned pointers, not their text (verified:
  `[&"..b", &"..a", &"..c"].sort()` gave c, a, b). `KitVillageBuildings.build`
  sorted house ids that way and designed houses in that order; shared canopy
  claims, KitRoofJunctions joins and (since this stream) `merge_houses` are
  order-dependent, so a town's buildings changed with the process's intern
  history. Pre-existing in production (the build sort predates this stream);
  streaming builds towns in arbitrary order. Fix: `KitVillageBuildings.
  sorted_ids` (lexicographic) for the build order, merge order, merged group
  and `BuildingKit.all_asset_ids`. Regression test
  `tests/test_september29_town_build_order.gd` builds Town A, then Town B and
  3:standard, then Town A again and compares the full kit payload (fails with
  pointer sort: 152804 vs 149363 bytes; passes with the fix). Only the kit
  layer was audited; other `.sort()` calls on StringName arrays elsewhere in
  the village code may hide the same bug (not covered by this test unless
  they affect Town A).
* Two roof holes the merge introduced on the tiered corpus (3:large, 6:grand):
  a compound's tall (>1 storey) gable faced a neighbouring building. Square
  crowns now turn their ridge away from such a neighbour
  (`BuildingDesigner._gable_abuts`), and a compound whose whole-crown wing
  would still point a tall gable into a neighbour uses its members' own
  crown packing (`_abutting`). 50-town roof survey: gable holes 0 (0 with
  merging disabled), tiny 32 (33), air roofs 86 (51, all on posts).
* Re-pinned `test_september29_roofline_variety`: Town B now rolls a citadel
  with a one-storey lower town (15 roofed houses). Per photo town: minority
  axis > 0.25 (0.13/0.19 before this review), twins <= 3, compound >= 2, roof
  audit clean. Corpus (six towns): twin share < 0.18 (0.16; 0.18 with merging
  disabled; 0.21 before this review), minority > 0.38 (0.44; 0.28 before),
  compound share > 0.15 (0.24; 0.03 without merging).
