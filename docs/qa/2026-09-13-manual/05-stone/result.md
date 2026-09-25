# Issue 05 — U-shaped stone in P05 walkway

Status: accepted for P05 and its measured walking aperture.

Reference P05: Screenshot 2026-09-12 at 12.00.37 PM; seed 2697992464; player (-217.9,20.4,-945.9), crosshair (-212.6,21.7,-946). ReviewCam reconstructs the close camera from these rounded values. The original full-precision camera transform is unavailable; paired native renders use identical reconstructed transforms, FOV 75, at 0 and ±8°.

## Diagnosis, alternatives and implementation

The photographed U is six native `maze-stone` panels at fine cells (-1,4,0), (-1,4,1), (-2,4,0), (-2,4,1). Their world height spans 20.08–23.08 m, through a ramp rising toward +X. These are actual retained masonry, not a texture or transparency artifact. Native original rendering reproduces the complete U.

Clipping only the visible panel would conceal the invalid retained volume while leaving conflicting ownership and potentially collision. Lowering an entire course would disturb adjacent support. The shared complete-flight air reservation accepted in issue 04 prevents these cells from being retained at all. All six panel IDs disappear under that existing repair; no additional production change is necessary. Room/floor assets below remain owned and present.

## Tests and judgments

The dedicated P05 test fails both assertions against the isolated pre-issue-04 code. Fifty-three of 125 native capsule stances collide with the original stone, across five lateral lines; the current implementation clears all 125. The actual continuous ramp air is public in every sampled cell. Original real-player traversal passes nine of ten trials: ordinary step-up/slide behavior gets through most of the U, but the uphill +1.5 m line stops at X -208.4866. All ten final walking trials pass.

All three matched native photo comparisons are visually judged. Each removes the entire U while preserving the ramp, landing, side guards and surrounding facades. Mean absolute RGB differences in the U region are 8.63–9.10/255; 21.04–22.12% of its pixels change by more than 20. Full-image differences are 1.18–1.61/255, including the neighboring issue-04 change visible at the lower left. Pixel differences locate geometry changes; they do not alone establish collision correctness.

The accepted issue-04 production fingerprint, full 48-town matrix, 95-assertion gate and historical 19-failure broad-suite limitation apply unchanged. `04-path/final-payload-comparison.json` proves the current photographed-town payload matches the fresh production snapshot used here.
