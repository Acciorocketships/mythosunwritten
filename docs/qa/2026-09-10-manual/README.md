# September 10 manual review

The fixes were developed and judged individually, with rejected candidates retained in each issue folder. The [issue ledger](review.md) indexes all fifteen investigations. Each result describes the change, matched game images, pixel differences, physical checks and acceptance limits.

## Main results

- [Water continuity and shoreline closure](12-water/result.md): 24 judged render pairs, four real-character traversals and a 73,322-point shoreline scan. The photographed cliffs/folded sheets are fixed; eight historical water failures remain unchanged.
- [Terrain queue and repeated travel](13-streaming/result.md): sixteen teleports, long walks and queue-event profiling. Accepted extended routes have zero frozen walking time. Cold generation still takes minutes in some locations.
- [Grass readiness](14-grass/result.md): a separate visual worker removes measured underfoot/nearby grass delays across four walks without retaining canonical water/terrain plans.
- [Town forms, tiny settlements and T roofs](15-city-form/result.md): four warren shapes, smaller defaults, 3–6-house gathering places, low outer courses and shared prefab/modular streets. All 48 construction cases and 50 hamlet walking traversals pass. [Asset-informed next compositions](15-city-form/asset-compositions.md) distinguish implemented features from windmill/island/paired-town proposals.

## Visual examples

These are real Godot outputs. The tiny-town fixture below isolates construction on flat terrain; it omits ordinary streamed biome dressing and atmosphere.

![Three-house tree green](/Users/ryko/story/docs/qa/2026-09-10-manual/15-city-form/hamlet-candidate4/3/square.png)

The water comparison uses the same reconstructed camera before and after; neighboring views and actual geometry checks accompany the pixel differences in the water report.

![Water before](/Users/ryko/story/docs/qa/2026-09-10-manual/12-water/before/15_water_cliffs_exact.png)

![Water after](/Users/ryko/story/docs/qa/2026-09-10-manual/12-water/candidate14/15_water_cliffs_exact.png)

## Camera and validation limits

The source overlays contain rounded player/crosshair coordinates rather than complete camera transforms. Before/after captures use identical reconstructed cameras, but the exact original full-precision angles cannot be recovered. That limitation is stated in each photographed review.

This is acceptance of the reported defects and measured routes, not a globally green repository test suite or a guarantee of instant cold loading. The new wider crescent also costs more than the old round town despite the measured optimization; its timing test was explicitly recalibrated from three runs. No windmill, island or paired-town bridge feature is claimed implemented.
