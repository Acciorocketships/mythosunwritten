# Cliff texture and variability revision

The previous rounded candidate was rejected by the owner for smooth faces, regular semicircular shelves and too little rock projection. This revision adds independent weathered rock masses and finite ledges to the existing connected shell. It improves the inspected composition; it is not owner approval or a claim to match the gold-standard reference.

## What changed

- Independent rock masses have mixed widths, elevations, tilt and depth, with larger supporting shoulders toward the ground. Smaller crags break up the larger faces. Rounded bevels retain broad stone faces without returning to inflated spherical pods.
- Six potential ledge streams produce finite, independently placed cuts with different lengths, slopes, heights and thicknesses. They are candidate distributions, not six continuous rows. Elevation transitions happen in the gaps between ledges, removing the thin fins found during review.
- Shallow fractures, clefts and physical bumps add intermediate detail. A dedicated world-space mineral/bump shader adds restrained surface variation without copying the native wall's repeated courses.
- Gray attachment surfaces retain the shared stone palette. Upward ledges retain the existing native turf treatment. Existing crevice foliage and grass-colour ownership remain.

## Matched visual evidence

The final comparison is **paired-before / paired-after**. Both use the same frozen world, lighting and cameras, rebuilding 31 local crag owners at their saved production anchors. Before uses the exact saved pre-turn geometry and material implementation. After uses the final current source. Current plant contacts are regenerated against each phase's rock geometry.

Twelve cameras reuse saved ReviewCam reconstructions at P05/P12/P17/P20, each at 0 and ±8 degrees. Five additional explicitly supplemental context cameras expose wider composition. The supplemental cameras are not substitutes for the photographed poses.

| View | Before | After | Judgment |
| --- | --- | --- | --- |
| P20 wide oblique | [Before](paired-before/P20_oblique.png) | [After](paired-after/P20_oblique.png) | Broad blank rounded skin becomes mixed block faces, smaller left-hand crags, offset ledges and clearer depth changes. |
| P12 front context | [Before](paired-before/P12_front.png) | [After](paired-after/P12_front.png) | More upper and lower projections and weathering. Broad individual faces remain; native wall repetition is still apparent. |
| P17 corner context | [Before](paired-before/P17_front.png) | [After](paired-after/P17_front.png) | Lower masses project beyond the wall and join the supporting body. Native corner remains visible. |
| P05 vine context | [Before](paired-before/P05_vines.png) | [After](paired-after/P05_vines.png) | Face depth and local ledge variation improve; shadow limits fine-material judgment. |
| P12 reported pose | [Before](paired-before/P12_reported_0.png) | [After](paired-after/P12_reported_0.png) | Rock is more detailed; a newly located fern intrudes into the close camera and remains a limitation. |
| P12 reported −8° | [Before](paired-before/P12_reported_-8.png) | [After](paired-after/P12_reported_-8.png) | Nearby angle confirms relief; fern remains at upper edge. |
| P17 reported +8° | [Before](paired-before/P17_reported_8.png) | [After](paired-after/P17_reported_8.png) | Irregular roots and mid-height projections visible around the corner. |
| P20 reported −8° | [Before](paired-before/P20_reported_-8.png) | [After](paired-after/P20_reported_-8.png) | Downward close view confirms face detail and finite turf cuts; limited whole-wall composition evidence. |

### Main comparison

Before:

![Rejected smooth cliff](/Users/ryko/story/docs/qa/2026-09-16-manual/11-fractured-outcrops/paired-before/P20_oblique.png)

After:

![Revised rock faces and ledges](/Users/ryko/story/docs/qa/2026-09-16-manual/11-fractured-outcrops/paired-after/P20_oblique.png)

## Iteration and verification

The intermediate studies are retained for audit, not final presentation. Rejected versions included rough plaster-like bump noise, thin ledge-end fins, mushroom-shaped unsupported-looking shoulders, obvious triangle-grid normals, and too few distinct projections despite passing ledge-count checks. Files named final-study/final-context predate the final width mixture; use paired-after for the current result.

The new actual-geometry projection test failed an intermediate candidate (4 qualifying projections versus 2 on the rejected baseline). Narrower crags among the broad masses raised the final sampled count to 7. These are fixed cross-section probe results, not a total world boulder count or a beauty metric. The test was added during iteration, not before the first edits of this turn.

[Final focused run](verified-tests.log): **22/22 tests, 1,167 assertions, 86.531 seconds**, eight test files. The headless log includes a macOS system-certificate lookup error before GUT starts; all tests complete successfully. Both native paired capture logs have no script/parse/render errors. No existing thresholds were relaxed. Checks include connected shells, owner continuity, restrained toe depth, finite ledges, actual grass roots, material/UV integration, wet/public exclusions and the new independent protrusion control. Some retained integration tests also cover historical assets.

The 72 m ledge control contains 19 substantial finite components spanning eight metre-height bins and lengths approximately 1.04–8.35 m. The actual grass worker produces 31 rooted patches with zero escaped or buried samples. These scoped controls do not establish a universal visual result.

## Limits still visible or unverified

The native upper wall and cap retain their repeated shapes. Some broad faces and narrow turf edges remain, and the art has not reached the richness of the supplied reference. P12's close camera intersects fern foliage. These observations are not hidden by the passing tests.

The replay is **art-only frozen context**: original terrain, grass and collision remain; rock placements reuse saved anchors and do not repeat current hydraulic admission or real-terrain seating. No fresh full-world generation, final collision traversal, global performance, other biome acceptance or completion of the original issue catalog is claimed. The previous full-world capture stall is documented in [the preceding result](../10-rounded-ledges/result.md).

## Reproduction

Run `tests/harness/september16_crag_art_context.tscn` natively with `-- --output=res://docs/qa/2026-09-16-manual/11-fractured-outcrops/paired-after`. Add `--before` and choose paired-before for the saved rejected generator. The harness depends on the saved production-01 world under 10-rounded-ledges and its pose records.

Final source SHA-256 values:

- `scripts/terrain/field/CliffRockCrags.gd`: `69d796a28943e83b2c95c95df01e0a6257fc465ca78db82f60330f97677abe34`
- `terrain/materials/cliff_crag.gdshader`: `892eec2cc4084958e22192eb4db8c66fb32295639c8b7e7a99295732b0366b76`
- `tests/harness/september16_crag_art_context.gd`: `31b5833566e938486a48e2016e56abd5c52eff0f3b2445d07cc791f1f3970363`
- `tests/test_september16_crag_variability.gd`: `8c49cb865dc63699f375ff5e9ab9341d515b0eed86d18690df110ce74d958d81`
- `tests/fixtures/september16/crags_before_variability.gd`: `7069f7d6be6a44e83efea4ed8720ca573149b9b66384192e8a8e7a9d35428a12`
