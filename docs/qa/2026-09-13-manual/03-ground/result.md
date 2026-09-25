# Issue 03 — receiver-backed ground and interior visibility

References: P01, P06, P26, P30, P31. Visual acceptance is limited to these reported sites and the controls below. Issues 01/02 supply the wider foreground bubble and shared building enclosure ownership.

## Findings and iterations

The old effect reproduces the photographed grey holes and reverse cliff skins. Real-ground depth prevents a hole where no actual surface exists behind the obstruction. The first fresh replay nevertheless exposed purple reverse skins at the widened feather in P26. A depth-independent first-surface mask plus full-frustum selection of ground owners removes that mismatch: every intervening earth skin follows the same screen ray. The private first-surface pass shares the actual native meshes and live MultiMesh buffers; it supplies depth, never replacement color or geometry.

That candidate exposed bare triangles on raised background ground. Native triangle tracing identified actual upward turf/ground at y=24.05 and y=24.036 rather than a fake fill. The grass was independently fading because its roots stood above the player. The final material protects grass using the actual receiver depth at each blade root. It also keeps cover when the first ground surface is itself the retained receiver. Native cliff caps without grass are unchanged; terrace grass is issue 31.

Rejected evidence: `rejected-edge/` (purple reverse skin), `first-surface/` (bare receiver triangles), and `retained-cover/` (incomplete root protection). The initial edge test counted 48 cyan pixels already visible in its opaque control; the final invariant correctly counts newly exposed reverse pixels. The first grass fixture removed the bank entirely and wrongly demanded that eight intentionally feathered edge pixels disappear. Its final independent reference restores the original grass material while retaining exactly the same bank and feather.

## Verification

- Final focused native GPU run: **42 tests, 346 assertions pass** (`regressions.txt`).
- The isolated rejected candidate fails two final invariants: **128 newly exposed reverse pixels** at radius 2 and **48 lost raised-grass pixels** (`edge-final-red.txt`). The final code has zero in both. Additional radii 3/4/6/10, native houses in four orientations, no-receiver pixel identity, slope controls, live buffer sharing/replacement and eviction pass.
- Fifteen native before/after pairs at all five photo poses and yaw -8/0/+8, plus opaque controls and receiver images: `root-support/`. Every pair and pixel-difference panel was inspected. Before uses the archived September 12 effect; after uses current production shaders. P31 was freshly generated before freezing; other sites reuse native snapshots to isolate rendering.
- Zero pixels without a receiver change by more than 20/255 in any pair. Maximum small readback/postprocessing difference is 9/255. Exact synthetic no-receiver controls remain bit-identical. These are supporting controls, not a claim that a global difference statistic alone proves a visual fix.
- P01 and P31 retain the ordinary foreground where the old grey crescent appeared. P26/P30 reveal the actual lower clearing and retain the unbacked hill, with no purple inner cliff. P06 retains background exteriors and clears the foreground enclosure. Its small orange double-gable defect also exists in the independent background-only native control from issue 02; it remains assigned to roof issues 08/11.
- A 600-frame frozen native camera/vertical-player replay provides six additional matched pairs and differences (`motion/judging.png`). Inspected orbit, rising and falling samples retain the clearing without void/reverse-skin artifacts. This is image-motion validation, not a physical traversal or streaming claim.

Photo matching uses seed 2697992464 and `ReviewCam.solve_cam` with the rounded player/crosshair overlays. Original full-precision camera transforms are unavailable, so subpixel equality to the annotated original photographs is not claimed. Regenerated pairs have identical stored transforms and frozen material clocks.

## Pixel differences

Mean absolute RGB difference at yaw 0 (0–255), followed by fraction of pixels changing over 20/255:

| Reference | Mean absolute RGB | Changed pixels |
|---|---:|---:|
| P01 | 3.354 | 9.83% |
| P06 | 12.015 | 22.17% |
| P26 | 4.938 | 15.01% |
| P30 | 7.923 | 22.38% |
| P31 | 3.237 | 8.21% |

All angles, raw difference images and receiver controls are in `root-support/pixel-summary.json` and each site's `judging.png`. The water boundary visible at P01 is unchanged and remains issue 22.

## Cost and limits

Two alternating native frozen trials measured old-effect medians 26.704/26.691 ms per frame and candidate 38.595/38.149 ms; candidate p95 41.218/40.422 ms. Camera CPU p95 was 2.317/1.438 ms. The depth passes impose a material rendering cost on this M1 Pro scene; no performance improvement or general frame-rate acceptance is claimed. Mesh positions, textures, collision and world generation are unchanged by this repair. The capture/readback and rendering code hashes are in `fingerprints.json`.
