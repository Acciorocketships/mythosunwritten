# Terrain regimes and local relief — design

Date: 2026-10-02. Status: phase 1 implemented (see Deviations); awaiting visual review. Branch: `claude/terrain-generation-overhaul-adb98f`.
Scope: sub-projects **A** (structured local relief) and **B** (terrain-biome "regimes") of the
terrain overhaul. **C** (water-coupled landforms: gorges/waterfalls, deltas/braided channels,
lake islands/peninsulas) and **D** (overhangs: caves, arches, roofed clefts) get their own specs;
this one only defines the hooks they plug into.

This is explicitly a first, try-it-and-look pass. Parameters, archetypes and even layer
boundaries are expected to change after visual review.

## 1. Intent

**Owner goals.**
- The world reads as large-scale: vast plains, mountains as one big bump. Exploration and ground
  geometry are uninteresting at walking scale.
- Turn-based encounters (~50 m across, character-sized squares) will run on this ground later.
  High vs low ground, impassable walls and walkable climbs should produce different tactics in
  different places.
- Terrain should vary by region with its own random settings ("biomes" for landform), with
  features at several scales.
- The current slope *shape* (one-storey smootherstep per 12 m tile, ~32° peak) is liked and must
  not get steeper. Only the heightfield changes.

**Root cause in the current code** (`HeightfieldPlan.height01`, `LandformField`):
1. The only sub-province detail is one 46 m value-noise octave of amplitude
   `0.015 * relief * 128 m` (≤ ~1.6 m, ~0 in meadow), below one 4 m storey, so it rarely survives
   quantization.
2. `LandformField` gives each 768 m province one analytic shape, then averages the four owner
   shapes with smootherstep weights *and* across up to seven biome weights. Averaging sharp shapes
   produces soft bumps; the named vocabulary (escarpment, mesa, cleft...) is erased.
3. Nothing produces organizing structure (ridgelines, connected benches, drainage, passes).

**Decisions taken in brainstorming.**
- Keep the 12 m point lattice and the `TerrainTileField` kernel untouched. Size all new features
  in **metres**, so a later move to a 6 m lattice changes sampling and slope rules, not landforms.
- Terrain regimes are a **separate geology layer, biased by the visual biome** (hybrid).
- Regimes are **curated archetypes with sampled parameter ranges**.
- Phase 1 is a **structured continuous field only** (approach 1). A discrete lattice clean-up pass
  (morphology on storeys, guaranteed ramps, minimum bench width) is deferred; its slot is
  reserved and the survey in §7 decides whether it is needed.
- At 12 m the heightfield supplies tile-scale tactics (benches, walls, ramp tiles, gullies).
  Sub-tile cover comes from dressing and later from D.

## 2. Architecture

```
H(x,z) = base(x,z) + setpieces(x,z) + relief(x,z)        (metres, pre-carve)
H'     = terrace_transform(H)        (regimes that terrace; aligns treads to storeys)
height01 = clamp(H' / HEIGHTFIELD_AMPLITUDE, 0, 1) * spawn_falloff
```

| Layer | Scale | Role | Seen by river tracing |
|---|---|---|---|
| `base` | 1–5 km | Continental elevation: highlands vs lowlands, from the regime's sampled base level, cross-faded across regions | yes |
| `setpieces` | 150–1200 m | Sparse, individually placed landforms (escarpment, amphitheatre, mesa, hanging valley, big ridge with pass, cleft); never averaged | yes |
| `relief` | 15–300 m | Regime-driven sum of structural primitives | no |
| `terrace_transform` | — | Maps height onto storey-aligned treads/risers where the regime asks for it | detail only |

**Contracts kept.**
- `HeightfieldPlan.height01(pos, seed, include_detail)` keeps its signature and [0, 1] range.
  `include_detail=false` (the smooth field `WaterPlan.smooth01` traces) = base + setpieces.
  `include_detail=true` = all layers. `natural01`, `LOWPASS_M`, the water carve, storey/level
  quantization, the clamp (`MAX_CLIFF_STEP` 3), `TerrainTileField`, mesher, sheet, grass, water and
  village grading are unchanged consumers.
- Pure function of `(world_seed, position)`; all caches are bounded and output-identical
  (pattern: `LandformField._owner_parameters`, mutex-guarded static FIFO).
- The spawn falloff (`smootherstep((r - 60) / 180)`) still multiplies the whole field.

**Not in phase 1.** `valley_damp` (attenuating relief near rivers) was considered and dropped:
`WaterPlan.noise_h` calls `natural01`, so relief that reads river distance creates a
height ↔ water cycle. Rivers trace the smooth field and the carve cuts through local relief,
bounded by `CONTAIN_DROP` containment. If review shows ugly trenches, add damping explicitly with
a cycle analysis (sub-project C is the natural home).

**Reserved slot.** A fixed-radius discrete stage over the quantized storey region, between storey
quantization and the clamp in `HeightfieldPlan.compute_*region`. Empty in phase 1.

**New modules** (all under `scripts/terrain/heightfield/`, scene-free, headless-testable):

| Module | Responsibility |
|---|---|
| `TerrainRegimeCatalog.gd` | Data: archetypes, parameter ranges, biome affinities, set-piece densities |
| `TerrainRegimeField.gd` | Regions, archetype choice, parameter sampling, border blending; `regime_at(pos)` |
| `ReliefPrimitives.gd` | Static noise building blocks in metres (+ shared domain warp) |
| `LandformSetpieces.gd` | Sparse placement, footprints, shapes, composition |
| `TerrainField.gd` | Composes the layers; `HeightfieldPlan.height01` delegates to it |

`LandformField.gd` is retired; its useful analytic shapes move into `LandformSetpieces`.

## 3. Regime layer (`TerrainRegimeField`)

**Regions.** Jittered Voronoi: one site per 640 m grid cell, jitter ±40% of the cell. A query
finds the nearest and second-nearest sites over the surrounding 3×3 grid cells. Site parameters
are cached per site.

**Large regions.** With a per-pair probability (catalogue `merge_chance`, ~0.2) a site copies its
archetype from a neighbour chosen by a coarser hash, so some regions read as one 1–2 km
territory.

**Archetype choice.** At the site, read `Helper.biome_weights5`. The archetype distribution is
`Σ_biome weight_biome × affinity[biome][archetype]`. Every archetype has a floor affinity (~0.03)
in every biome. Pick with the site hash. Visual biome boundaries are unchanged.

**Parameter sampling.** Every archetype parameter is a `[min, max]` range. Each draws an
independent hash `u ∈ [0, 1]` from (site, parameter index), unless the catalogue groups
parameters to share a draw. Each region also draws `scale ∈ [0.6, 1.7]` that multiplies all of
its relief wavelengths, giving scale variety within one archetype.

**Borders.** Let `e = d2 - d1` (second-nearest minus nearest site distance), with the query point
warped by 2-octave noise (~60 m amplitude) so borders never look straight. For `e < 120 m` the
two regions' `relief` cross-fades by `smootherstep(e / 120)` toward the nearest region. Outside
the band a point has exactly one regime. Terrace transforms cross-fade their strength the same
way.

**Base is blended broadly, not at the border.** Region base levels differ by up to ~20 storeys,
so a 120 m cross-fade would build a wall at every border. `base(x, z)` is instead a
Gaussian-weighted mean of the sampled `base_level` of all sites in the 3×3 grid neighbourhood
(σ ≈ 320 m), giving the km-scale continental surface. Sharp steps between regions come only from
border escarpments.

**Border escarpment (optional, catalogue flag, default on for review).** Where neighbouring
regions' base levels differ by ≥ 2 storeys, a set-piece escarpment may follow the warped border
segment instead of the plain cross-fade.

**API.** `regime_at(pos) -> {archetype, params, site, weight}` and `regimes_at(pos)` (both sides
inside a band) for review tools, the F3 readout, and future consumers (dressing, encounters, C/D
hooks). A static `force_archetype` override (tests, gallery, review) makes every region one
archetype.

## 4. Relief primitives (`ReliefPrimitives`)

Every primitive is static and pure, takes position plus explicit parameters in metres, and
returns metres. All share `warp(p, amplitude_m, wavelength_m, seed)`. Noise basis: the existing
`Helper._value_noise01` family, plus a gradient-noise helper if value noise proves too blocky for
ridges (implementation decides; the first implementation measures and records which).

| Primitive | Definition | Landform |
|---|---|---|
| `ridged` | Multifractal `(1 - abs(n))^sharpness`, octave weights driven by the previous octave; warped | Connected ridge networks between peaks |
| `pass_mod` | Slow noise along ridges lowering crest height by `pass_depth` at intervals `pass_spacing` | Passes / saddles through ridges |
| `cellular` | Worley F1 (pits/mounds) or F2-F1 (cell interiors vs boundaries), with `jitter` and a radial profile | Sinkholes, hollows, buttes, plateau cells |
| `gully` | Stripes oriented along the downhill gradient of `base + setpieces` (4 extra smooth samples), phase-jittered and amplitude-scaled by slope | Branching gullies and spurs on hillsides |
| `hummock` | Billow `abs(n)` 2–3 octaves | Gentle storey-scale rolling ground |
| `terrace_transform` | `h → s·floor(h/s) + s·riser(fract(h/s))`, `s = tread_rise_storeys × 4 m`, `riser` a smoothstep of width `riser_sharpness`; tread levels on storey multiples; tread edges warped | Benches, cliff bands (sharp riser ≥ 2 storeys becomes a wall), stepped valleys |

**Units.** Relief amplitudes are given in **storeys** in the catalogue and converted to metres
(×4), so each archetype states how many levels it produces. Terrace treads land on storey
multiples so quantization yields clean levels without sliver tiles.

## 5. Archetype catalogue (starter set, all values reviewable)

Wavelengths are before the region `scale` multiplier. "st" = storeys (4 m).

| # | Archetype | Primitives | Key ranges | Set pieces |
|---|---|---|---|---|
| 1 | Rolling downs | hummock + sparse cellular knolls | relief 1–2 st; hummock λ 60–140 m; knoll spacing 150–300 m | rare escarpment |
| 2 | Ridge and pass | ridged + pass_mod + gully | ridge spacing 60–200 m; ridge height 2–5 st; pass spacing 150–400 m, pass depth 50–80% of ridge | big ridge with pass |
| 3 | Escarpment country | terrace_transform on base + hummock | tread rise 2–3 st (cliff risers); tread depth 40–150 m; riser sharpness high | escarpment (dense), cleft |
| 4 | Terraced valleys | valley trough (warped centreline through the site at a sampled azimuth; height rises with distance beyond the half-width) + terrace_transform | tread rise 1 st; 3–6 treads per side; valley width 150–400 m | amphitheatre |
| 5 | Karst hollows | cellular F1 pits + large shallow F1 hollows + knobs | sinkhole Ø 20–60 m, depth 1–3 st; hollow Ø 80–200 m, depth 1–2 st | cleft |
| 6 | Tableland | cellular F2-F1 plateaus + terrace (sharp) + gully | plateau cell 80–250 m; rim height 2–4 st; channel width 15–40 m | mesa, cleft |
| 7 | Highland massif | ridged (high amplitude) + gully + pass_mod | relief 4–8 st; ridge spacing 120–300 m | hanging valley, big ridge with pass |
| 8 | Low flats | hummock (weak) + low mounds | relief 0–1 st | none (reserved for C: deltas, braided channels) |

Each archetype also samples `base_level` (storeys above sea floor): low flats 0–2, rolling and
terraced 1–6, escarpment and karst 2–8, tableland 4–12, ridge 4–14, massif 8–24, all within the
128 m amplitude.

**Biome affinities** (starting weights, floor 0.03 elsewhere):

| Visual biome | Main archetypes |
|---|---|
| Sunwash Meadows | rolling downs .45, terraced valleys .25, escarpment .20 |
| Lanternwood | rolling downs .35, karst hollows .30, ridge and pass .25 |
| Opal Highlands | highland massif .40, ridge and pass .25, tableland .20, escarpment .15 |
| Cherryveil | terraced valleys .45, rolling downs .35 |
| Moonfen | low flats .65, karst hollows .25 |
| Amber Heath | tableland .45, escarpment .35 |
| Jade Estuary | low flats .50, terraced valleys .30 |

## 6. Set pieces (`LandformSetpieces`)

**Placement.** One candidate per 512 m grid cell at a hashed position. It is admitted with the
probability its region's archetype gives that set-piece kind. Overlap is resolved by Matérn-II
priority (hash) against candidates in the 3×3 neighbouring cells whose footprints intersect, so
the result is order-independent and seam-free. The kind, orientation, size and parameters come
from the candidate hash and catalogue ranges.

**Composition.** Each set piece returns `(delta_m, mask)`. Admitted set pieces never overlap, so
`setpieces(x, z) = Σ delta·mask`, with no averaging between shapes. Masks are feathered over
24–48 m (≥ 2 tiles) so set pieces join the regime relief, whose amplitude they suppress by
`(1 - 0.7·mask)` inside their footprint so the shape stays legible.

| Kind | Shape (from `LandformField` where noted) | Size |
|---|---|---|
| Escarpment | Long warped step, high/low sides (LandformField 0, sharpened) | 400–1200 m long, 2–4 st |
| Amphitheatre | Horseshoe ridge with a wide mouth (1) | Ø 200–500 m |
| Mesa / butte | Flat crown, low skirt, optional needle (3) | Ø 120–400 m, 3–6 st |
| Big ridge with pass | Continuous spine with saddle (4) | 500–1200 m |
| Cleft (open) | Narrow winding slot between shoulders (6), slot ≥ 24 m (2 points) so it stays walkable | 200–600 m |
| Hanging valley | Tributary floor on a lip above a trunk trough (8) | 300–800 m, lip 2–4 st |
| Border escarpment | Escarpment following a regime border (§3) | border segment |

**Hooks for C/D.** Set-piece records (kind, frame, footprint) are queryable
(`setpieces_in_rect`). A cleft or hanging-valley lip is where D (roofed clefts/arches) and C
(waterfalls) will attach. No behaviour is added for them here.

## 7. Measurement and review

**Structure survey** `tests/harness/terrain_structure_survey.gd` (headless; seeds and area from
args; writes JSON plus a printed table broken down by archetype). It samples the final graded
storey region (`HeightfieldPlan` with water) in random 48 m windows (4×4 points):
- `structured`: share of windows with ≥ 1 storey difference.
- `tactical`: share with both a wall (cliff) edge and a walkable climbing edge.
- `speckle`: isolated single-point storey islands/pits per km².
- `wall_run`: longest straight-ish wall run without a walkable crossing (p50/p95).
- `trapped_area`: share of area in level components only reachable across walls.
- Global: settlement site count (`SettlementPlan`), river count, total wall length per km².

The same harness run on the pre-change field gives the baseline. Phase 1 has **no hard
thresholds**: numbers inform owner review. The clean-up pass is warranted if `speckle`,
`trapped_area` or `wall_run` p95 are visibly the problem in review. Each of those maps to one
clean-up operation (opening/closing, level connectivity, guaranteed ramps).

**Region map** `tests/harness/terrain_regime_map.gd` (headless): writes a top-down PNG of a
4×4 km window, shaded by storey with hillshade, regime borders and set-piece outlines overlaid,
and a legend. This is the fastest iteration view.

**Archetype gallery** `tests/harness/regime_gallery.tscn` (windowed, mirrors `tile_gallery`):
`-- --archetype NAME --samples N --seed S --output DIR`. It forces the archetype, streams a
3×3-chunk site through the real streamer/mesher/sheet per sample, and captures one oblique view,
one high view and one F9-category view.

**In game.** The F3 readout adds the regime archetype and site. F4 review teleports gain one
spot per archetype (generated by the region-map harness for the review seed 2697992464).

**Performance.** `tests/harness/september15_landform_cost.gd` is updated to time `height01`
with and without detail. Budget: smooth field (river tracing) ≤ 1.5× current per sample; detailed
field ≤ 3× current. Report the 49-chunk `profile_terrain.gd` startup against the current main.

## 8. Testing

- `test_terrain_regime_field.gd`: determinism and query-order independence; border continuity
  (height is continuous across a Voronoi edge, sampled at 0.5 m); exactly one regime outside the
  band; `force_archetype`; biome bias (affinity proportions over many sites within tolerance);
  parameter ranges respected.
- `test_relief_primitives.gd`: each primitive is deterministic, bounded by its declared amplitude,
  and wavelength-scaled; terrace treads land on storey multiples.
- `test_landform_setpieces.gd`: Matérn-II placement is order-independent across overlapping
  queries; no two admitted footprints intersect; masks feathered ≥ 24 m; `setpieces_in_rect`
  matches pointwise evaluation.
- `test_terrain_field.gd`: `height01` in [0, 1]; `include_detail=false` excludes relief; spawn
  falloff preserved.
- Existing tests: `test_september11_landforms`, `test_september15_landform_cache`, and
  `test_atmosphere_field`'s landform references are retired or rewritten against the new modules.
  Geography-pinned tests are re-pinned to equivalent current sites found programmatically, never
  loosened (AGENTS.md). The full suite is compared to the current-main baseline failure list.

## 9. Risks

1. **More cliffs fragment routes and settlements.** Fewer walkable route edges and fewer flat
   town sites. Survey settlement count and route connectivity against baseline; tune relief down
   in affected archetypes or add the guaranteed-ramp clean-up op.
2. **The carve cuts deep trenches through relief.** See §2 (valley_damp deferred). Watch in
   review.
3. **The clamp shaves high relief.** `MAX_CLIFF_STEP` 3 lowers points more than 3 storeys above
   their lowest neighbour, so massif peaks may plateau. Expected and acceptable for now.
4. **Cost.** Primitive count per sample is the main lever; the smooth field stays cheap because
   river tracing samples it heavily.
5. **Border mush.** If 120 m cross-fades still read as averaged blobs, shorten the band or prefer
   border escarpments.

## 10. Phasing

1. **Phase 1 (this spec):** primitives, catalogue, regime field, set pieces, composition into
   `height01`, the survey/map/gallery harnesses, the F3 readout, re-pinned tests. Then owner
   visual review and iteration on parameters and archetypes.
2. **Phase 2 (conditional on §7):** discrete clean-up pass in the reserved slot.
3. **Later specs:** C (water-coupled landforms, using set-piece/regime hooks), D (overhangs), and
   a possible 6 m lattice (sampling plus slope-rule change only, since landforms are in metres).

## Deviations in the phase 1 implementation

- Voronoi site jitter is ±30% (offsets in [0.2, 0.8]) with a 5×5 search, so nearest
  distances are exact.
- `base` is a smootherstep-bilinear interpolation of region base levels on a 320 m node grid,
  not a Gaussian-weighted site mean.
- Border blending weighs **every** site within 120 m of the nearest
  (`1 - smootherstep((d - d1) / 120)`, normalized), not just the two nearest: a two-site blend
  jumps where runner-up sites swap order.
- The smooth field rivers trace is base + set pieces + each regime's **macro** relief (ridge
  spines, escarpment stairs, valley troughs, plateau cells), not base + set pieces alone. Without
  it, mountains were invisible to rivers and headwater sources fell below the density guard.
- The gentle archetypes (rolling downs, karst hollows, low flats) contribute their first
  hummock octave to the macro relief, so headwaters have rounded hills to rise from.
- Spawn: regions whose site lies within 1.2 km of the origin are calm rolling downs (base ≤ 2
  storeys, relief ≤ 1) and never merge; no set piece comes within 400 m of the origin.
- Gully kernels use a compactly supported window (a truncated Gaussian left seams).
- Escarpment country uses a warped triangle-wave stair (one tread rise per tread depth), not
  value noise.
- Gullies follow the gradient of the region's own ridged term (ridge and massif archetypes only).
- Set-piece lengths are capped at 840 m (footprint radius ≤ 480 m).
- Deferred: border escarpments, valley damping near rivers, the F9 view in the archetype gallery.
- Archetype recipes live in `RegimeRelief.gd`; the catalogue stays pure data.
