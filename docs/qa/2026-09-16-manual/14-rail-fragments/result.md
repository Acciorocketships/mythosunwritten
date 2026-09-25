# Remove isolated stair-post fragments

In image P15, wall clipping had removed a stair post's shaft and both connecting rails while leaving its decorative cap floating above the lawn. A ray through the annotated cap identifies `public-transition/volume.transition.10.mesh`; this is generated stair geometry, not a prop.

The builder now computes exposed rail segments first. Each clipped post fragment must still meet one of those segments before it contributes visual or collision geometry. Fully exposed guards keep their original posts; partial parapets retain posts attached to the remaining upper rail.

In the photographed town, three isolated pieces disappear across two transition meshes (72 vertices / 108 collision triangle vertices). All native batches and explicit collision boxes remain identical, as do the other 99 generated meshes. See [payload comparison](payload-comparison.json).

## Verification

- [Red](red.log): the photographed cap and four rotated clipped-post controls fail on the original builder; ordinary exposed guards pass.
- [Focused final tests](focused.log): 10/10 tests, 199 assertions, covering the four new tests plus prior garden/stair guards, native wall clipping and outward shading.
- [Related checks](green.log): 12 headless tests pass, with one GPU test pending. That [native GPU test](native-test.log) subsequently passes 32 assertions. These runs overlap the focused tests; their counts are not additive.
- [Native collision survey](clearance.log): 312 public stance and 444 crossing results remain identical; six doorway casts remain clear. Eight longer bridge casts retain their baseline endpoint contacts. No full character traversal claim.
- [48-town corpus](corpus.log): 48/48 seal, 11,772 clear centres and 16,915 clear crossings, no connectivity split. Twenty-five conservative offset pillar candidates remain unchanged, with no measured centre/gate obstruction or intrusion. [Fingerprint gate](corpus-gate.log): 95/95 assertions.
- Six native before/after pairs at P04/P15, using the saved photo reconstruction and ±8° views. Six game pairs repeat the same cameras with the bridge overlap correction included. The game replay verifies exact native piece matches and full world-space generated vertex matches before applying the delta.

## Visual judgment

P15's isolated cap disappears in the reported and both nearby views. Stair treads and connected guards remain. P04 keeps the clear doorway and guard at the withdrawn false side lane. Native and game views agree. The roof/stair termination and P04's upper facade/rail intersection are unchanged, so T08 remains partially open.

Before:

![Before](game/before/P15/P15_0.png)

After:

![After](game/after/P15/P15_0.png)

The first game replay attempts used an overly specific batch name and then stale tangent arrays; those captures were rejected. The final `game.log` contains no script/render errors and confirms two generated mesh replacements. Native logs retain the known material UID fallbacks. The frozen game replay changes appearance only; physical evidence comes from separately committed current native collision. No fresh streaming, global performance or full-suite acceptance.

## Reproduction

- `tests/harness/september17_rail_fragments_payload.gd`: build current photo payload and compare to saved pre-fragment payload.
- `tests/harness/september17_rail_fragments_native.gd`: isolated matched pairs.
- `tests/harness/september17_rail_fragments_clearance.gd`: actual native collider survey.
- `tests/harness/september17_town_repairs_game.tscn -- --frozen --snapshot res://docs/qa/2026-09-16-manual/05-town-rails/baseline/world.scn --spot P04 --camera-poses-root res://docs/qa/2026-09-16-manual/05-town-rails/baseline --output res://docs/qa/2026-09-16-manual/14-rail-fragments/game`.

Source SHA-256:

- `scripts/terrain/features/villages/fabric/WarrenTransitionSurfaceBuilder.gd`: `ddd44664390362b6d2fcff1541544c0067ef548fc80a95044a8069e72ec3773f`
- `tests/test_september17_rail_fragments.gd`: `177d98db943bf507cafc02f6fb6b24008cad0eb6cc59c840cc60ce8b7c242df0`
- `tests/harness/september17_town_repairs_game.gd`: `796e0d6320f00385fe14235ed3e6c430760e8501f198a021f673f2b9a5e1607a`
