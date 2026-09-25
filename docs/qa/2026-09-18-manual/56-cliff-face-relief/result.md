# Cliff exterior-relief investigation

No production change. Pass 55 remains byte-identical. This investigation rejects further small-step surface modifications and identifies an explicit turf/topology dependency in a shape-preserving support prototype. [Native comparisons](comparison.md) retain the evidence.

## Evidence and decisions

1. `quiet.gd` applies shallow erosion according to the existing broad stone partition after the outer-profile constraint. Tread tops, roots and crown are protected. Seventeen native frozen-world views complete. P20 develops a jagged diagonal crease, so this trial is rejected.
2. `shaped.gd` omits the extra narrow-joint part and retains only broad volume curvature in that added erosion. Seventeen native views complete; the unwanted crease remains. The original hypothesis that only the extra narrow-joint component caused it is disproved.
3. `carried.gd` replaces clipped body depth with descent-scaled body depth, then carries lost ledge width down toward the root. Seventeen native frozen-world views and five tall views complete, with five matching production tall controls. The longest connected upper ledge reaches 42.5 m (seven qualifying spans, shortest 2 m). The upper envelope has zero excess across 304,175 samples. But six of 57 actual cap probes lose turf: **5/6 tests, 11/12 assertions**. The tall wall still has strong vertical fluting and too little varied rocky composition. It is not selected.
4. `treads.gd` preserves each cap's previous cross-section including lower displacement, rather than just its overall width. It produces the same six failures: **5/6 tests, 11/12 assertions**. This falsifies the idea that lost width alone caused the material regression.
5. `channel-diagnostic.log` locates all six failures on adjoining shoulder triangles with upward normal components 0.855–0.865. They are sloping continuation surfaces outside the explicit tread tag, not missing physical surfaces.
6. `connected.gd` admits connected upward shoulder faces into the turf component. **6/6 tests, 12/12 assertions** pass, including 57/57 tread coverage, closed photo shells and long ledges. However, the 17-view native replay shows ragged grid-shaped turf patches. Passing geometry checks is not sufficient: this trial is rejected visually.
7. `contour.gd` splits the existing triangles at an interpolated slope contour, preserving explicit treads. Seventeen native views show a softer turf boundary. But the front-only subdivision is incompatible with the unchanged closing skins and introduces tiny collapsed triangles: 727 bad edges and 60 degenerate triangles across the photo corpus. **5/6 tests, 10/12 assertions** pass. This trial is rejected technically and is not a material-only production edit.

The first `carried-native.log` contains a prototype type-inference parse error and has no valid captures. `carried-fixed-native.log` belongs to the corrected source and complete captures.

## Discarded plane-fit diagnostic

The original proposed 7.5 cm plane-residual bound was not a reliable red test. Its depth filter selected different point sets after deformation, and the first quiet run could skip the pinned window entirely. `before-probe.log`, `red.log` and `quiet-probe.log` are excluded from acceptance evidence. Corrected `*-fixed-probe.log` files require the pinned window and include every exterior vertex in the fixed window. They report 0.14137 m RMS for production, 0.14788 m for quiet and 0.15090 m for shaped, each with 197 points. The baseline already passes the proposed bound, so it does not establish a flatness defect or prove an improvement. The result is merely diagnostic; it is not registered as a regression test.

## Scope and next constraint

All native world comparisons are frozen-context art replays; they retain old terrain, grass and collision and cannot validate fresh placement, seating or gameplay. No new production, grass, water, biome, streaming or performance acceptance is claimed. The production hashes remain:

- `CliffRockCrags.gd`: `f82eb7a70cc9f64f7f755548f33a1d217ae4d2365a52342cb8a9d6c222a67fbe`
- `CliffCornerCrags.gd`: `bd2f4d8c71a5c831721243dd8e2fc3bc30d42a5f0865f970970e3a2f337af6d6`

Further work must address the vertical organization of the supporting volumes rather than add another surface-crease layer. If the shape-preserving support approach is revisited, material continuation must follow the changed physical shoulder, and any contour subdivision must also update every closing boundary. Do not repeat the rejected all-triangle turf expansion as an accepted fix. Overall cliff art and the original judging register remain open.
