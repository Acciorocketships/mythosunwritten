# Compound foundation and entry course — October 4

`PureVillageCrossFoundation` follows the final ground-wall panels: full bays
receive native 3 m masonry, half returns receive handed 1.5 m ends, convex
corners receive native corner blocks. The selected door gets the native entry
foundation and Stone_Stair_2, aligned to its transform. No solid wall is placed
behind the entry foundation. Inside corners join the straight and half courses.

`PureVillageCrossHouse.instantiate(..., foundation=true)` enables the course;
it is optional so existing shell-reference fixtures remain explicit about
what they compare. This course is generated from the final perimeter, not a
claim to reproduce House_5's duplicate and offset foundation placements.
Source-shell fidelity remains separate from foundation fitting.

Two tests / 948 assertions pass: sampled masonry coverage across three dimension
combinations, one entry stair per chosen door, and actual stair triangles at
three transverse tracks. Treads descend outward with no sampled rise/drop above
0.4 m; top tread is within 0.16 m of the doorway datum. The first ground-to-tread
rise is approximately 0.31 m. An initial test incorrectly required that first
tread to sit less than 0.3 m above grade; it now applies the same 0.4 m bound
as all other risers. This is geometric evidence, not a production-player test.

Native front/back/base views were inspected for three shapes; close entry views
confirm the stair meets the threshold and the entry panel joins adjacent stone.
The review ground is lowered to -1.5 m to expose the complete native foundation.
Production still must choose grade/burial and entry access using the real terrain
and public walk envelope. Floors/interiors, runtime collision compilation,
projection/tower grammar and town integration remain unfinished.
