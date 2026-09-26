# Town architecture and wood roofs — September 26

Work isolated on `codex/town-shapes-wood`, based on `main`. The active cliff/grass work in the primary checkout was not part of this change.

The reported hamlet is seed **2697992464**, player **(235.1, 12.0, 449.2)**, crosshair **(227.2, 12.0, 468.0)**. `village_site_capture --reported` uses `ReviewCam.solve_cam` with the current tactical distance/height (26/16 m, focus +1 m). The resulting before/after pose is fixed; it reproduces the site rather than claiming pixel-identical framing to the older owner capture. Eight additional orbit cameras share a 65 m radius and 32 m height.

## Changes

- The production hamlet/outskirts adapter previously repeated a rectangle on every floor. Lot houses now select left/right L wings, central T wings where space permits, and offset upper-floor wings. Shapes stay inside the reserved module rectangle; floor count and planned entrance side are retained. Tiny lots keep their compact rectangular rooms and low roofs.
- Exposed lower crowns become railed balconies with a house door; shifted upper rooms receive underside boards and brackets within one module of lower bearing. The existing sealed warren continues to own its floor plans and circulation.
- Street-facing roof wings take priority over rear wings. A native rear-angle review caught a cross-gable fin in the first candidate; the ridge-height regression was red before the longitudinal partition fix and green afterward.
- More eligible door canopies, window boxes, ivy, chimneys and selected ridge details. Flush fronts alternate with jetties rather than giving almost every house the same inset base.
- Both vendor roof finishes, including bay/dormer surfaces, use the pack's **Boards** albedo and normal textures, in warm brown and weathered brown. Historical red/blue catalog IDs remain stable. The manifest and baker's `material_textures` field reproduce the replacement; portable resources do not depend on source-pack files at runtime. Geometry/collision and catalog membership did not change during the bake.

## Verification

The original floorplate regression fails because the lot adapter makes no compound or changing floorplates. The first roof candidate also fails the independent host-ridge check. Final GUT results: **34/34 tests, 3,301 assertions** (`final-tests.log`); tests include real native collision rays on roof crowns and balcony floors, connected rooms, intact entrances, lot containment, projection bearing, wood textures/normals, narrow roofs, kit inventory and hamlet construction.

The existing real-player hamlet harness passes **18/18** square/approach walks, both directions (`walking.json`). This is a flat-ground production hamlet check, not a claim about every possible town route.

The additional outskirts suite passes its doorstep test but retains an existing path-overlap assertion failure: **nine identical assertions fail on unchanged main and the candidate** (`outskirts-baseline.log`, `focused.log`). These concern unchanged planner support envelopes, not the newly generated floorplates. No broad all-repository green claim is made.

Six selected paired gallery views are retained; they cover balconies, opposite sides, cross-roof joins, flowers/canopies, and both wood tones. Compact seed 1 and standard seed 2 native town views check the shared dressing/material path. Both full native runs completed all nine chunks and nine captures. The retained reported view plus orbit 0/2/4/6 pairs show the new balconies, stepped rooms, roof wings, wood surfaces and intact square/approaches. The gallery also confirms both wood shades close up. Grass, particles and frame timing remain live, so pixel differences are review aids rather than a zero-difference terrain guarantee.

## Reproduce

```sh
Godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/test_town_architecture.gd,res://tests/test_building_kit.gd,res://tests/test_september10_hamlets.gd,res://tests/test_environment_bake_geometry.gd -gexit
Godot --path . -s res://tests/harness/suntail/building_gallery.gd -- --set lots --count 8 --output /tmp/town-lots
Godot --path . res://tests/harness/village_site_capture.tscn -- --seed 2697992464 --at 235.1,12,449.2 --radius 1 --reported --grass --orbit 65,32 --output /tmp/town-site
Godot --headless --path . -s res://tools/environment_bake/environment_bake.gd -- --manifest res://tools/environment_bake/manifests/suntail_village_kit.json --keep-existing
```
