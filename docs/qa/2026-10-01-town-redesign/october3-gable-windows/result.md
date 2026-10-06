# Native attic windows — October3

Two additional towns (31/large,43/grand) exposed blank Pure Village gable
interiors. `PureVillageBuildingKit.roof_study` used plain plaster for every
full-height interior bay. These now use the pack's complete closed rectangular
or arched window panels, chosen by house style. Triangular edge panels are
unchanged. The existing final roof/floor-contact arbitration retains a complete
plain closing panel where an opening is obstructed.

The first trial used the facade's open casement. Rejected: it exposed the attic
and triggered actual gable-hole samples in the mixed-town closure audit. The
initial worker geometry also lacked window panels. `bake_roof_geometry.gd`
now gathers both Pure style selections into the shared triangle cache; the
rebaked `pure_village_roofs.bin` includes their actual native surfaces.

Final visual evidence is **closed/**. Root and **final/** contain superseded
open-casement trials. Before views: `../october3-holdout-art/`. Inspected
31/large overhead and43/grand overhead/turret junctions: the former large blank
plaster triangles gain real framed openings without added fake window decals.
31 legitimately has no admitted full towers;43 has four. This confirms variation,
not a proof of desired tower frequency across all towns. Both are urban/no-tree
rolls; previously inspected24/large remains the wooded comparison.

Focused regression:24 assertions on both ridge axes, actual glazing metadata,
worker geometry presence, unobstructed survival and complete panel replacement
when an obstacle crosses the opening's outside viewing plane. The test's first
obstacle stopped behind that plane; widened to cross the actual tested opening.
No production clearance threshold changed. Broader native roof/facade suites
are in progress; append their final outcome before accepting the change.

The production-world walk completed before this attic-panel change:9/9 routes,
confirmed eviction/replacement/reentry,712.261 seconds. Current native closure
and clearance tests must cover the new attic panels. No fresh world performance
claim for this small geometry edit. Full redesign acceptance remains open.

The three-file run finished:30/31 tests pass; its only failure was the old test
obstacle extent described above. The corrected focused case then passes24/24
assertions. Thus all31 unique native-roof/facade cases pass on the closed-window
candidate; no gable holes or newly failed roof geometry checks remain. A fresh
finished-triangle/public-air corpus check is now running in session98018, log
`/tmp/october3-attic-air.log`; do not treat this paragraph as a passing result.

Finished-triangle/public-air corpus completed:1/1 test,19 assertions,102.053 s;
all reported finished meshes have zero intrusions. See `finished-public-air.log`.
This closes the new attic-panel change's native closure/clearance checks.
No jobs from this pass remain active. The full redesign remains active.
