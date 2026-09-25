# Geometry-following riser triangulation

Production retains the pass-55 rock shapes and now chooses each regular riser quad's diagonal to follow its local curvature. This removes avoidable hard facets without adding geometry or changing the sampled crown, foot or complete turf triangles. It does not resolve the tall column composition or broad plain faces, and no original issue is closed wholesale.

## Diagnosis and falsification

The preceding stronger body trial produced visible tooth-like folds in the P12 supplemental front camera. Exact screen rays identify ordinary sampled riser faces on saved formation 9, rather than explicit tread joins. `probe.log` records the screen coordinates, native formation, local hit, triangle vertices and normal. `columns.log` and `columns-fine.log` retain the sampled field around that location.

The first hypothesis was insufficient physical resolution. Doubling sampling in both directions made more teeth, not a clean curve: the local maximum shared-edge angle rose from 78.75 to 86.11 degrees. That alternative is rejected. The local field changes rapidly where a protruding body meets the backing face. The fixed diagonal cuts repeatedly across this curve, causing alternating facets. Choosing the less creased diagonal removes most visible teeth at the original density.

The original local maximum-angle test still fails after this correction (72.37 degrees). It includes real shoulder transitions as well as avoidable triangulation creases; it is not weakened or registered as a passing test. The broader blending experiment reduces the maximum to 61.47 degrees but also fails, and is not selected. Fine sampling plus diagonal choice also fails this maximum-angle bound. Strong-body experiments remain unpromoted.

The production regression instead distinguishes an avoidable mesh crease from an inherent surface bend: in actual regular riser quads, a diagonal producing a bend over 50 degrees must not have an alternative more than 10 degrees smoother. The same boundary vertices define both choices. This guard does not forbid genuine sharp ledges or geological boundaries.

## Red-first and preservation evidence

- `production-red.log`: unchanged pass 55 measures 41,022 photo riser quads and fails on three avoidable hard creases; the largest avoidable angle difference is 22.89 degrees.
- `production-candidate.log`: the isolated correction passes eight tests / sixteen assertions, including the new guard, cap/tip/channel/shell checks, lip bearing, long ledges and upper envelope.
- `production-regression.log`: integrated production passes **22 tests / 69 assertions** in 247.258 seconds. This includes grass support and ownership, corner closure at 16/32/64 m, orientation, detached workers, and complete wet/public exclusions.
- `shape.log`: one additional test / three assertions compares all 31 photo formations. No added or missing vertex positions, no changed turf triangles and no triangle-count difference. Interpolation inside changed rock quads differs, so this is not a claim of byte-identical collision triangles.
- Production retains 407 supported grass roots, zero escaped/buried roots, 57/57 cap probes and four connected upper ledges spanning 6.5–40.75 m. The paired grass test's older 176-root reference is not the immediate baseline; pass 55 already had 407.
- The upper envelope has zero excess over 304,189 samples. The existing lip-bearing check retains zero breaches over 32,334 samples.

The registered new guard is `tests/test_september18_cliff_riser_diagonals.gd`. The shape-preservation fixture is intentionally a before/after study. No sampling-density, material, water, streaming or mass-profile change is promoted.

## Native review and limits

Seventeen matched frozen game captures and five tall studio views review the isolated production correction. The dramatic P12 tooth comparison uses the rejected strong-body prototype as a diagnostic; it is not presented as the current production before image. On the existing production shapes, the correction is subtler. Broad featureless game faces and upright tall supports remain visible.

A separate matched corner side view checks the shared mapped geometry. The frozen replays retain old terrain, grass and collision. They establish visual behavior, not newly generated admission, fresh-world walking or global performance. Physical shell and worker tests exercise current production separately. The production vertex and complete-turf preservation check supports the limited scope, not an overall art acceptance.

See [matched comparisons](comparison.md) and `source-evidence.sha256`. The broader cliff work and original judging register remain open.

Production generator SHA-256: `b6e191cd92792d766f169109bc589a3a5d1f35c3893a1da0036eb576684331a8`.
