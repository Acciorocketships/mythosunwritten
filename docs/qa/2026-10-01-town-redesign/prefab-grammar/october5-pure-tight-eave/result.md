# Pure Village eaves beside raised walks

## Accepted repair

The reduced-overhang Pure Village profile used an unshifted native slope piece whose foot still projected 0.298138 m beyond its nominal wall plane. Public headroom consequently cut off its edge. The frozen experimental 301/grand landmark had five affected pieces, and the accepted live 9/grand had three affected bridge eave pieces.

The kit now seats the complete tight course 0.3 m inward and 0.45 m upward along its authored 3:2 plane. Start/end caps and tight dormer stock share that placement. The roof retains its scale and pitch. An existing timber crossbar, with a deeper section and the house's finish, closes the resulting wall-head joint. Ordinary projecting eaves are unchanged.

The first translated-course experiment passed the public-air test but failed visual inspection: its uphill backing emerged through the opposite roof slope just below the ridge. It is preserved in `rejected-slide/`. The accepted assembly ends that shifted surplus at the original upper course joint, using the existing roof union; the visible foot and end finish remain whole. On deeper roofs the same rule meets the next unchanged row, and on a two-module roof it meets the ridge. `BuildingKit.tight_eave_joint_clip` describes this kit-specific requirement; the assembler handles both axes and both roof sides.

## Reproduction and evidence

`tests/fixtures/october5-interior-court-landmark-source.txt` freezes the archived interior-square candidate at 301/grand. The candidate route/frontage/support code was installed only while recording the fixture, then all accepted source bytes restored. The larger layout experiment remains unaccepted.

Affected owner: `kit.spatial.feature.landmark.00`, roof rectangle (4,-6), size(3,2), axis0, eave band4. Its south foot is native z-8, y6. Fixed world cameras:

- `eave`: eye(20,13.7,-10), target(20,14,-20), FOV70.
- `seam`: eye(29,14,-11), target(20,13,-18), FOV65.

```
/Applications/Godot.app/Contents/MacOS/Godot --path . -s tests/harness/suntail/kit_town_review.gd -- --cities 301:grand --frozen-source res://tests/fixtures/october5-interior-court-landmark-source.txt --views overview --view eave:20,13.7,-10:20,14,-20:70 --view seam:29,14,-11:20,13,-18:65 --output /tmp/pure-tight-eave-review
```

The automatic landmark camera was inside another building; it was not used for acceptance. The explicit close views above show the actual foot, wall closure, upper joint and end cap. Matched `before/` and `after/` plus the rejected intermediate render are retained. Live 9/grand overview and courtyard views were also inspected in `holdout/`.

## Checks

- Red-first native triangle test: body/start/end all lose geometry to walking air before the seat change (3 failed assertions). Afterward all retain their complete feet.
- Three final regressions  / 33 assertions pass: native public-air clearance, backing at row/ridge joints for depths 2/3/4 on both axes, and the native fascia's overlap with wall and roof.
- Active falsification: disabling only the joint cut reproduces six seam failures, with up to 0.576198 m of backing beyond its joint. Candidate bytes were restored before final tests and renders.
- Focused suite: 22 selected tests pass across Pure tight seating, Suntail tight seating, native/mixed Pure roofs and the raised-court ridge regression. This does not imply the whole repository suite is green.
- Frozen 301 audit: clipped eaves 5→0; no new gable holes, exposed ends, unsupported roofs or uncapped towers. Roofs 62, tiny roofs 4 (two adjacent), turrets 4 are unchanged by this repair.
- Live 9 audit: clipped eaves 3→0, with zero gable holes, tiny roofs, exposed ends, unsupported roofs and uncapped towers. Roof count 40 and turrets 4 remain unchanged.
- Actual player: all four square approach/loop traversals pass in both directions on frozen 301. See `court-walk.json`.
- Live 8 audit unchanged: one existing four-sample gable hole in house.041 and three tiny roofs, no clipped eaves. That hole remains open work.

The remaining four tiny wings in frozen 301 are on house.018 and house.043, two at each stepped crown. They still prevent architectural acceptance of the larger square experiment. More fitting spires, enclosed circulation, broad interior deck squares, and overall world-level art acceptance remain required by the original goal.
