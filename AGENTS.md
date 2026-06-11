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

- `TerrainModule` (Resource): `scene`, `size` (AABB), `tags`, `tags_per_socket`, `socket_size`, `socket_required`, `socket_fill_prob`, `socket_tag_prob`, optional `visual_variants`, `replace_existing`, `displaceable`.
- **Logical bounds**: `TerrainModuleInstance` uses the authored `def.size` for its AABB (never the mesh AABB — meshes overhang their tile with lips/skirts, and mesh-derived AABBs make face-adjacent tiles register as overlapping).
- **Displaceable decorations**: modules with `displaceable = true` (grass, bush, rock, tree) never block structure placement (`can_place` ignores them; the placement removes them), but they DO block other decorations (otherwise retiled tiles re-enqueue their foliage sockets and stack duplicates). Three mechanisms keep the displacement invisible:
 - `socket_suppressed_by` (per-socket `{"socket", "prob"}` map): a decoration socket is never enqueued when its tile's `topcenter` position roll would pass at the authored probability. The probability is authored independently of the current variant (level edges use the center's stacking prob) so the verdict is stable across retiles.
 - `DECO_PRIORITY_PENALTY`: decoration-capable sockets (size dist includes `"point"`) enqueue at distance + 48u, so nearby structural growth settles first.
 - Residual displacements happen almost exclusively beyond visible range.
- `TerrainModuleInstance` (RefCounted): `def`, `root`, `socket_node` (`Sockets`), `sockets` (String → Marker3D), `transform`, `aabb`.
- **Level stacking model**: stacks may only exist above a full `level-center` support (all 4 cardinals AND all 4 diagonals — an inner-corner support would leave the stack overhanging its notch). Only center tiles have a nonzero `topcenter` fill_prob; edge variants have a **blocking** `topcenter` (0.0) so stack positions above them are never probed. When `LevelEdgeRule` retiles a piece to center via `_replace_piece`, the new center's topcenter is automatically enqueued (deterministic position roll). When a support stops being a center, `LevelEdgeRule` and `_purge_orphaned_stacks` delete its stacks (support validity = the support carries the `level-center` tag; mirrors cliff stacks requiring `cliff-interior`). There is no fill-prob override mechanism — variant tags are the single source of truth for stackability.
- `TerrainModuleSocket` (Resource): binds a piece to one socket name; exposes `socket`, `get_piece_position()`, `get_socket_position()`.
- `TagList`, `Distribution`: helpers for set/weighted ops (`union`, `sample`, `normalise`, …).
- **Sizes**: tags like `"24x24"`, `"8x8"`, `"12x12"`, or `"point"` (for 0x0 pieces).

## Library and tag rules

- `TerrainModuleLibrary.init()` loads modules and builds tag indexes.
- **Socket tag rewrite**: `[socket]tag` in `tags_per_socket` becomes `"[<socket>]<tag>"` using the connecting socket context.
- `get_required_tags(adjacent)`: union of per-socket requirements across adjacents with socket-context rewrites.
- `get_combined_distribution(adjacent)`: multiply per-adjacent `socket_tag_prob`, then normalize.
- Filtering/sampling: `get_by_tags` filters; `sample_from_modules(filtered, dist)` samples with bias from adjacency.

## Script organization

- **scripts/core/**: Shared utilities — `Helper.gd`, `PriorityQueue.gd`, `TagList.gd`, `Distribution.gd`.
- **scripts/terrain/**: Terrain system — `TerrainGenerator.gd`, `TerrainModule.gd`, `TerrainModuleInstance.gd`, `TerrainModuleSocket.gd`, `TerrainModuleLibrary.gd`, `TerrainModuleList.gd`, `TerrainModuleDefinitions.gd`, `TerrainGenerationRule.gd`, `TerrainGenerationRuleLibrary.gd`, `PositionIndex.gd`, `TerrainIndex.gd`, `TerrainIndexSimple.gd`.
- **scripts/terrain/rules/**: Terrain generation rules — one script per rule (e.g. `LevelContradictionRule.gd`). `TerrainGenerationRuleLibrary.gd` preloads these and appends instances to `rules`.
- **scripts/camera/**: Camera controller — `camera.gd`.
- **characters/**: Character script and controllers — `character.gd`, `controllers/player_controller.gd`, etc.
- **docs/known-issues/**: Investigation dossiers for known generation/performance issues and fix history.

## Terrain generation flow (`scripts/terrain/TerrainGenerator.gd`)

- **_ready**
 - Initialize `TerrainModuleLibrary`, `PositionIndex`, `TerrainIndex`.
 - Spawn a start tile with `load_ground_tile()`; immediately register it in indices.
 - Seed a distance-priority queue with start tile sockets having `socket_fill_prob > 0`.
- **load_terrain loop**
 - Pop nearest socket; out-of-range sockets are staged and re-queued after the per-frame processing loop (prevents same-frame pop/requeue churn).
 - Skip if the socket position already has an expandable connection (connection logic is based on socket expandability, not tile tags/layers).
 - Sparsity was already decided at enqueue time (deterministic position roll — see "Queueing, sockets, and probabilities"); the pop path only re-checks expandability.
 - Sample a size from `socket_size[socket_name]`.
 - Compute adjacency via `get_adjacent_from_size`:
	- Spawn a temporary test piece for that size, determine attachment socket using `Helper.get_attachment_socket_name()`, position the test piece correctly, then query `PositionIndex` for adjacent sockets.
	- For ground expansion sockets, non-ground adjacency is ignored on lateral sockets, but kept on `"top..."` sockets so elevated systems (like level tiles) can connect to existing non-ground neighbors.
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
 - `insert(ps: TerrainModuleSocket)`: uses `ps.get_socket_position()` (off-tree safe). All sockets are indexed, but barrier behavior is controlled by `socket_fill_prob` semantics (see below).
 - `query_others(pos, piece)`: returns all sockets at a snapped position except those from `piece` (use this when overlap can contain more than one candidate).
 - `remove_piece(piece: TerrainModuleInstance)`: removes all sockets for a piece from the index.
- `TerrainIndex` (Object):
 - Hierarchical index for AABB overlap tests/culling.
 - `query_box` prunes aggressively before AABB checks.

## Conventions and code style

- **Typed GDScript**: annotate variables explicitly; avoid `:=`. Prefer `var n: int = 0`.
- **Transforms off-tree**: avoid `global_position` when nodes aren’t in the scene tree; use `Helper.to_root_tf`/`Helper.socket_world_pos`.
- **Snap**: keep socket/AABB positions on the 1.0 grid via `Helper.SNAP_POS`; snap final placement.
- **Distributions**: normalize after merges/manual edits.

### Code style requirements (simplify as much as possible)

- **Consolidate repeated logic**: If the same or similar logic appears in multiple locations, it probably can be consolidated.
- **Avoid retries/iterations/try-catch**: If we have retries, loops over attempts, or try/catch, rethink the design so the normal path works without them.
- **Minimize special cases**: A lot of handling for corner cases or tag/socket-specific behavior (e.g. "if this happens only for tiles with tag X") usually means we can rethink the design, reorganise the code, and implement a more robust system that doesn't need special cases.
- **Prefer shorter code**: In general, if we can edit something to be shorter, that will be simpler and more understandable.

## Queueing, sockets, and probabilities

- Do not enqueue sockets with `socket_fill_prob <= 0`.
- `_process_socket` also early-exits when the socket is not expandable so externally re-queued sockets cannot expand.
- **Sparsity roll happens at enqueue time** (`add_piece_to_queue`), not at pop time: the queue only ever holds sockets that will actually expand once in range.
- **Rolls are deterministic per world position**: `Helper.position_hash01(socket_pos, world_seed)` is compared against the effective fill prob. Piece retiles (rule replacements) re-derive the same verdict instead of getting a fresh roll — without this, frontier sockets get re-rolled on every neighbour retile and any fill probability ratchets toward 1 (the historical "cliffs grow until they cover everything" bug).
- **Macro density field**: `TerrainGenerator._effective_fill_prob` multiplies fill probs (only those `< 1.0`) by a factor derived from `Helper.macro_density01(pos, world_seed)` — smooth value noise over ~`Helper.MACRO_SCALE` (144u) XZ regions, faded to 0 near the world origin so the spawn is always open meadow. Features (mountains, level hills, groves) cluster in high-density cores and die out past the core edge, which is what bounds cluster size. Structural sockets (fill `>= 1.0`, e.g. ground laterals) ignore the field so ground stays infinite.
- Queue entries are deduped by `(piece instance, socket name)`; do not bypass `TerrainGenerator` queue helpers when enqueuing/removing sockets (exception: rules may push sockets via `sockets_for_queue`, which deliberately skips the sparsity roll).
- `socket_fill_prob` semantics:
 - `> 0`: socket can expand and is non-forbidden for adjacency.
 - `0`: socket cannot expand and is considered blocking/forbidden in adjacency checks. Edge-variant `topcenter` sockets use `0.0` (blocking) so stack tiers can never be probed above a non-center/non-interior tile. Cliff-interior lateral sockets use `0.0` so neighbouring expansions can never probe into the plateau footprint (non-blocking laterals let a neighbour expand into the interior, eat it via replace_existing, and churn forever).
 - `null`: socket cannot expand but is **non-blocking** in adjacency checks (use for adjacency-only sockets such as level diagonals).
 - Missing `socket_fill_prob` entries are invalid and must fail module validation. Every socket in a module scene must have an explicit `socket_fill_prob` entry.
- Only index/enqueue sockets that are not already connected (determine connectivity by checking all hits at the position, not only the first).
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

- Each rule lives in its own file under `scripts/terrain/rules/` (`WaterRule.gd`, `CliffEdgeRule.gd`, `LevelEdgeRule.gd`, `ClusterFillRule.gd`). `TerrainGenerationRuleLibrary.gd` instantiates rule classes in `_init()` and appends them to `rules` (WaterRule runs first because it may swap the placed base tile; ClusterFillRule runs last so it sees the final retiled placement).
- `ClusterFillRule`: when a placed cliff/level tile leaves an empty cardinal position with >=2 same-family same-height neighbours, it pushes that expansion socket directly onto the queue (no sparsity roll). This convexifies clusters into chunky plateaus that can host interior tiles — which is what enables vertical stacking.
- **Style**: Prefer instantiating rule classes directly (e.g. `LevelContradictionRule.new()`) rather than `preload()`ing scripts; rule scripts use `class_name` so they are globally available.
- Rule-specific helpers belong in the rule file (e.g. static or instance methods on the rule class).
- Rules can modify or skip placements based on complex logic (e.g., `LevelContradictionRule` avoids invalid level tile configurations).
- `LevelContradictionRule` compares fillability using the actual touching socket names from adjacency (do not remap through expansion attachment logic).
- Rules can request removal of existing pieces or re-queueing of sockets.
- Rules return `piece_updates` (Dictionary: `TerrainModuleInstance -> TerrainModuleInstance|nil`) so one rule can retile/remove multiple pieces in one pass.
- `TerrainGenerator` applies `piece_updates` after successful placement, replacing/removing already-placed pieces and re-registering replacements.

## Level edge retile system

- Terrain sampling library includes the sampled center modules only: `level-ground-center` for the first level and `level-stack-center` for elevated levels. Visual variants (`"level-side"`, `"level-corner"`, `"level-line"`, `"level-peninsula"`, `"level-island"`) are selected by `LevelEdgeRule`.
- `LevelEdgeRule` computes missing neighbors on cardinal sockets and rotates canonical edge variants to match missing sides.
- If all cardinals are connected, `LevelEdgeRule` computes missing diagonal neighbors and selects inner-corner variants (`"level-inner-corner"`, `"level-inner-corner-diag"`, `"level-inner-corner-side"`, `"level-inner-corner-three"`, `"level-inner-corner-all"`), rotated from canonical `"frontleft"`-based socket sets.
- Diagonal edge detection is same-layer only; elevated tiles must not affect lower-level inner-corner or edge silhouettes.
- `LevelEdgeRule` treats a diagonal as an inner-corner gap only when both touching cardinals are connected; this allows mixed variants that combine inner-corner diagonals with cardinal edges (`"level-inner-corner-edge1"`, `"level-inner-corner-edge2"`, `"level-inner-corner-edge-both"`, `"level-inner-corner-side-edge"`).
- When a new level tile is chosen, `LevelEdgeRule` also updates directly adjacent level tiles so their edge silhouettes stay consistent after the new connection appears.
- Level expansion is encoded in the module tier, not in `TerrainGenerator`:
 - `level-ground` variants may expand laterally to form first-level patches.
 - `level-stack` variants are vertical-only; their lateral sockets are non-expandable.
 - `LevelEdgeRule` preserves the `level-ground`/`level-stack` tier when it retile-swaps variants.
 - Elevated stacked tiles are only valid above supports that have all four cardinal level neighbors.
- Default level density is intentionally higher on the first level: ground `"topcenter"` uses stronger level seeding so contiguous level patches can form before elevated vertical growth takes over.

## Water, banks, rivers and islands

- `Helper.is_water(pos, world_seed)` is the deterministic water field: ridged value noise forms winding rivers, blob noise forms lakes, finer noise carves islands inside water regions, isolated single-tile ponds are eroded, and the field fades to zero near the origin (dry spawn).
- The base plane has three tile kinds: plain ground (sampling tag `ground-plain`), `water`, and `bank`. Water and banks also carry `ground`/`side` so they satisfy neighbour requirements, but lateral tag distributions sample `ground-plain` exclusively — water/banks are placed only by `WaterRule`.
- `WaterRule` (runs first) swaps a placed plain-ground tile for a water tile when the field says so, and retiles land adjacent to water to bank variants: the cliff scenes placed at ground depth (grass top at ground level, rock wall dropping to the water floor), rotated so the wall faces the water. Classification counts ungenerated neighbour positions via the field so banks don't churn while the frontier advances.
- `WaterTile` rides the ground grid: lateral sockets at ground level keep the frontier flowing across water; its `topcenter` is blocking (0.0) so levels can never cantilever over open water. Solid collision sits at the basin floor; an `Area3D` volume on collision layer 8 marks the water body for swimming.
- **Swimming** (`characters/character.gd`): the character probes the water volume each physics frame (point query at knee height). In water: movement at `SWIM_SPEED_FACTOR`, drag pulls vertical speed toward a slow sink, and holding jump floats it up to a bobbing equilibrium about half-submerged (`SWIM_FLOAT_DEPTH` below the surface, oscillating by `BOB_AMPLITUDE`; `jump_held` on `CharacterController`). Pressing into a bank wall near the surface with jump held (or pressed) launches the character out of the water like a jump. Verified by `tests/harness/swim_harness.tscn` (sink / bob / leap-out phases with screenshots).
- **Water visuals**: `terrain/water/Water.gdshader` is a Godot 4 port of the ideas in `assets/SeaWaterMaterial` (a Godot 3 asset that cannot be loaded directly): world-space layered waves (seamless across tiles), fine ripple normals, depth-tinted transparency, and depth-based animated shore foam via `hint_depth_texture`. `scenes/world.tscn` has a `WorldEnvironment` with a procedural sky so the water has something to reflect.

## Adding new terrain pieces

- Create a scene with the required node structure and named sockets; ensure sockets are on the 1.0 grid.
- Add a corresponding `TerrainModule` entry in `TerrainModuleDefinitions`:
 - AABB, module tags, per-socket tags, `socket_size`, `socket_required`, `socket_fill_prob`, `socket_tag_prob`.
- Any socket can serve as an attachment socket.
- Use tags to categorize pieces (e.g., `"ground"`, `"hill"`, `"level"`) and sizes (e.g., `"24x24"`, `"8x8"`, `"point"`).
- **Decoration visual variants**: grass/bush/rock/tree modules carry `visual_variants` (random pick at create time). To add a new decoration look: wrap the KayKit gltf in `terrain/gltf/<name>.tscn` (tree x2.5 + capsule collision, bush x4, rock x3 + cylinder collision, grass x1 — match the existing wrappers), create `terrain/scenes/<Name>.tscn` (Mesh + Sockets/bottom), and append it to the kind's `_load_scenes([...])` list in `TerrainModuleDefinitions`.
- **Shared surface spawning**: `TerrainModuleDefinitions.surface_spawn_sockets()` is the single source of truth for what spawns on top of a walkable tile (foliage on the 8 top cardinal/corner sockets + a seeding distribution on `topcenter`). Ground tiles, level centers, and cliff plateau interiors all merge its output into their socket dicts — change spawning behavior there, not per-module.
- **Cliff tier tags**: every cliff variant carries both the bare variant tag (`"cliff-side"`, matches both tiers) and a tier-qualified tag (`"cliff-base-side"` / `"cliff-stack-side"`). Seeding/lateral distributions must use the tier-qualified tags — sampling a bare tag picks a random tier, and a cliff-stack at ground level (or vice versa) is invalid and gets removed by CliffEdgeRule.

## Before finishing

- **Always run the game** before considering a change complete: `godot --headless --path /Users/ryko/story`. If the game errors, fix the error and re-run until it runs without errors.
- **After moving/renaming scripts**: run `godot --headless --path /Users/ryko/story --import` once so Godot regenerates the global script class cache; otherwise you may see "Could not find type X in the current scope" when running headless.
- **Maintain known-issues docs**: whenever you discover new root-cause context, repro details, logs, or fix outcomes for active issues, update files under `docs/known-issues/` in the same change.

## Screenshot harness (visual iteration)

- `godot --path . res://tests/harness/screenshot_harness.tscn` boots the real world, walks the character in a slow spiral, and saves screenshots to `/tmp/terrain_shots/` every 8s for ~80s: `shot_NN_gameplay` (player camera), `shot_NN_overhead` (above the player), `shot_NN_wide` (top-down, ~600u), `shot_NN_mountain` (aimed at the tallest piece).
- It also prints `[harness N] fps=... pieces=... queue=... counts={ground/level/cliff/hill}` — use these to detect runaway growth (a family count exploding), churn (pieces count oscillating), and perf regressions.
- Each checkpoint also runs `_scan_invariants`, which prints `[scan N] violations=K` plus a line per violation: wrong-tier tiles, stacks without a center/interior support, and edge variants whose tag disagrees with their actual neighbours. A healthy run reports 0 everywhere.
- **Scene gotcha**: inner-corner level variants carry adjacency-only `topfrontleft`-style rule markers. Never add same-named sockets to those scenes — duplicate node names in a `Sockets` parent corrupt instantiation (crashes Godot's ObjectDB). Level foliage uses the 4 top cardinals only.

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
 - `insert(ps)`, `query(pos)`, `query_other(pos, piece)`, `query_others(pos, piece)`, `remove_piece(piece)`.
- `TerrainGenerator`
 - `_ready()`, `load_terrain()`, `get_adjacent_from_size(socket, size)`, `transform_to_socket(new_ps, orig_ps)`, `add_piece(new_ps, orig_ps)`, `can_place(piece)`.

## Code Design Principles

- **Avoid tag/socket specific logic**: Never add conditional logic in `TerrainGenerator` based on specific tags, socket names, or piece types. All logic should be generalizable.
- **No fallbacks**: Avoid coding "fallback" behaviors. The system should work correctly without special case handling.
- **No backward compatibility paths**: When behavior or schema changes, update all call sites/tests/data in the repo to the new contract immediately instead of keeping legacy compatibility branches.
- **Clean and succinct**: Design the architecture to minimize special handling and edge cases. Keep code clean and maintainable.

## Future plans

- **Level-on-level → cliff**: Add rule so that when a level is placed on top of another level tile, the bottom one is transformed into a cliff side (need to add cliff asset).
- **Level tile sockets**: Level variants now include bottom-side sockets (`bottomfront`, `bottomback`, `bottomleft`, `bottomright`) with `fill_prob` 0 and no requirements, while corner sockets stay on top (`topfrontleft`, `topfrontright`, `topbackleft`, `topbackright`) for rule adjacency logic.
- **Inner corners (level rule)**: Add inner corners to level rule; check diagonals (one use case for the new sockets). If the diagonal is free, that side needs an interior corner.
- **Modularise ground/level tile logic**: Give level tiles the same logic as ground tiles; only difference is that another level is significantly more probable on level tiles. Use the new sockets so the majority of level tiles are slightly inset from the platform below (avoid unwanted cliff).
- **Guaranteed-fill rule**: Add a rule that guarantees fill with a tag if at least n adjacent tiles in some set (default: front, back, left, right) have that tag.
- **Camera**: Fix camera blurring/jittering; add new camera controller that follows the mouse.
- **Character**: Strafing where character always looks towards the mouse; dodge/dash animation. (Stepping over ledges is implemented in `characters/character.gd` via `MAX_STEP_HEIGHT` + step probe motion.)
- **Items and inventory**.
- **Full list**: See `docs/future-work/` for detailed future-work projects in markdown files.
