# Native grammar in the fabric recipe pipeline

The sealed-town feasibility probe tried 24 native compound derivations at each
of nine existing landmark sites across 7/standard, 31/large, 13/large and
43/grand. None fit both the reserved visual cells and terrain-bearing cells.
Even the best candidate leaves 52 visual cells and four bearing cells outside
its entitlement. This rules out a late replacement in those sites; native
families must reserve their own measured space before packing.

`NativeHouseRecipe.cross` now expresses the shared seeded native derivation as
a sealed `FabricRecipe`. The world-to-lattice mapping compensates the town's
anisotropic frame, preserving uniform native world dimensions. Every module,
including its complete roof and correct stair, remains an individual baked
placement. The addressed entrance is the ground arrival at the private stair,
not the raised closed door. Native footings receive the existing 0.08 m town
construction guard. No upper connection sockets are invented.

The current body/terrain mask conservatively reserves the complete bounding
footprint. This costs the cross-house notches as private space; it is a safe
integration starting point, not the final fine-grained courtyard policy.
The visual compound shape is unchanged and never stretched to that rectangle.

Tests:
- Native-to-world recipe reconstruction and actual fabric assembly: 2 tests /
  5289 assertions pass. Six size/seed combinations preserve every module and
  world transform. Four rotations survive `SettlementFabricPlan.seal` and
  `SettlementFabricAssembler.payload` without added/dropped parts or substitute
  roof surfaces.
- Actual player on that fabric payload, with the production anisotropic stage
  transform and 0.08 m construction guard: 8/8 ascent/descent routes pass across
  four orientations and sampled doors. A valid terrain-landing recipe and
  surface claim accompany the isolated house.

Fixture repairs: the first pipeline fixture lacked a public surface plan,
then used `landing` instead of the required `route_landing` role. It also lacked
shared catalog bounds, causing facade-pass initialization errors for an SFV
pillar. Inspection confirmed native recipes were already excluded from generic
facade insertion. The fixture now supplies the normal metadata; production
facade logic was not changed. The clean final test and walk logs are saved.

Still open: register native recipes and derive their doorway-relative planner
templates, select them before site reservation, preserve native realization in
the kit replacement path, then validate real terrain, neighbor/public clearance,
full-town views and traversal. The generator is not enabled in production towns.
