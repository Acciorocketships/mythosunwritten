# Project Instructions (AGENTS.md)

## Quick commands

- **Run the project**: `godot --headless --path /Users/ryko/story`
- **Run all tests (GUT)**: `godot --path /Users/ryko/story -s res://addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json`

## Project context: procedural terrain via “socketing”

- **Engine/language**: Godot 4; typed GDScript.
- **Goal**: build procedural terrain from reusable pieces (“modules”) that connect via named sockets.
- **Grid/snap**: 1.0-unit grid. Use `Helper.SNAP_POS` (single source of truth).
- **Socket transforms (off-tree safe)**: compute with `Helper.to_root_tf` and `Helper.socket_world_pos` (avoid `global_position` when off-tree).

## Terrain piece invariants

- A `TerrainModule`’s scene includes:
  - `Mesh`
  - `StaticBody3D` with a `CollisionShape3D` child
  - `Sockets` node (parent of socket `Marker3D` nodes)
- **Socket naming**: ground pieces use `"front"` for attachment, other pieces use `"bottom"`. Common expansion sockets: `"left"`, `"right"`, `"back"`, `"topfront"`, etc.
- **Socket placement**: sockets sit on the 1.0 grid for reliable adjacency.

## Types and terminology

- `TerrainModule` (Resource): `scene`, `size` (AABB), `tags`, `tags_per_socket`, `socket_size`, `socket_required`, `socket_fill_prob`, `socket_tag_prob`, optional `visual_variants`.
- `TerrainModuleInstance` (RefCounted): `def`, `root`, `socket_node` (`Sockets`), `sockets` (String → Marker3D), `transform`, `aabb`.
- `TerrainModuleSocket` (Resource): binds a piece to one socket name; exposes `socket`, `get_piece_position()`, `get_socket_position()`.
- `TagList`, `Distribution`: helpers for set/weighted ops (`union`, `sample`, `normalise`, …).
- **Sizes**: tags like `"24x24x2"` correspond to AABB extents (now include height dimension).

## Library and tag rules

- `TerrainModuleLibrary.init()` loads modules and builds tag indexes.
- **Socket tag rewrite**: tags starting with `"!"` become `"[<socket>]<tag>"` using the connecting socket context (e.g., `"!path"` with `"left"` → `"[left]path"`).
- `get_required_tags(adjacent)`: union of per-socket requirements across adjacents with `"!"` rewrites.
- `get_combined_distribution(adjacent)`: multiply per-adjacent `socket_tag_prob`, then normalize.
- Filtering/sampling: `get_by_tags` filters; `sample_from_modules(filtered, dist)` samples with bias from adjacency.

## Terrain generation flow (`scripts/TerrainGenerator.gd`)

- **_ready**
  - Initialize `TerrainModuleLibrary`, `PositionIndex`, `TerrainIndex`.
  - Spawn a start tile with `load_ground_tile()`; immediately register it in indices (use a dummy `TerrainModuleSocket`).
  - Seed a distance-priority queue with start tile sockets having `socket_fill_prob > 0`.
- **load_terrain loop**
  - Pop nearest socket; if distance > `RENDER_RANGE`, requeue and exit for this frame (`MAX_LOAD_PER_STEP` caps work).
  - Skip if the socket position already has a connection (use `PositionIndex.query_other` with the current piece to avoid self-hits).
  - Roll `socket_fill_prob` to decide sparsity.
  - Sample a size from `socket_size[socket_name]`.
  - Compute adjacency via `get_adjacent_from_size`:
	- Spawn a temporary test piece for that size, determine attachment socket using `get_attachment_socket_name()`, position the test piece correctly, then query `PositionIndex` for adjacent sockets.
 - Choose a module with library/tag logic; if initial adjacency produces no valid modules, try rotating the adjacency up to 3 times.
  - Try up to 4 attempts: create, `transform_to_socket`, then `add_piece`. On failure, destroy and retry. On success, continue.
- **Placement**
 - `transform_to_socket` aligns in XZ by rotating yaw so vectors (piece center → socket) oppose, then translates so sockets coincide (snap to grid).
  - `can_place` checks overlap via `TerrainIndex.query_box(aabb)`.
  - `add_piece` assumes the instance is created; on success, add to `terrain_parent`, register sockets, enqueue new sockets.

## Spatial indices

- `PositionIndex` (Node):
  - Stores multiple sockets per snapped position; keyed by `Helper.snap_vec3(world_pos)`.
  - `insert(ps: TerrainModuleSocket)`: uses `ps.get_socket_position()` (off-tree safe).
  - `query(pos)`: returns one socket at the snapped position or null.
  - `query_other(pos, piece)`: returns a socket at the position that belongs to a different piece (avoids self-matches).
- `TerrainIndex` (Object):
  - Hierarchical index for AABB overlap tests/culling.
  - XZ plane: 24×24 chunks; within each chunk, 4-unit X/Z buckets and 2-unit Y buckets.
  - `query_box` prunes aggressively before AABB checks. `query_outside(box)` supports future unloading/streaming.
  - `TerrainIndexSimple` exists for reference; use `TerrainIndex`.

## Conventions and code style

- **Typed GDScript**: annotate variables explicitly; avoid `:=`. Prefer `var n: int = 0`.
- **Transforms off-tree**: avoid `global_position` when nodes aren’t in the scene tree; use `Helper.to_root_tf`/`Helper.socket_world_pos`.
- **Snap**: keep socket/AABB positions on the 1.0 grid via `Helper.SNAP_POS`; snap final placement.
- **Distributions**: normalize after merges/manual edits.
- **TerrainIndex updates**: if you change transforms for already-registered modules, call `TerrainIndex.update(module)`.

## Queueing, sockets, and probabilities

- Do not enqueue attachment sockets (`"bottom"`, `"front"`); they are attachment points, not expansion points.
- Only index/enqueue sockets with `socket_fill_prob > 0` and that are not already connected (determined by `PositionIndex.query_other()`).
- Priority queue uses distance to the player; `RENDER_RANGE` and `MAX_LOAD_PER_STEP` throttle work.

## Socket Attachment System

- **Attachment Rules**: Sockets containing `"top"` attach with `"bottom"`. Cardinal directions attach with their opposites:
  - `"front"` ↔ `"back"`
  - `"left"` ↔ `"right"`
  - `"bottom"` ↔ `"top"`
- **Adjacency Rotation**: If initial adjacency produces no valid modules, rotate socket names up to 3 times to find alternative placements.
- **Test Pieces**: Dedicated test pieces exist for each size (`8x8x2`, `12x12x2`, `24x24x2`) to determine adjacency without mixing with game pieces.

## Runtime tuning

- `RENDER_RANGE` gates deferred work via the queue.
- `MAX_LOAD_PER_STEP` bounds per-frame generation.
- `socket_fill_prob` controls sparsity.
- `socket_tag_prob` biases biome/path continuity.
- `socket_size` guides scale continuity.

## Tests

- GUT-based tests include:
  - `tests/test_helper.gd` (socket utility functions: attachment mapping, adjacency rotation)
  - `tests/test_module_index.gd` (validates `TerrainIndex` vs a naive approach; deterministic + randomized scenarios)
  - `tests/test_priority_queue.gd` (heap ordering behavior)
  - `tests/test_terrain_generator.gd` (alignment, placement, adjacency, integration)
  - `tests/test_terrain_module_library.gd` (module loading, filtering, tag indexing)

## Adding new terrain pieces

- Create a scene with the required node structure and named sockets; ensure sockets are on the 1.0 grid.
- Add a corresponding `TerrainModule` entry in `TerrainModuleDefinitions`:
  - AABB, module tags, per-socket tags, `socket_size`, `socket_required` (use `"!"` where appropriate), `socket_fill_prob`, `socket_tag_prob`.
- For ground pieces: include a `"front"` socket for attachment. For other pieces: include a `"bottom"` socket for attachment.
- Socket names should follow conventions: `"front"`, `"back"`, `"left"`, `"right"`, `"topfront"`, `"topback"`, etc.
- Prefer tags like `"ground"`, `"hill"`, `"grass"` and 3D sizes like `"24x24x2"`, `"8x8x2"`. Use `"!"` socket tags for directional/path semantics as needed.

## Debugging workflow (preferred)

- If the issue isn’t obvious:
  - Add targeted `print()`s in suspected scripts
  - Run the game (`godot --headless --path /Users/ryko/story`)
  - Use console output to identify the root cause
- When asked to test a fix:
  - Re-run with relevant `print()`s and iterate until behavior is correct

## Quick API reference

- `Helper`
  - `to_root_tf(n, root)`: local-to-root transform without requiring scene tree.
  - `socket_world_pos(piece_tf, socket_node, root)`: off-tree safe world position.
  - `snap_vec3(v, snap = Helper.SNAP_POS)`: grid snap for positions/sizes.
  - `get_attachment_socket_name(expansion_socket_name)`: determines attachment socket based on expansion socket.
  - `rotate_adjacency(adjacency)`: rotates adjacency socket names for alternative placement attempts.
- `PositionIndex`
  - `insert(ps)`, `query(pos)`, `query_other(pos, piece)`.
- `TerrainGenerator`
 - `_ready()`, `load_terrain()`, `get_adjacent_from_size(socket, size)`, `transform_to_socket(new_ps, orig_ps)`, `add_piece(new_ps, orig_ps)`, `can_place(piece)`.
