# Biomes, Atmosphere & Asset Backend — Design

**Date:** 2026-07-04
**Status:** Approved (brainstorm 2026-07-04)
**Depends on:** field-driven terrain (2026-06-26), cliff dressing (2026-06-27)
**Master design:** §11.3 (biomes), §11.9 (lighting & atmosphere), §11.11 (asset libraries)

## Summary

Three tightly-coupled pieces, one spec:

1. **Named biomes** — a moisture axis and two sparse pocket fields join the
   existing `forest`/`rocky` noises; a resolver turns them into five normalized
   biome weights per world position. Each biome is a `BiomeProfile` resource:
   atmosphere, palette, scatter, and particle data in one place.
2. **Atmosphere** — a fixed time-of-day render grade (warm key light,
   warm-neutral ambient, bloom, tilt-shift DoF) plus per-biome fog/sky/ambient
   blended continuously at the camera, and local `FogVolume`s over pocket
   biomes so the twilight marsh reads as a visible mist bank from outside.
3. **Asset backend refactor** — a single `AssetCatalog` replaces the two
   hard-coded tag→scene dicts; instantiation moves out of the mesher into a
   `DecorationPlacer`; scatter composition finally consumes biome weights;
   dead scenes and stale variant lists are removed.

Decisions locked during brainstorm: all five biomes in v1; fixed time of day
(no cycle, profiles hold exactly one atmosphere); approach B for atmosphere
(camera blend + pocket fog volumes); no per-biome asset **size** variation —
current models are placeholders and biome identity comes from **tint**, not
scale; no new asset pack purchases — everything sources from packs on disk.

### Goals

- Five named biomes: **meadow** (spawn), **deep forest**, **highland**,
  **blossom grove**, **twilight marsh** (scattered pocket, distance-independent).
- Deterministic: every new field is a pure function of `(pos, world_seed)`;
  the heightfield is untouched — this spec changes color, air, and props,
  never terrain shape.
- Crossing a biome border smoothly shifts fog, sky, ambient, ground tint,
  foliage tint, and scatter composition.
- The cozy-diorama grade from master §11.9: cool ambient vs warm key, bloom
  on emissives, tilt-shift DoF, soft long shadows.
- One catalog as the only place that maps asset tags to scenes; game code
  references tags, never `res://assets/...` paths.
- Headless mode generates identical worlds with zero render nodes.

### Non-goals (v1)

- Dynamic GPU grass (§11.8 — own spec; static grass scenes stay for now).
- Settlements, paths, bridges, water-bank dressing (§11.6, water spec).
- Day/night cycle; per-biome asset size distributions (dropped — placeholders).
- MultiMesh batching for foliage (catalog reserves a `kind` field so it can
  be added later without another refactor).
- Buying missing packs (Medieval Hexagon, City Builder Bits, Halloween Bits,
  Fantasy Weapons / RPG Tools / Board Game Bits are explicitly not needed).

---

## 1. Fields & biome resolution (`Helper.gd`)

Existing axes unchanged: `biome_forest01` (scale 190), `biome_rocky01`
(scale 150). New fields, same value-noise machinery, all pure `(pos, seed)`:

| Field | Scale | Shape | Role |
|---|---|---|---|
| `biome_moisture01` | ~230 | smooth 0..1 | §11.2 moisture/mood axis; boosts marsh, later gates reeds & decorative ponds |
| `biome_blossom_pocket01` | ~260 | `smoothstep(0.78, 0.90, noise)` | sparse blossom-grove cores (~4–6% of area) |
| `biome_marsh_pocket01` | ~300 | `smoothstep(0.82, 0.92, noise + 0.15·moisture)` | rarer marsh hollows (~2–4% of area), anywhere on the map |

Thresholds are starting values; the GUT census test (§10) pins the target
area fractions so tuning stays honest.

**Resolver** — `Helper.biome_weights5(pos, seed) -> Dictionary[StringName, float]`:

```
marsh    = marsh_pocket01                      # pockets claim their share first
blossom  = blossom_pocket01 * (1.0 - marsh)
rest     = 1.0 - marsh - blossom
forest   = forest01 * rest                     # existing axes split the rest
highland = rocky01 * (1.0 - forest01) * rest
meadow   = rest - forest - highland            # baseline; ≥ 0 by construction
→ normalize all five to sum exactly 1.0
```

Pocket cores saturate to ~1 (their smoothstep tops out), so inside a marsh
the other weights vanish; at pocket rims everything cross-fades organically.

- `Helper.biome_at(pos, seed) -> StringName` — argmax of the five; used for
  discrete decisions only (fog-volume placement, F3 readout, future prop sets).
- `Helper.biome_weights` (tag multipliers) and `biome_foliage_density` are
  **re-expressed over the five named weights** by summing
  `profile.tag_weights` / `profile.foliage_density` weighted by biome weight.
  Meadow/forest/highland profiles start with values matching today's output
  so current terrain reads the same before tuning.

## 2. `BiomeProfile` + `BiomeRegistry`

`scripts/terrain/biome/BiomeProfile.gd` (`Resource`), one `.tres` per biome
in `terrain/biomes/`:

```gdscript
class_name BiomeProfile extends Resource
@export var biome_name: StringName
# atmosphere
@export var fog_color: Color
@export var fog_density: float
@export var pocket_fog_density: float      # 0 = no local FogVolume
@export var sky_top: Color
@export var sky_horizon: Color
@export var ambient_color: Color
@export var ambient_energy: float
# palette
@export var ground_tint: Color
@export var foliage_tints: Dictionary[StringName, Color]   # tag → tint
# scatter
@export var foliage_density: float
@export var tag_weights: Dictionary[StringName, float]     # tag → weight
# particles: recipe → density; multiple allowed (marsh = orbs + fireflies)
@export var particles: Dictionary[StringName, float]
                                  # recipes: &"fireflies" | &"petals" | &"motes" | &"orbs"
```

`scripts/terrain/biome/BiomeRegistry.gd` (static): name → profile lookup and
`blend_atmosphere(weights) -> Dictionary` — a pure function returning the
weight-blended fog/sky/ambient parameters, unit-testable without a scene tree.

Starting palettes (from the approved mood cards; all tunable in the `.tres`):

| Biome | sky top | fog | ground tint | canopy tint | accent |
|---|---|---|---|---|---|
| Meadow | `#8EC9E8` | `#DCEBDD` (thin) | `#7FBE4E` | `#5FA045` | `#E8C84A` |
| Deep forest | `#6E93A8` | `#557567` | `#3D6B33` | `#2E6B3A` | `#C96A32` |
| Highland | `#A8BCC8` | `#C2CCC9` | `#8AA07E` | `#6E8B62` | `#98A0A8` |
| Blossom grove | `#C8D8F0` | `#F2DCE8` | `#8FC470` | `#F2AECB` | `#F6C6DA` |
| Twilight marsh | `#2A3560` | `#24505C` (dense + pocket) | `#2E5E52` | `#1F4A44` | `#FFB347` (orbs) |

## 3. `AtmosphereDirector` + fog pockets

New node in `world.tscn` (`scripts/terrain/biome/AtmosphereDirector.gd`),
owning references to the `WorldEnvironment`, `DirectionalLight3D`, and the
camera's `CameraAttributes`.

- Every **0.2 s** it samples `biome_weights5` at the camera target, calls
  `BiomeRegistry.blend_atmosphere`, and eases the Environment's fog color/
  density, sky top/horizon, and ambient color/energy toward the result over
  ~1 s. Continuous fields ⇒ border crossings are automatic crossfades.
- **Pocket fog:** when `FieldTerrainStreamer` builds a chunk whose dominant
  biome (`biome_at` at chunk centre) has `pocket_fog_density > 0`, it adds a
  box `FogVolume` as a child of the chunk node — chunk-sized in XZ, spanning
  a vertical band around local ground (≈ min surface −4 u to max surface
  +20 u) — streaming in/out with the chunk, no extra lifecycle code. Environment volumetric fog is ON
  with near-zero global density, so only pocket volumes contribute. Marsh
  gets dense teal; deep forest optionally a light haze (tunable, may be 0).
- **Headless:** the director frees itself (and the streamer skips fog/particle
  children) when `DisplayServer.get_name() == "headless"`.

## 4. Tinting

- **Ground:** `TerrainChunkMesher` writes per-vertex `COLOR` = blended
  `ground_tint` sampled at each grid vertex (3 u resolution → smooth spatial
  gradients across borders). The walkable sheet gets `ground_tinted.tres` —
  a duplicate of the shared KayKit-derived material with vertex-color
  multiply enabled. Cliff walls/lips/skirts keep the original untinted
  material: rock reads as neutral rock in every biome.
- **Foliage:** one shared `foliage_tint.gdshader` `ShaderMaterial` (same
  albedo texture as the KayKit palette) with
  `instance uniform vec3 tint : source_color`. The placer sets each
  instance's tint from the blend at its position. One material for all
  foliage keeps batching; per-instance uniforms are cheap in Godot 4.
- Blossom grove needs **zero new tree assets**: blossom trees are KayKit
  trees with pink canopy tint (`foliage_tints[&"tree"]`).

## 5. Particles

Per-chunk `GPUParticles3D` children built by the streamer from the dominant
profile's `particles` dictionary — one emitter per recipe entry (emission box
= chunk bounds, amount ∝ density × area, visibility-culled, skipped headless):

- `fireflies` — small warm drifting points; marsh (high), deep forest (low).
- `petals` — pink quads with lateral drift; blossom grove.
- `motes` — faint dust; meadow & highland at low density.
- `orbs` — twilight marsh signature: larger, slow, emissive spheres; a
  capped few (≤4/chunk) carry cheap `OmniLight3D`s so they genuinely light
  the murk under bloom.

## 6. Global grade (fixed time of day, applied once)

Constants live in one config block on `AtmosphereDirector`, applied at ready:

- **Key light:** warm color (~`#FFEACC`), lowered golden-hour angle, soft
  shadows (existing splits kept), long-shadow look.
- **Ambient:** warm-neutral (per master §11.9 — not sky blue), sky
  contribution reduced so shadowed rock still reads as rock.
- **Glow/bloom:** enabled, HDR threshold tuned so only genuine emissives
  bloom (orbs now; lanterns/windows in later specs).
- **Tonemap:** filmic (already set).
- **Tilt-shift DoF:** `CameraAttributesPractical` near + far blur bands tied
  to the camera rig's framing distance — the miniature-diorama read.
- **Volumetric fog:** enabled globally at ~0 density (pockets supply it).

## 7. Asset backend refactor

Explorer findings being fixed: tag→scene mappings duplicated across two
unrelated hard-coded dicts (`TerrainChunkMesher.FOLIAGE_SCENES`,
`CliffDressing.SCENES`); only 2–3 of 4–8 existing variants wired; variant
choice derived from the yaw hash (any list change reshuffles the world);
`Helper.biome_weights` computed but never consulted by scatter; mesher both
builds geometry and instantiates props; material derivation buried in
`_ensure_skirt_style` (mesher digs UVs out of KayKit meshes inline); dead
scenes and materials.

### 7.1 `AssetCatalog` (`scripts/core/AssetCatalog.gd`)

The **single** tag → asset mapping. Data is a catalog resource
(`terrain/asset_catalog.tres`), entries:

```
tag: StringName → {
  kind:     "scene"                        # "multimesh" reserved for later
  variants: [ { path, weight, scale } ]    # scale defaults 1.0 (pack mismatch fix)
}
```

- Static API: `variants(tag)`, `pick(tag, hash) -> PackedScene` (cumulative
  weights), `audit() -> Array[String]` (missing files, empty tags — the GUT
  integrity test calls this).
- Owns load-once scene caching (replaces per-instance `load()` in the mesher
  and the piece cache in `CliffDressing._ensure_loaded`).
- Cliff dressing pieces become tags too: `cliff_wall`, `cliff_lip`,
  `cliff_outer_wall`, `cliff_outer_lip`, `cliff_inner_wall`, `cliff_inner_lip`.
- v1 tags: `grass`, `bush`, `rock`, `tree`, `lantern`, `standing_stone`,
  the six cliff tags. **All** existing KayKit variants get wired (4 grass,
  6 bush, 6 rock, 8 tree — today's dicts use 2–3).

### 7.2 `DecorationPlacer` (`scripts/terrain/field/DecorationPlacer.gd`)

Instantiation moves out of the mesher. Pipeline becomes three clean stages:

```
DecorationScatter   position → tag        (pure; now consumes per-biome tag
                                           weights + density from profiles)
AssetCatalog        tag → PackedScene     (data; load-once cache)
DecorationPlacer    scene → instances     (node building, tint application)
```

- **Variant picking decoupled from yaw:** a dedicated hash over
  `(cell, slot, "variant")` selects by cumulative weight. Adding a variant or
  editing weights no longer reshuffles rotations or unrelated placements.
- The placer samples `biome_weights5` once per decoration position for the
  foliage tint instance uniform.

### 7.3 Cleanup checklist (explicit scope of "leave it cleaner")

- Delete after confirming zero references: `terrain/scenes/hill/*`,
  `terrain/scenes/base/*` (old socket system), `terrain/materials/forest.tres`.
- Remove `TerrainChunkMesher.FOLIAGE_SCENES` and all instantiation logic from
  the mesher; remove `CliffDressing.SCENES` + `_ensure_loaded` piece cache in
  favor of catalog lookups (its transform/rule logic is untouched).
- Extract shared-material derivation out of `_ensure_skirt_style` into a
  small `TerrainMaterials` helper (`scripts/terrain/field/TerrainMaterials.gd`)
  that CliffDressing and the mesher both call; the mesher stops introspecting
  KayKit mesh UVs inline.
- Replace `DecorationScatter.TAG_WEIGHTS` with profile-driven weights;
  delete the now-dead static dict.
- Audit `scripts/core/TagList.gd` and `scripts/core/Distribution.gd`; delete
  if orphaned by the socket-system removal (explorer suspects both).
- `assets/KayKitNature/.../Color{2,3,4}` stay on disk but a comment in the
  catalog notes Color1 is the canonical palette.

## 8. Asset integration plan (owned packs only)

### 8.1 This spec

| Source | Feeds | How |
|---|---|---|
| KayKit Nature | all-biome flora | wire all variants; biome identity via tint (meadow warm, forest dark, highland grey-green, blossom pink canopy, marsh teal-dark) |
| Forge & Armory `SFFA_Lantern_*` / LowPolyFantasyVillage lanterns | `lantern` tag | rare scatter in marsh + deep forest; warm emissive under bloom — the "lantern on a stump" reference beat |
| KayKit Dungeon stone pieces | `standing_stone` tag | highland clearings; implementation picks pieces that read outdoors |
| Alchemy / Crafting packs | possible marsh toadstools | implementation task: scan ~1,200 props for mushroom/plant meshes; if none fit, marsh v1 stands on tinted flora + orbs + fog |

Accepted v1 gaps: cattails/lily pads (arrive with water-bank dressing),
flower models (meadow uses accent-tinted grass tufts; petals stay particles).

### 8.2 Later specs (catalog is designed for these, not built now)

- **Settlements & paths:** Fantasy Village (buildings, windmills, bridges),
  LowPolyFantasyVillage (fences, wells, lantern posts, benches),
  Fantasy Market (stalls); Battle Pack carts/wagons/tents for roadsides.
- **Interiors:** Tavern & Kitchen, Interior Pack, Crafting, Alchemy.
- **Characters & items:** KayKit Adventurers/Skeletons + Character
  Animations; Forge & Armory + Battle Pack weapons/armor. Extract
  `~/Downloads/FantasyArmoryFBX.rar` so it isn't forgotten.

### 8.3 Import pipeline standards

1. Game code references **tags only**; raw packs live under `assets/<Pack>/`;
   wrapper scenes exist only where a prop needs collision or behavior.
2. **FBX:** try Godot's built-in ufbx import on Mistage packs first; if
   materials import wrong, one-time batch FBX→glTF conversion. One decision,
   applied uniformly, recorded in the catalog resource header comment.
3. **Material pass:** Mistage models get the same de-sheen normalization as
   KayKit (roughness up, metallic zeroed) via a shared utility at catalog
   registration, so everything sits in the cool-vs-warm grade.
4. **Scale audit:** per-entry `scale` in the catalog corrects KayKit↔Mistage
   mismatches in data, never by editing scenes.

## 9. Streaming, headless & determinism

- Fog volumes, particles, decorations are chunk children — streamed for free.
- `AtmosphereDirector` self-disables headless; streamer skips render-only
  children headless. Nothing here touches simulation or the heightfield:
  `surface_y` outputs are byte-identical before/after this work.
- All new fields are pure `(pos, seed)` statics — the existing anti-churn
  guarantee (any chunk computes identical results regardless of query order)
  holds.

## 10. Testing & debug

GUT (`test/terrain/`):

- `biome_weights5` sums to 1.0 (±1e-6), deterministic across repeated calls,
  and matches at chunk-boundary sample points regardless of evaluation order.
- Pocket census: sample a large grid; marsh fraction within 1–6%, blossom
  within 2–8% (loose bounds so tuning doesn't thrash tests).
- `blend_atmosphere`: pure; single-biome weight vector returns that profile's
  exact values; 50/50 vector returns midpoints.
- `AssetCatalog.audit()` returns empty: every tag ≥1 variant, every path
  loads, weights positive.
- All five profiles load with every export set (no default-white colors).
- Heightfield regression: pinned seed, `surface_y` sampled on a grid,
  identical before/after (this spec must not change terrain shape).

Tools & acceptance:

- F3 `CoordOverlay` gains `biome: <name> (m .62 f .21 …)` at player position.
- Visual acceptance: one pinned-seed screenshot per biome matching the
  approved mood cards; marsh fog bank visible from meadow distance; bloom
  only on orbs/lanterns.

## 11. Implementation order (suggested for the plan)

1. Asset backend first (catalog + placer + cleanup) — pure refactor, world
   looks identical after; heightfield + decoration-regression tests green.
2. Fields + resolver + profiles (+ scatter wiring) — composition/density now
   biome-driven.
3. Tinting (ground vertex color, foliage instance uniform).
4. Global grade + AtmosphereDirector blending.
5. Fog pockets + particles + orb lights.
6. F3 readout, census tests, screenshot pass.
