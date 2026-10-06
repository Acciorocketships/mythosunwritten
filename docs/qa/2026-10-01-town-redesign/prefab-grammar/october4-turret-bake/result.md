# Runtime-independent turret-house stock

The House_16c derivation now renders from 89 baked stock variants and 182
placements without loading the source prefab or borrowing its materials.
`export_turret_manifest.gd` exports the measured bindings and canonical
placement data to `terrain/environment/grammar/house16c.json`. Reflected
geometry is baked with corrected winding; the corresponding placement basis
is positive. The original reconstruction fixture remains unchanged.

EnvironmentBakeGeometry.bind_materials resolves an entire set of per-mesh,
per-surface bindings before applying any. Invalid paths, surfaces, resources
or duplicates reject the set atomically. Overrides affect only the imported
instance, never shared source meshes. Bake tool version is now41. Materials
are saved as offline inputs; the ordinary baker handles textures and runtime
resources. Existing native IDs are reused for unchanged stock; explicit
binding variants have deterministic suffixes.

Validation:

- Binding tests:2/2,11 assertions. Shared geometry and other instances stay
  unchanged; invalid batches do not partly apply.
- Baked derivation plus existing native recipe/assembler checks:3/3,
  7492 assertions. All182 parts preserve source bounds (0.2mm tolerance),
  authored material-name sets, collision presence and positive transforms.
- Python grammar tools:8/8 tests.
- Native baked front/back views inspected.182 placements and182 collision
  pieces loaded without source prefab instantiation. No new missing surfaces,
  cube artifacts or cap/shaft separation observed in these two views.

The bake exited successfully. The headless dummy renderer reported material
cleanup warnings at root.free(); saved materials pass the checks and native
render has no such warnings. This does not claim those engine warnings fixed.

Not yet a production town family or randomized sampler. Compatible structural
variations, source entrance/terrain-datum handling, full envelope reservation,
actual-player traversal and representative/holdout town review remain required.
Current compiler's module-only IDs must not discard these authored bindings.
The existing turret-presence failures have not been changed or relaxed.
