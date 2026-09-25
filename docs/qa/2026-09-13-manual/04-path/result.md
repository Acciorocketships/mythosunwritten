# Issue 04 — timber/plaster barrier across P04 ramp

Status: accepted for the photographed barrier and measured regression controls.

Reference: P04, Screenshot 2026-09-12 at 12.00.30 PM. Seed 2697992464, player (-222.4,17.7,-958.4), crosshair (-222.4,19.2,-954.7). The camera is reconstructed through ReviewCam from rounded overlay coordinates and the close-view boom/pivot, FOV 75; original full-precision camera and spring history are unavailable. Fresh pairs use identical reconstructed transforms. Supplemental views and physical traversals are separately identified.

## Diagnosis and options

Native rays identify a complete wall at world Z -954.72, ending at Y 20.08. The ramp underneath rises through Y 18.65. The offending facade belongs to `spatial.parcel.maze.house.001.part01.room00/east`, using native wood/plaster stock. Rounded route addresses reserve the upper band while the continuous ramp still passes through the band below. That lower interval was allocated to a room.

Hiding the wall would leave its collision and expose a house interior. Removing a single panel would open the shell. Moving the ramp changes the authored route. Instead, reserve the complete physical flight band before room allocation: a full room cannot fit into the fractional space below an ascending ramp or stair. Keep all route addresses, source plots and excavation unchanged. Native prefab admission reads the same flight clearance.

## Implementation

`WarrenVolumeTransition.clearance_air_cells()` reserves the intermediate footprint from the lower endpoint band through upper headroom. `WarrenVolumetricSolver` consumes it before parcels/rooms, and `WarrenPlotReservations` includes it in native prefab admission. There are no camera/shader/collision-only changes for this issue.

The fresh canonical source is byte-identical to the original source (`source.txt` vs `current-source.txt`). The final room count is 110 rather than 112: the two records belonging to the incompatible house are rejected. Streets are retained. The surrounding retained masonry and timber remain closed in inspected views. The final support follow-up leaves every photographed-town batch, surface array and collision box identical to the captured candidate (`final-payload-comparison.json`).

## Red-first checks

The photographed test fails before the change: four continuous-air samples are allocated incorrectly, and 42 of 99 actual capsule stances collide with the native wall. The candidate clears all 99 stances. Actual ramp/stair triangle samples test four orientations, both rise signs and both flight types. The final 51 focused tests pass 511 assertions, including the existing volumetric, unified-city and skywalk integration controls.

All six original real-player traversals stop at the barrier (uphill/downhill, centre and ±0.7 m). All six candidate traversals pass. The final mandatory matrix constructs 48/48 towns, retaining 11,868 clear centres and 17,038 clear crossings; 24 historical off-centre pillar contacts remain unchanged.

## Evidence exclusions

The first live candidate looked correct, but its snapshot was saved before clearing the live visibility adapter. Replaying that snapshot lost material bindings and produced white surfaces. `rejected-snapshot` and its differences are excluded from visual acceptance. The harness now clears the adapter before saving and reruns from production. This is a capture fixture error, not evidence of a production material fix.

## Structural follow-up

The first candidate introduced a real regression in seed 9/standard: six retained stone cells depended on a jamb subsequently withdrawn. The existing `test_rock_is_retained_as_stone` exposed it. `WarrenSpatialFabricCompiler` now repeats ground connectivity and local crown bearing until the retained set stops shrinking. This is bounded by the candidate cell count. The six unsupported cells become zero; no bearing criterion is relaxed. The focused test retains this case.

`support-native` contains four native pairs and differences. Angle 0 clearly shows the formerly hanging stone removed, exposing the existing roof beyond. The surrounding houses, bridge and facade remain intact. The other three views are context controls; angle 90 is pixel-identical. Angle 0 mean RGB difference is 1.868/255, with 3.61% of pixels changing more than 20. This isolated diagnostic compares the rejected path candidate to its final support correction, not the original photo build.

## Native visual judgment and pixel differences

`walk-before` versus `matched-after` supplies the three matched close views (0, ±8°), with original lighting copied into both replays and frozen animation. All three remove the transverse plaster/timber wall and leave a continuous ramp into the landing. The left masonry and right facade remain closed. Whole-image mean absolute RGB differences are 0.7709–0.9599/255. In the barrier region, differences are 7.67–7.80/255 and 19.08–19.43% of pixels change by more than 20. These measurements locate the repair; the six actual walking passes prove traversal.

`wide-before` / `wide-after` supply six additional full-world context pairs. Four are obscured and are not credited as direct evidence of closure; 180° clearly shows the repaired route. `closure-native` supplies four closer native context pairs. The 180° view shows the continuous route and preserved side walls; 90° and 270° are obscured controls. No hidden or sliced meshes are used. An unchanged visibility adapter is disabled for these architectural comparisons.

The full composition suite retains exactly the same 19 failing test names as the isolated unchanged baseline (69/88 tests pass, 8,591/8,657 assertions). Some already-failing geometry census values change; this is not full-suite acceptance. The new unsupported-stone failure is gone. The final fingerprinted corpus gate passes 95 assertions. No test pin was loosened. Native timings are not a performance claim.
