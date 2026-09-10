# September 8 manual review

Seed: 2697992464. Source: thirteen owner screenshots from 09:28–09:34.
Camera pins: `tests/harness/village_september8_qa.gd`, in attachment order.
ReviewCam reconstructs the orbit from rounded player/crosshair coordinates;
matched generated pairs are exact to each other, not guaranteed pixel-identical
to the annotated source image. Each site must finish production streaming.

## Sequential issue ledger

1. Town slopes (photos 2, 13): photographed ground spikes fixed and reviewed.
   Elevated portals were assigning their platform height to two 3 m ground
   cells beside lower ground. Both now declare a stair approach and full lower
   landing; the ground retains its base datum. A normal-length soil slope here
   would consume neighboring buildings. Field/kernel and pad resampling were
   investigated; neither caused these particular spikes.
2. Overlapping/flickering floor surfaces (11, 12): fixed and reviewed.
   Protruding/staggered caps in 1 and 11 were subsequently corrected in issues 4/9.
3. Inline wall seam (7): fixed and reviewed; perpendicular exposed ends were corrected in issue 4.
4. Exposed ends, planes and exterior finishes (3, 4, 9): fixed and reviewed.
5. Stair character/camera jitter: fixed and reviewed.
6. Dead-end stair/walk destination (8): fixed and reviewed.
7. Door path alignment (6): fixed and reviewed.
8. Main/town path junction notches (5): fixed and reviewed.
9. Staggered grass-platform outcroppings (1, 11): fixed and reviewed.
10. Arbitrary-looking hole fills: fixed through issues 2/4 and reviewed across both towns.
11. River bank access/canyon carving (10): accepted after matched renders, pixel review, four grounded shoreline traversals, six town entrance traversals and 95 passing tests.

12. Additional self-review porch approach (9): fixed and reviewed, including six strict live walking traversals.

## Independent art review

Initial photo observations to verify in renders: abrupt material changes on
continuous banks, exposed module ends at inside corners, inconsistent plank
direction at joins, and elevated walkways lacking a clear destination.
The final twelve-photo town pass confirms the corrected bank finish, closed
door returns, continuous balcony boards, and open stair destination. Garden
outcroppings now form a consistent silhouette. The remaining visual priorities
are reducing repeated large-scale facade patterns and giving major public
destinations stronger identity through dedicated furnishings or signage. Those
are art-direction improvements, separate from the photographed construction
defects. The unmarked turnout left of the market in photo 9 was independently traced
to a short porch approach and repaired as additional self-review item 12.

## Issue 10 evidence

The apparent arbitrary fills were duplicate floor surfaces in photo 12 and
misused wall/cap surfaces in photos 9 and 11. Options considered were replacing
the horizontal stock, removing competing surface owners, or filling a remaining
uncovered region. The first two were implemented in issues 2/4. Final geometry
and image inspection did not justify adding another patch over those surfaces.

Eight focused surface tests pass 70 assertions, including original UV retention,
partial surface ownership, the actual photographed balcony/door, and fitted
horizontal ledge stock. All twelve town photo pins were rendered again in
`10-town-review`; the exact views were inspected alongside the earlier source
captures and the pixel comparisons in `10-town-east-diff` and
`10-town-west-diff`. The formerly broken floor patch reads as complete boards;
the tall miscellaneous panel at the market corner is now a continuous facade.
Nearby views and small camera shifts remain available in the render folder.
No separate production change was needed for this issue after the earlier fixes.

## Issue 9 evidence

Brainstorm: align the wall projections across the existing bank; fit each cover
to the projection beneath it; inspect whether separate trim strips are also
needed. The reproduced photo shows alternating deep bays and shallow bump-outs
on one continuous facade. Shallow bump-outs additionally carry full-depth caps,
extending 0.375 m behind and beyond their intended support footprint.

Construction now partitions eligible adjacent panels as before, then selects
one available depth for each continuous horizontal run. The run intersects the
existing two-profile clearance domains before emitting geometry. Long runs
prefer full bays; isolated pairs retain both authored profiles. Shallow caps
fit the actual half-depth projection. Wall-top bearing height is preserved.

Both new regressions fail against the old construction (eight failed assertions)
and pass with the change. The new and related joint tests pass 10 tests / 79
assertions. The west town's physical survey is identical before and after:
140 centered-clear walking cells and 205 centered-clear crossings.
The exact photo 1 and nearby views now show one straight covering edge along
both garden sides. The matched pixel comparison isolates the formerly shallow
bay and staggered boards. The nearby photo 2 approach and photo 12 floor remain
clean. Photo 11 retains the earlier corrected balcony, with no geometric change
in its comparison against issue 6. `09-garden-before`, `09-garden-candidate`,
`09-garden-diff` and `09-garden-east-diff` contain the reviewed pairs.

## Issue 1 evidence

- Red-first frozen west source: four rotated placements produce 16 m ground
  where the underlying ground is 13 m; the exit also has a blocking guard.
  `gate-regression-before.log` records five failing assertions.
- Final focused tests: 2 tests / 1,049 assertions pass, including tread heights,
  lower landing size, ground datum and duplicate post faces.
- Related regressions: 11 tests / 12,157 assertions pass. Complete perimeter
  corpus: 64 cases, no conflicts (`gate-corpus.log`).
- Streamed walking: six successful ascent/descent traversals per town, across
  the center and both sides. Final west evidence is `01-slopes-west-final`;
  east evidence is `01-slopes-east-walk`. Walking traces include every tick.
- Original photo-angle baseline is `01-slopes-before`. Matched exact, nearby,
  and slight-camera-motion renders show the spike replaced by an architectural
  flight with an open upper seam and a grounded lower landing. Main buildings
  remain; the perimeter and outer houses consume the newly reserved approach.
- Pixel comparisons are in `01-slopes-west-final-diff` and
  `01-slopes-east-diff`. Photo 13's marked region changes by 25.48 mean RGB
  levels, with 60.24% of pixels changing by more than 20. These describe the
  change; acceptance comes from looking at the renders and physical checks.
  Character animation, spirit lights and foliage can differ between captures.
- The first extra `gate_*_side.png` captures were taken before the camera
  transform settled; they are not acceptance evidence. Exact and nearby views
  use the existing settled ReviewCam workflow.
- Motion smoothness and general floor/railing surface joins remain the later
  issues in this pass; access success is not a claim that those are fixed.

## Issue 2 evidence

Single-cell boards were displaced by half a cell in both X and Z. The existing
asset pivot correction already handled their authored origin. Ordinary public
floors and courtyard paving now use the logical cell center, matching collision.
Two red-first measured-asset regressions fail before and pass after; the focused
and related suites pass 78 tests / 97,378 assertions. The western exact and
nearby renders show continuous boards in photo 12. The ROI comparison in
`02-surfaces-west-diff` isolates removal of the overlapping strips and triangular
patches. Photo 1 retains its existing trim geometry for issue 9.

The eastern verification revealed a second cause: full-height doorway caps
were omitted from interface preparation because imported feet extend 2.1 mm
below zero. The compiler and offline manifest now accept that measured course
base while retaining the 1 mm top-face tolerance. Ten ordinary baked interface
variants complete that vocabulary. Four focused tests include actual photo 11
floor/cap triangle intersections; the related ownership suite passes 10 tests
and 1,306 assertions. `02-surfaces-east-cap-candidate` and its matched diff
show the long overlapping cap removed, with continuous balcony planks.

## Issue 3 evidence

Different-depth, collinear facades from adjacent rooms now declare one recessed
timber joint. Same-room repeats, equal-depth contacts and perpendicular corner
contracts remain independent. The photographed seam closes in the exact view
and both nearby angles (`03-wall-seams-candidate` and `03-wall-seams-diff`).
The measured native timber mesh closes the full-height seam in four rotations.
Five seam/enclosure tests pass 98 assertions. The complete frozen town has
identical physical clearance to the previous accepted survey across 124 walk
cells and 179 crossings (`03-wall-clearance.json`).

## Issue 4 implementation and rejected candidates

Final review passed. Closed doorway return cuts survive ownership by a
shared corner. Timber miter cuts close with the native timber material and
one-sided faces; the stone doorway replaces its raw ends with authored masonry
relief inside its existing envelope. Its central door and arch triangles stay
unchanged. Additive corner posts and side-cover panels were rejected after
matched renders showed oversized members and stone poking through them; those
experimental placements are removed from production.

An isolated, uncovered retained shoulder continues masonry rather than wearing
one disconnected house panel. Actual room courses retain their styles. The
bank uses a dedicated stone-only profile with the original joining envelope;
it does not inherit a house wall's wooden skirting. Non-garden ledge caps use
fitted horizontal boards with exact private-floor surface ownership instead of
an upright wall rotated flat. Source arrays are prepared on the main thread.

The ledge regression fails on the pre-exterior compiler (two assertions). The
first stone-only bake also failed its material test because a 2 cm remnant of
the wooden skirt survived; the measured source strip is now fully excluded.
The full bake and incremental update retain 1,002 unique fabric provenance
records and 639 wall-interface records. Before/after images remain production
streamed captures; the faster frozen mesh views are diagnostic only.

Final evidence is `04-exteriors-final`, with matched comparisons in
`04-exteriors-final-diff` and the previous floor repair rechecked in
`04-final-floor-diff`. Exact and nearby views close the raw stone end in photo
4, both jagged doorway corners in photo 3, and the disconnected panel and deep
ledge in photo 9. Photo 7's seam and photo 11's continuous balcony remain clean.
The small camera shifts also show continuous finished edges.

The focused suite had 17/18 passing before the final envelope fit; its sole
failure was the measured retaining bounds. After fitting the cropped stock to
the original declared envelope, all three baked-exterior tests pass (108
assertions), the five cap-related tests pass (3,992 assertions), and the stock
constant check passes (180 assertions). The cap tests now inspect emitted board
vertices and the final shell's owned faces, including floor-partitioned pieces.
The broad composition baseline already had 12 failures and one pending test;
this review does not claim that entire legacy suite passes. The final physical
survey is byte-for-data identical to issue 3: 124 cells and 179 crossings.

## Issue 5: stair motion

Investigate real collision/body height and camera-follow motion separately.
Possible approaches: remove repeated lost-ground/fall cycles in the step solver;
then let the visible body and camera absorb discrete step handoffs with bounded
continuous motion. A camera-only filter is insufficient if the body still
bounces or loses floor contact. Preserve jump, downhill, edge and landing behavior.

The initial per-tick measurements reproduce roughly 47 cm of cumulative
backward vertical movement during each ascent, including individual drops of
8 cm. The body borrowed a future tread's height from a long probe while its
horizontal destination remained behind the edge. Steps now test their actual
destination. A short vertical ray at an ambiguous capsule contact distinguishes
a flat tread nose from an unwalkable face, including at slow speeds. A bounded
80 ms floor witness permits the normal finite snap onto the next lower tread;
it cannot cancel jumps, swim motion or real ledge falls.

The visible body uses an exact critically damped height response, and the camera
follows that same height. Camera orbit velocity uses horizontal movement.
Fourteen movement/camera/water-force tests pass 146 assertions, including low
ceilings, tall obstacles, jumping, ledges, slow ascent/descent, landing settlement
and the original ground-handoff walking test. The slow case failed on the first
candidate and passes after the tread-contact correction.

All five frozen flights pass ascent and descent at normal speed and at 35%
speed with a 1 m lateral offset (20 traversals). Typical normal-speed ascent has
about 1.1 cm of cumulative millimetre-scale collision recovery, with visible
height changes below 10 cm per 60 Hz frame instead of 32 cm; descent remains
monotone with visible changes below 11 cm. See `05-motion-metrics.json` and
`05-motion-height-traces.png`. A final animation check additionally prevents false jump/landing cycles at
tread noses while retaining the jump animation for deliberate jumps. The five
character tests pass 130 assertions after this adjustment; nine related camera
and water-force tests remain passing. Final streamed visual review passes. All ten ascent/descent traversals pass
in `05-motion-final/walking.json`. Matched motion frames, contact sheets and
height traces show continuous character/camera motion; the exact photo 7/8
diffs retain the surrounding construction. `05-motion-up.gif` and
`05-motion-down.gif` compare recorded frames at matching physics ticks.
Animations and ambient particles are not pixel-frozen, so dynamic differences
are judged with the measured trajectories rather than a changed-pixel score.

## Issue 6: walkway destinations (in progress)

Inspect photo 8's upper landing, its actual route connections, neighboring room
floor heights and reserved air. Prefer a real doorway when the landing meets a
habitable room at the same height; otherwise construct a usable terminal
platform with a deliberate boundary and purpose. Do not add a door into empty
mass or extend a deck through an existing room/roof reservation.

## Issue 6 evidence

The terminal flight ended halfway up its neighboring house storey. A doorway
would not meet a real interior floor. The carver now reserves a second platform
cell and open sky before bridge compounds and house plots consume that space.
The original stair itinerary stays intact; the final destination is a guarded
6 by 12 m overlook. This uses one source construction, with no completed house
deletion or alternate-town retry.

The red-first photographed source test and four-direction reservation test pass
2 tests / 73 assertions. The broader carver suite passes 12/13; its one frontage
density failure has the same three values in the pre-change baseline. No threshold
was weakened. The completed town has 128 clear walk cells and 185 passable crossings.
Eight crossings require an offset from their midpoint, versus four in the
baseline; none is blocked.
All five actual stair flights and the new platform join pass walking both ways
(12 traversals); the level join is measured center-to-center.

`06-destination-candidate` contains the matched photo 8, nearby angles, and five
neighboring photo locations. `06-destination-diff` compares with the final motion
baseline; `06-nearby-diff` checks the earlier exterior review. Photo 8's region
changes by 20.91 mean RGB levels, with 43.79% changing by more than 20. Visual
judgment confirms continuous boards, an open view and complete perimeter guards.
Room composition changes around the reserved air; the nearby doors, walls and
previously repaired floor caps were inspected again.

## Issue 7 evidence

Seven complete prefab houses used their door hinge as the approach center.
The authored entrance now uses the measured leaf center, while the attached
door retains its original hinge placement. This shifts only the approach
sideways by approximately 1.094 m at production scale.

The red-first measured-door test fails all 28 orientations before the fix.
The final two tests pass 63 assertions, including physical capsule sweeps
through the actual prefab jamb openings. Related program, junction and
frontage tests pass another 7 tests / 10,596 assertions. Door leaves remain
closed; the aperture sweeps intentionally test the house shell separately.

`07-doors-before`, `07-doors-candidate` and `07-doors-diff` contain exact,
nearby and small-camera-motion pairs for photos 6, 5 and 13. Visual inspection
shows centered, symmetric approaches at both reported doors; pixel changes
are localized to the former offset tabs plus ambient/character animation.

## Issue 8 evidence

The short gate handoff painted its full 6 m structural aperture next to a
4 m exterior road, creating two extra shoulders. Its paint now uses the
canonical road width; structural stair, walk and headroom reservations retain
their complete original width. The old handoff test now samples the actual
paint corridor rather than assuming every reserved square meter is painted.

The four-orientation width regression fails before and passes after. Related
gate and junction tests pass 5 tests / 4,513 assertions. `08-junction-candidate`
and `08-junction-diff`, paired with `07-doors-candidate`, verify photos 5, 6
and 13. Exact and nearby visual inspection confirms removal of both side
tabs with a straight connection into the larger town court.

## Issue 11 — candidate and rejected iterations

The photographed river had a roughly 12 m discontinuity between bank and bed.
The original narrow carving collar and the special one-storey water-bank cliff
rule combined to make a canyon. Options considered: raise the water datum,
reduce bed depth, or shape dry-bank controls through ordinary terrain slopes.
The third preserves hydraulic descent and was selected. A broad uniform bed
feather was rejected because it over-widened water and retained a cliff.

The current candidate keeps the ordinary terrain kernel, widens gentle bank
controls, and preserves the established profile around steep river descents.
Banks constrain hydraulic spill without seeding water themselves. Lake shores
retain their connected basin. This distinction was checked against historical
waterfall, narrow-passage and chunk-border regressions; source-pool spill and a
fine-lattice ceiling error were found and corrected during iteration.

A separate real-physics test found that exact water-box faces have zero point
query hits. The corrected trigger boxes overlap by 1 mm on each side; the sampler
continues to own wetness. The test fails at six shared-face/corner points before
and passes all twelve points after. The intermediate `11-river-final` run has
four successful shoreline walks, with no airborne frames and maximum per-frame
height change below 0.099 m. The final adaptive candidate is being re-rendered
in `11-river-reviewed`; it is not accepted solely on those intermediate images.

### Issue 11 final judgment

Accepted: the final `11-river-reviewed` exact, left/right and grounded views
show continuous banks reaching the river, with the former canyon wall and the
rejected candidate's distant high water sheet absent. The official pixel pair
uses `11-river-before-terrain`: both cameras are identical and both omit the
character, whose original elevation would float above the lowered bank. The
separately labelled grounded image shows the actual player at the new shore;
it is excluded from pixel comparisons because its camera elevation changes.

The photo-10 comparison has mean absolute RGB difference 17.796/255 within the
bank region, with 40.155% of its pixels changing by more than 20 in at least one
channel. Visual inspection attributes the large changes to removed cliff faces
and changed bank silhouette. Water animation and particles also contribute, so
the percentage is not a standalone correctness score. The sampled ground
profile shows the original 12 m discontinuity replaced by ordinary smooth
slopes at the unchanged 1.7 m water datum.

All four final shoreline traversals remain grounded for every frame, including
walking exactly along the former trigger seam. Maximum height change is below
0.099 m per physics frame. Before, the descents included 66 airborne frames and
both return climbs failed. The raw older harness's `passed` flag for descent
did not require groundedness; the recorded airborne counts are the relevant
physical failure, and are preserved in `11-river-walking-summary.json`.

The final six-suite water run passes 44 tests / 2,492 assertions. Current-world
water borders pass 2 tests / 5 assertions; water planning passes 26 / 6,498;
ordinary terrain passes 23 / 9,901. Total: 95 tests / 18,896 assertions. The
historical narrow-passage test continues to require wet endpoints and an
unobstructed submerged connection; its sparse repair count now allows zero,
since the connected lake handles that passage on the coarse lattice already.

Nearby town photos 1/2/12 were re-rendered in `11-town-recheck` and compared
against `10-town-review`. The repaired stairs, facade bank, and floor remain
unchanged in the relevant geometry; prominent local differences are the
character's animation pose. All six west-town gate traversals pass. The river
change does not withdraw any town or retry its placement.


## Additional self-review — porch approach

The unmarked turnout left of the market in photo 9 belongs to the large
prefab house. Its legacy entrance datum and broad foundation reservation put
the painted endpoint 3.7 m beyond the actual porch at production scale.
Options considered: remove the turnout, relocate the house/entry datum, or
publish the native porch's measured ground handoff. The third retains the
house's fixed placement and gives the existing path a real destination.

`VillageAssetSpec.ground_entrance_local` optionally declares that measured toe.
The SFV 006 blue/orange house uses local (0.019, 5.70); the legacy entrance and
floor datum remain placement inputs. Outskirts construction uses the measured
point when provided. The existing foundation rectangle remains conservative
for support and neighboring-house reservations.

The red physical regression finds no tread at any of 24 contact samples before
the metric is supplied. Afterward both themes and all four orientations meet
a real first tread at center and lateral offsets; every initial rise is below
the player step limit. The broader paint test now permits only the empty front
strip up to that measured toe and still rejects paint into the house. All four
related suites pass 7 tests / 6,231 assertions.

The final matched photo-9 pair and nearby/small-shift pixel comparisons show
only the extended approach and its rounded street junction as substantial
geometry changes. The approach-region mean absolute RGB difference is
2.379/255, with 4.262% of pixels changing by more than 20 in one channel.
Ambient lights contribute small differences. The supplemental ground view
confirms that paint ends at the native step instead of extending under the
house. All six final live traversals reach the porch landing or return to the
street in 55–56 physics frames, without a timeout. The test stops on the
landing before the closed doorway and requires full arrival. This completes
the additional cleanup. Final evidence is `12-porch-reviewed` and
`12-porch-final-diff`; the earlier `12-porch-after` run retained a looser
arrival tolerance and is not the final walking evidence.
