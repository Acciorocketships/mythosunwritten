# Slope ledges, jagged rock, slope-versus-cliff and the dead-end road

Owner review, September 27, seed 2697992464. All changes are in
`scripts/terrain/field/CliffSlopeEnvelope.gd`, plus a four-line exclusion
change in `CliffSlopeField._exclusion`. Tests:
`tests/test_september27_slope_ledges.gd` (9 tests).

## A. Ledge lips (treads rising outward)

**Diagnosis.** Fall-line profiles through the owner's sites
(`profile-site-A-before.txt`, `profile-site-B-before.txt`, instrumented
per-component values) show three sources of outward rise:

1. **The per-block `jut`** (−0.3..1.0 m). It was faded in by `s²` and by
   `1 − smoothstep(.7,.9, frac)`, and both factors grow downhill. At site B
   the tread itself was level (`carved` 66.83 → 66.95 → 66.95), but the jut
   added 0.05 → 0.23 → 0.37 → 0.51 m going outward, which made a 0.44 m lip.
   Without the jut, B's rises fall from 16 to 1 (`component-attribution.txt`).
2. **Fading an outward-only bench down the fall line.**
   `lerp(F, carved, s)` with `s` rising downhill (the crown guard, steepness
   and the patch mask). The bench stands up to (1−r)·step (0.9–2.6 m) proud
   of the backing, so a fade faster than the backing falls tilts the tread
   upward. At site A the crest-capped tread (`top − .5` = 30.11) sat 0.6 m
   above the faded shoulder just uphill (29.5). That made a 0.65 m rise. The
   jut has nothing to do with this one: it stays at 0.65 without the jut.
3. **Phase blends between blocks stacked down the fall line.** Blocks are
   stretched along the contour, so a tread's run crosses block borders. The
   downhill block's tread can be higher than the uphill one's.

The crest clamp itself cannot raise anything, the riser shift keeps treads
level within one profile, and the fin filter only damped the result.

**Change.**
- The jut is removed.
- The bench profile is rewritten (`_bench_profile`). Tread levels are
  n·step − phase and do not depend on the riser share r. Each tread meets the
  backing at its inner edge and stands proud at its outer edge.
- A single invariant is enforced last: `_level_outward`. Carved nodes are
  visited from the highest backing down. Each one is capped by the surface
  one grid line uphill on its own fall line. A tread can therefore stay
  level or fall along the fall line, and may still tilt side to side
  (blends between neighbouring blocks).

**Numbers.**

| Case | Before | After |
|---|---|---|
| P03 native fixture: treads rising > 0.1 m over 1 m | 21 (max 0.43 m) | 0 (max < 0.1 m) |
| Site A, dry envelope: rising nodes | 31 (max 0.65 m) | 0 (max 0.01 m) |
| Synthetic 20 m wall at 0°, max rise | 0.65 m | < 0.3 m along the backing's own fall line (2 nodes still rise 0.68 m along the wall normal, at lateral block ramps) |
| Synthetic 20 m wall at 30°, max rise | 0.99 m | < 0.3 m along the backing's own fall line |

**Evidence.** The live views are `site/mA-comparison.png` and
`site/mA-zoom-before-after.png`. The raised pale lip with its dark trough
behind it becomes a tread meeting a lower rock edge. The neutral study view
is `study/p03-close-neutral-comparison.png`, where the ridge across the right
tread is gone.

## B. Jagged ledges (sawtooth facets)

**Diagnosis.** 7×7 height neighbourhoods at the worst nodes show that
single-node spikes and notches come from:

- treads narrower than the 0.5 m grid (tread run (1−r)·step/grade is often
  0.5–0.7 m);
- hard tread/riser creases running diagonally across the grid (a single
  bench profile with no block variation still scored 121/204 contour kinks
  on 30°/45° walls);
- blending only the two nearest blocks, which jumps wherever the second and
  third change places;
- the 0.35 m `split` groove within 0.4 of a border;
- benches carved on the creased backing of road and water cut faces. These
  caused the multi-metre fins, for example at P03 (519.5, 943.5).

**Change.**
- The bench is sampled as its half-metre cell average: a tent filter along
  the fall line, `FILTER` 1.5.
- Corners are rounded (`CORNER` .25).
- Every tread keeps at least `TREAD` 1.75 m of run and every riser at least
  `RISER` 1 m. Where the backing is too steep for both, the bench fades into
  the slope.
- All neighbouring blocks are blended, weighted by closeness to winning,
  over `BLOCK_BLEND` 3 m.
- The split groove is removed. Chip noise now has a 4.6 m wavelength instead
  of 2.3 m.
- Cut faces keep their stone colour but are no longer benched.
- `_remove_bedrock_fins` is deleted as unnecessary.

**Numbers.** Contour kinks are nodes whose second difference along the
contour exceeds 0.5 m.

| Case | Before | After |
|---|---|---|
| P03 native fixture | 348 | 67 |
| Synthetic 20 m wall at 30° | 204 | 89 |
| Synthetic 20 m wall at 45° | 197 | 95 |
| Synthetic 20 m wall at 0° | 132 | 44 |

The Sept 26 guards still pass on P03, but tread samples fall from 63 to 52, only just above the gate of 50:

| P03 guard | Before | After | Gate |
|---|---|---|---|
| Tread samples | 63 | 52 | > 50 |
| Patches | 11 | 11 | > 8 |
| Face-normal deviation, median | 11.05° | 10.85° | < 14° |
| Face-normal deviation, p90 | 20.07° | 16.3° | < 24° |

A stronger filter (2.0) halves the diagonal kinks again (34/35), but drops
P03 treads to 29–35. That fails the owner-approved tread gate, so it was not
chosen (`synthetic-*-study.txt`).

**Evidence.** In `study/p03-close-neutral-comparison.png` the sawtooth edge on
the left cut face is gone. The other `study/*-comparison.png` images are
matched neutral and textured renders of the frozen native P03 inputs and a
30° synthetic wall.

## C. Slope versus cliff: the owner's question

**The answer.** The heightfield has only two kinds of height change:

- **Levels (1 m).** These are always smootherstep slopes in the terrain mesh
  itself. The envelope leaves them alone (`LOCAL_RELIEF` 2–3.2 m).
- **Storeys (4 m).** In the heightfield these are vertical cliffs. Under the
  `sheet` style, *every* storey cliff is covered by the envelope's rounded
  slope, including a single storey.

So there was no longer a geometric difference between a one-storey "cliff"
and a slope. The only distinction was the envelope's own decoration, and
until now that decoration (ridge/valley shoulder noise between 3.0 and
6.4 m, bumps and divots, bedrock benches from relief ≥ 2.5–4.5 m) applied to
one-storey drops exactly as to tall cliffs.

The circled bank at C is a one-storey dry bank above a river. The river is
carved a further storey into the bed, so the old relief measure saw about
7.9 m (`C-line-profile-before.txt`). That bank received:

- the ridge blend (`t` swinging 0 → 1 along it);
- bench carving on its water-cut face, which is the underwater slab or bulge
  in the before image.

**Change.**
- Variation is gated on relief measured to the **water surface**, not the
  carved bed (`drop`).
- Ridges, valleys, bumps and bedrock fade in smoothly from 4.5 to 8 m of
  relief (`VARIED`). A one-storey drop gets the uniform wide rounded
  **narrow** shoulder (`PLAIN` = 0) and no bedrock. The narrow choice keeps
  the Sept 25 24 m terrace flat: `test_terraces_stay_flat` now passes; it
  failed before. Two storeys and more keep the full variation.
- Bedrock additionally needs more than a storey of drop above any water, so
  P03's tall rocky channel banks keep their rock (349 face samples).

**Numbers.**

| Case | Before | After |
|---|---|---|
| 4 m step: height spread along the step | 1.17 m | 0.000 |
| 4 m step: rock exposure | 0.10 | 0.0 |
| 8 m step: height spread along the step | 3.17 | 2.9 (kept) |
| 12 m step: ridges and rock | present | still present |
| One-storey river bank: crest spread | 0.106 m | 0 |
| Continuous 3 → 13 m wall: worst half-metre seam | — | < 0.5 m (the backing's own rolling, unchanged at 0.41) |

**Evidence.**
- `site/C-comparison.png` and `site/mC-comparison.png`: the underwater
  slab/bulge beside the bank is gone.
- `site/A2-comparison.png` and `site/mA2-comparison.png`: the wavy-edged
  one-storey slope becomes one even slope.

## D. Path dead-end in a box trench

**Root cause, measured in the live world** (`dead-end-owner.txt`):

- The trench is the country-road **lattice path** (mask 3 along row 22 from
  cell 44 to 51). It is not a town shape.
- `PathPlan` validated the edge from cell (49,22) to (48,22) on **natural**
  terrain. There it is a walkable one-storey slope: 28 m to 32 m,
  `walkable(natural) = true`.
- The town at node (51,22) then grades its approach. Its native controls
  lower cells 49 and 50 to 24 m, one storey below natural.
- The same edge becomes an 8 m, two-storey cliff: `walkable(graded) = false`.
- The envelope then cut the road clear to its ground,
  `caps = ground + 1.4·dist`. The result was a flat road floor at 24 m, two
  1.4-grade cut walls with bedrock colour, and the bare native storey face
  at the end.

**Change (envelope side).**
- The exclusion query now distinguishes open-country road (2) from other
  kept-clear ground (1: town grades, plazas, streets).
- Where a road's *own* ground steps by a storey (`crossing`), the slope is
  not cut within `RAMP_REACH` (16 m). The road rides the rounded slope, and
  benches stay off it.
- Roads beside a cliff and village ground are still cut clear. Both are
  pinned by a test.

**Numbers** (`dead-end-profile-after.txt`). The native fixture road now
climbs 24 → 32 m continuously, steepest 1.1 m per metre (48°, under the 55°
walk limit), instead of the 8 m wall.

**Evidence.** `site/mD-comparison.png`. The tactical `D` view is blocked by
a foreground town railing in the current world.

**Not fixed at the root.** The grading defect itself is still there: a town
grade may open a cliff across a road that was already validated.

- The proper fix is in the town grade (`NativeTerrainGrade.controls`, or
  where the approach patch is made). An existing road edge's walkability
  should be a grading constraint, for example lowering the next cell one
  storey as a ramp.
- That code belongs to the town/grading owners (another agent is editing
  `features/villages/**`). It changes terrain around every town, so it was
  not changed here.
- The path paint still ends at the foot of the ramp and resumes on top. The
  slope mesh has no path colour.

## Verification limits

- **The live geography moved during this pass.** Concurrent `WaterPlan` and
  terrain changes by other agents mean the owner's exact B, A2 and P03
  photo poses no longer frame the same ground:
  - the mB camera is inside a mountain;
  - the P03 cameras look at a different landform.
- **What still has matched views.** A and D keep matched before/after views.
  Each pair comes from one process, using `--override` for the before
  revision, then `reload`.
- **Where B and P03 evidence comes from instead:** the frozen native P03
  inputs (numeric tests and neutral study renders) and synthetic walls.
- **The "before" revision** for C and P03 is the backed-up envelope plus the
  water agent's film change (`before_with_film`). This isolates this pass's
  changes. The A, B and D pairs used the plain backup; they have no
  thin-film water.
- **The sweep's reach.** The sweep depends on uphill nodes inside each
  chunk's 32 m grid pad. A carved chain longer than that on a very tall
  face could in principle differ between chunks. No seam test failed, but
  this was not measured on a huge face.

## Render provenance

- **C, B and A2** (`site/`) were rendered from the final revision.
- **A and D** were rendered from an intermediate revision. It had the same
  bench, sweep and road-crossing code. It lacked the later changes (water
  surface drop, narrow plain shoulder, bedrock drop gate), none of which
  touch those two sites' ledges or road.
- **Before** is `before-envelope.gd.txt` (B, A2, A, D). For C, before is
  that file plus the water agent's film change.
- **Matched views.** Each pair is one process (`cliff_site_review
  --override`, then `reload`). Water animation differs between the two
  captures, so the water shows up in the pixel diffs.

## Tests

`test_september27_slope_ledges.gd`:

- Before: 5 of 9 red. These are the rise, sawtooth, one-storey, river-bank
  and road-crossing tests, plus the native dead-end fixture test. Evidence
  is in the baseline hook runs.
- After: 9 of 9 pass.
- The guards (tall cliffs keep variation, seam-free blend, graded ground and
  roadside ground still cut) pass both before and after, as intended.

Existing suites: `tests-after.txt` and `tests-baseline.txt` (baseline = backed-up envelope, via `tests/harness/baseline_source_hook.gd`).

| Suite | After | Before |
|---|---|---|
| test_p03_constrained_cliffs | 13/13 | same |
| test_p03_cliff_followup | 10/10 | same |
| test_september26_bedrock | 6/6 | same |
| test_september26_manual_cliffs | 6/6 | same |
| test_cliff_sheet_normals | 2/2 | same |
| test_meadow_rocks | 3/3 | same |
| test_september27_rock_placement | 8/8 | same |
| test_september27_mountain_water | 3/3 | same |
| test_slope_face_inclusions | 2/2 | same |
| test_september23_cliff_directions | 32/34 | 28/34 |

The two remaining `test_september23_cliff_directions` failures also fail on
the baseline:

- ridge amplitude 1.008 against a gate of 1.2 (1.027 on the baseline);
- corner reach 20.25 m.

The rock-placement suites are being edited concurrently by another agent,
so their counts moved between runs.

## E. Dead-end road: town-grade root fix (follow-up)

This replaces the envelope mitigation of section D.

**Root cause, from the frozen town grade**
(`tests/fixtures/september27-dead-end-grade.var.gz`, frozen by
`tests/harness/road_grade_freeze.gd`):

- The town at node (51,22) (datum 24 m, storey 6) connects the west country
  road through `VillageWarrenFabricSolver._connect_world_roads`. Its handoff
  street runs from road cell (49,22)'s centre to the town boundary, then
  along the perimeter; `_extend_street_grade` flattens it to the datum.
- Native controls sample the grade at each 24 m cell centre, so the street
  lowers (49,21) and (49,22) from 28 m to 24 m (both within 2 m of a street
  claim).
- Road cell (48,22) stays at natural 32 m: two storeys over those cells, so
  it becomes a cliff top and draws its east edge flat. The accepted edge
  (48,22)->(49,22) is an 8 m wall.
- Route acceptance cannot use the graded field instead: the town's frame
  and grade depend on the accepted routes, so that would be circular.

**Why the road ends there.** Row 22 is the town's incident route from the
west. It ends at the town's node, and the town's handoff street takes it on
to the gate. The road does continue into the town; the cliff hid the join.

**Change (grade side).**
- `PathPlan.accepted_road_masks_for_node` returns the full lattice of the
  settlement's accepted incident routes. `accepted_mask_for_node` is now
  derived from it.
- `WorldFeaturePlan.frame_for` stores it in `VillageFrame.road_masks`.
- `VillageWarrenFabricSolver.solve` seals it into the town's
  `TerrainGradePatch.road_masks` before any construction samples the
  graded field. Continuous, fixed and foundation-pad extensions and grass
  copies all keep it.
- `NativeTerrainGrade._grade_roads` runs after the collar and fixed owners
  resolve, and before the pad-support closure. It looks at unclaimed road
  cells that were not already cliff tops on natural ground. Any such cell
  that has become a cliff top is lowered to one storey above its lowest
  neighbour.
  - This is a lowering-only fixpoint, a whole storey at a time, so it
    terminates.
  - It is computed once over the grade's complete control domain, so it
    does not depend on which chunk asks.
  - Ramp cells stay within one tile of the grade bounds, inside the
    published `NATIVE_CONTROL_MARGIN`.
- The road is graded down into the town: 32 → 28 → 24 m. The town's own
  claims, and the ground beside the road, are untouched.

**Envelope mitigation removed.** The following are gone:
- the `excluded_at` kind 2;
- `RAMP_REACH`;
- the road-crossing carry in `CliffSlopeEnvelope`;
- the `_path_at_cell` branch in `CliffSlopeField._exclusion`.

Roads are cut clear as before. The two slope-ledges tests that pinned the
mitigation were removed. The synthetic road-crossing test and the native
dead-end fixture test are superseded by `test_september27_road_grade.gd`.
The old fixture is kept and marked historical in the fixture README.

**Invariant corpus** (`E-road-grade-corpus.txt`,
`tests/harness/road_grade_walkability_probe.gd`). For every town, every
accepted road edge that is walkable on natural ground must still be
walkable on the final graded field. The audit uses the complete
path-context masks, not just the sealed ones.

| | Seed 2697992464 | Seed 1 | Seed 777 |
|---|---|---|---|
| Before: towns | 9 | 9 | 8 |
| Before: broken edges | 1, the reported (48,22)->(49,22) | 0 | 0 |
| After: broken edges | 0 | 0 | 0 |

- 26 towns in all.
- No road cell inside any grade's reach is missing from the sealed incident
  lattice (`unsealed_in_reach=0` everywhere).
- In 18 towns (seeds 2697992464 and 1), the ramp changed exactly one
  control: (48,22), 32 → 28 m.

**Renders** (`site/E-*-comparison.png` show before | after; `site/E-*-diff.png`
mark pixels changed by more than 24).
- Before is the pre-fix revision, loaded in the same harness through
  `--override` of `NativeTerrainGrade.gd`, `CliffSlopeEnvelope.gd` and
  `CliffSlopeField.gd`. That revision includes the section D mitigation.
- Views:
  - `D` is the owner's F3 pose, via `ReviewCam.solve_cam`. The foreground
    town railing still occludes part of it.
  - `over` looks down on the approach.
  - `road` is a ground view looking east along the road.
  - `side` looks south across the ramp.
- Before: the lattice paint stops at the crest and the town street starts
  separately below it.
- After: one continuous painted road runs down the notch into the town
  street.
- Changed pixels: 0.8% (`over`) to 9.3% (`road`). They are confined to the
  ramp and to two trees that now grow where the envelope slope used to
  stand.

**Walks** (`E-walks-before.json`, `E-walks-after.json`). The production
character walked 45 m each way along row 22. Both walks passed before and
after, with no wall contacts.
- Before, the mitigation's rounded slope already carried the character.
- After, the character goes over native ground: 32 → 28 → 24 m.

**Tests** (`E-tests.txt`).
- `test_september27_road_grade.gd`: 5 tests. Red first: the fixture and
  synthetic ramp tests failed, 2 of 5. After: 5/5 pass, 30 asserts.
- These suites match the baseline exactly:
  - `test_terrain_grade_patch`
  - `test_september15_grade_topology`
  - `test_september13_village_grade`
  - `test_september7_continuous_street_grade`
  - `test_graded_cliff_construction`
  - `test_feature_context`
  - `test_path_features`
  - `test_path_program`
  - `test_september13_world_paths`
  - `test_september10_path_decision_work`
  - `test_village_plan`
- `test_path_plan_nodes` is 4/5 both before and after. The same
  exact-water count assertion fails in both (12 against 9).
- `test_september27_slope_ledges`: 9/9 before, 7/7 after (two mitigation
  tests removed).
- Envelope suites after the change:
  - p03 constrained 13/13;
  - p03 follow-up 10/10;
  - September 26 bedrock 6/6;
  - September 26 manual cliffs 6/6;
  - sheet normals 2/2;
  - cliff directions 32/34. The same two baseline failures remain: ridge
    amplitude 1.008 against 1.2, and corner reach 20.25 m.

**Not verified / open.**
- **Raised towns.** Only lowering is handled. If a town pad stands two
  storeys above an approaching road, the edge stays a wall. This did not
  occur in the 26-town corpus.
- **Deep sinks.** A sink three or more storeys deep needs a ramp longer
  than the one-tile reach and would leave a cliff at the reach edge (not
  observed).
- **Non-incident roads.** Roads that are not the town's own incident
  routes are not sealed. None came within grade reach in the corpus.
- **Other agents' tests.** The broader test suite and the rock agent's
  suites were not rerun.
