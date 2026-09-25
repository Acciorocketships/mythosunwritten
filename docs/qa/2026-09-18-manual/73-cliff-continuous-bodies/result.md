# Physical cliff formations — continuous-body study

Status: study only; rejected for production. Production remains pass 69. C01,
C02 and C03 remain open. No original water, town, streaming or biome issue is
closed by this pass.

The owner asks for actual bumps, outcroppings and random rock formations. This
pass changes physical vertices and solid topology; it does not add a repeated
normal map, crack shader or color-only relief. Native Forward+ Metal renders
are the acceptance evidence, not the numerical geometry test alone.

## Experiments and visual decisions

1. `authored.gd` varies the inherited sampled rock supports. The amber view
   retains low bulges, dark undercuts and an overly plain upper face. Rejected.
2. `build_union_voxel.py` reconstructs a solid and unions rotated CC0 Nature
   Pack rock hulls. It reveals visible voxel sampling and detached-looking
   lower forms. Rejected.
3. `build_union.py` and `build_world_union.py` instead rasterize the actual
   front geometry into a continuous signed-distance approximation, union
   rotated rock hulls and wider feet, and extract one connected solid. The
   second tall render reduces sampling noise but still has broad smooth faces,
   blunt projections and substantial dark lower edges. Rejected.
4. `split_turf.py` splits the same physical triangles along a continuous
   slope contour, sharing the intersections between materials. This is more
   coherent than whole-triangle selection, but the final game render still
   has ragged turf patches, narrow boundary marks and overly large plain
   planes. The tall version retains rectangular composition and undercuts.
   Both are rejected, despite their closed topology.
5. `embedded-detail.gd` tests an alternative that preserves the existing
   ledge topology and displaces it using finite, rotated Nature Pack fronts.
   It adds physical width and depth while leaving the crown alone. The amber
   view retains its ledges, but the tall render exposes narrow fins, abrupt
   joins and repeated rounded patches. Test-green does not make this an
   accepted result. Rejected.

The two mechanisms expose different problems: full remeshing damages the
ledge finish; deforming the inherited sampling structure retains its columns
and creates fins around sharper incoming forms. Neither is a sufficient fix.

## Native views inspected

- [Authored amber](authored-world/P20_oblique.png)
- [First voxel tall](union-tall/oblique.png)
- [Supported continuous solid](supported-union-tall/oblique.png)
- [Initial union in amber](union-world/P20_oblique.png)
- [Final continuous solid in amber](contour-world/P20_oblique.png)
- [Final continuous tall solid](contour-tall/oblique.png)
- [Existing topology with physical formations, amber](embedded-world/P20_oblique.png)
- [Existing topology with physical formations, tall](embedded-tall/oblique.png)

The final contour world run also captured the ordinary 17-angle context set.
The rejection is already visible in the two inspected final oblique images;
this report does not claim all 17 were visually accepted or individually judged.

## Reproduction and scope

Sources are in `tests/fixtures/september18/cliff-continuous-bodies/`.
`export_source.gd` exports the 48 m by 32 m tall wall. `export_world.gd` exports
actual frozen-world face records. The world union wrapper replaces only records
19, 20 and 21 near P20, at native origins (-498,32,-253.5),
(-480,32,-253.5), and (-457.5,32,-253.5), with widths 12, 24 and 21 m.
All three are 8 m high. Other faces and corners retain production behavior.
This site-specific baked wrapper is strictly an art study.

Python dependencies for the offline union are numpy, scipy and scikit-image;
an isolated runtime was installed at `/tmp/story-cliff-mesh-venv`. The original
OBJ assets are Ultimate Nature Pack Rock_3 through Rock_6, CC0. Hull transforms,
source hashes and resolutions are recorded in the generated manifests. The
world resolution is 0.12 m; the tall resolution is 0.20 m.

Godot renders use `september16_cliff_transition_context.tscn` with
`--generator=res://tests/fixtures/september18/cliff-continuous-bodies/world-union.gd`
and the matching union tall scene. The embedded alternative uses
`embedded-detail.gd` and `embedded-detail-tall.tscn`. Native GPU runs completed
with exit code zero. All runs are frozen/studio geometry tests, not fresh
production regeneration.

## Measured checks

The first mesh-health check failed on collapsed tiny triangles. Shared
sub-millimetre vertex welding and bounded short-edge collapse fixed the four
final remeshed solids. `check_union.py` verifies one connected component,
exactly two incidences per edge, no degenerate triangles and clockwise exterior
signed volume. Final triangle counts are 259,978 for the tall wall and 77,842 /
139,004 / 134,108 for the three world sections. These are expensive study meshes,
not an accepted runtime budget.

`check_turf_subset.py` verifies every final turf triangle is an exact member of
the corresponding physical surface (zero missing triangles on all four meshes).
The final counts and hashes are in `turf-subset-checks.json`. Manifests were
refreshed after final shared-edge welding. A fresh end-to-end bake hash replay
has not been claimed.

The inherited upper-formation invariant fails on current production: zero
new upper projected samples; 3/6 assertions. The embedded-detail alternative
passes all 6 assertions: 14,128 of 52,094 sampled upper vertices gain more than
0.15 m, 32,051 stay within 0.02 m, 367 columns participate, maximum added
projection is 1.154843 m, and the top metre moves 0 m. This proves real local
geometry and quiet intervals. It does not prove the result looks good.

No self-intersection proof, native capsule traversal, fresh grass/water
reservation verification, streaming timing or general suite acceptance is
claimed. The offline remesh is not wired into workers. The embedded alternative
is also not promoted: its inherited placement bounds and ground reservations
would need to be updated before any production use.

## Production preservation

The production generator, corner mapper and material retain their pass-69
hashes in `source-hashes.json`. No production geometry or shader was changed.
The work remains open; the rejected artifacts are retained so the next pass
can address the topology/composition defects rather than repeat these tests.
