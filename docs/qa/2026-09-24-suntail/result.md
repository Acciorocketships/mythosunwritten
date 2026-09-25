# Suntail building kit: review record (2026-09-24)

Branch `suntail-towns`, worktree `/Users/ryko/story-suntail`.

## What changed

Village buildings are drawn by a pack-agnostic building kit layer
(`scripts/terrain/features/villages/kit/`) using the Raygeas Suntail modular
pack. See the spec and plan under `docs/superpowers/`.

## Review method (falsification)

- Flat-ground battery, `tests/harness/suntail/kit_town_review.gd`: towns
  1/7/12 compact, 2/3/9 standard, 4/5 large, 6 grand; orbit, top, street
  (route-aimed) and skywalk side/underside views. Each round tried to show a
  defect; each found defect was fixed and the same view rerendered.
- Live streamed world, `tests/harness/village_site_capture.tscn` (seed
  2697992464): hamlet (216,480), villages (-242,431), (-213,-926),
  (304,1078), town (-1096,533), hamlet (2040,456).
- Gallery, `tests/harness/suntail/building_gallery.gd`: House_1 replica
  beside the source prefab; designed standalone houses.

## Defects found and fixed

| Found in view | Defect | Fix |
|---|---|---|
| gallery | pink timber, mirror-glossy roofs | manifest `material_palette`, `material_roughness` |
| town orbit | legacy SFV/LPFV roofs, landmarks, tan bays survived | withdraw roof tiles (`.tileNN`), landmark/bay/balcony/support units, `maze-outcrop` |
| town street | jetty inset opened slots against neighbours | jetties inset only exposed runs; corner-aware run ends |
| town orbit | "fortress" stone storeys | stone ground storey is a 40% seeded minority; retained skin keeps stone low |
| street | stretched masonry/rails from substitution | tile kit pieces at native size |
| street | awnings under bridges and in 1-cell lanes | awnings need a 2-cell street and open sky |
| skywalk underside | posts through public walks, tangled supports | posts land only on ground/structure |
| street | plinth band at mid-wall on stacked houses | plinths only where a wall meets the ground |
| orbit | all-red roofscape | small red/blue quarters, 50/50, occasional flips; softer slate blue |
| live village | landmarks as one-storey hollow barracks rings | landmark = full rectangle, 2-3 storeys |
| orbit | oversized six-deep roofs | crowns deeper than four modules split into main + cross gables |
| street | giant vase / upscaled props | prop fits capped at 1.25x; low garden props |
| hamlet | legacy well and prefab houses | Suntail well/bonfire; designed kit houses in lot footprints |

## Tests

`tests/test_building_kit.gd` 8/8 (House_1 replica inventory, metric, jetties,
roof fallback, determinism, legacy withdrawal). Village suites: hamlets 5/5,
gate handoffs, village grade, frame, occupancy pass. `test_village_plan`
(1), `test_village_outskirts_construction` (1) and `test_settlement_fabric`
(2) fail identically on the untouched baseline tree `/Users/ryko/story-towns`.

## Known open items

- Legacy stair/ramp surface meshes keep their plank shader (colours close).
- The largest grand-town blocks remain tall; pent eaves and finishes break
  them but a dedicated massing pass could step them further.
- Enclosed skywalks are open-ended timber galleries; a portal frame piece
  would read better.
