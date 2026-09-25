# Native cliff terraces

Accepted for the inspected faces, corners, native contacts and production site.
Nine existing KayKit hill columns now participate in ordinary terrain construction,
including Hill_4x2x4. Complete native meshes keep their proportions and collision.
Grass caps use the existing terrain material and continuous biome tint. Wider,
shorter ledges alternate with slender tall columns; occasional native rocks sit
on their supported tops.

## Choice and implementation

Considered freely floating shelves, rescaled cliff slabs, and complete native
ground-rooted columns. The last option supplies real lower support and preserves
the authored silhouettes. A source-cell halo arbitrates face and convex/concave
corner proposals deterministically. Their full footprints must straddle the wall
and flat lower ground, stay below the upper turf, and avoid public/graded space.
Wet-foot rejection follows arbitration so local water coverage cannot change a
neighboring chunk's winner. Placement and collision use detached CPU values;
resource preparation and grouped MultiMesh construction remain on the main thread.

The initial regression failed all seven assertions before asset registration and
placement. A later wet-foot regression found thirteen columns in a flooded test
footprint; the final exclusion removes them. Initial test API parse errors are not
credited as red evidence. `wet-red.log` contains the actual 13-versus-0 failure.

## Rendered evidence and judging

- Eighteen baseline/candidate face, outer-corner and inner-corner pairs in
  `candidate-differences`, all judged. Pixels changing over 20 RGB levels occupy
  **0.99–2.00%** of each frame; changes follow the outcrops.
- Eighteen additional seed-1 pairs in `rock-differences`, all judged, plus eighteen
  close native views in `native-details`. The rocks contact the turf; native columns
  meet lower ground and remain embedded in the wall. Changed coverage is
  **0.66–1.81%**. The before images omit only the new construction data.
- Eighteen matched production-site pairs in `world-differences`, all judged.
  Twelve columns in four native batches dress real nearby cliffs. Four views
  obscure the nearest outcrop behind its parent ground and are context only;
  the other views expose the added geometry. The frozen loaded-world boundary
  appears in some views on both sides. This is not evidence of infinite terrain
  coverage. The before side hides those four new batches in the same snapshot;
  existing nature rocks remain visible. `world-audit.log` records the exact batches.
- Twelve matched photo/nearby pairs in `photo-differences`, all nonblack and judged.
  The town is unchanged; changed coverage is **0.05–0.16%**, predominantly independent
  ambient particles. These compare the accepted issue-10 snapshot with a freshly
  generated final snapshot. The four supplied player/crosshair pairs still feed
  `ReviewCam.solve_cam`; all paired transforms agree. The original rounded 0.1 m
  overlays cannot recover the original full-precision camera. The fifth image is
  an art reference without a game camera.

All **66 paired camera transforms** match exactly. Pixel counts are inspection
aids; geometry, actual collision and contact checks establish support. Frozen
world tint differs from live atmosphere, so those comparisons establish geometry.

## Checks and limits

- **8/8 new tests, 283 assertions** pass: catalog, all three cliff kinds,
  actual native top physics, complete feature exclusion, wet feet, chunk ownership,
  detached-worker identity, and supported sparse rock footprints.
- **128** orientation/stepped-arm/seed cases retain an inner-corner terrace in every
  case; the census includes **79** sparse rocks. Terrace computation median
  **9.885 ms**, maximum **15.712 ms** on this scan, excluding resource preparation.
- The original ground, apron, skirt and cliff visual/collision arrays remain
  byte-identical in all three baseline fixtures (`native-geometry.json`). New
  native collision adds 6,580–6,804 triangles in those deliberately cliff-rich chunks.
- The final related run is **100/103 tests, 8,553/8,562 assertions**. The same three
  historical carved-corner failures remain in `test_cliff_dressing.gd` at lines
  949, 1013–1044 and 1067–1087. `CliffDressing.gd` itself has no diff; this change
  does not claim to repair those earlier corner cases or make that suite green.
- A fresh production site loads all nine startup chunks in **132.281 s**, without
  a water-coverage assertion. This is a loaded capture, not a new long-walk or
  startup-speed acceptance. The snapshot tool's existing shader-global readback
  warning remains diagnostic-only.
- `project.godot` remains SHA-256
  `7fc4cfdab9570925f688f0b6a6ff0602c5d8153ad9f536cbb2668593043437e4`.

Evidence: `red.log`, `wet-red.log`, `final-tests.log`, `census.json`,
`native-geometry.json`, `final-live.log`, and the image/difference folders above.
Biome-specific landforms are the next separate issue.
