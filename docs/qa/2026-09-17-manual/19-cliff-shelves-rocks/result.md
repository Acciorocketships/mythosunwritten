# Curved ledges and supported rock shoulders

The owner rejected the flat-fronted, rectangular masses and then clarified that merely rounding them retained an underlying arrangement of vertical and horizontal lines. This revision changes the paths of the ledges themselves. Finite shelves slope and bend along the wall, their supporting faces change width with height, and modest lateral drift breaks straight sides. Wider lower terraces retain bearing instead of curling deeply back underneath. Upper rock withdraws beneath the original turf crown.

This is a selected implementation step, not overall cliff-art acceptance. The native wall's repeated pattern remains obvious in the 64 m control. Some close views still show angular turf endpoints, narrow stone creases, and broad soft faces. Those remain open against the owner's landscape reference.

## Geometry and source data

Production is `scripts/terrain/field/CliffRockCrags.gd`; the exact selected fixture is `tests/fixtures/september17/cliff-shelves-rocks/selected.gd`. The shared convex-corner builder consumes the same source geometry. The original terrain, turf crown, lighting and materials are retained.

The earlier max-norm bevel created large flat fronts and near-vertical sides. Rounded asymmetric cross-sections replace it, retaining finite sharp ledge cuts. Whole fronts from the four CC0 Ultimate Nature rocks supplement the generic masses. Their numeric 49 by 33 samples are prepared and filtered on the main thread; workers only read detached arrays. A lower support envelope limits source-rock undercuts. The existing final 7.75 m soft projection limit remains.

`tools/mountain_art/build_nature_terrace_profiles.py --body` produces `terrain/cliff/nature_rock_profiles.json`, retaining source paths, hashes and license provenance. Repeating the bake into `/tmp/nature-bodies-rebaked.json` produced an identical file. The default older section-only bake remains unchanged.

Ledge elevation combines independently selected slopes and curves. The lowest curves are constrained above the closing floor; failing to do that produced open physical edges in the first curved candidate. The selected implementation closes those edges. Curvature follows world coordinates, including across chunk ownership. Turf uses the same actual cap triangles as collision and retains its native ground material.

## Rejected experiments

- `candidate`, `shaped`, and `blended`: increasing whole-rock strength exposed teeth at source-grid transitions; smoothing the detached source samples improved this.
- `filtered`: broader supported bases, but still boxy; also failed grass, upper coverage and variation controls.
- `organic`: rounded fronts, but the ledges still predominantly followed planar paths.
- `curved`: better ledge paths; low curves crossed below the floor and failed closure.
- `flowing`: sloping treads outward from back to front eliminated usable planar grass-patch support. Withdrawn. The selected slopes and curves run **along** the wall; depthwise treads remain level.
- `tapered`: stronger upper exposure introduced excessive recession below the upper body. Withdrawn.
- `settled`: passed the main support/variation checks; tall corner coverage still needed correction. The final height-dependent correction leaves the photographed short formations identical.

## Reported geometry measurements

Seed is **2697992464**. The support tests use the 31 saved straight production anchors and the saved photographed convex corners, rather than fabricated camera sites.

| Measurement | Earlier control | Selected short geometry |
|---|---:|---:|
| Largest recession beneath a photographed straight projection | 2.161 m | 0.676 m |
| Added crown projection in the top 0.5 m | 1.113 m | 0 m |
| Turf area on treads at least 1.5 m deep | 0.380 m² | 90.324 m² |
| Corner recession, 188 sampled columns | — | 0.340 m |
| Substantial photo shelves changing elevation | 8 / 39 | 17 / 27 |
| Substantial photo shelves with changing slope | 9 / 39 | 14 / 27 |

The support defect reproduces red in [red.log](red.log). The curvature composition reproduces red against the frozen pre-curve `organic.gd` in [curvature-red.log](curvature-red.log). The original count-only curvature test was insufficient because exceptional ledge tips already bent; the revised test measures the proportion of substantial connected shelves. Actual closure, crown clearance, native joins and support are independently tested.

The earlier carved-ledge test used the grass worker's *coplanar* patch borders as a proxy for complete ledges. Curving a ledge deliberately splits those support patches, so that test now measures shared-edge connectivity of the actual turf triangles. All six requirements and their thresholds remain: finite count, maximum length, variable lengths, varied elevations, area and gray attachment. The grass worker's stricter support partition is unchanged. Likewise, the mass-scale test still checks every original centre/radius/depth dimension while allowing the new signed lateral coordinates.

The final focused set has **45 distinct passing tests / 674 assertions across the scoped runs**: [20 main tests](settled-regressions.log), [25 collateral tests with two initial failures](settled-collateral.log), the corrected carved-ledge test in [selected-final-checks.log](selected-final-checks.log), and [17 final tall/corner/transition tests](selected-tall-coverage.log). The latter repairs the remaining physical upper-corner regression; none of its thresholds were changed. A standalone identity check proves all 31 production photo formations equal both the selected fixture and the rendered short-wall candidate: [selected-identity-final.log](selected-identity-final.log). The headless runs contain the existing macOS certificate-loader diagnostic before GUT; the final runs exit successfully.

The actual grass-worker fixture retains nine rooted patches on more than five supports, with zero escaped or buried samples and identical chunk ownership. Curved shelves offer less planar grass-bearing area than the earlier flat shelves; denser grass following curved surfaces is still open. The mesh remains closed at 16, 32 and 64 m, and the wet/public footprint and detached-worker controls pass.

## Visual review and limits

The native replay captured 17 views in [settled/](settled/), including the four original photo poses and their −8/+8 degree alternatives through `ReviewCam`. Supplemental front, side and oblique poses deliberately expose seams and shelf profiles. This reconstructs the 31 straight and four convex formations inside the saved world; it is not a fresh world-generation, streaming or hydraulic run.

Inspected short views: `P12_front`, `P12_side`, `P20_oblique`, `P05_reported_0`, `P12_reported_0`, `P17_front`, and `P20_reported_8`. The side view makes the bowed shelf especially clear; the front view is calmer and loses the strongest rectangular silhouettes. The oblique view retains wider lower projections and recessed intervals. Close photo views still reveal some angular endpoints and smooth broad faces, so these images do not establish that all art concerns are resolved.

The original `settled-tall` control exposed insufficient upper-corner coverage. The final tall control is in [selected-tall/](selected-tall/). Its native wall repetition remains an explicit open art issue.

The final tall front, oblique and ledge views were inspected. They retain larger coherent bodies and more upper-corner coverage without opening seams, but are not accepted as the final artistic target: the repeated backing still dominates some tall stretches.

No new performance, fresh-world, full-suite or owner acceptance is claimed. The separate pass-18 fresh capture completed in 510.697 seconds under concurrent work; it predates this selection and is not validation of the new geometry.
