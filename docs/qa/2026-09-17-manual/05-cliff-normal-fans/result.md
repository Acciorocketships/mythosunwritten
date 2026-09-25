# Connected cliff-face normal correction

Neighboring triangles previously computed different normals at the same vertex by weighting incident faces relative to each triangle independently. This exposed triangle boundaries even where the physical stone had no intended crease. The first photographed formation reproduces **162 discontinuous edges among 1,183 gently joined edges** in the [red test](red.log).

Production now groups incident triangles into connected smooth fans through shared edges. Each fan receives one area-weighted normal at its common vertex. Geometric folds of 50 degrees or greater retain separate fans. Thin roots still blend into the sampled native wall normal afterward. Geometry construction, turf selection, UVs, colors, transforms and collision remain unchanged; the geometry-generating source prefix is byte-identical to the saved baseline. The redundant preliminary SurfaceTool smoothing pass was removed after verification.

## Verification and visual judgment

[Final focused suite](final-tests.log): **11 tests / 31 assertions pass**. [Post-cleanup normal/geometry checks](cleanup-tests.log): five of those tests / 19 assertions pass again. The first formation now has zero unwanted discontinuities, as do nearby controls with 8,858, 2,844 and 5,308 eligible edges. Sharp 90-degree folds and gently rounded faces both retain their intended behavior. Existing tests preserve actual vertices, turf and attachment weights, finite unit normals, full-height coverage, wider selected feet, and tall physical sampling.

One exploratory neighbor test included anchor 30, which has no exposed stone beyond the two-metre attachment zone. Its sample-count assertion failed, so it was excluded from the thick-face controls rather than weakening their required edge count. Thin attachments remain covered by independent native-mesh raycasts: mean mismatch is 0.98 degrees over 823 samples.

Seventeen native game-context views and five freshly constructed 64 m study views completed. P12 front and +8 degrees retain continuous rounded stone with clearer ledge joints; P20 oblique retains short fractures and the irregular lower toe. P05 remains dark but does not gain new light triangles across the broad face. The tall close view retains resolved fractures throughout its height. This accepts the normal-continuity correction, not the whole cliff-art task. Broad forms remain too soft in places and the exposed native corner pattern remains conspicuous.

| View | Before | Current |
|---|---|---|
| P12 front | [Before](../03-cliff-plant-spacing/candidate/P12_front.png) | [Current](candidate/P12_front.png) |
| P12 +8° | [Before](../03-cliff-plant-spacing/candidate/P12_reported_8.png) | [Current](candidate/P12_reported_8.png) |
| P20 oblique | [Before](../03-cliff-plant-spacing/candidate/P20_oblique.png) | [Current](candidate/P20_oblique.png) |
| P05 | [Before](../03-cliff-plant-spacing/candidate/P05_vines.png) | [Current](candidate/P05_vines.png) |
| Tall close | [Before](../01-cliff-lighting/candidate2/close.png) | [Current](tall/close.png) |

The game context retains frozen terrain, grass and collision and rebuilds visible rocks/plants. It does not prove fresh hydraulic admission, streaming or traversal. No global performance or gold-standard art claim. The native runs completed without script errors; headless tests retain the known non-fatal certificate message.

## Further cut experiments

`cut-study/` retries the earlier deeper chips with connected normals. It reduces artificial shading discontinuities, but the small cut geometry itself still exposes jagged near-face facets. Rejected. `broad-cut-study/` uses larger, less frequent cuts with wider rims; P12 front still reads predominantly as a broad soft face, so this is also rejected. Both are detached fixtures; neither geometry is installed in production.

Reproduce native current: `tests/harness/september16_cliff_transition_context.tscn -- --output=res://OUTPUT`. Use `--generator=res://tests/fixtures/september17/cliff-normal-fans/before.gd` for the exact old normals. The red fixture is `tests/fixtures/september17/cliff-normal-fans/red.gd`. Fresh tall construction uses `tests/harness/september16_cliff_transition_study.tscn -- --height=64 --output=res://OUTPUT`.

Final production source SHA-256: `c5bf218b90503a712e3a504160b8a367562ba69262b5c95af9b9d919fa15c01d`.
