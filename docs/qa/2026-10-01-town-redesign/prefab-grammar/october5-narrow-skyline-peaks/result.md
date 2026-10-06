# Optional narrow skyline peaks — October 5

Accepted a targeted height rule for optional narrow skyline peaks. The planner previously let these local maxima bypass the ordinary terrace envelope and roll five repeated room storeys. `OPTIONAL_PEAK_STOREYS` now limits that optional body to four storeys plus the roof reservation. Upper streets and carried rooms still override it when they require greater bearing height. This is a procedural rule, not a seed-specific correction or a global house-height cap.

## Evidence and limits

The red-first regression fails three height assertions on the prior source, while the required-floor fixture already passes. Final focused run: two scripts, six tests, 207 assertions pass, including existing raised-district height tests. Required upper-street and upper-room heights remain intact.

Ten-town comparison: 31/large and 8,9,13,43,53,63,83,103,301/grand. All 480 previously covered walkway quarters retain their exact ceiling heights; floating masses and public-air intrusions remain zero. Five source plots shorten by two bands: 8 house.012; 9 houses.007/.035; 53 house.035; 83 house.006. Only four finished kit houses change: 53's finished storeys and roofs were already constrained downstream, and its fixed native view is pixel-identical. Do not count that source change as a visual improvement.

Corner turret counts remain unchanged. The turret on 9 house.035 moves down one world storey with its host (native Y 16.5→13.5). Both native corner views were inspected: the shaft, corbel and roof remain attached to the host; one side has foreground occlusion and the opposite side exposes the connection. This does not add more spires.

All 40 actual-player traversals pass: 8 (12), 9 (8), 53 (14), 83 (6). These cover the available skywalks, source bridges and underpasses in both directions. Matched native before/after views were inspected. 8,9 and83 lose a repeated wall storey while retaining projecting rooms and balconies. Some close views crop roof tips; they establish the local change, not overall architectural acceptance.

## Roof audit

8 retains its previous 55 roofs, three tiny roofs and one old gable hole. In 9, roofs increase 46→47 while defect metrics remain unchanged: one tiny roof and three pre-existing cut eaves on bridge.00.end.0.lower. Exposed open ends, unsupported roof air and uncapped towers remain zero. 53 and83 have identical before/after audit summaries, each with one old tiny roof and no gable holes, exposed open ends, unsupported roof air, cut eaves or uncapped towers. Their finished roof records change only for 83 house.006.

The baseline renderer/audit temporarily restores the prior planner in a try/finally block and restores the candidate byte-for-byte. Evidence JSONs, focused test logs, traversal reports and matched images are saved alongside this report. No global-suite acceptance is claimed.

## Remaining work

This improves selected narrow building proportions without sacrificing enclosed circulation. Other tall repeated façades are still visible, as are areas needing more convincing architectural composition. The full prefab-generalizing grammar, broad internal-square supply and overall redesign art acceptance remain open. This change neither finishes those goals nor increases tunnel or skywalk counts.
