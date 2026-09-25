# September 15 reported issues

All issues begin open. Work proceeds one issue at a time: diagnosis and alternatives, failing reproduction/invariant, implementation, matched renders and pixel differences, nearby/time/collision controls, then an explicit result. An invariant passing alone does not close a visual issue.

## Photo register

Seed: **2697992464**. Coordinates below are transcribed rounded player/crosshair overlays, not exact camera transforms. Use `ReviewCam.solve_cam`/`shoot` to reconstruct the camera; preserve the solved pose for before/after. P05’s partially obscured player coordinate needs original-resolution confirmation.

| ID | Original screenshot | Observation | Player | Crosshair |
|---|---|---|---|---|
| P01 | [9.51.51 AM](</Users/ryko/Desktop/Screenshot 2026-09-15 at 9.51.51 AM.png>) | Doorframe filled with stone; missing door | [-201.6, 8, -969.8] | [-200.6, 10.1, -967.1] |
| P02 | [9.50.57 AM](</Users/ryko/Desktop/Screenshot 2026-09-15 at 9.50.57 AM.png>) | T-roof finish and roof-to-wall edge gaps | [-169.4, 16.7, -944.2] | [-174.4, 8.5, -944.7] |
| P03 | [9.49.33 AM](</Users/ryko/Desktop/Screenshot 2026-09-15 at 9.49.33 AM.png>) | Town path gap and protruding corner | [-212.6, 8, -896.6] | [-213.5, 8, -895.0] |
| P04 | [9.48.26 AM](</Users/ryko/Desktop/Screenshot 2026-09-15 at 9.48.26 AM.png>) | Sparse repeated pyramid cliff dressing | [-521.8, 28, -728.5] | [-533.1, 16, -755.8] |
| P05 | [9.47.14 AM](</Users/ryko/Desktop/Screenshot 2026-09-15 at 9.47.14 AM.png>) | Missing streamed terrain ahead; player coordinate partially obscured | [-530.6, 44, -377.2] | [-528.3, 44, -381.7] |
| P06 | [9.55.01 AM](</Users/ryko/Desktop/Screenshot 2026-09-15 at 9.55.01 AM.png>) | Bare riverbank cliffs | [-458.8, 24, -1888.8] | [-458.1, 12, -1860.3] |
| P07 | [9.55.19 AM](</Users/ryko/Desktop/Screenshot 2026-09-15 at 9.55.19 AM.png>) | Town-adjacent folded grass sheet and exposed rock | [-518, 20.3, -1954.1] | [-520.9, 21.4, -1956] |
| P08 | [9.55.51 AM](</Users/ryko/Desktop/Screenshot 2026-09-15 at 9.55.51 AM.png>) | Grass sheet overhang and split lip | [-589.4, 22.3, -2002.1] | [-601.5, 24, -1996.7] |
| P09 | [9.46.58 AM](</Users/ryko/Desktop/Screenshot 2026-09-15 at 9.46.58 AM.png>) | Square grass plane replaces rounded cliff lip | [-492.4, 36.6, -277.9] | [-493.3, 38.4, -276] |
| P10 | [9.53.41 AM](</Users/ryko/Desktop/Screenshot 2026-09-15 at 9.53.41 AM.png>) | Water sinks into ledge instead of crossing exposed drop | [-201, 8, -1485.6] | [-221.2, 0, -1478.9] |
| P11 | [9.44.34 AM](</Users/ryko/Desktop/Screenshot 2026-09-15 at 9.44.34 AM.png>) | Spawn field partial water and abrupt floating surface cutoff | [6.7, 0, -6.4] | [7.1, 1.2, -6.5] |
| P12 | [9.52.49 AM](</Users/ryko/Desktop/Screenshot 2026-09-15 at 9.52.49 AM.png>) | Abrupt short-distance animated-water transition | [-98.3, 4, -1221] | [-97.2, 4, -1224.4] |

## Work queue

The grass regression is first because its common surface/lip contract is a dependency of the requested cliff integration. Later issues stay open until their own review completes.

### 01. Grass lip and sheet regression

References: **P07, P08, P09; P03 nearby town control**. Status: **Implemented and verified at P07/P08/P09 — native terrain controls now precede tile selection**. [Result and evidence](01-grass/result.md).

Owner follow-up: [download.png](</Users/ryko/Desktop/download.png>) and [download-1.png](</Users/ryko/Desktop/download-1.png>) show the remaining deformation. Covering gaps is insufficient: restore the same simple slope/flat-cliff/corner topology as ordinary terrain. The follow-up now replaces post-classification deformation with ordinary native controls. P08 retains its standard cliff; P07/P09 retile to ordinary ground. Nine judged pairs and 5,325 foundation probes verify these sites; broader terrain and streaming acceptance remains open.

Initial alternatives / investigation: First: trace the recent change with historical source snapshots. Restore common terrain clipping/lip ownership for natural and town-graded ground; revert only the demonstrated offending behavior. Avoid another village-specific skin.

### 02. Terrain arrives too late / long apparent stalls

References: **P05**. Status: **Verified for the reproduced 180-second travel stall** — [result](02-streaming/result.md). Startup and universal streaming remain unaccepted.

Measured progress: the 180-second baseline survey freezes for 36.219 s. The first candidate reduces this to 11.209 s but remains rejected as a complete fix. The second candidate distinguishes approaching crossings from lateral prefetch, completing 1,803 m with zero waiting. Three matched loaded-site photo controls and 76 exact field hashes pass. See [investigation](02-streaming/investigation.md).

Initial alternatives / investigation: Profile a repeatable running route. Log job key, generation, queue age, distance, phase duration, cancellations/requeues, blocking dependencies and commit backlog. Distinguish expensive useful work from churn or wrong priority before choosing optimization; evaluate directional lookahead after nearest-player correctness.

### 03. Spawn water partly covers the field and ends as a floating plane

References: **P11**. Status: **Verified at the reported spawn and surrounding four-chunk seam** — [result](03-spawn-water/result.md). Source connectivity is retained after spill containment; 51 tests / 3,629 assertions and nine judged view pairs pass. Other water issues remain open.

Initial alternatives / investigation: Compare physical wet-domain/shore ownership with rendered coverage and source-domain boundaries. Repair the canonical field/coverage cause; do not hide it with fog or add an unrelated water plane.

### 04. Water motion ends at a nearby hard boundary

References: **P12**. Status: **Verified for the reported short-distance seam** — [result](04-water-motion/result.md). A separate 192 m current field fades circularly over 42 m while contact ripples retain their original resolution. Twenty-six tests / 150 assertions, fifteen judged timed pairs and six identical GPU contact-ripple controls pass. Broader water geometry remains open.

Initial alternatives / investigation: Measure the actual wave/current support and attenuation. Extend stable world-space motion and use a broad continuous transition; verify multiple times, camera angles and positions plus stationary controls.

### 05. Flow disappears into ground at cliff drops

References: **P10**. Status: **Verified at both photographed cliff lips** — [result](05-water-drops/result.md). Fifteen matched water-only, full-rebuild and timed pairs, 186 physics samples and 60 distinct tests / 3,847 assertions verify the repair and controls. The older free-shore input remains a separate unchanged-threshold regression; its production outlet now crosses the crest. Broader water acceptance remains separate.

Initial alternatives / investigation: Compare ground, spill routing, continuous water surface and actual flow across both sides of the ledge. Correct physical connectivity/containment, keeping genuinely dry islands dry.

### 06. Mountain assets need irregular green terraces and broader bases

References: **Previous mountain-study hero; P04 provides production context**. Status: **Verified for the reusable mountain assets and art study** — [result](06-terraces/result.md). Fourteen matched planted/bare pairs, four source tests, two native tests / 184 assertions and unchanged 41 clear study samples pass. Production grid integration remains issue 08.

Initial alternatives / investigation: Try coherent stepped buttresses with irregular shelf elevations, lengths and depths, tapering outward toward the base. Preserve fractured rock gaps, add shared ground treatment to exposed ledges, and judge several alternatives.

### 07. Protruding study terrace has no ground support

References: **Previous mountain-study hero, right-hand projection**. Status: **Verified in the study** — [result](07-grounded-study/result.md). Separate hanging slabs are removed in favor of the rooted terraced solids; full-footprint seating closes exposed rock toes. Fourteen matched pairs, three native tests / 215 assertions and 41 clear study capsules pass.

Initial alternatives / investigation: Replace the hanging shelf with a terrain-rooted buttress or a continuous supported rock mass, checking the complete underside and collision.

### 08. Dress original grid cliffs with matching rocks, green ledges and vines

References: **P04, P06, P07, P08, P09**. Status: **Implemented; P04/P06 art reviewed, nearby geometry controls documented** — [result](08-cliff-siding/result.md).

Owner revision, September 15: the rock-textured siding is rejected. Preserve the original cliff-face texture and native grid joins; attach matching rocks, irregular green terraces/ledges and trailing vines directly to the exposed face. All prior siding images remain rejected prototypes. The later 22:33 direction also rejects normal smaller cliff tiles. Production now overlays custom ledged rock ribs and Ultimate Nature mossy outcrops, keeping native faces/crowns underneath.

September 16 supersedes the dense overlay: all facade ribs are removed. Six weathered, wider outcrop forms retain exposed native walls, shared stone coloring, biome-colored moss, rounded native shrubs and cutout vines. New photos Q01/Q02 and an amber control are reviewed in the [revision result](../2026-09-16-cliffs/result.md).

### 09. Sparse repeated pyramids leave most cliff walls blank

References: **P04**. Status: **Implemented and visually reviewed** — [result](08-cliff-siding/result.md).

The native-tile attempt is rejected. Dense overlapping rock masses, green ledges and rooted bushes replace it. Sampled straight-wall coverage is 2,560/2,560 points in four orientations; native corner returns and protected route/grade areas remain exceptions. See the recorded rejected iterations and final oblique views.

September 16 owner direction explicitly replaces that full-coverage target with separated larger outcrops: current sampled coverage is 31–67%, with more variable depth and broader lower shoulders. See the [current review](../2026-09-16-cliffs/result.md); the prior 100% coverage result is historical.

### 10. Riverbank cliff faces also need dressing

References: **P06; P10 water-edge control**. Status: **P06 bank dressing reviewed; broader hydraulic/P10 compatibility remains unaccepted** — [result](08-cliff-siding/result.md).

September 16 Q02 exposed a decorative rock/cascade overlap. Owned outcrops now reject wet footprints; three matched waterfall views verify that reported obstruction is removed. Dry banks retain rocks and biome-tinted vines. This does not close broader hydraulic/P10 acceptance; [evidence and limits](../2026-09-16-cliffs/result.md).

Initial alternatives / investigation: Extend the same face treatment to banks rooted in their actual bed, protecting channel width and hydraulic continuity; qualify green cover by exposed surface and biome.

### 11. Path gap near town

References: **P03**. Status: **Open**.

Initial alternatives / investigation: Trace canonical external road to sealed town gate/street union; compare reservation masks against final paint and grade. Repair shared ownership and prove a continuous walk.

### 12. Odd corner protrudes from path

References: **P03**. Status: **Open**.

Initial alternatives / investigation: Inspect the same junction polygon and corner/fillet ownership; remove the spur through common junction construction while preserving path width.

### 13. T-shaped roofs have unfinished surfaces and short edges

References: **P02; P07 secondary roof context**. Status: **Open**.

Initial alternatives / investigation: Separate missing native valley material from incomplete roof coverage. Inspect stock UVs, orientation and exact roof/wall boundary; retain complete native surfaces and use measured roof-end fitting.

### 14. Doorframe has no door

References: **P01**. Status: **Open**.

Initial alternatives / investigation: Identify the emitted native door asset and any overlapping foundation/wall owner. Check closed-leaf bake and facade partitioning before repairing the responsible general rule.

## Earlier reports carried forward

The request to finish the other issues also retains the [September 13 ledger](../2026-09-13-manual/issues.md). Its accepted repairs are scoped evidence, not permission to drop its open items. In particular:

- Older water items 22–26 (floating boundaries, remaining P13 corner, mountain pockets, movement video V01, animation seam) continue under current items 03–05, with their original views/video retained as controls.
- Older cliff items 28, 29 and 33 (repetition, vegetation, landscape relief) continue under current items 06–10.
- Older item 15, disconnected tower massing, remains open after the current queue.
- Older item 17, the village collar/bank gap at its P24, needs a fresh review against the native-control grass repair; it is not automatically closed by the newer three-photo grass result.
- Older items 34 and 35, village lighting/shadows and wood/plaster detail, remain open after the geometry defects.
- Inter-town paths (older item 36) and full-width perpendicular stairs (older item 07) have documented functional acceptance. The newer path gap and roof photos explicitly reopen their own sites above; expensive road planning remains part of current streaming work.
