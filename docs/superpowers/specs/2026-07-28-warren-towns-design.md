# Warren Settlements — Exterior 3D-Maze Fabric Design Spec

**Date:** 2026-07-28
**Revised:** 2026-08-02 — component-bounded arcades and visual cleanup
**Status:** The volumetric warren is the default production transaction when the common
fabric vocabulary is present. `VillageWarrenFabricSolver` aligns its boundary landing to
the road, resamples immutable terrain into the same vertical lattice, and materializes
the sealed fabric through `VillagePlan`. The older terrain-led solver remains only for
explicit compact custom-program fixtures; the two algorithms are never combined inside
one settlement. Broader production screenshot and performance validation remains open.
**Scope:** Replace freestanding village massing and the rejected straight-street
prototype with one compact three-dimensional fabric grammar. Villages and towns use
the same representation; profile data changes density, route length, and module
budgets. Natural terrain remains immutable.

**Implementation checkpoint (2026-08-01, volumetric source plan):** The former
pipeline chose an ordered route, packed building recipes around its boundary, and added
overhead relationships afterward. Although seeds changed route and construction
signatures rather than merely roof colours, this ordering made connected upper fabric
an aspirational post-process. It is superseded by a terrain-relative discrete city
mass, a connected exterior-public-realm carver, and a later parcel/asset compiler.

`WarrenVolumeEnvelope` builds a warped anisotropic Gaussian height envelope from each
column's immutable natural-ground band. `WarrenPublicRealmCarver` performs a bounded
deterministic search from one terrain-level perimeter entrance. Its sealed
`WarrenVolumePlan` distinguishes buildable `MASS`, abstract `WALK` floor planes,
`PUBLIC_AIR` swept headroom, and deliberate `DAYLIGHT_VOID`. Every transition owns
both endpoints and its swept volume; it rises by at most one 1.5 m circulation band,
and reserves real horizontal space between two square landings for every rise. A
two-macro-cell rise leaves a complete 3 m stair span; a three-or-more-cell rise leaves
at least 6 m and becomes a sloped boardwalk. An adjacent pair of full landing squares
can never masquerade as a zero-length stair. Every perpendicular vertical turn owns a
square landing.

The worker-only source corpus solves 12/12 seeds with distinct raw envelope and maze
signatures, at least four public elevation bands, no rise over one band, substantial
higher-mass cover, facade opportunity, repeated XZ columns at different elevations,
and at most 10% unblocked deep central columns. `WarrenParcelizer` reserves scarce
neighboring half-level pairs and one exact future occupied-link corridor before generic
packing. It emits only complete roofable 1x1, narrow/deep 1x2, and 2x2 macro envelopes;
the rejected 1x3 family and every frontage-wider-than-depth orientation are impossible.
Current structural seeds produce 14–22 parcels, while the stricter measured-asset
transaction typically retains 13–16. Bases may use any 1.5 m band, but inhabited
storeys remain complete 3 m units with a separately reserved roof envelope. Different
seeds alter envelope, maze, parcel, building, and occupied-link geometry—not only
palette.

`WarrenVolumePublicRealmAdapter` losslessly expands each 3 m route square into the
common two-lane 1.5 m fabric lattice. `WarrenVolumeSurfaceCompiler` then derives one
horizontal mesh/collision union, exact facade openings, exposed-edge guards, and one
collision-bearing transition mesh from the sealed route and parcel solids. Six-metre
rises are sloped walks; three-metre rises are six-tread stairs; both own continuous
side rails and exact two-lane seams at both landings. A wide building candidate is now
admitted only when its real transformed authored doorway—not merely its facade
rectangle—lands on the addressed public square. All 12 structural seeds therefore
serve every facade threshold with zero entrance/guard conflict.

Asset-aware parcelization measures the final modular wall/roof clearance envelopes
before packing and reserves either a straight or right-angle occupied skywalk corridor,
including its SOLID, WALK, HEADROOM, public-air, visual-clearance, and internal
component-conflict facts. `WarrenFabricCompiler` then rebuilds buildings, public
surfaces, exterior air, solid/void boundaries, skywalks, and roofed outcroppings as one
ordinary `SettlementFabricPlan`; an optional overhead element is accepted only by a
full transaction. The current four-seed construction slice has unique signatures,
zero unrelated visual-envelope intersections, zero public-air/occupied overlap, and at
least one occupied skywalk in every seed.

**Known regression (2026-08-06, pinned seed 4242):** The production canary
test_village_plan (seed 4242, flat frame) fails with "no ranked town survived
exact construction". Verified pre-existing at commit 7f8bba4 via stash-toggle
(NOT caused by the round-5 changes). Diagnosis: all three frontier volumes
produce 15-24 occupied-link motifs, but every motif dies in
_best_connection_pair's followup gates — chiefly _followup_packing failing to
reach MIN_PARCELS=10 with the motif seeded (under_capacity 14/15/20, rest
no-opposing). The empty-best branch now records these counts in
last_diagnostic["connection"]. Root-cause investigation spun off as its own
task; suspects are round-4 feasibility predicates (visual compatibility with
enlarged bay/roof envelopes, tall-construction step-neighbor gate).

**Implementation checkpoint (2026-08-06, round-5 remediation):** Three review
notes landed. (1) Corner-wrap oriels read from above as open frames with bare
plank tabletops; they now wear the closed compact gable (theme-mapped 03/06),
left the capped_outcropping family, and carry a four-band solid envelope like
the roofed projection bays — pinned by
test_corner_wrap_bays_are_roofed_turrets. (2) Route-climb and overpass levers
were calibrated across five 12-seed sweeps: the aggressive settings (height
weight 100/90, revisit -705/-680, crossover -215/-200) each cost two corpus
seeds via "no exact optional-infill variant", while TARGET_OVERHEAD_RATIO was
proven irrelevant to those failures (0.45 and 0.35 sweeps identical); the
shipping config keeps the 82/-650/-180 route weights, raises MAX_SKYWALKS to
7, extends the parcelizer overpass reward to a sixth rung, and lifts the
composition demand to four occupied overpasses — 6/12 corpus acceptance with
five overpasses across accepted towns (baseline: 5/12, five overpasses, three
towns with none). (3) Open items recorded: route_y_span plateaus at 4-6 bands
regardless of weight pressure — genuine snaking ascent needs a structural
change (route length families or envelope shaping), and overhead ratio remains
below the 45-65% spec band on most seeds (one seed reached 0.64).

**Implementation checkpoint (2026-08-05, walkway colour unification):** Review
captures showed some walkways as normal wood while stair/ramp transitions and
their side guards read essentially white. Instance-colour falsification renders
(red plank tiles, blue guards, per-kind garish surface materials) proved the
ivory surfaces were the generated STAIR transitions: the review board shader
wrote sRGB-authored swatch constants directly into ALBEDO, a linear-light
input, so the display transform desaturated them to ivory. The shader now
linearises its constants (`pow(c, 2.2)`) and renders lit like the surrounding
plank assets — the earlier near-black lit attempt was the since-fixed top-face
winding, not lighting. Production is unaffected (its lit StandardMaterial path
interprets `albedo_color` as sRGB correctly). Rule recorded: hand-authored
colour constants in spatial shaders must be linearised before ALBEDO, and
`unshaded` masks both winding and colour-space errors.

**Implementation checkpoint (2026-08-05, covered negative space):** The
annotated production review restated the core philosophy — public paths are
negative space snaking through a chaotic jumble of buildings, mostly covered,
never a flat platform field — and flagged a bare deck court, a detached tent
row, and too much open-sky route. Three remedies landed. Market stalls now
require adjacent non-market building mass within one module
(`WarrenMarketSolver._backs_onto_mass`, `tests/test_warren_market.gd`), which
removes approach-road tent camps by construction. Tunnel supply rose across
three layers: bridge-house parcels keep a diminishing packing reward through
the fifth overpass with a three-overpass composition target, the skywalk
budget is five, and the carver's fold rewards strengthened (column revisits at
headroom separation -650, crossover adjacency -180; -780 bought more tunnels
but cost a corpus seed, so the softer pair is the reviewed optimum). The
12-seed sweep holds 5/12 acceptance with overhead route ratios 0.29-0.39
(baseline 0.24-0.35), one town packing three occupied overpasses and another
six skywalks; TARGET_OVERHEAD_RATIO rose to 0.35 as the preferred-tier
selection line. A latent winding bug in every generated surface quad (tops
emitted as back faces, masked for months by unshaded materials) was fixed at
both emitters, which also retires the near-black slab class of review
artifacts. Open: overhead ratios still trail the 45-65% spec band — the next
real lever is parcels bearing directly on elevated courts and a
cross-gable/multi-valley roof vocabulary for denser interlock.

**Implementation checkpoint (2026-08-05, corner oriels):** Rooms now expose
end-of-face `room.corner.<face>.<side>`/`bearing.corner.*` sockets carrying a
corner-wrap bay: a 2 x 2 module square straddling the building corner — two
squares overlapping on one diagonal — whose outside L holds the solid cells,
two 3 m window faces, 1.5 m cheeks, a corner post, and the gallery-deck cap,
while the inside quadrant stays a declared visual seam into the parent.
Corridor/link planning explicitly ignores corner sockets (`_socket_facing`
and upper-endpoint enumeration skip `.corner.`); missing that skip let the
parcel-stage occupied-link reservation bind a corner socket the skywalk
enumerator never offers, rejecting every seed — the corner vocabulary is
outcrop-only by contract. Seed 1 now mixes gable/shed dormer bays with
corner oriels under a one-bay-per-stack-FACADE reservation — bays on distinct
faces of one column articulate it; a repeat on one face is a stamp
(`tests/test_warren_outcrops.gd`, 7 passing). Because a 1.5 m bay honestly
covers only its near lane, the uncovered-route component ceiling moved 12 → 16
fine cells as a reviewed relaxation: a one-sided edge street may keep the
2 x 8 opening that 3 m-deep bays used to roof from a single facade; larger
shafts remain rejected, and corpus seed 4242 composes again under the same
seal. The closing 12-seed sweep with every change live accepts 5/12 (up from
the session's 4/12 baseline — the reviewed ceiling admitted a fifth seed with
a 0.30 largest-roof-band ratio), and the first seed's structure tightened to
six roof bands, a 0.50 largest-band ratio, and four infill patches where the
baseline had fourteen.

**Implementation checkpoint (2026-08-05, style restoration):** The production
review preferred the earlier composition — varied small roof punctuation,
prominent stone bases, and ground paths reading as negative space — over the
first remediation pass. Outcroppings are now a shallow-bay vocabulary: every
bay is one 1.5 m module deep (solid cells a single row; the visible face at
the row plane), built either as an authored attic-window dormer whose gable or
shed roof matches the parent stack's family (`sfv.fabric.roof.window.001-004`;
the orange pair's missing `SFV_ROOF_ORANGE` fallback texture was repaired in
the bake) or as a flat jetty capped by the gallery deck with the newly baked
1.5 m side walls and symmetric corner posts. One bay per building stack.
Production ground streets are no longer planked: `TERRAIN_STREET` keeps its
worn-path paint on real terrain so lower alleys read as dirt carved between
masses, and timber marks genuinely structural surfaces only; the review
harness's generated surfaces now use the same lit plank palette so captures
match streaming. Optional gallery infill dropped to a [6,3,0] ladder. A
12-seed sweep held acceptance at 4/12 with 4-6 roof bands, 0-1 same-band
adjacent pairs, and stepped-pair counts of 4-6 — parcel-level height variation
was measured healthy, so skyline work stays a scoring preference
(same-band-adjacency penalties) rather than a tighter gate; compact tower/slim
dominance (six per town) is bound by route-carved pocket shapes, not scoring,
and its orange-only palette remains a known limitation.

**Implementation checkpoint (2026-08-04, review-note remediation):** The
reported production notes drove four construction-level fixes. Outcroppings are
now a two-variant vocabulary with a shared parent contract: the gabled bay may
join only a parent face wider than itself beneath a warm roof family, its wood
follows the parent's wall family, and every other parent — narrow towers/slims
and cool-roofed stacks — receives a flat-capped jetty (floor-module cap, no own
gable) that carries the same inhabited overhead cover. This keeps the
uncovered-route seal satisfiable (the gates alone regressed corpus seed 4242)
while removing the glued-on mini-house reading; `tests/test_warren_outcrops.gd`
pins the contract. Production streaming now commits the sealed plan's
stair/ramp transition meshes with collision through a generated-surface channel
in `EnvironmentInstancePayload`/`FeatureCommitQueue` (lit plank-family
material); previously STAIR claims had no production visual or physics at all —
`tests/test_warren_production_surfaces.gd`. Equal-band ridge-continuation and
parallel-valley junction partners must select roof recipes whose measured
weather-surface heights agree within 5 cm: joined square roofs build from new
ridge-Z plain modular runs (`roof.square.{blue,orange}.plain`) instead of
mixing SFV runs with 0.6 m-lower LPFV shells — `tests/test_warren_roof_profiles.gd`.
The legacy gable-fronted `roof.blue`/`roof.orange` ids deliberately remain
X-run for the authored fixture path; rotating them broke the embedder proof and
was reverted. Baseline caveat: the 12-seed topology-composition corpus tests
and four fixture-path tests (`test_settlement_fabric` ring-planner proofs)
were already failing before this checkpoint and are unrelated to these fixes.

**Implementation checkpoint (2026-08-01, surface/roof cleanup):** The first
full-resolution render of this pipeline failed its visual gate because the lower route
read as exposed slabs, broad shafts looked directly to grass, short huts sat beside tall
stacks, and a duplicate generated skin showed through authored floor boards as nearly
black rectangles. Those failures now have construction-level remedies rather than
per-image offsets.

`WarrenPlatformInfillSolver` grows a bounded frontier of small structural courts from
accepted elevated route squares. Each patch remains owned by its route node and
therefore cannot create a disconnected suspended platform. Fixed-size reviewed board
meshes render the horizontal union; its generated mesh remains the sole collision
authority but is not drawn beneath the boards. Stairs and ramps keep their exact
generated collision/render surface and use a world-stable plank shader. Sparse timber
supports derive from the same structural-surface cells down to an explicit support
datum. A court only one 1.5 m band above that datum is a retained stone terrace, not a
crawl-height lawn beneath timber posts. A daylight well is subtracted only after the
complete surface is known, every cardinal edge is another public surface or an
inhabited wall, and a flood proves that every surviving extension cell still reaches
the route square that owns it. This prevents a visually bounded hole from removing a
one-cell neck and forcing exact construction to discard an otherwise useful upper
court. Short route-fused strips may also terminate in a pocket bounded by two
inhabited facades even when that pocket does not project onto a lower route; these are
typed upper courts with the same support, guard, headroom, and connectivity proofs, not
detached suspended platforms. The surface compiler independently rejects an explicit
unbounded well, and the hard audit requires zero unbounded edges. Remaining uncovered
macro columns are measured before lightwell subtraction; no accepted town may keep any
unclassified 3 m core aperture. Only isolated, bounded 1.5 m guarded lightwells may look
through to a lower level, and their XZ projections remain at least three fine cells
apart even when they occur on different levels. Court contact with a stair or ramp is reduced to a
deterministic non-overlapping two-lane seam instead of treating every incidental side
contact as a second transition.

The raw parcel-stage void is independently audited before platform infill and may have
no cardinal component larger than four macro columns. This prevents the infill pass
from concealing a failed building composition with one broad low deck. The sealed
1.5 m public realm is the final hard authority: it permits no unclassified 3 m core
aperture and no uncovered same-level route component larger than twelve fine cells.
Two connected
ground arcades are carved before parcelization: a seven-or-eight-cell primary market
branch and a spatially separated four- or five-cell secondary branch. The world seed
chooses the secondary length as a sectional grammar family before parcelization; this
is ordinary procedural variety, not a special-case repair. Both turn at
least twice and attach through square landings on the primary itinerary, so buildings
and markets have to enclose both lower approaches rather than leaving the far side as
a grass-floored undercroft tunnel. Across the current four-seed exact construction
corpus this yields 10--15 connected roofed buildings, 15--24 full-headroom route-fused
patches, six isolated guarded lightwells, and largest exact uncovered lower-route
components of 6--8 fine cells. Every raw post-infill core opening is closed;
the later lightwell pass may subtract only isolated guarded fine cells. The patches
include connected upper galleries crossing lower arcades rather than detached cover;
their support and address relationships come from the same public graph.

The vertical check also measures every ground-street fine cell that has neither
inhabited mass nor a structural public surface above it. Average overhead coverage is
not sufficient: those cells are flood-filled in the horizontal plane and no connected
component may exceed twelve 1.5 m cells, the size of a short turning three-module
court. `WarrenPlatformInfillSolver` first closes the raw core obligation, then greedily
selects the legal route-fused gallery bundle that most reduces the largest remaining
ground opening; visual scores break ties only after component topology. This prevents
several individually attractive facade shelves from consuming the one bounded patch
needed to divide a continuous roof-to-ground street.

`WarrenPrunedMassPlan` is the authority for provisional Gaussian mass. `BUILDING` and
`BEARING_OPPORTUNITY` block gallery headroom; `PRUNED_EXTERIOR_AIR` and `OUTSIDE_CORE`
do not become invisible solids. Outside-core air is nevertheless eligible only when
the candidate directly shelters an already sealed lower public route, so the correction
cannot create an arbitrary suspended terrace beyond the city. Stair and ramp footprints
come from `WarrenVolumeTransition.surface_cells()` and their complete player-height
envelopes are reserved during gallery discovery. The adapter, surface compiler, and
infill solver therefore cannot derive disagreeing transition geometry or admit a court
through a future stair.

Every construction proposal owns exactly one complete pitched roof shell. Compact roof
variants 03 and 06 and a chimney asset are part of the measured vocabulary. Parcel
choice evaluates the terrain-rooted final stack, not merely its nominal source envelope;
visually one-storey proposals and frontage-wider-than-depth orientations are ineligible.
Equal-height, equal-family neighbours may use one narrowly typed party-wall seam only
when their roof ridges are collinear and their eave faces meet exactly. Mixed heights,
gable contacts, corners, and occupied overlap remain hard conflicts.

`WarrenGroundArcadeSolver` adds both terrain-level public branches before inhabited
parcels seal. Each attaches at a real square landing on the primary graph, requires at
least two turns, and participates in the same air/occupancy transaction. The seed-selected
four- or five-cell secondary family is resolved before parcelization. The secondary
root must be at least four macro cells from the first branch. `WarrenMarketSolver`
then ranks complete stocked prefabs by how much of the residual raw core opening their
measured envelope occupies before applying its stable hashed tie-break. The parcel and
market searches therefore build both lower alleys into the city instead of decorating
whichever residual exterior volume happens to remain.

The composed route uses a 50% pre-detail viability floor after building adjacency,
inhabited overhead mass, and route-fused courts are combined. Plans at or above 55%
form the preferred exact-review tier; 50--55% plans fill only otherwise unused slots.
The asset-aware search retains eight ranked sealed town candidates through exact
exterior-air, visual-envelope, skywalk, market, optional-detail, and hostile-ray
compilation. A near-threshold rescue candidate therefore cannot crowd a stronger
preliminary composition out of the bounded frontier, while a seed with only one poor
55% survivor still gains complete alternatives. The current four-seed
gate treats parcel-only enclosure and opposing frontage as ranking signals, not
pre-composition acceptance rules: neither proxy can see route-fused courts or upper
galleries. Final frontage, overhead coverage, occupied-link, and through-sightline
measurements are authoritative because they see the completed construction.
The measured corpus otherwise
requires 10--15 connected roofed buildings, zero visually short
parcels, no stair endpoint gap, at most six isolated guarded 1.5 m lightwells, zero
unclassified 3 m core apertures, zero unrelated visual-envelope intersections,
and zero public-air/occupied overlap. All four maze and construction signatures differ.
The current exact corpus holds 56.5--77.3% composed enclosure, at least one occupied
skywalk construction per seed, and distinct construction geometry for every seed.
Occupied straight skywalks use the same measured pitched repeat-and-gable roof contract
as rooms; a floor
asset can never become their ceiling. A fresh adversarial review over multiple seeds
checks 44 full-resolution images: opposite overviews, entry, two hostile ground-corridor
views, upper route, east section, roofline, skywalk side and underside, and the top-down
network. Required close targets prove both camera clearance and line of sight, and the
manifest explicitly treats finding an issue as review success. The pass found one overly
opaque upper court; increasing the bounded fine-cell lightwell allowance from four to six
split that surface without permitting adjacent holes or a broad top-to-ground shaft. A
later adversarial seed exposed the inverse failure: a bounded well could sever the sole
route neck and trigger a five-patch fallback. Route-connectivity validation now prevents
that subtraction, and a twenty-four-patch ceiling admits additional narrow galleries
over lower streets while retaining six isolated fenced wells. The later connected-
component gate exposed a 20-cell lower arcade in an adversarial exact seed; topology-
aware gallery selection and the typed outside-core-air correction reduce that opening
to eight cells without relaxing any support, headroom, stair, entrance, or overlap
invariant.
Review cameras
now require a player-sized visual-clearance bubble as well as a collision-free point, so
a stall post or eave cannot technically pass while obscuring most of a frame. Broader
player-capsule traversal and a full 24-village rendered production corpus remain pending.
A real-streamer capture of world seed `2697992464` now covers eleven adversarial views;
it verifies the requested roof, proportion, plank-material, stair, and vertical-opening
non-regressions while deliberately retaining broad-deck and horizontal-sightline findings.

**Implementation checkpoint (2026-07-30, production migration):**
`VillageWarrenFabricSolver` now adapts the same sealed `SectionalPublicRealmPlan` used
by the fabric solver into the production `VillageRecord`; it does not infer a second
route from the rendered pieces. The default program uses this path exclusively. The
legacy terrain-massing solver remains available only to explicit custom fixtures and
its output is never combined with a sectional record. Sectional towns suppress legacy
outskirts and incidental props, so an empty tent or campfire cannot appear as a detached
substitute for the inhabited transaction.

Procedural seeds now alter both route and construction signatures. Seed bits select one
of 32 sectional grammar families (four orthogonal route motifs, two turn phases, and
four balanced vertical profiles) before hashed packing and overhead choices; all family
selection remains in 64-bit integer space. The exact fabric corpus and the production
adapter corpus require distinct raw route, rotation-normalized route, and construction
signatures across their seed sets, a sealed public graph, every inhabited stack
connected to that graph, and zero
unsupported or isolated stair/platform components. Every stair endpoint must meet an
actual public surface; perpendicular consecutive flights must share a full square
landing, never only a corner or another stair tread. The production surface adapter
tiles the sealed street/court/bridge cells with fixed board modules, retains the authored
stair assets, derives guards from exposed surface edges, and adds fixed-height supports
where the immutable terrain is below a public deck.

Exact visual selection is bounded and adaptive. Every seed compares two complete sealed
transactions. Only when their best survivor still has less than 25% overhead route
coverage or more than 50 through-core sightlines may the planner compare the remaining
members of the fixed eight-plan frontier. Overhead route coverage includes inhabited
mass and a real upper public surface crossing the same column; detached decoration and
unsupported ceilings never count.

Production occupancy preserves the same semantic proof. Solid, public-walk, headroom,
and guard cells are deterministically coalesced into exact typed cuboids before entering
the bucketed village index. This avoids both a prefab-wide collision proxy and a quadratic
one-volume-per-cell transaction; the broad district reservation remains only a separate
ground-exclusion contract for later feature planners.

The construction vocabulary now rejects comically transverse small houses by
construction: both the micro house and the stackable townhouse use 3 m by 6 m
narrow/deep envelopes, including their rotated roof runs and bearing footprints. The
townhouse can fill deep upper-route pockets with separately addressed storeys and a real
pitched roof instead of a sideways house or flat-capped tower. Exterior stair-facade
rooms use the same cardinal doorway contract as every other addressed room, and the
door is required to meet the adjacent low landing rather than imply an interior route.
Outcroppings are shallow roof-closed room envelopes or corner-overlap envelopes with
legal parent seams; raw facade cubes are not a generation option. Markets draw only
from seven reviewed `stocked_market` prefab stalls; plain or empty tent families are not
eligible. The corresponding tests live in `tests/test_settlement_fabric.gd`,
`tests/test_village_plan.gd`, and
`tests/harness/production_warren_seed_corpus.gd`.

This checkpoint is not a declaration of visual completion. Exact frontage, overhead
occupation, enclosure, and through-core sightline metrics still report useful failures
for some seeds. The screenshot reviewer is explicitly falsification-seeking: finding a
real defect is a successful review outcome, and production rollout is not visually
accepted until a many-seed rendered corpus has no unresolved structural or composition
issue. Every sectional capture manifest now carries its raw and rotation-normalized maze
signatures, construction signature, and the hard stair/platform/entrance/support/overlap
audit beside the image targets. Corpus coverage rejects any repeated route, repeated
rotation-normalized maze, or repeated construction. A current four-site real-terrain
development selection has four distinct values for all three signatures and zero hard
structural failures, but all four still fail the quantitative visual-quality target;
this is evidence for continued critical review, not closure.

**Implementation checkpoint (2026-07-30, construction-contract revision):** The v14
fixed proof exposed a second class of failure beneath the layout metrics: planning-cell
occupancy and rendered asset geometry did not share authoritative seam planes. A floor
mesh placed at a nominal public datum could put its visible top above the adjoining
generated surface; repeated roof presets could use a planning pitch unrelated to their
authored connector planes; and roof eaves or trim could leave a nominally empty cell
while intersecting a neighboring building. These are construction-model failures, not
visual offsets. Before the fixed proof or procedural search advances, every admitted
module now requires a compiled construction contract covering walk/threshold planes,
repeat and end-cap seams, hard structure, visual clearance, support, and legal joins.
The same revision clarifies that winding remains completely orthogonal: a helix-like
journey is composed from successive right-angle turns, landings, and half/full rises.
No building, overpass, or route asset needs a free-angle transform.

**Implementation checkpoint (2026-07-29, exterior embedder slice):** Public-realm nodes carry explicit
`EXTERIOR` air provenance and open/covered policy. Every public surface claims two cells
of swept exterior air; `FabricVolumeClassifier` rejects overlap with structural or
inhabited volume and flood-proves the complete claim back to the route landing. Passage
rooms, occupied skywalks, and the retired stair-house are private building mass and can
no longer satisfy public circulation. The fixed proof uses exterior facade stairs and
currently proves 282 connected exterior-air cells, seven primary exterior-stair
episodes, zero public-interior nodes, and zero public-air/occupied overlap. Its v7
adversarial pass reviewed all 17 full-resolution captures and deliberately remains
non-closing: it found disconnected visual islands, 3.26% facade enclosure, 1,356
through-core sightlines, insufficient overhead coverage, synthetic rectangular support
towers, and several cameras that do not expose their named targets. The first staggered
solid/void slice is now implemented without becoming a runtime fallback:
`FabricSolidVoidPlan` turns every exposed route side into a typed boundary obligation;
`StaggeredFabricEmbedder` runs a deterministic bounded beam over complete roof-closed
one/two-storey envelopes at route, half-level-lower, and full-level-lower bases; and
`StaggeredFabricCompiler` converts accepted proposals into ordinary terrain-perched
room/roof DAGs. If no complete room fits a low route edge, the same search may use a
full baked FantasyMarket stall envelope, never a plain tent or decorative blocker. The
common transaction then rebuilds exterior air, surfaces, occupancy, and solid/void
classification from those compiled units; no seed result is copied forward.

The v14 adversarial slice folds the upper journey sideways, returns its descent over the
existing town footprint, moves both large prefab anchors inward, and replaces the
detached valley branch with an occupied bridge-house directly above the lower folded
route. Its classified core shrank from 40 x 50 to 30 x 36 lattice cells, overhead route
coverage rose from 8.16% to 19.15%, and through-core sightline failures fell from 178 to
101. It now commits 430 reviewed asset placements, 434 collision pieces, 26 continuous
surface patches, and eight derived guards. Structural courts and bridges retain one
continuous generated collision/underlay, but are visually tiled with reviewed
fixed-size FantasyVillage plank meshes; terrain-street claims in the fixture render as
supported rock/ground perches rather than floating dark rectangles.

The alignment revision makes those visual relationships authoritative plan data.
Exterior doors now exist only as typed threshold records with an exact adjacent public
landing; an unserved facade compiles with a closed/windowed bay instead of retaining a
decorative door. The same threshold record opens the derived guard, so a railing cannot
cross an entrance. Stair endpoints are audited as two-lane low/high seams against the
actual surface union, and guard openings come only from those frozen graph seams rather
than from arbitrary vertically adjacent floor cells. The upper court is a 31-cell
planked structural surface carried by two explicit inhabited bearing stacks. Its one
omitted cell is a typed `DAYLIGHT_VOID`, remains in exterior headroom, and receives four
derived guard edges. Missing geometry that is not such a reserved void remains a hard
failure; the compiler never fills leftover air speculatively.

This is still a failed intermediate proof, not a production layout. The compactness
gate is 24 x 24 cells, there is no level-changing reconnecting loop, exact solid/void
frontage is only 38.41%, 85 route sides remain open, and the worst sightline is 42.75 m.
Several route cameras are also obstructed or expose open grass beyond the intended
maze. These are now explicit review failures. The remaining fixed proof must co-solve
shorter facade/corner relationships, the reconnecting path, and overhead occupancy;
it may not repair these results with props, empty decks, or a detached branch.

This revision incorporates the visual reviews of both the multi-street and folded-route
prototypes. They demonstrated useful modular walls, roofs, stairs, occupancy, and
parent ancestry, but retained the wrong primary abstraction: buildings and route pieces
were planned separately, then connected with platforms or skywalk branches. The result
could have one connected abstract graph while still reading as several unrelated
perches above a flat ground path.

The first sectional revision correctly made circulation a continuous graph, but it
still treated route pieces and occupied masses as distinguishable layers. A graph can
be connected while the visible town remains a row of similarly elevated houses beside
an open street. It also allowed a stair-house to route the player through an interior,
which belongs to a later interior phase.

The corrective principle is now:

> A warren is a compact three-dimensional maze of occupied building masses. Its public
> realm is the one continuous exterior void left between those masses: alleys wrap
> around corners, stairs climb facade canyons, terraces cross narrow gaps, and paths pass
> beneath outcroppings and occupied skywalks. Buildings begin and end at many different
> heights, so the void folds upward and downward through the same footprint. No camera
> chord or player-facing corridor can look through the core to the opposite outside.

“Exterior” does not mean uncovered lawn. An exterior route may pass beneath a projecting
room, occupied skywalk, awning, or gallery; it remains exterior because its traversable
air belongs to the outside-air component rather than a building interior. Buildings may
connect to one another with enclosed occupied skywalks, but public traversal through
those interiors is deferred. For this phase, every public stair, terrace, landing, and
bridge is visibly outside the building envelope.

---

## 1. What the current prototype taught us

The current screenshots expose architectural faults rather than missing decoration:

- `SettlementStreetPlan.path_sections` are straight runs with one elevation each.
  Long flat sightlines are therefore represented directly in the input.
- Repeated 6 m row blocks are emitted independently from the path. They form parallel
  facades, not a building mass that encloses and crosses the route.
- The small upper-floor shift reads as a facade taper, not an inhabited cantilever.
  No room volume actually occupies space above a pathway.
- Cross-street bridges are open floors with rails. They cannot read as enclosed
  building-to-building tunnels.
- Markets under galleries degrade into repeated stocked tables; complete
  `FantasyMarketFBX` stall structures are not the default market frontage.
- Complete buildings from the other asset packs are excluded from the grammar even
  though several useful candidates are already baked.
- Fringe tents are a first-class collection and the validator requires them. They add
  open lawn and weaken the dense-town silhouette.
- The plan validates counts, elevations, ancestry, and reachability, but has no
  enclosure or eye-level sightline invariant.
- Rectangular review terraces visually separate the route into obvious levels instead
  of letting natural terrain, half-rises, rooms, and stairs interlock.
- Each route recipe emits its own narrow floor asset. Graph connectivity therefore
  does not imply continuous surface coverage; adjacent strips can leave grass holes,
  cracks, and visibly unfinished courts.
- Skywalks are authored as secondary branches between already placed buildings. They
  do not carry the main journey through the town or cause the massing to interlock.
- Passage-room recipes have same-height entrance and exit assumptions. They cannot
  model entering a building low and emerging from another facade several half-levels
  higher.
- Generic `terrain_bearing` route tags turn elevated paths into isolated platforms on
  columns. They cannot express an upper courtyard borne by inhabited rooms below.
- A multi-storey stair-house can satisfy graph elevation metrics while moving the
  player into an interior volume. It does not prove the exterior, facade-bounded
  circulation required before interior gameplay exists.
- Raising a cluster of houses to roughly the same second- or third-storey datum creates
  one obvious “upper level.” It does not create a continuously staggered section.
- Packing buildings into a central clump does not make a maze if their ground-level
  gaps align into an unobstructed chord. Aerial mass cannot rescue a street that can be
  seen through from one side of the core to the other.
- Treating sightline rejection only as a final metric invites token occluders. The
  embedding must alternate meaningful occupied corner masses across the route tangent,
  so long views are impossible before decoration or audit.

No further patch should move the route indoors, raise another row to a shared datum, or
add a freestanding blocker to repair a sightline. The prototypes are retained only as
regression fixtures for assets, deterministic DAG ordering, surface union, and review
instrumentation until the exterior-maze slice supersedes them.

## 2. Non-negotiable visual contract

The core of a warren must satisfy all of the following:

1. **The public realm is one continuous exterior maze.** It turns every 3–9 m, changes
   elevation at least every 6–12 m, includes both rises and descents, and remains in the
   outside-air component at every sample. Public circulation does not enter a building
   during this phase.
2. **The route is the gap between occupied barriers.** At eye level, walls, doors, shop
   fronts, stalls, stairs, and genuine occupied corners form the maze boundaries on
   both sides. Lawn, a freestanding occluder, or a path strip with buildings merely
   nearby is not an inner-core street edge.
3. **Occupied mass crosses above and beside the exterior route.** Upper rooms,
   undercrofts, projecting bays, outcroppings, facade galleries, and enclosed occupied
   skywalks cover and deflect substantial portions of the route. The player may pass
   beneath them but does not traverse their interiors yet. An awning or empty deck does
   not count as an inhabited overhang.
4. **Buildings occupy the whole section rather than shared levels.** Neighboring bases
   and rooflines are staggered by half- and full-level offsets. The core mixes low
   ground houses, tall ground houses, short perched houses, middle-height terraces, and
   higher outcroppings; it never reads as one ground row plus one uniform upper row.
5. **Markets use market structures.** Alleys are lined with baked, populated
   `FantasyMarketFBX` stalls and their themed variants. Plain BattlePack tents are not
   warren market frontage.
6. **There are no fringe tents in the warren profile.** A future rural camp or festival
   profile may use them through its own grammar; they never dissolve the edge of this
   town into random canvas on grass.
7. **Generated and prefab buildings share one placement contract.** A full Alchemy,
   Forge, FantasyVillage, or Tavern building is an anchor module with the same occupied
   cells, sockets, entrance facts, and support rules as generated modular fabric.
8. **Every exposed platform has a reason.** Public timber exists as a stair, a short
   route, a one-cell door landing, a facade gallery, or a building-bearing floor. There
   is no substantial uninhabited suspended platform.
9. **Every apparent exterior floor is complete.** Streets, landings, courts, facade
   galleries, stairs, and short bridges compile into continuous surface regions. The
   core contains no accidental patch of grass, uncovered support top, or gap between
   separately placed floor strips.
10. **Higher public space becomes local ground.** An elevated court may be supported by
    inhabited rooms and may itself support doors, stalls, stairs, and further building
    mass. It is not treated as a decorative platform attached to a lower street.
11. **Every internal void is intentional.** A space in the dense envelope is either
    public surface, inhabited volume, a guarded daylight court/lightwell, or outside
    the core. There is no fifth category for leftover space.
12. **No chord sees through the maze.** At player-eye heights and the relevant exterior
    approach heights, a ray that enters one side of the compact core must hit a
    substantial occupied facade/corner before it can leave another side. The blocker
    must be part of a valid inhabited recipe, not a decorative sightline patch.
13. **The maze works in section as well as plan.** A route cannot satisfy winding by
    zig-zagging on one flat plane beneath a uniform shelf. Its barriers, address planes,
    and stairs must change height together, producing meaningful choices and occlusion
    from below, beside, and above.

## 3. Scale and coordinate grammar

The common topology lattice is **1.5 m in X, Y, and Z**.

- Two horizontal cells form a 3 m public alley and align with the reviewed modular
  building bay.
- One vertical cell is the requested half-level.
- Two vertical cells form the common 3 m modular storey.
- The existing small FantasyVillage stair rises approximately one half-level; the
  medium stair rises approximately one full level. Both therefore fit the same route
  graph without ad-hoc scaling.
- Asset scale correction is applied exactly once at bake time. Runtime placement uses
  rigid 90-degree transforms only; a solver never rescales an asset to make it fit.

The lattice is a planning and proof structure, not visible voxel geometry. Building
construction additionally uses an exact authored-bay contract. A module is not assumed
to fit merely because its measured AABB rounds to the same topology cells. Its compiled
contract records:

- local walk, threshold, wall-base, underside, eave, ridge, and end-cap planes;
- repeat axis, repeat pitch, legal 90-degree orientations, and compatible seam profile;
- hard structural envelope, collision envelope, visual/eave envelope, and support
  footprint;
- joinable facade/party-wall sockets and the clearance required on every other face;
- material family, orientation, and continuous run phase.

Every final transform is rigid and orthogonal. Topology may occupy half-level cells,
while floors, roofs, walls, and neighboring buildings meet on the compiled seam planes.
An asset whose seam facts cannot be reviewed is not admitted into procedural placement.

## 4. Three coupled plain-data facts, one sealed plan

Connectedness is represented explicitly rather than inferred from touching assets, but
the route is no longer embedded independently and decorated afterward. One bounded
search co-solves three facts for every candidate: occupied building volume, exterior
air/headroom, and the walk surface at the bottom of that exterior channel. A candidate
episode is accepted only when all three fit.

The resulting `SectionalPublicRealmPlan` records the exterior traversal proof:

```text
ExteriorRealmNode
  stable_id
  episode_kind       # ALLEY, FACADE_TURN, STAIR_CANYON, UNDERCROFT,
                     # TERRACE, COURT, EXTERIOR_GALLERY, SHORT_BRIDGE
  lattice region
  entry / exit elevation
  portal requirements
  left/right occupied-boundary requirements
  exterior-air cells
  air realm          # EXTERIOR in this profile; INTERIOR is reserved
  cover policy       # OPEN or COVERED

PublicRealmEdge
  stable_id
  from_node / to_node
  traversal kind     # LEVEL, HALF_STAIR, FULL_STAIR, or RAMP
  swept walk/headroom cells

SectionalPublicRealmPlan
  nodes / edges
  ordered primary itinerary
  optional reconnecting loops
  surface claims
  exterior-air claims
  occupied-boundary obligations
  core envelope classifications
```

The `INTERIOR` air realm remains in the type vocabulary for a later profile but is
illegal in the exterior-maze profile. `COVERED` means an undercroft, outcropping,
awning, or occupied skywalk lies overhead while the route air remains flood-connected
to the outside around at least one side or end. It never means that the public graph
entered a room shell.

The ordered itinerary is a traversal promise, not a camera spline. Every consecutive
episode must share a real player-width exterior seam and collision-bearing walk
surface. Every non-court episode also declares which occupied mass closes its left and
right tangent boundaries. Optional graph edges add shortcuts and loops but cannot be
required to repair a broken primary itinerary.

The program also compiles a finite set of `FabricRecipe` values. A recipe contains only
plain data:

```text
FabricRecipe
  recipe_id
  role_tags
  asset placements
  solid cells
  public-surface claims
  public-headroom cells
  eye-level occluder cells/faces
  typed sockets
  required structural parent sockets
  measured visual bounds
```

The solver emits one small inhabited/structural instance record for each barrier mass:

```text
FabricUnit
  stable_id
  recipe_id
  lattice transform
  parent_ids
  socket bonds
```

The recipe representation covers:

- modular ground rooms and upper rooms;
- complete prefab building anchors;
- projecting rooms, bay windows, corner rooms, dormers, and lean-tos;
- exterior stair flights, facade galleries, undercrofts, and structural court
  boundaries;
- one-parent cantilevers and two-parent enclosed skywalks;
- real market stalls and facade awnings;
- roofs, braces, railings, chimneys, signs, and other attachments.

Recipes contribute solids, facade/address sockets, occupied boundaries, support facts,
and possible surface claims. They do **not** independently place the final floor beneath
each route unit. After the co-solved occupied/exterior channel is accepted, one
`PublicRealmSurfaceSolver` unions the channel's bottom boundaries into maximal
continuous patches and the assembler emits each patch once. This prevents cracks,
doubled planks, and uncovered grass without turning arbitrary space around the buildings
into a road.

Roles are data tags used for budgets and audits. They do not select separate collision,
support, or placement algorithms. The occupied-volume, exterior-air, and surface facts
seal into one `SettlementFabricPlan`; none may be projected independently.

### 4.1 Socket types

Only four geometric socket classes are needed:

- `WALK`: joins exterior public walk/headroom volumes, including address doors,
  facade stairs, galleries, terraces, and short open bridges. It records plane,
  outward normal, clear width, elevation, and exterior-air provenance, so unequal-height
  seams must declare the stair/ramp transition that joins them;
- `ROOM`: joins occupied building volumes, including upper stacks and outcroppings;
- `MARKET`: accepts a reviewed stall or awning frontage module;
- `BEARING`: names terrain contact, one or more supporting parents, or both ends of a
  span.

A projecting Weasley-like room is a `ROOM` bond plus one or more `BEARING` bonds. An
enclosed skywalk is an occupied room recipe with `ROOM` sockets and two bearing parents;
it may cover an exterior alley but does not expose public `WALK` sockets until interior
traversal is implemented. An exterior stair-facade recipe has two `WALK` sockets at
different elevations, owns the transition between them, and keeps its complete swept
volume outside every room shell. A whole prefab is a larger recipe with conservative
cell masks and reviewed address-door sockets. None requires a solver special case.

### 4.2 Surface and void classifications

Every lattice column clipped to the compact core and its bounded height envelope is
partitioned into explicit vertical intervals. Each interval is exactly one of:

- `PUBLIC_SURFACE`: the bottom boundary of a traversable channel: terrain street,
  structural exterior floor, stair, court, facade gallery, or short open bridge;
- `EXTERIOR_AIR`: player headroom above a public surface, connected through the solved
  exterior-air flood graph to the outside of all building envelopes;
- `INHABITED_VOLUME`: a room or occupied anchor volume;
- `DAYLIGHT_VOID`: a deliberately open court/lightwell with explicit boundary and
  guard facts;
- `OUTSIDE_CORE`: space not claimed by the dense settlement.

Interior passage and public enclosed-skywalk surface kinds remain reserved for a later
profile; they are not values this plan can emit. Each active surface must have
`EXTERIOR_AIR` directly above its complete swept player volume. Covered exterior air
may run beneath occupied volume, but it must remain connected to outside air without
crossing a door or room shell.

An interval cannot remain `UNCLASSIFIED` when the plan seals. `DAYLIGHT_VOID` is never
inferred merely because massing left a hole; the itinerary must reserve it before
buildings are grown. Likewise, the surface solver never fills arbitrary leftover space.
It fills only authored street/court regions, swept traversal corridors, portal
forecourts, and bounded seams explicitly claimed by adjoining episodes.

## 5. Module vocabulary

### 5.1 Modular inhabited fabric

The first curated set should contain:

- compact rock and timber ground rooms in straight, inside-corner, and outside-corner
  forms;
- meaningful maze-corner masses whose inhabited footprint crosses the incoming route
  tangent and forces the exterior street around a real building corner;
- wooden upper rooms with door, window, and closed variants;
- undercroft houses whose covered public air remains exterior and inhabited rooms lie
  above;
- exterior stair-facade houses with lower and upper address doors beside a guarded
  facade stair; no stair flight enters the room shell;
- courtyard blocks whose middle-storey public court is borne by inhabited rooms below;
- occupied bridge houses and enclosed skywalk rooms that span a narrow exterior alley
  while public circulation passes below or around them;
- switchback facade blocks whose exterior circulation wraps between occupied bays;
- short-perched, tall-grounded, and half-base-offset variants so neighboring houses do
  not share one foundation or roof datum;
- S/M/L floor and roof caps in both existing colour families;
- one-cell and two-cell projecting room recipes with visible braces;
- a corner oriel/turret, roof dormer, lean-to room, and tall chimney recipes;
- short door galleries and corner landings;
- half-rise and full-rise stair recipes with exact landings and guards;
- 3 m, 6 m, and 9 m enclosed occupied skywalk rooms with floor, walls/windows, roof,
  room-door clearance, and two bearing ends; they are overhead mass, not public paths;
- a small set of open curved/turning timber links for nearby facade sockets only.

Outcroppings change the occupied silhouette; pasted signs and props do not satisfy the
outcropping budget. Adjacent modules may project in different directions and bands, but
each recipe has fixed support geometry and validated clearance.

Every rectangular generated-house contract names local **Z** as its depth and roof-ridge
axis and local **X** as its transverse/eave width. The complete measured roof must be
strictly longer along Z than X before yaw; parcel and roof rotate together. A production
parcel may therefore be square or narrow/deep, never wider across its eaves than along
its ridge. Side facades are complete authored 3 m modules with their source-pack UVs;
their measured planes tile every declared side span exactly. Palette swaps, stretched
end panels, and untextured procedural side caps are not admissible repairs.

Roofs are not attached independently to every room during growth. After outcroppings,
bridge rooms, and adjoining upper bays are frozen, a `BuildingEnvelopeCompiler` derives
the connected roof planes, gable closures, dormer openings, and wall caps from the final
occupied envelope. Every exposed top or roof-end boundary must be covered or explicitly
declared as a court edge. This prevents the missing gable sides and intersecting partial
roofs seen in review captures.

### 5.2 Prefab building anchors

The source audit establishes this initial candidate pool:

- `FantasyVillageFBX`: twelve colour/design combinations. The useful measured
  footprints span roughly 12–19 m, with heights around 9–18 m. Compact designs
  001/003/004/006 are good bend or perch anchors; 002 is a tall accent; 005 is a large
  rare anchor.
- `AlchemyPackFBX`: buildings 001–003 are roughly 14.6 m square and 10–18 m tall. They
  are strong narrow landmark/tower candidates.
- `ForgeFBX`: two full building sources exist. Building 001 measures roughly
  19 × 22 × 16 m and fits an outer industrial bend or court, not a tiny alley bay.
- `TavernandKitchenFBX`: seven full building sources exist, but they share an enormous
  roughly 39 × 29 m ground envelope before the current bake correction. They must not
  be squeezed into the compact core. A larger-town profile may use one as an edge or
  terminal anchor; the common pack's windows, chimneys, signs, and attachments can
  diversify smaller generated fabric.

The runtime catalog already contains an Alchemy building, a Tavern building, eight
FantasyVillage houses, and six FantasyMarket stall structures. Forge buildings and
additional pack variants still require curation.

Every prefab must pass an admission gate before entering `SettlementFabricProgram`:

- one bake-time human-scale correction;
- conservative solid/occluder masks and true visual bounds;
- reviewed ground-bearing footprint;
- at least one doorway/facade socket aligned to a public route;
- structural collision that follows walls, floors, roof/support pieces, and entrances
  rather than a prefab-wide box;
- collision, doorway, front, side, rear, and roofline lineup captures;
- instance/triangle/collision budgets appropriate to its profile.

An asset that cannot meet those facts remains a visual reference, not an exception in
the solver.

### 5.3 Market vocabulary

`FantasyMarketFBX` contains complete Alchemy, Armory, Bakery, Butcher, Fabric,
Fishmonger, Forge, Fruit, and Tavern stall families plus colour variants. Their measured
widths span about 3.8–7.6 m, so the program compiles S/M/L market niches rather than
pretending every stall is a 3 m prop.

The first pass should bake one populated and one lightweight variant from as many
families as survive collision and performance review. A market recipe owns its canopy,
posts, counter, stock, solid mask, customer clearance, vendor clearance, and facade
socket. Repeated loose fish tables are dressing for a fish stall, not the generic market
module.

Markets occupy the lowest folded part of the public route, continue around at least
two bends, and preferentially sit beneath inhabited outcroppings or facade galleries.
They are never scattered outside the urban envelope.

## 6. Generation model: carve circulation first, compile construction second

One bounded deterministic transaction remains mandatory, but layout authority moves
upstream of recipes. The source plan is a classified volume; assets interpret a sealed
plan and may not change its circulation, add a disconnected platform, or repair a
failed boundary after the fact.

### Stage A — terrain-relative Gaussian height envelope

Sample immutable terrain into 1.5 m vertical bands beneath a 3 m horizontal planning
grid. Build an anisotropic Gaussian height field with broad deterministic warp and
correlated variation, then fill each column from its local natural-ground band to that
height. The result is tallest and densest near the center, tapers to one-band foundation
mass around the edge, and has a perimeter column where player headroom meets terrain.
Several blended lobes may be admitted later; independent cell noise and a flat-bottomed
rectangular prism are forbidden.

### Stage B — explicit volume classification

The source vocabulary is:

- `MASS`: possible inhabited or structural building volume;
- `WALK`: an abstract public floor at one elevation datum;
- `PUBLIC_AIR`: player-swept exterior headroom owned by a walk or transition; and
- `DAYLIGHT_VOID`: deliberate open space that is neither building nor platform.

`WALK` is a surface fact, not an empty voxel. Its headroom consumes `PUBLIC_AIR` above
it. Missing geometry never implies a platform or daylight void.

### Stage C — connected three-dimensional public-realm carve

Begin at a terrain-level perimeter entrance and grow a weighted randomized frontier
through the mass. Nodes live at `(x, band, z)`; all movement remains cardinal. A graph
edge may stay level or change by exactly one circulation band. A one-band change uses a
two-or-more-cell continuous ramp whenever its grade and swept clearance fit, otherwise
it uses a compact stair. Every perpendicular turn involving a vertical edge owns a full
square landing. The edge, endpoints, swept headroom, guards openings, and later visual
surface are one atomic record.

Candidate scoring rewards repeated X/Z neighborhoods at different elevations,
overpasses with legal headroom, alternating rises and descents, loops, short straight
runs, central winding, and exterior-air-connected alleys. It penalizes aligned
corridors, excessive constant-height travel, route/headroom self-intersection, footprint
growth, deep vertical shafts, and boundary-to-boundary sightlines. Bounded complete-plan
selection chooses among sealed candidates; no authored helix schedule or fixed town is
a fallback.

### Stage D — coherent mass pruning

Only after circulation is sealed may mass become `DAYLIGHT_VOID`. Pruning removes
correlated orthogonal blocks or future parcels, never independent salt-and-pepper
voxels. It must preserve route enclosure, addressable frontage, structural ancestry,
roofable residual shapes, central vertical occlusion, and every declared overpass.
Useful results include narrow courts, lightwells, silhouette setbacks, and outer-edge
porosity. Every lightwell touching public surface has a complete derived guard.

### Stage E — orthogonal parcelization and addressing

Partition remaining useful mass into connected, roofable orthogonal parcels. A parcel
may consume several planning cells and several vertical bands, but every building
component and every externally inhabited floor owns a facade threshold adjacent to a
real `WALK` surface. Large buried regions are not buildings merely because mass remains.
Exact-cover/beam decomposition prefers narrow/deep houses, shared party walls, varied
base and roof datums, corner overlaps, and occupied volumes above lower routes.

### Stage F — situational asset and shell compilation

Match parcels against compiled contracts for footprint, height, entrances, facade and
party-wall sockets, roof interfaces, support footprint, visual clearance, and material
family. A reviewed prefab may replace a parcel group only when all contracts match;
modular shells fill the remainder. Outcroppings are part of the parcel footprint before
roof solving, so they become shallow roofed bays or corner overlaps rather than attached
cubes. An upper route span becomes an open skywalk, platform bridge, or occupied
bridge-house according to its sealed walk/mass relation—it is never scattered later.

The ground portion of the route receives only complete reviewed `stocked_market`
recipes along bounded alley frontages. Plain tents and loose-table fallbacks remain
ineligible.

### Stage G — surfaces, roofs, joins, and bearing

Union coplanar `WALK` cells into platforms and courts while retaining transition spans
and explicit lightwell holes. Terrain-aligned walk uses terrain; higher walk compiles to
plank platforms, ramps, stairs, or short bridges. Visual mesh and collision derive from
the same surface payload. Exposed edges derive guards except at frozen graph seams.

Shared walls have one owner. Roof runs are solved over the final parcel shape with
typed ridges, eaves, gables, valleys, and end seams. Every elevated surface or parcel has
an acyclic load path through terrain, inhabited mass, a two-ended span, or sparse
reviewed supports that do not obstruct lower circulation. Nothing is stretched or
nudged to conceal an invalid seam.

### Stage H — seal and migrate atomically

The compiled plan must pass volume connectivity, rise/landing/grade constraints,
surface and threshold closure, exterior-air provenance, parcel addressing, visual
clearance, support ancestry, roof closure, traversal, enclosure, horizontal and
vertical anti-sightline, asset diversity, exact terrain/water, performance, and
adversarial screenshot audits. A failure rejects the complete transaction. Production
now uses the sealed volumetric transaction when the common vocabulary is available. Any
failed volume, construction, or exact audit rejects that transaction; the older
terrain-led solver remains an explicit custom-fixture path and is never mixed with
volumetric output.

## 7. Hard acceptance invariants

Initial values are visual-slice targets and may only be relaxed with reviewed evidence:

### Volumetric source plan

- the envelope begins at the exact local natural-ground band in every column and its
  broad height tendency decreases toward the perimeter;
- one terrain-level perimeter `WALK` cell connects the complete public graph to the
  outside; every public-air cell is reachable from that entrance through swept route
  volume without crossing mass;
- every graph edge changes elevation by at most one 1.5 m circulation band;
- a vertical transition with sufficient run compiles as a continuous ramp; a compact
  stair is legal only when that run cannot fit or exceeds the traversal grade;
- every perpendicular pair involving a vertical transition owns a square landing;
- transition endpoints, visual surfaces, collision, and guards derive from one record,
  with zero detached endpoint or missing-lane count;
- at least 45% of inner-core walk length lies below higher `MASS` or `WALK`, and a
  meaningful subset consists of different-height route revisits rather than a flat
  ceiling token;
- every future building component has at least one addressable mass boundary adjacent
  to `WALK`; no detached or entirely buried mass becomes a building;
- at most 10% of inner-core columns admit an unobstructed top-to-terrain ray, excluding
  declared bounded lightwells; and
- seed corpora have unique raw-envelope, public-graph, parcel, and construction
  signatures. Palette/material changes do not count as geometric diversity.

### Connectedness and sectional progression

- clear public corridor: at least 2.4 m at every route sample;
- maximum straight route run between meaningful bends: 9 m;
- maximum constant-elevation run inside the core: 12 m;
- every public node, surface patch, and exterior address landing belongs to one
  traversal component rooted at the route landing;
- every consecutive primary-itinerary episode shares a real portal and continuous
  collision-bearing surface; proximity is not connectivity;
- at least six half/full-level changes in the fixed town slice, spanning at least 9 m
  between its lowest and highest public surfaces;
- at least one up → down → up sequence;
- public surface inside an `INHABITED_VOLUME` interval: exactly zero;
- every public stair and its complete swept headroom lie outside room shells, and that
  headroom belongs to the exterior-air flood component;
- at least two route episodes pass beneath genuine occupied volume while remaining in
  the outside-air component;
- at least one graph loop reconnects through a nonzero elevation change;
- the primary itinerary itself reaches an elevated court and passes beneath or beside
  an enclosed occupied skywalk; these may not exist only on optional branches;
- every stair has valid lower/upper landings and continuous guards.
- every stair exposes the complete player-width lane set at both its low and high seam;
  a visually touching stair with a missing lane is rejected;
- every visible exterior door owns one typed threshold, an exact adjacent landing on
  the solved public-surface union, and a guard opening derived from that same record;
  unserved doors compile as closed/windowed facade bays.

### Surface and void closure

- the union of public-surface claims completely covers every authored street, court,
  landing, stair, exterior gallery, and short-bridge footprint;
- every adjacent pair of surface patches either shares identical boundary vertices or
  is joined by an explicit stair/ramp transition;
- no public region exposes terrain grass, an uncovered support top, a sub-cell crack,
  or overlapping coplanar floors;
- every compact-core interval is `PUBLIC_SURFACE`, `EXTERIOR_AIR`,
  `INHABITED_VOLUME`, `DAYLIGHT_VOID`, or `OUTSIDE_CORE`; `UNCLASSIFIED` count is zero;
- every public swept-headroom cell belongs to the exterior-air flood component;
- no exterior-air proof crosses a closed door, wall shell, floor, roof, or window;
- every `DAYLIGHT_VOID` was reserved before massing and has complete walls/guards at
  each public edge;
- every structural court/platform satisfies its declared bearing-parent count before
  it contributes any public surface; supports cannot be added later as visual repair;
- terrain paint, visual mesh, and collision derive from the same solved surface
  boundary and therefore cannot disagree about coverage.

### Enclosure and sightline

- at least 85% of eligible inner-route side length has occupied facade, corner, stall,
  or stair frontage;
- no unplanned lateral opening wider than 3 m inside the core;
- 45–65% of inner-route length lies beneath an inhabited outcropping, enclosed
  skywalk, or occupied room volume;
- explicit open-sky courts interrupt overhead cover every 12–18 m;
- entry and terminal route nodes never have mutual eye-level visibility;
- from every route node, sample at least 24 horizontal directions at 1.6 m above that
  node's public surface. A ray may not traverse 12 m of inner core and leave the
  opposite boundary without hitting a qualifying occupied occluder;
- sample non-adjacent pairs on a 3 m-spaced boundary ring at every reachable public
  eye-height band. A boundary-to-boundary chord whose middle crosses the inner core
  must hit qualifying occupied mass before reaching its far endpoint;
- audit terrain-street chords separately from the aggregate multi-level ray set. An
  accepted exact town has at most 12 hostile ground-level through-core chords; dense
  upper galleries cannot hide a straight lower street;
- tangent visibility along the public route is at most 12 m;
- a meaningful bend exists only when qualifying occupied mass overlaps the forward
  continuation of the incoming corridor and physically forces the route around it;
- no freestanding wall, screen, prop, foliage, stall back, or rail may satisfy a
  through-core chord or meaningful-bend requirement.

Occlusion uses recipe-owned conservative visual masks, not physics boxes. A qualifying
occluder is at least one 3 m bay deep, spans the player-eye band, belongs to a supported
and roof-closed inhabited recipe, and has a valid exterior address relationship.
Windows may be treated as occluding in v1; open door/headroom cells may not. These
requirements turn the see-through test into a consequence of inhabited massing rather
than a target that can be gamed with token blockers.

### Staggered height distribution

- the fixed proof uses at least five distinct 1.5 m building-base bands and at least
  five distinct roofline bands across its inhabited anchors;
- no 3 m-tall base window or roofline window contains more than 40% of core anchors;
- at least half of neighboring core-building pairs differ in base height by at least
  one half-level, and at least one quarter differ by a full level or more;
- exterior address landings occur at no fewer than four elevations;
- the mix includes at least two low terrain-grounded houses, one tall grounded house,
  two short perched houses, and inhabited mass beginning in both middle and high bands;
- an upper house needs terrain, retained, or inhabited bearing proved independently;
  a post stack cannot be introduced merely to satisfy the histogram;
- a three-or-more-storey proposal is admitted only after an already-complete lower
  neighboring roofline exists. Exact selection rejects any remaining tall stack without
  a descending occupied neighbor, so central height cascades through successively lower
  houses toward terrain instead of ending as one uniform shaft;
- base and roof histograms are sealed-plan invariants, not scoring preferences that a
  later repair pass may waive.

### Stacked occupied fabric

- every occupied-overhead counted cell belongs to a room or enclosed skywalk recipe;
- the separate vertical-coverage metric may also count a connected upper public surface
  crossing a lower route column;
- a town has at least two enclosed skywalks and at least four projecting room recipes;
- at least 40% of core building anchors carry a meaningful outcropping;
- at least 35% of occupied horizontal core columns contain public or inhabited content
  in two or more elevation bands, and at least 10% contain it in three or more bands;
- at least one elevated public court is supported primarily by inhabited volume below
  and serves multiple doors or onward transitions;
- skywalk spans are 3–9 m and join two inhabited sockets;
- enclosed skywalks contribute overhead occupied mass but no public traversal surface
  in the exterior-maze profile;
- an open gallery or deck is at most one module deep unless a building occupies it;
- optional 3 m gallery infill may never complete a 2 × 2 macro-tile floor when unioned
  with the sealed route and previously accepted infill. Across the town, structural
  infill is capped at 16 macro patches, of which at most 10 are optional. The exact
  fine-grid audit permits no more than eight structural-court cells surrounded by floor
  on all four sides; this distinguishes long narrow paths from empty suspended plazas;
- multi-patch upper networks retain separated fenced 1.5 m daylight openings. A hole is
  a typed subtraction from a connected supported surface, never missing floor geometry;
- every close-facing core building pair is joined by a shared seam, common public
  region, bridge/skywalk, occupied overhang relation, or explicit daylight court;
- every non-terrain unit follows an acyclic bearing chain to terrain; a span has two
  independent bearing ends;
- a unit marked terrain-bearing intersects its proved terrain support footprint;
  elevated courts borne by lower rooms are never mislabeled terrain-bearing;
- every exposed top boundary has a compiled roof/floor cap, and every roof end has a
  gable/wall closure unless it is an explicit court boundary.

### Asset and market diversity

- the fixed proof slice uses modular generated fabric plus prefab anchors from at least
  two full-building source families;
- the procedural town profile targets at least three building designs and two source
  families when the site/budget permits;
- the market contains at least four themed stall families, with no adjacent identical
  recipe;
- the warren profile emits zero plain/fringe tents.

## 8. Simplified code architecture

Production code remains under `scripts/terrain/features/villages/fabric/`:

```text
WarrenVolumeEnvelope          terrain-relative warped Gaussian construction mass
WarrenPublicRealmCarver       bounded connected 3D exterior-route search
WarrenVolumeTransition       atomic level/ramp/stair endpoint and swept-air contract
WarrenVolumePlan              sealed MASS/WALK/PUBLIC_AIR/DAYLIGHT_VOID source truth
WarrenMassPruner              coherent daylight courts, setbacks, and lightwells
WarrenParcelizer              roofable orthogonal addressed building envelopes
WarrenVolumePublicRealmAdapter lossless 3 m to two-lane 1.5 m topology adapter
WarrenTransitionSurfaceBuilder collision-bearing stair/ramp spans and side guards
WarrenVolumeSurfaceCompiler   route/solid/entrance-derived public surface transaction
WarrenAssetCompiler           situational prefab/modular construction selection
FabricModuleProgram           compiled seam, datum, envelope, and material contracts
FabricVolumeClassifier       exhaustive intervals and exterior-air flood proof
PublicRealmSurfacePlan        platform/ramp/stair union, closure, holes, and guards
BuildingEnvelopeCompiler      shared walls, joined roofs, and support ancestry
SettlementFabricAssembler     expands only an accepted plan into feature placements
```

These are responsibility boundaries, not independent generation passes. Internal
records remain resource-free plain data. `WarrenVolumePlan` is the single spatial
authority. Pruning and parcelization may classify its remaining mass, but cannot alter
the sealed public graph. The classifier and surface/envelope compilers prove and
materialize that decision; they cannot add mass or reroute around a failure. The
assembler never guesses missing floors, supports, walls, roofs, or exterior connections.

`SettlementStreetPlan` is removed. The fixed review composition belongs to the harness
as data and uses the same recipes/plan validator; a production program must not contain
a hard-coded `review_town()`.

`SettlementFabricPlan.validate()` owns all common correctness:

1. recipe and socket existence;
2. ordered-itinerary portal continuity and public graph reachability;
3. exact solid/surface/headroom occupancy compatibility;
4. surface union closure, exhaustive interval classification, and exterior-air
   provenance for every public swept volume;
5. parent-before-child acyclic ancestry to terrain and two-ended span bearing;
6. exact walk/threshold continuity, visual-envelope clearance, compatible building
   joins, and roof-run/gable closure;
7. staggered base/roof distributions, enclosure, stackedness, overhead occupancy, and
   anti-chord invariants;
8. stable ordering, bounds, and deterministic signature.

The solver contains no asset-id conditionals. Asset-specific measurements and seam
declarations are compiled once by `FabricModuleProgram`; layout code consumes only the
resulting typed profiles. Adding a new building, stall, outcropping, or skywalk means
compiling another contract and recipe that satisfy the common validator.

## 9. What is reused and what is removed

### Reuse

- `VillageFrame`, `VillageRecord`, `VillageTerrainView`, `VillageOccupancy`, immutable
  projection, feature cache, and commit contracts;
- `TraversalEnvelope` and exact terrain/water sampling;
- reviewed modular wall/roof/floor/stair/railing assets and valid primitive collision;
- `FabricRecipe`, socket matching, typed occupancy, and bearing ancestry as generic
  proof mechanisms rather than layout policy;
- environment bake/catalog/render infrastructure;
- deterministic stable-id and parent-before-child record ordering;
- the screenshot capture/review pipeline after its camera set is replaced.

### Replace before further visual iteration

- `WarrenPlotVoidGrammar` fixed action schedules as the production source of route
  geometry;
- `StaggeredFabricEmbedder` as the first authority for building placement around an
  already-selected route;
- `WarrenOverheadSolver` as a post-hoc source of skywalks and outcroppings; overhead
  relationships must already exist in the volume plan;
- fixed straight `path_sections` and `SettlementStreetPlan`;
- one visual floor placement per `route.straight`/`route.corner` unit;
- generic `terrain_bearing` on route floors and hand-authored columns beneath them;
- independently authored skywalk branches added after the main route;
- same-height passage shells and interior stair-houses used as substitutes for
  exterior circulation;
- repeated fixed 6 × 6 row-block emission;
- open-railed bridge-only spans;
- table-first market emission;
- every `TENTS`/`add_tent`/`_emit_tents` path and tent-count assertion;
- rectangular harness terraces and tent-specific cameras;
- count-only path/junction/elevation audits.

### Retire from production after parity

The earlier `VillageMassing*`, independent circulation/aerial/platform/support repair
pipeline, and legacy elevated-district path remain retirement targets from the previous
spec. The new fabric solver must replace them transactionally; the algorithms are never
mixed as fallbacks.

## 10. Structural and visual proof gates

First prove the procedural source volume without rendering: a fixed diagnostic seed
and a broad seed corpus must pass envelope taper, public-air connectivity, transition,
landing, overhang, frontage, vertical-shaft, and signature-diversity gates. The source
plan may then compile one pinned seed through real assets on an uneven terrain site. A
hand-authored fixed route is diagnostic evidence only and cannot become a production
fallback.

This harness composition is deliberately fixed and is not evidence of seed-varied
generation. Deterministic gap embedding inside the fixture remains a regression aid.
The feature becomes procedural only when a world seed changes itinerary, band, asset,
and adjacency candidate ordering while every accepted result still passes the same hard
contracts.

The proof occupies at most a **36 × 36 m** core but contains a **60–90 m** traversed
public itinerary because it folds above, below, and beside earlier segments. The player
must encounter, in order:

1. a ground market alley continuing around two bends;
2. an inhabited overhang and undercroft;
3. an exterior stair canyon bounded by occupied facades;
4. a reversal around a building corner onto a half-level facade terrace;
5. an exterior switchback rising to a structural courtyard supported by inhabited
   rooms;
6. a turn beneath or beside an enclosed occupied skywalk, continuing along an exterior
   facade gallery;
7. a half/full-level descent through a narrow facade-bounded gap;
8. a second exterior stair wrapping a short perched house to another terrace; and
9. an undercroft or short open link that reconnects toward the market without entering
   any building.

The slice must also contain:

- 15–16 inhabited anchors satisfying the complete five-base-band and five-roof-band
  distribution contract;
- at least six vertical changes and one descent after a rise;
- a market continuing around two bends with at least four themed
  `FantasyMarketFBX` stall families;
- continuous modular facade fabric plus at least two prefab building families;
- at least four supported projecting rooms;
- at least two enclosed occupied skywalks or bridge houses above exterior air, with the
  primary itinerary passing beneath or beside at least one of them;
- at least one inhabited room over a market stretch;
- one elevated court that reads as local ground and serves at least three onward
  facade/route relationships;
- short facade galleries/curved timber links where doors require them;
- zero plain or fringe tents and zero empty suspended platforms.

The proof fails if any audited public-height chord sees through the core, if any public
stair or route segment enters a room shell, if the route reads as one flat street with
elevated branches, if the inhabited bases collect around one upper datum, if a skywalk
reads as an unrelated open bridge, if a higher court exposes accidental grass or
incomplete flooring, if prefab assets read as unrelated objects, or if the town depends
on an overview to communicate its vertical structure.

## 11. Verification

### Asset admission

For every new recipe family, capture front, rear, side, doorway, underside/support, and
collision-overlay views. Depth-test collision views must expose proxy material only
outside the rendered mesh. Walk the real capsule over every exterior stair, undercroft,
gallery, landing, and short bridge. Door sockets are checked as address endpoints; the
capsule does not enter a building or occupied skywalk in this phase.

### Automated layout tests

- recipe/socket compilation and invalid-bond rejection;
- deterministic itinerary/embedding ordering and shuffled-query signatures;
- ordered exterior episode/portal continuity across unequal-height address bands;
- exact occupancy/headroom conflicts;
- exact floor/threshold/stair walk-plane agreement within construction tolerance;
- roof repeat/end-cap seam closure, continuous material phase, and zero untyped roof
  overlap;
- disjoint hard/collision/visual envelopes except at explicitly compatible joins;
- maximal surface-union coverage, shared patch boundaries, and no coplanar overlap;
- exhaustive interval classification, exterior-air flood provenance, and zero public
  surface inside inhabited envelopes;
- parent-DAG and two-ended span ancestry;
- terrain-bearing truth and inhabited-bearing elevated courts;
- primary-itinerary, loop, surface, and door reachability;
- roof/gable/exposed-envelope closure;
- straight-run, level-run, meaningful occupied-bend, frontage, overhead-cover, and
  daylight-court limits;
- base/roof height histograms, neighboring-base differences, stacked-column, and
  close-building relationship quotas;
- route-node ray fans plus multi-height boundary-ring chord rejection, including tests
  proving props and freestanding walls cannot qualify as blockers;
- asset-family, stall-family, and no-tent invariants;
- exact terrain/water support and record bounds.

### Adversarial screenshot review

For the fixed proof and then a multi-seed corpus, capture:

- every approach and exit;
- both directions at every bend;
- before, on, and after every vertical transition;
- beneath and beside every projecting room;
- below, beside, and beyond every enclosed skywalk;
- market frontage, courts, facade galleries, side silhouettes, and rooflines;
- eye-level views from every route node selected by the sightline audit;
- 3 m-spaced boundary-ring views at every reachable public eye-height band, plus one
  high overview for diagnosis only.

Also capture a top-down maze diagnostic, two orthographic sections through the densest
stacked columns, a base/roof height-band diagnostic, and one classified-volume render.
That render uses distinct colours for inhabited mass, exterior air, terrain streets,
structural courts/platforms, exterior stairs, bridges, and daylight voids; any
unclassified interval is bright magenta and any public interior cell is fluorescent
red. A sequential first-person capture follows every primary-itinerary checkpoint so a
reviewer can verify that the apparent route before a transition is the route reached
afterward without an interior shortcut.

The real player capsule (or an identical harness body) must traverse the primary
itinerary in both directions and one level-changing loop. The traversal report records
the exact failing edge/portal rather than reporting graph reachability alone.

The reviewer receives the explicit instruction: **the review is successful when it
finds a real issue**. Every image receives exactly one `clear`, `suspicion`, or `finding`
disposition with seed, settlement id, unit/recipe ids, and camera id. Findings are fixed
or deliberately accepted before the next phase. Final closure uses fresh seeds and a
fresh critical review pass.

### Corpus and performance

After the fixed slice passes, generate at least 25 varied sites and screenshot at least
10 representative accepted towns across terrain/biome conditions. Record acceptance
rate, route length, bend/elevation histograms, stacked-column ratios, surface/void
closure, exterior-air provenance, base/roof distributions, relationship closure,
through-core ray failures, frontage, overhead coverage, prefab/stall diversity,
instance counts, collision counts, commit time, and memory.
Performance budgets are frozen before production integration.

## 12. Implementation phases

1. **Seal the volume vocabulary:** implement terrain-relative Gaussian envelope,
   explicit mass/walk/public-air/daylight-void facts, atomic transitions, deterministic
   signatures, and rejection diagnostics.
2. **Prove the public-realm carver:** run broad flat and synthetic-terrain corpora for
   ground entry, connectivity, one-band rises, ramp preference, stair landings,
   elevation diversity, overhead mass, addressable frontage, horizontal winding,
   vertical shafts, and seed diversity.
3. **Implement coherent pruning:** cut bounded courts, setbacks, edge porosity, and
   guarded lightwells while preserving occlusion, bearing opportunity, and roofable
   residual mass.
4. **Parcelize and address mass:** decompose usable mass into variable-size orthogonal
   building envelopes, select exact exterior thresholds, reject detached/buried parcels,
   and establish party-wall and occupied-overpass relationships.
5. **Compile situational construction:** match prefabs and modular shells by their
   common contracts; solve shallow/corner outcroppings as parcel geometry, interpret
   sealed upper spans as platforms/skywalks/bridge-houses, and build joined roofs.
6. **Compile exterior surfaces and bearing:** union terrain streets, plank platforms,
   ramps, stairs, landings, courts, bridges, holes, collision, guards, and acyclic
   supports from the same source facts. Run exact endpoint and player-capsule tests.
7. **Render one pinned terrain proof:** capture every transition, address, crossover,
   undercroft, lightwell, platform seam, roof join, and support from first-person and
   section cameras. Iterate until the falsification-seeking review finds no unresolved
   issue.
8. **Run procedural visual corpus:** generate at least 25 varied terrain sites, capture
   at least 10 accepted settlements, require distinct envelope/route/parcel/construction
   signatures, and critically review horizontal and vertical see-through behavior.
9. **Migrate transactionally:** switch `VillageWarrenFabricSolver` to the volume
   compiler only after structural, traversal, screenshot, performance, and fresh-seed
   gates pass. Remove the route-first grammar/embedder/overhead pipeline only after
   parity; never use it as a partial fallback.

## 13. Explicitly deferred

All building interiors and public interior traversal, including stair-houses, enclosed
passage buildings, and traversable occupied skywalks; arbitrary free-angle placement;
deforming natural terrain; abstract load simulation; long suspension bridges; giant
uninhabited decks; runtime building damage; NPC market operation; far-distance
impostors; rural camp and festival tent profiles; unrestricted cross-pack material
recolouring.
