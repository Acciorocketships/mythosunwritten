# Cliff style restoration

**Reopened by the owner:** the P03 comparison still showed visible defects. This report's completion claim is superseded by the [annotated P03 follow-up](../2026-09-26-p03-followup/issues.md).

The owner rejected the previous pass, especially p03's disconnected tops and angular, recoloured rock. Its acceptance claim is withdrawn. This repair restores the original slope/rock art and limits production changes to old lips and holes.

## Restored

The original surface-net mesher, shoulder/foot radii, stone palette, moss/grass shaders, rock fitting, grass density and support paths are restored. The direct heightfield, wider slopes, fin trimming, material tint changes, grass footprint/colour changes and blanket native-wall withdrawal are removed. Only `CliffSlopeField.gd` and `CliffSlopeEnvelope.gd` retain production edits.

## Narrow repairs

1. **Missing columns:** a deep bedrock notch can lie below its plateau. The old height comparison omitted the upper columns and exposed the void. The existing four-metre neighbourhood now includes those columns; the original surface-net algorithm meshes them.
2. **Tiny holes:** winding follows the sign-changing grid edge. The old per-triangle normal test could reverse one triangle in a folded quad, giving adjacent triangles inconsistent winding. Vertices and their gradient normals are retained.
3. **Old lips:** a native grass lip is removed only when its entire projected vertex footprint has replacement columns. Exposed native backing walls keep the original height/burial rule. This specifically avoids the rejected pass's unsupported flat tops. A later p07 control isolated a thin exposed edge to the old skirt, not the slope: a skirt triangle is now withdrawn only when a full grid neighbourhood covers every tested point. The uncovered-wall regression prevents removing needed backing.

## Programmatic and controlled evidence

- [Focused tests](tests.txt): **13 tests / 339 assertions pass**. They reproduce 15 inconsistent shared edges and 16 missing-column rays in the original frozen photo 11 mesh, then verify zero remaining failures.
- The same suite pins unchanged original face positions, shading normals and rock exposure away from the hole, original slope radii, covered-lip removal, uncovered-wall preservation and partial-coverage rejection. Existing level-step, water-runout, steep-grass and optional underlip checks pass.
- [Profile regressions](profile-tests.txt): **10 tests / 42 assertions pass**.
- [Controlled original mesh](mesh-original-one.png), [repaired mesh](mesh-repair-one.png), [pixel difference](diffs/mesh-repair-x4.png). The inspected difference is confined to the large opening and small missing triangles. The repaired one-sided and double-sided images are **pixel-identical**, so the holes are not merely hidden by two-sided rendering. [Geometry measurements](mesh-probe.txt).

## Native visual review

Original-style baselines are the `*-close/00` images under [the earlier QA directory](../2026-09-26-manual-cliffs/result.md); its `review-*` images show the rejected implementation and are not the target. The [three-way p03 comparison](p03-style-comparison.jpg) shows the original, rejected and restored art.


Nine matched native before/after pairs and their amplified pixel differences were inspected. Each comparison below contains original, repaired and difference panels. Moving grass/water contributes to the full-scene differences; the frozen mesh control above isolates the geometry repair.

| Owner image | Inspected comparison | Finding |
|---|---|---|
| #2 | [Before / after / difference](diffs/p02-review.jpg) | Original river-bank profile and materials retained. |
| #3 | [Before / after / difference](diffs/p03-review.jpg) | Foreground opening closed and distant missing backing filled; original rounded sides and colours restored. |
| #5 | [Before / after / difference](diffs/p05-review.jpg) | Small triangular opening filled; original stone mass and ledges retained. |
| #6 | [Before / after / difference](diffs/p06-review.jpg) | Far bridge-bank openings filled, retaining original rock treatment. |
| #7 | [Before / after / difference](diffs/p07-review.jpg) | Covered old lip and thin V-shaped skirt edge removed; original slope retained. |
| #8 | [Before / after / difference](diffs/p08-review.jpg) | Original rolling slope profile retained. |
| #11 | [Before / after / difference](diffs/p11-review.jpg) | Large opening and small missing triangles filled with the original surface-net rock/moss shape. |
| #12 | [Before / after / difference](diffs/p12-review.jpg) | Covered scalloped lips removed and gaps filled; broad original rock face retained. |
| #13 | [Before / after / difference](diffs/p13-review.jpg) | Small gap repaired; original rock and top texture retained. Texture redesign is deferred. |

Final captures are `north/01`, `river/91` and `south/91`. Northern images follow the corrected winding and lip repair with a full five-chunk rebuild. The later skirt-only refinement was verified by full production rebuilds in river/south. The p07 [native-piece control](river/p07-no-native.png) and [skirt control](river/p07-no-skirt.png) isolate the remaining dark edge to the skirt before that refinement. Northern `00` is an intermediate winding experiment; river/south `90` are diagnostic replays, not final captures. The extra southern `90/p03.png` has unloaded distant terrain and is excluded from evidence.

Native collision audits hit **526 of 526 sampled slope contacts**: [north, 249](north/surface-audit.json), [river, 138](river/surface-audit.json), [south, 139](south/surface-audit.json). River/south audits were rerun after the final full rebuilds. These are surface-contact checks, not exhaustive traversal or grass-root acceptance.

The narrowed restoration and hole/lip repair is complete. The previous pass's broader slope, traversal, texture and grass changes are withdrawn; the other original judging categories remain deferred at the owner's request. This report does not claim that all eleven original categories are fixed.
