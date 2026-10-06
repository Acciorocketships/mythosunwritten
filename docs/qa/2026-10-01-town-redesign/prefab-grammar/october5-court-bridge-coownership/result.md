# Interior square / bridge co-planning — active candidate

The working tree currently contains the resumed interior-court prototype (three archived patches and `WarrenInteriorCourt.gd`), plus the repairs below. It is NOT yet accepted as the production layout: the completed wider checks below still contain unresolved roof and wall-room findings. Do not mistake this document for full art acceptance or restore it blindly.

Previous goal turn: verified palette/grass progress. This turn changes the candidate layout and adds independently failing regressions.

## Two reservation defects and a late bearing loss

43/grand originally proposes nine court columns at floor7, but preview lost its eastern room frontage. A rounded lower stair tread passed the coarse reserved-band check while its full compiler clearance removed a reserved house bearing. `stride_cells` now checks `WarrenVolumeTransition.clearance_air_cells` against construction reservations. Red-first 1/3 assertions failed; 3/3 then pass.

The proposed square then survived preview but disappeared at final plot reservation. Both eastern frontages had become committed bridge endpoint houses, and the square classifier counted them only as blocked columns. `_bridge_house_fronts` now counts the exact lower/upper room intervals promised by the bridge proof, preserving both square and bridge. A focused false-to-true test also rejects imagined full-width upper facades and rooms above the actual top.

The square now survives, but the first compilation exposed a late wall-room problem. `house.wall-room.004` occupied column(-2,-1) floor1..4 below a public street while `bridge.01.end.0.lower` stood at7..10. `solid_at` then erased band6 (not carved), leaving the bridge house unsupported. The frozen failed layout is `tests/fixtures/october5-court-bridge-bearing-source.txt`, signature `4c0d5e662ffbcdaddf500068e81788fbdd17edcd8007c3516aa5705aed302e9b`. The reusable bearing probe identifies the conflicting plots and every band. A wall room may no longer use a terrace cap below its upper house's required support datum. This preserves the existing full-height support rule; it does not relax the compiler.

## Current evidence

- New bridge-frontage and flight tests: 2 tests /6 assertions pass.
- Frozen wall-room regression and actual13/43 interior-square integration: 4 tests /25 assertions pass.
- The finished43 square passes the three-majority-inhabited-side test and native renders with a bridge overhead and 227 actual grass instances.
- Native overview and player-height court views inspected. Existing wider issues remain, including facade variety and spire supply; this town has one accepted generated tower.
- The first native render failed on the compiler assertion and was explicitly stopped (session2880, exit143). It is not counted as visual evidence.
- Wider checks completed with the results below. Original goal remains active.

Rollback references: the three pre-resume source files are in `/tmp/october5-court-resume-before/`. Additional edits are confined to the flight check in `WarrenPassageLatticeRules`, bridge-frontage counting in `WarrenPlotReservations`, and terrace-cap guard in `WarrenMazeSourcePlan`. Diagnostic trace prints were removed.

## Completed broader checks

- Candidate43 actual-player traversal: courtyard routes 4/4 and separate skywalk/underpass routes 14/14, both directions; 18/18 total pass.
- Expanded frozen bearing proof: 2 tests /5 assertions pass, including restoring the missing bearing and sealing the upper parcel.
- Ten-town survey: all ten build; 492 roofs, 244 houses, 126 compound houses. Two tiny roofs and two gable-hole findings remain; exposed open ends, unsupported air and cut eaves are all zero. Candidate43 has one gable-hole finding requiring diagnosis. Seed8 has one tiny roof and one hole; seed103 has one tiny roof.
- Flight/frontage plus existing wall-room tests: 6/7 tests, 90/91 assertions. `test_short_wall_rooms_keep_roof_clearance_below_setback_houses` expects a short terrace wall room in 2/grand, but this candidate produces none. This failure has NOT been baseline-proved and remains unresolved.
- The candidate stays applied for further iteration, without production/art acceptance. Next gates are the43 gable finding, the2/grand wall-room regression, and renewed crossing/spire/public-air corpus checks.
