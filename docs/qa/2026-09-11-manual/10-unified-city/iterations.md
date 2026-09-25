# Unified city source — active

Baseline is accepted issue 9. Live before: ../09-prefabs/live-after. The saved
native before payload contains the common warren only; the full live snapshot
also contains the later perimeter streets and ground houses.

Diagnosis: VillagePlan._build first solves/materializes the warren, then calls
VillageOutskirtsConstruction.generate. That function builds a perimeter circuit
from finished urban bounds and allocates ground-house frontage against already
finished buildings. Even inward/shared frontage remains this second allocation.
Ground hamlets already omit the second pass but use a separate square/frontage
source. The universal ring therefore still exists in the production call graph.

Brainstorm: (1) merely suppress the outer rows or distort their ring; rejected as
not source unification. (2) merge their completed payload into the fabric record;
rejected because the decisions remain sequential and disconnected. (3) reserve
shared low/high construction space, public routes and native sites before either
kind of building exists, then use one plot allocation and materialization; favored.
Existing one-storey source rims, courtyard/ridge/crescent forms and measured
native reservation families provide the common foundation. Real country-road
handoffs must survive; invented perimeter circuits must not be required. Tiny
settlement focal reservations and three-to-six-house scale must remain meaningful.

No production change or acceptance yet. Establish a failing ownership/topology
invariant and inspect source/road/hamlet constraints before implementation.


## Proposal 1 — shared low neighborhoods (under verification)

The source-only comparison covers the photo seed and compact seeds 2, 9 and 11.
All twelve source masses validate. Merely widening the radius yields 2/2/0/1
native plots, compared with baseline 2/0/1/2. Combining two low lobes with the
original field before all streets and plots yields 4/1/2/2. The source preserves
courtyard/crescent exclusions, whole-storey terrace coalescing and low rims.
The photographic proposal fully compiles: 23 modular room records and four
native prefab features, versus 28 and two in the previous common-source core.
The complete baseline game also contains its later ground-house pass, which the
native-only comparison deliberately does not pretend to include.

The production candidate adopts the shared field, two additional source lanes
and three additional native requests per tier. These remain legal-site requests,
not forced placements. VillagePlan no longer calls the completed-city house
allocator. Existing tiny hamlets keep their already self-contained focal square
and 3–6-house allocation; they have no added warren/outskirts pass.

Actual external roads meet source gates through the shorter outside boundary arc.
Only crossed canonical road edges create connections. There is no unconditional
four-side circuit and no external building allocation. The existing street paint,
clearance and continuous-grade machinery emits these connections. The source city
owns a natural ground-paint domain so country roads cannot draw through its rooms.
This external connection geometry does not allocate or rearrange buildings.

Red/green: requires_outskirts was true in baseline. The low-neighborhood test
finds two source native plots in baseline versus four in the candidate. An initial
version incorrectly required all four at datum zero; actual inspection finds two
at zero and two at a half-storey terrace. The corrected low-terrace assertion was
rerun against the isolated baseline and still fails (2 < 4). Final four focused
checks pass 113 assertions, including all four cardinal road handoffs, isolated
no-road topology, interior paint ownership and short-arc geometry.

Prototype native overview and lower-angle captures are paired with the same
transform and camera. Full production photo replays, 48-town composition and
actual physical route checks are still running. No issue-10 acceptance yet.

## Proposal 1 gate findings

The first full sweep constructs 47/48 towns. Seed 8/grand fails a measured roof
intersection; frozen source and complete failure are preserved in
`tests/fixtures/september11-unified-roof-source.txt` and `roof-case-red.log`.
The other 47 have 11,732 clear public centres and 16,883 clear crossings.
The historical 95-assertion composition gate passes because its grand-town floor
permits a failed town. This does NOT accept the candidate. The roof conflict is
still a blocker. The world-record probe also exposed two noncanonical keys added
to the sealed fabric audit. Those connection records now belong to a typed urban
plan field; independent world-record validation must be rerun.

## Owner follow-up: floating grass platform

The owner explicitly flagged the remaining floating grass and isolated tall
skywalk endpoints. These stay within issue 10 before acceptance. Grass was handled
first. Seven capped garden cells at y=3 over public air survived because the
retained-earth closure treated any public-air reservation as a tunnel. They were
ordinary retained soil, not the separately planned suspended plaza.

Brainstorm: adding pillars through the public street would change clearance;
hiding the grass would leave the floating base. Instead, final retained-source
ownership must prove a continuous roof between two opposing actual jambs.

First red: public air alone incorrectly preserved a one-sided soil cantilever
(13/14 assertions). First candidate passed the synthetic test but was REJECTED
visually: it removed the turf and three cells, leaving four floating stone cells
with a timber cap. The opposing-support ray had crossed an uncovered gap to a
far building. Second red pins precisely that disconnected crown (17/18).
The final proof requires continuous retained/built ceiling cells all the way to
both actual jambs. Seven photographed bed cells are now absent, and no unsupported
capped garden remains. The normal garden, skin, underside and furnishing consumers
all use that corrected retained set; no asset or render-only exception is added.

Verification: 4 focused/older turf tests pass 47 assertions, and 6 related
skywalk/overhang/prefab-floor tests pass 195. Actual collision remains identical
at 132 public positions / 186 crossings, all clear (`grass-final-clearance.json`).
Sixteen native camera pairs and differences were inspected: 14 show the complete
platform removal (1.63–7.04% of pixels exceed 20 RGB levels); 2 reverse views
are obscured and exactly unchanged, so they provide context only. Both source
photo cameras and nearby turns show no remaining stone/timber remnant.

Twelve full-world photo-camera pairs (`live-after` → `grass-live`) were also
inspected with differences. All 12 camera transforms match exactly. The six
03/04 views clearly remove the platform; 01/02 are mostly clipped context.
Dynamic spirit positions differ between cold runs, which the diff shows separately.
The source screenshots round coordinates, so only the paired reconstructed cameras
are exact. Replayed actor coordinates are frozen diagnostic positions, not proof
of a supported stance after geometry changes. Cold startup was 128.536 seconds.
The photographed grass-platform repair passes this local review; issue 10 remains
open for isolated towers, the roof conflict and the complete final corpus.

## Owner follow-up: isolated skywalk towers

The old source accepted two perimeter spans whose endpoint stacks rose above
nearby building mass. Truncating their final rooms would strand their spans;
adding arbitrary tall neighbors would preserve the same artificial silhouette.
The selected repair moves the rule to source admission: each complete endpoint
foundation group must share an external wall column for the full storey just
below the proposed span. Both endpoints and the span itself are excluded as
witnesses. Future public-air openings invalidate a witness before placement.
The existing bearing and clearance proof still applies.

The photographed source fails three of four endpoint checks before the change.
Afterward it keeps one interior span with both endpoints in substantial adjacent
mass. The 48-source matrix retains 122 spans and passes 345 assertions, including
checks against the final carved/opened field. These prove neighboring construction
mass, not playable interior access or universal final-room graph connectivity.

The local final town compiles and retains 132 clear public positions / 186 clear
crossings. Sixteen native photo/nearby pairs and sixteen orbit overview pairs were
judged with differences. The old isolated tall endpoints disappear; remaining high
roofs belong to a wider connected cluster. The grass platform stays absent.

Twelve clean full-world snapshot pairs (`tower-before-frozen` to
`tower-frozen-persistent`) were also judged, all with exactly identical paired
camera transforms. All twelve show the removed perimeter tower mass; 03's large
new foreground building obscures part of the interior replacement span, which is
checked by the orbit views. Changed pixels above 20 RGB levels range from 16.96%
to 56.07%; differences reflect rearranged room allocation as well as tower removal.
Snapshot grass tint differs from the live biome tint, so these are geometry
comparisons. Original photo coordinates remain rounded to 0.1 m.

Four frames from the earlier cold `tower-live` capture were wholly black and are
EXCLUDED: all three 01 poses and `02_bubble_8`. The eight valid live images were
inspected. A separate persistent-camera-bubble replay produces twelve nonblack
images, and the marked GPU probe records 1,440 finite-color samples (1,430 mapped
pose identities agree; ten marker samples are unmapped). This does not explain or
resolve the four failed readbacks. No renderer change or additional renderer
acceptance is claimed. The QA harness's optional `--persistent-bubble` uses the
normal camera-owned component across poses instead of creating/freeing a new one
for every still. The old capture mode remains available for reproduction.

Local tower geometry review passes. Issue 10 still needs the unrelated measured
roof-domain conflict resolved and a fresh complete construction corpus.

## Final roof-domain repair and construction corpus

The grand seed-8 failure was not a need for a whole-town retry. Its complete
residual room had a stale topology `flat_roof` proposal despite its complete,
exposed private crown. Early clearance reserved ordinary and tight native gables;
final selection consumed the stale flat marker, returned no full-roof alternatives,
and eventually failed its setback fallback against the neighboring row roof.

The frozen source regression fails 6 of 8 assertions before repair: five promised
options are missing from final selection and construction returns null. The shared
full-crown domain now ignores a stale flat topology marker and always retains its
measured complete tight alternatives. Explicit bridge-party profiles stay in their
own domain; public floors and upper-load classifications remain outside this path.
The frozen case builds with the original row dormer and a complete tight slim gable.
No seam tolerance, asset, source seed exception, or town retry changes.

The first isolated roof render was rejected as a diagnostic: it included a merged
continuous roof with its other supporting rooms omitted, producing an apparent
extension. `roof-native-incomplete-context` preserves that invalid isolation.
The corrected twelve native comparisons use complete recipe geometry consistently
in both phases. All twelve were judged; the eaves shorten and the redundant slim
dormer disappears without a hole. They compare the exact REJECTED roof candidates
from the red log with the selected native recipes, not two formerly valid towns.
Pixel changes above 20 RGB levels are 0.20–1.64% of each full frame.

The photographed final payload remains byte-for-byte identical to the tower
candidate after this roof repair, including rooms, batches, surfaces and collision.
The earlier unified-city test's four-prefab minimum described proposal 1. The
connected span's different source reservation leaves three low native prefabs,
still above the old core's two; the test now pins that agreed composition tradeoff
rather than requiring an extra house by displacing the connected span.

All nine final focused tests pass 484 assertions. The fresh four-scale matrix
constructs 48/48 towns, with 11,868 clear public centers and 17,038 clear crossings;
no blocked center, crossing, unreachable public cell or split public component.
Twenty-four off-center pillar contacts remain. The fingerprinted composition gate
passes 95/95 with raw host calibration 0.949 (applied 1.000); timing pins are unchanged.
Sweep timings include other bounded QA work and are not standalone benchmarks.
Five real world records (one town, three villages, one hamlet), including the
photographed town, all validate and all have no separate outskirts transaction.

Sixteen full-world wide pairs (`world-overviews/before` to `world-final`) were
judged with identical paired cameras. The detached ring, its perimeter street,
and the old isolated upper towers are absent. Low native houses and modular upper
rooms form one closer cluster with its real external road handoff retained.
Full-frame changes above 20 RGB levels range from 21.90% to 40.07%. These are
snapshot geometry comparisons; biome/animation differences are not geometric proof.

Final review: all twelve full issue-10 photo pairs match camera transforms and
are nonblack; all were visually judged with differences. Full-town seed-8 roof
views confirm the merged roof has actual neighboring supports: six clearly expose
the join, four are partial context and two are occluded. The related run passes
33 tests / 8,597 assertions. Alongside 9 / 484 focused and the 95-assertion gate,
this closes issue 10 within the limits in `result.md`.
