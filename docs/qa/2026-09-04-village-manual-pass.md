# Village manual QA pass — 2026-09-04

World seed: `2697992464`

Every position below is transcribed from the F3 overlay in the named annotated
image. `tests/harness/village_reported_qa.tscn` uses the exact player/crosshair
pair with `ReviewCam.solve_cam()` so the original gameplay orbit can be repeated.
Each target also captures ±8° adversarial views.

## Original annotated references

These are the untouched source images, including the user's arrows and circles:

- [Ground handoff wedge](</Users/ryko/Desktop/Screenshot 2026-09-04 at 4.47.25 PM.png>)
- [Orphan stone cell](</Users/ryko/Desktop/Screenshot 2026-09-04 at 4.53.10 PM.png>)
- [Diagonal gap and facade planes](</Users/ryko/Desktop/Screenshot 2026-09-04 at 4.50.23 PM.png>)
- [Elevated turf and disconnected supports](</Users/ryko/Desktop/Screenshot 2026-09-04 at 4.49.52 PM.png>)
- [Planters in walkway](</Users/ryko/Desktop/Screenshot 2026-09-04 at 4.49.25 PM.png>)
- [Door behind railing](</Users/ryko/Desktop/Screenshot 2026-09-04 at 4.49.13 PM.png>)
- [Double ground sheet](</Users/ryko/Desktop/Screenshot 2026-09-04 at 4.46.44 PM.png>)
- [Facade plane protrusion](</Users/ryko/Desktop/Screenshot 2026-09-04 at 4.48.59 PM.png>)
- [Turf lip and corner mismatch](</Users/ryko/Desktop/Screenshot 2026-09-04 at 4.48.41 PM.png>)

The F3 overlay gives rounded player and crosshair positions, not a full camera
transform or lens. The harness reconstructs the gameplay orbit from those facts;
the regenerated before and after use identical saved inputs. They are mutually
pixel-comparable, but not claimed pixel-identical to the original editor capture.

| ID | Annotated image | Player / crosshair world position | Reported defect | Suspected canonical owner |
| --- | --- | --- | --- | --- |
| `terrain_handoff_wedge` | `Screenshot 2026-09-04 at 4.47.25 PM.png` | `(238.1, 4.0, 316.6)` / `(237.8, 4.2, 316.6)` | The separate wedge-shaped street handoff has a visible underside and open seams. A level change must be part of the canonical terrain-height surface, using the terrain slope kernel, rather than a second ramp sheet. | Village terrain projection and terrain surface field |
| `orphan_stone_cell` | `Screenshot 2026-09-04 at 4.53.10 PM.png` | `(253.4, 9.9, 289.5)` / `(253.7, 10.1, 289.3)` | A stone upper cell floats without a cardinal bearing connection; an intended neighbour appears to have become a roof. | Final fabric connectivity / unsupported-volume cull |
| `diagonal_gap_facade_planes` | `Screenshot 2026-09-04 at 4.50.23 PM.png` | `(286.3, 5.1, 291.4)` / `(286.4, 5.4, 291.7)` | Diagonally adjacent buildings leave a vertical slot, and several cream facade panels protrude past finished corners. Prefer cardinal infill in planning; otherwise emit an explicit diagonal trim joint. | Parcel closure and final facade boundary derivation |
| `elevated_turf_supports` | `Screenshot 2026-09-04 at 4.49.52 PM.png` | `(237.5, 17.0, 294.2)` / `(237.4, 17.8, 293.1)` | Elevated turf reads as a flat plate without a coherent lip/side, while isolated columns below are disconnected from both the platform and each other. | Unified turf boundary and final support outline |
| `planters_in_walkway` | `Screenshot 2026-09-04 at 4.49.25 PM.png` | `(247.3, 17.0, 299.1)` / `(247.0, 17.4, 299.3)` | Two planters occupy the middle of a public walkway. | Final public-clearance-qualified prop derivation |
| `door_behind_railing` | `Screenshot 2026-09-04 at 4.49.13 PM.png` | `(258.8, 11.0, 315.3)` / `(259.2, 11.3, 315.4)` | A visible exterior door is blocked by a stair rail. An unserved door must become a closed/window facade. | Threshold/approach proof before facade and guard derivation |
| `double_ground_sheet` | `Screenshot 2026-09-04 at 4.46.44 PM.png` | `(251.0, 4.0, 278.7)` / `(251.8, 4.2, 278.3)` | Natural ground and a constant-height town base render as two stacked surfaces. | Single canonical village-conditioned heightfield |
| `facade_plane_jut` | `Screenshot 2026-09-04 at 4.48.59 PM.png` | `(262.8, 5.0, 336.0)` / `(263.0, 5.2, 336.3)` | Thin cream facade planes protrude beyond multiple building corners. | Finished-volume boundary-derived facade selection |
| `turf_lip_corner` | `Screenshot 2026-09-04 at 4.48.41 PM.png` | `(282.3, 8.1, 345.2)` / `(282.6, 8.3, 345.5)` | Retaining rock changes appearance, rock shows through the grass lip, and straight lips do not meet corner pieces. | One clipped turf boundary driving surface, wall, lips, and corners |

## Ground investigation and judgments

- Red: production seed emitted eight `public-terrain-street`/handoff sheets and no
  heightfield grade (`/tmp/village-ground-red.log`).
- Iteration 1: the wedge disappeared, but the nearby outskirts house also disappeared.
  **Rejected**, even though the new ground tests passed. Comparison:
  [iteration 1](../../artifacts/qa/2026-09-04-manual-pass/ground-iteration1/diffs/terrain_handoff_wedge_exact-comparison.png).
- Iteration 2: sealed the neighbouring accepted foundation pads into the same grade
  rather than placing houses on a partially completed grading collar. The original
  house remains; the wedge has no underside or open seam. The stacked-ground view has
  a continuous terrain slope instead of a second floating town sheet. Exact and ±8°
  views inspected; **reported ground defects pass this iteration**.
  [Wedge comparison](../../artifacts/qa/2026-09-04-manual-pass/ground-iteration2/diffs/terrain_handoff_wedge_exact-comparison.png),
  [stacked-ground comparison](../../artifacts/qa/2026-09-04-manual-pass/ground-iteration2/diffs/double_ground_sheet_exact-comparison.png).
- Verification: production street-centre heights and preserved neighbourhood pass;
  graded/direct samples agree; edited-ground visuals and collision share identical
  vertices and one sheet; collar/coarse-grid T-junction test passes. The existing 49
  mesher tests also passed. Full-suite and other issue judgments remain outstanding.

## Orphan stone investigation and judgment

- Identified the block as `terrain-foundation/6/4/-7/*` and its neighbouring
  course instances, not an inhabited room. The renderer was adding one 6 m
  foundation course beneath a room at 17.08 m, leaving its bottom at 11.08 m
  above roughly 4 m ground.
- Red: the exact production seed exposes suspended foundation courses
  (`/tmp/village-foundation-red.log`).
- Fix: emit a terrain foundation only when the authored course can reach the
  ground. High terrace structures keep their own structural supports; a skirt
  no longer masquerades as a floating column.
- Green: production foundation audit passes. Exact and nearby render views show
  the orange roof unobstructed, the orphan stone gone, and the neighbouring rooms
  retained. The isolated pixel diff confirms removal of the circled block:
  [foundation comparison](../../artifacts/qa/2026-09-04-manual-pass/foundation-iteration1/diffs/orphan_stone_cell_exact-comparison.png).
  **This reported orphan block passes.** The distinct tall retained columns in
  `elevated_turf_supports` remain an open issue; this change does not claim to fix them.

## Facade investigations and judgments

- Isolated the alleged corner-post asset: it is a narrow handed wall with cream
  plaster sheets. Four unoriented copies manufactured the reported fins.
- The apparent diagonal slot is a missing intermediate facade-bay/T-joint on a
  long room after the adjoining party wall is suppressed. Framing only the four
  outside room corners misses this vertex.
- Iteration 1 replaced plaster with timber but retained a 0.75 m square section:
  **rejected** as too heavy, with the intermediate slot still visible.
- Iteration 2 uses a 0.28 m timber section within the room envelope and frames all
  authored bay endpoints. Exact and nearby views show the slot closed and the
  plaster fins gone. Isolated pixel comparisons inspected:
  [slot](../../artifacts/qa/2026-09-04-manual-pass/facade-iteration2/diffs/diagonal_gap_facade_planes_exact-comparison.png),
  [fins](../../artifacts/qa/2026-09-04-manual-pass/facade-iteration2/diffs/facade_plane_jut_exact-comparison.png).
  **These two reported facade defects pass.** All 54 fabric tests pass.
- Wider review caught an additional ground-iteration regression: exposed floor
  boards at ground-floor thresholds compete with the newly unified terrain.
  Ground iteration 3 removes the construction datum's 8 cm visual guard from
  the terrain target. The red/green street-height regression test and the
  threshold exact/nearby images now pass: boards no longer flicker with grass.
  [Threshold comparison](../../artifacts/qa/2026-09-04-manual-pass/ground-iteration3/diffs/diagonal_gap_facade_planes_exact-comparison.png).

## Turf investigations and judgments

- Straight lips scaled X/Z by 0.5 but left Y at 1.0; corners were uniformly
  scaled. Iteration 1 corrects this but does **not** pass the whole issue:
  incompatible square stone still intrudes through the rounded boundary.
- The elevated lawn's invisible equal-height control ring suppressed its true
  exposed-edge classification. Removing the invented neighbours restores its
  rolled boundary (iteration 2). A focused red/green test protects that fact.
- Iteration 3 tests matching terrain rock beneath the same lip slots rather
  than vertically sinking an incompatible square wall. The garden's exact,
  nearby and pixel-diff views pass: the lip/corner joins meet without pierced
  stone and the whole retaining course uses the normal terrain's rock family.
  [Garden comparison](../../artifacts/qa/2026-09-04-manual-pass/turf-iteration3/diffs/turf_lip_corner_exact-comparison.png).
- Elevated support investigation: the hanging columns were one-band planted-deck
  support markers expanded into full-height wall courses. Grounded retained
  mass remains; suspended plaza cells instead receive a connected timber floor.
  Iteration 4 removes the columns, but exposes an old grass drape behind them:
  **not accepted**. Iteration 5 disables that unbacked end drape through the same
  terrain clip kernel's structural-boundary limit. Exact and nearby after views,
  plus the isolated pixel comparison, now show a continuous planted timber deck
  without hanging stone courses or a green curtain. **Both turf reports pass.**
  [Elevated lawn comparison](../../artifacts/qa/2026-09-04-manual-pass/turf-iteration5/diffs/elevated_turf_supports_exact-comparison.png).

## Planters investigation and judgment

- The corner-placement code had a fallback that forced two planters onto any
  clear floor when no outside corner fitted. It also mistook adjoining stairs
  at another band for missing neighbours.
- Removed the decorative quota and consider stair neighbours one band above
  and below. A narrow stair landing can correctly have no planters.
- The focused regression passes. Exact and nearby after views show both
  circled planters gone and the stair/door approach clear. The pixel diff is
  localized to those two objects. **The reported planter issue passes.**
  [Planter comparison](../../artifacts/qa/2026-09-04-manual-pass/planter-iteration1/diffs/planters_in_walkway_exact-comparison.png).

## Door investigation and judgment

- The door is `maze.house.007.part00.room00/south`. Its nominal landing
  `(-4,1,-2)` and approach `(-4,1,-1)` both belong to transition 07's rising
  stair span, not a flat doorstep. The old proof counted cell existence alone.
- Construction now chooses the existing closed facade for such a room and
  records that decision in `stair_blocked_door_ids`. The house, conservative
  clearance reservation and stair safety guards remain. Surface sealing
  independently rejects a doorstep on a flight or an approach across its side
  rail. An aligned flight's open end may still lead to a flat doorstep. Prefab
  landmarks receive this same qualification before their mass is reserved.
- Exact and ±8° captures show the circled door replaced by a closed window
  facade. Its house and the necessary stair railing remain. The close-up diff
  shows the facade replacement, rather than removal of the safety rail.
  **The reported unreachable door passes.** Three focused approach/dressing
  tests and all four photographed-production regressions pass.

## Final annotation-by-annotation acceptance

The [close-up gallery](../../artifacts/qa/2026-09-04-manual-pass/closeups/index.html)
contains 12 independently cropped details from the nine reconstructed camera
positions: untouched before, untouched after, and absolute RGB difference (3×
display gain). Native captures are in
[final](../../artifacts/qa/2026-09-04-manual-pass/final/); the deterministic camera
inputs and reconstruction are in
[the capture harness](../../tests/harness/village_reported_qa.gd).
All nine targets also have matched ±8° views. No scene pixels were repainted.

| Detail | Final visual judgment |
| --- | --- |
| 01 — ground wedge | Pass: continuous graded ground; no floating ramp, triangular underside, or open edge. The nearby house remains. |
| 02 — orphan upper stone | Pass: the disconnected foundation course is absent; the roof and inhabited rooms remain. |
| 03 — facade joint slot | Pass: the previously open intermediate bay joint is covered by a slim timber post. |
| 04 — facade planes | Pass: handed plaster fins are replaced by correctly oriented timber framing within the envelope. |
| 05 — elevated lawn edge | Pass: continuous rolled lip and a visible joined timber substrate give the planted deck depth. |
| 06 — hanging columns | Pass: disconnected stone courses beneath that lawn are gone; grounded retained stone is preserved. |
| 07 — walkway planters | Pass: both obstructing planters are absent and the stair approach is clear. |
| 08 — door behind rail | Pass: an unreachable door becomes a window facade; the house and safety rail remain. |
| 09 — stacked ground | Pass: one terrain surface slopes into the city, without an elevated duplicate street sheet. |
| 10 — corner plaster fin | Pass: no cream plane protrudes past the timber corner. |
| 11 — straight grass lip | Pass: the matching terrain rock course no longer pierces the rolled grass edge. |
| 12 — grass corner | Pass: the straight and corner pieces meet with matching profile and stone treatment. |

Each crop has nonzero changed pixels; the percentage alone is **not** the
acceptance criterion. The visible defect must disappear in the after and nearby
views, and the difference must show the relevant geometric change. Rejected
iterations above remain available, including a disappearing neighbour, oversized
corner posts, and an exposed green curtain.

## Regression verification

- The production seed checks ground height, retained neighbouring houses,
  foundation grounding, suspended turf substrate, and every surviving door's
  approach: **4/4 tests, 83 assertions pass**.
- Door/dressing fixtures: **3/3 tests, 15 assertions pass**.
- Settlement fabric: **54/54 tests, 122,258 assertions pass** on the final code.
- Turf seam/physics fixtures: **4/4 tests, 15 assertions pass**. Native terrain
  rock is visual-only, so each logical retaining face now has its own inset wall
  collider; paired corner assets still cover and audit both faces.
- Terrain grade, mesher, surface field, heightfield region, feature context,
  grass field, production surfaces, and spatial compiler suites passed. These
  include deterministic height composition, exact graded collision, and
  fine/coarse mesh seam checks.
- Broad maze composition: **69/86 pass, 17 fail, 1 pending**. An untouched
  baseline checkout has the **same 17 named failing tests**. No new failing
  tests remain. Existing failures include unrelated source/roof refusals and
  composition/decoration quota expectations; this is not a claim that the
  repository's entire test suite is green.
- The old production test demanding separate handoff ramps now requires zero
  duplicate street/ramp sheets, a sealed terrain grade, matching street heights,
  and two or three preserved exterior portals. Inner-corner rim pieces are also
  counted in the rim-layout audit, rather than incorrectly reporting surplus
  geometry as a negative deficit.

## Checklist procedure

For each ID:

1. Add a headless invariant that fails on the current production seed/plan.
2. Capture `exact`, `near_left`, and `near_right` before changing the owner.
3. Change the canonical plan/field owner; do not add per-coordinate offsets.
4. Run the focused invariant and its owning test suite.
5. Repeat the three images from the same player/crosshair pair.
6. Generate an absolute pixel diff and a three-panel comparison with
   `tools/compare_review_images.py`.
7. Visually falsify the exact and nearby after images. A non-zero diff proves a
   change occurred; it does not by itself prove the reported defect is fixed.
