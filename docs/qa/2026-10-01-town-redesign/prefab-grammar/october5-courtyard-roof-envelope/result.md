# Roof ridge clearance beneath raised squares

## Scope and outcome

The photographed green ridge in the rejected 9/grand interior-square layout is repaired independently of that layout experiment. The larger route/frontage/support candidate remains archived and unaccepted. This is a roof admission repair, not completion of the town redesign or an increase in square/spire/skywalk supply.

`BuildingDesigner._roof_fits` reserved only nominal slope height, rounded with a 0.15-band allowance. Pure Village's ordinary ridge reaches 0.76906 native metres above the even-depth slope peak; Suntail's reaches 0.313463. A roof whose slope nominally stopped at an upper square could therefore enter its planting bed. Walking-air clipping protected the perimeter but not the lawn.

`BuildingKit.roof_clearance_height` now includes the measured ridge head and the kit's existing odd/even pivot lift. `_roof_fits` reserves every band reached by that complete peak. The existing alternate-axis, shallow-pile and closed-deck fallbacks remain responsible for a crown that cannot take a pitched roof. No mesh, texture, or source asset was replaced; the room beneath the square remains present.

## Exact reproduction

Frozen CPU source: `tests/fixtures/october5-interior-court-bed-source.txt`, generated from the archived final interior-court candidate for 9/grand. Production does not load the fixture. The visible intrusion was `kit.spatial.parcel.maze.house.028/k0114`, a sage Pure Village ridge at native x14..16, y12..12.769, z around -2. A separate skywalk roof also reaches this elevation; the visible green piece was the house, correcting the initial skywalk attribution.

The plaza is the nine macro columns x3..5, z-2..0 at band8. Its native surface is y12 (world y24). Matched camera: eye (44,25.7,-4), target (29,26.5,-6), FOV80. Opposite and both side views were also captured. `native-before/` and `native-after/` retain all eight courtyard/deck views. The checked-in review and traversal harnesses now accept `--frozen-source`:

```
/Applications/Godot.app/Contents/MacOS/Godot --path . -s tests/harness/suntail/kit_town_review.gd -- --cities 9:grand --frozen-source res://tests/fixtures/october5-interior-court-bed-source.txt --views courtyard --output /tmp/court-roof-review
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tests/harness/suntail/nested_gate_walk.gd -- --seed 9 --profile grand --frozen-source res://tests/fixtures/october5-interior-court-bed-source.txt --courts --output /tmp/court-roof-walk.json
```

Run the traversal command again with `--skywalks` in place of `--courts` to exercise crossings and bored underpasses. The flags select separate route sets.

## Verification and limits

- New regression: 3 tests / 18 assertions pass. The red run fails for both kits and the exact photographed ridge. The tests also measure assembled even/odd ridge assets independently of the declared envelope and retain a room below the bed.
- Active falsification: temporarily restoring only the old `_roof_fits` calculation reintroduces both failed admission assertions and `house.028/k0114`. Candidate bytes were restored in `finally` before final review/traversal.
- Existing focused suite: 10/12 tests pass, 10,581/10,583 assertions. Both failures are the existing highest-tier expectation (4 versus 8) in `test_october2_elevated_courtyards`; both reproduce with the old calculation. Do not report this suite as green. Native prefab reconstruction, six-town finished walking-air checks and frozen skywalk-canopy clearance pass.
- Actual-player checks on the frozen town: all four square approach/loop traversals and ten skywalk traversals pass (both directions). This fixture emits no additional bored-underpass traversal cases; do not count these as tunnel checks.
- Additional roof audits: accepted 301/grand, 8/grand and 9/grand retain zero exposed roof ends, unsupported air roofs and uncapped towers. 301 has no tiny roofs, gable holes or cut eaves. 8 retains its existing house.041 four-sample gable hole; 9 retains three existing clipped bridge eaves. Frozen candidate9 has no tiny roofs, gable holes or clipped eaves after the repair. See `court-envelope-audit.json`.
- The stricter envelope changes roof choices: accepted301 has 49 roofs, 8 has50, 9 has40. This repair is not a claim that roof variety or turret supply improved. Native overviews of301 and9 were inspected (`live-after/`). More spires, more enclosed circulation and wider interior squares remain separate open requirements.
- The isolated harness still displays planted beds as plain green surfaces; production grass quality and the small existing lawn-edge wedges are not validated or repaired here.

The archived square candidate must still pass its other native roof and passage issues before promotion. Do not re-enable it on the strength of this selected courtyard repair.
