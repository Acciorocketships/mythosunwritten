

## Streaming and wider production survey follow-up

The refreshed actual-world test passed all nine player walks, including eviction
and rebuilt-town reentry (world 2697992464, native terrain/grass/collision).
Harness elapsed 788.118 s; process elapsed 816.93 s under concurrent full-suite
load, so this is not a quiet performance comparison. Godot static memory was
6.87 GB at ready and 7.08 GB at completion. Main-thread village statistics show
7 builds at ready and 10 at completion; they do not by themselves account for
all worker planning. The time utility could not read kern.clockrate in the
sandbox and returned exit 1 after the harness successfully wrote its passing
result; peak RSS was not produced. Evidence: `october3-discovery-contract/world/`
and `world-run.log`. The harness now saves memory and feature statistics.

The 16-world-seed ownership survey keeps every native/mesh extent within the
existing one-chunk geometry halo at every 24 m site offset within a chunk.
Only 15/16 records validate. World seed 3 fails because the covered market's
canopy intersects a late bridge-house ground-frame post, not because of bounds
or connectivity. The overlapping AABBs measure 0.28 x 1.826 x 0.252 m.
The structural canopy must not be dropped as decoration, and the bearing post
must not be dropped to hide the failure. `record-three-pair.log` records the
exact units and native asset. This assembly conflict remains open.

A separate roof audit still finds one Pure Village tight eave corner clipped
by public clearance on 85830433957479026/compact (retained overhang area
0.0831 of 0.7218). The close native views in `october3-eave-corner/` are
occluded by neighboring construction and do not establish visual acceptance.
No production code changed during these diagnostic passes. The full isolated
suite continues in session 24812; its original logs are preserved. Overall
visual, assembly, and quiet performance acceptance remain open.


### Native canopy intersection confirmed

The record validation failure is not only empty space in an aggregate AABB.
Clipping the authored butcher-stall mesh triangles to the support post box
(inset 1 mm on all faces) finds seven intersecting triangles, total area
0.0483155 square metres. `market-triangles.gd` and its log preserve the measured
asset/pose/box probe. Therefore do not relax the unrelated-envelope validator.
The construction needs coordinated support and market placement.
