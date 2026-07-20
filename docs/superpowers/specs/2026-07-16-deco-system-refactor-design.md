# Environment Assets and Ecological Dressing — Final Design Spec

**Date:** 2026-07-16
**Last revised:** 2026-07-17
**Status:** Implementation reference; architecture and verification gates are final.

## 1. Decision

This refactor has two deliberately bounded responsibilities:

1. **Environment asset backend.** Editor tooling converts source-pack scenes into
   stable-ID, self-contained runtime assets. Runtime terrain code never loads source
   paths under `res://assets/`.
2. **Ecological dressing.** A pure deterministic field places ambient nature from
   biome fill rates, shared habitat patches, terrain, and water. Visuals are batched;
   optional static collision is committed before a terrain chunk becomes ready.

This is not the general world-placement system. Settlements, paths, bridges,
buildings, camps, interactable objects, harvesting, persistence, and other
world-planned features need stable identity and lifecycle authority. They belong in
a future `WorldFeaturePlan`/`WorldFeatureStreamer`.

Combat is undecided and outside this refactor. No combat grid, tactical occupancy,
cover, or combat-facing API is introduced.

Dense or interactive grass is also deferred. Sparse KayKit grass remains ordinary
dressing for compatibility; LPFV grass and a dedicated grass renderer are not part
of this implementation.

### 1.1 Ownership boundary

| Content | Owner | Identity/state | Static collision | Rendering |
|---|---|---:|---:|---|
| Ambient trees, rocks, logs, and stumps | `DressingField` | No | Optional baked proxy | Batched |
| Bushes, flowers, mushrooms, reeds, lily pads, sparse grass | `DressingField` | No | Normally none | Batched |
| Buildings, paths, bridges, camps, contextual props | Future world-feature layer | Yes | As required | Independent |
| Interactive or persistent objects | Future feature/entity layer | Yes | Yes | Independent |
| Dense/interactive grass | Future grass system | Undecided | Undecided | Undecided |
| Combat representation | Future combat system | Undecided | Undecided | Not owned here |

Static collision does not imply gameplay identity. A dressed tree can block the
player while remaining a replaceable deterministic field sample. As soon as an
object can be chopped, moved, looted, reserved, saved, or referenced by another
system, it graduates to the feature/entity layer.

## 2. Non-negotiable invariants

- **Pure deterministic placement.** Output is a function of world seed, authored set
  data, and immutable world-position fields. Chunk order, worker timing, collection
  insertion order, and wall-clock state cannot affect it.
- **Seam correctness by construction.** Candidates have stable world identities and
  half-open chunk ownership. Overlapping queries agree bit-for-bit.
- **Bounded decisions.** All neighbourhoods and margins are compiler-derived and
  finite. There are no retries, mutable placed-object indexes, or greedy chains.
- **True ecological structure.** Biome fill is authored directly. Shared continuous
  habitat fields create interiors, edges, and exteriors with real negative space;
  no set depends on already-placed objects.
- **Pure worker boundary.** Workers return only IDs, transforms, colours, and other
  plain CPU data. Resource loading and all render/physics objects stay on the main
  thread.
- **Atomic physical readiness.** Collision-bearing dressing is attached before a
  chunk enters the streamer's built set. A player never encounters a visible
  structural object whose physics is pending, or physics whose placement can later
  change.
- **Visual work remains budgeted.** MultiMesh creation uses an independent per-frame
  queue. Stale chunk generations are discarded.
- **Selective heavy loading.** The catalogue is lightweight; only visuals referenced
  by active consumers are warmed.
- **One owner per fact.** Ground comes from `TerrainSurfaceField`, water and shore
  facts from `WaterFieldContext`, and biome weights/tints from `BiomeRegistry`.
- **Self-contained runtime assets.** Generated meshes, materials, textures, and
  shapes do not depend on source packs or their import cache.
- **One-directional future integration.** A future feature plan may publish immutable
  reservation or distance fields for dressing to read. Dressing never modifies
  terrain, water, paths, features, or combat.

## 3. Architecture

### 3.1 Runtime types

| Type | Responsibility |
|---|---|
| `EnvironmentAssetDescriptor` | Lightweight stable ID, visual path, tags, measured bounds, collision count, tint/provenance metadata |
| `EnvironmentVisual` | Heavy mesh pieces and optional collision pieces |
| `EnvironmentCollisionPiece` | A baked `Shape3D` and asset-local transform |
| `EnvironmentCatalog` | Explicit sorted lightweight descriptor index |
| `EnvironmentRenderCache` | Main-thread-only selective heavy-resource cache |
| `DressingChoice` | One asset option and its per-biome visual affinity |
| `DressingHabitatLayer` | One shared ecological field, scale, preference, and per-biome coverage |
| `DressingSet` | One population: fill, habitat, support/water rules, spacing, and appearance |
| `DressingProgram` | Validated flat worker-safe data compiled from active sets |
| `DressingPayload` | Per-chunk asset IDs, transforms, and colours |
| `DressingCollisionBuilder` | Main-thread adapter from placements plus baked shapes to chunk physics |
| `DressingCommitQueue` | Generation-safe, budgeted MultiMesh construction |

Generated asset data and authored population data never share a file. Rebaking may
replace an entire descriptor/visual without touching ecological tuning.

### 3.2 Runtime layout

```text
scripts/terrain/environment/
  model/
    EnvironmentAssetDescriptor.gd
    EnvironmentVisual.gd
    EnvironmentVisualPiece.gd
    EnvironmentCollisionPiece.gd
    EnvironmentCatalogIndex.gd
  EnvironmentCatalog.gd
  EnvironmentRenderCache.gd

scripts/terrain/dressing/
  model/
    DressingChoice.gd
    DressingHabitatLayer.gd
    DressingSet.gd
    DressingCatalogIndex.gd
  DressingCompiler.gd
  DressingEcology.gd
  DressingProgram.gd
  DressingField.gd
  DressingCollisionBuilder.gd
  DressingCommitQueue.gd

terrain/environment/
  catalog/
  visuals/
  meshes/
  materials/
  textures/
  collisions/

terrain/dressing/
  sets/
  index.tres

tools/environment_bake/
  environment_bake.gd
  manifests/
  collision_sources/
  provenance/
```

Only bake tooling knows source-pack paths. Runtime code does not scan directories.

### 3.3 Startup

Before the worker starts, the main thread:

1. Loads explicit environment and dressing indexes.
2. Validates IDs, paths, canonical biome maps, choices, habitat layers, field
   combinations, support/spacing bounds, and seed versions.
3. Compiles resources into one flat `DressingProgram` containing no `Resource`
   references.
4. Warms exactly the program's active environment visuals plus cliff visuals.
5. Starts the terrain worker only after active heavy assets are ready.

Catalogue-only assets add descriptor metadata but no startup mesh, texture, material,
or shape cost.

### 3.4 Per-chunk flow

The worker computes one shared `HeightfieldRegion` and `WaterFieldContext`, then
produces terrain, water, effects, and dressing payloads as sibling pure computations.
`TerrainChunkMesher` does not own ambient dressing.

The main thread:

1. commits terrain and water;
2. resolves the dressing payload's baked shapes and attaches one
   `DressingCollision` `StaticBody3D` to the unattached chunk;
3. attaches the physically complete chunk and records it as built;
4. queues each `(asset_id, visual_piece)` MultiMesh batch;
5. drains visual batches under the dressing budget and rejects stale generations.

Collision uses the same transform payload as rendering, so visual and physics
placement cannot diverge.

## 4. Environment bake contract

### 4.1 Descriptor and heavy asset split

`EnvironmentAssetDescriptor` contains only lightweight metadata and the string path
to its `EnvironmentVisual`. `collision_piece_count` is validation/review metadata,
not a shape reference.

`EnvironmentVisual` owns:

- typed mesh pieces, each with its asset-local transform;
- typed collision pieces, each with a saved `Shape3D` and asset-local transform.

The cache composes each world placement with the same asset-local transforms:

```text
world_visual_transform   = placement * visual_piece.local_transform
world_collision_transform = placement * collision_piece.local_transform
```

This keeps the lightweight catalogue cheap while keeping heavy rendering and physics
data together as one scale-correct baked asset.

### 4.2 Scale policy

Scale correction is manifest data and is applied exactly once during baking. It is
never guessed at placement time.

- Existing KayKit wrapper parity is canonical: bushes `4x`, grass `1x`, rocks `3x`,
  and trees `2.5x`.
- LowPolyFantasyVillage nature uses a `3.25x` pack default so its trees and props
  share the established world scale.
- A per-entry override is allowed only when the source asset genuinely uses a
  different unit convention.
- Every catalogue item is reviewed beside a one-metre marker and its measured AABB.

Runtime `DressingSet.scale_range` is natural instance variation around the baked
canonical size, not a substitute for source-pack correction.

### 4.3 Collision policy

The manifest supports exactly one of:

- `collision_source` — a bake-only scene containing authored primitive shapes;
- `collision_profile = "convex"` — a generic convex proxy for a wholly rigid mesh;
- `collision_profile = "flat_rock"` — each declared rigid component as a convex hull
  with its top vertices flattened into a stable walkable face;
- `collision_profile = "flat_box"` — one inset box for a block-like rock;
- `collision_profile = "stump_cylinder"` — one cylinder fitted to the undecorated
  woody component and its visible cut;
- `collision_profile = "trunk_capsule"` — one capsule fitted only to the grounded
  lower trunk after foliage removal;
- `collision_profile = "trunk_capsule_chain"` — a bounded chain of jointed capsules
  fitted to successive lower-trunk cross-sections when a strongly curved trunk cannot be
  represented by one chord without protruding; adjacent capsules share the exact same axis
  endpoint so their hemispherical caps are concentric at the joint. Reviewed exceptional
  silhouettes may author `collision_joint_points_m` and `collision_segment_radii_m` in
  corrected asset-local metres rather than relying on an ambiguous forked cross-section;
- `collision_profile = "oriented_cylinder"` — one flat-ended cylinder rotated onto
  the primary rigid component's long axis;
- `collision_profile = "oriented_capsule"` — one smooth capsule rotated onto that
  long axis;
- neither — no collision for deliberately non-rigid dressing.

Profiles may declare `collision_max_height` in corrected world metres. Assets tagged
`walkover` use that cap, and validation multiplies the baked collider height by every active
population's largest authored scale before comparing it with the character step height. This
makes low-rock traversal a content invariant rather than a per-instance corner case.

The semantic tags close the completeness gap by construction: every `tree`, `rock`,
or `deadwood` entry must declare a collision source/profile or the bake fails. Generated
collision uses simple convex `Shape3D` resources. Every LPFV rigid component normally produces
exactly one shape. A reviewed curved trunk may instead declare a bounded capsule chain; its
successive rounded shapes share cap centres at each joint so the assembly has neither gaps nor
disconnected, offset bends.
Ordinary entries contain one hard component; multi-rock source models explicitly declare
`collision_component_count`, and the bake creates a separate disjoint hull for each selected
stone instead of bridging empty space. Collision must remain within a small tolerance of the
visible rigid component; a scale-relative
automated AABB guard and the collision-overlay lineup enforce this in both directions.
Foliage identification uses the same baked albedo criterion as palette variation, so
recoloured tree variants inherit identical woody physics.

Reviewed KayKit trees and rocks use old-wrapper `collision_source` templates only where the fit
survived visual review. The owner's original three-cylinder proxy remains on the first rock;
the second rock replaces its oversized sphere with a mesh-derived flat-topped hull. KayKit tree
variants 2 and 4 are removed from the catalogue. LPFV trees collide only at the grounded
lower trunk using a rotated capsule fitted from exact horizontal mesh cross-sections. LPFV tree 2
uses three overlapping capsules along those cross-sections because a single chord exits its bend;
reachable canopy and branches intentionally do
not collide. LPFV logs use one rotated flat-ended cylinder, stumps one flat-topped cylinder,
the fallen branch one rotated capsule, and rocks one inset box or one top-flattened convex hull
per disconnected stone.
Bushes, flowers, fungi, reeds, lily pads, small plants, and sparse grass remain non-blocking.

Terrain/cliff physics is still owned by `TerrainChunkMesher`. Hill wrapper collisions
must not be duplicated as environment dressing.

### 4.4 Bake outputs and provenance

For each stable-ID manifest entry the bake:

- recursively extracts mesh pieces and root-relative transforms;
- applies scale/pivot correction once;
- duplicates meshes and self-contained materials/textures;
- optionally creates selective foliage palette variants while preserving bark and
  neutral texels;
- imports or derives collision pieces and saves shapes under
  `terrain/environment/collisions/`;
- measures the corrected AABB;
- writes the heavy visual, lightweight descriptor, and sorted index;
- records source hash, parameters, pack/license, and tool version;
- prunes generated orphans and rejects runtime dependencies on source packs.

Rebaking unchanged inputs must be equivalent at the resource-data level.

## 5. Ecological dressing model

### 5.1 Direct biome fill

Each `DressingSet` authors `fill_per_cell` for every canonical biome. A value is the
expected local population before habitat, qualification, and spacing. This is clearer
than multiplying a global count by an indirect foliage-density field: a designer can
read and tune meadow, forest, highland, grove, and marsh abundance directly.

The compiler derives proposal slots from the maximum authored fill. Choice affinities
only change the local species mix; they never silently change population density.

### 5.2 Shared negative space

Before per-set habitat is evaluated, every ground population is multiplied by one
world-wide `land_occupancy01` field. A broad low-frequency mask creates substantial
clearings. The feathered boundary graph of a jittered-Voronoi field creates connected,
winding path bands. Zero is a shared exclusion rather than a probability reduction, so
no tree, rock, flower, mushroom, or other ground set can independently refill a clearing
or path. Water-surface and emergent populations do not use this land-only mask.

### 5.3 Shared habitat fields

A `DressingHabitatLayer` contains:

- a stable channel name;
- a world-space scale;
- `INTERIOR`, `EDGE`, or `EXTERIOR` preference;
- coverage for every canonical biome;
- a finite transition softness.

`DressingEcology.habitat01` combines broad and smaller deterministic value-noise
scales. Sets naming the same channel and scale sample the same latent habitat. This
creates correlated ecological relationships without parent/child placement or set
ordering:

- trees occupy the interior of `woodland_canopy`;
- bushes favour its ecotone;
- grass and flowers favour its exterior/openings;
- mushrooms require both canopy and a smaller fungal-colony field;
- deadwood requires canopy and disturbance pockets;
- large and small rocks share `rocky_exposure`;
- reeds and lily pads use wetland/pond colony fields in addition to canonical water
  qualification.

Coverage thresholds produce true interiors and true clearings, not merely a mild
probability boost. Several layers may be multiplied to express nested niches.

Mushrooms are represented by two populations sharing one species community: a dense
patch population admitted only inside fungal colonies and a much rarer singleton
population admitted outside them. This produces conspicuous patches plus the occasional
isolated specimen without procedural parent/child placement.

### 5.4 Species communities

Per-instance random choice produces visual confetti even when density is clustered.
An optional community channel partitions the world into irregular jittered-Voronoi
neighbourhoods. Every point in a neighbourhood shares a stable species roll.
`community_strength` blends that regional roll with the candidate's independent roll.

The result is local stands of related trees, flower drifts, mushroom colonies, and
rock formations while still allowing controlled variation within each community.

### 5.5 Terrain, water, and support

- `GROUND_POINT` grounds at the final jittered anchor.
- `GROUND_SUPPORT` checks a symmetric stencil on the continuous terrain surface and
  rejects excessive height span or grade.
- `WATER_SURFACE` uses the canonical static water level.
- `LAND`, `SHORE`, `SHALLOW`, `EMERGENT`, and `FLOATING` all use the same
  `WaterFieldContext` values used by water rendering.

Reeds use `EMERGENT`: their anchors must be wet, 0.05–3.2 m deep, and no more than 4 m
inside the shoreline. They therefore form near-shore water colonies rather than appearing
on arbitrary land.

Qualification is performed at final anchors/support points. Land content cannot be
underwater and broad objects cannot bridge unsuitable slopes by construction.

### 5.6 Spacing

Matérn-II arbitration gives every conflict a stable winner in one bounded
neighbourhood. Structural nature sets share `natural_structural` so tree trunks,
rocks, logs, and stumps cannot overlap each other even though they come from
different populations. Small non-structural sets retain their own spacing groups.

## 6. Placement algorithm

The world is divided into half-open 24 m proposal cells. Candidate identity is:

```text
(world_seed, set_id, set.seed_version, proposal_cell, slot_index)
```

Named-purpose salts independently derive jitter, eligibility, arbitration, choice,
yaw, scale, and brightness. No chunk coordinate, enumeration index, engine-object
hash, `randi`, or clock participates.

For each candidate affecting the compiler-derived query window:

1. Blend direct per-biome fill at the anchor.
2. Multiply the suitability of every shared habitat layer.
3. Apply a stable eligibility roll.
4. Qualify terrain support and water policy at the final anchor/stencil.
5. Choose a visual using biome affinity plus the optional community roll.
6. Arbitrate against eligible candidates in the same spacing group.
7. Emit only if the winner belongs to the core half-open chunk.

The stable total arbitration key is
`(hash64, set_id, proposal_cell.x, proposal_cell.y, slot_index)`. Even a hash
collision has a deterministic winner.

The compiler derives the query margin from proposal jitter, support stencil, and the
maximum active spacing-group radius. Habitat and community fields are point samples
and require no query halo. Regional plans and feature reservations stay outside this
local system.

## 7. Appearance

Biome tint is resolved through the descriptor's explicit `tint_group`, then multiplied
by one stable brightness roll. Baked palette variants selectively recolour foliage
texels while preserving bark, stone, flowers, and neutral texels; the independent
per-instance biome tint still applies.

The terrain ground-tint invariant is unchanged: terrain sheets, aprons, skirts, and
KayKit cliff pieces share the one ground palette/tint source.

## 8. Future world-feature boundary

A future `WorldFeaturePlan` owns canonical stable IDs for settlements, roads, paths,
bridges, buildings, camps, and contextual props. It may publish terrain shaping before
heightfield/water resolution and immutable reservation/distance fields afterward.

Its streamer owns feature lifecycle, collision readiness, interaction, persistence,
navigation, and authored feature scenes. Feature definitions may reuse environment
asset IDs, but `EnvironmentAssetDescriptor` never acquires gameplay fields.

Dressing may eventually read immutable feature masks pointwise. It never queries
mutable streamed feature nodes and never places features itself.

## 9. Content included

- Migrated KayKit bushes, sparse grass, rocks, trees, and cliff visuals at legacy
  world scale.
- LowPolyFantasyVillage `Tree_01`–`Tree_09`; the sparse `Tree_10` conifer and the
  depth-order-broken pink blossom variant are deliberately excluded.
- LPFV flowers, small plants, mushrooms, reeds, rocks, big rocks, logs, and stumps.
- The LPFV fallen branch.
- Small Fantasy Village lily pads.
- Reviewed primitive collision for migrated KayKit trees and rocks.
- One close-fitting primitive for each LPFV tree, rock, log, stump, and fallen branch;
  tree collision stops at the lower trunk and foliage remains non-blocking.

Not included:

- LPFV `Grass_01`–`Grass_07`;
- buildings, bridge placement, lights, carts, stalls, tents, or workstations;
- interaction, chopping, harvesting, persistent removal, or save-state IDs;
- combat, navigation generation, or LOD/HLOD.

## 10. Verification gates

### 10.1 Asset backend and scale

- Every stable ID resolves to a lightweight descriptor and valid heavy visual.
- Loading descriptors transitively loads no mesh, material, texture, scene, or shape.
- Runtime environment resources contain no source-pack dependency.
- Corrected manifest scale is asserted for each pack/category.
- LPFV trees are reviewed against KayKit trees and the one-metre lineup marker.
- Rebakes are equivalent and the environment-runtime PCK works from an empty cache.

### 10.2 Collision

- Reviewed KayKit proxies retain authored data only where it fits; the restored first-rock
  proxy is guarded explicitly and the second rock is guarded as a planar fitted hull.
- Every active LPFV structural asset has a valid generated proxy.
- Every `tree`, `rock`, or `deadwood` stable ID has at least one collision piece, and
  every generated piece is a simple convex shape.
- Every LPFV rigid asset uses one collision piece per declared disconnected hard component unless
  it explicitly declares a reviewed curved-trunk capsule chain; every piece's bounds stay within
  a small absolute/scale-relative tolerance of the visible rigid mesh.
- LPFV tree proxies are substantial single capsules around only the grounded lower trunk;
  they cannot collapse to a line or root-sized sphere, bridge branches, or include foliage.
- Logs are rotated flat-ended cylinders; stumps have flat walkable cylinder tops; rocks
  use boxes or convex hulls with at least three coplanar top points.
- Every `walkover` collider remains below the character step height even at the largest active
  dressing-set scale.
- Worker programs and payloads recursively contain no `Shape3D`, `Node`, RID, mesh,
  material, texture, or packed scene.
- Placement/collision transform composition is covered by a unit test.
- The streamed harness requires nonzero structural instances and collision shapes
  before capture.
- Eviction removes render and physics together with the owning chunk.

### 10.3 Ecology and determinism

- Coverage extremes create all-interior/all-exterior results correctly.
- Shared channel samples are deterministic and correlated across sets.
- Habitat thresholds produce both dense regions and true clearings.
- The shared land-occupancy field creates both broad zero-occupancy clearings and
  connected zero-occupancy path bands across every ground population.
- Mushroom patches are locally much denser than the separate rare singleton population.
- Reeds qualify only as emergent water content near the shoreline.
- Community rolls are stable and form local visual neighbourhoods.
- Direct per-biome fill survives compilation unchanged.
- Reordered sets, dictionaries, proposal enumeration, and chunk requests do not alter
  identities or results.
- Overlapping windows and chunk boundaries emit no duplicate or missing anchors.
- Adding an unrelated set does not reroll existing candidates.

### 10.4 Field and commit correctness

- Ground/support transforms use the continuous surface at final positions.
- All water modes agree with `WaterFieldContext`.
- Cross-population structural spacing prevents collider overlap.
- Collision is committed before chunk readiness; MultiMesh batches remain budgeted
  and generation-safe.
- Existing terrain, water, cliff, tint, and chunk-weld tests remain green.

### 10.5 Required project checks

- Full GUT suite.
- Catalogue lineup with measured AABBs, one-metre markers, and optional collision
  overlays.
- Fixed streamed-world ecology capture after both terrain and dressing queues settle.
- 49-chunk profile attributing dressing compute, collision commit, and visual commit.
- Export/PCK and source-pack-absence verification.

## 11. Performance model

- Proposal cost scales with active sets and compiler-derived slots, not catalogue size
  or choice count.
- Habitat lookup is two bounded noise samples per layer; community lookup is a bounded
  3×3 Voronoi search.
- Arbitration is bounded by compiled spacing-group radii.
- One present `(asset_id, visual_piece)` produces one MultiMesh batch.
- Collision uses one `StaticBody3D` per chunk and one `CollisionShape3D` per baked
  primitive/convex proxy. It is readiness-critical but measured separately.
- Visual batches remain asynchronous and budgeted.

## 12. End state and deferred work

Delete the retired decoration scatter, terrain-owned foliage payloads/caches, wrapper
scenes, tag-weight population path, and source-backed runtime environment resources
after parity/export gates pass. Bake-only collision templates remain under tooling;
generated runtime shapes remain under `terrain/environment/`.

Explicitly deferred:

- combat and all combat-facing terrain APIs;
- `WorldFeaturePlan`/`WorldFeatureStreamer` and feature reservations;
- settlements, paths, bridges, buildings, camps, and contextual prop placement;
- interaction, persistence, chopping, harvesting, and authored entity state;
- terrain flattening/road shaping for future features;
- dense, dynamic, interactive, or specialized grass;
- navigation integration;
- LOD/HLOD until profiling demonstrates a need;
- source-pack git-history cleanup.

These are separate systems, not corner cases to add to `DressingField`.
