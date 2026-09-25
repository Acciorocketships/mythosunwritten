# Cliff attachment, lower terraces and full-height relief

September 16–17 follow-up to the owner's seam, shallow-base and fixed-height reports. The current revision blends thin rock into the real native wall detail, adds selected wider lower feet and finite low terraces, and carries most relief close to each wall's own crown. The earlier upper cutoff and sparse-coverage ceiling are superseded.

## Implementation

`CliffRockCrags.gd` prepares a 0.1 m numeric depth/normal sample of the actual native KayKit wall mesh on the main thread. Geometry workers consume only detached arrays. Canonical 3 m horizontal and 4 m vertical phases match the backing wall. Thin attachment geometry borrows that relief, fading it out over increasing projection; rendered attachment normals converge toward the native normals. Independent stone colour variation and bump also fade out at the join, avoiding a material boundary over the geometry transition. Thick outcrops retain their independent cracks and crags rather than repeating the native wall courses.

The crown envelope now follows full wall height with irregular local recesses. More of the upper body remains exposed near the crown. Horizontal sampling is 0.25 m; vertical sampling increases with height so tall cliffs resolve the same crag scale. Short fractures and medium physical relief are deeper. The closed rear and original native turf crown remain.

Selected lower shoulders broaden, with two additional finite low-terrace distributions. Recessed feet remain between them. Projection retains the existing sub-8 m bound to avoid returning to oversized masses. Native turf still owns exposed flatter ledges; gray stone owns wall attachment. Existing wet/public exclusions, actual triangle collision and crevice foliage placement continue through the ordinary dressing pipeline.

## Before and after

Before is the exact preceding geometry and a frozen copy of its shader. After is the final source including height-dependent sampling. Both use the same frozen Amber terrain and cameras. Twelve cameras reuse the saved P05/P12/P17/P20 ReviewCam poses (0 and ±8 degrees); five additional context cameras show wider composition. Seventeen pairs are captured.

Before:

![Before: exposed upper band and shallow lower relief](/Users/ryko/story/docs/qa/2026-09-16-manual/12-cliff-transition/paired-before/P20_oblique.png)

After:

![After: fuller height coverage, blended attachments and varied lower terraces](/Users/ryko/story/docs/qa/2026-09-16-manual/12-cliff-transition/paired-after/P20_oblique.png)

## Visual judgment

- P20 oblique: the exposed upper strip is mostly absorbed into the added relief. Thin areas borrow the native stone shape while larger rock faces retain independent crags. Low terraces and forward feet break up the former shallow toe.
- P12 front and reported nearby angles: fuller upper coverage and stronger stepped lower projection. The transition reads more continuously; some broad surfaces remain soft in shadow. The close fern overlap persists and is not presented as repaired.
- P17 front / reported −8°: the original corner remains recognizable; the adjacent rock extends farther and joins toward the crown. This does not prove exact blending on every native corner variant.
- P05: the prior abrupt bare upper band is substantially reduced. The shaded lighting limits judgment of small surface details.
- The first 64 m study exposed stretched vertical detail and was rejected. The final 64 m study resolves it into smaller crags while preserving full-height coverage and irregular upper recesses.

| Additional evidence | Before | After |
| --- | --- | --- |
| P12 front context | [Before](paired-before/P12_front.png) | [After](paired-after/P12_front.png) |
| P12 photographed pose | [Before](paired-before/P12_reported_0.png) | [After](paired-after/P12_reported_0.png) |
| P12 +8° | [Before](paired-before/P12_reported_8.png) | [After](paired-after/P12_reported_8.png) |
| P12 side context | [Before](paired-before/P12_side.png) | [After](paired-after/P12_side.png) |
| P17 corner context | [Before](paired-before/P17_front.png) | [After](paired-after/P17_front.png) |
| P17 −8° | [Before](paired-before/P17_reported_-8.png) | [After](paired-after/P17_reported_-8.png) |
| P05 context | [Before](paired-before/P05_vines.png) | [After](paired-after/P05_vines.png) |
| 64 m native wall study | [Rejected coarse sampling](tall-64/front.png) | [Final](tall-64-final/front.png) |

## Verification

[Final test run](verified-final.log): **26/26 tests, 1,581 assertions, 166.636 seconds**, nine focused files. Two new shape tests first failed on the saved starting geometry; the additional tall sampling test first failed on the initial full-height candidate. Existing closure, owner seam, grass, wet-channel and restrained-depth checks pass.

- At 94% of wall height, actual added geometry projects beyond the native wall at 19/23, 18/23 and 19/23 sampled positions on 16, 32 and 64 m walls respectively.
- At 21 sampled lower positions, projection increases by more than 0.65 m. Ten sampled positions remain below 4 m. Deepest sampled projection is 7.69 m.
- Across 858 exposed thin-attachment vertices, mean normal difference from independently raycast native triangles is 2.93°, versus 41.77° before. This is a shading continuity measurement, not proof that every visible join is absent.
- The longest sampled vertical front edge on the 64 m control falls from 2.09 m to 0.65 m, eliminating the rejected coarse tall geometry.
- The 72 m ledge control contains 31 finite components across ten metre-height bins, approximately 1–8.5 m long, with 74.13 m² of turf. The actual grass worker reports 32 roots, zero escaped samples and zero buried roots.

One earlier test required under 90% sampled wall coverage. That ceiling represented the prior sparse composition and conflicts with the owner's current request for full-height coverage in most places. It was removed explicitly; the majority-coverage lower bound remains, and the new near-crown, attachment-normal and tall-detail checks enforce the new requirements. No other existing thresholds were relaxed.

The headless run emits the known macOS system-certificate lookup error before GUT starts; tests complete successfully. Final native render logs have no script/parse errors.

## Scope and remaining limits

The context replay rebuilds current visible rocks and plant contacts at 31 saved anchors. Original terrain, grass and collision remain frozen: this is visual evidence, not a fresh full-world hydraulic admission, native seating or player traversal run. The synthetic tall study uses current native wall stock and current outcrop construction. Focused tests exercise the actual current production geometry and exclusion rules separately.

No global performance or gold-standard art acceptance is claimed. The denser mesh increases geometry work, particularly on tall cliffs. Native corner repetition, some soft broad faces and the close fern overlap remain visible. Other original water/town/streaming issues are outside this follow-up.

## Reproduction

Native context: `tests/harness/september16_cliff_transition_context.tscn -- --output=res://docs/qa/2026-09-16-manual/12-cliff-transition/paired-after`. Add `--before` and change the output directory to reproduce the saved starting appearance.

Tall native study: `tests/harness/september16_cliff_transition_study.tscn -- --height=64 --output=res://docs/qa/2026-09-16-manual/12-cliff-transition/tall-64-final`.

Final source SHA-256:

- `scripts/terrain/field/CliffRockCrags.gd`: `57eca1a896ba88cd1f607401fbd30149843319cc22d761fc7d69163f31f4320c`
- `terrain/materials/cliff_crag.gdshader`: `183bdd481a3c60e5b0da63331837aaf481becda9095acb76e26bd95b90605d0d`
- `tests/test_september16_cliff_transition.gd`: `96fb86e3f157844533cfb8b4181646e32053e09b812f3b3e97ec55eed9395850`
- `tests/test_september16_ledge_variation.gd`: `90fa3a06329bb1634a1e7a71be52eebb5a457991f87b3f4f60781537608c2749`
- `tests/harness/september16_cliff_transition_context.gd`: `c1900b5003688b91ac96712e731d8a8397f831417ca9d6bd70f7abe9c6a58026`
- `tests/harness/september16_cliff_transition_study.gd`: `be6955a6751d202a4afd9c7d3a04df75f45d9a158bbace1c66d01376c9fa0f26`
