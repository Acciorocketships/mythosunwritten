# Contextual cutaway constrained by real ground

The revised visibility effect implements the owner's intersection rule: an obstacle fades within the player bubble only where actual ground exists behind it. Where revealing it would expose void, the original foreground remains. The soft transition feathers inward from the valid-ground boundary. The rejected actor silhouette and brown earth cap are archived; neither is in production.

The private depth pass shares existing ground meshes and live native MultiMeshes. It selects upward terrain, actual native turf swatches and supported public walking surfaces. Sky, wall faces and private house interiors cannot certify a reveal. The same screen mask clears intervening front and rear shell surfaces up to real ground, including separate terrain batches beyond the actor plane. Native deck detail is retained only at genuine receiver depth. This changes no authored geometry, collision, placement or palette.

The implementation went through three rejected intermediate results. A feather computed separately at each surface depth left rear cliff skins visible; a common screen mask removed that. Normal-only cap selection accepted sloping rock facets; the actual turf atlas swatch now separates real ground. An actual native house exposed a narrow interior-floor strip; separating public deck detail from building shells removed it. The bubble broadphase also includes the complete rear terrain interval, preventing a separately batched reverse face from escaping the material change.

## Verification

Eight camera suites pass **36 tests / 275 assertions** in [receiver-regressions-final.txt](receiver-regressions-final.txt). Four new GPU behaviour tests fail against the archived original adapter and pass against the revised one. The original creates **8,120 new void pixels and 210 reverse-skin pixels** in the bank fixture; the revision creates zero of either. Eight flat/slope/grass controls preserve ground, surrounding scene objects remain visible, and removing the ground receiver preserves the original foreground exactly. The actual catalogue house is checked in all four orientations against independently rendered ground; the interior contributes zero pixels in the fully revealed test region. The original leaves 1,697–1,787 house pixels there. A fifth test verifies seven resource-ownership conditions: same-world selection, shared native meshes/buffers, replacement transforms and meshes, hidden owners and freed terrain.

The native-house no-receiver comparison uses the disabled instrumented material as its control. Converting StandardMaterial alone introduces small rounding differences from the original material (5–18 pixels, at most six channel codes); the cutout/no-receiver comparison itself is exact. See [original failing run](receiver-original-red-final.txt), [bank fixture](receiver-fixture/) and [native-house fixtures](receiver-house-fixture/).

Fifteen final native before/after pairs cover the five reported ground/interior photographs, each at reconstructed yaw and ±8 degrees. The scene, camera and clocks are frozen within each pair. The separate opaque reference and actual receiver depth image test the rule independently of the old broken cutout. All **1,926,990 pixels without a receiver** across these views retain their foreground content. Native postprocessed comparisons have small channel differences there, at most eight codes, with none above the recorded 20-code threshold; they are not bit-identical claims. Exact unpostprocessed fixture checks supply the stronger clipping invariant. Pixel changes are also visually judged, rather than treated as proof by themselves.

| Source view | Final visual judgment | Mean absolute RGB difference at reconstructed yaw (0–255) | Pixels changing >20 codes |
|---|---|---:|---:|
| 11:56:57, spawn | Underfoot ground stays intact; the separate water-field issue remains visible | 2.802 | 8.29% |
| 12:27:00, heath | Foreground fills the former grey void; the genuine lower clearing remains visible, without rear cliffs | 3.644 | 10.79% |
| 12:34:46, heath | Original foreground survives the bank boundary; actual cap and ground context remain | 4.914 | 12.72% |
| 12:35:28, town | Flat ground remains opaque while the existing building composition stays visible | 3.046 | 8.09% |
| 12:01:38, town | Public platforms and far ground are visible; the intervening interior wall/floor layers are removed | 7.114 | 13.54% |

Final comparisons, amplified differences, opaque controls, receiver maps and camera poses are in [receiver-verified](receiver-verified/). Each site's judging.png contains before/after/difference rows. Machine-readable pixel measurements are in [pixel-summary.json](receiver-verified/pixel-summary.json). The [heath comparison](receiver-verified/30_heath/before-after.png) shows the owner's requested distinction particularly clearly.

Six further matched pairs sample a 600-frame frozen-world camera orbit and actor-height replay. All six preserve the hill outside valid reveals and show no exposed reverse shell or new void. This is image-motion testing, **not a physical traversal or streaming test**. See [motion judgments](receiver-motion-final/judging.png), [differences](receiver-motion-final/diff/metrics.json) and [performance](receiver-motion-final/performance.json).

## Limits and exclusions

Two sequential three-angle town runs produced wholly black opaque, original and revised images at +8 degrees, including a black receiver texture. Those sets are excluded, never credited as a zero-difference pass. Capturing the same +8-degree pose first in a fresh process produced clean images in all three phases, which are the credited final pair. This points to capture-order/resource-lifecycle sensitivity but does not establish its cause or resolve general renderer stability. The excluded example and run references remain in [receiver-excluded-black](receiver-excluded-black/).

The receiver pass adds measurable work. Warm measured heath frame medians are **26.491 ms original / 32.304 ms revised**, with p95 **28.753 / 35.291 ms**. Camera CPU p95 is **0.436 / 1.057 ms**. An early shader exit for unaffected fragments reduced the revised median from about 40 ms to 32 ms during iteration. These are one-scene measurements, not global performance acceptance.

Source overlays contain rounded player and crosshair coordinates rather than full camera transforms. The photographs are reconstructed with ReviewCam at 1716×1033; each before/after pair has exactly the same camera, but this is not subpixel recovery of the original screenshot. The result closes the reported ground-removal and interior/reverse-face cases under the owner's revised visibility rule. Near-camera coverage and all other original manual issues remain pending in [the issue ledger](../issues.md).

The source fingerprint is [receiver-source-fingerprint.json](receiver-source-fingerprint.json). Earlier prototype renders are retained for iteration history and are not final acceptance evidence.
