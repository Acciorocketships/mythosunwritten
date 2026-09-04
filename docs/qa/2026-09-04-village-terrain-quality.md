# Village and terrain quality checkpoint — 2026-09-04

This checkpoint preserves the combined village/terrain work in the shared
workspace. It is not an all-green release or a claim that every reported village
defect is resolved.

## Changes

- City turf now supplies its actual grass-lip topology to the same visual
  clipping kernel used by ordinary streamed terrain. Logical center cells and
  full collision coverage are preserved. Inner-corner backing retains rock UVs.
- Exterior house streets minimize turns before distance and share a primary
  road root. They use the normal 4 m path width, spotted terrain surface, and
  quarter-turn fillets. Built town junctions remain square.
- The checkpoint also includes the preceding agent's natural-terrain separation,
  sealed town exits, floor closure, overhang-support cleanup, outskirts prefab
  work, startup changes, and removal of retired village implementations.

## Verification and known limitations

- Terrain mesher and feature commit: 55/55 tests, 5,183 assertions.
- Outskirts solver: 12/12 tests, 667 assertions.
- Focused corpus turf coverage: 1/1 test, 2,728 assertions.
- The broader workspace run reported 963 tests, 942 passing, 20 failing, and
  2 risky/pending. One failure was the old full-extent visual-turf assertion;
  its corrected collision/visual coverage check subsequently passed. The other
  19 village generation/composition and sloped-frontage failures remain open.
  Godot also aborted during teardown after printing the full-suite summary.
  The complete suite was not rerun after the final focused fixes.
- Twelve matched production turf views show the square grass-sheet overhangs
  removed and the centers retained. Rough stone cladding and some narrow
  lip/stone junction irregularities remain visible.
- At world seed `2697992464`, settlement supercell `(-1, 1)`, all 234 outskirts
  paint shapes connect to the main road. Three large ground prefabs are accepted;
  the stricter connected-street constraints reduce house coverage versus the
  preceding layout. That coverage regression remains open.

## Reproducing screenshots

The capture tools and camera inputs are versioned; bulky renders and logs stay
local under ignored `artifacts/qa/`.

```sh
godot --path . res://tests/harness/warren_spatial_review.tscn -- \
  --production-terrain-site --super-x -1 --super-z 1 \
  --capture-filter turf-component --output artifacts/qa/turf-review

godot --path . res://tests/harness/village_site_capture.tscn -- \
  --at -552,6,1133 --radius 1 --output artifacts/qa/village-review \
  --view overview:-622,68,1190:-553,12,1103:65 \
  --view reverse:-487,60,1030:-553,12,1103:65 \
  --view plan-town:-552,140,1104:-552,4,1104:70
```

The local detailed judgments, test logs, and matched RGB difference boards are
under `artifacts/qa/2026-09-04-turf-final/` and its neighboring capture folders.
Those current-production views are not exact reconstructions of the historical
user screenshots: intervening work changed that earlier town geometry.
