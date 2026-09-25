# Reach routing on unchanged terrain — promising separation, downstream gate still red

This controlled experiment removes the reported high hillside water without changing the existing terrain. It remains unselected: the intended downstream route has three local surface rises, up to 0.270 m, and broader routing/discovery/current issues remain unresolved. Production water is unchanged; W01 and the original judging register stay open.

## What was isolated

The pass-112 reach adapter supplies the new water network. HeightfieldPlan still uses the ordinary original WaterPlan for geological carving. The renderer reuses the exact saved baseline terrain/cliff meshes and collision, removes only old water meshes, then generates fresh WaterField/WaterSurfaceBuilder output against that original terrain. No shader mask hides water. This is an experimental separation of geological shape from present water supply, not acceptance of a permanent duplicate-planner architecture.

Both P10 and P21 generation runs completed in one native process, exit 0, without route rejection. The study/plan reference cycle is explicitly released before exit; the pass-112 resource-leak warning does not recur. The known snapshot global-shader-list warning remains. There is no controlled performance comparison.

## Geometry and physical evidence

`geometry_identity.gd` hashes each non-water mesh's surface arrays, every instance buffer/transform and native ground collision shape/mask. Final paired identities match exactly:

| Site | Geometry records | Native collision shapes | Identity |
|---|---:|---:|---|
| P10 | 787 | 38 | Identical |
| P21 | 720 | 36 | Identical |

These scenes overlap; counts are not unique world totals. An early P21 identity run logged empty-buffer hashing errors and is superseded by `geometry-P10-P21.json` and the clean final identity log. Empty instance buffers now have explicit serialized representation.

The 441-point 240 m square survey at each site confirms zero ground-height changes. All 29 positive water-triangle centroid controls hit. Saved water coverage changes from 238 to 99 sampled positions at P10 and 226 to 203 at P21. P21 has 29 wet-to-dry and six dry-to-wet samples. Retained water changes by −7.650 to +0.700 m at P10 and −10.040 to +4.250 m at P21. These are static actual-mesh measurements, not wave/current or swimming acceptance.

## Native visual judgment

Inspected source, overview and 90° diagnostic views at both sites show the high hillside sheet removed while the original terrain remains. This resolves pass 112's confounding landform changes. P10's former high river corridor is now visibly dry; its source provenance and downstream branching still need broader judgment. P21 exposes original bare cliff tiles that were previously submerged, so a final integration would need ordinary dressing to consume the new water state. The frozen-scene experiment deliberately does not regenerate dressing and is not cliff-art acceptance.

The blue diagnostic material exposes coverage only. It does not demonstrate finished water optics, biome atmosphere, grass, current travel, waterfalls or shoreline quality. Original-material isolated lighting is not accepted as a replacement for a fresh game review.

- [P10 original](../112-hillside-native-reaches/before-diagnostic/P10/view_0.png) / [unchanged-terrain experiment](diagnostic/P10/view_0.png)
- [P10 overview](diagnostic/P10/overview.png)
- [P21 original](../112-hillside-native-reaches/before-diagnostic/P21/view_0.png) / [unchanged-terrain experiment](diagnostic/P21/view_0.png)
- [P21 overview](diagnostic/P21/overview.png)

## Actual supply-path check and failing gate

The source `(-2,-1)` has 64 planned stations ending in an existing receiver basin. Samples every at most 3 m produce 268 positions; 247 lie inside the saved native terrain and 21 lie outside its extent. Every inside position hits water in both baseline and experiment. The two surfaces buried more than 10 cm below ground also occur in both; neither is cleared by this experiment. All thirteen samples across the reported 15.58 m confluence hit water, but this alone does not establish downstream consistency.

The baseline static mesh has two small increases along this intended path, largest 0.0463 m. The experiment has three above 1 mm, largest **0.2697 m**. `supply-audit.json` pins exact endpoints, ground and water heights for every increase. The explicit downhill gate in `supply_audit.py --require-downhill` exits 1. This is a real surface measurement, not a parse failure. It does not prove the animated current flows uphill; it proves the composed intended path and realized static surface are not yet consistently descending.

Next work should inspect those pinned points in the WaterField profiles and the common receiving-channel solve. Do not simply flatten the rendered mesh, remove supply, move the camera or relax the gate. Preserve existing terrain and fix the shared source/receiver surface geometry, then recheck native joins, currents and broader routes. The 720-station budget, increased discovery work, partial-bar handling, large other confluences and broad architecture remain experimental.

## Reproduction

- `native.gd -- --reaches --spots=P10,P21 --output=res://docs/qa/2026-09-19-manual/113-hillside-stable-terrain/after`
- `geometry_identity.gd -- --spots=P10,P21`
- `physical_samples.gd -- --spots=P10 --survey` (repeat P21)
- `physical_samples.gd -- --spots=P10 --junction`
- `physical_samples.gd -- --spots=P10 --supply`
- `python3 tests/fixtures/september19/hillside-stable-terrain/audit.py`
- `python3 tests/fixtures/september19/hillside-stable-terrain/supply_audit.py --require-downhill` (expected red)

Use explicit `/tmp` Godot logs. Native generation/replay uses Metal; physical/identity checks run headlessly. Final geometry/survey audits pass. The downhill gate remains red, and no production promotion or original issue closure is claimed.
