# Villages — Dense Vertical Urban-Fabric Design Spec

**Date:** 2026-07-26; revised 2026-07-28 after visual massing review
**Status:** Unified terrain-led urban fabric implemented; production-corpus visual
falsification and final closure remain in progress. The fixed three-level elevated
district is retained only as a migration source and is not used by production.
**Scope:** The second slice of the master design's settlement-and-path layer (§11.6): a
deterministic **village content pass** that consumes the existing `SettlementPlan` site
identities and `PathPlan` plazas/routes and populates them with **enterable buildings,
market structures, and a **compact terrain-led vertical town** built from a reviewed
subset of the source packs. Villages never reshape terrain; natural perches, retaining
walls, compact public platforms, short local links, foundations, stairs, and bounded
cantilevers make structures fit the natural field. NPCs, door interaction, interior enrichment,
animated feature nodes, and military camps remain out of scope (§9).

---

## 1. Decisions

| Question | Decision |
|---|---|
| Village identity | Consume `SettlementPlan.site_for` `{id, cell}` and `PathPlan.node_for` validation unchanged. The village pass adds content around the existing 16 m plaza; it introduces no second site planner |
| Planning ownership | A worker-owned **`WorldFeaturePlan`** composes `PathPlan` and `VillagePlan` into one `FeatureContext`. `PathPlan` remains the owner of routes; `VillagePlan` consumes a canonical, complete `VillageFrame` from it and never reads a block-local context |
| Canonical record | `VillagePlan.record_for(frame)` computes one immutable `VillageRecord`, cached by settlement id. The record contains the complete layout, exact world bound, ground shapes, placements, and stable ids; block projection only selects complete contributions and cannot make layout decisions |
| Terrain reshaping | None. Enterable ground floors sit above the highest terrain sample under their interior footprint; a generic foundation solver fills down to terrain. Fixed-size support modules reach upward from terrain without non-uniform collision scaling |
| Size tiers | Production rolls **village** (~85 %) or **town** (~15 %). Hamlet remains compiled authored vocabulary but is not selected until its grammar satisfies the inhabited multi-level contract. Each tier supplies bounded semantic lot slots; rejected slots disappear without shifting any other slot or id |
| Theme | Per-village roll: **blue** or **orange** roof family for prefabs, composed roofs, and awning tents, plus matching accent props. One theme per village |
| Districts | One compact **3D urban fabric**, not separate ground and elevated districts. The flat route landing may sit at its edge; buildings, alleys, terraces, platforms, and short links are solved together around a nearby natural-relief core. Sparse outskirts remain optional |
| Interiors | Furnished `_Interior_` prefab variants baked whole; players walk in through open doorways. Door leaves, interaction, and extra interior dressing are deferred |
| Traversal contract | A shared, resource-free **`TraversalEnvelope`** owns the canonical humanoid capsule, headroom, aperture, and step limits. Village validation, physics probes, and the player-scene contract test all consume the same numbers |
| Urban fabric | `VillageTerrainSurvey` discovers dry buildable perches and useful relief around the route landing. `VillageMassingSolver` packs all buildings into one bounded 3D occupancy volume; `VillageCirculationSolver` derives alleys, stairs, shared platforms, and local aerial links only after inhabited destinations exist |
| Platforms and paths | A compact platform is a piece of new public ground and must serve at least two inhabited frontages, or one civic frontage plus public activity. Building skirts exist only beyond actual support. Elevated paths connect nearby destinations, normally span at most 12–18 m, and prefer curved/bending centre-lines. No substantial uninhabited platform or long empty-air perimeter route may materialize |
| Elevation and support | Natural buildings retain their exact terrain-derived floor heights. Retained buildings use a compiled architectural profile: a full level must clear the tallest stackable furnished house plus roof clearance and is split into two exact module-aligned half levels (currently 12 m / 6 m). This produces irregular natural offsets and genuine half-level differences without confusing 4 m terrain storeys with building clearance. Support priority is natural shelf → compact rock retaining core → unsupported-only timber skirt/cantilever → sparse posts. Production requires ≥70% natural support and never creates tall empty stilt fields |
| Building vocabulary | Production uses reviewed complete furnished prefabs, not procedural hollow shells. The compact stackable family establishes vertical cadence; larger silhouettes are ground-only accents. The initial expanded roster uses four furnished designs across blue/orange variants. A future composed-building grammar may be added behind the same asset/occupancy contracts without changing the solver |
| Ground fields | Replace the path-specific projection internals with **`FeatureGroundField`**: the existing O(1) path-grid layer plus a bucketed shape layer. `surface_at` resolves ground paint by priority; `clearance_at` resolves the union's signed distance. Paths and villages use the same query path by construction |
| Layout occupancy | Planning uses a separate bucketed **3D occupancy index**. Ground exclusion, solid volumes, walk surfaces, and protected headroom are distinct data, so a deck over an alley or a stall under a platform is legal without weakening collision checks |
| Placement & commit | Static structures emit through `EnvironmentInstancePayload` into 192 m feature blocks. A generic **`FeatureCommitQueue`** demand-warms assets and incrementally commits collision before readiness, then budgeted visuals. No village code touches the scene tree |
| Collision | Enterable shells use reviewed complete collision; modular pieces use reviewed boxes/ramps/convex shapes. Compound prop proxies follow disconnected structural parts: the cooking spit uses cylinders, the tent uses a two-sided triangular roof shell plus narrow post/ridge beams and a back prism (preserving sloped walk-in headroom), stalls keep the open frame, tables keep four separate legs, and the well keeps its ring opening. Phase 0 sets hard per-asset triangle/size gates |
| Architectural scale | The reviewed furnished houses already span roughly 12–19 m and read at human architectural scale. A blanket 2× runtime transform is forbidden because it would make the compact house about 23×32 m, break module relations, and reduce density. Per-family corrections are frozen at bake time only when a player-scale probe proves them; larger authored variants provide silhouette scale without runtime stretching |
| Animated content | The windmill rotor is static in v1. Rotor animation, chimney smoke, runtime lights, and similar node/effect features wait for a general typed effect payload rather than creating village-only commit hooks |

Measured raw-scale AABBs that drive the probe and authored metrics:

| Asset | Size (m, W×H×D) | Role |
|---|---|---|
| `SFV_Building_Interior_*` (6 designs × 2 colors) | 11.6×10.9×16.3 … 18.5×16.2×18.8 | furnished enterable houses |
| `SFT_Building_001..004` | 39.3×28.3–34.3×28.9–32.3 | one grand tavern (variant chosen at probe) |
| `SFFA_Building_001` | 18.8×15.9×22.3 | forge |
| `AWS_Building_003` | 14.6×18.0×14.8 | alchemist (furnished) |
| `SFBP_Tent1..6` | ~7.9×7.2×8.5 | four swept walk-in families in production; visually closed fronts remain catalogued but cannot be inhabited |
| `SFM_*_Stall` (+17 color variants) | 4.5×4.0×3.2 | market stalls |
| `SFV_Tent_{Blue,Red,White}` | 4.2×3.5×3.0 | awning tents |
| `SFV_Windmill_001/002` | tower 27.3×73.1×28.2; rotor separate | town landmark (static v1) |
| `SFV_Floor_S` | 1.5×1.5 | exact timber skirt/street cell |
| `SFV_Wall_Pillar_001` | reviewed fixed height | sparse timber support stack |
| `SFV_Wall_Rock_001` | 3.0 m module | stacked building core |
| `SFV_Wall_Wooden_{S,M}` | 1.5/3.0 × **3.0** × 0.5 | kit module & storey height |
| `SFV_Floor_{S,M,L}` + planks | 1.5×1.5 / 3×1.5 / 3×3; planks 3×0.75 | kit floors & catwalks |
| `SFV_Stair_S` + `SFV_Stair_Floor_M` | 1.45×**1.55**×1.5 + landing | half-storey flights, chained |
| `SFV_Wall_LSupport_{S,M,L}` | up to 4.26×0.55×4.26 | cantilever braces |
| `SFV_Well`, `SFV_Quest_Board` | 3.9×4.3×3.3 / 2.2×2.1×0.5 | plaza civic props |

## 2. Architecture and invariants

Data flow:

`SettlementPlan + PathPlan → VillageFrame → VillageTerrainSurvey`

`VillageTerrainSurvey + VillageProgram → VillageMassingSolver → VillageCirculationSolver → VillageRecord`

`Path projection + selected VillageRecord contributions → WorldFeaturePlan → FeatureContext`

`FeatureContext → terrain / dressing / grass` and
`FeatureContext.payload → FeatureCommitQueue`

These are small typed classes with one responsibility each: `VillageCirculationSolver`
owns graph topology, `VillageGroundRouter` owns cardinal terrain streets/public stairs,
`VillageAerialRouter` owns rounded local links/two-frontage platforms, and
`VillageRouteGeometry` owns their shared swept-volume facts. Planners decide canonical
records, `WorldFeaturePlan` projects them, consumers query one context, and the commit
queue alone mutates the scene tree. V1 uses explicit composition rather than a feature
registry or inheritance framework; another abstraction is introduced only when a later
feature demonstrates a shared need.

### 2.1 Canonical decisions, projection-only streaming

1. A `VillageRecord` is a pure function of `(world_seed, settlement_id)`. Terrain,
   water, and accepted incident routes are themselves canonical functions of that pair;
   they arrive through a `VillageFrame` whose sorted connection signature is asserted
   on cache hits.
2. `PathPlan.canonical_frame_for(node)` completes the node's four route possibilities,
   including the neighbouring endpoint ranking needed by backbone selection, before it
   returns the accepted incident directions. It never derives a frame from whichever
   routes happened to enter one block query.
3. `VillagePlan` makes the full record once. It does not know about chunks or feature
   blocks. `WorldFeaturePlan` alone enumerates records intersecting a query, selects
   their full ground shapes, and half-open-owns placements by anchor block. It never
   geometrically clips a canonical shape, which preserves signed distance at seams.
4. Semantic slot ids are fixed before validation: `(settlement_id, district, slot_key)`.
   Rejection never renumbers later content. Composite structures reuse the structure id
   plus a stable piece key; output order is never identity.
5. Worker methods return plain data only. Render/physics resources and nodes are created
   exclusively by main-thread commit adapters.

### 2.2 Bounded by construction

1. `VillageProgram.MAX_ANCHOR_RADIUS = 144.0` m. Every authored slot, procedural spur,
   prop anchor, support anchor, and vertical-route anchor is rejected if it exceeds that radius
   from the plaza. The value keeps a village inside the protected interior of its 768 m
   settlement super-cell.
2. `VillageProgram.max_asset_reach` and `max_ground_shape_reach` are derived from every
   referenced asset footprint and ground primitive relative to its anchor.
   `max_record_radius` is `MAX_ANCHOR_RADIUS` plus the larger local reach; every emitted
   `VillageRecord.bounds` must fit it. Compile also asserts that `max_record_radius` does
   not exceed the settlement candidate's 192 m inset from its super-cell boundary.
3. `WorldFeaturePlan` enumerates settlement super-cells against
   `query.grow(max_record_radius + maximum_clearance)`, independently of route discovery.
   A village whose centre lies outside a block can therefore never lose an outlying
   placement or reservation inside it.
4. **Geometry halo** and **record discovery reach** remain separate concepts. Geometry
   halo is `ceil(max_asset_reach / 192 m)` and controls collision readiness around a
   terrain chunk; discovery reach finds village centres. The existing bridge is expected
   to keep geometry halo at 1, subject to compiled-metric validation.
5. All LRU eviction affects performance only. Recomputing after eviction yields the
   identical record and connection signature.

### 2.3 Feature ground and occupancy fields

`FeatureContext` replaces the misleading path-only context name and exposes:

- `surface_at(world_xz, known_cell) -> int` — resolves the highest-priority compiled
  ground-surface id (`NATURAL`, `WORN_PATH` in v1).
- `clearance_at(world_xz) -> float` — signed distance to the union of ecological
  exclusion shapes, clamped to the compiled maximum query distance.
- `placements() -> EnvironmentInstancePayload` — half-open-owned instances for the
  requested 192 m block.
- canonical path masks/node cells for route diagnostics and the optimized path-grid
  layer, not as an alternate public source of truth.

`FeatureGroundField` has two composable internal producers:

1. `PathGridLayer` preserves the current O(1) connection-mask/plaza classifier.
2. `FeatureShapeLayer` buckets immutable circles, capsules, and oriented rectangles on
   the 24 m terrain lattice. Each shape independently declares a surface id/priority
   and a clearance footprint.

`surface_at` always evaluates both producers and resolves by priority. There is no
"masks present, ignore rectangles" branch. The terrain, dressing, and grass consumers
use only `FeatureContext`, so future plazas, camps, courtyards, and roads add shapes
without new consumer plumbing.

Layout collision is intentionally not inferred from these 2D ground shapes.
`VillageOccupancy` stores oriented 3D volumes in deterministic buckets with five roles:
`SOLID`, `WALK_SURFACE`, `HEADROOM`, `GROUND_EXCLUSIVE`, and `WALK_GUARD`. Candidate
placement rejects only incompatible role pairs. `WALK_GUARD` is the narrow structural
role for public railings: it can meet a walk surface or another guard only when both
declare the same public walk network, while an ordinary `SOLID` can never borrow that
permission. This represents intentional vertical overlap—market beside an overhang,
catwalk over alley, rail joined to its stair landing—without ad hoc owner exceptions.

### 2.4 Traversal, foundations, and supports

`TraversalEnvelope` is a pure value shared by village compilation and tests. Its v1
humanoid contract is derived from the current player capsule rather than duplicated:

- capsule radius: current player value (about 0.3975 m);
- standing capsule height: current player value (2.244 m);
- minimum finished aperture width: **1.0 m**;
- minimum protected headroom: **2.4 m**;
- maximum finished step: **0.5 m** (planning targets ≤ 0.48 m for tolerance).

A contract test fails if the character scene changes without updating the shared
envelope. Phase 0 rejects or uniformly rescales any structural family whose real visual
and collision aperture cannot contain a swept capsule with these margins.

Every ground-bearing enterable structure uses `FoundationSolver`:

1. Authored metrics identify its interior floor plane, interior footprint, doorway
   contact, perimeter, maximum covered foundation depth, and available skirt modules.
2. Ask `TerrainSurfaceField.height_bounds(footprint)` for a conservative bound derived
   from every intersected patch's controls, then sample the doorway/perimeter contacts
   exactly. Set `floor_y` above the proven footprint maximum by a small compiled guard;
   natural terrain collision is therefore strictly below the walkable floor everywhere.
3. Fill the visible perimeter down to terrain with fixed rock/wood foundation modules.
   Reject the lot if the required depth exceeds the authored cover or if water/cliff
   rules fail. Ground never gets cut, hidden collision never enters the room, and no
   special terrain-mesher path is introduced.
4. Solve the doorway-to-street connection with a threshold, ramp, or stair composition.
   Every physical contact is checked against `TraversalEnvelope`; a thin plank may close
   only a residual seam already within the step budget, never repair an arbitrary gap.

Every structure that is not already fully terrain-supported uses `SupportSolver`:

1. Walk-surface, retaining-terrace, or platform top elevation is fixed first. Each authored support stencil casts down to
   exact terrain and requests a required support interval.
2. The solver chooses a deterministic stack from fixed trestle/pillar/base modules,
   aligns the top exactly, and permits only bounded burial. Timber references the highest
   terrain under its narrow footprint. Retaining walls and rock terraces reference the low
   side while remaining laterally attached to a real natural shelf; freestanding artificial
   rock towers are not an ordinary elevation source. Fixed modules may bury only within their
   authored allowance and no collision-bearing asset receives non-uniform scale.
3. A support fails if no legal fixed-module stack reaches terrain without a gap, water,
   cliff overhang, solid-volume intersection, or protected-headroom intrusion.
4. Every required retaining/platform support must pass before its owned urban-fabric group
   emits. Sparse timber post candidates are independently qualified and omitted over water,
   cliff seams, terrain above the deck, or an unavailable fixed stack; candidate-index ids
   remain stable, so environmental filtering cannot renumber surviving structure.

The third-person camera receives a general collision-aware pivot/boom controller as a
village prerequisite. Ceiling probes lower its framing pivot from the current outdoor
height, while a sphere-cast shortens the boom against world collision. It has no village
hooks; the same behavior covers cliffs, buildings, interiors, and future dungeons.

## 3. Assets and bake

### 3.1 Bake tool extensions (`tools/environment_bake/environment_bake.gd`, TOOL_VERSION 15 → 16)

- **`merge_pieces: true`** (per asset): after correction transforms, merge every
  `MeshInstance3D` into one ArrayMesh, combining surfaces that share a material. A
  prefab becomes one visual piece with 1–2 surfaces instead of 167–338 pieces.
- **`collision_profile: "building_trimesh"`**: one `ConcavePolygonShape3D` from the
  corrected merged triangle soup, with backface collision. Applied only where a complete
  enterable shell needs its authored floor/walls. Open-frame tents and props use explicit
  compound collision instead, so empty space stays empty.
- **`collision_profile: "ramp_box"`**: one oriented box fitted to the stair run so
  chained flights read as smooth ramps under `move_and_slide`.
- Floor pieces use `flat_box`; pillars, railings, and stall frames use compound authored
  shapes. Door-wall kit pieces get authored jambs + lintel—the
  arch-gate pattern—so collision preserves the measured opening.
- Manifest hygiene: the SFV door-wall folder's duplicate exports (`_001`, `_001_1`,
  `_001__1`) collapse to one canonical source per design.
- Generated provenance records corrected mesh bytes, visual triangles, collision
  triangles, surface count, collision-piece count, aperture metrics, and measured AABB.
  Bake validation enforces the hard per-asset gates frozen in Phase 0.
- Repo cost is expected to be roughly 100 MB before pruning. Phase 2 keeps only variants
  selected by lineup, aperture, and budget review.

There is no pack-wide `scale = 1.0` invariant. New structural families use their probed
uniform correction; the existing calibrated 2× arch/lamp corrections and bridge's
`[1.2, 1.0, 6.0]` correction remain untouched.

### 3.2 Catalog additions

New tags: `building`, `tent`, `stall`, `deck`, `stair`, `support`, `railing`,
`landmark`, `village_prop`, `foundation`. Catalog tests require collision on every
`building`, `stall`, `deck`, `stair`, `support`, `railing`, and `foundation`;
`building_trimesh` is permitted only on `building`/`tent`; ids remain sorted; collision
counts and the no-`res://assets/` runtime scan continue to apply.

### 3.3 v1 manifests

`fantasy_village_structures.json` (houses, tents, windmill, wells, quest boards, signs,
fences, carts, planters, ivies, hanged clothes, bird houses, modular kit, stairs,
floors, pillars, foundations, L-supports), `battle_pack_platforms.json` (deck floors +
corners, fixed trestles, ladder, plain tents, campfires, wagons, barrels, crates),
`tavern_kitchen.json` (tavern + chimneys + signs), `forge_armory.json` (forge, chimney,
signs), `alchemy_workshop.json` (alchemist buildings), and `fantasy_market.json`
(base + themed stalls, color variants, string lights, market props).

## 4. Canonical layout

### 4.1 Compiled program and scale vocabulary

`VillageProgram` compiles lightweight catalog descriptors and authored metrics only; it
loads no render resources. It owns asset footprints/contact planes, foundation/support
vocabularies, category/tier weights, traversal limits, `MODULE = 1.5`, the measured
single-flight stair rise, platform widths, maximum local-link span, density targets,
support-mode priorities, bounded search budgets, and `max_record_radius`.

The bake lineup reviews every larger authored SFV building family plus floor M/L,
planks, stair landings/handrails, retaining pieces, and cantilever braces. Scaling is a
family contract, not a layout parameter: runtime transforms remain unscaled and every
aperture, stair, railing, collision proxy, ground contact, and occupancy volume is
recompiled from the accepted bake.

`FeatureProgram` composes `PathProgram` and `VillageProgram` and derives the one worker
query margin, maximum clearance, surface-priority table, geometry halo, cache budgets,
and catalog validation result used by `WorldFeaturePlan`.

### 4.2 Terrain survey

`VillageTerrainSurvey` is a pure, resource-free analysis of the immutable final terrain
and guarded planning-water fields around the route landing. On a canonical lattice it evaluates actual
building footprints in cardinal orientations and records conservative height bounds,
floor height, relief, dry support fraction, cliff exposure, retaining depth, distance
from the route landing, and a stable candidate key.

The survey ranks **useful relief**, not flatness or maximum ruggedness. A viable urban
core contains several nearby supported perches, a bounded 4–12 m vertical span, a dry
walkable arrival, and sufficient projected room for dense occupancy. The selected urban
core may be offset from the flat route landing; a short terrain path connects them. No
heightfield value is changed and no candidate is moved after validation.

Broad discovery uses `WaterPlan`'s conservative guarded source footprint; it never builds
a hydrostatic fill for every rejected candidate. After massing and circulation reduce the
search to one bounded transaction, exact `WaterFieldContext` queries validate every selected
footprint, support, stair, and path. Any exact-water conflict rejects that transaction rather
than treating unknown coverage as dry.

### 4.3 Unified massing and circulation

`VillageFrame` still freezes settlement identity, accepted incident routes, fields, and
connection signature. `VillagePlan.record_for(frame)` runs these deterministic stages:

1. **Ground market** — choose a bounded connected orthogonal alley topology and line both
   sides with reviewed stalls wherever exact terrain and occupancy allow. The resulting
   streets, stall solids, and service clearances become hard input to every later stage;
   no building or prop can erase the market by winning an earlier placement race.
2. **Survey** — discover and sort terrain perches within the compiled compact-core reach.
   Natural perches retain their exact floors; bounded retained variants use the compiled
   12 m / 6 m architectural cadence.
3. **Building packing** — a bounded composition-diverse beam assigns the 10/15 authored
   village/town roster to nearby perches. Final validation accepts no fewer than 7/10
   inhabited buildings. Its objective favors compactness, natural support, multiple
   elevation bands, half rises, nearby same-floor pairs, and ground frontage. The larger
   furnished silhouettes are additive ground accents; they cannot replace or invalidate
   the compact stackable search vocabulary.
4. **Support selection** — each accepted building receives one typed atomic construction
   mode: ordinary perimeter foundation on a natural perch, or compact stacked-rock core
   plus timber only beneath the actual unsupported overhang. There is no broad platform
   or freestanding-stilt fallback.
5. **Public platforms** — derive module-cell platforms from clusters of nearby doors on
   the same floor.
   Every platform proves its frontage/activity ownership, complete support, exposed-edge
   railings, and lower headroom before materialization. Building skirts are the exact
   unsupported difference between ground contact and support, not a platform substitute.
6. **Circulation** — build a proximity graph over the route landing, doors, and platforms.
   Ground alleys and terrain stairs have priority. Remaining edges use short local timber
   links with straight and rounded sections; graph pruning forbids redundant aerial
   perimeter loops and links beyond the 24 m neighbour relation. Each stepped aerial link
   freezes its stair interval only after reserving clear departure runs at both facades;
   the fabric solver consumes that interval rather than rediscovering it as a special case.
7. **Validate and seal** — require route-to-door connectivity, traversal/headroom,
   occupancy, water, support, density, vertical variation, support-ratio, and compactness
   gates. Sort placements/shapes by stable key and return one immutable urban transaction.
8. **Outskirts and optional activity** — after the required dense transaction exists,
   place at most one village or two town shelters in the 36–60 m annulus, each with a
   short connected ground lane. Optional props and outskirts may fail independently but
   can never substitute for or veto the inhabited core. Seal exact record bounds last.

`VillageRecord` generalizes the current `elevated_*` audit fields into structures,
public surfaces, circulation edges, and support systems with arbitrary floor heights.
Ground and elevated content therefore share one construction path. The old
`VillageElevatedDistrict` remains only until these consumers and regressions migrate;
it receives no new layout special cases.

## 5. Projection, streaming, and commit

### 5.1 World feature projection

`WorldFeaturePlan.context_for(block)` is the worker-facing API:

1. Project canonical routes/bridges/path props for the context coverage.
2. Enumerate every validated settlement site whose conservative record bound intersects
   the coverage and request its canonical frame/record.
3. Select each complete ground shape whose influence intersects
   `coverage.grow(maximum_clearance)`; never cut the shape at the coverage boundary. Add
   a placement only when the half-open 192 m block containing its anchor is the requested
   block.
4. Seal one immutable `FeatureContext`. Context LRU order cannot affect any record.

Terrain meshing changes from `paths.corridor_at*` to `features.surface_at`; dressing
continues to use `clearance_at`; grass uses `surface_at != NATURAL` for footprint-safe
worn-ground rejection plus `clearance_at` for other structures. This is a small
intentional refactor, not a village-specific branch.

### 5.2 Feature commit queue

Man-made blocks no longer join the eager startup pre-warm set. `FeatureCommitQueue`
owns a generic state machine for every non-empty feature payload:

1. **WAITING_ASSETS** — demand-load the payload's sorted asset ids on the main thread,
   under an elapsed-time/count budget. The bake's maximum per-asset size gate bounds one
   indivisible load.
2. **COLLISION** — incrementally create collision shapes under elapsed-time and shape-
   count budgets. The block is not ready yet.
3. **READY** — attach the complete collision root and publish feature readiness
   atomically. Pending terrain can now commit.
4. **VISUALS** — create `(asset_id, visual_piece)` MultiMeshes under the existing visual
   budget; stale generations are discarded at every stage.

Empty blocks publish readiness without nodes or resource loads. `FieldTerrainStreamer`
owns scheduling and attachment but contains no village-specific cases. Existing
dressing/grass/cliff warming remains unchanged; all man-made path and village assets use
the feature queue uniformly.

Phase 0 freezes explicit M1 Pro gates for: maximum baked asset bytes, visual/collision
triangles per prefab, collision pieces per asset, collision shapes and feature instances
per block, asset-load time, collision-commit time, and worst-town resident memory. A
worst-tier town, not a single house, is the integration benchmark.

## 6. Verification

### 6.1 Automated, physics, and profiling gates

**Unit (GUT, headless):**

- `test_traversal_envelope` — player capsule contract, aperture/headroom constants,
  stair/ramp/threshold contacts.
- `test_foundation_solver` — terrain is strictly below every interior floor; perimeter
  coverage; doorway connector; depth/water/cliff rejection; deterministic fixed pieces.
- `test_support_solver` — exact top contact, grounded bottom with bounded burial, no
  non-uniform scale, no water/solid/headroom conflicts.
- `test_feature_ground_field` — path grid and shape layer union; priorities; signed
  clearance; bucket seams; no branch can suppress another producer.
- `test_village_program` — metrics, family correction, tier/slot tables, traversal,
  compiled bounds, maximum record reach, resource gates.
- `test_village_plan` — canonical-frame signatures, deterministic recompute/LRU
  eviction, stable semantic ids, bounds, foundations, occupancy roles, theme consistency.
- `test_village_terrain_survey` — deterministic perch discovery, conservative footprint
  bounds, water rejection, useful-relief ranking, compact core selection, and no terrain
  mutation.
- `test_village_massing_solver` — compact accepted building graph, arbitrary/half-rise
  floor heights, ≥70% terrain/retaining support, bounded tall-support ratio, platform
  ownership, local-link limits, stable ids, atomic group rejection, and zero incompatible
  volume overlaps.
- `test_village_circulation_solver` — route-to-door connectivity, exact stair residuals,
  curve/straight section continuity, supported platforms, exposed-edge railings, no
  redundant aerial perimeter loops, and protected lower streets.
- `test_world_feature_plan` — centre-outside-query discovery, dormant isolated sites,
  four block borders and corners, anchor ownership, full-shape seam equivalence, and
  recomputation in shuffled block order.
- `test_feature_commit_queue` — staged readiness, budgets, exact asset demand, stale
  generation cancellation, collision-before-ready, visuals-after-ready.
- Catalog extensions (§3.2), including per-asset triangle/size/aperture provenance.

**Statistical corpus** (`tests/harness/village_corpus.gd`): N seeds × M sites → tier
distribution, accepted inhabited roles, core radius, nearest-building distance, natural/
retaining/platform/cantilever/stilt ratios, elevation histogram and half-rise presence,
platform frontage count, local-link length/curvature, foundation/support rejection reasons,
building/transition/skirt/walkway/railing counts, record radius, block payload counts,
collision shapes/triangles, demanded asset set, and incompatible overlaps (must be 0).
Thresholds gate like `path_corpus.gd`; order-shuffled projection signatures must match.

**Physics and visual battery:** `environment_lineup.tscn -- --show-collision` reviews
every baked structure and measured aperture. A new `village_traversal.tscn` drives the
real character capsule through each doorway family, foundation entrance, stair chain,
tier transition, curved link, platform, undercroft, and alley. `village_review.tscn` plus pinned
`review_villages.json` vantages cover arrival court, terrain perch, retaining wall,
interior, alley canyon, compact urban mass, each building support/overhang relationship,
shared platform, undercroft, every descent, and skyline. Camera pivot/boom tests approach walls, enter each building, pass under
overhangs, and orbit in the narrowest legal alley.

`profile_terrain.gd` gains a pinned worst-town sweep and reports startup warm time,
on-demand asset load, collision commit by frame, feature-ready latency, visual backlog,
peak memory, and steady frame time on the M1 Pro baseline.

### 6.2 Adversarial generated-village screenshot review

Visual verification is a required implementation stage, not an informal final spot
check. `tests/harness/village_visual_corpus.gd` deterministically selects a stratified
set from the statistical corpus; `village_capture.tscn` then visits those records and
captures them only after terrain/features are ready, the visual commit queue is empty,
and two stable render frames have elapsed. Capture waits use a bounded worker-progress
lease: relevant work renews the deadline, a stalled phase still expires, and each
completed village checkpoints its auditable index before the runner moves on.

**Corpus coverage:** each full review contains at least **24 villages**: six for every
production tier/theme pair (village/blue, village/orange, town/blue, town/orange). The
selector deliberately covers relief quartiles, high/low lot rejection, sparse/dense
payloads, block interiors/edges/corners, every prefab building family, both foundation
styles, and every stair/doorway family. Every selected production village must contain an
an accepted compact urban fabric satisfying the density, useful-relief, support-ratio,
half-rise, and local-link gates; a sparse or support-dominated result is evidence and
blocks closure, not a coverage stratum to fill. If the current seed corpus cannot fill a stratum, the
search grows deterministically; it never silently relaxes coverage.

**Capture battery:** every selected village gets the same minimum eight view recipes
(recipes with two endpoints produce two images):

1. uphill and downhill skyline/whole-record views that expose compact massing;
2. arrival court at player eye height looking into the urban core;
3. main approach toward the densest façade cluster;
4. densest alley from both travel directions, including overhead fabric;
5. lowest retaining/foundation edge and its natural-terrain contact;
6. representative doorway from outside and just inside;
7. urban fabric from above, every shared platform, each building's support/overhang seam,
   the longest local link, representative curved links, and the protected undercroft;
8. every ground descent framed from both endpoints.

Conditional views are added for the tavern, forge, alchemist, windmill, tents, tier
transition, terrain-assisted exit, largest support stack, and any corpus outlier. The
capture harness uses fixed resolution, FOV, exposure, time of day, render settings, and
camera recipes. It emits a sidecar JSON record for every image containing screenshot id,
world seed, settlement id/cell, tier/theme, camera transform and target, selected asset
ids, feature-block generations, and corpus metrics. A contact sheet is generated for
composition review, but the reviewer must inspect the original-resolution image before
filing or dismissing a local geometry finding.

Iterative development runs may pass `--representative-views` to select one deterministic
view from every major risk category (both skylines, plaza/approach/street, market,
foundation, upper web, lower street, building overhang, aerial link, shared platform,
stair, and outskirts). This is explicitly a faster falsification loop across several
villages; the 24-village closure pass never uses the flag and still captures every
authored recipe.

Structural collision is a separate required capture stratum. For every collision-bearing
village family, `environment_lineup.tscn -- --asset ID --show-collision
--collision-closeup` captures the visible compound proxy, and a second
`--depth-test-collision` view for roofs/open frames exposes only proxy material escaping
the rendered mesh. The collision-closeup recipe suppresses world-space labels that could
cover small props. Unit tests pin the primitive mix and piece count for the cooking spit,
tent, stalls, table, well, quest board, fence, and elevated railing; visual review still
judges alignment, empty-space preservation, and snag risk.

**Independent critical review:** `tests/harness/village_visual_review_prompt.md` is the
versioned reviewer contract. The reviewer receives the design invariants, checklist,
contact sheets, full-resolution captures, and metadata, but not implementation excuses
or a list of areas the author believes are safe. A fresh reviewer/context is used after
every material fix round. The prompt says explicitly:

> Your task is falsification, not approval. This review is successful when you find a
> real, evidenced issue. An issue-free report is not a successful outcome by itself and
> must never be produced from a cursory scan. Inspect every capture critically. Do not
> reward the implementation for looking plausible; try to prove it wrong.

The reviewer is not rewarded for speculative volume: every finding must cite one or
more screenshot ids, the visible pixels/region, violated invariant, severity (P0–P3),
confidence, and exact seed/settlement/camera reproduction data. Suspicions are retained
as such rather than promoted without evidence.

The required checklist covers:

- floating, buried, stretched, unsupported, or terrain-intersecting structures;
- foundation holes, interior terrain bleed, bad thresholds, and inaccessible doors;
- mesh overlap, z-fighting, cracks, missing faces, scale mismatch, and broken pivots;
- stairs, railings, descents, tier transitions, headroom, and misleading traversal;
- supports, skirts, or walkway spans intersecting rock cores, alleys, buildings, stalls,
  or protected space; timber beneath any rock-supported portion of a building;
- path/ground-paint discontinuity, grass or dressing intrusion, and block seams;
- theme inconsistency, accidental repetition, implausible layout, weak silhouette,
  unreadable entrances, and poor district composition;
- camera obstruction, wall/roof clipping, occluded interiors, and unusable framing;
- missing or partially committed visuals, collision proxies, or streaming artifacts.

**Triage and closure:** the review writes `village_visual_review_report.json`. Every
supported P0–P2 becomes a pinned entry in `review_villages.json` before it is fixed, so
the original defect remains reproducible. A dismissal requires written pixel-level or
invariant-level evidence; "looks fine to me" is not an adjudication. After a fix, the
harness re-captures the exact failing view, its reverse/adjacent views, and a fresh
stratified corpus. The stage closes only when:

1. all required strata and views were actually captured and reviewed;
2. every finding is reproduced and fixed, explicitly accepted by the owner, or
   evidence-backed as a false positive;
3. no P0/P1 remains and no P2 is silently deferred;
4. every fixed P0–P2 has a passing pinned re-capture; and
5. a fresh independent reviewer completes one final full-resolution pass over a newly
   selected corpus, with all of that pass's findings triaged under the same rules.

Bulk captures/reports live in an ignored run-artifact directory keyed by date and build
signature. Only the small pinned regression manifest, representative failing/passing
captures needed to understand a regression, and the versioned reviewer prompt are
committed.

**Current development snapshot (2026-07-27; not a closure claim):** the latest
falsification work includes 223 original-resolution captures from nine settlements
across four seeds plus 31 real-streamer views pinned to the reported
`2697992464` / `settlement.29bc5c240c52f84a` regression, with zero adjusted,
obstructed, or unresolved camera diagnostics in that pinned run.
It confirmed the compact rock-core/unsupported-only timber invariant, the orthogonal
multi-level street web, and full-visual dressing clearance, while deliberately retaining
four evidenced findings in `review_villages.json`: empty interiors (VVR-006), two extreme
wall-only foundation framings (VVR-009), open-sided stair flights (VVR-023), and a sparse
settlement whose street extent exceeds accepted occupancy (VVR-024). VVR-025 pins the
reported tent-and-spit-only production failure and its passing dense multi-height recaptures.
The 24-village tier/
theme/foundation quota and a fresh independent final pass are still required before this
stage can close.

## 7. Delivery phases

- **Phase 0 — probes and gates (go/no-go):** bake one representative from every doorway/
  collision family plus the tavern and a complete elevated rig. Test the real capsule,
  foundation floor over worst accepted relief, fixed support stacks, exact tier contacts,
  camera obstruction, trimesh interiors, and a synthetic worst-town payload. Freeze
  family corrections, aperture/headroom, deck tiers, foundation/support vocabularies,
  resource gates, and commit budgets. A family that cannot pass is pruned or receives a
  reviewed authored compound collider before Phase 1.
- **Phase 1 — shared feature architecture:** `TraversalEnvelope`, conservative terrain
  footprint bounds, foundation/support/occupancy solvers, `FeatureGroundField`,
  `FeatureContext`, `FeatureProgram`, `WorldFeaturePlan`, staged `FeatureCommitQueue`,
  and the generic camera obstruction controller. Existing path behavior and tests must
  remain bit-identical before villages are added.
- **Phase 2 — bake:** tool version 16, reviewed manifests, family corrections, catalog
  tags, provenance gates, structural compound collision, and collision-overlay lineup
  review of the pruned asset set.
- **Phase 3 — canonical village planning:** terrain survey, compact massing motifs,
  unified structure/support records, shared platforms, proximity-derived circulation,
  activity binding, props, unit tests, and corpus. Migrate and then remove the fixed
  `VillageElevatedDistrict` grammar rather than adding fallback cases to it.
- **Phase 4 — projection and runtime integration:** bounded site enumeration, full-shape
  record projection, block ownership, demand warming, staged collision readiness, review
  harness, traversal battery, and order-shuffled seam tests.
- **Phase 5 — adversarial visual verification:** generate the stratified screenshot
  corpus, run the independent falsification review, pin every supported P0–P2, iterate
  fixes and exact re-captures, then run the fresh-corpus final review (§6.2). This phase
  cannot be replaced by the implementer's own walkthrough.
- **Phase 6 — final QA and profiling:** pinned-village falsification, worst-town
  streaming, camera/interior walkthrough, corpus thresholds, M1 Pro gates, final asset
  pruning, and confirmation that the Phase 5 review report is fully triaged.

## 8. Risks

| Risk | Mitigation |
|---|---|
| Natural terrain enters a flat interior | Foundation solver puts the floor above the footprint maximum; invariant and physics tests forbid penetration |
| Doorways or headroom fit visually but not physically | Shared traversal envelope + real capsule sweeps; scale is a probe result, not an assumption |
| Trimesh interiors snag or exceed physics cost | Per-family Phase 0 test and hard provenance gates; authored compound-collider fallback |
| Supports float, stretch, or distort collision | Fixed-module support solver with exact top, bounded burial, and no non-uniform scale |
| Sparse or support-dominated fabric passes structural checks | Core-radius, nearest-neighbour, natural-support, tall-stilt, platform-frontage, local-link, and half-rise gates are part of record validity and corpus closure |
| Terrain-led search grows nondeterministic or expensive | Canonical lattice candidates, stable lexicographic scoring, fixed motif/search budgets, and shuffled-order signature tests |
| Village content disappears at block seams | Compiled record radius, super-cell enumeration independent of routes, full-shape projection, shuffled-order signatures |
| Ground paint producer masks another producer | One `FeatureGroundField` union evaluates the path grid and bucketed shapes by priority |
| Dense vertical layouts cause false overlap rejection | Typed 3D occupancy roles encode legal vertical overlap by construction |
| Asset roster stalls startup or feature commit | Demand warming, per-asset bake gates, staged collision readiness, worst-town budgets |
| Third-person camera clips through walls/walkways | General collision-aware pivot/boom, tested in interiors and the narrowest legal spaces |
| Screenshot review rubber-stamps attractive overviews | Stratified deterministic corpus, mandatory close views, full-resolution adversarial reviewer whose success is finding evidenced defects, pinned repros, and independent re-review |
| Repo grows ~100 MB | Phase 2 lineup/budget pruning; only accepted variants are committed |

## 9. Explicitly deferred

Door leaves + open/close interaction; furnished interiors for composed houses and any
interior-enrichment dressing (InteriorPack, Crafting, scene-prefab vignettes); military
camp POI (themed battle tents, palisade kit, banners, siege props); watermills and
riverside features; literal building-on-building structural stacking whose source assets
do not expose reviewed bearing contacts; NPC
habitation, navigation/navmesh, quest-board content; a spawn-adjacent
guaranteed village; far-landmark impostors; windmill rotor animation; chimney smoke;
runtime feature lights; and the general typed effect/animated-scene payload that will
own those future node-based features.
