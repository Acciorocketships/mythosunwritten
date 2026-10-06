# October 4 crown packing — rejected experiment

A crown-only equal-area tie-break preferred a 2x2 roof wing over a 4x1 strip.
It reduced 103/grand tiny roof wings from two to zero without changing occupied
rooms. The other three holdouts were unchanged. The combined roof/packing/
skywalk suite passed 9/10 tests (188/189 assertions); the attic-closure failure
also occurs after restoring the old packing (9/standard, house.012).

All 12 selected directional skywalk/underpass controller walks passed in the candidate.
However matched native renders prove a NEW cornice/window-frame overlap at
103/grand's east crown. Before, the shallow eave sits above the window; after,
the perpendicular gable cornice descends across its arched frame. This violates
the user's explicit roof/projection clearance requirement. The candidate was
rejected and the production packing and signature restored. Its test and patch
are retained here only as experiment evidence, not as accepted functionality.

The mixed masonry/plaster courses visible at this location predate this trial.
Three tiny wings remain open (53/grand one, 103/grand two). Future candidates
must fit whole facade trim and preserve the enclosed crossing, not merely
improve a roof-count metric. The attic-closure warning was an oracle error: the two flagged cells at
9/standard (4,1) and (5,1), eave band 9, are occupied below by
`kit.skywalk.4.7.-1.0.1` and `kit.tunnel-ceilings`. The test's house-parcel map
omitted these finished masses. It now checks built storey occupancy. Since the
corpus currently has no truly unoccupied porch attic, an explicit porch control
checks real board placements and proves their removal is detected. Final full
skywalk suite: **5 tests / 10 assertions pass**. This corrects test coverage;
it does not claim a production geometry improvement or resolve the user's
broader hollow-tower concerns.
