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

Keep the pipeline pure: the plan, field, mesher, scatter, and dressing classes are plain
`RefCounted` with **no scene-tree access**, which is what makes them headless-unit-testable.
Only `FieldTerrainStreamer` touches the scene tree.

## Terrain pipeline (`scripts/terrain/`)

Data flows: **HeightfieldPlan → HeightfieldRegion → TerrainSurfaceField → TerrainChunkMesher
(+ CliffDressing, DecorationScatter)**, driven per-chunk by **FieldTerrainStreamer**.

- **`heightfield/HeightfieldPlan.gd`** — the deterministic plan. A continuous height field
  `H(cell)` (layered value noise + rocky-biome mountain spines, faded flat near spawn) is
  quantized into integer **storeys** (4 m each) and sub-storey **levels** (0.5 m). A monotone
  trickle-down **clamp** lowers each cell to at most `max_step` storeys above its lowest
  cardinal neighbour (diagonals may drop two — a valid formation). The clamp has a unique,
  order-independent fixpoint, so results are seed-stable. `compute_region()` batches a whole
  chunk's storeys+levels in two clamps and returns a `HeightfieldRegion`. Per-cell noise+carve
  samples are **memoized on the plan instance** (`_sample`, cleared by `set_raw_height_override`/
  `set_water_plan`) so the ~77 %-overlapping windows of successive chunk builds are sampled once
  — a pure-performance cache, output-identical.
  - **Levels are computed but NOT rendered** (`RENDER_LEVELS = false`): the surface is
    flattened to the 4 m storey grid for now (owner wants flat "level-texture" ground, not
    smooth 0.5 m interpolation). The level field is kept for a future flat-terrace feature.
- **`heightfield/HeightfieldRegion.gd`** — precomputed storey/level dictionaries with O(1)
  `storey_at` / `level_at` / `surface_height`. Same read API as the plan.
- **`field/TerrainSurfaceField.gd`** — reconstructs the **continuous walkable height** from a
  region. Cell interiors are flat; a cell **ramps down** toward lower neighbours with a
  `smootherstep` half-cell slope (≤1 storey → walkable grass slope). There is **no up-ramp**:
  a cell never rises to meet a higher neighbour — the higher cell is a flat **cliff top** and
  walls down vertically. Also the classifier for everything downstream: `_is_cliff_top`,
  `has_inner_corner`, `is_flat_cell`, `own_edge_flat`, `is_exposed_edge`, `is_higher_flat`,
  `edge_profile`. Single-valued everywhere ⇒ sampled on a shared grid, adjacent cells/chunks
  share identical boundary vertices ⇒ **gap-free by construction**.
- **`field/TerrainChunkMesher.gd`** — builds one chunk (8×8 cells = 192 m, sampled at 3 m).
  Produces, as children of a chunk `Node3D`: `Surface` (walkable grass mesh, visually clipped
  behind the cliff lips), a separate full-extent **collision** trimesh (the lip band stays
  walkable), `CliffFaces` (vertical **rock skirts** filling the gap under each flat cliff edge,
  double as wall collision), `Aprons` (ground continued under higher neighbours to seal recess
  slits), `Decorations` (foliage **batched into one `MultiMesh` per scene/mesh piece**, like the
  dressing — `compute_decorations()` returns pure `Transform3D` data, `build_chunk` batches it),
  and `Cliffs` (the dressing). Quads are **pinned to their own cell** so cliff tops render flat
  to their boundary; the vertical gap is filled by the skirt. The walkable collision sheet is a
  raw `PackedVector3Array` fed to `ConcavePolygonShape3D.set_faces` (no `SurfaceTool`/trimesh
  cook). Much of this file is edge/lip/corner clip geometry — read the inline comments first.
- **`field/CliffDressing.gd`** — hangs real **KayKit** rock-wall + beveled grass-lip + inner/
  outer/step/junction **corner** pieces on cliff edges, batched into one `MultiMesh` per piece
  type per chunk. Visual only; the mesh skirt is the collision. `compute()` returns plain
  `Transform3D` arrays (unit-testable headless); `build()` turns them into nodes. Pieces snap to
  the **old-tile 10.5 grid** (3 m KayKit modules at ±1.5…±10.5, corners at ±10.5,±10.5).
- **`field/DecorationScatter.gd`** — pure per-cell deterministic foliage scatter (returns data,
  no scene access). Density and tag mix come from biome fields in `Helper`.
- **`field/FieldTerrainStreamer.gd`** — the only scene-tree node (`Node3D` in `world.tscn`,
  wired to the player). Builds field chunks within `CHUNK_RADIUS` of the player on **one
  background worker thread** (the whole pipeline is scene-free `RefCounted`, so `build_chunk`
  runs off-thread as-is and returns a detached `Node3D`); the main thread only **integrates**
  finished chunks (`add_child`), `MAX_BUILD_PER_FRAME` per frame, nearest-first, evicting beyond
  `KEEP_RADIUS`. The worker exclusively owns its `_plan`/`_water`/`_mesher` instances, so their
  caches need no locks; the player's own chunk is still built **synchronously** when missing (on
  separate `_sync` pipeline instances — same seed ⇒ identical output) so the player never falls
  through unstreamed space, and the cold river-trace spike moves off the main thread with the
  rest. Owns the `world_seed` (random per run) and the tuning exports: `HEIGHTFIELD_AMPLITUDE`,
  `HEIGHTFIELD_MAX_STOREYS`, `MAX_CLIFF_STEP` (1 = all slopes, 3 = cliffs up to 12 m).

## Shared fields & utilities (`scripts/core/`)

- **`Helper.gd`** — deterministic, infinite-terrain-safe noise fields, all pure functions of
  `(pos, world_seed)`: `macro_density01`, biome fields `biome_forest01` / `biome_rocky01` /
  `biome_foliage_density` / `biome_weights`, the water field `is_water`, value-noise
  (`_value_noise01`), and hashing helpers (`_cell_hash01`, splitmix64 `_mix64`). Also
  transform/AABB/collision helpers. `HeightfieldPlan._height01` samples these for landform shape.
  (Some doc comments here still name the retired `TerrainGenerator` — ignore those references.)
- **`Distribution.gd` / `TagList.gd` / `PriorityQueue.gd`** — small generic helpers.

## Terrain tools & water

- **`terrain/tools/CoordOverlay.gd`** — the F3 debug HUD (in `world.tscn`): a crosshair plus a
  readout of the seed, the player's cell, the crosshair-target cell, and the 3×3 storey grid
  around it. A screenshot alone then pins down exactly where a terrain issue is — use it to
  reproduce a reported bug by its seed and coordinates.
- **`terrain/tools/SlopeProfile.gd` / `SlopeAtlas.gd`** — the `smootherstep` slope profile math
  and grass/rock UV sampling from KayKit pieces, shared by the field and mesher.
- **Water** (`scripts/terrain/water/`): a deterministic **river network carved into the
  heightfield** — `WaterPlan` (sources on a super-grid, downhill traces locked to the fall
  line on steep ground, terminal `PondStamp` bowls; carve applied inside
  `HeightfieldPlan.raw_height`). Beds obey **containment** (`CONTAIN_DROP`): every bed is
  capped a full storey below the lowest flanking bank's natural storey, so channels always
  quantize bounded by ground on both sides — never a sheet hanging off a hillside.
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
    from a **hydrostatic fill**: seeds placed in channels and ponds spread outward only
    DOWNHILL-OR-LEVEL over connected ground sitting below the seed's own level (never
    uphill), with the LOWER level winning wherever two spreads meet, rasterized on a 6m
    world-space lattice with a 30m margin around each chunk — so the waterline follows a
    real terrain contour instead of stopping at a fixed claim radius. Pure and deterministic
    — no rendering, no nodes.
  - `WaterContour` — waterline → smooth, chunk-welded G1 polylines. Six-step pipeline:
    presence grid → per-edge crossing refinement → chain into polylines → two Chaikin
    passes + uniform 1.5m resample → clip to rect LAST → per-point level/normal/wall
    attributes from the curve's own frame. Clipping LAST (after smoothing) is what makes
    the chunk weld: two neighbouring chunks both smooth the SAME margin-grown polyline
    before either clips it, so they land on bit-identical border-crossing points. SADDLE
    cells (marching-squares' standard ambiguous case: two diagonally-opposite corners wet)
    are resolved by sampling the field at the cell's own CENTRE (world-grid-aligned, so
    neighbouring chunks agree) rather than falling through a generic two-crossing path that
    used to silently drop the diagonal wedge (r3 Task 15). CLOSED curves resample by EVEN
    DIVISION of the circumference (`cnt = round(circ/spacing)` equal arcs, no remainder)
    instead of a fixed-spacing walk that left an arbitrary leftover segment.
  - `WaterSkin` — the ONE mesh builder (the old marching-squares mesher is retired, r3 Task
    7; its own boundary was raw ~45-90° grid corners). Welds a 3m world-aligned interior
    lattice to a boundary strip that sits directly ON `WaterContour`'s curves (zip-stitched
    via nearest-curve ring ownership — narrow-channel safe), plus a **meniscus rim** that
    curls the strip's own outer edge: it OVERSHOOTS into banks that genuinely rise within
    reach of the waterline (water laps flush to the shore, never a gap) and BURIES itself
    under drops (clamped to landing ground, so it can never float a film over a dip) — every
    free edge is accounted for (a chunk border, or the rim's own buried outer row), so no
    edge is ever left hanging in mid-air over the terrain. Per-vertex CUSTOM0 bakes `(s, d,
    slope, shore_dist)` — arc length / signed cross-channel distance / continuous profile
    slope along the nearest river trace, plus shore distance — and vertex normals are real
    (heightfield-derived interior, rim-curl frame on the meniscus), not a blanket up vector.
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
  `WaterSurfaceBuilder` is a thin adapter: `build_chunk` calls `WaterSkin.build`/`commit`
  and emits one `Area3D` swim trigger per `triggers` entry (never more than one per tile —
  the steep gate above means a tile either has one trigger or none), each carrying
  `set_meta("sampler", sampler)` so a probe anywhere inside reads its exact water height
  from that one shared, chunk-frozen sampler instead of a per-cell plane. It also still owns
  the shared `ShaderMaterial` and the river-trace `surface_profile`/`steepness_profile`
  helpers.
  `water_unified.gdshader` is the ONLY water shader and renders still, flowing, AND falling
  water from the one baked `steep` attribute × depth — no separate waterfall shader or
  swept mesh exists, the falling look is a blend on the one sheet material. Motion has two
  independent carriers (r3 Task 13, owner rewrite): mesh **geometry** displaces ONLY with
  the travelling **pond swell spectrum** (`water_waves.gdshaderinc::water_wave_h`,
  CPU-mirrored in `character.gd::_swell_offset` for buoyancy rocking, everywhere — river
  reaches included, keep constants in sync); ALL river/rapids motion instead comes from a
  fragment-side **two-phase morphing refraction-distortion** advection
  (`water_distort_wobble`) that perturbs the refraction offset only — never vertex height,
  never albedo, never the lighting normal. The old geometric river trains (vertex-displaced
  wave trains riding the CUSTOM0 flow frame) are DELETED — they aliased the 3m mesh lattice
  below Nyquist into a maze/moiré pattern the owner rejected. **ZERO albedo whitening
  anywhere** (the owner's hardest rule): no foam mask, no steep wash, no streak scroll, no
  plunge whitening. Clarity comes from `sky_reflect` (0.5 → 0.3, r3 round-6): the higher
  value washed a milky pale-sky sheen over the body at grazing angles and hid the bed; 0.3
  lets the refracted, depth-tinted bed read through while keeping a soft SoS-style
  reflection. Plus `WaterRippleSim` (SubViewport wave sim: swim wakes, entry splashes,
  ambient raindrop rings). Plunge mist (particle spray at fall landings) is currently
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
  true. The **swell** (`_swell_offset`, pond spectrum only — the river-term mirror was
  deleted alongside the shader's own geometric river trains, r3 Task 13) feeds ONLY
  `water_surface_y`, the float-height buoyancy chases — NEVER the depth gate: letting the
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
  buoyancy proportional to submerged fraction fights gravity (idle sinks slowly), holding jump
  adds thrust, and pressing toward a nearby bank wall launches the character out. Verified by
  `tests/harness/swim_harness.tscn`.
- **`scripts/controllers/`** — a pluggable `CharacterController` resource: `PlayerController`
  (keyboard, camera-relative) and `TestController` (steers toward a target node, for harnesses).
- **`scripts/camera/camera.gd`** — orbit camera (Q/E orbit, scroll zoom) following the character.

## Conventions & code style

- **Typed GDScript.** Annotate function signatures, exported vars, and members. Inline `:=`
  type inference is used freely for locals — match the surrounding code.
- **Purity boundary.** Terrain computation (plan / field / mesher / scatter / dressing) stays
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
  `test_cliff_dressing`, `test_decoration_scatter`, `test_field_streamer`, `test_biomes`,
  `test_helper`, and the `test_slope_*` profile/geometry guards. Continuity guards
  (`test_slope_tile_continuity`, `test_diag_seams`, `test_slope_socket_grounding`) assert the
  surface is gap-free and decorations sit on the mesh — the invariants above, encoded.
- **`tests/harness/`** — visual/screenshot scenes for eyeballing behavior a unit test can't
  (`heightfield_shot.tscn`, `hf_shapes.tscn`, `swim_harness.tscn`, `teleport_deco_harness.tscn`,
  `debug_water.tscn`, …).

## Adding terrain content

- **New foliage look**: wrap the KayKit gltf under `terrain/gltf/<kind>/`, make a
  `terrain/scenes/<kind>/<Name>.tscn`, and add its path to the matching list in
  `TerrainChunkMesher.FOLIAGE_SCENES`. Tag mix/weights live in `DecorationScatter.TAG_WEIGHTS`.
- **Different cliff dressing**: swap the KayKit scene paths in `CliffDressing.SCENES` (they must
  tile on the 3 m / 10.5 grid — mismatched module widths leave slits at the corners).
- **Tuning terrain shape**: `FieldTerrainStreamer` exports (amplitude, storey cap, cliff step,
  radii), `HeightfieldPlan` constants (`STOREY_HEIGHT`, `LEVELS_PER_STOREY`, aggregation), and
  `Helper` field scales (`MACRO_SCALE`, biome/water scales).

## Before finishing

- **Run the tests** (`godot-test`) and fix regressions before considering a change done. For
  anything visual, also open a relevant `tests/harness/` scene (or the game) and look.
- If you rename/move a `class_name` script, run the `--import` step above.

## Historical docs (stale — do not follow as current)

These predate or partially describe the retired socket engine and are kept only for history:
`terrain/TERRAIN_README.md`, `docs/known-issues/*`, most of `docs/future-work/*`, the older
`docs/superpowers/plans|specs/*`, and `docs/superpowers/terrain-status-2026-06-24.md`. When they
conflict with the code, the code and this file win. The living design reference is
`docs/mythosunwritten-master-design.md`.
