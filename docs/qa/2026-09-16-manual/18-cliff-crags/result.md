# Cliff crags and thin attachment follow-up

The current cliff geometry carries irregular relief close to the native crown, retains selected broad lower feet and finite terraces, and now gives thick stone stronger staggered fractures while protecting its thin native-wall attachment. This continues the owner’s seam/detail, lower projection and full-height requests. Overall art approval remains open.

## Changes

The former five fracture cuts were spread over any wall height. Their fixed horizontal clusters also left some whole columns without cuts. The revised field uses a physical vertical interval, independently staggered horizontal positions, varied spans and slopes. Short clefts have sloping sides and small bevels instead of soft Gaussian troughs; vertical clefts are a little wider and deeper. This is actual shared render/collision geometry, not a repeated wall texture.

Independent crags now fade by actual projected thickness above the sampled native wall. The native depth and normal blend continues to own thin joins. A stronger-cut candidate exposed backing stone near the crown and failed the existing height-coverage test; the thickness blend fixes that regression without changing its threshold. Thick stone retains the full fracture depth. Turf selection now uses the same welded triangle vertices as the emitted geometry so rounding cannot move a selected tip onto an excessively steep face.

The wider selected feet, finite low terraces and full-height crown envelope from [revision 12](../12-cliff-transition/result.md) remain. This follow-up does not simply enlarge every outcrop. Final measurements retain lower projections from 2.69 to 7.50 m in the continuous control, 31 finite turf components at ten metre-height bins, and near-crown relief at 19/23 sampled positions on each of the 16, 32 and 64 m controls.

## Rejected iterations and visual judgment

- `candidate/`: shorter sharper fractures, but some broad faces remain soft.
- `candidate2/`: tighter mass bevels and less waviness made large flat panels and conspicuous edge facets. Rejected; original rounded shoulders restored.
- `candidate3/`: stronger resolved cuts, but fixed horizontal clusters left smooth columns.
- `candidate4/` and `candidate5/`: intermediate stagger distributions retained excessive empty vertical intervals. The latter also exposed upper backing and one turf classification edge case (`rejected-05-tests.log`).
- `candidate6/`: the final span distribution before the thickness-sensitive blend. Superseded by `final/`.

The final P20 oblique view has clearer short rock cuts across formerly uninterrupted faces. P12 front retains rounded faces with stronger ledge/joint separation; the thin crown region stays backed. P17 −8 degrees retains an irregular lower toe and blends back toward the native corner. The native corner’s repeated pattern is still recognizable. P12’s close fern overlap and some broad soft faces remain visible. These images do not meet a claim of universal seam removal or gold-standard art completion.

Starting source is saved in `before.gd.txt` and `tests/fixtures/september17/cliff-crags/before.gd`. The exact preceding native renders are the `candidate2` images from [revision 16](../16-cliff-fracture-shading/result.md); the shader has not changed since those renders. Final output reuses the same frozen terrain, 31 rock anchors and 17 saved cameras, including reported and ±8-degree views.

| View | Exact starting appearance | Current |
|---|---|---|
| P20 oblique | [Before](../16-cliff-fracture-shading/candidate2/P20_oblique.png) | [Current](final/P20_oblique.png) |
| P12 front | [Before](../16-cliff-fracture-shading/candidate2/P12_front.png) | [Current](final/P12_front.png) |
| P12 +8 degrees | [Before](../16-cliff-fracture-shading/candidate2/P12_reported_8.png) | [Current](final/P12_reported_8.png) |
| P17 −8 degrees | [Before](../16-cliff-fracture-shading/candidate2/P17_reported_-8.png) | [Current](final/P17_reported_-8.png) |
| P12 side | [Before](../16-cliff-fracture-shading/candidate2/P12_side.png) | [Current](final/P12_side.png) |

![Current game cliff](final/P20_oblique.png)

The additional [64 m front](tall-64/front.png) and [oblique study](tall-64/oblique.png) show relief and varied cuts throughout a freshly constructed native wall. Five study cameras were captured. Fine dark hatching appears on some steep, strongly lit faces; this prevents treating the tall study as finished art. The earlier 64 m study also shows this artifact, but that older rendering predates the current normal treatment and is not an exact baseline for attributing its severity. Native upper recesses and the constant study crown remain apparent. This study tests a deliberately straight wall, not mountain silhouette composition.

## Verification

[Verified focused run](verified-tests.log): **26 tests / 1,315 assertions pass**, nine test files, 87.223 seconds. This covers actual attachment normals, full-height coverage, varied lower projection, closed geometry, canonical owner seams, crevice plant contact, actual grass roots and finite ledge classification. No existing thresholds were relaxed.

Three new regressions were reproduced against saved sources:

- [Height-scale red](red.log): largest empty interval inside a fracture cluster was 35.94 m; final is 5.85 m.
- [Lateral-gap red](stagger-red.log): gaps between fixed clusters left a full 64 m column without cuts; final largest sampled interval is 9.35 m. Lateral gaps remain irregular and finite.
- [Thin-attachment red](attachment-red.log): independent cuts removed 0.577 m at sampled thin roots. Final maximum is 0.025 m across 17 eligible samples; the thick-face control retains 0.58 m cuts.

Final actual mesh checks report 19/23 near-crown samples on all three wall heights, 2.44-degree mean normal mismatch at 804 thin attachment samples, and a maximum sampled lower projection of 7.69 m. The control retains 31 finite turf components approximately 1–8.5 m long with 74.14 square metres of turf. Intermediate tests and rejected images are retained; `verified-tests.log` is the final authoritative run.

The first draft of the height test incorrectly included deliberate lateral gaps. That draft and a GUT command with an unsupported custom argument are excluded; `red.log` is the corrected cluster test against the saved starting generator. The known macOS certificate lookup error precedes GUT but does not prevent the successful run. Final native render processes exit cleanly without script errors.

## Scope and reproduction

The context replay rebuilds visible rocks and plant contacts while retaining frozen terrain, grass and collision. It is visual evidence, not fresh full-world admission or player traversal. The focused tests separately exercise current geometry and ownership; no startup or global performance acceptance is claimed. Overall cliff art and the original water, town and streaming register remain open.

Current context: `tests/harness/september16_cliff_transition_context.tscn -- --output=res://docs/qa/2026-09-16-manual/18-cliff-crags/final`.

Exact before context: add `--generator=res://tests/fixtures/september17/cliff-crags/before.gd` and use a separate output directory.

Tall control: `tests/harness/september16_cliff_transition_study.tscn -- --height=64 --output=res://docs/qa/2026-09-16-manual/18-cliff-crags/tall-64`.

Final SHA-256: `CliffRockCrags.gd` = `2e663853a481259b680330ea164f89fcc3b9ed7881708c49d0731d1f62a71027`; unchanged cliff shader = `183bdd481a3c60e5b0da63331837aaf481becda9095acb76e26bd95b90605d0d`.
