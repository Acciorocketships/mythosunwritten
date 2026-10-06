# Interior court frontage ownership — rejected route candidate; retained canopy repair

## Status

The route, plot-priority and flight-support candidate is **not in production**. The accepted `WarrenMazeCarver.gd`, `WarrenPlotPlanner.gd` and `WarrenMazeSourcePlan.gd` were restored byte-for-byte from their pre-iteration backups. The experimental helper and tests are archived here. The original redesign remains active.

The independently reproduced wall-canopy obstruction is repaired in `KitPublicClearance.skywalk_ornament_air` and `KitVillageBuildings`: optional facade ornaments now see late skywalk spans and their landings. These volumes are not roof/wall cutters. Admission still keeps or rejects a complete canopy run, including its end boards. The rejected source layout is frozen in `tests/fixtures/october5-skywalk-hood-source.txt` so the regression does not depend on the live route algorithm.

## What the court prototype established

The previous prototype reserved a real 3×3 interior square but ordinary lower-floor seeds occupied its prospective frontages. Stable priority for the actual admitted plaza's level doorways restores that datum. A second loss occurred at a shared corner doorway: growth absorbed a west-facing seed into a north-facing parcel, then the rectangle packer chose the north rectangle and left the west front as retained stone. Preventing absorption between differently facing protected court seeds keeps both facades.

The initial priority applied to all courts and displaced four covered quarters each in 31/large and 53/grand. The narrowed version only prioritizes a committed square that exactly matches the early `interior_court` proposal. Their source plots then match the accepted generator exactly.

13/grand's final 3×3 square at band 2 has occupied adjacent frontage counts 4/6, 0/6, 4/6, 6/6. 301/grand's 3×3 square at band 7 has 6/6, 0/6, 6/6, 4/6. Native views show planted central space and deck edges, with an inhabited bridge overhead in 301. 43/grand does **not** preserve its proposed interior square: its final plaza is only four columns at band 6 with no majority inhabited side. Do not count that town as a successful interior court.

43's earlier fabric failure was a genuine source/exact-flight mismatch. Room `spatial.parcel.maze.house.004.part00.room00`, origin (-4,7,-1), had four supposed support columns at band 6. Every column was exact `PUBLIC_AIR`, owned by `public.route`, although the macro source reported solid. Transition `volume.transition.12`, (-2,4,-2) to (-2,5,1), reserves the full flight-height clearance interval; the macro bore left material over its lower treads. The experimental source support rule refused such a foundation. The compiler's bearing gate was never weakened. This support rule is archived with the route candidate, not separately shipped.

Focused candidate tests: 3/3, 20 assertions. Existing court tests: 5/5, 74 assertions. These checks proved necessary but insufficient for visual acceptance.

## Broader evidence and rejection

Ten complete towns build, with no floating-mass or public-air audit findings. Covered fine floor quarters rise from 480 to 739; this is a changed route network, **not preservation of all old crossings**. Exact per-town results are in `comparison.json` and `court-scoped-cover.json`.

- Unchanged source plots: 103/grand, 31/large, 53/grand, 63/grand.
- Changed layouts: 13/grand, 301/grand, 43/grand, 83/grand, 8/grand, 9/grand.
- Coverage in 9 decreases 80→71; the other changed towns gain coverage.
- Fitting generated turret count across the sample decreases 18→16. Increased coverage is not completion of the user's spire request.
- After the canopy repair, all 68 sampled skywalk/underpass player traversals and 22 square access/loop traversals pass (90 total).

The native and roof review still rejects the route candidate:

1. 301 produces seven tiny roof sections (two adjacent), and five clipped landmark eave pieces; the accepted roof audit had zero in both categories. See `court-final-roofs.json`.
2. 8 has a five-sample hole in the gable of house.027, as well as an adjacent tiny roof. Its accepted layout already had one gable-hole finding on a different house (four samples) and more tiny roofs: do not describe this as a 0→1 count regression. The changed gable still needs repair.
3. 9's square shows a green ridge/gable tip protruding through its planted bed (`native-final-other/9_grand_court_plaza.00_0.png`). Walking-air clearance excludes the bed, so successful perimeter walking does not certify the whole square surface.
4. The 43 bridge interior still shows roof material above walking headroom in `native-hood-repair/43_grand_skywalk-clear.png`. The canopy blockage is fixed, but that image is not full architectural acceptance.

Native soil/grass beds in this isolated harness are plain green. Do not claim production grass quality was validated.

## Retained canopy repair

Both directions of 43's `skywalk.0` hit `pure_village_wall_hood_middle_finish_walnut_1193`. The measured collision is near world (12.84,6.58,-56.01); the offending placement is `kit.spatial.parcel.maze.house.wall-room.000/k0019`. The span is added after the floor mesh used by `KitPublicClearance.build`, leaving its landing invisible to the ornament callback.

The new check includes each selected span's occupied lanes and both endpoints. It is used only for optional ornaments, so it cannot carve holes in an enclosed bridge's shell. The integration regression first fails on that exact placement, then passes; both player directions and all eight of 43's crossing/underpass checks pass. The frozen fixture also passes after the experimental route source is removed. After restoring the accepted route source, the focused acceptance suite passes 7/7 tests, 171 assertions across four scripts (`hood-frozen-final-tests.out`). This is not a globally green suite.

## Resume from here

Restore `WarrenInteriorCourt.gd` and `test_interior_court_route.gd` to their original paths and apply the three `*-final-candidate.patch` files only for further experimental work. Earlier `planner-candidate.patch` is the overly broad priority variant, not the final narrowed one.

Next resolve whole-court ownership at all heights, including the planted bed; source house and roof reservations must agree before the court is accepted. Protect native roof joints and gable closure when the rerouted network changes parcel shapes. Keep the frontage ownership and exact flight-bearing findings; do not weaken compiler, roof or traversal checks to admit a prettier selected screenshot. Search cost and lost turret opportunities also remain open.
