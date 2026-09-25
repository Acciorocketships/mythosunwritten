# Continuous ledge tops and pointed turf ends

The reported P05 upper-facing channels came from closely spaced ledge cuts and stitching an exposed cap to an inactive cap slot in the neighboring column. Broad turf also stopped before its narrow pointed ends.

`CliffRockCrags.gd` now transfers closely spaced shoulder support into the adjacent active ledge, blending height, grade and thickness. Empty cuts are removed before profile construction. Neighboring columns match their actual exposed ledges by height; wall strips join by height and curved caps by depth fraction. This removes the artificial notch while retaining the inclined and curved tread profiles.

Turf follows actual tread edges through pointed ends. A connected broad cap seeds its narrow extensions; isolated hairline strips remain stone. A trial that painted every upward-facing triangle was rejected because it scattered turf onto the wall. End closures now triangulate the complete polygon rather than generating zero-area quads beside flat tread rows. Visible and physical geometry remain shared.

## Reproduction and checks

- `red-final.log`: the frozen original reproduces the narrow-riser and abrupt turf-continuation failures. Earlier `red.log` and `turf-red.log` had an incorrectly scoped single-column probe and are not acceptance evidence.
- `notch-red.log`: the ordered intermediate covers only six of nine physical notch probes with turf and has 24 degenerate closure triangles.
- Final: all nine notch probes have turf; narrow risers fall from one to zero across 25 sampled columns; abrupt shallow turf continuations fall from 15 to zero.
- All 31 photographed shells are closed, with zero bad boundary edges and zero degenerate triangles.
- The combined final run is [50 tests / 1,988 assertions](../29-cliff-stone-colour/focused-tests.log), all passing. It includes collision/support, corners, root continuity, grass, curvature, shading and triangulation controls. Seventeen actual worker grass roots have zero escaped or buried roots. The 76,599-sample support-continuity maximum remains 0.074629 m.

The user's pointed-end request explicitly supersedes the old rule rejecting every thin turf triangle. The width regression now rejects disconnected thin islands while permitting tips attached to broad caps. Whole-cap span includes these tips: the former 14 m middle-only bound becomes the actual 24 m owner-span bound; the measured largest connected span is 16.25 m. The fine physical detail-spacing test excludes buried polygon end closures, whose internal triangulation diagonals do not describe visible relief. Its interior maximum remains 0.200001 m, with more than 10,000 measured edges.

## Native visual review

`final/` contains 17 saved native ReviewCam views using the frozen production world and newly generated dressing. The same geometry is visible with the final colour material in [pass 29](../29-cliff-stone-colour/current/). Inspected P05 frontal and alternate angles, P12 side/front, P17 front and P20 oblique/alternate views retain continuous broad caps and pointed turf ends without the reported triangular channel. Intermediate all-upward paint was rejected visually.

This is a scoped ledge repair. Some broad bodies remain too vertical or soft, backing relief repeats, and some upper ledges remain thin. Overall cliff art, fresh-world traversal, global performance and the broader original issue register are not accepted by these results. One earlier run (`verified-tests.log`) mixed a cached old shader include with the new overload during editing; the final clean-process run replaces it.
