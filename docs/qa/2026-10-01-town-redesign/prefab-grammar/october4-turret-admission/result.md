# Corner turret admission investigation

Production foundation-extension experiment rejected and fully reverted.

The new lightweight `tower_admission_probe.gd` reports the finished kit tower
admission counters. Baseline towns 7/standard, 13/large, 43/grand produce
0, 1, 0 towers respectively; the one admitted tower is not a corner tower.
This explains the failing corner-presence tests without relaxing them.

7/standard makes eight corner proposals, all failing bearing at the house
datum. 13/large makes 59: 27 fail bearing, 25 fail reservations, five fail
host connection, and the two remaining candidates intersect public clearance.
43/grand makes 60: 32 fail bearing, 19 fail reservations, eight fail host
connection, and the remaining candidate intersects public clearance.

Experiment: extend whole native round courses downward (bounded to six
courses), keep the cap at its original eave, and require contiguous corner
connection from the house's ground band upward. The full footprint still
needs real bearing, all shaft cells still respect reservations, and all public
air checks remain. It changes the rejection reason, not the finished result:
the additional supported proposals hit reserved space. Counts remain 0,1,0.
No render or art-acceptance claim is made for this rejected geometry.

Saved candidate patches are diagnostic evidence only, not production. Both
production files were restored byte-for-byte from their pre-experiment copies.
The next implementation needs turret footprint/shaft space reserved while
rooms and circulation are composed, or a complete native house derivation
whose turret is part of its measured envelope. Further post-hoc bearing
relaxation does not address these observed failures. The cause relative to
historical native-house integration is still unproven; this is not evidence
that that integration itself regressed towers.
