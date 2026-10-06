# Native stone house grammar: shell and opening interfaces

`PureVillageNativeHouse` now derives a full native 3 m-bay stone shell around
`PureVillageNativeRoof`. Ridge-bay count determines long walls, foundation
courses, head courses, end faces and corner courses together. No complete house
prefab is loaded by the rule; all output uses native modular GLBs.

The unadorned native House_4 is now a complete special case: three ridge bays,
solid facade choices. A test compares every mesh in the authored house against
the generated house, including world vertices, triangle topology, UVs, material
assignments, albedo/roughness/metallic and texture paths. It passes within the
0.2 mm tolerance for rounded source quaternions. Native matched front/back
renders differ in only 3/2 pixels above 8/255; channel mean error <0.0006/255.

Facade choices replace entire wall panels. A door changes its foundation course
to the native entrance opening too. The Door_9_1 frame has a 125 mm tangent
socket offset, applied in local rather than world coordinates. Door frame,
moving leaf and Window_14_1 geometry match the corresponding House_1 bays.

A deterministic sampler chooses a single front door and complete compatible
stone window panels, with at least one opening on each exposed face. Sixteen
seeds verify repetition, variation, one panel per bay (no hidden solid wall),
coordinated doorway/foundation and coherent material family. The initial sample
used Window_1_3, which includes plaster: visual inspection rejected that mixed
patchwork. It remains an explicit reconstruction option but is not selected by
the stone sampler. Window_14_1 is a rectangular stone-backed window; Door_9_1
provides the native stone arch.

Validation: 6 tests / 3843 assertions across the roof/reference and house/opening
suites pass. Complete reconstructed and sampled native views inspected from
both sides. The source House_4 is a blank shell; matching it is a reconstruction
benchmark, not approval to fill towns with blank rectangular buildings.

Still open: deeper composition (supported upper rooms, compound wings, connected
roof junctions, corner towers), other native structural/material families, full
reference corpus reconstruction and holdouts, floors/interiors/collision/access,
and production envelope reservation/town integration. This family is not yet
used by production. Do not treat these small sampler fixtures as final art.
