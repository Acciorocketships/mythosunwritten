> **Reopened after owner review.** Candidate 07 repairs hanging sheets but retains nonstandard grading around cliff corners and side faces. Its acceptance below is withdrawn. The topology defect remains open; see the updated issue register.

# Issue 01 — grass rims restored

Status: accepted for the reported grass-sheet/lip regression at P07, P08 and P09, with P03 as a town-ground control. Other September 15 issues remain open.

## Cause and chosen repair

Town grading discarded native grass lips while rebuilding only the rock. The terrain sheet also disabled its normal lip clipping/aprons in that domain. September 13's wider smooth grading collar exposed more of that older omission: historical measurements show native lip counts at P09 falling from 21 natural to 18 under the previous grade and 14 under the new collar; P07 is 21/3/2; P08 is 45/31/31. P08 therefore predates the recent collar change. See `history.json`.

The final rule carries the ordinary native rock, grass rim and apron through the same canonical grade mapping, preserving native topology, palette and UVs. Fully removed cliffs collapse their rim within the existing 0.001 tolerance. Surviving cliffs retain native recess width. Unclipped ground vertices remain untouched. This restores common terrain construction beside towns without reverting the accepted smooth grading or introducing a separate town grass skin. Exact per-chunk vertex memoization avoids repeated grade sampling.

## Iteration and rejected output

Initial rim restoration left an end hole; restoring the ordinary lower apron closed it, but needed a fully flattened-street control to reject coplanar paint. Scaling all native recess widths by grading strength then created a long exposed seam at P08 and was rejected. Narrowing that collapse fixed the seam, but moving unclipped vertices produced striped shading on flat town ground at P03. Candidate 07 preserves those vertices and removes the collateral defect. New tests reproduce both the original missing lip and the rejected sideways compression.

Early persistent reload captures in candidate-04/candidate-05 were stale: GDScript.reload did not reread disk. They are excluded. The QA reload now explicitly reads source before reload. `verified/`, `native-05/` and older directories contain earlier candidates and are not final acceptance evidence. Only `candidate-07/` is credited below.

## Visual review

Twelve fresh, matched before/after pairs: P03/P07/P08/P09 at reconstructed photo orientation and ±8 degrees. All twelve images and their absolute RGB difference panels were inspected. P07 loses the hanging green flap while retaining a joined rounded edge; P08 loses the projecting sheet and split lip without the rejected long rock seam; P09 recovers its rolled native corner. P03 ground shading stays smooth and its separate path gap/corner remain unchanged. Native close views from earlier iterations provided additional seam checks; they do not replace these final game captures.

Camera poses use ReviewCam and the rounded original player/crosshair overlays, with identical transforms within each pair. The original exact camera transform and character facing are not recoverable from those overlays. Nearby grass jobs are fully drained before capture, world animation/shader clocks are frozen, and both variants use the same loaded field, feature context, scene and camera. Minor residual temporal lighting noise appears below the difference threshold.

Changed pixel fraction (luma difference >12/255, range over the three views):

| Site | Changed pixels |
|---|---|
| P03 | 0.000–0.000% |
| P07 | 1.078–1.619% |
| P08 | 0.958–1.109% |
| P09 | 1.662–1.774% |

Each site in `candidate-07/` includes original-resolution before/after images, raw absolute differences, labeled 3× difference comparisons, per-image metrics and saved poses. Metrics establish change location; visual judgment, not a changed-pixel percentage, determines acceptance.

## Geometry and tests

`geometry.json`: original main terrain collision and wall collision arrays remain identical at all three sites. Actual physics ray surveys cover 15,987 positions with zero lost or added support. Four P07 points on the restored lower apron move down by at most 4.91 cm; P08/P09 heights are identical. Apron collision is intentionally not claimed identical.

Four new tests / eight assertions and four graded-cliff tests / eleven assertions pass. The ten-suite final run is 145 tests: 139 passing, five failing and one pending, with 34,929/35,947 assertions passing. A baseline run reproduces the same five historical failures, plus the new missing-rim reproduction. Those historical failures are three carved-corner cases in test_cliff_dressing and two older native-lip ownership/coverage cases in test_september9_grass_lip. No full-suite acceptance is claimed. Raw baseline/final logs are retained here.

One loaded timing sample is recorded with geometry: before/after P09 7580/7798 ms, P07 4970/5121 ms, P08 1680/1302 ms. Concurrent review processes make these unsuitable for a general speed claim. Streaming performance remains issue 02.
