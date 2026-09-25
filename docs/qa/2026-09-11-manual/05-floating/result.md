# Floating block review — accepted for the reported defect

The projecting half of the photographed room is removed by ordinary room
composition. Its supported rear half remains beneath the same skywalk endpoint.
All 28 rooms remain; a second upper room shifts to a shallower supported edge.
Ordinary timber projections are now limited to one 1.5 m construction cell;
complete public arcade supports retain their deeper opening. Compact timber
knees use native pillar geometry and participate in measured clearance.

The original room-support recipe emitted no geometry. A deeper knee candidate
intersected the lower roof; compact knees passed contacts but failed visual
judging because the photographed room still looked unsupported. Both trials
were rejected as repairs for the reported block. See [iterations](iterations.md).

## Visual evidence

[Live before / after / pixel difference](live-diff/floating-block-detail.png)
shows the reported repair. Twelve live pairs cover all four reconstructed photo
angles and +/-8 degrees. Sixteen native pairs add +/-30 and reverse views.
Twelve frozen-world pairs provide a further geometry control; their terrain
colour does not preserve the live shader globals and they are not the final
colour reference. All of these comparison sheets have been visually inspected.

The live circled region changes by 16.688/255 mean absolute RGB, with 30.894%
of pixels differing by more than 20/255. Full live frame means span 5.484–9.340;
the original 03_block pose changes by 8.066/255 and 16.940% above the threshold.
The differences cover the removed room projection and the second room's moved
roof/frontage, plus small animated grass/orb/fog differences. Native fixed-light
pairs isolate construction changes. Pixel differences are evidence of where
changes occurred; visual and physical checks determine whether they repair it.

All paired camera matrices agree exactly. They use ReviewCam and the rounded
player/crosshair overlay, so original full-precision photographic agreement
cannot be recovered. See [live metrics](live-diff/metrics.json),
[image audit](live-diff/image-audit.json), and the three live contact sheets
[0](live-diff/contact-0.jpg), [-8](live-diff/contact--8.jpg),
[+8](live-diff/contact-8.jpg).

## Construction and physical checks

- The original source-plan test fails immediate bearing; the candidate passes.
- 46 focused tests / 357 assertions pass, including native support endpoint
  contacts, public arcades, room composition and skywalk bearing.
- The existing native-recipe inventory passes 70,929 assertions.
- Complete before/after physical payloads retain identical 88 public positions
  and 124 crossings at the photographed town.
- All 48 corpus towns construct. All 11,112 sampled positions and 15,923
  crossings are clear. Twenty-seven off-centre pillar contacts remain, with no
  blocked centres or crossings. Private-garden reachability remains separate.

The corpus took 432.969 seconds while sharing the machine with other QA work;
this is not a performance improvement claim. The first additional regression
gate passes 94/95 assertions and fails only its 9/standard timing ceiling. Its
own calibration reports an invalid timing environment (2.96x slowdown, capped
at 2x). A repeat passes 93/95 with timing misses for 3/standard and 9/standard
at x3.15 calibration. The original generator also misses 3/standard (21.133 s
versus candidate 20.208 s) at x3.88 calibration; its 9/standard is 9.038 s
versus candidate 11.468 s. These loaded single-run timings do not establish
performance equivalence or a speedup. Timing acceptance remains unresolved;
no timing pin is weakened. The original run correctly refuses to score the
candidate-fingerprinted matrix as original-code evidence. Acceptance here is
the reproduced floating-block repair and construction/physical checks, not a
green timing or full-suite claim.

Current source files and project settings are restored after the live baseline
capture. No temporary editor plugin or editor setting remains. This report does
not claim full-suite health or completion of the subsequent building/terrain
requests.
