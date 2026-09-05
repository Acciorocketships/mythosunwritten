# Village manual review — September 5, 2026

Seed: **2697992464**. All 14 marked details passed the final matched visual review.
Broader regression-suite exceptions are recorded separately below. The F3 overlays contain rounded
player/crosshair positions, not full camera transforms. The reproduction harness
uses `ReviewCam.solve_cam`; matched renders use identical reconstructed cameras,
plus ±8° views and alternating 1.5 cm camera offsets. Original annotations remain
the authority for the location of each defect. Pixel change alone is not acceptance.

## Issue inventory

| IDs | Original annotated image | Player world | Crosshair world | Individual details |
|---|---|---|---|---|
| A1–A3 | [10:57:38](</Users/ryko/Desktop/Screenshot 2026-09-05 at 10.57.38 AM.png>) | (259.8, 5.0, 299.5) | (260.1, 5.2, 299.3) | A1 left stone junction slit; A2 central stone junction slit; A3 cream facade fin beside right doorway. |
| B1 | [11:00:18](</Users/ryko/Desktop/Screenshot 2026-09-05 at 11.00.18 AM.png>) | (239.0, 17.1, 295.4) | (238.6, 17.3, 295.4) | Upper room appears borne only at its lower edge, with no face bond or visible diagonal support. |
| C1–C8 | [10:58:10](</Users/ryko/Desktop/Screenshot 2026-09-05 at 10.58.10 AM.png>) | (308.9, 4.2, 275.5) | (309.1, 4.4, 275.2) | C1–C4: four circled vertical facade/stone fins, left to right. C5 rear-left abrupt slope; C6 foreground-right abrupt slope; C7 inner path-corner staircase; C8 outer path-corner staircase. |
| D1–D2 | [10:59:49](</Users/ryko/Desktop/Screenshot 2026-09-05 at 10.59.49 AM.png>) | (239.4, 17.1, 300.1) | (239.6, 17.3, 300.4) | D1 coplanar overlap/flicker beneath near-left railing; D2 angular lawn cut-out and wood intruding on right. |

## Working sequence and acceptance

1. A1/A2 — trace retained-wall joint ownership, require closed joints without
   adding unclaimed building cells or blocking passages.
2. A3/C1–C4 — trace authored facade geometry and handed framing, consolidate
   alignment instead of adding more cover-up posts.
3. B1 — inspect the actual room bearing chain; use a real face bond or a measured
   support course which clears the public route, not invisible support.
4. C5/C6 — compare town grade controls with normal terrain slope controls and
   transition length; unify the final field rather than introducing ramp geometry.
5. C7/C8 — preserve one path/ground surface while fitting the actual continuous
   painted boundary instead of classifying whole triangles into stair-step pixels.
6. D1/D2 — inspect ownership at turf/plank/transition seams, eliminate duplicate
   surfaces and invalid clipping controls, then inspect repeated/jittered captures.

Before captures: `artifacts/qa/2026-09-05-manual-pass/before/`.
Harness: `tests/harness/village_september5_qa.tscn`.

## Investigation and judgments

### A1/A2 — retained masonry junctions

- **Rejected iteration 1:** checkerboard-only corner handling did not change either
  photographed slit. The pictures identify concave joints of an L-shaped mass.
- **Accepted iteration 2:** a single four-cell occupancy rule emits one timber
  joint for a concave corner or diagonal-only contact; ordinary straight seams and
  buried vertices emit none. No building cell is added. The member fills the
  measured recessed wall thickness, not a guessed camera-dependent offset.
- Two focused tests pass (8 assertions). Both matched close-ups show the openings
  closed; the side-angle render also shows closed joints. The diff changes the
  joint itself, not just lighting. A3 remains visibly open as a separate issue.
- Evidence: `artifacts/qa/2026-09-05-manual-pass/joints-review/01-stone_joints_facade-comparison.png`
  and `02-stone_joints_facade-comparison.png`; full captures in `iteration2-joints/`.

### A3 / C1–C4 — facade ends

- **Accepted facing correction:** the shared facade alignment contract now
  presents the authored +Z exterior toward the named boundary. Historical east/
  west poses exposed the back of the plaster. A3 and C3/C4 now show timber
  framing instead of cream return sheets (`facing-review/03-...` and
  `door-corner-review/03-...`, `04-...`).
- **Rejected iterations 4–6 for C2:** finishing only plain/window corners left
  the perpendicular door slab's end sticking through. Iteration 5 also exposed
  an accidental retained-stone asset dependency and failed to render the town;
  that output is explicitly rejected, not counted as a changed/fixed image.
- **Accepted iteration 7 for C1/C2:** full-width wall bays replace half-width
  selections in full-width slots. Plain, window and door panels select finite
  baked corner ends at proved perpendicular joins. Straight repeats stay uncut;
  clipped assets remain subsets of the original clearance envelopes. The
  retained-stone dependency is explicit. Both marked stone ends are clean in
  the matched close-ups and ±8° views. Evidence: `door-corner-review/01-...`
  and `02-ground_slopes_path_edges-comparison.png`, captures in
  `iteration7-door-corners/`.
- Focused corner/facing tests: 5/5, 38 assertions. Bake geometry: 10/10,
  78 assertions. Broader regression checks remain pending.

### B1 — final room bearing

- **Accepted iteration 8:** the room depended on source stone that did not survive
  final construction. A shared six-neighbour ground-connectivity proof now excludes
  edge-only contacts and pitched-roof boxes. Where a root room has lost its bearing,
  four finite timber corner courses must pass the ordinary public-air and measured
  construction clearance checks and reach the local ground or retained mass.
- The matched diff shows the new supports under the unchanged room. Both nearby
  views preserve the connection. A separate ground-level view confirms the posts
  touch the terrain and the room underside, with open space between them.
- Evidence: `ground-frame-review/01-unsupported_room-comparison.png` and
  `iteration8-ground-frame/unsupported_room_ground_contact.png`.
- Focused tests: 7/7, 44 assertions. Broader facade/fabric regression: 54/54,
  122,279 assertions, including handed corner variants.

### C5/C6 — shared ground transition

- Iteration 9 replaces the twice-smoothed fine-cell weight lattice with the
  normal terrain's physical 12 m transition profile and surveys outskirts on
  the finished town ground. C6's narrow bright ridge becomes a broad transition.
  C5 is not yet accepted: narrow dark ridges remain in its close-up, including
  a diagnostic with directional shadows disabled.
- Height samples found a second defect: nearest-pad extrapolation could switch
  between unequal pad heights and manufacture a ridge in their shared collar.
  Iteration 10 continuously blends the actual boundary controls instead. Five
  grading tests pass (5,237 assertions); the earlier terrain suite passed 50/50
  (5,157 assertions). Render-time probes are locating the remaining C5 detail.
- Evidence: `grade-review/`, `grade-boundary-review/`; neither a changed pixel
  nor a relocated house is being counted as proof that C5 is fixed.

- **Accepted visual iteration 11:** both C5 and C6 ridges disappear in their
  matched close-ups and both nearby angles. Outskirts had introduced fractional
  foundation heights next to the town band; they now propose pads on the same
  construction datum before entrance and route checks. A later pad cannot
  overwrite an existing ground claim. The original frozen player pose is below
  the newly raised ground in this diagnostic; the paired camera is unchanged.
- Evidence: `pad-grid-review/05-ground_slopes_path_edges-comparison.png`,
  `pad-grid-review/06-ground_slopes_path_edges-comparison.png`, and
  `iteration11-common-pad-grid/ground_slopes_path_edges_near_left.png` / `near_right.png`.
- Grading: 6/6 tests, 5,766 assertions; outskirts: 12/12, 667 assertions.
  Cold generation performance is being checked separately after removing redundant
  ghost-control bounds evaluation; it is not yet a performance acceptance.

### C7/C8 — smooth path boundaries

- **Accepted iteration 13:** the feature field already defines curved corners,
  but centre-classified 25 cm quads rasterized them into steps. Boundary triangles
  now split at the same field's contour, with shared crossing vertices and no
  extra paint sheet or collision. World roads and house lanes share this rule.
- The matched view and nearby angle show continuous inner and outer edges.
  The inner-corner diff isolates the removed staircase; the outer-edge diff
  is thinner, as expected at this viewing angle.
- Evidence: `path-contour-review/07-ground_slopes_path_edges-comparison.png`,
  `08-ground_slopes_path_edges-comparison.png`, and `iteration13-path-contour/`.
- Terrain mesher regression: 51/51, 5,172 assertions, including conserved area,
  bit-identical reversed seams, unchanged collision and adaptive-edge stitching.

### D1 — coplanar wood at the overhang

- **Accepted iteration 15:** ray/geometry inspection identified the overhang cap
  and window-wall tops sharing exactly world Y=17.08. A decorative cover now bears
  with its underside on the wall top; it no longer uses the walk-floor alignment
  convention. Its covering band is reserved during projection admission.
- The matched crop replaces flickering angular patches with continuous boards.
  The nearby view also shows a coherent covering course. Alternating 1.5 cm camera
  captures show edge motion rather than the former interior patch changes.
- Evidence: `cap-course-review/01-turf_wood_overlap-comparison.png`,
  `cap-jitter-review/01-turf_wood_overlap-comparison.png`.
- Focused measured-bearing regression passes alongside the corner/frame tests.

### D2 — lawn divot and exposed timber substrate

- **Accepted iteration 16:** a hidden retained block one band below the deck had
  been admitted as a terrain height control. That pulled grass down to world
  Y=16.13 through its wooden substrate (top Y=16.76). The turf field now takes
  only finished turf/public surface owners; raw structural occupancy is no longer
  an input. Real one-band changes between selected lawns still use the shared
  terrain slope kernel. No cover panel or invented neighbour ring was added.
- The matched crop and nearby views show the lawn continuing to its edge without
  the deep angular cut-out or exposed wood. The diff isolates the former divot.
- Evidence: `turf-owner-review/02-turf_wood_overlap-comparison.png` and
  `iteration16-turf-owner/turf_wood_overlap_near_right.png`.
- Turf and production-surface tests: 28/28, 1,348 assertions, including dense
  corner-height probes and preservation of real two-level turf slopes.

## Final combined review

- Final captures: `artifacts/qa/2026-09-05-manual-pass/after/`, all four sites
  completed with `ready=true`, with exact reconstructed angles, ±8° views,
  alternating 1.5 cm camera shifts and a ground-contact view of B1.
- [All 14 before/after/diff close-ups](/Users/ryko/story/artifacts/qa/2026-09-05-manual-pass/final-review/index.html).
  Every region was inspected individually in the final combined output: A1/A2
  closed joints; A3/C1–C4 finished facade ends; B1 continuous bearing to ground;
  C5/C6 broad ground transitions; C7/C8 smooth path contours; D1 coherent boards;
  D2 lawn without the deep cut-out and exposed substrate.
- Repeated-camera comparison: 11/14 regions have zero pixels changing by more
  than 8 RGB levels. B1 and D2 each change one pixel; C6 includes the animated
  character at its crop edge. D1 has zero changed pixels at the repeated camera;
  its 1.5 cm shifted comparison contains moving outlines rather than interior
  coplanar patches. This is evidence for the photographed overlap, not a claim
  that every possible city surface is flicker-free.
- C's player remains frozen at the original Y=4.2 for matched-camera evidence;
  the corrected ground is higher there, so the diagnostic character is partly
  submerged. This is not a live character-physics screenshot.

## Regression results and remaining caveats

The photographed defects are visually accepted; this is **not** an all-green
release or a performance acceptance.

- Full GUT run: 90 scripts, 995 tests, 974 passing, 20 failing, 2 risky/pending;
  317,612/317,651 assertions, 1,303.627 seconds. Godot also reported a native
  recursive-mutex error during teardown after printing the completed totals.
- Seventeen failing maze-composition tests match the recorded baseline failures
  (`/tmp/baseline-maze.stdout`), including rejected town/roof corpus cases and
  composition/dressing quotas. They were not weakened to make this pass green.
- One failure expected the old half-width stone panel. That expectation now
  names the reviewed full-width panel; the subsequent facade-variety suite
  passes **22/22 tests, 67,607 assertions**. The full suite was not rerun after
  this expectation-only update.
- Two broader failures remain unresolved: the seed-4242 village fixture rejects
  a portal one band above the terrain street (`terrain_gate_projection`), and
  the stepped seed-12 compact frontage ratio is 0.541667 versus a 0.55 minimum.
  Neither is being labelled pre-existing without a corresponding baseline.
- Latest focused checks pass: corner/frame/cap **8/8, 54 assertions**;
  turf/production surfaces **28/28, 1,348**; terrain mesher **51/51, 5,172**;
  grading **6/6, 5,766**; outskirts **12/12, 667**; settlement fabric
  **54/54, 122,279**; bake geometry **10/10, 78**.
- Cold feature-context generation in the diagnostic increased from roughly
  **34 s to 159 s**; terrain meshing increased from roughly **21 s to 37 s**.
  These are single diagnostic runs, not a controlled benchmark. Further profiling
  is needed before calling generation performance acceptable.
- The asset bake incidentally rewrote existing generated resources as well as
  creating the required corner variants. Automatic review blocked restoring
  those existing resources because that could discard other work. Explicit
  cleanup approval was subsequently granted. The 1,027 existing generated asset
  rewrites were restored; the updated catalogue and new corner variants remain.
  Existing code changes were preserved. The owner then requested this initial
  fix set be committed and integrated before the next manual-review pass.
- `git diff --check` passes. Full-run output is currently in
  `/tmp/sep5-full-gut.stdout`; targeted rerun output is in
  `/tmp/sep5-variety-tests.stdout` and the issue-specific logs noted above.
