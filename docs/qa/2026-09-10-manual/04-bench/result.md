# Bench collision — accepted

Both native bench variants now use their complete authored triangle collision
(96 and 162 triangles). The bake manifest owns this through `native_trimesh`;
no placement or visual mesh changed. A simple box was considered, but the tiny
native meshes preserve the open leg spaces and exact seat without an oversized
invisible obstruction. Baker 34 rebaked only these two assets.

## Red / green evidence

Before the fix, eight seat rays and both walking-capsule approaches failed.
Afterwards, both benches support the seat in four orientations and stop the
capsule. The combined furnishing run passes 6 tests / 399 assertions with a
clean exit; see `bench-red.txt`, `bench-walk-red.txt`, `bench-props-tests.txt`.

The actual game character was then walked at the photographed bench from both
sides and at three transverse offsets. All six baseline runs passed through;
all six fixed runs remained grounded and stopped 0.756–0.784 m from its centre.
`live/walking.json` records every physics sample, and `live-run.txt` records the
production run. `live-judging.png` shows the six matched comparisons and pixel
differences. The avatar stops on its approach side with collision enabled.

## Image and path judgment

Six reconstructed photo-7, nearby, jitter and gameplay-camera pairs have
identical camera records. Every pair and its difference was inspected in
`static-judging.png`. Furniture shape, position and neighboring surfaces remain
unchanged; the visual mesh files have identical SHA-256 hashes before/after.
The exact-view region has mean absolute RGB difference 0.118/255 and 0.0383%
of pixels changing by more than 20 levels. Small differences are animated
character/orb rendering. Collision is established by live walking, not these
small pixel differences. The pinned screenshot fixture intentionally places
the avatar at the original overlapping coordinate in both static views.

The complete photographed town retains identical physical clearance over
112 public cells and 164 crossings (`clearance-after.json`, compared with
`../03-prefab/clearance-after17.json`). No routes move or become obstructed.

This accepts both bench collision assets and the measured production placement.
The other reported platform, grass and railing issues remain separately open.
