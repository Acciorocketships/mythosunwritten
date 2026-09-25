# Inclined broad cliff terraces

The preceding revision curved ledges along the wall but left their treads level from back to front. This follow-up gives selected broader Nature-profile terraces shallow outward grades (6–14%, reduced where the next shelf limits clearance). Their existing varying elevation paths remain, so a terrace can bend along its length while also inclining outward. Smaller stone shelves retain resting treads. This preserves distinct rock projections while avoiding one universal shelf orientation.

Production `scripts/terrain/field/CliffRockCrags.gd` matches `tests/fixtures/september17/cliff-shelf-edges/broad-slopes.gd` byte-for-byte. The convex corner consumes the same geometry. The lowered lip keeps its measured depth; recomputing depth at the new elevation had fragmented coherent grass support in the prior rejected experiment. The available vertical interval bounds the lip drop. Turf and collision share the actual altered triangles; grass still uses its strict physical support checks.

## Red/green evidence

The new depthwise-slope test uses the 31 saved photographed formations, seed 2697992464. Before this change, none of their turf area had a depthwise grade above 3%, failing the requirement that inclines occupy a meaningful part of the shelves: [red.log](red.log). Existing along-wall curvature checks remain unchanged.

The selected geometry has 93.561 m² of inclined turf out of 258.067 m² (36.3%). Nineteen of 27 substantial connected shelves change elevation; 18 of 27 change along-wall slope. This measures real cap triangles, not shader normals. The existing prominence test remains unchanged and passes.

Final checks: **32 tests / 594 assertions pass** in [final-tests.log](final-tests.log). Six actual grass patches retain complete support, with zero escaped or buried samples and identical chunk ownership. Straight-photo recession remains 0.6762 m, crown excess zero, and wide-tread area 90.355 m². This is a focused run, not whole-project acceptance. It covers real grass-worker roots and ownership, actual closed straight/corner collision, 16/32/64 m corner closure, crown clearance, lower bearing, native attachments, public/wet exclusions, finite turf and independent rock projections. The existing macOS certificate-loader diagnostic precedes GUT.

## Experiments not selected

- `candidate.gd`: smoothing the imported horizontal section samples produced little useful visible improvement; production does not contain it.
- `sloping.gd`: inclining narrow and broad shelves together reduced a distinct physical projection (7 to 6 in the unchanged prominence check).
- `supported.gd`: iterating the lowered lip against the deeper body did not recover that projection; not selected.
- `broad-slopes.gd`: inclines on the broad terrace family preserve the seven measured projections. Smaller carved shelves remain level across their depth, while their paths still slope and curve along the wall. No prominence threshold or other historical assertion was weakened.

## Native visual review

The native context harness captured 17 selected views in [selected/](selected/), reconstructing the four original reported poses and their alternatives through ReviewCam. Four selected views were inspected directly: P12_side, P05_reported_0, P12_reported_0 and P20_oblique, against the preceding pass and the rejected all-shelf-slope candidate. The lower terraces gain shallow inclines without changing the overall cliff extent. The final 64 m control generated five views in [selected-tall/](selected-tall/); front and ledges were inspected directly.

The replay regenerates the rock/plant geometry inside an earlier frozen world. It does not establish fresh-world streaming, hydraulics, performance or actual-player traversal. Some turf endpoints remain angular. The repeated native vertical/horizontal relief is still especially apparent on tall walls, and broad soft faces remain below the owner's reference standard. This is a further geometry step, not overall cliff-art acceptance.
