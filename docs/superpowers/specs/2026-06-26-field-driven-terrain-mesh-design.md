# Field-driven terrain — design

**Date:** 2026-06-26
**Status:** approved architecture; this doc specs **sub-project 1** in full.
**Branch:** `refactor/terrain-field-driven`.

## Why

Terrain is currently assembled from a finite catalog of ~30 discrete 24×24 variant
meshes (ground / ~15 level / ~15 cliff / bank / water), chosen per cell by a
neighbour bitmask and placed edge-to-edge. Three failure modes are *structural*
consequences of that approach, and we keep hitting all three:

- A neighbour configuration with **no matching tile → a hole** (missing wedge).
- A tile whose mesh edge doesn't *exactly* equal its neighbour's, or is placed a
  hair off in height → **a gap or lip** (the original ground/slope gap; the square
  lip).
- Water can only be a flat tile swapped in at one height → **a y=0 decal**.

Every one of these is "the catalog is incomplete or imperfect." A hand-tuned
catalog cannot be made provably complete or provably seam-free — there is always a
next missing/mismatched case. Patching individual tiles is a treadmill. We remove
the bug class by removing the catalog.

A 3D tileset (GridMap / MeshLibrary) is explicitly **not** the answer: it snaps
discrete meshes to a grid, reintroducing the same edge-matching fragility.

## Approved architecture (the whole vision)

One **continuous walkable-surface mesh** is generated per chunk straight from the
heightfield. Everything follows from a single rule:

> Between two adjacent walkable cells, if the height difference is **≤ 1 storey
> (4 m)** → connect them with a **walkable slope** that is part of the continuous
> mesh. If the difference is **> 1 storey** → the lower cell sees a **blocky
> vertical cliff face**, and the upper surface simply ends at that top edge.

Consequences (all the merges you asked for, for free, because the walkable surface
is one mesh with shared boundary vertices):

- Slope into the **side** of a cliff → walkable mesh ends at the cliff base, cliff
  rises above it (a wall). ✓
- Ground at the **same height** as a cliff top → the cliff top *is* walkable
  plateau, same mesh → seamless. ✓
- Ground rising **above** a cliff top (≤ 1 storey at a time) → a 4 m walkable
  slope, same mesh → seamless. ✓

Gaps, lips, and missing tiles become *geometrically impossible*: there is no
catalog and no independent edges to mismatch.

**Roadmap (each its own spec → plan → build):**

1. **Continuous walkable-surface mesher + decoration scatter** — *this document*.
   Replaces catalog placement and the socket engine. Fixes gaps/lips/missing-tiles.
   Keeps simple flat-level water so nothing regresses.
2. **Blocky multi-storey cliffs + richer terrain generation** — relax the clamp so
   big drops are allowed, emit cliff faces, tune the noise for plateaus / mountains
   / valleys.
3. **Multi-elevation water** — water-level field + fill + real shorelines; delete
   the remaining flat-water shim.
4. *(Later)* **`Plane*` level detail** — swap flat cell-tops for authored detailed
   meshes; the mesher still generates the sloped connectors (no edge-matching).

---

# Sub-project 1: Continuous walkable-surface mesher + decoration scatter

## Goal

Replace per-cell catalog tile placement with a **continuous chunk mesher** that
builds the walkable surface (flat cell tops + walkable slopes for every ≤1-storey
drop) as **one gap-free mesh per chunk**, with collision, streamed around the
player. Re-home decoration to a deterministic per-cell field scatter (sockets die
with the tiles). Keep a minimal flat-level water surface so water doesn't vanish.
Then delete the catalog, the variant/bake system, and the socket engine.

In this sub-project the clamp is **unchanged** (still ≤1 storey between cells), so
the surface is fully continuous (no vertical walls yet) — i.e. a pure heightmap,
which is trivially gap-free. Multi-storey cliffs arrive in sub-project 2.

## What stays

- **`HeightfieldPlan`** — the deterministic quantized field (storeys 4 m, levels
  0.5 m, `compute_region`, `surface_height`, `level_at`, `storey_at`, clamp). This
  is the solid core and is reused unchanged.
- **`SlopeProfile`** — its smootherstep edge/outer-corner/inner-corner height math
  is proven and tested; the surface field reuses it (consumed continuously instead
  of baked into discrete component meshes). `SlopeMeshGenerator`,
  `SlopeVariantLayout`, and the bake scripts go away.

## Components (each isolated, testable, single-purpose)

### 1. `TerrainSurfaceField` (pure, deterministic)
A continuous walkable-surface height function over world XZ.

- `static func surface_y(plan, x: float, z: float) -> float`
- Flat on cell interiors at `plan.surface_height(cx, cz)`; within a boundary band
  it smootherstep-ramps toward each lower cardinal/diagonal neighbour, reproducing
  today's edge / outer-corner / inner-corner profiles (the `SlopeProfile` math
  generalised to read neighbour heights from the plan rather than a baked cell
  layout).
- Pure: depends only on `(plan, x, z)`. No scene access.
- **Key property:** single-valued at every point ⇒ when the mesher samples it on a
  shared grid, adjacent chunks/cells share identical boundary vertices ⇒ gap-free
  by construction.

### 2. `TerrainChunkMesher`
Builds one chunk's surface mesh + collision from the field.

- `func build_chunk(plan, chunk: Vector2i) -> Node3D` returning a `MeshInstance3D`
  (grass material) + `StaticBody3D` collision.
- A chunk is an N×N block of cells (N tunable, e.g. 8 → 192 m). The mesh is a
  regular grid sampled at S samples/cell (S tunable, e.g. 4) with `y =
  TerrainSurfaceField.surface_y`. Normals generated; grass UV/material as today.
- Collision: a trimesh/heightmap collider from the same samples (or convex slabs);
  pick the cheapest that's exact enough — resolved in the plan.
- **Water shim:** for cells where `Helper.is_water`, emit a flat water-surface quad
  at sea level (y=0) over the cell and keep the grass bed below — preserving the
  current water look. (Generalised in sub-project 3.)

### 3. `DecorationScatter` (pure, deterministic) + placement
Per-cell field scatter replacing sockets (this is FR-3's model).

- `static func cell_decorations(cell, world_seed, surface_y) -> Array` → list of
  `{tag, pos, yaw, scene_key}` from `hash(cell, seed)`, weighted by
  `Helper.biome_foliage_density` / `Helper.biome_weights`, jittered (blue-noise) so
  it isn't gridded. Pure, returns data only.
- The mesher (or a thin placer) instances the foliage gltf per result as a child of
  the chunk, at the cell's surface height, so it evicts with the chunk.
- Hills handled as a deterministic decoration with one optional stack roll (no
  socket recursion).

### 4. `TerrainStreamer` (slim driver, replaces the `TerrainGenerator` engine)
- `_process`: build chunk meshes within a Chebyshev radius of the player, evict
  beyond a keep radius, frame-budgeted (N chunks/frame). Reuses only the
  player-tracking + radius logic from today's generator.
- Deletes: the priority-queue placement loop, `_process_socket`, rule pipeline,
  reveal-margin machinery, `_purge_orphaned_stacks`, `_ensure_seed_under_player`,
  socket bookkeeping.

## Data flow

```
HeightfieldPlan ──surface_height/neighbours──▶ TerrainSurfaceField.surface_y(x,z)
                                                      │ (sampled on a shared grid)
                                                      ▼
player pos ──radius──▶ TerrainStreamer ──build_chunk──▶ TerrainChunkMesher
                              │                              │  mesh + collision + water shim
                              │                              ▼
                              └──per cell──▶ DecorationScatter ──▶ foliage instances (chunk children)
                              evict beyond keep-radius ──▶ free chunk + its decorations
```

## Deletions (after the mesher is verified behind a flag)

`HeightfieldInstantiator` catalog placement; `TerrainModuleDefinitions` variant
tables + loaders; the ~30 authored/generated variant scenes
(`terrain/scenes/{level,cliff,slope,bank}/*`); `SlopeVariantLayout`,
`SlopeMeshGenerator`, `bake_slope_cliffs.gd`, `bake_level_tiles.gd`; the
`TerrainGenerator` socket engine; `TerrainDensity`; `TerrainModuleSocket`; the
8 `TerrainModule` flags + socket dicts; `WaterRule`; test pieces; and the tests
whose subject is gone. (This overlaps the old FR-2 + FR-3 deletion lists.)

## Migration safety

Build `TerrainSurfaceField` / `TerrainChunkMesher` / streamer **alongside** the
current system behind a flag; verify visually + by tests; **tag the pre-deletion
commit** (`git tag terrain-catalog-archive`); then delete the old path. No "big
bang" — the old catalog keeps running until the mesher is proven.

## Testing

- **Deterministic:** `surface_y` and a chunk mesh are pure functions of `(seed,
  region)` — same in → same out.
- **Gap-free:** boundary samples shared by adjacent chunks/cells are bit-identical;
  a probe over a region finds no vertex discontinuity at cell/chunk seams (the
  property that the old catalog violated at ±11.75).
- **Faithful:** `surface_y` equals `plan.surface_height` on cell interiors; a
  1-storey drop produces a walkable slope between the two flats.
- **Scatter:** deterministic; every decoration sits on the surface and within its
  cell; density tracks biome.
- **Water shim:** water cells get a water surface at sea level with grass below.
- Full GUT suite green after deletions (obsolete tests removed).

## Out of scope (later sub-projects)

Multi-storey blocky cliffs + relaxed clamp + richer noise (sub-project 2);
multi-elevation water + shorelines (sub-project 3); `Plane*` authored level detail
(sub-project 4).

## Risks / open questions (resolve in the plan)

- **Corner correctness of `surface_y`.** Generalising the outer/inner-corner
  profiles to a global field must stay C0 and keep flat interiors. Mitigation:
  reuse the proven `SlopeProfile` math; characterise against current geometry.
- **Collision cost** at S samples/cell over the streamed radius — pick the cheapest
  exact-enough collider; benchmark vs today.
- **Chunk vs cell granularity** for streaming/eviction churn and frame budget —
  tune N and the radii; benchmark against the current generator.
- **Decoration parity** — the field scatter should look as good or better than the
  socket scatter; tune density/jitter visually.
