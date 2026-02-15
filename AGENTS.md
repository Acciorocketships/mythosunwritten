# Project Instructions (AGENTS.md)

> **CRITICAL**: This file MUST be updated whenever the project structure, conventions, or core logic change.

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
- **Socket naming**: Sockets are named by their direction/position (e.g., `"front"`, `"back"`, `"left"`, `"right"`, `"topcenter"`, `"bottom"`).
- **Socket placement**: sockets sit on the 1.0 grid for reliable adjacency.

## Types and terminology

- `TerrainModule` (Resource): `scene`, `size` (AABB), `tags`, `tags_per_socket`, `socket_size`, `socket_required`, `socket_fill_prob`, `socket_tag_prob`, optional `visual_variants`, `replace_existing`.
- `TerrainModuleInstance` (RefCounted): `def`, `root`, `socket_node` (`Sockets`), `sockets` (String → Marker3D), `transform`, `aabb`.
- `TerrainModuleSocket` (Resource): binds a piece to one socket name; exposes `socket`, `get_piece_position()`, `get_socket_position()`.
- `TagList`, `Distribution`: helpers for set/weighted ops (`union`, `sample`, `normalise`, …).
- **Sizes**: tags like `"24x24"`, `"8x8"`, `"12x12"`, or `"point"` (for 0x0 pieces).

## Library and tag rules

- `TerrainModuleLibrary.init()` loads modules and builds tag indexes.
- **Socket tag rewrite**: tags starting with `"!"` become `"[<socket>]<tag>"` using the connecting socket context (e.g., `"!path"` with `"left"` → `"[left]path"`).
- `get_required_tags(adjacent)`: union of per-socket requirements across adjacents with `"!"` rewrites.
- `get_combined_distribution(adjacent)`: multiply per-adjacent `socket_tag_prob`, then normalize.
- Filtering/sampling: `get_by_tags` filters; `sample_from_modules(filtered, dist)` samples with bias from adjacency.

## Script organization

- **scripts/core/**: Shared utilities — `Helper.gd`, `PriorityQueue.gd`, `TagList.gd`, `Distribution.gd`.
- **scripts/terrain/**: Terrain system — `TerrainGenerator.gd`, `TerrainModule.gd`, `TerrainModuleInstance.gd`, `TerrainModuleSocket.gd`, `TerrainModuleLibrary.gd`, `TerrainModuleList.gd`, `TerrainModuleDefinitions.gd`, `TerrainGenerationRule.gd`, `TerrainGenerationRuleLibrary.gd`, `PositionIndex.gd`, `TerrainIndex.gd`, `TerrainIndexSimple.gd`.
- **scripts/terrain/rules/**: Terrain generation rules — one script per rule (e.g. `LevelContradictionRule.gd`). `TerrainGenerationRuleLibrary.gd` preloads these and appends instances to `rules`.
- **scripts/camera/**: Camera controller — `camera.gd`.
- **characters/**: Character script and controllers — `character.gd`, `controllers/player_controller.gd`, etc.

## Terrain generation flow (`scripts/terrain/TerrainGenerator.gd`)

- **_ready**
 - Initialize `TerrainModuleLibrary`, `PositionIndex`, `TerrainIndex`.
 - Spawn a start tile with `load_ground_tile()`; immediately register it in indices.
 - Seed a distance-priority queue with start tile sockets having `socket_fill_prob > 0`.
- **load_terrain loop**
 - Pop nearest socket; if distance > `RENDER_RANGE`, requeue and exit for this frame (`MAX_LOAD_PER_STEP` caps work).
 - Skip if the socket position already has a same-layer connection (ground-ground or non-ground/non-ground).
 - Roll `socket_fill_prob` to decide sparsity.
 - Sample a size from `socket_size[socket_name]`.
 - Compute adjacency via `get_adjacent_from_size`:
	- Spawn a temporary test piece for that size, determine attachment socket using `Helper.get_attachment_socket_name()`, position the test piece correctly, then query `PositionIndex` for adjacent sockets.
 - Choose a module with library/tag logic; if initial adjacency produces no valid modules, try rotating the adjacency up to 3 times.
 - Try up to 4 attempts: create, `transform_to_socket`, apply `TerrainGenerationRuleLibrary`, then `add_piece`.
- **Placement**
 - `transform_to_socket` aligns in XZ by rotating yaw so vectors (piece center → socket) oppose, then translates so sockets coincide.
 - `can_place` checks overlap via `TerrainIndex.query_box(aabb)`. Ground pieces and `replace_existing` pieces have special overlap rules.
 - `add_piece` applies `replace_existing` by removing overlapping non-ground pieces before final placement; on success, add to `terrain_parent`, register sockets, enqueue new sockets.
 - `_process_socket` is split into staged helpers (`_is_socket_connected`, `_resolve_placement_context`, `_try_place_with_rules`) so the main loop stays short and reusable.

## Spatial indices

- `PositionIndex` (Node):
 - Stores multiple sockets per snapped position; keyed by `Helper.snap_vec3(world_pos)`.
 - `insert(ps: TerrainModuleSocket)`: uses `ps.get_socket_position()` (off-tree safe). All sockets are indexed, including those with `fill_prob = 0`, so they can act as adjacency barriers.
 - `remove_piece(piece: TerrainModuleInstance)`: removes all sockets for a piece from the index.
- `TerrainIndex` (Object):
 - Hierarchical index for AABB overlap tests/culling.
 - `query_box` prunes aggressively before AABB checks.

## Conventions and code style

- **Typed GDScript**: annotate variables explicitly; avoid `:=`. Prefer `var n: int = 0`.
- **Transforms off-tree**: avoid `global_position` when nodes aren’t in the scene tree; use `Helper.to_root_tf`/`Helper.socket_world_pos`.
- **Snap**: keep socket/AABB positions on the 1.0 grid via `Helper.SNAP_POS`; snap final placement.
- **Distributions**: normalize after merges/manual edits.

## Queueing, sockets, and probabilities

- Do not enqueue sockets with `socket_fill_prob <= 0`.
- Only index/enqueue sockets that are not already connected (determined by `PositionIndex.query_other()`).
- Priority queue uses distance to the player; `RENDER_RANGE` and `MAX_LOAD_PER_STEP` throttle work.

## Socket Attachment System

- **Attachment Rules**: `Helper.get_attachment_socket_name(expansion_socket_name)` determines which socket on the new piece should attach to the expansion socket.
 - `"top..."` ↔ `"bottom"`
 - `"front"` ↔ `"back"`
 - `"left"` ↔ `"right"`
 - `"bottom"` ↔ `"topcenter"`
- **Adjacency Rotation**: If initial adjacency produces no valid modules, `Helper.rotate_adjacency` rotates socket names up to 3 times to find alternative placements.
- **Test Pieces**: Dedicated test pieces exist for each size (`8x8`, `12x12`, `24x24`) to determine adjacency without mixing with game pieces.

## Terrain Generation Rules (`scripts/terrain/TerrainGenerationRuleLibrary.gd`)

- Each rule lives in its own file under `scripts/terrain/rules/` (e.g. `LevelContradictionRule.gd`). `TerrainGenerationRuleLibrary.gd` instantiates rule classes in `_init()` (currently `LevelContradictionRule`) and appends them to `rules`.
- **Style**: Prefer instantiating rule classes directly (e.g. `LevelContradictionRule.new()`) rather than `preload()`ing scripts; rule scripts use `class_name` so they are globally available.
- Rule-specific helpers belong in the rule file (e.g. static or instance methods on the rule class).
- Rules can modify or skip placements based on complex logic (e.g., `LevelContradictionRule` avoids invalid level tile configurations).
- Rules can request removal of existing pieces or re-queueing of sockets.

## Adding new terrain pieces

- Create a scene with the required node structure and named sockets; ensure sockets are on the 1.0 grid.
- Add a corresponding `TerrainModule` entry in `TerrainModuleDefinitions`:
 - AABB, module tags, per-socket tags, `socket_size`, `socket_required`, `socket_fill_prob`, `socket_tag_prob`.
- Any socket can serve as an attachment socket.
- Use tags to categorize pieces (e.g., `"ground"`, `"hill"`, `"level"`) and sizes (e.g., `"24x24"`, `"8x8"`, `"point"`).

## Before finishing

- **Always run the game** before considering a change complete: `godot --headless --path /Users/ryko/story`. If the game errors, fix the error and re-run until it runs without errors.
- **After moving/renaming scripts**: run `godot --headless --path /Users/ryko/story --import` once so Godot regenerates the global script class cache; otherwise you may see "Could not find type X in the current scope" when running headless.

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
 - `insert(ps)`, `query(pos)`, `query_other(pos, piece)`, `remove_piece(piece)`.
- `TerrainGenerator`
 - `_ready()`, `load_terrain()`, `get_adjacent_from_size(socket, size)`, `transform_to_socket(new_ps, orig_ps)`, `add_piece(new_ps, orig_ps)`, `can_place(piece)`.

## Code Design Principles

- **Avoid tag/socket specific logic**: Never add conditional logic in `TerrainGenerator` based on specific tags, socket names, or piece types. All logic should be generalizable.
- **No fallbacks**: Avoid coding "fallback" behaviors. The system should work correctly without special case handling.
- **Clean and succinct**: Design the architecture to minimize special handling and edge cases. Keep code code clean and maintainable.
