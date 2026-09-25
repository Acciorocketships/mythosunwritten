# Camera control roles

Status: accepted for the requested camera control roles and measured native
input/collision behavior.

The tactical camera now spins smoothly with left/right travel, using the original
close camera's motion response while retaining its 26 m / 16 m framing. Q/E and
existing tactical pointer-edge orbit remain available. Close view uses relative
mouse motion for yaw and pitch, with a small center crosshair. It follows position
without movement-driven rotation. Its initial eye stays 8 m behind / 5 m high;
the aim point is raised above the mage hat so the crosshair has a clear view.
F7 preserves heading. Escape, focus loss, pause and teardown release capture;
a game click reacquires it. Character facing follows the view even above the
horizon. The camera boom still retracts against real collision.

## Brainstorm and rejected candidates

Moving the old follow behavior into the tactical view should preserve its actual
angular response, rather than inventing a different rotation gain for the wider
boom. A planar reference follow preserves the original velocity smoothing,
strafe blend and bounded positional step. Native comparisons match the old
camera's heading within 0.0001 radians at 30, 60 and 120 Hz.

The first close-view focus placed the crosshair on the avatar's face; its native
render was rejected. Raising the focus clears the hat without changing the
initial eye. Native mouse limits prevent pole flips, and four-orientation wall
plus ground sweeps check that looking around cannot move the boom through them.

The first screenshot mouse sequence did not acquire native capture, so its four
mouse-response comparisons were rejected despite rendering correctly. The audit
uses actual camera bases, not just a controller variable. A corrected native
replay passes capture and actual yaw/pitch assertions at photo 04. Focus remains
unreliable between separate desktop processes, so the four final image fixtures
invoke the same production motion handler directly; native integration tests
separately dispatch real InputEvent objects through the viewport. No synthetic
image fixture is presented as proof of desktop focus ownership.

## Evidence

All sixteen accepted pairs were visually judged, including all four reconstructed
photo starting views, tactical strafing, close-view strafing and close mouse
motion. `accepted/sources.json` records each source and file hash; `accepted/diff`
contains the differences. No accepted pair is wholly black.

The four unchanged starting views have mean absolute RGB differences of
0.000021–0.008069 levels (0–255); only 0.000048–0.019821% of pixels exceed 20
levels, including timed details. Their framing stays fixed. Motion differences
are deliberately large, so acceptance uses saved trajectories as well as images:
the 4 m lateral sequence turns tactical heading about 55.968 degrees, matching
the original close view. New close-view strafing changes heading by zero. A
100-pixel right / 50-pixel up mouse replay turns right 8.959 degrees and raises
the view 4.480 degrees at all four pins; the old close view changes neither.

The close view at the two enclosed pins still meets real nearby walls, as its
baseline did. These pictures verify orientation/collision behavior, not an
unobstructed vista through those walls. The open lawn views show the reticle
clear of the avatar. No building or collision was removed to improve framing.

All 24 final focused native tests pass 166 assertions with a clean exit
(`tests.txt`), covering both directions of tactical movement, exact reference
follow, idle, mouse yaw/pitch limits, capture/release and reacquisition, F7 heading,
explicit eye reset, center reticle, directional player input and boom collision.
The original four photo pins are reconstructed from 0.1 m rounded overlays;
paired starting transforms match each other, not the unrecoverable original
full-precision camera. Motion sequences intentionally change the camera transform.
Their geometry/actor paths remain fixed within each scenario, with the close-view
avatar posed toward its production aim. The fixture uses actual saved native
village geometry; its ground tint lacks live biome sampling services.

The earlier combined camera/material/GPU run stalled awaiting a projection draw
and was stopped; it is not counted as a complete pass. The final focused camera
run is recorded separately. The independently accepted bubble tests and evidence
remain in issue 2. No universal black-screen fix is claimed here.
