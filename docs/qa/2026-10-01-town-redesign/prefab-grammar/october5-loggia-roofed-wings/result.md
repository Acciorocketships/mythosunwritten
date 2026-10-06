# Lower roof wings survive balcony recesses

The four remaining tiny roof sections in frozen experimental 301/grand were caused by balcony recesses applied after stepped-wing shaping. House.018 had a complete 2×2 lower wing at eave band 15; house.043 had a 3×2 wing at band 9. Removing their front bays left L shapes that packed into one-module strips and small intersecting gables.

`KitLoggias` now checks the existing `crown_parts` before accepting a recess. A previously roofable lower pavilion must retain a nonempty crown that decomposes into complete roof sections at least two modules across. Other faces and broad roofable crowns remain eligible. This preserves the inhabited wing and its normal roof assembly instead of hiding roofs or filling reserved public space. It applies to generated buildings generally, without seed or house exceptions.

## Evidence

The archived interior-square route experiment remains unaccepted. Its frozen source is `tests/fixtures/october5-interior-court-landmark-source.txt`; these repairs do not install that layout in production.

Matched Godot views are under `before/`, `after/`, `before-nearby/` and `after-nearby/`. Cameras (world coordinates, FOV55):

- house.018: eye(-17,57,16), target(-4,45,2).
- house.018 reverse: eye(-16,56,-11), target(-5,45,2).
- house.043 north: eye(1,38,-58), target(4,27,-38).
- The initial house.043 camera eye(-13,39,-20), target(4,27,-38) was obstructed by another building; it is retained but is not acceptance evidence.

The lower sections now read as full stepped pavilions joined to taller hosts. The reverse view also shows the retained matching corner turret. This does remove the destructive balcony notch on these narrow wings; other supported balconies remain. Existing window/facade repetition is not considered solved by this roof repair.

## Validation

- Red-first test reproduced 30 tiny pieces across 24 two-module-wing samples. Extended coverage includes both two- and three-module wings, plus a broad L crown that remains roofable.
- Final new tests: 2 tests / 3 assertions pass.
- Disabling the new guard reproduces 69 tiny pieces across the extended samples (1/2 tests fail). The broad L-crown check passes. This final falsification uses a temporary mutant copy; production source remains unchanged. Baseline output for the older street-loggia failure is also retained.
- Focused street-loggia/stepped-wing suite: 13/14 tests, 956/957 assertions pass. The remaining expectation of two recessed levels also fails with the new guard disabled (one level); it is an existing failure, not silently weakened.
- Frozen 301: roofs 62→60, tiny sections 4→0, adjacent tiny sections 2→0. Gable holes, exposed openings, unsupported roofs, clipped eaves and uncapped towers remain zero; four corner turrets remain.
- Live 8: roofs remain 50; tiny sections 3→1, adjacent tiny sections 1→0. Its existing four-sample hole on house.041 remains. Turret count stays one.
- Live 9: roofs 40, no tiny sections, no gable holes, clipped eaves or unsupported roofs, four turrets: unchanged.

- Actual player: four square/deck approach-and-loop traversals pass, including both directions. See `loggia-court-walk.json`.

Broader interior-square layout acceptance, the outstanding gable hole, spire supply and enclosed circulation remain active work. The roof audit is not evidence that the whole redesign or the world-level art review is complete.
