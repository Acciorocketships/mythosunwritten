# Village camera stalls — verified scope

The reproduced camera workload is repaired. Visibility no longer reads back or
copies placement buffers or native mesh geometry when the camera turns. Shared
source materials are adapted once, per-instance strength preserves independent
fades, and a bounded history retains compiled shader programs across turns.
For multi-surface batches, reversible render-material bindings retain the native
mesh and live producer buffer. Source resource materials and physics stay intact.
The last selected owner restores the render binding, including after node deletion.

## Brainstorming and rejected approaches

Input loss, streaming holds, physical collisions and camera work were measured
independently. Copying only single-surface batches, then retaining live batches
while still duplicating their meshes, did not sufficiently reduce recurring
stalls. Both were rejected. The final implementation removes both data copies;
[iterations](iterations.md) retains the measurements and rejected claims.

## Timing and movement

All timings below are camera-update CPU time, not total frame rate. The frozen
production-town replay uses 180 physics samples for each implementation at each
of the four screenshot pins. The final camera p95 comparison is:

| View | Original | Fixed |
|---|---:|---:|
| 6:37:38 village | 11.153 ms | 4.381 ms |
| 6:37:47 block | 7.696 ms | 3.970 ms |
| 6:38:05 bubble | 6.296 ms | 3.458 ms |
| 6:39:15 black-screen position | 5.168 ms | 3.210 ms |

The live-world replay includes grass and actual streaming. At the last pin,
720 samples / nearly three camera revolutions per variant reduce camera p95
from **12.531 to 2.594 ms**, and maximum from 85.586 to 41.418 ms. The maximum
fixed update is initial adaptation; initial work is not free. The original,
fixed and fade-disabled walks travel 80.533, 80.534 and 80.541 m respectively.
They all have the same 110 stopped samples after warmup and the same actual
building/stair contacts. Held requested movement never becomes zero, and no
streaming-frozen samples occur. No physical collision is removed to make the
character walk through a building.

The frame cap is 30 FPS. Live wall-clock tick intervals have p95 31.621/31.770 ms
and maxima 86.080/95.364 ms (original/fixed). These numbers do **not** establish a
whole-game frame-rate improvement. Startup remains expensive at 128.432 s.
This accepts the reproduced camera stalls on these routes; it does not establish
the cause of an unrecorded native focus loss or promise universally stall-free
streaming. The screenshot pins alone do not encode the owner's original input
sequence. Existing native held-input/capture checks also pass.

## Matched images and pixel judging

`render-bindings/poses.json` records all reconstructed transforms. The original
F3 values are rounded to 0.1 m, so full-precision original camera recovery is
impossible. Each before/after pair uses the same reconstructed transform.
Twelve frozen-town pairs cover four photo views and ±8° alternatives. Their
maximum mean RGB difference is 0.000314 levels (0–255), with at most 0.001013%
of pixels changing over 20 levels. Visual inspection of all paired views and
differences finds preserved native silhouettes, surfaces and visibility coverage.

Three additional live-world pairs restore actual biome colour, grass and live
materials. Mean RGB differences are 0.067–0.234 levels; at most 0.001303% of pixels
change over 20 levels. Inspection finds small dynamic shading differences,
without changed building geometry or corrupted black regions. Earlier direct-window
captures showed black corruption, but subsequent original runs did not. Issue 2
later found that the inherited capture helper read before frame completion;
those captures therefore cannot establish an in-game reproduction of the
intermittent corruption. Acceptance remains separate under issue 4.

Local evidence:
- `render-bindings/diff/contact.jpg`: all twelve before/after/difference rows.
- `render-bindings/diff/metrics.json`: frozen pixel metrics.
- `live-world/diff/`: live comparisons and pixel metrics.
- `render-bindings/movement.json`, `live-world/movement.json`: per-sample input,
  actual collider shapes, freeze state, elapsed time and profiler subphases.
- `village-no-grass.scn`: original frozen geometry/physics fixture.
- `village.scn`: later snapshot including live grass at the loaded site.

## Tests

Red-first ownership tests fail on the original buffer/mesh-copying paths.
The final **29 tests / 263 assertions** pass together in the native renderer,
with exit 0. They cover the existing camera, controls, obstruction and projection,
source synchronisation, shared live buffers, independent fades, cache retention,
restoration after node deletion, and actual shared-mesh rendered pixels. The last
render test requires the unselected object to be pixel-identical and restoration
to reproduce the complete original image.

Two earlier compact native runs passed assertions but crashed at shutdown;
suite isolation and the final six-suite run exit cleanly. This historical result
is retained in the iteration log rather than represented as a passing process.
No engine-wide shutdown repair or globally green game suite is claimed.
