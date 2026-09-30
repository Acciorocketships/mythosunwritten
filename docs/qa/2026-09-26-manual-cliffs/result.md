# September 26 cliff repair results

**REJECTED BY OWNER.** p03 exposed a pervasive style regression: disconnected flat tops and angular, recoloured rock. The acceptance statement below was incorrect. The broad production changes have been reverted; see [style restoration](../2026-09-26-cliff-style-restoration/result.md).

**Historical record of the rejected pass:** The [issue register](issues.md) links all 13 original images. Twelve poses have matched native before/after captures and inspected pixel differences; image 1 has an explicitly approximate context comparison. This is site-based acceptance, not an exhaustive proof over every generated world.

## What changed

- **Missing faces and triangles:** bedrock is a single-valued heightfield, now triangulated directly on its 0.5 m world grid. Surface nets had folded thin benches and created downward-facing top triangles. The new triangles also supply collision and grass support. Other experimental solid styles retain their original mesher.
- **Old lips and projecting native walls:** actual replacement-quad coverage withdraws the native pieces. Coverage includes the upper plateau band beside deep carved notches and neighbouring chunk ownership. Rendered skirts and their collision are filtered together.
- **Gentler slopes and crests:** shoulder radii increase from 1.8–4.8 to 2.6–6 m, foot radius from 3.6 to 4.5 m; tall-relief radii also widen. Roads and water retain their cut constraints, and 1 m level steps remain unchanged. The optional rejected underlip mode retains its original radii.
- **Rock glitches:** thin, isolated bedrock peaks are bounded against opposed neighbours; the frozen photo 13 fin was 4.55 m high across one 0.5 m node. Off-grid rock fitting now samples the exact rendered triangle. Exposed bedrock uses the same summer stone overlay tint as Meadow rocks, removing the grey material mismatch behind them.
- **Striped rock tops:** Meadow's grass projection uses the rock surface normal rather than the hillside support normal. Horizontal tops no longer collapse texture coordinates into parallel lines.
- **Floating grass:** support is evaluated on the exact rendered triangle; excluded rock points remain claimed, and the clump footprint must stay supported. Grass can continue across the ownership boundary onto ordinary ground. Rocks below an upper plateau do not suppress its grass.
- **Colour seams:** the sheet's spatial biome colour is applied once, rather than being multiplied again by an instance tint. Slope grass carries the sheet's interpolated shading normal into the same moss colour function. Flat-ground grass retains its original palette path.

## Alternatives and controls

The original surface-nets investigation compared fragment removal, snapping, triangle area thresholds, full column ranges, and distance extrapolation. Those did not resolve both defects. Double-sided rendering hid small inverted triangles but left the large opening; direct heightfield triangulation closed both. [Controlled difference](diffs/controlled-mesh-x4.png).

A no-native-piece render control retained the photo 13 stone projections, isolating them to the bedrock rather than the old kit. The measured single-node fin now has a dedicated frozen regression. Broad faces and benches are retained.

The native unlit colour control uses the actual grass and cliff shaders. Before, RGB-vector error was 0.0738 at 35° and 0.1043 at 45°. After, it is 0 at 0°, 20° and 35°, and 0.00877 at 45° (the shaders sample slightly different positions within the centre pixel). [Before data](colour-control-before/results.json), [after data](colour-control/results.json), [difference](diffs/controlled-grass-colour-x4.png).

## Traversal

The original photo 4 replay is blocked for all 360 uphill-input ticks: 0 m travel. The first valid cached candidate replay travels 4.125 m, rises 1.868 m, and ends on the 44 m plateau with floor contact. The character's 55° walk limit is unchanged. [Before trace](climb/00/walks.json), [candidate trace](climb/01/walks.json).

The initial multi-view walk in `south-final` is excluded: the streamer had disabled the character’s physics body after camera teleports requested an arrival halo outside the review area. A later waiting-only replay in `review-south` correctly asserted instead of producing a false result. The final cached-world replay asserts loaded chunks along the entire path, pauses streaming, and reactivates the unchanged production character and collision. It runs from the northern review scene, whose loaded terrain includes photo 4. [Final uphill/downhill traces](review-north/00/walks.json): uphill **4.1255 m**, rise **1.8680 m**; downhill **4.1266 m**, fall **1.8998 m**; both finish on the floor. Wider terrain settles the original starting pose to `(280.732,42.132,902.594)` before uphill input; that settled start is retained in the trace.

## Evidence provenance

`*-close/00` are original production captures at reconstructed mouse-view camera poses: 8.2 m boom, 3.2 m pivot, FOV 75. Initial `south/00`, `river/00`, and `north/00` used a tactical-camera assumption and are contextual only. Image 1 has no crosshair hit; its nearby context view is explicitly approximate.

`*-close/01` checks mesh/tint repairs, `*-close/02` checks replacement coverage. `*-final/00` is the first fresh integrated candidate. `south-final/01` is the no-native control, `/02` adds fin/contact fixes, and `/03` matches the Meadow stone tint. These are intermediate studies, not final acceptance.

The final review is captured in `review-south`, `review-river`, and `review-north`. Pixel differences establish changes; visual inspection and geometric/physics checks establish fixes. Grass sway, water animation and temporal rendering also contribute to live image differences. No pixel-change percentage is treated as proof of correctness.

## Final verification

- [Focused native tests](tests/focused-final.txt): **43/43 tests, 521 assertions** (11 new manual-cliff regressions plus bedrock, Meadow, grass-field and grass-streamer suites).
- [Terrain and legacy regression run](tests/terrain-regression.txt): terrain mesher **51/51**; legacy cliff dressing **40 passing, 3 failing, 1 without assertions**. All nine failing assertions reproduce against the original `HEAD` production scripts/materials in an isolated source snapshot: [baseline control](tests/legacy-baseline.txt). They concern pre-existing carved-pocket/flush-step native-kit fixtures; they are not regressions from this repair. The broader suite is therefore not claimed fully green.
- Native scene audits: **493 grass roots**, no unsupported roots; **634 surface collision contacts**, no misses. [South](review-south/native-audit.json), [river](review-river/native-audit.json), [north](review-north/native-audit.json).
- Exact adjacent ownership heights, triangle winding, fin bounds, grass mesh interpolation, blocked-rock ownership, footprint edges and ordinary-ground transitions are pinned programmatically. GPU material controls verify the shader path, not merely source strings.
- `git diff --check` passes. Review cameras, grass placement and collision use the integrated production build.

## Inspected final image comparisons

Every row links the full-resolution before, after and amplified pixel difference. Raw differences and numeric metrics sit beside each amplified difference. Animation contributes to some pixels; the observations below describe visible geometry/material changes.

| Image | Before | After | Difference | Visual finding |
|---|---|---|---|---|
| 2 | [before](river-close/00/p02.png) | [after](review-river/00/p02.png) | [diff](diffs/p02-x4.png) | Rounded bank crest; continuous ground-to-moss grade; no exposed lip band. |
| 3 | [before](north-close/00/p03.png) | [after](review-north/00/p03.png) | [diff](diffs/p03-x4.png) | Former exposed native gaps backed by continuous bedrock; water cut remains intact. |
| 4 | [before](south-close/00/p04.png) | [after](review-south/00/p04.png) | [diff](diffs/p04-x4.png) | Broader climbable shoulder; smoother crest and supported grass. Real-character replay passes both ways. |
| 5 | [before](south-close/00/p05.png) | [after](review-south/00/p05.png) | [diff](diffs/p05-x4.png) | White triangular gaps and floating clumps gone; remaining bench grass is supported. |
| 6 | [before](river-close/00/p06.png) | [after](review-river/00/p06.png) | [diff](diffs/p06-x4.png) | Far bridge-bank opening filled; bridge and channel remain clear. |
| 7 | [before](river-close/00/p07.png) | [after](review-river/00/p07.png) | [diff](diffs/p07-x4.png) | Scalloped lip and hard material seam removed; rounded crest remains continuous. |
| 8 | [before](north-close/00/p08.png) | [after](review-north/00/p08.png) | [diff](diffs/p08-x4.png) | Rolling shoulders replace sharp transitions; grass follows the surface colour. |
| 9 | [before](south-close/00/p09.png) | [after](review-south/00/p09.png) | [diff](diffs/p09-x4.png) | Tiny white gaps gone; rock tops use canonical grass instead of parallel stripes. |
| 10 | [before](south-close/00/p10.png) | [after](review-south/00/p10.png) | [diff](diffs/p10-x4.png) | Rounded approach and crest, no floating fringe or triangular openings. |
| 11 | [before](north-close/00/p11.png) | [after](review-north/00/p11.png) | [diff](diffs/p11-x4.png) | Large opening that showed the town underside is closed; smaller inverted triangles also gone. |
| 12 | [before](north-close/00/p12.png) | [after](review-north/00/p12.png) | [diff](diffs/p12-x4.png) | Scalloped lips and exposed gaps removed across the stepped formation. |
| 13 | [before](south-close/00/p13.png) | [after](review-south/00/p13.png) | [diff](diffs/p13-x4.png) | Striped top removed; isolated fin bounded; exposed backside uses Meadow stone tint. |
| 1 (approx.) | [before](river/00/p01-context-approximate.png) | [after](review-river/00/p01-context-approximate.png) | [diff](diffs/p01-context-approximate-x4.png) | Nearby bank context: continuous crest colour and supported grass; not an exact original-camera reconstruction. |

## Reproducing the review

Use `tests/harness/cliff_site_review.tscn -- --seed 2697992464 --at X,Y,Z --radius 1 --grass --full --plain --output DIR --mouse-shot p04:280.5,41.7,901.7:280.6,44,899.8` (repeat `--mouse-shot` for the register poses). Group centres are south `300,20,960`, river `470,24,460`, north `430,40,850`. The harness saves 1600×900 captures. `cliff_pixel_diff.py BEFORE AFTER PREFIX` emits raw and amplified differences. The `cliff_manual_audit.gd` and `cliff_manual_walk.gd` test-only probes operate on the settled review scene through its `probe` file. `cliff_manual_colour.gd` and `cliff_manual_material.gd` provide isolated GPU controls. Large diagnostic arrays and rendered images remain local QA artifacts under the repository's existing ignore policy; the small frozen regression fixtures are retained in `tests/fixtures/september26-cliffs`.
