# Central spawn registry + level/slope socket gating

**Date:** 2026-06-22
**Status:** Design — awaiting implementation

## Problem

Ground-spawning logic (what pieces spawn in which sockets, with what
probabilities) is spread across three layers:

- **`TerrainModuleDefinitions.gd`** — per-piece socket dictionaries
  (`socket_size`, `socket_fill_prob`, `socket_tag_prob`, `socket_required`,
  `socket_suppressed_by`) built inline in each factory, plus a tuning-constant
  block at the top.
- **`TerrainModuleLibrary.gd`** — adjacency resolution
  (`get_required_tags`, `get_combined_distribution`).
- **`TerrainGenerator.gd`** — runtime filtering: `_sample_socket_size`,
  `_biome_scaled_dist`, fill-prob application.

There is no single place to see or tweak "socket X spawns pieces Y/Z at
probabilities P/Q." The set of keys that count as a *structure*
(`8x8x2`/`12x12x2`/`4x4x4` hill sizes; `level-ground-center` / `cliff-base-side`
seed tags) is hardcoded and **duplicated** — once implicitly across the size/tag
distributions, and again literally in `_biome_scaled_dist`'s cliff-core
suppression (`TerrainGenerator.gd` ~410-430).

Separately, **slopes are baked cliff-variant scenes** (`terrain/scenes/slope/*.tscn`)
whose top-surface sockets (`topcenter`, `topfront`, …) sit on the *tilted* band.
`SlopeVariantLayout` classifies each tile cell as `top` (flat plateau) vs
`edge`/`outer`/`inner` (sloped); the slope-band sockets are baked **below y=0**
while plateau sockets stay at **y≈0** (enforced by
`tests/test_slope_socket_grounding.gd`). Today **hills and structural seeds
spawn on those sloped sockets**, so a hill protrudes into the mountain (uphill)
or juts into the air (downhill).

## Decisions (from brainstorming)

- **Slope behavior:** normal foliage allowed on slopes; structures blocked.
- **Level-only set:** hills + structural seeds (level/cliff stacking). All
  foliage (grass/bush/tree/rock) may spawn anywhere.
- **Refactor scope:** a central spawn registry — one source of truth for the
  socket→pieces mapping, probabilities, and the structure key set.
- **Category source:** derive level-vs-slope from the socket's **baked local Y**
  (recommended). No re-baking; relies on the grounding invariant the test suite
  already enforces.

## Architecture

Three components.

### Component 1 — `scripts/terrain/TerrainSpawnConfig.gd` (new — single source of truth)

A `Resource`/static-helper script that owns **all** ground-spawn data and the
helpers to read it:

- **Tuning constants** — moved out of the `TerrainModuleDefinitions` tuning
  block: lateral/topcenter/foliage fill probs, `FOLIAGE_TAG_WEIGHTS`, topcenter
  seed splits (`GROUND_TOPCENTER_LEVEL_PROB` / `…_CLIFF_PROB`), hill-stack probs
  (`HILL_8X8_STACK_FILL_PROB`, …), cliff-core boosts.
  - To avoid a churny rename across the codebase, the existing
    `TerrainModuleDefinitions.CONST` references may be preserved as thin
    forwarding `const`s (`const X := TerrainSpawnConfig.X`) — or updated to read
    from the new file directly. Implementation plan decides; the *authoritative
    values* live in `TerrainSpawnConfig`.
- **Socket-role config builders** — the Distributions currently constructed
  inline in factories, exposed as functions:
  - `foliage_size(is_corner: bool) -> Distribution`
  - `foliage_tags() -> Distribution`
  - `topcenter_seed_size()` / `topcenter_seed_tags()` (ground topcenter)
  - lateral configs (size/tags/required) per piece family
    (ground / level / cliff / water-bank)
  - hill-stack configs (per hill size)
- **Canonical structure key set** — the one definition of which **sizes**
  (`8x8x2`, `12x12x2`, `4x4x4`) and **tags** (`hill`, the level/cliff seed tags)
  are level-only structures:
  - `STRUCTURE_SIZES: Array[String]`
  - `STRUCTURE_SEED_TAGS: Array[String]`
- **`filter_for_category(dist: Distribution, category: String) -> Distribution`**
  — when `category == "slope"`, erase every `STRUCTURE_SIZES` / `STRUCTURE_SEED_TAGS`
  key from a copy of `dist` and renormalise; when `category == "level"`, return
  `dist` unchanged. Must never empty a distribution (`point` always survives a
  foliage dist; assert-safe like the existing biome scaling).

`surface_spawn_sockets()` and the per-piece factories in
`TerrainModuleDefinitions.gd` call into `TerrainSpawnConfig` instead of holding
their own constants/Distributions. The factories keep their structural identity
(scene, tags, AABB, which sockets exist); only the *spawn parameters* move.

### Component 2 — Socket categorization (level vs slope)

Each socket carries a `category` ∈ {`"level"`, `"slope"`}.

Derived from the socket's **baked local Y** in `TerrainModuleInstance`:

```
const SLOPE_Y_THRESHOLD := -0.5   # plateau sockets sit at y≈0; slope-band
                                  # sockets are baked below 0
category = "slope" if marker.transform.origin.y < SLOPE_Y_THRESHOLD else "level"
```

- Computed once when sockets are discovered (`_find_sockets`), cached in a
  `socket_category: Dictionary` (name → String), with an accessor
  `get_socket_category(name) -> String` defaulting to `"level"`.
- Flat tiles (ground, level, cliff-interior, banks) keep all sockets at y≈0 →
  all `"level"` → no behavior change.
- Only baked slope scenes have dropped top sockets → those classify `"slope"`.
- Adjacency sockets (front/back/left/right, diagonals, bottom) are intentionally
  left at y=0 in the slope scenes for adjacency parity, so they always classify
  `"level"`. That is correct — the gate only needs to affect surface
  (foliage/seed) sockets, and laterals carry no structure entries anyway.

### Component 3 — The gate (runtime)

In `TerrainGenerator`:

- **Size roll** (`_sample_socket_size`): after building the (possibly
  biome-scaled) size distribution, pass it through
  `TerrainSpawnConfig.filter_for_category(dist, piece.get_socket_category(socket_name))`.
- **Tag roll** (the `socket_tag_prob` path feeding placement): apply the same
  filter with the same category, so size and tag rolls stay consistent (mirrors
  the existing biome-scaling consistency note).
- **Cliff-core suppression** (`_biome_scaled_dist`, ~410-430): replace the
  hardcoded structure keys with `TerrainSpawnConfig.STRUCTURE_SIZES` /
  `STRUCTURE_SEED_TAGS`, so the two suppression paths share one definition.

On slope sockets, hill sizes and seed tags drop out and only `point` foliage
remains; on level sockets nothing changes.

## Data flow

```
factory (TerrainModuleDefinitions)
  └─ reads spawn params from TerrainSpawnConfig → builds TerrainModule

scene instantiated → TerrainModuleInstance._find_sockets()
  └─ computes socket_category[name] from baked marker Y

generator expands a socket
  ├─ _sample_socket_size: biome-scale → filter_for_category(category) → sample
  └─ tag roll: biome-scale → filter_for_category(category) → sample
```

## Error handling / edge cases

- `filter_for_category` must never produce an empty/zero-sum distribution
  (`Distribution.sample()` asserts). `point` always survives in foliage dists;
  if a dist somehow consists only of structure keys, return the original
  (same guard pattern as `_biome_scaled_dist`).
- Sockets absent from `socket_size` already default to `"point"` — unaffected.
- Threshold `-0.5` is between the plateau (0) and the deepest slope drop (−4) and
  comfortably outside the grounding test's `TOL = 0.4`; exposed as a named const
  for tuning.

## Testing (GUT)

- **Unit — `filter_for_category`:** slope category drops all `STRUCTURE_SIZES`
  and `STRUCTURE_SEED_TAGS` from a sample foliage/seed dist while keeping
  `point`; level category returns the dist unchanged; never empties a dist.
- **Unit — categorization:** a marker at y≈0 → `"level"`; a marker at y=−2 →
  `"slope"`.
- **Integration — slope scenes:** for each `terrain/scenes/slope/*.tscn`, any
  top socket baked below the threshold classifies `"slope"` (sanity that real
  slope scenes actually trigger the gate). Complements the existing grounding
  test rather than replacing it.
- Run via the project's GUT workflow (see memory: Godot GUT test workflow).

## Out of scope

- No change to adjacency/WFC semantics, cliff-contour math, or the slope mesh
  geometry/baker.
- No re-baking of slope scenes.
- No change to which sockets exist on any scene.
