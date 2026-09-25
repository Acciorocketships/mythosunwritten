# Biome landforms — iteration history

Final acceptance and limits are recorded in [result.md](result.md). Entries below
retain their original provisional findings and rejected candidates.

The existing height range clips all seven biomes at 32 m. The red height test
fails both assertions. The candidate uses continuous biome-owned geological
profiles, a 128 m range and 32 storeys, preserving the three-storey cliff step.
Highland relief was reduced from 1.0 to 0.85 after the first render exposed a
clipped summit. Twenty-one initial matched terrain pairs show stronger relief;
regular cell contours and overlapping survey cameras still need review.

The amplitude change initially reduced headwater counts to 16/8/9. Source and
lowland thresholds now retain their original physical heights rather than their
old fractions of amplitude. The three source censuses recover 53/51/50. The
height/water run passes 28 tests and has one assertion-free historical junction
test; this is not complete water acceptance. The photographed-world height
candidate loads in 211.036 seconds. Its twelve captures await final judging.

An overhead arch cannot come from a single-valued heightfield. A pure terrain
volume prototype admits complete opposite bearings, reserves its footprint from
vegetation and commits actual triangle collision. Two fixture tests pass ten
assertions, but the twelve paired renders in `arches` REJECT the prototype:
the smooth rectangular slab resembles a constructed bridge. The 2/90-degree
camera is inside terrain and is excluded. A narrow diagonal cleft at (-720,48)
is the sole eligible site in the initial 5.4 km survey. The full-world arrival
at this site exceeds eleven minutes in feature-context construction and is
not accepted. A native stack sample is being used to investigate that delay.

Braided-channel work currently has only a failing fixture and unused scaffolding.
The two assertions in `alluvium-red.log` fail. No braided water, delta or retained
island is claimed. The intended approach is canonical channel widening with
retained natural-ground bars, shared by terrain carving and physical water fill.

Issues 10 and 11 remain separately documented. No issue-12 completion or global
terrain, streaming, water or renderer acceptance is implied by their results.

## Follow-up iterations

The height dependency test first sampled 8,281 cells against a 2,500-cell bound.
The exact min-plus influence radius is ceil(max_storeys/max_step). Using it in
both compilers preserves all owned samples against the original full window,
including maximum spikes on both sides of its boundary. Fifty related tests
pass 5,850 assertions. This does not alone fix the slow arrival.

The beveled arch in `arch-rock` was also rejected for its shallow bridge-like
silhouette. `arch-ridge` raises an irregular rock crown and adds continuous
beveled strata, retaining a closed collision volume. Eleven usable matched
pairs/differences have been visually judged; the original 2/90 camera remains
excluded. Two physical tests pass 17 assertions. Full-world validation remains
pending, so this is a candidate rather than final acceptance.

All twelve `height-photo-differences` have now been judged. The revised geography
moves the settlement away from the old photo coordinates. These captures are
terrain/context evidence, not proof of the new settlement's construction or the
previous building repairs. The frozen actor is above the new physical ground;
its visibility cutout is not a supported-player bubble test.

The slow arrival is a road endpoint water query at (-1104,480). Its coarse
hydraulics complete; fine shoreline reconciliation repeatedly queues a ceiling
that rounds back to the existing float32 height. A two-node regression fails
1/2 assertions before the correction. The exact saved 175-by-468 coarse domain
replays in 1,312 ms after comparison in storage precision. The baseline direct
replay remains stuck after its flood queue completes, matching the full-world
failure. No water height is deliberately changed by suppressing non-changes.
Full water regressions and the production arrival are running.

The first alluvial candidate broadens bounded gentle wet-biome reaches and
retains offset ground bars, preserving the centerline hydraulic profile.
The fixture passes two tests / 14 assertions: bar centers retain 12 m terrain,
are physically dry, and have real wet channels on both sides. Rendering and
production occurrence/containment checks remain outstanding.


## Current-world follow-through

The fixed arch arrival completes in 272.884 seconds; the delta arrival in
250.526 seconds. Both are still expensive cold starts. Historical water tests
now explicitly retain their original input geography while exercising current
hydraulics: 30 tests / 1,297 assertions pass. These frozen inputs do not establish
current-world water coverage.

The three-seed raw census contains 160 rivers, 22 broad fans, 38 proposed bars,
78 lakes with islands and 31 peninsulas. Final river joining retains 15 bars.
Occurrence is not physical or visual acceptance. The alluvial fixture passes
2 tests / 14 assertions, but all twelve `alluvial-valid` pairs are visually
insufficient: the bars read as narrow, rectangular plateaus and clear water over
the green bed is hard to see. Actual delta overviews confirm the blocky bars.
This candidate is not accepted. An outer-branch sampler regression fails both
assertions because the former one-cell search misses the wider river; a width-
derived search radius is under test.

All thirty `landmark-differences` have been visually judged. They establish
larger relief, while strong coarse grid contours remain visible and some named
landforms are weak at these viewpoints. This is not yet complete visual
acceptance for the requested geological vocabulary.

All sixteen new world overview images have been judged. Seven arch views show
real bank bearings; `arch-world-overviews/14_270.png` is inside the cliff and is
excluded. The eight delta views show wet flow around retained dry bars, but the
bars need the visual iteration above. Finite nine-chunk snapshot boundaries are
visible in overview cameras and are not a production streaming acceptance test.

Five current-geography settlement records include three accepted hamlets, one
accepted 91-building town, and one rejected village at cell (51,22). The original
photo district now hosts a four-house hamlet at (-20,-13). The new rejected
village is a generator defect to investigate, not a valid empty town.


## Low-bar and native-only construction iterations

Width-aware water indexing passes 29 tests / 2,271 assertions, including both
outer-branch red assertions. The alluvial crest iteration lowers retained banks
to the next dry terrain storey above the local river datum and widens bar half-
widths from 24 to 36 m (lengths 54 to 72 m), inside a 120 m fan. Four tests / 20
assertions pass. Twelve matched lit first/second-candidate comparisons have been
judged: bars are lower and broader, but retain the coarse terrain's rectangular
contours. The clear-water fixture has poor water contrast; live-world checking
is running. Older proposed counts refer to the tall-bar candidate.

Village cell (51,22), seed 2695877283924445960, is a compact source containing
three fully reserved native prefabs and zero modular houses. The empty modular
subset was incorrectly fatal in parcel sealing, room composition, support-graph
admission, rooftop-court planning, feature generation and room/roof compilation.
The root repair carries native reservations and their real terrain roots through
the shared construction graph. Empty modular work is allowed and cached as a
completed result; an entirely empty town remains invalid. Optional court planning
naturally finds no modular crowns. The complete original source now constructs
all three prefabs (1 test / 28 assertions before added negative guards). The
subsequent five valid related files pass 13 tests / 647 assertions, but that run
also names two nonexistent test files and must be rerun correctly. The required
48-town corpus and eight native views are running. No native-only acceptance yet.


## Current verification follow-through

The native-only construction repair passes the mandatory 48/48 production town
corpus and the fingerprinted 95-assertion composition gate. No timing pins were
changed. The newly admitted three-prefab source has 76 clear public centers and
114 clear crossings, checked against the complete native collision payload.
Eight live overview angles show the native buildings and retaining garden beds
meeting actual terrain; the earlier bare-stage views alone did not prove that.
Its cold arrival takes 320.957 seconds with other bounded QA work running, so
this is neither an isolated benchmark nor a startup improvement. The three
close frozen-player views are context only: the fixed 12 m player pin lies below
the new town's raised ground and produces a visibility cutout.

All eight low-bar live before/after comparisons are judged. The previous high
bank remnants become low islands with water visible on both sides. All six bars
sampled from three seeds have 4 m dry centers and two wet side channels over
0 m ground, with measured water levels 1.2 or 1.7 m. The final joined census has
160 rivers, 11 widened fans, 15 retained bars, 31 lake islands and 13 peninsulas.
These occurrence counts do not establish the physical state of every bar or lake.

The stronger closed-arch mesh regression rejected the concave end-cap triangle
fan: 18 unmatched/oriented edges in each of four axes. Proper polygon
triangulation preserves all boundary vertices and closes both buried ends;
three tests / 29 assertions pass. All six actual-character swims pass through
the opening, at offsets -2/0/+2 m in both directions. Five take 366 physics ticks,
one 314; their final progress exceeds 10 m from starts at -10 m. The first
360-tick deadline was too short: the character continuously reached +9.68 m,
without a blockage. That trace remains in arch-traversal/short-timeout.json.
All 18 matched start/middle/end image pairs are judged. Their before images hide
the arch visual at the same actor/camera pose; collision remains active throughout
both captures and all traversals. They are not pre-change physical-route claims.
The native scene's very clear water has poor visual contrast against its green
bed; live world views remain the water-appearance evidence.

All thirty broad landmark before/after pairs are also judged. The larger
height range is visible, while amphitheatre/hollow/terraced-valley silhouettes
remain subtle at this aerial scale and the existing coarse contour grid is
obvious. Closer matched silhouettes and actual lake/drop views are running.
No full geological-vocabulary acceptance is recorded yet.


## Lake ownership and buried trigger follow-up

The consolidated pre-lake run passes 61 tests / 9,977 assertions. All thirty
closer landmark pairs are now judged: mountains, flat mesas, ridge saddles and
clefts read more clearly; forest bowls and terrace valleys remain restrained
rather than dramatic, with the established stepped terrain style visible.

The production lake/drop renders expose a real composition failure: a broad
river excavates dry land reserved by its receiving pond. The new focused fixture
fails two of three assertions before the repair, then passes with its dry island
and wet inlet. PondStamp now exports its existing island excavation weight to
the incoming RiverTrace's shared terrain reservation. Terminal lake land uses
finite angular reservations inside the actual wobbled basin, with a clear wet
inlet and a complete wet rim (an outward bank connection is allowed for a
peninsula). The three-seed final census now admits seven lake-land reservations,
including three peninsulas, rather than crediting 31 unverified proposals.
The three-seed physical and live visual follow-up is still running.

The steeper drop also exposes negative Area3D box heights in tiles touched only
by deeply buried water closure vertices. A red regression reproduces the empty
vertical interval. WaterSkin now omits that interval instead of constructing an
inverted swimming volume. It does not change any visual mesh. The combined
lake/trigger/alluvial/photographed-water follow-up passes 16 tests / 426 assertions.
Earlier water-landmarks images contain invalid-volume errors and are not accepted
as complete physical evidence; clean recaptures are running.


## Final physical and material follow-through

The final combined native/height/water run passes 64 tests / 10,009 assertions
with a clean exit (308.528 s). The six lake-land cases across three seeds all
pass: three dry island centers have twelve wet perimeter samples each, and three
dry peninsula centers have seven wet flank samples each (63 positions total).
All three peninsula center-to-bank paths remain dry at thirteen positions each.
The bare `nan` dry-water levels in these JSON records were normalized to JSON
`null`; the original console logs retain the raw Godot values.

Eight full-world peninsula views show its dry head and wet flanks. Cold arrival
is 261.286 s. The initial gorge arrival is 270.426 s, but the fixed player pin is
below the 48 m physical terrain and is not usable camera/character evidence.
Two of its eight initial overview cameras are also inside terrain. An explicit
snapshot raycast now measures the target and raises cameras above real ground;
StaticBody3D processing is re-enabled solely for these snapshot ray queries.
No terrain or collision was changed to accommodate a review camera.

The corrected gorge views exposed insufficient contrast on the falling water.
A first scattering candidate brightened lateral shoreline faces and was rejected.
A second required alignment with the current and excluded the near-shore closure,
but incorrectly depended on the sign of a two-sided surface normal. It was also
rejected. The saved native mesh has 127,933 vertices, 19,446 flowing interior
vertices, and an interior downstream grade up to 1.625; a raw trace-bed drop alone
was not an adequate visual acceptance metric.

The third candidate uses gravitational head-loss power from the existing slope
and current, the magnitude of actual mesh grade along that current, and an
explicit 2–6 m shoreline exclusion. It changes light scattering only on the
steep moving interior, without a repeated streak texture, new water mesh or
hydraulic change. Eight matched gorge pairs are judged: exposed falling faces
are clearer, while reverse/occluded views provide context rather than proof of
a visible change. The terrain retains its coarse stepped style and broad clear
cascades; no plume/spray or realistic erosion claim is made.

The real-GPU probe fails red on the missing falling response and passes all five
cases from each side after the repair. The active falling patch changes by
0.322876 normalized mean RGB; stationary, flat, transverse-face and near-shore
controls change by exactly zero. Seven existing water shader tests / 47 assertions
pass. All eight matched full-world lake controls are judged: no pixels change by
more than 20 RGB levels; mean whole-frame differences are 0.0235–0.1326 of 255,
including unrelated live shader timing. The exact flat-water GPU control, rather
than that small whole-world timing noise, proves the unchanged calm response.

A fresh production island arrival and final native lake/gorge recapture are
running before final acceptance. Their results belong in result.md only after
inspection. Earlier invalid-volume captures and below-ground camera pins remain
excluded; the previous failed candidates and differences are retained.


## Closing captures and acceptance

The final production island arrival completes in 327.947 seconds with all nine
startup chunks. Three player views and eight island overview angles are judged;
one low view is partly occluded by trees. The dry island is surrounded by water,
consistent with its independent physical center/perimeter survey. The snapshot
exporter emits Godot's one-time global-parameter-list performance warning; no
terrain-generation failure is present. The snapshot overview replay exits cleanly.

The final native lake/gorge recapture supplies twelve judged before/after pairs
with 12/12 identical serialized camera transforms, no invalid-volume errors and
a clean exit. Native lake water remains hard to distinguish against the bare
terrain, so full-world views provide the material/shore-appearance evidence.
Both sides of the five-case GPU probe pass. The final result accepts the implemented
vocabulary and inspected repairs while retaining the explicit coarse-grid,
subtle-valley, clear-cascade, cold-start and historical-test limitations. No
universal water, streaming, collision or renderer claim is made.
