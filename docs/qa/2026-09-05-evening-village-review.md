# September 5 evening village review

Seed **2697992464**. Initial fixes integrated into remote main at `7648599b` before this pass.
Camera reconstruction uses the rounded player/crosshair overlay through ReviewCam;
paired renders use identical reconstructed transforms, with nearby angles and jitter.

## Inventory

| IDs | Annotated source | Player world | Crosshair world | Findings |
|---|---|---|---|---|
| A1–A3 | [5:51:08](</Users/ryko/Desktop/Screenshot 2026-09-05 at 5.51.08 PM.png>) | (282.9, 5.0, 305.1) | (282.6, 5.2, 305.3) | A1 left missing wall strip; A2 right missing strip; A3 multiple exterior doors serving the same house. |
| B1–B5 | [5:51:45](</Users/ryko/Desktop/Screenshot 2026-09-05 at 5.51.45 PM.png>) | (258.8, 27.6, 306.3) | (258.4, 27.9, 306.2) | B1 upper-left facade fin; B2 lower-left fin; B3 upper-right fin; B4 left horizontal flicker seam; B5 right horizontal flicker seam. Audit other equivalent seams too. |
| C1–C3 | [5:52:33](</Users/ryko/Desktop/Screenshot 2026-09-05 at 5.52.33 PM.png>) | (260.1, 4.8, 270.1) | (260.0, 5.1, 269.7) | C1 upper T corner rounded; C2 lower T corner sharp (inconsistent pair); C3 grass break disconnects town entrance. |
| D1–D3 | [5:52:23](</Users/ryko/Desktop/Screenshot 2026-09-05 at 5.52.23 PM.png>) | (303.0, 5.0, 272.9) | (303.2, 5.2, 272.7) | D1 small house overlaps lane; D2 near entrance lacks outer-road connection; D3 far entrance lacks outer-road connection. |

## Sequence

1. Reproduce and close wall apertures; consolidate entrance selection by house.
2. Audit facade returns and coplanar courses, then verify jittered renders.
3. Consolidate path junction/entry connectivity and protect roads from houses.
4. Profile cold feature generation and runtime phases; remove repeated computation
   and avoid generate/reject/retry algorithms rather than weakening validity checks.
5. Inspect existing assets; implement measured wall lanterns with soft light, then
   present asset-backed decoration and occasional landmark ideas.

Status: investigation in progress. No new issue is accepted yet.

## Evidence and current checkpoint

- Before: `artifacts/qa/2026-09-05-evening/before/` — four reconstructed
  cameras, each with exact, two nearby, and four alternating jitter frames.
- First A experiment: `artifacts/qa/2026-09-05-evening/iteration-a1/`.
  Capping the diagonal cut passed a synthetic closed-solid test but did **not**
  close the reported openings. Rejected after viewing the matched render.
  The experimental clipper code was removed. Its generated assets still need
  restoring; the safety reviewer blocked that operation. Their full binary
  recovery patch is `/tmp/sep5-rejected-miter-cap-assets.patch` (2,351,350 bytes).
- Actual A ownership defect: room `spatial.parcel.maze.house.017.part00.room00`
  uses `room.tower.base.rock`, suppresses `west`, but its door was still using
  the double-miter variant that assumes both side walls exist. The new finite
  end-owner binding follows those explicit suppressions. The regression was
  red on the old code (double-miter instead of square-ended panel), then green.
  **Not visually accepted yet.**
- A3 ownership audit: the two pictured doors belong to distinct buildings
  (`spatial.maze_back.01` and `spatial.parcel.maze.house.017.part00`). No
  production building in this seed has more than one addressed room. Do not
  conflate adjoining houses with duplicate entrances to the same dwelling.
- Cold profile: first complete record 148,376 ms. Instrumented repeat: frame
  discovery 9,470 ms; record 125,432 ms, of which urban generation 2,887 ms,
  urban materialization 50 ms, and outskirts generation 122,406 ms.
  The surrounding-house solver—not the core town—is the dominant cost.
  No performance improvement is claimed yet.
- Initial checkpoint remains on remote main at `7648599b`. New work is on
  `codex/village-september5-evening-review`, uncommitted. Remaining visual
  issues, optimisation and lantern/decor work are unfinished.
