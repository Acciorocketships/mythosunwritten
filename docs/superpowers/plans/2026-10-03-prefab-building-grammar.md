# Prefab-derived building grammar

Owner direction: Pure Village and Suntail authored houses must be expressible
by the generator, not merely inspire a few decorative additions. New samples
must use the same construction rules. This extends the October 1 redesign.

## Acceptance contract

Every reference prefab gets a derivation from reusable structural rules and
native modules. Replaying a derivation must reconstruct geometry, transforms,
material assignments, openings and exterior closures at native scale. Loading
a complete prefab or recording an arbitrary list of all its pieces does not
count as a generalized grammar. Exact component recipes are the benchmark,
not the final generative representation. Pack-specific features need their own
rules; do not force both packs into the existing two-metre lattice.

Novel samples use deterministic seeds, share those rules, and fit a reserved
building envelope with public clearance and support. Keep style decisions at
building/wing level, coordinated primary, secondary and trim materials, and
allow explicit accents. No arbitrary incompatible piece substitution.

## Ordered work and gates

1. **Reference corpus and provenance.** Inventory every regular Pure Village
   house and Suntail house. Extend to warped Pure Village variants separately;
   do not treat their deformation as assembly errors. Map each mesh to native
   modular geometry, its local coordinate system, material family and hierarchy.
   Resolve unmatched components explicitly. Keep a portion of the houses out
   of rule tuning, then test whether the grammar can reconstruct them.
2. **Construction interfaces.** Measure wall endpoints, returns, corner and
   opening boundaries; floor/beam bearing planes; roof ridge, eave, verge and
   valley seams; turret body/cap seats; arch springing and apex; balcony/oriel
   backs, support brackets and complete closures. Bounds proximity only suggests
   a connection: inspect triangles and native rendered examples to confirm it.
3. **Reusable rules and derivations.** Model room volumes and supported upper
   offsets first, then exterior facade bays and openings, then a connected roof
   graph, then dependent details. Distinguish end/middle/corner panels and
   shallow/full roof courses. Stone arches belong to real door, window, arcade
   or passage assemblies with matching returns and supporting piers. Corner
   towers are part of the host's floor/wall/roof topology. Derive each reference
   using shared rules; unexplained pieces are coverage failures, not exceptions
   hidden in a prefab-specific renderer.
4. **Reconstruction gate.** Compare reconstructed references from every side
   and above, with matching lighting. Check missing/excess triangles, seam
   gaps, inverted/missing sides, materials and doorway/collision clearance.
   Preserve intentional authored overlaps; reject exposed penetration and
   z-fighting. Record failures by rule family and reference.
5. **Constrained sampler.** Sample volumes, wings, setbacks, bays, corner towers
   and roof graphs jointly. Changes in width/depth/height must update all
   dependent junctions, supports, closures and trim. Start within measured
   native dimensions; enable new spans only after junction tests. Test novel
   combinations and held-out houses, not only replayed examples.
6. **Town integration.** Let the planner reserve the grammar's real envelope,
   including eaves and projecting rooms. Mixed-pack neighbors can share a
   structural interface without forcing identical module dimensions. Validate
   in isolation AND in full-town context, then player traversal, deterministic
   multi-seed/holdout surveys and performance. Do not replace known-good
   production families until the relevant reconstruction and novel-sample
   gates pass.

## Reopened screenshot defects

The October 3 Pure Village corner-wing image is not accepted. Track separately:
- Hood/oriel roof penetrates its host eave: choose a compatible integrated
  opening or move/resize the whole projection assembly, not clip it arbitrarily.
- Disconnected crossing rooflines: identify host/branch graph and construct
  continuous valleys, ridges, gable closures and flashings from native pieces.
- Exposed missing side: determine whether it is a genuinely unsupported/open
  room or an artifact of isolating a town building after neighbor culling.
  Test both contexts. A deliberate porch/loggia needs posts, returns, soffit
  and appropriate rails; absence must not be justified merely by naming it.
- Flush lower eave: reserve native overhang and end closures. If public
  clearance disallows it, change the building/roof composition upstream.

The earlier geometry audits are necessary but do not establish visual quality.
Reproduce the reported 7/standard landmark and retain matched before/after
cameras. User rejection supersedes the earlier corner-wing visual assessment.

## Initial evidence (October 3)

Implemented `tools/building_grammar/audit_prefab_vocabulary.py`: exact vertex
attributes and topology lookup against modular GLBs, independent of mesh names,
with stride-aware accessor reading. Four tests pass. Materials and transforms
are intentionally not yet treated as proven by geometry identity.

Pure Village regular houses:49,5905 mesh instances;5899 match native Architecture
modules,47 houses have complete geometry lookup. Six unmatched quads belong to
StoreFacade2 window-glass assemblies in House_6b and StreetHouse_8c (one uses
Default-Material). They need explicit source handling, not deletion.

Suntail eight authored houses from the primary checkout:3003 mesh instances;
2600 match Building_Modules or Props. Remaining geometry identity failures
must be investigated; no claim of complete Suntail reconstruction. The primary
checkout was read only. Compact evidence is under
`docs/qa/2026-10-01-town-redesign/prefab-grammar/`.

No production building changes are claimed by this inventory pass. The four
reported visual defects and grammar implementation remain open.


## First screenshot repair

Equal-width gable continuations now align and merge with their host ridge.
Native matched views show a continuous main roof on the reported landmark.
New2tests14assertions, existing9junction tests12002assertions, eight-town
clearance/floating checks pass with unchanged cover. Missing side proved to
be a neighbor-culling isolation artifact; harness now supports `--context`.
Lower eave and general hood sockets remain open. See
`docs/qa/2026-10-01-town-redesign/prefab-grammar/roof-continuation-result.md`.


## Owner follow-up: download-2.png

Track the latest seven observations explicitly in
`docs/qa/2026-10-01-town-redesign/prefab-grammar/side-eaves-result.md`.
Production now excludes single-storey tower hosts and fits eaves per side.
Corrected complete-context rendering restores omitted public decks/bridges;
that explains hollow terrace tops but does not accept the protruding blocks,
material transitions, gable seam or canopy joins.

## October 4 repair checkpoint

Native stone/plaster gable sills, whole-hood roof admission, coherent native
half/full support masonry and timber-only upper corner beams are implemented.
See [evidence](../../qa/2026-10-01-town-redesign/prefab-grammar/october4-facade-repairs/result.md).
The shed canopy still needs a connected run/corner grammar. StreetHouse_7's
native corner and middle-piece poses have been measured. Do not mark this
checkpoint or the full reconstruction/generation contract complete.

Outer shallow-canopy corners now use a source-derived connection rule and
native corner modules, with complete-run and connection clearance. Native
fixture and 7/standard town views inspected; six tests pass. Inward canopy
junctions remain open; measured House_10 evidence is in
[the corner review](../../qa/2026-10-01-town-redesign/prefab-grammar/october4-hood-corners/result.md).

October 4 inward-corner follow-up: same-height accepted inward runs now use
native valleys with reserved 1.5m seams; the source transition fin is excluded
while retaining authored tiles/timber. Eight tests/125 assertions and native
renders pass. Blocked/short/unequal canopy terminations and broad overhangs
remain open. Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-hood-inner/result.md`.

October 4 connected canopy datum: height adjustments now propagate within
shared-endpoint courses, enabling the native hip at the reported raised-front
corner. Nine tests and native close-up pass; eight towns have zero structural
floating/main-roof air violations. The close-up exposes rear dormer timbers
above the foreground roof, still unresolved. Evidence:
`docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-hood-height/result.md`.

October 4 dormer repair: House_11c's overlay/continuous-host connection now
replaces the framed replacement panel that exposed a rear batten. All four
palettes and tight/normal eaves rebuilt; source glazing and host tiles verified.
Matched town and palette fixtures inspected; 13 focused tests and production
check pass. Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-dormer-connection/result.md`.

October 4 cantilever progress: native curved supports now connect eligible
one-module rooms to lower wall joints, with whole-piece admission and six
passing tests. The reported house.004 floor8 projects two modules (~8 world
metres); that larger wing is NOT resolved by these supports. Its structural
room/support composition is the next open item. Evidence:
`docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-cantilever-supports/result.md`.

October 4 large-wing support correction: the native four-post frame was already
reserved by the planner and erased by kit replacement. Retaining its recipe
restores the reported wing's support without moving rooms or routes. Eight towns
retain zero structural floating/main-roof air violations; the actual player
reaches the covered destination and returns. Regression: 77 assertions pass.
Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-arcade-supports/result.md`.

October 4 native grammar foundation: `PureVillageNativeRoof` derives a full
native straight/curved roof and matching closures from ridge-bay count and wall
datum. It reconstructs House_1 and House_4 roof/gable geometry, UVs and materials;
3 tests / 1954 assertions and matched native renders pass. Novel lengths retain
closed ends. This is not whole-house reconstruction or production integration.
Next: native wall/floor volumes and dependent openings, then connected roof
junctions and corner towers. Evidence:
`docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-native-roof-rule/result.md`.

October 4 native house rule: full House_4 now reconstructs from ridge-bay count
and shared wall/foundation/head/corner rules. Complete-panel opening choices
include source-aligned Door_9_1 (native stone arch) and stone-backed Window_14_1;
a deterministic stone sampler coordinates entrance foundation and material
family. Six tests / 3843 assertions and matched native full-house renders pass.
The blank House_4 shell is only a reconstruction benchmark; compound features
and production integration remain open. Evidence:
`docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-native-house-rule/result.md`.

October 4 projecting-room interface: `PureVillageJetty` derives the native
StreetHouse_1 front, split underside, brackets and short returns, with explicit
host/roof obligations and shared-side ownership. Eight source meshes match;
3 tests / 79 assertions and native source/replacement views pass. The rest of
the host remains a source prefab in this review, not a derived house. Next:
short-cornice roof/end-cap and host topology rules for this projection. Evidence:
`docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-native-jetty-rule/result.md`.

October 4 full projecting house: `PureVillageJettyRoof` coordinates native
long front verge/ridge caps with the projecting gable; `PureVillageStreetHouse`
now derives the complete StreetHouse_1 from two native longitudinal bays. No
reference prefab is loaded by either rule. Six reconstruction tests / 6112
assertions and 348 triangle coverage probes on three lengths pass; matched
native views inspected. Plain reference side walls are benchmark fidelity,
not approved production sampling. Next: compatible opening variation and
compound roof/room junctions, corner towers, and full native envelope integration.
Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-native-street-house/result.md`.

October 4 facade sampling: the native street-house rule now exposes only valid
middle-bay sockets and chooses coordinated window families deterministically.
A rendered upper-window/eave conflict was rejected and pinned with actual-glass
ray tests; high narrow windows are lower-storey only in this roof family.
Reference reconstruction is unchanged. Next: multi-volume/compound roof rules
and corner towers; this sampler is not production integrated. Evidence:
`docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-street-facades/result.md`.

October 4 compound roof junction: `PureVillageCrossRoof` derives House_5's
roof from four native valley corners and dimensioned whole-bay arms. Seven
reconstruction tests / 7490 assertions and 2332 sampled triangle coverage
checks pass; native source/reconstruction and extended-wing views inspected.
This is roof skin only, not a complete house or production rollout. Next:
derive matching gable/attic and room closure, then corner-tower connections.
Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-native-cross-roof/result.md`.

October 4 cross-gable closure: the compound roof now carries the four native
House_5 gable assemblies, including the different long/short cap seats. Seven
reconstruction tests / 7874 assertions and two coverage tests / 2412 assertions
pass. Extended native views inspected. Remaining: short eave-side attic walls,
ground-floor/foundation topology, compatible openings and production envelope
integration. Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-cross-gables/result.md`.

October 4 compound attic sides: native short walls now follow the cross-roof
arm lengths, completing its side and gable perimeter above the host. Seven
reconstruction tests / 8070 assertions and three coverage tests / 3996
assertions pass; native extended eave views inspected. Lower host/foundation,
openings, corner towers and production integration remain. Evidence:
`docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-cross-attic/result.md`.

October 4 compound host: `PureVillageCrossHouse` derives House_5's ground-floor
walls together with the roof/attic. Eight reconstruction tests / 10400 assertions
and four coverage tests / 6732 assertions pass. Native review caught missing
extended-wing corner trim; outer end panels now move outward while new middle
bays insert behind them. Foundation and opening sampling remain, as does town
integration. Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-cross-host/result.md`.

October 4 compound openings: complete middle-wall sockets support two coherent
native window families and the plaster/timber Door_3_1. Twenty seeded layouts
retain corners and roof poses; real glass-to-roof clearance checks and native
views pass. End-panel facade treatment, foundation/entry support and production
integration remain. Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-cross-openings/result.md`.

October 4 compound end facades: gable-face window sockets now retain explicit
corner ownership. Replaced short-wing end panels receive native timber posts;
long-wing corners keep adjoining wall posts. Native views, actual glazing rays,
full-height post probes and reference reconstruction pass. Further side-facade
variation, foundations and production integration remain. Evidence:
`docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-cross-end-windows/result.md`.

October 4 compound foundation: native full/half courses and corner blocks now
follow the final shell; the selected door receives a matching entry panel and
native stone stair. Optional foundation assembly passed two geometry tests /
948 assertions and native base/entry views. This is a fitted foundation, not
exact replay of House_5's foundation offsets/duplicates. Production terrain,
access, collision and town integration remain. Evidence:
`docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-cross-foundation/result.md`.

October 4 runtime bridge: 69 validated-family modules baked at native scale
with collision and self-contained resources. `NativeGrammarCompiler` emits
existing environment payloads only after whole-assembly reservation/public-air
checks. Compiler/catalog 3 tests / 546 and dependency traversal 1 / 473 pass;
compiled sample commits 128 colliders and has 10/10 stair physics-ray hits.
Native/baked views inspected. Planner reservation/access and production calls
remain open. Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-native-compiler/result.md`.

October 4 entrance traversal: actual-character testing caught doubled native
risers above the player step budget. Double-scale compound houses now select
the pack's authored 3 m stair at its original world size. Both directions at
both scales pass; foundation 3 tests / 2106 and compiler/dependency 4 / 1030
pass. Native entry views inspected; catalog 70 modules. No production placement
claim: reservation, terrain fitting and real public-route attachment remain.
Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-native-entry/result.md`.

October 4 native siting contract: `NativeHouseSite.cross` publishes a complete
seeded derivation positioned from its actual stair arrival, with a uniform
world pose, measured envelope, separate foundation contacts and exterior route.
Site tests 2 / 2370; actual-player routes at translated/elevated sites 8/8.
Production remains open: existing prefab-landmark rendering rebuilds generic
kit masses, so native derivations need an explicit reservation/realization path
before sealing, not a late mesh replacement. Evidence:
`docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-native-site/result.md`.

October 4 recipe integration foundation: `NativeHouseRecipe.cross` preserves
native module poses through sealed FabricRecipe and SettlementFabricAssembler
payload generation. Two tests / 5289 assertions and actual-player fabric-payload
walks 8/8 pass, including production frame/ground guard. A fit probe found 0/216
candidates fitting existing landmark entitlements across four towns. Next:
native doorway-relative reservation templates and pre-packing selection, then
preserve the native recipe through kit replacement and judge full-town results.
Conservative bounding-footprint body mask remains to refine. Evidence:
`docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-native-recipe/result.md`.

October 4 production admission: 18 sealed native derivations, five measured
planner profiles, preserved native payloads through kit substitution. A raised
holdout failed actual-player access, so admission/realization now require natural
ground across the complete native footing. Final survey 16/16 builds, one native
compound (106 parts); integration 3/222, template oracle 1/267, variants 1/200;
ground-level full-town entrance walks 2/2. No final art acceptance: raised support,
selection distribution, richer facades, additional families and notch occupancy
remain. Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-native-town/result.md`.

October 4 detail/runtime follow-up: measured round gable windows added to native
sites while default reconstruction stays undressed. Source-to-baked visual review
caught reversed roof faces on reflected instances. Bake seven reflected variants
and canonicalize native compiler/recipe instance bases; matched town view now
shows continuous blue tiles. 16 tests / 13,959 assertions pass. Catalog 78,
observed compound 110 parts. Further facade richness and family/distribution work
remain. Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-gable-detail/result.md`.

October 4 street-house production integration: narrower authored jetty/bracket
family now samples two-/three-bay derivations through measured planner profiles.
Four-bay trial removed from production sampling after visual review of its long
roof. Same survey native presence 1/16 -> 12/16 towns, seven/eight holdouts;
16 native houses / 945 intact parts, no generic duplicate masses. Actual player
8/8 isolated, 4/4 town7 and 2/2 holdout61; measured template/variant and real-terrain
checks pass. Both families remain ground-only, without invented upper sockets.
Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-street-town/result.md`.

October 4 corner-turret ground contract: material-bound module IDs now survive
compiler and recipe assembly. Authored door/landing siting preserves the native
ground datum. Production scale uses native 3 m stairs after real-character tests
rejected doubled short stairs. Empty approach cells beneath the spire envelope
are released only after per-module bounds checks. Focused tests 9/17,977;
assembled entrance walks 8/8. Still not admitted to town sampling: frontward
spire reach needs a complete planner reservation, followed by full-town review.
Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-turret-site/result.md`.

October 4 complete turret reservation trial: the street address now clears the
whole forward cap reach and leads straight to the preserved recessed source
entrance. Two derived profiles registered (36 total derivations, 9 native
profiles). Seven tests / 2896 assertions and eight actual-character walks pass.
24/24 towns build but ZERO turrets selected; five preference-biased diagnostic
carved plans also cannot fit one. Registration is not visible success. Next
work is earlier field/carving co-planning of larger native ground sites, then
full-town turret placement and review. Evidence:
`docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-turret-reservation/result.md`.

October 4 turret town integration: early preview DOES have suitable sites in
some towns. Exported corner-turret metadata and a seeded one-landmark preference
preserve them before optional lanes. Measured native footing depth now sizes
negative grid padding; the one-band assumption dropped otherwise valid houses.
Grand 8/9/20 and assembly holdouts 53/63 retain complete turret families. Source
survey: 15 selections among 32 preference-bearing seeds, all 32 plans build.
Four actual-player entrance walks pass in towns 8/9; explicit family-presence
and public-air test 819 assertions. Generic flat walls/exposed decks and wider
art/grammar requirements remain. Evidence:
`docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-turret-town/result.md`.

October 4 full Pure Village reconstruction audit: geometry-proven fallback for
renamed stock raises complete posed derivations from 44 to 47 of 49 houses.
Engine comparison verifies 5,637 meshes / 7,377,955 vertices, normals, UVs, indices
and materials with zero failed complete examples. House_11c front/back source
comparisons inspected; focused 2/4,993 and Python 11 tests pass. Two storefront
houses still lack standalone door leaves/glazing. These are verified grammar
examples, not 47 new production town variants; additional connection rules and
admission remain. Evidence:
`docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-prefab-reconstruction/result.md`.

October 4 Pure Village coverage complete: inventory now includes the pack's
Doors and Structures folders with explicit module source paths. Modified named
assemblies fall back to independently verified children (House_16c staircase).
49/49 original houses reconstruct exactly in engine: 5,905 meshes, 7,704,699
vertices plus normals/UVs/indices/materials. Python 13; focused Godot 3/7,861.
Storefront source/reconstruction views inspected. Production admission and new
variation rules are still open; source coverage alone is not their completion.
Initial Suntail extraction: 5/8 complete, three Cupboard_1 variants to inspect.
Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-storefront-stock/result.md`.

October 4 street-window hoods: complete Pure Village Window_5_2 bays now replace
lower frontage bays through a seeded rule; never upper rows under the main eave.
Source reconstruction unchanged. Stock bake 79 modules, production vocabulary
36 derivations / 9 profiles. Grammar 5/3,127, site integration 5/1,426, fresh
holdout 1/635 pass; 8 towns build, 5 hoods across 4 towns; four player entrance
walks pass. Native close/underside views inspected. Modest facade depth only;
large forms, roof/stair conflict and town-wide acceptance remain open. Evidence:
`docs/qa/2026-10-01-town-redesign/prefab-grammar/october4-street-window-hoods/result.md`.

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
