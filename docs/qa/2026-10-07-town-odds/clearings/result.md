# Courtyard clearings: evidence for the owner checkpoint

Branch `town-redesign`, HEAD d77cda827. No production code changed. Nothing here changes the default `clearing_count`; that is your call after you look at the images.

## What was run

Knob: `--odds clearing_count=2.5` for large/grand towns, `--odds clearing_count=1` for standard/compact (as the plan says). Eight towns: 53:grand, 31:large, 43:large, 83:grand, 13:standard, 103:standard (evidence) and 7:compact, 61:standard (holdouts, never used for tuning).

- Renders (windowed): `Godot --path . -s tests/harness/suntail/kit_town_review.gd -- --output <dir> --cities <list> --views overview,orbit,courtyard,street --garden-grass [--odds clearing_count=X]`. Off images in `off/`, on images in `on/` (PNGs are gitignored; they are on disk only).
- Audit: copy of the Oct 7 production audit with the `--odds` block (`odds_audit.gd.txt`), logs `audit_*.out`, results `audit_*.json`.
- Walks: copy of `oct6-preview-court-walk.gd` with the `--odds` block (`court_walk.gd.txt`), outputs `walk_*.out/json`.
- Blocks: throwaway script `odds_blocks.gd.txt`, results `blocks.json`.
Harness copies were deleted from `tests/harness/`.

## Audit (clearings on)

All eight towns build; every row has `valid_payload: true`, `floating: 0`, roof `intrusions: 0`.

| Town | clearing_count | valid_payload | floating | intrusions |
|---|---|---|---|---|
| 53 grand | 2.5 | true | 0 | 0 |
| 31 large | 2.5 | true | 0 | 0 |
| 43 large | 2.5 | true | 0 | 0 |
| 83 grand | 2.5 | true | 0 | 0 |
| 13 standard | 1 | true | 0 | 0 |
| 103 standard | 1 | true | 0 | 0 |
| 7 compact | 1 | true | 0 | 0 |
| 61 standard | 1 | true | 0 | 0 |

## Player walks

`--courts` walks every `deck` plot, and clearings are deck plots (`clearing.NN`), so they are included. It walks from the entrance to each court, then back (reverse). Court ids printed confirm it.

| Town | PublicWalkAudit dead ends | Courts walked (each forward and reverse) | Result |
|---|---|---|---|
| 53 grand, 2.5 | 0 | clearing.00, clearing.01, plaza.00 | 6/6 passed |
| 31 large, 2.5 | 0 | plaza.00 only (no clearing kept) | 2/2 passed |
| 103 standard, 1 (used instead of 31 for clearings) | 0 | clearing.00, plaza.00 | 4/4 passed |

## Block sizes (house plots, columns per plot), off vs on

| Town | houses off/on | largest off/on | median off/on | clearings kept (cells, floor, purpose) |
|---|---|---|---|---|
| 53 grand | 48/50 | 10/6 | 2/1 | 00: 11 cells, raised (band 2), green; 01: 10 cells, ground, workyard |
| 31 large | 21/21 | 29/29 | 2/2 | none |
| 43 large | 43/36 | 6/6 | 2/2 | 00: 6 cells, raised, green; 01: 4 cells, ground, paved |
| 83 grand | 32/39 | 14/8 | 2/2 | 00: 12 cells, ground, paved |
| 13 standard | 21/21 | 4/4 | 1/1 | none |
| 103 standard | 16/15 | 4/4 | 1/1 | 00: 4 cells, ground, green |
| 7 compact | 8/13 | 2/4 | 1/1 | 00: 8 cells, ground, paved |
| 61 standard | 18/17 | 6/6 | 2/2 | 00: 4 cells, ground, green |

Headlines:
- Median block is 1 to 2 columns in every town with or without clearings; clearings do not move it.
- The only really large blocks off are 31 large (29 columns) and 83 grand (14) and 53 grand (10). 53 and 83 shrink (10 to 6, 14 to 8). 31 large keeps its 29-column block because no clearing survived there (guardrails reject them), so the owner's "large block" complaint is not addressed in that town.
- Clearing supply is low: 6 of 8 towns kept at most 1 (2 of them none); only 53 grand and 43 large kept 2. With the requested count 2.5 a large/grand town kept 0 to 2.

## Images inspected

Off vs on overviews, 53 and 83; courtyard/clearing views for 53, 83, 43, 103, 7, 61.

Improved:
- `on/53_grand_court_clearing.00_0.png`: a green clearing court with a centre tree, benches, lamp and grass on a raised deck with railings. Reads as a real small green and is clearly better than a plain deck.
- `on/43_large_court_clearing.00_0.png`, `on/103_standard_court_clearing.00_1.png`, `on/61_standard_court_clearing.00_0.png`: green clearings with a tree, benches and flowers/grass. Grass is present, no floating decks or clipped walls seen.
- `on/83_grand_overview.png` vs `off/83_grand_overview.png`: the cluster of houses on the right of the town opens up around the paved court; the town is slightly less packed at the edge.
- `on/53_grand_overview.png`: houses at the lower right are reorganised around open paved ground.

Looks wrong or weak:
- Paved and workyard clearings are bare beige slabs with no props: `on/53_grand_court_clearing.01_0.png`, `on/83_grand_court_clearing.00_1.png`, `on/43_large_court_clearing.01_1.png`, `on/7_compact_court_clearing.00_2.png`. They read as empty plazas, not workyards or markets. Purpose-specific dressing (market stalls, wells, covered variants) is not built yet.
- On 83 and 7 the paved clearing looks like an outskirts forecourt open to the sky and the terrain (the camera sees open grass beyond), not an enclosed courtyard in a dense block.
- 43 large lost 7 houses (43 to 36) for a 6-cell raised green and a 4-cell paved court; 7 compact gained 5 houses (8 to 13). Counts move both ways because the street layout changes around the clearing.
- Not observed: floating decks, wall clipping, missing grass or unreachable-looking courts.

## Known limits
- Covered variants of clearings are not built; only deck courts (green lawn, paved, workyard).
- Purposes other than green have no dressing.
- Only 2 of 4 large/grand towns kept two or more clearings; 31 large kept none, so its 29-column block is unchanged.
- Images checked by eye for a subset of views; the walks prove reachability from the entrance, not usability.
- clearing_count curve and default are undecided; awaiting owner.
