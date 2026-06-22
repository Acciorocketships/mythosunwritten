## How to Add New Tiles
1. Right-click the .gltf and select New Inherited Scene
2. Click on the new scene that was created and ⌘s save it to the terrain/gltf directory
3. Create a new scene, select 3D Scene, and save it as terrain/scenes/tilename.tscn
4. Drag the visual scene in terrain/gltf onto the root node in the new scene to create an instance as a child.
5. If the object can be collided with, then add a StaticBody3D as a child of the root, and add a CollisionShape3D as a child of that. Set the collision shape.
6. Add a Node3D called "Sockets", and add Marker3D as sockets under it, one of which must be "main". It will be attached to other pieces via the main socket.
7. Add a new function load_tile_name() to TerrainModuleLibrary, and then call that function and add it to terrain_modules in load_terrain_modules().

## Tall tiles (cliffs, ≥4 units)

Tall tiles like the cliff variants follow the same conventions as ground/level tiles, with one extension:
- Origin is at the **top surface** (lateral sockets at local `y=0`).
- `bottom` socket is at local `y=-H` where H is the tile height (e.g., `(0, -4, 0)` for a 4-unit cliff). It attaches to a ground tile at world `y=0` below.
- Use a height-suffixed size tag (e.g., `"24x24x4"`) so adjacency probing uses the correct test piece with sockets at the right height.
- Register a corresponding test piece in `TerrainModuleLibrary.load_test_pieces()` if no existing one matches the height.

## Sloped cliffs (procedural)

The cliff family uses **procedurally generated, grass-covered sloped sides** instead of
sheer faces. Each exposed edge ramps over the outer **50%** of the tile (12u of the 24u
width) from the plateau (`y=0`) down to the lower ground (`y=-4`) with a smootherstep
profile (continuous derivative at top and bottom); the inner 50% stays flat. Tiles remain
24×24 — only the internal subdivision changed. Because the band is half the tile, a Line
variant becomes a ridge and an Island a dome.

- **Components** (generated): `terrain/gltf/slope/{top,edge,outer_corner,inner_corner}.tscn`
  — four reusable 12×12 cells, each a `MeshInstance3D` + `StaticBody3D`. Slope cells carry
  `COLLISION_SEG²` convex collision slabs that follow the curve; `top` is a single flat box.
- **Assembled variants** (generated): `terrain/scenes/slope/Cliff*.tscn`, built on a 2×2
  grid of those components, with each original's `Sockets` node copied so adjacency is
  unchanged. The adjacency sockets (`front`/`back`/`left`/`right`, diagonals, `bottom`) keep
  their original `y=0`, but the **top-surface decoration sockets** (`topcenter`/`topfront`/
  `topback`/`topleft`/`topright`) are **dropped onto the slope** at bake time via
  `SlopeProfile.surface_height(cells, x, z)` — otherwise a socket over a slope band would
  stay at `y=0` while the grass dropped below it, leaving its decoration floating (decorations
  attach socket-to-socket, no raycast). `topcenter` is always at the plateau centre, so it
  stays at `y=0`.
- **Loader**: `TerrainModuleDefinitions.load_cliff_variant()` resolves cliff scenes from
  `res://terrain/scenes/slope/`.
- **Regenerate** all component + variant scenes after changing the profile/params/layout:
  `Godot --headless --path . -s scripts/terrain/tools/bake_slope_cliffs.gd`
- **Tuning**: profile + dims in `SlopeProfile.gd` (`HALF`, `CELL`, `HEIGHT`, `smootherstep`);
  mesh resolution / collision density in `SlopeMeshGenerator.gd` (`SEG`, `SKIRT`,
  `COLLISION_SEG`); grid size + per-variant edge/corner exposure in `SlopeVariantLayout.gd`
  (`CENTERS`, `VARIANT_MASKS`). Scope: **cliffs only** — Level (0.5m terraces) and Hill
  tiles are unchanged (still sheer).

### Two-storey diagonal corners (continuity)

The cardinal clamp keeps cardinal neighbours within one storey, but a **diagonal** drop can
be two storeys (a convex corner one diagonal step above a pit, with the two adjoining
cardinals clamped to one storey between — the clamp caps diagonals at two). A single
one-storey corner can't reach the pit floor there, so it would bottom out at a ledge with a
sheer drop. The fix is a **2-storey diagonal-ramp corner**:

- **Profile**: `SlopeProfile.outer_corner_stacked_height` is `BOTTOM·(rampz + rampx)` — the
  sum of the two per-axis edge ramps. Along each cardinal edge-seam one ramp is 0, so it
  reduces to the plain `edge` profile (mating continuously with the 1-storey sloping
  neighbour); at the open-diagonal vertex both are 1, reaching `2·BOTTOM` = the pit floor.
- **Components / scenes**: `outer_corner_stacked.tscn` (2 storeys tall, 2-storey collision)
  is assembled into the stacked variant scenes. A plain corner uses `CliffCornerStacked`
  (tag `cliff-corner-stacked`). Any variant with **two adjacent edge-walls meeting at a
  convex corner** can have that corner drop two storeys, so the baker **generates one variant
  per non-empty subset of those corners** (e.g. `CliffIslandStacked_FLBR`, tag
  `cliff-island-stacked-flbr`) via `SlopeVariantLayout.generated_stacked_variants()`. The
  stackable bases are peninsula (FL/FR), island (FL/FR/BL/BR), **and
  `inner-corner-edge-both`** (back+right meet at a convex BR corner, alongside an FL inner
  notch → `CliffInCornerEdgeBothStacked_BR`). This last one was the lone case still showing a
  triangular sheer ledge before being added (`SlopeVariantLayout.STACKABLE_BASES`).
- **Selection**: automatic. `HeightfieldInstantiator` detects each 2-storey-down diagonal,
  maps its world socket back to the canonical corner (un-rotating by the tile's
  `rotation_steps`), and selects the variant baked for that exact corner subset. Each ramp
  variant gets a base plate two storeys down (the pit floor). No concave understack tile is
  spawned for cliffs (level 0.5m two-tier diagonals still stack a sheer `LevelInCorner`).
- **Peninsula orientation**: `CliffPeninsula`'s slope mask uses `["front","left","right"]`
  (open = back) to match `HeightfieldVariant`'s canonical peninsula — the heightfield drives
  cliff placement by computed rotation, so the slope geometry must use its convention.

### Tests

- `test_slope_*` — profile math, mesh/collision, variant layout, baked-scene/socket parity,
  module registration, orientation.
- `test_slope_tile_continuity` — random-field guard: adjacent cliff tiles must form a
  gap-free surface at shared boundaries (0 gaps).
- `test_slope_socket_grounding` — every `top*` decoration socket in every baked slope scene
  must sit on the actual mesh surface (sampled triangle-accurately), so decorations don't
  float over slope bands.
- `test_slope_edgeboth_corner` — the `inner-corner-edge-both` convex BR corner, when it drops
  two storeys, must select the ramp variant and form a gap-free surface (regression for the
  triangular sheer ledge).
- `test_diag_seams` — deterministic, triangle-accurate guard: samples the actual walkable
  surface over controlled staircases (single-storey, 2-storey pit, real-field spot) and
  asserts no vertical discontinuities. Run targeted; it spawns full placements so it's slow.
