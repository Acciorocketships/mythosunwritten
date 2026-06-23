# Mesa Cliff Tier — 8m Sheer Cliffs for Deep Ravines

**Status:** Approved design (2026-06-23)
**Scope:** Additive. Existing 4m sloped-cliff and 0.5m level systems are behavior-unchanged.

## Problem

Terrain today is built from 0.5m **level** terraces and 4m **storey** cliffs rendered as
grass-covered *sloped* ramps. The cardinal trickle-down clamp
([`HeightfieldPlan.clamp_field`](../../../scripts/terrain/heightfield/HeightfieldPlan.gd))
limits every cardinal step to **one storey**, so the world has only gentle relief: there are
no dramatic vertical drops, ravines, or mesa/plateau walls.

We have authored a set of **8m, sheer (vertical rock) cliff tiles** in
`terrain/scenes/cliff/` — the full variant set (Corner, Side, Line, Island, Peninsula, and the
inner-corner family) using the `hill_cliff_tall_*` meshes, each presenting a single continuous
8m face (walls from `y=0` to `y=-8`). They are not wired into generation yet.

We want generation to use them to carve **ravines / valleys / plateaus / mesas** — sheer
8m drops where the terrain is steep — while keeping the existing gentle sloped cliffs and level
terraces for everything else.

## Approach: a third nested tier

Add a **mesa** tier (8m) one level *above* the existing 4m storey tier, mirroring how the
storey tier already sits above the 0.5m level tier. Each tier quantizes a height into integer
indices and runs a trickle-down clamp; nesting them gives layered relief.

| Tier | Height | Tile source | Profile | Clamp | Role |
|------|--------|-------------|---------|-------|------|
| **Mesa** (new) | 8.0m | `terrain/scenes/cliff/` (sheer) | sheer vertical | ±1 mega-step, **cardinal + diagonal** | dramatic ravine / plateau walls |
| Storey (exists) | 4.0m | `terrain/scenes/slope/` (sloped) | grass ramp | ±1 storey, cardinal only | gentle hills |
| Level (exists) | 0.5m | level tiles | sheer terrace | ±1 level, cardinal only | fine terraces |

Constants: `MESA_HEIGHT = 8.0`, `STOREYS_PER_MESA = 2` (mirrors `LEVELS_PER_STOREY = 8`).

### Why this is the right shape

- **Uniform 8m faces, guaranteed — by the mesa-distance ramp.** This is the crux. Today the
  system guarantees uniform 4m faces *not* by the storey clamp alone, but by the
  **cliff-distance ramp**: `level_at` pins `level = 0` within one tile of any storey cliff
  (`cliff_cap = cliff_distance - 1`), so a cliff-edge cell has no 0.5m drops and its faces are
  exactly 4m. The mesa tier needs the exact analogue: a **mesa-distance ramp** that pins
  **storey-within-mesa = 0** (and hence level 0) within one tile of any mesa cliff. With it, a
  mesa-edge cell sits on its mesa floor, its lower-mesa neighbour sits on the mesa floor below,
  the drop is exactly `MESA_HEIGHT` (8m), and the cell has *no* 4m or 0.5m drops on its other
  edges → uniform 8m faces, so the authored single-height 8m tiles render with no new geometry.
  This nested-ramp structure (mesa-ramp → cliff-ramp → clamp) is why a *nested tier* is correct
  rather than loosening the storey clamp to ±2 (which would produce mixed faces).
- **Storey saturates within a mesa.** Within one mesa, storey-within-mesa ranges
  `[0, STOREYS_PER_MESA - 1]` = `[0, 1]`, so a full mesa step is always a single 8m sheer cliff,
  never two stacked 4m cliffs — exactly as a full storey is one 4m cliff, never eight 0.5m level
  tiles today. **Absolute storey** = `mesa * STOREYS_PER_MESA + storey_within_mesa`, and the
  rendered `surface_height` in absolute-storey terms is unchanged
  (`abs_storey * 4 + level * 0.5`); the mesa tier only changes *how* the storey field is
  derived and clamped.
- **Natural landforms.** High mesa columns = plateaus; low channels between them = ravines /
  valleys. Gentle relief inside a mesa is still expressed by the existing 4m sloped cliffs and
  0.5m terraces. This matches every prior decision: sheer = deeper tier only; 4m sloped stays
  the normal step; sheer applies per tall formation.

### Diagonal clamp: stricter than the storey tier

The **storey** clamp constrains only **cardinal** neighbours and deliberately leaves
**diagonals** unconstrained, so a storey can drop two storeys diagonally at a convex corner;
the storey tier renders that with a special 2-storey diagonal *ramp* corner
(`cliff-corner-stacked`, etc.) to keep the grass slope continuous to the pit floor.

The **mesa** tier clamps **diagonals too** (all 8 neighbours within ±1 mega-step). Rationale:

- Mesa walls are **sheer**, so there is no ramp to keep continuous — the 2-down diagonal case
  has no continuity benefit here.
- Allowing it would require authoring **16m stacked-corner** tiles that do not exist. Clamping
  the diagonal means every mesa corner is a single clean 8m step, fully covered by the base
  variant set already authored.

Cost: slightly smoother mesa outlines (no two-deep diagonal notches). Accepted.

## Components & changes

### 1. `HeightfieldPlan.gd` — plan math (three nested tiers)

Generalize today's two-tier (storey → level) pipeline into three tiers (mesa → storey → level),
where each lower tier is the residual within the upper, pinned to 0 within one tile of the
upper's cliffs:

- **Mesa field** `mesa_at`: `quantize_mesa(h) = _round_mode(h / MESA_HEIGHT)` clamped to
  `[0, max_mesas]`, then an **8-way clamp** (`clamp_field_8way`) constraining **cardinal *and*
  diagonal** neighbours to ±1. (Today's `clamp_field` is cardinal-only; the mesa clamp adds the
  four diagonals so no two-deep mesa diagonals form — see the diagonal-clamp section.)
- **Storey-within-mesa** `storey_in_mesa`: the residual `quantize((raw - mesa*MESA_HEIGHT) /
  STOREY_HEIGHT)`, capped by `min(detail, mesa_cap, STOREYS_PER_MESA - 1)` where
  `mesa_cap = mesa_distance - 1` (the **mesa-distance ramp**, mirroring `cliff_cap`), pinned to 0
  when a diagonal mesa cliff is present (mirroring `_has_diagonal_cliff`), then a **mesa-masked
  cardinal clamp** (`|Δ| ≤ 1` only among same-mesa neighbours — cross-mesa is the 8m cliff,
  owned by the mesa tier). Exactly the shape of today's `level_at`, one tier up.
- **Absolute storey** = `mesa * STOREYS_PER_MESA + storey_in_mesa`. `storey_at` returns this, so
  every existing downstream caller (`cell_descriptor`, instantiator, level tier) keeps working
  in absolute-storey units. The level tier is unchanged: its `cliff_distance` already keys on
  *different absolute storey*, which now includes mesa boundaries for free.
- `surface_height = abs_storey * STOREY_HEIGHT + level * LEVEL_HEIGHT`
  (`== mesa*8 + storey_in_mesa*4 + level*0.5`, since `MESA_HEIGHT == STOREYS_PER_MESA *
  STOREY_HEIGHT`). **Unchanged formula** in absolute-storey terms.
- `tile_plan` returns `{mesa, storey (absolute), storey_in_mesa, level, height}`. `mesa` is
  exposed so the variant layer can detect 8m drops directly, though the magnitude test on the
  surface-height delta is the primary signal.
- Extend `compute_region` / margins: add the mesa clamp's influence radius (one mega-step per
  tile, capped at `max_mesas`) plus the mesa-distance ramp radius (`STOREYS_PER_MESA`) to the
  outer window, the same nested-window reasoning the storey/level margins already use. The
  batched `compute_region` must equal the per-cell reference (existing equivalence tests
  extended to the mesa tier).

Constants: `MESA_HEIGHT = 8.0`, `STOREYS_PER_MESA = 2`, plus a `max_mesas` cap (=
`max_storeys / STOREYS_PER_MESA`, rounded up) governing the mesa clamp window margin.

**Determinism preserved:** every addition is a pure function of `(world_seed, cell)`. The
churn-free guarantee (a tile's planned height is final before instantiation) is unchanged.

### 2. `HeightfieldVariant.gd` — family classification

- A cardinal drop of magnitude ≈ `MESA_HEIGHT` (8m) classifies as a new **`cliff-tall`** family,
  via the same nearest-magnitude test the code already uses for 4m-vs-0.5m
  (`absf(drop - MESA_HEIGHT)` smallest → `cliff-tall`).
- Variant tags become `cliff-tall-<bare>` (e.g. `cliff-tall-side`, `cliff-tall-corner`,
  `cliff-tall-interior` for the plateau center), reusing the existing `CANONICAL_MISSING_BY_TAG`
  rotation logic unchanged.
- `origin_y` is the cell surface height as today. The 8m walls (`y=0 → y=-8`) reach exactly one
  mesa step down by construction.
- Flat mesa-plateau interior (no drop, `mesa > 0`, storey/level 0) → `cliff-tall-interior`.

### 3. `HeightfieldInstantiator.gd` — placement

- `cliff-tall` family base-fills **8m** down (new drop constant; existing cliff path uses 4m,
  level uses 0.5m).
- No understack / stacked-corner handling for mesas — the ±1 diagonal clamp removes the
  two-deep diagonal case entirely. (Storey/level understack logic is untouched.)
- Debug label support extended to the `cliff-tall` family.

### 4. `TerrainModuleDefinitions.gd` — module wiring

- `load_cliff_tall_variants()`: load the existing `CLIFF_VARIANT_TABLE` variant set from
  `res://terrain/scenes/cliff/<Name>.tscn`, tagged `["cliff-tall", "cliff-tall-<variant>",
  "24x24x8", ...]`. Register via `TerrainModuleLibrary` alongside `load_cliff_variants()`.
- The mesa cliffs are placed by the heightfield path (direct transform, no socket adjacency
  probing), so they need to be retrievable by tag; full WFC adjacency registration is **out of
  scope** unless a test shows it is needed.

### 5. Tile fixes (`terrain/scenes/cliff/*.tscn`)

- **`bottom` socket:** several tiles (e.g. [`CliffSide.tscn`](../../../terrain/scenes/cliff/CliffSide.tscn))
  have `bottom` at `y=-4`, a leftover from the 4m tile; it must be `y=-8` for an 8m tile. Audit
  all 14 scenes.
- Verify the `top*` decoration sockets sit on the (flat) 8m-plateau top surface so plateau
  decorations don't float — analogous to `test_slope_socket_grounding`. (Mesa tops are flat, so
  this should be simpler than the slope case.)

### 6. Noise (`HeightfieldPlan._height01`) — minimal

The existing amplitude (`32m` ≈ 4 mesas) already carries enough relief; the mesa
quantization + clamp surfaces it as 8m walls automatically. Start with **light tuning of the
mesa-band frequency only**, then iterate visually. No dedicated ravine-carving channel in this
pass.

## Testing

Mirror the existing `test_heightfield_*` / `test_slope_*` suites for the mesa tier:

- **Quantization & clamp math:** `quantize_mesa`; the 8-way mesa clamp produces a field where
  every neighbour (cardinal + diagonal) is within ±1 mega-step; idempotent fixpoint;
  order-independent.
- **Nesting:** storey saturates at `STOREYS_PER_MESA - 1` within a mesa; `surface_height`
  composes the three tiers correctly; a synthetic raw-height field (via
  `set_raw_height_override`) produces expected mesa/storey/level decomposition.
- **Mesa-distance ramp:** `storey_in_mesa` is pinned to 0 within one tile of any mesa cliff
  (cardinal and diagonal), mirroring the level cliff-distance ramp.
- **Uniform face guarantee:** no cell has both an 8m and a 4m (or 8m and 0.5m) cardinal drop —
  the property the mesa-distance ramp produces and that lets single-height tiles render. Assert
  over a random field.
- **Variant selection:** 8m drops → `cliff-tall-*` with correct rotation; 4m → existing
  `cliff-*`; 0.5m → `level-*`.
- **Surface continuity:** adjacent mesa tiles form a gap-free surface at shared boundaries
  (analogue of `test_slope_tile_continuity`).
- **Socket grounding:** every `top*` socket in every `cliff/` scene sits on the plateau surface;
  `bottom` sockets at `y=-8`.
- **Module registration:** every `cliff-tall-*` tag resolves to a module.

Run targeted GUT suites per the project test workflow; the full continuity/placement tests are
slow.

## Out of scope

- 16m stacked mesa corners (precluded by the diagonal clamp).
- Dedicated ravine-carving noise channel (revisit after visual iteration).
- Changes to the 4m sloped-cliff or level systems.
- WFC/socket adjacency registration for mesa cliffs beyond what the heightfield path needs.

## Risks

- **Margin/window correctness** in `compute_region` once a third clamp is threaded — the storey
  tier added exactly this kind of nested-window reasoning; reuse its margin proofs and guard
  with the determinism/equivalence tests (per-cell reference vs batched region).
- **Visual tuning** of mesa frequency is iterative; the design keeps it isolated to
  `_height01` so iteration is cheap.
