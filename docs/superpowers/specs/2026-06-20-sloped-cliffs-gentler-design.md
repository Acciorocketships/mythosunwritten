# Gentler Sloped Cliffs (50% band) + Convex Curve-Following Collision — Design Spec

**Date:** 2026-06-20
**Status:** Approved (design); pending implementation plan
**Branch:** feat/sloped-cliffs
**Builds on:** [2026-06-20-sloped-cliffs-design.md](2026-06-20-sloped-cliffs-design.md)

## Goal

Make the procedural cliff slopes **gentler** — the slope band becomes **50% of the tile
width** (12u of 24u) instead of 25% (6u), halving the grade (4u drop over 12u). Also
upgrade collision from a single straight convex ramp to a **small grid of convex slabs
that follow the slope**, staying convex (fast) rather than concave/exact.

## Decisions (confirmed with user)

| Topic | Decision |
| --- | --- |
| Slope band | **50%** of tile width = 12u (one 12×12 cell). |
| Flat top on multi-edge tiles | **True 50% accepted.** Side/corner/inner-corner keep a flat top; Line→rounded ridge, Peninsula→fully sloped, Island→dome (only a center point flat). |
| Collision | **Convex** (faster than concave trimesh; exactness not required). Each slope cell → a small grid of convex slabs following the height function; flat cells → one box. |
| Scope | Cliffs only (same 14 variants). Mating-profile continuity work is a separate, later change. |

## Approach: 2×2 grid of 12×12 cells

**The tile footprint is unchanged — still 24×24, sockets at ±12, one tile per heightfield
cell, identical adjacency and downstream placement (incl. future building placement).** The
"2×2 grid" below refers only to how each 24×24 tile is *internally* assembled from component
meshes — 4 pieces of 12×12 instead of today's 16 pieces of 6×6. The components grow because
the slope band (one piece wide) goes 6u→12u; the assembled tile stays 24×24.

The existing system bakes 4 reusable components (top / edge / outer_corner / inner_corner)
and assembles them on a grid where **the slope band is exactly one cell**. Keeping that
invariant, a 50% band means the cell grows to 12×12 and the tile becomes a **2×2 grid**
(was 4×4 of 6×6). Every cell is then a tile corner, and `SlopeVariantLayout`'s existing
per-cell classifier (outer if both touching edges slope, else edge if ≥1 slopes, else
inner if it's a masked inner corner, else top) produces the correct 4-cell layout for all
14 variants. The component meshes, the assembler/baker, socket-copying, and the
profile-seam continuity math are all **scale-independent** and carry over unchanged.

### Constant/parameter changes
- `SlopeProfile.gd`: `HALF` 3.0 → **6.0**, `CELL` 6.0 → **12.0**. `HEIGHT`/`BOTTOM`,
  `smootherstep`, and the three height functions (`edge_height`, `outer_corner_height`,
  `inner_corner_height`) are unchanged — they operate on cell-local coords in `[-HALF, HALF]`.
- `SlopeVariantLayout.gd`: `CENTERS` `[-9,-3,3,9]` → **`[-6.0, 6.0]`** (2 cells, centers at
  ±6). Generalize the grid loop and the `_corner_of` / `_edges_touching` index checks to use
  `last = CENTERS.size() - 1` (so `== 3` becomes `== last`, loops `4` become `CENTERS.size()`).
  `VARIANT_MASKS`, `EDGE_ANGLE`, `CORNER_ANGLE`, and the classification order are unchanged.
- `SlopeMeshGenerator.gd`: `H` already derives from `SlopeProfile.HALF` (→ 6). Component
  meshes become 12×12. Bump `SEG` (e.g. 10 → ~12) so the longer slope stays smooth.

### Geometric consequence (intended)
- **Side**: outer 12u ramps, inner 12u flat (50/50).
- **Corner / inner-corner**: one flat 12×12 quadrant remains.
- **Line / Peninsula / Island**: opposite/all edges' slopes meet in the middle — little or
  no flat top (ridge/dome). Accepted.

## Collision: convex slabs following the curve

Replace the single convex ramp per slope cell with **`COLLISION_SEG × COLLISION_SEG`
convex slabs** (default `COLLISION_SEG = 2` → 4 slabs/cell). Each slab is the convex hull
of one sub-quad of the surface (its 4 corner samples of the height function) plus those
points pushed down by `SKIRT`. This tracks the gentle sigmoid far better than one straight
ramp while every shape stays **convex** (fast narrow-phase). `COLLISION_SEG` is a tunable
constant (raise for a closer fit, lower for cheaper). Flat-top cells keep a single
`BoxShape3D` (`6×SKIRT×6` → now `12×SKIRT×12`), offset to `y = -SKIRT/2` by the baker.

### API change
- `SlopeMeshGenerator` collision builders return **`Array[ConvexPolygonShape3D]`** (one per
  slab) instead of a single shape: `build_edge_collision()`, `build_outer_corner_collision()`,
  `build_inner_corner_collision()` via a shared `_convex_slabs(hfn, seg) -> Array`.
  `build_top_collision()` still returns a single `BoxShape3D`.
- `bake_slope_cliffs.gd` `_save_component` adds **one `CollisionShape3D` per slab** under the
  component's `StaticBody3D` (named `CollisionShape3D`, `CollisionShape3D2`, …), each with its
  shape; the top box keeps its `y=-SKIRT/2` offset.

## Files touched
- `scripts/terrain/tools/SlopeProfile.gd` — constants.
- `scripts/terrain/tools/SlopeVariantLayout.gd` — `CENTERS` + grid-size generalization.
- `scripts/terrain/tools/SlopeMeshGenerator.gd` — `SEG`, `COLLISION_SEG`, `_convex_slabs`,
  collision builders return arrays.
- `scripts/terrain/tools/bake_slope_cliffs.gd` — multi-shape `_save_component`.
- Re-baked outputs: `terrain/gltf/slope/*.tscn` (4), `terrain/scenes/slope/Cliff*.tscn` (14).
- Tests updated for new dimensions/counts (below).
- `terrain/TERRAIN_README.md` — note the 50% band + convex-slab collision.

## Testing

Update existing slope tests for the new geometry; keep them green:
- `test_slope_profile.gd`: band endpoints now at z = ±6 (HALF=6); `edge_height(0,6)=0`,
  `edge_height(0,-6)=-4`; seam checks at x=±6.
- `test_slope_mesh_generator.gd`: top/edge AABB `size.x/z` 6 → **12**; edge y-range still
  `[-4, 0]`; collision builders now return non-empty `Array` of `ConvexPolygonShape3D`
  (assert `.size() == COLLISION_SEG*COLLISION_SEG`); `build_top_collision()` still `BoxShape3D`.
- `test_slope_variant_layout.gd`: layouts now have **4 cells** (2×2). Update counts:
  CliffSide → 2 edge / 2 top; CliffCorner → 1 outer / 2 edge / 1 top; CliffIsland → 4 outer /
  0 edge / 0 top; CliffInCorner → 1 inner / 3 top; CliffInCornerEdgeBoth → 1 outer / 1 inner /
  2 edge / 0 top. Inner cell position for CliffInCorner now at (−6, −6). Angle assertions
  unchanged (angles are scale-independent).
- `test_slope_components.gd`, `test_slope_variant_scenes.gd`: still pass (structure unchanged;
  re-bake first). Component scenes now have multiple `CollisionShape3D` under `StaticBody3D`
  for slope cells — the existing `_find` assertions still hold (≥1 present).
- `test_slope_orientation.gd`: tile half-width (±12) and min-y (−4) behavior are unchanged, but
  the flat region shrinks to the inner 12u:
  - `test_side_dips_only_at_front`: the "behind the front cells is flat" threshold moves from
    `z >= -6` to **`z >= 0`** (front cells now span z∈[−12,0]); min-y still at the front boundary.
  - `test_island_dips_on_all_four_edges`: **remove the interior-flat assertion** — at 50% the
    island is a dome with no flat interior. Keep the "drops on all four edges" check.
  - `test_right_edge_ramps_toward_right` and `test_inner_corner_dips_at_fl_exterior`: still hold
    (a right-side dip exists; the inner-corner notch is still front-left). `test_all_geometry_within_band`
    unchanged.
- `test_slope_cliff_integration.gd`: unchanged (loader path only).

Re-bake, run the slope test files isolated, then re-verify orientation (geometry test) and an
in-world render. Full regression baseline unchanged (the pre-existing
`test_heightfield_interior_corners` failure is unrelated).

## Out of scope
- Mating-profile continuity for staircase corners (separate follow-up).
- Levels and Hills.
