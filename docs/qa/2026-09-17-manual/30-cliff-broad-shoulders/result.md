# Upper ledge slopes — scoped selection

The selected production change gives all nine generic finite ledges the same deterministic resting/sloped tread family already used by the Nature-profile terraces. Their fourth cut value now comes from `_tread_grade`; existing curved depth interpolation supplies the tread surface. The body, foot, crown, depth and colour formulas remain unchanged. The rendered `graded.gd` fixture differs from production only by a two-line explanatory comment.

This is a limited improvement to upper tread curvature, not acceptance of the overall cliff composition. The larger shoulder experiments below were rejected.

## Rejected shape experiments

- `candidate.gd` varies upper shelf strength from 0.65 to 2.3 and adds grades. P20 develops a larger boxy block despite passing the local check.
- `recessed-body.gd` recesses the broad core and reduces mass depth. It exposes excessive repeated native backing while retaining boxy formations.
- `balanced.gd` uses milder 0.8–1.5 strength variation. The upper broad-tread fraction is 0.4014, below the existing 0.45 bound; its silhouette remains slab-like.
- `spread.gd` adds widening lower bearings beneath generic caps. It still reads as broad slabs, misses the broad-tread fraction and retains only six of nine reported notch turf contacts.

All are archived under `tests/fixtures/september17/cliff-broad-shoulders/` with their native images and logs here. The first two studies retained the old corner recipe; balanced, spread and graded use corresponding corner fixtures. None of the rejected shape changes is in production.

## Regression evidence

The new actual-geometry upper-shelf test first fails on the preceding production fixture: only 17.742568 of 74.296889 square metres of upper turf incline across depth (23.88%). The selected change produces 46.262191 of 77.855357 square metres (59.42%). Broad upper treads retain 36.309764 square metres; thirteen formations have substantial upper turf. The unchanged bounds require more than 35% inclined and 45% broad area.

The first combined run passes 50 of 51 tests, with 2,669 of 2,670 assertions (`final-tests.log`). Its only failure is the historical exact-height prominence probe. `prominence.log` and `prominence-height.log` isolate an existing projection whose sloping lip moves through the 12 m sampling plane: at 11.9 m its prominence remains 0.505835 m, above the unchanged 0.45 m requirement. The probe now samples offsets -0.1, 0 and +0.1 m, half the physical mesh step, counting each horizontal location once. It retains the original magnitude and count thresholds. The corrected probe finds two original versus eight current prominences. The two-test follow-up passes all five assertions (`section-tests.log`). These are separate runs, not a single clean 51-test run.

Other passing checks include all 31 closed, nondegenerate photo shells, nine of nine notch turf contacts, 62 broad treads, 55 sloping and 62 curved treads, rooted collision, protected crown clearance and unchanged mass continuity bounds. Thirteen current worker grass roots are supported, with zero escaped or buried roots; altered slopes change the viable planting count.

## Native review and limits

The selected `graded/` replay contains seventeen saved-camera views. P20 oblique, P12 side, P05 reported alternate and P17 front were inspected. Five native 64 m tall-study views were generated; the oblique view was inspected. Full-height attachment remains, but repeated native relief and vertical organization are still conspicuous.

A fresh production P12 capture waited for terrain, feature commits and grass. All three [saved views](fresh-P12/P12_0.png) were inspected, including the alternate angles. Pointed turf coverage and curved caps survive production generation. Foreground formations remain coarse/angular and some faces too smooth/upright; this is not the final desired art direction.

Fresh startup was 487.436 seconds, with other work running concurrently, so it is not a controlled performance comparison. No player traversal, full-suite or global performance acceptance is claimed. Shared warm/cool stone colour from pass 29 is retained unchanged.
