# Cross-tread curvature experiments — not selected

Production is restored byte-for-byte to `tests/fixtures/september17/cliff-tread-curvature/before.gd` (the preceding inclined broad terraces). No grass, support, width or prominence threshold was relaxed. The production test files were restored after the experiment. New diagnostics and experimental mesh builders remain only in the fixture directory.

The preceding treads bend along the wall and selected broad terraces incline outward, but each depthwise section is straight. A diagnostic on the 31 photographed formations (seed 2697992464) counts adjacent tread segments whose physical grades differ. Baseline has zero and fails [red.log](red.log). The first curved candidate has 241 qualifying columns and passes all three curvature checks in [green.log](green.log). That is not sufficient for acceptance.

The first candidate subdivides each cap into four depth intervals and eases the descent. The focused run is **32/33 tests, 1,800/1,801 assertions**, with the real grass worker reduced from six rooted patches to four: [regressions.log](regressions.log). Closed corners at 16/32/64 m, lower bearing, crown clearance, seven measured rock projections and ownership controls pass. These are rejected-candidate results, not current production acceptance.

Subsequent candidates retain flat treads, reserve a planar inner 60% or 75%, or restrict curvature to wider treads. They retain only four or five rooted patches, except the width-restricted ordered-strip candidate which retains six but provides too little substantial curvature. Changing caps from height-ordered stitching to depth-ordered stitching repairs inappropriate triangle fans, but full curvature still loses planting. The final clipping experiment subdivides the original cap triangles so their inner planes and original diagonal survive; it curves only the outer part. That also retains five rather than six rooted patches. Both clipped candidates pass five of six targeted tests: [clipped-closed.log](clipped-closed.log), [clipped-bearing.log](clipped-bearing.log). Their geometry is not promoted.

During subdivision, shelf-width diagnostics were temporarily changed to measure connected tread sections rather than individual triangle edges. The frozen original still measures the same 90.3552 m² of wide treads in [width-control.log](width-control.log). The helper remains experimental; the ordinary production tests were restored.

## Native review

`candidate/` contains 17 game replays from the initial `subdivide-all.gd` fixture; P12_side, P05_reported_0 and P20_oblique were inspected. The initial 64 m study in `tall/` generated five views; ledges was inspected. These context renders use the then-current original production corner, so they do not establish final curved-corner appearance. `selected/` is a historical output-directory name from the subsequent inner-75% candidate, **not an accepted selection**. No final clipping candidate is claimed visually accepted.

The visible improvement was small, while the original mass organization and repeated backing relief remained. The experiments therefore do not satisfy the user's broader request for flexible, varied cliff geometry. They were withdrawn rather than weakening planting requirements. No fresh-world, traversal, performance or overall art acceptance.
