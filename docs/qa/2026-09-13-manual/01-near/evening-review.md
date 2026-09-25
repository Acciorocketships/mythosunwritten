# Evening visibility review — P43–P51

The final candidate repairs the reproduced foliage bands, unnecessary terrain cuts, buried terrace receivers, background cliff removal and water cutouts. Accepted for these reported visibility defects, with the focused scope and exclusions below. Separate roof, water-shape and terrace-dressing issues remain open.

## General rules

Native foliage now carries the complete asset's measured ownership bounds. Every face of a foreground asset evaluates one shared camera-facing mask plane, so a nearer front leaf cannot disappear while its farther back face remains as a pink polygon. Upward-facing leaves no longer qualify as ground merely because of their normal. Actual grass roots still use the real ground-depth receiver. Foreground foliage can reveal a real vertical cliff as well as an upward floor; closed houses continue to require the existing ground receiver and complete enclosure ownership.

Terrain beyond the actor's horizontal camera-facing plane remains opaque. Terrain cutaway additionally requires actual first-earth depth to obstruct one of three body-height samples. The same decision controls receiver peeling, preserving a clear player's surrounding bank and its grass. This removes the triangle beside P49 rather than hiding that triangle with another surface.

Only the exposed part of a native terrace can serve as ground. A private overhead depth view uses the existing complete physical heightfield triangles to reject buried caps. The rendered terrain sheet alone was insufficient because it deliberately recesses beneath native lips. CPU triangles are read once per committed terrain owner; the private proof mesh is reused and released with its owner. Physics, native visual triangles and terrain sampling remain unchanged. Arches, decks and terrace collision are not classified as solid heightfield volume.

Actual WaterSheet nodes opt out of camera obstruction adaptation. Their original water shader, mesh and swim volumes remain intact. This does not change water's optical transparency or repair the separate hydraulic/shoreline defects.

## Failing controls and verification

- Native upward foliage originally retained 808 pixels; removing the normal heuristic alone still retained 94. Shared asset ownership removes the residual. A separate actual-cliff receiver control originally retained 1,520 foliage pixels and now clears them.
- The buried-cap control originally exposed 862 pixels. Four terrain orientations and an intentionally recessed visual-sheet control now retain exposed caps while rejecting buried portions. Reuse, eviction and unchanged collision-face assertions also pass.
- A bank beside a clear character originally changed 5,735 pixels. After the material gate passed, a separate depth test still caught its missing grass receiver. Sharing the obstruction decision fixes both. A 60-frame camera sweep has zero damaged bank frames, while an intervening-bank control still reveals the player.
- The final isolated native run passes 40 tests / 328 assertions, including camera roles, water, ground, foliage, houses, owner lifecycle and commit behavior. The added moving-bank assertion passes in a separate two-test / four-assertion run. These are focused results, not full-suite acceptance.

## Native image judgment

`evening-reviewed/` contains 24 matched before/after pairs, their opaque controls, receiver images, saved camera transforms, differences and capture logs. Each row below was inspected at reconstructed yaw 0, -8 and +8 degrees. Original overlays round the player/crosshair positions; exact original camera recovery is not claimed.

| Photo | Judgment across all three views |
|---|---|
| P43 | Rectangular water removal is gone. The exposed terrace edge remains; its buried extension no longer supplies a receiver. |
| P44 | Full buried cap is gone; its small physically exposed lip remains. Foreground tree clears consistently. |
| P45 | Pink tree bands are gone; the actual cliff and exposed shelves remain visible. |
| P46 | Previously missing background cliff stays complete. |
| P47 | Pink bush front/back remnant is gone; actual bank and grass remain together. |
| P49 | Triangular terrain cut is gone; the real terrace/cliff stays solid beside the visible player. |
| P50 | Near-camera pink canopy polygon is gone; the real cliff is visible and water has no cutaway hole. |
| P51 | Small cliff behind the player remains opaque. Fresh fully loaded scene replaces the invalid earlier snapshot. |

Twelve additional matched controls in `evening-collateral/` retain the prior house/background result at P06/P33 and clear the original near-camera foliage at P03/P32, all at 0/-8/+8 degrees. P33 +8 had black baseline rails and P03 +8 had two wholly black frames; those original pairs are excluded and replaced by the individually captured, inspected pairs in `evening-collateral-retry/`. P06 still shows the separately documented native roof-geometry issue, with no new interior reveal attributed to this change.

## Rejected evidence and limits

Earlier render-only burial proofs passed a simplified fixture but failed the real native-lip recess and were rejected. The first P51 snapshot lacked ground even in its opaque control, so all its comparisons are invalid; the final snapshot comes from a fresh individual live arrival. Earlier P47 +8 before/after and P49 +8 after black readbacks are excluded. The final 24 pairs contain no black frames.

One combined focused test run reported signal 11 after all assertions passed while native captures also ran. An identical isolated rerun completed cleanly. A prior intermediate candidate had a similar shutdown report. These observations do not establish a cause or general renderer stability. A preliminary single-site CPU sample measured p95 1.819 ms before and 1.793 ms after the physical burial proof, before the final obstruction gate; GPU timestamps were unavailable (all zero). No general performance bound, streaming improvement or renderer acceptance is claimed.
