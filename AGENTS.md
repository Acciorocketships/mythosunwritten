# Project Instructions (AGENTS.md)

> Keep this file current. When the architecture, conventions, or core invariants
> change, update it in the same change.

## What this project is

**MythosUnwritten** (Godot project name "Story"; repo `Acciorocketships/mythosunwritten`).
An open-ended, turn-based fantasy RPG conceived as an LLM-driven **world simulator** —
every non-player character and the world itself are meant to be agent-driven, with
narrative emerging rather than scripted. See **`docs/mythosunwritten-master-design.md`**
for the full vision; that document is the design north star.

- **Engine/language**: Godot 4.5, typed GDScript.
- **What exists today**: an infinite procedural terrain world plus a controllable,
  physics-driven character (walk, jump, step-up, swim) with an orbit camera. The RPG /
  combat / agent layers in the master design are not built yet.

## Quick commands

- **Run the game (windowed)**: `godot --path /Users/ryko/story`
  The terrain streams forever around the player, so a run does **not** self-exit — stop
  it with Ctrl-C / closing the window. For automated verification prefer the tests and
  the harness scenes below over a bare headless run.
- **Run all tests (GUT)**: `godot-test` (a shell alias for
  `godot -d --path /Users/ryko/story -s res://addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json`).
  Tests live in `tests/`, are named `test_*.gd`, and `extends GutTest`.
- **After moving/renaming a `class_name` script**: run
  `godot --headless --path /Users/ryko/story --import` once so Godot rebuilds the global
  script class cache; otherwise headless runs fail with "Could not find type X".
- **Profile terrain generation**: `godot --headless --path /Users/ryko/story -s res://tests/harness/profile_terrain.gd`
  prints per-phase build timings (49-chunk startup sweep + phase attribution). Paste the summary
  into perf-related commit messages.

## The core invariant: field-driven, deterministic, churn-free

Terrain is a **pure function of `(world_seed, cell)`**. A cell's final height is decided
before any geometry is instantiated, so tiles never retile, morph, or pop as neighbours
stream in. This is the whole point of the current architecture — it replaced an older
socket / module-catalog engine that grew terrain reactively and needed reveal margins and
churn suppression to hide the settling. **That socket engine is gone.** If you find docs
referring to `TerrainGenerator`, `TerrainModule*`, sockets, `WaterRule`, `PositionIndex`,
or generation "rules", they describe the retired system (see "Historical docs" below).

Keep the worker pipeline pure: plan, field, mesher/dressing `compute*` methods return
plain CPU-side data and are headless-unit-testable. Render/physics resources and nodes are
created only by the explicit main-thread `commit*` adapters; only `FieldTerrainStreamer`
attaches those nodes to the active scene tree. Never create `MeshInstance3D`, `MultiMesh`,
`ArrayMesh`, collision shapes, or other server-backed resources in the streamer worker.

## Terrain pipeline (`scripts/terrain/`)

Data flows: **HeightfieldPlan → HeightfieldRegion → TerrainSurfaceField → TerrainChunkMesher**,
with sibling **WaterSkin** and **DressingField** payloads, driven per-chunk by
**FieldTerrainStreamer**.

- **`heightfield/HeightfieldPlan.gd`** — the deterministic plan. A continuous height field
  `H(cell)` (layered value noise + rocky-biome mountain spines, faded flat near spawn) is
  quantized into integer **storeys** (4 m each) and sub-storey **levels** (1 m). A monotone
  trickle-down **clamp** lowers each cell to at most `max_step` storeys above its lowest
  cardinal neighbour (diagonals may drop two — a valid formation). The clamp has a unique,
  order-independent fixpoint, so results are seed-stable. `compute_region()` batches a whole
  chunk's storeys+levels in two clamps and returns a `HeightfieldRegion`. Per-cell noise+carve
  samples are **memoized on the plan instance** (`_sample`, cleared by `set_raw_height_override`/
  `set_water_plan`) so the ~77 %-overlapping windows of successive chunk builds are sampled once —
  a pure-performance cache, output-identical. Settlement and village layout never feed this plan:
  the natural heightfield has no village stamp or settlement mutation hook.
  - **Levels are rendered** (`RENDER_LEVELS = true`): adjacent same-storey cells may differ
    by one 1 m level, and that short step uses the same shared smootherstep surface patch as
    a 4 m storey slope. Levels do not emit cliff dressing or vertical backing walls.
- **`heightfield/HeightfieldRegion.gd`** — precomputed storey/level dictionaries with O(1)
  `storey_at` / `level_at` / `surface_height`. Same read API as the plan.
- **`field/TerrainSurfaceField.gd`** — reconstructs the **continuous walkable height** from a
  region. Each non-cliff cell quadrant is a smootherstep patch through four shared controls:
  its centre, the pairwise-minimum height at each adjoining edge midpoint, and the four-cell
  minimum at the corner. Both owners of an ordinary storey/level seam therefore compute the
  exact same boundary curve, including T-junctions where one neighbour slopes in a transverse
  direction. There is **no up-ramp**: a cell never rises to meet a higher neighbour — the
  higher cell is a flat **cliff top** and walls down vertically. Deliberate cliff/inner-corner
  discontinuities are filled by the mesher's rock skirts. Also the classifier for everything downstream: `_is_cliff_top`,
  `has_inner_corner`, `is_flat_cell`, `own_edge_flat`, `is_exposed_edge`, `is_higher_flat`,
  `edge_profile`. Ordinary slopes are single-valued on the shared grid, and adjacent chunks
  sample the same controls ⇒ **gap-free by construction** without miniature level walls.
- **`field/TerrainChunkMesher.gd`** — builds one chunk (8×8 cells = 192 m, sampled at 3 m).
  `compute_chunk()` produces CPU-side mesh arrays, collision faces, and cliff placement data on
  the worker; `commit_chunk()` turns that payload into the chunk
  `Node3D` on the main thread. Its children are `Surface` (walkable grass mesh, visually clipped
  behind the cliff lips), a separate full-extent **collision** trimesh (the lip band stays
  walkable), `CliffFaces` (vertical **rock skirts** filling the gap under each flat cliff edge,
  double as wall collision), `Aprons` (ground continued under higher neighbours to seal recess
  slits), and `Cliffs` (the fixed cliff dressing). Ambient environment dressing is intentionally
  not part of the terrain payload. Quads are **pinned to their own cell** so cliff tops render flat
  to their boundary; the vertical gap is filled by the skirt. Classic inner-corner sheet points
  tuck below the rounded piece; any part of that tuck exposed by a low camera uses the same rock
  atlas texel as the wall, never bright grass. The walkable collision sheet is a
  raw `PackedVector3Array` fed to `ConcavePolygonShape3D.set_faces` (no `SurfaceTool`/trimesh
  cook). Much of this file is edge/lip/corner clip geometry — read the inline comments first.
- **`field/CliffDressing.gd`** — hangs real **KayKit** rock-wall + beveled grass-lip + inner/
  outer/step/junction **corner** pieces on cliff edges, batched into one `MultiMesh` per piece
  type per chunk. Visual only; the mesh skirt is the collision. `compute()` returns plain
  `Transform3D` arrays (unit-testable headless); `build()` turns them into nodes. Pieces snap to
  the **old-tile 10.5 grid** (3 m KayKit modules at ±1.5…±10.5, corners at ±10.5,±10.5).
- **`dressing/DressingField.gd`** — the pure deterministic ambient-nature field. Sets author
  direct per-biome fill rates, then shared `DressingHabitatLayer` fields form correlated groves,
  clearings, ecotones, rock exposures, and small colonies with true negative space. Optional
  jittered-Voronoi community fields keep nearby visual choices related instead of confetti-like.
  A separate world-wide `DressingEcology.land_occupancy01` mask is multiplied into every
  ground population, so broad clearings and the connected edges of a jittered-Voronoi graph form
  paths that no independent set can sprinkle back into. Mushrooms deliberately use a dense
  colony set plus a rare singleton set. Reeds are `EMERGENT` content: wet, inside the shoreline,
  and never scattered over dry land.
  Final jittered anchors are qualified against terrain and the shared `WaterFieldContext`, then
  bounded Matérn-II arbitration supplies local and cross-population spacing. Chunk ownership is
  half-open, so overlapping queries agree and seams cannot duplicate or omit an anchor. Worker
  payloads contain only asset IDs, transforms, and colours. `EnvironmentCollisionBuilder` commits
  baked static physics for structural nature before chunk readiness; `EnvironmentCommitQueue`
  creates one visual `MultiMesh` per `(asset_id, visual piece)` under a separate per-frame budget,
  and discards stale chunk generations. Dressing still owns no gameplay identity, interaction,
  persistence, navigation, or world-feature planning.
- **Paths and man-made features** (`scripts/terrain/features/`) — pure `SettlementPlan` owns only
  deterministic 768m future-village site identities and cells; it has no terrain API. `PathPlan`
  validates those sites against the untouched final fields, then owns canonical dry-landing bridge
  sites, monotone bounded route
  solves, local backbone/loop selection, and bridge/arch/lamp identities. `PathProgram` compiles
  the five selectively warmed assets and their primitive placement metrics; it contains no
  resources. `PathContext` is the immutable per-block projection: centred 4 m corridor masks,
  16 m-diameter circular village plazas, signed reservation clearance, and one half-open-owned
  `EnvironmentInstancePayload`. Future-village nodes validate a compact dry, supported footprint;
  their circular path surface provides a gathering place without mutating terrain.
  Its hot predicates use the same connection masks plus a local
  reservation bucket, so terrain UV and dressing queries are O(1) in route length; lattice callers
  pass their already-known terrain cell to avoid repeating coordinate division. Each perpendicular
  arm pair adds a bounded quarter-annulus fillet, so both inner and outer path edges curve through
  turns and branches without a circle stamped over the junction. Path
  triangles keep the original tan; sparse varied-size world-hashed circular decals use one
  slightly darker tan from the same atlas island. The circles conform to the sheet and share its
  mesh, material, and draw call; exposed aprons use the base path tan. Bridges are
  exact-water-validated before becoming atomic route macro-edges; ordinary routes use cheap
  planning water, then validate only the selected corridor against exact water. Every ordinary
  route edge uses `TerrainSurfaceField.is_walkable_edge`, so a hill may be climbed over the same
  continuous sub-storey/storey slopes the mesher renders, but a route can never cut through an
  exposed cliff face. Existing cliffs beside an approach remain natural and optional; no shelf,
  ridge, cutting, or flanking cliff is manufactured for a village. Lamps face inward over the road.
  Large arches walk every accepted route from both village endpoints: the first attempt is centred
  84 m from the node, later segments supply bounded support fallback, and shared segments deduplicate
  while routes that split early each retain a gate. Small arches mark refined dominant-biome
  crossings, stay at least 144 m from a village and 96 m from another arch, so ecotone oscillation
  cannot make a gate stack. Precedence is
  bridge → village gate → biome gate → lamp. Stable feature
  IDs never include a streaming chunk or contributing route.
- **`field/WorldFieldBlockCache.gd`** — the worker-confined canonical owner of independently lazy
  terrain regions and exact water contexts. Half-open 192 m keys and deterministic bounded LRU
  make planning, meshing, water, and dressing share the same live field objects without locks or
  output dependence on query order. `TerrainSurfaceField.is_walkable_edge` is likewise the one
  symmetric exposed-boundary fact shared by path traversal and the rendered mesh.
- **Environment assets** (`scripts/terrain/environment/`, `terrain/environment/`) — source-pack
  scenes are editor-baked into lightweight descriptors plus self-contained meshes, materials,
  textures, typed visual pieces, and optional typed collision pieces. Manifest scale is applied
  exactly once at bake time: KayKit retains its legacy wrapper scales and LPFV nature uses a 3.25×
  pack correction. Reviewed KayKit primitives are preserved from bake-only collision templates
  where they fit: the owner's original three-cylinder proxy remains on KayKit rock 1, while
  rock 2's oversized sphere is replaced by a mesh-derived flat-topped hull. KayKit trees 2 and 4
  are intentionally absent from the catalogue.
  LPFV rigid assets normally use one snag-free primitive per disconnected hard component. Trees use
  a rotated capsule around only the grounded lower trunk, fitted from true mesh cross-sections so
  sparse/leaning low-poly vertices cannot pull it off-centre. The strongly curved LPFV tree 2 uses
  an explicit four-capsule chain instead: short capsules follow successive cross-sections and
  adjacent capsule axis endpoints are the exact same point, making their hemispherical caps
  concentric at each rounded joint; one global chord can no longer protrude from the bend. Logs use
  flat-ended rotated cylinders, the
  fallen branch uses a rotated capsule, stumps use flat-topped cylinders, and rocks use an inset
  box or a convex hull whose top is flattened into a face. Multi-rock source clusters declare their
  hard-component count in the manifest, so each visible stone receives its own disjoint hull rather
  than one collider bridging the empty space between them. Decorative foliage and mushrooms never
  enlarge physics. This deliberately avoids overlapping compound-shape lips, point-topped walkable
  objects, and collision that bridges empty space. Low rocks tagged `walkover` cap their collision
  height so their largest authored dressing scale remains below the character's step height; a
  catalogue test couples those values and prevents later tuning from breaking traversal. Assets
  tagged `tree`, `rock`, or `deadwood` are rejected by
  the bake unless they declare collision, so rigid dressing cannot silently become non-blocking.
  Runtime consumers use
  stable asset IDs through the
  lightweight `EnvironmentCatalog`; the main-thread `EnvironmentRenderCache` selectively loads
  only active visuals. Environment runtime resources never depend on the source packs under
  `assets/`. `tools/environment_bake/` is the only owner of those source paths. Generated palette
  variants may selectively recolour foliage texels. The Fantasy Village man-made feature pack uses
  a reviewed 2× human-scale bake correction for its freestanding arches and lamp. A manifest
  fallback supplies the orange atlas missing from the second large arch's source material, so the
  correction is baked into the self-contained runtime asset. Its bridge
  retains the independently calibrated `[1.2, 1.0, 6.0]` vector scale that supplies a human-scale
  deck and rails plus the required crossing span. Large arches use compound collision following
  four posts, upper beams, diagonal braces, and both roof slopes; the character-height opening
  stays clear while collision reaches the visual top and depth.
  Every active material still multiplies
  the independent per-instance biome tint. `terrain/materials/forest.tres` is a self-contained
  bake-compatibility path for Godot's imported KayKit scene UID, not a runtime material owner.
- **`field/FieldTerrainStreamer.gd`** — the only scene-tree node (`Node3D` in `world.tscn`,
  wired to the player). Builds field chunks within `CHUNK_RADIUS` of the player on **one
  background worker thread**. It compiles dressing plus `PathProgram` and selectively warms their
  sorted asset union on the main thread before starting the worker. The worker returns only
  arrays/transforms/sampler payloads. Terrain and feature generations are independent, but queued
  requests for one block widen into one job. A completed terrain payload waits in one nearest-first
  list until every key in its footprint-derived feature halo is ready; v1's maximum footprint
  yields exactly the lexicographically sorted 3×3 square. Empty feature blocks are explicit ready
  records and allocate no node/resource. Non-empty feature collision commits under the one
  `ManmadeFeatures` root before readiness, with visuals independently budgeted. Terrain then
  commits in terrain → water → dressing collision → `add_child` → FX → dressing visual order,
  `MAX_BUILD_PER_FRAME` per frame, nearest-first, evicting beyond
  `KEEP_RADIUS` (features use `KEEP_RADIUS + feature_halo`). The worker exclusively owns its
  `_settlements`/`_plan`/`_water`/field/path/mesher instances, so their
  caches need no locks. At startup the player is frozen until every chunk beneath their footprint
  (four quadrants at the origin corner) and its feature square is ready; later, a missing current
  chunk freezes them during teleports or when outrunning the worker. Collision therefore cannot
  pop in after movement starts, and the cold river/path spike stays off the main thread. Owns the
  `world_seed` (random per run) and the tuning exports: `HEIGHTFIELD_AMPLITUDE`,
  `HEIGHTFIELD_MAX_STOREYS`, `MAX_CLIFF_STEP` (1 = all slopes, 3 = cliffs up to 12 m).

## Shared fields & utilities (`scripts/core/`)

- **`Helper.gd`** — deterministic, infinite-terrain-safe noise fields, all pure functions of
  `(pos, world_seed)`: `macro_density01`, biome fields `biome_forest01` / `biome_rocky01` /
  `biome_foliage_density` / `biome_weights5`, value-noise
  (`_value_noise01`), and hashing helpers (`_cell_hash01`, splitmix64 `_mix64`). Also
  transform/AABB/collision helpers. `HeightfieldPlan._height01` samples these for landform shape.
  (Some doc comments here still name the retired `TerrainGenerator` — ignore those references.)
- **`Distribution.gd` / `TagList.gd` / `PriorityQueue.gd`** — small generic helpers.

## Terrain tools & water

- **`terrain/tools/CoordOverlay.gd`** — the F3 debug HUD (in `world.tscn`): a crosshair plus a
  readout of the seed, the player's cell, the crosshair-target cell, and the 3×3 storey grid
  around it. A screenshot alone then pins down exactly where a terrain issue is — use it to
  reproduce a reported bug by its seed and coordinates. Storeys come from immutable snapshots
  attached to committed chunks; the main-thread HUD never reads the worker-owned plan or caches.
- **`terrain/tools/SlopeProfile.gd` / `SlopeAtlas.gd`** — the `smootherstep` slope profile math
  and grass/rock UV sampling from KayKit pieces, shared by the field and mesher.
- **Water** (`scripts/terrain/water/`): a deterministic **river network carved into the
  heightfield** — `WaterPlan` (sources on a super-grid, downhill traces locked to the fall
  line on steep ground, terminal `PondStamp` bowls; carve applied inside
  `HeightfieldPlan.raw_height`). Channel carving projects each terrain sample onto the same
  variable-width trace **segment capsule** used by `WaterField` (not isolated trace-point
  discs), so bathymetry cannot leave uncarved 12m gaps beneath continuous rendered water.
  `WaterPlan.planning_signed_distance` / `planning_intervals` expose that same source geometry
  with one fixed guard for cheap route planning; they never build hydrostatic water.
  `WaterFieldContext.wet_intervals` is the exact, lazily contour-cached counterpart for final
  route and bridge validation, so feature consumers never reproduce water geometry.
  Beds obey **containment** (`CONTAIN_DROP`): every bed is
  capped a full storey below the lowest flanking bank's natural storey, so channels always
  quantize bounded by ground on both sides — never a sheet hanging off a hillside. The
  hydraulic trace bed and rendered bathymetry are intentionally separate: ordinary reaches
  excavate another `CARVE_BED_EXTRA` below the trace bed so 4m storey quantization cannot
  leave only centimetres of cover, while reaches whose trace-bed grade is already a fall face
  keep the original shallow carve (never turn a vertical film into a deep swim volume).
  Pure data flows `WaterField → WaterContour → WaterSkin`, turned into nodes by
  `WaterSurfaceBuilder`; one shader renders it all:
  - `WaterField` — the continuous water surface as ONE height field `level_at(x,z)`, with
    **no cuts anywhere**: `profile()` is a single monotone, continuous curve per river.
    Ordinary reaches ride a smooth trend between anchors or hug a nearby steep face
    (unchanged in spirit); but a genuine multi-segment descent — several storeys down a
    real slope — is instead reshaped as ONE smooth **sill-riding envelope**: monotone C1
    cubic-Hermite, knots at the two span anchors plus any sill the naive curve would
    otherwise duck under, fit THROUGH the knots rather than clamped-then-corrected — so the
    water rides OVER intervening terrain instead of staircasing down it (the owner's
    round-4 reversal of run-2's terrain-hugging descent). Every floor-pinned point sits at
    `ground + DESCENT_CLAMP` (0.10m), a UNIFORM floor that must strictly clear the
    hydrostatic fill's own wetness epsilon `EPS` (0.05m) — at `DESCENT_CLAMP == EPS` the
    fill dries the exact band the envelope shaped to keep wet (r3 Task 12b). `steep_spans()`
    separately reports where the RENDERED terrain (not the level curve) drops more than
    `FALL_DROP_MIN` == 4m inside a 24m sliding window — purely a shader/mesh attribute bake,
    never geometry-forking. Static wetness beyond the channel/pond seeds themselves comes
    from a **hydrostatic fill**: river seeds are variable-width **segment capsules** whose
    levels interpolate at each lattice point's own longitudinal projection (not overlapping
    constant-level sample discs, which rebuilt terraces after the smooth profile); those
    flowing-channel lattice values are authoritative against a lower downstream flood. Seeds
    placed in channels and ponds spread outward only
    DOWNHILL-OR-LEVEL over connected ground sitting below the seed's own level (never
    uphill), with the LOWER level winning wherever two spreads meet. Those flood labels decide
    the deterministic **wet mask**, not the final flowing surface: five fixed Jacobi passes,
    anchored by the continuous river profile, relax the wet labels across river/pond joins so a
    lower flood cannot leave a one-cell sideways water cliff. The pass radius is 30m inside a
    42m chunk margin, preserving bit-identical overlap between chunks. The canonical surface stays
    on a 6m world-space lattice; mixed coarse cells seed a sparse, topology-only 3m rescue where
    real terrain exposes a submerged passage between dry 6m endpoints. The rescue walks only
    downhill-or-level through points the coarse continuous field calls dry, lower level still wins,
    and untouched samples remain bit-identical to the 6m field. Across a mixed wet/dry lattice
    cell the field interpolates **signed depth**: dry corners contribute a small negative
    depth, capped so a high bank never pulls the surface uphill. Water therefore thins to
    zero depth on a contour inside the cell instead of ending as a square fill-grid edge —
    the field source of the rounded/blob-like shoreline. Pure and deterministic — no
    rendering, no nodes.
  - `WaterContour` — waterline → smooth, chunk-welded G1 polylines. Six-step pipeline:
    presence grid → per-edge crossing refinement → chain into polylines → two Chaikin
    passes + uniform 1.5m resample → clip to rect LAST → per-point level/normal/wall
    attributes from the curve's own frame. One dry-side orientation is chosen for the whole
    G1 curve, so a zero-gradient saddle cannot reverse adjacent outward normals and fold the
    rim into a bow tie. Wall detection probes that outward normal plus ±45° corner guards, so
    a tangent that bisects two cliff faces cannot look through their diagonal notch and
    misclassify the corner as a gentle blob shore; a 1–3-sample gap bracketed
    by real walls is closed only when their normals form a turn. Clipping LAST (after smoothing) is what makes
    the chunk weld: two neighbouring chunks both smooth the SAME margin-grown polyline
    before either clips it, so they land on bit-identical border-crossing points. SADDLE
    cells (marching-squares' standard ambiguous case: two diagonally-opposite corners wet)
    are resolved by sampling the field at the cell's own CENTRE (world-grid-aligned, so
    neighbouring chunks agree) rather than falling through a generic two-crossing path that
    used to silently drop the diagonal wedge (r3 Task 15). CLOSED curves resample by EVEN
    DIVISION of the circumference (`cnt = round(circ/spacing)` equal arcs, no remainder)
    instead of a fixed-spacing walk that left an arbitrary leftover segment.
  - `WaterCurrentField` — pure deterministic horizontal current constraints. `WaterSkin`
    seeds a world-aligned 3m lattice from downstream trace tangents; width/depth provide a
    readable base current even on flat reaches (about 2.3m/s at the pinned representative
    reach, clamped 1.4–6.5m/s) and grade only adds speed. A finite two-cell
    signed-distance bank field zeros dry samples and removes bank-entering velocity, then
    finite differences derive vorticity and compression for turning packets and generated
    foam. Production chunks solve with a two-cell halo, so adjacent chunks bake bit-identical
    retained border values. The velocity/diagnostics live in mesh `CUSTOM1` and the frozen
    `WaterSampler`; GPU and CPU consumers never reconstruct separate flow fields.
  - `WaterForces` — pure, scene-free force laws shared by water consumers: displaced-column
    buoyancy, horizontal drag toward `WaterSampler.velocity_at()`, and vertical water drag.
    Bodies keep their own volume-to-mass/drag tuning and integration adapter; never copy a
    separate approximation of the current or character-only buoyancy math into future props.
  - `WaterSkin` — the ONE mesh builder (the old marching-squares mesher is retired, r3 Task
    7; its own boundary was raw ~45-90° grid corners). Welds a 2m world-aligned render
    lattice to a boundary strip that sits directly ON `WaterContour`'s curves (zip-stitched
    via nearest-curve ring ownership — narrow-channel safe), plus a **meniscus rim** that
    curls the strip's own outer edge. Rising banks receive a compact overshoot; a wall-flagged
    point reaches the KayKit wall's true 1.5m recess (`TILE/2 - CliffDressing.PLACE`) only when
    its own outward column confirms high ground there. A short sustained-high witness handles
    diagonal cliff arms that leave the normal column before the long probe. Because contour
    smoothing can move the visual curve inside the final signed-depth wet region, every column
    first stays level through its initial continuous wet run; this closes inner-corner and saddle
    gaps without bridging a dry cliff arm to water on its far side. A confirmed wall column then
    measures any remaining contact distance,
    then stays at water level through the 1.5m recess and another 0.3m behind the visible face before
    curling down. Adjacent confirmed columns whose wall normals turn use the intersection of their
    wall tangents as a bounded miter, so their outer edge follows the actual L-shaped cliff corner
    instead of cutting it off with a diagonal chord. The visible surface therefore meets rounded
    cliff corners flat instead of using the lower curl to fill them. That direct-contact
    gate stops a flanking wall from stretching a genuinely unbounded edge into a skirt. Free/drop
    edges instead form a finite convex lobe: a +4cm crest followed by -6/-28/-55/-65cm rows over
    only 0.64m, with monotonically outward/downward-turning tangents. Every
    free edge is accounted for (a chunk border, a bank-buried outer row, or that compact lobe),
    so no zero-thickness plane ends sharply in open air. The first rim row also advances
    outward (no vertical repair-skirt seam). Open contours may border several disconnected
    interior-lattice rings where a narrow channel falls below the render grid; the boundary zipper
    splits those into local components and partitions the contour among them instead of joining
    them with non-local fan triangles. Remaining over-scale faces are adaptively subdivided, and
    only tiny local closed surface holes are triangulated. Per-vertex CUSTOM0 bakes `(s, d,
    slope, shore_dist)` — arc length / signed cross-channel distance / continuous profile
    slope along the nearest river trace, plus shore distance. `CUSTOM1` bakes `(velocity.x,
    velocity.z, vorticity, compression)` from the shared `WaterCurrentField`. Vertex normals are real
    (heightfield-derived interior, rim-curl frame on the meniscus), not a blanket up vector.
    `ARRAY_COLOR.r` bakes a displacement scale from BOTH shore distance and actual static
    bed clearance; it covers the ambient spectrum plus packet-field trough bound. The shader,
    `WaterSampler.wave_scale_at()`, and character buoyancy use the same scale, so dynamic
    geometry cannot uncover a shallow bed while the CPU float height claims otherwise.
    `WaterSkin.build()` also returns `triggers`: one box per 24m wet tile, footprint from
    the mesh's own built vertices. r3 Task 12b RETIRED the whole-tile/sub-tile level-SPREAD
    suppression Tasks 7/9 had layered on top (`_tile_level_spread`,
    `TRIGGER_LEVEL_SPREAD_MAX`, `TRIGGER_SUB_TILE_SPREAD_MAX`) once the phantom-depth class
    it guarded against was proven dead by construction under the smooth descent envelope —
    triggers are simple wet-tile coverage again. `STEEP_UNSWIMMABLE` stays: a tile whose own
    max grade exceeds it gets **no trigger at all** — a steep fall face is not swimmable
    water, so a character falls/slides through it rather than floats. A single frozen
    `WaterSampler` snapshot of the water FIELD across the chunk (full wet footprint,
    shoreline band included; NaN only where the field itself says dry) backs every trigger
    for swim-depth queries.
  `WaterSurfaceBuilder` is a thin adapter: worker-safe `compute_chunk` calls `WaterSkin.build`;
  main-thread `commit_chunk` calls `WaterSkin.commit` and emits one `Area3D` swim trigger per
  `triggers` entry (never more than one per tile —
  the steep gate above means a tile either has one trigger or none), each carrying
  `set_meta("sampler", sampler)` so a probe anywhere inside reads its exact water height
  from that one shared, chunk-frozen sampler instead of a per-cell plane. The sampler freezes
  the field's native 6m fill lattice, sparse 3m topology rescue, and required terrain-height twins,
  then applies the identical dual-resolution signed-depth shoreline evaluation; do not resample
  levels through the render mesh grid, which
  double-interpolates steep shorelines and can turn dry/wade probes into false swimming. It also still owns
  the shared `ShaderMaterial` and the river-trace `surface_profile`/`steepness_profile`
  helpers.
  `water_unified.gdshader` is the ONLY water shader and renders the whole continuous network;
  no river/pond material fork or separate swept waterfall mesh exists. Its one
  `water_dynamic_height()` combines the slow ambient spectrum, persistent compact asymmetric
  wavelets, and interactive ripple height. Both vertex and fragment stages sample that SAME
  height: it displaces the 2m mesh and derives normals, refraction, curvature caustics, and
  reflection tilt, so a moving feature cannot become a detached albedo scroll. The old
  repeated river trains and fragment-only `water_distort_wobble` are deleted. Water is
  spectrally manual-composited: Beer–Lambert transmission
  (`absorption=(0.003,0.001,0.0005)`) stays in `EMISSION` because the refracted scene is
  already lit, while the real displaced normal uses Godot's PBR specular response. That split
  keeps the bottom dominant without losing the old clear swim-ripple highlight. Weak depth
  scattering and a broad Fresnel sky sheen supply the remaining body read. A short screen-space reflection
  ray march was actively rejected in the exact review view because its finite hit iterations
  formed concentric far-bank bands. White is legal only from generated energy:
  packet breaking or local flow compression. Swim/entry/ambient ripple impulses stay clear;
  their narrow height gradients refract and reflect the sky, and there is no foam/streak texture.
  `WaterRippleSim` owns two player-centred GPU fields. Its ping-pong wave equation carries
  swim wakes, entry splashes, and ambient clear rings; semi-Lagrangian backtracing advects it
  through a 32×32 current texture over the restored 96m interaction domain. Its second pass
  rasterizes at most 16 persistent world-space Morlet-style wavelets (compact, Gaussian-
  windowed 6–10m oscillating crests, not closed blur bubbles or repeated trains). Their CPU
  centres/lifetimes/directions/phases are transported through the same
  `WaterSampler.velocity_at()` field and turn with the shared vorticity as that field bends.
  The packet height is
  CPU-mirrored to character buoyancy. Plunge mist (particle spray at fall landings) is currently
  unwired — a follow-up; the shared particle resources it needs are no longer warmed on
  startup. `tests/tools/water_review_spots.gd` emits F4 review teleports
  (`ReviewTeleporter.gd` reads `review_teleports.json` and lifts the player onto streamed
  ground if a stale spot height would bury them).
  **Character depth gate** (`characters/character.gd`): classification is **static-field
  depth**, full stop — `depth = sampler.level_at(xz) - global_position.y`, read from the
  overlapping trigger's frozen `WaterSampler` snapshot (the knee-height probe only finds
  which triggers overlap; it plays no part in the depth number itself). Swim and wade are
  each hysteretic against that static number — swim ENTER at depth > 0.8m, EXIT at < 0.6m;
  wade ENTER at depth > 0.05m, EXIT at < 0.03m — so a reading sitting right on one boundary
  can't dither the state every frame. `wading = in_water or (deepest static depth clears the
  wade gate)` (since h-task-4): swimming is a DEEPER case of being in water at all, so a
  swimming character always reads wading too — never independently false while `in_water` is
  true. The **dynamic height** (ambient `_swell_offset` plus `WaterRippleSim`'s exact CPU
  packet mirror) feeds ONLY `water_surface_y`, the float-height buoyancy chase — NEVER the depth gate: letting the
  swell's own crest nudge the gate used to be able to latch a false swim state on a single
  crest-timed frame at a knife-edge shoreline depth, which is why classification reads the
  static field alone.
- **One tint field**: every terrain surface — walkable sheet, aprons, rock skirt, and all
  KayKit dressing pieces (per-instance colours) — multiplies THE shared material by
  `BiomeRegistry.blended_ground_tint` sampled at its own position. Change the palette or
  a biome tint once and every surface follows; never give a surface its own colour.

## Character & camera

- **`characters/character.gd`** (`CharacterBody3D`) — movement (accel / friction / turn),
  `_try_step_up` (climb ≤ `MAX_STEP_HEIGHT` ledges), jump, and **force-based swimming**: water
  tiles expose an `Area3D` on collision layer 8; while a knee-height probe is inside it,
  `WaterForces` supplies buoyancy proportional to submerged fraction and enough full-submersion
  lift for a stable passive float. Horizontal drag carries the character toward the exact
  `WaterSampler` current while player steering remains relative to that moving water. Holding
  jump adds thrust, and pressing toward a nearby bank wall launches the character out. Verified
  by `tests/harness/swim_harness.tscn`.
- **`scripts/controllers/`** — a pluggable `CharacterController` resource: `PlayerController`
  (keyboard, camera-relative) and `TestController` (steers toward a target node, for harnesses).
- **`scripts/camera/camera.gd`** — orbit camera (Q/E orbit, scroll zoom) following the character.

## Startup loading screen

- **`ui/loading_screens/mythos_loading_screen.tscn`** is the project main scene. It loads
  `world.tscn` on Godot's threaded resource loader, installs the live world behind a high
  `CanvasLayer`, and keeps its animated atlas visible until `FieldTerrainStreamer` reports
  every chunk under the player's startup footprint integrated. The origin is a four-chunk
  corner. Startup progress is real weighted work: threaded scene-resource loading, worker
  PathContext/feature/heightfield/mesh/water/dressing milestones for those support jobs and
  their required feature halo, then main-thread integration. Never replace it with elapsed-time
  progress. `MythosLoadingScreen.gd` owns the handoff,
  `MythosTaperedProgressBar.gd` draws the hairline/tapered fill, and
  `mythos_loading_screen.gdshader` composites transparent city/cloud/chart textures from
  `ui/loading_screens/layers/` over the genuinely cloud-free
  `mythos_mythic_atlas_background_cloudless.png` plate; never restore the older plate's static
  corner-cloud duplicates. Only the chart texture rotates; four cloud groups translate
  independently. The stationary river is the actual original atlas painting, with a second atlas
  sample travelling downstream along a hand-fitted river spine for most of each cycle and
  cross-fading only at wrap; both are clipped to its local width. The title/progress Control
  remain outside every rotation.

## Conventions & code style

- **Typed GDScript.** Annotate function signatures, exported vars, and members. Inline `:=`
  type inference is used freely for locals — match the surrounding code.
- **Purity boundary.** Terrain computation (plan / field / mesher / dressing) stays
  scene-free and deterministic so it can be unit-tested headless. Push scene-tree work into the
  streamer or scene glue.
- **Simplify — the owner strongly prefers root-cause re-architecture over band-aids.** If the
  same logic appears in several places, consolidate it. If you're adding retries, attempt loops,
  or a special case for "only when tag/config X", step back and redesign so the normal path just
  works. Prefer shorter code. (This is why the socket engine was replaced wholesale rather than
  patched.)

## Tests & harnesses (`tests/`)

- Unit tests mirror the pipeline: `test_heightfield_plan`, `test_heightfield_region`,
  `test_heightfield_clamp_step`, `test_terrain_surface_field`, `test_terrain_chunk_mesher`,
  `test_cliff_dressing`, `test_dressing_field`, `test_dressing_ecology`,
  `test_dressing_collision_builder`, `test_dressing_commit_queue`,
  `test_environment_catalog`, `test_water_field_context`, `test_field_streamer`, `test_biomes`,
  `test_helper`, `test_world_field_block_cache`, `test_water_path_queries`, `test_settlement_plan`, `test_path_program`,
  `test_path_plan_nodes`, `test_path_bridge_sites`, `test_path_route_solver`,
  `test_path_context`, `test_path_features`, and the `test_slope_*` profile/geometry guards. Continuity guards
  (`test_slope_tile_continuity`, `test_diag_seams`, `test_slope_socket_grounding`) assert the
  surface is gap-free and dressing sits on the mesh — the invariants above, encoded.
- **`tests/harness/`** — visual/screenshot scenes for eyeballing behavior a unit test can't
  (`heightfield_shot.tscn`, `hf_shapes.tscn`, `swim_harness.tscn`,
  `environment_lineup.tscn`, `teleport_deco_harness.tscn`, `debug_water.tscn`, …). The lineup
  pages the full generated catalogue with stable IDs, provenance, measured AABBs, a one-metre
  scale marker, and optional collision overlays (`--show-collision`). The teleport harness streams
  a fixed nine-chunk site through the real world pipeline, requires structural collision, and
  waits for both terrain integration and the independent dressing commit queue before capturing it.
  `path_review.tscn` renders straight/L/T/X/logical-node masks through the real terrain mesher beside the
  rejected offset-width alternative; `path_corpus.gd` is the deterministic smoke/full path gate.

## Adding terrain content

- **New environment visual**: add a stable-ID entry to the relevant manifest under
  `tools/environment_bake/manifests/`, including its canonical bake scale and either
  `collision_source`, a supported `collision_profile`, or intentionally neither. `tree`, `rock`,
  and `deadwood` tags require collision by construction. Prefer one close-fitting simple shape:
  `trunk_capsule` for a straight grounded lower trunk or `trunk_capsule_chain` for a reviewed
  curved trunk. A forked or root-heavy silhouette can explicitly provide
  `collision_joint_points_m` and `collision_segment_radii_m` in corrected asset-local metres,
  keeping asset-specific art direction in the manifest rather than the generic baker.
  Use `oriented_cylinder` for a log,
  `stump_cylinder` for a flat cut, `flat_box`/`flat_rock` for a walkable rock, and set
  `collision_component_count` when one source visual contains several disconnected stones; use
  `collision_max_height` plus the `walkover` tag for a low obstacle that must remain below the
  character step at every active population scale; use `oriented_capsule` for a branch. Use
  `collision_source` only for reviewed authored primitives.
  Run the bake tool and review every rigid asset beside its mesh in
  `environment_lineup.tscn -- --show-collision`; a proxy must not stray materially outside the
  mesh or collapse to an unusably thin line. Never add a runtime wrapper scene or a source-pack
  path.
- **New ambient population or variant**: author a `DressingSet`/`DressingChoice` under
  `terrain/dressing/` and add it to `terrain/dressing/index.tres`. The set owns direct per-biome
  fill and may share habitat/community channels with related sets; visual choices affect mix,
  never population. Structural sets must share the appropriate spacing group so their collision
  cannot overlap. The compiler derives proposal slots and margins and rejects illegal
  water/support/radius combinations. Author `feature_clearance` explicitly (`2.0` m for rigid
  structure, `0.3` m for small ground cover, `0.0` for floating lilies); the compiler rejects a
  margin outside `PathProgram`'s saturated clearance coverage.
- **New man-made path feature**: add its self-contained visual/collision through the environment
  manifest, then add only primitive footprint/support/opening semantics to `PathProgram`. Keep the
  decision inside `PathPlan` after final route-mask merge, add its footprint to the shared
  reservation union, derive its stable ID from the canonical world site, and let the existing
  environment payload/builder/queue and derived feature halo handle streaming. Do not add a
  sibling planner, scene wrapper, feature-specific streamer dependency list, or alternate water/
  terrain classifier. Review paths in `tests/harness/path_review.tscn`, assets in
  `environment_lineup.tscn -- --show-collision`, and deterministic statistics with
  `tests/harness/path_corpus.gd`.
- **Different cliff dressing**: change the stable asset IDs in `CliffDressing.ASSETS` (pieces
  must tile on the 3 m / 10.5 grid — mismatched module widths leave slits at the corners).
- **Tuning terrain shape**: `FieldTerrainStreamer` exports (amplitude, storey cap, cliff step,
  radii), `HeightfieldPlan` constants (`STOREY_HEIGHT`, `LEVELS_PER_STOREY`, aggregation), and
  `Helper` field scales (`MACRO_SCALE`, biome/water scales).

## Before finishing

- **Run the tests** (`godot-test`) and fix regressions before considering a change done. For
  anything visual, also open a relevant `tests/harness/` scene (or the game) and look.
- **For a reported visual defect, use red-first TDD plus active falsification.** Pin the exact
  seed/world coordinates and camera pose, write the smallest failing invariant before the fix,
  then rerun it green. When an F3 screenshot supplies `player world` + `crosshair world`, use
  `ReviewCam.solve_cam`/`ReviewCam.shoot`; never substitute a hand-authored camera transform.
  Capture the same-angle before/after view and deliberately
  try to prove the defect still exists: inspect alternate times/nearby angles, paired animation
  frames, seams, and likely collateral regressions. Reject a change if the unit test passes but
  the matched render exposes the original problem or a new artifact. Keep a deterministic
  self-driving harness for recurring review sites; `tests/harness/water_reported_qa.tscn` is the
  water example and accepts `-- --spot <name>` for a focused run.
- If you rename/move a `class_name` script, run the `--import` step above.

## Historical docs (stale — do not follow as current)

These predate or partially describe the retired socket engine and are kept only for history:
`terrain/TERRAIN_README.md`, `docs/known-issues/*`, most of `docs/future-work/*`, the older
`docs/superpowers/plans|specs/*`, and `docs/superpowers/terrain-status-2026-06-24.md`. When they
conflict with the code, the code and this file win. The living design reference is
`docs/mythosunwritten-master-design.md`.
