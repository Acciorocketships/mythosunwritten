# Narrow-groove integration trial — withdrawn

The lighter pass-39 sparse-groove study was provisionally integrated and checked against production's broader geometry and grass checks. It is **not retained in production**. All three changed production files were restored from the exact pre-trial backups; the experiments remain available for comparison. Pass 34 remains the existing production implementation, not accepted final cliff art.

## Visual judgment

Seventeen native frozen-context views are retained in `context/`. P20 oblique and P12 side were inspected. Sparse narrow grooves remove the all-over fabric-like small detail, but broad faces remain plain and vertically organized. This is the preferred *detail direction* among the requested experiments, not a completed cliff design. The separate [four larger-form trials](../40-cliff-rooted-fans/result.md) are also rejected.

## Integration checks

- Broader production trial: **36/38 tests, 189/192 assertions**. The real grass worker produces five supported roots instead of the previous eight and fails the distinct-support coverage requirement. No roots escape or enter stone. A 64 m convex corner has two collapsed triangles and two invalid shared edges.
- Nonlinear corner mapping precision trial: removing a second coordinate quantization preserves distinct vertices; the closure test passes all nine assertions at 16, 32 and 64 m. This fix remains in a fixture because the overall integration is withdrawn.
- Fracture overlap: one test / two assertions passes; duplicate fracture owners add zero extra erosion.
- Native shared stone-colour shader: one test / twelve assertions passes, retaining restrained warm/cool variation and shared native-wall colour.
- A follow-up fading fractures near ledge boundaries still produces five roots and fails coverage (two of three assertions pass). This does **not** establish the cause of the grass regression and is not retained.

Logs are `tests.log`, `corner-precision.log`, `overlap.log`, `colour-gpu.log`, and `grass-cap.log`. Trial sources and exact production backups are in `tests/fixtures/september17/cliff-selected-grooves/`. `initial-selected.gd` records the first integrated source; `cap-fade-trial.gd` records the unsuccessful follow-up. `restored-grass.log` records the restoration check: one test / three assertions passes, restoring eight fully supported roots with zero escaped or buried samples. All three production files are byte-identical to their pre-trial backups.

No fresh-world admission, regenerated visual grass, full-suite, streaming, traversal or global performance acceptance is claimed. Larger composition and the original judging register remain open. Do not weaken the grass requirement to accept this trial.

## Subsequent diagnosis

[Pass 42](../42-cliff-groove-grass/result.md) shows the grass count is sensitive to real rim movement relative to sampling: sixteen paired placement seeds retain 170/176 roots, with every footprint supported. The broader paired coverage gate passes. This does not reverse the withdrawal: the owner subsequently rejected the tall columns and isolated scratches themselves.
