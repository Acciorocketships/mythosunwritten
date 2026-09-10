# Photo 4 — country road exits

Status: accepted for the photographed dead-end spur.

The town had only a south world-road connection but independently painted a
56.867 m north approach. Gates now end at the shared perimeter; actual world
roads supply exterior handoffs and reserve frontage before houses are placed.
The photographed north stripe disappears, while the south handoff remains
continuously painted. See [iteration notes](iteration-notes.md).

All 15 related tests pass (5,662 assertions, 48.17 s), followed by both final
targeted regressions (116 assertions, 17.538 s). These cover four orientations,
the recorded road masks, populated frontage, physical lane/house clearance,
and existing connected country roads. Both runs exit 0.

All six matched before/after views and pixel differences were inspected.
The stripe is absent and the surrounding ground remains continuous. Exact-view
mean absolute RGB difference is 11.553993/255; 17.523694% of pixels change by
more than 20 in any channel. Restored grass and minor animation/shadow changes
also appear in the difference. Camera JSON is identical; original full camera
precision is unavailable. Captures finish with all nine chunks ready. Their
startup times (338.399 s before, 291.458 s after) do not establish a cold-start
performance fix.
