# Cliff turf width and continuity — September 17

Turf now requires actual ledge depth at both ends of a strip. Vanishing shoulders remain stone. A second pass removes tiny disconnected turf islands while retaining pieces that continue across an open canonical owner boundary. Native turf material, biome tint, rock geometry and collision are unchanged by this repair.

This follows the [full-height corner and attachment work](../08-cliff-corner-joints/result.md). It addresses C03 in the [original screenshot register](../../2026-09-16-manual/issues.md), especially P12 and P20, and the later report of streaks across added rocks. It does not accept the overall cliff art: some broad faces remain too soft, thin-looking strips remain in perspective where real narrow ledges survive, and the tall construction still reveals native repetition.

## Matched review

Seed **2697992464**. P12: player **(-439.6, 32, -297.5)**, crosshair **(-438.9, 34.8, -298)**. P20: player **(-482.8, 32, -242.4)**, crosshair **(-482.1, 32, -244.9)**. P17: player **(-443.9, 32, -247.9)**, crosshair **(-446.1, 32, -250.3)**. Reported and ±8-degree poses reuse the saved ReviewCam solutions.

| View | Before | Current |
|---|---|---|
| P17 reported | [Before](../08-cliff-corner-joints/final-body/P17_reported_0.png) | [Current](final/P17_reported_0.png) |
| P12 front control | [Before](../08-cliff-corner-joints/final-body/P12_front.png) | [Current](final/P12_front.png) |
| P20 nearby | [Before](../08-cliff-corner-joints/final-body/P20_reported_8.png) | [Current](final/P20_reported_8.png) |

The first width-only candidate in `context/` removed long hairlines but left small isolated yellow dashes, especially in the P17 foreground. That candidate was rejected as final. The component filter removes those fragments in `final/`, with broad ledges retained. Seventeen final native views cover P05, P12, P17 and P20 plus nearby/front/side controls. Close, oblique and reported views were inspected; the large foreground angular obstruction at P12 also exists in the before capture and remains open.

These are frozen native-world replays with current production crags and crevice plants rebuilt at saved anchors, including production convex corners. Original terrain, grass, atmosphere and collision are retained. They do not establish fresh hydraulic admission, regenerated ground seating, live traversal, streaming or frame-time acceptance.

## Red-first evidence and controls

- [Initial red](red.log): the 31 photographed formations contain **2,157** turf triangles with less than 0.20 m ledge depth. The current count is **zero**.
- Width-only rejection: [corrected red component test](dashes-red-corrected.log) reproduces **32** small complete islands. An earlier diagnostic used world bounds for a local boundary comparison; `dashes-red.log` is superseded by the corrected run.
- Final native turf area is **167.113 m²**, versus **208.169 m²** before; broad ledge area is **135.558 m²**, versus **140.946 m²** before (**96.18% retained**). Tiny complete islands below 0.35 m²: **zero**.
- All physical stone vertices in the 31 formations are byte-identical to the pre-repair fixture. Owner-cut controls preserve a small shared piece but remove the same isolated piece at a real cliff end.
- [Final tests](final-tests.log): **8 tests / 773 assertions pass**. [Added owner-cut case](owner-cut.log): **1 test / 2 assertions pass**. [Support controls](support-tests.log): **9 tests / 26 assertions pass**. Total: **18 distinct tests / 801 assertions**.
- Actual grass-worker sampling retains **32 rooted patches**, with zero escaped or buried roots. Plant spacing retains **166 plants**, zero heavy overlaps and all 31 formations planted.
- Existing attachment controls retain approximately **0.975 degrees** mean native-normal disagreement over 829 thin-join samples. Upper relief covers **19/23** probes at each of 16, 32 and 64 m wall height. Lower-shoulder controls retain 21 widened and ten restrained samples, with maximum projection **7.695 m**. These are bounded construction checks, not an aesthetic score.

## Reproduce

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/ryko/story --log-file /tmp/cliff-turf-context.log tests/harness/september16_cliff_transition_context.tscn -- --corner-study --output=res://OUTPUT
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryko/story --log-file /tmp/cliff-turf-tests.log --script addons/gut/gut_cmdln.gd -gtest=res://tests/test_september17_cliff_turf_width.gd,res://tests/test_september16_carved_ledges.gd,res://tests/test_september17_cliff_plant_spacing.gd,res://tests/test_september16_cliff_grass.gd,res://tests/test_september17_crag_normal_fans.gd,res://tests/test_september16_cliff_transition.gd -gexit
```

The frozen `tests/fixtures/september17/cliff-turf/before.gd` reproduces the original eligibility; `width-only.gd` retains the rejected intermediate candidate.
