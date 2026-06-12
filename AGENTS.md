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
- **Bounds must claim the piece's full occupied volume, not just its visible mesh.** Cliff INTERIOR tiles are visually a thin ground slab at the plateau top, but their bounds cover the whole 4u storey below — with slab-only bounds the volume under the plateau is unindexed, so a buried ground tile's still-queued (deco-deferred) foliage sockets pass `can_place` and plant trees inside the mesa, poking out of the plateau top (regression: `tests/test_deco_burial.gd`; audit harness: `tests/harness/debug_deco_scan.gd` reports BURIED/ORPHAN decorations across 8 seeds).
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
- **Macro density field**: `Helper.macro_density01(pos, world_seed)` — smooth value noise over ~`Helper.MACRO_SCALE` (144u) XZ regions, faded to 0 near the world origin so the spawn is always open meadow. Structural sockets (fill `>= 1.0`, e.g. ground laterals) ignore every field so ground stays infinite. `TerrainGenerator._effective_fill_prob` routes each `< 1.0` socket to the field treatment that fits its role:
 - **Cliff laterals — contour carving** (`_cliff_contour_fill`): a cliff lateral expands iff macro density at the target clears `CLIFF_CONTOUR_BASE + CLIFF_CONTOUR_STEP * storey` (storey from the piece origin height; base tier sits at y=4.5). Mesas come out as solid field-shaped blobs — independent per-socket rolls produce single-storey snake mazes that never form the 3x3 interiors stacking needs — and the rising threshold plus the geometric interior inset taper mountains into stepped pyramids. `CLIFF_TOPCENTER_FILL_PROB` is 1.0 (structural): every interior tile seeds the storey above; a probabilistic roll there leaves ragged holes in upper tiers that block the next tier's interiors. Ground topcenters inside a contour core seed eagerly (`CLIFF_CORE_SEED_FILL_PROB`) and the seed mix skews toward cliffs (`CLIFF_CORE_SEED_MIX_BOOST`) so every core reliably grows its mountain; mesa fill is idempotent, so extra seeds merge.
 - **Decoration sockets** (size dist includes `"point"`): biome flora density (`Helper.biome_foliage_density`), not macro — on EVERY walkable surface (ground, levels, cliff plateau tops, banks all share `GROUND_FOLIAGE_FILL_PROB` and the same routing; bank foliage sockets are pinned to point-only sizes so hills never overhang the waterline).
 - **Level-family sockets and ground topcenter seeds**: the gentle legacy curve (`_gentle_scaled_fill`, `0.25 + 2.2*macro^3`) — levels are the mid-altitude feature and the high-contrast curve would crush them.
 - **Everything else**: the high-contrast curve (`_macro_scaled_fill`, `0.15 + 3.2*macro^3.2`) that keeps lowlands flat.
- **Suppression mirrors the suppressor**: `_suppressor_roll_passes` routes the suppression prob through the SAME `_route_fill_prob` (same position hash, same curve) as the suppressor socket's own enqueue verdict. A mismatched curve either suppresses foliage nothing will displace (the historical "deco only near spawn" gradient: suppression scaled with the harsh macro curve, near zero at the origin falloff and ~40% far out) or spawns foliage where a structure is coming (pop-out). Cliff foliage is the exception: suppressed geometrically (`_cliff_foliage_covered_by_stack` — tile + all 8 neighbours inside this storey's contour means the next storey WILL cover it), because the perimeter tiles that never become interiors are deterministic for contour-carved mesas.
- **Stale queue priorities**: priorities are distances at enqueue time. Decoration sockets get enqueued when their tile is at the far frontier (priority ~300), so they lose to every fresh frontier socket while the player keeps moving — that's by design (deco trails structure) — but they must win promptly once the player stops. When the player is stationary, `load_terrain` spends its pop budget re-enqueueing stale out-of-range heap tops at their actual distance until an in-range socket surfaces (normal pass) or the top's priority already exceeds `RENDER_RANGE + DECO_PRIORITY_PENALTY` (honest priorities ⇒ nothing in range ⇒ cheap idle exit). A single-repair-per-frame version of this drained multi-hundred-socket backlogs over minutes — the area around a player who stopped after a long run stayed bare.
- **Re-seeding**: generation grows as one wavefront from the start tile, so a player teleported beyond frontier+`RENDER_RANGE` would hang over the void with every queued socket permanently out of range. `_ensure_seed_under_player` places a ground tile at the player's grid cell when nothing occupies it (rules pipeline included, so water-field cells become water); it merges seamlessly with the main wavefront.
- **Support sweep**: hills and displaceable decorations whose surface vanished (e.g. the base of a hill stack removed by a bank conversion) have no rule that re-checks them; `_purge_orphaned_stacks` probes their under-origin support every 16th call and removes floaters.
- **Biome fields** (`Helper.biome_forest01` / `biome_rocky01`): two independent low-frequency value noises with smoothstep-carved cores; where both are low the terrain reads as open meadow. They drive two hooks: (1) `Helper.biome_weights(pos, seed)` returns per-tag/per-size sampling multipliers (trees in forests, rocks/hills/cliff-seeds in rocky highlands, grass in meadows) applied by `TerrainGenerator._biome_scaled_dist` to BOTH the socket size roll (`_sample_socket_size`) and the tag roll (`_resolve_placement_context`) — paired entries (`"24x24x4"` ↔ `"cliff-base-side"`, hill sizes ↔ `"hill"`) carry identical multipliers so the two rolls stay consistent; (2) `Helper.biome_foliage_density` scales decoration fill probs (forests dense, meadows open). Continuous fields, not discrete IDs: smooth borders for free, deterministic per seed, infinite-terrain safe. Tags absent from the weights table pass through unchanged, so single-entry structural distributions are unaffected.
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
- **Mid-swap classification gotcha**: while `apply()` runs for a water-position placement, the piece registered in the indices is still the plain-ground instance (the swap to a water tile happens after the rule returns). Any piece classified in the same pass must already see it as water, so `_piece_counts_as_water` treats a `ground-plain` piece sitting on a field-water position as water (a settled ground-plain tile never occupies one — the rule always swaps at placement). Without this, neighbours beside newly generated water kept — or were even downgraded to — wall-less variants, leaving a see-through hole between the land slab and the waterline (regression tests: `tests/test_water_rule.gd`). The cheap exit also consults the field (`_field_water_near`) so banks pre-tile before their water tile generates.
- `WaterTile` rides the ground grid: lateral sockets at ground level keep the frontier flowing across water; its `topcenter` is blocking (0.0) so levels can never cantilever over open water. Solid collision sits at the basin floor; an `Area3D` volume on collision layer 8 marks the water body for swimming.
- **Swimming** (`characters/character.gd`): the character probes the water volume each physics frame (point query at knee height). Control is force-based: horizontal acceleration is low (`SWIM_ACCEL`, capped at `SWIM_SPEED_FACTOR` of run speed) so direction changes carry momentum; vertically, gravity always pulls while buoyancy pushes up in proportion to the submerged fraction of `BODY_HEIGHT` (`BUOYANCY` < gravity fully submerged, so idling sinks slowly), and holding jump adds `SWIM_THRUST` (`jump_held` on `CharacterController`). A body rising out of the water loses buoyancy and falls back in, so bobbing emerges naturally around the equilibrium (~0.59 submerged). Exiting mirrors `_try_step_up`'s forward probe: near the surface with jump pressed/held, a `test_move` along the facing direction within `WATER_EXIT_PROBE` of a bank wall launches the character out. Verified by `tests/harness/swim_harness.tscn` (sink / bob / leap-out phases with screenshots).
- **Nothing sits on banks**: bank `topcenter` is blocking (0.0) and bank foliage sockets are point-only — a level or hill on a bank would hang its untextured base over the waterline. `WaterRule._structures_above` removes any level OR hill above a tile it converts to a bank, searching the full 24x24 footprint (levels are co-located with the tile origin, but hills spawn from edge foliage sockets at offsets — a center-only box misses them). The harness scan reports `STRUCTURE-ON-BANK` violations.
- **Water visuals**: `terrain/water/Water.gdshader` is a Godot 4 port of the ideas in `assets/SeaWaterMaterial` (a Godot 3 asset that cannot be loaded directly): world-space layered waves, depth-tinted transparency, and depth-based animated shore foam via `hint_depth_texture` (depth measured vertically via world-space reconstruction, not along the view ray). `scenes/world.tscn` has a `WorldEnvironment` with a procedural sky so the water has something to reflect.
- **One global water sheet**: all visible water is a single 600×600 camera-following plane (`terrain/water/WaterSurface.tscn`, instanced in `world.tscn`) at y=−1.5, snapped to its 3.0-unit vertex grid so the lattice never slides relative to the world. Per-tile `WaterTile` scenes carry no surface mesh — only the basin floor, solid floor collision, the swim `Area3D`, and sockets. Land slabs (y=0 down to −0.5) occlude the sheet everywhere except inside basins, and beyond the generation frontier it reads as ocean. Per-tile surface planes are gone because adjacent displaced meshes could never line up (mismatched vertex lattices → visible seams).

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
- Each checkpoint also runs `_scan_invariants`, which prints `[scan N] violations=K` plus a line per violation: wrong-tier tiles, stacks without a center/interior support, edge variants whose tag disagrees with their actual neighbours, and base tiles beside placed water whose bank variant doesn't match their water-facing sides (`BANK-WALL-MISMATCH`). A healthy run reports 0 everywhere.
- `godot --headless --path . -s res://tests/harness/debug_level_bank_scan.gd` is a faster headless audit of the same water/bank invariants: it spirals a virtual player through the water belt for 8 seeds and reports `WALL-MISMATCH-PERSISTENT` (placed water beside a wrong variant — a real bug) vs `-PENDING` (field water not yet generated — retiles on arrival). It also prints a `cliff_storeys` histogram per seed — the fastest way to check mountain height/coverage when tuning contour or stacking knobs (healthy: storey 1 in the dozens, storeys 2–4 tapering, no seed at zero).
- `godot --path . res://tests/harness/debug_water.tscn` saves three water close-ups to `/tmp/terrain_shots/dbgwater_N.png` in ~30s — the fast loop for water-look iteration.
- `godot --path . res://tests/harness/teleport_deco_harness.tscn` teleports the character 850u from spawn and prints deco counts near them once per second (plus screenshots) — verifies re-seeding works and decoration density reaches spawn-comparable levels within seconds anywhere in the world.
- **Headless `-s` harness gotcha**: nodes added during `SceneTree._init()` are not in an active tree yet — `global_position` errors and reads back as the ORIGIN, silently pinning the virtual player at (0,0,0) and turning every scripted walk into a no-op (generation becomes a 250u disc around spawn). Harnesses must `await process_frame` before driving generation (see `debug_deco_scan.gd` / `debug_level_bank_scan.gd`).
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
