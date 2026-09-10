# Manual review comparisons

Each strip shows **before → after → amplified pixel difference**. The views reconstruct the rounded player/crosshair readings from your photos. Before/after cameras are identical; the original camera cannot be recovered exactly from those readings alone. Character and particle animation can also contribute to the differences. The [review report](/Users/ryko/story/docs/qa/2026-09-07-manual/review.md) gives the geometry and walking checks supporting each judgment.

## Full views from all six photo positions

| Photo | Before | Final | Pixel comparison |
|---|---|---|---|
| 1. Upper doorway gap | [Before](/Users/ryko/story/docs/qa/2026-09-07-manual/before/01_upper_door_gap_exact.png) | [Final](/Users/ryko/story/docs/qa/2026-09-07-manual/final/01_upper_door_gap_exact.png) | [Crop and difference](/Users/ryko/story/docs/qa/2026-09-07-manual/final-diff/01_upper_door_gap_comparison.png) |
| 2. Gallery gaps and flicker | [Before](/Users/ryko/story/docs/qa/2026-09-07-manual/before/02_gallery_gaps_flicker_exact.png) | [Final](/Users/ryko/story/docs/qa/2026-09-07-manual/final/02_gallery_gaps_flicker_exact.png) | [Crop and difference](/Users/ryko/story/docs/qa/2026-09-07-manual/final-diff/02_gallery_gaps_flicker_comparison.png) |
| 3. Parallel paths | [Before](/Users/ryko/story/docs/qa/2026-09-07-manual/before/03_parallel_paths_exact.png) | [Final](/Users/ryko/story/docs/qa/2026-09-07-manual/final/03_parallel_paths_exact.png) | [Crop and difference](/Users/ryko/story/docs/qa/2026-09-07-manual/final-diff/03_parallel_paths_comparison.png) |
| 4. Garden wall | [Before](/Users/ryko/story/docs/qa/2026-09-07-manual/before/04_garden_wall_exact.png) | [Final](/Users/ryko/story/docs/qa/2026-09-07-manual/final/04_garden_wall_exact.png) | [Crop and difference](/Users/ryko/story/docs/qa/2026-09-07-manual/final-diff/04_garden_wall_comparison.png) |
| 5. Ground-level wall gaps | [Before](/Users/ryko/story/docs/qa/2026-09-07-manual/before/05_ground_gaps_exact.png) | [Final](/Users/ryko/story/docs/qa/2026-09-07-manual/final/05_ground_gaps_exact.png) | [Crop and difference](/Users/ryko/story/docs/qa/2026-09-07-manual/final-diff/05_ground_gaps_comparison.png) |
| 6. Town slopes | [Before](/Users/ryko/story/docs/qa/2026-09-07-manual/before/06_town_slopes_exact.png) | [Final](/Users/ryko/story/docs/qa/2026-09-07-manual/final/06_town_slopes_exact.png) | [Crop and difference](/Users/ryko/story/docs/qa/2026-09-07-manual/final-diff/06_town_slopes_comparison.png) |

The individual repair comparisons below isolate each change in the requested order.

## Diagonal wall gaps

![Diagonal wall gaps](/Users/ryko/story/docs/qa/2026-09-07-manual/01-gaps-diff/01_upper_door_gap_comparison.png)

## Gallery corner, opposite-side inspection

![Gallery corner, opposite-side inspection](/Users/ryko/story/docs/qa/2026-09-07-manual/01-gaps-diff/02_gallery_gaps_flicker_orbit_-90_comparison.png)

## Ground-level diagonal gap

![Ground-level diagonal gap](/Users/ryko/story/docs/qa/2026-09-07-manual/01-gaps-diff/05_ground_gaps_comparison.png)

## Overlapping floor textures

![Overlapping floor textures](/Users/ryko/story/docs/qa/2026-09-07-manual/02-floor-diff/02_gallery_floor_comparison.png)

## Parallel paths

![Parallel paths](/Users/ryko/story/docs/qa/2026-09-07-manual/03-path-diff/03_parallel_paths_comparison.png)

## Walking up the stairs, same input at tick 30

![Walking up the stairs, same input at tick 30](/Users/ryko/story/docs/qa/2026-09-07-manual/04-stairs-diff/volume.transition.04_tick_30_comparison.png)

## Missing wall beneath the garden

![Restored garden wall](/Users/ryko/story/docs/qa/2026-09-07-manual/05-garden-final-diff/04_garden_wall_comparison.png)

## Continuous town slope

![Town slope before, after and pixel difference](/Users/ryko/story/docs/qa/2026-09-07-manual/06-slopes-diff/06_town_slopes_comparison.png)

The player also walks this slope up and down without jumping; all five stair flights remain walkable.
