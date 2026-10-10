# Measured turret-house derivation

Pure Village House_16c now has a complete modular reconstruction example:
182 independently loaded native module instances, no unmatched geometry.
`tools/building_grammar/export_prefab_derivation.py` verifies each candidate
module's mesh attributes/indices and relative child poses before accepting it.
Nested group transforms, nonuniform scale and reflections remain in the full
affine placement. It records authored material bindings explicitly.

Twelve instances differ from stock material defaults: gables and cut returns
use Planks instead of Plaster, and Window_17_2 also changes Wood_2 to Planks.
These are legitimate source choices, not geometry mismatches. Silently using
the stock materials would fail the intended reconstruction.

Godot reconstruction oracle: 1 test / 2140 assertions passes. It compares
every mesh, index array, world vertex (maximum allowed error 0.2 mm) and actual
material resource against the full source prefab. Four Python tests pass for
explicit material binding, geometry/pose mismatch rejection, duplicate-mesh
accounting, and nested mirrored transforms. Native front/back renders of the
reconstructed stock modules were inspected. The corner shaft, round upper
window course, cap, side projection and main roof preserve authored contact.

This is an example for a grammar, not yet a randomized production family.
The reconstruction oracle borrows materials from the reference prefab only
for validation. Production must bake the measured module/material variants,
derive compatible variation rules, reserve the complete envelope before paths
and neighboring rooms are composed, and verify entrance/collision behavior.
Do not register the JSON as a runtime prefab shortcut or claim turret presence
in towns has been repaired. Existing production turret presence failures remain.

Next: group the source's repeated facade/shaft courses and dependent caps into
interfaces; preserve this exact reconstruction as an oracle while sampling
legal variations. Material binding must participate in compilation and palette
selection, not be discarded by NativeGrammarCompiler's current module-only ID.
