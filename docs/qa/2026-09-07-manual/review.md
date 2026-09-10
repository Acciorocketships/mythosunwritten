# September 7 manual review

Seed: 2697992464. Source screenshots: 9.18.24, 9.17.35, 9.16.07,
9.18.42, 9.15.45, and 9.15.23 PM, in attachment order.

The requested sequence is gaps → flicker → parallel paths → stair walking →
garden wall → town slopes. Each issue requires a failing regression, an
implementation, matched captures, pixel-difference inspection, and nearby-view
falsification before acceptance and before proceeding to the next issue.

## Camera evidence

`tests/harness/village_september7_qa.tscn` pins all six player/crosshair readings
and uses `ReviewCam.solve_cam`. Viewport aspect matches the photographed game
area after excluding the editor toolbar. The original overlay rounds positions
to 0.1 m and does not record camera distance after obstruction, rotation, or FOV.
Consequently these are reconstructed original angles, not provably identical
original camera transforms. The regenerated before/candidate cameras are
identical to one another; ±8° and 15 mm-shift captures are additional checks.

## 1. Diagonal wall gaps — verified at the reported sites

Baseline: `before/`. The reported upper door gap is reproduced. A production
geometry probe identifies the point contact of `room.slim.base.orange` at
(-4,4,1), yaw 2, and `room.row.base.orange` at (-5,4,-3), yaw 1. The town transform
is scale 2, origin (238.5,8.08,-365.5).

Brainstorm and diagnostic renders:

- Test whether within-room corner finishing alone caused the gaps. A broad
  exploratory slice scan found a separate gallery-recipe enclosure failure,
  but the photographed defect needs a test of two neighboring rooms.
- Restore original wall ends: substantially reduces the photographed gap,
  but leaves a narrow slit at the diagonal contact.
- Add a wide shared joint while retaining the existing cuts: rejected visually
  because it encroaches on the doorway and looks intrusive.
- Candidate: give diagonal room contacts a shared timber joint and restore
  square ends into it. Keep existing corner finish elsewhere.

The photographed two-room regression failed at all three sampled heights before
this candidate and passed after it. The first matched pair closed photograph 1
and the right-hand gap in photograph 5, but left photograph 2 unchanged.

Further iteration:

- Photograph 2 is a three-cell inside corner. An inward column closed the
  opening but occupied the photographed player's standing area: rejected.
- A thin angled wall between the two rear reveals cleared the player and
  closed the central opening. The reconstructed original camera is behind
  that repaired wall, so the exact image now sees its back. This original
  transform is retained, with separately labelled opposite and side views
  and a view resolved by the production camera collision solver.
- The side view exposed a residual end slit. Square ends alone did not close
  it. Additional reveal posts closed it but made the join visually busy:
  rejected. The current return projects the half-thickness of BOTH meeting
  slabs along the joining angle, closing the side slit with the original
  plain wall asset.
- The left-hand opening in photograph 5 also contained a real one-band
  terrace-height notch. A supported return wall now joins the taller masonry
  to the diagonal house; a shared timber joint closes its house end. Ordinary
  isolated steps retain their height. Missing bearings or owned walking
  surfaces cannot receive this return.
- Masonry junction ownership now includes inhabited room volume, rather than
  seeing only the rooms' sparse structural cells.

The exact frozen town's full building/support/retaining collision survey uses
  the existing conservative corpus capsule. Before and after: all 124 cell
  centers are clear; 175 of 179 crossings are clear at their centers and four
  need a lateral offset. No cell or crossing changes classification. This is
  a standing/crossing survey, not the later walking-stair test.

Candidate history is preserved in `01-gap-candidate/`, `02-gap-candidate/`
(rejected standing-area intrusion), `03-gap-candidate/`, `03-gap-expanded/`,
and `04-gap-candidate/`. The final matched set is `01-gaps-after/`;
`01-gaps-diff/` contains the pixel differences and comparison crops.

Final judging: the original roof/background slit in photograph 1 is enclosed;
both circled openings in photograph 5 are enclosed, including the full lower
and upper contact bands. The photograph 2 return is enclosed from the opposite
and side views, including the small seam caught in the first side inspection.
The reconstructed original camera is behind the now-closed wall; the production
camera retracts to a steep view of the small doorway recess. That framing change
is recorded rather than substituted into the original pixel pair.

The changed-pixel fractions (maximum RGB difference >20/255) inside the pinned
crops are 27.01% for photo 1, 75.19% for photo 2, and 24.22% for photo 5. The
large photo 2 difference includes the original camera's new wall occlusion.
The side crop changes 48.84%. Inspection of the heatmaps localizes the dominant
changes to the new closures; animated character/particle pixels account for
small unrelated differences. Pixel counts alone are not an enclosure proof.
Near-left/right views retain the closures. The 20 focused facade tests pass
(193 assertions), followed by a six-assertion check of the complete stone bands.
The four rotations and the absent-bearing/walk-owned negative cases pass.
This accepts the reported gap repair; it does not claim a universal full-town
visual audit or completion of the other five issues.

## 2. Coplanar flickering — verified at the reported floor

Baseline: `01-gaps-after/`; accepted result: `02-floor-candidate/`.
The lower-left gray streak is a retaining wall top and horizontal stone cap
competing with the private wooden floor at local height 6. Public floor ownership
already existed; private room floors were absent from that ownership.

Brainstorm: an offset would hide the symptom while keeping competing surfaces.
Instead, extend the existing exact floor ownership and baked wall-interface
contract to retaining masonry. Complete floor-owned cells omit their cap;
partially covered caps retain their original uncovered triangles and collision.
Upright wall caps use the existing course-open asset plus uncovered original
triangles, preserving exposed shoulders and material/UV data.

The pinned regression initially measured 1.74949 square meters of competing
stone triangles inside the floor. The first implementation left 0.31584 square
meters: imported wall tops deviate from the declared course plane by fractions
of a millimeter. The offline interface manifest now explicitly allows 1 mm
when identifying those top faces, without moving any source vertex. Ownership
matches the declared course plane. The final overlap is zero within 1e-5 m².
Main-thread preparation copies plain source arrays for worker clipping.

Judging: the broad gray stripe is absent from the exact, near-left/right and
15 mm camera-shift renders; the same wooden plank edges continue across it.
The pixel heatmap in `02-floor-diff/02_gallery_floor_comparison.png` localizes
the change to that stripe. 5.37% of the floor crop changes by >20/255, with
mean absolute RGB change 1.75/255. Nearby walls and the previously repaired
corner remain closed. Small particle/animation differences remain elsewhere.
The 18 floor/bake/ownership tests passed (1,401 assertions), followed by 11
floor/previous-gap/facade tests (1,302 assertions), including actual baked AND
clipped triangles and the partial-cap collision case. The complete photographed
town's 124 cell and 179 crossing collision results are identical to issue 1.
This accepts the reported floor flicker repair; it is not a claim that every
surface in every possible town has received a visual audit.

## 3. Parallel paths — verified at the reported frontage

Baseline: `02-floor-candidate/`. The world-road lattice paints z = -384;
the perimeter street paints z = -390. The same frontage therefore has two
independent 4 m strips. `path-owner-probe.json` preserves their provenance.

Brainstorm: broadening paint would turn the whole gap into a plaza and still
leave two route authorities. Moving the country road alone would fail whenever
the town's footprint changes. The candidate gives the completed circuit's
interior to the town street plan. A lower-priority natural surface withdraws
country-road paint inside that domain; the town's streets retain their higher
priority. Each incoming lattice arm publishes its boundary intersection as a
short shared street handoff before houses consume frontage. Existing country
roads outside the circuit and the immutable source network remain unchanged.

The frozen photographed regression failed with two painted runs, and now has
one. Incoming west-road continuity and physical headroom checks pass. Existing
frontage tests pass (3 tests / 5,865 assertions); an additional four-orientation
boundary test passes 252 assertions. Matched `03-path-candidate` exact and near-left/right views show one street;
`03-path-diff/03_parallel_paths_comparison.png` isolates the removed second
strip. 15.00% of the pinned crop changes by >20/255, with mean absolute RGB
change 7.36/255. The retained street keeps its 4 m width. Exact-world probes
confirm all previous house access and gate paths retain their coordinates;
three boundary joins are added (west, east and the existing primary approach).
This accepts the photographed double-path fix.

## 4. Stair walking — verified in the streamed town

Straight walking on the isolated construction initially passed all five public
flights, including a slower off-center pass. The streamed-town reproduction
then failed at `volume.transition.04`: player (246, 8.00015, -355.4084), first
tread at 8.58 m. The isolated fixture had omitted the 8 cm difference between
finished terrain and the structural datum. Its result could not establish the
real handoff. The other four flights passed in the streamed scene.

Brainstorm: increasing the player's step limit would change traversal throughout
the game. Lowering only the first tread would enlarge the next riser. The
candidate instead derives the complete flight's tread count from the existing
planned-step limit, world scale, and shared ground-datum guard. It emits eight
37.5 cm world risers; the first approach is 45.5 cm including that guard. The
flight footprint, upper/lower landings and player controller remain unchanged.
The shared guard now lives with the explicit world-frame conversion.

The new geometric and real-player regressions both failed before the change
(58 cm first step; player stopped at the foot) and pass after. The 28 focused
movement/production-surface tests pass, 917 assertions. Four-orientation and
ascending/descending geometry checks are additional verification. Matched sets `04-stairs-before-front/` and `04-stairs-after/` use the same
unobstructed stair camera and controller inputs. Before: first flight fails,
four others pass. After: all five pass, including the first flight from
(246,8.00,-356.2) to (246,11.13,-348.16), with no jump request. At tick 30 the
before player is still at the foot while the after player has climbed the
flight. `04-stairs-diff/volume.transition.04_tick_30_comparison.png` shows the
movement and additional treads; 30.47% of that crop changes by >20/255. This
count includes player movement and is supported by the physical trace, not
used alone as proof. Original photo pins and nearby/orbit views are also
regenerated. The photo 5 opposite view clearly retains the flight and rails
with smaller treads. Animated character/particle differences remain in the
static photo pairs. The extra orientation test passes 92 assertions.
This accepts walking up the five public flights of the photographed town.

## 5. Missing wall beneath grass — verified at the reported site

The neighboring pitched roof reserves whole cells beside the retained bank.
Those clearance cells were also hiding the wall, despite the empty wedge above
the actual roof. The new shell derives vertical enclosure from non-roof mass;
full roof reservations remain in the structural and clearance fields. Panel
clearance consumes that same final shell.

The first candidate closed the mesh-ray regression but was rejected visually:
one half became a purple terrain-rock strip. The material selector had counted
only the short portion exposed above the neighboring room. It now derives the
course pattern from the full retained bank, independently of neighboring room
occlusion. The second candidate restores the continuous upper facade course.

The frozen regression failed 8 of 13 assertions before implementation. The
final focused set passes 32 tests / 2,204 assertions, including actual mesh-ray
closure, unchanged roof reservations, four orientations, lower-room ownership,
and the earlier wall/floor/surface checks. The 124-cell / 179-connection physical
clearance survey remains identical.

The four-town shell census initially missed the floor-clipped CPU meshes
introduced in issue 2 (the same failures occurred before this garden change).
Its independent census now includes the actual clipped triangles and the room
floor that owns the removed portion, counting a shared floor once. All four
towns pass: 305 assertions, zero uncovered boundaries, duplicate caps or plinth
overlaps. Asset-only counts remain separate from the complete construction count.

The final exact and ±8° views show two matching timber/plaster wall panels
beneath the grass, meeting the existing side posts and roof without the rejected
purple strip. The pixel comparison isolates that infill: 19.69% of
the crop changes by >20/255; mean RGB change is 9.79/255.
The rest of the facade and roof retain their positions. This accepts issue 5.

## 6. Town slopes — verified in the streamed town

The terrain mesh and slope kernel were already shared. The outskirts adapter
introduced a second ramp model: it sampled conical height envelopes into new
3 m claims, then the terrain kernel treated every sample as a separate plateau.
The old photographed row contains 11, 10.375, 9.625, 8.875, 8.125, 8 m targets.
This produces the visible repeated ridges even though the final mesher is shared.

Brainstorm: a separate town ramp mesh would duplicate terrain/collision ownership;
changing the general terrain interpolation would change unrelated geography.
The implemented fix removes the conical street-height helper and preserves the
already continuous TerrainGradePatch field when extending street reservations.
New foundation claims retain fixed heights while existing streets inherit their
original field. Subsequent access paths also retain that field. Original terrain
centre/edge/corner sampling and the 12 m smootherstep collar remain authoritative.
Conservative bounds compose the same inherited fields. A bounded sample cache
stores 64-bit target/weight coefficients, independent of natural input, to avoid
repeated nested sampling without changing values.

Before: the new four-orientation profile regression failed 236 assertions.
After: the street follows exactly one normal 12 m transition, including through
later foundation/access-path stages. Bound tests sample the composed field over
210 boxes. The combined focused run passes 52 tests / 15,679 assertions before
the final cache-only change; exact cold/warm cache parity is checked separately.

The candidate exact and ±8° renders remove the repeated ridges, leaving a single
continuous rise to the elevated gate. The crop's >20/255 change fraction is
16.20%, mean RGB difference 9.55/255. The heatmap follows the changed slope and
path height, with the surrounding buildings retaining their positions in these
views. This is visual evidence; the independent shared-profile and bound tests
establish the field behavior. The streamed player walks the gate slope in both directions without jumping:
ascent (268,8.02,-346) → (252.2089,10.9824,-346), descent →
(268.0015,8.0011,-346). All five stair flights still pass in the same run.
The exact and nearby images plus those physical traces accept issue 6.
Final cache checks pass 13 tests / 13,051 assertions, including exact cold/warm
sample equality with different natural-height inputs.

## Validation scope

All six reported issues were addressed sequentially, with rejected candidates
retained in the evidence folders. The focused 52-test combined run passed,
along with the four-town 305-assertion shell census and the final cache checks.
The entire pre-existing test suite was not rerun to claim a clean result: the
initial full run had 19 failures and one pending test among 1,089 tests. Older
architectural reviews in AGENTS.md retain their own acceptance status.

The measured terrain-mesh phase for chunk (1,-2) was 40.2 s before the slope
change, 102.0 s for its uncached composition, and 27.5 s with the bounded cache.
These are individual matched capture runs, not a statistically controlled game
performance benchmark. The complete initial world planning remains expensive.

Final full views and before/final pixel comparisons for all six photo positions are linked in [comparisons.md](/Users/ryko/story/docs/qa/2026-09-07-manual/comparisons.md). The cached final render retains the reviewed geometry.
