# Railing face orientation — accepted

Photo 12’s open-looking post and lower beam came from inward render fronts and
inward lighting normals in the generated transition boxes. Correcting their
winding and normals closes the visible faces. The original corner-based UV basis
preserves their texture coordinates. Native attachment positions remain fixed.

Changing culling would retain the bad normals; replacing the guard would disturb
its measured sockets. The face correction fixes the source error directly.
The first candidate exposed a redundant reversal in the suspended lawn border.
That candidate was rejected; removing that old compensation restores the border.

Photo 1’s broad circled fascia is native floor stock and its lawn border, rather
than generated railing. Issue 6 closed its underside. Its authored board seams
remain; this pass corrects the surrounding stair guards and preserves the border.

## Verification

- The new regression fails all 144 orientation checks before and passes after,
  covering vertical, horizontal and sloping members in four orientations.
- Eleven transition meshes across both towns retain byte-identical vertices,
  UVs, triangle counts and collision faces. Only normals and render indices change.
- Seventeen distinct focused tests pass 4,490 assertions. An older hanging-course
  test now checks actual emitted native masonry: all 14 historical failure points
  lay outside the shorter masonry accepted in issue 8. Its nonempty masonry
  witness and collision comparison remain explicit.
- Twelve matched game pairs and two native pairs were inspected, including the
  full photo views and heatmaps. Both camera metadata files are identical across
  before/final. The final lawn border retains its original outward appearance.
- Photo 12’s reconstructed view has full-image mean difference 0.922/255 and
  region mean 3.336/255; 8.872% of region pixels differ by over 20. Photo 1 gives
  1.237/255, 1.265/255 and 0.473%, respectively. Changed pixels follow the corrected
  guards. Incidental character and orb motion is not evidence of the repair.

The photographs contain rounded player/crosshair coordinates, so these are
matched reconstructions, not provably exact recovered original cameras.
This is focused acceptance, not a full-suite result.

Evidence: `before`, `final`, `final-diff`, `native-before`, `native-after`,
`native-diff`, `geometry-comparison.json`, `legacy-probe.json`, `validation.json`.
The rejected first candidate is retained in `candidate1` and
`native-diff-candidate1`. See `investigation.md` for its failure and correction.
