# Rotated roof extras versus their bearing walls

The fresh full-suite test_connected_roof_retains_its_declared_eave_flashing
fails with spatial.roof.spatial.maze_back.03.room00/chimney/turned overlapping
spatial.fabric.spatial.maze_back.03.room00/south. The preserved baseline focused
run reports UID warnings, not that explicit overlap; baseline alone cannot
establish this is pre-existing.

Root: _turned_space_is_clear excluded the bearing parent wholesale. Roof skin
may meet those walls, but rotating its optional chimney/dormer can put that
complete asset into a wall. The final validator never granted that exemption.
Admission now tests complete extra bounds against every unsuppressed placement
of the bearing parent. A blocked turn leaves the original complete orientation;
it does not clip the chimney or weaken final validation.

The same whole13-test roof-construction file passes13/13,42 assertions in69.498s.
Finished native roof-air corpus passes1/1,19 assertions in105.78s: zero
finished intrusions across all six cases. The exact repaired town keeps one
other valid roof turn and its original unsliced chimney (collision included).
The strengthened focused regression checks both facts and passes1/1,4 asserts.
All focused sessions completed.

This is the first production edit during the full repository runner24812.
Its initial source-manifest predates this change. It was made after the initial
roof-construction failure, during the room-band phase. This focused full-file
rerun supersedes that initial result; later fresh runner processes load the fix.
Timing is under concurrent load and is not performance acceptance.
