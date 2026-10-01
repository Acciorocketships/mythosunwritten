# Dual-grid terrain tiles: visual review (September 30 - October 1)

Branch `dual-grid-terrain` (worktree `/Users/ryko/story-dualgrid`) against the baseline copy
`/Users/ryko/story-dualgrid-base` (`7871fca4`, 24 m cells, game style `sheet_bedrock`).
Spec: `docs/superpowers/specs/2026-09-30-dual-grid-terrain-tiles-design.md`. Images are local
QA artifacts (gitignored `*.png`/`*.jpg`); this note is the versioned record.

## What was compared

| Directory | Contents |
|---|---|
| `gallery/` | First tile gallery run (`tests/harness/tile_gallery.tscn`), 55 PNGs: every tile case through the real mesher + cliff sheet, each with `_lines` (points, edge categories, `wall_segments`) and `_f9` (category overlay). |
| `gallery-fix1/` | Same after the cliff-end sheet fix `da5b6246`. |
| `gallery-fix2/` | Same after the fix round `c7399e09`, plus the new `cliff_stacked` case (58 PNGs). |
| `before-massif/00`, `after-massif/00`, `lowpass12-massif/00` | Photo-site captures (`cliff_site_review --shot`, seed 2697992464) of the green massif: `p03`, `p12`, `rp1`, `wide_a`, `wide_b`, `plan_a`, each also `_categories` (F9). Before = baseline, after = branch, lowpass12 = branch with `HeightfieldPlan.LOWPASS_M = 12`. |
| `before-lowland/00`, `after-lowland/00` | Lowland sites `low_e`, `plan_b`, `s28p1`, `wide_c`, `wide_d` (+ `_categories`). |
| `compare-massif/`, `compare-lowland/` | Labelled side-by-side composites (`tests/harness/dual_grid_side_by_side.py`): "current (24 m cells)" / "dual grid (12 m tiles)" / "dual grid + 12 m low-pass". |
| `before-town/00`, `after-town/00`, `compare-town/` | Town-site captures `town_a`, `town_b`, `town_c`, `plan_t` (+ `_categories`): baseline vs branch ground under generated towns, and the labelled side-by-side composites. |
| `before-kit/`, `after-kit/` | `kit_town_review` renders of flat-ground kit towns (city seeds 2 and 3, standard size): `overview`, `top` and four `orbit0-3` views each, baseline vs branch. No `compare-kit/` composite was made. |

Cameras are identical between columns. Geography differs: points sample the field at 12 m, so
every seed's ground is resampled (spec risk 4); rivers, roads and towns move with it.

## Findings

1. **Tile cases match the spec.** `gallery-fix2/slope_*`, `level_steps`, `cliff_straight`,
   `cliff_outer`, `cliff_inner`, `cliff_3storey`, `cliff_stacked`: walls stand on the 6 m
   midlines (`*_lines.png`), slopes are single-valued and span one 12 m tile, the slope saddle
   connects the low diagonal, and the sheet covers every wall (no bare skirt, no floating sheet).
2. **Cliff ends.** The first gallery showed a crease/gash where the sheet stopped at a cliff end
   (`gallery/mixed_e2_end.png`, `mixed_e1_end.png`, `terrace_hill.png`) and a thin dark flap at
   the E2 tip. Fixed in the cliff layer (`da5b6246`, `c7399e09`): the foot-fillet gate carries
   each wall's lift along its own wall, and low widened shoulders never stand above their crest
   drop; the flap was a normal-sampling bug. Compare `gallery-fix2/e1_vs_e2.png`: E2 (default)
   keeps a level high side and ends in a compact ramp; E1 shortens the wall across one tile with
   a slight dip. The E1 cyan patch in `gallery/mixed_e1_end_f9.png` was a harness artifact.
3. **Cliff saddle.** The kernel keeps two diagonal blocks as separate bumps, but the rounded
   sheet bridges the saddle point (`gallery-fix2/cliff_saddle.png`). Accepted as inherent to the
   closing envelope.
4. **Steep massifs read as a dome.** `compare-massif/wide_b.jpg`, `wide_a.jpg`: the baseline's
   long ledge bands become a dimpled dome with short walls, many cliff ends and blob-shaped
   bedrock. `compare-massif/plan_a_categories.jpg` shows why: on 12 m edges a steep hillside
   rises about one storey per edge, so it classifies as green slope edges, with only sparse red
   two-storey walls. The 12 m low-pass column barely changes it, so this is geometric, not noise.
   Owner decision (the spec's cliff rule versus world character).
5. **Lowland.** `compare-lowland/wide_c.jpg`, `low_e.jpg`, `plan_b.jpg`: terraces are finer and
   more organic; no seams, gaps or floating sheets were found. Roads follow the new ground.
6. **F9 overlay.** On bare ground no magenta/cyan appears (rendered mesh = kernel); trees, rocks
   and the cliff sheet show magenta as expected (`*_categories` images).

## Open items

- Dome look on steep massifs (finding 4): owner decision. Options: keep; raise the cliff
  threshold per 12 m edge; a larger low-pass; or measure storeys per 24 m for classification
  (none evaluated).
- E2 ramp-top chord notch: where the E2 fan width goes to zero, the 2 m terrain sheet and its
  collision sag up to 1.76 m below the kernel. The sheet solid takes the exact shape in the
  production style; only painted (road) ground shows it. Fix would be adaptive refinement near
  fan origins.
- Water step at a wall-corner rescue node, (1225, -56.375): 0.032 m; pending test
  `test_september13_water_corner::test_rescued_cell_meets_the_coarse_surface_beside_a_wall_corner`.
- Mixed-datum pads within one 12 m tile: the lower datum wins the shared corner, so the higher
  pad is not flat there (contract test pins the lower pad flat and native ground never above a
  datum).
- Outskirts gate checks the grade patch target instead of native ground (baseline behaviour;
  changing it alters town layouts).
- Village turf one-band steps now slope centre-to-centre; not yet reviewed in a town render
  (see `before-town/` / `after-town/` / `compare-town/` above).
