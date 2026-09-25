# Short inner corner surface continuation — pass 102

**Retained scoped production repair.** The short stepped inner corner now continues the actual adjoining rock profiles and their broad treads. It fills the photographed gap with a closed, grounded solid and a sloping ledge. The neighboring lower shelf crossing and overall cliff art remain unfinished.

## Change

`CliffInnerSurface.gd` discovers the two real perpendicular parent walls around a remaining independent inner corner. It samples the incoming shoulder before its terminal taper and the outgoing supported tread, then connects corresponding profile intervals through a curved surface. This replaces the independent corner while preserving its identity and anchor; the parent walls are unchanged. It applies only to eligible unequal-height corners with the lower parent at the corner height. Existing equal-height and backed stepped joins retain their previous treatment.

The surface closes through a common buried foot, retreats into the native crown above the main tread, and uses turf only on the corresponding upward ledge interval. Complete candidate footprints honor grade/public exclusions and the supplied rejection callback; normal owner and water admission still follows in the production pipeline. The saved recipe carries the actual sampled profiles. Snapshot replay restores the exact saved foot, including float32 differences smaller than the previous replay tolerance.

## Visual judgment

All eight final native detail views were inspected after fresh production generation. The short inner front, above and side views show a supported ledge and stone body through the former gap. The outer oblique view retains the broader wrap without the earlier radial fan. The main inner join remains continuous. The lower inner pair still shows an awkward angular shelf crossing; that is not accepted by this repair. Broad plain gray areas, a visible local shoulder junction and coarse plant silhouettes also remain art limitations.

- [Fresh short inner corner](final-details/short_inner.png)
- [Fresh short corner from above](final-details/short_above.png)
- [Fresh short corner from the side](final-details/short_side.png)
- [Previous matched control](../101-short-corner-runs/before/short_inner.png)
- [Retained outer wrap](final-details/outer_oblique.png)
- [Remaining lower shelf crossing](final-details/lower_inner_above.png)

The initial arc-length loft produced excessively green stair-like surfaces. Semantic tread alignment with physical-height crown retreat produced a hook. Tangent controls produced an arch. These are rejected. The collar experiment is invalid: its required tread assertions failed even though its capture caller exited normally. The retained shoulder study samples the actual parent before its taper; `production/` generalizes that rule, and `final-details/` renders the actual saved fresh world without rebuilding its rock geometry.

## Verification

- Five pinned ledge support failures become zero. Previously two probes struck substantially lower stone and three missed altogether.
- Unequal buried parent feet initially left 64 rear closing columns elevated; the common minimum closing foot makes that zero.
- A real fresh saved-scene replay mismatch reproduces before the exact-floor fix and passes afterward. Its fixture remains in `replay-mismatch.bin`.
- **28 distinct focused tests / 168 assertions pass** across the 27-test / 166-assertion final focused run and the final 11-test / 47-assertion overlapping replay rerun. The latter adds the fresh replay regression. Checks include closed edge incidence, nondegenerate triangles, turf support, four cardinal rotations, input-order independence, preservation of other forms and rejected reservations.
- Fresh audit: one surface connection, four previously joined walls, four outer corners and no remaining independent inner corner in the inspected area. All **327,717 distinct inspected triangles** occur in actual production collision. Exact current rock/turf replay has zero mismatches. **3,949 foot probes** have ground and remain buried.
- Native isolated surface contacts: **211 / 211 hit**, maximum error 0.00001336 m. All **130 native ground probes** remain buried. These are native physics rays, not player traversal.

Fresh P12 startup was **430.072 seconds**, with 53 grass batches and 14,899 committed grass roots. This is not a controlled performance comparison. The common-bottom source refinement occurred while the fresh process was running; the photographed parents have equal original feet, and the final exact-current replay audit verifies the saved geometry against the final implementation. The fresh run retains the known editor-only shader-parameter-list warning and exits normally. No general hydraulic, streaming, renderer or full-suite acceptance is claimed.

Final logs are `cliff102-final-tests.log`, `cliff102-replay-green.log`, `cliff102-fresh.log`, `cliff102-fresh-audit-final.log`, `cliff102-physics-final.log` and `cliff102-final-details.log`. Other archived logs include deliberately red tests and rejected/invalid studies. In particular, the first focused run referenced a nonexistent test file; the first physics diagnostic used an obsolete report field and was terminated; the first fresh audit caught the replay mismatch. None substitutes for the corrected final results.

The active original judging register remains open. Next cliff work is the lower shelf intersection, followed by broader composition review; the original water, town, streaming and biome issues have not been accepted by this pass.
