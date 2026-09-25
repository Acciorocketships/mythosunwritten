# Upper cliff attachment — scoped repair, further taper work required

Production `CliffRockCrags.gd` now retains a nearly flush upper metre at the actual native face, including four-metre cliffs. The original short, height-proportional join admitted a large bulge just beneath the turf. The closed shell and collision share this repair. This is the only production change in this pass; the larger experimental cliff studies are not adopted.

The owner confirms that the projection directly at the top is improved, but rejects how quickly the body returns to full projection below the collar. That remains open. A full-height or intrinsic body taper is being investigated in [pass 50](../50-cliff-long-shelves/result.md). This report does not claim the entire upper profile is accepted.

## Verification

The new photographed-face check fails on the frozen original at **2.692877 m** added projection and passes at **0.035050 m** across 18,453 sampled front vertices. Actual convex corners fail originally at **1.191476 m** and pass at **0.025561 m**, across 13,670 samples. The isolated repair preserves **18,731** lower vertices exactly across 4/8/16/32 m cases.

The broad run has 20 existing tests / 101 assertions passing. Its added crown test initially fails because the test tried to load an empty environment override, not because of geometry; the corrected test plus corner and lower-invariance checks pass 3 tests / 9 assertions in `join-tests.log`. Three curved-tread tests / 8 assertions also pass. Together the distinct completed checks total **26 tests / 118 assertions**. The original mixed-result log is retained transparently.

Checks cover 31 closed photo shells, pointed turf continuity, 57/57 reported contacts, lower bearing, native attachment tangents, curved/sloping ledges, corner topology and grass. Sixteen grass seeds retain all 176 sampled patches supported with none escaped or buried. Photo recession is 0.505700 m, corner recession 0.325036 m. No unrelated test threshold is changed.

## Native review

Seventeen frozen-context before/after pairs use the original reported ReviewCam poses and supplemental side/front/plant views. The upper projection retreats beneath the turf while lower geometry stays unchanged. P12 side and P20 oblique also show the remaining smooth broad body and quick collar transition; these are not approved as final art.

A fresh P12 world run finishes startup in **437.945 s**, saves its actual world, and captures three saved camera angles after readiness. Grass reports 53 tiles, 14,903 committed instances and 11,703 visible instances. This is one uncontrolled integration run, not a performance improvement. The snapshot utility emits its known warning about querying shader globals outside the editor. The saved camera/actor pose can intersect changed rock; this is not a player traversal test. The front capture is inspected and retained without claiming character clearance.

Sources are frozen in `tests/fixtures/september18/cliff-crown-collar`. Current production byte-matches `candidate.gd` at this pass. The original register and overall cliff composition remain open.
