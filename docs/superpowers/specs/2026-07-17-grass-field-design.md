# GrassField — Animated Ground-Cover Carpet — Design Spec

**Date:** 2026-07-17
**Status:** Implemented on `codex/grass-field`; final implementation reference.
**Scope:** The deferred dense-grass system from the 2026-07-16 environment/dressing spec: a lush,
wind-animated, player-trampled grass carpet with biome-specific coverage and clearings. Visual
only. This spec supersedes nothing in the dressing spec; it fills the slot that spec deferred
("Dynamic, dense, interactive, or LOD-specialized grass").

---

## 1. Decisions (locked during brainstorm)

| Question | Decision |
|---|---|
| Look & reach | Closed carpet inside viable habitat: a 289-candidate primary lattice per 24 m tile (0.50/m²) at saturation, plus deterministic slope/edge supplements, with 2.93–3.36 m-wide overlapping Collection 5 patches on a 1.41 m grid; a narrow 0.20–0.42 habitat curve makes strong beds denser and weak fringes reach zero quickly; patches become uniformly smaller with bounded extra density toward the remaining ecological margin and cliff lips; true ecological clearings and full patch footprints over paths stay empty; full LOD density to ~60 m and zero by ~84 m; whole-patch dropout plus a camera-distance motion low pass prevents temporal grain |
| Mesh source | Bake Collection 5 from the user-provided Collections FBX as `stylized_grass.collection_05`. Preserve all 311 blade silhouettes, but reduce each indexed ribbon from 18 to 4 triangles by retaining root, bend, and tip rows. Move complete blades 25% radially from the patch centre, and store each ribbon's resulting root XZ in UV2 for local deformation. The merged patch falls from 5,598 to 1,244 triangles (77.8%); its broader, less clumped footprint replaces many small tuft instances. The scatter file remains unsuitable (thousands of duplicated nodes with broken white material data), and the Japanese Maple is a tree |
| Trampling | Player stamps now; API takes any actor later; nothing reads trample state back — purely visual |
| Old KayKit grass | Retire the `ambient_grass` dressing set once the carpet lands |
| Architecture | `FieldTerrainStreamer` remains the one worker, scheduler, and scene-tree attachment owner. A pure `GrassField` computes 24 m-tile payloads; a main-thread-only `GrassStreamer` service owns grass ring/render state. One MultiMesh per non-empty tile; all motion in one vertex shader |

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
  `assets/Grass/**`.

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

terrain/environment/…  # baked stylized_grass.collection_05 catalogue asset
tools/environment_bake/manifests/stylized_grass.json
```

- **`GrassField`** — static pure function:
  `compute(program, world_seed: int, tile: Vector2i, region: HeightfieldRegion,
  water: WaterFieldContext, paths: PathContext = null) -> GrassPayload`. `GrassPayload` contains
  one packed MultiMesh buffer and count per selected asset; it owns no resources or nodes.
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
  ground. `HeightfieldRegion`, `WaterFieldContext`, and `PathContext` never cross to the main
  thread. Grass jobs carry only the tile, parent block, generation, and priority. On the worker
  they reuse the existing canonical `WorldFieldBlockCache` and `PathPlan` projections keyed by the
  containing 192 m block; creating a second grass-only LRU would duplicate ownership and reduce
  cache reuse. The shared cache remains deterministic, bounded at `PathProgram.FIELD_CACHE_CAP`
  (192 live block entries), and worker-confined. Its contexts use the maximum query margin and
  shore-distance limit required by dressing, paths, or grass.
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
- `variant_asset_ids: Array[StringName]` (currently the one reviewed Collection 5 patch, sorted at compile
  time);
- ordered finite `scale_range`;
- finite non-negative `max_grade` and `shore_clearance`.

Validation requires `grass_seed_version >= 1`, coverage values in `[0, 1]`, positive scale,
a unique non-empty variant list, and known self-contained assets with
instance-colour support, exactly one visual piece, and no collisions. Each grass piece must be
upright with uniform scale and zero XZ origin offset; only its vertical base correction may
translate the instance origin. The compiler copies the piece transform, descriptor AABB, mesh-local
base/height, and optional albedo-texture metadata into the program/render setup; the worker composes bake
scale/pivot once without loading a resource. Channel names and scales are engine-owned
constants, not authored strings; this removes an unnecessary registry and prevents grass from
silently drifting away from the established clearing/canopy fields.

---

## 4. Placement (worker, deterministic)

**Lattice.** Grass tile = 24 m (`TerrainChunkMesher.TILE`). Each tile has a stratified 17×17
primary slot grid (1.41 m pitch, 289 slots, 0.50/m² projected-area ceiling). Collection 5 is already a complete 311-blade
patch about 3.11 m wide before authored scale jitter, so neighbouring patches overlap by over 2× and
hide the terrain without a small-tuft-density instance count. Per slot, stable hashes with named-purpose
salts produce: jitter X/Z within the cell, eligibility roll, yaw, scale,
sway phase, and a temporary dropout-order key. A separate tile-purpose salt selects
one asset for the tile. Changing one concern's salt cannot reshuffle the others.
Identity is `(world_seed, grass_seed_version, tile, layer, slot_index)`; `grass_seed_version` bumps
only for a deliberate full reshuffle.

The first independent 17×17 supplemental layer corrects projected-area undersampling on hills. Its
acceptance is `coverage × (1 / normal.y − 1)`, capped by the authored maximum grade. Thus a slope
receives exactly the additional candidate density implied by its real surface area, while flat
ground receives none. Keeping the primary layer's old identities intact avoids reshuffling the
existing flat carpet.

One generalized edge scale is the minimum of the projected ecological grass-bed edge and the
physical exposed upper-lip edge. Both taper uniformly to the reviewed 55% minimum over their final
3 m. The lower side of a cliff is not a grass-bed edge: ordinary full-size carpet continues into
the opaque wall, which hides the part of a broad patch behind it. An edge tile visits only the
independent layers required by `(1 + slope_area_extra) / edge_scale²`, capped at four total layers.
This closes the shorter fringe without allowing compensation to grow unbounded. Fully covered
interior tiles still evaluate only the primary and possible slope layer.

**Coverage.** Biome weights, canopy opening, and ground tint are smooth fields whose shortest
authored scale is 108 m. `GrassField` evaluates those canonical owners on a world-aligned 3 m
lattice and bilinearly projects them to each jittered anchor. This is window-independent; after
the final patch-density tuning, the streamed performance is recorded in the implementation note. The
shared construction-level land mask remains exact at every jittered anchor, so grass still cannot
grow back into its clearings and connected paths. The formula is:

```text
at each 3 m lattice point q:
  weights(q)         = Helper.biome_weights5(q, world_seed)
  biome_base(q)      = dot(weights(q), program.coverage_by_biome)
  canopy_field(q)    = DressingEcology.habitat01(
                         q, world_seed,
                         DressingCompiler.stable_id_hash(&"woodland_canopy"), 132.0)
  canopy_coverage(q) = dot_in_BiomeRegistry_order(
                         weights(q), [0.22, 0.82, 0.14, 0.72, 0.42])
  canopy_opening(q)  = DressingEcology.suitability(
                         canopy_field(q), canopy_coverage(q), EXTERIOR, 0.11)
  smooth_coverage(q) = clamp(biome_base(q) * canopy_opening(q), 0, 1)
  projected_land(q)  = DressingEcology.land_occupancy01(q, world_seed)

at jittered anchor p:
  projected_carpet(p) = smoothstep(
                          0.20, 0.42,
                          bilerp_3m(smooth_coverage, p)
                          * bilerp_3m(projected_land, p))
  habitat(p)  = bilerp_3m(smooth_coverage, p)
                * DressingEcology.land_occupancy01(p, world_seed)
  coverage(p) = smoothstep(0.20, 0.42, habitat(p))
  edge_scale(p) = min(
                    lerp(0.55, 1.0, smoothstep(0, 1, coverage(p))),
                    cliff_edge_scale(p))
  tint(p)     = bilerp_3m(BiomeRegistry.ground_tint_at(q, world_seed), p)
```

- `biome_base` is the dot product of `Helper.biome_weights5(q, world_seed)` with the authored
  per-biome coverage dictionary. Defaults: meadow 0.75, deep_forest 0.60, highland 0.32,
  blossom_grove 0.66, twilight_marsh 0.45.
- `land_occupancy01` is the existing shared broad-clearing and path exclusion. It is
  construction-level: zero means no ground population, including grass, may reappear there. Its
  3 m projection only bounds which supplemental layers are worth visiting; the exact jittered
  query remains the authoritative placement value.
- `canopy_opening` uses the habitat layer retired with `ambient_grass`, including its
  canonical channel, scale, blended biome coverage, `EXTERIOR` preference, and softness. Moving
  those fixed values here preserves ecological agreement without inventing a second configurable
  channel system.
- `ground_tint_at` is the one tint owner shared with the terrain sheet and cliff dressing. It
  multiplies biome colour by deterministic ±4% value patches at 108 m and ±2.5% warm/cool patches
  at 156 m. Both are continuous world fields, so same-biome regions can vary subtly without tile
  or chunk boundaries.

A slot exists iff `coverage(anchor) > eligibility_roll`. The final monotone carpet curve is
deliberately saturating: open twilight marsh and stronger habitat close to the lattice ceiling,
while the narrow 0.20–0.42 transition removes the long tail of isolated repeated tufts. Because
the exact construction-level occupancy is
multiplied before that curve, zero-valued broad clearings and connected paths remain exactly empty;
the saturation cannot sprinkle grass back into shared negative space.
Accepted edge patches scale uniformly, and layer `n > 0` is admitted by its corresponding unit
slice of `coverage × (min(4, (1 + slope_area_extra) / edge_scale²) - 1)`. Grass becomes finer
toward an ecological margin or upper cliff lip without allowing extreme compensation to become a
visibly darker pile.

**Qualification** (all at the jittered anchor):

- context: `water.covers(anchor)` must be true (a violated query contract is an assertion, not a
  placement rejection);
- dry land: the canonical signed
  `water.shore_distance_at(anchor) ≥ program.shore_clearance` (default 0.3 m); wet values are
  negative, so a separate redundant wetness query is unnecessary;
- grade: the same centred 1 m finite-difference stencil as `DressingField` must be
  `≤ program.max_grade`; `TerrainSurfaceField.bake_cell` is cached for the few cells touched by
  the tile, and its exact `sample_baked` result removes repeated classification work without
  changing height;
- path: reservations keep their canonical clearance rule, while the actual corridor is tested at
  the anchor and eight points on the selected, randomly scaled asset's conservative horizontal
  footprint plus 0.2 m; broad Collection 5 blades therefore cannot hang over the path from an
  accepted centre outside it;
- cliff boundary: the cached mask is symmetric even though the renderer assigns each face to its
  high owner. A one-sided surface derivative on each side prevents the vertical discontinuity from
  becoming a false over-grade clearance strip. Lower ground keeps the ordinary full-size carpet
  right into the opaque wall. Only an upper candidate tapers, and it survives only when its final
  footprint remains on the walkable sheet; this closes the wall foot without hanging blades below
  the lip;
- `Y` is the exact baked-sampler equivalent of `TerrainSurfaceField.surface_y(anchor)`.

**Variant, pose, and appearance.** One tile hash chooses one asset uniformly from the sorted
variant list. The landed list contains only the reviewed Collection 5 patch, so a non-empty tile creates
one batch; the patch itself already supplies 311 varied blade silhouettes. Random yaw, scale,
tint, and world-space placement prevent a repeated stamp without multiplying draw streams.

Each patch's local up axis is the same finite-difference terrain normal used for slope-area
compensation, followed by random yaw around that local up and authored scale in 0.94–1.08. On
flat ground this produces a final standing height of roughly 1.10–1.27 m and width of roughly
2.93–3.36 m. This size is part of the closure contract: overlapping leaves hide the terrain
between neighbouring saturated anchors. At ecological bed margins and exposed upper cliff lips,
the complete patch scales uniformly toward 55%. Moderate taper uses the same inverse-area rule
with a four-layer bound. Symmetric edge masks provide one-sided normals on both sides; high-owner
footprint containment prevents the broad patch from crossing an open lip, while lower grass
remains the ordinary carpet against the wall. Masks are cached per terrain cell rather than
reclassified per patch.
Instance `COLOR` = projected `BiomeRegistry.ground_tint_at(world_position, world_seed)`. There is
no independent instance-brightness range: local variation belongs to that shared ground field or
to the shader above its contact row, so the base cannot expose instance-sized colour patches. On
the main thread, `GrassStreamer` binds the exact live texture object and lip-top UV from
`terrain/materials/ground_palette.tres`; it never copies a CPU-sampled colour. The
Collection 5 has no albedo texture: the relative light/dark structure visible in the source comes
from its bent blade normals. The shader retains 18% of those authored directions under a stable
82% up-normal bias and adds a nonlinear height colour ramp: an exact terrain-colour contact row,
shaded lower growth, terrain-family middles, and modestly warmer tips. A root-group-stable
0.97–1.03 value variation begins above the contact row and adds nearby
structure, then the camera-detail factor removes that variation and converges the height ramp to
one shaded carpet value in the far field. Back-facing ribbons flip their fragment normal so both
sides share one lighting hemisphere. The carpet therefore shares both the terrain's base swatch
and projected biome tint while keeping blade depth without distant value grain. The worker writes
`placement_transform * compiled_piece_local_transform`, applying the baked correction exactly
once. The piece contract keeps its XZ origin at the placement anchor.

**No arbitration.** At carpet density overlap is desirable; the Matérn spacing machinery is
deliberately absent. The only query margin beyond the tile is the fields' own fixed stencils
(grade/derivative sampling and the water context halo).

**Exact dropout ordering and output.** For the tile's selected asset, candidates are
sorted by `(dropout_order_key, slot_index)`. Only after sorting, candidate `i` receives
`dropout_rank = float(i) / float(count)`. The packed custom data is
`CUSTOM0 = (sway_phase, dropout_rank, 0, 0)`. Wind and trample directions use the actual
slope-oriented instance basis rather than a redundant yaw encoding. The random key chooses a stable spatial
order; the exposed normalized rank is exact, unique, and evenly spaced. Consequently the first
`ceil(count × d)` entries are precisely every entry whose rank is `< d`—not merely that many in
expectation.

`GrassPayload` stores at most one selected-asset batch. It contains one `PackedFloat32Array` already in
Godot's MultiMesh layout (`TRANSFORM_3D` + colour + custom data interleaved), its instance count,
and the pure CPU-computed union of the descriptor AABB under all placement transforms. The main
thread commits each MultiMesh with one `buffer` assignment—no per-instance calls and no buffer
parsing to recover bounds.

---

## 5. Streaming, rendering, LOD

**Ring.** Define `distance_to_tile(player_xz, tile)` as the Euclidean distance from the player to
the nearest point of the tile's closed 24 m AABB. The desired set contains every tile where that
distance is `< GRASS_RADIUS = 84 m` (about 45–56 tiles depending on grid phase). Using tile
intersection rather than tile-centre distance is load-bearing: an omitted tile can otherwise cut
a visible square hole as much as 17 m inside the radial fade. Missing tiles are requested
nearest-first within their worker tier; a tile is evicted when its nearest-point distance exceeds
`GRASS_RADIUS + 24 m`. Commits are budgeted by elapsed main-thread time with a 0.5 ms/frame gate.
At most one packed batch is uploaded per frame, so every non-empty tile attaches atomically.
Every queued result carries `(tile, generation)`; stale generations are dropped, including
partially committed unattached nodes.

**Batches.** One `MultiMeshInstance3D` per non-empty tile. It uses colours and custom data,
disables shadow casting, and receives the
grass shader as `material_override`; the compiled asset metadata supplies the albedo texture bound
to that shader. The shared per-asset material stores the mesh-local base and height used by the
bend profile.

The custom AABB starts with the payload's static union—each placement transform applied to the
already bake-corrected descriptor AABB—then is inflated from that batch's maximum scaled patch
height by the allowed idle, gust, trample, and arc bend ratios plus a small safety epsilon. It
therefore contains the tile's actual terrain-height band and every shader deformation; a flat tile
box is invalid on elevated or sloped ground. `GrassStreamer` defines those maximum ratios and
clamps runtime wind globals to them, so tuning cannot silently invalidate an already committed
AABB.

The construction upper bound is 64,736 committed instances across the maximum 56-tile ring
phase: 289 slots × the four-layer ecological bound × 56 tiles. Hard cliffs are bounded to two.
Ecological occupancy is lower but is not a correctness or budgeting
assumption. One source asset is warmed and each non-empty tile owns one batch, implying at most
56 resident grass batches before frustum culling. The pinned measured instance, buffer, primitive,
and frame costs live in the implementation note. The first fallback,
only if the GPU gate fails, is a separately specified far-mesh/variant reduction; do not pre-build
a second LOD path.

**Distance density.** `density(d) = 1` inside 60 m, smoothstep to 0 at 84 m.

`GrassStreamer` samples the player's XZ once per frame into `grass_lod_origin`, uses that exact
value for every CPU tile calculation, and publishes it as a global shader parameter. Population
LOD never uses `CAMERA_POSITION_WORLD`: orbiting or zooming the camera must not move the density
field or invalidate the CPU cap. Camera position is used only for the independent motion-detail
low pass described below.

- CPU, per frame: `visible_instance_count = ceil(count × density(distance_to_tile))`. Because
  nearest-point distance gives the maximum density anywhere in the tile, this cap is conservative:
  together with normalized ranks, it never removes an instance the shader might show.
- Shader, per instance: compute `d = density(distance(instance_anchor.xz, grass_lod_origin))` and
  retain the whole patch iff `rank < d`. This matches the exact CPU prefix. A previous broad
  partial-scale interval turned a large fraction of retained distant leaves into sub-pixel
  "petals" and was removed after temporal review.
- Far-field stability: from 32–48 m camera distance, one smooth `grass_detail` factor converges
  wind displacement to zero. Lighting keeps the same fixed up-biased normal at every distance;
  an earlier far-normal flatten created a visible bright LOD band. By the time grass becomes sub-pixel it is static, so
  rank removals do not become noisy moving grain. This uses the existing shader/material/draw
  stream—no transparency, screen-space dithering, billboard, or second far mesh. The shorter
  84 m ring also avoids spending frame time on detail the camera cannot resolve.

---

## 6. Wind — idle sway and rolling gusts

Global shader parameters (initialized and updated by `GrassStreamer`, added to `project.godot`):
`wind_direction: vec2`, `wind_idle_bend: float`, `wind_gust_texture: sampler2D` (seamless
low-frequency `NoiseTexture2D`), `wind_gust_scale: float` (110 m), `wind_gust_speed: float`
(4.2 m/s), `wind_gust_bend: float` (0.27). The idle bend is 0.055. Bend values are dimensionless fractions of patch height, so one
shader works across every baked and random instance scale. Names remain subsystem-neutral so
future tree/water consumers can reuse them; extracting a separate `WindState` before there is a
second owner is unnecessary.

Vertex shader, with
`h = clamp((VERTEX.y − local_base_y) / local_height, 0, 1)` and bend weight `w = h²`.
`local_base_y` and `local_height` come from the baked mesh's own local AABB and are set once on the
shared per-variant material. Do not use descriptor/world height here: bake and random scale live in
the instance transform, while `VERTEX` is still mesh-local.

All deformation remains mesh-local and height-relative. The shader reads the normalized local-X
and local-Z columns of `MODEL_MATRIX` and projects world-space wind/trample directions onto that
true surface tangent frame, then offsets by `local_height × bend_ratio × w`. This remains correct
for slope-normal nonuniform transforms without a per-vertex matrix inverse. The instance transform
naturally applies the baked and random scale once, and every deformation bound remains a simple
multiple of actual patch height.

1. **Idle sway** — small elliptical offset `sin(TIME · f + phase)` per instance (phase from
   `CUSTOM0.x`), amplitude `local_height · wind_idle_bend · w`, biased along the local-space
   form of `wind_direction`. The two harmonics run at 1.05 and 1.70 rad/s; the secondary one has
   22% amplitude. This sits between the original abrupt 1.7/3.1 pair and the nearly static
   0.65/1.05 review pass.
2. **Gust wave** — `n = texture(wind_gust_texture, (world_xz − wind_direction · TIME ·
   wind_gust_speed) / wind_gust_scale).r`, shaped by `g = smoothstep(0.38, 0.88, n)` into
   sparse travelling fronts. Displacement is `local_height · g · wind_gust_bend · w` along
   the local wind direction; `g` also scales idle-sway amplitude. Because the noise field itself
   translates across the world,
   contiguous blobs sweep through the meadow and grass bows in visible waves — the rolling-gust
   effect. A faster phase harmonic adds a small flutter without a second texture lookup.
3. **Arc correction** — tips drop by a bounded fraction of `local_height` derived from the total
   bend ratio, so blades arc instead of stretching.

The combined wind displacement is multiplied by the same 32–48 m camera-distance far-detail factor described
above. Gust fields remain world-continuous, but sub-pixel geometry is deliberately static; motion
there carries no readable shape information and only aliases between frames.

The same camera-detail factor removes root-group, height-ramp, and angled-normal contrast,
converging distant grass to the exact terrain palette value and upward terrain lighting response.
The low-pass must not apply a darker "carpet" value or retain unreadable card normals: because grass
has a finite population radius, either creates a false shadow band immediately before the brighter
bare terrain beyond the cutoff.

---

## 7. Trampling

**State.** `TrampleField` owns two 256² `FORMAT_RGBAH` `Image`/`ImageTexture` layers covering one
64 m world-anchored window (0.25 m/texel) centred near the player. The dynamic player layer stores
`RG` = bend direction (±1 encoded 0–1), `B` = strength, `A` = stamp timestamp against a rolling
epoch. The persistent structural layer stores radial-outward direction and strength for the
rotated/scaled near-ground outlines compiled from loaded collidable dressing; it has no timestamp
and is rebuilt only when chunks change or the window scrolls. Because every grass material reads
the same window, these are namespaced global shader parameters rather than duplicated material
updates: `grass_trample_texture`, `grass_static_trample_texture`,
`grass_trample_origin: vec2`, `grass_trample_size: float`, `grass_trample_epoch: float`.

- **Scrolling:** the window origin is texel-snapped; when the player moves > 8 m from centre,
  the image blit-shifts and newly exposed border texels clear. World-anchored means trails stay
  exactly where they were made while inside the window. The last-uploaded texture and its origin
  are one atomic render snapshot: after a CPU scroll, the old origin remains published until the
  scheduled shifted-image upload. Publishing the new origin against old pixels caused a one-frame
  world-wide deformation jump.
- **Epoch:** timestamps are seconds since a rolling epoch, rebased every 60 s (one full-image
  rewrite subtracting the delta). At 15 min a half float resolves time in roughly half-second
  steps, visibly coarse against a short recovery; a one-minute epoch keeps the step below a tenth
  of a second. Negative timestamps after rebase are legal. Effective recovery is 10 s, giving the
  wider, clearly flattened wake enough time to read while moving.
- **Uploads:** CPU stamps mark the image dirty. One render upload coalesces all changes and occurs
  at most 30 Hz; scroll/rebase may force the next scheduled upload but never create a second upload
  in the same frame. A standing actor refreshes its hold stamp every ~2 s. Static assets never
  refresh the dynamic image; the old shared two-second obstacle stamp caused visible direction
  resets after a player walked over a rock.

**Stamping.** In `_process`, after the physics step, `TrampleField` observes the exported player's
actual current/previous XZ positions, `velocity`, and `is_on_floor()` state. It passes the grounded
foot segment through its own public API; `character.gd` and every controller remain unchanged. The
field rasterizes along that segment at no more than 0.25 m spacing, so a fast actor cannot leave
gaps even though uploads are capped. Each stamp uses the normalized actual horizontal
displacement, radius 1.1 m, and
`strength = clamp(actual_speed / TRAMPLE_FULL_SPEED, 0.72, 1.0)`, where the field owns the tuning
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

**Structural crush.** `DressingCompiler` carries each collidable asset's ordered radial outline
of actual near-ground visual vertices into the resource-free `DressingProgram`. The streamer
transforms that polygon by each placement's complete basis (including yaw and non-uniform scale)
and replaces the persistent footprint set when terrain chunks integrate or evict. Rasterization
is polygon-contained—there is no radius expansion—so a long narrow rock cannot clear a wide
circle of grass. The shader uses a strong vertical drop and only a small radial bend for this
layer. A player trail temporarily contributes its stronger travel-direction bend; as dynamic
strength decays, `static * (1 - dynamic)` continuously restores the radial direction while
`max(static_drop, dynamic_drop)` keeps grass under the asset pressed down throughout.

**Recovery — entirely in-shader.** `flatten = B × (1 − ease_in(t))` with
`t = clamp((now − A) / 10 s, 0, 1)` and `ease_in(t) = t²` — recovery progress starts slow, so
grass lingers flat and then rises. No per-frame CPU decay pass, no viewport feedback loop.

**Deformation.** UV2 carries the authored mesh-local root XZ for every retained ribbon. The shader
transforms that root through `MODEL_MATRIX`, so each blade group samples its own world coordinate;
branches that genuinely share an authored root may share the same sample, but the full 3.11 m patch
never bends as one rigid tuft. The shader projects the stored world direction into the same actual
instance tangent frame used by wind, displaces by `local_height · flatten · w · TRAMPLE_BEND`, and
lowers by `local_height · flatten · w · TRAMPLE_DROP`. Both constants are ratios bounded by the
custom AABB contract. Slight per-instance-phase perpendicular splay keeps a trail from looking
uniform, and wind response is multiplied by `(1 − flatten)` — crushed grass does not sway. Outside
the window the sample contributes zero.

**Stretch polish (not required for done):** radial-outward stamp ring on jump landings.

---

## 8. Assets and material

The dedicated `stylized_grass.json` manifest selects Collection 5's `Grass_Type_4...Main4` node
from the user-provided multi-variant Collections FBX. `environment_bake`'s explicit
`source_root`/`component_ribbon_rows` import options find the 311 indexed connected components,
preserve every authored blade, and reduce each regular ribbon from ten vertex rows / 18 triangles
to root, bend, and tip rows / 4 triangles. `component_root_spread = 1.25` translates each complete
blade radially without altering its silhouette, then stores the translated lowest-row midpoint XZ
in UV2 for stable per-blade-root deformation. It merges, centres, and grounds the result at Y=0. The
result is one self-contained 1,244-triangle, 3.11 m-wide / 1.18 m-tall asset with normal provenance;
runtime has no FBX path or extraction logic. `GrassProgram`
compilation and its tests enforce the grass-specific descriptor contract: exactly one visual
piece, zero collision pieces, finite bounds, at most one optional albedo texture, a positive uniform scale with no
tilt, and zero XZ origin offset. A fixed yaw and vertical base correction are allowed. Failing an
assumption is a startup validation error, not a bake branch or runtime special case.

Grass introduces its own material family: `grass.gdshader` handles an optional validated baked
albedo texture, mesh/instance `COLOR` multiply, distance dropout, wind, and trample deformation. There is
one shared `ShaderMaterial` per asset across all tiles; its only asset-specific values are the
optional compiled albedo texture and mesh-local `local_base_y`/`local_height`. The shader uses
`render_mode cull_disabled` because the source ribbons are one-sided leaf cards.
`GrassStreamer` creates and warms these materials before the terrain worker starts. Collection 5
retains 18% of its authored normal direction under an 82% up-normal bias. The contact row is fixed
at the exact terrain colour and the lower blade eases gradually to a 0.84 shaded body before
reaching 1.04 at the tips; a subtle cool-to-warm tint and root-group-stable
0.97–1.03 variation begin above the contact row and keep the geometry readable on bright meadow
ground. These effects fade with the 32–48 m camera-detail factor toward a uniform 0.90 shaded-carpet
value, preventing distant speckle. Full roughness and zero specular avoid plastic highlights. The
terrain-exact base swatch and projected biome tint remain unchanged, but low-angle light can no
longer turn alternating blades near-black and glossy-bright. `FRONT_FACING` flips the fragment
normal for back-facing ribbon cards, so disabling culling does not leave half the carpet lit from
the opposite hemisphere.

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
  a non-empty unique variant list, sorted known asset IDs, exactly one visual piece
  per asset, no collision pieces, and the upright uniform-transform/zero-XZ-offset contract;
- deterministic tile hashes select one asset and a non-empty tile emits no more than one batch;
- coverage equals the specified saturated transform of the 3 m-projected biome/canopy field ×
  exact shared-land-occupancy formula, including zero grass on a shared path/clearing;
- qualification: wet/shore anchors rejected, grade limit enforced, `Y` matches `surface_y`, path
  corridors reject the complete patch footprint, slope bases align to the terrain normal, slope
  density grows by the real-area ratio, ecological/upper-cliff edges receive a uniform scale taper
  with bounded density compensation, lower grass meets the wall without a clearance band, and
  upper-lip silhouettes remain contained on the walkable sheet;
- trample: direction encode/decode round-trips; stamp merge rules; epoch rebase preserves
  effective flatten within tolerance; window scroll preserves world-anchored texels; segment
  rasterization leaves no gap; shifted pixels and their published origin update atomically;
  uploads coalesce and never exceed 30 Hz;
- streamer: AABB-intersecting desired ring has no anchor inside 84 m in an unrequested tile;
  nearest-point CPU density is never below any anchor's shader density; eviction hysteresis,
  stale-generation drops, elapsed-time commit budget, and the shared player-derived LOD origin are
  honoured; camera movement alone changes neither CPU caps nor shader density;
- shared worker: priority tiers protect the player and grass-underlay terrain while preventing
  distant-terrain starvation of grass; grass is not queued before its containing terrain chunk is
  committed; grass reuses the canonical worker-only field cache, bounded at
  `PathProgram.FIELD_CACHE_CAP` (192 blocks), and no field context appears in a main-thread result;
  teleport/stale results cannot resurrect a tile;
- render commit: packed layout stride/flags are correct and every custom AABB contains the full
  transformed descriptor bounds plus maximum height-relative shader displacement; materials bind
  the compiled albedo plus the terrain's exact linear-space grass swatch; the shader compiles with
  double-sided rendering, never inherits the source texture's blue-green hue, has no broad
  partial-patch dropout, resolves trample coordinates from baked blade roots, keeps lighting
  continuous, and fades far wind motion through one stable factor;
- worker purity: `GrassField` performs no resource loads and no RenderingServer calls.

**Visual battery** — `tests/harness/review_grass.json` pinned-seed teleports (godot-MCP loop, F3
overlay): meadow carpet density, shared broad clearing and connected path, forest canopy-opening
agreement (grass and flowers in the same openings), highland sparseness, marsh coverage,
shoreline clearance band, biome transition colour blend, fade-edge invisibility at ~84 m,
  no tile-shaped holes while circling the fade edge, a short dense transition without detached
  repeated tufts at ecological bed margins,
a closed carpet without visible ground inside its saturated beds or obvious 24 m tile patches, gust fronts readable in
  motion capture, trample trail direction, high-speed trail continuity, 10 s recovery, standing hold,
and re-trample refresh. The streamed harness captures two settled frames 30 frames apart; their
far grass must not exhibit the moving petal/grain pattern visible in a temporal diff.

**Perf gates:** Phase 2's static carpet is a hard go/no-go gate before wind or trample work begins.
The existing 49-chunk terrain profile must remain unchanged with grass disabled. With grass
enabled, priority tests must show that player-critical terrain still preempts grass; completion of
the distant ring may occur later by design. On named target hardware, record grass worker
time/tile, player-terrain latency, main-thread commit time/frame, CPU and GPU frame time,
resident/submitted instance counts, draw count, and raw MultiMesh buffer memory in a pinned
max-density run. The starting acceptance criteria are no individual frame exceeding 0.5 ms of
grass commit work and no sustained frame over the project's target frame budget. Record the
measured hardware-specific limits and result in
`docs/implementation-notes/2026-07-21-grass-field.md`. If the static carpet
fails, stop and revise density, source geometry, or the render representation; do not proceed by
hiding the failure behind wind/trample or an unplanned far-LOD branch. Phase 4 additionally records
trample upload rate while sprinting and verifies the 30 Hz ceiling.

---

## 11. Delivery phases

1. **Bake + field:** select, simplify, merge, and bake the reviewed Collection 5 patch and enforce the
   descriptor contract; `GrassSettings` + compiled program; `GrassField`; deterministic selection,
   coverage/qualification tests; lineup QA of scaled patches.
2. **One-worker streaming + hard gate:** add typed priority-tiered grass jobs and reuse the
   canonical bounded worker-only field cache in `FieldTerrainStreamer`; add main-thread-only `GrassStreamer`,
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
