# Deco System Refactor — Design Spec

**Date:** 2026-07-16
**Status:** Approved direction (brainstorm 2026-07-16); implementation plans to follow per phase.
**Scope:** How decorative assets are stored/instantiated, how they are placed, and the first
four content waves of new Synty/LPFV assets. Includes the KayKit cliff-dressing pieces
(they share the same storage problem). Excludes combat itself, building interiors,
interactivity (doors, lights), and navmesh.

---

## 1. Motivation

The decoration pipeline works but has structural problems that get worse with every asset
we add:

1. **`assets/` is load-bearing.** `terrain/gltf/*.tscn` wrappers ext-reference
   `res://assets/...` gltf directly, and `CliffDressing.SCENES` / `SlopeAtlas` load those
   wrappers. Deleting `assets/` (the goal — it is a 1 GB dump of downloaded packs, most
   unused) kills every bush, tree, cliff wall, and the shared ground material.
2. **Dead abstraction layers.** Each deco asset is wrapped twice
   (`terrain/gltf/<kind>/<name>.tscn` scale wrapper → `terrain/scenes/<kind>/<Name>.tscn`
   with a vestigial `Sockets/bottom` marker from the retired socket engine), only for
   `TerrainChunkMesher._foliage_pieces()` to harvest raw `(mesh, transform)` pairs out of
   them at load. The runtime unit is a mesh, not a scene.
3. **The catalog is code at the wrong altitude.** `TerrainChunkMesher.FOLIAGE_SCENES` is a
   const dict inside the mesher. Half the authored variants (Grass4, Bush3–6, Rock3–6,
   Tree3–7, TreeBare1) are orphaned because nobody added them to the dict.
4. **The water gate is vestigial.** Decoration placement is gated by `Helper.is_water`
   (the retired ridge-noise water field) at the **cell centre** only. Real water is the
   WaterPlan-carved river/pond network, so foliage spawns on submerged riverbeds and is
   suppressed on dry land the old noise happens to flag. This is the observed
   bushes-underwater bug.
5. **No concepts for the next content tier.** Props and buildings need collision,
   footprints, spacing, occupancy, and structured group placement; the current
   point-scatter has none of these.

## 2. Goals

- **Self-contained by construction:** nothing under `terrain/` or `scripts/` may depend on
  `res://assets/`. After the bake, `assets/` is deletable and the game/tests/harnesses run.
- **Data-driven catalog:** adding a decoration = add data (manifest line + generated
  `.tres`), never edit engine code.
- **One placement engine** that expresses everything from biome-weighted scatter to
  clusters, exclusion distances, water-band rules (cattails/lilypads), village stamps, and
  bridge site-finding — via composition, not special cases.
- **House invariants preserved:** placements are a pure deterministic function of
  `(world_seed, position)`; worker computes plain data, main thread commits nodes; chunk
  borders agree bit-identically via halo evaluation; no RenderingServer work on the worker.
- **Combat-ready occupancy:** blocking deco quantizes to a **2.0 m combat grid** and stamps
  an occupancy bitmap the future combat system consumes directly.

Non-goals: a global constraint solver (WFC — deliberately retired with the socket engine),
runtime placement editing, persisted placements (deterministic regeneration is the model),
structure interactivity, navmesh.

---

## 3. Part A — Storage: `DecoAsset` catalog + bake pipeline

### 3.1 Layout

```
scripts/terrain/deco/            # engine (pure logic + commit adapters)
  DecoAsset.gd                   # custom Resource schema (class_name DecoAsset)
  DecoCatalog.gd                 # registry: loads catalog dir, compiles standard rules
  DecoField.gd                   # per-chunk placement engine: compute (worker) / commit (main)
  PlacementRule.gd               # Resource: proposer + terms + emitter + priority
  proposers/  terms/  emitters/  # small Resource subclasses (§4)
terrain/deco/                    # data (all self-contained — no refs outside terrain/)
  catalog/<id>.tres              # one DecoAsset per entry, human-readable, diffable
  rules/<name>.tres              # hand-authored PlacementRules (special cases only)
  meshes/<pack>/<name>.res       # baked ArrayMeshes (binary, small)
  materials/<pack>*.tres         # per-pack material + copied atlas PNGs
  scenes/<id>.tscn               # structural deco only (prebaked collision), built on baked meshes
  tools/deco_bake.gd             # editor bake script (idempotent)
  tools/manifests/<wave>.json    # what to bake, per content wave
```

`scripts/` vs `terrain/` mirrors the existing code/data split.

### 3.2 Bake, not copy

Two candidate strategies were considered:

- **Copy source:** copy `.fbx`/`.glb` + textures into the project and let Godot re-import
  there. Keeps the import pipeline alive but drags importer quirks and hundreds of MB of
  source geometry around forever — defeats the point of deleting `assets/`.
- **Bake (chosen):** with `assets/` present, `deco_bake.gd` loads the already-imported
  scenes and saves the extracted **ArrayMesh → `.res`** plus a per-pack
  **material `.tres` + copied atlas PNG**. Runtime loads baked resources directly; the
  FBX/gltf importer is never involved again.

Bake tool responsibilities (per manifest entry):
- Extract `(mesh, local transform)` pairs (the exact walk `_foliage_pieces()` does today)
  and save meshes under `meshes/<pack>/`, remapping their materials to the pack material.
- Copy the pack atlas texture(s) and write `materials/<pack>.tres` (mirrors the existing
  extracted `*_MAIN_MATERIAL.tres` settings).
- Apply per-entry scale/pivot fixes (KayKit currently rides at 4×) so baked meshes are
  world-scale with ground-plane pivots; record the measured AABB on the catalog entry.
- For **structural** entries, generate `scenes/<id>.tscn`: MeshInstance3D(s) on the baked
  meshes + StaticBody3D with collision shapes (box/convex/trimesh per manifest) — built at
  bake time in the editor, so runtime never cooks collision (worker-thread rule).
- Generate or refresh `catalog/<id>.tres`, preserving hand-edited placement fields on
  re-bake (bake owns meshes/AABB/material; humans own placement data).
- Idempotent; processes packs one at a time (headless-import OOM lesson).

The KayKit **cliff pieces** (wall/lip/corners ×6) and the atlas material used by
`SlopeAtlas`/the ground sheet are baked by the same tool in phase 0; `CliffDressing` and
`SlopeAtlas` switch to the baked resources. `terrain/gltf/` and `terrain/scenes/` are then
deleted entirely.

### 3.3 `DecoAsset` schema

```gdscript
class_name DecoAsset extends Resource
@export var id: StringName
@export var tags: Array[StringName]            # grass / bush / tree / rock / prop / structure ...
# Visual — batched path (foliage, small props):
@export var meshes: Array[Mesh]                # baked, self-contained
@export var mesh_transforms: Array[Transform3D]
@export var material: Material                 # per-pack; wrapped by the tint shader if tintable
# Visual — structural path (mutually exclusive with meshes):
@export var scene: PackedScene                 # terrain/deco/scenes/<id>.tscn, prebaked collision
# Placement (compiled into a standard PlacementRule — §4.4):
@export var expected_per_cell: float = 0.0     # mean instances per 24 m cell at affinity 1
@export var biome_affinity: Dictionary = {}    # StringName biome -> float weight
@export var water_policy: int = WaterPolicy.LAND_ONLY
@export var slope_policy: int = SlopePolicy.NON_CLIFF
@export var spacing_radius: float = 0.0        # same-asset exclusion, metres
@export var cluster_scale: float = 0.0         # 0 = uniform; >0 = clump-noise wavelength (m)
@export var footprint_cells: Vector2i = Vector2i.ZERO  # 2 m combat cells; ZERO = non-blocking point
@export var scale_range: Vector2 = Vector2.ONE # uniform random scale span
@export var tintable: bool = true              # participates in biome mood tint
@export var variation_value: Vector2 = Vector2.ONE  # per-instance brightness jitter span
@export var variant_group: StringName          # groups palette variants for QA lineups
@export var measured_aabb: AABB                # written by the bake tool
```

**Two instantiation paths, declared by data:**
- **Batched** (`meshes` set): worker emits transforms/tints per asset; commit builds one
  MultiMesh per `(asset, piece)` per chunk — today's path generalized to per-pack
  materials. No collision, no per-node cost.
- **Instanced** (`scene` set): commit instantiates the PackedScene as a chunk child
  (evicted with the chunk like everything else). Collision is prebaked. Instantiation is
  main-thread and rides the existing `MAX_BUILD_PER_FRAME` stagger.

**Palette variants are just assets.** A pink-canopy tree is a second catalog entry sharing
the same baked meshes with a different material and blossom-heavy `biome_affinity`, linked
by `variant_group`. Biome borders blend by *mixing* instances — no variant machinery.
Source colorways exist in the packs (KayKit `Color1–8` folders; FantasyVillage `BLUE`/
`ORANGE`/`GRASS` atlases); where a desired palette doesn't exist, the bake tool may emit a
recolored atlas (hue-shift of masked palette regions) — same runtime path either way.

### 3.4 The self-containment guard

A unit test walks every resource under `terrain/deco/` (and the chunk pipeline's loaded
resources) and asserts **no dependency path starts with `res://assets/`**. This is the
"doesn't break when assets/ is removed" requirement encoded as CI, not convention. Phase 0
additionally verifies by moving `assets/` aside and running the suite + a streaming
harness.

---

## 4. Part B — Placement: one rule engine (propose → score → emit)

### 4.1 Model

```gdscript
class_name PlacementRule extends Resource
@export var id: StringName
@export var proposer: DecoProposer       # WHERE to consider candidates
@export var terms: Array[DecoTerm]       # WHETHER/HOW MUCH (each 0..1; 0 vetoes; product)
@export var emitter: DecoEmitter         # WHAT to place on acceptance
@export var priority: int                # evaluation order (structures < props < foliage)
@export var interaction_radius: float    # max distance this rule reads/affects (halo bound)
```

Per chunk, `DecoField.compute()` evaluates all rules in `(priority, id)` order over the
chunk plus a halo of `max(interaction_radius)`, maintaining a **placed-index** (point set +
occupancy bitmap) that later rules query. Accepted placements inside the chunk are
emitted; halo placements exist only to make neighbouring chunks agree. Everything is a
pure function of `(world_seed, rules, catalog)` — worker-safe, headless-testable.

**Acceptance:** a proposer yields candidate poses with a per-candidate base probability;
final probability = `base × Π terms`. All randomness derives from
`Helper._cell_hash01`-style world-anchored hashes (rule id salted), so results are
seed-stable and order-independent across chunks.

### 4.2 Initial slot inventory

**Proposers** (own geometric site-finding):
- `JitterProposer` — K hash-jittered points per 24 m cell (today's scatter). Option
  `quantize=true` snaps to 2 m combat-cell centres with 90°-stepped yaw (used by blocking
  deco).
- `ShorelineProposer` — points in a band `[d0, d1]` of signed shore distance (from
  `WaterField`'s wet mask on its 6 m lattice). For reeds/cattails/docks. (Phase 2)
- `AnchorGridProposer` — hash-selected anchor points on a coarse super-grid (the WaterPlan
  river-source pattern) with min spacing between anchors. For settlements/POIs. (Phase 4)
- `GapSpanProposer` — scans the heightfield region for opposing same-storey rims with a
  clear gap whose span lies in `[min_len, max_len]`, yielding oriented span poses. For
  bridges; world-lattice-anchored scan with deterministic tie-breaks. (Phase 4)

**Terms** (pointwise, 0..1, 0 = veto; each ~20 lines and unit-testable):
- `BiomeTerm` — blended affinity from `Helper.biome_weights5` × the asset/rule weights.
- `ClusterTerm` — low-frequency per-rule value noise (clumps; two rules can share a
  channel inverted for anti-correlation).
- `WaterDepthTerm` — policy vs the **real** `WaterField` depth at the candidate:
  `LAND_ONLY` (dry, with shore margin), `SHORE` (dry, within band), `SHALLOW` (depth in
  `[min,max]`), `EMERGENT` (wet, depth ≤ max — marsh trees), `FLOATING` (wet; pose Y set
  to water level; optional max `WaterCurrentField` speed — lilypads on still water).
- `SlopeTerm` — `ANY` / `NON_CLIFF` / `FLAT_CELL` / `FLAT_FOOTPRINT` (every combat cell
  under the footprint flat and same storey+level), via `TerrainSurfaceField` classifiers.
- `FeatureDistanceTerm` — prefer/require distance bands to *field* features (water, cliff
  edges); no ordering dependency because fields are ambient.
- `ExclusionTerm` — veto within `radius` of placed-index entries matching a tag filter
  ("bushes never within 5 m of structures"). Requires the excluded thing to have higher
  priority; the framework asserts this at load.
- Self-spacing (`spacing_radius`) is enforced by the placed-index within the rule itself
  (Poisson-style, deterministic hash order).

**Emitters:**
- `AssetEmitter` — one asset (scale/yaw/variation from hashes).
- `VariantSetEmitter` — weighted choice among assets (mainly for stamp slots).
- `StampEmitter` — a `DecoStamp` resource: slots with relative transforms, each slot an
  emitter + optional extra terms (recursive: village → houses + well + lamp posts; a house
  slot may stamp a garden). The stamp claims all its footprints atomically or aborts.
  (Phase 4)

### 4.3 Occupancy

- Grid resolution **2.0 m** (`COMBAT_CELL := 2.0`, one definition site). 24 m terrain cell
  = 12×12 combat cells; chunk = 96×96 bits (PackedByteArray bitmap in the chunk payload).
- Character capsule is 0.8 m ⌀ / 2.24 m tall — one unit per 2 m cell with clearance;
  2×2 cells fit large monsters. `MAX_STEP_HEIGHT` 0.5 m equals one terrain level, so the
  grid meshes naturally with elevation steps. (The 3 m mesh sample step and KayKit module
  width deliberately do not align with 2 m; occupancy is about footprints, not vertices.)
- Only `footprint_cells != ZERO` assets stamp occupancy and quantize their poses; pure
  dressing (grass, flowers, mushrooms, lilypads) stays continuous — it never blocks.
- Placement order stamps footprints test-and-set; the final bitmap ships in the chunk
  payload for the future combat layer (format: bitmap + storey/level per cell can be
  joined later from the region — combat integration is out of scope here).

### 4.4 Sugar: assets compile to rules

`DecoCatalog` compiles every `DecoAsset` with `expected_per_cell > 0` into a standard rule:
`JitterProposer(K=9, quantize = footprint != ZERO)` + `BiomeTerm(affinity)` +
`WaterDepthTerm(water_policy)` + `SlopeTerm(slope_policy)` + `ClusterTerm(cluster_scale)`
+ spacing — at a priority derived from footprint (blocking before non-blocking, large
before small). Hand-authored `PlacementRule` `.tres` files exist only for genuinely
special cases (bridge, village, shoreline bands). **One engine, two authoring levels** —
adding a shrub touches one file; biome profiles keep only mood + coarse budgets
(`foliage_density`; the per-tag `tag_weights` dictionaries retire in favour of per-asset
affinities).

### 4.5 Explicit non-goal

No global constraint solver. Priority-ordered greedy placement with vetoes is
deterministic, debuggable, and art-directable; relational structure comes from stamps
(hierarchical generation), not simultaneous constraint satisfaction. This is the lesson of
the retired socket engine, kept.

---

## 5. Part C — Tint model (three layers)

1. **Per-instance variation** (runtime, free): deterministic brightness/saturation jitter
   within `variation_value`, multiplied into the MultiMesh per-instance COLOR — "some
   trees darker than others".
2. **Biome mood tint** (runtime, existing): `BiomeRegistry.blended_foliage_tint` multiply
   for assets with `tintable = true`. Kept **moderate**: KayKit foliage is single-mesh
   (verified — one primitive, one material), so strong multiplies tint trunks too; true
   recolors belong to layer 3. The foliage tint shader generalizes to take each pack's
   albedo atlas (today it hardcodes the KayKit atlas).
3. **Palette variants** (bake time, discrete): separate catalog entries on shared meshes
   with different baked materials (§3.3), biome-weighted per instance — e.g. the
   blossom-grove pink tree. Instanced **structures** default to `tintable = false`
   (native albedo; atmosphere/fog already grades them).

---

## 6. Content plan — phases and the new asset waves

Engineering phases 0–1 build the system; content waves 2–4 add the requested assets
(paths verified on disk 2026-07-16). Each wave = manifest + bake + catalog tuning + QA
lineup; no engine changes expected after phase 1 except the phase-4 proposers/emitters.

### Phase 0 — storage migration (no visual change)
- Bake all KayKit foliage (including currently-orphaned variants) + the 6 cliff pieces +
  atlas material; create catalog entries; `TerrainChunkMesher`/`CliffDressing`/`SlopeAtlas`
  read baked resources; delete `terrain/gltf/`, `terrain/scenes/`, the `Sockets` remnants,
  and `FOLIAGE_SCENES`.
- `DecorationScatter`'s algorithm is untouched → placements byte-identical (parity test on
  fixed seeds + before/after screenshots).
- Self-containment guard test lands; verified by moving `assets/` aside and running the
  suite + streaming harness.

### Phase 1 — placement engine
- `DecoField` + rules + placed-index/occupancy; catalog sugar compilation; existing four
  tags ported to per-asset affinities reproducing today's look (tuned by eye, not parity).
- **Water gate fixed:** per-candidate `WaterDepthTerm` against the chunk's `WaterField`
  (the streamer already computes it per chunk on the worker; deco compute consumes it).
  `Helper.is_water` + `_is_water_raw` deleted (the deco gate is their last consumer).
- Per-instance variation tint (layer 1). `compute_decorations` leaves the mesher;
  placement QA teleport battery established (review_teleports pattern).

### Phase 2 — nature wave (batched; clusters, water bands, variants live)

| Assets (verified) | Path | Placement notes |
|---|---|---|
| Grass_01–07 | `LowPolyFantasyVillage/Models/Nature/` (.glb) | dense scatter, meadow/forest affinity |
| Mushroom_01–07 | same | `ClusterTerm` clumps; forest/marsh; shade bias via forest affinity |
| Tree_01–10 | same | grove clustering; species-split affinities across biomes |
| Flowers/Plants/Reeds/Stumps/Logs/Rocks (opportunistic) | same | zero marginal machinery; **Reeds_01** debuts `ShorelineProposer` (the cattail rule) |
| SFV_Lily_Pads_001 (+ Lily_Pad_001–003) | `FantasyVillageFBX/FBX/Nature/Lilypads/` | `FLOATING`: wet, still water (current-speed cap), Y = water level, marsh/pond affinity |
| Pink-canopy tree variant | KayKit colorway or baked recolor | `variant_group` demo: blossom-grove-heavy affinity |

LPFV is .glb with per-model textures — the bake merges each model's texture into its baked
material (or a small merged atlas per family if material count gets silly; bake-tool
detail, not an engine concern).

### Phase 3 — props wave (instanced, collision, quantized, exclusion live)

| Assets (verified) | Path | Placement notes |
|---|---|---|
| SFV_Light_Pole_001/002 (+ Lamp) | `FantasyVillageFBX/FBX/Exterior Props/Light Pole/`, `.../Lamp/` | rare; near-path/flat; footprint 1×1 |
| SFBP_Wagon_003 (+ carts opportunistically) | `BattlePackFBX/FBX/Wagons and Carts/` | flat footprint ~2×1; `ExclusionTerm` vs structures |
| SFWC_* workstations (Alchemy, Astronomy, Forge, Geologist, Herbalism, Kitchen, …) | `CraftingFBX/FBX/Workstations/` | rare clusters (camp feel); flat; footprint per AABB |
| SFBP themed tents (Armory, Deposit, Dormitory 1/2, Forge) | `BattlePackFBX/FBX/Tents/Themed Tents/` | flat footprint; grouped via shared `ClusterTerm` channel until stamps land |

Note: the light poles are FantasyVillage (`SFV_`), not BattlePack as first listed — path
corrected above.

### Phase 4 — settlements & spans (stamps + site search)

| Assets (verified) | Path | Placement notes |
|---|---|---|
| Themed market stalls (Alchemy, Armory, Bakery, Butcher, Fabric, Fishmonger, Forge, Fruits, Tavern) | `FantasyMarketFBX/FBX/<Theme> Stall/Stall/` | **market stamp**: stall row + props |
| SFV Buildings | `FantasyVillageFBX/FBX/Buildings/Buildings/` | village stamps; `FLAT_FOOTPRINT` |
| SFV_Windmill_003 | `FantasyVillageFBX/FBX/Windmill/` | lone-hill POI anchor |
| SFFA_Building_001 (forge) | `ForgeFBX/FBX/Forge Building/` | POI anchor |
| SFT_Building_003 (tavern) | `TavernandKitchenFBX/FBX/Building/` | village/POI stamp slot |
| SFV_Arch_001/002, Entrance Arch | `FantasyVillageFBX/FBX/Exterior Props/Arch/` | settlement-entry stamp slots |
| SFV_Bridge_001 | `FantasyVillageFBX/FBX/Exterior Props/Bridge/` | `GapSpanProposer`: opposing same-storey rims, span in range, water below preferred |

New machinery in this phase only: `AnchorGridProposer`, `StampEmitter`/`DecoStamp`,
`GapSpanProposer`. **Held-back question, decided here:** whether buildings flatten terrain
under their footprint (a `HeightfieldPlan` override stamp) or only place on naturally flat
ground — this touches the heightfield and gets its own mini-design at phase-4 start.
(LowPolyFantasyVillage `Landscape/Plane*` dropped from scope — owner 2026-07-16.)

### Per-wave QA
- Scale/pivot audit: bake records AABBs; a lineup harness (evolved from the existing
  `test_allpacks.tscn`) renders each wave beside the character for eyeball checks.
- Placement QA: pinned-seed teleport battery per wave (mirrors `review_teleports.json`
  falsification workflow).

---

## 7. Testing

- **Determinism:** identical placements for identical `(seed, chunk)`; adjacent chunks
  agree in the shared halo (evaluate both, compare); no wall-clock/`randi` anywhere.
- **Term unit tests:** each term pointwise against synthetic contexts (fake water depths,
  slopes, placed-indexes) — water policies, slope policies, exclusion ordering assert.
- **Occupancy:** footprints never overlap; bitmap matches emitted structural poses;
  quantized poses sit on 2 m centres with 90° yaws.
- **Catalog integrity:** every catalog entry loads; meshes/materials non-null; **no
  dependency under `res://assets/`** (the self-containment guard, §3.4).
- **Phase-0 parity:** old-vs-new decoration transforms byte-identical on fixed seeds.
- **Perf:** `profile_terrain` harness before/after each phase; MultiMesh count per chunk
  reported (expected same order as today: only assets present in a chunk get batches).
- Visual: wave lineups + teleport batteries as above; regressions handled with the
  red-first falsification workflow from AGENTS.md.

## 8. Performance notes

- Batched path is unchanged in kind; batch count grows with *present* variants per chunk,
  not catalog size. Monitor via the profile harness; if it ever matters, merge per-family
  meshes at bake time (bake-tool change, zero engine change).
- Rule evaluation is per-candidate hash math + O(1) field lookups; the placed-index is a
  coarse point grid. Expected cost is a small fraction of the mesher's existing work.
- Instanced structures instantiate on commit (main thread) under `MAX_BUILD_PER_FRAME`;
  if a village stamp spikes a frame, stagger instantiation across frames within the
  existing commit budget (streamer already owns this pacing).
- Catalog resources warm on the main thread before the worker starts (extends
  `prepare_resources()`), keeping lazy loads out of the worker.

## 9. Deletion checklist (end state)

- `terrain/gltf/**`, `terrain/scenes/**` — deleted (phase 0).
- `TerrainChunkMesher.FOLIAGE_SCENES`, `_foliage_pieces`, `compute_decorations` — deleted
  (phases 0–1); the mesher meshes terrain, nothing else.
- `Helper.is_water`, `Helper._is_water_raw` — deleted (phase 1).
- `BiomeProfile.tag_weights` — retired in favour of per-asset affinities (phase 1).
- `DecorationScatter.gd` — absorbed into `DecoField`/rules (phase 1).
- `assets/**` — deleted from the working tree once all planned waves are baked (any later
  re-bake restores it from git history or re-download). Optional, separate: purge from git
  history / move to LFS for repo size.
- Root-level exploration strays (`test_allpacks.tscn`, `var_tour.gd`) — superseded by the
  lineup harness under `tests/harness/`.

## 10. Deferred decisions

- **Buildings vs terrain:** flatten-under-footprint (heightfield override stamp) vs
  natural-flat-only placement — decided at phase-4 start with its own mini-design.
- **Combat consumption of the occupancy bitmap** (API/format) — when combat lands; the
  bitmap + region levels are the agreed inputs.
- **Git history purge of `assets/`** — hygiene, non-blocking, separate task.
- **LOD/HLOD for dense waves** — only if the profile harness says so.
