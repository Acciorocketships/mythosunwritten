## September 7 continuation — current evidence

The aligned perimeter screenshot is visually accepted at the user's marked junction:
[before](../../artifacts/qa/2026-09-05-evening/perimeter-user-before.png),
[after](../../artifacts/qa/2026-09-05-evening/perimeter-straight-gates-after/north_path_junction_plan_view.png).
It has a shared left/right junction, one four-metre circuit, an open incoming approach,
and houses directly along the perimeter. The secondary entrance notches were caused
by snapping a gate to the primary entrance's 3 m phase. Each gate now retains its
transverse coordinate to the perimeter, producing one cardinal segment. The exact
[doorway view](../../artifacts/qa/2026-09-05-evening/perimeter-straight-gates-after/door_wall_openings_exact.png)
and [east path view](../../artifacts/qa/2026-09-05-evening/perimeter-straight-gates-after/east_path_house_exact.png)
show the clean transition. All four camera pins completed with `ready=true`.
The reported-town test passes 2 tests / 5,824 assertions; the completed geometry
corpus passes all 64 combinations of four seeds, four town scales and four road orientations,
including physical town/lane clearance. These checks run independently of generation.

The three original terrain locations were recaptured with `after-perimeter-final` and
visually inspected: the blank cliff face has authored rock, the apron stripe is gone,
and the sky-blue ground hole is closed. Every harness completed its exact, later,
ownership and raised views. The missing-town location now has a populated, connected
town; its exact camera lies inside the restored building, so an additional overview
shows the complete result. These use the preserved September 6 geography in the review
checkout, with current terrain and town fixes; unrelated live biome/world changes remain
in the main checkout.

Focused checks: the current production-record harness passes four seeds, inspecting
existing source/spatial/fabric construction and stocked-stall realization. It no longer
reads the removed parcel adapter or assumes every size profile has two freestanding
markets. Legacy richness/coverage measurements remain informational in report schema 2.
The bridge test now pairs its frozen river with `ReportedWaterPlan.make_heightfield()`
and passes 2 tests / 22 assertions. The photographed floor-cap test preserves the exact
measured upper-floor rectangles despite later room layout changes and passes 19 assertions.

Full-suite run 6 (`/tmp/september7-full-gut-6.log`) finished with 1,069 passing tests,
19 failing tests and one pending corpus check; it is not a passing acceptance run.
The engine also crashed during shutdown after printing the results. Three failing
areas have since passed focused checks: the frozen bridge geography, the photographed
floor caps, and the (16,-201) supported upper floor.
Other source/geometry regressions remain open.

The 46-site survey identified a garden-roof/frame intersection at (116,-241) and a
spine construction failure at (19,-120). Both garden construction paths now use the
fixed support-column reservation. The garden regression and the full related roof/room
set pass: 16 tests / 51 assertions (`/tmp/roof-column-final-check.log`). The spine failure
and the broader no-retry migration remain open. A test-only experiment confirmed that
simply replacing the old spine search with greedy forward steps is insufficient:
88/101 routes missed the existing construction contract, and a contour-led variant
still missed 69/101. Neither experiment changed production. A constructive replacement
must own the street's required space before emitting the town; disabling validation
or returning incomplete routes is not a solution. Do not describe the whole request
as complete.

The final 49-chunk cold profile completed on the current main geography:
resource preparation 9,344.4 ms; worker total 431,083.1 ms (8,797.6 ms average,
75,507.0 ms worst at (-3,-3)); feature context 102,604.1 ms; terrain meshes
300,773.4 ms; water payload 14,842.6 ms; dressing 8,419.5 ms; commit total
6,726.8 ms. Process peak was 3,515.4 MiB. Log:
`/tmp/september7-terrain-final-profile.log`. Focused roof tests and the expanded
perimeter corpus overlapped portions of this run; it is not an isolated timing
comparison. Terrain mesh construction remains the largest measured component.

# September 5 evening village review

Work remains in progress. The original facade and ground defects have targeted
regression coverage and matched captures. The owner rejected the later street
spurs and staggered junctions; the replacement now constructs one constant-width
exterior circuit, keeps its incoming approach clear, and places houses directly
along its four frontage sides. The final matched overhead and ground captures pass the walkway review.
Full GUT run 6 has finished with failures, detailed above. Removal of all lower-level generation retries is not complete.

Seed **2697992464**. Camera reconstruction uses the rounded player/crosshair overlay
through ReviewCam. Before/after pairs use identical reconstructed transforms, with
nearby angles and alternating camera jitter. Historical captures use the original
world geography in `/private/tmp/story-september6-review`; the atmosphere rebuild
intentionally changes current seed geography. Current-world tests are separate.

| Report | Player / crosshair | Latest visual finding |
|---|---|---|
| 5:51:08 doorway walls | (282.9,5,305.1) / (282.6,5.2,305.3) | Both reported apertures are closed in exact and both nearby views. |
| 5:51:45 fins and flicker | (258.8,27.6,306.3) / (258.4,27.9,306.2) | Historical camera remains obstructed. Matched gallery jitter captures show closed stacked-facade seams. All three pinned coplanar overlaps are zero, including the partially covered rock wall; exposed cap geometry is retained. |
| 5:52:23 house / paths | (303,5,272.9) / (303.2,5.2,272.7) | Inner and outer streets connect; the former lane-overlapping house has a reserved lot. |
| 5:52:33 T junction | (260.1,4.8,270.1) / (260,5.1,269.7) | Plan view confirms continuous entry and rounded junctions. New houses obscure part of the original ground camera. |

Before renders: `/Users/ryko/story/artifacts/qa/2026-09-05-evening/before/`.
The owner-annotated perimeter before image is
`artifacts/qa/2026-09-05-evening/perimeter-user-before.png`.
`perimeter-after/` was inspected and exposed the approach-blocking house and
obsolete apron teeth; it is an intermediate result, not acceptance evidence.
`perimeter-clean-after/` completed all four reported viewpoints. Its matched
overhead and exact north ground views show the aligned junction, open approach,
constant-width perimeter and removal of the protruding apron teeth.
Matched wall-cap before/after renders: `/Users/ryko/story/artifacts/qa/2026-09-05-evening/wall-cap-before/` and `/Users/ryko/story/artifacts/qa/2026-09-05-evening/wall-cap-after/`. These hold the original geography and pre-alley-change construction constant.
Each spot has `exact`, `near_left`, `near_right`, and `jitter_0` through `jitter_3`.
The north junction also has `overview` and `plan_view`.

![Door walls after](/Users/ryko/story/artifacts/qa/2026-09-05-evening/owned-interfaces-review/door_wall_openings_exact.png)
![Upper facades alternate angle](/Users/ryko/story/artifacts/qa/2026-09-05-evening/wall-cap-after/upper_facade_overlap_gallery_jitter_0.png)
![Connected east paths](/Users/ryko/story/artifacts/qa/2026-09-05-evening/owned-interfaces-review/east_path_house_exact.png)
![North junction plan view](/Users/ryko/story/artifacts/qa/2026-09-05-evening/owned-interfaces-review/north_path_junction_plan_view.png)

The two pictured doors belong to distinct buildings: `spatial.maze_back.01` and
`spatial.parcel.maze.house.017.part00`. The ownership audit found no building with
more than one addressed room in this fixture. Legitimate neighboring doors remain.
Deep door panels retain whole ends; perpendicular returns stop at the measured
back plane. The offline manifest contains 397 variants and repeated export is
byte-identical. The rejected diagonal-cap experiment has been restored away.

Production outskirts use continuous frontage intervals derived from measured house,
road, and town bounds. Houses and their grade pads are constructed from those
intervals once. Public street handoffs use the terrain's paint and collision.
The old 122-second outskirts trial profile is historical, not the current result.
The September 7 profile measured 1.69 s for four village cores and 6.30 s for their outskirts, inside a 244.06 s / 49-chunk worker run. Feature context and terrain meshing dominated that run. It predates the latest cap and street changes and had some concurrent targeted tests, so it is not an isolated final benchmark.

Town existence no longer depends on road acceptance. Current-world tests passed
46 generated towns over 31.85 km² after the court and bridge-crown fixes. Removing
completed-room cleanup exposed bearing and roof-space defects. Upper-room contacts
now constrain the lower floorplate domain; exposed tops and undersides reserve
vertical interfaces before neighboring variations are selected. Production no longer
runs the support repair, repeated silhouette relief, crown truncation, or global roof
repair passes. The first sweep after one-pass alleys and loops generated 48/48 towns
in 286.926 s, with all 9,288 walk cells and 13,210 route gates clear. No street
pinches, collisions, split routes or unreachable walks were found. The composition
suite passed 86/87 tests (7,860/7,861 assertions). The remaining assertion counted
three overlapping width alternatives at one bridge location as independent sites;
its independent reservation-capacity correction passes, while still requiring two
connections whenever a disjoint pair exists. The final matching sweep also passed 48/48 in 286.049 s with identical cell/gate counts; the full 87-test composition file passed inside full GUT run 4.

Alley budgets now come directly from the size profile. Existing streets reserve
housing space before later excavation, and each selected alley/loop is emitted once.
The completed-lane frontage audits, whole-volume previews, rollback and next-candidate
retry are removed. Eighteen source tests passed (2,014 assertions), and the formerly
failing sloped frontage case now passes without changing its threshold. The added
reservation, surface-partition and material-commit tests pass (16 tests, 158 assertions).
The three cap overlaps plus corner and bake checks pass (13 tests, 134 assertions).

Full GUT run 4 completed 1,056/1,061 tests (368,003/368,011 assertions,
1,953.231 s). Its five failed tests identified one real packing defect, intended
doorstep contact scored as overlap, and three fixtures whose photographed source
geometry had changed with the street algorithm. Deterministic end packing now
constructs seven rather than five ground houses; the frontage/doorstep tests pass
(5 tests, 7,609 assertions). A one-centimetre intrusion still fails the independent
paint-area test. No houses are tried, rejected or repacked.

The canopy test now explicitly retains its original measured junction and adds an
undeclared-seam negative case (1 test, 9 assertions). The original doorway/lawn
source and the rock-shoulder source are frozen as readable CPU facts in test-only
fixtures, and compiled by the current code. The current generated town still runs
its separate integration checks. The four reported-ground tests pass (82 assertions),
and all 42 plot tests passed in the fixture run. These changes preserve regression
coverage rather than deleting the original geometric cases. Full GUT run 5 passed all 1,063 tests and 370,870 assertions. Godot again
crashed during shutdown afterward (exit 134), so this is a passing test summary,
not a clean process exit.
Godot again crashed during run 4 shutdown with a recursive-mutex error after its
summary; the test process did not exit cleanly.

The six unused room-repair helpers remain in their test fixture, with all five
original tests retained. The 128-phase massif retry loop has now been removed.
One coherent field, bounded terrace regions and ascending room-band construction
pass the 48-town construction sweep. The integrated physical sweep also passes
48/48: 8,884 walk positions, 12,692 connections, no blocked passages, pinched
streets or disconnected sections. After removing cantilever combination search
and town-wide support backtracking, the same physical counts still pass:
`/tmp/direct-support-production-clearance-48.log`. The exhaustive support solver
is retained only as a test oracle. All 16 mixed four-course obstacle patterns
match its preferred result and independently clear reserved construction
(two tests, 56 assertions; `/tmp/cantilever-domain-mixed.log`).
The production field passes 10,000 independent shape checks
(`/tmp/massif-production-10000.log`). One empirical width baseline for seed
9/standard changed from 15 to 11 cells after NE/SW visual review; the hard shape
limits were retained. Its massif suite passes 20 tests and 7,572 assertions.
Room-band regressions include the actual source bridge/frontage facts and pass
with the three formerly failing constructions. Shallow roofs now align their
explicit high edge and half-cell centre; shifted negative cases pass (96 assertions).
The narrow post/own-roof flashing fixture passes seven assertions.

The graded-street regression originally found an 11.94 m jump at the natural
cliff. Streets now claim their complete width before house pads, and the
perimeter follows the full constructed ground footprint. The rock backing and
authored rock vertices follow the same final height field; collapsed geometry
is omitted. The first rock refresh (`graded-rock-after/`) confirmed that rock
layers taper into the ground instead of leaving flat gray banks. A subsequent
regression found obsolete aprons lying over the graded road; removing those
passes 58 terrain tests and 5,207 assertions (`/tmp/graded-apron-teeth-green.log`).

The owner then requested a shared, constant-width perimeter and short house
connections. The reported town constructs nine houses on four straight frontage
sides in about five seconds in the targeted run. Its tests independently check
building overlap, continuous street height, facade setbacks, the single closed
circuit, all gate incidences, full-width headroom, and the incoming approach.
Five tests and 10,443 assertions pass (`/tmp/perimeter-approach-green.log`).
The road-lattice clearance regression also passes: four frontage-domain tests,
60 assertions (`/tmp/world-road-frontage-clearance.log`). No house is generated,
checked, rejected, or relocated to obtain this result. Measured frontage
intervals are consumed once.

The three original terrain locations were refreshed with phase
`after-graded-rock`. The first cliff's texture is continuous and the second
location has no contrasting apron stripe. The third exact view shows solid
ground where the sky-blue hole was; that run stalled after its first capture
and was stopped, so its later/raised captures still need refresh after the
latest apron change. Changed construction can obstruct historical cameras;
nearby views supplement the retained exact transforms.

Production now skips the unassigned-mass, route-overhead-supply and plot-mass
scans. The red test failed all three omissions; the green suite passes 7 tests,
43 assertions, including identical production/diagnostic geometry. Roof-selection
retries, spine searches and other lower construction choices still require
migration. No claim of complete no-retry construction is made.

Court corner closure now excludes inhabited room volume as well as structural
solids. Seed 2/grand formerly paved inside a room beneath its chimney. The
regression and full production-surface file pass (23 tests, 891 assertions).

Density was compared while holding the current geography constant. Across 54
supercells (31.850496 km²), seed 2697992464 has 46 settlement sites versus 17 with
the old site settings. Across four seeds, the path corpus has 78 nodes versus 30
and 599 road cells versus 87. Node counts cover 25 supercells per seed; road-cell
counts cover nine chunks per seed. These are separate sampling footprints, not
estimates of a common area. The old-settings path corpus fails its minimum
feature threshold, as expected; its measured rows remain the comparison evidence.

The reported ground regression now pins town cell (11,12), independent of current
site selection. Its four tests pass (82 assertions). Runtime-versus-diagnostic
parity and read-only inspection previously passed (four tests, 28 assertions) and
are being rerun after room cleanup removal. New construction-domain and negative
inspection fixtures also cover complete crowns, cross-parcel bearing and roof
ownership. The earlier production record tests passed (three tests, 1,412 assertions); full run 6 covers the later changes.

Remaining work: finish direct construction without retries, fix all relevant test
failures, broaden outskirts/path coverage, rerun the complete suite and profile,
then refresh any screenshots affected by subsequent construction changes. Existing local changes
and the previous task's notes correspond to this review; there is no evidence
explaining why that task disappeared.

The experimental source exposed a shallow-roof contract defect independently of
the one-pass migration: runs were shifted half a cell and a thin shed was judged
as a full solid crown. Current code centres those runs and declares their high
wall edge explicitly. Its regression failed 24/96 assertions before the fix and
passes all 96 afterward, including independently shifted X/Y/Z negative cases.
This correction follows full GUT run 5; broader recipe checks are pending.
