# September 26 manual cliff judging register

**Owner rejected this implementation after inspecting p03.** Its “Verified” labels below are superseded by the [style restoration](../2026-09-26-cliff-style-restoration/result.md); they must not be treated as acceptance.

Seed: **2697992464**. Baseline: clean working tree at task start, production `sheet_bedrock`. All 13 supplied images were visually inspected. Prior QA claims do not close these newly reported sites.

## Issues and candidate solutions

The table retains the initial investigation alternatives, with current status after the owner-requested restoration. The rejected pass's tests and captures remain historical evidence only; image 1 is an approximate context view.

| ID | Reported defect | Evidence | Candidate investigation / solution | Status |
|---|---|---|---|---|
| C01 | Original scalloped grass lips remain exposed beneath/through the mountain | [#7](/Users/ryko/.codex/attachments/a2f7d355-00ed-46dd-9bc7-2b0d6e530863/image-7.png), [#12](/Users/ryko/.codex/attachments/a2f7d355-00ed-46dd-9bc7-2b0d6e530863/image-12.png), [#13](/Users/ryko/.codex/attachments/a2f7d355-00ed-46dd-9bc7-2b0d6e530863/image-13.png) | Replace the lip band with continuous slope geometry before withdrawing native lips; audit coverage at cut boundaries. | [Repaired in restoration](../2026-09-26-cliff-style-restoration/result.md) |
| C02 | Large void openings and missing cliff faces | [#3](/Users/ryko/.codex/attachments/a2f7d355-00ed-46dd-9bc7-2b0d6e530863/image-3.png), [#6](/Users/ryko/.codex/attachments/a2f7d355-00ed-46dd-9bc7-2b0d6e530863/image-6.png), [#11](/Users/ryko/.codex/attachments/a2f7d355-00ed-46dd-9bc7-2b0d6e530863/image-11.png), [#12](/Users/ryko/.codex/attachments/a2f7d355-00ed-46dd-9bc7-2b0d6e530863/image-12.png) | Compare slope column coverage, native-piece removal and cut masks; retain a complete backing until replacement geometry exists. | [Repaired in restoration](../2026-09-26-cliff-style-restoration/result.md) |
| C03 | Tiny triangular gaps or protrusions on stone and moss | [#5](/Users/ryko/.codex/attachments/a2f7d355-00ed-46dd-9bc7-2b0d6e530863/image-5.png), [#9](/Users/ryko/.codex/attachments/a2f7d355-00ed-46dd-9bc7-2b0d6e530863/image-9.png), [#10](/Users/ryko/.codex/attachments/a2f7d355-00ed-46dd-9bc7-2b0d6e530863/image-10.png), [#11](/Users/ryko/.codex/attachments/a2f7d355-00ed-46dd-9bc7-2b0d6e530863/image-11.png), [#12](/Users/ryko/.codex/attachments/a2f7d355-00ed-46dd-9bc7-2b0d6e530863/image-12.png), [#13](/Users/ryko/.codex/attachments/a2f7d355-00ed-46dd-9bc7-2b0d6e530863/image-13.png) | Separate actual mesh boundary holes from grass tips, winding and fragment removal; pin each cause with geometry/root probes. | Missing triangles repaired in restoration; protrusion redesign deferred |
| C04 | Cliff slopes are too steep | [#4](/Users/ryko/.codex/attachments/a2f7d355-00ed-46dd-9bc7-2b0d6e530863/image-4.png), [#10](/Users/ryko/.codex/attachments/a2f7d355-00ed-46dd-9bc7-2b0d6e530863/image-10.png), [#11](/Users/ryko/.codex/attachments/a2f7d355-00ed-46dd-9bc7-2b0d6e530863/image-11.png) | Widen shoulder and foot profiles with relief-aware bounds; preserve roads, water and terrace interiors. | Deferred; original style restored at owner request |
| C05 | Character cannot climb visually walkable ground | [#4](/Users/ryko/.codex/attachments/a2f7d355-00ed-46dd-9bc7-2b0d6e530863/image-4.png) | Replay the real character uphill/downhill; inspect collision surface and controller contact behavior before changing walk limits. | Deferred; original style restored at owner request |
| C06 | Abrupt plateau-to-slope corner | [#2](/Users/ryko/.codex/attachments/a2f7d355-00ed-46dd-9bc7-2b0d6e530863/image-2.png), [#7](/Users/ryko/.codex/attachments/a2f7d355-00ed-46dd-9bc7-2b0d6e530863/image-7.png), [#8](/Users/ryko/.codex/attachments/a2f7d355-00ed-46dd-9bc7-2b0d6e530863/image-8.png), [#10](/Users/ryko/.codex/attachments/a2f7d355-00ed-46dd-9bc7-2b0d6e530863/image-10.png) | Round the crest with a continuous profile and normals, checking flat-top coverage. | Deferred; original style restored at owner request |
| C07 | Rock backside is grey/glitched | [#13](/Users/ryko/.codex/attachments/a2f7d355-00ed-46dd-9bc7-2b0d6e530863/image-13.png) | Inspect native rock materials, fitted caps and exposed cut/back faces; correct the source geometry/material path. | Deferred; original style restored at owner request |
| C08 | Dark striped/stretched grass texture on rock tops | [#9](/Users/ryko/.codex/attachments/a2f7d355-00ed-46dd-9bc7-2b0d6e530863/image-9.png), [#11](/Users/ryko/.codex/attachments/a2f7d355-00ed-46dd-9bc7-2b0d6e530863/image-11.png), [#13](/Users/ryko/.codex/attachments/a2f7d355-00ed-46dd-9bc7-2b0d6e530863/image-13.png) | Use the canonical world-space grass/moss mapping on every rock-top surface, including cap/side adapters. | Deferred; original style restored at owner request |
| C09 | Grass floats or overhangs cliff edges | [#5](/Users/ryko/.codex/attachments/a2f7d355-00ed-46dd-9bc7-2b0d6e530863/image-5.png), [#10](/Users/ryko/.codex/attachments/a2f7d355-00ed-46dd-9bc7-2b0d6e530863/image-10.png), [#12](/Users/ryko/.codex/attachments/a2f7d355-00ed-46dd-9bc7-2b0d6e530863/image-12.png), [#13](/Users/ryko/.codex/attachments/a2f7d355-00ed-46dd-9bc7-2b0d6e530863/image-13.png) | Validate blade roots and footprint against final rendered/collision support; suppress unsupported edge growth. | Deferred; original style restored at owner request |
| C10 | Grass colour differs from its cliff substrate | [#1](/Users/ryko/.codex/attachments/a2f7d355-00ed-46dd-9bc7-2b0d6e530863/image-1.png), [#2](/Users/ryko/.codex/attachments/a2f7d355-00ed-46dd-9bc7-2b0d6e530863/image-2.png), [#5](/Users/ryko/.codex/attachments/a2f7d355-00ed-46dd-9bc7-2b0d6e530863/image-5.png), [#8](/Users/ryko/.codex/attachments/a2f7d355-00ed-46dd-9bc7-2b0d6e530863/image-8.png), [#10](/Users/ryko/.codex/attachments/a2f7d355-00ed-46dd-9bc7-2b0d6e530863/image-10.png) | Trace grass and slope tint/biome sampling and steepness grading; share the substrate appearance field. | Deferred; original style restored at owner request |
| C11 | Hard colour transition between flat top and darker slope | [#1](/Users/ryko/.codex/attachments/a2f7d355-00ed-46dd-9bc7-2b0d6e530863/image-1.png), [#2](/Users/ryko/.codex/attachments/a2f7d355-00ed-46dd-9bc7-2b0d6e530863/image-2.png), [#7](/Users/ryko/.codex/attachments/a2f7d355-00ed-46dd-9bc7-2b0d6e530863/image-7.png), [#8](/Users/ryko/.codex/attachments/a2f7d355-00ed-46dd-9bc7-2b0d6e530863/image-8.png), [#10](/Users/ryko/.codex/attachments/a2f7d355-00ed-46dd-9bc7-2b0d6e530863/image-10.png) | Match ground field, normals and colour transition continuously at the crest; inspect unlit/albedo controls as needed. | Deferred; original style restored at owner request |

## Reproduction poses

Coordinates transcribed from F3. Use `ReviewCam.solve_cam` for every supplied crosshair. Image 1 has no terrain hit, so its camera cannot be uniquely recovered from the overlay; any reconstructed nearby view must be labelled approximate.

| Image | Player world | Crosshair world |
|---|---|---|
| [#1](/Users/ryko/.codex/attachments/a2f7d355-00ed-46dd-9bc7-2b0d6e530863/image-1.png) | `464.1,24.0,420.7` | `None` |
| [#2](/Users/ryko/.codex/attachments/a2f7d355-00ed-46dd-9bc7-2b0d6e530863/image-2.png) | `491.1,23.9,384.1` | `476.6,16.0,382.7` |
| [#3](/Users/ryko/.codex/attachments/a2f7d355-00ed-46dd-9bc7-2b0d6e530863/image-3.png) | `503.3,36.0,951.5` | `507.0,36.0,955.3` |
| [#4](/Users/ryko/.codex/attachments/a2f7d355-00ed-46dd-9bc7-2b0d6e530863/image-4.png) | `280.5,41.7,901.7` | `280.6,44.0,899.8` |
| [#5](/Users/ryko/.codex/attachments/a2f7d355-00ed-46dd-9bc7-2b0d6e530863/image-5.png) | `276.7,19.8,977.4` | `276.7,23.3,975.9` |
| [#6](/Users/ryko/.codex/attachments/a2f7d355-00ed-46dd-9bc7-2b0d6e530863/image-6.png) | `466.8,28.0,505.4` | `492.3,16.0,495.9` |
| [#7](/Users/ryko/.codex/attachments/a2f7d355-00ed-46dd-9bc7-2b0d6e530863/image-7.png) | `465.9,28.0,494.0` | `460.2,28.0,500.8` |
| [#8](/Users/ryko/.codex/attachments/a2f7d355-00ed-46dd-9bc7-2b0d6e530863/image-8.png) | `392.9,43.9,707.2` | `400.8,32.0,681.5` |
| [#9](/Users/ryko/.codex/attachments/a2f7d355-00ed-46dd-9bc7-2b0d6e530863/image-9.png) | `303.5,13.7,1006.1` | `304.6,15.9,1003.5` |
| [#10](/Users/ryko/.codex/attachments/a2f7d355-00ed-46dd-9bc7-2b0d6e530863/image-10.png) | `284.5,44.0,881.5` | `286.8,46.2,876.3` |
| [#11](/Users/ryko/.codex/attachments/a2f7d355-00ed-46dd-9bc7-2b0d6e530863/image-11.png) | `296.7,53.5,772.2` | `299.4,55.4,773.3` |
| [#12](/Users/ryko/.codex/attachments/a2f7d355-00ed-46dd-9bc7-2b0d6e530863/image-12.png) | `426.6,60.0,927.5` | `420.9,61.2,928.9` |
| [#13](/Users/ryko/.codex/attachments/a2f7d355-00ed-46dd-9bc7-2b0d6e530863/image-13.png) | `290.3,13.8,999.9` | `288.9,14.0,990.8` |

## Acceptance procedure

1. Reproduce the current build at the recorded poses with production grass, lighting, terrain and collision. Save baseline before editing production.
2. Pin each defect with a failing geometry, support, appearance or real-character invariant. Diagnose competing solutions and record the chosen cause/fix.
3. Run the targeted tests, then relevant regression suites.
4. Capture the same camera after changes. Inspect before, after and pixel differences; freeze animation where possible and distinguish unrelated lighting/grass motion. Inspect nearby angles and boundary cases to try to falsify the fix.
5. Close an issue only when its test and visual evidence support closure. An altered image alone does not prove a fix.

## Historical execution log — rejected pass

- Original screenshots inspected and mapped above. Native baseline capture launched for southern massif sites (4, 5, 9, 10, 13).

- Corrected the initial camera assumption: these are mouse-view screenshots (8.2 m boom, 3.2 m pivot, FOV 75), not tactical FOV 50 views. `south/00`, `river/00`, `north/00` are contextual only. Matched native baselines are `south-close/00`, `river-close/00`, `north-close/00`.
- Direct bedrock heightfield triangulation replaces surface nets. Frozen photo 11 culling controls distinguish inverted small triangles from the large topology opening; double-sided rendering hides only the former. The direct heightfield fixes both. Full-site iteration 01 confirms closure of the large opening; other defects remain at this stage.
- Native-piece coverage now follows replacement quads, including upper plateau bands beside deep carved notches. The old height-only burial rule retained projecting scalloped lips and wall slivers.
- Sheet tint was applied twice (vertex and MultiMesh instance). Sheets now use a white instance multiplier.
- Meadow tops were projecting grass with the support hillside normal, collapsing texture coordinates on horizontal tops. The rock's own world normal now controls projection and grass grade.
- Wider shoulder/foot profiles are under review. A 12 m lawn-profile median regression fails at 60.29 degrees on the original and passes below 55 degrees on the candidate. Original optional underlip radii are preserved.
- Slope grass uses the exact mesh triangle for roots, claims blocked rock points, carries the sheet's interpolated shading normal to shared moss colouring, and checks clump footprint support.
- A real-character replay at photo 4 is running against original production before the candidate. Test and visual closure remain pending.

- Withdrawn acceptance claim: all twelve recoverable camera poses inspected against matched baselines and pixel differences, plus approximate image 1 context. Native audits and uphill/downhill replay pass; three unrelated legacy test failures reproduce on original production sources. See [final evidence](result.md).
