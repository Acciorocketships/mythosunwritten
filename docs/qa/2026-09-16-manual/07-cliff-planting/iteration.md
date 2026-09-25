# September 16 shelf and planting follow-up

Scope: owner follow-up to C01–C04, including [the circled shelf](reference/owner-shelf.png). This reopens the previous Production04 art judgment. The original 23-image inventory remains in [issues.md](../issues.md).

## Observations and choices

- The circled shelf narrows below its lip, making the left end curl back toward the wall. Its long level edge and sparse neighbors read as separate attached platforms.
- Increase connected outcrop width and frequency, keep the high ridge buried, and require successive lower sections to bear the sections above them. Retain actual triangle collision and public/water exclusions.
- Vary whole ledge grades as well as edge height; retain smaller level walking patches among sloping shoulders. Keep the wall contact and steep faces gray, with native biome turf on flatter ledges.
- Replace miniature rounded bushes with existing Fern_1, Plant_01 and Plant_03 assets. The [native asset catalogue](plant-catalogue.png) also inspects other available plants and six vine sources. These are existing models with their native textures, not generated replacement images.
- Mix all six vine silhouettes within hanging clusters, varying bend, taper, mirror, length and spatial density. Retain the source ivy cutouts and native wall relief.

## Rejected candidates

1. Geometry01: larger vertical scale let some shoulders protrude above the cliff crown. Rejected; cap scale to the actual parent height.
2. Geometry02/03: nested sections eliminated the curled end and increased coverage, but game captures still showed long block-like risers. [Production01](production-01/P05/P05_0.png), [matched shelf](context-01/P05_vines.png), and [wide view](wide-01/P11_0.png) are intermediate evidence, not the final result.
3. First vine mix: wide source clusters started above the native cliff crown. A native support check failed. Lowering their baked origin fixed the actual source geometry; runtime canonical wall transforms remain unchanged. Final support check: 203 assertions; native relief check: 32 assertions.
4. First fern material: its unused source grayscale vertex channel multiplied the biome tint and rendered leaves almost black. The prepared visual now clears that unused colour channel while retaining its source triangles, UVs, texture and alpha cutout. The native studio replay shows readable foliage.

## Current candidate: Geometry04

Long risers slope outward instead of remaining almost vertical; central level patches are shorter, their sides grade into uneven shoulders. The source remains one closed solid per outcrop, including its lower terraces. Larger footprints preserve wet/public exclusion and deterministic halo ownership. The selected plants replace the spherical ledge population.

[Studio oblique](study-04/oblique.png) and [close](study-04/close.png) inspected. Focused geometry, moss, collision payload, ownership, grass and coverage run: **24 tests / 703 assertions pass**. Fresh Amber/Highland game review and actual traversal remain pending; studio success alone is not acceptance.


## Superseded by owner rejection

The owner rejected Geometry04 / later two-row variants: regular pods and flat courses remain. Work continues in [08-continuous-cliffs](../08-continuous-cliffs/iteration.md), using the subsequently supplied rounded cliff reference. The test counts above do not establish art acceptance.
