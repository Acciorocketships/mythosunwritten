# Tall cliff composition — September 17

Tall walls now mix occasional larger formations with smaller crags and recessed stretches. Main fractures vary across the available wall height, length and slope instead of keeping approximately four-metre courses everywhere. The change blends in above 16 m and reaches full strength at 64 m. Short-wall stone and turf remain exactly unchanged at the twelve tested height/position combinations.

This continues C01/C02 and the latest owner request in the [original judging register](../../2026-09-16-manual/issues.md). **Overall cliff art remains open.** The close P12 face is still too soft; some thin upper attachments reveal repeated native courses. This is an incremental composition improvement, not acceptance against the canyon reference.

## Selection and visual judgment

The first candidate enlarged too many tall masses and lost the smaller intervals. Scattering fractures and adding regional depth variation improved the tall composition, but applying it to short walls made the photographed faces smoother. Those versions are retained in `candidate/`, `irregular/`, and `context-candidate/` and were rejected. The selected recipe retains short geometry and gradually introduces the tall composition.

Thirty final views were inspected: seventeen amber frozen-world views, three highland views, five 32 m construction views and five 64 m construction views. The amber set uses the original P05/P12/P17/P20 ReviewCam-derived poses and ±8-degree controls plus five front/side/oblique views. All final images are actual Godot renders.

| Control | Before | Selected |
|---|---|---|
| 32 m front | [Before](before32/front.png) | [Selected](selected32/front.png) |
| 32 m oblique | [Before](before32/oblique.png) | [Selected](selected32/oblique.png) |
| 32 m ledges | [Before](before32/ledges.png) | [Selected](selected32/ledges.png) |
| 64 m oblique | [Before](../12-cliff-local-crags/tall/oblique.png) | [Selected](selected64/oblique.png) |
| P12 close regression control | [Before](original-context/P12_reported_0.png) | [Selected](final-context/P12_reported_0.png) |
| P17 corner regression control | [Before](original-context/P17_reported_0.png) | [Selected](final-context/P17_reported_0.png) |
| P20 lower edge regression control | [Before](original-context/P20_oblique.png) | [Selected](final-context/P20_oblique.png) |

The tall studies show longer upright formations between smaller cuts and fewer uniform horizontal courses. The 32 m treatment is deliberately intermediate. Broad soft faces, coarse upper native repetition and the rectangular overall study silhouette remain visible. P17 also retains some jagged diagonal cleft boundaries. These are recorded limitations, not newly accepted features.

The frozen amber formation heights are 4/8/12 m. The P23 highland replay also contains only short formations: 39 at 4 m, 38 at 8 m and one at 12 m. Neither replay demonstrates the tall-wall change; they are regression controls. The representative before/after amber comparisons retain the same visible composition. PNG hashes differ, so pixel identity is not claimed. Exact geometry equality is established separately by the short-wall test.

Frozen replays retain saved terrain, grass, admission and collision while rebuilding the dressing. They do not establish fresh world allocation, current hydraulic clearance or player traversal. No fresh world regeneration or performance comparison was performed in this pass.

## Verification

The initial scale probe already passed the old generator and is retained as `original-scale-probe.log`; it is not red evidence. The subsequent [red test](red.log) measures actual front geometry against matching unfractured geometry: only one original column retains eight metres of exposed stone between main fracture clusters, below the required eight. The selected generator retains 22 such columns. The separate size-mixture guard retains 21 large-formation columns and 17 smaller intervals; it rejected candidates that enlarged almost everything. These measurements constrain the reported repetition, not artistic quality.

The [focused run](focused-tests.log) covered forty tests across thirteen files, with one historical-control failure. That control imported the live straight generator and therefore changed with production. `shallow-body-control.gd` now freezes both its corner adapter and turn-start straight generator; no threshold changed. Its [targeted rerun](corner-control.log) passes. The expanded [short-wall rerun](short-check.log) passes 24 assertions for 4/8/12/16 m at three positions.

Across the focused run and those targeted replacements, **40 distinct tests / 1,008 assertions pass**. This was not a single clean full run. Retained checks include:

- Physical emergence slope 0.0456 and actual thin-join normal difference averaging 1.416 degrees over 946 samples.
- Near-crown relief at 19/23 probes for 16, 32 and 64 m walls.
- Twenty-four broadened lower positions and ten restrained positions; deepest sampled projection 7.714 m, within the existing 8 m guard.
- Finite turf ledges at eleven sampled heights, supported crevice plants and zero heavy canopy overlaps among 166 plants.
- Closed nondegenerate corner geometry, actual collision, four rooted orientations, detached worker preparation, public/wet exclusions and consistent halo ownership.

## Reproduction

`tests/fixtures/september17/cliff-scale/before.gd` and `corner-before.gd` freeze both original layers. `selected.gd` matches production, and `selected-unfractured.gd` disables fractures only for the physical recess comparison. Rejected fixtures remain separate.

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/ryko/story --log-file /tmp/cliff-scale-64.log tests/harness/september17_corner_joint_study.tscn -- --height=64 --output=res://OUTPUT
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/ryko/story --log-file /tmp/cliff-scale-context.log tests/harness/september16_cliff_transition_context.tscn -- --corner-study --output=res://OUTPUT
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryko/story --log-file /tmp/cliff-scale-tests.log --script addons/gut/gut_cmdln.gd -gtest=res://tests/test_september17_cliff_scale.gd -gexit
```

For the original red comparison set `STORY_SCALE_GENERATOR=res://tests/fixtures/september17/cliff-scale/before.gd` and `STORY_SCALE_CONTROL=res://tests/fixtures/september17/cliff-scale/before-unfractured.gd`. The study and context harnesses accept both `--generator` and `--corner-generator` to freeze both historical layers. Other original judging issues remain tracked in the register.
