# Native entrance at production scale

The actual player failed to climb the original Stone_Stair_2 after the whole
assembly was doubled: its authored approximately 0.3 m risers became roughly
0.6 m, above the character's 0.5 m step budget. Native-scale ascent/descent and
double-scale descent passed; double-scale ascent stopped partway up.

`PureVillageCrossFoundation.derive` now accepts the intended world scale
(default 1, supported 1 or 2). A double-scale host uses existing
`Stone_Stair_11`, whose authored rise is 3 m, at its original world size.
Its relative transform is uniformly half-scale inside the doubled house.
The matching full-width entrance foundation remains owned by the door.
Neither the player step limit nor a hidden ramp was changed. The original
native-scale derivation remains unchanged.

The manifest exporter includes both supported entrance vocabularies. The new
module was baked through the ordinary environment baker with keep-existing;
the native grammar catalog now contains 70 modules. Runtime dependencies do
not reference the source asset pack.

Validation:
- Actual player ascent and descent at both scales: 4/4 routes pass, versus
  3/4 before. Full baked house collision is present, not an isolated stair.
  This verifies exterior approach to a closed door, not interior traversal.
- Foundation/entry geometry: 3 tests, 2106 assertions pass. World-space tread
  sampling includes exterior ground and checks the character's real step limit.
- Compiler/catalog/dependency suite: 4 tests, 1030 assertions pass.
- Native renderer: 128 committed colliders, 10/10 stair ray hits. Source and
  baked front/back/entry views saved here. Inspected the baked entrance and
  full front view. Review images show native chart units, with the smaller
  relative stair appropriate to the doubled host; actual traversal runs at
  world scale.

The first new geometry probe incorrectly ended at the rough mesh's rear
boundary, where bevels are not a tread; it now samples through the top tread,
0.1 m from that boundary. Riser and support checks were already passing.

This is one entrance assembly's validation, not town integration or overall
art acceptance. Planner reservation, terrain fitting, real route attachment,
and integration of the native families into generated towns remain open.
