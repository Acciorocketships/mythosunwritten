# September 11 manual review

Work proceeds individually: reproduce, brainstorm, failing regression,
implementation, matched rendered comparisons, pixel differences, nearby and
behavioral falsification, then acceptance before advancing.

The initial working tree contains the September 10 review's uncommitted fixes.
They form this review's baseline and must be preserved.

## Queue

1. Village movement stops and lag — reproduced camera stalls repaired; route/visual verification accepted with scope in `01-movement/result.md`.
2. Larger circular visibility bubble with explicit nearby ground preservation — accepted; see `02-bubble/result.md` (two invalid live nearby captures excluded).
3. Tactical movement-follow orbit; close-view mouse look and centre crosshair — accepted; see `03-controls/result.md`.
4. Black screen corruption during repeated village orbit — resource-ownership repair accepted on the reproduced case; 4,682 marked embedded frames and 14 judged pairs, with limits in `04-black/result.md`.
5. Unsupported floating block — accepted for the reported visual/construction defect; 12 live pairs, 16 native pairs, 48/48 towns. Timing limitations are explicit in `05-floating/result.md`.
6. Building silhouette variety, projections, dormers and porches — accepted for geometry/visuals; timing remains unresolved, see `06-variety/result.md`.
7. Unnecessary protruding roofless cells — independently verified as repaired by issue 5; 16 fresh native pairs, 12 live comparisons, 6 tests / 157 assertions; see `07-roofless/result.md`.
8. Connected skywalks and meaningful half-storey support — accepted for construction/visuals; 38 judged pairs, 48/48 towns, timing limitation in `08-skywalk/result.md`.
9. Prefab integration and freestanding compatible town sites — accepted; 32 native recipes retained, extra supported source sites, 54 credited image pairs, 48/48 towns and 95/95 composition assertions; limits in `09-prefabs/result.md`.
10. Unified ground/warren allocation and reduced perimeter-ring composition — accepted, including the floating grass and isolated skywalk tower follow-ups; 48/48 towns, 11,868 clear positions / 17,038 crossings, 42 tests / 9,081 assertions and 95/95 composition. Four invalid live captures remain excluded; see `10-unified-city/result.md`.
11. Native cliff terraces/outcrops on faces and both corner types; sparse rocks — accepted for inspected geometry and site; 66 judged matched pairs, 8 tests / 283 assertions and 128 orientation/seed cases. Three historical cliff-corner tests remain red; see `11-cliffs/result.md`.
12. Biome-specific terrain forms and height variation — accepted for the implemented vocabulary and inspected sites; 90 landmark pairs, lake/bar/arch physical surveys, 64 tests / 10,009 assertions, 7 material tests / 47 assertions and ten real-GPU controls. Coarse contours, restrained valleys, clear cascades and expensive loading remain; see `12-landforms/result.md`.

## Camera evidence

Four game screenshots use seed 2697992464. The overlay supplies player and
crosshair world positions rounded to 0.1 m, not an exact camera transform.
ReviewCam.solve_cam reconstructs the orbit using the production 26 m distance,
16 m height and 1 m look offset. Before/after replays share the resulting exact
transform. Original full-precision screenshot agreement cannot be claimed.
The fifth image is an art reference, not a replayable game capture.

## Issue 1: candidate causes

- Lost input/capture or GUI focus: compare requested move and native input state.
- Terrain readiness: record the production player-frozen flag throughout walking.
- Collision: retain actual slide collider paths and normals at stopped positions.
- Visibility work: measure real camera update time with and without its bubble,
  while orbiting through the same town.

Initial replay: camera work reaches 34.155 ms (village-view p95 12.183 ms),
versus 0.046 ms p95 with fading disabled. No route records a terrain freeze.
Stops on three of four replay paths agree with fading disabled and have real
village collision contacts; this does not establish the cause of every manual stop.

The first candidate keeps single-surface MultiMeshes intact and applies a
geometry-instance material override. The prior implementation reads back and
copies their whole buffer whenever selected. The failing regression records
three failed assertions before the change. Afterward, the focused run passes
16 tests / 126 assertions. Live producer ownership is preserved by the fix.
Multiple-surface batches retain their separate material path.

Final issue-1 implementation and evidence: [result](01-movement/result.md).
Candidate failures and diagnostic limits remain in [iterations](01-movement/iterations.md).


## Issue 12: final scoped result

Seven continuous biome profiles, higher mountain relief, retained lake islands and
peninsulas, low alluvial bars, and closed natural arches are implemented and
checked. The native-only town compatibility repair passes the required 48-town
corpus and 95-assertion fingerprinted gate. Final evidence and excluded captures
are indexed in [the terrain result](12-landforms/result.md).

All twelve queue items now have individual results, including the later floating
grass and isolated skywalk-tower follow-ups in issue 10. This closes the requested
review pass in each report's measured scope; it does not turn historical baseline
failures or costly cold startup into passing claims.
