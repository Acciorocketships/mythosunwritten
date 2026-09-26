# Meadow landscape rocks — September 25

All active landscape dressing rock choices and both slope rock pools use Meadow. The twelve ground visuals are baked portable resources with native convex collision; source art remains available for comparison. Small ambient rocks are enlarged. Large ambient rocks use five distinct assets rather than duplicate entries.

Mid-slope groups use two or three different layered Meadow models, with primary widths of 6–8.5 m. Their depth is compressed. A shear follows the slope while preserving horizontal authored ledges: grass faces upward, rather than toward the slope normal. Outer end bands recess behind the terrain; the central source vertices remain unchanged before placement. Actual mesh samples constrain exposed projection to roughly 0.8 m and ensure a substantial visible side. Foot boulders stay upright, with their base buried. Face rocks do not add turf swells or distance-based green halos.

The rock shader restores Meadow's warm stone and normal-driven top layer. Following owner feedback, the green now uses the exact shared slope colour function, biome ground palette, world-space detail texture and grading. It does not use the pack's brighter green. The slope's normal is carried separately from the rock's normal, so ledge orientation does not change the surrounding green treatment. Lighting can still differ on a horizontal ledge.

The envelope's alternate shoulder widens to 3.4 m; less noise blurring and stronger smooth contrast create broad ridges and hollows. The lateral relief regression now requires over 1.2 m of variation. The corner-foot test permits one 0.5 m sampling cell beyond its previous ratio for the broader shoulders.

## Review and limits

Fresh nine-chunk native world: seed 2697992464, site (262,30,1045), grass enabled. Cold startup took 527.543 seconds; no performance improvement is claimed. Final rock settings were hot-rebuilt on that loaded terrain. Ambient placement in these world images predates the final expanded small-rock choices and ground-tint descriptor update; the runtime catalog tests cover those final resources.

The owner supplied dedicated cliff-face reference art and permits switching the exposed faces back if Meadow still reads as ground boulders. This remains a Meadow trial for visual review, not claimed art acceptance. Slope props remain visual-only as before; the terrain solid has collision. Ground dressing rocks have source-derived collision.

- [Final world view](detail.png)
- [Second angle](side.png)
- [Original Meadow top-layer preview](01-M-1.png) — earlier pack-green material, retained as source comparison only.

## Validation

- Before the latest orientation/material steering: 39 tests / 13,220 assertions passed, including terrain-envelope and cliff direction regressions.
- Final placement: 2 tests / 71 assertions passed, covering upright foot rocks, horizontal face ledges, cap burial, projection, substantial exposure and distinct clustered assets over multiple wall heights/corners.
- Runtime dependency checks: 2 tests / 32,694 assertions passed after portable baking.
- Final Meadow catalog integration: 3 tests / 146 assertions passed after the matched-green bake.
- The broader catalog run exposed two obsolete assumptions, now corrected: effective materials can be overrides, and walk-over height checks concern active populations, not retired catalog assets. The final material assertion sweep passes 29,267 geometry/material assertions but remains red because GUT treats existing stale UID warnings in KayKit terrace and fantasy-village resources as unexpected errors. These unrelated resources were not rebaked.
- `git diff --check` passes.
