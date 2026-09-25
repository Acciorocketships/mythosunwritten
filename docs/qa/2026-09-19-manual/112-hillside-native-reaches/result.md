# Native reach routing: useful supply correction, unaccepted terrain changes

Production water is unchanged. The detached reach network removes the high hillside water at both reported sites, but its combined routing/carving changes are not ready for production. At P10 a broad former river corridor becomes dry terrain, with changes up to 40 m in the surrounding 240 m survey. P21 changes less, yet its surrounding water levels and shoreline still change. A separate experiment now isolates water routing on the original terrain before choosing an implementation. W01 and the original judging register remain open.

## Completed discovery and adapter checks

The adapter preserves each actual source pool, follows the composed station path and terminates at the selected existing receiving pond. Spatial discovery uses the possible composed arc rather than the invalid original-prefix bounds. Three focused tests / fourteen assertions pass (the earlier synthetic cache setup failure is excluded as red evidence).

The original 360-station / 4,320 m allowance fails two of 146 discovered source routes. Neither reaches an admissible terminal pond before cutoff. The explicitly separate 720-station / 8,640 m experiment reaches their real basins in 433 / 423 stations. Its full source envelope is 9,038 m, with a 13-super-cell halo. Expanded discovery resolves 429 routes around the four review super-cells with zero rejections. Six exceed the original allowance. This is bounded empirical evidence, not proof for all seeds.

That increased discovery work is a material cost concern. Concurrent native runs do not establish performance improvement. The adapter also omits 173 partially supplied bar records across the 429 routes; that is not a count of unique geographical bars and is not an accepted land-bar policy.

## Matched native review

Both original and experimental native runs finished with exit 0. Each uses fresh ordinary terrain/water generation across nine chunks at P10 and P21, with identical saved ReviewCam source poses, ±8° nearby views, a 90° view and overview. Candidate shutdown reports eight retained resources, consistent with the experimental study/plan cycle; it is not a clean resource-lifetime result.

Original-material captures are unsuitable for optical appearance judgment because water blends into green terrain under this isolated scene's lighting. The opaque blue replays expose actual water geometry; they do not verify biome atmosphere, transparency, waves, grass or full-game appearance.

Inspected P10 source and overview pairs show the raised hillside reach disappearing along with a substantial adjacent river corridor. The 90° pair and candidate ±8° views confirm that this is a spatial change, not camera occlusion. P21 source/overview/90° pairs show the high sheet removed, exposing the existing terrace; lower water remains. Large plain cliff faces, exposed panels and missing surrounding game dressing are not accepted by these water studies.

- [P10 before](before-diagnostic/P10/view_0.png) / [candidate](after-diagnostic/P10/view_0.png)
- [P10 overview before](before-diagnostic/P10/overview.png) / [candidate](after-diagnostic/P10/overview.png)
- [P21 before](before-diagnostic/P21/view_0.png) / [candidate](after-diagnostic/P21/view_0.png)
- [P21 overview before](before-diagnostic/P21/overview.png) / [candidate](after-diagnostic/P21/overview.png)

## Actual saved-geometry survey

441 fixed XZ rays per site cover a 240 × 240 m square at 12 m spacing. Ground uses original native collision; temporary double-sided triangle collision measures the saved visual water surface. Every water mesh has an independent triangle-centroid control, all 32 controls hit. These are static mesh measurements, not swimming/current tests.

| Site | Changed ground samples | Ground change range | Water hits before → after | Wet → dry / dry → wet |
|---|---:|---:|---:|---:|
| P10 | 204 / 441 | −7.640 to +40.000 m | 238 → 99 | 139 / 0 |
| P21 | 21 / 441 | −6.786 to +0.881 m | 226 → 211 | 27 / 12 |

Where both versions have water, surface changes range −7.650 to +0.700 m at P10 and −11.457 to +4.250 m at P21. These samples overlap geographically and must not be counted as 882 unique world positions. The central nine-point subsets are derived from the corrected surveys.

**Invalid earlier measurement:** one-sided temporary water collision produced false zero-water counts. `physical-P10-one-sided-invalid.json` and the early logs are retained solely as invalid diagnostic history. Final `survey-P10.json`, `survey-P21.json`, `physical-P10.json`, `physical-P21.json` and `survey-summary.json` use double-sided collision with positive controls. Run `audit.py` to reproduce summaries and verify matching camera records; the obsolete `survey-summary-P10.json` is superseded.

## Junction evidence and next experiment

The reported source `(-2,-1)` switches at (−1110.78, −620.49) across 15.58 m to the retained receiver tail, dropping 24 m. The source `(-2,-2)` switches immediately across 92.90 m into a 120 m half-width alluvial reach, dropping 52.28 m. Its uncarved connector samples span 24.42–88.30 m. Smaller repeated switches between other raw channels also remain. `junction-profiles.json` records the actual positions and raw bed widths; uncarved heights alone are not a proof of valid or invalid hydraulic contact.

Pass 113 keeps the exact baseline terrain/collision while computing the same reach-based water against the original carving plan. This is a controlled separation of supply and geological shape, not a selected permanent architecture. It must demonstrate continuous supplied water and sound shoreline joins without relying on this pass's terrain changes. The long-route budget, duplicate downstream work, bar ownership, giant confluence drops, physics and full-game appearance still need resolution before promotion.

No production fix or original issue closure is claimed by this experiment.
