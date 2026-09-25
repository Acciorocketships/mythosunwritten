# Reuse the already evaluated water level

Production WaterFieldContext.level_at previously asked WaterField.wet to compute
the field level and terrain comparison, then evaluated the same field level a
second time for wet points. The context now evaluates the level once and retains
the exact authoritative predicate, including EPS and canonical dry NaN. Coverage
assertions, signed depth, field fill, interpolation and terrain remain unchanged.

A mixed owner and four fine bank-crossing grids retain all 18,820 results
exactly (5,815 wet, 13,005 dry). All sixteen timed output arrays match
byte-for-byte, including dry NaNs. Eight interleaved trials per implementation
report median 344.356 ms before and 280.609 ms after, a 18.5% reduction
for this query batch. The original loop omits the context coverage assertion;
the candidate includes it, so the control does not overstate the candidate gain.
The benchmark ran without another task-owned Godot job. Startup and frame throughput were
not measured, and this does not close slow-world-generation reports.

The existing WaterFieldContext test passes one test / 1,406 assertions, including
wet/dry agreement, shore distances and actual reed/lily placements. No visual
geometry change is intended; the exact result arrays establish unchanged inputs.
The usual headless macOS certificate diagnostic remains.
