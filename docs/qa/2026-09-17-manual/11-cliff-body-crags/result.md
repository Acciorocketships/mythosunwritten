# Geometric cliff fractures — September 17

The finite fractures in the added cliff stone now cut deeper into the broad rounded faces. Horizontal clefts and shorter vertical splits produce actual recessed geometry and sharper breaks. Outcrop widths, mass sizes, ledge placement, upper-height envelope, native attachment blend and the stone shader remain unchanged. The existing triangle collision follows the revised rock faces.

This follows the owner's report that added stone was smoother than the wall, together with C01/C02 in the [original register](../../2026-09-16-manual/issues.md). It improves the crag detail without returning to giant rounded masses or enlarging every outcrop. Overall art remains under review: native repetition still appears in the tall construction and some broad faces remain soft. This is not full acceptance of the canyon reference or the original judging pass.

## Visual iteration

The matched frozen replay uses seed **2697992464**, the actual photographed production anchors, and saved ReviewCam-derived P05/P12/P17/P20 reported and ±8-degree cameras. Five additional front/side/oblique controls supplement those views. Exact original coordinates and image links remain in the register.

1. `stronger/` increases broad and fine bump amplitudes together with a small cleft increase. It measures greater curvature, but P12 still looks swollen and soft. Rejected. More numerical roughness is not an art pass.
2. `fractured/` deepens the finite clefts while retaining the existing broad/fine amplitudes. P12 and P20 gain clearer breaks through their large faces. This fixture replay changes straight formations only; corners remain the production control.
3. `final/` rebuilds both straight and convex-corner formations with the production change. Seventeen captures complete. P17's corner retains native contact and has deeper local cuts; broad lower shoulders remain. Five fresh 64 m native construction views in `tall/` check height scaling and corner composition. They retain full-height relief, though repeated native courses and broad patch sizes are still visible.

| View | Before | Production candidate |
|---|---|---|
| P12 front | [Before](../09-cliff-turf-width/final/P12_front.png) | [Current](final/P12_front.png) |
| P20 oblique | [Before](../09-cliff-turf-width/final/P20_oblique.png) | [Current](final/P20_oblique.png) |
| P17 reported | [Before](../09-cliff-turf-width/final/P17_reported_0.png) | [Current](final/P17_reported_0.png) |
| 64 m close | [Before](../08-cliff-corner-joints/tall-body/close.png) | [Current](tall/close.png) |

Frozen replays preserve original terrain, grass, atmosphere and collision; their current crags/plants are rebuilt at saved anchors. The separate tall study constructs current native wall/corner geometry directly. Neither substitutes for fresh world placement or player traversal.

### Fresh production check

The ordinary world pipeline regenerated P17 and captured the [reported angle](fresh-P17/P17_0.png), [−8 degrees](fresh-P17/P17_-8.png) and [+8 degrees](fresh-P17/P17_8.png). All three were inspected. They retain full-height rock, the larger lower shoulder, grass and crevice plants. The fresh lower corner reads as a substantial vertical buttress; some broad faces and native courses still remain visually distinct. This verifies current placement and rendering at the site, not final overall art acceptance or an actual player traversal.

The harness waited for ordinary terrain readiness, an idle worker and the drained feature queue before freezing the scene. [Fresh log](fresh-P17.log): startup completes in **418.338 s**, nine terrain chunks. Concurrent headless investigations make this unsuitable for a performance comparison. The saved world and sampler data are retained beside the images. The log's `global_shader_parameter_get_list` warning comes from the review snapshot helper after startup; all three captures complete. No production rendering error is inferred from that review-only warning.

## Verification

The [red test](red.log) measures physical recesses on four actual photo formations relative to the same geometry with fractures disabled. Only **2.1–6.1%** of exposed thick samples originally have a cleft deeper than 0.5 m. The final range is **18.6–32.9%**, with maximum recesses **1.61–1.72 m**. The test also bounds the affected fraction and depth so it cannot pass by hollowing away the whole face. This establishes resolved physical detail, not visual beauty.

[Production checks](production-tests.log): **28 tests / 854 assertions pass**. [Additional topology, native seam and variability checks](topology.log): **8 tests / 38 assertions pass**. Total **36 distinct tests / 892 assertions**.

- Straight and convex-corner shells remain closed; corner checks cover 16, 32 and 64 m heights, four grounded orientations, actual collision, detached workers, complete public/wet exclusions and independent chunk ownership.
- Thin-wall normal disagreement remains approximately **0.950 degrees** across **955** measured exposed samples. Smooth connected stone edges have zero unintended shading discontinuities across four photographed formations.
- Upper relief retains **19/23** probes at each tested wall height. Selected widened feet remain **21** samples alongside ten restrained samples; maximum projection remains **7.695 m**. A separate long-wall survey retains a **2.694–7.511 m** foot range.
- The 31 photo formations retain zero hairline turf triangles and zero tiny complete paint islands. Broad turf area is **134.963 m²**, or **95.75%** of the old striped baseline and **99.56%** of the preceding turf-cleanup version.
- Actual grass-worker sampling retains **29** rooted patches with zero escaped or buried roots. Crevice planting retains **166** plants with zero heavy overlaps; all 31 formations remain planted. Changing the stone contact legitimately changes some plant and grass positions.
- The old turf-only vertex-equality proof now explicitly compares its two frozen versions. It does not claim that this deliberate physical fracture change preserves every vertex. Current topology, support, collision and material-cap tests cover the changed geometry instead.

No new shader work, runtime timing claim, global performance claim or full-suite acceptance is included.

## Reproduce

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/ryko/story --log-file /tmp/crag-body-context.log tests/harness/september16_cliff_transition_context.tscn -- --corner-study --output=res://OUTPUT
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/ryko/story --log-file /tmp/crag-body-tall.log tests/harness/september17_corner_joint_study.tscn -- --height=64 --output=res://OUTPUT
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryko/story --log-file /tmp/crag-body-test.log --script addons/gut/gut_cmdln.gd -gtest=res://tests/test_september17_cliff_body_crags.gd -gexit
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/ryko/story --log-file /tmp/crag-body-fresh.log tests/harness/september16_manual_qa.tscn -- --offscreen --grass --single --spot P17 --output res://OUTPUT --camera-poses-root res://docs/qa/2026-09-16-manual/10-rounded-ledges/production-01
```

`tests/fixtures/september17/cliff-body-crags/before.gd` is the exact preceding production generator. `stronger.gd` retains the rejected bump candidate; `fractured.gd` retains the selected straight-face study. `unfractured.gd` is solely a diagnostic control, not an alternative art proposal. `STORY_BODY_GENERATOR` allows the focused test to exercise a fixture.
