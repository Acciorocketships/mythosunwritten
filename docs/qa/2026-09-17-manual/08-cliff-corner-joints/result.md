# Cliff corner integration — September 17

The added rock now continues around exposed convex native corners. Previously the production pass dressed only straight walls, leaving an obvious repeating column at the turn. Corner relief uses the actual native corner depth and normals at thin attachments, then transitions to independent crags. A longer, irregular rock composition spans the turn so ledges end separately instead of wrapping into rings. The shoulder is broader toward the ground; contiguous native rows determine the full available height.

This is a scoped improvement to attachment and coverage. Overall cliff art remains open: some straight faces are broad and soft, thin turf strips remain visible, and the tall study still exposes native repetition near the crown. This does not establish the canyon reference's overall composition or approve all earlier issues.

## Matched game review

Seed **2697992464**. Primary P17: player **(-443.9, 32, -247.9)**, crosshair **(-446.1, 32, -250.3)**. Original and ±8-degree poses reuse the saved ReviewCam solutions. P05, P12 and P20 are retained as neighboring controls.

| Before | Current |
|---|---|
| ![Undressed native corner](../07-cliff-weathering/accepted/P17_reported_0.png) | ![Crags continuing around the corner](final-body/P17_reported_0.png) |
| ![Nearby before](../07-cliff-weathering/accepted/P17_reported_-8.png) | ![Nearby current](final-body/P17_reported_-8.png) |

The final replay contains **17 native views**, using current production corner generation and rendering at saved anchors. It retains frozen terrain, grass, atmosphere and collision. It does **not** rerun world streaming, hydraulic admission, fresh photo-site seating or character traversal. The foreground angular obstruction in P12 is also present in the before image; it remains open.

Five [fresh 64 m construction views](tall-body/front.png) exercise full-height native wall/corner stock. They show better independent upper-corner relief than the [rejected shallow body](tall-corrected/front.png). The initial `tall/` set has an incorrectly placed second arm and is excluded; `tall-corrected/` fixes the harness geometry and framing before comparing the body change.

## Verification and rejected candidates

- [Baseline red](red.log): the production diagonal corner has **0/5** height probes carrying independent relief. Current production has **4/5**.
- The first expanded study avoids rings but one photographed short corner has only 0.566 m depth variation. Its lower shoulder is widened; all four photographed corner columns then retain variable depth and relief at **4/5–5/5** sampled heights.
- The first production candidate still collapses into a native tile strip on tall walls. Restoring body thickness through the deeper native corner reduces insufficiently projected upper samples from **6/12 to 2/12**. Individual native courses are borrowed only through the thin-root blend; thicker stone gets a mean depth correction.
- [Final corner tests](body-tests.log): **9 tests / 37 assertions pass**. Closed, nondegenerate triangles at 16/32/64 m; native normal and shader-weight agreement; detached-worker determinism; buried feet in all four orientations; complete public/wet exclusions; identical independent chunk ownership; final tall-body regression.
- [Existing controls](controls.log): the 14 straight-cliff, transition, foliage, turf and water-margin tests pass (412 assertions). The same run caught a test tolerance error in the new corner weight comparison: Godot stores vertex color in 8-bit channels. [Corrected packing test](normal-packing.log) passes within one 8-bit step, and the final nine-test run includes it. The initial combined log is not an all-green run.

The production integration uses ordinary owner/halo, footprint reservation, grass support, plant and actual-triangle collision paths. Native corner samples prepare once on the main thread; workers consume detached arrays. No startup, global frame-time or full-suite acceptance is claimed.

## Reproduce

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/ryko/story --log-file /tmp/corner-context.log tests/harness/september16_cliff_transition_context.tscn -- --corner-study --output=res://OUTPUT
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/ryko/story --log-file /tmp/corner-tall.log tests/harness/september17_corner_joint_study.tscn -- --height=64 --output=res://OUTPUT
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryko/story --log-file /tmp/corner-tests.log --script addons/gut/gut_cmdln.gd -gtest=res://tests/test_september17_cliff_corner_joints.gd -gexit
```
