# Cliff root geometry, local cuts and lower terraces — September 17

The added stone now eases geometrically out of the actual native wall, rather than crossing it at full slope while relying on blended normals. Short oblique recesses add another physical detail scale. A third family of finite lower ledges and stronger localized feet add lower terraces; convex corners retain more of their lower source shoulder. Upper attenuation, variable crown coverage, native palette and turf material remain in place.

This addresses the latest owner request and C01–C04 in the [original screenshot register](../../2026-09-16-manual/issues.md). This is an incremental production repair, **not final art acceptance**. Broad faces in the close P12 view still look softer than the canyon reference. Tall constructions still expose repetitive native courses and too many similarly sized masses. Those art concerns remain open.

## Evidence and rejected iterations

The frozen production context retains seed **2697992464**, actual saved cliff anchors, original terrain/grass/lighting, and ReviewCam-derived P05/P12/P17/P20 reported and ±8-degree poses. Five front/side/oblique controls supplement the twelve reported views. All seventeen final views were inspected. Frozen placement does not prove current hydraulic admission or ground seating.

- `candidate/` and `iteration-01/` show the first candidate: smaller broad bump amplitudes, narrow eligibility for enlarged feet, short cuts and root easing. The first directory retains the previous corner recipe; the second rebuilds corners too. Its corner height-variation check fails. The corresponding initial straight fixture is `softened.gd`.
- `sharper/` lowers the smoothing crease angle from 50 to 35 degrees. It exposes triangular wedges in P12 instead of producing natural crags. **Rejected visually**, regardless of test scores.
- `corner-check.log`, `corner-check2.log`, and `corner-check3.log` retain the failed attempts. Eligibility/bump corrections alone do not restore the affected corner. The final corner retains its full lower source relief before the existing asymmetric modulation, while the upper face keeps its previous attenuation. No test threshold was relaxed.
- `final/` restores original broad/fine bump amplitudes, expands the original localized feet, retains the new cuts and finite ledge family, and includes the corrected corners. P17 has a fuller lower corner; P20 retains an irregular rooted edge. Root joins no longer depend solely on a shading correction.

| View | Previous production | Current production |
|---|---|---|
| P12 front, joins and terraces | [Before](../11-cliff-body-crags/final/P12_front.png) | [After](final/P12_front.png) |
| P12 original close view | [Before](../11-cliff-body-crags/final/P12_reported_0.png) | [After](final/P12_reported_0.png) |
| P17 corner and lower shoulder | [Before](../11-cliff-body-crags/final/P17_reported_0.png) | [After](final/P17_reported_0.png) |
| P20 lower edge | [Before](../11-cliff-body-crags/final/P20_oblique.png) | [After](final/P20_oblique.png) |

`before.gd` freezes the preceding straight generator. `corner-before.gd` freezes its corner adapter (which imports the production straight generator, so use a matching straight control for historical reproduction). `candidate.gd` matches the selected straight recipe. `unfractured.gd` has exactly the selected mass/ledge/root geometry with fractures disabled, solely for a fair physical-recess diagnostic. The earlier fracture test now uses that matching control for current geometry and preserves the older control for its historical baseline; it does not attribute enlarged feet to fracture depth.

## Verification

[Red test](red.log): the original normalized emergence slope is **1.0**, failing the **0.25** maximum. The final slope is **0.0456**; below/above contact samples remain on their correct sides of actual native relief.

[Final run](final-tests.log): **37 tests / 981 assertions pass**, across twelve focused files.

- Actual thin-join normals average **1.416 degrees** from native normals over **946** samples. This is a geometry-tangent repair; it does not claim a lower normal-error average than the preceding 0.950-degree result.
- At 16, 32 and 64 m wall heights, **19/23** near-crown probes retain exposed relief. The height envelope remains relative to the wall, with variable recesses instead of a fixed strip.
- The long-wall lower survey has **24** broadened positions and ten restrained positions; the preceding result had 21 broadened positions. Maximum sampled projection is **7.714 m**, within the unchanged 8 m guard. Another survey spans **2.694–7.576 m** at the toe and **11.5–15.5 m** at the crown.
- Broad turf area across 31 photo formations rises from **134.963 to 147.183 m²** (about 9%). There are zero hairline turf triangles and zero tiny complete turf islands. Ledges remain finite and occur at eleven sampled heights.
- Matched unfractured geometry confirms half-metre recess coverage of **18.5–33.0%** on the four exposed photo formations, with maximum local cut depth below **1.73 m**.
- **166** crevice plants have zero heavy canopy overlaps. Actual grass-worker sampling retains **30** rooted patches, zero escaped and zero buried roots. Halo ownership remains deterministic.
- Closed shells and nondegenerate corner geometry pass at 16/32/64 m, with four grounded orientations, actual collision, detached worker preparation and complete public/wet footprint exclusions. Gentle connected normal fans remain continuous.

## Fresh production and tall construction

The five final 64 m native construction views in `tall/` were inspected: [front](tall/front.png), [oblique](tall/oblique.png), [close](tall/close.png), [ledge overview](tall/ledges.png), and [wide](tall/wide.png). They retain full-height relief and supported lower shoulders. The tall wall remains too uniform in its overall distribution of similarly sized masses; this is recorded as an art limitation, not accepted as the gold standard. `tall-01/` is the earlier candidate, not the final geometry.

Fresh P12 regenerated through the ordinary world pipeline, waited for terrain readiness, an idle worker and a drained feature queue, then captured the [reported view](fresh-P12/P12_0.png), [−8 degrees](fresh-P12/P12_-8.png), and [+8 degrees](fresh-P12/P12_8.png). All three were inspected. Actual current terrain, ledge grass and crevice plants retain the selected geometry. The broad foreground face remains visibly soft, so this does not close the overall art concern. Together with the seventeen frozen views and five tall controls, **25 final views** were judged.

[Fresh log](fresh-P12.log): startup **426.087 s**, nine terrain chunks. Concurrent tests and a native study make this unsuitable for a performance comparison. The editor-only `global_shader_parameter_get_list` warning comes from the review snapshot helper; all three captures completed. No new runtime performance or actual player-traversal acceptance is claimed.

## Reproduce

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/ryko/story --log-file /tmp/local-crag-context.log tests/harness/september16_cliff_transition_context.tscn -- --corner-study --output=res://OUTPUT
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/ryko/story --log-file /tmp/local-crag-tall.log tests/harness/september17_corner_joint_study.tscn -- --height=64 --output=res://OUTPUT
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/ryko/story --log-file /tmp/local-crag-fresh.log tests/harness/september16_manual_qa.tscn -- --offscreen --grass --single --spot P12 --output res://OUTPUT --camera-poses-root res://docs/qa/2026-09-16-manual/10-rounded-ledges/production-01
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryko/story --log-file /tmp/local-crag-root.log --script addons/gut/gut_cmdln.gd -gtest=res://tests/test_september17_cliff_root_tangent.gd -gexit
```

`STORY_ROOT_GENERATOR` selects a frozen straight fixture for the new emergence test. No water, town, streaming or full-suite acceptance is included in this pass.
