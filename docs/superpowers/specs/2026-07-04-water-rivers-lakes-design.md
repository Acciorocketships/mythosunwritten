# Water: River Networks with Attached Ponds — Design

**Date:** 2026-07-04
**Status:** Approved (brainstorm 2026-07-04)
**Depends on:** field-driven terrain (2026-06-26), cliff dressing (2026-06-27)

## Summary

Deterministic procedural water for the field-driven terrain. All water is one
system: **river networks**. A river starts at a small **source pool** in the
mountains, traces a snaking channel downhill, and always ends in water — either
by **joining a higher-priority river** or by stamping a **terminal pond**.
There is no independent lake field; every pond/lake is attached to a river
(the pond stamp primitive still supports standalone use later if wanted).

Water bodies **carve** the heightfield before storey quantization, so the
existing quantize → clamp → cliff/slope/dressing pipeline builds banks, bank
cliffs, and shoreline geometry with no downstream changes. Ponds get flat
stepped (storey-aligned) surfaces; rivers get **continuous flowing ribbon
surfaces** that follow the descending bed. The player can swim in all of it
via the existing buoyancy swim system.

### Goals

- Rivers with real topology: source in high ground, monotone downhill flow,
  guaranteed termination in water. Lakes/ponds exist only as network nodes.
- Deterministic and chunk-local: pure function of `(world_seed, source
  super-cell)` with bounded windows — same anti-churn guarantee as the
  heightfield. Any chunk computes identical water no matter the query order.
- Carve-based integration: one touch point in `HeightfieldPlan.raw_height`.
- Flowing river visuals without baked flow maps; ponds and rivers share one
  stylized shader family (visual consistency with the existing water look).
- Swimming everywhere, with per-body water surface heights.
- Spawn area stays dry.

### Non-goals (v1)

- Bridges, reeds/cattails/lily pads, bank decoration (master design §11.4/§11.7
  — later passes).
- Dedicated waterfall shader + foam particles (v1 renders steep ribbon
  reaches; polish pass later).
- River current pushing swimmers (v2 — volumes already carry a flow vector).
- Oceans / global sea level, distant-water LOD, audio.

## Architecture

New pure planning class, peer of `HeightfieldPlan`:

```
scripts/terrain/water/WaterPlan.gd      (class_name WaterPlan, RefCounted)
scripts/terrain/water/RiverTrace.gd     (trace result record: polyline, bed, widths, join/pond)
scripts/terrain/water/PondStamp.gd      (pond record: center, radius, shape seed, level, depth)
```

`WaterPlan` is constructed with `world_seed` (plus the tunables below) and
answers two queries:

- `carve_at_cell(cx, cz) -> float` — metres to subtract from the raw noise
  height at a tile cell (0.0 where no water influence).
- `bodies_near(center_cell, radius_cells) -> { ponds: [PondStamp], reaches: [RiverTrace slices] }`
  — the water bodies whose footprint overlaps the window, for surface meshing
  and swim volumes.

**Single touch point:** `HeightfieldPlan` gains an optional `water_plan`;
`raw_height(cx, cz)` returns `noise_height − water_plan.carve_at_cell(cx, cz)`.
Storey quantization, the trickle-down clamp, levels/residuals, the surface
field, the mesher, and cliff dressing all operate on carved ground unchanged —
banks, bank cliffs, and shore slopes emerge from the existing machinery.
`compute_region`'s `target_cache` already caches per-cell quantized storeys,
so carve cost is amortized the same way the noise cost is.

The legacy tile-era water (`Helper.is_water`, the camera-following global
sheet `terrain/water/WaterSurface.tscn`) is retired from the field-terrain
path (kept on disk until the old tile scenes are deleted).

### Determinism & bounded windows

- River sources live on a **super-grid** of `SUPER = 768 u` (32 cells). Each
  super-cell hashes (splitmix-style, like `Helper._cell_hash01`) to zero or
  one source candidate.
- A trace is bounded: `MAX_STEPS` steps of `TRACE_STEP` metres (defaults:
  220 × 12 u ⇒ max river length 2 640 u). Terminal pond radius is bounded by
  `POND_R_MAX`.
- A chunk's relevant super-cells are those within
  `ceil((max_length + POND_R_MAX + carve_margin) / SUPER) + 1` rings — a fixed
  window, the same trick as the heightfield's clamp margin.
- Traces are pure functions of `(world_seed, super_cell)`; `WaterPlan` caches
  them per instance (a per-session performance cache, not a correctness
  dependency).

## River generation

**Source selection.** Per super-cell: hash a jittered candidate point; accept
iff the **smooth height field** exceeds `SOURCE_MIN_H`, and the point lies
outside the spawn water ring. `smooth_height` = `HeightfieldPlan._height01`
with the fine `detail` octave omitted but everything else kept (base + hills,
rocky multiplier, ridge term, origin falloff) × amplitude — exposed as a
helper so tracing descends the same macro landforms the terrain renders,
without jittering on the fine octave.
Accepted source ⇒ stamp a small **source pool** (radius ≈ 1.5 cells) and begin
a trace.

**Trace loop.** At each step:

1. `grad` = finite-difference gradient of the smooth height field.
2. `dir = normalize(lerp(-grad, prev_dir, MOMENTUM))`, then rotate by a
   meander angle sampled from low-frequency noise along arc length — the
   momentum keeps it from jittering, the meander makes it snake.
3. Weak **steering bias** toward the nearest higher-priority water point
   (channel or pond) within `SENSE_RADIUS` — makes junctions common.
4. Advance `TRACE_STEP`; record point with arc length `s`, width
   `w(s)` (widens downstream: `W_MIN → W_MAX` over max length), and bed
   `bed = min(bed, smooth_height(p)) − CHANNEL_DEPTH` — **monotone
   non-increasing by construction**, so flow direction is never ambiguous.

**Termination** (first hit wins):

| Condition | Result |
|---|---|
| Point enters a higher-priority river's channel, and that river's bed there ≤ our bed + ε | **Join** — truncate, no pond; downstream river's ribbon carries the water |
| Point enters a higher-priority river's terminal/source pond footprint | **Join** at the pond |
| Gradient magnitude below `FLAT_EPS` (basin floor) | **Terminal pond** |
| Smooth height below `LOWLANDS_FLOOR` | **Terminal pond** |
| Point enters the spawn disk (`SPAWN_WATER_RADIUS`) | Truncate at boundary, **terminal pond** just outside |
| `MAX_STEPS` reached | **Terminal pond** |

Terminal pond radius scales with arc length (`POND_R_MIN → POND_R_MAX`) —
longer river, bigger catchment, bigger lake.

**Junction rule (determinism).** Priority = hash of the source super-cell
(ties impossible with a 64-bit mix). River R may only join strictly
higher-priority rivers. Dependency depth is capped at `JOIN_DEPTH = 2`: when
tracing R, higher-priority rivers are resolved with depth 1 (their own joins
tested against **raw untruncated traces**). Beyond the cap, raw traces are
used. The approximation's only failure mode is joining a channel segment that
was itself truncated slightly earlier — rare, and the fallback everywhere is
"stamp a terminal pond," which never looks wrong. Join tests also require the
target's bed to be at-or-below ours (water never joins uphill).

## Pond stamps

A `PondStamp` = `{ center, radius, shape_seed, level (storey int), depth }`.
The footprint is the radius modulated by low-frequency radial noise (wobbly,
not circular). Two rules:

- **Level:** `level = quantize_storey(min pre-carve noise height over the
  footprint ∪ one-cell ring)`. Endpoint ponds sit in local lows already, so
  this is a safety clamp, not a crutch — it guarantees water never sits above
  its own banks. "Pre-carve" means the raw noise field, so pond levels don't
  depend on other bodies' carves (no ordering dependency).
- **Carve:** inside the footprint, pull cells down to
  `level·4 − depth`, feathered to zero at the rim with the shape noise.
  Water surface renders at `level·4 − SURFACE_DROP` (≈ 1.0 m below the bank
  storey so the bank lip reads).

Source pools use small fixed radius/depth; terminal ponds scale as above.
The stamp is self-contained — a future standalone decorative pond is the same
record with no river attached.

## River carving

`carve_at_cell` for rivers: distance from the cell center to the river
polyline (segment-wise; segments spatially bucketed per super-cell so a cell
only tests nearby segments). Within `w(s) + FEATHER`, carve down toward the
bed profile with a smooth U cross-section (smootherstep falloff by lateral
distance). The carve is cell-resolution (24 u), so a channel is at least one
cell wide — consistent with the chunky diorama look; the ribbon mesh is
narrower than the carved gulley (`w(s) ≤ carve width − margin`) so the water
never clips the cell-aligned banks on tight bends.

Where the bed drops ≥ 2 storeys over a short arc, the quantized channel forms
a cliff — a **waterfall site** (v1: steep ribbon; the site list is exposed for
the later polish pass and for KayKit dressing exclusion if needed).

## Water surfaces & shaders

Per chunk (built alongside the terrain chunk, same streaming lifecycle):

- **Pond surfaces:** one flat quad sheet per pond level covering footprint
  cells (merged per chunk into one mesh; skip cells where carved ground ≥
  surface — islands stay dry).
- **River ribbons:** polyline slices clipped to the chunk (+ 1-segment
  overlap to kill seams). Ribbon height = smoothed monotone envelope of
  `quantized bed + RIBBON_DEPTH_OFFSET`, flattening to pond level as it
  approaches its endpoint pond (backwater reach). Per-vertex: `CUSTOM0` =
  flow tangent, `UV.y` = arc length, `UV.x` = across. Flow is derived from
  the curve — **no baked flow maps** (the waterways-net technique, MIT,
  reimplemented in GDScript; we do not take the .NET dependency).
- **Shared shader family:** extract the existing wave/depth-tint/shore-foam
  functions from `terrain/water/Water.gdshader` into
  `terrain/water/water_common.gdshaderinc`. `water_pond.gdshader` keeps
  today's look (static sheet, world-position waves). `water_river.gdshader`
  adds tangent-aligned dual-scroll of the noise normal (classic no-flow-map
  trick) and boosts foam where the ribbon is steep (rapids/waterfall reaches).
  Depth-fade + foam hide ribbon/bank intersections.

## Swimming

Per chunk, `Area3D` swim volumes on the existing water layer (bit 7):

- Ponds: one box per pond-chunk intersection, bed → surface.
- Rivers: boxes along ribbon reaches (segment-aligned, surface = local ribbon
  height).

Each volume carries `surface_y` (and rivers a `flow` vector) as metadata.
`characters/character.gd` replaces the `WATER_SURFACE_Y = −1.5` constant with
the max `surface_y` of currently-overlapped volumes; buoyancy, bobbing, and
the bank-exit leap are unchanged. Current push from `flow` is a v2 toggle.

## Tunables (initial values)

| Name | Default | Meaning |
|---|---|---|
| `SUPER` | 768 u | source super-grid pitch |
| `SOURCE_MIN_H` | ~60 % of amplitude | min smooth height for a source |
| `TRACE_STEP` | 12 u | polyline step |
| `MAX_STEPS` | 220 | hard trace bound (max length 2 640 u) |
| `MOMENTUM` | 0.65 | direction inertia |
| meander amp/scale | ±35° / 90 u | snake wildness |
| `SENSE_RADIUS` | 96 u | junction steering bias range |
| `W_MIN → W_MAX` | 6 → 16 u | ribbon half-width growth |
| `CHANNEL_DEPTH` | 2.5 m | bed below terrain |
| `FEATHER` | 12 u | carve lateral falloff |
| source pool r / terminal pond r | 36 u / 60–140 u | stamp sizes |
| pond `depth` | 3.5 m | bowl depth below level |
| `RIBBON_DEPTH_OFFSET` | 1.5 m | river surface above carved bed |
| `SURFACE_DROP` | 1.0 m | water below bank storey top |
| `SPAWN_WATER_RADIUS` | 200 u | dry spawn disk (≥ spawn-clear 60+120) |
| `JOIN_DEPTH` | 2 | junction dependency cap |

## Testing (GUT, pure-function first)

- **Determinism:** two `WaterPlan` instances (same seed) produce identical
  traces/stamps for sampled super-cells; `carve_at_cell` identical when
  reached via different chunk windows (chunk-order independence).
- **Bed monotonicity:** every trace's bed profile is non-increasing.
- **Boundedness:** every trace ≤ `MAX_STEPS`; every non-join trace ends in a
  pond; every join's target exists and has lower-or-equal bed at the junction.
- **Pond containment:** pond level ≤ min pre-carve storey over footprint ∪
  ring.
- **Spawn dry:** no carve and no bodies within `SPAWN_WATER_RADIUS`.
- **Seam safety:** carve continuity across chunk borders (reuses the existing
  seam-test approach from the mesher tests).
- Swim/rendering verified in-game (MCP screenshots + pinned seed, per the
  debug overlay workflow).

## File plan

New: `scripts/terrain/water/WaterPlan.gd`, `RiverTrace.gd`, `PondStamp.gd`,
`scripts/terrain/water/WaterSurfaceBuilder.gd` (chunk meshes + volumes),
`terrain/water/water_common.gdshaderinc`, `water_pond.gdshader`,
`water_river.gdshader`, GUT tests under `tests/`.
Modified: `HeightfieldPlan.gd` (carve hook), `FieldTerrainStreamer.gd` (build
water per chunk), `characters/character.gd` (per-volume surface y).
Retired from field path: `Helper.is_water` consumers, global `WaterSurface`
sheet.

## Open questions / deferred

- Waterfall dedicated shader + splash foam (polish pass; sites already
  detected).
- Bridges at path crossings (master design §11.6-§11.7, after the path
  network exists).
- Bank flora (reeds/cattails/lily pads) via `DecorationScatter` wet-ground
  weights.
- River current push on swimmers (volumes already carry `flow`).
- Whether meadow biomes should get occasional standalone decorative ponds
  (the primitive supports it; intentionally not scheduled).
