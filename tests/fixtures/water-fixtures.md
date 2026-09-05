# Historical water regression fixtures

`water_2697992464.var` and `water_991177.var` freeze full-depth river records from
commit `7648599b` before the September 2026 generation revision. They cover source
cells [-8,8] on both axes and preserve the exact reported screenshot sites.
`ReportedWaterPlan.gd` reads these records; terrain reconstruction, channel carving,
hydrostatic fill, contours, normals, mesh construction and swim sampling remain live.
The files contain Godot Variant dictionaries keyed by source cell, with parallel
point/bed/width arrays, priority, join state, and pool/pond primitive parameters.
Do not regenerate these from the new planner: that would erase the visual regressions.
New generation is exercised by `test_water_plan.gd`, `test_river_generation.gd`, and
`tests/harness/river_corpus.gd`.
