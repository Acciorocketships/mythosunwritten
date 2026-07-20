# GrassField — Animated Ground-Cover Carpet — Design Spec

**Date:** 2026-07-17
**Status:** Final design; implementation reference.
**Scope:** The deferred dense-grass system from the 2026-07-16 environment/dressing spec: a lush,
wind-animated, player-trampled grass carpet with biome-specific coverage and clearings. Visual
only. This spec supersedes nothing in the dressing spec; it fills the slot that spec deferred
("Dynamic, dense, interactive, or LOD-specialized grass, including LPFV `Grass_01–07` placement").

---

## 1. Decisions (locked during brainstorm)

| Question | Decision |
|---|---|
| Look & reach | Lush carpet: ~2+ tufts/m² near the player so ground is mostly hidden in grassy areas; full density to ~60 m, zero by ~144 m; terrain ground tint hides the fade edge |
| Mesh source | Bake LPFV `Grass_01–05` scaled down through the existing LPFV nature manifest; skip 574–922-tri `Grass_06/07`. Each tile uses one full variant selected from `01–03` (7–8 leaves) and one sparse variant selected from `04–05` (3–4 leaves), so all five silhouettes appear across the world with at most two batches per tile |
| Trampling | Player stamps now; API takes any actor later; nothing reads trample state back — purely visual |
| Old KayKit grass | Retire the `ambient_grass` dressing set once the carpet lands |
| Architecture | `FieldTerrainStreamer` remains the one worker, scheduler, and scene-tree attachment owner. A pure `GrassField` computes 24 m-tile payloads; a main-thread-only `GrassStreamer` service owns grass ring/render state. At most two MultiMeshes per tile; all motion in one vertex shader |

Rejected alternatives: extending `DressingField` to carpet density (strains its sparse proposal
and spacing model; 192 m batches are too coarse for distance LOD), giving grass a second worker
(duplicates the expensive height/water caches and cannot guarantee terrain-first priority), and
GPU-driven placement (duplicates height/biome/clearing field ownership into GPU textures;
weakens determinism and QA). The placement contract stays independent of rendering so a GPU path
remains a possible future swap.

---

## 2. Invariants

Inherited from the terrain/dressing architecture and binding here:

- **Deterministic:** placement is a pure function of `(world_seed, grass_seed_version, tile,
  slot_index)` plus world-position fields. No chunk/tile request order, worker timing, wall
  clock, or enumeration order participates.
- **Window-independent:** a tile's buffer is identical no matter when or from where it is
  requested. There is no cross-instance interaction (no spacing arbitration), so this holds
  trivially; field stencils are the only margin.
- **Visual-only:** no collision, navigation, occupancy, gameplay state, or persistence. Trample
  state is render-side deformation input; nothing queries it back.
- **Pure worker boundary:** the worker owns the field contexts it reads and returns packed
  arrays. Meshes, materials, textures, RIDs, and all RenderingServer work stay on the main
  thread (including the known `--headless` read-back deadlock rule).
- **One field owner per fact:** ground from `TerrainSurfaceField`, water/shore from
  `WaterFieldContext`, biome weights/tint from the biome fields, construction-level clearings and
  paths from `DressingEcology.land_occupancy01`, and canopy correlation from
  `DressingEcology.habitat01` using the existing `woodland_canopy` channel at 132 m. Grass
  reconstructs none of them and cannot grow back into shared negative space.
- **Self-contained assets:** grass visuals go through `environment_bake`; runtime never touches
  `assets/LowPolyFantasyVillage/**`.

---

## 3. Components

```text
scripts/terrain/grass/
  GrassField.gd        # pure worker placement -> packed buffers
  GrassProgram.gd      # immutable compiled worker data
  GrassPayload.gd      # typed CPU-only worker result
  GrassStreamer.gd     # main-thread service: ring, commits, LOD, wind globals
  GrassSettings.gd     # authored Resource schema (validated at startup)
  TrampleField.gd      # world-anchored deformation window + stamp API

terrain/grass/
  settings.tres        # the single authored GrassSettings
  grass.gdshader       # one shader: sway + gusts + trample + fade + tint

terrain/environment/…  # baked lpfv.grass.01–05 via the normal catalogue layout
tools/environment_bake/manifests/low_poly_fantasy_village_nature.json
```

- **`GrassField`** — static pure function:
  `compute(program, world_seed: int, tile: Vector2i, region: HeightfieldRegion,
  water: WaterFieldContext) -> GrassPayload`. `GrassPayload` contains one packed MultiMesh buffer
  and count per selected asset; it owns no resources or nodes.
- **`GrassStreamer`** — main-thread-only `RefCounted` service owned by `FieldTerrainStreamer`. It
  maintains the desired tile set, reports missing tiles, builds committed tile nodes under a
  budget, updates `visible_instance_count`, evicts with hysteresis, and owns the namespaced wind
  and LOD shader globals. It owns no thread, never reads `_plan`/`_water`, and never calls
  `add_child`; `FieldTerrainStreamer` remains the only scene-tree attachment owner.
- **`FieldTerrainStreamer` integration** — its existing queue becomes a typed queue with terrain
  and grass jobs. One lexicographic priority key keeps startup useful without risking the player:
  `(0)` the player's missing terrain chunk, `(1)` missing terrain chunks whose AABB intersects the
  desired grass circle, `(2)` desired grass tiles whose containing terrain is committed, `(3)` all
  remaining terrain chunks; jobs are nearest-first within a tier. New tier-0/1 work jumps ahead
  immediately when the player moves, so grass can never delay required ground, while grass also
  does not starve behind the entire distant 49-chunk terrain ring. The worker remains the exclusive
  owner of `_plan`, `_water`, and their caches. A grass tile is queued only after its containing
  192 m terrain chunk is committed, so grass never gates terrain readiness or appears over missing
  ground. `HeightfieldRegion` and `WaterFieldContext` never cross to the main thread: both retain
  back-pointers into worker-owned plan/water data. Instead the worker keeps a bounded 16-entry LRU
  cache keyed by the containing 192 m terrain chunk. Terrain jobs populate it; grass jobs carry
  only the parent chunk coordinate and reuse or deterministically rebuild a cache miss. Contexts
  use the maximum margin and shore-distance limit required by dressing or grass. The cache stays
  worker-only and cannot grow with world travel.
- **`TrampleField`** — main-thread node created and attached by `FieldTerrainStreamer`, owning the
  trample texture window, an exported player reference, and the public
  `stamp(world_pos, dir, radius, strength)` and
  `stamp_segment(from, to, radius, strength)` APIs. It observes the player's actual post-physics
  position/velocity itself; the character and controller layers remain untouched. Creatures/NPCs
  can call either API later.

A compiled program mirrors the dressing pattern: `GrassSettings` (a `Resource`) is validated and
flattened at startup into a worker-safe `GrassProgram` containing only value data (numbers,
packed arrays, sorted `StringName`s, `Transform3D`s, and `AABB`s). The authored schema is
deliberately small:

- `grass_seed_version: int`;
- `coverage_by_biome: Dictionary` with exactly `BiomeRegistry.biome_ids()`;
- `full_variant_asset_ids: Array[StringName]` (`lpfv.grass.01–03`, sorted at compile time);
- `sparse_variant_asset_ids: Array[StringName]` (`lpfv.grass.04–05`, sorted at compile time);
- ordered finite `scale_range` and `brightness_range`;
- finite non-negative `max_grade` and `shore_clearance`.

Validation requires `grass_seed_version >= 1`, coverage values in `[0, 1]`, positive scale,
non-negative brightness, disjoint non-empty variant groups, and known self-contained assets with
instance-colour support, exactly one visual piece, and no collisions. Each grass piece must be
upright with uniform scale and zero XZ origin offset; only its vertical base correction may
translate the instance origin. The compiler copies the piece transform, descriptor AABB, mesh-local
base/height, and albedo texture metadata into the program/render setup; the worker composes bake
scale/pivot once without loading a resource. Channel names and scales are engine-owned
constants, not authored strings; this removes an unnecessary registry and prevents grass from
silently drifting away from the established clearing/canopy fields.

---

## 4. Placement (worker, deterministic)

**Lattice.** Grass tile = 24 m (`TerrainChunkMesher.TILE`). Each tile has a stratified 48×48
slot grid (0.5 m pitch, 2 304 slots, 4/m² ceiling). Per slot, stable hashes with named-purpose
salts produce: jitter X/Z within the cell, eligibility roll, yaw, scale, full/sparse class choice,
sway phase, brightness, and a temporary dropout-order key. Separate tile-purpose salts select one
full asset and one sparse asset for the tile. Changing one concern's salt cannot reshuffle the
others.
Identity is `(world_seed, grass_seed_version, tile, slot_index)`; `grass_seed_version` bumps
only for a deliberate full reshuffle.

**Coverage.** All terms are evaluated at the jittered anchor. The exact formula is:

```text
weights         = Helper.biome_weights5(p, world_seed)
biome_base      = dot(weights, program.coverage_by_biome)
canopy_field    = DressingEcology.habitat01(
                    p, world_seed,
                    DressingCompiler.stable_id_hash(&"woodland_canopy"), 132.0)
canopy_coverage = dot_in_BiomeRegistry_order(
                    weights, [0.22, 0.82, 0.14, 0.72, 0.42])
canopy_opening  = DressingEcology.suitability(
                    canopy_field, canopy_coverage, EXTERIOR, 0.11)
coverage        = clamp(biome_base
                    * DressingEcology.land_occupancy01(p, world_seed)
                    * canopy_opening, 0, 1)
```

- `biome_base` is the dot product of `Helper.biome_weights5(p, world_seed)` with the authored
  per-biome coverage dictionary. Defaults: meadow 0.65, deep_forest 0.50, highland 0.25,
  blossom_grove 0.55, twilight_marsh 0.35.
- `land_occupancy01` is the existing shared broad-clearing and path exclusion. It is
  construction-level: zero means no ground population, including grass, may reappear there.
- `canopy_opening` is the exact habitat layer retired with `ambient_grass`, including its
  canonical channel, scale, blended biome coverage, `EXTERIOR` preference, and softness. Moving
  those fixed values here preserves bit-identical ecological agreement without inventing a
  second configurable channel system.

A slot exists iff `coverage(anchor) > eligibility_roll`. Density is therefore directly
proportional to coverage — clearings are simply regions where coverage approaches zero, and
their edges thin out gradually over the channel's edge softness.

**Qualification** (all at the jittered anchor):

- context: `water.covers(anchor)` must be true (a violated query contract is an assertion, not a
  placement rejection);
- dry land: `not water.is_wet(anchor)` and
  `water.shore_distance_at(anchor) ≥ program.shore_clearance` (default 0.3 m);
- grade: the same centred 1 m finite-difference stencil as `DressingField` must be
  `≤ program.max_grade`; this removes anchors beside a discontinuous cliff edge;
- `Y = TerrainSurfaceField.surface_y(anchor)`.

**Variant, pose, and appearance.** Two tile hashes choose one asset uniformly from the sorted full
group (`01–03`) and one from the sorted sparse group (`04–05`). A separate per-slot class roll
chooses full or sparse with equal probability. Thus a tile creates at most two batches, while all
five silhouettes appear in deterministic 24 m neighbourhoods rather than five confetti-like draw
streams in every tile. The 50/50 class split preserves the fuller 7–8-leaf clumps without making
every anchor pay their triangle cost.

Tufts stay world-upright: random yaw and uniform scale in 0.85–1.2.
Instance `COLOR` = `BiomeRegistry.blended_ground_tint(weights)` × brightness jitter
(0.94–1.06). The carpet therefore colour-blends across biome transitions exactly like the
terrain. The worker writes
`placement_transform * compiled_piece_local_transform`, applying the baked correction exactly
once. The piece contract keeps its XZ origin at the placement anchor.

**No arbitration.** At carpet density overlap is desirable; the Matérn spacing machinery is
deliberately absent. The only query margin beyond the tile is the fields' own fixed stencils
(grade/derivative sampling and the water context halo).

**Exact dropout ordering and output.** For each of the tile's two selected assets, candidates are
sorted by `(dropout_order_key, slot_index)`. Only after sorting, candidate `i` receives
`dropout_rank = float(i) / float(count)`. The packed custom data is
`CUSTOM0 = (sway_phase, dropout_rank, sin(final_yaw), cos(final_yaw))`, where `final_yaw` includes
the allowed fixed piece yaw. The random key chooses a stable spatial
order; the exposed normalized rank is exact, unique, and evenly spaced. Consequently the first
`ceil(count × d)` entries are precisely every entry whose rank is `< d`—not merely that many in
expectation.

`GrassPayload` stores at most two selected-asset batches. Each contains one `PackedFloat32Array` already in
Godot's MultiMesh layout (`TRANSFORM_3D` + colour + custom data interleaved), its instance count,
and the pure CPU-computed union of the descriptor AABB under all placement transforms. The main
thread commits each MultiMesh with one `buffer` assignment—no per-instance calls and no buffer
parsing to recover bounds.

---

## 5. Streaming, rendering, LOD

**Ring.** Define `distance_to_tile(player_xz, tile)` as the Euclidean distance from the player to
the nearest point of the tile's closed 24 m AABB. The desired set contains every tile where that
distance is `< GRASS_RADIUS = 144 m` (about 132–141 tiles depending on grid phase). Using tile
intersection rather than tile-centre distance is load-bearing: an omitted tile can otherwise cut
a visible square hole as much as 17 m inside the radial fade. Missing tiles are requested
nearest-first within their worker tier; a tile is evicted when its nearest-point distance exceeds
`GRASS_RADIUS + 24 m`. Commits are budgeted by elapsed main-thread time with a starting budget of
0.5 ms/frame; the current tile finishes, then no new tile begins after the budget is exhausted.
Every queued result carries `(tile, generation)`; stale generations are dropped.

**Batches.** One `MultiMeshInstance3D` per non-empty `(tile, selected class asset)`: at most two
batches per tile. Each uses colours and custom data, disables shadow casting, and receives the
grass shader as `material_override`; the compiled asset metadata supplies the albedo texture bound
to that shader. The shared per-asset material stores the mesh-local base and height used by the
bend profile.

The custom AABB starts with the payload's static union—each placement transform applied to the
already bake-corrected descriptor AABB—then is inflated from that batch's maximum scaled tuft
height by the allowed idle, gust, trample, and arc bend ratios plus a small safety epsilon. It
therefore contains the tile's actual terrain-height band and every shader deformation; a flat tile
box is invalid on elevated or sloped ground. `GrassStreamer` defines those maximum ratios and
clamps runtime wind globals to them, so tuning cannot silently invalidate an already committed
AABB.

The honest construction maximum at default meadow coverage and no clearing is roughly 200–212 k
committed instances across the conservative ring. The conservative CPU caps below submit at most
about 115 k of them in that worst spatial case. With an equal full/sparse class split, the selected
82–184-triangle sources average about 134 triangles per instance, or roughly 15–16 M submitted
triangles before frustum rejection; expected
ecological occupancy is lower, but is not a correctness or budgeting assumption. Five non-empty
source assets are warmed, but only two are selected per tile, implying at most ~282 resident
batches before frustum culling. These are measurements to
validate, not claims of comfort. The first fallback, only if the GPU gate fails, is a separately
specified far-mesh/variant reduction; do not pre-build a second LOD path.

**Distance density.** `density(d) = 1` inside 60 m, smoothstep to 0 at 144 m.

`GrassStreamer` samples the player's XZ once per frame into `grass_lod_origin`, uses that exact
value for every CPU tile calculation, and publishes it as a global shader parameter. LOD never
uses `CAMERA_POSITION_WORLD`: orbiting or zooming the camera must not move the density field or
invalidate the CPU cap.

- CPU, per frame: `visible_instance_count = ceil(count × density(distance_to_tile))`. Because
  nearest-point distance gives the maximum density anywhere in the tile, this cap is conservative:
  together with normalized ranks, it never removes an instance the shader might show.
- Shader, per instance: compute `d = density(distance(instance_anchor.xz, grass_lod_origin))` and
  `scale *= smoothstep(rank, min(rank + 0.15, 1.0), d)`. An instance is non-zero only when
  `rank < d`, so the conservative CPU cap is exact; the 0.15 interval dissolves each instance as
  density falls, while `d == 1` still renders every instance at full scale.

---

## 6. Wind — idle sway and rolling gusts

Global shader parameters (initialized and updated by `GrassStreamer`, added to `project.godot`):
`wind_direction: vec2`, `wind_idle_bend: float`, `wind_gust_texture: sampler2D` (seamless
low-frequency `NoiseTexture2D`), `wind_gust_scale: float` (~100 m), `wind_gust_speed: float`
(~8 m/s), `wind_gust_bend: float`. Bend values are dimensionless fractions of tuft height, so one
shader works across every baked and random instance scale. Names remain subsystem-neutral so
future tree/water consumers can reuse them; extracting a separate `WindState` before there is a
second owner is unnecessary.

Vertex shader, with
`h = clamp((VERTEX.y − local_base_y) / local_height, 0, 1)` and bend weight `w = h²`.
`local_base_y` and `local_height` come from the baked mesh's own local AABB and are set once on the
shared per-variant material. Do not use descriptor/world height here: bake and random scale live in
the instance transform, while `VERTEX` is still mesh-local.

All deformation remains mesh-local and height-relative. `CUSTOM0.zw` stores the sine/cosine of the
final instance yaw after the compiled piece transform is composed. The shader rotates world-space
wind/trample directions into local XZ with that pair, then offsets by `local_height × bend_ratio ×
w`. The instance transform naturally applies the baked and random scale once. This avoids a
per-vertex matrix inverse and makes every deformation bound a simple multiple of actual tuft
height.

1. **Idle sway** — small elliptical offset `sin(TIME · f + phase)` per instance (phase from
   `CUSTOM0.x`), amplitude `local_height · wind_idle_bend · w`, biased along the local-space
   form of `wind_direction`.
2. **Gust wave** — `n = texture(wind_gust_texture, (world_xz − wind_direction · TIME ·
   wind_gust_speed) / wind_gust_scale).r`, shaped by `g = smoothstep(0.45, 0.85, n)` into
   sparse travelling fronts. Displacement is `local_height · g · wind_gust_bend · w` along
   the local wind direction; `g` also scales idle-sway amplitude. Because the noise field itself
   translates across the world,
   contiguous blobs sweep through the meadow and grass bows in visible waves — the rolling-gust
   effect. A small, faster second octave adds flutter.
3. **Arc correction** — tips drop by a bounded fraction of `local_height` derived from the total
   bend ratio, so blades arc instead of stretching.

---

## 7. Trampling

**State.** `TrampleField` owns a 256² `FORMAT_RGBAH` `Image`/`ImageTexture` covering a 64 m
world-anchored window (0.25 m/texel) centred near the player: `RG` = bend direction (±1 encoded
0–1), `B` = strength, `A` = stamp timestamp against a rolling epoch. Because every grass material
reads the same window, these are namespaced global shader parameters rather than five duplicated
material updates: `grass_trample_texture`, `grass_trample_origin: vec2`,
`grass_trample_size: float`, `grass_trample_epoch: float`.

- **Scrolling:** the window origin is texel-snapped; when the player moves > 8 m from centre,
  the image blit-shifts and newly exposed border texels clear. World-anchored means trails stay
  exactly where they were made while inside the window.
- **Epoch:** timestamps are seconds since a rolling epoch, rebased every 60 s (one full-image
  rewrite subtracting the delta). At 15 min a half float resolves time in roughly half-second
  steps, visibly coarse against a 7 s recovery; a one-minute epoch keeps the step below a tenth
  of a second. Negative timestamps after rebase are legal.
- **Uploads:** CPU stamps mark the image dirty. One render upload coalesces all changes and occurs
  at most 30 Hz; scroll/rebase may force the next scheduled upload but never create a second upload
  in the same frame. A standing actor refreshes its hold stamp every ~2 s.

**Stamping.** In `_process`, after the physics step, `TrampleField` observes the exported player's
actual current/previous XZ positions, `velocity`, and `is_on_floor()` state. It passes the grounded
foot segment through its own public API; `character.gd` and every controller remain unchanged. The
field rasterizes along that segment at no more than 0.25 m spacing, so a fast actor cannot leave
gaps even though uploads are capped. Each stamp uses the normalized actual horizontal
displacement, radius 0.45 m, and
`strength = clamp(actual_speed / TRAMPLE_FULL_SPEED, 0.4, 1.0)`, where the field owns the tuning
constant and defaults it to the player's walk speed. A nearly still grounded actor reuses its last
direction at the low hold cadence. Future actors call the same API directly.

For each touched texel, first evaluate the stored stamp's current effective strength using the
same recovery function as the shader. Then set:

```text
direction = normalize(old_direction * old_effective + new_direction * new_strength)
B         = max(old_effective, new_strength)
A         = now
```

If the direction sum is zero, use `new_direction`. This exact merge rule is deterministic;
re-walking a fading trail re-flattens it.

**Recovery — entirely in-shader.** `flatten = B × (1 − ease_in(t))` with
`t = clamp((now − A) / 7 s, 0, 1)` and `ease_in(t) = t²` — recovery progress starts slow, so
grass lingers flat and then rises. No per-frame CPU decay pass, no viewport feedback loop.

**Deformation.** Every vertex samples the same coordinate, the tuft's MultiMesh origin
(`MODEL_MATRIX[3].xz`), so a tuft bends as a unit. The shader rotates the stored world direction
into local XZ using `CUSTOM0.zw`, displaces by `local_height · flatten · w · TRAMPLE_BEND`, and
lowers by `local_height · flatten · w · TRAMPLE_DROP`. Both constants are ratios bounded by the
custom AABB contract. Slight per-instance-phase perpendicular splay keeps a trail from looking
uniform, and wind response is multiplied by `(1 − flatten)` — crushed grass does not sway. Outside
the window the sample contributes zero.

**Stretch polish (not required for done):** radial-outward stamp ring on jump landings.

---

## 8. Assets and material

Append LPFV `Grass_01–05` to the existing
`tools/environment_bake/manifests/low_poly_fantasy_village_nature.json`; do not create a second
manifest for the same source pack, because provenance is pack-keyed. Each entry uses a scale
targeting a 15–30 cm descriptor-measured standing height (verified against the 1 m marker in the
catalogue lineup), a grounded base pivot, normal provenance, and asset IDs
`lpfv.grass.01`–`lpfv.grass.05`. The ordinary bake path remains unchanged. `GrassProgram`
compilation and its tests enforce the grass-specific descriptor contract: exactly one visual
piece, zero collision pieces, finite bounds, one albedo texture, a positive uniform scale with no
tilt, and zero XZ origin offset. A fixed yaw and vertical base correction are allowed. Failing an
assumption is a startup validation error, not a bake branch or runtime special case.

Grass introduces its own material family: `grass.gdshader` handles the validated baked albedo
texture, mesh/instance `COLOR` multiply, distance dropout, wind, and trample deformation. There is
one shared `ShaderMaterial` per asset across all tiles; its only asset-specific values are the
compiled albedo texture and mesh-local `local_base_y`/`local_height`. The shader uses
`render_mode cull_disabled` because all five source meshes are double-sided leaf cards.
`GrassStreamer` creates and warms these materials before the terrain worker starts. Optional
tuning knob: blend normals toward world-up so the carpet shades more like the ground.

---

## 9. Retirement

When the carpet lands (Phase 5):

- remove `ambient_grass` from `terrain/dressing/index.tres` and delete
  `terrain/dressing/sets/ambient_grass.tres`;
- the baked KayKit grass descriptors/visuals stay in the catalogue — selective warm-up already
  guarantees unreferenced assets cost descriptor metadata only;
- by the dressing invariants, removing a set leaves every other set's candidates bit-identical.

---

## 10. Verification

**GUT:**

- identical `(program, world_seed, tile, region, water)` → bit-identical buffers; request order
  and tile order irrelevant;
- dropout keys sort stably, emitted ranks are exactly `i / count`, and every sampled density `d`
  exposes exactly the first `ceil(count × d)` instances; subsets nest, `d = 0` is empty, and
  `d = 1` keeps every instance at full scale;
- settings validation: exact biome coverage keys, values in `[0,1]`, ordered finite ranges,
  disjoint non-empty full/sparse groups, sorted unique known asset IDs, exactly one visual piece
  per asset, no collision pieces, and the upright uniform-transform/zero-XZ-offset contract;
- deterministic tile hashes select one full and one sparse asset, every slot belongs to exactly one
  class, and a non-empty tile emits no more than two batches;
- coverage equals the specified biome × shared-land-occupancy × canopy-opening formula, including
  zero grass on a shared path/clearing;
- qualification: wet/shore anchors rejected, grade limit enforced, `Y` matches `surface_y`;
- trample: direction encode/decode round-trips; stamp merge rules; epoch rebase preserves
  effective flatten within tolerance; window scroll preserves world-anchored texels; segment
  rasterization leaves no gap; uploads coalesce and never exceed 30 Hz;
- streamer: AABB-intersecting desired ring has no anchor inside 144 m in an unrequested tile;
  nearest-point CPU density is never below any anchor's shader density; eviction hysteresis,
  stale-generation drops, elapsed-time commit budget, and the shared player-derived LOD origin are
  honoured; camera movement alone changes neither CPU caps nor shader density;
- shared worker: priority tiers protect the player and grass-underlay terrain while preventing
  distant-terrain starvation of grass; grass is not queued before its containing terrain chunk is
  committed; the worker-only field-context LRU is capped at 16 parent chunks, rebuilds an
  evicted/missing entry bit-identically, and never appears in a main-thread result;
  teleport/stale results cannot resurrect a tile;
- render commit: packed layout stride/flags are correct and every custom AABB contains the full
  transformed descriptor bounds plus maximum height-relative shader displacement; materials bind
  the compiled albedo and the shader compiles with double-sided rendering;
- worker purity: `GrassField` performs no resource loads and no RenderingServer calls.

**Visual battery** — new `review_grass.json` pinned-seed teleports (godot-MCP loop, F3
overlay): meadow carpet density, shared broad clearing and connected path, forest canopy-opening
agreement (grass and flowers in the same openings), highland sparseness, marsh coverage,
shoreline clearance band, biome transition colour blend, fade-edge invisibility at ~144 m,
no tile-shaped holes while circling the fade edge, a balanced full/sparse carpet without obvious
24 m variant patches (and all five silhouettes present across the sites), gust fronts readable in
motion capture, trample trail direction, high-speed trail continuity, 7 s recovery, standing hold,
and re-trample refresh.

**Perf gates:** Phase 2's static carpet is a hard go/no-go gate before wind or trample work begins.
The existing 49-chunk terrain profile must remain unchanged with grass disabled. With grass
enabled, priority tests must show that player-critical terrain still preempts grass; completion of
the distant ring may occur later by design. On named target hardware, record grass worker
time/tile, player-terrain latency, main-thread commit time/frame, CPU and GPU frame time,
resident/submitted instance counts, draw count, and raw MultiMesh buffer memory in a pinned
max-density run. The starting acceptance criteria are no individual frame exceeding 0.5 ms of
grass commit work and no sustained frame over the project's target frame budget. Record the
measured hardware-specific limits and result in the implementation note. If the static carpet
fails, stop and revise density, source geometry, or the render representation; do not proceed by
hiding the failure behind wind/trample or an unplanned far-LOD branch. Phase 4 additionally records
trample upload rate while sprinting and verifies the 30 Hz ceiling.

---

## 11. Delivery phases

1. **Bake + field:** append all five manifest entries and enforce the descriptor contract;
   `GrassSettings` + compiled program; `GrassField`; deterministic two-class selection,
   coverage/qualification tests; lineup QA of scaled tufts.
2. **One-worker streaming + hard gate:** add typed priority-tiered grass jobs and the bounded
   worker-only parent-context LRU to `FieldTerrainStreamer`; add main-thread-only `GrassStreamer`,
   conservative tile ring, budgeted commits, shared player-origin distance density, and the static
   material path. Stop here until the hardware perf gate passes.
3. **Wind:** shared grass materials, shader idle sway and rolling gusts; `GrassStreamer` owns the
   globals until another subsystem adopts them.
4. **Trample:** observer-based `TrampleField`, coalesced uploads, in-shader recovery; leave
   character/controller code untouched; trample QA sites.
5. **Retire & tune:** remove `ambient_grass`, final per-biome coverage/colour pass, perf profile,
   and update `AGENTS.md` with the landed grass pipeline and worker ownership.

Each phase lands runnable.

---

## 12. Explicitly deferred

- Creature/NPC stamp wiring (API exists; callers arrive with those actors).
- Gameplay-readable trample state (tracking, stealth) — would break visual-only; separate design.
- GPU-driven placement behind the same placement contract.
- Trees/water adopting the shared wind globals; extract a `WindState` only when a second runtime
  owner actually needs one.
- Grass shadow casting; far-tile variant thinning (held lever); jump-landing radial stamp.
- `Grass_06/07` as rare baked accents in some future dressing set.
