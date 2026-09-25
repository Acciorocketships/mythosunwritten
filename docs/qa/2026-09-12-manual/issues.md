# September 12 manual review

Source: 31 annotated screenshots and the 4.45-second movement recording, SHA256 manifest in sources.json. The working tree had extensive earlier changes; baseline/ preserves source as received. No previous acceptance is evidence for these newly reported sites.

Work is sequential: reproduce, brainstorm, failing invariant, implementation, matched renders and differences, active falsification, then disposition before next issue. Screenshot overlays contain rounded player and crosshair positions, not a full-precision camera transform. Use ReviewCam reconstruction; label that limitation.

| Order | Issue | Source photo times | Status |
|---|---|---|---|
| 1 | Tactical view removes walkable ground | 11:56:57, 12:27:00, 12:34:46, 12:35:28 | Receiver-backed cutaway verified at reported sites; see 01-ground/result.md |
| 2 | Near-camera obstacle requires expanding screen coverage | 11:59:20 | Pending |
| 3 | Cutaway exposes house interiors and rear cliff faces | 12:01:38, 12:27:00, 12:34:46 | Verified with issue 1 under owner's revised rule; four native-house orientations and photo comparisons pass |
| 4 | Path obstructions, low exposed stone and loose rail ends | 12:00:30, 12:00:37, 12:02:53 | Pending |
| 5 | Unreachable public platform | 12:02:18 | Pending |
| 6 | Missing wall, roof end/side closure and mismatched low wall panel | 12:08:20, 12:02:18, 12:28:34 | Pending |
| 7 | Roof T junctions and centred bay windows | 12:03:37, 12:35:28 | Pending |
| 8 | Floating lawns, purposeless upper stair platforms, isolated modular houses/towers | 12:12:14, 12:19:59, 12:08:20 | Pending |
| 9 | Remove white facade decoration | 12:30:00 | Pending |
| 10 | Village ground gap/steep collar and blocked gentle ascent | 12:20:18, 12:08:40 | Pending |
| 11 | Path layout, larger well and campfire clearing variant | 12:20:05, 12:18:58 | Pending |
| 12 | Water floating field edges, divots and disconnected descending surfaces | 11:56:57, 11:57:49, 12:09:40, 12:10:53, 12:16:28, 12:21:02 | Pending |
| 13 | Water changes/glitches during movement | 12:05:48 recording | Pending |
| 14 | Cliff terrace contact, connected length/stacking, rocks and vegetation | 12:13:54, 12:14:23, 12:14:39, 12:15:37, 12:17:46 | Pending |
| 15 | Unified cliff collision, remove jump-catching lip, grass on terraces; audit new-item convex collision | 12:15:37 and written request | Pending |
| 16 | Landscape relief: hills, ridges, basins, canyons, narrow mountains | Written request and landscape photos | Pending |
| 17 | Village lighting, shadows, soft glow, surface texture and lanterns | 12:29:32 | Pending |
