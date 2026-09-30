# September 27 town scale, canopies and closures

Owner report, seed 2697992464 (F3 player / crosshair world positions):

1. Canopies on ramps and misaligned with buildings — site 1 (329.6,14.4,1088.9).
2. Gaps / missing walls — (1252.5,24.0,526.8), (1261.3,24.0,546.7),
   (318.4,18.9,1074.3), (1210.9,24.5,579.3).
3. Towns too small; stay aligned to the terrain grid.

Site 1 is city seed 1260018864828801968 (compact, frame centre (312,1056));
site 2 is 2695877283924445960 (compact, centre (1224,528)). Both towns keep
yaw 0; old frame origins (310.5,12.08,1080.5) / (1222.5,24.08,552.5), new
(310.0,12.08,1088.0) / (1222.0,24.08,560.0). "Mapped" after-cameras are the
before-cameras carried through old frame -> lattice -> new frame, so each
pair shows the same architecture at the new scale.

## Changes and root causes

### Scale (4/3, grid aligned)
`VillageWorldScale`: `KIT_WORLD_SCALE` 2.0; `HORIZONTAL_SCALE` 8/3 and
`VERTICAL_SCALE` 2 are now derived from the kit metric (2 m module, 1.5 m
band). Fine cell 4 m, macro 8 m (three per 24 m terrain cell), band 3 m,
storey 6 m; `validate()` pins those. Everything downstream already read the
constants (render, collision, occupancy, supports, terrain grade lattice,
gate handoffs, outskirts grid). Stair risers stay legal because flights add
treads (`WarrenTransitionSurfaceBuilder.MAX_STAIR_RISE` divides by
`VERTICAL_SCALE`); the stair-walk test now measures risers with the vertical
factor and walks a flight built in the real frame. Kit roof geometry, the
roof bake and `KitRoofMeshUnion` work in native metres and are unaffected.
Harnesses (`kit_town_review`, `town_passage_collision`) read the frame
instead of hard-coding 2 / 1.5.

Record discovery: the scaled towns reach farther from their site. A probe of
10 large + 10 grand towns found grade-collar reach up to 191.5 m (it was
already ~137 m before, beyond the old 120.6 m layout radius). Discovery now
covers the whole 192 m settlement inset (`VillageProgram.WARREN_RECORD_REACH`
feeds `max_record_radius` and `layout_record_radius`). This is measured, not
proved: a rarer town could still exceed it. A field span clip that would have
guaranteed it was tried and rejected (it cut ~90% of grand fields and failed
the open/dense layout test).

Legacy outskirts (not run by `VillagePlan`, which sets `outskirts = null`):
the branch corridor now scales with the outskirts grid.

### Canopies (issue 1)
Root causes: the canopy role placed the 3.8 m-wide four-post lean-to at a
uniform fit, 1.48 modules wide, overhanging neighbouring modules; and the
designer only checked that no building stood in front — never what the posts
stand on — so canopies landed on stair flights, gate approaches and open air.
Fix: the `awning` role anchor makes the canopy exactly 0.96 of one wall
module, centred, back posts on the wall's outer face (`BuildingKit.wall_face`,
`awning_*`). `BuildingDesigner._add_awning` admits it only where its whole
footprint is walked public floor at the storey band, outside every STAIR
claim and raised gate flight (`KitVillageBuildings.flight_columns`), then
spaces canopies so perpendicular faces never overlap (previously only lot
houses did). Doorstep props use the same level-ground rule.
Red-first: `tests/test_town_canopies.gd` failed on the baseline (72 too-wide,
62 on flights, 8 on gate flights, 42 legs off floor, 4 overlaps across five
towns) and passes now.

### Gaps / closures (issue 2)
- Deck over a raised lawn (318,19,1074): a structural court one band above a
  retained terrace was measured against the envelope ground (band 0), so no
  retaining skirt was emitted and posts ran through the lawn.
  `SettlementFabricAssembler.effective_support_base` now bears on the retained
  terrace beneath; the skirt closes the band and posts stop on the lawn (or
  vanish when the court sits on it). Red-first
  `tests/test_town_court_enclosure.gd` (7 open faces + piercing posts on the
  baseline) passes.
- Windows in retaining walls (1252,24,527 and site 1 podium): retained
  terrace masses inherited the default WINDOW opening; they are now plain.
  Facades whose lower band is backed by retained ground or another building
  (`BuildingDesigner._lower_band_backed`) are also plain.
- Rail board stuck on a wall beside a ramp (1210.9,24.5,579.3): flight guards
  were clipped only against legacy recipe wall boxes, which the kit replaced.
  `PublicRealmSurfaceSolver` now also clips against inhabited room cells and
  retained terrace cells (the kit draws walls there). The left stub is gone;
  a right rail that runs from the open approach up to the house corner remains
  (it is a legitimate guard ending at the wall, see open items).

## Evidence (this folder)
- `scale_plan_site1_before_after.png` — same plan camera, old vs new frame.
- `canopies_kit_before.png` / `canopies_kit_after.png` — every canopy of both
  site towns (kit review, flat ground); before: canopies over flights and wider
  than their module; after: one module, on flat floor.
- `site1_before_after.png` — in-world, rows s1_wide / s3_close / s3_wide,
  left before, right mapped after: canopy off the stair, podium windows gone,
  the deck's band above the lawn closed.
- `site2_before_after.png` — in-world s4_e / s2a_wide / s2b_wide mapped.
- `site2_s4e_kit_before_after.png` — kit review at the in-world frame (retained
  cells tinted in the after), left rail stub removed.
Full render sets: session scratchpad `town/before`, `town/after`,
`town/kit_*` (not versioned).

## Tests
Focused files, baseline clone vs changed clone (other agents' concurrent
cliff edits intermittently broke compilation of the main tree, so both runs
used frozen APFS clones of the same tree, differing only by these changes):
all of test_building_kit 8/8, test_kit_roof_junctions 8/8,
test_town_architecture 11/11, test_town_layout_field 6/6, test_town_depth 4/4,
test_warren_village_scale_profile 9/9, test_village_gate_handoffs 1/1,
test_september13_street_handoffs 3/3, test_september22_* 10/10,
test_warren_massif 17/17, test_village_frame 3/3, ten rail/guard files
unchanged, test_town_canopies 2/2 and test_town_court_enclosure 2/2 (new).
test_september7_stair_walk: baseline 1/2 (stale horizontal-scale riser
check), now 2/2. test_village_program 1/2 on both (baseline failure).
test_village_outskirts_solver 11/12: the legacy outskirts can no longer place
an SFV compound prefab on the synthetic unconstrained edge at 8/3 (entrance /
setback rejections); production does not run this solver. Pinned updates:
record radius (test_village_frame), P15 end post may now sit inside the kit
landmark wall (test_september19_prefab_stair_guards), outskirts L fixture
expressed in grid steps. Broader run, identical failing test names on both
clones: test_settlement_fabric 51/53, test_village_outskirts_construction 1/2,
test_village_plan 3/3.

## Second pass (coordinator follow-up: close every reported gap)

Round-2 baseline = the tree after the first pass; both runs used frozen APFS
clones of the same tree differing only by these changes.

1. **Overhead gap (1210.9,24.5,579.3).** Not an eave corner: the occupied
   bridge-house over the lane (`kit.spatial.maze_bridge.00`) had no
   terrain-bearing room, so its lowest floor was the house datum and the
   assembler never closed its underside. From the lane one looked straight
   into the room: pale inner wall faces, the gable's inner timbers, sky
   through the far gable. `KitVillageBuildings._mass_for` now marks any
   storey at the datum that hangs over public/daylight air as `soffit`; the
   existing soffit closure boards every cell with nothing solid below.
   Red-first: `test_town_closures` (4 cells without a soffit on the baseline).
2. **Low stone stub (1261.3,24.0,546.7).** Not terrain: the finished grade
   around the town's retained faces is flat at the datum (probe of site 2's
   finished graded terrain: all 77 ground-level retained faces meet it at the
   datum; none is buried or partially buried). The one-band retained course was tiled from Suntail's
   `Stone_Base`, a corner plinth with a taller pier at one end (2.32 m on a
   2 m module, asymmetric): the pier repeated at every module and jutted past
   one run end -- a gap-toothed wall with stepped ends. Courses standing on
   the ground now sink a full storey stone panel one band (same masonry as the
   storeys above); floating one-band courses use the same panel at half height.
   Red-first: 86 plinth-tiled course modules on the baseline, none now.
3. **Lawn corner post (1252.5,24.0,526.8).** At every convex kit wall corner
   the two panels' top beams stopped short of each other and the two edge posts
   stood side by side, leaving a stepped notch under the rail/cap. The slot that
   owns the corner at its right end now emits one timber post flush with both
   outer faces up to the top beam (all kit storeys, courses included).
   Red-first: 44 retained corners without a post on the baseline.
4. **Right ramp rail end.** The rail was clipped at the wall face and its tip
   post, centred on that face, was clipped away with the wall. A tip post that
   would not survive is now seated half a post in front of the face; guard
   clipping boxes for kit room/retained cells are grown by the kit wall's
   outer-face projection so the rail stops at the visible face. Posts under a
   floor underside keep their position (test_september19_rail_floor_joint).
   Red-first: unit case in `test_town_closures`.
5. **Prop scale.** Choice: keep player-sized props (barrels, crates, buckets,
   bags, benches, chairs, lanterns, potted plants, flowers, mushrooms) at their
   pre-upscale world size, because the player did not grow: at 2x a Suntail
   barrel was 2.4 m, taller than the 2.24 m player capsule. Legacy catalog
   props stay at 2x (`VillageWorldScale.human_prop_compensation`), kit
   doorstep/deck props at 1.5x (`BuildingKitAssembler.prop_scale`).
   Architecture-sized civic features (market stalls and goods, wells, fires,
   planters, canopies, window boxes) keep scaling with the town.

Evidence (this folder): `r2_bridge_underside_before_after.png`,
`r2_ramp_rail_before_after.png`, `r2_lawn_corner_before_after.png`,
`r2_course_before_after.png`, `r2_props_before_after.png` (kit review,
flat ground, same cameras), `r2_inworld_before_after.png` (streamed world at
site 2, rows: owner's lane view, looking up at the bridge, lawn corner,
course front, course side; left before, right after).

Tests (round-2 baseline | after): test_town_closures 0/4 | 4/4; every other
focused file identical, including canopies 2/2, court enclosure 2/2, the ten
rail/guard files, kit/roof/architecture/layout/depth/scale/stair files;
pre-existing failures unchanged: village_program 1/2, settlement_fabric
51/53, village_outskirts_solver 11/12.

## Open
- Items 1-4 of the first pass's open list are closed in the second pass
  (the first-pass diagnoses of the overhead gap and the stone stub were wrong;
  see above).
- The lawn's own rail stays inset from the retaining wall face (it follows
  the turf edge); the corner post closes the wall, not the rail line.
- Record reach is measured (≤ ~191.5 m), not guaranteed.
- Legacy outskirts compound-prefab test above.
