# Paths & Manmade Features (v1) — Design Spec

**Date:** 2026-07-17
**Last revised:** 2026-07-21
**Status:** Implemented; final review amendments incorporated.
**Scope:** The first slice of the master design's settlement-and-path layer (§11.6): a
deterministic, terrain-aware **path network** painted into the terrain surface, plus three
contextual feature types — **bridges** at water crossings, **lamp posts** along routes, and
**arches** as gateways. Settlement planning identifies future village sites but never reshapes
the landscape; buildings and gameplay interaction remain out of scope.

---

## 1. Decisions

| Question | Decision |
|---|---|
| What paths are | The original tan atlas texel painted onto existing walkable terrain triangles, plus sparse varied-size circular decals in one slightly darker tan — all in the same mesh/material/draw call |
| Path geometry | Centred 4 m corridors on the 24 m cell graph; bends use constant-width quarter-circle fillets with curved inner and outer edges. A future-village node validates a 12 m support footprint and paints a separate 16 m circular path plaza without changing terrain height |
| Network model | `SettlementPlan` publishes one candidate site per accepted 768 m super-cell; feasible neighbouring sites connect through a deterministic local backbone plus optional loops, using a bounded solve over the monotone cell DAG |
| Terrain reshaping | None. Villages and paths never flatten, raise, carve, or stamp the heightfield. Routes follow the natural rendered slopes and reject exposed cliff faces |
| Decision ownership | `SettlementPlan` owns only site identity/cell; `PathPlan` owns validation, routes, bridge sites, lamps, arches, feature IDs, reservations, and clearance. No downstream consumer recreates either decision |
| One worker query | `PathPlan.context_for(chunk)` returns one cached immutable `PathContext`; terrain painting, dressing suppression, and feature payload extraction all read it |
| Field cost | Route search reads exact terrain plus a cheap water-owned planning footprint. Full hydrostatic `WaterFieldContext`s are lazy and used only for exact validation and streamed production |
| Streaming | Props live in canonical 192 m feature blocks owned by anchor position. A demand-driven footprint halo is the complete readiness proof; empty blocks become ready keys without scene nodes |
| Rendering/physics | Generalize the existing dressing payload, collision builder, and budgeted visual queue into environment-instance infrastructure reused by dressing and features |
| Extensibility | Path internals stay path-specific. Only instance payloads, commits, and block ownership are generic; a cross-plan aggregator is deferred until a second feature plan exists |
| Bridge sizing | Choose an explicit three-axis bake scale from deterministic multi-seed crossing statistics and lineup QA; then gate every crossing against the complete oriented bridge footprint |
| Prop tinting | `tint_group: "identity"`; manmade props keep their authored colour. The path swatch still multiplies the shared ground tint |
| Lamp light | Emissive material only in v1. Future lights must consume the same lamp sites in feature blocks; no second biome-FX placement roll |

All five asset entries come from `FantasyVillageFBX`. The requested
`BattlePackFBX/FBX/Lamp/SFV_Light_Pole_001` path does not exist; the SFV pole is under
`FantasyVillageFBX/FBX/Exterior Props/Light Pole/`.

Measured raw-scale visual AABBs:

| Asset | Size (m, W×H×D) | Note |
|---|---|---|
| `SFV_Light_Pole_001` | 0.35 × 2.97 × 1.36 | pole with a 1.36 m lantern arm |
| `SFV_Arch_001` / `002` | 10.55 × 8.15 × 3.83 | town-gate scale |
| `SFV_Entrance_Arch_001` | 3.87 × 4.20 × 0.25 | small gateway |
| `SFV_Bridge_001` | 4.69 × 2.27 × 10.51 | deck along local Z |

The AABB is not the walkable deck span. The bake/lineup phase authors and verifies separate
`PathProgram` bridge metrics: deck-end contact points, clear opening, underside height,
collision footprint, and usable span. Worker code consumes those compiled numbers, never a guessed
fraction of the visual bounds. Metrics are expressed in baked asset-local metres after manifest
correction, so manifest scale is applied exactly once.

---

## 2. Invariants

- **Pure and deterministic.** Every node, route, feature ID, transform, and reservation is a
  function of `(world_seed, PATH_SEED_VERSION, canonical key)` plus immutable terrain, biome,
  and water fields. Query order, chunk order, worker timing, collection insertion order, and
  wall time never participate. Every hash ordering has a lexicographic canonical-key fallback.
- **One owner per decision.** `PathPlan` decides all path-network and contextual-feature facts.
  `PathContext` is only a bounded immutable view of those decisions. Terrain, dressing,
  streaming, and commits do not infer or reroll features.
- **Two-tier canonical field evaluation.** One worker-owned `WorldFieldBlockCache` supplies lazy
  canonical 192 m terrain regions and exact water contexts; each world point has exactly one
  half-open owning block. Ordinary route search never materializes exact water across its whole
  bounding box: it uses `WaterPlan`'s canonical planning footprint, then validates only the chosen
  route and prospective bridge footprints against exact block water.
- **Bounded solve.** A route between adjacent super-cell nodes is solved inside the endpoints'
  monotone bounding box. The graph, state, bridge look-ahead, and conflict neighbourhood all
  have finite seed-independent bounds.
- **Window-independent queries.** A route or feature has the same canonical identity and value
  no matter which chunk asks for it. Per-instance caches affect performance only and are bounded.
- **Explicit worker boundary.** Only primitive programs, CPU field objects, immutable contexts,
  and payload data exist on the worker. Meshes, materials, shapes, nodes, RIDs, and resource
  loading remain on the main thread.
- **Spatially complete physical readiness.** A compiled footprint bound derives the complete square
  of possible owner blocks. A terrain chunk is not player-ready until those keys are ready and every
  non-empty block has committed collision. Large features cannot disappear merely because their
  anchor lies across a chunk boundary; empty blocks allocate no scene objects.
- **Budgeted visuals.** Feature collision gates readiness; feature MultiMesh batches use the same
  generation-safe per-frame mechanism as dressing visuals.
- **One material/tint contract.** Dirt quads use the shared terrain material and ground tint.
  Props resolve colour from their baked descriptor and compiled instance colour.

---

## 3. Architecture

### 3.1 Shared canonical field blocks

```text
scripts/terrain/field/
  WorldFieldBlockCache.gd  # independently lazy HeightfieldRegion/WaterFieldContext cache
```

`WorldFieldBlockCache` receives the existing `HeightfieldPlan`, `WaterPlan`, and fixed combined
query/shore limits after dressing and features compile. Its deliberately small API is:

```gdscript
region(chunk: Vector2i) -> HeightfieldRegion
water(chunk: Vector2i) -> WaterFieldContext
region_at(world_xz: Vector2) -> HeightfieldRegion
water_at(world_xz: Vector2) -> WaterFieldContext
```

Each accessor selects a 192 m key with half-open `floor(world_xz / CHUNK_WORLD)` ownership,
including negative coordinates. Region and water values are memoized independently: asking for
terrain does not build hydrostatic water. `water(key)` reuses `region(key)` and builds one exact
context covering the canonical core plus the fixed compiled query/shore margin.

Production terrain, water, dressing, node validation, final route validation, and feature jobs
share this worker-owned cache. No exact consumer builds a caller-shaped region or a second
`WaterFieldContext`. The cache has a fixed entry cap; eviction discards work only and cannot affect
output. Compilation rejects combined margins beyond `WaterFieldContext`'s fill/contour contract.

Ordinary route search uses no exact water blocks. `WaterPlan` instead exposes the cheap canonical
planning queries `planning_signed_distance(point)` and `planning_intervals(a, b)`. They read the
same variable-width river segment capsules and pond stamps that seed the real water field, expanded
by one fixed `PATH_WATER_GUARD`; they do not run hydrostatic fill or contours. These methods are
owned by water so `PathPlan` never duplicates river geometry. Their answer is a guarded planning
approximation, not rendered-water truth. Exact validation against lazy `water(key)` remains
authoritative. `WaterFieldContext.wet_intervals(a, b)` is the exact counterpart shared by final
route validation and bridge profiling, so neither consumer implements its own shoreline scan.

### 3.2 New feature types

```text
scripts/terrain/features/
  SettlementPlan.gd # seed-only village site identities/cells; no terrain API
  PathProgram.gd      # validated primitive asset metrics + tuning; main-thread compiled
  PathPlan.gd         # canonical routes, props, reservations, bounded route caches
  PathContext.gd      # immutable bounded view: masks, sites, clearance, owned payload
```

- **`PathProgram`** is compiled on the main thread from the lightweight environment catalogue
  plus fixed v1 tuning. It contains no `Resource` references: only asset IDs, measured bounds,
  authored bridge contacts/clearances, footprint radii, probabilities, limits, and margins.
  Compilation rejects missing collision, invalid metrics, a derived halo above the explicit
  `MAX_FEATURE_HALO` budget, and a query margin beyond the canonical water-field contract.
- **`SettlementPlan`** is worker-owned and uses only seed, biome fields, the base landform, and
  water's bounded planning footprint to choose site identities/cells. It exposes no height or
  terrain-mutation API, and `HeightfieldPlan` has no settlement hook.
- **`PathPlan`** receives that same settlement plan, `WaterPlan`, the shared
  `WorldFieldBlockCache`, and the compiled `PathProgram`. It validates published sites against
  exact final fields, then solely owns bridge sites, route solving, backbone/loop selection,
  route merge, prop placement, and stable feature identity.
- **`PathContext`** covers one canonical 192 m chunk core plus a compiler-derived reservation
  margin. `PathPlan.context_for(chunk)` memoizes it by `Vector2i`; there are no caller-shaped
  windows or duplicate terrain/feature contexts. It exposes:

```gdscript
corridor_at(world_xz: Vector2) -> bool
clearance_at(world_xz: Vector2) -> float
placements() -> EnvironmentInstancePayload
```

`clearance_at` is signed distance to the union of painted corridors and prop footprints:
negative inside, zero on the boundary, positive outside, saturated at a small compiled limit.
A consumer with required margin `m` accepts a point iff `clearance_at(point) >= m`.

### 3.3 Consolidated environment-instance infrastructure

The feature layer does not clone dressing's commit code. Generalize it once:

```text
scripts/terrain/environment/
  EnvironmentInstancePayload.gd   # asset ID -> IDs/transforms/colours
  EnvironmentCollisionBuilder.gd  # payload + baked shapes -> named StaticBody3D
  EnvironmentCommitQueue.gd       # generation-safe budgeted MultiMesh batches
```

- Replace `DressingPayload` with `EnvironmentInstancePayload`.
- Replace `DressingCollisionBuilder` with `EnvironmentCollisionBuilder`; the caller supplies the
  body name (`"DressingCollision"` or `"FeatureCollision"`).
- Replace `DressingCommitQueue` with `EnvironmentCommitQueue`; dressing and features use separate
  queue instances and supply their container names (`"Dressing"` / `"Visuals"`). Feature block
  roots themselves live under the streamer's single `ManmadeFeatures` root.
- The queue owns generation checks, weak parents, piece composition, batching, and stale discard.
  There is no second ~30-line feature-specific implementation.

Ambient dressing may leave instance IDs empty. Feature batches carry a stable ID alongside each
transform so a later entity/persistence layer can adopt a feature without changing generation.
The v1 renderer and collision builder do not interpret that ID.

`SettlementPlan`, `PathProgram`, `PathPlan`, and `PathContext` remain concrete and narrow. A
future village-content pass consumes the existing settlement IDs/sites and may emit the same
`EnvironmentInstancePayload`; it does not need to replace path generation. Introduce a thin
context/reservation aggregator only when a second payload-producing plan exists.

---

## 4. Path network

`SettlementPlan.SEED_VERSION` owns site identity; `PATH_SEED_VERSION` owns routes and contextual
features. Named salts keep unrelated decisions stable; bump a version only for an intentional
reshuffle of its own domain.

### 4.1 Nodes and settlement candidacy

`SettlementPlan` owns distinct named salts for each 768 m super-cell. Its five candidates use the
base continuous landform, biome fields, and cheap planning-water clearance:

1. Existence roll, initially `NODE_PROBABILITY = 0.75`.
2. Five candidate terrain cells hashed into the central half of the super-cell.
3. Each candidate is scored using local continuous-height span plus meadow/rocky weights and is
   rejected inside the bounded settlement-water clearance.
4. The lowest passing score is the provisional winner; the candidate hash is the final tie-break.
5. The site publishes only a stable settlement ID and cell. It never publishes or applies a
   height target, plateau, ridge, pass, or village layout stencil.
6. `PathPlan` validates only that the published site's 12 m future-village support footprint is
   supported and dry in the untouched
   final terrain through `WorldFieldBlockCache`. Failure produces no node; there is no fallback or
   retry.

There is no feature-specific spawn exclusion; the existing flat/dry origin fields participate in
the normal score, and a route crossing the starting clearing is allowed.

The path node publishes only the stable settlement ID and cell. Future village content may use
that identity and must adapt its layout to the natural final terrain; v1 does not place buildings
or encode a building layout.

### 4.2 Canonical bridge sites

Bridge legality is resolved before route solving. On the centred 24 m path graph, a fixed
program-derived look-ahead repeatedly applies `WaterPlan.planning_intervals(a, b)` to identify each
prospective axis-aligned wet run and its first dry landing cells. The bound comes from maximum
usable bridge span; no unbounded shoreline walk is possible. The canonical site key is `(axis,
sorted dry landing endpoints)`; it does not depend on a route, query window, or arbitrary wet cell.

`PathPlan.bridge_site(key)` lazily performs the complete exact profile in §5.1 using only the
canonical field blocks intersecting the footprint. Identical keys coalesce. For a valid site,
`PathPlan` enumerates the fixed-radius set of other valid site footprints that can overlap it. The
site survives iff no incompatible overlapping site has a strictly higher `(priority hash, site
key)` rank. Compatible collinear identity is already one key. Raw exact profiles and resolved
survival are separate memoized values, so neighbourhood resolution is one flat comparison rather
than recursive site-to-site evaluation.

Only a surviving site is exposed to route search as one complete macro-edge from dry landing to
dry landing. The macro-edge records every traversed cell connection, keeping merged masks and
reservations continuous even though wet terrain quads are not painted. Perpendicular bridges and
wet T/X junctions are impossible because the graph never exposes the losing sites. There is no
post-route bridge arbitration and therefore no route that becomes invalid because another route
later supplied a bridge conflict. An unused winning site may conservatively reserve an overlap;
that local tradeoff avoids route-order coupling and is measured by the corpus.

### 4.3 Candidate routes

Only node pairs in cardinally neighbouring super-cells are route candidates. The pair key is the
sorted endpoint IDs. Candidate feasibility is determined before the local network-selection rule
in §4.4.

The route graph is the finite Manhattan-monotone DAG inside the endpoint bounding box. Search
state is `(cell, previous_direction, vertical_variation_units)`. One unit is one rendered terrain
level. At a given cell, signed height change from the start, in the same units, is fixed, so
separate ascent/descent state is redundant:

```text
max(up, down) = (vertical_variation + abs(height - start_height)) / 2
```

The route is pruned whenever that value exceeds `ROUTE_VERTICAL_BUDGET_UNITS`. A bridge macro-edge
adds its conservatively quantized deck-profile variation. This preserves the symmetric climb gate
while replacing the old ascent × descent state space with one dimension.

For each planning-dry cell, legal edges are the one or two cardinal steps that reduce Manhattan
distance:

- `TerrainSurfaceField.is_walkable_edge(region, cell, direction)` is the single shared classifier
  for path planning and future navigation. Vertical cliff/wall transitions are illegal; ordinary
  storey and level smootherstep slopes are legal.
- Cost uses absolute surface change, rocky weight, and a turn penalty. Signed east/north elevation
  never affects acceptance.
- `WaterPlan.planning_intervals()` checks the complete forward segment; dry cell centres are not
  sufficient because a narrow river can pass between them. A segment with a planning-water
  interval is not a normal step. It is traversable only through the one surviving canonical bridge
  macro-edge spanning that interval; a partial wet run is never search state.

Dynamic programming processes states in increasing Manhattan progress. A candidate state is
discarded if an existing state at the same cell and direction has both no greater cost and no
greater vertical variation. Exact cost ties use a named hash of the pair key,
predecessor state, and destination state, followed by lexicographic predecessor comparison for the
theoretical hash tie.

The one winning planning route is then checked against exact lazy water blocks along its corridor.
`WaterFieldContext.wet_intervals()` checks the centreline and corridor-edge segments, and every
quad centre that would be painted must be dry; bridge sites are already exact. If validation fails,
or no planning state reaches B, the candidate route is absent. The solver does not rerun for an
alternate path. Thus the common search pays only exact terrain reads, while exact hydrostatic work
is proportional to the selected route rather than its whole bounding box.

### 4.4 Local backbone and route merge

For a query window, enumerate every cardinal super-grid edge whose possible endpoint bounding box,
grown by the maximum bridge footprint, can intersect that window. Because nodes stay in the
central half of adjacent super-cells, this is a fixed two-super-cell neighbourhood. Materialize
that complete bounded set before selecting edges.

Each node considers its at most four exact-feasible incident routes and selects the lowest
canonical `(route cost, pair hash, pair key)` rank as its backbone edge. An undirected candidate
route is accepted if either endpoint selects it. Every remaining feasible route is accepted by one
named `LOOP_EDGE_PROBABILITY` roll, initially `0.35` and finalized by Phase 0 statistics. Therefore
a node with any feasible neighbour cannot be isolated by a keep-roll, while optional loops still
break up tree-like topology. Route infeasibility and a super-cell with no neighbouring nodes remain
legitimate reasons for isolation.

Accepted route masks are unioned by cell; dry route overlap is legal. Every cell's final connection
set is the union of its accepted route connections. Lamps and arches are placed only after this
merge, so their eligibility sees the final degree and cannot disagree at overlaps. Routes that use
the same canonical bridge site share its one placement.

### 4.5 Corridor painting

The terrain grid uses 12 quads per 24 m cell: `STEP = 2 m`. Every route junction stays at the true
terrain-cell centre. Because that centre lies between quad-centre columns, a symmetric 4 m strip
covers exactly two 2 m columns without a second offset coordinate system.

- Each connection contributes a centred 4 m wide rectangle from the cell centre to its connected
  edge.
- Unioning the rectangles yields stubs, straights, corners, T/X junctions, and overlapping routes.
- Each perpendicular arm pair contributes one tangent quarter-annulus: the path centreline bends
  at 4 m radius and its inner/outer edges follow 2 m/6 m radii. Incoming strips stop at the
  tangency, so the result is a constant-width ribbon rather than a disk stamped over the pivot.
- A node remains a logical village identity only. Independently of its 12 m validation footprint,
  it paints a 16 m circular path plaza around the connected road. This is surface styling only;
  it is not a village heightfield/layout stamp.
- `corridor_at()` is evaluated at each terrain quad centre. A 4 m corridor covers two 2 m quads.
- Nodes, route segments, bridge centre lines, and feature offsets all use this one centred graph.

`TerrainChunkMesher.compute_chunk` receives the `PathContext` and the existing
`WaterFieldContext` explicitly. At the one point that chooses the walkable sheet UV:

```gdscript
var uv := _path_uv if features.corridor_at(quad_centre) \
    and not water.is_wet(quad_centre) else _grass_uv
```

Every path triangle uses the original centre tan texel. A sparse world-hashed subset of its 2m
quads also emits a terrain-conforming 12-sided circular decal, with continuously varied 0.18–0.52m
radius and one slightly darker sample from the same padded tan island. Each circle must fit wholly
inside the dry corridor. The decals join the same surface, material, and draw call: there is no
texture, shader, or material fork. Inner-corner backing triangles still force `_cliff_uv`; an apron
under a path uses the base path tan so a cliff corner cannot expose a green square inside the dirt
corridor.

World-space predicates and half-open route ownership make adjacent chunks agree without a seam
protocol. Painting changes no terrain height, collision, or surface classification; the circles
sit 8mm above only the visual sheet to avoid z-fighting.

---

## 5. Contextual features

Every placement has a canonical ID:

```text
hash(world_seed, PATH_SEED_VERSION, feature_type, canonical_site_key)
```

Bridge site keys include axis plus quantized dry landing endpoints; they are not keyed by an
arbitrary cell inside the wet run. Lamps and biome arches read the final merged route mask; village
gates walk accepted routes outward from each endpoint because a merged mask cannot distinguish two
routes that share one arm and split early. Placement precedence is fixed: shared bridges, village
gates, biome gates, then lamps. Each later class rejects earlier footprints. Shared village-gate
segments and final network cells deduplicate before placement rather than at commit time.

### 5.1 Bridges — `sfv.bridge.001`

A bridge macro-edge evaluates the complete oriented baked footprint, not only its centreline.
Sampling uses the exact continuous water/terrain fields through `WorldFieldBlockCache`.

1. Read the centreline and lateral shoreline intervals from the shared exact
   `WaterFieldContext.wet_intervals()` classifier.
2. Transform the authored deck, collision, and landing sample points into world space.
3. Require every landing-footprint sample to be dry and supported.
4. Across several lateral sample lines, require the refined wet interval plus both dry landing
   intervals to fit inside usable deck span. Oblique banks therefore consume more span naturally.
5. Ground the bridge by its authored deck-end contact heights. Both residual end-to-bank steps
   must be at most `BRIDGE_END_STEP_MAX = 0.4 m`, conservatively below the character's current
   0.5 m step capability.
6. Reject excessive bank-height difference, water-level spread, or terrain grade beneath the
   bridge. The entire underside must clear the maximum static water level plus the shared dynamic
   wave bound.

The bridge visual/collision transform is the one transform proven by those samples. There is no
separate placement approximation after route legality.

Collision comes from an authored `collision_source`: deck primitives following the walkable arc
plus rail primitives, with no shape across the channel below. Standing on the deck remains outside
the static-depth swim gate; swimming underneath remains possible.

#### Bridge scale selection

The raw visual is 10.51 m long, while declared river half-widths are 9–16 m. A uniform 1.75× scale
would provide only an 18.39 m visual AABB and is not accepted as a default: even an 18 m wet run
needs additional dry landings, and uniform scaling also makes the bridge unnecessarily tall.

Phase 0 probes prospective axis-aligned dry-to-dry crossings on the centred 24 m path graph,
independently of route acceptance, across a deterministic corpus of seeds. It reports perpendicular
and oblique span quantiles plus legal-site coverage. The manifest then uses an explicit JSON
three-vector such as `[width_scale, height_scale, length_scale]`; scalar JSON scales are invalid.
The chosen vector must pass lineup review for deck width, rail height, slope, character clearance,
and collision fit. If acceptable proportions cannot span the target quantile, use a different or
modular bridge rather than stretching this asset further.

### 5.2 Lamp posts — `sfv.light_pole.001`

- Eligible cells are dry, straight, degree-2 cells outside bridge, node, and arch reservations.
- A stable keep-roll plus one-cell hash-rank thinning gives a minimum 48 m centre spacing and a
  target mean of one lamp every 48–72 m; long random gaps remain legal.
- Each eligible cell belongs to the lowest-key accepted route that traverses it. Accepted lamps are
  ordered along that route; side is `(accepted_index + hashed_route_phase) % 2`, which guarantees
  actual alternation rather than independently random sides.
- Anchor is approximately 4.5 m from the centreline. The complete pole/arm footprint must be dry,
  supported, and outside other feature reservations. The lantern arm faces the path.
- Collision is a slim authored pole primitive. The lantern material is emissive; no light node.

### 5.3 Arches — `sfv.arch.001/002`, `sfv.entrance_arch.001`

- Every accepted route is walked outward from both village endpoints. The first candidate is the
  fourth segment, centred 84 m from the node; later segments through step 12 are bounded support/
  water fallback. Routes still sharing that segment deduplicate to one physical gate, while routes
  that split earlier each retain their own gate.
- Existing cliffs beside that segment are welcome but optional. Gate placement never creates
  cliffs or side walls, and simply declines when the asset's real supports do not fit the terrain.
- Gate placement checks the full leg footprints and opening, not one centre stencil. Both legs
  must be dry and supported; the clear opening must contain the 4 m corridor plus authored margin.
- Small-arch candidates begin on path connections whose endpoint dominant biomes differ. Eight
  fixed bisections refine the transition along the 24 m edge. Stable-priority 96 m spacing collapses
  rapid ecotone oscillations, and a 144 m village clearance prevents biome gates from stacking with
  the more important village threshold.
- Yaw places the opening along the route axis. Small-arch collision stays on its legs. Large-arch
  collision follows four posts, two beams, four diagonal braces, and two roof slopes; the
  character-height opening remains empty while collision bounds reach the visual roof and depth.

### 5.4 Reservations and dressing

`PathContext.clearance_at()` includes corridor geometry and the compiled horizontal
footprint of every nearby prop. `DressingSet` gains one explicit authored
`feature_clearance: float`, compiled into `DressingProgram`:

- `0.0` means only reject inside a reservation;
- structural trees/rocks use roughly 2 m beyond it;
- small ground cover uses roughly 0.3 m.

`DressingField._qualify` performs this check alongside its terrain and water checks. Eligibility
hashes, choice hashes, and spacing arbitration remain unchanged, so features never reroll distant
dressing. The future grass carpet uses the same context with its authored 0.3 m margin.

---

## 6. Streaming and pipeline integration

### 6.1 Startup

On the main thread, before the existing worker starts:

1. Load the environment catalogue and compile dressing as today.
2. Compile `PathProgram`, validating the five asset entries, collision, metrics, margins, and
   maximum horizontal footprint.
3. Warm the union of dressing, cliff, and active feature visuals.
4. Construct the worker-owned `WorldFieldBlockCache`, then `PathPlan` with `WaterPlan`, that cache,
   and the primitive path program.
5. Prepare separate `EnvironmentCommitQueue` instances for dressing and feature blocks.

### 6.2 Worker jobs

`FieldTerrainStreamer` remains the only owner of the one background worker. There is still one job
type and one 192 m key grid; each job carries `build_terrain` and `build_features` flags. A key in
the terrain radius normally computes both missing outputs in one pass. An on-demand halo key
outside that radius computes only features. If its feature block is already ready, a later terrain
request computes only terrain. Terrain and feature outputs retain separate generation numbers
because their keep bounds differ. There are never parallel terrain/feature jobs duplicating one
key's context work.

Every job begins once:

```gdscript
core = Rect2(Vector2(chunk) * CHUNK_WORLD, Vector2.ONE * CHUNK_WORLD)
paths = _paths.context_for(chunk)

if build_features:
    feature_data = paths.placements()

if build_terrain:
    region = _fields.region(chunk)
    water = _fields.water(chunk)
    terrain_data = _mesher.compute_chunk(_plan, chunk, region, water, paths)
    dressing_data = DressingField.compute(_dressing_program, world_seed,
        core, region, water, paths)
    water_data = _water_builder.compute_chunk(_water, chunk, region, water)
```

The result carries whichever optional outputs were requested, each with its own captured
generation under one chunk key. Terrain and feature consumers validate their generations
independently. Feature-only jobs build CPU path/context data and exact fields only where validation
requires them; they never eagerly build their own water block or create terrain/water meshes.

### 6.3 Demand-driven feature halo and readiness

Feature blocks are anchor-owned by half-open 192 m core. Compilation derives one correctness bound:

```text
FEATURE_HALO = ceil(path_program.max_horizontal_footprint_radius / CHUNK_WORLD)
```

V1 sets `MAX_FEATURE_HALO = 1` and compilation requires `FEATURE_HALO <= MAX_FEATURE_HALO`.
Increasing that explicit budget later changes loop bounds, not ownership architecture.
One sorted `_feature_halo_keys(chunk)` helper owns the integer-square enumeration; scheduling,
readiness, tests, and player priority all call it instead of repeating boundary logic.

- A terrain-radius job normally produces the feature block with the same key, so anchors inside
  streamed terrain appear without a second job.
- When a finished terrain payload reaches integration, the streamer checks the fixed square of
  feature keys `chunk + [-FEATURE_HALO, FEATURE_HALO]²`. Only missing keys are enqueued as
  feature-only jobs. A feature request inherits the distance of its nearest waiting terrain and
  wins ties against terrain work; the current player's square is therefore first without a second
  priority system. Unrelated outer halo work is not eagerly swept at startup.
- A feature job with no placements records its key as ready without creating a root, collision
  body, or visual-queue item. Overlapping `PathPlan` and field queries reuse their bounded caches.
- A terrain payload waits until every key in its derived square is ready. Non-empty blocks commit
  feature collision before dependent terrain enters `_built`; feature visuals may remain queued.
- Pending terrain stays in one nearest-first integration list. Each drain rechecks its nine-key
  square through `_feature_halo_keys`; the bounded scan replaces reverse dependency maps and
  wake-up bookkeeping.
- The player is released only when their terrain chunk and its derived feature square are ready.
- Feature keep radius is `KEEP_RADIUS + FEATURE_HALO`; no dependency lists, reference
  counting or chunk-parent migration is introduced.
- Eviction invalidates the feature visual generation before freeing the canonical block root.

A bridge anchored exactly across a chunk boundary is therefore already present when either
intersected terrain chunk becomes traversable. With the v1 halo, the player's critical startup
wait is at most nine lightweight feature keys, while the eventual union around a 7×7 terrain
window is at most 9×9. Correctness follows solely from the compiled footprint bound; no placement
enumerator must independently rediscover readiness dependencies.

### 6.4 Main-thread commit order

Feature block:

```text
empty: mark key ready
non-empty: block root → feature collision → add to feature root → mark key ready → queue visuals
```

Terrain chunk, after derived-halo readiness:

```text
terrain → water → dressing collision → add_child → FX → mark built → queue dressing visuals
```

Feature blocks live under one streamer-owned `ManmadeFeatures` root, not under terrain chunks.

---

## 7. Assets and bake

Add `tools/environment_bake/manifests/fantasy_village_features.json` with pack
`fantasy_village`, the pack's existing license label, `default_scale: [2,2,2]`, and JSON vector
scales. In-game review established the 2× correction for the freestanding assets; the bridge keeps
its independently calibrated proportions and crossing span:

| ID | Source under `FantasyVillageFBX/FBX/Exterior Props/` | Scale | Collision | Tint |
|---|---|---|---|---|
| `sfv.light_pole.001` | `Light Pole/SFV_Light_Pole_001.fbx` | `[2,2,2]` | pole primitive | identity |
| `sfv.arch.001` | `Arch/SFV_Arch_001.fbx` | `[2,2,2]` | posts + beams + braces + roof | identity |
| `sfv.arch.002` | `Arch/SFV_Arch_002.fbx` | `[2,2,2]` | posts + beams + braces + roof | identity |
| `sfv.entrance_arch.001` | `Arch/SFV_Entrance_Arch_001.fbx` | `[2,2,2]` | leg primitives | identity |
| `sfv.bridge.001` | `Bridge/SFV_Bridge_001.fbx` | `[1.2,1,6]` | deck + rail primitives | identity |

Tags are `feature` plus `lamp`, `arch`, or `bridge`. Every entry declares
`supports_instance_color: true` and a `collision_source`. Authored placement metrics live in
`PathProgram`'s compile-time validation data and are checked against baked descriptors;
generated runtime meshes and shapes remain normal environment assets.
`sfv.arch.002` also declares the pack's orange atlas as a fallback albedo because that FBX
surface imports with UVs but no texture; the baker applies the fallback only to textureless
standard-material surfaces and bakes it into the normal self-contained runtime material.

Lineup QA uses the one-metre marker, a character, measured AABBs, and collision overlays. It must
verify bridge deck contacts, under-deck swim clearance, rail height, arch opening width, lamp-arm
yaw, pivots, and every authored footprint sample.

---

## 8. Verification

### 8.1 Unit and integration tests

- **Canonical field blocks:** cold/warm/reverse/evicted query equality; owner selection at positive
  and negative chunk borders; `region()` alone never materializes water; exact consumers reuse the
  same independently lazy region/water objects.
- **Planning water:** capsule/pond ownership and continuous segment intervals; bounded look-ahead;
  endpoint-order equality; known planning/exact mismatches fail only final candidate validation.
- **Settlements/nodes:** seed/version determinism, candidate tie-breaks, bounded terrain influence,
  final exact-water validation without fallback, minimal public node output, and a quantized test
  proving each gate has two real three-storey unwalkable cliff faces with an open road axis.
- **Route solver:** compare small synthetic DAGs with an exhaustive oracle; prove containment,
  endpoint-order independence, the one-value vertical-variation equivalence to separate ascent and
  descent, dominance pruning, deterministic ties, exact-final-validation absence, and no rerun.
- **Bridge macro-edges:** precise shore refinement; complete footprint checks at perpendicular and
  oblique crossings; landing dryness/support; endpoint step margin; water-level spread; underside
  clearance; collision leaves swim-under space.
- **Bridge-site field:** identical sites coalesce; incompatible overlaps resolve before routing by
  stable priority; no wet T/X or perpendicular overlapping bridge is exposed to the solver.
- **Backbone/loops:** every node with a feasible incident route has at least one accepted edge;
  pair acceptance is endpoint-order/query-order independent; optional-loop rolls use one pair key.
- **Path context:** one cached context per canonical chunk key; half-open owned placements, stable
  IDs, signed clearance at interior/edge/exterior, prop footprints included, and cold/warm/evicted
  query equality.
- **Terrain painting:** inspect emitted triangle UVs on the real path overlay for every mask shape,
  centred 4 m width, constant-width inner/outer bend fillets, a 16 m circular village plaza,
  dry/wet boundary, inner-corner override,
  positive/negative chunk seams, the bounded junction join, path-coloured aprons, and all
  circular spot UV staying inside the mip-safe tan island, varied deterministic radii, and every
  disc contained by the dry path. No path-grid offset exists.
- **Dressing suppression:** authored margins work; hashes stay unchanged; anchors beyond the
  reservation plus arbitration radius remain bit-identical to a feature-free run.
- **Shared commits:** existing dressing tests pass through generalized payload/builder/queue;
  feature body/container naming, batching, stale generation discard, and payload purity.
- **Streaming:** a maximal bridge centred on each chunk edge and corner has collision before either
  intersected chunk becomes ready; the derived halo is complete at positive and negative keys;
  player-critical halo jobs outrank unrelated work; empty payloads create ready keys but no nodes;
  feature blocks survive and evict at the conservative halo without duplication.

### 8.2 Deterministic statistical corpus

Use a fixed checked-in seed list spanning all biomes. Report:

- nodes per km², rejected-node reasons including planning/exact mismatch, and node-support span/shore
  distributions;
- feasible/backbone/loop/accepted edges, isolated-node reasons, connected-component sizes, route
  length, turn frequency, vertical variation, planning/exact validation mismatch, and route-drop
  reasons;
- water crossings by perpendicular/oblique span, bridge legality reason, chosen-scale coverage,
  bridge conflicts, and unused conflict-winning sites;
- lamps per route kilometre, gap distribution, and side alternation;
- arches per node and per route kilometre.

Thresholds are explicit test constants. A small fixed smoke subset runs in normal GUT; the full
corpus is a deterministic harness and Phase 0/release gate so routine test time stays bounded. A
pinned visual seed is for reproducible art review, not for selecting global bridge scale or network
density.

### 8.3 Visual and performance battery

Pinned review teleports cover: straight/L/T/X masks, a 16 m circular village plaza, long slope, mountain rejection,
merged routes, lamp spacing and true alternation, both arch sizes, perpendicular and oblique
bridges, walk-over/swim-under/wade-at-bank behavior, path/dressing/grass clearance, all chunk-edge
bridge orientations, and a seam pan.

The 49-chunk profile attributes region creation, exact water creation, planning-water queries,
bridge-site validation, route solve, final validation, context query, terrain paint lookup,
feature-block compute, readiness-critical collision commit, and visual batches. Caches are tested
cold and warm. A direct counter asserts ordinary DAG expansion creates zero exact water contexts;
final validation reports only the route/bridge blocks it actually touches. The profile separately
reports player-critical halo latency, requested/empty/non-empty feature keys, empty-key main-thread
cost, bounded pending-integration scan cost, and gradual expansion from the 7×7 terrain window
toward its bounded 9×9 feature union.
Startup remains lazy except for compiled primitive programs and selective visual warming.

---

## 9. Delivery phases

Each implementation phase lands runnable with the full existing GUT suite green.

0. **Go/no-go probe:** before production architecture, run the deterministic bridge-span corpus,
   review centred 4 m and offset 6 m strips in the real terrain/asset lineup, measure planning-water
   mismatch, exercise the backbone topology on representative seeds, and profile cold field plus
   the demand-driven nine-key player halo. The default remains centred 4 m; changing it, rejecting
   the bridge asset, or replacing the halo with a more complex measured optimization is an explicit
   owner-approved spec edit before Phase 1. Freeze bridge scale and statistical thresholds here.
1. **Consolidation + bake:** generalize the environment payload/collision/queue with dressing
   behavior unchanged; add feature assets, collision templates, program validation, and lineup QA.
2. **Pure planning core:** implement independently lazy canonical fields, water-owned planning
   queries, seed-only settlement sites/final node validation, canonical bridge sites, the one-value DAG solver, exact validation,
   backbone/loops, route merge, `PathContext`, and exhaustive headless tests. No scene nodes.
3. **Atomic world integration:** add centred 2 m-quad painting, explicit dressing clearance, keyed
   terrain/feature job flags, demand-driven halo readiness/eviction, empty-block elision, and
   bridge collision/visuals.
   The visible world gains complete paths and usable bridges together.
4. **Lamps + arches:** place from the final merged network, add reservations and exclusions, and
   verify spacing, alternation, openings, support, and yaw.
5. **Falsification + polish:** full statistical corpus, pinned visual battery, performance gates,
   atlas/tint tuning, export/source-pack-absence checks, and `AGENTS.md` update.

---

## 10. Explicitly deferred

- Village-layout height stamps, manufactured gateway cliffs, route-wide flattening, cuttings, and
  retaining walls. Uphill routes use the natural walkable slope geometry instead.
- Village buildings, procedural lot/layout acceptance, and plaza content.
- Fences, signs, carts, and other route furniture.
- Real lamp lights derived from the existing lamp sites, day/night behavior, and settlement
  warm-light orchestration.
- Organic/non-right-angle paths, wear variation, path decals, and navigation integration.
- Interaction, destruction, persistence, or gameplay state. Stable feature IDs and independent
  feature blocks preserve the adoption path without implementing those systems in v1.
