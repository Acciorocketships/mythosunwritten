# Shoulder crags with preserved ledge caps

The selected correction restores physical clefts on exposed rock shoulders that previously borrowed a thin underlying body's detail limit. The ledge caps remain unchanged. This is a scoped repair: broad soft faces, angular corner cuts, native upper-course repetition, and overall cliff art remain open.

## Cause and selected change

The former body calculation decided how much crag detail was safe before adding the ledge shoulder. A visibly thick shoulder could therefore inherit a thin attachment's suppressed fractures. The selected calculation includes the shoulder when evaluating room for detail. It retains the existing conservative erosion-depth budget and native-wall transition.

The first correction narrowed some usable ledges. Its focused run passed 42/43 tests, failing the existing broad-turf-area requirement (130.809 m² versus the required 133.898 m²). It was rejected. The selected version eases the extra shoulder contribution over 0.01–0.45 m below/above the existing cap boundaries; the caps themselves retain their previous geometry. The same turf test now measures 147.396 m² of broad ledge area and zero hairline turf triangles. No existing acceptance threshold was lowered.

An earlier all-surface probe counted 360 samples with suppressed relief among 2,198 eligible samples. Making every sample fully detailed passed that probe but caused the ledge regression. The final version intentionally retains the cap transition: 221 of those samples remain below the probe's full-detail threshold. Consequently that broad diagnostic remains an experimental fixture, not a claim that all 360 were repaired.

The production regression pins nine actual face samples away from the protected caps, plus exact cap-array equality on the three photographed formations. Seed is 2697992464. P12 anchors are (-433.5,32,-301.5) and (-445.5,32,-288); P20 is (-480,32,-253.5).

| Anchor index | Local XY (m) | Original cleft depth (m) | Selected depth (m) |
|---|---|---:|---:|
| 9 | -6, 1 | 0.160 | 0.766 |
| 9 | -5, 1 | 0.103 | 0.390 |
| 9 | -2, 1.2 | 0.297 | 0.500 |
| 12 | 0.5, 3.8 | 0.223 | 0.446 |
| 12 | 2.75, 3.4 | 0.576 | 0.815 |
| 12 | 3, 3.2 | 0.383 | 0.712 |
| 20 | 4, 4.2 | 0.038 | 0.314 |
| 20 | 5, 3 | 0.229 | 0.623 |
| 20 | 6, 4.2 | 0.493 | 0.800 |

The [corrected original run](pins-red-corrected.log) fails all nine relief assertions while retaining all nine samples. Three cap-preservation checks pass. An initial pin lookup used exact floating-point dictionary coordinates and missed three samples; the corrected test keys use the mesh's existing 0.0001 m precision. The earlier lookup run is not the regression evidence.

The final [focused run](final-tests.log) passes **44 tests / 1,063 assertions** across fifteen files in 264.271 seconds, with exit code zero. This includes closed collision geometry, native attachment, five prior cut-through pins, full-height coverage, lower projection, turf and plant spacing. The headless process prints the existing macOS certificate-loader diagnostic before GUT; no test fails. Both final GPU capture processes complete with exit code zero.

## Visual judgment

All seventeen final frozen context views were inspected: P05/P12/P17/P20 reconstructed reported cameras with both neighboring offsets, plus P12 front/side, P17 front, P05 vines and P20 oblique. [P12 close](final/P12_reported_0.png), [P17 corner](final/P17_reported_0.png), [P20 context](final/P20_oblique.png), [P05 vines](final/P05_vines.png). The matched baseline is the previous pass's [limited capture set](../15-cliff-planes/limited/). The original screenshot overlay poses are reconstructed through the existing ReviewCam harness, not exact unrecorded original camera transforms.

The localized shoulder cuts are more readable and the broad cap outlines survive. P12's central large face remains too soft; P17 retains angular diagonal cut boundaries; the shaded P05 face still reads muddy. Recomputed crevice plant positions change in some views and must not be mistaken for better stone geometry. No overall art acceptance is claimed.

Five final 64 m native construction views were also inspected: [front](final-tall/front.png), [oblique](final-tall/oblique.png), [close](final-tall/close.png), [wide](final-tall/wide.png), [ledges](final-tall/ledges.png). Full-height coverage and varying lower projection remain: the existing probes cover 19/23 crown samples at each of 16, 32 and 64 m; lower-depth probes retain 24 broadened and nine restrained samples. Regular native columns and repetitive small-scale detail are still visible. This is a studio construction control, not fresh world generation or physical traversal.

## Rejected studies

Fixtures under `tests/fixtures/september17/cliff-shoulder-union/` retain the experiments. Only representative views of the rejected studies were judged, except the complete 17-view shoulder-gate set.

- `candidate`: changed mass bevel/profile; still regular with awkward caps and soft faces.
- `normals`: narrower attachment shading and wider smooth fans; angular/blurred patches remained.
- `blocks`, `blocks-fine`, `blocks-scattered`: cellular stone relief; broad panels, obvious brick-grid or puzzle-like divisions failed the reference. Experimental static caches were not audited for production use.
- `stone`: stronger grain and contrast over scattered blocks; insufficient shape improvement.
- `shoulder-detail`: corrected exposure plus a larger erosion budget; overly hollow cuts were rejected.
- `shoulder-gate`: corrected exposure with the original budget, but reduced usable ledge area; rejected by the existing turf test.
- `cap-preserving`: selected production version, restoring shoulder crags while retaining caps.

No fresh world, player traversal, global streaming, hydraulic, performance, or full-suite acceptance is made. Original manual issues remain in the [register](../../2026-09-16-manual/issues.md).
