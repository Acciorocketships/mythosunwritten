# October 8 manual judging pass — fixes and validation

Seed **2697992464**, starting revision `5dee037d797ad1837fe88aa3a657db2948edf119`.
The reported reproductions have been investigated, corrected where a defect was confirmed, and reviewed in the combined build. The photographed “sapling” is a correctly grounded short-stem bush. Unvisited procedural geography and occasional rendering hitches remain limits of this validation.

## Current acceptance map (October 9)

The sections below are chronological experiments; later entries supersede earlier defaults and outstanding-work notes. This table preserves the complete owner request and distinguishes measured fixes from remaining acceptance work.

| Owner issue | Current evidence | Validation and limits |
|---|---|---|
| Rivers dry before ledges | Continuous tile profile plus separate river descent clearance; fresh nine-chunk owner-seed and seed-99 physics audits found 0 dry/buried samples over 904 and 1,350 probes. Native parity retained. | Adaptive finished-surface refinement fixes measured shoreline triangles cutting through ground: 1,004 local and 5,910 two-chunk clearance samples pass, plus 470 actual mesh seam probes. Post-adjustment source support removes the reproduced uphill side branch; 594 river-axis probes and 1,219 shared-edge samples pass on two seeds. Broader unvisited geography remains a limitation. |
| Angular underwater terrain glitch | Drowned-crest rounding fix and exact photo-4 before/after; synthetic reproduction and C# parity. | Original defect fixed in the reviewed site. The later seed-99 ridge is a different feature, unchanged by the normal-only fix. |
| Water spills over hills | Bank-bound interpolation, source-flow ceiling and pond-join changes remove demonstrated fans/notches while retaining freeform routing. | Matched rendered views show the unsupported side cascade gone while the main river remains continuous. This is local visual acceptance, supported by two-seed numeric checks. |
| Medium-distance leaf dots | Complementary crossfade noise and restored mip chains on all three unique painted-leaf albedos; saved and trial captures match. | Final combined captures at 40, 80, 100 and 120 m, including adjacent camera headings, show no regular dot grid. A continuous motion review remains useful for temporal aliasing. |
| Apparently embedded saplings | Exact photographed object is a short-stem birch bush; root differs from ground ray by ~9 cm. Grass-hidden view exposes stems. | The photographed bush is correctly grounded; grass obscures its short stems. Collar trials were not adopted. Final nine-chunk root audit: 21 birch bushes and one actual sapling; the sapling root is 2.6 cm below ground. This small sample is not a comprehensive asset audit. |
| Slope/cliff grooves | Shared full-tile transition rule; 6,561 corner-case edge/bounds/monotonicity checks, native/GPU parity, grading regressions and rendered photo area. Steep continuous-surface normals corrected. | Rendered photo-area review retains cliff faces and smooth slope transitions; unvisited combinations remain covered numerically rather than visually. |
| Local battle-scale relief | Deterministic clustered peaks and bridge/divided-hollow forms; 960 m survey increases peaks 12→18 and basins 8→15, with native parity and world overview. | Final ground-level views plus actual-character routes pass across the clustered crests (31 waypoints) and divided-hollow bridge (34 waypoints). This verifies these representative areas, not universal connectivity of every generated feature. |
| Late-play lag | Bounded integration/retirement, incremental biome map, trample indexing and 743 MiB texture sharing saving. Ten-minute collision archive trial saves another 2,609 MiB peak static memory. | Final combined build: late-idle process p95 10.42 ms versus 36.36 in the earlier failing run; final-idle frame p95 35.08 versus 68.55 ms. Return to the original pose: process p95 6.53 ms, frame p95 30.92 ms. A fixed 600-step wave replay proves identical motion and roughly halves CPU cost. Occasional long GPU/retirement frames remain; end scenes differ as movement no longer stalls. |
| Grass only under feet | Support/shore indices preserve exact tile hashes; two workers, cancellable tail waits, bounded 60-second travel prediction, and exact cliff/water mesh optimizations keep ground ahead of the final route. | Final combined run: zero held movement frames across every phase; running backlog mean4.41/max24 tiles, run-and-turn mean0/max1, zero in both final idle and return idle. The route validates this seed and trajectory; it is not a guarantee against every cold solve in unvisited geography. |

## Retained changes

### Grass: repeated whole-chunk scans

Every blade-support query, including repeated footprint probes, scanned every rock-skirt grid in the chunk. The existing spatial index indexed polygon supports but put all grids into one flat list. Grid domains now occupy local 2 m buckets, preserving source order, tie behavior, and blocked-rock semantics. Detached water samplers similarly index shoreline segments in 12 m buckets grown by the saturated query distance. Neither change alters placement or water values.

Three real 24 m tiles in chunk (2,5), same inputs and output hashes:

| Tile | Before support indexing | After | Instances | Batch hash |
|---|---:|---:|---:|---:|
| (19,45) | 1904 ms | 486 ms | 161 | 3229466039 |
| (20,45) | 3179 ms | 407 ms | 460 | 3713151639 |
| (19,46) | 1613 ms | 409 ms | 155 | 3999560683 |

The measurements are worker throughput under background load, not frame-time claims. Shore indexing reduced 1,000 saturated-distance queries from roughly 307–407 ms to 69–75 ms. The optional GrassField.compute profile breaks out support, cliff, qualification and footprint work. Remaining qualification work is roughly 194–329 ms per measured tile.

### Underwater angular trench: drowned crests skipped rounding

At x=462, z≈1106–1108, the raw cliff drops from 48 m to 40 m while water is around 51–52 m. The wall was visible with the water hidden. `_walls` previously skipped **every** wet crest, a rule intended to avoid burying waterfalls. A fully drowned cliff now rounds; a crest whose downstream water falls below its top still skips that rounding. The C# implementation matches the GDScript reference.

The synthetic 8 m submerged wall reproduces the missing rounding before the change and passes afterward. The exact photo-4 camera shows the trench gone. This does not fix every river discontinuity or every angular shoreline triangle.

![Before](water-before.png)
![After](water-after.png)

### Tree dot grid: per-pixel imposter crossfade

The exact photo-8 view loses the regular grid when the imposter fade is disabled. The near tree and card previously used complementary interleaved-gradient thresholds at each pixel. They now share a continuous 8-pixel patch mask, including bark and alpha-tested Farmlands materials. They still use complementary opaque cutouts and retain the existing switch distance, LODs and shadow proxies.

The new render regression measures transitions between adjacent pixels inside the crown, excluding the atlas silhouette. The original shader alternates coverage across **88.6%** of measured adjacent pairs; the replacement passes the <25% bound while retaining a substantial contribution from both representations. This removes the regular pixel grid; it does not remove all leaf-edge aliasing or all visible silhouette differences between meshes and cards. A moving-camera art review remains useful.

These views use the exact photo-8 camera, but the distant background lies outside this focused harness's loaded area; judge the foreground/circled tree, not the missing horizon.

![Before](foliage-before.png)
![After](foliage-after.png)

### Runtime: distant integration budget

After startup, priority-3 distant scenery now gets a 2 ms integration budget instead of 6 ms. Startup, current ground, nearby crossings and the predicted travel corridor keep the 6 ms budget. This limits ongoing background work; a single slow commit can still exceed either budget.

Two 150-second phase runs at the reported water site, 1920×1080, no vsync, Apple M1 Pro:

| Phase | Before frame p95 | After frame p95 | Before process p95 | After process p95 |
|---|---:|---:|---:|---:|
| Idle | 30.45 ms | 27.76 ms | 23.60 ms | 20.94 ms |
| Run | 38.37 ms | 40.00 ms | 25.62 ms | 28.11 ms |
| Run + turn | 40.70 ms | 37.14 ms | 25.89 ms | 23.52 ms |
| Final idle | 42.88 ms | 40.40 ms | 25.62 ms | 21.00 ms |

These are a diagnostic pair, not a drift-controlled performance claim. Startup was under other test load, and the streamed scenes differ as work finishes. Grass backlog had median zero in the moving phases; run p95 was 8 then 7 tiles, run-turn p95 2 in both. The first run grew from 9 to 23 committed chunks while the background queue continued filling. Individual mesh/collision commits and trample updates still spike; retained memory was approximately 6.6–7.0 GB. Sustained-play lag therefore remains open. Raw summaries are included alongside this report.

## Diagnosed, still open

### Dry reaches and water spread

The water field solves against the carved terrain kernel. The separately constructed cliff sheet can stand over that water. Narrow corridors are explicitly allowed to be absorbed by the rounded banks in the current implementation. This explains an important class of disappearing reaches, but does not prove that every gap has this cause.

Two rejected experiments:

1. Fit every narrow channel by squeezing the existing rounded-bank profile. Synthetic 4/6/8/12 m channels stayed wet, but the matched real view developed steep slivers and ridges. Reverted.
2. Cap the final rounded sheet below solved water, with a shallow-depth blend. This exposed unrounded raw cliff cuts and angular trenches. Reverted.

Next design: give channel excavation, rendered banks, water meshing, grass support and collision one shared bed constraint. Build bounded, smooth cross-sections along connected wet reaches, with explicit crest-to-fall continuity. Validate depth against the **rendered** ground, not only TerrainTileField. Hydrostatic expansion must remain within spill containment; flowing reaches can descend, but their lateral wet extent must fit a carved cross-section. Do not globally raise the water table or impose a fixed river/lake shape taxonomy.

The broad hillside water in photo 3 still needs an isolated source/profile/containment audit. It is not established that it has the same cause as the buried reach.

#### Follow-up: exact centerline reproduction

`tests/fixtures/october8/water-inputs.var.gz` holds the saved chunk (2,5) terrain lattice, the water context's lattice and solved fill, and six river traces/profile arrays from the photographed reach. It contains numerical data only. The headless `october8_water_section.gd` harness reconstructs these inputs and rebuilds the current GDScript cliff envelope, independently of world generation. `--verify-water` exits 1 while a sampled wet river center is buried; this is an intentionally **red investigation harness**, not a passing suite claim. Current result: **three buried centerline samples**. The measured data is in `water-sections.json`.

| River point (x,z) | Kernel ground | Solved water | Rendered sheet | Sheet above water |
|---|---:|---:|---:|---:|
| (467.179,1127.435) | 36.0 | 37.170 | 43.635 | 6.466 m |
| (465.816,1139.357) | 24.0 | 25.593 | 39.596 | 14.003 m |
| (467.585,1151.226) | 12.0 | 22.032 | 26.706 | 4.674 m |

This river is roughly 44 m wide in its trace, so the failure is not limited to narrow peripheral wet pockets. Its raw trace bed stays at 51.5 m (profile head 53.7 m) until z≈1162, while the actual quantized/clamped terrain has already descended. The connected-water reconciliation lowers water against that kernel, but it does not know about the separately rendered rounded bank.

Stage capture distinguishes three contributors. At the first failed point the bank blend is already 41.250 m, and the final fillet raises it to 43.635 m. At the second point the tight bank is 37.752 m; removing only convex-corner rounding lowers that variant to 32.444 m, still above the 25.593 m water. Thus fixing only corners or only the final fillet cannot establish clearance. No experimental production geometry change from this follow-up was retained.

A separate, still-unproven containment hypothesis is that fixed river anchors cover the full trace width and are exempt from the hydrostatic cap. This needs a source-seeding audit against the natural rendered terrain; it must not be presented as the established explanation for photo 3.

#### Follow-up: bank constraints and both hydraulic reconciliation passes

A third bank-shaping experiment capped the *dilation before erosion*, rather than cutting the final rounded bank. It passed all 1,742 wet grid samples in the focused fixture, but the rendered scene exposed stepped walls and thin fins. **Rejected and reverted.** The GDScript-only patch and rendered failure are retained as `rejected-water-obstacle.patch` and `rejected-water-obstacle.png`; the experiment requires the native envelope disabled.

The uncarved terrain comparison (`natural-bed.json`) shows substantial excavation: at the problematic centerline points the original rounded ground is roughly 73–82 m high, whereas the carved kernel is 12–36 m. The early descent therefore follows the carve and storey-step clamp; it is not evidence that this reach was never carved.

The exact source solve has now been exported **before** its final downhill reconciliation (`tests/fixtures/october8/surface-input.var.gz`). At (465,1137), reconciliation lowers the offered water from 53.7 m to 26.3 m over a rounded bank at 42.1 m. Replaying with that bank as a lower bound retains 42.2 m, without exceeding the original source surface. The fine shoreline rescue runs another reconciliation against raw ground; constraining only the coarse pass is consequently undone. The optional `bank_floor` argument to `_build_sub_lattice_rescue` lets the offline replay constrain the second pass as well. Production does not yet supply it. Flood topology and the frozen raw-ground samples remain unchanged by this option.

Rebuilding smooth bank bounds, without dry-rock detailing, for all 6,730 lowered nodes in this source takes about **6.5 seconds across 192 occupied 96 m tiles**. Each tile builds only its affected bounding rectangle plus the envelope's normal padding. This is a measured prototype cost, not an accepted runtime regression or a final optimization.

The matched view keeps rounded banks and substantially improves the wet descent (`experimental-bed-bound.png`), unlike the rejected bank-cutting trials. Sampling the river path every ~2 m gives:

| Variant | Buried path samples / 40 | Worst intrusion |
|---|---:|---:|
| Current production water | 18 | 14.955 m |
| Replayed bank floor in both passes, plus experimental 1 m clearance | 1 | 0.077 m |

This candidate is **still failing**. Its one-metre clearance is an experiment, not an adopted design constant. A proper bound must account for the interpolated water between hydraulic nodes (and the wall-aware interpolation), rather than merely sampling the bank at those nodes. Lateral contacts also remain: 351 of 1,998 raw-wet one-metre grid samples are covered by the rendered bank. Those include shore contacts and cannot all be classified as broken river interiors from this count alone. Containment of the broad photo-3 water remains open.

The replay harnesses are reproducible from the saved source fixture: run `october8_surface_replay.gd -- --all-bank-tiles --clearance`, then `october8_project_surface.gd`, then `october8_water_section.gd -- --trial --verify-water`. The final command intentionally returns 1 until all sampled river-path clearances pass. `october8_apply_surface.gd` projects the trial into an idle live review harness for visual comparison. This modifies only the review process's cached contexts; it is not production water planning.

The restored .NET build succeeds. After adding the optional replay inputs, all **10 tests / 66 assertions** in `test_october8_water_banks.gd` and `test_native_water_fill.gd` pass. The candidate's failing geometric check is reported separately and is not hidden by those green compatibility tests.



### Follow-up: measured interpolation bound, viable dry-reach candidate

`WaterBankBound.node_bounds` builds a bilinear upper approximation to the bank at its 0.5 m sample nodes. For each 3 m or 6 m water cell it measures the greatest deficit of ordinary interpolation and adds that requirement to the four corners, taking the maximum of incident-cell requirements. A plane gets no artificial offset. Three tests (34 assertions) cover planes, curved and stepped banks at both pitches, and translation to the source solve's negative world coordinates.

The remaining physical contact with this bound alone was 9 cm into the cliff sheet (`Body/CliffRocks142`), not a separate rock. The current candidate adds the existing envelope's 0.4 m film threshold to the bank lower bound; reconciliation contributes its existing 0.1 m minimum depth. This replaces the earlier arbitrary one-metre interpolation margin with a measured interpolation allowance plus a half-metre nominal flow depth. The coarse reconciliation continues only to lower the original offered heads.

**Focused result:** the numerical path check passes all 164 samples at no more than 0.5 m spacing. Both chunk (2,5) and its downstream neighbor (2,6) were rebuilt with the trial. Physics raycasts at the same 164 points find zero buried **riverbed** samples, with a minimum measured water clearance of **0.308 m**. Two ray hits above water belong to the separate `CliffSlopeRockCollision` body; raycasting beneath those rocks confirms a submerged bed. These obstacles are recorded explicitly in `interpolation-bound-path-rays.json`, not silently discarded. The matched view retains smooth banks and a connected descent (`experimental-interpolation-bound.png`).

This is still an **offline replay candidate**, not the production water solve. Lateral bank contacts and the broad hillside-water containment issue remain open. Production integration must cache/reuse the bound, account for all hydraulic passes, preserve native parity, and measure cold-planning cost. The prototype builds bounds for all 192 occupied tiles in roughly 9.4 seconds, versus 6.5 seconds for point-sampled banks alone. Do not interpret that as an accepted runtime cost.

To reproduce this candidate, use `october8_surface_replay.gd -- --all-bank-tiles --majorant --flow-depth`, then `october8_project_surface.gd`, then `october8_water_section.gd -- --trial --verify-water`. The latter now passes for this fixture. The production fixture without `--trial` remains a red regression. All 13 targeted bound, drowned-bank and native-water tests pass (100 assertions). The live `october8_apply_surface.gd` probe rebuilds both photographed and downstream chunks and records dense path raycasts.

### Production bank-bound integration and reuse (in progress)

The source solve now feeds the measured bank bounds into **both** downhill reconciliations. A fresh production solve, without injected replay data, passes all 164 centerline probes. A separately started production scene also gives zero buried bed samples in 164 physics rays, minimum clearance 0.308 m. Three rays meet separate emergent slope rocks first; their underlying bed remains submerged (`production-bank-path-rays.json`). The render is `production-bank-bound.png`. This establishes continuity for the photographed reach, **not acceptable containment everywhere**: the water still spreads too broadly over the slope.

`NativeGridKernels.BankBound` mirrors the interpolation-bound calculation exactly, gates against the GDScript reference, and falls back after a forced native exception. All 16 integrated bound/cache-key/wet-bank/native-water tests passed (170 assertions) before adding the cache. The final integrated run with the fixed-tile cache passes **17 tests / 173 assertions**, including the new certified-region reuse check.

The first uncached production implementation spent about 12 seconds on 192 bank footprints. Combining footprints did not help (7.53 / 7.67 / 8.23 seconds for one-, two-, and three-tile batches in the isolated fixture); that experiment was discarded. The current candidate instead retains compact bounds for fixed 96 m world tiles on the heightfield plan, capped at 512 entries. Dictionary access holds a short mutex; computing a tile never holds it. No full envelope or mesh is retained. Region halos are certified before caching, so an incomplete edge cannot poison later requests.

The full-tile cold build is slower (about 33 seconds under current load), but repeating the complete source solve after clearing only the basin cache reduces bank work to **71 ms**, with **identical final water arrays** and 192 cached tiles. Whole-startup and travel costs still need assessment: this is not yet an accepted solution to runtime freezes. The most recent dense geometry check with fixed cached tiles still passes all 164 points.

A first 6 m containment scan of the photographed area finds 1,416 wet nodes, 20 above the uncarved kernel and 7 with no measurable cut. In the preliminary western analysis window, the median excavation is 23.4 m and median water depth 5.6 m; this window was broader than the later ray-located circle, so these are not exact measurements of that circled fan. Simply carving everything deeper is not supported by this scan. This scan compares kernels rather than final banks and does not establish lateral containment. The first attempted wide production screenshot extended beyond the loaded chunks and is excluded from evidence. The subsequent scene centered at (380,1120) loads the foreground water sites and confirms that both broad fans persist (`production-containment-open.png`); the distant background is beyond the loaded ring. Its startup took 243.5 seconds, but the different center makes this unsuitable as an A/B performance comparison. Its 164 bed raycasts also pass. The scene remains available for containment probes.

### Containment: bank allowance and premature joins

Camera rays locate the two circled fans at about **(50,1181)** in chunk (0,6), and **(121,1036)** in chunk (0,5). The first replay rebuilt only (0,5), leaving a false straight seam against the old (0,6); that mixed-state comparison is discarded. The corrected trial rebuilds both.

**Confirmed mismatch:** `_carved_flow_ceilings` extended every projected river head by 96 m, even where `WaterPlan.bank_strengths` had removed the broad carve beside a steep descent. The cap therefore allowed a high river to occupy another body's excavation outside its own banks. It now uses the same finite bank-strength fade as seeding/carving, and no broad collar along a dense descent. The new test fails on both sides before the change and passes afterward; it also protects genuine broad gentle banks. Together with the existing containment suite: **20 tests / 828 assertions pass**.

That correction removes the left fan in the rebuilt view (`narrow-allowance-containment.png`). In its ray-located 80×68 m analysis box, the 6 m wet-node count falls from 67 to zero. The right channel remains but no longer floods quite as much neighboring ground. The photographed dry reach still passes all 164 probes. A broader visible-trace audit finds 1,217 bed rays, zero buried wet samples, and 36 dry samples near the upstream source at (334,1163); those source-head samples are not declared fixed.

**Confirmed premature join:** the remaining right river ends at (143.016,1058.538), bed 43.5 m, because that point lies just inside the nominal terminal lake footprint. But the natural ground there is **56 m**, the lake removes **zero** ground there, and its water surface is **29.7 m**. This is dry lake rim, not receiving water. `_join_target` now requires the pond's own carve to put the point below its surface, excluding high flanks and retained islands. A joined trace also hands its bed to the receiving channel/lake datum. The photographed trace now continues three stations, to (135.925,1088.693), where it reaches the lower river channel at bed 27.5 m.

Lowering only the final station produced an unacceptable sharp 16 m terminal cut (`rejected-sharp-join.png`). The revised candidate carries only the added descent upstream at at most 1:4 until it meets the original bed. It does not reroute or raise the raw walk. New focused tests pass **6 tests / 36 assertions**; the existing joined-target tests pass 3 / 31, the junction-dependency test 1 / 34. A separate audit of 66 source traces over four seeds retains every lower-depth route dependency. The revised production render removes the giant terminal steps, but a smaller sharp lip remains (`distributed-join-detail.png`). The existing containment suite passes **18 tests / 823 assertions** after this change. A wider trace audit has 1,254 samples, zero buried wet samples, 36 dry source samples including 5 internal dry samples; the next correction below addresses those. This is not a claim of complete water QA.

### Grooves at slope/cliff joins

The F9 categories show the circled joins crossing the rounded cliff sheet and ordinary slope tiles. Saving the exact local lattice allows this defect to be reproduced without regenerating the whole world. A 4 m cross-section scan finds an introduced depression of about **0.568 m** at (-303.5,1342), absent from the raw kernel comparison.

Stage capture at z=1342 shows the raw ground decreasing smoothly while the wide cliff rounding rises into it around x=-303. The fillet partly fills the new valley but returns to the raw ground at x=-303.5, leaving the trough. Bedrock contributes no displacement on this section (`dent-stages.json`). This narrows the cause to the rounded transition and its fillet gate rather than rock detail.

A trial that filled only the additional morphological crease, subtracting the ground's own closing, reduced the measured worst depression to 0.421 m but left a visible groove. Reverted; not accepted as a fix.

Proposed reusable transition family: straight cliff-to-slope end, rising and falling end, convex corner, and opposing-bank saddle. Specify the shared boundary height and first derivative, preserve ordinary slope profiles outside the transition footprint, and prohibit added extrema along monotone cross-sections. Enumerate corner-storey combinations and rotations, then render the saved real lattice plus the tile gallery. An arbitrary post-mesh smoothing pass would defeat the requested repeatability.

![Terrain categories](dents-categories.png)

### Apparently buried sapling

The photographed instance is `meadow_birch_bush_03_summer_piece_00`, a short-stem birch **bush**. Placement is (-222.0464,62.416,1328.914), scale 1.185; the nearby ground ray hits y=62.507. Hiding grass exposes both short stems. The photograph does not establish a deeply buried sapling.

![Bush without grass](birch-bush-without-grass.png)

No placement lift was applied: it would float the roots. A candidate readability change is a modest grass-clearance collar for short woody vegetation, derived from asset metadata and its root footprint. It should be judged with grass present before changing all bushes. Other actual sapling placements have not been exhaustively audited.

### Local battle-scale geography

Before the October 9 follow-up below, no world-generation retuning was included. Macro feature candidates are spaced 256 m apart, with many footprints 200–285 m wide; merging raised features and suppressing cuts through their cores reinforces continuous large forms.

Candidate direction: retain the macro elevation and tall landforms, add a secondary structured tier of connected local summits/saddles and partial cross-valley ridges, and give broad basins multiple offset remnants. Initial proposed scale: several features within 100–200 m, with 8–25 m relief. Preserve routes through saddles and around islands. Avoid generic high-frequency noise, independent little bumps, or simply lowering CELL globally. Add this tier to the smooth river-planning field and its native parity implementation together; then re-pin geography tests to equivalent sites.

## Verification

- .NET build succeeded; NuGet vulnerability-data lookup warned because the network was unavailable.
- 46 tests / 24,077 assertions passed across October 8 grass/water regressions, native cliff-envelope parity, P03 cliff follow-up, support refinement, bedrock, rock placement and cliff-end suites.
- All 8 windowed tree-imposter tests / 312 assertions passed, including the new red/green dot-grid regression.
- The old detached-grade test in `test_september10_grass_sampling.gd` already indexes an empty `terrain_grades` array on the baseline, because current graded regions use native control heights. Its separate fine-shore identity test passed. This unrelated obsolete test was not weakened.
- Final targeted verification: 22 tests / 66 assertions passed across the new water/grass regressions, streaming queue, priority yielding and grass-worker latency/lifetime checks. The water regression now also explicitly compares the drowned-crest C# surface and protects a flowing sill.
- A broader field-streamer test attempted a new user-data cache directory outside the headless sandbox and was interrupted; it is not counted as a pass.
- Full-suite clean status is not claimed.

## Reproduction

Use `/Applications/Godot_mono.app/Contents/MacOS/Godot`, not the standard Godot binary. Build the C# project first. Windowed visual captures require the imported asset packs.

```sh
Godot_mono --path . res://tests/harness/cliff_site_review.tscn -- --seed 2697992464 --at 468.6,48,1117.4 --mouse-shot water_glitch:468.6,48,1117.4:467.8,48,1114.5 --mouse-shot dry_drop:494.4,52,1120.5:489.8,51.8,1122.8 --output /tmp/oct8-water-review
Godot_mono --path . res://tests/harness/cliff_site_review.tscn -- --seed 2697992464 --at -260,60,1330 --mouse-shot sapling:-226.7,60.1,1331.7:-222.4,61.8,1330.8 --mouse-shot dents:-312.3,47,1357.6:-311.8,49.2,1355.6 --output /tmp/oct8-land-review
Godot_mono --path . res://tests/harness/cliff_site_review.tscn -- --seed 2697992464 --at 264.9,95.2,1192.1 --mouse-shot foliage:264.9,95.2,1192.1:260.1,90.9,1202.3 --output /tmp/oct8-foliage-review
Godot_mono --headless --path . --log-file /tmp/oct8-dents.log -s tests/harness/october8_dents_probe.gd
Godot_mono --headless --path . --log-file /tmp/oct8-water-section.log -s tests/harness/october8_water_section.gd -- --verify-water
```

The live review harness accepts a resource path written to its output directory's `probe` file. `october8_site_probe.gd` records grass costs/hashes and wet-ground conflicts; `october8_geometry_probe.gd` raycasts the trench and captures the raw kernel; `october8_land_probe.gd` identifies the bush and captures categories. The stored lattice is `tests/fixtures/october8/dents-lattice.var`. Probe timings under concurrent world generation are throughput evidence only.


### Spring outlet datum and remaining flowing bank (October 9)

The dry head of source (0,1) inherits its pool level of 91 m while the independently planned outgoing bed begins at 95.5 m. The carved kernel stands around 92 m there: water cannot flow out of its own spring. `_fit_source_bed` now caps the outgoing bed at the pool surface minus the existing river ride until the original descending bed is lower. It changes excavation, not pool height. NativeRiverWalk mirrors the exact float32 output and receives both hydraulic constants from GDScript. The first parity run caught the missing native change and disabled the port as designed; after the C# update/build, **8 tests / 71 assertions pass**, including exact native/reference walks and fault/deferred-gate tests.

The fresh production scene using the safe GDScript fallback (it started before the new native build finished) now has **1,254 river-centerline probes, zero dry, zero internal dry, and zero buried samples**. The original 164-point ledge reach also remains clear. This establishes continuity at the photographed site, not every waterway in every seed. Native equality is tested separately; this fallback scene's 234 s startup is not a native performance measurement.

The remaining right-channel lip is a real 8 m kernel step at z=1050, x≈120. Upper ground is 40 m, lower ground 32 m, and water crosses from 40.1 m to 39.06 m in the first half metre. `_walls` intentionally omits a flowing crest, leaving its vertical ground face. An in-memory experiment is testing continuous rounding capped beneath the actual water surface; it is not yet a production change. Containment appearance and cold planning cost remain open.


The source-bed change also passes the existing containment and flow-footprint tests: **20 tests / 828 assertions**. A first in-memory flowing-bank experiment that removed crest suppression and capped the entire sheet beneath water is **rejected** (`rejected-flow-bank-cap.png`): it rounds the center lip but cuts vertical walls into the shores. Its 1,254-point continuity audit still passes, showing why that test alone is insufficient. The next in-memory trial preserves the original rounded bank everywhere and adds only the extra flowing-crest rounding that fits beneath water, fading the addition to zero as clearance vanishes. This intentionally expensive two-envelope prototype is for visual judgment only.


The second prototype preserves the shoreline and removes the exposed angular face (`flowing-bank-addition-trial.png`), with all 1,254 centerline samples still clear. However, the center still reads as a blunt bump, and the implementation requires two full envelope builds. **Not adopted.** The production envelope remains unchanged by these two trials; only the diagnostic live scene holds the second prototype in memory. The four-seed route-dependency scan after the spring-bed correction again reports **66 sources / zero failures** (a macOS certificate-store message appears after completion, unrelated to the geometric audit). The .NET build succeeds with the existing unavailable NuGet vulnerability-data warning. `git diff --check` passes.


### October 9: battle-scale connected relief

Implemented `LandformFeatures.local_relief` in the smooth river-planning field and the detailed terrain field together. A deterministic 192 m grid carries connected three-summit crests or divided hollows, with 16–32 m amplitude and at most 148 m radius. Crests retain lower saddles; hollows retain a cross-valley bridge and two offset remnants. Neighbors merge their positive and negative contributions separately using the existing smooth union. The macro hills, elevation bands, and mountain ranges keep their previous parameters. Candidate memos use the existing short GDScript mutex and bounded native concurrent cache; native hot calls allocate no per-point node arrays.

The exact native mirror is `LocalLandforms.cs`, called by `HeightField.cs`; tuning constants come from the GDScript table. The initial parity failure exposed a float32 division in C# where GDScript promotes method-returned floats to double. Casting the operands to double restores exact agreement. **9 local-shape/native-height tests / 3,727 assertions pass**, including independent two-seed detail/smooth comparisons. **3 native river-walk tests / 35 assertions pass** with the revised geography. **29 existing terrain-field, macro-landform, and cache-key tests / 16,492 assertions pass**. No old geography pin was weakened.

Matched production-kernel previews over 960×960 m, centered at (-200,1000), show additional local ridges and divided hollows while retaining the large forms. An interior-component prominence scan at 4 m sampling counts **12→18 summits** and **8→15 basins** with at least 8 m prominence/depth; components touching the sampled boundary are excluded. The script is `local-prominence.py`; inputs are the harness's `0_heights.json` and `1_heights.json`. This is a local shape measurement, not proof of tactical traversal throughout the world.

![Before local relief](local-battle-before.png)
![After local relief](local-battle-after.png)

The full production valley scene completes in 154.6 s under concurrent tests. `local-world-overview.png` confirms the new relief remains visible with cliff rounding, rocks, and vegetation. That overhead camera differs from the owner's photo: the old camera lies inside the revised terrain, so its first capture is excluded. The scene has no visible river traces in its collected contexts (zero audit samples), and must **not** be counted as a water-continuity pass. Local relief changes water routing and carving; earlier successful 1,254-point water checks describe the preceding geography only. New wet-site QA, traversal review, planning-cost assessment, and the remaining original issues are still required.

Reproduce the matched kernel views with `october9_local_kernel_preview.tscn -- --output DIR`, then run `python3 local-prominence.py DIR`. The fixed site and 4 m sampling are embedded in this review harness. The baseline view uses a detached copy of TerrainField without the local-relief term and the same terrain quantization. The superseded standalone shape prototype was removed; the game has one local-relief implementation plus its exact native mirror.


Current absolute native-height benchmark (not an A/B regression measurement): warm detailed `height01` 13.6 µs/call, smooth 5.36 µs/call; native batches 9.29 / 2.24 µs per detailed/smooth point. Three cold r16 regions take 439 / 235 / 325 ms. Native gate/setup takes 4.75 s under the current machine load. The game still defers the gate to a worker. A macOS certificate-store error is printed after the benchmark; the geometry calls and gate completed successfully.


### October 9: chunk-local trample updates and sparse time rebasing

Confirmed a late-streaming main-thread cost: each scenery change flattened and recopied all loaded structural grass footprints, then repainted the local texture even for distant chunks. `TrampleField.update_static_chunks` now owns per-chunk copied stamps and bounds, updates only changed chunks, and repaints only when an old/new extent intersects the local texture. Rasterization retains stable x/z chunk order so overlapping direction blends are deterministic. The streamer batches arrivals/removals into this API.

A 25-chunk / 10,000-footprint microbenchmark changes a distant chunk 25 times: median **28.647 ms → 0.394 ms**, maximum **47.186 → 0.677 ms**; static texture hash remains **1123532323**. Different background load limits precise speedup claims. The full texture remains necessary when nearby scenery changes or the domain scrolls.

Dynamic trample timestamp rebasing previously scanned all 65,536 pixels every minute. It now tracks stamped pixels, remaps those indices on scroll, and discards expired entries during rebasing. A matched simulated two-minute curved walk measures epoch maximum **4.213 → 0.191 ms**, stamp median **0.037 → 0.040 ms**, stamp p95 **0.101 → 0.065 ms**, and scroll maximum **1.023 → 2.689 ms**. Sparse tracking trades some scrolling cost for removing the full-image periodic scan. This is not proof that all late-play lag is fixed.

**15 trample tests / 86 assertions pass**, covering overlapping chunk order, removal/replacement, distant no-upload behavior, dynamic trails through scrolling, expiry, and large elapsed-time rebases. The streamer's targeted static-dressing integration test passes (1 test / 2 assertions). Harnesses: `october9_trample_cost.gd` and `october9_trample_walk_cost.gd -- --reference PATH` (supply the baseline TrampleField source). A sustained windowed frame/grass run is in progress; no result claimed yet.

A fresh nine-chunk wet-world scene with local relief takes **170.962 s** to start and checks **420 river samples: zero dry, zero internal dry, zero buried**. This replaces neither the earlier geography's 1,254 probes nor visual containment judgment. The two automatic cameras land at loaded chunk boundaries, exposing the review scene's unloaded background; those captures are unsuitable as final water appearance evidence. Flowing-bank shape, slope/cliff grooves, complete water containment, and sustained travel remain open.


The 150 s windowed run is complete (`runtime-trample-local-relief.json`, 1920×1080, no vsync, .NET, seed 2697992464). Startup takes **151.4 s**. Grass backlog median/p95 is **2/5 tiles** in run and **0/6** in run-turn (maximum 8); both idle phases have zero pending tiles. This route no longer demonstrates grass restricted to the player's feet. It is an absolute measurement on changed geography, not a controlled old/new game comparison.

Main-thread process p50/p95: idle **1.20/6.82 ms**, turn **1.24/6.22**, run **4.95/10.57**, run-turn **9.80/17.62**, idle-end **5.32/10.95**. Run-turn frame interval p50/p95 is **22.65/33.49 ms**, maximum **109.07 ms**. Sustained smoothness is **not solved**. The largest streamer spikes identify `cliff_rock_skirts` commit steps at **29.3, 26.7, and 21.9 ms**, with additional 9–12 ms collision steps. Another 22.7 ms integration frame includes an 8.1 ms abandonment and 11.5 ms preparation. These are specific remaining targets; the changed world prevents attributing their frequency solely to the trample change.

A separate saved-photo groove experiment (`october9_dent_profiles.gd`, `dent-width-profiles.json`) replaces the variable ridge-width blend with constant narrow/middle/wide values, only in detached diagnostic scripts. Baseline added dip is **0.568 m** across a 4 m section; constant variants reach **0.698 / 0.706 / 0.877 m**. All retain substantial introduced grooves. Therefore simply removing width noise does not fix the problem; the cliff-end/foot transition itself needs a better rule. None of these variants changes production geometry.


### October 9: bounded rock-skirt collision integration

The last `cliff_rock_skirts` step was an unbounded collision BVH build, even though skirt gathering was already split into 24-skirt batches. `RockSkirt.commit_steps` now builds at most **1,000 triangles per collision step**, all on the same static body. The rendered mesh and all collision vertices/windings are unchanged. The first shape retains the old name; subsequent shapes have numbered names. This applies to cliff and dressing rock skirts through their shared implementation.

Two targeted tests / six assertions pass: all **2,501 input triangles** are recovered exactly and in order from three shapes, each bounded to the configured count; an empty input creates no steps. A 30,000-triangle sloping-surface benchmark (five repeats) measures a whole build at **30.293 ms median / 43.406 ms max**, versus **0.265 / 0.844 ms** per 1,000-triangle piece. Total construction time per chunk falls from **33.080 to 8.427 ms** in that synthetic case; additional physics shapes may affect runtime broadphase cost, so whole-game follow-up remains necessary.

The windowed .NET `profile_chunk_commit` run at chunk **(0,2)**, the location of the earlier 29.3 ms skirt spike, completes with **no terrain integration step above 3.2 ms** (`rock-skirt-integration.txt`). This harness excludes roads/villages and executes all timed steps consecutively, so it establishes bounded construction costs for that chunk rather than predicting a whole-game frame distribution. Its deliberate unsplit baseline collision timing is 646.5 ms for the 674,473-triangle cliff sheet; that is not the streaming path. The large post-attachment frame likewise follows the harness building full chunks repeatedly in one frame. A new sustained world run has not yet been performed after this change.


### October 9: isolate the groove's cross-tile overlap

Saved photo geometry confirms the worst point (-303.5,1342) lies in **tile (-26,111)**, corners **56/52/48/52 m**, with **zero cliff edges**. The raw kernel falls monotonically across the measured section. The neighboring sheet's rounding rises from 48.75 m at x=-303.5 to 49.16 m at x=-300 while raw ground falls to 48.14 m. Thus this is a separate cliff-sheet overlap deforming an ordinary slope piece, not a different slope kernel selected inside that tile.

Detached experiments (`october9_dent_fillet_profiles.gd`, `october9_dent_end_profiles.gd`) isolate the existing controls. Ungated filleting reduces worst added dip from 0.568 to 0.421 m; removing its lip bound gives 0.603 m, and doing both 0.444 m. Disabling low-wall widening leaves the worst dip unchanged; disabling convex-corner rounding leaves 0.545 m. None solves the issue and none changes production.

A new prototype (`october9_dent_guard_profiles.gd`) preserves every tile with no cliff edges exactly, fading sheet lift to zero over 2 or 4 m on the neighboring cliff side. Worst added dips become **0.394 / 0.255 m**. Matched windowed renders (`october9_dent_guard_view.gd`) reveal the cost: straight transition seams and abrupt exposed faces. **Rejected** as a production solution. The 4 m capture is retained as `dent-guard-slope_guard_4.png`, with `dent-guard-baseline.png` for comparison. This confirms the need to construct compatible cliff/slope transition shapes; a post-process mask can improve a dip statistic while violating the requested smooth geometry.


### October 9: compatible tile-profile prototype

The next isolated prototype builds cliff and slope crossings inside the existing corner-layer tile construction, replacing the discontinuous crossing with a rounded profile and removing the separate cliff-end warp. It does **not** apply the raised cliff sheet. This is a candidate change to the underlying geometry, not a mask over current geometry, and it is not enabled in production.

Narrow crossings spanning 40% / 70% of a tile reduce worst added dips in the saved photograph area to **0.051 / 0.020 m**, while ordinary slope tiles remain exact. However, a 625-arrangement property scan finds a 0.0264 m adjacent-sample reversal with the 70% profile. Reason: an 8 m steep crossing can lie below a neighboring 4 m gentle crossing near their common low end, so fixed narrow and broad profiles can cross despite ordered corner heights. Edge continuity alone cannot exclude that groove.

Using the same smootherstep profile over the full tile for both crossings makes steepness follow the height difference. The shared profile passes **6,561 corner arrangements**, heights 0–32 m: zero overshoot, zero shared-edge error, zero ordinary-slope change, and zero reversals along either axis whenever that axis's corner heights are ordered. Saved-photo added dip is **0.000001423 m** (sampling precision), with zero sections above 4 cm. The local render is smooth without the border-mask seams. The wider 960 m kernel-only comparison retains peaks, basins, plateau interiors, and steep faces, with rounded transitions. It deliberately omits water, dressing, and the cliff sheet; it does not prove the integrated world is correct.

Harnesses: `october9_tile_transition_kernel.gd` constructs the detached experimental kernel; `october9_tile_transition_trial.gd` samples the saved photo region; `october9_tile_transition_check.gd` returns failure if any property error exceeds 1e-9; `october9_dent_guard_view.gd -- --tile-profiles` renders the local samples; `october9_tile_world_preview.tscn -- --output DIR` renders the wider kernel-only comparison. First run `october9_dent_guard_profiles.gd` to produce the baseline sampling domain in /tmp. Outputs are `tile-transition-properties.json`, `tile-transition-dips.json`, and the accompanying PNGs. Integration with native sampling, cliff dressing, collision, and water remains required before adopting this candidate.


### October 9: opt-in shared-profile integration

`TerrainTileField.CliffEnd.SHARED_PROFILE` now implements the candidate in the real sampler, with the exact C# counterpart. `NativeTileKernel`'s parity gate covers all four enum values. The `cliff_site_review` flag `--shared-profile` selects it before world construction; **E3 remains the default**. PlanningDiskCache uses a separate seed directory for alternate modes and rejects entries after the configured mode changes. This prevents review water from crossing between geometries.

The .NET build succeeds (existing NuGet vulnerability-data network warning). Five native tile tests / **1,630 assertions** pass, including independently seeded point/grid comparisons with the new mode. Three cache-key tests / **68 assertions** pass. The production-mode property harness repeats all **6,561 arrangements** with zero overshoot, edge mismatch, ordinary-slope error, or ordered-axis reversal.

A full nine-chunk world centered at (0,1200) starts in **114.071 s** under test load. The integrated shared terrain renders smoothly, but the complete review is **not passing**: cliff rocks disappear and the river audit reports **904 samples / 9 internal dry / 0 buried**. The dry reach is source (-1,1), stations 6–7, approximately x=-41..-34, z=1143..1148. Captures and failed probes are retained in `shared-profile-world-overview.png`, `shared-profile-world-water.png`, and `shared-profile-river-failures.json`.

The missing-rock cause is explicit: `TerrainTileField.wall_segments` emits segments only when owner-side heights differ, and `CliffSlopeField._add_wall` resamples that same discontinuity. A continuous shared profile therefore supplies no foot lines, although its storey classifications still mark cliff edges. Rock placement needs a semantic cliff description compatible with the rounded ground, rather than reintroducing vertical walls. The nine dry river samples require tracing the revised profile/carve/fill interaction. This mode remains opt-in until those dependencies and full-world style are resolved. Native gates reported no mismatch in this scene.


### October 9: shared-profile dry-reach diagnosis

Live probes isolate the nine dry samples to hydraulic interpolation. At (-39,1144.5), ground is **75.012 m**, planned channel membership level **75.568 m**, but coarse water is **74.346 m**. At (-40,1143.927), one of the four coarse corners is dry; the tapered surface is **75.333 m** over ground **75.365 m**. Thus the coarse water chord/taper cuts through a curved descent even where the planned river has clearance. The fine rescue did not preserve that planned head through this reach.

`october9_shared_fine_trial.gd` performs a **detached** experiment: in a local 42 m square, valid planned channel levels above sampled ground can supplement the existing 3 m fine grid. It changes 140 vertices and makes **29/29 half-metre centerline samples wet**, but minimum clearance is only **0.0643 m**. This is not adopted: a thin wet film is insufficient for the requested visual flow, and channel-edge containment has not been judged. The trial does not mutate the live world. `shared-dry-detail.json` and `shared-fine-trial.json` retain the values. The review scene remains available for further probes.


### October 9: semantic cliff foot lines for shared-profile dressing

`wall_segments(..., include_rounded=true)` now offers dressing-only shoulder/foot lines for classified cliff edges under SHARED_PROFILE. Heights are sampled half a cell to either side of the centre line on the actual rounded surface; `sample_offset` tells `CliffSlopeField` where to resample. `CliffRockDressing` opts in. The default query remains discontinuity-only, so grass rejection and mesh-wall generation do not acquire phantom vertical walls. Ordinary one-storey slopes generate no semantic cliff line.

Rock placement in shared-profile mode can fit directly to the ground; the old requirement that the envelope stand at least 0.2 m above raw ground excluded every such rock. E3 retains that requirement and its old placement behavior. The targeted tests pass (2 tests / 12 assertions); the preceding combined run of new and existing tile tests passes **35 tests / 39,860 assertions**, before one extra no-phantom-wall assertion was added and rerun in the targeted tests.

The windowed chunk (0,6) review generates **132 slope-rock instances**, and the capture confirms foot rocks have returned (`shared-profile-foot-rocks.png`). Worker construction takes **158.550 s** under concurrent tests; this is not a performance pass. Exposed bedrock patches are still absent: their mask is currently derived from the old raised envelope. Therefore the experimental mode is not visually complete and remains opt-in. The integrated water review scene was shut down cleanly after its diagnostics were saved; no live review process is required for the next iteration.


### Shared-profile bedrock integration (October 9, candidate only)

The continuous tile profile has no discontinuous wall for the former envelope
closing to detect. The previous candidate therefore retained foot rocks but lost
exposed bedrock. Added a separate shared-profile envelope path: start from the
actual ground, add at most 0.30 m on grades above 1.0 (full at 1.2), apply the
existing bedrock detail there, then clamp back to that bound. Ordinary one-storey
slopes, excluded ground and finite-water nodes receive no lift or rock exposure.
No morphological wall closing or foot fillet runs in this path. E3 stays default.
The native BuildShared entry catches faults and is covered by the existing parity
gate; gate comparisons pass an explicit tile mode instead of changing runtime
state. The old E3 gate remains exercised even when the world uses the candidate.

Validation: dotnet build succeeds (existing NU1900 network warning). Three shared
profile tests / 20 assertions pass. Five native envelope tests / 31 assertions
pass, including the original P03 fixture, twelve random old-mode cases and twelve
shared-profile variants, dispatch and forced-fault fallback. The initial bounds
test used an unsupported PackedFloat64Array.max call; changed it to Array.max and
reran successfully. No production arithmetic changed for that test correction.

Viewed `shared-profile-bedrock.png`, a .NET windowed chunk (0,6) capture: exposed
stone patches are restored and foot rocks remain. The dark, sharply bounded moss
bands also exist in the previous no-bedrock candidate; player-scale shading
review remains necessary. This single-chunk capture is not evidence of complete
water containment or broad visual acceptance. Worker build 144.4 s under concurrent
test load; 23 cliff tiles, 152559 vertices, 129 foot-rock instances. Largest listed
integration step 3.2 ms. Synchronous commit totals and the harness's first frame
are not representative of streamer frame time. New cold-planning performance
and long travel still need validation. Shared water's nine known dry samples and
local fine-head experiment remain unresolved; this step changes neither.


### River descent depth: production correction (October 9)

The shared-profile source (-1,1) gap has two interpolation losses. Its dense
profile guarantees only 0.10 m at 4 m-spaced samples. A direct audit of 144
samples found 0.099999 m at the nodes but only 0.039690 m between nodes, below
the 0.05 m wetness threshold. The 6 m fill then lowered parts further. An older
membership-only diagnostic overestimated the offered head because it reads the
coarse trace stations rather than the dense descent; it is not the production
seeding answer. The revised experiment projects the actual dense segments.

Rejected detached repairs: restoring membership heads closed the gap at only
0.0643 m minimum depth. Raising fine nodes by a sampled bank bound did not
improve that minimum and widened the wet footprint. Restoring actual dense
heads still left 27/57 probes dry. Instead changed the uniform profile shaping
floor, DESCENT_CLAMP, from 0.10 to 0.80 m, before fitting the monotone spline.
The detached 0.4 / 0.8 m trials produced 0.112 / 0.683 m minimum depth, with zero
water above original uncarved ground in 7225 half-metre patch probes. These
figures include detached fine-head restoration and are not production claims.

The production change is only the deeper shaping floor; no detached fine-head
restoration was adopted. The same constant had also controlled coarse/fine
crest interpolation. That unrelated feather is now SHORE_CREST_FEATHER=0.10
in GDScript and NativeFineRescue. The first native gate correctly rejected the
coupled edit; separating the settings restored exact parity. Native profile
constants already pass the new depth explicitly to C#.

Fresh no-disk production chunk (-1,5): 57/57 gap probes wet, minimum 0.146999 m,
region 3.19 s, water 9.96 s. New regression tests the real fill and the original
uncarved banks over the full 42 m patch: 1 test / 2 assertions pass. Native
profile suite: 3 tests / 84 assertions, 30 rivers, 29 native, 170 descent spans.
Existing monotonicity: 1 test / 519 assertions; smooth pool-to-pool: 1 / 5.
Build succeeds with existing NU1900 warning; diff whitespace check passes.

Fresh nine-chunk .NET scene (shared-profile candidate), startup 150.718 s:
904 physics-backed river samples, zero dry / internal dry / buried (formerly
nine internal dry). Viewed gap and downstream captures saved here. The drop is
continuous, but shallow-looking areas, abrupt banks and stepped moss bands
remain visual concerns; this is not complete art acceptance or proof across
all terrain/seed combinations. E3 remains default. The review session remains
live for follow-up probes: tool session 60202, output
/tmp/oct9-water-production-depth-final, log with the same stem + .log. Earlier
review sessions 74308 and 51884 have exited; the latter was deliberately stopped
after the constant-coupling parity failure. No render from that aborted run is
used as evidence.

### Five-minute movement and bounded biome-map scrolling (October 9)

The nine-chunk review above has now exited normally. Neutral/lighter moss
material trials reduced some dark bands but flattened the palette; neither
was adopted. Their captures are retained as shading diagnostics.

Longer shared-profile run: five 60 s phases, .NET, 1920x1080, no vsync,
startup 137.831 s. No movement-freeze frames. Process p95 idle/turn/run/
run-turn/idle-end: 5.61 / 6.39 / 14.22 / 10.01 / 7.32 ms. Frame dt p95:
22.64 / 24.39 / 26.15 / 31.29 / 31.51 ms. Grass pending p95 was 24 during
run and 28 during run-turn (max 40), draining to zero at rest. Memory reached
8.57 GB as the loaded world grew to 41 chunks; this does not establish a leak.
The largest movement frame was 877.89 ms, with 189.05 ms of process time,
not attributed to streamer sections. Late-play lag remains open.

Confirmed bounded-work opportunities: cliff collision steps reached 8–13 ms;
pieces are now 1000 triangles instead of 3000. Whole/stepped real chunk tree
equivalence passes (1 test, 3 assertions). Gameplay integration uses 2 ms
while the player is free to move, preserving 6 ms for startup/held players.
This is pending the repeated movement/grass profile, not yet a performance win.

BiomeGroundMap synchronously rebuilt 4225 samples whenever crossing a 768 m
window boundary. Direct measurement: 61–62 ms per rebuild. Subsequent windows
now prepare rows within a 1 ms soft budget and publish the four textures and
origin together on completion. The previous 3 km map remains active meanwhile;
the first map and seed changes remain synchronous. Direct probe: 35 slices,
median 1.834 ms, max 1.968 ms, identical digest 2935280639. Two tests / 100
assertions cover exact output, retained old map, reversal and seed replacement.
This removes a measured stall source but does not prove the 189 ms event's cause.

Repeated five-minute result: the all-gameplay 2 ms budget is REJECTED and
reverted. No movement freezes, but grass pending p95 increased from 24/28 to
48/64 in run/run-turn (max 65), and only about 31 chunks had arrived near the
end versus 41 before. Run-turn process p95 fell 10.01→6.42 ms, idle-end
7.32→5.51, but run remained 14.64 ms (was 14.22). The moving worst process
frame fell 189.05→56.66 ms; worst dt remained 472.6 ms (was 877.89).
Startup 149.6 s. These are sequential trials with slightly different routes
(end positions differ by about 13 m) and background load, not isolated causal
measurements. Keep the original 6 ms budget for nearby arrivals / 2 ms distant.
The biome-map change and smaller collision pieces remain for separate review.

Next runtime suspects: the 472.6 ms frame coincides with chunk eviction
(resident count 21→19), so deferred destruction merits direct measurement.
Rock-skirt gather steps still reach about 8–11 ms; first mist material
creation reaches 29 ms, and is missing from BiomeChunkFx.warm(). No fix for
either was included in this measured trial. Both profiling sessions have exited.

### Bounded chunk retirement (October 9, gameplay validation in progress)

Isolated chunk (0,2), shared profile, 1241 nodes: one-shot free 20.015 ms.
TerrainRetirementQueue detaches immediately (0.667 ms) then destroys leaves on
the main thread, at most 32 nodes / a 1 ms soft budget per frame. Measured
maximum slice 2.597 ms. Render/physics resources remain main-thread-owned.
These probes had zero visible draws because the camera was aimed at the
default centre rather than the requested chunk; they establish CPU destruction
cost, not GPU or gameplay frame improvement. The harness now supports forced
drawing; pass a matching --centre for future visible-chunk probes.

Terrain and feature evictions use the queue. Large grass-sampling metadata is
removed into the existing worker drop box before retirement, preventing node
destruction from releasing those field/support dictionaries on the main thread.
Two queue tests / 107 assertions verify immediate detachment, bounded deletion,
complete cleanup and partially processed shutdown. One streamer test / four
assertions verifies snapshot lifetime through worker release.

Rock-skirt gathering is now four skirts per step (was 24); its collision
ordering tests pass (2 / 6). The older real-chunk test now compares the same
rendered node and concatenated collision faces, because partitioning into more
shapes intentionally changes the collision-node tree. Its rerun is pending.
BiomeChunkFx.warm now creates the shared mist material behind the loading screen.
The repeated five-minute gameplay run is active at /tmp/oct9-shared-feel-retire.log
(tool session 78811); nearby integration is restored to 6 ms, distant 2 ms.

That run has now exited. Startup 116.2 s; no frozen frames. Run/run-turn process
p95 16.64/8.87 ms, max 55.14/36.77; dt p95 27.47/32.42, max 91.59/141.51 ms.
Grass pending p95 32/40, max 38/41, draining at rest. This recovers much of the
rejected budget trial's grass backlog but does not beat the earlier 24/28 p95.
There was no 473–878 ms moving frame in this run. Retirement itself reached
6.1 ms in a loaded gameplay frame despite the 1 ms soft budget (individual
resource destruction cannot be interrupted); eviction/detachment still reached
31 ms. The 577 ms first idle frame includes the harness's last PNG save and
must not be treated as a gameplay hitch.

Memory still reached 8.0 GB. An 80.9 s system-wide vm_stat interval recorded
35,500 swap-out pages (~555 MiB at 16 KiB/page), 7,668 swap-in pages and heavy
compression/decompression. This limits timing attribution and is not a claim
that the game caused all system pressure. Reducing retained game memory and
investigating remaining eviction work are still necessary.

Exit exposed a separate pre-existing lifetime hole: an in-progress commit's
unattached terrain/effects roots had no scene-tree owner, and _exit_tree did
not abandon them. Shutdown now abandons that integration, retiring both roots
before clearing the queue. A focused test passes (1 / 3). Interrupted commits
also use staged destruction during gameplay. The previous profiling run's
60-resource/RID leak warnings preceded this fix; a full shutdown rerun remains.

The real-chunk skirt equivalence rerun passes (1 test / 4 assertions), preserving
rendered mesh signature and every collision face in order with four-skirt steps.

### Photograph 9 vegetation follow-up

Fresh nine-chunk shared-profile scene found the exact photographed birch bush
at (-222.0464, 62.416, 1328.914), within 0.25 mm of the earlier placement.
With grass hidden, both birch stems are visibly above the terrain. It is the
Meadow birch bush 03, not a buried Farmlands sapling. Reversible root-clearance
trials from 0.5 to 2.5 m barely improved stem readability from this uphill view:
foreground grass still occludes it. No lifting or persistent grass collar was
adopted. Saved baseline, narrow/wide collar trials and grass-hidden diagnostic.
The loaded mesh-path audit found no farm_sapling instances, so it does not
establish placement correctness for that separate asset family. The review
scene remains live at /tmp/oct9-bush-collar-review (session 7392), useful for
terrain/vegetation follow-up; all performance and GUT sessions above exited.

The vegetation review has now exited normally too (7392, exit 0), with no
resource/RID leak warnings at shutdown. This fully committed scene complements
the focused interrupted-commit lifetime test; no review or profiling game is
left running. The initial collar probe had a typed-Array assignment error,
fixed before the successful captures; no production script error occurred.

### Shared-profile consumer and second-seed checks

F9's GPU kernel was missing the shared-profile branch. Both GPU profile helpers
now use the same smootherstep in mode 3. The expanded GPU comparison passes
E1/E2/E3/shared across two seeds: 32,768 sample points (1 test / 16 assertions).
E3 remains the default pending the broader transition review.

The new production-margin water survey covers four chunks on each of seeds
2697992464 and 99. Four sites were dry and supply no continuity evidence.
The four wet sites contain 594 centreline samples: no missing or sub-EPS
water, minimum measured depth 0.171 m. The accompanying coarse original-ground
comparison is diagnostic only, not a universal containment proof.

A fresh nine-chunk seed-99 scene completed startup in 138.706 s. Against live
physics terrain, 1,350 river samples had no dry, internally dry or buried
water. The channel capture reads as contained; the descent capture still
has a conspicuous angular line. All 12 shared chunk boundaries agree at
0.5 m samples (883 wet comparisons; no wetness or height disagreement).
The line survives hiding water, and normal/unshaded diagnostics were saved;
its appearance is not fixed and should not be attributed to mismatched water
solves. It lies inside chunk (1,6), around x330–359 / z1200–1225.

The profiling harness now resets its interval after optional PNG captures
and suppresses spike logging for that uninitialized interval. This prevents
the previously identified 577 ms screenshot-encoding interval from appearing
as the first gameplay sample; it is not a production performance improvement.

The seed-99 review exited normally (session 31476, exit 0), with no shutdown
resource/RID warnings. No review or profiling game remains running.

### Shared-profile rollout and collision lifetime

SHARED_PROFILE is now the default terrain reconstruction. This supersedes the
opt-in status above. The F9 and native ports already cover this mode. The
6,561-case property harness was corrected to compare ordinary slopes against
explicit E3 (instead of the current global default); bounds, shared edges,
ordinary-slope difference and monotonicity all remain exactly zero. Road and
town-grade consumers pass 18 tests / 9,774 assertions.

The frozen water consumer suite was run in both modes before adapting fixtures.
E3: 33 passing, 5 failing, 3 pending. Shared: 31 passing, 7 failing, 3 pending.
Three extra shared failures are vertical-wall preconditions (straight wall,
inner corner, wall-rim location); the unbounded false-dry-shore test instead
improves from failure under E3 to passing under shared. The same 38.5-degree
pond contour and river-frame continuity failures occur in both modes. These
remain open; the suite is not green. The three historical wall tests now
explicitly select E3, with mode-separated test caches and saved/restored mode;
all three pass unchanged assertions (2 + 2 + 7). The original attempt to use
a comma-separated GUT name filter ran nothing; individual reruns supplied the
actual evidence. Step-ground cliff fixtures likewise need the E3 envelope;
shared tests use continuous production-style profiles.

A matching E3 render of seed 99's descent shows the same exposed ridge
intersecting the water. This is not newly introduced by the shared transition.
Its appearance remains a water/terrain art follow-up, not proof of a chunk seam.
The E3 review exited normally with no shutdown warnings (32929, exit 0).

EnvironmentCollisionBuilder formerly allocated a StaticBody before returning
its step list. Abandoning the list before its first step leaked that unparented
Node. Creation now occurs in the first step, with immediate parent ownership.
Two tests / 75 assertions verify no Node allocation on unstarted cancellation
and all 70 completed shapes in order, plus parent-owned destruction.

Native tile/envelope/solid tests under the new default pass: 16 tests /
1,684 assertions, including forced-fault fallback. All 49 cliff/cache tests
pass across the final split runs. The first rerun caught mixed indentation
in the new foot-line test hook and an outdated reference dictionary missing
`sample_offset: 0.0`; both were repaired, and the affected eight tests pass
(386 assertions). No geometric assertion was relaxed. The original failed
run is retained to distinguish those repairs from a first-pass green suite.
All process handles from this rollout are terminal; no game remains running.

### Grass backlog classified during travel

A fresh .NET 1080p, no-vsync run uses the default shared profile, five 45 s
phases, and no PNG capture. The harness now classifies missing grass every
tenth frame using the same desired-ring scan: missing terrain, missing sampler,
unrequested, requested worker work, or completed work awaiting upload.

No frozen frames. Run process p95/max 14.58/73.31 ms, frame p95/max 25.23/95.60
ms; run-turn process 10.71/42.07 ms, frame 26.18/70.55 ms. These are observations
from one run, not an isolated A/B speedup. Run missing-ground backlog mean/p95/max
2.45/12/17; requested grass 1.35/5/13; uploads 0/0/1. Run-turn missing ground
2.55/17/18; requested grass 0.21/1/11; uploads always zero. All backlog classes
are zero during initial idle, turn and final idle. Thus the dominant remaining
visible lag in this route is terrain availability, not grass upload throughput.
The corrected harness has no screenshot-time contamination.

Static memory peaks at 7,077.9 MiB in final idle as distant terrain completes;
texture memory is 2,601.3 MiB, reported video memory 3,385.5 MiB. These counters
are different accounting views and must not be added as independent allocations.
The game exits normally (98678, exit 0); no game remains live.

A small redundant allocation was removed from detached grass samplers: when
grass and water use the identical canonical region, both now share one private
copy. Different graded/natural regions remain distinct. A focused test passes
1 / 6 and verifies canonical data cannot be mutated through the copy. This
change was made after the profiling process loaded its scripts, so the run
is a baseline for it; no measured whole-game memory saving is claimed.

### Grass ring terrain priority and texture inventory

The nearby-ground tier previously ended at 96 m even though grass draws to
140 m. It now uses the greater of the collision look-ahead and enabled grass
radius; forward travel stays tier 1 and lateral grass ground tier 2. The new
regression passes 1 / 4; existing travel/dependency priority tests pass 9 / 46.

Same five 45-second phase setup as runtime-backlog: run grass pending mean
4.00 -> 2.96, p95 14 -> 12; run-turn mean 2.77 -> 1.45, p95 17 -> 15. Run
missing-ground mean 2.45 -> 1.70; run-turn 2.55 -> 1.29. No frozen frames,
and final grass backlog is zero. Run process p95 14.58 -> 14.90 ms and frame
p95 25.23 -> 25.54; run-turn process 10.71 -> 11.78 and frame 26.18 -> 31.24.
Final static-memory peak 7,077.9 -> 7,556.4 MiB as more terrain finishes.
This is a single sequential comparison with asynchronous generation and
background-load confounders: improved grass readiness, not an overall frame
performance win. The priority rule is retained for its correct visible-ring
scope; remaining memory/frame costs are open. Process 21862 exited normally.

An offline inventory of all 424 baked environment textures (including unused
assets) finds 2,006,620,420 decoded image bytes. This is not live VRAM. Suntail
village textures account for 1,019.3 MiB; Angry Mesh Meadow 213.3 MiB. The
photographed birch leaf atlas 6c85fe13d4cf50759f02 is 1024x1024 RGBA8 with no
mipmaps, although painted_leaf requests mipmapped filtering. 36 of 140 Meadow
textures lack mipmaps. A reversible runtime mipmap trial is now running in
/tmp/oct9-leaf-mipmap-review (session 61423); no texture assets have changed.

### October 9: missing leaf mipmaps repaired

The reversible trial visibly reduced dense pinprick noise in the middle-distance crowns. The saved textures reproduce the improvement (`leaf-mipmap-before.png`, `leaf-mipmap-trial.png`, `leaf-mipmap-saved.png`). All three unique painted-leaf albedo textures lacked mipmaps: two Meadow textures and one Farmlands texture, shared by many materials. The narrow `repair_leaf_mipmaps.gd -- --apply` migration adds lossless mip chains in place, verifies the complete serialized chain byte-for-byte after reload, then strips the reloaded mipmaps and verifies that the original base pixels are unchanged. No meshes, materials, descriptors, or catalogue references changed. An initial scan was stopped after the two Meadow repairs because it was unnecessarily loading unrelated materials; the narrowed scan completed the remaining Farmlands repair.

The normal bake now regenerates mipmaps after resizing and palette edits. `test_leaf_mipmaps` checks the actual catalogue: 1 test, 7 assertions passed. The live review reloaded the saved resources before its final capture. This addresses another concrete source of foliage noise alongside the earlier crossfade-pattern change. This is a visual/filtering fix, not a memory reduction: mipmaps increase storage. Ordinary-texture GPU compression remains an untested option for the outstanding runtime memory investigation.

### October 9: identical environment texture sharing

A reversible BC7 foliage trial preserved appearance in the reviewed view and reduced the three leaf textures from 16,777,212 to 4,194,384 image bytes. It is **not adopted**: its ~12 MiB saving is small beside the larger loaded-scene duplication, and broader material compression still needs review.

The live cache inventory exposed repeated village atlases. An offline comparison verified dimensions, format, mip presence, and the complete image byte sequence; 23 duplicate paths across the baked catalogue could save 430,615,188 image bytes if all were loaded. `terrain/environment/texture_aliases.json` records only these proven equal aliases. `EnvironmentTextureSharing` replaces material texture references on the main thread before crossfade copies are made. It preserves authored asset files and individual pack references. Source textures are retained only through bulk load batches / the startup feature warm, then released, preventing repeated decodes while loading neighbouring visuals.

In the existing live review, the reachable environment texture count fell 300 → 280 and image bytes 1,422,647,876 → 1,042,364,332 (362.67 MiB). Godot's texture-memory counter fell 2,629,011,712 → 1,879,345,408 (714.94 MiB); these two accounting views must not be added. This review process also contained earlier reloaded leaf textures, so a fresh process is the next measurement. The scene capture remains visually consistent; alias byte equality is the stronger appearance invariant. A fresh 45-second-per-phase profile is running at `/tmp/oct9-runtime-texture-sharing.json` (session 61707); no runtime-speed claim yet.

Texture-sharing checks: **3 tests / 100 assertions**, including every alias mip byte, both standard and shader material resource identity, idempotence, and source-texture release after a batch. The fresh run has completed feature warming in 9,701 ms versus preceding runs 8,801 / 8,762 ms; this is a small startup cost in these non-alternating samples, not yet a completed runtime comparison.

### Fresh texture-sharing runtime result

The 225-second five-phase runtime profile completed and exited normally (session 61707). Startup 110.9 s versus 111.2 s in the preceding grass-priority run. End texture memory 2601.28 → 1858.34 MiB (742.94 MiB lower); video memory 3464.20 → 3126.64 MiB. Static-memory peak during final idle 7556.41 → 7394.63 MiB. These counters overlap and must not be summed.

Run frame p95 25.54 → 25.65 ms, process p95 14.90 → 14.83 ms; run-turn frame p95 31.24 → 29.91 ms, process p95 11.78 → 9.48 ms. Run-turn frame maximum remains 100.24 ms (previous 108.74). No movement freeze in either run. Mean/max grass backlog: run 2.96/16 → 2.04/10; run-turn 1.45/18 → 0.03/2. These sequential runs have asynchronous terrain completion and machine-load differences, so they establish the memory saving, not a controlled speedup or complete late-play solution.

Many remaining long frames have short measured process/physics times. The harness now samples cumulative .NET GC pause time each frame and managed heap/full-collection counts every tenth frame, without forcing collections. This is diagnostic only; production code does not instantiate the probe. A longer run will test whether managed pauses correlate with the unexplained stalls.

The diagnostic build succeeds (only the existing offline NU1900 warning). Probe smoke check passes: 10,000 pause-counter calls take 1,921 µs (~0.19 µs/call), with nonnegative monotone pause/full-collection counters and a nonzero heap. A 120-second-per-phase (ten-minute gameplay) run is now active: session **6520**, `/tmp/oct9-runtime-gc-long.log`, report `/tmp/oct9-runtime-gc-long.json`. Reuse this running handle; the preceding 61707 profile has exited.

### Continuous-transition normals

Inspection found two legacy vertical-wall decisions still active in `TerrainChunkMesher.field_normals`: discarding a steep half-derivative, and rejecting a neighbouring owner's sample by comparing clamped samples away from the exact ownership border. Neither applies to the shared profile's continuous ground. The shared mode now keeps both samples across steep slopes and owner boundaries; E1/E2/E3 retain their lip handling.

A synthetic 40 m rise sampled at 119 positions reproduced normal-vector error 0.06178175 versus the actual surface's central derivative. Disabling the steepness heuristic alone left 0.00043654 error near an ownership boundary; disabling the inapplicable border rejection too yields **exactly zero** error at all 119 positions. The original strict 0.0001 tolerance is retained. This corrects a demonstrated lighting defect but is not yet proof that the remaining seed-99 angular riverbed feature is fixed: a fresh rendered comparison is pending after the sustained profile. No vertex heights or physics geometry change. The running profile (6520) loaded the prior normal code before this edit and should be allowed to finish.

The historical E2 wall-lip regression also passes after both changes: 1 test / 3 assertions.

### Ten-minute runtime diagnosis

Session 6520 completed all five 120-second phases and exited normally. It recorded **no movement freezes**, but sustained performance is not solved. Resident chunks rose 9 → 20 during idle, 20 → 30 during turn, 30 → 28 during travel (eviction works), 28 → 49 during run-turn, and 49 → 61 during final idle. Final-idle measured static memory peaks **12,356.7 MiB**, with 53,585 nodes; the top-level report's lower post-run memory value is not the peak. Managed heap at phase ends is only 122–166 MiB. Frame p95 rises from idle 21.4 ms to run 32.36, run-turn 39.95 and final-idle 53.99 ms.

There are 337 frames over 50 ms: 314 have no recorded GC pause and only four have a GC pause over 10 ms. GC can cause individual stalls (largest pause 70.361 ms, matching a 98.853 ms frame), but does not explain most late-play degradation. The next investigation should attribute per-chunk resident memory and draw/physics cost rather than optimize GC in isolation. Grass backlog during run is mean 11.1 / p95 39 / max 45, then zero throughout run-turn and final idle; the longer straight run still outruns grass-ready terrain even without freezing. Texture memory remains 1858.33 MiB, confirming the atlas-sharing saving survives sustained play.

The normal comparison now runs separately after profiling: session **98901**, `/tmp/oct9-normal-scene-review.log`, output `/tmp/oct9-normal-scene-review`, seed 99 at (318,65,1228). Its queued `october9_normal_scene_compare.gd` probe reproduces the old normal sampler in a temporary script and swaps only normal arrays, captures legacy/current, then restores production meshes. It must finish and be visually inspected before claiming the riverbed edge is fixed.

### Matched real-scene normal result and resident geometry inventory

The seed-99 review's normal-only comparison completed. Across the framed terrain it changes 24 vertices, maximum normal-vector difference 0.00011691 at (254,79.64507,1266). The prominent riverbed edge remains visually unchanged (`riverbed-normal-legacy.png`, `riverbed-normal-current.png`). The synthetic steep-transition normal defect was real, but **was not the cause of this feature**. Ground rays along the visible edge hit the terrain Body (and a rock skirt at its far end), not an unexpected water collider. There are no terrain grades in these samples. The terrain kernel closely matches the collision surface (largest sampled difference ~0.118 m); two rightmost points are dry ground. This is a ground ridge/shore feature, not a disagreement between chunk water solves.

The nine-chunk resident geometry inventory is saved in `chunk-memory-seed99.json`: it counts unique mesh-array payloads and concave shape input faces separately. These are lower bounds, excluding backend BVHs, allocation overhead, textures and plan/cache dictionaries; do not equate them to engine resident memory. An additional diagnostic releases collision shapes in the eight surrounding review chunks while retaining target chunk (1,6), to measure actual shape-memory cost without changing the photographed geometry. This only affects the disposable review scene.

Collision release result: removing 5,411 CollisionShape3D nodes from the eight non-target chunks lowers measured static memory **3,992,061,844 → 3,018,523,080 bytes**, a **973,538,764-byte / 928.44 MiB** reduction. The nine chunks originally had 6,062 shapes and 3,562,048 concave triangles; their unique input face bytes total only 128,233,728, much smaller than the engine's actual shape cost. Mesh input arrays total 230,033,588 bytes. This strongly supports detailed terrain collision residency as the next memory target. Candidate: retain exact collision near all active physics actors, archive/delay distant concave shapes, and restore in bounded steps before entry; do not simplify visual terrain or leave actors without support. No production collision residency change yet.

Live review session **98901** remains available with target chunk (1,6) physics intact; the surrounding eight chunks intentionally have no collision following this diagnostic. Do not use it for general traversal validation or assume all its physics is intact.

### Exact collision archive prototype

`TerrainCollisionArchive` suspends generated concave shapes into Zstd-compressed, lossless Variant face buffers. It retains only weak node references; the original shape is released. Restoration recreates the same faces, margin and backface flag on the existing node, preserving its transform, disabled state, layers (on its body), and metadata. Imported resource-path shapes are excluded because the catalogue retains them anyway. It is **not wired into production residency yet**.

Unit tests: 2 tests / 17 assertions, covering exact geometry/flags, release of the original shape, no duplicate suspension, and removal of archived nodes without keeping them alive. Live target chunk (1,6): 357 shapes, 12,791,928 raw serialized bytes → 3,050,573 compressed bytes. Measured memory falls 3,015,598,948 → 2,915,967,932 bytes (**95.02 MiB released**, archive included). Maximum one-shape suspension 4,388 µs, restoration 2,322 µs. All restored face hashes match, and 64 vertical rays return exactly the same hit position/normal. Target physics was fully restored; the surrounding eight chunks still have no collision from the preceding diagnostic.

Next: an actor-aware residency coordinator with hysteresis/prefetch, bounded restoration, and arrival support checks, then sustained travel and teleport tests. The archive alone is not a complete runtime fix. Live review session remains 98901.

### Collision residency coordinator

Added `TerrainCollisionResidency` over the exact archive. It accepts all actor/predicted positions, restores within 256 m of a chunk, suspends beyond 384 m, and retains state in between to avoid churn. Restoration is nearest-first and precedes suspension; each drain has a time/step budget. An empty actor inventory restores rather than disabling the world. Readiness requires no archived shapes and at least the next physics frame. Chunk retirement removes the entry and returns its plain archive ownership for deferred release; weak references do not keep retired nodes alive.

Four tests / 23 assertions pass: multiple interests, partial restoration, physics-registration delay, hysteresis, empty interests, retirement, and reversal during partial suspension. This coordinator is still **not wired into gameplay**. Integration must enumerate every CharacterBody3D / RigidBody3D actor, safely hold newly arrived or teleported actors until readiness, register completed chunks, unregister retired chunks, and then demonstrate sustained travel memory/frame behavior. No production collision has been disabled by this change.

### Opt-in streamer integration and actor arrival guard

`FieldTerrainStreamer.COLLISION_RESIDENCY` remains false by default; `frame_feel_profile --collision-residency` enables the experiment. Completed chunks register with the coordinator; retired chunks unregister and their compressed archives go through the existing off-main drop box. Main-thread suspension/restoration gets a 1 ms soft budget, with `collision_residency` as a slow-frame section. Frame samples include archived chunk/shape counts and compressed bytes.

`TerrainCollisionActors` tracks existing and newly added CharacterBody3D / RigidBody3D nodes through scene-tree signals. Interest points include each actor's position and velocity prediction (30 s, clamped to 192 m). A physics-priority guard holds unready non-player actors by preserving/restoring process mode and rigid-body freeze state. Player support uses the streamer's existing hold/release path, now gated on collision readiness at four points 12 m around the actor. The physics guard runs before normal actor movement, and restored shapes must pass the next physics frame before release. Startup/shutdown disconnect tracking and restore held actor state.

Actor tests: 2 tests / 12 assertions. Real physics teleport test: 1 test / 7 assertions; a character teleported above archived ground remains held through restoration/registration, then collides with the exact restored StaticBody3D. Existing streamer priority check passes 1 / 4. Coordinator checks remain 4 / 23.

The matched 120-second-per-phase profile is now live: **session 27824**, `/tmp/oct9-runtime-collision-residency.log`, output `/tmp/oct9-runtime-collision-residency.json`. Do not restart while it runs. Review session 98901 has exited normally; no review scene remains live. Default enablement awaits sustained traversal/memory/frame results.

### Collision shape property preservation

The archive now preserves custom solver bias, resource name and local-to-scene state in addition to faces, margin and backface collision. Scripted shapes are excluded, since restoring a plain shape would discard custom behavior. Unit checks pass **3 tests / 24 assertions** (`/tmp/oct9-collision-archive-properties-final.log`). The initial scripted-shape assertion exposed GUT's object formatter requiring a resource-file-backed script; using a boolean identity check avoids that test-only error.

The running residency profile loaded the earlier archive implementation, before these additional property copies; generated terrain shapes use their default solver bias. Do not describe the profile as a test of the later property-preservation revision.

### Ten-minute collision residency result — remains opt-in

Session 27824 exited normally. Peak engine static memory fell **12,356.70 → 9,748.10 MiB** (2,608.60 MiB / 21.1%) against the preceding ten-minute run, despite ending with 62 rather than 61 chunks. At the end, 41 chunks / 11,305 shapes were archived into 101,354,802 bytes. Texture memory remained ~1,858 MiB. Run / run-turn / final-idle frame p95: 32.36 / 39.95 / 53.99 → 31.79 / 38.51 / 52.34 ms; corresponding process p95: 15.56 / 15.52 / 12.68 → 16.35 / 15.84 / 13.97 ms. These sequential runs do not establish a frame-time improvement.

**Regression:** 170 consecutive run frames were held, totaling 2,710.06 ms; the baseline had no holds. The archived-shape count did not change across that hold, and release coincided with a new chunk attaching. This suggests the 12 m neighboring-chunk readiness guard waited for unbuilt ground rather than collision restoration, but the first profile did not record the exact blocked chunks. A hold-only diagnostic now records position, missing registrations, pending archive counts, physics-registration frame and current-chunk feature readiness. Do not weaken the safety guard without that evidence. One logged residency section also took 14.5 ms, above the 1 ms soft budget; individual shape work remains indivisible.

Grass run backlog mean/max was 11.91 / 40 (baseline 11.10 / 45), with zero backlog in run-turn and final idle. The experiment is **still disabled by default** pending hold diagnosis and follow-up validation. Reports and raw frames are saved as `runtime-collision-residency.*`.

Follow-up diagnostic run is live as **session 72579**, `/tmp/oct9-runtime-collision-holds.log`, report `/tmp/oct9-runtime-collision-holds.json`, same 120 s phases, 1080p/no-vsync and opt-in residency. It includes the shape-property preservation revision and hold-only details. Startup has begun without parse errors. Do not restart while this process is live. Session 27824 has exited 0. No other Godot review process is intentionally live.

### Collision hold diagnosed; repeated warm views bounded

Diagnostic session 72579 exited 0. It reproduced 244 held frames / **4,033.908 ms** at (-194.4205,62.52074,-756.0471), current chunk (-2,-4). Current ground and features were ready throughout. All 243 blocked samples identify only **unbuilt diagonal chunk (-1,-5)**; none had pending archived shapes. The 12 m corner guard imposed an unrelated neighbor dependency. The player now uses a 1 m margin (capsule radius 0.398 m plus maximum 0.167 m / 60 Hz movement step fits inside it); current chunk readiness is explicit. Other actors retain the conservative 12 m margin. Actual unloaded edge crossings and arrivals still hold. Focused regression uses the recorded position and tests both edge and unbuilt arrival.

A separate late-frame contributor is FirstViewWarmer: it rerendered unseen headings every 500 ms indefinitely at a stationary pose. In the first residency run's final idle, 249 frames with a changed warm count had dt median/p95 **55.88 / 95.52 ms**, versus **32.18 / 40.70 ms** for 3,189 other frames. Adjacent-frame offsets do not show that same association. This is strong correlation, not an isolated causal timing claim. The warmer now completes three headings, then stops until the camera moves 8 m or new geometry is queued. Movement retains the 500 ms interval and cycling directions; new chunk views are unchanged. Unit tests pass **2 / 15 assertions** for stationary completion, invalidation and interval caps. Full traversal/turning validation is next; the completed diagnostic loaded the old unbounded warmer and old 12 m player guard.

Recorded-position guard regression passes 1 test / 3 assertions (`/tmp/oct9-collision-player-margin-test.log`). Combined validation is live as **session 70088**, `/tmp/oct9-runtime-bounded-warm.log`, `/tmp/oct9-runtime-bounded-warm.json`, five 120 s phases, 1080p/no-vsync, residency opt-in. Do not restart a live run. No default residency enablement yet.

### Prepared combined visual acceptance views

`october9_final_site_views.gd` retains the reported XZ anchors but obtains camera/target heights from actual physics ground, excluding dressing bodies. It records collider paths and camera poses and rejects unloaded ray hits. This avoids treating a camera inside the changed terrain as a visual defect. Three water views and three land/foliage/battle views are selected according to the loaded site's side of the origin; full grass is populated at each anchor. Parse-only validation passed (`/tmp/oct9-final-site-views-parse.log`). **Not rendered yet**: wait for session 70088 to finish before launching another GPU scene, then review both site groups. Preparing this probe is not visual acceptance.

### Combined ten-minute runtime validation

Session 70088 exited 0, startup **110.7 s**, no script errors. The corrected player guard produces **zero held frames in every phase**, versus 170 and 244 in the two prior archive runs. Collision residency still restores before entry; its teleport/registration tests remain applicable. Peak static memory is **9,041.62 MiB**. Final-idle frame p95 is **38.95 ms**, versus 52.34 ms in the first residency run and 53.99 ms in the pre-residency ten-minute run. First-view renders in final idle fall **249 → 46**; newly arriving geometry still triggers them. These runs are sequential and their streamed chunk schedules differ, so do not attribute the whole timing change to one edit.

Current phase frame p95: idle20.48, turn27.28, run30.85, run-turn40.71, final-idle38.95 ms. Process p95:4.53 /5.61 /14.86 /16.34 /12.00 ms. Grass backlog run mean11.25 /max41, zero in the other phases. The warmer preserves its moving behavior (run213 /run-turn258 extra views) while reducing stationary work (initial idle54 /final idle46). Late worst frames still occur; no claim of complete runtime acceptance. The archive remains opt-in pending a final safety/rollout review.

### Collision residency rollout

Enabled `FieldTerrainStreamer.COLLISION_RESIDENCY` by default after the exact archive, actor, teleport and sustained traversal evidence. Re-ran archive3/24, coordinator4/23, actors2/12, physics teleport1/7: **10 tests /66 assertions**, all passed. `frame_feel_profile --full-collision` provides the baseline for future comparisons. The 1 ms drain remains a soft budget; individual physics-shape operations occasionally exceed it. This change does not claim to eliminate every long frame. The fresh water review was launched before this default flip and is solely a visual review, not another residency test.

Fresh water visual session **30177** is live (`/tmp/oct9-final-water-review.log`, output `/tmp/oct9-final-water-review`), with the ground-relative acceptance probe queued. Session70088 has exited normally. Do not launch a second GPU review concurrently.

### Original-site captures and current-channel selection

Session30177 completed the ground-relative views after 151.95 s startup. The three original positive-X water locations are now dry in the changed geography; the pictures are saved under `final-original-sites/` with exact poses. **These are not water acceptance evidence.** The nine-chunk physics river audit still finds 420 samples, zero dry/internal-dry/buried, but no wet trace point survives the camera selector's 80 m interior margin. Current channels lie near the loaded scene boundary, so widening the claim based on those captures would be wrong. The scene exited 0.

A new combined review centered at (-100,100,1200) includes the known current wet reach near (-44,1143), the reported negative-X foliage/transition locations, and interior space for meaningful channel cameras. It uses the now-default collision residency; near review actors retain exact collision. The ground-relative land probe is queued; run `october9_water_world_check.gd` afterward to select actual wet channels. Do not treat the queued probe as completed evidence.

Combined visual review is live as **session76296**, log `/tmp/oct9-final-combined-review.log`, output `/tmp/oct9-final-combined-review`. All earlier runtime/review sessions have exited; do not launch a competing GPU scene. Remaining next steps: inspect iteration40 land captures, queue current-channel selector, inspect its wet views, then decide whether further bank/readability changes are needed.


## Final combined-site inspection: water mesh clearance (October 9)

Fresh owner-seed nine-chunk scene centered at (-100,100,1200), with the current
production defaults and full grass/dressing. The original positive-X water
photo anchors are now dry after the geography changes; those dry captures do
not validate water. Selected current, interior river reaches instead:
`final-combined-sites/river_drop.png` and `river_shallow.png`. The selected drop
falls 9.64 m over 8 m; the shallow reach has 0.587 m analytic depth. The main
river is continuous and contained in these views, but small water fragments
remain on a side bank. Hiding water in the identical view confirms that the
fragments are water, not exposed rock.

The visible-river analytic-level/physics-ground audit in this scene covered
596 samples with no dry or buried centerline sample. That is insufficient:
a new probe copies the **actual WaterSheet mesh** into a temporary physics
layer and compares it against real ground collision. The 24×21 m side-bank
patch has 1,004 samples at 0.5 m spacing with analytic depth above 0.15 m.
Nine have mesh clearance below 0.02 m; the worst mesh is **0.304 m below
physical ground**, despite positive analytic depth. Failures lie in shoreline
strip/rim triangles interpolating across the narrow descending wet band.
The analytic side branch itself is connected downstream, so this is not
proof that disconnected hydraulic islands caused the fragments.

Probe correction: the `water_surface` group contains Node3D roots with a
`WaterSheet` MeshInstance3D child. An initial probe incorrectly expected the
root itself to be a mesh, found zero meshes, and reported 1,004 misses. That
result is invalid and discarded. The corrected baseline found two meshes.

### Isolated mesh-resolution trials (not adopted in production)

The trials reuse the live scene's canonical context/ground but build only the
24×21 m patch. All temporary nodes are freed and original group membership
restored. No gameplay water, shader, solver, or terrain changed.

| Trial | Clearance failures / 1,004 | Mesh vertices / triangles |
|---|---:|---:|
| Actual production baseline | 9 (minimum −0.304 m) | Full chunk meshes |
| 0.5 m contour presence/spacing and surface lattice | 0 (minimum 0.091 m) | 2,676 / 5,080 |
| Fine contour, original 2 m surface | 2 (minimum +0.0167 m) | 998 / 1,846 |
| Original contour, 0.5 m surface | 1 missing at the artificial patch boundary | 1,996 / 3,742 |
| Original contour presence, 0.5 m spacing and surface | 0 (minimum 0.129 m) | 2,493 / 4,765 |
| 1 m presence/surface and 0.75 m contour spacing | 7 missing | 977 / 1,802 |
| Refine visible surface faces **after** hole closure; original contour/lattice | 0 (minimum 0.144 m) | 2,459 / 4,678 |
| Same post-refinement plus 0.5 m contour spacing | 0 (minimum 0.129 m) | 5,405 / 10,613 |

Refining strip faces before `_seal_local_surface_holes` leaves gaps: added
boundary vertices can exceed the hole closer's bounded loop size. Changing
the shared STRIP_EDGE_MAX also changes topology acceptance, so it is not a
safe isolated resolution knob. Post-closure refinement is the promising
candidate. It still needs conforming shared edges/chunk-boundary validation,
a bounded adaptive criterion, actual shader captures, and build/render cost
measurement. These numeric patch trials are **not** a production water fix
or final visual acceptance. Trial times include building geometry and the
physics audit; they are not pure meshing benchmarks.

Evidence: `final-combined-sites/water-mesh-clearance-*.json`, including exact
failed triangles, and harnesses `october9_water_mesh_clearance.gd` /
`october9_water_resolution_trial.gd`. The latter currently reproduces the two
post-refinement trials. The original baseline JSON is preserved separately.

### Short woody roots and final photographs

The corrected unique-visible-instance audit skips LeafShadow duplicates:
**21 birch bushes and one Farmlands sapling**, no missing ground rays.
The photographed birch bush at (-222.0464,62.416,1328.914) is 3.50 m tall,
with its root 0.0779 m below ground. The actual sapling at
(30.6371,49.6048,1419.305) has its root 0.0255 m below ground.
No lift/collar change was made. This confirms the photographed short-stem
bush diagnosis; legibility amid tall grass is a separate unresolved design
issue. `short-woody-roots.json` records every unique instance.

`bush_original_direction.png` restores the original screenshot orientation
and shows the bush and nearby foliage with the current mipmaps.
`transition_original_direction.png` is limited to a nearby slope;
`battle_overview.png` shows local forms but includes the loaded-world border.
Neither substitutes for the remaining representative ground-level battle
and transition acceptance views.


## Retained adaptive water-surface refinement (October 9)

`WaterSkin.build` now refines the completed surface **after** local hole
closure, before normals and shader payloads are baked. New helper
`WaterSurfaceRefinement.gd` compares edge midpoints and triangle centroids
against the authoritative field. Faces more than 8 cm below it split their
edges, to a 0.5 m minimum edge threshold and at most four rounds. Every
incident face receives each shared split, including adjacent rim faces;
buried faces do not independently rise to the water field. New normals
interpolate the existing smooth normals, avoiding redundant derivative
queries. Per-build field/eligibility memos are local to this worker.

Chunk-border subdivision depends only on the border edge's own midpoint
error, independently of the interior on either side. Freezing the old border
chord was rejected: it avoids cracks but can leave the border below ground.
The implemented rule allows both neighbours to refine to the same curve.

Two actual full chunk meshes, (-1,5) and (-1,6), were rebuilt in the loaded
owner-seed scene using the production build path and existing material.

- Local original side-bank probe: **0 / 1,004** clearance failures, minimum
  clearance 0.0295 m (baseline 9 failures, worst −0.304 m).
- Broader 1 m scan across both chunks: **0 / 5,910** confidently wet ground
  samples with mesh depth below 0.02 m; minimum 0.1085 m. The coarse broad
  grid complements, rather than replaces, the 0.5 m local grid.
- Actual shared mesh boundary at z=1152: **470 probes, zero mismatches**,
  maximum opposite-edge distance 0.00000763 m. Baseline: 440 probes, zero
  mismatches. Both sides now have 47 boundary edges (previously 44).
- Four focused regression tests / nine assertions pass: planar geometry
  unchanged, curved surface clearance plus interior edge closure, independent
  neighbours sharing a curved border, and buried rim preservation.
- Existing `test_water_skin::test_free_edges_only_buried_rim_or_border`:
  **310 non-border free edges, zero offenders**, three assertions pass.

Matched shader captures are in `final-combined-sites/river_shallow_refined.png`
and `river_drop_refined.png`. The formerly fragmented side stream is visibly
continuous, while the main waterfall remains continuous. This fixes the
surface tessellation defect. The side stream's hydraulic placement remains
a separate containment/design question, not automatically accepted because
its mesh is now continuous.

Cost: the two full chunks grow from 3,495 / 3,058 triangles to 6,426 / 6,425.
Whole water builds measured 4.64 / 5.06 seconds in the diagnostic scene;
refinement-only trials before the final border rule measured 1.28 / 1.53
seconds after removing redundant normal field queries. These are worker
costs in production, **not** additional main-thread frame time; their impact
on streaming/grass availability still needs final traversal measurement.
No fine-rescue, river solver, native kernel, or terrain field changed here.

The patch-only edge audit initially flagged altered boundary chords after
border refinement. Those are expected curve changes, not internal holes;
the independent two-chunk seam test above verifies agreement. Earlier
24×21 m trial bounds also extended the rounded 2 m lattice to z=1156;
the production-sized chunk is aligned, and later patch trials use 24×24 m.
The obsolete experimental helper was removed; diagnostics now exercise the
production refiner directly.


## Combined refinement traversal: a real hold, attribution still open (October 9)

Completed windowed .NET run, session 78475 exited 0: five 120 s phases,
1920×1080, no vsync, owner seed, production defaults including refinement.
Startup 120.7 s. The optional grass LOD capture ran before measurement;
`runtime-refined-water-startup-grass.png` shows full visible grass coverage.

| Phase | Frame p95 ms | Process p95 ms | Grass pending mean / max | Held frames |
|---|---:|---:|---:|---:|
| idle | 20.36 | 4.37 | 0 / 0 | 0 |
| turn | 26.22 | 5.13 | 0 / 0 | 0 |
| run | 26.80 | 13.28 | 16.65 / 49 | 562 |
| run_turn | 37.38 | 15.97 | 0 / 0 | 0 |
| idle_end | 43.35 | 13.71 | 0 / 0 | 0 |

The 562 held frames total **6.926 s**, all at
(-191.0287,95.94024,-635.894), center chunk (-1,-4). The center was built
with ready features; the next required chunk (-2,-4) was unbuilt and not
registered. This is a real missing-ground crossing, not an archived-shape
restore delay or the previous unnecessary 12 m diagonal guard. At first
hold, all 49 pending grass tiles waited for ground, with zero active/queued
workers. Extra grass workers would not fix that cause.

Peak static memory 9,046.5 MiB; final 62 chunks, of which 42 were collision
archived (11,262 shapes, 100,718,994 compressed bytes). Run / run-turn /
final-idle counts of frames over 50 ms: 23 / 36 / 103. Final-idle warm
increments: 57. The full combined result is not yet accepted as a sustained
streaming fix; lower moving frame p95 does not excuse the ground hold.

A control with only WaterSkin's refinement call disabled **in memory** is
running as session **75191**, `/tmp/oct9-runtime-unrefined-control.log`,
using `october9_unrefined_feel.tscn` and the same flags, including the startup
grass shots. Production source stays enabled. Do not launch another GPU
scene or restart this verified-live control. Its absence of a final report
is not a terminal state.

### Benchmark route precision discovered during attribution

The old timed turn phase ends on a frame boundary. Between the earlier
bounded-warmer run and this run the measured total turn differs by **1.239°**
(14,399.264° versus 14,398.025°), changing the ensuing long walk. Thus these
runs, and the currently running same-parameter control, are **not exact
route-matched causal evidence** that refinement alone caused the hold.
The hold itself and grass's missing-ground diagnosis are authoritative.

The harness now offers `--fixed-route`: before straight running it resets
the camera to the intended elapsed-turn heading, settles a frame with no
movement, and records the option in report metadata. This diagnostic option
has not been executed yet and does not alter the currently loaded control.
Use it for future causal traversal comparisons; retain existing results as
observed scenarios, not a controlled effect estimate.

Also prepared, not yet rendered/executed: `october9_battle_ground_review.gd`
corrects photo 6's actual Z=914.2 (the prior overview used 1150), chooses
nearby ridge/hollow ground views and records physics-ground hits;
`october9_foliage_motion_review.gd` selects an actual loaded painted tree and
records three moving poses at each of four medium distances;
`october9_water_branch_supply.gd` tests whether the suspect side branch can
be reached downhill through wet cells from an actual trace. Next review
scene centered at (-192,0,960), radius 1, covers these local sites. Preparing
these probes is not acceptance evidence.


## Refinement control and exact face-cache optimization (October 9)

The in-memory no-refinement control (session 75191) finished normally. Same
five 120 s phases, startup LOD photos, seed, dimensions and no-vsync settings.
Production water refinement stayed enabled on disk throughout.

| Phase | Frame p95 ms | Process p95 ms | Grass pending mean / max | Held frames |
|---|---:|---:|---:|---:|
| idle | 20.50 | 4.53 | 0 / 0 | 0 |
| turn | 28.21 | 5.65 | 0 / 0 | 0 |
| run | 29.35 | 15.09 | 10.86 / 41 | 0 |
| run_turn | 41.73 | 16.81 | 0 / 0 | 0 |
| idle_end | 42.82 | 13.47 | 0 / 0 | 0 |

Peak static memory 9,365.4 MiB. Unlike the older bounded-warmer comparison,
this control's recorded turn total is almost identical to the refined run:
14,398.025963° versus 14,398.025335° (difference 0.000628°). There was **no
terrain hold**, versus 6.926 s with refinement, and lower moving grass
backlog. This supports a throughput penalty from refinement, while one
sequential pair is not a precise isolated timing estimate. The different
final scene and continuing background work also prevent treating idle-end
p95 as a same-pose degradation measurement.

Retained optimization: the refiner now remembers evaluated faces within one
build. Immutable faces that survive a round unchanged need no second edge
or midpoint test; newly split faces still receive their full test, including
independent border decisions. This changes scheduling work, not geometry.
Four surface fields, five repetitions each, compare all resulting state
byte-for-byte against the saved pre-cache implementation: **20/20 identical**.
Synthetic total 141.0 → 108.2 ms (23% lower). The four focused regression tests
still pass (nine assertions). Real full-chunk timing/identity is prepared but
not yet measured, so the synthetic improvement is not claimed as a chunk or
frame-time speedup. Reference source retained as
`water-refinement-before-face-cache.gd`; diagnostic
`october9_refinement_cache_check.gd` takes that reference path as its argument.

`frame_feel_profile` additionally offers `--return-to-start`. After the
traversal, it restores the original pose, waits for the 3×3 ground/features
and grass to be ready (three seconds settled, 180 s hard limit), then records
`idle_return`. Loading is excluded and its status is explicit. This allows
initial/final performance at the same scene complexity. Together with
`--fixed-route`, it passes script parsing; runtime execution is still pending.

The combined land/foliage/branch review is now live as **session 85661**,
`/tmp/oct9-battle-ground-review.log`, output `/tmp/oct9-battle-ground-review`.
Its queued probe `october9_combined_ground_review.gd` will run the three
prepared inspections after the nine-chunk scene settles. No second GPU scene
should run until this one exits or is deliberately closed. Next exact
full-chunk cache benchmark: `october9_refinement_full_cache_check.gd` in that
same paused scene.


## Side-branch supply check after final mesh refinement

The mesh-clearance fix is not sufficient evidence of correct water placement.
A directed flood through actual wet samples from the river traces cannot reach
(-26,1142), (-26,1138), or (-25,1146), while the main-channel control at
(-39,1144) is reached. This persists at 0.25 m spacing with eight neighbors,
and with a 0.02 m per-edge uphill tolerance. The 80 m square has 49,067 wet
samples; 44,130 are reached with 0.001 m tolerance, 47,563 with 0.02 m.
This is a local diagnostic, not a global proof about every possible source.

The candidate explanation is more precise than simply "seeds cross a ridge":
the actual dense-capsule offers at the nearest trace point and branch are
72.65865 and 72.65869 m. The entire sampled cross-section's ground is at most
71.72613 m, so it *would* be connected at that initial head. The final water at
the nearest trace point is about 68.05 m, whereas the branch remains 72.19 m.
Later level adjustments therefore need a supply/connectivity invariant; a
terrain-only rejection at initial seeding would not catch this case. No new
production hydraulic rule has been adopted from this diagnosis yet.

`october9_water_branch_supply_fine.gd` repeats the finer checks in the live
review scene; `bank-fragment-claim.json` records actual initial offers and the
cross-section. Preserve the distinction between original trace profile heads
and dense-descent capsule heads (73.26 versus 72.66 m here).

## Final face-cache and visual review checks

On actual unrefined chunks (-1,5) and (-1,6), the refinement face cache preserves
byte-identical output and the exact 17,311/18,046 field queries. Alternating
before/after pairs measure 1,376/1,310 and 1,381/1,318 ms for the first chunk,
1,620/1,561 and 1,613/1,566 ms for the second: about 3–5%, substantially less
than the synthetic 23% result. It does not resolve the streaming-margin cost.

Final combined foliage captures at 40/80/100/120 m show natural leaf coverage
without the reported regular pixel grid. Three adjacent headings were captured
at each distance; these are still images, not a continuous-motion recording.
Bare grass around some foliage cameras is a review-harness limitation: those
poses did not move the grass streaming anchor and are not grass acceptance.

The ground-level hollow view shows a grassy connecting rise with lower terrain
on both sides. The original valley coordinate now sits against a changed
hillside; that camera does not provide an equivalent broad valley composition.
The ridge view also remains a weak demonstration of the local peak cluster.
Neither is used to claim complete battle-terrain visual acceptance.


## Post-adjustment source-support candidate (not enabled)

`october9_water_support_candidate.gd` prototypes a maximum-supported-head
walk from actual source indices. Each path is capped by every existing
surface level along it and stops where that supported level cannot cover
the bed. The highest supported path wins. This is stronger than the earlier
boolean directed walk: a small rise in the offered surface over a submerged
bed can be lowered, rather than incorrectly treated as an absolute barrier.
It never raises an offered level, and independently sourced pools survive.

Five synthetic tests / six assertions pass: a high bank behind a lowered
reach loses supply; a harmless surface hump lowers; a second source retains
its own higher basin; source order does not change the result; dry roots and
array row boundaries cannot fabricate a path. These tests validate the
candidate numeric rule, not its suitability for all production waterways.
It remains in the harness and is not called by the game.

The fine branch probe now optionally applies this candidate to the actual
sampled two-dimensional water/ground grid and saves `water-support-grid.bin`
for repeatable experiments. That new actual-area trial has not run yet.
Selecting real source roots, preserving narrow passages, avoiding chunk
seams, and measuring the added solve cost are still required before adoption.

The fixed-route, return-to-start production runtime trial is now live
(`/tmp/oct9-runtime-return.log`, report `/tmp/oct9-runtime-return.json`). Its
purpose is the same-view before/after lag comparison; do not infer results
from a live log before the final return phase completes.


## Fixed-route traversal and return-to-start — completed

The production run exited 0. Both new runtime options executed successfully.
After five 120 s phases, the return reached (0.5,114.0001,0.5), versus its
original (0.5,114.0,0.5), after 132,460 ms waiting for terrain/grass readiness.
A sixth 120 s stationary phase measured the original view. That delay is
real terrain regeneration and is excluded from the stationary frame timings.

| Phase | Frame p50/p95 ms | Process p95 ms | Median draws | Held frames |
|---|---|---|---|---|
| Initial idle | 19.55 / 20.37 | 4.45 | 1,415 | 0 |
| Turn | 21.51 / 26.42 | 5.37 | 1,914 | 0 |
| Run | 17.72 / 27.73 | 15.80 | 911 | 48 |
| Run and turn | 25.01 / 37.72 | 15.96 | 2,266 | 0 |
| Final location idle | 29.41 / 37.60 | 12.86 | 3,872 | 0 |
| Return to original view | 24.33 / 28.23 | 5.74 | 3,289 | 0 |

The straight-run hold totals 723.4 ms. This fixed route differs from the older
unfixed trials, so its shorter hold is not isolated proof of the face-cache
optimization's benefit. Grass is fully loaded during both idle comparisons.

Even the last 30 s of initial versus returned idle shows 1,415 versus 3,289
draws and 2.04 versus 4.30 million primitives. Built chunks increase from
roughly 20–22 to 45–47. Frame p95 is 20.73 versus 30.71 ms for these tails.
The same pose therefore renders substantially more completed scenery later;
this test does not isolate memory retention from workload growth. It does
establish that returning to the original position alone does not restore
initial performance. Further performance work must account for fully loaded
scenery and regeneration throughput, not only allocation/retirement costs.

Artifacts: `runtime-return.json`, `runtime-return.log`, and losslessly
compressed per-frame rows `runtime-return.frames.json.gz`.


## Source-support candidate on the actual photographed area

The headless production-field adapter completed after fixing a diagnostic-only
PackedFloat64Array conversion. At 0.25 m spacing the candidate removes all
three side-branch probes and preserves the main-channel probe at 75.75043 m.
This survives a conservative test with 4,063 roots: actual trace samples,
every wet survey-boundary point, and all wet points in intersecting pond
footprints. Thus neither omitted external inflow nor a nearby pond explains
the rejected side branch. The reference pass takes 263 ms for 49,067 wet
samples in the 321×321 grid; sampling is additional work, not in that timer.

Repeats aligned to the production 3 m lattice give the same branch outcome
at 0.5, 1, and 3 m spacing. Conservative rejected/lowered wet-node counts are
222/31 of 12,172, 58/10 of 3,069, and 8/3 of 370 respectively. The reference
walk times are 60.65, 14.77 and 1.57 ms. The 3 m probes use their nearest
lattice nodes, recorded explicitly as `sample_at`; they are not claimed to
sample the original coordinates exactly.

The 3 m production-field fixture is retained under
`tests/fixtures/october9/water-support-branch.bin`. A regression applies the
candidate to this actual field with the conservative roots, requiring the
three unsupported samples to dry while the supplied main channel stays
unchanged. Production integration is still pending. In particular, sparse
fine-rescue `-INF` currently means "use coarse interpolation", not "explicitly
dry": simply assigning rejected support values into that sparse array would
silently resurrect the very water being removed. Integration must handle
that representation deliberately and preserve cross-chunk identity.


## Integrated source support — review switch, not default yet

The single numeric implementation now lives in `WaterSourceSupport.gd`.
`WaterField.SOURCE_SUPPORT` defaults false while full-scene validation is in
progress. The source solve can apply it after fine rescue and before chunk
cropping. The canonical domain supplies all river-axis roots and real pond
footprints; this is not a separate per-chunk solve. The basin key and disk
cache distinguish the review switch, preventing reuse of an incompatible
cached fill. The headless support harness deliberately disables disk caching
when this rule is enabled.

An explicit packed-byte `sub_dry` mask now distinguishes removed water from
an absent fine override. Chunk crops and detached `WaterSampler` snapshots
retain the mask. Fine evaluation uses the actual rectangular source-grid
size, and edge support ignores rejected anchors. Ordinary unmarked fills
retain their previous fallback semantics. Tests cover dry override, untouched
coarse water, binary round-trip, detached snapshot ownership, rectangular
source dimensions, and cache-mode separation. Thirteen combined tests / 90
assertions passed; the added fourth cache test also passed (four cache tests,
72 assertions total).

Full cold source solve (owner area, 1365×993 fine grid): 121,967 wet nodes,
24,652 roots; 633 rejected and 398 lowered. Sampling costs 3,807.7 ms and
support propagation/output costs 709.6 ms. The production-cropped fields now
return dry at all three original branch probes while retaining the exact
main-channel level. At 1 m and 3 m, the conservative boundary/pond-supplied
second audit finds no further unsupported or lowered points in the local
window; at 0.5 m it finds one each. This is good local evidence, not yet a
multi-seed acceptance claim.

A fresh windowed nine-chunk review is running with `--source-support`, output
`/tmp/oct9-water-support-visual`, to capture the two matched river views and
ray-check the actual new water meshes. The game default is still off. The
added ~4.5 s per canonical solve needs attention before enabling it broadly.
A likely exact optimization to test is sampling fine lattice nodes directly:
at an exact node, an existing finite fine override owns the value; otherwise
only the coarse evaluator is needed. The current implementation invokes the
full four-corner fine evaluator at every node, redundantly visiting neighbors.
That equivalence must be tested before changing the sampling path.


## Source-support visual and exact-sampling review

Fresh nine-chunk rendered startup completed in 156.3 s. The two matched
views show the unsupported side cascade removed and the main river still
continuous over its drop. Actual mesh ray checks cover 871 confidently wet
samples with zero failures, minimum water/ground clearance 0.05048 m.
Captures are `final-combined-sites/river_shallow_supported.png` and
`river_drop_supported.png`. The count is lower than the old 1,004 because
the removed side water is now legitimately dry.

Exact-node sampling now avoids the general fine four-corner evaluator when
the node already has known ground. Unknown-ground nodes retain the full
path, including its double-precision wetness gate. Synthetic mixed shores
and missing ground: 3,510 points, zero value mismatches. Actual two-chunk
fields: 18,050 points, zero mismatches, 172.1→149.1 and 166.1→144.6 ms.
The full canonical-source check is stronger: the entire fine result,
including ground and dry mask, is byte-identical to the saved pre-optimization
implementation. Source sampling drops 3,793.5→2,250.8 ms; propagation remains
~700 ms, so total added solve cost falls from 4.49 to 2.95 s.

The combined numeric, dry-mask, sampling and cache tests pass 15/15 with
94 assertions. The source-support default remains off pending the broader
river survey and chunk-boundary/visual acceptance. A fresh eight-site,
two-seed river-axis survey with `--source-support` is now running, writing
`/tmp/oct9-supported-water-survey.json` and its matching log. The windowed
review has exited cleanly; no GPU review remains live.


## Source support enabled: native parity and wider checks

`WaterField.SOURCE_SUPPORT` is now enabled by default. After the final surface
adjustments, genuine trace and pond roots supply water through submerged
connections. Unsupported uphill branches dry; harmless surface humps above
a low bed lower to the available head. This removes the photographed side
cascade without raising water over banks or prescribing fixed river shapes.

The two-seed, eight-site survey retains all 594 wet river-axis probes with
zero dry/shallow failures. Across 24 shared chunk edges, all 1,219 wet samples
match exactly, including wet/dry classification. The matched rendered views
and 871 actual mesh clearance checks are described above.

`NativeWaterSourceSupport.cs` implements the same max-head propagation. Its
loader gate compares every output on 24 deterministic rectangular fixtures;
a photographed fixture and forced-fault same-call fallback also pass. Native
water tests: 10/10, 66 assertions. A full canonical solve is byte-identical to
the saved reference, including ground and explicit dry masks. Sampling takes
2,248 ms and native propagation 77 ms, versus 3,529 + 696 ms for the reference
in that run. This adds about 2.33 s per canonical source solve; it is not free.

Default-enabled numeric, mask, sampling and cache tests pass 15/15 with 95
assertions. Cache mode is now included in fake-cache test setup as well as
production cache identity. The broader runtime profile still needs to include
this new default. Logs and survey JSON are saved alongside this report.


## Fixed-scene rendering diagnostic

The completed return-to-start traversal distinguishes scene growth from a
simple accumulating slowdown. At the same position and heading, the last
30 seconds of initial idle contain 1,415 draw calls and 2.04M primitives;
the return contains 3,289 draws and 4.30M primitives. The completed chunk
count grows from 20–22 to 45–47. Frame p50 rises from 19.75 to 25.26 ms.
Thus substantially more completed scenery is visible at the later pose.
This does not rule out other lag causes. The return also requires 132.46 s
of regeneration before the measured idle, which remains a streaming concern.

The frame harness now offers `--steady-ablate`: wait for the complete desired
ring and grass, require ten stable seconds, hold the view fixed, pause streamer
integration, and insert a fresh full-render baseline before every rendering
variant. This isolates rendering from changed headings and new chunk commits.
It is a rendering diagnostic, not an end-to-end gameplay performance claim.
The current run writes `/tmp/oct9-steady-render.json` and matching log.

A fresh combined regression run passes 21/21 tests and 3,848 assertions,
covering collision actors/archive/residency, bounded warm views, abandoned
collision ownership, water refinement, local landforms and shared-profile
normals. `final-fast-regressions.log` records the exact test list.


## Fixed-scene result: grass dominates this view

The stationary profile completed successfully with all 49 desired chunks,
zero pending grass tiles and 46,108 nodes. Full-ring readiness took 414.18 s
after the startup wait. The main scene and camera were held constant; no
other benchmark ran during the measured rendering comparisons.

Full-render baselines remain tightly grouped: frame p50 21.87–22.20 ms,
p95 22.56–22.93 ms, 2,084 draws and 2,807,087 primitives. Script-process
p95 is 0.88–0.97 ms with integration paused. Representative variants:

| Variant | Frame p50 / p95 ms | Interpretation |
|---|---:|---|
| No grass | 12.21 / 13.61 | Grass is the largest rendering cost in this view. |
| Flat grass material | 16.22 / 16.79 | Lighting/shading is a substantial part of that cost. |
| Grass LOD bias 0.5 | 20.49 / 21.08 | About 1.6 ms saving; appearance must be judged. |
| Grass LOD bias 0.25 | 19.75 / 20.32 | About 2.4 ms saving; appearance must be judged. |
| No shadows | 20.21 / 20.77 | Much smaller than removing grass here. |
| No SSAO | 20.17 / 20.80 | About 1.9 ms, with an appearance tradeoff. |
| No cliff sheet | 19.70 / 20.24 | Includes its slope-rock children. |
| No water | 21.45 / 22.14 | Water rendering is not the dominant cost here. |
| No dressing | 21.59 / 22.24 | This spawn view is not a dense-forest benchmark. |

These are local rendering diagnostics, not production quality changes. The
next run compares grass vertex lighting, simpler diffuse/specular lighting,
and both LOD biases, with matched frozen-clock screenshots. Shader variants
exist only in the harness; the production grass material remains unchanged.
Reports: `steady-render.json`, `steady-render.log`, and losslessly compressed
`steady-render.frames.json.gz`.


## Grass rendering trials and retained LOD change

The repeat full-scene trial confirms the earlier LOD saving. Baselines stay
at 22.09–22.17 ms frame p50 and 22.78–22.84 ms p95. Bias 0.5 gives
20.58/21.20 ms; bias 0.25 gives 19.82/20.62 ms. Both retain the same number
of draw calls and instances; they select existing nested whole-blade meshes
earlier. The 90/140 m render ring and shading are unchanged.

Rejected lighting experiments: vertex lighting is slower (22.63/23.34 ms)
and visibly brighter, with a harsher shadow. Lambert/no-specular lighting
looks closer but offers no useful gain (22.02/25.60 ms). Neither changes the
production shader. See `grass-render-shots` for matched frozen-clock images.

Bias 0.25 is retained as `GrassStreamer.BLADE_LOD_BIAS`. In RGB code values
0–255, the foreground image mean absolute change is 0.017 (baseline repeat
0.006); middle band 0.125; distant grass band 1.257, with mean brightness
change +0.056. Visual review shows the same close carpet and coherent
distant grass, without an exposed bare band. These are static views; the
sustained moving profile remains to be checked. The harness accepts
`--grass-lod-bias 1` to restore the old selection for comparison.

All 13 existing grass streamer tests pass, 1,713 assertions, including ring
coverage, atomic buffer commits, stale-result handling, density controls and
nested whole-blade LOD identity. The combined ten-minute fixed-route plus
return-to-start profile is now running with the new water support default
and grass LOD, writing `/tmp/oct9-final-combined-feel.json` and matching log.


## Remaining acceptance: actual local-terrain routes

`october9_battle_routes.gd` is prepared for the original local-relief review
area at (-192, 0, 960). It samples the actual collision sheet on a 3 m grid,
finds candidate paths between the outer local crests and across the divided
hollow's bridge, then follows them with the production character/controller
interface. The route planner omits dressing when finding ground; the actual
walk retains all collision, so a blocked walk is reported rather than hidden.
This is pending execution after the sustained GPU profile finishes. No second
GPU scene has been started. Results will be saved as `battle-routes.json`.


## Combined traversal fails the runtime acceptance check

The combined run completed and returned to its exact starting pose. Initial
idle improves to frame p50/p95 17.27/17.96 ms; turn 19.91/25.31 ms; run
15.34/25.51 ms; run-turn 24.67/38.34 ms. However, running hits a **20.97 s
missing-ground hold** at (-191.05, 99.87, -622.42): neighboring chunk (-2,-4)
is not built. Running grass backlog mean 21.36, max 48; run-turn max 5 and
final idle max 3. This remains a real generation/grass-loading issue.

Late idle at approximately (-67.73,62.93,-796.08) reaches frame p50/p95
39.31/68.55 ms and script-process p95 36.36 ms. Returning to spawn restores
script-process p95 5.59 ms (frame 23.63/29.40), after a 152.95 s regeneration
wait. This suggests location-dependent active work rather than simply
accumulating time in the session. The LOD gain is not a complete runtime fix.

The harness now has optional `--profile-callbacks`, which wraps the world's
process callbacks in memory before instantiation and records each script's
per-frame elapsed time; production files are not rewritten. `--idle-only`
allows a focused reproduction. The next run targets the late-idle location.
The local battle-route check is prepared but deferred until this GPU run ends.

## Late-idle lag: wave simulation diagnosis and exact query caches

`oct9-idle-callbacks` identified `WaterRippleSim` as the dominant recurring main-thread cost at the late-run location: mean 10.461 ms, p95 23.047 ms, max 176.194 ms, versus streamer mean 2.334 / p95 4.954 ms. Finer instrumentation (`oct9-ripple-stages`) separates packet updates (mean 8.664 / p95 19.186 ms) from occasional flow-texture rebuilds (max 52.582 ms). The waveform itself was not reduced.

Retained changes:

- `WaterGroundSnapshot.water_surface_y` caches exact terrain probes used by the authoritative water evaluator. Its 8,192-entry FIFO evicts one entry at a time. Both original double coordinates are retained to reject collisions in the float32 `Vector2` lookup key. The cache dictionary is protected by a short mutex; terrain evaluation happens outside the lock.
- `WaterCurrentSurface` compiles a frozen cell's immutable corner levels, ground heights and cliff-gate result, then evaluates the original dynamic weights, wall spans and shoreline support. Fine overrides avoid computing and discarding the coarse answer first. The reference's double wet sum and float32 mixed-shore rounding are preserved separately. Its bounded FIFO uses a short mutex too; compilation happens outside the lock. It does not mutate the planner's `node_ground` memo from concurrent consumer calls.
- `WaterSampler` uses this evaluator for current derivatives; static water height remains the shared `WaterField` evaluator. Current ownership and velocity interpolation avoid allocating four nested corner Arrays on every wave start/midpoint query, preserving accumulation order.
- Flow-texture cache invalidation is limited to cells a changed sampler can own. Distant chunk arrivals no longer erase the entire local flow cache.

The initial fully-wet-only shortcut was insufficient and was replaced by the compiled evaluator. The fixed-step replay fixture contains the actual 64-packet, six-sampler slow state (`tests/fixtures/october9/ripple-late-update.bin.gz`). The reference disables both cell compilation and ground caching. Four alternating 600-frame replays produce the same **whole-motion** digest, including every frame's packets and spawn timer/counter: `75015086d087297f9a9481b582561c18d447a69a652a1907d04b716930dba133`. Reference mean 4.35 / 4.10 ms and p95 9.62 / 8.36 ms; optimized mean 1.76 / 1.78 ms and p95 2.91 / 3.56 ms (`oct9-ripple-final-replay.log`). Background load varies, so the exact motion equality and alternating measurements matter more than a single absolute time.

`oct9-current-parallel-tests.log`: **15/15 tests, 34 assertions**, including 16,000 exact surface comparisons across all four tile modes, wet/dry/inherited fine corners and coarse-only fields; 1,000 scalar velocity/ownership comparisons; concurrent frozen-cell readers; exact ground-cache key collisions and FIFO eviction; the existing downstream crest/bank constraints.

The rendered 120-second `oct9-ripple-compiled-live` run (before the final scalar lookup reduction) measured ripple mean 6.148 / p95 9.660 / max 32.361 ms with detailed nested instrumentation enabled. Packet updates p95 9.143 ms; flow-refresh max 18.408 ms. Whole-frame process p95 14.04 ms. This location is in moving water: the character drifts, so these live runs are not fixed-camera A/Bs. The deterministic replay is the motion-equivalence comparison. A final traversal without detailed instrumentation is still needed; this result does not dismiss cold planning holds or the grass backlog waiting on unbuilt ground.


## Local battle terrain: actual character routes

`october9_battle_routes.gd`, seed 2697992464, nine production chunks centred at (-192, 960). The harness raycasts the actual collision sheet at 3 m spacing, restricts route planning to walkable grades, then follows the selected route using the production character controller and all placed collision. Both paths completed: clustered crests near (-275.39, 826.81), 31/31 waypoints; divided-hollow bridge near (-71.84, 816.80), 34/34. The crest path descends from roughly 96 m to an 88 m pass and climbs to 100 m, rather than remaining on one hillside. Results and sampled trajectories are in `battle-routes.json`; full run in `oct9-battle-routes.log`. Earlier final combined ground/overview captures provide the visual comparison.


## Combined traversal after current-query fixes; ground starvation reproduced

`oct9-current-combined-feel`: 120 seconds each idle/turn/run/run-turn/final-idle, then return to the original pose and another 120-second idle. No callback instrumentation. Compared with `oct9-final-combined-feel`, final-idle dt p50/p95 falls from 39.31/68.55 to **19.85/24.15 ms**, process p95 from 36.36 to **6.49 ms**. The runs follow different final positions when loading holds differ, so the fixed wave replay above is the controlled equivalence/cost evidence. The return reaches the exact original pose; return-idle dt p50/p95 27.53/32.81 ms, process p95 6.40 ms. Occasional long GPU/retirement frames remain.

Grass is still **not accepted on this run**: run backlog mean/max 62.12/94; 61.16 tiles on average wait for ground, 0.88 for grass computation. The player is held 50.301 seconds at (-176.87, 103.68, -575.06), waiting for chunk (-1,-4). The planner is blocked in `tail_wait` for 75.019 seconds on background chunk (1,-3), while three old tails own every mesher. Its semaphore wait never checks the priority changes that arrived after it began waiting.

The follow-up makes that wait cancellable at the existing safe planning boundary and reserves one of the three meshers for tiers 0–2 after startup. Background tier 3 can use the other two; startup can still use all three. An acquired slot is returned if cancellation wins the race. This changes scheduling only, preserving the boxed payload handoff and existing complete-cache resume semantics. `oct9-tail-reserve-tests.log`: 13/13 tests, 34 assertions, including interruption with every slot occupied, reservation, urgent use, shutdown, startup, exact semaphore balance and the existing priority/dependency tests. A focused live route validation is in progress.


## Tail throughput: endpoint lookup and water refinement

The reserved-slot route (`oct9-tail-reserve-route`) reduced held movement from 50.301 to 42.732 seconds and mean moving grass backlog from 62.12 to 43.21 tiles, but 40.42 tiles still waited on ground. This remains a failed grass acceptance run. Debug snapshots identify background (-3,0) holding a mesher for over 100 seconds while urgent (-1,-4) and (-2,-4) also compute.

A new detached production-tail profiler measures (-3,0) at 50.65 seconds: terrain 33.59 s, water 16.62 s, dressing .38 s, grass snapshot .059 s. Urgent (-2,-4) is 31.33 seconds: terrain 12.27 s, water 18.42 s. The ground mesh itself is under 1.2 seconds; cliff construction and water refinement dominate.

Two exact changes address that work. Cliff endpoint continuation uses the existing eight-metre-halo spatial buckets instead of scanning every primitive for each endpoint. On (-3,0), endpoint detection falls from 12.908 to .207 seconds. The exhaustive-reference endpoint test and existing foot-line/refinement tests pass 9/9, 356 assertions. Water refinement compiles immutable fill corners with the already-tested exact cell evaluator, preserving shore float32 rounding and raw canonical contexts' default fill size. Refinement falls from 9.043 to 1.848 seconds.

Complete (-3,0) terrain payload SHA256 is unchanged: `2e507b82f1690172a1febe7d80f93261baed81838346d7c1338bf5ce7943c4ef`; water mesh arrays are unchanged: `1bf61f422003e61551eb3ca7808af92d9b6b2d177625d931a052a20f807ca4ca`. Terrain total falls from 33.79 to 21.18 seconds; actual water build from 16.66 to 8.70 seconds (outer reported water timing includes hash serialization in these diagnostic runs). Logs: `oct9-tail-detail-base.log`, `oct9-tail-detail-fast2.log`. An initial invalid cache integration assumed sampler-only fill_size metadata; it was corrected to the reference default before the successful equality run. Live route acceptance follows.

Final cache/endpoint/refinement focused suite: `oct9-mesh-cache-tests.log`, 13/13 tests, 30 assertions (including 16,000 exact surface comparisons inside aggregate assertions).


The exact mesh optimizations' live route (`oct9-tail-fast-route`) starts in 99.9 s. Run holds fall from 42.732 to **30.049 s**, mean grass backlog 43.21→**26.19**, max94→65; mean ground wait 21.30 tiles. The first boundary (-1,-4) now holds only 97 frames; the rest is the later (-2,-4) crossing, whose feature-village planning takes 17.8 s before terrain/water tails. The route travels farther, so its run process p95 rises to 12.44 ms and dt p95 to23.04 ms amid more active integration; these are not matched-position frame comparisons. Twenty-second settle ends without frozen frames but retains mean23.29 pending grass tiles. This is better throughput, still not grass acceptance. A bounded travel prediction trial extends 30→60 seconds, retaining the existing maximum radius and prioritizing the same footprint earlier.


The 60-second bounded prediction (`oct9-prefetch-route`) further reduces held movement to **5.800 s** (from30.049), moving grass backlog mean **20.21**, max65; mean14.90 tiles wait for ground and5.16 for computation. Backlog is zero at the run's end and essentially zero throughout the20-second settle (mean.07,max2); no settle freezes. Startup100.8 s, run dt p50/p9517.53/26.74 ms, process p9512.89 ms. The shorter hold lets the runner reach more scene complexity, so frame costs are not matched-position comparisons. Remaining held frames wait for (-1,-4) and then(-2,-4) tails/integration. Retain60 seconds; existing radius cap still bounds the footprint. Follow-up removes repeated group-index searches and memoizes identical repeated cliff mesh vertex colours, with full payload equality required.


The last cliff throughput changes reuse the assigned group index, compare line groups only against actual corner groups, and memoize biome colours for triangle-soup vertices sharing one position. The complete terrain and water hashes above remain identical. Final detached (-3,0) tail: terrain15.38 s, water~7.65 s, dressing.334 s, grass snapshot.052 s; outer total24.04 s includes water-array hashing. Earlier matching tail was50.65 s without hashing. Machine load improved modestly (basic surface.50→.44 s), so use the unchanged outputs and individual removed operations as evidence, not a universal2x speed claim. Final full-route/late-idle validation follows.


## Final combined acceptance — retained build

`oct9-acceptance-feel`, seed 2697992464, Apple M1 Pro, 1920×1080, no vsync; 120 seconds each idle, turn, run, run-and-turn, final idle, then return to the original pose and another 120-second idle. No concurrent test/benchmark workload was launched. Startup 83.5 s. **No held movement frames in any phase.**

| Phase | Frame p50 / p95 ms | Script process p95 ms | Grass pending mean / max |
|---|---:|---:|---:|
| Idle |18.39 /19.42|4.29|0 /0|
| Turn |20.85 /27.10|5.26|0 /0|
| Run |18.26 /29.48|12.60|4.41 /24|
| Run and turn |23.47 /35.33|10.65|0 /1|
| Final idle |26.67 /35.08|10.42|0 /0|
| Return idle |24.26 /30.92|6.53|0 /0|

The return arrives at (0.5,114.0001,0.5), matching the requested (0.5,114.0,0.5), after 52.299 s of explicit teleport loading. This loading is separate from the uninterrupted ordinary travel phases. Peak monitored static memory 9670.5 MiB; final-idle snapshot 8592.0 MiB; textures 1858.3 MiB. The route now reaches farther than stalled comparison runs, so scene-dependent GPU/frame comparisons are qualified. The fixed wave replay and unchanged complete mesh hashes supply controlled computation/identity evidence.

Occasional long rendering/retirement frames remain; this work does not claim a universally hitch-free renderer. The sustained CPU escalation and the reported grass/ground starvation are no longer reproduced in this final route. Final cliff tests: 7/7, 12,262 assertions (`oct9-cliff-final-tests.log`); final exact water-cache/refinement/endpoint suite: 13/13, 30 aggregate assertions including 16,000 exact surface comparisons (`oct9-mesh-cache-tests.log`). Earlier native parity, source-support, seam, clearance, visual, and actual-character route validations above remain applicable because the final throughput changes preserve complete terrain and water mesh hashes.
