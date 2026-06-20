# Sloped Cliffs — Design Spec

**Date:** 2026-06-20
**Status:** Approved (design); pending implementation plan
**Scope:** Replace the sheer-faced cliff tiles with parametric, sigmoid-sloped sides. Cliffs only (the `Cliff*` variant family). Levels and Hills are out of scope for this pass.

## Goal

Today the cliff tiles (`terrain/scenes/Cliff*.tscn`) are assembled from fixed KayKit
art parts and present **vertical sheer faces** dropping 4 units from the plateau to the
lower ground. We want **sloped sides** with a continuous derivative ("sigmoid-like"):
the outer 25% of each exposed edge ramps smoothly down, the inner 75% stays a flat,
walkable plateau. The top surface keeps the current grass look, and the slope is grass
all the way down. Collision stays cheap but follows the shape closely.

## Decisions (confirmed with user)

| Topic | Decision |
| --- | --- |
| Footprint | Slope stays **inside** the existing 24×24 tile footprint. Outer ~6u of each exposed edge ramps from plateau (`y=0`) to lower ground (`y=-4`); inner region flat. Neighbours/grid unchanged. |
| Slope surface | **Grass all the way down** (green palette), top texture unchanged. |
| Collision | **One convex ramp per sloped cell** (top→bottom incline) + thin flat boxes. Cheapest; straight convex under the curved mesh ⇒ minor (cm-scale) mid-slope visual/collision mismatch — accepted. |
| Module scope | **Cliffs only** — the 14 `Cliff*` variants. |
| Authoring | **Parametric / procedural** mesh generation via a `@tool` script (sigmoid is math). New components + scenes go in **subfolders** of `terrain/gltf` and `terrain/scenes`. |
| Swap-in | Point the cliff variant table at the new `slope/` scenes (replace). Old KayKit cliff scenes remain on disk for rollback. |

## Current system (facts established)

- Cliff tile = **24×24 units, 4 tall**. Sockets at `±12` (lateral), `bottom` at `y=-4`,
  plus `top*` sockets. Origin (`y=0`) is the plateau top; `bottom` attaches to a ground
  tile 4 units below.
- Existing cliff scenes tile many ~3u-wide KayKit parts along edges
  (`hill_cliff_tall_h_side`), plus `hill_cliff_tall_i_outer_corner` /
  `_i_inner_corner`, top parts (`hill_top_*`), and a `hill_top_e_center` fill.
- Each KayKit part wraps a `.gltf` and adds a `StaticBody3D` + box `CollisionShape3D`.
- Texture is a **KayKit color-palette atlas** (`assets/KayKitNature/Assets/gltf/Color1/forest_texture.png`),
  exposed via `terrain/materials/ground.tres` (resource name `forest`). Grass-green and
  rock-grey are different texels in that atlas, selected per-vertex by UV.
- The 14 cliff variants are registered in
  `scripts/terrain/TerrainModuleDefinitions.gd`:
  - `CLIFF_VARIANT_TABLE` maps `scene_name → variant_tag` (14 entries).
  - `load_cliff_variants()` builds each at two tiers (`cliff-base`, `cliff-stack`) via
    `load_cliff_variant()`, which resolves `res://terrain/scenes/<name>.tscn`.
  - Tiles carry tag `"24x24x4"`; sockets drive heightfield adjacency.

The 14 variants:
`CliffSide, CliffCorner, CliffLine, CliffPeninsula, CliffIsland, CliffInCorner,
CliffInCornerDiag, CliffInCornerSide, CliffInCornerThree, CliffInCornerAll,
CliffInCornerEdge1, CliffInCornerEdge2, CliffInCornerEdgeBoth, CliffInCornerSideEdge`.

## Geometry

### Profile
Across the 6u slope band, with local axis `s` going from the inner break-line outward:
`t = s / 6`, `t∈[0,1]`, and

```
height(t) = -4 · smootherstep(t)        # smootherstep(t) = 6t^5 − 15t^4 + 10t^3
```

`smootherstep` has zero first derivative at `t=0` and `t=1`, so the surface meets the
flat plateau (at the inner break-line) and the flat lower ground (at the tile boundary)
with **C1 continuity** — the desired sigmoid feel. A `steepness`/profile param is exposed
on the generator for future tuning; default = smootherstep.

### 6u sub-grid decomposition
The 24×24 tile = a **4×4 grid of 6×6 cells**. The slope band is exactly one cell wide,
so the inner 2×2 cells (12×12) are always flat, and the perimeter cells carry slopes.
Every configuration tiles from **4 reusable component meshes**, each used at 4 rotations:

1. **Top** — flat 6×6 grass plateau cell at `y=0`.
2. **Edge** — sigmoid ramp along one axis (down toward the exposed edge), flat across the
   perpendicular axis.
3. **Outer corner** — convex corner: ramps down in **two** directions (rounded quarter),
   for a tile corner where two perpendicular edges are both exposed.
4. **Inner corner** — concave corner: plateau wraps around; only the corner notch dips,
   for re-entrant corners.

Mesh resolution along the slope: enough segments for a smooth curve (e.g. 8–12 per 6u
band); flat cells are minimal quads.

### Assembly per variant
Each of the 14 `Cliff*` variant scenes is rebuilt as a placement of these 4 components
(rotated) across the 4×4 grid according to which edges/corners are exposed for that
variant, **preserving the existing socket node layout** (`front/back/left/right/…`,
`bottom` at `y=-4`, `top*`) so heightfield adjacency and stacking behave identically.

## Texture

Assign the existing `forest` material (`terrain/materials/ground.tres`). Every generated
vertex's UV is set to the **grass texel**, whose UV is **sampled at bake time from the
existing `Hill_Top` mesh** (read its surface UV array, take a representative grass-top
vertex UV) rather than hardcoding pixel coordinates — guarantees an exact palette match.

## Collision

Per sloped cell: one **convex** collision shape approximating the ramp (a tilted
box/convex hull from the top break-line down to the bottom edge). Flat cells: a thin box.
Assembled as `StaticBody3D` + `CollisionShape3D` children, mirroring the existing
component-scene convention. This keeps collision cheap and walkable; the accepted
tradeoff is a small mid-slope deviation from the curved render mesh.

## Files & integration

- **Generator** — `@tool` script under `scripts/terrain/tools/` that bakes the 4
  component `ArrayMesh`es (and their convex collision shapes), parameterised by
  height (4), band width (6), and profile.
- **Components** — `terrain/gltf/slope/` : 4 `.tscn` wrappers (MeshInstance3D +
  StaticBody3D/CollisionShape3D + any needed Sockets), following `TERRAIN_README.md`
  conventions.
- **Variant scenes** — `terrain/scenes/slope/` : 14 rebuilt `Cliff*.tscn`, same names,
  same socket layout, assembled from the `slope/` components.
- **Swap-in** — update `load_cliff_variant()` in `TerrainModuleDefinitions.gd` to resolve
  `res://terrain/scenes/slope/<name>.tscn`. Old scenes stay on disk for rollback.

## Verification

- Headless run of the project; screenshot `scenes/world.tscn` to confirm sloped cliffs
  render with grass slopes and a flat plateau, with no gaps at tile/variant seams.
- Existing terrain tests must still pass: `test_heightfield_*`, `test_module_index`,
  `test_terrain_module_library`, socket/adjacency tests (the swap keeps tags, sizes, and
  socket layout identical, so these should be unaffected).
- Spot-check a multi-tile cliff (Side + Corner + InnerCorner) for continuous slopes
  across tile boundaries.

## Out of scope

- Level (`Level*`) and Hill (`Hill_*`) families.
- Multi-storey/stack-tier visual changes beyond reusing the same new components.
- Reworking the heightfield placement logic (only the scene contents change).
