# October 4 native foundation masonry

Pure Village's facade adapter inherited two Suntail foundation roles. Its
one-band course compressed a 3 m panel to 1.5 m, changing brick proportions;
its plinth used the blue stone corner-base mesh, introducing blue stripes and
repeated projecting blocks below native pale stone walls.

The adapter now uses native `WallStone_Start_20x15_1` for the half course and
newly catalogued `WallStone_Start_20x10_1` for the plinth. Both keep unit scale
and the full wall's 0.17 m outward backing alignment. The plinth measures
2 x 1 x 0.345 m and keeps the original 1 m foundation depth. Suntail houses
retain their own foundation vocabulary. Frame palette descriptors include the
new stock asset; they reuse its geometry and do not tint its stone.

The first half-course-only render did not change the blue stripe. Investigation
identified the separate plinth inheritance; the final matched close-up proves
that stripe is replaced with matching native masonry. Before/half-only/after
images are retained. No crown-packing experiment has been reintroduced.

The half-course regression failed before the fix (9/26 assertions) and passed
after it. Half-course and retaining tests passed 3/70. Four holdout roof audits
with the half-course change match baseline, including three unresolved tiny
wings. Final plinth/retaining/roof suite: **9 tests / 271 assertions pass**, including
measured foundation extents and unchanged native stone proportions. Logs are
in final-tests.txt. Native close and overview renders inspected.

Scope: this repairs accidental material switching in these two adapter roles.
It is not complete acceptance of town roof joins, elevated foundations, all
facade materials, all prefab grammar families, or the wider redesign.
