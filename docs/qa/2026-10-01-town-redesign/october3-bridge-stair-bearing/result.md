# October 3 bridge stair bearing

The previously failing 4/large town now builds. Source bridge admission had
accepted a lower endpoint house at band 6 above source-solid band 5. A later
fine-grid stair from (0,3,-3) to (0,4,0) reserves band 5 for clearance, leaving
all four foundation quarters in public air. The compiler correctly rejected it.

`WarrenMazeCarver._bridge_foundation_is_direct` now checks the lower room and
its bearing against `WarrenVolumeTransition.clearance_air_cells`, including
main-route, lane and loop transitions. This uses the downstream clearance
kernel; it does not shrink stairs or weaken the compiler's foundation check.
The invalid endpoint is rejected early and ordinary generation can use the site.
Temporary compiler diagnostics were removed, restoring that file exactly.

Validation:
- New focused regression: 2 tests, 6 assertions pass, including 4/large generation.
- Existing whole-or-absent passage-cover test: 1 test, all 43 assertions pass
  (previously 42/43 because 4/large failed to build).
- Nine-town native-kit audit: all build, zero floating masses and roof-air
  intrusions. The eight previously valid towns retain their cover counts:
  7/standard 36,31/large 18,13/large 42,43/grand 68,58/large 14,
  101/large 24,103/grand 40,211/grand 92. Repaired4/large has40 quarters.
- Actual player traverses the affected stair in both directions,2/2.
  The harness's new `--flight from:to` option requires a published transition.
- Native 4/large overview and passage rendered; passage shows an enclosed
  timber-soffit corridor with a clear route. This is a support regression fix,
  not acceptance of all remaining town silhouettes or architecture.

Broader enclosure, long compounds, Gothic stone composition, full-world review
and baseline full-suite failures remain open.

Quiet real-terrain production gate passes:1test,125assertions,6804ms town
generation against the unchanged8000ms ceiling. `git diff --check` passes.
