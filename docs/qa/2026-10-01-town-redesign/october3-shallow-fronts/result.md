# October 3: shallow native roofs for embedded wall fronts

Retained production change: wall-room shed hoods now use the existing Pure
Village shallow roof-bottom course with its authored left/right end caps.
This repairs the roof grammar. It does NOT yet make the room facade project
from the city wall, add new inhabited bores, or complete the architectural goal.

## What changed and why

The old hood used `suntail.roof.roof_1_cornice_*`, a complete gable-slope
module. Its native Y bounds run from -0.599 to +3.119 m: most of its slope
rose a storey into the retained wall behind the visible cornice. The controlled
`gallery-raised/legacy-front.png` shows the roof emerging inside the wall top.

The new assets are original `Roof_Bottom_30x5_1`,
`Roof_Bottom_Left_20x5_1`, and `Roof_Bottom_Right_20x5_1`. The continuous
three-metre stock is cropped to the shared two-metre bay without rescaling
its tiles. The complete native end caps retain their projecting tiles and
wooden end closure. Their pivots align the interior seams; authored material,
UVs, scale and collision geometry are retained. The manifest/provenance and
three baked catalog visuals are checked into the working changes. No new
texture or visible primitive architecture was made.

The native low edge falls 1.248 m below its attachment. A first trial at the
old datum obscured opening heads and was rejected (`gallery/`). The accepted
seat is 0.85 m above the room head, within the retained half-storey cap:
low edge 0.398 m below the room head, high edge 0.962 m above it. Native
window and door heads remain visible. The finished public-air predicate
continues admitting or rejecting each COMPLETE hood run, including both caps.
The source roofs are blue; they are not tinted to mimic the former Suntail
colour variants. Main building roof selection is unchanged.

## Verification and judgment

- Bake succeeded using `--keep-existing`; unrelated assets were not pruned.
- Final room/support/skywalk suites: 9/9 tests, 164 assertions, 82.892 s.
- Expanded hood-only final suite: 4/4 tests, 59 assertions, 27.639 s. It checks
  complete rejection, independent clear runs, native vertical/depth limits and
  unchanged scale, plus actual admitted town-13 hood geometry against finished
  public-route air. Existing support and skywalk tests include 41/large,
  2/grand and 43/grand. No full-suite claim.
- Actual player in 13/large: 8/8 directions, including two skywalks, the
  inhabited bridge and an underpass. This does not claim every town route.
- Native town-13 platform views and town-13/41 room views rendered. Reviewed
  platform_wall0 and room close views; the platform view shows the low blue
  roof joined beneath the occupied upper walls. The automatic room cameras
  are too close to show the whole hood, so they are not the primary art proof.
- Controlled two-bay comparison in `gallery-raised/` and four-bay comparison in
  `gallery-wide/` reviewed: complete openings, aligned continuous native roof
  strips, closed ends, no old slope emerging into the upper wall. These are
  deliberately isolated grammar fixtures, not completed town designs.
- The initial raw-part render placed below-zero native cornices under the
  study ground. Those images are preliminary bounds evidence, not art proof;
  the reusable source-part harness now lifts each part onto the study floor.
- No fresh quiet production-time or world-streaming claim. No commit/PR.

## Still open / next architectural work

Most wall-room storeys are only three native metres high. The earlier complete
Pure Village bow-window prefabs cannot be used as one-storey applique. The
room fronts still occupy the original wall plane. Need a complete shallow
room extension (front, returns, floor, roof) represented against real street
clearance and neighbouring construction, or a multi-storey reserved frontage
for the full source assembly. A diagnostic using whole doorway AABBs reports
public-air intersection even at zero offset; it is too conservative to prove
that any outward projection is impossible. Do not use that diagnostic to
justify abandoning the requested room extension.

Preserve the full objective: actual inhabited bore/cover co-design, enclosing
upper climbs, stepped buildings/overhangs, native turret connections, broader
seed and player review, and all other outstanding plan gates remain active.
