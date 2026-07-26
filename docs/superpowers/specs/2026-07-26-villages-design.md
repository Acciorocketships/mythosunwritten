# Villages (v1) — Design Spec

**Date:** 2026-07-26
**Status:** Draft for owner review.
**Scope:** The second slice of the master design's settlement-and-path layer (§11.6): a
deterministic **village content pass** that consumes the existing `SettlementPlan` site
identities and `PathPlan` plazas/routes and populates them with **enterable buildings,
market structures, and a multi-level deck district** built from the eight `assets/*FBX`
packs. Villages never reshape terrain; elevation comes from structure (stilts, decks,
stairs). NPCs, door interaction, interior enrichment, and military camps remain out of
scope (§9).

---

## 1. Decisions

| Question | Decision |
|---|---|
| Village identity | Consume `SettlementPlan.site_for` `{id, cell}` and `PathPlan.node_for` validation unchanged. The village pass adds content around the existing 16 m plaza; it introduces no new site logic and no second planner |
| Terrain reshaping | None, reaffirmed. Every lot/support validates against natural terrain and is **skipped on failure** (no retry). Decks and stilt platforms stay level while support lengths absorb relief — elevation comes from structure, not flattening |
| Size tiers | Rolled from the settlement id hash: **hamlet** (~50 %), **village** (~35 %), **town** (~15 %). Each tier is a district composition (§4.1); failed lots shrink a village gracefully, never abort it |
| Theme | Per-village roll: **blue** or **orange** roof family for prefabs, composed roofs, and awning tents, plus matching accent props. One theme per village |
| Districts | **Dense core** (towns; single-alley mini-core in villages) + **open ring** (all tiers) + **outskirts** (tents, fences, campfires). Different vibes by construction, not by accident |
| Interiors | Furnished `_Interior_` prefab variants baked whole; players walk in through open doorways. Door leaves, door interaction, and extra interior dressing are deferred |
| Second level | Two deck tiers: **3.7 m** (S-trestle tier, composed-house upper doors) and **4.8 m** (M-trestle tier, stilt blocks). One connected web per core: minimum spanning tree over mandatory anchors + seeded loop edges, **≥ 2 ground descents**, BFS-verified walkability |
| Stilt blocks | M-trestle grid + `SFBP` deck field carrying a full house, railed apron, stairs; **market stall undercroft** beneath (4.6 m clearance fits the 3.4–4.0 m stalls). S-tier undercrofts are passage/crate-only |
| Composed buildings | A scoped storey grammar on the SFV modular kit: rectangular footprints from {3.0, 4.5, 6.0} × {4.5, 6.0} m, 1–3 storeys × 3.0 m, optional 0.75 m jetty on L-supports, rock or wood ground storey, ≤ 1 door per storey (upper doors only where a deck cell docks), gable + theme roof. Hollow shells with plank floors in v1 |
| Decision ownership | `VillagePlan` (worker-owned, LRU by settlement id) owns layout, lots, deck web, and reservations; it is **invoked by `PathPlan`** during context projection, like `PathRouteSolver` — no sibling planner, no feature-specific streamer dependency |
| Exclusion & ground paint | Village pads, streets, aprons, and support cells join the existing `PathContext` reservation/corridor union. `clearance_at` suppresses dressing/grass; `corridor_at` paints worn ground through the existing mesher path — zero new plumbing |
| Placement & commit | Structures emit through the existing `EnvironmentInstancePayload` → 192 m feature blocks → `EnvironmentCommitQueue` (MultiMesh) + `EnvironmentCollisionBuilder` (StaticBody). The feature halo is raised to cover the largest structure footprint |
| Collision | Merged prefab buildings: new **`building_trimesh`** profile (`ConcavePolygonShape3D`, backface on) — exact doorways and interiors with zero authoring. Modular kit: per-piece boxes/ramps via profiles; **authored sources only for door-wall pieces** (jambs + lintel keep the opening). Nature-tag simple-shape policy is untouched (buildings tag `building`, not `rock`) |
| Bake | New **`merge_pieces`** manifest option collapses multi-mesh prefabs (167–338 MeshInstance3Ds per SFV house) into one ArrayMesh; kit pieces bake individually and MultiMesh-instance across the whole village. All packs bake at **scale 1.0** (authored human scale; doors 0.8 × 2.3 m) |
| Pack usage arc | v1 manifests: FantasyVillage, TavernandKitchen, Forge, Alchemy, BattlePack (platform kit + plain tents), FantasyMarket. InteriorPack + Crafting → interior-enrichment pass; themed battle tents + palisade + banners → camp POI pass (§9) |

Measured raw-scale AABBs that drive the numbers above:

| Asset | Size (m, W×H×D) | Role |
|---|---|---|
| `SFV_Building_Interior_*` (6 designs × 2 colors) | 11.6×10.9×16.3 … 18.5×16.2×18.8 | furnished enterable houses |
| `SFT_Building_001..004` | 39.3×28.3–34.3×28.9–32.3 | one grand tavern (variant chosen at probe) |
| `SFFA_Building_001` | 18.8×15.9×22.3 | forge |
| `AWS_Building_003` | 14.6×18.0×14.8 | alchemist (furnished) |
| `SFBP_Tent1..6` | ~7.9×7.2×8.5 | plain walk-in tents |
| `SFM_*_Stall` (+17 color variants) | 4.5×4.0×3.2 | market stalls |
| `SFV_Tent_{Blue,Red,White}` | 4.2×3.5×3.0 | awning tents |
| `SFV_Windmill_001/002` | tower 27.3×73.1×28.2; rotor separate | town landmark (static v1) |
| `SFBP_WWall_Floor_001..004` + corners | ~4.0×0.22×2.5 | deck field modules |
| `SFBP_WWall_Floor_Support_M/S` | 8.0×**4.79**×2.8 / 3.8×**3.72**×2.5 | trestle tiers → deck heights 4.8 / 3.7 |
| `SFV_Wall_Wooden_{S,M}` | 1.5/3.0 × **3.0** × 0.5 | kit module & storey height |
| `SFV_Floor_{S,M,L}` + planks | 1.5×1.5 / 3×1.5 / 3×3; planks 3×0.75 | kit floors & catwalks |
| `SFV_Stair_S` + `SFV_Stair_Floor_M` | 1.45×**1.55**×1.5 + landing | half-storey flights, chained |
| `SFV_Wall_LSupport_{S,M,L}` | up to 4.26×0.55×4.26 | cantilever braces (jetties, wall-hung decks) |
| `SFV_Well`, `SFV_Quest_Board` | 3.9×4.3×3.3 / 2.2×2.1×0.5 | plaza civic props |

## 2. Invariants

1. A village layout is a **pure function of `(world_seed, settlement_id)`**. All planning
   runs on the streamer worker against CPU-side fields; only existing main-thread commit
   adapters create meshes, shapes, or nodes. No RenderingServer access from the worker.
2. The heightfield is never mutated. Validation is **accept-or-skip**: a lot, support,
   span, or descent that fails its check disappears; nothing retries or force-fits.
3. Runtime resources never reference `res://assets/`; `tools/environment_bake/` remains
   the only owner of source-pack paths.
4. **Walkability:** every emitted walk surface (deck, apron, stair, landing, threshold)
   meets its neighbours within the 0.5 m step limit; every deck web is one connected
   component with ≥ 2 ground descents; no span or support intersects building collision
   or blocks an alley below 2.0 m clear passage.
5. The `PathContext` reservation/corridor union is the **single source of truth** for
   suppression and ground painting; dressing, grass, and the mesher read it unchanged.
6. Every placed structure carries a **stable id** derived from `(settlement_id, slot)`,
   preserving the adoption path for persistence/NPC layers.
7. Determinism is chunk-order independent: instances are owned by the 192 m block
   containing their anchor; any chunk that computes a village recomputes it identically.

## 3. Assets and bake

### 3.1 Bake tool extensions (`tools/environment_bake/environment_bake.gd`, TOOL_VERSION 15 → 16)

- **`merge_pieces: true`** (per asset): after correction transforms, merge every
  `MeshInstance3D` into one ArrayMesh, combining surfaces that share a material (each
  pack is a single-atlas pack, so prefabs land at 1–2 surfaces). Without this, one SFV
  house would commit as 167 MultiMeshes.
- **`collision_profile: "building_trimesh"`**: one `ConcavePolygonShape3D` from the
  merged triangle soup, `backface_collision = true`. Applied to prefab buildings and
  walk-in tents only.
- **`collision_profile: "ramp_box"`**: one oriented box fitted to the stair run so
  chained flights read as smooth ramps under `move_and_slide`.
- Deck/floor pieces use the existing `flat_box` profile (walkable, full footprint);
  trestles/pillars/handrails/stall frames use `convex` or authored boxes where the fit
  is poor. **Door-wall kit pieces** get authored collision sources (jambs + lintel), the
  arch-gate pattern — the only hand-authored scenes in v1 (≈ 6–8 pieces after dedup).
- Manifest hygiene: the SFV door-wall folder ships duplicate exports
  (`_001`, `_001_1`, `_001__1`); manifests reference one canonical file per design.
- Repo cost: expect roughly 100 MB of committed baked meshes across ~70 structure and
  kit assets. Accepted; flagged here so it isn't a surprise at review.

### 3.2 Catalog additions

New tags: `building`, `tent`, `stall`, `deck`, `stair`, `support`, `railing`,
`landmark`, `village_prop`. Catalog tests extend to: every `building`/`deck`/`stair`
asset has collision; `building_trimesh` is permitted only on `building`/`tent` tags;
id sort, collision counts, and the no-`res://assets/` scan apply as today.

### 3.3 v1 manifests

`fantasy_village_structures.json` (houses, tents, windmill, wells, quest boards, signs,
fences, carts, planters, ivies, hanged clothes, bird houses, modular kit, stairs,
floors, pillars, L-supports), `battle_pack_platforms.json` (deck floors + corners,
trestle supports, ladder, plain tents, campfires, wagons, barrels, crates),
`tavern_kitchen.json` (tavern + chimneys + signs), `forge_armory.json` (forge +
chimney + signs), `alchemy_workshop.json` (alchemist buildings), `fantasy_market.json`
(base + themed stalls, color variants, string lights, market props).

## 4. Layout

`VillageProgram` (main-thread compile, mirrors `PathProgram`): per-asset authored
metrics — footprint, door offset/facing, sink depth, max support span, category, tier
weights — plus module constants: `MODULE = 1.5`, `STOREY = 3.0`,
`DECK_TIER_LOW = 3.7`, `DECK_TIER_HIGH = 4.8`, alley vocabulary `{3.0, 4.5, 6.0}`,
`UNDER_CLEARANCE_MIN = 2.0`.

`VillagePlan` (worker, LRU by settlement id) runs stages in order; every stage is pure
and independently testable:

1. **Rolls** — tier, theme, and layout salts from `Helper._mix64(world_seed, settlement_id)`.
2. **Frame** — plaza cell, incoming road tangents from `PathContext` connection masks;
   dominant axis picks the main-street direction; the flattest dry quadrant (scored like
   `SettlementPlan._compute_site`) hosts the dense core.
3. **Open ring** — civic anchors on the plaza rim (well, quest board; stalls and awning
   tents facing the plaza), tavern/forge/alchemist on plaza-facing lots, prefab houses
   along street spurs with jittered setbacks and door-to-street orientation. Per-lot
   validation: support span ≤ authored limit (≈ 1.0 m houses, 1.2 m tavern), dry, clear
   of roads/reservations; structures sink 0.25–0.35 m to bury bases on minor slope.
4. **Dense core** (town: 2–3 alleys; village: 1) — module-grid rows of composed houses
   and prefabs packed at 0.5–1.5 m side gaps with jittered setbacks; alley widths drawn
   from the vocabulary so every gap is spannable by construction; stilt lanes (6.0 m)
   host 1–2 stilt blocks per town.
5. **Stilt blocks** — M-trestle grid at deck pitch, SFBP deck field, one prefab house
   (the smallest SFV designs) or composed house on top with railed apron; stall undercroft beneath
   (M tier only); ≥ 1 stair chain to ground.
6. **Composed grammar** — storey stacks per §1; upper doors only where step 7 can dock
   a deck cell, else demoted to windows.
7. **Deck web** — mandatory anchors: stilt aprons, composed upper doors, tower hub
   (towns). Candidate graph: wall-hugging deck runs (cantilevered) + trestle-supported
   runs + catwalk spans (3.0–8.0 m) + SFV bridge spans (to 10.5 m). Solve MST over
   anchors, add loop edges at a seeded probability (path-network precedent), prune
   stubs. Place descents — stair chains (`Stair_S` × 2–3 + landings) and
   **terrain-assisted exits** where a deck edge meets an uphill terrain storey —
   until ≥ 2 per web; ladders are extra. Threshold planks (0.16 m) quantize any seam
   over the step limit. Handrails line open deck edges.
8. **Props & dressing** — per-building attachables from the building's slot seed
   (sign, planter, ivy, hanged clothes, bird house), plaza set (string lights between
   poles, benches/carts/barrels), street furniture (direction signs at spur mouths,
   reuse of `sfv.light_pole.001` lamps), outskirt tents + campfires + fence runs.
9. **Emit** — placements payload + reservation/corridor shapes + stable ids.

**Degradation ladder:** failed stilt lane → extra composed row; failed core → open-ring
village; failed anchors reduce the web toward zero (no web is legal for hamlets); a
site that validates nothing beyond the plaza remains today's plaza-only node.

## 5. Integration

- **`PathPlan._project_context`** invokes `VillagePlan.layout_for(node)` and merges
  village reservations/corridors and placements into the `PathContext` it already
  builds. `PathContext`'s public API is unchanged; `placements()` now includes village
  instances near the chunk.
- **Mesher/dressing/grass:** no changes — suppression and worn-ground painting arrive
  through the existing clearance/corridor queries.
- **Streaming:** `PathProgram.feature_halo` derives from the max structure footprint
  (tavern 39 m, windmill 28 m) instead of the current bridge constant; blocks own
  instances by anchor as today. New building visuals join the pre-warm set in
  `FieldTerrainStreamer._ready` before the worker starts.
- **Commit order** is untouched: collision before readiness, MultiMesh visuals budgeted
  behind it. Deck/stair collision commits with its feature block exactly like props.

## 6. Verification

**Unit (GUT, headless):** `test_village_program` (metrics compile, tier tables, module
constants), `test_village_plan` (determinism across recomputes; pad validation; zero
overlap between pads/roads/water; sink bounds; theme consistency),
`test_village_building_grammar` (storey stacks legal, upper doors only with docks,
piece counts), `test_village_deck_solver` (**BFS walkability: single component, ≥ 2
descents, all seams ≤ 0.5 m, spans clear of structure footprint AABBs, ≥ 2.0 m
under-deck passage**), `test_village_context` (reservations suppress dressing/grass; corridors
paint; payload block ownership), catalog test extensions (§3.2).

**Statistical corpus** (`tests/harness/village_corpus.gd`): N seeds × M sites →
tier distribution, buildings per tier, lot rejection rates, deck-web size/connectivity/
descent counts, overlap violations (must be 0), grammar composition stats. Thresholds
gate like `path_corpus.gd`.

**Visual battery:** `environment_lineup.tscn -- --show-collision` review of every baked
structure; new `tests/harness/village_review.tscn` + `review_villages.json` pinned-seed
vantages (plaza, alley canyon, deck web, stilt undercroft, descent, skyline); a
walkthrough falsification pass on the pinned seed (enter every building type, climb
every descent, cross every catwalk); `profile_terrain.gd` sweep with a village in
radius to hold the frame/streaming budget on the M1 Pro baseline.

## 7. Delivery phases

- **Phase 0 — probe (go/no-go):** bake one house, the tavern, one plain tent, one
  stall, and a hand-composed rig (stilt block + 2-storey composed house + catwalk +
  stair chain + terrain-assisted exit) at one pinned settlement. Verify: doorway steps
  ≤ 0.5 m, trimesh interiors walkable, deck seams/shims, stall undercroft clearance,
  tavern variant choice + scale feel, draw calls/physics cost. Freeze `DECK_TIER_*`,
  sink depths, and shim rules from measurements.
- **Phase 1 — bake:** tool extensions (§3.1), six manifests, catalog tags + tests,
  lineup review of all ~70 assets.
- **Phase 2 — planning core:** 2a open-ring + tiers/themes/frame; 2b deck-web solver;
  2c composed-building grammar. Unit tests + corpus green, headless.
- **Phase 3 — integration:** `PathPlan`/`PathContext` merge, halo derivation, pre-warm,
  commit path, exclusion verification in-game.
- **Phase 4 — props & QA:** prop passes, review harness + vantages, falsification
  battery, corpus thresholds tuned, profiling gate.
- **Phase 5 — polish:** windmill rotor idle spin (single animated node case), chimney
  smoke via existing FX hooks, interior ambience check, **camera behaviour in alleys
  and under decks** (named work item), balcony docks against prefab windows.

## 8. Risks

| Risk | Mitigation |
|---|---|
| Trimesh interiors misbehave (seams, sliding) | Phase 0 walkthrough; authored-box override path stays available per asset |
| Doorway/threshold steps exceed 0.5 m | Probe measures every family; sink depth + threshold planks; worst case authored ramps |
| Auto-composed scaffolding reads as noise | Dedicated review vantages; corpus caps on span lengths/support density; jitter bounds |
| Third-person camera in 3 m alleys under decks | Named Phase 5 item; alley vocabulary keeps a 3 m minimum |
| Tavern (39 m) dwarfs neighbours | Town-only, plaza-adjacent placement; probe confirms scale feel before roster lock |
| Feature halo growth costs streaming time | Halo derived from measured footprints only; profile gate in Phase 4 |
| Repo grows ~100 MB of baked meshes | Flagged in §3.1; prune unused variants at Phase 1 review |

## 9. Explicitly deferred

Door leaves + open/close interaction; furnished interiors for composed houses and any
interior-enrichment dressing (InteriorPack, Crafting, scene-prefab vignettes); military
camp POI (themed battle tents, palisade kit, banners, siege props); watermills
(requires settlement–water adjacency the current 108 m clearance forbids) and riverside
features; second deck tier at +8–9 m; buildings stacked on multi-storey platforms
beyond stilt blocks; NPC habitation, navigation/navmesh, quest-board content; a
spawn-adjacent guaranteed village; far-landmark impostors for the windmill.
