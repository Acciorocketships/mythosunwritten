# Growing upper floors: result (October 8–9)

Spec: `docs/superpowers/specs/2026-10-08-growing-upper-floors-design.md`, including both owner
amendments (October 8 "step out, every exposed face, wraps, rows, bury" and October 9 "Amendment 2:
step in the kit's way"). Plan: `docs/superpowers/plans/2026-10-08-growing-upper-floors.md`.

## What changed

**Knobs** (`terrain/villages/town_odds.tres`, TownCharacter streams):

| Knob | Kind | Shipped value |
|---|---|---|
| `growing_house_chance` | CHANCE | 0.3 small → 0.45 large, spread 0.1 (was 0 until this task) |
| `growth_street_face_chance` | CHANCE | 0.85 |
| `growth_other_face_chance` | CHANCE | 0.85 (every exposed face alike) |
| `growth_step` | WEIGHTS | {0.5 native m: 1, 1.0 native m (the kit jetty): 3} |
| `growth_max_lean` | RANGE_FLOAT | 2.0 native m = the ground storey's total step-in below the top storey |

`growth_gable_front_boost` and `lane_sky_gap` were removed (the latter in the final review: inert under step-in). `tests/fixtures/town_old_look.gd` pins
`growing_house_chance = 0.0`, so the old look still reproduces the pre-growth towns.

**Eligibility.** Any exposed face (not touching another building at the storey's bands) of a house
with at least two stacked storeys. Landmarks and prefabs never grow.

**The step-in.** A growing house keeps its roof and its top storey on the footprint. Each lower storey
on a stepping face stands one step (normally the kit jetty, 1.0 native m = 2 m world) further in than
the storey above, so the ground storey is the narrowest and every upper storey overhangs the one below
on the kit's own jetty: floor beam on the face, `bracket.jetty` diagonal braces (`bracket.small` for
the 0.5 step). Offsets are the old cumulative profile re-referenced to the top storey
(`KitGrowingFronts.offsets_of`: storey k at `lean_k - top`, ground at `-top`).

**Fronts and closures.** Faces step as fronts (a lone face, a convex-corner wrap of one house, a
coplanar row of houses) with one monotone capped profile; a front steps only up to its shortest
member's top storey. Each end of a stepped run closes as:

- `return`: the perpendicular corner panel shortens to the baked `frontage.return.dNNN` strip (or is
  dropped for a whole-module step) and the corner post moves to the new corner; the overhang closes
  its open side with the baked return beam.
- `wrap`: both faces of a convex corner step equally, both corner panels are cut, one post stands at
  the new corner, and an upper floor keeps the inner `frontage.corner.dNNN` square.
- `joint`: a coplanar row steps together, with no piece at the joint.
- `bury`: the house's own cell beside the end; a strip on the vertex line closes the recess.
- `abut`: an end beside a touching neighbour closes with our own strip on the party plane.

**Braces** stand on wall-module joints (panel joints and corner posts) of the stepped-in storey, never
over a window or door head, with one owner per joint.

**Floors.** The ground floor stays whole: it becomes the paving under the overhang, out to the lot
line. A stepped-in upper storey's floor is trimmed to its own wall. An off-grade ground storey (on a
podium or massif) steps in only over solid bearing; the strip it leaves becomes a stone plinth cap
(`plinth.cap` rows).

**Recessed doors.** A ground-storey door on a stepped-in run moves in with its wall, with its
doorstep, as a shopfront under the overhang. Upper-storey doors and bays on a stepped-in run withdraw
the step.

**Guardrails under step-in.** A failing step drops the front's cap by one step. A member that cannot
take the first step leaves the front. Nothing is ever removed from the town.

| Guardrail | Under step-in |
|---|---|
| G1 walking air | Can fire where public air reaches inside the house (passages, tunnels): cause `air`. |
| G2 sky gap | Cannot fire (no outward offset is written). |
| G3 neighbours / features | Fires only for another building's or a tower's pieces inside the recess: `obstacle.*`. Recess claims are tested on the recess cells. |
| G4 → ends | `return` / `wrap` / `joint` / `bury` / `abut`; otherwise `ends` (door, passage, bay or blank on the cut corner panel; a partial cell beside the end; the perpendicular face already stepped). |
| G5 footprint | Unchanged (the face chain walk). |
| G6 portals | Passages, blanks and balconies; upper doors and bays on a stepped-in run: `portal`. |
| G7 crown | Removed. |
| Bearing | ≥1 module behind every stepped edge, ≥2 across a two-sided axis: `bearing`. |
| Party | Never against a touching building or party wall: `party`. |
| Material | Stone storeys only by whole modules; no retaining/fortified/sunk/abutted storey: `material`. |
| Grade | An off-grade strip needs solid bearing below (it becomes the plinth cap): `grade`. |
| Decor | Ivy, window boxes and awnings that braces or beams meet yield; a porch post on the run withdraws the step. |

## Corpus

**Shipped defaults** (no `--odds`). Audit outputs are in `audit/default_fp.json` and
`audit/default_sample.json`. Both runs end `GROWTH_AUDIT_DONE bad=0`, every payload valid, and every
violation count is 0.

| Measure | 8 fingerprint towns | 16-town production sample |
|---|---|---|
| Stepping faces | 4 (53:1, 13:1, 83:1, 61:1) | 12 (3:1, 5:1, 8:2, 9:6, 15:1, 18:1) |
| Stepped storeys (records) / stepped-in | 8 / 4 | 24 / 12 |
| Ground faces | 4 | 12 |
| Deepest offset | -1.0 native (one kit jetty) | -1.0 |
| Recessed doors | 2 | 4 |
| Returns / wraps / joints / buried / abut | 6 / 0 / 0 / 5 / 5 | 28 / 4 / 0 / 11 / 5 |
| Pulled houses | 0 | 0 |
| Violations (12 kinds) | 0 | 0 |

Withdrawals at the defaults, as attempts / distinct faces. These are the final build pass only (fix
round 1 below): houses that rolled growth but kept no step are rebuilt as plain houses, so their
withdrawn attempts are no longer reported.

| Cause | 8 fingerprint towns | 16-town sample |
|---|---|---|
| ends | 5 / 4 | 17 / 11 |
| portal | 2 / 2 | 6 / 5 |
| air | 2 / 2 | 9 / 7 |
| party | 2 / 2 | 3 / 2 |
| grade | 1 / 1 | 8 / 4 |
| bearing | 3 / 2 | 6 / 4 |
| obstacle.* | 3 / 3 | 4 / 4 |

`ends_why`: door 1, partial 1, stepped 3 (fingerprint towns); door 6, partial 2, stepped 9 (sample).

**At `growing_house_chance = 1`** (Task 10; every eligible house rolls growth):

- 19 faces / 38 storeys on the 8 fingerprint towns (53:4, 31:2, 13:1, 43:1, 83:10, 103:0, 7:0,
  61:1), with 3 recessed doors, 16 wraps, 4 joints, 21 buried, 7 abut and 28 returns.
- 23 faces on the 16-town sample.
- 0 violations in all runs.
- Withdrawals (attempts / distinct faces): ends 71/51, portal 53/33, grade 52/31, air 38/31, party
  37/22, bearing 32/24, obstacle.spatial 14/11, material 10/7.

**History of the count** (8 fingerprint towns, chance 1):

| Stage | Faces |
|---|---|
| Original street-face rules (Task 4 diagnosis), stepping out | 1 of 45 candidates |
| Every exposed face, false-blocker fixes | 183 candidates → 18 stepping |
| Coplanar terrace estimate | 22 |
| Task 7 (step-out, before roofs) | 21 |
| Superseded Task 8 roof following | 2 |
| This plan (step-in) | 19 |

## Gates

- **Source plans unchanged** (growth is kit-layer only): `town_fingerprint --parts source` against
  the pre-default baseline: FINGERPRINT_MATCH.
- **Zero path:** `--odds growing_house_chance=0 --compare` the pre-default baseline (HEAD ea48983a4):
  FINGERPRINT_MATCH.
- **Re-pinned** `docs/qa/2026-10-07-town-odds/fingerprint/baseline.json` for the shipped defaults:
  - Source hashes are unchanged in all 8 towns.
  - Payload hashes changed only in the 4 towns with a stepping face (53, 13, 83, 61). Against the
    pre-default baseline, 31, 43, 103 and 7 MATCH again after fix round 1; before the fix, 7 towns
    differed because of failed growers.
  - The full gate against the new baseline: FINGERPRINT_MATCH.
- **Old look:** `--old-look --compare old_look_baseline.json --parts source`: FINGERPRINT_MATCH;
  `test_town_old_look` 1/1.
- **Growth-on smoke** (`--odds growing_house_chance=1`): 0 FINGERPRINT_NO_TOWN.
- **Production range audit** (`oct7-range-audit-prod`) at the defaults on 53, 31, 13, 43, 83, 103: every
  row has `valid_payload` true, `floating` 0 and `roof.intrusions` 0.
- **Tests** (each file in its own process, all green):
  - test_growing_floors 10/10
  - test_growing_floors_guardrails 22/22
  - test_growing_floors_wrap 4/4
  - test_growing_floors_rows 5/5
  - test_growing_floors_bury 3/3
  - test_growing_floors_knobs 6/6 (red first on the new default assertion: 5/6)
  - test_growing_floors_step_in 13/13
  - test_growing_floors_edges 8/8
  - test_growing_floors_corpus 1/1
  - test_growing_floors_failed_growers 1/1 (fix round 1)
  - test_growth_front_family 3/3
  - test_october3_room_projections 9/9
  - test_roof_proportion 4/4
  - test_town_odds 12/12
  - test_town_old_look 1/1

## Images

Renders are in `docs/qa/2026-10-08-growing-floors/final/` (PNG/JPG on disk only, gitignored).
Camera notes:

- The `growth` / `wrap` / `door` views of `kit_town_review` measure eye height from the house's own
  ground floor and stop short of the first collision. The brief's version used the flat review
  ground, which put most cameras inside the massif.
- The `wrap` views take at most three of each closure kind.
- `building_gallery --street` lays the gallery's houses out as two facing rows along one lane (new
  for this task).

**Comparisons** (`final/compare/`):

| Image | What it shows |
|---|---|
| `gallery_street_west_before_after.jpg`, `_north_`, `_south_`, `_east_`, `_above_` | Eight designer houses in two facing rows, with and without growth (every house grows, step 1.0, cap 2.0). The Shambles read: every ground storey a jetty narrower, timber storeys jutting over it on diagonal braces, ground boards running out to the lot line under the overhang. Roofs and tops are identical. |
| `gallery_b07_before_after.jpg` | One house without/with growth from the same camera. Roof, top storey and window boxes are unchanged; the ground storey is narrower on braces. The ivy and the stone footing course on that storey yield (decor rule). |
| `gallery_grid_step100_cap200.jpg` | The 9 gallery houses (1–4 storeys, timber and stone grounds) at step 1.0, cap 2.0. |
| `83_grand_`, `53_grand_`, `31_large_`, `61_standard_overview_before_after.jpg` | Town overviews at growth 0 vs shipped defaults. Honest result: from overview distance the difference is invisible. Roofs never move, and at the defaults each of these towns has at most one stepping face (31 has none). |
| `53_grand_street0_before_after.jpg` | Same camera. A posted wooden canopy is gone: a house that rolls growth is designed without porch awnings and without its kit jetty (`BuildingDesigner`). 53 loses its canopies for its one growing house (house.045), which keeps a step. See limit 8. |
| `53_grand_street2_`, `61_standard_street1_`, `61_standard_lane0_before_after.jpg` | Random street cameras. They pick their direction by ray tests against collision, so the cameras differ slightly between runs; not a like-for-like comparison. |

**Before/after town sets** (`final/before/`, `final/after/`): 8 towns × overview, orbit0-3, street0-5,
lane views. These use the same cameras, except the random street cameras noted above.

**Street-level views at the shipped defaults** (`final/street/`; one stepping face per growing town):

- `13_standard_growth0_up.png`: a stepped-in ground storey with arched window standing on its stone
  plinth cap, the overhang above.
- `53_grand_growth0_up.png`: an overhang over window boxes on a stone plinth cap.
- `61_standard_growth0_up.png`: a recessed door under the overhang beside a stone neighbour.
- `61_standard_door0.png`: the recessed door with its doorstep.
- `83_grand_door0.png`: a recessed door on the ground boards, its walk to the threshold floored.
- `83_grand_growth0_up.png`: an overhang above a recessed door.
- The `*_lane.png` and `*_bury*` views at the defaults are mostly cramped (lanes are 1–2 cells wide)
  and add little.

**At chance 1** (`final/after_all/`, `--odds growing_house_chance=1`):

- `31_large_growth1_lane.png`: a lane along a stepped facade, braces on every joint, ground storey on
  the plinth cap rows.
- `31_large_growth1_up.png`: braces on panel joints, none over a window.
- `53_grand_joint2_street.png` / `53_grand_joint3_street.png`: a terrace row stepping as one at a row
  joint, braces on joints, plinth cap below. No doubled post or brace at the joint.
- `83_grand_wrap8_street.png`, `83_grand_wrap9_street.png`, `83_grand_wrap8_side.png`: wrapped convex
  corners, one post at the new corner, both faces stepped.
- `83_grand_door0.png`, `83_grand_door1.png`, `83_grand_growth1_up.png`: recessed shopfront doors
  under the overhang.
- `83_grand_bury*`, `31_large_bury*`: mostly too close to read. The bury strip closes the recess (the
  audit counts 0 open ends).

**Gallery** (`final/gallery/`):

- `step100_cap200/`: the usual case. `b02_c0` is a four-storey stepped tower; `b05_c2` is a recessed
  door with a wrapped corner and braces; `b07_c1`.
- `step050_cap200/`: the light 0.5 step on `bracket.small`.
- `step100_cap100/`: one jetty only.
- `nogrowth/`: the same houses without growth.
- `street_growth/`, `street_nogrowth/`: the street layout.

What to check, and what was seen:

- Roofs and top storeys are as in `nogrowth`.
- Braces stand on joints and corner posts only, never over a window or door head.
- Cut corner panels are flush, with one post at each new corner.
- No floor ledge outside an upper wall.
- Wrapped corners have one post.
- Row joints show no doubled post or brace.
- Doors are recessed on the ground boards.
- No awning crosses a brace: awnings that would yield are removed.
- No defect needing a red-first fix was found in these renders.

## Deviations from the spec (ledger ruling F5)

Original plan rulings that still stand:

1. The cap is quantised: `step · min(4, floor(cap / step))`.
2. Monotone profiles; a failure drops the cap one step for the whole front.
3. A growing house loses its house-wide inset jetties (the kit's own jetty), while its design rolls are
   kept, so other design choices do not reshuffle.
4. Growth runs after towers and before room projections and bays.
5. The street face is a column test; it only selects which face knob applies.
6. G6 (portals) is widened to passages, blanks and balconies on the run or the storey above.
7. Returns are cut from wall starts (no runtime scaling).
8. (Removed in the final review: `lane_sky_gap` and its G2 sky-gap guardrail; an inset never narrows a lane.)

October 8 amendment rulings that still stand:

1. The 0.25 step is retired; its baked pieces were removed in the final review (only the d025 return beam, the wrapped-corner filler, stays).
2. Pulling is one hop: a growing face pulls only its direct coplanar or convex-corner neighbours.
3. Rows pull non-growing eligible neighbours, so more houses can step than `growing_house_chance` alone
   gives (0 pulled houses in every corpus run so far).
4. Rows join only on the same first upper storey.
5. A member that cannot hold leaves the front. It is refitted alone only if it was a seed (rolled
   growth).
6. Rails, bays and architecture never yield; only ornament yields.
7. The ornament yield extends to row members.
8. Outer (convex) corners of the same house wrap: both faces step together and the corner is closed.
   This overrides original plan ruling 7 ("never two faces that meet at a corner"); two faces that
   meet at a convex corner step equally (wrapped), or one of them stays flush at that storey.

Amendment 2 rulings:

1. Step-in is built by re-referencing the step-out machinery to the top storey, not by a rewrite.
2. The superseded roof-following code (gable shift, eave cap/allowance, crown G7, one-face eave inset)
   is removed. Its assembler step-in pieces (short corner panels, inset ends, inset jetty) are kept and
   generalised.
3. A front steps only up to its shortest member's top storey. This supersedes the Task 6 ruling "the
   taller member continues alone above the shorter".
4. The profile is found by cap iteration on final offsets, which gives the same outcomes as "hold from
   the failing storey up".
5. Bearing: one module behind every stepped-in edge, two across an axis stepped from both sides.
6. Party rule: a run against any touching building never steps in, so a face over a lower neighbour
   stays flush.
7. A stone storey steps in only by whole modules; no stone half strip is baked.
8. Ground doors recess. Upper-storey doors and bays on a stepped-in run withdraw the step. Passages,
   blanks and balconies keep their old effect through the re-referencing.
9. The ground floor stays whole as the paving under the overhang; upper floors trim to their wall.
10. No path paint is extended; towns have none inside a lot.
11. Growth braces go on module joints, while the kit's own non-growing jetty keeps slot-centre braces
    (zero-chance byte identity).
12. Outward-only code (step-out returns, wrap extension strips, the plain-wall bury contact, face
    probes, reserved columns beyond a face) was removed rather than left dead.
13. `growth_gable_front_boost` is removed.

Controller rulings in the ledger that changed behaviour (plain language):

- Eligibility first meant one inhabited storey above the ground storey with a street face. The owner
  later widened it to any exposed face of a house with two stacked storeys.
- Task 5: the corner post moves out only when both faces at a corner step (the zero-growth byte
  identity required it).
- Task 6: 20 faces were accepted instead of 22. True same-line row joints are rare, and no guardrail
  was loosened.
- Task 6 rider rule: a row member's house is treated like the host when checking pieces that ride with
  the face.
- Task 6 (superseded by Amendment 2 ruling 3): the taller member of a row would have continued alone
  above the shorter.
- Task 7: an inside-corner end counts when the cell beside it is the house's own cell or another
  building. `_end_open` was fixed so a run that is part of a longer wall is not blocked. Plain
  structural trim counted as plain contact (that contact test was later retired).
- Task 8 (superseded; amendment conflict 1): the eave inset ruling. A stepped top storey would stay
  under its eave by insetting the storey below, falling back to 0.5/flush only if the inset was blocked.
  Ruled cost: ground floors on some faces shrink by 1 native m, so the lane is wider at ground; revert
  = the Task 8 fallback. That idea became Amendment 2.
- Owner option 2 (October 9): step in the kit's way, with roofs and top storeys fixed. Implemented by
  re-referencing (Amendment 2).
- Braces stand on wall-module joints, never over a window head.
- Task 8b: the step-in test caches the catalogue. Side-panel bounds allow `kit.wall_face` (the edge
  post covers the corner square).
- Task 9, ruling (a): an end beside a touching neighbour closes with our own strip on the party plane
  (`abut`) instead of withdrawing.
- Task 9, ruling (b): a designer bay on a cut corner panel yields to growth.
- Task 9, ruling (c): a vertex contact with another building's piece within its own wall face is
  touching, not an obstacle.
- Task 9, ruling (d): landmarks and prefabs never grow.
- Task 9: the at-grade rule (e) was replaced. An off-grade storey may step in where the vacated strip
  has solid bearing below, and that strip becomes a stone plinth cap. Air or a public walk below still
  withdraws (`grade`).
  - Omitted on purpose and accepted as conservative: the ruling's third bearing case, "a lower
    storey's roof-free solid". It is not implemented: where another building's room stands below the
    vacated strip, nothing caps that room under our boards, so trimming would open a hole into it.
    That strip still withdraws with cause `grade`.
- Task 9: 19 faces accepted below the "well above 21" target. The remaining withdrawals are real
  geometry.
- Task 10: crossing braces at an inside corner where two buried strips meet are accepted as one
  carpentry knuckle.

## Limits and open owner questions

1. **The feature is rare at the shipped chance.** 4 stepping faces on the 8 fingerprint towns, 12 on
   the 16-town sample (19 / 23 at chance 1). The withdrawals per cause are above:
   - `ends` (door or partial cell beside the end) and `portal` (passages) dominate.
   - `material` appears in the sample (stone grounds stepping a half module).
   - Raising `growing_house_chance` cannot pass the guardrails; only geometry rules can (e.g. a baked
     stone half strip, doors on cut corner panels).
2. **No town lane shows 3–4 stepped houses in a row.** The Shambles street is shown with the gallery
   houses (`gallery/street_growth`, `compare/gallery_street_*`).
3. **The kit's own non-growing jetty still braces at slot centres**, over window heads. Should the
   joint rule apply there too? That would change zero-chance towns and the fingerprint.
4. **Plain return strips** (d050/d100/d150) lack the rail pattern of the panels they cut (visual; needs
   a bake).
5. **Ribbed plinth cap rows.** The off-grade cap reads as rows of coping stones (`31_large_growth1_lane`,
   `53_grand_joint2_street`). It is solid, but visibly a course, not a flat sill.
6. **Crossing braces at a buried inside corner:** two faces' end braces meet inside the strips
   (accepted ruling; one brace per vertex is a 5-line change).
7. **The one-module plinth run** pokes 2 cm past one lot line. It is hidden under a built neighbour, a
   2 cm coping lip on an open side. Not seen in these renders.
8. **Dressing a growing house loses.**
   - Ivy and window boxes that the braces meet yield (the spec's yield rule).
   - A house that keeps a step is still designed without porch awnings and without its kit jetty
     (house-wide). 53's house.045 loses its canopies (`53_grand_street0_before_after.jpg`).
   - A house that rolls growth but keeps no step is now identical to one that never rolled (fix round
     1 below).
9. **Stone storeys** step in only by whole modules until a stone half strip is baked.
10. **Flush faces:** faces over a lower neighbour or against a party wall never step.
11. **The planner is unaware of the recesses:** the strip under an overhang is the house's own cell.
12. **`lane_sky_gap` removed (final review):** the knob, the G2 sky-gap guardrail (`gap_ok`,
    `MAX_LANE_MODULES`), the always-empty outward registry, `KitRoomProjections`' `facing`/`sky_gap`
    parameters and the unreachable outward wrapped-corner branch of `storey_slots` are gone.

## Fix round 1 (controller ruling): failed growers

A house rolls growth before its faces are fitted, and its design depends on that roll (no kit inset
jetty, no porch awning; the rolls themselves are still drawn). A grower whose every step withdrew used
to stay plain: 31:large house.000 kept no step but lost a porch awning, and 7 of the 8 fingerprint
payloads changed although only 4 towns step.

`KitVillageBuildings.build` now rebuilds the town with every grower that kept no step marked in
`growth_withheld` (designed and fitted as a plain house), and repeats until every remaining grower
keeps a step. The withheld set only grows, so this ends; one extra pass in practice. The result reports
`growth_withheld`.

- The build stays pure and deterministic: the same inputs, the same keyed rolls, and the withheld set
  is a plain argument.
- Fix round 2: the retry restarts only the planning half of the kit layer (`_plan_town`: house design,
  roof joins, towers and the growth fit). Assembly, facade fits, the roof mesh union and the payload run
  once, on the final plan.
- Cost, measured as a clean A/B. Same machine, one process, the same generated plans, the two settings
  alternating back to back, 3 rounds. `KitVillageBuildings.build` ms, median (min–max):

  | Town | growth 0 | shipped defaults | withheld growers | delta |
  |---|---|---|---|---|
  | 31:large | 24 629 (22 642–25 369) | 22 784 (21 924–24 842) | 1 | -7% (noise) |
  | 83:grand | 27 638 (27 109–28 347) | 30 304 (29 235–30 777) | 1 | +10% |
  | 53:grand | 31 450 (31 343–31 651) | 33 600 (32 077–33 707) | 6 | +7% |
  | 13:standard | 8 702 (8 633–9 093) | 9 117 (8 502–10 014) | 0 | +5% |

  Town planning (`WarrenVolumetricSolver.generate`) is unaffected by growth. Its run-to-run spread on
  this machine is large: 83:grand took 145 s and then 98 s for identical inputs. That spread, not
  growth, explains most of the `ms` rise in the re-pinned fingerprint baseline.
- The fingerprint harness records `ms` per town but compares only `source`, `payload` and `error`
  (`--parts`), so `ms` changes are diff noise in `baseline.json`, never a mismatch.
- Red-first test `tests/test_growing_floors_failed_growers.gd`, on 31:large at the defaults: no face
  steps, house.000 is withheld, the awning count is equal, no mass grows, and the kit payload is
  byte-identical to `growing_house_chance = 0`. It was red with 4 failures (awnings 3 vs 4,
  house.000 still `grows`, payload differs) and is now green.
- Fingerprint against the pre-default baseline: 31, 43, 103 and 7 MATCH. 53, 13, 83 and 61 differ only
  through their surviving steps. The baseline is re-pinned and the gate MATCHes.
- Corpus counts are unchanged: 4 faces (fingerprint towns), 12 (sample), 19 at chance 1, with 0
  violations in every run.
- `test_growing_floors_knobs` "build marks houses growing" now counts withheld growers as well:
  7:compact and 103:standard roll growth but keep no step, so their houses no longer end with `grows`.
- All 15 focused files are green again, along with the old-look gate, the growth-on smoke (0 NO_TOWN)
  and the production range audit (valid, floating 0, intrusions 0).
- The `before`/`after` renders were made before this fix. Their 31/43/103 differences (one awning in
  31) are gone in the code.
- Fix round 2 gates: all 15 focused files are green.
  - The fingerprint gate against the re-pinned baseline MATCHes, so the restructure is byte-identical
    and the baseline is not re-pinned again.
  - Zero path against the pre-default baseline: MATCH.
  - Old look: MATCH.
  - Growth-on smoke: 0 NO_TOWN.

## Final review fixes

- **Dead outward code removed:** `lane_sky_gap` (knob and table entry), `KitGrowingFronts.gap_ok`,
  `MAX_LANE_MODULES`, `GAP_KNOB`, the always-empty outward `registry` in `fit`'s result,
  `KitRoomProjections.fit`'s `facing`/`sky_gap` parameters (and `KitVillageBuildings` feeding them),
  and the outward wrapped-corner branch of `BuildingKitAssembler.storey_slots` (unreachable: positive
  wall offsets come only from room projections, one per storey and never on or beside a growth face).
  Tests that pinned the dead behaviour (`test_gap_ok_measures_to_the_facing_lean`, the knob cases) are
  gone or rewritten. Knobs draw per-name streams, so no other draw moved.
- **Unused baked front pieces removed:** the depths are now per piece
  (`KitGrowingFronts.FRONT_DEPTHS`): floor and corner 0.5/1.0/1.5 (what is left of the module), return
  0.5–2.0, return beam 0.25 (the wrapped-corner filler) and 0.5–2.0. Nine pieces were never requested
  and are gone with their oak/walnut copies, meshes, materials, collision, visuals, manifest and
  provenance entries and index rows: floor and corner d025/d075/d200, return d025/d075, return beam
  d075. An instrumented run of all growth tests plus the growth-on corpus requested exactly the kept
  set (corner d050 is reachable through a wrapped 1.5 step). `test_growth_front_family` pins it.
- Gates: fingerprint MATCH against the shipped baseline; old look, odds, room projections, roof
  proportion and all growth files green; growth-on smoke 0 NO_TOWN; corpus 4 faces (fingerprint
  towns) and 19 at chance 1, 0 violations. `test_october3_stepped_wings` is 9/11 at both the plan
  commit 7adf075c4 and here, with the same failing assertions (834/838 asserts both): of the 53/63
  regression houses one is not built under its id and the other has no stepped wing, and 8:grand
  builds no house.014. Pre-existing town drift, not growth.
