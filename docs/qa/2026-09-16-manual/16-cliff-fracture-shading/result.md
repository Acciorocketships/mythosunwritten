# Cliff fracture shading follow-up

The full-height, native attachment and wider lower-terrace geometry from [the preceding revision](../12-cliff-transition/result.md) remains in production. This follow-up makes carved fractures read more clearly while retaining rounded broad faces and the thin native-wall normal blend.

## What changed and what was rejected

Previously all incident triangle normals were averaged together. A 90-degree carved fold consequently shaded 45 degrees away from either rock face. The new mesh construction averages neighboring face normals according to their angle to the current face. Gentle curvature retains common smooth normals; strongly opposing faces no longer inflate the joint. The native attachment normal and material blend still runs afterward.

The first candidate blended directly toward individual triangle normals. Its unit tests passed, but P12 front and P20 oblique exposed conspicuous triangle patches. It is rejected and retained as `rejected-triangle-shading.gd.txt`, with renders in `candidate/`. The second candidate uses the neighboring-face average and is the production revision. No material, vertex position, turf UV, attachment weight or collision construction changed in this follow-up.

## Native comparison

Exact starting source is retained in `before.gd.txt` and `tests/fixtures/september17/cliff-shading/before.gd`. Both controls rebuild 31 existing rock anchors on the same frozen terrain, using the same 17 cameras. The output is native Godot Metal rendering, not an edited or generated illustration.

![Current cliff relief](candidate2/P20_oblique.png)

| View | Before | Current |
|---|---|---|
| Broad lit face | [Before](before/P20_oblique.png) | [Current](candidate2/P20_oblique.png) |
| Close front | [Before](before/P12_front.png) | [Current](candidate2/P12_front.png) |
| Reported P12 +8 degrees | [Before](before/P12_reported_8.png) | [Current](candidate2/P12_reported_8.png) |
| Corner / lower terraces | [Before](before/P17_reported_-8.png) | [Current](candidate2/P17_reported_-8.png) |
| Shaded wall | [Before](before/P05_vines.png) | [Current](candidate2/P05_vines.png) |

Judgment: the second candidate removes the strongest triangle-patch regression of the first attempt and retains clearer deep joints than the starting shading. This is a modest shading improvement, not a new cliff composition. Some small facets remain visible close up, broad shaded faces are still soft, the exposed native corner pattern remains conspicuous, and the close P12 fern overlaps the view. These limitations keep the overall cliff art review open; this is not gold-standard acceptance.

## Verification

- [Red test](red.log): sharp-fold test fails on both faces, measuring approximately 45 degrees of smoothing; gentle-curvature control passes.
- [Focused checks](green2.log): 13 tests / 51 assertions pass, covering shading, actual attachment normals, full-height coverage, varied lower projection, closed/continuous geometry and ledge variation.
- [Final shading and preservation check](final-shading.log): three tests / 11 assertions pass. The added preservation check compares actual production vertex arrays, turf UVs and attachment weights and checks all emitted normals are finite and normalized. Together these runs cover 14 distinct tests / 59 assertions.
- Native rendering completed without script errors. The replay preserves frozen terrain/grass/collision and does not replace fresh generation or player traversal testing. No startup or global performance acceptance is claimed.

Reproduce current: `tests/harness/september16_cliff_transition_context.tscn -- --output=res://docs/qa/2026-09-16-manual/16-cliff-fracture-shading/candidate2`.

Reproduce before: add `--generator=res://tests/fixtures/september17/cliff-shading/before.gd` and use a separate output directory.

Final `CliffRockCrags.gd` SHA-256: `9d591fefa76468826c775eb3040a0df630005a67d1c3ba7dc946e2397859a1b6`. The cliff shader remains `183bdd481a3c60e5b0da63331837aaf481becda9095acb76e26bd95b90605d0d`.
