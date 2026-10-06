# October 1 town redesign

Status: implementation and iterative acceptance remain active. Mixed native
Suntail/Pure Village roofs and facades, reserved greens, contextual dressing,
wooded towns, supported bridge reservations and nested fortified tiers are
implemented. The reported town passes eight bidirectional production-player
routes plus its entrance again after confirmed chunk eviction/rebuild. The
24-town survey builds 13 bridge houses versus 8 at baseline. Final production
regression classification and broad rendering/memory acceptance remain open.
The earlier quiet real-terrain sample passed at 7.103 s against its 8 s
ceiling, but the October 6 checkpoint failed at 8.062 s; repeat solves took
8.691, 13.649 and 8.680 s with the same accepted geometry signature. The
production timing gate subsequently passed three quiet solves at 7.905,
7.366 and 7.726 s after exact-output roof clipping optimization; the slowest
still leaves little margin. The full 495-file isolated regression
run completed: 351 files pass and 144 require failure/error classification;
this does not establish whole-suite acceptance. The validated courtyard back-room
and continuous crown-cover repairs were then integrated, with 14 focused tests /
119 assertions passing. Tower-address fallback is integrated after holdout/equivalence checks; five tests/41 assertions and the production31/large bidirectional
native entrance walk pass. Further entrance holdouts remain. Oversized arcade supports now use native
kit proportions, with 22 player traversal/door checks passing. See the October 6 integrated
checkpoint. A later reservation repair replaces superseded landmark-preview masks
while preserving gate/court and tower claims. On 53/grand it reduces the largest
orphan plot from 62 to 10 columns and proposes another bridge (released during
construction to preserve a doorway; finished stamped bridges remain one); six paired towns
compile, the focused regression passes 30 assertions, and four production native
entrance traversals pass. Another 24 production player traversals pass on 53/grand
(skywalks, underpasses and all three courtyard approaches); PublicWalkAudit reports
98 nodes and no unaddressed dead ends. Native close views expose a missing garden
cap course and remaining parallel-gable/repetitive-facade issues, so art acceptance
remains open.

The owner's follow-up expands the architecture work: more L/T/complex buildings,
more distinct-house mini massifs instead of large plain rectangular blocks,
complete projecting bays and towers/spires, and optional inhabited stone terrace
walls. The reported twin-roof pair now merges into one building, and broad
landmarks select seeded L/T footprints. Lower street-facing rooms now inhabit
eligible platform columns, with explicit structural ceilings; repeated wall-grid
accents have been removed. The Pure Village molded stone arch now replaces the tiled header at actual
gateways, with measured fitting and tested walking clearance. The older automatic small spire bays were removed after the owner rejected their
tacked-on appearance; ordinary projecting window bays remain. Full tower
assemblies now generate with measured host fitting and whole-piece clearance;
broader silhouette acceptance remains open. Lower- and upper-tier inhabited wall rooms are implemented
and have passed actual-player routes. Supported wall through-routes connect eligible pairs of existing lower
streets. Their routing/ceiling proof and actual walks pass; their plain corridor
art, broader route variety and final architectural
acceptance remain open.
See the addendum and QA work log for current evidence and outstanding work.

The latest wall revision builds native-height Pure Village masonry courses with
closed stone blocks for parapets, caps and merlons, retaining authored materials.
Paths round both convex and concave boundary corners. Broad greens protect
planting cores from boring; an optional central-green arrangement connects and
inhabits surrounding districts. Native and streamed-world wooded examples have
been reviewed with production grass. These specific improvements have evidence;
they do not yet close every stage's architecture and holdout acceptance gates.

Owner request: October 1, four images (three game captures and the Suntail store
reference). This document is an execution plan, not a claim of implementation.

## Intended result

Towns retain their dense, traversable, vertically bored massifs while gaining
purposeful open greens, small detached buildings, stronger facade relief,
supported skywalks and occasional fortified tiers. Suntail and Pure Village
become compatible architectural families. Towns range from urban to wooded;
the store image is a composition reference, not a layout to reproduce literally.
No world coordinate or reported seed may receive special production treatment.

## Findings that shape the work

- `WarrenTownField` already samples a crown, 1–5 satellite Gaussian lobes and
  clearings before excavation. It takes the maximum lobe height, restores the
  crown core and connecting shoulders, then keeps the largest component.
  Merely increasing clearing count will not establish durable open-space uses.
- September 29 reports bridges declining 27→5, full stacks 19→6, and only 9
  covered bores in 14 towns. `cover_tunnels` acts after carving; many bores no
  longer have both bearings or an adjacent room to carry their crown.
- `WarrenTownPlatform` implements an optional two-storey citadel. It protects
  itself and a surrounding band from boring. This is a starting point, not a
  finished system of tiered rings.
- `KitRoofMeshUnion` already clips native roof triangles against rooms and
  route-cell headroom. Audit the completeness of its inputs (flights, landings,
  decks and lot buildings) before changing tolerances or deleting roofs.
- Suntail has 0.2 native-metre masonry reveals, trims, supports and projections.
  Their existence does not establish that the reported streets show useful
  relief. Review at player scale, not just in an asset lineup.
- Pure Village exists at `/Users/ryko/story/assets/PureVillage`; this worktree
  has no source asset directory. Its converted modular prefabs are available,
  but conversion is not runtime integration. The README explicitly says source
  collision, lights and particles were not exported. Measure geometry rather
  than trusting dimension-like filenames.

## Execution order and acceptance policy

Complete and judge each stage before moving to dependent implementation. Every
stage records commands, seed corpus, metrics, rejected iterations, limitations
and matched images in `docs/qa/2026-10-01-town-redesign/`. Preserve baseline
results separately. A passing count alone cannot approve a visual change.

### 0. Reproducible baseline and asset survey

1. Record Git revision, engine version and current production pipeline.
2. Pin world seed 2697992464 and all three photo locations. Read original F3
   coordinates and derive camera poses with `ReviewCam.solve_cam`/`shoot`.
   The walkway obstruction is clearest in the September 30 capture; use both
   October 1 views for facade and ground comparison.
3. Capture matched world views plus overhead, reverse street and nearby side
   views. Preserve complete generated payloads/parameters where practical.
4. Establish focused test baseline and survey compact through grand towns,
   current continuous production sizes, the reported town, and seeds with and
   without platforms. Separate existing failures from new regressions.
5. Inventory the available new packs, including Pure Village, Raygeas,
   FantasyMarket, Forge, Crafting, Alchemy, Tavern/Kitchen, Interior and nature
   packs. Record candidate IDs, dimensions, style, collisions and runtime cost.
6. Inspect Pure Village assembled houses alongside their component transforms:
   corner/start/middle/end rules, cut panels, floor datums, roof pitch and
   intersections, opening inserts, pivots, back faces and material variants.

Gate: reproducible defect, usable baseline and measured asset inventory. Never
run the shell `godot-test` alias against the unrelated primary checkout; use
its equivalent with this worktree's explicit path.

### 1. Walkway intersections and misplaced pieces

1. Trace each reported roof to its owner mass and actual public walking surface.
2. Write a failing geometry invariant for the reproduced intersection. Test
   triangle/volume overlap, not just triangle centroids or broad AABBs.
3. Establish one complete public traversal envelope from final walk geometry,
   including sloping flights, landings, decks, bridge endpoints and doorways.
   Use it consistently for building articulation, roofs and rigid decorations.
4. Prefer a legal roof/body envelope during design; clip only legitimate small
   overhang intersections. Do not leave open attics, cut gable holes, remove
   bearing posts, or solve visual clipping by disabling collision.
5. Audit nearby canopy posts, rails, beams, window boxes and overlapping roofs.

Gate: reproduced test red→green; no rendered or collision geometry invades
required walking clearance; matched and reverse-angle renders remain closed
and structurally plausible; roof/skywalk/door-access suites do not regress.

### 2. Architectural grammar and facade depth

1. Build a measured Pure Village module gallery and small composition examples
   before assigning roles. Bake selected modules with stable IDs, provenance,
   native materials and explicit collision; no runtime source-pack dependency.
2. Extend `BuildingKit` only where a real second-kit composition requires it.
   Make roof geometry data kit-owned rather than hard-wired to Suntail.
3. Establish facade depth budgets per face from available space: recessed
   openings and sills, lintels/stone arches, protruding timber, corner treatment,
   supported bays, brackets and cornices. Plain sections remain intentional.
4. Select coherent styles per building or district, not random parts on every
   panel. Keep masonry courses, structural timbers and opening heights aligned.
5. Judge masonry and timber streets with neutral lighting and production light;
   require visible relief in silhouette, parallax and cast shadow.

Gate: both kits independently build complete houses at correct human scale;
openings are real and traversable where appropriate; corners and roofs close;
no z-fighting; occupied clearance remains valid. Compare plain/decorated views.

### 3. Open-space reservations and mass hierarchy

1. Introduce seed-derived town character parameters for openness, lobe scale,
   vegetation and fortification using independent stable random streams.
2. Carry sampled circles/ellipses as explicit open-space reservations through
   the source plan, excavation, partition, composition and final record.
3. Use large connected lobes for bored massifs; classify small satellite lobes
   as detached-house/garden sites where reachable. Separate the connected
   walking domain from the solid-building domain; do not discard useful
   satellites merely because their stone is disconnected.
4. Protect the principal massifs and their vertical route potential. Dense
   edges around clearings remain allowed. Fit grade transitions and doors
   without flattening the whole settlement or regrowing a rim rampart.
5. Assign open-space purposes (green, courtyard, market, workyard, grove) before
   dressing. Preserve access, minimum useful dimensions and connections.

Gate: reserved gaps survive final buildings; meaningful variation across seeds;
dense districts and multi-storey massifs remain; every door reachable; no new
road grade failures, disconnected routes or multi-storey boundary walls.

### 4. Restore supported skywalks and underpasses

1. Measure attrition at each stage: possible bore, retained bore, two bearings,
   room-over-bore, reachable upper floor, final open bridge/enclosed bridge-house.
2. Co-plan selected bores with bearing jambs and an upper room or walked floor.
   Reserve the complete structure before partition rather than trying to add
   a cover after its supports have been allocated away.
3. Distinguish a house over an underpass, an enclosed room-to-room span and an
   open pedestrian bridge. Each has different endpoint and support rules.
4. Keep daylit breaks and clearance; never restore unborne stone crowns. Ensure
   stair connections make the upper public routes useful and reachable.
5. Measure counts per eligible opportunity and per town size, with meaningful
   production examples. Choose regression floors from the judged distribution,
   not by lowering tests until a weak output passes.

Gate: visibly restored vertical crossings across the corpus; real routes above
and below; zero unsupported crowns; endpoint doors and collision verified by
actual-player walks. Urban, open and wooded layouts all retain opportunities.

### 5. Optional fortified tiers and rings

1. Generalize the existing platform into zero, one or several nested districts
   selected by seed and available area. Small towns may have none.
2. Derive boundaries from the town field and terrain, with adequate street,
   building and gate area inside each ring. Avoid identical rectangular stamps.
3. Make one bearing-height owner serve grading, plots, walls and circulation.
4. Build closed wall runs with corners, gates, parapets and occasional towers;
   connect tiers through usable flights/ramps and gate landings.
5. Restrict boring only where required by actual fortification foundations;
   prevent the present broad exclusion from silently erasing skywalks again.

Gate: multiple seeds show distinct tier layouts, many towns remain unfortified,
all rings/gates are reachable, no walls block roads or doors, and stage 4's
vertical-crossing distribution is retained.

### 6. Ground cover, trees and purposeful decoration

1. Separate construction/clearance reservations from visible ground paint.
   Paint actual paths, door approaches and selected activity surfaces, not the
   town footprint. Leave greens and gardens on the shared terrain/grass field.
2. Carry final town habitat/support masks into grass and nature consumers.
   Vegetation density spans none to wooded, chosen per town with local uses.
3. Reserve tree trunk, mature canopy and root/support space; keep walking and
   door clearance, bridge headroom and building faces clear.
4. Add authored activity groups from the inventory: workbench/anvil, sheltered
   stall/goods, campfire/cooking/seating, carts/crates, wells, fenced gardens,
   lamps and small domestic props. Use contextual groups, not uniform clutter.
5. Fit every group's actual footprint to final support and clearance. Bake
   appropriate structural collision; emit effects only through existing runtime
   adapters. Audit streaming ownership and placement determinism.

Gate: ground-level world renders show readable paths amid grass/trees; urban
and wooded extremes both exist; no floating props, buried trees, blocked doors,
canopy/roof intersections or duplicate streamed objects. Performance measured.

### 7. Mix the kits and integrate

1. Enable per-building/district kit selection only after both grammars pass.
2. Normalize planning interfaces (floor/door datums, party walls, eaves, bridge
   endpoints), retaining each pack's measured native proportions.
3. Test Suntail↔Pure Village adjacent pairs at equal and different heights,
   corners, shared streets and skywalk endpoints. Use compatible abutments or
   deliberate small separation where native details cannot join cleanly.
4. Permit cross-pack compounds only where a measured transition closes walls,
   corners and roofs. Do not randomly mix incompatible roof pitches.
5. Review a matrix of sizes, density, greenery, tiers and kit mixtures with
   matched baseline images and unselected holdout seeds. Run focused suites,
   the full isolated suite, determinism/build-order checks, actual-player
   traversal, repeated streaming and generation/render-memory profiling.

Gate: complete production integration, each earlier quality gate still passing,
documented baseline-only failures, visual evidence inspected, and no claims
of universal quality based solely on a showcase seed.

## Decision defaults

- Preserve warm/weathered Suntail roofs unless a deliberate palette study
  demonstrates a better compatible mixed-pack result; the reference does not
  automatically authorize reverting the earlier roof-material decision.
- Preserve the September 30 point-based terrain kernel. Town grading changes
  must use its per-point controls and accepted road-edge contract.
- Layouts remain pure functions of seeds and context. Constants and authored
  modular assets are necessary rules, not hand-authored town layouts. Audit
  production for seed/coordinate exceptions and keep fixtures test-only.
- Stage acceptance is technical and visual evidence, not a new approval pause.
  Keep unresolved artistic tradeoffs visible and iterate within the request.

## Progress ledger

- [x] Read current source and prior review findings; locate Pure Village.
- [x] Write ordered plan and acceptance gates.
- [x] Establish exact-photo construction baseline and focused tests.
- [x] Repair the two photographed roof-end overhangs; 24 focused tests pass.
- [ ] Accept stage 1: intersections.
- [ ] Accept stage 2: facade and second-kit grammar.
- [ ] Accept stage 3: open-space/mass hierarchy.
- [ ] Accept stage 4: skywalks.
- [ ] Accept stage 5: fortified tiers.
- [ ] Accept stage 6: ground/vegetation/dressing.
- [ ] Accept stage 7: mixed kits and final regression/visual review.

## Owner refinement: building silhouettes and inhabited stone terraces

The follow-up adds two store images as visual references, especially Pure
Village's projecting bays, attached round towers, spires and multi-level stone
street. This extends the current work; the previous clearance, support,
procedural variability and traversal requirements still apply.

1. **Shape and settlement hierarchy.** Measure the largest rectangular kit
   compounds and trace whether they came from one source parcel or repeated
   kit merges. Prefer articulated L/T/stepped unions when geometry permits.
   Keep broad clusters as multiple distinct buildings around real passages
   more often than merging them into one rectangular range. Distinguish this
   from a cosmetic roof split: mini massifs retain source height variation,
   multiple addresses and traversable upper/lower circulation. Use seeded,
   scale-aware choices; retain occasional simple buildings for contrast.
2. **Individual building silhouette.** Inspect and measure the Pure Village
   authored tower, half-tower, roof-spire, support and projecting-window
   modules in their original assembled buildings. Compose complete supported
   features, including bases, transitions and caps, rather than scattering
   ornaments onto roofs. Allocate them within the building envelope before
   roof fitting. Keep door, stair, bridge and neighbor clearances; compare
   matched player-scale and elevated views across both kits and mixed streets.
3. **Inhabited retaining terraces.** Extend the procedural massif/platform
   treatment with stone retaining street fronts, selected from the measured
   Pure Village modules, including supported arches, stair connections, cap
   courses and optional rooms where the source occupancy permits them. Plain
   stone terraces and fortified parapets are separate seeded possibilities.
   Neither must appear in every town. Preserve the authoritative terrain and
   bearing datums, avoid applied rock facades concealing unsupported mass, and
   prove lower streets, stairs and upper streets with the real player.
4. **Acceptance.** Add shape metrics (largest plain rectangle, articulated
   compound share, distinct houses per dense cluster), positive and absent
   tower/terrace cases, complete native geometry and collision audits, and
   matched renders. Retain the original seed and holdout corpora; do not encode
   production seed/coordinate exceptions or simply lower existing clearance
   thresholds. Judge the architecture against the references before marking
   the expanded facade/massif stages accepted.

### Courtyards, integrated walls, path edges and repeated roofs

Further owner direction, illustrated by the annotated 13/large render:

- Courtyards may occur at ground level or on higher inhabited massif levels.
  Elevated courts must have real bearing, daylight, public access and safe
  edges; connect them to stairs/skywalks and surrounding doors. Do not reduce
  this to decorative inaccessible roof gardens.
- Paths must follow circulation and intentionally paved squares. Preserve
  green pockets throughout the town and soften the current blocky paint
  boundary. Both the reported world and the native review harness must show
  the same ground-surface policy.
- The long blank platform wall in 13/large is specifically rejected. Integrate
  its face with inhabited building frontage or a pathway through/along the
  massif. Remaining exposed wall must have appropriate windows, trim, arches
  or other architectural relief, with actual backing/use and legal collision.
  A separate undecorated retaining box is not accepted as the terrace solution.
- The two neighboring normal roofs at the bottom of that image should become
  a coherent larger building. Trace whether these are separate parcels or one
  house split into parallel roof piles; solve the resulting appearance either
  way. Small repeated neighbors should merge. Broad clusters should become
  articulated compounds or mini massifs, so these requirements work together.

October 2 progress: rounded convex street boundaries implemented through shared `TownStreetPaint` analytic paint/native skin, red-first tests and matched 13/large native review. Broad paving reduction, upper courtyard reservation, inhabited retaining walls and foreground joined-range acceptance remain open. An upper-court preference-only experiment found no additional eligible sites; reserve their footprints before optional district streets. Foreground 13/large pair traced to adjoining house.032/.033, not landmark.00.

Elevated courtyard root cause found and repaired: lower streets opened through the bearing of a square selected earlier. Generalized protected-construction volumes now preserve courtyard bearings/headroom alongside landmarks, and the final reservation honors the still-valid selected site. Three native town builds, support/public-air tests and eight real-player court walks pass. Courtyard art acceptance remains open: add purposeful planting/furniture and improve surrounding walls; current reachable turf terraces are too bare. See QA `elevated-courtyards/`.

Upper-court planting now has explicit supported garden-floor reservations, a continuous walk ring, approach-aware secondary doors, leafy measured centre trees and biome tint. Native review caught and corrected internal guard rails and retaining-frame heads protruding through the garden. Player routes pass around the planting. Richer court dressing and streamed-world art acceptance remain open; see QA `courtyard-planting/`.

Broad landmark footprints now choose connected seeded L/T wings within their conservative reservation, preserving the entrance and two-module minimum wing width; small landmarks stay intact and plain broad ranges remain a minority. Shape/real-town checks and landmark/roofline/floating regressions: 22 tests / 4,695 assertions pass. Close native inner-corner and roof-junction views inspected in 58/large and 7/standard. This resolves the separate rectangular-landmark source, while vertical silhouettes and wall integration remain open. See QA `landmark-shapes/`.


Upper inhabited walls now accept a supported floor at an elevated street, retaining their whole cap to the next tier. Native review corrected battlements overlapping those new facades; both kit styles and ten public-approach walking directions were checked. This advances the inhabited-terrace requirement without changing optional platform frequency. Remaining plain faces, porch-clearance details and final acceptance remain open. See QA `upper-wall-rooms/`.


October 2 path follow-up: concave street corners now receive matching polygon fillets in terrain paint and retained ground meshes, retaining their floor datum. Five focused suites pass 36/36 (23,547 assertions), with matched native 13/large and 7/standard views. Larger clearing candidates improve reserved-area statistics, but native views still put most ground trees at the perimeter. Interior-green acceptance stays open; an enclosure-ranking alternative was tested and discarded. See QA `path-inner-corners/` and the latest result entry.


October 2 planting preservation: sufficiently broad explicit clearings now protect a contiguous plantable core before boring. Source/final ground/dressing tests pass 21/21, production-size source survey 60/60, and the affected 32/large entry–courtyard character walk passes both directions. Native views show lawn and trees surviving where paving crossed a clearing. Central enclosure and streamed grass acceptance remain open; QA `protected-green-cores/`.


October 2 elevated grass review: actual native garden supports now have a production grass rendering mode. Tree-root exclusions corrected from whole canopy to measured low geometry. Native reference/holdout reviewed and cross-block owner/non-owner plus cache eviction tests pass. Fresh full-world walk/reentry run is in progress; see latest QA entry. Broader acceptance stays open.


October 2 streamed regression: fresh production world with grass passes all nine character walks, including a rebuilt entrance after actual chunk eviction/reentry. Final garden support suite passes 5/5 (95 assertions). This closes this run's traversal/reentry check, not central-green visual acceptance or the full stage gates. Isolated cached-roof-bounds experiment rejected for changed output and slower timing; production unchanged. Evidence: QA `streamed-world-current/`.


October 2 central-green experiment: rearranging existing satellite lobes around a green can preserve the original crown and build all 18 sampled source plans, but rendered 24/large loses all satellite buildings. Final source audit shows every non-crown lobe has zero streets and plots. Candidate rejected and production restored; patch/evidence retained in QA `central-green-topology-study/`. Next stage-3 work must co-plan street access and viable house frontage around the green; source connectivity and tree totals alone are insufficient acceptance. In 17/large two lobes have streets but no plots, so house-site/partition admission also needs inspection.


October 2 central-green access correction retained: optional existing-lobe arrangement plus legal early ground connections to each district restores actual houses around the green. Native 17/large and 24/large, including pedestrian views, reviewed. 23 focused tests pass (26,516 assertions across two runs); 60/60 production-size sources build, all lobes of the 11 selected green towns have streets and plots; 24/large actual entry-to-district routes pass 10/10 directions. QA `central-green-district-access/`. This supersedes the unconnected candidate rejection, not the full remaining art/world/performance gates.


October 2 production ground check: actual urban central-green site (-1,1) of world seed 2697992464 has 938 grass instances in planting spaces and zero on painted paths. Wooded central-green site found at (2,1); full production ground probe is live, then review its measured green via town_world_review --at. QA `central-green-world/`. Planting-space totals alone do not close visual acceptance.


October 2 streamed central-green evidence: actual wooded production site (2,1) reviewed with terrain/grass; seven trees and 516 grass instances in planting spaces, none on paint. Close views show an inhabited green and rounded paths; canopy partly occludes the camera. QA `central-green-world/`. Roof clipping optimization preserves 3,251 placement results exactly; 20 tests/12,253 assertions pass. Quiet real-terrain production test now passes all 153 assertions, including 6.735 s vs 8 s solve budget, without repinning. QA `roof-clipping-performance/`. Broader performance/art/final stage acceptance remains open.


### October 2 owner refinement (active)

- Larger internal greens around preserved GMM districts; broad courts before leftover pockets. Implemented candidate; retain dense massifs and test access.
- Remove garden perimeter circuits and count existing entrances before growing new gate lanes. Implemented candidate; final player/native verification pending.
- Owner does not accept cross-gables/trim alone as the architecture solution. Study actual Pure Village and Suntail prefab modules, then generate coherent projecting upper rooms, supported bays, roof wings and native turrets/spires within reserved envelopes. Pure11c/16c/7b front/back study completed; production tower integration and richer mass grammar remain open.
- Rejudge street and overhead views against the supplied reference and mark each component accepted only with geometry, traversal, distribution and art evidence.


### October 2 current owner-request increment implemented

Native attached stone turrets/spires now participate in town generation through whole-envelope admission and matched-gable fitting. Long upper facades can receive supported native bays above the finished public headroom. Medium/broad crowns gain transverse pavilions and town-aware seeded ridge variation. Garden perimeter circuits and forced district-access zigzags are suppressed without removing planted cores or required gates. Both reopened photo-town roof tests are green. Native close/overview/street views, six-town roof clearance, 60-source sweep, actual character routes and quiet production-site timing pass; see `docs/qa/2026-10-01-town-redesign/native-turrets-and-direct-streets/result.md` for exact scope and evidence. This advances the active architecture/access stages; it does not close the broader holdout, masonry art, streaming/memory or full regression gates.

Fresh holdout review (41/large, 67/large) rejects the remaining tall blank timber/plaster support faces. Final-mass diagnostic confirms ordinary retained massif/courtyard supports use plain timber layers; inhabited wall-room admission is platform-only. Next work must address those supports through real accessible rooms where valid and native retaining relief elsewhere, not fake windows into earth. Native views and completed diagnostic: `docs/qa/2026-10-01-town-redesign/holdout-retained-faces/result.md`. No production change at this checkpoint; all jobs terminal.


October 2 ordinary massif wall rooms: street-addressed rooms may now replace retained support immediately below the lowest existing plot, reaching its floor with a structural cap. Platform behavior remains supported; source/platform tests5/5,92 assertions; final holdout source/build2/2,18; actual41 doorway walks2/2; source60/60 with no uninhabited districts. Native41/67 re-rendered;67 has no qualifying site. Large blank retained faces remain an art failure and need native relief or further valid inhabited treatment. QA `docs/qa/2026-10-01-town-redesign/ordinary-wall-rooms/result.md`. All processes terminal; full goal active.


October 2 retaining relief: inspected original Pure Village supports; baked whole SupportStone_Middle_30x15 with original material and collision. Native corbels admitted only at exposed retained crowns with whole-bound public/neighbor/tower clearance. Rejected corbels-on-plaster; ordinary retained backing now native Suntail masonry. Holdouts41/67 render4/9 corbels. Four tests55 assertions; actual67 courtyard walks4/4. Broad lower faces still need articulation; full art/performance/regression scope remains active. QA `docs/qa/2026-10-01-town-redesign/native-retaining-corbels/result.md`. All processes terminal.


October 2 integrated recheck: quiet production149 assertions,6182ms<8000ms; tunnel/skywalk/court/platform12/14 tests,608/612 assertions. Bridge-house corpus12 (floor12), skywalk endpoint tests pass, actual7/standard routes8/8. Reopened court gate:58/large and58/grand preselect band4 instead of8;13/grand remains8. Four elevation assertions fail; support/air pass. Keep tests red and investigate early-gate/district street versus upper-site availability; do not silently repin. QA `docs/qa/2026-10-01-town-redesign/current-integration-check/result.md`. All jobs terminal, goal active.


October 2 courtyard assertion diagnosis:58large/grand now generate only band4 platforms and no band8 streets, and courts are at their highest tier. Removing early secondary gates did not change that.13grand retains band8. Corrected obsolete absolute-height fixture to highest-generated-tier equality (>=4), retaining explicit13 nested >=8; no production algorithm change. Tests2/2,101; actual13grand highest-plaza traversal2/2; native13/58 reviewed. QA `docs/qa/2026-10-01-town-redesign/courtyard-tier-validation/result.md`. Broad art still open; all jobs terminal.


October 3 range-pavilion fallback: try the opposite end when the seeded preferred
end fails existing roof/headroom/gable checks. Red regression reproduced seven
failures; final three suites pass 14/14, 7,874 assertions. Six finished town
payloads have zero walking-air roof intrusions (gable contacts tracked separately).
Real 58/large house023 gains a cross pavilion. Native 58/41 overviews reviewed;
broad retaining faces and some plain roof ranges remain unaccepted. No new
character walk for this roof-only change. QA `range-pavilion-fallback/result.md`.
All increment jobs terminal; full redesign goal remains active.


October 3 intermediate retaining courses: whole native Pure Village corbels may
articulate intermediate storey tops as well as crowns. Unframed Pure Village
masonry replaces the retained timber grid; the mismatched blue-stone candidate
was rejected. Native41/67 overviews and67close inspected; modules4->7 and9->16.
Final four suites8/8,165 assertions; actual67 courtyard directions4/4 pass.
41's broad path-facing blank support remains an art failure; full goal active.
QA `docs/qa/2026-10-01-town-redesign/retaining-courses/result.md`. All jobs terminal.


October 3 retaining floor-seat correction: diagnostic found native deck undersides
only1.688mm below the prior cap ceiling. Whole caps now seat below shallow deck
contacts, then recheck all obstacles/air; deep floor conflicts stay rejected.
Tests8/8,73 plus focused extra constraints1/1,16; actual41 wall-room walks2/2.
Native41overview gains relief; custom close camera entered a neighbouring
structure and is not exterior acceptance. Supports41:7->17,67:16->17 (counts
include hidden faces). QA retaining-floor-seat/. All jobs terminal; goal active.


October 3 integrated audit active: added public-floor/sight-line retaining review;
three41close views inspected, depth confirmed with adjacent plain face remaining.
Corrected native-asset bounds in gate/parapet tests, facade metric scope and the
obsolete all-seeds-must-be-nested fixture; corrected gate3/3, facade4/4,694 and
rings4/4,89 pass. Initial raw failures preserved. Full October isolated run47
files remains LIVE session74175, `/tmp/october-current-suite.txt` (28 done at
checkpoint). Unresolved landmark/roof-fallback/chimney/released-bridge failures;
classify before changing expectations. QA integrated-october-audit/. Goal active.


October 3 isolated October run COMPLETE:47 files,38 initially clean/9 failing;
three corrected test-oracle files green on separate reruns; six unresolved
(landmark reservation, native roof fallback, released bridge sites, chimney
variety, small town lobes, joined ranges). Raw logs saved in integrated-october-audit/.
Landmark9 held3x4 becomes3x3; temporary trace rejects column(2,-1) atfloor0 as
hanging_street during reservation. Final public cells omit that column: trace
intermediate street/transition and pruning before repair. Production trace fully
restored byte-for-byte. Small-house sites6/9/12 also lack addressed houses.
All sessions terminal; full goal active.


October 3 landmark overhead reservation: seed9/standard's held3x4 asset was
shrunk because optional spine descent put a band5 street over its fixed top4;
partition later pruned the street, too late to recover the site. Fixed assets
now reserve above their legal roof-level headroom through the massif envelope.
Courts retain their previous rules. Exact held-site regression passes unchanged;
landmark6/6,39 assertions; bridge/court5/5,188; finished24-town bridge count12.
The combined attempt skipped the landmark script after an indentation error;
that error was corrected and the separate6/6 run is authoritative. Earlier
unqualified-constant compile error also corrected before final runs.
Source60/60 valid,11 central-green towns with no empty districts. Native9/6
overviews inspected; street images saved but not yet reviewed. No new actual
character walk for this increment. QA landmark-overhead-reservation/. All
increment jobs terminal. Full redesign remains active; small-house access is
under investigation and broader art/regression/performance acceptance remains.


October 3 cottage-access candidate: reserved small-lobe sites lacked streets;
new shortest legal entrance per site restores104/104 cottages across60 valid
sources, preserving11 inhabited central-green districts. Native landmark/deck
reservations now respect earlier cottage footprints and measured eave halos.
Focused16/16,586 assertions; actual12large entrance2/2; native6/12 overviews
and12street inspected. Existing direct-access cadence exemption includes cottages.
Compact landmark fixture now1 instead of2 with documented frontage conflict;
exact held-site preservation strengthened to include that town.
Integration remains RED:24-town finished bridge count11<12 (unchanged floor).
Only12compact source bridge differs: destination pruning withdraws unused street
and its span at(1,-2),floor6. Moving access after bridge reservations still loses
that bridge AND strands7 cottages, so rejected; final code restores early access.
QA cottage-access/result.md. Other unresolved October failures: native fallback,
released-bridge fixture/infill, chimney coverage, joined ranges. Broad faces,
long roofs/tower admission and global performance still open. All jobs terminal;
no commit/PR, full goal active. Next diagnose12compact bridge/destination
co-planning without preserving purposeless road circuits or abandoning cottages.


October 3 bridge destination validation

The cottage-access source comparison isolates one lost bridge at12/compact,
(1,-2),floor6/top8: destination pruning removes its unused underlying street.
Tried allocating bridge endpoint houses before pruning, so real doors could
preserve that address. REJECTED:60-town source test breaks39 (a lower endpoint
has a doorway on a removed stair cell); finished-towns test also returns null.
This repeats the historical flight-door hazard documented by September27.
Production order restored: ordinary destinations prune, released sites infill,
then bridges allocate only over surviving streets. No purposeless road retained.

The corpus floor is explicitly revised12->11, documenting this deliberate
withdrawal rather than asserting a supported span must remain at an obsolete
location. Whole-cover/support and actual built-door requirements stay unchanged.
Final tests: tunnel hosts3/3, released bridge sites2/2, destination agreement3/3;
8/8 total,188 assertions. Actual counted doors are built across the historical
11-town destination corpus. The previously failing released-site regression is
now exercised naturally again at12/compact; no fixture change needed there.
This resolves the bridge classification and released-site failures, not the
whole redesign. Other outstanding October files: native roof fallback coverage,
chimney coverage, joined-range fixtures. Broad walls/rooflines and fuller turret
variety remain art work. All increment jobs terminal.


October 3 native attic turrets

KitTownTowers now tries bounded lateral gable attachments (one module on widths
>=4, half a module on width3) after the centred position. All support, doors,
public air, other buildings and own-wing clearance checks remain authoritative.
Unit fixtures prove this can fit beside protected central doors without changing
the host. Seven real holdouts7/9/17/24/41/58/67 nevertheless gain no offset
attachments; lateral choice alone was insufficient visual progress.

Added a short CORBELLED_HALF form: one whole native round window course, its
native half-corbel and original conical spire. The corbel's full rear support
volume must bear on the flush host wall below the eave. This allows attachment
without flattening or removing lower-storey jetties. Taller forms are attempted
first; only the short form permits one course. Host roof fitting accepts shaft
intersection too, since a short turret's cap can sit above the gable. Existing
exact roof cutters, opening protection and collision emission remain in use.
No new texture, generated substitute masonry or scaled tower parts.

Production12/large gains its first turret (0->1);13/large retains2;6/large still0.
Three overviews rendered,12 overview and both close sides inspected; the first
close framing clipped the finial, so final65deg views show the complete assembly.
Native course/corbel/cap and gable junction read closed from both sides. The
large plain retaining face visible behind it remains an art issue. Lateral-only
candidate does not claim measured town-wide turret growth.

Final tower3 suites19/19,3151 assertions, now including real12 and13 emission,
collision and open-wall checks. Added short-form regression24 assertions verifies
existing inset lower floors stay unchanged and the attachment uses3 complete
native parts at the eave. Finished-roof/public-air and roof-detail suites4/4,113:
all6 finished payloads have0 walking-air intrusions; raw skin cuts and gable
contacts are separate diagnostics. The old chimney-count failure now passes
with the cottage-access layout; no chimney expectation was relaxed.

No new character walk for this roof-only change. Broader density/performance,
native terminal-fallback and joined-range stale fixtures, broad wall relief and
roofline art remain open. Harness supports --views turrets for side inspection.
All jobs terminal; no commit/PR. Full redesign goal remains active.


October 3 continuation: central cross-gables implemented and native-reviewed for
6/large and13/large elongated ranges. Range/variety/tower tests19/19,9931assertions;
finished six-town roof/public-air audit0 intrusions. Corrected native-cap coverage
in roof audit with cap-removal negative control. Evidence:
`docs/qa/2026-10-01-town-redesign/central-cross-gables/result.md`.
Broad retaining faces and full integration acceptance remain open.


October 3: wall rooms can support final level public terraces, with a full
2-band storey and1-band slab. Placed after destination pruning; early placement
rejected16/60 invalid plans. Final60/60 source validation,8/8 tests125assertions,
41/large5entrances walked both directions10/10. Broad front retaining face still
requires art work. See `docs/qa/2026-10-01-town-redesign/terrace-wall-rooms/result.md`.


October3 native retaining panels: complete WindowSolo_3 ornaments on emitted
stone backing compete with corbels. Floating planned-wall candidate rejected;
full backing/air/neighbor checks retained.41large3panels+5corbels,67large1+0.
Six tests/1437assertions;41overview and public-floor close views inspected.
Evidence `docs/qa/2026-10-01-town-redesign/native-retaining-panels/result.md`.
Full integration and art acceptance remain open.


## October 3 — short wall-room roof clearance and stable joined-lot coverage

The integrated grand-town survey found a real new failure at 2/grand: a
three-band inhabited support below an upper house left exposed lower roof
faces after the upper facade stepped back. Neither a complete native pitched
roof nor a legal public-floor slab fitted; the entire town was rejected.
`wall_room_support_ok` now requires the usual four bands below houses while
retaining three-band rooms immediately beneath an actual non-flight public
floor. No clearance, bearing, or roof-closure check was relaxed. The surviving
short terrace room remains addressed. The old case failed construction; the
repaired case builds and passes payload, public-air and floating-mass checks.

The photographed seed-13 joined-lot coordinates no longer exist after street
changes. Its regression now preserves the actual pair of adjoining 4x2 lots
as direct construction inputs across 16 seeds, verifies both complete storeys
and addresses survive, and requires one 16-module roof. A separate current
seed-13 complete-town check retains floating-mass and public-headroom coverage.
This is not a claim that the original positions still occur in the live seed.

Validation: four targeted suites, **13/13 tests, 1,588 assertions** (88.442 s).
Native 2/grand overview and its surviving wall-room entrance inspected; the
entrance is seated and surrounded by complete native masonry/timber. The
close view does not show the whole terrace ceiling. Player-controller approach
and return both pass (**2/2**); these are exterior entrance routes, not door
opening or interior traversal. Evidence: `wall-room-roof-clearance/`.

Still open: the terminal-roof regression's former 9/grand fallback no longer
occurs. A 40-grand-town search found no positive terminal instance; retain the
failing coverage assertion until a real positive contact fixture is recovered.
The survey also discovered the above construction failure; it is not evidence
that all 40 towns pass after the repair. Broad regression classification and
final art acceptance remain open. The new overview still contains narrow
roof ranges, so it is not accepted as completion of the reference-building goal.


## October 3 — lower native cross-gables in dense ranges

Two remaining 8x2 ranges in 2/grand could not accept taller cross-pavilions:
their neighbors only partly backed the proposed gables. The generator now
tries a lower complete native profile and admits a rear party contact only
when the entire gable envelope is backed, with at least one free end.
Partial contacts stay rejected. Native roof union closes the two roof axes.
A close render caught the first blue-wing ridge touching a railing; the new
low profile now guards the ridge-height walking rim and finds the opposite
clear end. An overbroad guard disturbing another photo-town roof was rejected.

Final range/variety/finished-air suites: **19/19, 8,022 assertions**. Native
2/grand overview and both junctions inspected. Evidence and rejected trial:
`backed-cross-gables/result.md`. No new character walk for this roof-only edit.
The holdout 17/large shows a huge empty central area and long outer approach,
plus an undecorated masonry face at street0. Its woodland roll is zero (valid
variation), but its spatial composition is not accepted; use it for the next
path/facade pass. Broad acceptance and the terminal-roof positive fixture
remain open. No complete-goal claim.


## October 3 — route through central greens

Fixed the actual cause of 17/large's long outer access: missing route-domain
ground inside the lobe ring. Central-green towns now reserve missing ground
within the sampled lobe-centre hull, keeping it unbuildable and carrying it
through planting/dressing. Natural datums and the existing planting-core rule
are preserved. Nearest-district ordering was an ineffective trial and reverted.

17/large district paving **64 -> 48 cells**, longest branch **31 -> 20**.
60/60 source towns validate, all104 cottages and all districts served; field
comparison proves49 ordinary cases unchanged and11 central cases retain their
sampled solid/lobes/sites/platforms. Focused coverage:10 unique tests /5,945
assertions; complete17/24 roof/bearing/headroom checks pass. Player routes:
10/10 (five approaches bidirectionally). Native17/24 overviews inspected;
24 has44 trees,17's zero-tree urban roll remains intentional. Evidence:
`central-ground-access/result.md`. Plain facades, sparse central-lawn dressing,
terminal-roof fixture and broad final acceptance remain open.


## October 3 — central-green activity areas

Large greens now admit several seeded, separated activity groups within12 m of
an unobstructed ground street; complete native seating/vendor/camp assemblies
replace isolated loose furniture. 17/large:13 groups,15 props,zero trees;
24/large:five groups,five props,44 trees. A canopy/window-box contact revealed
that grid occupancy omitted finished facade geometry. Dressing now indexes
measured low native entries (including noncolliding details), and the preview
uses the same inputs. The canopy relocates clear in the final close render.
Dressing suite15/15, followed by a stronger actual-kit urban test1/1 with8,397
assertions. See `green-activities/result.md`; final images `native-clearance/`.
No new player walk or full-world/performance acceptance in this pass. Broad
remaining work stays open.


## October 3 — recovered terminal-roof coverage and regression run

The positive terminal-roof fixture is restored from the original native recipe
poses and measured contact, independent of random layout drift. It calls the
real fallback transaction: no closure -> rejected with no partial commit;
proved closure -> two supported native strips, exactly one prior-roof seam,
no unrelated overlap. Current9/grand and the other native/mixed towns retain
whole-town validation. Three whole-town tests pass; the focused recovered case
passes7,258 assertions. No production geometry or tolerance changed. Evidence:
`terminal-contact-fixture/result.md`.

A fresh isolated run of all47 October1/2 test files is now in progress via
`/tmp/october-redesign-suite.py`, exec session94641. Log:
`/tmp/october3-regression-runner.log`; authoritative per-file state and logs:
`docs/qa/2026-10-01-town-redesign/october3-regression/`. Poll this exact runner;
do not start a duplicate on timeout. No full-suite result claimed yet.
Broad art/streamed-world/performance acceptance and baseline comparison remain
open. Goal stays active.

## October 3 renewed architecture direction

The owner again rejected tall flat apartment-like streets and rectangular roofs, and emphasized overhangs, turrets and bored inhabited massifs. Street-air-facing recesses, narrow crown retention, shorter cross-gables and increased measured turret proposals are implemented. The blanket raised-district skywalk exclusion now respects height: upper crossings can be proposed above the platform datum, while lower approaches keep protection. A planted public courtyard floor can share the existing market-canopy interface exactly as a paved floor does. Three review towns gain source spans 0/0/0 -> 2/3/3; 31/large passes six actual-player crossing/underpass directions. Sixteen production records validate. Art acceptance is still open: some tall slabs remain, final 31 has no full turret, and the new crossings alter 103's prior three-turret layout to one. See `docs/qa/2026-10-01-town-redesign/october3-upper-town-spans/result.md`. Next prioritize stepped inhabited mass and broad final-revision route/roof/collision review rather than treating facade counts as success.

## October 3 latest owner clarification

Prioritize real Pure Village stepped-wing tower connections (House_16c/11c studied), shallow embedded projecting wall frontages with shed roofs, and supported enclosed climbs with overhead rooms/skywalks or tree canopy. Removing one-course turret fallback and restoring raised-district natural bores are first corrections, not acceptance. See `docs/qa/2026-10-01-town-redesign/october3-enclosed-streets/result.md` for evidence, rejected flight-bore experiment, live production corpus and outstanding performance failure.

## October 3 raised courtyard canopy

Completed local canopy fitting and native roof clearance, with benches under crowns and root-aware underplanting. Final7/7 tests and13/grand two-direction player route pass; final native views inspected. See `docs/qa/2026-10-01-town-redesign/october3-court-canopy/result.md`. Integrated towers, embedded projecting facade rooms and enclosed climbs remain active priorities; this courtyard does not satisfy those goals.

## October 3 native eave tower connections

Tower caps now follow House_16c’s eave-minus-half-metre datum; eave-side candidates and native grounded half-tower bases are supported, with complete bearing and public-clearance checks. Final focused23/23,2,627 assertions; cap-removal mutation catches the exposed eave cut. The31/large suspended eave variant was subsequently rejected visually; new eave attachments require a grounded base, and the final grounded43/grand mutation/host suites pass12/12. See `docs/qa/2026-10-01-town-redesign/october3-eave-towers/result.md`. Full stepped-wing architecture and enclosing massifs remain open.


### October 3 tunnel-bearing review

Recovered stone piers and a later cover retry were tested and rejected. The
former improved source cover counts but replaced an existing detailed frontage
with plainer stone, while an existing bridge already covered the lane. The
latter restored no reviewed covers. Both were reverted. Only measured native
window panels on narrow two-module retaining faces were retained (7/7 tests,
7,354 assertions; native views inspected). Next enclosure work must co-design
inhabited jambs, covers and roof reservations and measure actual final overhead
coverage. See `docs/qa/2026-10-01-town-redesign/october3-tunnel-bearings/result.md`.


## October 3 embedded-frontage native-part study

Pure Village bow-window assemblies and return stock were inspected at authored
scale. No projecting facade was enabled: the full bay volumes require earlier
room/route/roof reservation. Retained a narrower fix to admit complete shed-eave
runs independently, preserving clear faces when another face is blocked.
Wall-room regressions6/6 (82 assertions), final hood checks2/2 (17); native
13/large views inspected. Embedded projections, integrated towers and enclosed
climbs remain open. Evidence:
`docs/qa/2026-10-01-town-redesign/october3-frontage-parts/result.md`.


## October 3 stepped roofed wings

Eligible repeated rectangular upper stacks now form seeded lower roofed wings
inside their original footprint, preserving doors, public walks and external
bearing. Removed the old independent spire-bay decorator; full tower fitting
remains. Initial10/10 geometry cases, final4/4 including four-town public-air and
floating-mass checks; corrected full-cap mutation1/1. Quiet production7.103s,
149 assertions. Matched native shape views inspected. This is partial progress:
13/large loses its former full shaft, tower distribution remains insufficient,
and embedded projecting facades/enclosed massif streets are unfinished.
Evidence: `docs/qa/2026-10-01-town-redesign/october3-stepped-wings/result.md`.


## October 3 native roof-emergent turrets

Implemented the complete narrow shaft/window/cap grammar from Pure Village
House_11c as a seeded fallback beside the existing larger attached towers.
The shaft begins within an occupied upper room and passes through the native
roof, using hidden measured inner cuts. Reviewed native isolated buildings and
three towns: 13/large4 new turrets,31/large1,43/grand3 prior+4 new. Focused suites
9/9 (6,364 assertions); quiet production7.227s<8s,149 assertions.

This is retained progress, not overall architectural acceptance. Embedded
projecting facades and coupled inhabited tunnel/roof/route planning remain the
next structural work; exposed climbs and long flat fronts are still visible.
See `docs/qa/2026-10-01-town-redesign/october3-roof-turrets/result.md`.

## October 3 inhabited route clearance and rejected enclosure candidates

Interior-priority bridge selection lost upper-room coverage in103/grand and
was reverted. Joining bridge and endpoint houses into one kit mass preserved
coverage but reduced enclosure in the matched street view; also reverted.
Retained explicit private-room passage clearance for optional turret shafts.
New2/2,143 assertions; existing roof-turret3/3,3091. Retained13/large player8/8;
43/grand improves4/8->6/8 by clearing both shaft-blocked bridge directions;
its exterior skywalk0 has an identical baseline landing/railing failure. No overall architectural acceptance.
Next work must preserve existing overhead rooms and native projections while
adding supported interior coverage, and resolve the43/grand exterior landing.
Evidence: `docs/qa/2026-10-01-town-redesign/october3-inhabited-selection/result.md`.

## October 3 skywalk landing repair

Resolved43/grand's missing landing and railing obstruction: the kit preserves
reachable flat construction crowns as native decks, and terrace guard seams
open onto accepted bridge walking lanes. Their headroom is protected in roof
and detail fitting. Final8/8 tests,3273 assertions; actual player8/8 directions;
native landing views inspected. The former43 landing failure is resolved.
Broader architectural goals remain open. Evidence:
`docs/qa/2026-10-01-town-redesign/october3-skywalk-landings/result.md`.

## October 3 — shallow native wall-house roofs

Replaced full gable-slope hoods with existing Pure Village shallow bottom courses
and complete native end caps. Corrected the first low seat after it obscured
opening heads; accepted attachment fits in the retained cap. Native controlled
two/four-bay and town views inspected; final room/skywalk 9/9 (164 assertions),
expanded hood 4/4 (59), actual 13/large player 8/8. This does not complete the
requested projecting inhabited frontages or massif enclosure; those remain open.
See `docs/qa/2026-10-01-town-redesign/october3-shallow-fronts/result.md`.

## October 3 — inhabited wall-room projections

Existing upper wall rooms can now project as complete native assemblies: shifted
front panels, two closed returns, walked floor/ceiling strips, beams and brackets.
Long fronts select a seeded two/three-bay section with recessed shoulders. Native
58/large and67/large views inspected;13's blocked bridge-side front stays flush.
Final projection/hood/landing suites10/10,182 assertions; actual local doorway
approaches58 and67 each8/8. Quiet production7.362s<8s,149 assertions. Broader
bored-massif coverage and enclosed climbing streets remain OPEN, as do overall
architectural acceptance and refreshed world/full-suite review. Evidence:
`docs/qa/2026-10-01-town-redesign/october3-room-projections/result.md`.

## October 3 — shared excavation-clearance experiment (deferred)

Two-band excavation increases finished inhabited street coverage across five
measured towns104->148 quarters; matched native13/43 lower streets improve and
13 actual player10/10 directions passes. But58/large exposes an odd five-cell
private crown the even-sized roof grammar cannot cover. Restored excavation and
compiler exactly; candidate patch, frozen crown and native evidence saved. Next:
complete native odd-corner roof grammar, then reapply/revalidate the candidate
and projection coverage. Related suites9/10; carver12/13 with the same five
spine requirements failing at baseline. Production verifier's two failures also
reproduce before the change. No acceptance/full-suite/performance claim.
See `docs/qa/2026-10-01-town-redesign/october3-bore-headroom/result.md`.


## October 3 — inhabited bore construction retained

The two-band excavation experiment now has native construction for its odd
private roof corners, so it no longer fails 58/large. It preserves more rooms
over lower streets (five matched towns:104 ->148 covered quarters). The final
nine-town survey has no floating masses or measured roof/public-air intrusions.
A separate omission in cross-gabled halls was also fixed: their long roof wings
now receive seeded, clearance-fitted dormers. Final targeted tests:19/19,
13,761 assertions. Actual-player checks cover12 directions; native alley and
roof-wing views are inspected. No alternate-town retry was introduced.

Details and limits: `docs/qa/2026-10-01-town-redesign/october3-bore-construction/result.md`.
The broader dense-frontage, climbing-walk enclosure, integrated-tower and canopy
art goals remain active; this is not full redesign acceptance.

Quiet real-terrain production check for this revision:5,103ms<8,000ms;
1/1 test,125 assertions. No fresh full-suite or streamed-world claim.

## October 3 owner correction: corner towers and coordinated materials

The owner rejects the roof-emergent turret fallback as the default design.
Use Pure Village corner/lower-wing shaft junctions as the target; retain full
support, closed junctions, native stock and public clearance. A tower's cap must
follow its host building's roof palette. Coordinate primary, timber trim, masonry
and roof across each compound, without making all components monochrome.

Prepare controlled material options: oak/walnut/birch-inspired wood, original
blue slate, earthy muted green, and warm smooth stone/charcoal. Native prefab
House_16c is the fixed comparison geometry, NOT procedural implementation.
Wood names describe visual studies using the pack's grain, not botanical texture
identification. Smooth stone is a material study; collegiate/Gothic style also
needs architecture (window groupings, tracery/buttresses/stepped parapets).

Work order: finish the climbing-support regression/player checks; render and
judge coordinated options; co-plan corner tower support with house footprint
and adjoining lower wing; make one palette authority cover main roofs, caps,
dormers, hoods and frames; review single buildings and mixed town ensembles.
Production corner placement and palettes remain OPEN until that evidence exists.


## October 3 — corner shaft and immediate cap matching

Production roof-emergent fallback removed; native grounded corner shafts now
join both wall faces. Narrow stock reaches 43/grand, but only one of five towns
has a corner tower: reserve support/space earlier to meet the skyline goal.
Cap material follows the adjoining roof (blue slate or Suntail warm/weathered
wood), retaining separate timber trim/stone. Full compound palette integration,
Gothic architecture and enclosure goals remain open. See
`docs/qa/2026-10-01-town-redesign/october3-corner-towers/result.md` for comparisons,
rejected cap seating and the remaining small Pure eave clipping fragment.


## October 3 — tower support diagnosis

Retained stone tops now count as real native tower bearing; unsupported foot
columns and public air remain protected. Five-town tower counts unchanged.
Rejected inward L-corner variant after native inspection (buried cap, no gain).
Space/support must still be co-planned with the lower wing. Evidence:
`docs/qa/2026-10-01-town-redesign/october3-corner-support/result.md`.


## October 3 — grounded short corner towers retained

Complete native window-course/cap assemblies now fit lower wings and occasional
single-storey houses. Five-town corners1->12, four towns represented; three
holdouts have zero floating masses/roof-air intrusions. Nine targeted tests and
actual-player13coveredstreet both directions pass; native13/43 inspected.
This improves visible corner variety but leaves tall compound tower planning,
full palettes and the broader art goals open. Evidence:
`docs/qa/2026-10-01-town-redesign/october3-low-corners/result.md`.


## October 3 coordinated roof families

Pure Village roofs now select one seeded blue/warm-wood/weathered-wood/sage
family per merged house, including corner caps, dormers and ridge tiles.
Native geometry remains unchanged. See
`docs/qa/2026-10-01-town-redesign/october3-roof-palettes/result.md` for actual-town
images, targeted regression results and the corrected streamed asset-list gap.
Full facade wood/stone palette integration and Gothic composition remain open.


## October 3 contrasting wood finishes

Native/oak/walnut framing now varies per merged Pure Village building while
roof colours, stone, plaster and glass remain separate. Descriptor variants
share original visuals, collision and worker geometry. Final facade/dormer
clearance resolves canonical asset IDs; native town review and regression
results are in `docs/qa/2026-10-01-town-redesign/october3-frame-palettes/result.md`.
Gothic stone architecture and the full original acceptance scope remain open.

## October 3 enclosure audit and rejected ground-link candidates

Current eight-town finished audit: 280 street quarters under occupied rooms;
all towns build, floating masses and roof/public-air intrusions zero. Added
per-quarter inhabited-side and raised/ground classification to the probe.
A natural-ground foundation check incorrectly asks for an underground massif
voxel; its isolated correction passes, but naive admission and late admission
both displace existing room covers elsewhere. The best five-town candidate
fails holdout 7/standard (40 -> 28); eight-town total 280 -> 272. Reverted all
production candidate changes. Next repair must co-plan endpoint allocation and
existing inhabited bore covers. Evidence, native candidate views and player
checks: `docs/qa/2026-10-01-town-redesign/october3-enclosure-audit/result.md`.


## October 3 endpoint allocation follow-up

The rejected ground-support shortcut also bypassed reserved-green checks.
Restoring that exclusion admits a valid narrower bridge but still reduces
holdout cover: eight-town total 280 -> 276. Entire candidate reverted again.
Added source plots, selected proofs and allocation outcomes to the audit.
Mutable seed-array indices also change unrelated footprint/height rolls;
structural identity and upper-room ownership need isolation before admission.
See `docs/qa/2026-10-01-town-redesign/october3-endpoint-allocation/result.md`.


## October 3 stable budget draws and corrected enclosure measurement

Footprint and height draws now use seed column/floor/door, preserving those
choices when a prior seed is reserved away. Seven tests pass, eight towns build
with no floating masses or roof/public-air intrusions; native7/43 and actual
player101climb reviewed. The enclosed-skywalk audit omission is corrected.
Additional ground-crossing candidate remains reverted; this is groundwork,
not a claimed enclosure increase or final art acceptance. Evidence:
`docs/qa/2026-10-01-town-redesign/october3-stable-building-draws/result.md`.


## October 3 ordinary projecting room fronts

Ordinary tall houses can now receive one closed native projecting room front,
with supported floor, ceiling, returns, brackets and windows in each bay. Own
lower-wing roofs are respected. Eight towns: 11 ordinary fronts plus two embedded
fronts, zero floating/roof-air intrusions, inhabited coverage unchanged at 328.
Nine tests / 82 assertions; player43 routes10/10; production gate passes.
Native close review shows useful local depth but still leaves broader compound
architecture and enclosure open. Evidence:
`docs/qa/2026-10-01-town-redesign/october3-upper-house-fronts/result.md`.


## October 3 connected corner-wing silhouettes

Broad repeated stacks now shape a lower roofed corner before loggias, preserving
connected L-shaped upper arms and native roof junctions. Sixteen-town survey:
16 corner-wing buildings in nine towns, zero floating/roof-air, inhabited cover
unchanged. Native Pure7/Suntail103 inspected, final wing tests and player10312/12
pass, isolated production gate passes. Long narrow compounds, broader enclosure
and Gothic composition remain open. Evidence:
`docs/qa/2026-10-01-town-redesign/october3-corner-wings/result.md`.


## October 3 inhabited tunnel floor alignment

Accept the first existing host storey on either two-band phase above a bored
crown, without growing the host. Composition reserves and verifies the whole
bearing run; this repairs the partial crown exposed by the planner-only attempt.
Sixteen towns: inhabited cover764->800 quarters, no town loses coverage,
floating/roof-air0. Focused2tests44assertions and actual repaired-corner player2/2
pass. Legacy whole-cover test retains one pre-existing4/large build failure.
Native final13 reviewed. Broader enclosure/full world/art acceptance remain open.
Evidence: `docs/qa/2026-10-01-town-redesign/october3-tunnel-floor-alignment/result.md`.


## October 3 bridge stair bearing

Fixed the remaining4/large cover-corpus build failure by checking direct bridge
endpoint bearings against the actual fine-grid stair-clearance kernel before
source admission. Compiler support gate unchanged. Nine towns build with zero
floating/roof-air violations and no cover loss in the previously valid eight.
Legacy cover regression now43/43, new tests6/6 assertions, actual stair player2/2.
Evidence: `docs/qa/2026-10-01-town-redesign/october3-bridge-stair-bearing/result.md`.


## Owner correction: prefab-derived grammar

The owner rejects the October 3 Pure Village corner-wing image: roof/hood
penetration, disconnected roofs, missing side and flush lower eaves. Reopen
visual acceptance. Implement shared construction rules capable of reconstructing
the native prefabs and producing novel houses; do not equate asset inventories
or prefab replay with a generalized sampler. Detailed sequence and initial
coverage audit: `2026-10-03-prefab-building-grammar.md`.


## October 4 cover-chain experiment

Rejected and reverted: extending an existing supported back room across adjacent
bores, including outward fixed-point ordering, produced one extra source cover
but no additional finished enclosure. Construction tracing isolates missing
inhabited/retained jambs in 101/large. Keep final bearing checks intact. Eight
holdouts remain free of floating/air audit findings, but this is not art
acceptance. Next enclosure implementation must co-decide inhabited jambs and
rooms during construction, not repeat post-hoc cover/stone-pier experiments.
Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-cover-chains/result.md`.


## October 4 inhabited tunnel supports retained

Room composition now preserves the occupied columns bearing an admitted tunnel
cover, carrying contacts through variation/handoffs. Existing flat roof courses
of low jamb houses are retained when the crown needs them. This keeps inhabited
supports instead of recovering empty stone piers. Two finished covers recovered
across 16 towns; fully covered cells186->188, quarters798->802; all36 bridge cells
remain and floating/air audits stay zero. Focused5/72 and composition/skywalk7/33
pass. Player101 through-route and83 destination approach each2/2. Matched native
101 and holdout83 views inspected. Full enclosure and architecture still open.
Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-inhabited-jambs/result.md`.

## October 4 courtyard canopy orientation

Courtyard trees now try their four measured crown orientations before shrinking.
All existing root support, native roof and public-headroom gates remain. Three
of eight finished towns retain larger trees (two raised courts, one ground
court); the other five keep their previous centre features. Four tests / 18,644
assertions pass against actual emitted trees and baked colliders; native court
views in all three changed towns inspected. This improves canopy enclosure but
does not close the remaining exposed decks or finish the architectural grammar.
Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-court-canopy/result.md`.
Player43/plaza and deck.01 pass both directions. The broader court walk exposes
a separate pre-existing deck.00 blockage at world(18,12.05,-54), reproduced with
the prior single-orientation rule. Keep this generated-surface collision open.

## October 4 invisible roof fragments on raised decks

The deck.00 blockage above is repaired. Roof subtraction retained long strips
about 0.02 mm high that passed an area-only degeneracy check but stopped the
player. Newly clipped fragments now need a minimum altitude above clipping
precision; untouched authored detail is preserved and render/collision agree.
The same 43/grand entrance-to-court route passes both directions (before: both
failed). Native crossing reviewed. Red-first regression passes; roof/junction
suite16/17 passes, with the remaining compact photo-town eave-cut assertion
reproduced under the prior clipping behavior. That separate eave-cut defect and
broader architecture/massif acceptance remain open.
Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-deck-slivers/result.md`.

## October 4 eave/stair interface diagnosis

The remaining compact photo-town eave failure is a real corner contact with
the first tread of transition.07. Complete Pure Village cap retraction and a
complete Suntail tight-eave alternative both still overlap its walking space;
neither is admitted. A focused native-triangle reproduction and rendered view
are saved. Next work must co-design the corner roof and stair interface, while
retaining the headroom proof. This is not another numerical strip and is not
fixed by switching roof materials or dropping the assertion.
Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-eave-stair/result.md`.

October 4 eave precision: fitting now distinguishes real material loss from
unchanged native surfaces merely re-triangulated by public clearance. A native
interior-run regression fails under the old fitter and preserves its cornice
under the new one; actual centimetre-scale losses still block. The hip-corner
trial also intersects the stair and was rejected. The compact photo-town corner
remains open, without weakening its audit or headroom. Evidence:
`docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-eave-precision/result.md`.

October 4 street-window hoods: complete Pure Village Window_5_2 bays now replace
lower frontage bays through a seeded rule; never upper rows under the main eave.
Source reconstruction unchanged. Stock bake 79 modules, production vocabulary
36 derivations / 9 profiles. Grammar 5/3,127, site integration 5/1,426, fresh
holdout 1/635 pass; 8 towns build, 5 hoods across 4 towns; four player entrance
walks pass. Native close/underside views inspected. Modest facade depth only;
large forms, roof/stair conflict and town-wide acceptance remain open. Evidence:
`docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-street-window-hoods/result.md`.

October 4 eave/stair width trial: regenerating actual tread clearance after a
0.6 m roof-side stair setback, plus the native flush verge, clears all roof
parts at the compact photo-town corner; 0.4 m is insufficient. Production
unchanged: a physical edge profile must also own guards, landing openings and
surface claims before admission. Reproducible asserted harness and evidence:
`docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-eave-stair-width/result.md`.

October 4 physical stair profiles: builder now shares explicit bounded edge
insets across treads/collision/guards and closes wider landing shoulders with
rail returns. Deferred surface-plan guards retain the same profile. Profile
3/686, production surface 23 tests, and 32 unchanged-default comparisons pass;
actual builder preserves the roof in the width trial. Automatic admission,
native short-return visual review and player traversal remain open. Evidence:
`docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-stair-edge-profile/result.md`.

October 4 native stair returns: visual review rejected compressed whole railings
on short shoulders. Returns now use two existing stock timber beams plus one
ordinary-width post, aligned to the measured source rail joints. Final native
close views inspected; focused 4/721 pass. Material suite 8/9, eight assertions
match previous renderer (three legacy stone, five grass). Profile admission and
player traversal remain open. Evidence:
`docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-stair-native-returns/result.md`.

October 4 automatic stair/roof admission: bounded physical margins now selected
before sealing public surfaces; lateral routes and closed court corners prohibit
setbacks. Structural eave fitting precedes optional dormers, and complete dormer
geometry must clear public air. Compact photo-town roof regression now passes;
34 tests/1,952 assertions, dormer 4/107, six actual directional player walks pass.
Four holdout roof audits exactly unchanged (their existing defects remain open).
Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-stair-roof-admission/result.md`.

October 4 variant-cap audit correction: all four holdout gable-hole warnings
were caps with unrecognized material variants. Actual native cap render and
missing-cap mutation establish closure; audit now recognizes known variants
only. Two tests/76 assertions pass; four towns rebuilt, all gable counts zero,
other metrics unchanged. Seven eave cuts and three tiny wings remain open.
Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-variant-cap-audit/result.md`.

October 4 native tight-eave seating: Suntail's straight panel projects 0.118539 m
past its nominal wall line. Its tight role now slides the complete panel 0.12 m
inward along the existing 3:2 roof plane; existing crossbar timber closes the
wall-head seam (panel-only version rejected visually). Native Pure roof seating
is explicitly isolated. Final 10 tests/135 assertions pass; native matched
views inspected and affected 103 flight walks both ways. All four holdouts
have zero eave cuts/gable holes/unsupported roof corners; three tiny wings remain.
Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-tight-eave-seating/result.md`.

October 4 compact crown packing trial rejected: two tiny wings in 103/grand
became one compact gable and a boarded closure, but matched native views show
a new cornice crossing an arched window frame. Production packing restored.
Three tiny wings remain open. One attic-closure test also fails on the restored
code and is being investigated. Evidence:
`docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-crown-packing/result.md`.

Crown-trial follow-up: attic warning was source-parcel ownership omitting built
skywalk/retained masses. Test now reads finished occupied storeys and includes
an explicit open-porch ceiling control plus board-removal mutation. Full skywalk
suite 5/10 passes; production crown trial remains rejected. No global art
acceptance implied.

October 4 native foundations: Pure Village inherited Suntail's compressed
half-storey panel and blue corner-base plinth. Both roles now use matching
native 20x15 and 20x10 stone stock at unit scale and common backing alignment.
Matched close-up verifies the blue stripe and repeated block projections are
gone; final foundation/retaining/roof suite 9 tests / 271 assertions passes.
This is a material-adapter repair, not global art acceptance. Evidence:
`docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-native-foundation/result.md`.

October 4 native window surrounds: source timber components on Pure Village
plaster-window panels now have measured clearance envelopes, checked against
finished roof/floor skins. This catches arch-head and sill intersections beyond
glazing, preserving complete alternatives. A stale high-window oracle named a
house no longer generated (also fails on restored code); it now checks backed
Suntail facades in the actual town and retains multiple high openings. Final
17 tests / 296 assertions pass; matched 103/grand close render inspected. Other
source families and overall art acceptance remain open. Evidence:
`docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-window-surrounds/result.md`.

October 4 Suntail surrounds: bake follows native timber-component contacts
from glazing to identify window trim without claiming detached house beams.
Frame walls select eight components; native stone/bay/dormer frames are also
measured. Header-contact regression checks all four orientations and a detached
beam negative control. Facade suite 18 tests / 338 assertions passes; three
7/standard native street views inspected. Broad blank retaining faces seen in
those views remain open. Evidence:
`docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-suntail-window-surrounds/result.md`.

October 4 recessed retaining windows: when a projecting window cannot clear a
path, substitute a complete native windowed masonry panel within the existing
street envelope; only extra inward depth needs new space, and a rear passage
vetoes it. Existing roof/floor opening clearance still applies. Corbels cannot
cross replacements. 7/standard gains nine recessed panels; matched native
street views inspected. Tests 5/101 and four directional controller walks
(underpass plus selected skywalk) pass. These are closed facade windows, not
new rooms in retained earth; broader inhabited-wall composition remains open.
Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-recessed-retaining-windows/result.md`.

October 4 recess holdouts: added measured five-piece Pure Village stone-window
surround, catching header contacts above clear glass. Recess/facade suite 22/400
passes. Four grand towns retain prior roof audits and gain 12/6/11/0 eligible
recesses (53/103/301/83). Native 53 street views retain long blank spans and an
apparent stair/boardwalk seam as open review sites. Evidence:
`docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-recess-holdouts/result.md`.

October 4 retaining/flight joint: diagnosed 53/grand street2 slit as native
masonry protruding through the upper ramp contact. Complete retaining panels
now seat behind the landing edge when wholly within the flight; their windows
follow the actual backing face. Native geometry and public surface geometry
are preserved. Matched render clears the slit; 14 tests/5,694 assertions, both
controller directions, and four unchanged grand roof audits pass. Three tiny
roof wings and broad flat-face composition remain open. Evidence:
`docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-retaining-flight-joints/result.md`.

October 4 Suntail source coverage: all eight original houses reconstruct from
stock after adding one geometry-verified bounded drawer-slide rule (the three
remaining mismatches were Cupboard_1 drawer poses). Engine 8/8, 3,003 meshes /
883,306 vertices plus normals/UVs/indices/materials; Python 15; Pure regression
3/7,861. Source/reconstructed front/back renders inspected. No production family
admission claimed; expanding architectural variation and whole-town QA remain.
Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-suntail-reconstruction/result.md`.

October 4 arcade family study: StreetHouse_8c default exactly preserves its
source derivation; a bounded upper-course removal and whole side-window choices
produce three seeded variants. Rejected the initial low-eave/hood overlap and
replaced the upper hood with a complete flush bay in the short variant. Native
roof/wall closure and original reconstruction regressions: 6/10,350 pass; four
front/back views inspected. NOT admitted to production: baking, site reservations,
support and entrance/player checks remain. Evidence:
`docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-arcade-family/result.md`.

October 4 arcade bake and entrance: 104 stock variants baked with authored
bindings and mirrored collision; real recessed-door siting and complete fabric
recipe added. Exact source prefab now has nonzero sampler probability (four
configurations). Tests 9/10,790; actual-player walks 8 standalone + 8 assembled
recipe pass; four baked views inspected. Production vocabulary registration and
generated-town terrain/neighbor/art validation remain. Evidence:
`docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-arcade-bake-entry/result.md`.

October 4 arcade production admission: four configurations / two new measured
profiles registered through ordinary plot selection (native vocabulary 40/11).
Eight survey towns build; four contain complete arcade houses. Town integration,
103 holdout and corner-turret regressions: 6 tests / 2,620 assertions pass. Six
actual-character entrance routes pass in seeds 7 and 31. Two overviews and three
close frontages inspected. Source middle-front plaster panel still needs a
window-bay variant; sloped terrain and full inter-building geometry auditing
remain, alongside original skyline/enclosure scope. Evidence:
`docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-arcade-town-admission/result.md`.

October 4 arcade frontage: varied configurations now use two complete native
shuttered window bays in the formerly blank middle front course. Exact source
configuration remains unchanged/sampleable. Seven geometry tests / 3,089 asserts
and two town tests / 909 asserts pass; three native town close views inspected.
Regenerated vocabulary byte-identical; no reservation extent change. Remaining
skyline, enclosure and natural-terrain work stays open. Evidence:
`docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-arcade-frontage/result.md`.

October 4 range articulation: 2:1 crowns now always attempt a connected
cross-gable (mandatory threshold was 3:1). Diagnostics distinguish random skips
from actual roof/gable constraints. Red-first 96 cases now pass 1,440 assertions;
range suite 10/11, sole old parcel-ID failure reproduced with old rule. Matched
31/103 gain 1/4 cross-gable plans; six town audits have zero new roof safety or
public-air failures. Existing 103 thin strips and 53 tiny crown remain. Two
native overviews inspected; broader skyline/enclosure scope remains open.
Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-range-articulation/result.md`.

### October 4 upper-street investigation

The finished enclosure probe now separates inhabited and structural flanks and reports complete tunnel-cover height requirements. Three-town height-cap experiment did not change the exposed routes and was reverted. The citadel climb still wraps outside tall fronts; stair/room co-planning and player-level review remain open. See `docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-upper-street-investigation/result.md`.

### October 4 interior citadel climbs

The gate planner now prefers a supported entrance below district grade and an interior ascent. Swept stair slots and both ceiling supports are proved before commitment; support reservations protect later carving, and nested climbs cannot cut a higher tier prematurely. The exterior gate remains a fallback where the interior route cannot fit. Native fortification trim yields to exact stair headroom as complete parapet assemblies, avoiding both blocked treads and floating merlons.

Validation: 32/32 source plans, 13 interior climbs in 12 towns; six tests / 940 assertions; 14/14 final character traversals across five fully built towns including two nested-tier examples. Matched native 83/grand views and an upward entrance-ceiling view were inspected. Full redesign remains open: exposed fallback routes (31/large), broad blank walls and long rooflines still need work. Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-interior-citadel-gates/result.md`.

### October 4 native fortified-wall openings

Full platform-wall modules can now use Pure Village's native recessed stone windows, with frame/roof/floor/neighbor/public-air checks and spacing that tries the next clear bay when one is blocked. Native block footings now stop below the authored sill (0.5 m total). No occurrence, seed-specific or structural-room changes. Twelve tests / 1,083 assertions pass across two runs; 83/grand admits 23 windows and its actual-character gate ascent/descent pass. Matched 83 views plus 63/103 holdout views inspected. Broader flat fronts, long roof planes and masonry-family transitions remain open. Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-fortified-windows/result.md`.

### October 4 public masonry compatibility

The final public-wall substitution used blue Suntail house-footing stone beside cream Pure Village fortifications. Both public retaining-panel IDs now use the native Pure half course, preserving their measured support envelope; house-specific plinths stay independent. New regression: seven assertions pass. Existing materials: 4/5 tests pass, the remaining 11 assertions reproduced unchanged with the previous mapping. Matched 103/grand native face views inspected; actual gate ascent/descent pass. Upper house material transitions and broader skyline work remain open. Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-public-masonry/result.md`.

### October 4 tall-facade investigation — height-only candidate rejected

63/grand's five-storey shafts extend above the originally bored massif. A candidate bounded optional height by that field, preserving required street/room support, and passed a 32-plan sweep, eight finished safety probes and gate traversal. It was nevertheless rejected: matched towns 7/31/53 lost quarter-cell room ceilings two bands above paths. The old height rule is restored; 63's original walk/ceiling records match exactly. The enclosure harness now distinguishes ceiling distances (`ceiling_band_histogram`, `full_cover_max_ceiling_band_histogram`), since aggregate coverage also counted very distant rooms. Further silhouette changes must preserve overhead rooms or co-plan lower tunnel coverage, not merely lower parcels. Evidence and rejected patch: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-massif-house-height/result.md`.

### October 4 cover-aware height trials — rejected

Late kit crown trimming could not alter the target stacks without disturbing doors/balconies or neighbors. Early massif caps with one/two reserved overhead rooms still displaced real low passage ceilings; both are removed. Four finished towns had zero floating/roof-air failures, demonstrating why those checks alone cannot accept architecture. A new snapshot comparator checks ceiling preservation at each town/walk/quarter instead of accepting unchanged aggregate totals (3 tests / 11 assertions); it correctly rejects the two-room trial's ten lost quarters within four bands. Further work must preserve actual room relationships while forming roofable wings/setbacks, not tune another generic height reserve. Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-cover-aware-height/result.md`.

### October 4 primary wings — active candidate, visual repair pending

Primary stepped wings now run before small loggia notches on long crowns too; sampled two-storey cuts also retry a valid one-storey wing. Two of eight surveyed towns gain real lower roofed wings. Six tests / 221 assertions pass; all 300 overhead quarter-cell ceiling records remain exactly unchanged; floating/roof-air audits are zero and four actual street traversals pass. Matched 53 views improve the height break, but 63 exposes a protruding vertical timber member at its new roof junction. Candidate remains in the worktree, explicitly not fully art-approved; diagnose and repair the supported join next. Original five-storey shafts remain open. Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-primary-wings/result.md`.

### October 5 overhang support endpoint — primary-wing join repaired

The exposed 63/grand pole was an independent room-overhang support, not a corner post. `_support_mass` incorrectly used the top of the reserved room as its endpoint; it now reaches the room's floor bearing plane. All four native supports remain. Red-first measured-bounds regression and suites: 8 tests / 313 assertions pass, including seven finished towns and native arcade retention. Two actual street traversals pass; both native join views show the protrusion gone and the stepped roofs intact. The primary-wing candidate's reported defect is closed; five-storey shafts and the wider redesign remain open. Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-overhang-post-endpoint/result.md`.

### October 5 compound crown wings — structural pass, one visual finding open

Stepped wings now admit contained ranges of L/T crowns while requiring a connected, roofable remainder and preserving door/balcony/support/public-space proofs. Seven tests / 281 assertions pass; eight towns retain all 300 exact overhead cover samples and zero floating/public-air failures. Five towns gain lower roofed ranges; four actual street traversals pass. Native views show improved height breaks, but a 301 landmark view exposes an apparently uncovered neighboring room whose baseline status remains unproven. Compare and resolve that junction before full visual acceptance; tall shafts and overall redesign remain open. Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-compound-wings/result.md`.

### October 5 native room ceilings beneath structural skins

The 301 open room predates the compound-wing rule. Its roof was suppressed by structural occupancy, but the retaining skin had no horizontal surface. The designer now records such crowns; final composition adds native board ceilings while deferring to actual upper-room floors and existing decks, avoiding duplicate full/partial interfaces. Four tests / 17 assertions pass; eight towns preserve all 300 overhead samples with zero floating/roof-air failures. Two actual street traversals pass, and a matched native render proves the twelve-module room is closed. This resolves the compound-wing review's specific open-room finding; full town art remains open. Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-room-ceilings/result.md`.

### October 5 complete frontage alternatives

Projection fitting keeps the seeded preferred frontage, then tries smaller complete two/three-module bays under the same bearing, closure, public-air and measured-neighbor proofs. Red-first door fixture and full suite pass (8 tests / 72 assertions). Six finished towns gain five projections, with three existing placements relocated; all 220 compared overhead samples remain unchanged and floating/roof-air audits stay zero. Native views reviewed across all six towns; a valid 63 access route passes both ways. Tall shafts and overall architectural character remain open. Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-frontage-candidates/result.md`.

### October 5 flower-box sill fitting

Fixed-height flower boxes were obscuring low-sill Pure Village panes. Finished boxes now use baked pane bounds, retaining native scale and allowing at most 15% vertical foliage overlap; ground-clipping and orphan boxes are omitted, followed by existing public-clearance checks. Three tests / nine assertions pass. Matched 103 Pure Village and 63 Suntail views inspected: arched glazing is visible and suitable Suntail placement remains. Geometry/layout scope is unchanged; wider architecture remains open. Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-window-box-sills/result.md`.

### October 5 local bracket bearings for stepped wings

Wing lowering now protects measured balcony-raker contacts instead of rejecting every room on a balcony-bearing storey. Existing lower-wall jetty protection remains. Nine tests / 526 assertions pass; six towns preserve all 220 compared overhead quarters, exact walk records and zero floating/roof-air failures. Five new stepped wings across 53/83/301 retain all 25 measured contact cells; a connected 301 approach passes actual-player traversal in both directions. Five exterior native views inspected. Eight absent contact cells in unchanged 63/103 reproduce under the old wing rule and remain an open diagnostic. Tall regular shafts and exposed boardwalks remain open. Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-local-bracket-bearings/result.md`.

### October 5 stacked balcony bearings

The older 63/103 bracket discrepancy was a real shifted-floorplate case: upper-balcony braces ended in air over a lower balcony, whose private reservation was mistaken for a wall. Actual house floorplates now distinguish this case; the existing timber asset forms a post/diagonal triangle from the lower deck, limited to one storey and outside public air. Five triangles repaired per affected town, matched native views reviewed. Four tests / 60 assertions plus a focused ten-assertion native endpoint check pass. Six-town survey fields and all 220 overhead samples remain identical; six actual skywalk traversals pass. This closes that specific older bearing finding; tall shafts and exposed boardwalks remain open. Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-stacked-balcony-bearings/result.md`.

### October 5 owner follow-up — active requirements

Preserve all earlier goals. The owner additionally requests: (1) outcroppings matching host colors/materials; (2) merge overlapping short parallel gables into coherent roof masses; (3) more properly attached corner spires on sufficiently tall buildings; (4) more supported skywalks and bored tunnels; (5) broad town-square decks inside building clusters, including upper massif levels, rather than gaps between disparate satellites. Acceptance needs native and actual-route evidence, with squares judged against finished inhabited frontages rather than raw massif height.

Bay finish repair: the assembler now applies the house tint; Pure kits use the exact host plaster on geometry-identical Suntail bay variants, preserving other authored materials and frame finishes. Two tests / 110 assertions and matched native views pass. Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-bay-host-materials/result.md`.

Interior-square ranking trial rejected: 24/24 plans sealed; 31/large expanded from 2x2 to 3x3 with valid support and bidirectional player access, but the native view still showed an exposed edge platform. Raw massif frontage was a misleading enclosure proxy. Production ranking restored and candidate test removed. Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-interior-square-trial/result.md`. Parallel-gable merging, increased spires, more covered routes and truly internal squares remain unimplemented for this follow-up.

### October 5 short parallel roof ranges

Added whole-envelope admission for joining side-by-side short gables. The 103/grand skywalk/landing pair now has one continuous native roof; matching before/after views from both sides inspected. Six towns retain identical inhabited-route coverage (220 quarters), zero floating masses and zero roof-air intrusions; native junction suite 9 tests / 11,975 assertions passes. This addresses a reproduced pair, not all roofline variety; additional spires, more covered routes and truly internal squares remain active. Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-parallel-roof-ranges/result.md`.

Parallel-range acceptance completed: focused suite 4 tests / 24 assertions; actual player traverses all three 103/grand skywalk/source-bridge routes both ways (6/6), including the affected route. Full redesign remains active.

### October 5 corner-tower datum trial — rejected

Trying actual raised-wing floor datums produced 237 extra corner-tower attempts across six towns; every added attempt failed the measured footing bearing proof. All accepted towers, route coverage and safety records stayed identical. Candidate placement changes/tests archived and production restored; bounded corner-occupancy diagnostics retained. Next work needs planned corner bearings or verified native corbel connections, not more spawn probability or weaker support checks. Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-corner-tower-datums/result.md`.

### October 5 native corbelled corner turrets

Added the native Pure Village round support and a continuous two-wall corner-bearing rule for sufficiently tall hosts. Six comparison towns gain towers from 3 to 9 (seven corbel placements, one replacing a half-shaft); all 220 covered quarters remain, with zero floating/roof-air failures. Four holdout towns also pass those safety audits. Focused suites, palette checks, ten actual 31/large traversals, isolated support views and native views of all seven placements pass this bounded review. Matched 301 before/after pairs inspected. More covered routes and broad internal square decks remain outstanding; tall regular facades and exposed walks remain open. Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-corbelled-corner-turrets/result.md`.

### October 5 finished court frontages — missing address contract

A new six-town finished-court probe finds nine of ten decks are 2x2 macro columns and several raised squares sit above neighboring occupied floors. The critical planning gap is now explicit: house seeds and legal door addresses come only from passage cells; a connected court deck cannot supply house addresses. Court footprint reservation alone cannot preserve inhabited enclosure. Next implementation must integrate court-boundary addresses with reachability, source validation, door composition and frontage reservation, rather than repeat raw-massif ranking. No production layout change claimed. Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-court-frontage-diagnosis/result.md`.

### October 5 connected court house addresses

Connected court floors now supply legal house addresses through source seeding, volume frontage and exact paved threshold validation. Real 301 raised-court regression: red-first failure then 3 tests / 16 assertions pass; plot suite matches restored baseline exactly (39/42 tests, same three existing failures). Six towns preserve all 220 prior covered quarters and gain 24; four holdouts pass safety audits. Six actual court/door/new-underpass traversals pass. Native matched views show a new court-facing facade, but 301 loses its previous tree after the doorway notches its planting bed and courts remain small/exposed. Broad court + surrounding houses + durable planting must still be co-planned. Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-court-house-addresses/result.md`.

### October 5 notched court planting

Corrected the 301 missing-tree diagnosis: its new doorway leaves a three-cell L-shaped bed, which the old mandatory 2x2-block search discarded before measured clearance. Irregular planned beds now search actual root positions with unchanged native assets, height alternatives, roof/trunk/headroom checks and protected public entries. Two focused tests / six assertions, native 301 test / 3,898 assertions, matched views and four actual court/door traversals pass. Older missing-tree assertions reproduce with prior code; broader internal squares remain open. Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-irregular-court-planting/result.md`.

### October 5 broad internal courts and deck finish

Broad court priority now uses real house admission and precedes landmark reservations when three sides have buildable frontages. With the earlier court-address contract, 31/large grows from 2x2 to 3x3 and gains real court-facing houses. Public court walks now retain native board surfaces; turf belongs only to unwalked planting islands. Final 30 tests / 976 assertions pass; ten towns preserve all 454 compared covered quarters with zero floating/roof-air findings; four final court/door player traversals pass. Native 31/301 views and matched 31 before cameras reviewed. Older October 2 size assertions fail identically under restored baseline; not weakened. Only one of ten squares expands, some remain exposed, and tall facades/full redesign are still open. Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-broad-court-decks/result.md`.

### October 5 — alternate loggia positions rejected

Tested searching supported alternate facade recesses around blocked doors. Six-town covered-route checks preserved all 244 existing quarters, but matched native seed 63 views retained the five-storey shaft and only changed its crown roof. Reverted the candidate and its tests; earlier accepted changes remain. Existing street-loggia count failure reproduced at baseline. Next step is joint room/route composition, not more superficial facade details. Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-loggia-fallback-trial/result.md`.


## October 5 — supported covered routes

Accepted back-room parcel identity repair and independent supported street skywalks. Shared native crown occupancy rejects masonry-obstructed spans. Ten-town covered quarters 454→482, all old samples preserved; floating/public-air audits zero; 10 focused tests / 48 assertions and final holdout player runs 12/12 pass. Seed 31 loses one turret site to restored occupied rooms. Tall flat shafts and broad visual acceptance remain open. Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-supported-covered-routes/result.md`.


## October 5 — second projecting frontage

Tall houses can fit a second supported room projection on another face after all first fronts are placed. Ten towns: projections 31→33; previous fronts, towers and all 482 covered quarters preserved; floating/public-air audits zero. Nine tests / 77 assertions and 14 final player traversals pass. Matched native views show additional depth, but five-storey shafts remain: this is a limited facade improvement, not acceptance of the overall silhouette. The exposed-wall diagnostic now excludes party walls. Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-second-frontage/result.md`.


## October 5 — crown obligations and height recheck

The earlier broad field-height cap still loses low covers after the host-identity/skywalk repairs and was restored byte-for-byte. New native-owner traces distinguish actual lost house rooms from selected skywalks. In 63/grand both low/high bridge candidates remain valid, but seeded ordering chooses the higher one; street-distance ordering is being checked independently. The three tall source crowns have no direct public entrances, only later private balcony/overhang contacts, and stand wholly on fortified plinths. These facts support joint silhouette/circulation work before optional feature placement, not a late visual trim. Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-height-obligations/result.md`.


## October 5 — closer street skywalks

Accepted closest-ceiling ordering among equally wide, fully valid private street crossings. Ten towns preserve all 482 covered quarters; two quarters in 63/grand gain a ceiling two bands lower. Towers unchanged; floating/public-air audits zero; 9 tests / 41 assertions and 12/12 player traversals pass. Matched native bridge and relocated facade views reviewed. Five-storey shafts remain an unresolved silhouette issue; broad height cap stays reverted. Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-low-street-skywalks/result.md`.


## October 5 — raised-district proportions

Accepted an early crown-height policy only for wholly plinth-borne houses, preserving upper street/room authority and an adjacent passage’s overhead room budget. In 63 the three five-storey houses become three/four/three; one four-storey house in each of 103/83 becomes three. Ten-town low covers (through seven bands) are preserved; 14 distant 8–11-band covers and one redundant high crossing in 63 disappear intentionally with shortened crowns (482→468 total quarters). One extra corner turret fits. Eight relevant tests / 228 assertions and 16 player traversals pass; five older platform tests reproduce exactly the same 501 assertion failures at baseline. Native views of all changed towns inspected. Ground/mixed-datum shafts and broader art remain open. Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-raised-district-proportions/result.md`.


## October 5 — bay/skywalk ordering diagnosis

Rejected ordinary-house three-storey optional budget: 31 loses two low bridge-houses (six four-band quarters), despite unchanged endpoint rooms. Exact occupancy disproves the roof hypothesis: optional facade-bay.02 moves into the bridge’s first/lateral cells. Restoring prior height restores gap/site/enclosure admission. Retained a generic crossing-refusal diagnostic; production height restored to the accepted raised-district policy. Next: share supported crossing prospects with optional bay arbitration before retrying ordinary silhouettes; do not weaken late clearance checks. Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-bay-skywalk-priority/result.md`.


## October 5 — crossings before bays and open skywalk landings

Accepted shared complete-room/street-crossing prospect arbitration before optional facade bays. Ten towns: covered quarters 468→476; 43 gains low cover, 8 shifts a low crossing one bay (two covered quarters move), other eight towns exactly unchanged. Floating/public-air audits zero; plots/turrets unchanged. Fixed native balcony end guards fencing off accepted skywalk entrances, reproduced at baseline in 53. Final actual-player checks 40/40 across 53/43/8; 15 tests / 241 assertions. Native crossings, landing openings and relocated projection inspected. Ordinary optional-height cap remains rejected because holdouts lose low cover. Full prefab grammar and overall art remain open. Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-street-crossing-bay-priority/result.md`.


## October 5 — double-ended native projecting room study

Added a coherent optional rear upper room to the Pure Village street grammar, including native walls/soffit/supports and matching longer roof/ridge endings. Geometry and measured-envelope tests pass (7/3356 and 3/897), isolated entry walks 8/8, candidate town entry walks 4/4. Early town registration naturally selects the family but reduces covered quarters in 31/large (34→24) and 8/grand (70→60), so production registration is deferred; normal vocabulary remains 40 derivations/11 profiles and both complete restored audit records match baseline. Explicit exporter study flag retains reproducibility. This simple-gable extension is not completion of complex building grammar or town art. Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-double-projecting-room/result.md`.


## October 5 — committed square frontages and leafy large beds

Protected the real house sites used to admit a broad court from subsequent landmark envelopes and optional decks. The preliminary perimeter preview remains unchanged: protecting its speculative sites lost the square and that version was rejected. In final 31/large the same 3×3 raised deck gains a third inhabited side (west 0/6→4/6 adjacent occupied fine cells); one lower landmark yields to room buildings. Large planted-bed tree choices now use the measured leafy canopy fitter instead of the legacy bare tree, retaining seeded wells/stalls and full roof/headroom checks. Nine tests / 118 assertions; ten towns preserve every old ceiling and gain four covered quarters (476→480), zero floating/public-air findings, towers unchanged. Final player traversal 26/26 across court, doors, bridges and underpasses. Fixed native before/after views reviewed. Broader square supply, tall flat faces and full architectural grammar remain open. Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-inhabited-square-frontages/result.md`.


## October 5 — repeated roof pavilions without long collinear unions

Long roof ranges now recurse into supported native-depth transverse pavilions and shorter connecting halls. Adjacent crown strips account for earlier wings so the normal collinear join does not recreate longer roofs; the first aligned candidate was rejected. In 31/large the largest section falls 28→16 modules, in 103/grand 20→16. All 480 existing covered quarters across ten towns keep their exact ceilings, with zero floating/public-air findings; 43/grand gains one fitting corner turret. New regressions pass; focused suite 12/13 with two unchanged baseline assertions in the older dense-range test. Player traversal 16/16 and native square, holdout and turret views reviewed. Tall repetitive façades and overall grammar/art acceptance remain open. Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-repeated-roof-pavilions/result.md`.


## October 5 — remote stepped wings on skywalk houses

Removed the whole-storey `abutted` veto from wing shaping; actual door cells, walked floors, external construction and bracket bearings still protect the bridge landing. Jetties remain flush. Three houses in the ten-town corpus gain roofed lower wings (8 house.014, 301 houses.022/.024); every one of 480 covered quarters keeps its exact ceiling, floating/public-air audits stay zero and turret counts are unchanged. Eleven focused tests across two runs / 845 assertions, 20/20 player traversals and matched native views; roof audits retain only previous findings. The façade probe now joins finished houses to source height decisions, exposing optional skyline peaks in 8/9 as a remaining cause of repeated five-storey shafts. Full design scope stays open. Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-remote-skywalk-wings/result.md`.


## October 5 — bounded optional skyline peaks

Optional narrow skyline peaks now roll at most four room storeys plus roof reservation; actual upper streets and carried rooms retain their required height. Five source plots shorten across ten towns, with four finished kit houses visibly changing (53 already had a downstream height constraint). All 480 covered quarters retain exact ceilings, floating/public-air audits stay zero and turret counts remain unchanged; one corner turret moves down with its host and was visually checked. Six focused tests / 207 assertions and 40/40 player traversals pass. Matched native views and roof audits retain only previous defect findings. This is a limited proportion correction, not completion of façade variety, square supply or the full prefab grammar. Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-narrow-skyline-peaks/result.md`.


## October 5 — broader court and recovery of dropped house frontages

A deeper-corner-only candidate produced a larger but insufficiently enclosed square and was rejected. Root tracing found a viable court-facing seed absorbed into a taller house and dropped during final height assignment. A bounded recovery pass over committed court-house columns restores it. Combined with a six-band corner allowance only for broad three-sided sites (same three-band mean budget and support rules), 53/grand now has a 3×3 deck court with three majority inhabited sides. Eight focused tests / 90 assertions and 32 actual-player checks pass; all 480 old covered quarters keep exact ceilings across ten towns, with zero floating/public-air findings and the other nine source layouts unchanged. Fixed native views inspected. Follow-up corrected the view attribution: turret1 is new and passes the two-sided attachment/palette review; turret2 is an existing tower. Its suspected fragment is a complete dormer several metres behind the cap, confirmed by mesh rays, opposite view and a reversible no-dormer render. The costly exact-cap-cutting study did not change it and was rejected. This bounded court change is accepted; deeper internal/upper squares and overall architectural acceptance remain open. Evidence at `docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-court-frontage-recovery/result.md`.


## October 5 — interior raised-square capacity study

The uncarved field offers broad supported interior candidates with at least three house frontages in all ten reviewed towns; all are raised. At the existing early reservation (after the mandatory spine and gates, before optional streets), only 31/large has an addressed broad three-sided site. A diagnostic shared-level-street waiver adds no such site after carving, so it was not shipped. The next change must co-plan the square and its approach before fixing the spine; merely widening cut budgets or sharing street headroom does not meet the requested enclosure. Diagnostic harness gains field-only and shared-floor modes plus specific support refusals. No production rules changed. Evidence and reproducible studies: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-interior-court-capacity/result.md`.


## October 5 — co-planned interior-square route prototype (rejected)

A supported interior court proposal can guide the climb to a real level entrance: 13/grand expands from a 2×4 pocket to 3×3 at floor 2 inside the cluster. Initial placement regression passes, but finished-room enclosure fails (one majority side, because lower-floor houses consume the prospective frontages with roofs), and rerouted 43/grand fails exact source-bearing foundations. Native review and strengthened tests reject the candidate (1/3 tests). Production carver restored byte-for-byte; resumable patch/helper/tests and evidence are archived under `docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-interior-court-route/`. Next: co-decide actual court-level room ownership/roof reservation and diagnose 43's foundation translation; also bound search cost (13 needed 10,740 visits). No new square feature ships from this prototype.


## October 5 — interior-court ownership experiment and late skywalk canopy clearance

A pre-spine 3×3 court proposal plus datum/face ownership produced genuine three-sided raised squares in 13 and 301. A ten-town experiment increased inhabited path coverage 480→739 fine quarters, but changed routes lost some old crossings and reduced fitting turrets 18→16. Ninety player traversals passed after a canopy repair; native review still found new clipped landmark eaves/tiny roofs in 301 and a roof tip through 9’s planted court bed. The route, plot-priority and flight-support experiment was archived and all three accepted source files restored byte-for-byte. None of those square/coverage gains are shipped.

Retained fix: optional facade ornaments now check late skywalks and both landings, which the earlier public-floor mesh omitted. A Pure Village wall hood blocked both directions of 43’s new crossing; the frozen source reproduces the failure independently of the live layout. Complete canopy-run rejection fixes it without cutting bridge walls or roofs. Accepted-source focused suite: 7 tests / 171 assertions; frozen regression fails when this callback is disabled and passes with it. The broader redesign remains active, particularly whole-court surface/roof ownership and spire supply. Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-court-frontage-ownership/result.md`.


## October 5 — ridge envelopes beneath raised courts

The frozen rejected 9/grand layout exposed a nominal-height error: native ridge caps rise above the roof slopes and entered the planted square above. Kit roof admission now includes measured ridge height, retaining the room below and choosing the existing closed crown fallback when necessary. Three new tests / 18 assertions pass; restoring the old calculation reproduces the exact green ridge. Native matched/opposite views are clear; four square and ten skywalk player traversals pass. Existing focused checks pass 10/12 (two highest-tier expectations also fail before this change); other sampled roof defects are unchanged. The larger interior-square route experiment remains archived, and extra spires/enclosed circulation still need work. Evidence and runnable frozen-source harness commands: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-courtyard-roof-envelope/result.md`.


## October 5 — complete Pure Village eaves at public walks

The frozen interior-square candidate 301 still clipped five landmark eaves after the ridge-envelope repair. Pure’s straight slope foot projects 0.298 m past its nominal line. Its tight course now seats along the native roof plane with matching existing timber fascia. A first simple-slide version was rejected because its backing emerged at the ridge; the accepted assembly closes the hidden surplus at the original course joint. Matched close views and native triangle regressions confirm the complete foot and closed upper seam. All 22 focused tests pass; final new regressions 3/33 and deliberate joint-cut disabling confirm the defect. Clipped eaves fall 5→0 in frozen 301 and3→0 in live 9; live 8’s known gable hole remains. The court-layout candidate stays archived because four tiny wings (two adjacent) remain in 301. Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-pure-tight-eave/result.md`.


## October 5 — preserve roofed pavilions through balcony placement

A recess after stepped-wing shaping was cutting intact lower pavilions into one-module roof strips. `KitLoggias` now preserves the roofable width of their declared crown parts, while allowing other recesses. Frozen 301's tiny sections fall 4→0 (roofs 62→60), with four turrets and no gable holes, exposed ends, clipped eaves or unsupported roofs. Live 8 improves 3→1 tiny sections; its existing house.041 hole remains. Live 9 is unchanged. Matched native front/reverse views verify whole lower gables; the initial blocked camera was replaced. Four actual-player square traversals pass. Two new tests / three assertions pass; focused suite 13/14 retains a baseline-reproduced street-loggia expectation. The larger interior-square route candidate remains archived, and spire/circulation supply and full art acceptance remain open. Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-loggia-roofed-wings/result.md`.


## October 5 — gable contact diagnosis (candidate archived)

Frozen experimental 8/grand now has a reusable source fixture. Its five-sample house.027 gable finding comes exclusively from the adjoining higher cross roof cutting the outward panel thickness at the eave. A small mass reproduces it. A seam-preserving cutter passes the initial regression and removes live 8's older finding, but matched overview/close renders are pixel-identical; a visible benefit is unproven. The candidate was archived and production roof union restored. This is not proof that the original finding is harmless. Next prioritize the visible roof intrusion inside frozen 43's bridge, then revisit complete assembly visibility and square/spire/crossing acceptance. Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-gable-contact-study/result.md`.

October 5: enclosed crossings now close their attic with native kit boards and reserve their full room height against facade ornaments (including endpoint bays). Frozen43 k0045 canopy intrusion removed; 8 tests/31 assertions and 8/8 actual-player traversals pass. Disabling both fixes reproduces two failures. Matched views and rejected roof-cut experiment: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-enclosed-crossing-interiors/result.md`. Interior-square layout/spire supply remain open. Next owner steering: warm Suntail plaster toward Pure Village and share regional terrain colour/real grass on courtyard lawns.

October 5 owner palette follow-up: warm Suntail plaster preserves its authored texture; courtyard lawn and grass colours now share the terrain’s 24 m regional tint field. Native comparison and raised courtyard with 349 actual grass clumps inspected. New 3/19 tests pass, active falsification reproduces all three failures; broader 35/36 with one independently reproduced retired-grade test failure. See `docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-warm-plaster-regional-lawns/result.md`.

## October 5 — resumed interior-square / bridge co-planning (active candidate)

The working tree now contains the resumed court prototype, not an accepted final layout. Three root defects were found: rounded-tread admission missed the compiler’s full reserved flight envelope; the square classifier ignored already committed bridge-end houses; a late lower wall room erased a bearing band under an upper bridge house. Focused red-first repairs restore 43’s nine-column floor7 square and its actual three-sided room enclosure. Integration 4 tests /25 assertions passes; native courtyard shows a bridge overhead and actual planted grass. Ten-town roof survey and player checks are still being completed; initial roof results are clean for13/301 but43 has a new gable-hole finding, so do not promote the candidate yet. Frozen failed support layout and reproducible probe: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-court-bridge-coownership/result.md`. Full goal, additional spires, circulation supply, and broad art acceptance remain open.


October5 candidate validation follow-up: all ten surveyed towns build; candidate43 passes all18 actual-player courtyard/skywalk/underpass routes. Wider acceptance remains open:43 has one gable-hole finding,8 and103 retain roof findings, and the wall-room regression suite is6/7 (2/grand lacks the expected short terrace room; not baseline-proved). The candidate remains applied for iteration. Full evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-court-bridge-coownership/result.md`.


October5 native gable audit follow-up: candidate43's four flagged samples are inside the neighbouring attic at their actual authored plaster face (x16.157), despite lying outside at the nominal module plane. The audit now proves enclosure at every actual outward face hit; missing panels and the same cut with the neighbouring attic removed still fail. New5/22 tests pass; disabling the correction reproduces3 failures. Holdouts8/103/13 have no gable holes; two real thin roof strips remain. The short-terrace expectation also failed on the saved pre-candidate2/grand source; it now exercises the actual three-band room in41/large with all original clearance/support assertions,7/7 tests92 assertions. Refreshed ten-town circulation/turret/safety measurement remains in progress. Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-gable-surface-audit/result.md`. The full redesign remains active.


October5 refreshed candidate safety survey is complete: ten towns build, floating/public-air0 throughout. Covered floor quarters480→711; fitting generated turrets18→16. This is not acceptance of the spire goal or preservation of every old crossing (9 retains80→71);43 now has100 covered quarters after the bearing repair. Roof strips8 house000 and103 bridge00.end1.lower remain the next fitting problem. Full current comparison and admission records: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-gable-surface-audit/current-comparison.json`. No live processes remain.


October5 backed-shed experiment (applied, NOT accepted): constrained narrow lower crowns can use a full native slope backed by a flush upper room; addressed doors/public headroom block admission. Four tests/nine assertions pass, but corrected native previews still show ridge/bargeboard remnants at the higher-eave junction. The first preview omitted trimmed meshes and was invalid evidence; final harness uses FeatureCommitQueue. Production BuildingDesigner/KitRoofMeshUnion currently contain the unfinished candidate. See `docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-backed-shed-study/result.md` for exact rollback delta, matched views and outstanding gates. No claim of art acceptance or full redesign completion.


October5 backed-shed follow-up supersedes the unfinished status above: bounded join repair accepted after removing the free ridge cap and fitting end trim beneath the upper eave. Both-kit matched/side views plus an unobstructed town8 alternate inspected; 20 tests/12,023 assertions pass, old-assembler falsification restores three stray caps. Four towns retain zero floating/public-air intrusions and unchanged enclosure counts; town8 courtyard walks4/4. Final93-roof survey is clear except the existing thin bridge-end crown in103. Full redesign and increased spire/circulation supply remain open. See `docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-backed-shed-study/result.md`.


October5 spire-supply experiment: higher-terrace corner datums pass a red-first structural fixture but add no towers in seven full towns; production proposer restored exactly and candidate archived rather than promoted. Attached-tower counts also omit native recipe towers (8/grand contains `anchor.z_native.turret.00` despite attached count0). Next supply work must measure complete native+attached skyline and address early structural space, not just late candidate quantity. Evidence and native fragment finding: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-terrace-tower-datums/result.md`. Full redesign remains open.


October5 full spire census: native+attached cap instances8/83/13/43/103=1/0/2/1/1;43 and103 also have opaque whole-house prefabs excluded from this cap count. Seed83 already prefers a turret; of12 initially ground-supported clear bodies, two are cut by spine/market and all ten eastern sites by district_access (then loop_join), before landmark preview can protect them. Next implementation target is joint district-access/frontage + tower-house siting, not spawn probability or only minimum-datum attachment. Raw part owners/poses and complete site-cut trace: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-spire-site-census/result.md`. Production placement unchanged; all jobs terminal; full goal open.


October5 district tower-house candidate: joint district access/site selection plus protected neighbouring frontage passes source checks, but finished construction exposed a market canopy occupying the promised native house. Added a finished-fabric red-first regression and market selection that respects source asset plot volumes; it now passes. Native player walks, matched views and eight-town holdout checks remain in progress. Candidate is applied, not yet accepted. Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-district-tower-frontage/result.md`. Full redesign remains active.


October5 district candidate validation: finished native tower survives after market ownership repair; matched front/back/overview inspected, native entrance2/2 and district streets8/8 actual-player runs pass. Focused7/7 tests62 assertions; eight towns floating/public-air0. Four-town200-roof survey has one thin crown in127 (baseline attribution pending), no other measured defects. Candidate remains applied for further art/holdout work;83 covered quarters68→64 is explicitly retained as an open tradeoff. No live jobs remain. See district-tower-frontage result.


October5 crown repacking candidate (applied, not accepted):127 thin roof traced to greedy rectangle packing, not walkway headroom. Repartitioning only existing crown cells restores a full offset roof; final focused7/7 tests76 assertions pass. First-version four-town204-roof survey has only the known103 thin crown, but native view exposes a trim contact at the neighbouring blue roof; final depth-enumeration extension still needs repeated visual/corpus/player verification. All jobs terminal. Evidence and exact scoped rollback: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-crown-repacking/result.md`. Full goal stays active.


October5 crown candidate final-depth verification: four-town204-roof results reproduced, focused9/9 tests85 assertions,127 sampled walks6/6 and finished public-air intrusion0. Close opposite views nevertheless prove a blue ridge cap passes through the new curved Suntail eave (the apparent trim is actually house034/k0303 native cornice). Straight-plane roof union is insufficient for this contact. Candidate stays applied and unaccepted; next repair must measure the actual mixed-kit eave/ridge geometry. Evidence in crown-repacking/eave-contact. All jobs terminal; full goal remains active.


October5 native ridge/eave contact candidate: actual upward eave geometry terminates foreign ridge ornaments whose bases it covers; 127 large protruding cap removed in opposite close views. Small reverse seam remnant remains, so candidate applied but unaccepted. Focused11/11 tests98 assertions pass. Need resolve remnant and broader verification; all jobs terminal. Evidence/rollback: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-ridge-eave-contact/result.md`. Full goal active.


October5 ridge-contact follow-up: actual ray picks identify remaining k0229 cap flutes. Full-width termination restricted by low-rim bearing admission removes remnant without cutting higher ridges; both final close views inspected. Final27 tests12,099 assertions pass. Earlier-candidate four-town204-roof and six-fixture public-air checks pass but predate refinement; final corpus/player acceptance outstanding. Exact evidence and scoped patch in october5-ridge-eave-contact. All jobs terminal; full redesign active.


October5 final ridge/crown validation: final-source204-roof survey remains clear except known103 thin crown;127 player circulation6/6 passes. Bounded127 repacking/ridge contact accepted with final27-test suite and both views. Remaining103 bridge-end close view/access probe rules out blind terrace merging: no walked band6 access; half adjacentdeck has rooms immediately aboveband7. Structural access/headroom or actual upper-bearing roof composition is required. Evidence: october5-bridge-end-roof-investigation/result.md. All processes terminal; full redesign active.


October5 end-backed-shed experiment rejected: full-height own-room backing permits103 narrow wing to become a single native slope,8 tests34 assertions pass, but actual front/side exposes hanging eave trim and awkward neighbouring-room join. Designer restored exactly; candidate patch/test/views archived at october5-end-backed-shed-experiment. Need measured complete eave/verge footprint and room contact, not just nominal roof profile. All jobs terminal; full redesign stays active.


October5 court holdouts: current43/83/211 grand eachretain9-column mainplaza and3finished inhabited sides.257 loses interiorproposal after40,020 routevisits, retains6-column plaza with1strongside.211 nativegrass282instances and24/36quarters under actualroom/skywalkfloors; preserve shelteredvariation/crossings. Court frontageharness nowrecords overheadcoverage. Next fixbounded alternativecourtentrances/sites ratherthan morelatepockets. Evidence october5-court-holdout-review/result.md; allprocesses terminal; fullgoal active.


October5 bounded court entrance alternatives applied: preferred search keeps its original40k allowance; only failure tries at most20distinct entrances at1.5k each. Rejected equal splitting lost13. Final257 recovers9-column floor4 interior square on ninth entrance,50,788calls; focused4tests33assertions, native opposite views with334grass instances, courtyard walks4/4, skywalks10/10, gate2/2, floating/public-air0. Default gate walks were initially mislabeled as square checks; explicit --courts supplied the actual square evidence. Broad failed-court holdouts/performance still open; candidate remains provisional. Evidence october5-court-entrance-alternatives/result.md. All processes terminal; full redesign active.


October5 court alternatives holdouts:12new grand seeds build,8existing preferred sites preserved,29 gains9-column interior square,3still fall back. Sequential source-time total149.397→146.372s is noisy single-sample evidence, not a speedup claim. Finished29 has3inhabited sides,12/36quarters under rooms/skywalks,235grass instances, floating/public-air0 and4/4court/deck walks. Four native views reveal dominant market canopy as a remaining composition concern. Evidence october5-court-entrance-alternatives/holdouts and result.md; all jobs terminal. Full goal remains active.


October5 courtyard canopy proportion: planned islands admit a roofed stall only below one-third of their connected unreserved planting area. Measured full-size assets; other courts/public crossings cannot subsidize area. Seed29 now chooses leafy tree/seating,343grass instances; matched opposite native views improve visibility of bordering houses and preserve skywalk. Red-first4oversized selections; final5tests68assertions,4/4actual-player square/deck walks. Bounded change accepted; full redesign active. Evidence october5-court-canopy-proportion/result.md; all jobs terminal.


October5 partially blocked crown repacking:103 thin wing caused by rejecting an already-unroofable remainder during exact crown repartition. Preserve that old flat-area option while requiring the new full-width wing to fit. No new rooms or scaled shed assets. Red-first fixture;13tests122assertions; four-town204roof survey all measured defects0, including103 thin roof1→0. Matched front/side inspected, skywalk/source-bridge walks 6/6 pass. Bounded change accepted; full redesign active. Evidence october5-partial-crown-repacking/result.md. All jobs terminal.


October6 integrated checkpoint: production real-terrain gate124/125, timing8.062s>8s; repeated actual solves8.691/13.649/8.680s keep identical layout signature but do not meet performance acceptance. Fresh495-file isolated suite running under session31565, source/resource SHA256manifest recorded; keep production unchanged during run. Raw /tmp/oct6-full-isolated.txt and .logs. Evidence prefab-grammar/october6-integrated-checkpoint/result.md; full goal active.
