# River generation and diagonal water contact

The September river revision surveys four candidate hilltops per 768 m source district,
uses an 85% admission roll, and walks a bounded fan of contour-biased directions with
clearance from previous reaches. A gentle outward drift prevents the walk from enclosing
itself. Hydraulic beds remain monotone and contained below both banks, including where
an open cutting passes through rising natural ground. The maximum arc is 4.32 km within
2.4 km of the spring; flat-ground termination starts at 2.64 km.

Channels have a 20–26 m full-depth half-width. This exceeds half a 24 m terrain-cell
diagonal, so diagonal crossings excavate both intermediate cells rather than relying on
corner-only contact. Lakes independently vary in size and elongation within their existing
conservative discovery radius. Junction resolution selects immutable route prefixes, with
raw-bound rejection before dependency expansion; it does not retrace the mountain.

## Measurements

`tests/harness/river_corpus.gd` scans 81 source districts per seed. Before junction
truncation, seeds 991177 / 2697992464 / 314159 yielded 41 / 35 / 40 rivers, with mean
lengths of 2.73 / 2.74 / 2.64 km. More than 90% exceeded 2 km, and mean geographic extents
exceeded 2.3 km. These are planned headwater routes, not a claim that every tributary
retains that length after joining another river.

The full-depth seed-991177 network (`-- --full`) had 41 sources and 14 terminal lakes,
versus 9 sources and 9 terminal lakes in the historical fixture. Eighteen realized rivers
still exceeded 2 km; mean realized length was 1.58 km. Springs add smaller source pools.

The 49-chunk production profiler (seed 3046246887) completed with 170733 ms worker time:
heightfield 494 ms, water context 4872 ms, feature planning 88969 ms, terrain mesh 44385 ms,
water skin 22679 ms, dressing 9334 ms; commit total 1954 ms. This was measured while other
verification processes were running, so it is not an isolated performance comparison.
The profiler also exposed a pre-existing stale `path_program` argument, removed here.

## Reported diagonal seam

Pinned seed: 2697992464. Player: (-225.6, 4.0, -752.7). Crosshair: (-225.6, 4.2, -753.0).
`ReviewCam.solve_cam` reconstructs the reported camera. The false reflective stripe lay
near (-228, 3, -756): a flat, still-wet shelf had free-edge curl normals, some only 0.174
aligned with up. Shelf normals now use the same level weight as shelf heights.
The red-first normal regression failed before the fix and passed afterward. The exact
camera, later animation frame and nearby camera angle were visually inspected.

- [Before](../tests/artifacts/river_review/diagonal-before.png)
- [After, same camera](../tests/artifacts/river_review/diagonal-after.png)
- [After, nearby angle](../tests/artifacts/river_review/diagonal-nearby-after.png)
- [Generated mountain reach](../tests/artifacts/river_review/mountain-river.png)

The isolated renderer is `tests/harness/river_corner_review.gd`; `-- --mountain` selects
new production generation. Historical water traces are frozen in `tests/fixtures/` so
changing generation cannot erase old shoreline, contour, swim and bridge regressions.
Terrain, carving, fill and rendering all remain live. Profile/region caches also now key
by immutable trace and terrain-plan owner, preventing different worlds with the same
source cell from sharing stale hydraulic data.

## Validation

- Final focused water suite: all 127 tests / 29,413 assertions passed. Godot then
  exited with a `recursive_mutex lock failed` error during process teardown (exit 134).
  This is not a clean process exit and is retained here as a verification limitation.
- All 26 planner tests passed, including immutable junction-prefix containment.
- All five new generation tests passed, including actual rendered-field wet width and
  the red-first cache-collision regression. Rerunning them in the merged main worktree
  passed with a clean exit, as did the exact diagonal-normal regression.
- Both preserved historical bridge tests passed.
- The full project attempt reported village asset-UID warnings and failures in dry-fixture
  village/maze composition tests. It also exposed the cross-world water-cache collision
  fixed in this change. The final focused water run supersedes those earlier water
  results; the outdated full-suite process was stopped after recording its failures.
- Code merged into the main worktree as `13cb0221`, preserving the concurrent facade
  edits and combining the water invariants with the other agent's `AGENTS.md` changes.
