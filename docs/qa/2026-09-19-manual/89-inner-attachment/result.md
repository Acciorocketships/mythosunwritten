# Continuous inner-corner attachment — pass 89

The inner join switched from diagonal native-corner sampling to perpendicular straight-wall sampling at `abs(u) = 1`. That ignored how the diagonal sweep also moves along each adjoining wall. The frozen previous generator differs from actual native backing by up to 0.500 m in the 48-point control and has a 0.555 m synthetic jump across the switch in the identity-pose control.

The inner backing table now samples the native corner and both adjoining straight-wall arms as one surface. Geometry and root normals use that same continuous table. The table is detached on the main thread before worker placement; its packed numeric data occupies about 0.30 MiB once per process. The outer mapping and independent thick-rock relief remain unchanged. No crack overlay or additional surface noise is added.

## Rendered judgment

Three matched views reconstruct current rock on the pass-88 fresh game snapshot at identical saved anchors and camera poses. The attachment change is local: the upper inner join follows the native backing rather than acquiring a discontinuity from the sampler switch. Broad lower bearing and the existing ledges remain. The front and elevated views still show pointed shelf intersections and broad plain faces; this repair does not establish overall cliff art acceptance. Plant contacts are regenerated against the changed geometry, so foliage placement can differ too.

[Before inner join](before/inner_front.png) · [Final inner join](final/inner_front.png) · [Final elevated join](final/inner_above.png) · [Outer control](final/outer_oblique.png)

These are geometry replays on real saved surroundings, not a fresh terrain-generation run. The saved world itself is not rewritten. The initial `after` directory precedes the final sampling-resolution refinement; `final` is authoritative.

## Verification

- **18 tests / 126 assertions pass**: native attachment, short/tall closed solids, production ownership and grounding, detached worker output, public-footprint exclusion, crown clearance and snapshot replay. Native backing error is at most **0.01556 m across 72 samples**, including samples between table entries. Increasing only vertical table resolution did not fix the off-grid error; finer horizontal sampling did. The initial off-grid test failures are preserved in the logs.
- **13,624 inner upper-metre samples**, across three heights and four orientations, retain maximum added projection **0.00510 m** above native backing. Existing straight/outer crown checks also pass.
- The actual saved game scene supplies **seven native wall pieces / 48 ray samples**, with no missing intersection and maximum backing error **0.000004 m**. This independently checks the canonical assembly used by the table against real native instance transforms.
- **4,169 physics-server contacts across 32 generated forms** pass with zero misses and maximum error **0.000053 m**. This covers both corner types, four heights, four rotations and two seeds.
- Rebuilt current forms retain **224 buried native-ground foot samples**, no missing ground and no exposed roots. All four outer-corner rock and turf arrays exactly match the saved pass-88 world; the three inner forms change as intended.

The earliest `cliff89-red.log` used an incorrectly interleaved diagnostic backing mesh and is excluded. `cliff89-red-corrected.log` uses the corrected independent mesh and reproduces both original failures. `cliff89-final-tests.log`, `cliff89-final-physics.log` and the `final` render directory describe selected production.

[Native instance audit](native-audit.json) · [Grounding audit](ground-audit.json) · [Collision audit](physics.json) · [Production delta](attachment.patch). No player traversal, full-world regeneration, startup improvement or broader water/town/streaming acceptance is claimed. The original judging register remains open.
