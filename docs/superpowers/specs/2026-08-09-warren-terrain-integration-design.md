# Warren ↔ Terrain Integration — Design Spec

**Date:** 2026-08-09
**Status:** Proposed (investigation + design). No production code in this
commit.
**Branch:** `feat/mass-first-warren`
**Extends:** `docs/superpowers/specs/2026-08-06-mass-first-warren-design.md`
(phase 2 of the reviewer-approved Option C).
**Reverses one decision of:** `docs/superpowers/specs/2026-07-17-paths-manmade-features-design.md:21`
("Terrain reshaping | None. Villages and paths never flatten, raise, carve, or
stamp the heightfield") and its deferral at `:688-689`. That reversal is the
whole point of this milestone and is called out explicitly rather than
absorbed silently.

---

## 1. Problem

Mass-first towns read correctly at street level and fail at the seam where the
city meets the ground. Four rounds of visual review closed every escape route
in turn, and the closing finding of the last round is a *trilemma*:

> **grounded houses**, **2–3 storey visible faces (stone included)**, and
> **no masonry monument** are jointly unsatisfiable on a 16–20 band hill while
> the fabric is responsible for rendering everything below the houses.

The measured horns:

| Horn | Evidence |
|---|---|
| Ungrounded | 74/92 (seed 7) and 84/100 (seed 11) houses stand >2 bands above their own ground with nothing drawn beneath (ledger, REVERTED 2). |
| Composed towers | Drawing that mass took floating to 0/252 but halved the composed face and rendered as the masonry terrace-farm rounds 2–3 rejected. |
| Monument | Rendering the whole standing solid (`WarrenFabricCompiler._retained_terrace`, `WarrenFabricCompiler.gd:79-120`) is what produced the "stone ziggurat" and then "far too much stone". |

The resolution the controller adopted, twice pre-endorsed by the reviewer
("it is also permissible to change the terrain itself… I think that could be a
useful direction", and their own question "if building into existing terrain
without changing it, is there a system?"): **the hill becomes real terrain.**
Terrain renders and collides everything below the houses — grass, slopes,
KayKit cliffs — and the fabric places only buildings, paths and supports on
top.

A second, independent defect makes this urgent rather than merely desirable.
A read-only audit proved mass-first cannot run on sloped ground **at all**:

- `WarrenMassifBuilder._worst_neighbor_step` (`WarrenMassifBuilder.gd:112-128`)
  compares **absolute** `top_at` between neighbours, so a terrain step is
  charged to the builder as a cliff it must forbid.
- `WarrenMassif.widest_plateau_cells` (`WarrenMassif.gd:90-114`) groups columns
  by **absolute** `top_at`. On a slope where the base rises as the Gaussian
  terrace falls, the sum is constant across many cells — the audit's observed
  "12–14 cell plateaus on a slope".
- `WarrenMassif.terrace_levels` (`WarrenMassif.gd:80-87`) counts distinct
  **absolute** tops, so on relief the ≥5-level gate passes vacuously.

`WarrenMassifBuilder.build` therefore rejects, or accepts meaninglessly, before
anything downstream is reached.

---

## 2. What exists today

Everything in this section is a read of the current tree, not a proposal.

### 2.1 Terrain is a 24 m quantised heightfield, and it is strictly 2.5D

| Fact | Value | Evidence |
|---|---|---|
| Terrain cell | 24.0 m | `TerrainSurfaceField.gd:11`, `HeightfieldPlan.gd:13` |
| Storey | 4.0 m | `HeightfieldPlan.gd:14` |
| Level (sub-storey terrace) | 1.0 m, 0–3 | `HeightfieldPlan.gd:15-18` |
| Amplitude / max storeys | 22.0 m / 8 (=32 m ceiling) | `TerrainWorldTuning.gd:8-9` |
| Max cardinal storey step | 3 | `TerrainWorldTuning.gd:10`, applied `HeightfieldPlan.clamp_field:186-204` |
| Chunk | 192 m, 8 cells | `TerrainChunkMesher.gd:8,12` |
| Mesh sample step | 2.0 m (96 quads/axis) | `TerrainChunkMesher.gd:11,13-14` (the `# 3.0`/`# 64` comments are stale) |
| Cliff threshold | a neighbour ≥2 storeys below ⇒ flat cliff top | `TerrainSurfaceField._is_cliff_top:36-49` |
| 1-storey drop | ramped smootherstep slope, walkable | `TerrainSurfaceField.surface_y_in_cell:307-329`, `is_walkable_edge:189-192` |

**No voids, no overhangs, no tunnels.** The plan is
`Dictionary[Vector2i] -> int` (`HeightfieldRegion.gd:11-12,35,54`); the mesher
runs a single `for iz in GRID: for ix in GRID` loop with a collision buffer
pre-sized to exactly `GRID*GRID*6` (`TerrainChunkMesher.gd:112,140-141`);
`TerrainSurfaceField.surface_y_in_cell` is documented as single-valued
(`:322`). The only place two collision surfaces share an XZ column is the
≤2.4 m ground apron under a higher flat neighbour (`TerrainChunkMesher.gd:25`,
`_emit_aprons:771-850`) — a sealing band with no headroom and no authoring
API. Adding overhangs would replace the plan, the soup and `sample_baked`, not
extend them.

### 2.2 There is exactly one height-write mechanism, and it is the water carve

`HeightfieldPlan._sample` (`HeightfieldPlan.gd:47-63`) computes
`h - carve` and only then quantises (`:414-415`). The carve source is
duck-typed and optional (`:33-35`, `set_water_plan:92-97`), and
`WaterPlan.carve_at_cell(cx, cz) -> float` (`WaterPlan.gd:668`) is documented
as *"a pure function of (world_seed, cell); the caches never change the
value"*. `PondStamp.carve_at` only ever lowers (`PondStamp.gd:66-72`).
`HeightfieldPlan.set_raw_height_override` (`:86-89`) has **zero production
callers** — every call site is under `tests/`.

This is the precedent the massif write path must follow exactly.

### 2.3 `FeatureGroundField` writes surface **type**, never height

`FeatureGroundField` resolves a `surface_id` — `NATURAL := 0`,
`WORN_PATH := 1` (`FeatureGroundField.gd:7-8`) — by priority over 2D
primitives (`surface_at_cell:46-59`), plus a clearance distance field
(`clearance_at:65-70`). `FeatureGroundShape` is a closed 2D vocabulary of
circle / capsule / oriented-rect (`FeatureGroundShape.gd:7-11`) with no Y
component anywhere. **There is no pad-flattening today**, and the invariant is
stated in code: `SettlementPlan.gd:4-7` — *"villages never flatten, raise,
carve, or otherwise stamp the procedural landscape."*

So the answer to "does `FeatureGroundField`/`FeatureGroundShape` already
support raising the heightfield?" is a flat **no**, and the extension must not
be bolted onto them: they are consumed on the worker *after* the region is
built (`WorldFeaturePlan.context_for:33-59`), which is too late.

### 2.4 The read path is already plumbed end to end

```
VillageWarrenFabricSolver._sample_ground_bands   (:441-477)   5 probes/column, 3 m pitch
  -> WarrenBuiltTownSolver.solve_attempt(..., ground_bands)   (:241-250)
  -> WarrenTownSolver.solve_attempt / mass_first_frontier     (:357-376)
  -> WarrenMassifBuilder.build(world_seed, ground_bands)      (:41-84)
```

`_sample_ground_bands` already samples the real surface at each 3 m massif
column (`VillageWarrenFabricSolver.gd:446-471`) via
`VillageTerrainView.surface_y` → `TerrainSurfaceField.surface_y`
(`VillageTerrainView.gd:33-36`), and `WarrenExcavationCarver` is **already
ground-relative everywhere** — `_is_at_grade` is `cell.y == base_at(column)`
(`WarrenExcavationCarver.gd:942-946`), and every borability, wall and lane
test reads `massif.base_at(column)` (`:506, 712, 718, 845, 865, 1070, 1184`).
The carver needs no change.

Two gates in the *production adapter* refuse relief outright:
`MAX_FABRIC_TERRAIN_RELIEF := 4.5` m (`VillageUrbanFabricPlan.gd:12`), checked
at `VillageWarrenFabricSolver.gd:80` and again at
`VillageUrbanFabricPlan.gd:132`.

Note the seam's exact shape: `WarrenMassifBuilder.build` and
`WarrenTownSolver.mass_first_frontier` take a plain
`Dictionary[Vector2i -> int]`, never a `HeightfieldRegion`
(`WarrenMassifBuilder.gd:41-42`, `WarrenTownSolver.gd:357-358`). Outside
`VillageWarrenFabricSolver._sample_ground_bands`, **nothing in `tests/` or
`tools/` converts a real region into that dictionary** — the only unit
coverage is a uniform all-2 lift (`tests/test_warren_massif.gd:35-40,51`), and
`tests/harness/warren_mass_first_report.gd --stage terrain` (`:1499-1526`)
synthesises `flat` / `slope 0-8` / `terrace 0/2/6` dictionaries by hand
(`:1508-1514`). That is why the audit's "fails at the first stage on any
non-flat ground" went unnoticed for the whole build.

### 2.5 The fabric currently renders the whole hill

`WarrenFabricCompiler._retained_terrace` (`WarrenFabricCompiler.gd:79-120`)
declares **every macro mass cell that is not a building**, expanded 1→4 at
construction resolution (`:107-119`), into
`SettlementFabricPlan.retained_terrace_cells` (`:26`, `set_retained_terrace:81-91`).
`SettlementFabricAssembler.terrace_retaining_payload` (`:186-208`) then draws
it as `house_plinth_walls` + `hill_substrate_walls` (`:222-...`). This whole
block is mass-first only (keyed on `town.volume.mass_context[&"massif"]`,
`:107`) and it *is* the masonry monument the reviewer rejected.

### 2.6 A conform-only system already exists

`VillageTerrainSurvey` (`VillageTerrainSurvey.gd`) discovers building perches
on **immutable** terrain at `GRID_STEP := 3.0` — the same 3 m pitch the massif
uses — with `NATURAL` vs `RETAINED` support kinds
(`VillageTerrainPerch.gd:8-11`), `MAX_RETAINED_RELIEF := 5.95`,
`MIN_RETAINED_SUPPORT_RATIO := 0.30`, `CLIFF_EXPOSURE_DROP := 2.0`
(`VillageTerrainSurvey.gd:13-22`), and its header states *"The survey never
edits terrain"* (`:5-6`). It feeds `VillageMassingSolver` (`:54-72`) and
`VillageOutskirtsSolver` (`:38`). `FoundationSolver`
(`FoundationSolver.gd:10-60`) and `SupportSolver` (`SupportSolver.gd:8-50`)
fit fixed modules down to whatever ground `TerrainSurfaceField.height_bounds`
reports, never stretching collision.

This is the direct answer to the reviewer's question 5: **yes, there is a
system for building into existing terrain without changing it, it is
production code, and mass-first has simply never used it.**

### 2.7 Collision and streaming, as built

- Terrain collision is authored on the **worker** as raw CPU triangle soup
  (`TerrainChunkMesher.gd:111-113,174-180`, comment `:108-110`: *"Raw triangle
  soup straight into a `ConcavePolygonShape3D` — no SurfaceTool, no ArrayMesh,
  no `create_trimesh_shape` re-extraction"*), and turned into
  `StaticBody3D` + `ConcavePolygonShape3D` on the **main thread**
  (`commit_chunk:310-317`). Aprons and cliff walls do round-trip
  `create_trimesh_shape()` — main thread only (`:318-322, 331-335`).
- `CliffDressing` emits **visuals only**, no collision
  (`build_from_data:599-608`, `_multimesh:717-734`; header `:3-4`). Cliff
  collision is the mesher's boundary wall plane.
- There is **no terrain rebuild/dirty/invalidate API**. `invalidate_chunk`
  exists only on the dressing and feature commit queues
  (`FieldTerrainStreamer.gd:680,690,698`). A terrain chunk changes only by
  eviction past `KEEP_RADIUS` and re-entry (`:681-686`);
  `CHUNK_RADIUS := 3`, `KEEP_RADIUS := 4` (`:34-35`).
- Village fabric brings its own collision faces through the payload
  (`VillageWarrenFabricSolver._world_surface_mesh:219-225`,
  `EnvironmentCollisionBuilder`).

### 2.8 The dirt-street paint mechanism

There is **no `TERRAIN_STREET` terrain surface id**. `TERRAIN_STREET` is a
fabric enum (`PublicRealmSurfacePlan.gd:6-12`) translated into the terrain
vocabulary at `VillageWarrenFabricSolver.gd:176-185`: one
`FeatureGroundShape.oriented_rect` of one fabric cell (1.5 m) per
ground-level street cell, `surface_id = FeatureGroundField.WORN_PATH`,
`priority = VillagePlan.SURFACE_PRIORITY` (=120, `VillagePlan.gd:10`).
Those shapes ride `VillageRecord.surface_shapes`
(`VillagePlan.gd:54,102-103` → `VillageRecord.gd:10,35,38`) into
`FeatureGroundField.extended` (`WorldFeaturePlan.gd:41-57`).

The mesher then paints it: `PATH_OVERLAY_DIVISIONS := 8` subdivides the 2.0 m
sample step to **0.25 m** patches (`TerrainChunkMesher.gd:367,414`), each
patch takes `_path_uv` or `_grass_uv` by a binary
`features.surface_at_cell(...) == WORN_PATH` test (`:423-425,442`). It is a
UV swap: *"Terrain collision remains the unchanged coarse continuous sheet"*
(`:376-382`), and collision faces are written before any path branching
(`:174-180`).

Grass is suppressed by the same fact: `GrassField._footprint_overlaps_feature_surface`
rejects any anchor whose surface `!= NATURAL` (`GrassField.gd:311-321`,
gate at `:279-284`).

---

## 3. Architecture

### 3.1 The two-tier split, and the arithmetic that forces it

The massif works in a 3.0 m column / 1.5 m band lattice
(`WarrenVolumePlan.gd:9-10`); the terrain works in a 24 m cell / 4 m storey
lattice. At `RADIUS_CELLS := 16` (`WarrenMassifBuilder.gd:17`) the town
footprint is 33 columns = **99 m ≈ 4.1 terrain cells across**. The terrain
lattice therefore *cannot* carry the massif's terraces, and lowering
`TerrainSurfaceField.TILE` is not on the table — 24 m is baked into the
path lattice, `CliffDressing.PLACE = 10.5`/`OFFSETS`
(`CliffDressing.gd:33,53`), the grass tile, water, and every seed pin in the
world.

So the split is by **scale**, not by taste:

| Layer | Owner | Lattice | Renders |
|---|---|---|---|
| **Landform** — the hill, its slopes, its cliffs, the ground the town stands on | Terrain | 24 m / 4 m storey / 1 m level | Mesh sheet + grass + KayKit cliff dressing + collision |
| **Buildable layer** — 4–6 bands of occupiable mass above the sampled ground | Massif → fabric | 3 m column / 1.5 m band | Houses, street decks, stairs, supports, ≤2-band plinths |

That is exactly the controller's decision in the ledger (line 169): *"per-column
base becomes a rising terraced ground surface… with only ~4–6 bands of
buildable mass above it."* What this design adds is **who computes the rising
ground surface**: the terrain system, before the village exists.

**Relief budget — measure, do not assume.** With ≤1 storey per terrain cell
(a walkable smootherstep slope, never a cliff top —
`TerrainSurfaceField._is_cliff_top:36-49`), a 2-cell footprint radius buys only
2 storeys = 8 m = 5.3 bands of ground rise inside the town. Combined with a
4–6 band buildable layer that is 9–11 bands of vertical development, which
clears the excavation's `span >= 8` gate but *not* the massif's
`MIN_CORE_BANDS := 16` as currently measured. Three levers exist and Wave 3
must report their measured cost rather than pick one blind:

1. **Widen the footprint.** `RADIUS_CELLS` 16 → 24–32 gives a 3–4 terrain-cell
   radius (12–16 m / 8–10.7 bands of walkable rise) and delivers the
   horizontal sprawl the reviewer liked. Cost: massif columns scale as r²
   (565 columns at r=16, ledger line 178 → ~2200 at r=32) through the carver
   and partitioner loops.
2. **Permit 2-storey terrain cliffs inside the footprint.** 8 m dressed KayKit
   rock faces buy relief fast and are "mountain character", not masonry
   monument — but they are not walkable
   (`TerrainSurfaceField.is_walkable_edge:189-192`), so the route must cross
   them on fabric stairs (§3.6), and the reviewer's 2–3 storey face rule must
   be argued for rock the terrain authored rather than rock the fabric stacked.
3. **The level tier.** 1 m levels add up to 3 m of articulation, but
   `cliff_cap` pins level to 0 within 4 cells of a storey change
   (`HeightfieldPlan.level_at:344-359`), so levels only appear on broad
   terraces. Minor; name it, do not rely on it.

**`MIN_CORE_BANDS` must be re-derived, not weakened.** The property is "the
town has ≥16 bands of vertical development"; today's *proxy* is one column's
own height, which was correct only while the massif owned the whole hill. The
re-derivation is `terrain_relief_bands + buildable_layer_bands >= 16`,
measured over the footprint. This is the same scale-dependence argument the
ledger already accepted twice (parcel-count → footprint-cell share, isolated
count → isolated share, ledger lines 123 and 127) and it carries the same
three obligations: a controlled route-first A/B proving identity, an
invariance test pinning the property, and a measured distribution.

### 3.2 Write path — a settlement relief stamp, at the water tier

**Mechanism.** A new `SettlementReliefPlan` (proposed:
`scripts/terrain/features/SettlementReliefPlan.gd`) exposing

```gdscript
func relief_at_cell(cx: int, cz: int) -> float   # metres, >= 0, only ever raises
```

duck-typed into `HeightfieldPlan` exactly as `WaterPlan` is, via
`set_relief_plan()` mirroring `set_water_plan` (`HeightfieldPlan.gd:92-97`),
and applied inside `_sample` (`:47-63`) as

```gdscript
s = [h - carve + relief, carve]
```

so quantisation, the trickle-down clamp, the level tier, cliff classification,
dressing, grass suppression and collision are all **downstream and unchanged**.

**Why here and not in `FeatureGroundField`.** There is a hard dependency
order, and it is already correct for us:

```
FieldTerrainStreamer._ready()
  :153  _water       = WaterPlan.new(world_seed, ...)
  :154  _settlements = SettlementPlan.new(world_seed, _water)      <-- site identity, no heightfield
  :155  _plan        = HeightfieldPlan.new(...)
  :157  _plan.set_water_plan(_water)
  :190  _fields      = WorldFieldBlockCache.new(_plan, _water, ...)
  :192  _features    = WorldFeaturePlan.new(world_seed, _water, _fields, ...)
```

`SettlementPlan` is constructed **one line before** the heightfield and depends
only on `(world_seed, water)` plus the static pure noise
`HeightfieldPlan.height01` (`SettlementPlan.gd:30-33,73-76`). The stamp
therefore slots in at `:157+` with no cycle. Anything hung off
`WorldFeaturePlan` or `FeatureGroundField` would be circular: `VillageFrame`
is built *from* `_fields.region(block)` (`WorldFeaturePlan.frame_for:74-94`).

**Contract.**

- Pure function of `(world_seed, SettlementPlan.SEED_VERSION, cell)`. No
  caches that change values; a memo is allowed exactly as `_samples` is.
- **Monotone raise only** (mirror of the carve's monotone lower). Never
  negative. Never lowers natural ground; conform-only mode is a *zero* stamp,
  not a negative one.
- **Zero where the water carve is non-zero**, and the stamp's outer radius is
  bounded below `SettlementPlan.WATER_CLEARANCE := 108.0`
  (`SettlementPlan.gd:16`) so the two can never argue. Pinned by a test.
- **Bounded against the storey ceiling.** `quantize_storey` clamps to
  `[0, max_storeys]` (`HeightfieldPlan.gd:153-154`), so an unbounded stamp
  would silently truncate the hilltop into a wide flat plateau — precisely the
  shape `MAX_PLATEAU_CELLS` exists to forbid. The stamp returns
  `min(profile, max_storeys * STOREY_HEIGHT - MARGIN - h)`. Raising
  `HEIGHTFIELD_MAX_STOREYS` is forbidden: it is the clamp window margin
  (`storey_margin:210-211`) and re-rolls the entire world.
- **Window independence survives** because `quantize_storey` still clamps every
  target into `[0, max_storeys]`, so the `storey_margin()` proof at `:206-211`
  is untouched. A test must assert `compute_region` centred on the stamp and
  centred two chunks away agree cell-for-cell.
- **Profile shape**: bell, peak-offset, warped — the same family
  `WarrenMassifBuilder` already uses (`:45-69`), so the hill keeps its
  character; the stamp gets its own salt space and the massif no longer
  authors the mound.
- **Slope discipline**: inside the built footprint the profile's per-cell
  gradient is bounded so no cell has a neighbour ≥2 storeys below (no cliff
  top). Beyond it, 2–3 storey steps are allowed and become the dressed crag
  flanks. This is a checkable property of the stamp, tested directly on
  `HeightfieldRegion`.
- **One walkable approach.** `PathPlan` routes reject exposed cliff faces, so
  the stamp must leave at least one cliff-free corridor from the settlement's
  road node onto the mesa. Test: `TerrainSurfaceField.cardinal_strip_is_walkable`
  (`TerrainSurfaceField.gd:198-212`) succeeds along the approach axis.

**Both construction sites must be fed.** `FieldTerrainStreamer._ready()`
builds its plan inline (`:153-157`) while every harness and test goes through
`TerrainWorldTuning.make_heightfield` (`TerrainWorldTuning.gd:18-24`), whose
own header warns that harnesses copying literals means *"a valid pin in a
harness may not exist in the rendered world at all"* (`:4-7`). The stamp goes
into `TerrainWorldTuning` and the streamer is changed to call it, closing that
divergence in the same wave.

**Streaming implication.** There is no terrain rebuild API (§2.7). This is
fine and in fact required: the stamp is part of the *plan*, so a chunk is
built with the hill in it the first time and forever. Nothing invalidates,
nothing re-meshes, and the anti-churn guarantee (`HeightfieldPlan.gd:4-8`)
is preserved because the stamp is a pure function of seed and cell. The one
consequence to respect is that **a town's terrain must be decided before any
chunk near it is built** — which is already true, since the plan is built once
at `_ready()`.

### 3.3 Read path — relief-relative massif gates

Only three call sites are wrong, all measuring absolute height where they mean
relief:

| Site | Today | Change |
|---|---|---|
| `WarrenMassifBuilder._worst_neighbor_step:112-128` | `absi(top_at(a) - top_at(b))` | compare the *layer*: `absi((top-base)(a) - (top-base)(b))` for the built face, and separately assert the **terrain** step between the same two columns is one the terrain itself renders as a slope or a dressed cliff (i.e. hand the relief back to terrain instead of charging it to the builder). The missing-neighbour branch (`:123-124`) is already relative and stays. |
| `WarrenMassif.widest_plateau_cells:90-114` | groups by `top_at` | group by `top_at - base_at`, so a constant-thickness layer on a ramp is not a plateau. |
| `WarrenMassif.terrace_levels:80-87` | distinct `top_at` | distinct `top_at - base_at`; the ≥5-level gate then measures layer articulation, and the *ground's* terracing is the terrain's own storeys. |

`core_top_bands` (`WarrenMassifBuilder.gd:85-88`) is already
`top - base` and needs nothing. `_step_ceilings` (`:131-168`) operates on the
pure Gaussian and needs nothing. `WarrenExcavationCarver` needs nothing (§2.4).
`WarrenExcavationVolumeAdapter.envelope_from_massif` (`:14-66`) already copies
`base`, `bearing` and `top - base` faithfully and needs nothing — but note the
deferred minor recorded at ledger line 51: the adapter's envelope-vs-massif
test assertions hold only because `ground_bands = {}` makes base 0 on both
sides (`tests/test_warren_excavation_adapter.gd:301-327,416-420`). Those
assertions are expected to move in Wave 1 and their movement is *correct*.

`_sample_ground_bands`'s `ceili` of the column **maximum**
(`VillageWarrenFabricSolver.gd:455-471`) is conservative-upward: on a real
slope it lifts every column to its highest corner, which is what produces the
"floating on the downhill side" artefact at 3 m column pitch. Wave 5 replaces
it with a per-column *pair* (min and max) so a house can choose between a
plinth on the low side and a shallow cut on the high side, within the ≤2-band
plinth budget the reviewer's doctrine allows.

### 3.4 Split of responsibilities after integration

**Massif owns** the buildable layer and nothing below it:

- per-column `base_at` = the terrain band under that column (sampled, not
  invented);
- per-column `top_at` = `base + layer`, `layer ∈ [4, 6]` bands (6–9 m,
  i.e. 2–3 storeys at `FabricRecipe.CELL_SIZE = 1.5` m ×2 per storey);
- the excavated public realm through that layer, unchanged;
- the partition of the remainder into houses, unchanged.

`WarrenMassif.BUILDABLE_LAYER_BANDS := 8` (`WarrenMassif.gd:20`) becomes the
*whole* column thickness rather than a cap applied to a taller solid, and the
two-datum split collapses: `bearing_at` (`:64-77`) returns
`max(base, top - BUILDABLE_LAYER_BANDS)`, which with `top - base <= 6 < 8`
is simply `base`. The second datum was invented precisely to name "the mass
between natural ground and where houses stop descending"; when terrain owns
that mass, the datum has nothing left to name. Keep the method (the envelope
copies it, `WarrenExcavationVolumeAdapter.gd:53`) and let it degenerate; do
not delete a shared accessor mid-milestone.

**Terrain owns** everything below: the mound, its slopes, its cliffs, the
grass, and the collision.

**`retained_terrace_cells` shrinks to plinths.** The per-parcel declaration
`WarrenParcelConstruction.retained_terrace_cells(parcel)`
(`WarrenFabricCompiler.gd:103-105`) survives — that is the ≤2-band foundation
course under a house, `sfv.foundation.rock.001`, the wood-over-stone junction
the reviewer likes. The "whole remainder" block that follows
(`WarrenFabricCompiler.gd:107-119`, the 1→4 macro expansion of every unbuilt
mass cell) is **deleted**: it exists only to draw the hill, and the hill is no
longer the fabric's. Consequently
`SettlementFabricAssembler.hill_substrate_walls` (`:222-...`) loses its input
and should be removed with it; `house_plinth_walls` stays.
`SettlementFabricPlan.retained_terrace_cells` and `set_retained_terrace`
(`:26,81-91`) keep their contract unchanged — the set simply gets small.

### 3.5 Streets

- **Ground streets** stay fabric decks with terrain paint underneath. The
  existing translation at `VillageWarrenFabricSolver.gd:176-185` already emits
  one `WORN_PATH` rect per ground street cell; on real relief this keeps
  working because the paint is a UV decision per 0.25 m patch
  (`TerrainChunkMesher.gd:414,423-425`) with no height component. The visible
  change is that the dirt now follows a slope instead of a plane.
- **Sunken lanes cutting into a riser** cannot be cut from terrain: a 3 m lane
  is 1/8 of a terrain cell and the field is single-valued. They remain a
  fabric cut through the buildable layer — which is what they already are.
  Where a lane wants to sink *below* the local ground band, it must instead be
  a stair down onto a lower terrace.
- **Tunnels stay fabric-clad, definitively.** §2.1 settles this: the terrain
  system has no void representation and gaining one means replacing the
  mesher. Cover therefore comes from **buildings over the street** inside the
  buildable layer — which is the reviewer's own stated mechanism ("the
  buildings should be built on paths which themselves are overpasses"). The
  earlier bridging-impossibility proof (ledger 152) was derived at a 3-band
  headroom under a 16–20 band monolith; at a 4–6 band layer on real ground the
  arithmetic is different and **must be re-derived**, not inherited.
- **Stairs on slopes** are already a fabric competence:
  `VillageStairSolver`, `VillageRouteStairFabricSolver`,
  `WarrenVolumeTransition` (STAIR run 2 / RAMP run 3), plus the 17-piece SFV
  stair family baked in the vocabulary wave (ledger 201). Where the route
  must cross a terrain cliff (§3.1 lever 2), the stair is the crossing, and
  `TerrainSurfaceField.is_walkable_edge` is the authority on where one is
  required.

### 3.6 Collision and streaming ownership

| Thing | Collider | Where |
|---|---|---|
| Hill body, slopes, terraces | **Terrain** | `TerrainChunkMesher` worker soup → main-thread `ConcavePolygonShape3D` (`:111-113,174-180,310-317`) |
| Cliff faces | **Terrain** | mesher boundary wall plane (`:331-335`); `CliffDressing` is visual-only (`:599-608,717-734`) |
| Houses, decks, stairs, supports, plinths | **Fabric** | payload `collision_faces` (`VillageWarrenFabricSolver.gd:219-225`) → `EnvironmentCollisionBuilder` |

**Nothing double-claims today, and the integration removes the one thing that
would have.** The substrate/terrace stone (§3.4) is the only fabric geometry
that ever stood *for* the ground; deleting it is what prevents a hill
collider and a masonry collider occupying the same volume. Two hazards to
test explicitly:

1. **Plinths must not sink through terrain collision.** A ≤2-band plinth on a
   slope is buried on the high side by construction (the same rule
   `SupportSolver.GroundReference.LOWEST` already applies,
   `SupportSolver.gd:31-38`); the test is that no *walkable* fabric surface
   ends up below `TerrainSurfaceField.surface_y` at its own anchor.
2. **The apron band.** `APRON := 2.4` m of lower-cell sheet continues under a
   higher flat neighbour (`TerrainChunkMesher.gd:25`), giving a ≤2.4 m strip
   where two terrain colliders overlap. A house footprint straddling a
   terrain cliff edge sits over that strip. Keep buildings off cliff-edge
   cells, or accept the strip explicitly with a measurement.

Streaming is unchanged: the hill is in the plan, chunks build once,
`CHUNK_RADIUS/KEEP_RADIUS` (`FieldTerrainStreamer.gd:34-35`) and the feature
halo (`:687-699`) need no new margins because the stamp's footprint is smaller
than a settlement super-cell.

### 3.7 Preview loop

Today the preview has **no terrain at all**: `warren_mass_first_preview.gd`
builds a single `MeshInstance3D` with a `BoxMesh(160, 0.4, 160)` in olive
`#718d50` at `y = -0.2` (`_build_ground:133-144`), passes no `ground_bands`,
and never touches `HeightfieldRegion`, `TerrainChunkMesher` or
`FieldTerrainStreamer`. Every mass-first render the reviewer has judged has
been a town on a flat green slab.

The cheapest honest preview is the **real mesher on a small region**, not a
stub — and the pattern already exists in the repo. `tests/harness/path_review.gd:88-98`
builds a `HeightfieldPlan`, calls `compute_region`, hand-builds a
`WaterFieldContext`, and then runs
`mesher.prepare_resources()` → `compute_chunk(...)` → `commit_chunk(...)`
inside a `Node3D` harness. Copy that shape with the production tuning:

```gdscript
var water     := TerrainWorldTuning.make_water(seed)
var relief    := SettlementReliefPlan.new(seed, SettlementPlan.new(seed, water))
var plan      := TerrainWorldTuning.make_heightfield(seed, water, relief)
var region    := plan.compute_region(cx, cz, TerrainChunkMesher.CELLS_PER_CHUNK)
var data      := TerrainChunkMesher.new().compute_chunk(...)   # worker-safe, pure CPU
mesher.commit_chunk(data, root)                                # main thread
```

Both halves are already public and already separated at the thread boundary
(`TerrainChunkMesher.gd:96-98,285-286`), and the harness runs on the main
thread so both are legal. That gives the preview the *actual* surface,
*actual* KayKit cliff dressing (`CliffDressing.compute(region, ...)`,
`TerrainChunkMesher.gd:280`) and *actual* collision — i.e. the render is
evidence rather than an approximation. A 192 m chunk centred on the site
covers the 99 m footprint, so the cost is a single `compute_chunk`.

A stub is explicitly rejected: the whole question this milestone answers is
"does the hill read as terrain", and a stub answers it with our own mesh.

Wiring: replace `_build_ground()` (`:133-144`) behind a `--terrain` flag
alongside the existing `--output` / `--seed` / `--no-detail`
(`_read_args:96-104`), defaulting on once Wave 3 lands, keeping the slab for
A/B. The five existing views (`overview-ne`, `overview-sw`, `skyline-east`,
`street-level`, `route-eye`, `_capture_all:147-180`) need no change; note
`VIEW_COUNT := 4` (`:16`) is already inconsistent with the five actually
emitted, which is a pre-existing cosmetic bug and not this milestone's
problem.

For the headless side, `tests/harness/village_warren_terrain_probe.gd:27-47`
is the existing real-terrain chain
(`make_water` → `SettlementPlan.site_for` → `make_heightfield` →
`compute_region` → `VillageTerrainView.from_region` → `VillageFrame.from_mask`
→ `VillageWarrenFabricSolver.solve`) and is the natural place to prove the
stamp end to end without rendering anything.

### 3.8 Composing with pre-existing terrain, and conform-only mode

Three modes, one code path, selected per site and reported in the audit:

| Mode | When | Behaviour |
|---|---|---|
| **STAMP** | site relief below the conform threshold | Full raise profile. The stamp *adds to* natural ground rather than replacing it — `h - carve + relief` — so a site that already slopes gets a hill leaning the way the land leans. No footprint replacement, no discontinuity: the clamp (`clamp_field:186-204`) blends the stamp into its surroundings by construction, and the profile tapers to zero before its outer radius. |
| **CONFORM** | the site is already steep enough to supply the relief budget | Stamp returns 0 everywhere. The town is laid on natural ground through the *existing* read path (§2.4) and the *existing* perch machinery (§2.6). This is the reviewer's "building into existing terrain without changing it", and it is the mode that proves the read path independently of the write path. |
| **BLEND** | in between | Stamp supplies only the deficit, i.e. `target_profile - natural_relief`, clamped at 0. Falls out of the same formula; no third branch. |

Site selection needs one honest adjustment. `SettlementPlan._compute_site`
sorts *ascending* on `(hi - lo) * LOCAL_RELIEF_WEIGHT + rocky * 3 - meadow`
(`SettlementPlan.gd:81-91`), i.e. it deliberately picks the **flattest, least
rocky, most meadow** candidate in each super-cell. That is right for the
route-first village and wrong for a hill town. Changing that scoring re-rolls
every settlement site in the world and therefore every path, so it is **out of
scope for this milestone**: STAMP mode works on flat sites (that is the point),
and CONFORM mode is exercised in tests and harnesses against synthetic and
seed-selected steep regions until a separate decision is taken on site
scoring.

`MAX_FABRIC_TERRAIN_RELIEF := 4.5` (`VillageUrbanFabricPlan.gd:12`) is a
route-first constant that the hill town must not inherit. It becomes
mode-dependent: route-first keeps 4.5 m unchanged (A/B-proven), and the
mass-first hill gets a budget derived from the stamp's own profile plus the
plinth allowance, with the derivation documented.

---

## 4. Waves

Each wave is independently testable, TDD-able, and lands green. Suites are
named per wave; **canary** means "must be byte-identical in behaviour". One
suite runs as

```
Godot --headless --path /Users/ryko/story -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/test_warren_massif.gd -gexit
```

(`AGENTS.md:25-26`, `tests/TEST_README.md:3-5`). Pass **no `-gconfig`**:
`tests/gutconfig.json:2` pins `"dirs":["res://tests/"]`, so passing it defeats
`-gtest` isolation and runs the whole ~7-minute battery.

### Wave 1 — Relief-relative massif gates (+ the one-time re-pin)

Make `WarrenMassifBuilder`/`WarrenMassif` score relief, not absolute height
(§3.3). No terrain involved: the tests feed synthetic `ground_bands`.

- **New tests** in `tests/test_warren_massif.gd`: a sloped `ground_bands` ramp
  must produce the *same* gate verdicts as the flat case (the invariance
  property); a genuine 6-band layer step must still fail
  `MAX_NEIGHBOR_STEP_BANDS`; a genuine 7-cell constant-layer plateau must still
  fail `MAX_PLATEAU_CELLS`. Sabotage-verify each by reverting the fix. The
  existing coverage is one uniform all-2 lift (`:35-40,51`), which cannot see
  any of this.
- **The scaffold already exists.** `tests/harness/warren_mass_first_report.gd
  --stage terrain` (`:1499-1526`) already runs `flat` / `slope 0-8` /
  `terrace 0/2/6` dictionaries through `WarrenMassifBuilder.build` (`:1531`)
  and `mass_first_frontier` (`:1542`) over
  `span = RADIUS_CELLS + 4` (`:1508`). It is the before/after instrument for
  this wave; extend it, do not replace it.
- **Re-derive `MIN_CORE_BANDS`** under the established standard (§3.1) —
  measured distribution, invariance test, and proof that a genuinely flat
  town still fails.
- **Suites (owners, expected to move):** `tests/test_warren_massif.gd`,
  `tests/test_warren_excavation.gd`, `tests/test_warren_excavation_adapter.gd`,
  `tests/test_warren_solid_partitioner.gd`,
  `tests/test_warren_generation_mode.gd`.
- **Canaries (must not move):** `tests/test_warren_volume.gd`,
  `tests/test_warren_outcrops.gd`, `tests/test_warren_market.gd`,
  `tests/test_warren_roof_profiles.gd`,
  `tests/test_warren_production_surfaces.gd`.
- **This is the wave that re-rolls the seed corpus.** See §5.

### Wave 2 — The settlement relief stamp (data only, nothing rendered)

`SettlementReliefPlan` + `HeightfieldPlan.set_relief_plan` +
`TerrainWorldTuning.make_heightfield(seed, water, relief)` + the streamer
switched onto `TerrainWorldTuning` (§3.2). No village consumes it yet.

- **New suite** `tests/test_settlement_relief.gd`: determinism (two
  independently built plans agree cell-for-cell, mirroring
  `tests/test_water_plan.gd:332-335`); monotone-raise-only; zero under water
  carve; storey-ceiling clamp measured, not asserted; **window independence**
  (`compute_region` centred on the hill vs two chunks away agree); no cliff
  top inside the built radius; at least one walkable approach strip via
  `TerrainSurfaceField.cardinal_strip_is_walkable`.
- **Canaries:** the heightfield/terrain-surface/water suites and
  `tests/harness/path_corpus.gd` — with `relief = null` every value must be
  bit-identical to today.

### Wave 3 — Terrain renders and collides the hill

Prove the free lunch: mesh, cliff dressing, grass suppression and collision
all appear with zero new rendering code, and measure the relief budget levers
of §3.1.

- Harness `tests/harness/warren_mass_first_preview.gd` gains `--terrain`
  (§3.7) and renders the stamped hill with no town on it.
- Report: storeys of relief inside the footprint, count and height of cliff
  tops, walkable fraction, chunk build time delta, collision triangle delta.
- **Decision point:** footprint width vs in-town cliffs, decided on those
  numbers.

### Wave 4 — Buildable layer: the fabric stops drawing the mountain

Cap the massif's column thickness at 4–6 bands over the sampled ground; delete
the whole-remainder branch of `_retained_terrace`
(`WarrenFabricCompiler.gd:107-119`) and `hill_substrate_walls`; keep plinths.

- **Suites:** `tests/test_warren_solid_partitioner.gd` (layer cap pinned by a
  test, per the reviewer's 2–3 storey rule),
  `tests/test_warren_production_surfaces.gd` (a Wave 1 canary but a Wave 4
  **owner**: its 10 hand-built payload fixtures are the plinth/cladding
  coverage that `hill_substrate_walls`' removal moves),
  `tests/test_settlement_fabric.gd`, `tests/test_warren_generation_mode.gd`.
- **Report:** exposed-storey histogram before/after (the ledger's standing
  measure: seed 3 was `2:6 3:2 4:1 5:2 6:5 7:3`), tallest continuous composed
  face, floating-house count, stone-unit count.

### Wave 5 — Streets, stairs and paint on real ground

Replace `_sample_ground_bands`'s single conservative `ceili`
(`VillageWarrenFabricSolver.gd:455-471`) with a min/max pair; let a house
choose plinth-up or cut-down within the ≤2-band budget; verify `WORN_PATH`
paint follows the slope; route stairs across any terrain cliff the route
crosses; **re-derive the bridging arithmetic** at the new layer thickness
(§3.5).

- **Suites:** `tests/test_warren_production_surfaces.gd`,
  `tests/test_village_terrain_survey.gd` (unchanged, canary),
  new coverage in `tests/test_warren_generation_mode.gd` for a sloped frame.

### Wave 6 — Production placement, collision ownership, streaming

Mode-dependent relief budget replacing the flat 4.5 m gate (§3.8); the two
collision hazards of §3.6 tested; a real village record built over a stamped
site end to end through `VillageWarrenFabricSolver.solve`.

- **Suites:** `tests/test_village_plan.gd`, `tests/test_village_program.gd`,
  `tests/harness/village_warren_terrain_probe.gd`,
  `tests/harness/village_corpus.gd`; canary `tests/test_village_capture_views.gd`.

### Wave 7 — Conform-only mode and acceptance re-measure

Stamp off, town on natural relief, using the existing perch/foundation/support
machinery (§2.6). Then re-measure the acceptance battery — overhead ratio
against `TARGET_OVERHEAD_RATIO := 0.35`
(`WarrenBuiltTownSolver.gd:28`), uncovered components, composed-town count —
and report movement rather than tuning to it.

- **Suites:** `tests/test_village_visual_review_gate.gd`,
  `tests/harness/warren_mass_first_report.gd`,
  `tests/harness/production_warren_seed_corpus.gd`.

---

## 5. Migration: the one-time re-pin

Wave 1 changes what the massif's gates *measure*, so any suite whose
expectations were computed from a specific seed's massif re-rolls. Authorized
in the ledger (line 210): *pins re-derived by measurement, gates verified to
hold statistically, single migration commit, before/after documented.*

**Expected to re-roll.** Exactly five suites reference a mass-first class
(`WarrenMassifBuilder` / `WarrenExcavationCarver` /
`WarrenExcavationVolumeAdapter` / `WarrenSolidPartitioner`), and they carry
these pins:

| Suite | Pinned seeds | Pinned values most at risk |
|---|---|---|
| `tests/test_warren_massif.gd` (8) | `1`, `4` (`:8-9,34,40,44`); `[17, 19]` (`:87`, already once re-pinned off 13); `[0,1,3,5,11,18]` (`:150`) | `core>=16` `:12`, `levels>=5` `:14`, `plateau<=6` `:16`, `raised*3 > columns` `:137` ("126 of 291 on seed 1"), `tallest_face <= MAX_NEIGHBOR_STEP_BANDS` `:150` |
| `tests/test_warren_excavation.gd` (15) | `PROBE_SEEDS := [1,2,6]` `:12`; canyon window 40–63 (`:27-28`); arcade window 16–31 (`:34-35`) | `MIN_ARCADE_CLEARED_SEEDS := 5` `:40` / `MIN_ARCADE_CLEARED_RATIO := 0.55` `:41` (asserted `:506,:510`); supply floors `carved_seeds > 8` `:418,:459`; lane floors `:54-55` (`:604,:608`) |
| `tests/test_warren_excavation_adapter.gd` (10) | literal `1` in 7 tests; `range(6)` `:188,:255` | `lanes.size() > 0` `:312`; **the envelope-vs-massif height assertions `:301-327,416-420`**, which the ledger (line 51) already flags as holding only because `ground_bands = {}` makes base 0 on both sides — their movement is *correct*, not a regression |
| `tests/test_warren_solid_partitioner.gd` (22) | `CORPUS := [1,3,4,5,6,9,11]` `:13`; `FRONTIER_CORPUS := [6,11,12]` `:18`; literal `1` `:51-52,853,877,893` | `MEASURED_UNJOINABLE_FILL_SITES := 20` `:35` (`:579`), `MEASURED_UNDESCENDED_TALL_HOUSES := 8` `:40` (`:795`), `MAX_UNSUPPORTED_BANDS := 2` `:1065` (`:1122-1125`), `MAX_COMPOSED_FACE_BANDS` `:1071` (`:1183`), plus the observed-count floors at `:93,229,577,790,925,157,916,1181` |
| `tests/test_warren_generation_mode.gd` (8) | `MASS_FIRST_SEED := 11` `:21` (the only seed) | `addressed_walk_ratio >= 0.55` `:87`, `same_datum_route_fold_count == 0` `:88`, `base_band_count >= 3` `:205`, `footprint_family_count >= 3` `:207`, `owned*3 >= wall_count` `:249`, `high-low >= 8` `:256` |

Plus the mass-first corpora in `tests/harness/warren_mass_first_report.gd`
(`DEFAULT_SEEDS := [1,3,4,5,6,9,11,13,16,20]`, `:80`) and
`tests/harness/production_warren_seed_corpus.gd`.

`MAX_COMPOSED_FACE_BANDS` deserves separate attention: it is *derived* as
`WarrenMassifBuilder.MAX_NEIGHBOR_STEP_BANDS + WarrenMassif.BUILDABLE_LAYER_BANDS`
(`test_warren_solid_partitioner.gd:1071`), so Wave 4's layer cap moves it
automatically. Re-derive the constant's *meaning* before accepting its new
value.

**Must NOT move** (route-first canaries; verified as the complement of the
five above — none of them names a mass-first class):
`tests/test_warren_volume.gd` (12, including the attempt-pinned seeds at
`:90,93` and `:129-131,150`), `tests/test_warren_outcrops.gd` (8, sweeps
seeds 0–3 through `WarrenBuiltTownSolver.solve`),
`tests/test_warren_market.gd` (2, same 0–3 sweep),
`tests/test_warren_roof_profiles.gd` (2, hand-built pairs),
`tests/test_warren_production_surfaces.gd` (10 — **not** a solver suite: grep
for `Solver.`/`Carver.`/`.solve(` returns zero, its only seed use is the
facade-family list at `:364`), `tests/test_settlement_fabric.gd`, and
`tests/test_village_*`. Plus the standing controlled route-first A/B over
seeds 0–7 that the last three metric changes each used, which must again come
back diff-identical.

**Protocol.**

1. Land the behaviour change with the old pins failing; capture the failure
   list verbatim.
2. Re-derive each pin by measurement over the same seed window that produced
   the original, never by pasting the new observed value blind: state what the
   number means before stating what it is.
3. Verify each gate still has teeth by sabotage (revert the gate, show the
   suite fails) — the standard already used for the arcade floor and the wall
   ratio.
4. Verify gates hold **statistically** over a ≥100-seed sweep, reporting
   supply before and after; a supply change is a result to report, not a
   number to restore.
5. One migration commit, `test(villages): re-pin mass-first corpus for
   relief-relative massif gates`, with the before/after table in the message.
6. Route-first A/B in the same commit, proving identity.

---

## 6. Risks

1. **The relief budget may not fit in 4 terrain cells (highest).** §3.1's
   arithmetic says a 99 m footprint buys ~5 bands of cliff-free ground rise.
   If Wave 3 measures that as too flat to read as a hill, the answer is a
   wider footprint (r² cost through carver and partitioner) or in-town dressed
   cliffs (stairs, and a doctrine argument about rock the terrain authored).
   Both are real costs and neither is a gate weakening. Mitigation: Wave 3 is
   a measurement wave with an explicit decision point, before Wave 4 commits
   the fabric to a thin layer.
2. **Storey-ceiling truncation flattens the hilltop.** `quantize_storey`
   clamps at `max_storeys = 8` (`HeightfieldPlan.gd:153-154`,
   `TerrainWorldTuning.gd:9`); natural ground already reaches 22 m, so a 20 m
   stamp saturates and produces exactly the wide plateau the massif forbids —
   and raising the ceiling re-rolls the whole world. Mitigation: the clamp is
   part of the stamp contract (§3.2) and is *measured* in Wave 2, not assumed.
3. **Cover collapses when the buildable layer thins.** Overhead is already
   0.11–0.21 against a 0.35 target, and the entire remaining mass above
   streets moves to terrain. The layer may need to be thicker at the core than
   at the rim. Mitigation: Wave 4 reports the histogram and Wave 5 re-derives
   the bridging arithmetic that was proven impossible only at the old
   geometry; **no threshold moves** without the established standard, and
   "the authored vocabulary cannot roof an excavated street at this scale"
   remains a legitimate outcome.
4. **Two heightfield construction sites.** `FieldTerrainStreamer._ready()`
   builds its plan inline (`:153-157`) while harnesses use `TerrainWorldTuning`
   — a stamp wired into one and not the other means renders and tests disagree
   about what the world is. Mitigation: Wave 2 unifies them, and the unification
   is the wave's acceptance criterion, not a side effect.
5. **Path routing may refuse the new hill.** `PathPlan` rejects exposed cliff
   faces and the stamp raises ground beneath already-planned corridors.
   Mitigation: the walkable-approach property is a Wave 2 test, and
   `tests/harness/path_corpus.gd` is a Wave 2 canary.

---

## 7. Non-goals

- **Route-first is untouched and remains the shipping default.** Every shared
  file gets the controlled A/B that the last three metric changes used.
- **No terrain voids, overhangs or tunnels.** §2.1 settles it; tunnels are
  buildings over streets, inside the buildable layer.
- **No change to `TerrainSurfaceField.TILE`, `STOREY_HEIGHT`,
  `LEVELS_PER_STOREY`, `HEIGHTFIELD_AMPLITUDE`, `HEIGHTFIELD_MAX_STOREYS` or
  `MAX_CLIFF_STEP`.** Each re-rolls the entire world.
- **No sub-cell terrain refinement.** A feature-local finer surface inside the
  town footprint was considered and rejected for this milestone: cliff
  classification, `bake_cell`/`sample_baked`, `height_bounds`, walkability and
  water all key off the 24 m lattice, so refinement is a mesher rewrite, not
  an extension point. Revisit only if Wave 3's measurement says the two-tier
  split cannot deliver the hill.
- **No change to `SettlementPlan` site scoring** (§3.8) — it re-rolls every
  settlement and path in the world.
- **No new authored art.** The corner-junction roof gap (ledger 144, 158)
  remains its own task; this milestone must not be blocked on it, and the
  diagnostic corner-overlap flag stays off by default.
- **No gate weakened.** `MIN_CORE_BANDS` and `MAX_FABRIC_TERRAIN_RELIEF` are
  *re-derived* under the established three-proof standard, and that
  derivation is itself reviewable work.
