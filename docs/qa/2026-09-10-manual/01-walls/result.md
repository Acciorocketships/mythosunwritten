# Wall seams — photos 6 and 13

Status: accepted for the reported seams after twelve matched production pairs,
pixel differences, nearby views and physical checks. The earlier rear-slab
candidate was rejected.

## Diagnosis and alternatives

Photo 13 exposes the unclosed side housing of the native wooden door's projecting
frame. The perpendicular return ends at the doorway's declared rear boundary,
but the native frame does not supply a complete side surface across that depth.
Moving the return to the rear slab reduced the opening without closing oblique
views: two photographed pixel rays still hit no triangle. That experiment and
its rebaked return vocabulary were removed. Its rejected production images and
differences remain in `rejected-slab-*` for an auditable comparison.

The final candidate finishes the native doorway's two end strips using the
existing authored timber/plaster wall stock through the ordinary offline
`finish_facade_sides` operation. The 0.12 m strips stay within the original asset
envelope; the central leaf, hinges and arch triangles remain intact. Both hands,
miters and floor-owned forms are baked. Wall placements, return planes and their
397-variant vocabulary retain the original construction. The side-fitting
operation now respects the source's actual minimum Y and height, including its
slightly below-datum feet, instead of assuming a zero-based three-metre asset.
Baker version 33 records this preparation.

Photo 6 exposes a different problem: a jagged stone return already closes the
rear of the concave corner, but leaves a deep irregular notch between the facade
ends. The candidate uses native plain timber stock for that shared return,
retaining the rear-reveal construction and projected overlap calculation. It
provides one continuous joining face between the facades.

A full corner post was rejected because it reduced capsule clearance at a
previously reviewed gallery corner. A smaller inset post was also rejected
because it reopened the rear-view slit. The final diagonal timber return passes
both checks. The final stone fixture includes all three actual neighboring
rooms; its rays stop within 0.50 m of the nominal facade corner rather than
crediting a deeply recessed wall as a finished visible join.

## Geometry and physical evidence

- Door rear-return regression: all 40 contacts missing before; all present
  after, covering both ends, five heights and four orientations.
- Native housing regression: 60 of 72 side contacts missing before; all present
  after across both hands and both floor-owned forms.
- Stone corner regression: 20 contacts missing before; all present after.
- Final focused run: **16 tests / 1,486 assertions, clean exit**. Includes prior
  diagonal/concave closure, supported masonry return, inline seam, native cut
  faces, stock containment, side fitting and preservation of central doorwork.
- The census reads actual indexed surface arrays. `Mesh.get_faces()` rounds its
  cached triangle coordinates to 0.1 mm and can falsely cross a precise cut
  plane; the strict stock-bound tolerance has not been loosened.
- All 674 existing timber return / floor-owned variants still retain their
  referenced vertices within the original stock and declared cut planes.
- The full frozen photographed east-town physical survey is identical before
  and after: **124 walking cells and 179 crossings**. The complete dictionaries
  in `clearance-before.json` and `clearance-after.json` compare equal.

The source asset files are unchanged. Only ten closed-door derivatives require
rebaking: eight ordinary/mirrored/miter forms and two floor-owned forms. The
canonical exporter still demands 639 floor-owned wall variants. Unrelated
native meshes and historical bake artifacts are preserved.

## Render evidence

`before/` contains six production views per photo: reconstructed original,
left/right nearby, two small camera jitters and production collision camera.
The original overlay has player/crosshair coordinates rounded to 0.1 m, so these
are matched `ReviewCam.solve_cam` reconstructions, not recovered exact original
poses. Both sides use 75-degree FOV and a 1718 x 1035 viewport (half the original
game area). Isolated grey-background renders were diagnostic only.

The baked housing now supplies actual native triangle hits for the previously
empty photo-13 rays at pixels (843,230) and (849,170), owned by the second doorway.
The avatar reflects the current character implementation, so its facing differs
from the source photograph; matched before/after captures share that behavior.

The final `before/` and `after/` camera records compare equal for both photos.
All twelve complete after frames and their paired crops/differences were inspected.

| Photo | Exact-view judgment | Nearby/jitter/gameplay judgment | Exact ROI difference |
| --- | --- | --- | --- |
| 6 | Continuous timber closes the formerly jagged vertical recess from top to lower skirting. | All five additional views retain closure without a protruding post or new slit; surrounding window, stall and walking space retain their form. | Mean absolute RGB 3.622/255; 12.578% of ROI pixels exceed 20/255 in a channel. |
| 13 | Both deep side openings are filled by native timber/plaster housing. The lamp formerly visible through the side is correctly occluded by the finished wall. | Both oblique views and all three additional cameras retain closure to the base. The former through-view beside the second door is gone. | Mean absolute RGB 6.329/255; 13.383% of ROI pixels exceed 20/255 in a channel. |

`differences/metrics.json` contains all twelve measurements. The hot regions
follow the new corner face and doorway side strips. Small differences from
animated character shading, moving orbs and the desktop cursor are not credited
as repairs. Positive pixel differences alone are not an acceptance criterion:
the visible joins and the previously empty native ray contacts establish closure.

Review sheets: `06_stone_gap_review_sheet.png`,
`13_plaster_gap_review_sheet.png`, and `full-after-review.png`. Full PNG sequences
remain local ignored QA artifacts; reports, camera records, numeric evidence and
harnesses are retained. This accepts the photographed seams, not universal city
material cohesion or the documented broad baseline failures.
