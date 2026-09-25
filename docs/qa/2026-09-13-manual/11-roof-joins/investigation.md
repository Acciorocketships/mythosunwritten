# Compact roof junction investigation

P09 is reproduced at the original overlay pose in the live world and native
town assembly, with two nearby angles. Runtime integration of the finite native
roof vocabulary is now under review; the issue is not accepted yet.

The front chimney roof is `spatial.roof.spatial.maze_back.03.room00`, a
`roof.tower.short.blue` over a complete square plate. Its immediate equal-height
neighbor is `spatial.parcel.maze.house.031.part00.room00`, a slim room continuing
into the longer roof behind. Both presently run on the same ridge axis. The
topology therefore calls their shared eave a parallel valley. The generic free
crown rule retains their individual complete pitched shells after the older
junction classifier marks this neighborhood flat.

The current atomic T-junction vocabulary covers four-cell SFV building/long
roofs. These two-cell LPFV compact roofs have a different native profile,
including a longitudinal bow. Merely rotating the square roof or using a scaled
wide valley piece would not prove closure. The next roof work must provide a
profile-compatible compact junction and preserve the existing continuous-run
seams, parent footprint, and public clearance. `plan.json` contains room,
topology, and actual selected-unit records; `before-payload.bin` preserves the
current native baseline.

P31 is an additional reported junction context and still needs its own complete
source/roof ownership reproduction. This issue remains open. Intertown paths are restored; their loading-time
review remains separately open under issue 36.

## Offset native junction prototypes (September 14)

P31 now has a fresh complete live snapshot, frozen original tactical pose and
±8° views, and its canonical (1,-3) source/payload in `P31-current-source.txt`,
`P31-probe-before.json`, and `P31-before-payload.bin`. The initially inferred
close-camera capture was wrong for this tactical photo; use `P31-tactical-before`
for the actual roof comparison. All three corrected views were inspected.

The red production test `test_september13_compact_roof_join.gd` keeps both P09
crown units and fails their perpendicular-axis / atomic-valley assertions
(2/5 assertions pass). No roof production change has been accepted yet.

The six original LPFV Roof_01–06 models contain no complete native T piece.
A CSG experiment produced an empty result for the native source, including a
single-roof control; an ordinary box control rendered. It is not a usable bake
for these non-manifold source meshes and is rejected.

An isolated symmetric native-section prototype (`native-valley-prototype-*`)
closes a centered T using proper mirrored quarter stock and complementary 45°
cuts. Three views were inspected. This does not establish the photographed
junction: P09's branch contacts the last two cells of its slim host, with a
+2 half-step offset. The host's outer bowed strip is not the same profile as a
central repeat. Do not promote the centered example into production or force
ordinary neighboring roofs onto that symmetric profile.

The subsequent offset prototype preserves the original middle/end profiles and
alternating proper mirrors. `september13_roof_prism_cut.gd` is an exploratory
OFFLINE native-triangle cutter: the upward source triangles define exact vertical
prisms; subtracting their union partitions overlapping shells without moving
vertices off their source triangles or adding a cover. UVs, colors and normals
interpolate. It is not wired into the generator, the catalog or runtime.
The offset prototype has 13,639 triangles before the coplanar-owner follow-up;
three closer views were inspected. An independent NumPy upper-envelope scan
found 16,875 source hits, three missing samples at the intersecting ridge faces,
and maximum retained-height error 0.000000443 m. `offset-coverage-red.json`
records that failed coverage. The follow-up assigns coincident face ownership
to the host; its coverage is still to be checked. Prototype renders alone are
not acceptance.

Before implementation, the cutter needs bounded tests for coincident faces,
empty cuts, sharp valleys, attributes and both handed native profiles. A finite
catalogue operation must retain actual prepared bearing datums, outside gables,
ordinary continuous-run phase, and tight-eave variants. Runtime must only select
prepared values/assets, never perform this expensive mesh operation. The final
change must alter ordinary topology/recipe rules, without matching room IDs or
seed coordinates; then rerun the failing town test, original/native live pairs,
public-clearance checks and the mandatory 48-town corpus.


## Prepared catalogue and admission (September 14, continued)

The raw offset prototype's three holes were caused by float32 plane arithmetic.
Double-precision scalar plane distances remove those reproduced holes without
changing source stock. The original red arrays/report remain retained. Its
16,875-ray repeat and a prepared narrow-eave replay now have no missing samples;
the latter's maximum vertical difference is 0.000000391 m.

`tools/environment_bake/EnvironmentRoofEnvelope.gd` now owns the OFFLINE cutter;
the former harness script is a compatibility wrapper. Bake version 38 supports
finite native section declarations, measured pre-valley bearings, proper mirror
and cardinal poses, and complementary envelope subtraction. The manifest
`low_poly_fantasy_village_compact_valleys.json` produces 64 native derivatives:
two colors, two eave profiles, both sides, both ends, and four ownership roles.
No runtime source-mesh cutting is introduced. Both colors have identical
geometry, recorded in `catalog/color-geometry-parity.json`.

The catalogue harness assembles 16 cases and captures three angles each. The
48 views were inspected in contact sheets, including the opposite side and
above. Roof skins join with native stock and retain their exterior gables. These
are isolated catalogue renders, not acceptance of the photographed town.

The full-domain independent scan covers 242008 rays / 172997 original source hits
across the eight distinct geometries, with no holes. Each case has one raw
vertical-height difference over 0.1 mm at an almost vertical native shingle lip.
The actual winning native triangle is unchanged within two float32 coordinate
ULPs (the first case is 0.000000119 m); equivalent assembly orders amplify that
rounding into a vertical-ray difference up to 0.000853 m. The checker retains
those raw discrepancies and requires complete matching triangles for this
classification. It does not relax the 0.1 mm threshold for changed geometry or
excuse any holes. `catalog/coverage-summary.json` records every case.
A deliberate removal of 37 triangles fails with 95 uncovered samples and 75
unexplained height errors (`catalog/falsification-result.json`).

The focused cutter suite passes six tests / 57 assertions, including a real
UV2/tangent/name-preservation cut, complete burial, unindexed stock and bounded
source domains. The two new domain assertions first failed; their red/green
logs are retained. Spatial indexing also has a finite reference budget.

`FabricCompactRoofJunctionPlan.gd` is an unconnected, pure admission rule under
review. A complete square leaf at the terminal half of a slim/row plate owns
one native offset junction. Different datums, partial plates, non-square
branches, occupied host ends and competing branches cannot select it. Three
tests / 103 assertions cover all 16 rotations/hands/ends plus negative cases and
input-order/name independence (red 6/23). Actual photographed-town admission is
being checked before connecting these facts to recipes and continuous runs.
The original town-level roof test remains red; no issue-11 completion, full-town
clearance, or corpus acceptance is claimed for this new vocabulary.

## Runtime integration under review

The shared roof-domain preparation now selects the same compact pair for early
clearance reservations and final unit construction. P09 selects exactly the
reported square branch and its slim host through plate dimensions and adjacency.
The prepared host sections also participate in ordinary continuous-roof realization.

The first integrated run rejected the branch because the generic roof alignment
check centres the remaining mesh AABB. A cut branch deliberately extends inward
to its host ridge. Its finite native asset and original section pose now define
that bearing contract, with exact footprint and recipe metadata checks; moving
either the placement or declared datum remains invalid. Eight variants first
failed the alignment regression. The five focused tests now pass 132 assertions,
including the original photographed-town perpendicular-axis/valley assertions.
This is structural test evidence only. Native comparison renders, full public
clearance, continuous-run variants and the 48-town corpus remain pending.


## Rejected early reservation and atomic replacement

The early/final forced pair integration above is rejected. Its 48-town run
constructed only 39 towns, and the photographed town's neighboring roof allocation
changed. `corpus-integration.txt` and `failures-full.txt` preserve those failures.
The compiler now leaves ordinary room/roof selection intact, then admits both
joined alternatives together against the completed allocation. A failed pair
keeps both ordinary roofs. Dormered candidates retain their original native assembly.
A controlled omission of just this final pair selection confirms identical 111
room records and 101 roof units, with only the two intended roof recipes changing
(`atomic-selection-control-comparison.json`). The older captured source produced
110 rooms; that historical difference is not credited to this comparison.

The host's opposite end uses the existing native flush variant at its neighboring
roof interface. The branch retains its original chimney through four finite native
orientations. Continuous realization stages all sections before suppressing any
original roof, validates native phase and actual tight assets, and the pair is
rejected if its host loses its previous continuing-run membership. The profile key
alone was insufficient: ordinary blue/orange keys already select tight native stock.
The photographed junction now passes the continuity/three-cut-section/chimney-pose
regression. The four previously failing seed/profile controls pass
(`atomic-failure-controls.txt`). The new all-variant datum regression exposed two
additional host cases and is still under investigation. No final native/live
comparison, complete corpus, or issue-11 acceptance is claimed.
