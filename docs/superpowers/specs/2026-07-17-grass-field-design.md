# GrassField — Animated Ground-Cover Carpet — Design Spec

**Date:** 2026-07-17
**Status:** Approved design; implementation reference.
**Scope:** The deferred dense-grass system from the 2026-07-16 environment/dressing spec: a lush,
wind-animated, player-trampled grass carpet with biome-specific coverage and clearings. Visual
only. This spec supersedes nothing in the dressing spec; it fills the slot that spec deferred
("Dynamic, dense, interactive, or LOD-specialized grass, including LPFV `Grass_01–07` placement").

---

## 1. Decisions (locked during brainstorm)

| Question | Decision |
|---|---|
| Look & reach | Lush carpet: ~2+ tufts/m² near the player so ground is mostly hidden in grassy areas; full density to ~60 m, zero by ~144 m; terrain ground tint hides the fade edge |
| Mesh source | Bake LPFV `Grass_01–05` (82–184 tris) scaled down via the existing environment bake; skip 574–922-tri `Grass_06/07` |
| Trampling | Player stamps now; API takes any actor later; nothing reads trample state back — purely visual |
| Old KayKit grass | Retire the `ambient_grass` dressing set once the carpet lands |
| Architecture | Dedicated `GrassField` worker function + `GrassStreamer` at 24 m-tile granularity with its own ~144 m radius; MultiMesh per (tile, variant); all motion in one vertex shader |

Rejected alternatives: extending `DressingField` to carpet density (computes 10–20× wasted
instances at terrain-chunk radius; strains its per-cell slot model; per-chunk MultiMeshes too
coarse for distance LOD) and GPU-driven placement (duplicates height/biome/clearing field
ownership into GPU textures; weakens determinism and QA). The placement contract stays
independent of the rendering mechanism so a GPU path remains a possible future swap.

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
- **Pure worker boundary:** the worker sees immutable field data and returns packed primitive
  arrays. Meshes, materials, textures, RIDs, and all RenderingServer work stay on the main
  thread (including the known `--headless` read-back deadlock rule).
- **One field owner per fact:** ground from `TerrainSurfaceField`, water/shore from
  `WaterFieldContext`, biome weights/tint/coverage from the biome fields, clearings from the
  shared named-noise-channel convention. Grass reconstructs none of them.
- **Self-contained assets:** grass visuals go through `environment_bake`; runtime never touches
  `assets/LowPolyFantasyVillage/**`.

---

## 3. Components

```text
scripts/terrain/grass/
  GrassField.gd        # pure worker placement -> packed buffers
  GrassStreamer.gd     # tile ring, worker jobs, budgeted commits, density counts
  GrassSettings.gd     # authored Resource schema (validated at startup)
  TrampleField.gd      # world-anchored deformation window + stamp API
  WindState.gd         # global wind shader parameters

terrain/grass/
  settings.tres        # the single authored GrassSettings
  grass.gdshader       # one shader: sway + gusts + trample + fade + tint

terrain/environment/…  # baked lpfv.grass.01–05 via the normal catalogue layout
tools/environment_bake/manifests/grass.json
```

- **`GrassField`** — static pure function: `compute(tile: Vector2i, region: HeightfieldRegion,
  water: WaterFieldContext, program) -> Dictionary` of per-variant packed buffers.
- **`GrassStreamer`** — main-thread node driven by player position. Maintains the desired tile
  set, submits worker jobs (lower priority than terrain chunks, same worker infrastructure),
  commits results under a per-frame budget, updates `visible_instance_count` per tile, evicts
  with hysteresis. Grass radius ≪ terrain radius, so terrain is always committed beneath
  visible grass; grass never gates terrain readiness.
- **`WindState`** — owns the global shader parameters for wind. Namespaced (`wind_*`) so trees
  and water can adopt the same wind later without refactoring grass.
- **`TrampleField`** — main-thread node owning the trample texture window and the public
  `stamp(world_pos: Vector3, dir: Vector2, radius: float, strength: float)` API. The player
  controller calls it; creatures/NPCs can call the same API later with zero redesign.

A compiled program mirrors the dressing pattern: `GrassSettings` (a `Resource`) is validated and
flattened at startup into a primitive, worker-safe program object (numbers, arrays,
`StringName`s only). Validation follows dressing rules: coverage/variant dictionaries must
contain exactly `BiomeRegistry.biome_ids()`, ranges ordered and finite, scales positive,
`grass_seed_version >= 1`.

---

## 4. Placement (worker, deterministic)

**Lattice.** Grass tile = 24 m (`TerrainChunkMesher.TILE`). Each tile has a stratified 48×48
slot grid (0.5 m pitch, 2 304 slots, 4/m² ceiling). Per slot, stable hashes with named-purpose
salts produce: jitter X/Z within the cell, eligibility roll, yaw, scale, variant choice, sway
phase, brightness, dropout rank. Changing one concern's salt cannot reshuffle the others.
Identity is `(world_seed, grass_seed_version, tile, slot_index)`; `grass_seed_version` bumps
only for a deliberate full reshuffle.

**Coverage.** `coverage(p) = biome_base(p) × clearing(p)`, evaluated at the jittered anchor.

- `biome_base` is the dot product of `Helper.biome_weights5(p)` with the authored per-biome
  coverage dictionary. Defaults: meadow 0.65, deep_forest 0.50, highland 0.25,
  blossom_grove 0.55, twilight_marsh 0.35.
- `clearing(p)` comes from named world-noise channels, the same convention dressing habitat
  layers use. `deep_forest` reuses the existing `woodland_canopy` channel so grass and
  canopy-driven dressing agree on where openings are; meadow gets a large-scale
  (~180 m) clearing channel producing occasional bald patches with soft edges; highland a
  small-scale (~60 m) patchiness channel. Channel names, scales, per-biome mix, and edge
  softness are authored in `GrassSettings`.

A slot exists iff `coverage(anchor) ≥ eligibility_roll`. Density is therefore directly
proportional to coverage — clearings are simply regions where coverage approaches zero, and
their edges thin out gradually over the channel's edge softness.

**Qualification** (all at the jittered anchor):

- dry land: `water.shore_distance_at(anchor) ≥ 0.3 m` (keeps grass off wet sand and out of
  ponds/rivers);
- grade: `TerrainSurfaceField` grade ≤ authored `max_grade` (steep cliff faces drop out
  automatically);
- `Y = TerrainSurfaceField.surface_y(anchor)`.

**Pose & appearance.** Tufts stay world-upright (low-poly style, cheap): random yaw, uniform
scale in 0.85–1.2. Instance `COLOR` = biome tint sampled at the anchor (same tint fields the
ground uses) × brightness jitter (0.94–1.06). The carpet therefore colour-blends across biome
transitions exactly like the terrain, which is also what makes the far-edge density fade
invisible. `CUSTOM0 = (sway_phase, dropout_rank, 0, 0)`.

**No arbitration.** At carpet density overlap is desirable; the Matérn spacing machinery is
deliberately absent. The only query margin beyond the tile is the fields' own fixed stencils
(grade/derivative sampling and the water context halo).

**Output.** Per variant, one `PackedFloat32Array` already in Godot's MultiMesh buffer layout
(`TRANSFORM_3D` + colour + custom data interleaved), sorted by dropout rank ascending, plus the
instance count. The main thread commits each with a single `multimesh.buffer` assignment — no
per-instance calls.

---

## 5. Streaming, rendering, LOD

**Ring.** Desired set = tiles whose centre lies within `GRASS_RADIUS = 144 m` of the player
(~115 tiles). Missing tiles are requested nearest-first; tiles beyond `GRASS_RADIUS + 24 m`
are evicted (hysteresis). Commits are budgeted per frame (target: a tile commit ≤ ~0.5 ms;
spillover waits). Every queued result carries `(tile, generation)`; stale generations are
dropped, matching the dressing commit-queue rule.

**Batches.** One `MultiMeshInstance3D` per (tile, variant): 5 variants → ≤ 5 batches per tile,
each with `use_colors = true`, `use_custom_data = true`, custom AABB = tile bounds inflated by
max sway, `cast_shadow = OFF`. Frustum culling handles behind-camera tiles. Expected steady
state ≈ 30–60 k committed instances, ~3–4 M worst-case triangles, ~200 visible instanced draws,
~25 MB of buffers — comfortable for Forward+. Held-back lever if profiling disagrees: far tiles
commit only the two cheapest variants (halves far draws and triangles); not built until needed.

**Distance density.** `density(d) = 1` inside 60 m, smoothstep to 0 at 144 m.

- CPU, per frame: `visible_instance_count = ceil(count × min(1, density(tile_distance) + 0.05))`
  — free nested subsets because buffers are dropout-sorted; the 0.05 margin keeps the CPU cap
  slightly above the shader cutoff so the shader always controls the visible edge.
- Shader, per instance: recompute `density(camera_distance)` and shrink instances whose
  `dropout_rank` is within 0.15 of the local cutoff
  (`scale *= 1.0 − smoothstep(d − 0.15, d, rank)`), so the edge dissolves instead of popping
  when counts step.

---

## 6. Wind — idle sway and rolling gusts

Global shader parameters (owned by `WindState`, added to `project.godot` global uniforms):
`wind_direction: vec2`, `wind_idle_amplitude: float`, `wind_gust_texture: sampler2D` (seamless
low-frequency `NoiseTexture2D`), `wind_gust_scale: float` (~100 m), `wind_gust_speed: float`
(~8 m/s), `wind_gust_strength: float`.

Vertex shader, with `h = clamp(local_y / tuft_height, 0, 1)` and bend weight `w = h²` (roots
pinned; `tuft_height` is a per-variant uniform from the baked descriptor's measured AABB):

1. **Idle sway** — small elliptical offset `sin(TIME · f + phase)` per instance (phase from
   `CUSTOM0.x`), amplitude `wind_idle_amplitude · w`, biased along `wind_direction`.
2. **Gust wave** — `n = texture(wind_gust_texture, (world_xz − wind_direction · TIME ·
   wind_gust_speed) / wind_gust_scale).r`, shaped by `g = smoothstep(0.45, 0.85, n)` into
   sparse travelling fronts. Displacement `g · wind_gust_strength · w` along the wind; `g` also
   scales idle-sway amplitude. Because the noise field itself translates across the world,
   contiguous blobs sweep through the meadow and grass bows in visible waves — the rolling-gust
   effect. A small, faster second octave adds flutter.
3. **Arc correction** — displaced tips drop by a quadratic term so blades arc instead of
   stretching.

---

## 7. Trampling

**State.** `TrampleField` owns a 256² `FORMAT_RGBAH` `Image`/`ImageTexture` covering a 64 m
world-anchored window (0.25 m/texel) centred near the player: `RG` = bend direction (±1 encoded
0–1), `B` = strength, `A` = stamp timestamp against a rolling epoch. Shader uniforms:
`trample_texture`, `trample_origin: vec2`, `trample_size: float`, `trample_epoch: float`.

- **Scrolling:** the window origin is texel-snapped; when the player moves > 8 m from centre,
  the image blit-shifts and newly exposed border texels clear. World-anchored means trails stay
  exactly where they were made while inside the window.
- **Epoch:** timestamps are seconds since a rolling epoch, rebased every ~15 min (one full-image
  rewrite subtracting the delta) so half-float precision never degrades recovery.
- **Uploads:** the texture re-uploads only on change (stamp, scroll, rebase). A standing
  player refreshes its hold stamp at a low cadence (~every 2 s) rather than every physics
  tick, so a motionless player costs almost nothing.

**Stamping.** Each physics tick while grounded and moving, the player controller calls
`stamp(foot_pos, normalize(horizontal_velocity), 0.45, strength)` with
`strength = clamp(speed / walk_speed, 0.4, 1.0)`; when nearly still it re-stamps with the last
direction at the low hold cadence, keeping grass pinned underfoot. Per texel in the
disc: `strength = max(current_effective_strength, new)`, direction lerps toward the stamp
direction weighted by stamp dominance, timestamp = now. Trails therefore lie *away from* the
walker along the direction of travel, and re-walking a fading trail re-flattens it.

**Recovery — entirely in-shader.** `flatten = B × (1 − ease_in(t))` with
`t = clamp((now − A) / 7 s, 0, 1)` and `ease_in(t) = t²` — recovery progress starts slow, so
grass lingers flat and then rises. No per-frame CPU decay pass, no viewport feedback loop.

**Deformation.** Sampled once per vertex at the tuft's MultiMesh origin
(`MODEL_MATRIX[3].xz`), so a tuft bends as a unit: displace along the stored direction by
`flatten · w · 0.35 m`, squash `y` by `flatten · w · 0.8 · tuft_height`, add slight
per-instance-phase perpendicular splay so a trail isn't uniform, and scale the wind response by
`(1 − flatten)` — crushed grass doesn't sway. Outside the window the sample contributes zero.

**Stretch polish (not required for done):** radial-outward stamp ring on jump landings.

---

## 8. Assets and material

A `grass` bake wave through the existing `environment_bake` pipeline: manifest entries for
LPFV `Grass_01–05`, manifest scale ~0.5 targeting a 15–30 cm standing height (verified against
the 1 m marker in the catalogue lineup), base pivots, provenance recorded as usual; asset IDs
`lpfv.grass.01`–`lpfv.grass.05`.

Grass introduces its own material family: `grass.gdshader` handles albedo (the shared LPFV
grass texture — likely one material for all five variants), instance `COLOR` multiply, and all
vertex deformation. Per-variant material instances differ only in `tuft_height`. Optional
tuning knob: blend normals toward world-up (`NORMAL = mix(NORMAL, up, k)`) so the carpet shades
like the ground and individual tufts pop less.

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

- identical `(seed, tile, program)` → bit-identical buffers; request order and tile order
  irrelevant;
- dropout subsets nest: the first K instances of a buffer are the same for every K;
- settings validation mirrors dressing rules (complete biome dictionaries, ordered finite
  ranges, positive scales, unknown channel names rejected);
- qualification: wet/shore anchors rejected, grade limit enforced, `Y` matches `surface_y`;
- trample: direction encode/decode round-trips; stamp merge rules; epoch rebase preserves
  effective flatten within tolerance; window scroll preserves world-anchored texels;
- streamer: eviction hysteresis, stale-generation drops, commit budget honoured;
- worker purity: `GrassField` performs no resource loads and no RenderingServer calls.

**Visual battery** — new `review_grass.json` pinned-seed teleports (godot-MCP loop, F3
overlay): meadow carpet density, meadow clearing with soft edge, forest canopy-opening
agreement (grass and mushrooms in the same gaps), highland sparseness, marsh coverage,
shoreline clearance band, biome transition colour blend, fade-edge invisibility at ~144 m,
gust fronts readable in motion capture, trample trail direction, 7 s recovery, standing hold,
re-trample refresh.

**Perf gates:** 49-chunk startup sweep unchanged (grass streams independently); tile commit
≤ ~0.5 ms; steady-state frame time, instance/draw counts, and buffer memory recorded in the
terrain profile alongside the dressing numbers.

---

## 11. Delivery phases

1. **Bake + field:** `grass` bake wave; `GrassSettings` + compiled program; `GrassField` pure
   function; GUT determinism/qualification tests; lineup QA of scaled tufts.
2. **Streamer:** tile ring, worker jobs, budgeted commits, distance density counts — static
   carpet in-game; coverage/density tuning against the teleport battery.
3. **Wind:** `WindState` globals + shader idle sway and rolling gusts.
4. **Trample:** `TrampleField`, player stamping, in-shader recovery; trample QA sites.
5. **Retire & tune:** remove `ambient_grass`, final per-biome coverage/colour pass, perf
   profile and gates.

Each phase lands runnable.

---

## 12. Explicitly deferred

- Creature/NPC stamp wiring (API exists; callers arrive with those actors).
- Gameplay-readable trample state (tracking, stealth) — would break visual-only; separate design.
- GPU-driven placement behind the same placement contract.
- Trees/water adopting `WindState`.
- Grass shadow casting; far-tile variant thinning (held lever); jump-landing radial stamp.
- `Grass_06/07` as rare baked accents in some future dressing set.
