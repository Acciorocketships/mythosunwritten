# Warren Town Quality Remediation Plan

**Status:** active living plan  
**Last updated:** 2026-08-12  
**Branch:** `feat/mass-first-warren`  
**Reviewed production fixture:** world seed `6052724565602100358`, compact
profile, excavation attempt `8`, source candidate `5610100382`, partition
variant `6`

## Goal

Make production towns read as coherent hill settlements rather than stacks of
small modular boxes. The town must be planned from macroscopic, authored
building and feature shapes; use explicit geometry-aware joins; retain a
connected climbing public realm; contain frequent occupied outcroppings and
skywalks; and stream into the real game within a practical frame-time budget.

This document is the durable implementation and evidence ledger for the visual
review begun from `download-1.png`, `download.png`, `download-2.png`, and
`download-3.png`. Update it whenever a measured result changes the diagnosis,
an approach is rejected, or a task changes state.

## Review findings

### 1. The boxiness begins in source parcelization

The reviewed source partition originally contained 37 parcels, of which 28
were one-cell parcels. Later construction faithfully turned those into visible
3 x 3 m tower shells. Asset variation cannot repair a plan dominated by that
footprint.

Required architectural rule:

- plan complete authored macro footprints first;
- admit a tower only when no larger legal cover preserves its public threshold,
  bearing, public-air clearance, and roof neighborhood;
- never scale or stretch a mesh to cover an arbitrary remainder;
- record why every apparent macro cover was refused.

### 2. Broad/shallow street buildings were missing from the source grammar

The source parcel contract allowed only narrow/deep or square footprints. A
pair of adjacent street towers could form a visually useful 6 x 3 m rowhouse,
but the planning layer could not name that shape. A later merge then had to
choose between preserving two source identities and drawing one coherent
building.

The new `row` family is a first-class 2 x 1 macro parcel / 4 x 2 fine-grid room:

- one two-module broad facade;
- two authored doorway phases on the eave;
- a complete paired-gable or flat-service roof transaction;
- facade, portal, dormer, chimney, roof-garden, party-wall, and roof-seam
  vocabulary;
- exact room, visual-envelope, collision, bearing, and roof contracts.

### 3. A geometric adjacency is not automatically a legal merge

Two boxes whose union matches a larger footprint may still carry two distinct
doorways, a skywalk endpoint, a court boundary, different support ancestry, or
an unroofable transition. The macroscopic audit currently reports geometric
opportunities, not proof that they are semantically mergeable.

Every missed cover therefore needs one of these dispositions:

- `selected_macro`;
- `distinct_public_addresses`;
- `hero_socket_conflict`;
- `bearing_conflict`;
- `vertical_phase_conflict` (same plan-view union, different absolute floor
  planes; requires a stepped wall/roof seam rather than a rigid merge);
- `public_air_conflict`;
- `roof_transition_conflict`;
- `visual_envelope_conflict`;
- `competing_higher_value_cover`.

An undispositioned cover is a planning defect.

### 4. The apparent gaps and overlaps are construction-seam failures

The review images show contacts that are geometrically close but still render
as separate buildings. A legal contact must compile as exactly one typed seam:

- party wall;
- continuous ridge;
- parallel valley;
- perpendicular valley;
- stepped eave wall;
- stepped gable wall;
- occupied skywalk socket;
- supported outcrop socket;
- roofed lean-to/endcap;
- deliberately sealed terminal facade.

Coincidental mesh overlap is not a seam. A missing seam cannot be hidden with a
prop or a small filler plane.

### 5. Roof fallback is still visually expensive

The current reviewed result is structurally sealed, but many exposed rooms use
flat roofs or small setback caps after pitched roofs lose measured-clearance
tests. The annotated misplaced roof is a symptom of selecting roofs one room
at a time in a dense neighborhood.

Touching roof groups must be solved atomically. The solver must choose the
complete neighborhood arrangement—ridges, valleys, steps, terminal strips,
and flattening—before any member is committed.

### 6. Skywalk supply is below the visual target

The compact profile currently requires one occupied skywalk. That passes its
old structural gate but does not create the repeated overhead rhythm requested
in review. Skywalks should be topology-first campaigns that connect two real
inhabited sockets and preferably cover or turn a primary alley.

Provisional target ranges are compact 2, standard 3, large 4, grand 5. These
become hard production minima only after terrain and corpus supply is measured.

### 7. Runtime is improved but is not yet real-time

The exact-cover lookup formerly spent roughly 1.1 seconds brute-forcing origins.
Deriving the sole origin analytically reduced that pass to 1–2 ms. The complete
reviewed compiler-only spatial solve is still about 9.1 seconds, however. That
is acceptable for offline review and unacceptable as a synchronous in-game
load.

## Measured progress

All rows below use the exact reviewed fixture named at the top of this file.

| Measurement | Original reviewed plan | Row vocabulary only | Source row parcel | Source roof/plinth gates |
|---|---:|---:|---:|---:|
| Source parcels | 37 | 37 | 34 | 34 |
| Source one-cell parcels | 28 | 28 | 21 | 21 |
| Source two-cell parcels | 7 | 7 | 11 | 11 |
| Final tower storeys | 56 | 46 | 32 | 34 |
| Final row storeys | 0 | 13 | 20 | 18 |
| Final slim storeys | not retained | not retained | not retained | 14 |
| Final long storeys | not retained | not retained | not retained | 5 |
| Macroscopic private-volume ratio | 54.8% | 65.2% | 75.4% | 73.4% |
| Undispositioned geometric tower pairs | 10 | 5 | 0 | 0 |
| Typed refused geometric tower pairs | not audited | not audited | 2 | 2 |
| Served entrances | 32 | 32 | 31 of 31 | 31 of 31 |
| Unrelated visual-envelope overlaps | 0 | 0 | 0 | 0 |
| Unsupported room transitions | 0 | 0 | 0 | 0 |
| Composition time | not retained | ~6.7 s | ~4.25 s | ~10.09 s |
| Compiler-only spatial solve | ~12.6 s baseline | ~10.4 s | ~9.1 s | ~10.09 s |

The source-row result remains sealed and preserves:

- one connected exterior public route;
- 64 public-realm nodes and 63 graph edges;
- 14 of 14 aligned exterior stairs;
- 10 level-changing loops;
- zero public-air/occupied-volume overlaps;
- zero missing roof faces;
- zero unclassified public/private intervals;
- zero isolated or unsupported platforms.

Current weaknesses in that same result:

- the two remaining plan-view tower pairs sit on different absolute half-storey
  phases and are now dispositioned as `vertical_phase_conflict`; they are not
  legal rigid macro covers, but they still require authored stepped-eave or
  stepped-gable joins so the offset reads as intentional;
- only one enclosed skywalk is ultimately selected;
- all 3,134 unassigned massif cells are exterior-connected candidate shell,
  with zero enclosed room-sized residuals; however, four one-cell (1.5 m)
  interstitial gap cells remain in two components between occupied walls and
  must be consumed by a typed seam/endcap or opened into deliberate space;
- 19 flat roof closures and 40 setback caps still dominate parts of the
  roofline;
- the latest 10.09-second compiler-only solve is too slow for synchronous
  gameplay. The stricter source preflights are correct but currently erase
  some of the earlier speed and macro-volume gain; the bounded source beam must
  recover quality without weakening those gates.

## Current implementation slice

The active slice is compiled-transaction-aware hero-feature selection,
followed by the typed
`interstitial_join` / stepped-roof transaction. The ordering changed after the
wider production checkpoint proved that the current skywalk objective rewards
link count and generic public-air cover, but does not reward distinct portions
of the primary itinerary. A first exact-route implementation then exposed a
second-order cost: a bridge can move an endpoint room block and uncover more
route than its own occupied span covers. A visually improved pinned seed must
not conceal a town-generation regression, so the large-profile production
topology must first seal at its existing 38% inhabited-overhead floor.

The hero-feature beam change must:

1. derive the canonical public-route walk cells from the sealed public realm;
2. map every candidate's occupied body to the exact route cells it covers at
   the same 2--6 fine-band range used by the final quality audit;
3. retain raw unique and marginal bridge coverage as diagnostics, not as a
   selection proxy;
4. evaluate a bounded, diverse set of endpoint-compatible combinations through
   the exact room composition and measured recipe transaction already used by
   the court/landmark/skywalk preflight;
5. rank only those sealed transactions by the final recipe occluder coverage
   used by `SettlementFabricSolver._audit_enclosure`, including all displaced
   or recomposed endpoint rooms;
6. retain support risk, tower risk, landmark coverage, endpoint-room
   preservation, and deterministic tie-breaking as hard or secondary terms;
7. report selected unique/marginal bridge coverage and exact final
   denominator/numerator in the diagnostic audit;
8. prove that adding a fourth link actually raises distinct inhabited route
   coverage, or reject that link as visually redundant.

Once that checkpoint seals, the join transaction targets the two repeatable
2 x 1 x 1 half-storey slots in the reviewed fixture:

- `(0, 4, 5)`--`(1, 4, 5)`, between two tower lineages;
- `(-8, 5, -2)`--`(-7, 5, -2)`, between two row lineages.

Both slots are one fine cell deep (1.5 m), two cells wide (3 m), and lie
between occupied walls on opposing horizontal sides whose floor phases differ.
The layer probe proves that these are shoulder/junction conditions, not missing
full rooms: the first slot is immediately above inhabited mass and both slots
touch the overlapping half-storey of a lower neighbor. They must not be
repaired by moving a source parcel or stamping an arbitrary filler plane. The
intended transaction is:

1. discover the final slot after required market, landmark, skywalk,
   cantilever-support, annex, and balcony reservations;
2. bind the slot to its exact two room owners and record the higher/lower floor
   phase;
3. classify the obligation as a stepped shoulder roof, sealed terminal endcap,
   or (only when two complete vertical bands and bearing are available) an
   occupied shallow bay;
4. admit only a complete measured recipe whose socket/contact, roof/cap,
   facade closure, support, and visual envelope all fit atomically;
5. emit an `interstitial_join` reservation and construction record, with the
   owner-to-owner relationship carried into the compiler;
6. reject the town if any sub-tolerance slot remains unresolved, rather than
   silently exposing two unrelated facade meshes.

The existing setback lean-to and roof-seam vocabulary is the preferred source
for the shoulder case. The capped-outcrop vocabulary may be reused only when
its complete 2 x 2 x 1 occupied volume, authored socket, support, and measured
envelope fit; the one-band slit alone is never permission to insert a room.
A new purpose-built stepped endcap recipe is required when neither vocabulary
matches. This pass runs before optional facade bays, so decorative relief
cannot consume a required join, but after all topology-critical feature
campaigns so a join cannot steal a skywalk, entrance, market, or structural
support reservation.

Evidence required before this slice is marked complete:

- focused unit fixtures for a valid half-storey join and the important refusal
  cases (same-owner opening, public-air conflict, missing bearing, visual
  collision, unsupported opposite edge);
- reviewed fixture reports zero one-cell interstitial gap cells/components;
- every new construction record compiles through the measured visual-overlap
  gate with zero unrelated overlap and no lost entrance;
- low-street and underside captures show an intentional roofed/stepped join,
  not a thin patch hiding the opening.

The transaction is now implemented and measured. Two corrections to the
earlier diagnosis first: the fixture's gap census had evolved under the
checkpointed source gates — the current sealed plan exposed seven one-cell
gap cells in three components, not four cells in two. The layer probe showed
three distinct conditions: the (0,4,5)-(1,4,5) two-cell stepped shoulder; a
four-cell complex around (-3,5..6,-1..0)/(-3,6,-2) containing a two-band slit
capped by parcel 0030's bridging storey; and a floating one-cell notch at
(-4,5,4) with open air below.

`WarrenSpatialFeatureSolver._reserve_interstitial_joins` runs after every
required feature reservation and before optional facade bays. It re-runs the
audit's own trap predicate, groups gap cells into straight single-band runs
(bands resolve bottom-up so stacked slits rest on the strip sealed beneath
them), takes the longest classifiable prefix of each run, and commits exactly
one typed construction per authored chunk: `stepped_shoulder` (2/4/6-cell
lean-to from the existing `roof.setback.lean` vocabulary, ridge on the single
continuing upper wall, bearing bond into the room below's exact top socket)
or `sealed_infill` (new measured `interstitial.seal.1/2.capped|buried`
recipes; capped strips take a flush deck cap, buried strips carry timber
blocking and omit the cap so no plate fights the bridging soffit above).
A shoulder may not bear on an earlier strip — only real room mass with
authored top sockets. Any unclassifiable slot rejects the town with a
reason-coded refusal. Strips claim PRIVATE_VOLUME under the feature id with
typed PARTY_WALL/ROOF/SOFFIT/FACADE face claims (prior claims from adjacent
strips stay authoritative), so shell derivation, facade suppression, and the
final `one_cell_interstitial_gap` audit all see deliberate built mass.

The compiler realizes each reservation as one bonded unit
(`_compile_interstitial_join_feature`): touching rooms — including the
diagonal upper wall a shoulder seals against and the bridging cover storey —
are explicit visual seams; the wall/cover/bearing/upper owner set plus the
wedged parcels' whole lineages satisfy the room envelope gate's relatedness
rule; and interstitial strips join the support-course seam pool so a later
bracket frame measuring into one declares the same typed timber joint it
would declare against an earlier brace.

Evidence: seven focused fixtures pass (100 assertions) covering the valid
shoulder, the two-sided slit, the buried strip, the shoulder-over-strip
refusal, the no-closure typed refusal, chunking, and the sealed recipes. The
reviewed fixture seals end-to-end with `one_cell_interstitial_gap_cell_count
= 0`, five `interstitial_join` features (one lean-to shoulder, four sealed
strips), 31 of 31 served entrances, and unchanged 40.8% overhead. Sealed
infill placements are deliberately minimal (flush cap or base blocking; the
flanking party walls are the reveal surfaces) — capture review judges whether
the reveals need richer authored boarding.

## Village-scale recalibration (2026-08-14, in flight)

Review feedback: the radius-12 large town reads as a metropolis; a standard
town should be roughly one fifth of it, and two other directives follow —
compose the roofs properly (many read as one floating half-slope) and make
towns performant enough to work in-game. All three pull the same way:
smaller towns are the largest single performance lever.

Profiles are resized (radii 7/8/9/11, room budgets 10-30/16-60/25-70/40-110,
quotas scaled; core heights nearly unchanged so the hill stays vertical) and
the metropolis-tuned absolute gates are being recalibrated one measured
failure at a time, each with its own scan evidence:

- the topology route floor now enforces the selected profile's own
  `route_cell_range.x` (quality ratios untouched);
- the covered bazaar is a city obligation — villages take one exactly when
  the measured canopy/aisle/backing fits, through an `optional_absent`
  market sentinel that mirrors the optional court, normalized after the
  hero beam;
- standard landmarks are `(0, 1)` take-when-it-fits, with the hall-less set
  appended as the last-ranked fallback;
- upper-route crossovers scale with the massif's column count (villages 1,
  grand mounds 2);
- the skywalk beam requests the profile's richer count but accepts its
  declared minimum, including a single-link fallback in the pair path;
- `MIN_BUILDINGS` 10 -> 6; balcony floors compact 0 / standard 1.

State at the end of this session: the radius-8 mountains naturally yield
47-58 rooms, so the standard ceiling sits at 60; standard seeds compile
complete villages and fail only late quality-bearing gates — per-seed
variance now, not a shared constant: seed 1 hits the through-sightline cap
(71 vs 48) and the 33% overhead floor (29.5%); seed 9 hits a genuine
room-envelope collision its variant search could not route around; seed 8
still starves on arcade crossovers; seeds 5/6 die in composition support
and envelope tails — seed 1's best variants report
71 through sightlines against the absolute 48 cap and 29.5% overhead
against the unchanged 33% floor. Both bars are quality-bearing; do not
lower them blindly. The open calibration questions are whether the
through-sightline cap should scale with declared route budget (it is an
absolute count tuned on 284-cell metropolis routes) and whether village
overhead needs the single-flank jetty increment to clear 33% the same way
variant 5 needed it for 38%. The pinned compact/variant-5 fixtures predate
the resize and are superseded; new pinned fixtures must be chosen from the
first sealing village seeds.

## Village fixture and measured performance (2026-08-14)

New pinned village review fixture: world seed 1, standard profile, attempt
6, candidate token 6000019, partition variant 0. It compiles and seals
end-to-end (production still rejects it on the 33% overhead floor at 29.5%,
the known jetty-increment gap) and renders through the review battery. Its
kind mix is tower 14 / slim 12 / row 7 / long 2 / building 2 at 80.6% macro
ratio with zero unexploited exact pairs — further de-boxing must come from
the still-open source exact-cover beam (prefer building/long kinds at
serving time), not from post-hoc merging. Roof mix: 30 setback caps, 5
lean-tos, 3 gardens; at this scale the flat areas read as awning terraces.

Measured cold spatial solve for the complete village: **5.9 s** single
variant (the pre-resize large city measured 116 s), of which composition is
about 1.3 s. The feature solver now searches to the top of each declared
balcony/cantilever range while gating at its floor: this fixture keeps 13
room outcroppings and 3 balconies through every gate.

Optimization plan beyond the rescale, in measured-leverage order:

1. **Off-thread planning with frame-budgeted commit** — the in-game
   architecture: solve massif->fabric on the worker (no RenderingServer
   calls), commit collision and near-field silhouettes first, then visual
   batches under an elapsed-time budget (existing Phase G items; a ~6 s
   background solve is already streamable if the main thread never blocks).
2. **Persistent source caching by stable signature** — massif, excavation,
   topology gate, and parcel-candidate results are pure functions of
   (seed, attempt, profile); the staged production search currently
   recomputes them cold every run.
3. **Preflight sharing across palette-equivalent variants** and the
   already-memoized exact-room failures extended to positive results.
4. Micro hot spots when the above land: the residual backfill's full-grid
   candidate rescans per placement, linear recipe socket lookups, and
   per-block composition offset solves.

## Visual state (2026-08-13)

The joined fixture renders to `/tmp/mythos-town-joins-after2` through
`warren_spatial_review.tscn`, which now includes `interstitial-join-*`
reveal cameras (the naive `-b` reverse angles sometimes sit inside neighbor
mass and need the occlusion-aware placement the outcrop battery uses). The
join reveals read as deliberate planked ledges and sealed courses; no open
sliver remains. The roof mix is essentially unchanged by the joins
(10 pitched, 18 flat, 44 setback caps, 12 lean-tos), so the flat/setback
dominance of Phase E remains the largest outstanding visual lever.

## Visual baseline (2026-08-12)

The exact fixture was rendered through `warren_spatial_review.tscn` into
`/tmp/mythos-town-quality-current`. Its `index.json` records every camera and
the complete spatial/fabric audit. The images are diagnostic evidence, not a
passing review set: all capture dispositions remain `UNREVIEWED` until each
full-resolution image is inspected.

Measured construction in this baseline is 88 roof units: 10 pitched roofs, 19
flat closures, 40 setback caps, 10 lean-tos, and zero complete shoulder macro
gables. There is one enclosed skywalk and one optional facade bay. Overview
captures show a material improvement from the broad rowhouse vocabulary, but
the centre/lower town still reads as many capped boxes; the roof-campaign view
also exposes a misplaced steep roof and unfinished-looking cap joins. The
skywalk underside view is useful evidence for the join phase because the span
exists but its neighboring wall/eave contacts still read as independent
modules.

## Checkpoint validation findings (2026-08-12)

The first full-file structural checks deliberately blocked a commit of the row
parcel slice. The exact reviewed fixture remained sealed, but wider
deterministic fixtures exposed admission rules that had to move into source
selection:

- `test_settlement_fabric.gd`: the initial 34/35 result was a stale expectation,
  not a geometry defect. The new 6 x 3 m row already includes the same measured
  vertical stone core as the narrow/deep slim family; the contract test now
  recognizes `row` as a narrow-axis lived-in terrace. The compiler's measured
  envelope gate remains authoritative.
- `test_warren_solid_partitioner.gd`: the initial run passed 20/25. Seeds 1 and
  3 exposed a false source assumption that a parcel ridge always follows its
  frontage. Broad/shallow `row` parcels actually turn the ridge ninety degrees;
  source compatibility now derives the ridge from the rotated footprint and
  the focused real-roof compilation fixture passes (1 test, 169 assertions).
- Seed 5 exposed corner-only contact as an omitted source objective. Variant
  selection now counts corner-only pairs, minimizes the excess after roof
  conflicts, and only early-exits when both are zero. The focused corpus
  fixture passes (1 test, 7 assertions).
- The first plinth repair incorrectly treated an addressed route plane as the
  bottom of every fully borne building, which removed eight mandatory wall
  owners from the exact fixture. The corrected rule checks full-footprint
  terrain relief for every parcel and limits base lift only for mixed-span
  parcels. The three focused plinth/bearing fixtures now pass (3 tests, 1,772
  assertions total).
- The first full `test_settlement_fabric.gd` run passed 34/35. The sole failure
  was a stale expectation that only `slim` terraces receive the measured stone
  core/chimney recipe. The first-class `row` contract deliberately shares that
  recipe; the focused terrace fixture now passes (1 test, 292 assertions).

These are generator defects, not thresholds to loosen. The exact-cover beam
must carry roof-module compatibility, corner-contact cost, and the minimum
terrain height under the complete rotated footprint before it can select a row
parcel. The roof compiler remains the final authority and should never be made
to accept a partial perpendicular valley merely because the source partition
claimed it was joinable.

The focused blockers are green, but the full partition and settlement files
were then rerun. `test_settlement_fabric.gd` passes 35/35 (13,373
assertions). `test_warren_solid_partitioner.gd` initially passed 24/25: its one
remaining test independently inferred ridge direction from an unsealed
parcel's unset `width_cells`/`depth_cells`, so valid broad/shallow rows were
misclassified as perpendicular valleys. The independent audit now derives
width and depth directly from the raw footprint, and its focused rerun passes
(1 test, 6 assertions). The final full rerun passes 25/25 (17,838 assertions).
The expensive spatial-compiler file still passes 9/10. Its focused
production-frontier fixture failed after 409.27 seconds because no staged
frontier sealed. Four source variants reached fixed-asset preflight but exposed
a partial equal-height ridge contact: the finite roof table correctly refused
to stretch a narrow ridge module across unequal gable widths. Other variants
failed later composition, skywalk, or third-storey-court gates. Mass-first
fixed-asset styling now handles that exact source condition with the same
atomic policy as spatial roof neighborhoods: both complete touching roofs use
their authored flat-service closures, or the candidate is rejected. A focused
partial-ridge fixture passes (1 test, 8 assertions); production seed 7 still
needs a complete rerun. That production-only rerun completed in 459.58 seconds
and still rejected the seed, but the former `continuous ridge ... is not
full-width` failure no longer appears in the retained diagnostic. The roof
blocker is fixed; another attempt-10 frontier gate is now authoritative and is
being isolated directly. The cold runtime remains categorically unsuitable for
synchronous game loading even after correctness is restored.

Attempt 10 was isolated in 350.45 seconds. Its roof preflight succeeds; its
surviving source variants now reject during room composition because each
retains one unsupported merged macro room before hero-feature search. Variant
0 produces an unsupported `building` at `(-1, 4, -1)` in lineage
`parcel.solid.0011`; variant 3 produces an unsupported `long` at `(5, 5, 0)` in
lineage `parcel.solid.0030`. In both cases the proposed macro footprint contains
some borne columns but leaves a substantial unborne set after support repair.
The correct next fix is therefore in macro selection/support ancestry: a merge
must prove its complete bearing transaction, inherit an exact supporting room,
choose a supported alternative, or receive a typed `bearing_conflict`
disposition. The compiler must not promote missing geometry into support, and
feature gates must not be weakened merely to make seed 7 pass.
That diagnosis is now closed at the source. Macro merges re-prove complete
bearing against the current room graph immediately before commit, rather than
an immutable pre-merge snapshot, and the candidate beam is ordered from low to
high absolute floor band so an upper merge cannot be accepted before a later
transaction removes its parent. The focused ancestry fixture passes (1 test,
3 assertions). Both isolated attempt-10 source variants now advance past the
support audit in about 13.8 seconds.

The next production blocker was the elevated-court preflight. The best court
bridge candidate touched exactly two fine cells of its own endpoint parcel
after that parcel was macro-composed; the old zero-conflict gate rejected it
before skywalk search. This is now an explicit owner-socket transaction: at
most two fine cells (one 3 m by 1.5 m attachment strip) may be recomposed, only
when every conflicting macro cell belongs to the candidate's named endpoint.
Any unrelated owner or larger self-cut remains a hard rejection. The focused
classification/ranking fixture passes (1 test, 11 assertions). The isolated
probe confirms the candidate has two owner-socket cells and zero unrelated
conflicts, then produces 367 raw / 353 viable skywalk candidates and selects
the required three. Its joint exact room/court/landmark/skywalk solve succeeds.

The surviving seed-7 frontier next reached final measured asset compilation in
about 104.2 seconds and exposed a preflight/finalization mismatch. Portal-aware
room recipes were first mirrored into the preflight and pinned by a focused
fixture (1 test, 7 assertions), but a structured final failure audit proved the
actual colliding rooms had no typed contact face and were not a shallow edge
nick. The final collision gate was correct. The early room-pair pass had
already dispositioned two complete optional parcels (`0004` and `0056`), but a
repeated exact pass rebuilt them, observed the same exclusion list, and then
incorrectly reused that stale composition. Repeated exact passes now begin
with prior exclusions absent, preserve the reason class, and final composition
honors the same set. The isolated trace proves 143 rather than 148 room probes,
zero displaced lineages in the selected 48-lineage composition, and successful
spatial plus measured-fabric gates.

Variant 0 is now structurally sealed: spatial planning completes in 102.88 s
and fabric compilation in 19.13 s. It is still correctly rejected by the
production visual-quality gate because only 28.5% of 108 public route cells
have inhabited/connected overhead coverage, below the large-profile 38% floor.
It contains nine compiled skywalk links, four covered-market aisle cells, and
eight residual backfill buildings, but those features do not compensate for
the uncovered main itinerary. The threshold must not be lowered. The next
checkpoint is to measure the remaining attempt-10 partition frontier and pick
or improve a topology with sufficient inhabited overhead before returning to
the reviewed interstitial joins.

That frontier measurement is complete. The deterministic source order was
variants `0, 3, 6, 1, 4, 7, 2, 5`:

| Variant | Deepest result | Disposition |
|---:|---|---|
| 0 | Spatial + fabric sealed; 28.5% overhead | Below the unchanged 38% large-profile floor |
| 3 | Court macro preflight | Best bridge requires 4 own-socket cells; bounded contract permits 2 |
| 6 | Court macro preflight | Best bridge requires more than the bounded own-socket strip |
| 1 | Exact composition | Arbitrary 12-cell shoulder has no complete authored closure |
| 4 | Exact composition | Alternate court choice leaves unsupported forced slim/long transitions |
| 7 | Court macro preflight | Best bridge exceeds the owner-socket recomposition budget |
| 2 | Court macro preflight | Best bridge exceeds the owner-socket recomposition budget |
| 5 | Spatial + fabric sealed; 33.4507% overhead | Best sealed frontier survivor, still below 38% |

Variant 5 has 108 public route cells, five residual buildings, four covered
market aisle cells, and seven reported compiled skywalk link records. It is the
current production optimization fixture because it is structurally sound and
closest to the visual-quality floor.

As a measured experiment, large and grand profiles now request four occupied
skywalks and the ranked triple beam has a bounded deterministic quadruple
extension (384 triples, 24 extensions per triple, 6,144 retained quadruples).
Variant 5 selected four compatible links and sealed again (116.422 s spatial,
22.924 s fabric), increasing the reported compiled link records from seven to
ten. Its final overhead ratio nevertheless remained exactly 33.4507%.
Therefore raw skywalk count is not the missing objective: the fourth selection
covered route columns already credited by existing mass, or covered generic
public air that is not part of the canonical itinerary. The next change is the
unique-route-coverage objective specified in the current implementation slice;
the 38% threshold will not be lowered.

The first canonical-route implementation measured bridge bodies at the same
2--6-band window as the final enclosure audit. It selected 24 unique route
cells, 16 of them outside the macro-composed baseline, and swapped the
`0012--0014` link for `0012--0016`. The complete variant still sealed, but its
final overhead fell from 33.4507% to 33.0986%. This falsifies bridge-body-only
ranking: forcing the new link moved endpoint room blocks that had covered more
route than the connector gained. A first attempted correction projected the
entire cheap source transaction—original endpoint block removal, forced block
placement, and connector body—before the expensive exact composition proof.
The final audit will also expose its exact route denominator and overhead-cell
numerator; the former `108 public route cells` trace used a broader public-realm
count and was not the denominator of `overhead_route_ratio`.

The first whole-transaction projection still chose the same regressing link
set and predicted only 32 covered cells, while final fabric measured 94 of 284.
A second projection indexed baseline route cells by their sealed macro
`lineage/source_offset_block` owners and predicted 112, but final fabric again
measured 94. It also expanded the viable triple frontier from 10,483 to 12,401
and slowed the quadruple pass. Both semantic-volume projections are rejected
and have been removed from selection. The pre-experiment deterministic order
is retained while exact route diagnostics remain available. The next selector
must compare the complete composed recipe occluders inside the existing bounded
exact feature transaction; the final fabric audit remains authoritative.

That selector is now implemented and measured. The exact court preflight's
room-probe construction (real compile-time stamps, portal-mask-aware measured
recipes) was extracted into `_exact_composition_room_probes` and shared with a
new `_sealed_recipe_occluder_route_coverage` objective that reproduces the
final audit's occupied-overhead test on the sealed preflight composition.
`_skywalk_plan_for_landmarks` keeps its original unbounded first-survivor
primary scan (the variant-5 survivor ranks 281st; an early bounded-scan draft
would have rejected the town) and stashes a deferred alternate search. Only
after a landmark set's primary exact preflight seals does the transaction
lazily prove up to two diverse alternates (two-plus differing links, scan
resumed after the primary's rank because every earlier combination already
failed endpoint preservation) plus one reduced triple, run each through the
same memoized exact preflight, and choose the highest composed-occluder
coverage with deterministic ties. An eager draft that proved alternates for
every landmark permutation stalled the fixture beyond seven minutes and was
replaced; the lazy form costs nothing measurable (116.2 s spatial, equal to
baseline).

Measured verdict on the variant-5 fixture: the primary four-link plan and the
sealed three-link alternative both project exactly 85 of 280 covered route
cells, and no diverse four-link alternate survives endpoint preservation even
past rank 281. The fourth link therefore adds zero distinct inhabited route
coverage (`occluder_rank_fourth_link_redundant` is now an exact recorded
fact), and the final overhead remains 33.45% under either choice. Equal-
coverage extra links are deliberately kept rather than dropped: acceptance
gate 11 values repeated overhead episodes, so redundancy is now a measured
diagnostic for visual review, not an automatic rejection. Large/grand
profiles request four links (`skywalk_range` is now `(3, 4)` with the
production contract accepting the range), and the 38% floor is unchanged.

The decisive conclusion: on this topology, skywalk choice cannot close the
33.45% to 38% gap. The largest uncovered route component is an 18-cell ground
street beside the selected market; covering it requires overhanging inhabited
mass or an arcaded gallery from source parcelization (Phase B), not another
bridge. The hero-feature selection slice is complete; the active slice moves
to the typed `interstitial_join` transaction, and the overhead deficit
returns to the source-decomposition beam where the mass actually is.

## Street-spanning mass measurement (2026-08-13)

A pre-discard supply audit (`route_overhead_supply_*` in the spatial audit)
now classifies every canonical route cell lacking occupied overhead in the
2--6 band window: does trimmed massif supply sit above it (a claimable
partition failure) or genuinely empty sky (a massing failure)? On the sealed
variant-5 fixture the answer is emphatic: of 280 sampled route cells, 96 are
covered, **172 uncovered cells have authored massif mass directly above them
in the credit window**, and only 12 (all high upper-walk cells) truly lack
mass. The Gaussian mountain and the excavation carver already author the
tunnels and underpasses the review asks for; the solid partitioner cannot
represent a parcel whose columns stand wholly over a carved street (no
terrain bearing, no plan-view support-parent overlap), so
`_discard_unassigned_mass` erases the authored cover and the street opens to
the sky. Reaching the 38% floor needs roughly eleven more covered cells;
claiming even a tenth of the measured supply clears it.

The next slice is therefore **bridge parcels in `WarrenSolidPartitioner`**:
recognize over-street solid components and admit them as first-class parcels
with an explicit two-ended bearing contract (flanking parcels at both run
ends, the same two-parent shape the skywalk recipes already declare), plus
jetty rows that keep partial plan-view overlap with one parent and consume
the existing outcrop bracket vocabulary for the overhung remainder. Bearing
ancestry must ride the existing macro-merge proof, the support DAG, and the
finite roof-junction table; nothing may be stretched or inferred from a
doorway cell. The carver's tunnel supply is the input, not new massing.

Reading the partitioner narrowed the mechanics, and a measured first attempt
falsified the cheapest form. The pipeline already contains over-street
contracts in several places: `WarrenBuildingParcel.seal` derives
`support_mode = mixed_span` and `has_occupied_overpass` generically and
enforces the at-least-half continuous-bearing rule;
`WarrenParcelConstruction.perimeter_gateway_support` realizes the frontier
gateway motif; `WarrenSolidPartitioner._can_carry_courtyard_span` admits
interior span candidates over a lower passage; and the carver records the
per-cell tunnel fact in `excavation.covered`. Widening the span-admission
gate from courtyard cells to every covered street cell was, however, a
measured no-op (variant 5 identical to the cell: 96 covered, 172 supply,
131.3 s): a street-level candidate anchors its envelope at the walk's own
band, inside the carved slot, and `_top_band`'s truncation-at-first-carve
clips it to zero height. Court spans only work because the court walk sits
above its passage. The change was reverted.

The real gates, mapped precisely: `_can_carry_house` (rejects any column
with a carved band, so tunnel columns never become wall candidates),
`_top_band:~1319` (clips every envelope at the first carved band),
`WarrenBuildingParcel.seal:~100` (every extruded cell must be source mass —
a parcel cannot contain the street slot), and residual backfill's support
rule: `_residual_room_candidate` requires half the footprint to stand
directly on building mass below, and a tunnel-top room by definition has
void below. The backfill pass is otherwise already the designed consumer —
it indexes every uncovered route floor by its potential ceiling cells and
scores street-spanning rooms far above peripheral ones
(`RESIDUAL_OVERHEAD_ROUTE_CELL_SCORE`); it starves only because no bearing
form exists for rooms whose support is the two flanking walls they span
between.

Next-session implementation, in preference order:

1. **Bridge bearing for residual rooms**: admit a residual candidate with
   zero below-support when its side contacts include two distinct
   established owners on opposing sides along the span axis (two or more
   contact cells each), and realize its support as a two-sided wall bond —
   the `bearing_parent_count = 2` side-socket form the skywalk recipes
   already compile — plus the existing bracketed course where only one wall
   exists. This consumes the indexed tunnel supply directly, post
   composition, without touching the partitioner.
2. **Support-parent span parcels**: generalize
   `_fill_courtyard_upper_walls` (currently court-gated) so a covered
   street's tunnel mass becomes an upper parcel seated on a flanking parcel
   with the existing overlap rule, entering ordinary composition.
3. Only if supply remains: interior gateway rows via
   `perimeter_gateway_support` minus the envelope-boundary gate.

Option 1 is now implemented and measured: **variant 5 rose from 33.45% to
37.68% inhabited overhead** — the first movement of that number in the
entire remediation — and both fixtures seal with every focused test green.
The mechanism: `room.bridge.tower.*` and `room.bridge.slim.*` recipes
(ordinary unaddressed shells, `bearing_parent_count = 2`, span sockets on
every boundary cell of both storey bands so half-storey-staggered flanks
bind), a `_residual_bridge_span` admission proof that runs the flanks' real
measured recipes so the strict compile-time `_sockets_meet` bond can never
disagree with admission, bridge-aware compile ordering (a bridge sorts one
band late so staggered flanks build first), and telemetry
(`residual_backfill_bridge_counts`). Iteration falsified three cheaper
forms first: opposing-only pairs bind zero towns (half-storey stagger),
single-band span sockets bind one side only, and the residual roof halo
must be waived for nestled bridges (their roofs are party-wall caps under
the roof phase's own gates). Corner pairs, residual flanks, and
same-building two-room arches are admitted; bridge-on-bridge is not.

The remaining 0.9 points to the 38% floor are exactly the open-market-side
street cells, where only one flank exists: the **single-flank jetty** —
one span bond plus a measured bracket course on the outer edge (the
`perimeter_gateway_support` two-bracket motif, interior) — is the specified
next increment and would close the floor.

Generalizing the join transaction to this dense fixture also hardened it:

- air exclusively reserved by a composed feature, or flanked by a feature's
  own authored wall (landmark silhouettes, bridge houses, earlier strips),
  is typed `feature_clearance_gap_cell_count` — owned void, never a join
  obligation and never a defect;
- any remaining trapped course seals: stepped shoulders keep their strict
  contract, and everything else — including flush parapet slots between two
  walltop rows — becomes side- or below-anchored sealed infill;
- a strip's support node must be a terrain-reaching building, never another
  strip;
- relatedness at the room envelope gate is physical: touching rooms
  (including vertical diagonals), wedged lineages, and named owners; and
  interstitial strips are exempt from room displacement entirely because
  they occupy proven-vacant trapped cells — grazing eaves, sibling strips,
  and crossing features instead declare typed joints through the shared
  structural-course seam pool.

With those rules variant 5 seals end-to-end with 47 typed joins, zero
one-cell gap cells, 32 typed feature-clearance gap cells, and unchanged
33.45% overhead; the compact reviewed fixture seals identically with four
joins (its fifth former slot proved to be feature-reserved air).

The latest exact fixture is sealed with 31 of 31 served entrances, 74 buildings,
zero unresolved exact macro covers, and two typed
`vertical_phase_conflict` refusals. Its roof mix is 10 pitched roofs, 19 flat
closures, 40 setback caps, 12 lean-tos, and one shoulder macro gable.

## Rejected approaches

### Post-hoc visual merging

Rejected. Merging meshes after room compilation cannot reason about public
thresholds, support parents, hero sockets, or roofs. It can make a screenshot
look quieter while corrupting topology.

### Late exact tower cleanup

Rejected after implementation and measurement. A prototype merged exact pairs
after upper-room variation and reduced the reviewed town from 32 entrances to
30. The geometry was legal in isolation, but source address identities had
already become lineage facts. The prototype was removed. Equivalent choices
must happen in source parcelization or in a joint multi-address composition
transaction.

### Brute-force exact stamp search

Replaced. Iterating every origin for every footprint produced identical output
but cost about 1.1 seconds. Rectangular bounds now identify compatible kinds,
orientations, and their single possible origin analytically.

### Semantic-volume overhead ranking

Rejected after two measured production runs. Bridge-body union selected 24
route cells yet reduced final overhead by one cell. Raw source-prism projection
predicted 32; macro-owner projection predicted 112; both produced the same
94/284 final result, and the latter made the frontier slower. PRIVATE_VOLUME is
not the final occluder transaction: feature portal variants, room
recomposition, complete parcel displacement, roof/floor recipes, and structural
surfaces change what the final audit sees. These proxies remain useful only as
diagnostics and must not order production candidates.

## Implementation plan

### Phase A — measurable review fixtures

- [x] Pin the exact reviewed production fixture and variant.
- [x] Add final macroscopic-shape measurements: kind counts, macro-volume
  ratio, exposed towers, and missed exact covers.
- [x] Add deterministic review-camera support to the harness.
- [x] Add a concise machine-readable summary artifact beside every image set.
- [x] Add low-street, underside, roofline, and top-down cameras that directly
  correspond to the annotated failure classes.

### Phase B — source-level macroscopic decomposition

- [x] Author and compile the complete 6 x 3 m broad-frontage `row` family.
- [x] Admit `row` as a real source parcel rather than only a later room choice.
- [x] Prefer it ahead of the one-cell fallback in mass-first partitioning.
- [x] Add reason-coded disposition for every final exact macro cover.
- [x] Eliminate the final `unresolved` cover: the reviewed fixture now reports
  zero unresolved covers and two `vertical_phase_conflict` obligations.
- [ ] Replace greedy within-band face service with a bounded exact-cover beam:
  maximize mandatory wall coverage, then authored macro area, then addresses,
  then roof compatibility; minimize towers, residual components, and repeated
  identical rows.
- [x] Carry complete bearing ancestry into macro-room merge selection; refuse
  the seed-7 attempt-10 `building`/`long` merges above before they can survive
  into the unsupported-transition audit.
- [x] Reject a source cover whose complete rotated footprint exceeds the local
  plinth budget; do not infer bearing from only its doorway or anchor cell.
- [x] Include finite roof-junction compatibility and corner-only adjacency cost
  in the source-cover score/gate, as pinned by partition seeds 1, 3, and 5.
- [ ] Carry selected scale-profile room budgets into the beam instead of
  repairing excess micro-parcels later.
- [ ] Run the production corpus and set scale-specific macro-volume floors from
  observed viable supply.

### Phase C — typed residual mass

- [x] Split unassigned massif cells by connected component and distinguish
  exterior-connected source shell from enclosed residuals.
- [x] Audit exact one-cell interstitial slits independently of the surrounding
  exterior-connected source component.
- [ ] Classify each component as structural bearing, daylight void, public-air
  reservation, complete room infill, complete market envelope, authored
  lean-to/endcap, or discardable exterior trim.
- [x] Prove the reviewed fixture has zero enclosed room-sized residuals; its
  former 3,128-cell "room-sized trim" was the exterior source shell, not one
  hidden buildable room component.
- [ ] Reject any enclosed room-sized component that remains merely `trimmed`
  across the corpus.
- [ ] Reject isolated one- or two-cell facade slivers unless an authored
  terminal strip consumes them.
- [x] Consume the reviewed fixture's exact half-storey slots with a typed
  `interstitial_join`, or reject the plan with a reason-coded refusal. The
  fixture's census had grown to seven cells in three components; all consume
  as one stepped shoulder plus four sealed strips, and unclassifiable slots
  reject the town.
- [ ] Report retained and discarded volume separately; a huge discarded source
  shell must not hide a visible planning hole.

### Phase D — geometry-aware building joins

- [ ] Seal a `FabricBuildingJunctionPlan` from final room geometry before asset
  assembly.
- [ ] Give every lateral contact exactly one typed seam or one explicit air gap
  wider than the visual-envelope tolerance.
- [ ] Suppress duplicate wall/beam modules only through a party-wall seam.
- [ ] Compile stepped wall closures and terminal endcaps from authored pieces.
- [x] Make `interstitial_join` an atomic two-owner construction contract; it
  must reserve its complete shallow volume and roof/cap before optional facade
  decoration runs.
- [ ] Add audits for small gaps, coplanar duplicate faces, protruding beams,
  unsupported eaves, and seam assets whose semantic owners do not match.

### Phase E — atomic roof neighborhoods

Kickoff findings (2026-08-14): the cross-room neighborhood machinery already
exists and works — `WarrenSpatialFabricCompiler._spatial_roof_neighborhood`
classifies full-plate rooms through `FabricRoofTopologyPlan` and the
junction module table, flattens whole incompatible campaigns together, and
reports `roof_neighborhood_join_count`. The reason caps still dominate
(44 setback caps vs 10 pitched on the compact fixture) is its entry gate:
`_is_full_roof_plate` excludes every PARTIAL plate, and half-storey-staggered
compositions make most exposed plates partial, so exactly the shoulders that
form the boxy roofscape bypass the neighborhood solve and fall to per-room
cap partitioning. The redesign is therefore: classify partial plates into
the same neighborhood transaction (junction phases for half-storey steps
already exist as STEPPED_EAVE/GABLE_WALL kinds), and only then let
`_cap_pieces` consume what remains. A first bounded improvement is in place:
`_cap_pieces` may now place up to three non-touching macro crowns per
shoulder (a clear strip cell between crowns, so no untyped valley can form);
it is inert on the compact fixture — its per-room plates are too small —
and becomes meaningful once neighborhood-level plates reach it.

- [ ] Build connected components of touching exposed roof plates.
- [ ] Enumerate complete neighborhood recipes rather than independent room
  roofs.
- [ ] Admit partial (staggered-shoulder) plates into
  `_spatial_roof_neighborhood` with typed stepped junctions instead of
  excluding them at `_is_full_roof_plate`.
- [ ] Prefer continuous ridge and authored valley transactions; flatten only a
  complete incompatible component.
- [ ] Make every partial shoulder an exact macro crown, lean-to, garden strip,
  rail strip, or rejected proposal.
- [ ] Add a hard `misplaced_roof_count == 0` audit using exact roof volume,
  visual envelope, support, and public-air ownership.
- [x] Require every narrow-axis lived-in flat roof (`slim` and `row`) to include
  the measured vertical stone core; the first-class row test now pins it.

### Phase F — skywalk and vertical-route campaigns

- [ ] Raise provisional scale targets to 2/3/4/5 and measure exact supply.
- [x] Raise the large/grand experimental minimum from three to four and add a
  bounded ranked-quadruple frontier; the first measured four-link plan sealed
  but added no unique final route coverage.
- [ ] Rank skywalk pairs before final room composition so endpoint rooms remain
  available.
- [x] Measure exact unique canonical-route bridge coverage, including marginal
  coverage beyond the current macro room mass.
- [x] Falsify and remove bridge-body, source-prism, and macro-owner coverage as
  production ranking proxies when they disagree with final recipe occluders.
- [x] Carry a small diverse combination frontier into the existing exact
  court/landmark/skywalk composition transaction and rank sealed survivors by
  the same transformed recipe occluders used by the final enclosure audit.
  The alternate search is deferred until a primary plan seals and resumes
  after the primary's frontier rank; an eager per-permutation draft stalled
  the fixture and was replaced.
- [x] Expose selected route-cover cells/count and redundant-link count in the
  machine-readable skywalk diagnostic; `occluder_rank_trial_coverages`,
  selected covered/denominator counts, and the exact fourth-link redundancy
  fact now land in the composition audit.
- [ ] Reward links that cover primary alleys, connect different height bands,
  close an upper circulation loop, or break a long sightline.
- [ ] Require two distinct inhabited endpoints, full support, exterior air
  below, and no route obstruction.
- [ ] Preserve one connected public route through streets, stairs, courts,
  galleries, and underpasses after every feature transaction.
- [x] Permit a bounded court bridge-house attachment recompose only at its
  named owner socket; unrelated macro-room conflicts remain ineligible.
- [x] Mirror exact skywalk/court endpoint portal masks in the early measured
  room-pair preflight so a feature set cannot pass on ordinary facades and fail
  later on the portal-bearing recipe.
- [x] Preserve complete optional-parcel collision dispositions across repeated
  exact passes and invalidate cached compositions that still contain them.
- [ ] Raise the seed-7 attempt-10 surviving topology from 28.5% to the sealed
  38% large-profile inhabited-overhead floor without counting detached props.
  Exact occluder ranking proves link choice cannot close the remaining
  33.45% to 38% gap on this topology; the uncovered mass must come from the
  Phase B source beam (overhanging rows or arcaded galleries over the
  market-side ground street).

### Phase G — runtime and streaming

- [x] Replace brute-force exact-cover origin search with O(kinds × rotations)
  analytic lookup.
- [ ] Cache pure source mass, excavation, parcel candidate, and compiled asset
  metrics by stable source signature.
- [ ] Share structural preflights among palette-equivalent asset variants.
- [ ] Bound every beam and expose visited/retained counts in timing output.
- [ ] Split worker planning from main-thread commit; never create server-backed
  resources in workers.
- [ ] Commit collision and near-field silhouettes first, then visual batches
  under an elapsed-time frame budget.
- [ ] Cancel stale village generations when their feature block unloads.
- [ ] Measure cold plan, warm plan, first collision-ready, first visible, and
  fully dressed times in the actual game streamer.

### Phase H — visual/corpus acceptance

- [ ] Run focused row/parcel/roof/junction tests after each structural change.
- [ ] Run the mass-first source and exact production corpora.
- [ ] Run live-game streaming with a player arriving from outside the feature
  block.
- [ ] Capture the four review angles at full resolution.
- [ ] Compare captures against all annotated findings and record a falsification
  disposition per image.
- [ ] Update `AGENTS.md` when the source decomposition, join, roof, skywalk, and
  streaming invariants become stable.
- [ ] Commit only after the corpus, live-game run, and visual pass are green.

## Acceptance gates

Completion requires all of the following on the production corpus, not merely
the reviewed seed:

1. Every town is deterministic and sealed.
2. Every required public surface belongs to one connected exterior route.
3. Every stair endpoint and entrance has an exact landing and remains served.
4. Every public-air cell flood-connects to the exterior and overlaps no
   occupied volume.
5. No unsupported room, skywalk, outcrop, roof, stair, or platform remains.
6. No unrelated visual-envelope overlap, sub-tolerance building gap, coplanar
   duplicate facade, or unexplained protrusion remains.
7. Every apparent exact macro cover is selected or carries a typed refusal.
8. No room-sized residual remains generically trimmed.
9. Every roof neighborhood has a complete supported closure and
   `misplaced_roof_count == 0`.
10. Each scale meets its terrain-qualified occupied-skywalk minimum.
11. The visual corpus shows materially fewer micro-boxes at street and overview
    scale, more coherent large buildings, intentional contacts, varied
    rooflines, occupied projections, and repeated overhead episodes.
12. Actual-game cold and warm load measurements meet the final streaming
    budgets without a long main-thread stall.

## Reproduction commands

Focused reviewed fixture:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless \
  --log-file /tmp/mythos-town-quality.log \
  --path /Users/ryko/story \
  -s res://tests/harness/probe_warren_spatial_features.gd -- \
  --world-seed 6052724565602100358 --profile compact \
  --attempt 8 --candidate-token 5610100382 --variant 6 \
  --serial-composition --composition-timing --compiler-only
```

Focused row vocabulary tests:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless \
  --path /Users/ryko/story -s res://addons/gut/gut_cmdln.gd \
  -gconfig= -gtest=res://tests/test_settlement_fabric.gd \
  -gunit_test_name=rowhouse -gexit -gdouble_strategy=partial
```

Do not treat these focused checks as corpus or live-game proof.
