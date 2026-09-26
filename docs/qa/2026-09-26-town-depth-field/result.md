# Town depth and shared layout field — September 26

This pass follows the roof joining / inhabited passages change at `7977b85d`. It implements the owner's follow-up requests for more projecting windows, balconies integrated into tall buildings, and one architectural generator with a broader range of open and dense layouts. Production choices depend on geometry and seed; no photographed town, camera, or fixture seed is special-cased.

## Changes

- Upper timber faces choose spaced projecting bays on all eligible orientations. Doors, party walls, occupied neighbouring cells and balcony decks keep their clearance. Roofs/decks are established before facade choices, so bays cannot consume a balcony doorway or its walking surface.
- Wide private upper rooms can recess two or three modules into L/U-shaped balconies. Lower rooms supply their floors; alternating upper rooms supply ceilings. Recesses keep side/back walls, connected rooms, existing entrances and the public route. Public balcony platforms use short diagonal wall braces and underside beams, including diagonal bearing at outside corners, instead of poles descending several storeys to terrain.
- `VillagePlan` now uses the same volumetric pipeline for every settlement. Population labels and size budgets remain record metadata; they no longer select a separate square-hamlet architectural generator. The old hamlet constructor remains available to historical fixtures only.
- `WarrenTownField` samples overlapping elliptical Gaussian lobes, a broad clearing, independent spread/density/height and coherent boundary noise before any passage boring. Low shoulders connect the route domain without making every gap a tall block. Missing columns are explicit air. Existing terrace/riser rules and the inhabited passage/skywalk pipeline remain in charge of construction.
- New layouts exposed integration issues fixed here: reclaimed courts may connect only real stair landings; new room projections reserve bracket clearance above markets; retained-ground boolean markers are not stone tags; an exhausted legacy gable falls back to the validated plate solver before native kit roofs replace it; source air survives expanded stair/room envelopes (public route ownership wins where both describe the same void); roof audit labels refresh after destination pruning.

## Visual review

The gallery uses native Suntail geometry/materials and fixed camera/light settings. `tests/fixtures/town_depth_before_masses.var` contains four architecture masses produced with the exact designer and kit adapter at `7977b85d`: gallery seed 11, indices 0–3, alternating 6×4 / 7×4 footprints and three / four storeys. The current production adapter builds the matching `loggias` gallery. This is a controlled facade study, not a saved whole-world replay.

[Matched facade comparison](comparison-b01_a.png) and [opposite corner comparison](comparison-b01_b.png) include magnified pixel differences. Ground/camera remain stable. The new recesses, their room ceilings/floors and separated bays are visible from the opposite corner; the old long shallow projection is gone. Full-size before/after/difference PNGs and changed-pixel counts are beside this report. All eight gallery angles were captured; these two are retained as the principal pairs.

Final town captures use the actual planner/compiler at `3:standard`, `16:grand`, `6:grand`, and `16:compact`. They include overviews, four orbit angles, street views and dedicated tunnel captures. The legacy-feature skywalk camera selector finds no applicable feature in these two final tunnel towns, so it supplies no skywalk evidence. Street cameras that face a nearby wall are excluded as circulation evidence. Seed 16 deliberately samples the open end of the distribution; it is not a production exception. Broad gaps and multiple low/high clusters coexist with the dense central district. The reviewed dense town still has tall narrow faces where neighbour/public clearances prohibit a balcony; this pass does not promise a recess on every wall.

## Reproduce

Use `/Applications/Godot.app/Contents/MacOS/Godot` from the project checkout (native rendering requires a GUI session):

```sh
Godot --path . -s res://tests/harness/suntail/building_gallery.gd -- --output /tmp/loggias --set loggias --count 4 --seed 11
Godot --path . -s res://tests/harness/suntail/building_gallery.gd -- --output /tmp/loggias-before --set loggias-before --count 4 --seed 11
Godot --path . -s res://tests/harness/suntail/kit_town_review.gd -- --output /tmp/towns --cities 3:standard,16:grand,6:grand,16:compact --views overview,orbit,street,tunnel,skywalk
Godot --headless --path . -s res://tests/harness/suntail/town_junction_survey.gd -- --compile
Godot --headless --path . -s res://tests/harness/suntail/town_passage_collision.gd
Godot --headless --path . -s res://tests/harness/suntail/town_field_survey.gd
```

## Validation and limits

Red evidence retained here covers the missing multilevel recess/room ceiling, shared production entry point/field, old bay coverage, and market bracket admission. The first bay-count test was too weak; the strengthened all-face/spacing test fails the original designer (206 failing assertions) and passes the new one. Native balcony tests build real collision meshes and probe floors/headroom with the shipped player capsule scaled to native kit units. The 128-seed field distribution test requires both below 45% and above 65% occupied bounding-box area, and more than 2× variation in occupied columns at the same size budget.

The exact old massif-width snapshots were replaced by coherent-plateau/anti-slab bounds while connectivity, riser, height-ladder and terrain support checks remain. Compact crown / skywalk budget expectations were stale already at the base revision and now match its reviewed production values. The four-profile frontage guard is explicitly changed from 0.65 to 0.60 (measured minimum 0.6078), reflecting the requested open ground between clusters; addressed-column and retained-solid guards remain unchanged. The dictionary-order fixture now copies field identity and deliberate-air metadata as well as columns.

Full-world streaming/startup performance and every possible generated town are outside this measured corpus. Routing former hamlets through the richer common pipeline increases their planning work; no startup-speed claim is made. Earlier roof/tunnel evidence remains in the preceding town QA report.

The final combined run has **125 tests: 120 pass, five fail (33,971 / 33,982 assertions)**. All 70 focused architecture/layout/kit/scale/production-entry tests pass. The five remaining adjacent planner failures also fail on base `7977b85d`: spine outward descent, plaza count snapshot, street-floor count/refusal snapshots, a flat-roof stacked-parcel fixture, and sloped frontage/refusal snapshots. The baseline run of those two legacy suites has nine failing tests; the current pass reduces that to five. These are not represented as a clean full-suite result. The new source/volume identity and final roof-label regressions are green.

The volume fix initially exposed an overlap between source voids and fine-route air in `4:large`: daylight subtraction attempted to reclaim an already-public cell. Public route ownership now wins for that shared empty space. The regression compiles with its original 26 roof joins; its native tunnel is included in final collision review.

Final closure: the additional shared-air regression passes in the six-test / 80-assertion layout run, bringing the distinct focused set to **71 passing tests**. The 48-town native-payload survey passes 47 rows, then its one failed `4:large` row passes after the air-ownership fix (`town-air-regression.log`). No other row failed. This is a complete corpus plus a focused repair rerun, not a falsely relabelled zero-failure original log. Nine retained tunnel cells all remain covered. The final native passage run checks **81 capsule positions with zero obstructions**, plus nine upward ceiling rays across eight towns. The native balcony gallery also retains actual floor contacts and capsule headroom.

All three follow-up objectives are implemented in production. The work remains parameterized by seed, size budget and geometric clearance. The five baseline planner-test failures and broad world startup/streaming performance remain outside this acceptance claim.
