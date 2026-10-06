# Native grammar catalog/compiler — October 4

Exported 69 distinct native modules used by the validated stone, projected
street-house and compound families to `pure_village_native_grammar.json`.
The normal environment bake ran with `--keep-existing`, producing native-scale
visuals, textures/materials and building-trimesh collision in the runtime
catalog. Existing production assets were retained. Source meshes are not
scaled onto the two-metre kit lattice.

`NativeGrammarCompiler` converts a derivation to the existing worker-safe
EnvironmentInstancePayload. It requires baked collision-capable modules,
finite nonsingular transforms, a complete enclosing reservation, and no part
bounds intersecting supplied public-air AABBs. It rejects the whole assembly
on failure, without emitting partial walls or clipping native parts. This is
conservative bounds clearance, not triangle-tight fitting. Root transforms
support native placement and rotation; deterministic part identities survive
batching. The caller must supply all relevant public-space reservations.

Evidence:

- Compiler/catalog tests: 3 tests / 546 assertions, including rotated native
  placement, stable deterministic payloads, missing asset rejection,
  insufficient reservation and public-clearance rejection with zero emitted
  instances. All 69 descriptors have collision and baked visuals.
- Dependency traversal: 1 test / 473 assertions. The transitive baked resource
  graph contains no runtime `res://assets/` dependencies.
- Native compiled review uses EnvironmentRenderCache and the actual
  EnvironmentCollisionBuilder. A sampled compound house including foundation
  commits 128 instances and 128 collision pieces. Ten physics rays along its
  entry stair all hit. This is not an actual-player walk.
- Matched front/back source and baked renders inspected. Geometry/joints are
  retained. Baked textures use the catalog's mipmapped Basis compression;
  front/back mean channel differences are at most 0.98/0.71 out of 255, with
  50305/39898 pixels differing by >8/255. The baked texture filtering is visibly
  smoother than the source preview; this is not claimed pixel-identical.

Commands: `tools/building_grammar/export_native_manifest.gd`, then
`tools/environment_bake/environment_bake.gd -- --manifest
res://tools/environment_bake/manifests/pure_village_native_grammar.json
--keep-existing`; `tests/test_native_grammar_compiler.gd`;
`tests/harness/suntail/native_compiled_house_review.gd`.

Remaining: planner-side native envelope/entrance reservations, terrain support,
real public-air inputs, production house selection and collision/player walks,
material variants, broader samples and holdouts. The compiler is usable but
not yet called by production town generation. The full prefab reconstruction
and architecture goals remain open.
