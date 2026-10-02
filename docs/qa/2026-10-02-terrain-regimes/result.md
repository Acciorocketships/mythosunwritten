# Terrain regimes and local relief, phase 1 — result

Spec `docs/superpowers/specs/2026-10-02-terrain-regimes-local-relief-design.md`, plan
`docs/superpowers/plans/2026-10-02-terrain-regimes-local-relief.md`, branch
`claude/terrain-generation-overhaul-adb98f` (base `b8e130d9`). Images are on disk only
(`docs/qa/**/*.png` is git-ignored).

## What changed

`LandformField` (one analytic shape per 768 m province, averaged across four owners and
seven biomes) is gone. `HeightfieldPlan.height01` delegates to `TerrainField.height_m`:

- **base**: smootherstep-bilinear of region base levels on a 320 m node grid.
- **set pieces** (`LandformSetpieces`): escarpment, amphitheatre, mesa, big ridge with pass,
  open cleft, hanging valley; one candidate per 512 m cell, Matérn-II, never overlapping,
  never within 400 m of spawn.
- **regime relief** (`TerrainRegimeField` + `TerrainRegimeCatalog` + `RegimeRelief` +
  `ReliefPrimitives`): 640 m jittered Voronoi regions, one of eight archetypes chosen with the
  visual-biome bias, parameters drawn from ranges with a 0.6–1.7 scale; each blended regime
  applies its own storey-aligned terrace.
- The smooth field rivers trace carries each regime's macro relief.
- Regions within 1.2 km of spawn are calm rolling downs (base ≤ 2 storeys, relief ≤ 1).

## Maps (`map-*.png`, `tests/harness/terrain_regime_map.gd`)

Tinted by archetype (legend in the harness `TINT` table), hillshaded storey bands, border
bands darkened, set-piece footprints outlined in white.

| Window (4 km, seed) | rolling | ridge | escarp. | terraced | karst | table | massif | flats | set pieces |
|---|---|---|---|---|---|---|---|---|---|
| spawn, 2697992464 | 48% | 6% | 10% | 4% | 13% | 10% | 4% | 5% | 9 |
| spawn, 42 | 45% | 12% | 0% | 10% | 19% | 4% | 2% | 8% | 13 |
| (6000, -3000), 2697992464 | 23% | 12% | 15% | 11% | 11% | 15% | 2% | 12% | 18 |

## Gallery (`gallery/`, `tests/harness/regime_gallery.tscn`)

Two samples per archetype; oblique, top and close views (archetype forced everywhere).
Rendered before the gully-window fix (affects ridge/massif by ≤ 0.23 m).

Visual read:
- **Escarpment country** reads as intended: long parallel bands of rock-faced cliffs.
- **Tableland** reads as plateau cells with cliff rims and rock.
- **Karst hollows** shows scattered pits, but they read as small level squares more than sinkholes.
- **Ridge and pass / highland massif read too gentle**: rolling ground with 1 m level steps,
  not distinct ridgelines and passes. The relief is real (a massif site spans storeys 9–16)
  but its slopes (~11–17°) almost never make a two-storey wall within one 12 m tile. This
  is the first thing to tune (steeper ridge flanks, smaller ridge spacing, or terracing
  ridge flanks).
- The gallery uses plain green with no biome texture; one-storey slopes are hard to read from
  above, hence the close views.

## Structure survey (`survey-{before,after}-*.json`, `tests/harness/terrain_structure_survey.gd`)

Seed 2697992464, 256 × 256 points (3 km) per site, with water. "structured" = 48 m window
has a storey change; "tactical" = window has both a wall (cliff) edge and a walkable slope
edge; "speckle" = single-point pits/spikes.

| Site (points) | structured | tactical | speckle/km² | walls/km² | wall run p95 / max | rivers | towns |
|---|---|---|---|---|---|---|---|
| (60, 40) before | 0.71 | 0.15 | 2.6 | 397 | 8 / 23 | 15 | 23 |
| (60, 40) after | 0.63 | 0.17 | 22.0 | 394 | 4 / 12 | 10 | 23 |
| (-300, 250) before | 0.79 | 0.19 | 3.4 | 534 | 8 / 39 | 15 | 23 |
| (-300, 250) after | 0.69 | 0.19 | 17.6 | 469 | 5 / 17 | 14 | 23 |
| (400, -350) before | 0.74 | 0.13 | 3.9 | 337 | 6 / 19 | 13 | 24 |
| (400, -350) after | 0.71 | 0.17 | 16.0 | 364 | 6 / 37 | 12 | 25 |

Per archetype (after, three sites): tableland tactical 0.51–0.69, escarpment 0.34–0.53,
massif 0.05–0.45, ridge 0.07–0.21, karst 0.12–0.17, rolling downs 0.05–0.08, terraced
valleys 0.03–0.16, low flats 0.02–0.06. Speckle concentrates in tableland (13–88/km²) and
karst (24–42/km²).

Reading:
- Site averages barely move: the baseline already had storey changes in 71–79% of
  windows (long hillsides). The gain is in kind and is concentrated in the structured
  archetypes, as designed; gentle archetypes stay gentle.
- Speckle rose ~5x. Per spec §7 this is the trigger for the deferred clean-up pass
  (opening/closing on storeys), mainly for tableland and karst.
- Wall runs got shorter (p95 8 → 4–6) except one 37-point run at (400, -350).
- Settlement sites unchanged; river sources lower near spawn (calm rolling downs).

## Cost (`cost.txt`, `tests/harness/terrain_field_cost.gd`)

µs per `height01` sample: baseline smooth 25 / detailed 27; final 21–27 / 55–66 (higher
figures measured under a concurrent test suite). Budget smooth ≤ 1.5x, detailed ≤ 3x: met.

## Tests

New: `test_relief_primitives`, `test_terrain_regime_catalog`, `test_terrain_regime_field`,
`test_regime_relief`, `test_landform_setpieces`, `test_terrain_field`,
`test_coord_overlay_regime`. Guards extended: river sources ≥ 30/81 on seven seeds; spawn ring
(180 m) ≤ 16 m on seven seeds; field continuity by bisection to 0.5 µm on three 4–5 km lines.
Retired with `LandformField`: `test_september15_landform_cache`, two `test_atmosphere_field`
landform tests, and the harnesses `september11_landmark_survey`, `september15_streaming_qa`
(+ scene), `september15_landform_cost`.

## Suite comparison (`tests/tools/run_suite_isolated.sh`, per file, both trees)

| | files | files with a failure | failing tests |
|---|---|---|---|
| baseline `b8e130d9` | 344 | 67 | 105 |
| this branch | 350 | 67 | 104 |

The seven new test files pass. Better than baseline: `test_village_plan` (its span test
passes at the re-pinned site). Worse than baseline: `test_september13_water_turf`, left red
on purpose (below). Nine files failed on first run because they pin old geography; all were
re-pinned to equivalent current sites found programmatically, assertions unchanged:

| Test | Old site | New site / fixture |
|---|---|---|
| `test_heightfield_plan` carve, `test_water_plan`, `test_water_dual_grid` (2) | 22 m-amplitude worlds (no rivers can exist now) | production amplitude, same seeds/windows |
| `test_water_terminal_datum` | districts (-2,-2), (-1,-1), (1,1), (0,0) | first four firing districts of the central 5x5 |
| `test_september27_mountain_water` | looping spring (0,1) | looping spring (-5,-6), found by scan |
| `test_september13_water_corner` (3) | (1185,18.625), (1191.75,183.625) | (-612,-845.375), dying wall (1264.25,171.625) via `september13_water_corner_scan` |
| `test_september15_water_drops` (3) | lips (-240,-1473), (-231,-1446) | lips x = 1206 and z = -1806 in chunk (6,-10), via a `wall_segments` spill scan |
| `test_village_plan` | super-cell (0,-1) | (0,-2) |
| `test_village_massing_solver` | (0,-1) | (-1,-1) ((0,-2) is a platform cluster) |
| `test_september13_water_turf` | chunk (4,1) window (826,342) | chunk (4,6) window (810,1178), densest shallow water |

`test_september13_water_turf` fails at its new site: the cliff sheet's rounded shoulder
over a submerged wall (x = 822) stands 0.07-0.17 m above the terrain field, the wave budget
reserves only `WaterSkin.SHEET_COVER` (0.05 m), so the maximum trough shows turf in 12 of
1460 samples (up to 9.4 cm). The water code is unchanged on this branch; the new geography
exposes a pre-existing water/sheet clearance gap. Fix belongs with water (sub-project C).

## Startup profile (`tests/harness/profile_terrain.gd`, 49 chunks round spawn)

| | worker total | terrain mesh payload | peak memory |
|---|---|---|---|
| baseline | 1775 s | 967 s | 7609 MiB |
| this branch | 681 s | 276 s | 7362 MiB |

The 49 chunks lie inside the calm rolling downs round spawn (few cliffs, so a much cheaper
cliff sheet); this is not a world-wide speed-up. Runs were on a shared machine.

## Open for owner review

1. Ridge/massif archetypes are too gentle to produce ridgelines and passes (see gallery).
2. Speckle up ~5x (tableland, karst): decide on the phase-2 clean-up pass.
3. Deferred by design: border escarpments, valley damping near rivers (rivers carve through
   relief), F9 view in the gallery.
4. Calm spawn zone (1.2 km of rolling downs) is a judgement call; size is one constant
   (`TerrainRegimeField.SPAWN_CALM_M`).
5. Pre-existing F4 review spots point at re-rolled geography; eight new `regime <archetype>`
   spots were added.
6. `test_september13_water_turf` is red: turf shows through maximum wave troughs over a
   submerged cliff-sheet shoulder (water/sheet clearance, see the suite section).
7. The photographed September water sites now sit in the calm spawn zone; their tests moved
   1.5-2 km out.
