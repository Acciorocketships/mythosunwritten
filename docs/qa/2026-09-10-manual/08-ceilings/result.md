# Ceiling and masonry result

Accepted for photos 4, 8 and 9 and the inspected nearby views.

Singleton exposed masonry now fits its complete native stock into the one owned
band. It no longer extends through windows or walking passages below. The same
ownership controls wall clearance and facade-miter selection. City garden walls
use the city masonry stock and palette; their corners fit the actual rounded
native grass silhouette, retaining every source face and UV. The original grass
lip and ordinary world terrain rock remain intact.

Height correction alone was rejected because photo 4 still mixed rock families.
Square city-stone corners were rejected by actual grass-triangle silhouette
checks. The final shared rounded corner mapping passes in four orientations.
See [investigation](investigation.md) for the measured cause and rejected trials.

All 18 final game before/after/ROI-difference pairs were inspected, including
nearby left/right, camera jitter and production-camera views. The three full
final images and full difference maps were also inspected. Photo 4 has coherent
masonry over the market passage; photos 8/9 expose the existing complete walls
and windows after the unowned hanging stock is withdrawn. No new seam appeared
in the inspected views. All three before/after camera JSON records are identical.
The original screenshot coordinates are rounded: these are matched reconstructed
poses, not recovered original full-precision camera transforms. PNG size is
1718 × 1034 on this native renderer.

| View | Full mean RGB difference (0–255) | ROI mean (0–255) | ROI pixels with channel difference > 20 |
| --- | --- | --- | --- |
| 04_ceiling_exact | 1.583268 | 7.951101 | 17.2399% |
| 08_hanging_stone_exact | 4.362084 | 11.104723 | 22.4022% |
| 09_stone_course_exact | 1.752660 | 8.071296 | 22.4234% |

[All metrics](diff/metrics.json). Changed pixels are evidence of
scope; acceptance follows visual inspection and geometry checks.

Ten additional native before/after/difference pairs cover photos 1/2/3/4/5/7/8/9/12/17.
They retain the accepted prefab floors, grass silhouettes, guards and skywalk
bearings. Photo 3 is pixel-identical in this fixture. Native source checks retain
UV arrays, reject degenerate triangles and place actual stone vertices beneath
actual grass-cap triangles.

Final focused run: 25 tests / 4,806 assertions. Production run: 31 / 1,131.
Facade-return run: 7 / 202. Removing duplicate ceiling tests gives 57 distinct
tests / 6,021 assertions, all passing with clean exits. Both final physical
surveys match baseline: 120 cells / 175 crossings and 297 cells / 424 crossings,
with no blocked samples. [Clearance comparison](clearance-comparison.json).

This accepts the photographed finishing defects; it does not claim a globally
green terrain/water suite. Cold distant-site generation remained expensive in
the capture logs and belongs to the pending extended streaming review.

Final evidence: `before`, `after`, `diff`, `native-before`, `native-after`,
`native-diff`. Candidate folders are rejected/intermediate, not final evidence.
