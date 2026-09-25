# September 16: continuous cliffs, then rounded boulder reference

**In progress. None of the intermediate art candidates below is owner-approved.** Original inventory: [24 issues / 23 photos](../issues.md).

## User evidence and criteria

- [6:10 PM annotated rejection](reference/owner-pods.png): long straight parallel rows, regular pods, bare upper wall, shallow straight toe, inconsistent detail.
- Follow-up: ferns must root in actual wall crags and the junctions of outcrops/native wall; ferns and ivy must use the grass colour, not tree foliage colour.
- Further rejection: undulating two rows are still two continuous rows. Ledges need independent widths, elevations, grades, thicknesses and depths.
- Further clarification: do not copy the native repeating 3 m × 4 m wall pattern onto outcrops. Use irregular crags and occasional much deeper masses.
- [Rounded cliff reference](reference/rounded-cliffs.webp): owner rejected the triangle/parallelogram study. Target is broad weathered rounded rock masses, irregular fractures and smaller ledges between larger forms, all integrated into the cliff.

## Rejected iterations

1. Studies 01–05: replaced repeated closed pods with a continuous world-coordinate surface. Raised shoulders and varied toe; two courses remained. Flat-normal checkerboard was rejected. Study05 softened lighting but did not solve composition.
2. Production01 / context01: real seeded game geometry; missing empty-turf guard and native-wall plant probe were corrected afterwards. Not final evidence.
3. Production02 / wide03 / highland01: two-course candidate, later explicitly rejected by owner. 21 tests / 833 assertions, one native-wall contact test / 2 assertions, two GPU tint tests / 60 assertions and 12 player walks passed **for that candidate only**.
4. Study06: finite independent shelf events, still used repeated native relief. Rejected by owner clarification.
5. Studies07–08: irregular noise, deeper buttresses and continuous moss blending. Still triangular/parallelogram surface character; explicitly rejected by owner reference.
6. Study09: first rounded union. Rejected internally: inflated cushion overhangs and stretched rear crowns.
7. Studies10–11: supported lower profile, adaptive crown sampling. Rejected internally: long extruded bases, still stretched rear edges.
8. Study12: large lower boulders with smaller upper masses. Better hierarchy, but crowns still produced needle-like strips.
9. Study13: finite shoulder curvature removes infinite-tangent stretched crown triangles. Current candidate, pending real-game judgment. Buried end caps no longer average their normals into the exposed front. Hidden backing uses a closed perimeter fan; tiny projected triangles that cannot hold a whole grass patch skip grass preparation.

## Current implementation

`CliffRockRelief.gd` generates one closed exposed union per canonical wall interval, sampling shared world-coordinate boulder events. Large low masses, smaller upper masses, different heights/widths/depths/tilts, rounded shoulders and irregular physical weathering. Neighboring ownership intervals share the field. `CliffRockDressing` retains actual triangle collision, water/public exclusions, real terrain seating and shared ownership.

`cliff_relief.gdshader` blends native gray rock into native turf only on flatter exposed shoulders, protecting the wall collar. It retains the grass palette and ground-style field.

Ferns use actual concave edges on original wall triangles and added rock triangles. Stems orient out of the supporting crevice; roots embed at the contact. Existing Quaternius fern geometry and native plant assets replace small spherical bushes. Mixed native ivy silhouettes remain.

Both fern and ivy materials use native grass swatch, local ground tint **and the grass shader's final ground-style field**. The final field was missing from Production02/wide03, leaving foliage too green in amber despite correct instance multipliers; those captures are explicitly not final colour evidence.

## Verification status

- `topology-07.log`: current closed-edge/crown test passes, 1 test / 10 assertions.
- `regressions-05.log`: finite-shelf prototype had a true grass chunk-ownership mismatch and an obsolete per-panel AABB-max depth statistic. Both need current-candidate verification; replacing depth statistic with actual 10–90 percentile physical-column depths preserves the requested variation criterion.
- Current `grass-08.log` and fresh `production-04.log` are running. Production03 stopped as superseded; no acceptance claimed from incomplete runs.
- Previous 12 player walks do not validate the replacement rounded geometry. Repeat on final saved game geometry.
- Broad hydraulic, streaming, town, full-suite and performance acceptance remain open. Original task backlog remains in the issue register.

## Rounded reference follow-up (current)

Studies09–13 replace the independent-shelf height profile itself with a union of rounded boulder fields. Large ground-bearing masses use broad proportions; smaller upper pieces have independent poses and sizes. Weathering has no copied native wall period. Finite shoulder derivatives and adaptive crown rows remove the infinite-tangent strips. Adjacent chunk caps are excluded from exposed-face normal averaging.

The narrowed grass preparation gate now skips projected triangles with inradius below 0.10 m. Existing GrassField whole-patch border checks still decide actual admission. `grass-08` has **14 real elevated roots, zero escaped patches, zero buried roots, and identical full/split owner buffers**. The old “more than 20 roots” assertion was a density pin from the rejected broad flat ledges. It is replaced with coverage of more than five distinct real support triangles; whole-patch containment and burial tests remain unchanged. Final regression is running.

The previous prototype's AABB-max depth statistic is replaced by the actual 10th–90th percentile of physical column-front depths. Whole-panel maxima can all contain a large boulder while depth along each panel varies strongly. Water/public exclusions and full actual collision arrays remain checked.
