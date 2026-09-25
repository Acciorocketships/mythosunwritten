# Issue 38 — plain public ramp floor

The production mesh commit path assigned the generic flat surface material to transitions, while the isolated review assembler used a plank material. Both now use the same cached transition material. Ramp and stair tops supply face-metric UVs, so boards span the full hallway width and retain their spacing along the slope in all four orientations. Mesh positions, normals, indices and collision remain unchanged.

An initial candidate wired in the old review shader, but its world-axis grid looked like square tiles. It was rejected after native and live inspection; those captures remain in `rejected-grid/`. The accepted shader uses long alternating boards with filtered seams, in the existing native timber palette.

## Verification

- Original production fails the two focused material regressions with eight failed assertions. Final native checks pass 19 tests / 187 assertions, including production commit, shared material, metric UVs, frozen geometry equality and camera adaptation.
- Eight rendered controls cover ramps and stairs in all four directions. Inactive camera adaptation changes at most one 8-bit color level in two channels; mean channel error remains below 0.001. Restoration is exact. This measured GPU rounding tolerance replaces an initially over-strict byte equality assertion; it does not change production rendering.
- All native placements, walking claims and generated collision boxes match the preceding accepted barrel repair. Of 52 generated mesh payloads, 45 are identical and seven change only UVs. Their physical geometry is identical. The preceding 164-position / 235-crossing physical survey therefore retains the same inputs; no new traversal is claimed.
- Three native pairs and three fresh game pairs use P36’s original rounded-overlay camera plus ±8-degree views. All were inspected with their differences. Boards now continue across the reported floor, with surrounding native walls and landings preserved. Live camera poses are identical. See `live-pairs.jpg`, `live-differences.jpg` and `native-reproduction/pairs.jpg`.
- The mandatory matrix seals 48/48 towns, retaining 11,868 clear centers / 17,035 crossings and the same 24 off-center pillar contacts. The fingerprinted composition gate passes all 95 assertions. No full-suite or performance acceptance is claimed.

P36: player `(965,20.8,-436.2)`, crosshair `(964.5,21.3,-434)`, seed `2697992464`, reconstructed through `ReviewCam.solve_cam` and normal obstruction handling. Fresh live startup took 365.223 seconds and remains expensive.
