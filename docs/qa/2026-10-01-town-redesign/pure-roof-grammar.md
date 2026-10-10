# Pure Village native roof grammar — measured study

Source: `assets/PureVillage/Models/Houses/House_1.glb` and its corresponding
`Architecture` modules. Reproduce with `tests/harness/pure_village_roofs.gd`.
Measurements are in `pure-roof-modules.json`; rendered studies are in
`pure-native-roofs`. These are source-pack studies, not a production rollout.

## Verified assembly

The reference uses two successive courses on each roof side:

- `Roof_Base_30x30_1`: upper straight course, three metres along the ridge,
  nominal 1.5 m horizontal run and 3 m rise. Its local lower seam is near
  y=0, z=0; it climbs toward negative Z.
- `Roof_Curved_30x30_1`: lower flared course, also three metres along the
  ridge. It descends from the same seam toward positive Z. Measured local
  bounds reach y=-2.527154 and z=2.375532. It includes its own planked
  underside and timber; it is not a second skin on the straight course.
- The reference places both course pivots at y=6.125, z=±1.5, rotating the
  opposite side by 180 degrees. Its two ridgewise regular segments have
  centres x=±1.5. Start/End verge pieces have centres x=±3.
- `Roof_Top30_Start_x30_1` closes the ridge at y=9.125, z=0, x=±1.5;
  matching x5 start/end pieces cap the outer ends.
- `Wall_CutBendDown_{Start,End}_30x30_3` closes the lower curved gable
  (reference y=3), and `Wall_Cut_{Start,End}_15x30_3` closes the upper
  straight triangle (reference y=6). Both pairs share the end-wall pivot
  and face outward along the ridge. The reference end faces use x=-2.875
  and x=3.125; these pivots must be normalized, not copied to arbitrary lots.

The complete roof's measured bounds are x=-3.8..3.79499,
y=3.597846..9.897121, z=-3.875541..3.875532. Thus y=6.125 is the
course junction, **not the eave**. This corrects the earlier work-log
interpretation based only on prefab translations.

Inspected complete end/oblique and closed-end images: continuous curved-to-
straight roof, complete board underside, continuous ridge, and matching
curved/straight gable closure. Source blue tiles are retained in this study;
it makes no production palette decision.

## Integration constraints

The production kit currently has 2 m ridgewise modules, 2 m horizontal runs,
3 m rise per row and a separate odd-depth ridge row. Pure Village cannot
replace its roof role IDs without reconciling those interfaces. A proper
adapter must fit slope, curved eave, gable closure, verge and ridge together;
it must also include dormer/valley behavior or deliberately select another
complete roof grammar where no compatible native assembly exists.

Measure the adapted envelope and mesh contacts before enabling it. Retain
finished-walk clearance, roof-junction clipping and native geometry-backed
collision. Public clearances and mixed-pack contact tests remain mandatory.
Production still uses the earlier Pure Village facade family with Suntail
roofs; full roof-family integration remains open.

## Adapter study: short cornice family

Reference `Houses/House_10.glb` uses `Roof_Base` courses with the separate
`Roof_BottomCurved_30x5_1` cornice at their lower seam. This family can retain
the common three-metre row rise. The opt-in adapter uses:

- Base run normalized from 1.5 to 2 m; regular strips clipped to 2 m width.
- A complete base/cornice assembly for the first row.
- Paired `Roof_Up_30x10_1` pieces for the odd-depth top row.
- Matching normalized gable halves and an assembled small gable.
- Whole regular strips centred **inside** each bay, with native narrow
  Start/End caps added on the end-wall planes. Replacing a whole regular
  strip with a cap is incorrect and leaves an open roof band.
- Ridge and ridge-end pieces receive the same transverse normalization as
  the slope. Leaving the ridge at native width leaves narrow peak gaps.

`BuildingKit.roof_edge_caps` expresses that strip/cap grammar. It defaults
false for Suntail, preserving the existing boundary-centred strip placement.
`PureVillageBuildingKit.roof_study()` is opt-in. Bakes and worker geometry
are present; production selection is unchanged pending the remaining review.

### Refined contacts and dormers

The straight `Window_Roof_1_1` is a complete three-metre roof bay with its
own opening and tile shell. The adapter fits it to a two-metre bay (X 2/3,
Z 4/3) and adds the same short cornice; it never places a plain roof behind
the glass. Native roof/gable catalog count is now sixteen.

The ridge requires a wider transverse fit (Z 1.5) than the courses. The
half-height top's nominal rise is 1.5 m, and its cap seat differs from a full
course: kit ridge lifts are 0.3 m even / 0.24 m odd, with the baked ridge's
0.3 m pivot normalization. This closes the measured cap/skirt contact from
oblique views. A vertical ray alone can hide that gap by striking the far
roof's back face; the tests explicitly reject back-facing hits and include
both-side oblique rays. `pure-roof-seated/b01_roof.png` is the accepted close
contact study. Earlier adapter/dormer images retain rejected iterations.

### Complete tight eaves beside raised circulation

Where finished public headroom intersects the curved cornice, the adapter can
select an entire straight-eave wing: ordinary `Roof_Base` bays and their
matching Start/End caps. This uses the original native straight geometry;
it does not flatten or clip the curved lip into a new profile. The matching
tight dormer is `Window_Roof_1_1` without the added curved cornice, using the
same X 2/3 and Z 4/3 module normalization. Native roof/gable catalog count is
now seventeen. Both dormer variants retain their glazing and close the bay.

`KitRoofEaveFits` selects from actual authored/public intersections. Clear
cornices remain unchanged. `KitRoofDormerFits` keeps clear opening bays and
relocates obstructed dormers to the nearest clear non-edge bay, maintaining
two-bay spacing; only a roof with no available bay loses the whole dormer,
replacing it with a complete plain course. Aperture bounds include measured
window materials, not the full roof-panel box. Final clipping still owns
render/collision correspondence. These changes do not yet enable production
native-roof selection; remaining envelope/clearance and texture-budget gates
are documented in the QA result.


Short public verges preserve the whole native ridge end: Start reaches 0.8 m
outward and End 0.79499024 m. Move the cap inward by any excess over the legal
verge and trim the regular ridge course to its new seam. Keep the source cap's
small inward overlap. Do not truncate its ornamental outer face or stretch it.
