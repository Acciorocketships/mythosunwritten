# Warren Volumetric City Architecture — Design Spec

**Date:** 2026-08-09
**Status:** Living architecture; the first volumetric production transaction is
implemented and under visual/construction iteration.
**Supersedes:** The constant-2D-footprint partition and vertically repeated
construction assumptions in
`2026-08-06-mass-first-warren-design.md`.
**Retains:** Mass-first negative-space streets, immutable terrain bearing,
resource-free worker planning, authored-asset construction, exact public-air
proofs, deterministic generation, and the existing production adapter boundary.

## 1. Decision

The next warren generator will plan the town as a **bounded semantic 3D grid**.
The grid is the authoritative source for:

- allocatable inhabited mass;
- public streets, stairs, tunnels, courts, galleries, and their swept headroom;
- private inhabited volumes;
- structural support and bearing paths;
- building ownership at every height;
- large-structure, skywalk, balcony, outcropping, market, roof, and visual-clearance
  reservations;
- the interfaces between volumes: floors, roofs, facades, party walls, doors,
  windows, guards, and deliberate openings.

Generation begins with a mountain-shaped allocation envelope above immutable
terrain. It subtracts connected public space from that envelope, reserves the
town's major composed features, and partitions the remaining volume into
interlocking three-dimensional room clusters. Building floorplates may grow,
shrink, offset, branch, bridge, and terminate independently at each storey.

Only after this volumetric plan seals does construction select and place
authored assets. The grid is therefore **not voxel art**, a block-mesh format,
or runtime constructive-solid-geometry. It is a resource-free planning and
proof representation from which modular construction is compiled.

This directly replaces the failed model:

```text
old:  choose 2D footprint -> extrude N storeys -> decorate the extrusion

new:  reserve 3D public/feature volumes
      -> partition residual 3D mass into rooms and structures
      -> derive every exposed interface
      -> realize those interfaces with authored assets
```

## 2. Why the current architecture produces towers

`WarrenBuildingParcel` owns one rectangular `footprint`, one `base_band`, and
one `top_band`. Every cell in that footprint is occupied for the full vertical
interval. `WarrenParcelConstruction` can vary facade families and roofs, but it
cannot change the building's volume between storeys. A three-, five-, or
eight-storey parcel therefore remains one extrusion even when its skin changes.

This also makes important features unnaturally late and fragile:

- a skywalk searches for a corridor after both endpoint towers already exist;
- a shallow facade bay can decorate a wall, but a room-sized jetty would leave
  the parcel;
- a balcony has no owned exterior floor volume or door/guard contract;
- a tunnel is carved in source mass, but construction later reasons about
  independent columns flanking it;
- a courtyard is a special floor subset rather than a void around which the
  whole town is composed;
- complete prefabs compete with already-final parcels instead of shaping the
  surrounding mass.

These are representation failures, not asset or Godot limitations. Parameter
tuning cannot make a constant-footprint extrusion behave like an interlocking
3D settlement.

## 3. Spatial scale and coordinate system

### 3.0 Settlement scale is a source-plan parameter

Village size is selected before the allocation massif, route, feature set, or
rooms exist. It is not implemented by cropping a large town, deleting its rim,
or scaling placed meshes. A pure `WarrenVillageScaleProfile`, derived from the
world seed and stable settlement identity, owns the bounded planning domain and
the budgets every later stage consumes.

The initial production distribution is deliberately weighted toward small
settlements:

| Scale | Share | Character | Hero-feature budget |
|---|---:|---|---|
| `COMPACT` | 55% | 63 m planning diameter; one dense climbing knot | covered market, 1 skywalk, 4 balconies, 4 room cantilevers, no prefab landmark |
| `STANDARD` | 30% | 69 m diameter; two or three interlocked street episodes | covered market, 2 skywalks, 5 balconies/cantilevers, 1 landmark |
| `LARGE` | 12% | 75 m diameter; full warren grammar | covered market, 3 skywalks, 6 balconies/cantilevers, elevated courtyard, 2 landmarks |
| `GRAND` | 3% | 87 m diameter; rare regional centre and stress case | covered market, 3 skywalks, 8 balconies/cantilevers, elevated courtyard, 3 landmarks |

These percentages are deterministic selection weights, not streaming spawn
probabilities. They make the median settlement substantially smaller than the
current seed-7 showcase. The existing large review town remains an explicit
`LARGE` fixture rather than the implicit template for every village.

The profile carries at least:

```gdscript
class_name WarrenVillageScaleProfile

var scale_id: StringName
var radius_cells: int
var minimum_core_bands: int
var maximum_core_bands: int
var route_cell_range: Vector2i
var route_span_range: Vector2i
var lane_budget: int
var lane_cell_budget: int
var room_volume_budget: Vector2i
var residual_room_budget: int
var residual_kind_budget: int
var skywalk_range: Vector2i
var balcony_range: Vector2i
var cantilever_range: Vector2i
var landmark_range: Vector2i
var requires_elevated_courtyard: bool
var requires_covered_market: bool
```

Size changes the amount of authored mass and the length of the negative-space
route, not the density doctrine. A compact village still has narrow streets,
touching buildings, at least one overhead crossing, real roofs, and complete
support. It must not become a few detached cottages merely because its bounds
are smaller.

Feature minimums are conditional only where the feature genuinely needs the
larger topology. The covered market remains part of every size. The 6 x 6 m
third-storey courtyard is mandatory for `LARGE` and `GRAND`; `STANDARD` may
admit it when the sealed route reaches the required datum; `COMPACT` does not
reserve one. A smaller town is never rejected for lacking a large-town feature
that its selected profile did not request.

All integrity gates remain scale-invariant: zero public-air/occupied overlap,
complete bearing, exact entrances, typed seams, roof closure, and connected
public circulation. Aesthetic count/length gates are expressed by the profile
or normalized by available route/facade area. Stable signatures and cache keys
include `scale_id`, and terrain placement rebuilds must reuse the exact selected
profile.

The current total inhabited-room budgets are 18–110, 30–190, 50–220, and
80–300 from compact through grand. They count both route-frontage composition
and residual infill; the latter cannot disappear from the size audit merely
because it was packed in a later phase. Residual infill is independently capped
at 12/16/24/32 rooms (3/4/6/8 per room family), preventing a compact source
from quietly growing a large town's secondary shoulder. Landmark requirements
similarly scale 0/1/2/3. A standard town's two skywalks may remain internal to
the connected room mountain; large/grand landmark groups require at least one
occupied connector endpoint.

### 3.1 One uniform fine lattice

The new planning lattice uses **1.5 m cells on all three axes**.

```text
FINE_CELL_SIZE_M = 1.5
STOREY_CELLS     = 2       # 3.0 m
ROOM_BAY_CELLS   = 2 x 2   # 3.0 m x 3.0 m
STREET_WIDTH     = 2       # 3.0 m clear
MIN_HEADROOM     = 2       # 3.0 m clear
```

This unifies the current 1.5 m `FabricRecipe` lattice with the volume planner.
The present `WarrenVolumePlan` uses 3 m horizontal macro cells and 1.5 m vertical
bands; each of its horizontal cells maps to a 2 × 2 fine-cell square.

The fine lattice is necessary for:

- 1.5 m facade offsets and asymmetric upper floorplates;
- usable 1.5 m-deep balconies;
- half-bay jetties and room outcroppings;
- narrow stairs, alleys, and side passages without changing vertical units;
- skywalks that need not align to a whole 3 m parcel column;
- precise public-air and visual-clearance reservations around authored pieces.

Authored 3 m modules remain the common construction unit. The fine grid is not
permission to scale meshes or fill every 1.5 m cube with a separate asset.

### 3.2 Bounded storage

A town plan has fixed local X/Z bounds and a fixed vertical band range derived
from its accepted massif. The expected planning domain is small enough to use
flattened packed arrays rather than nested dictionaries. A 64 × 64 × 24 fine
grid contains 98,304 cells and is comfortably bounded.

The proposed `WarrenSpatialGrid` stores hot mutually exclusive cell state in
packed arrays and sparse data only for uncommon facts:

```gdscript
class_name WarrenSpatialGrid

var bounds: AABB  # integer lattice bounds, represented by explicit min/max fields
var use_by_cell: PackedByteArray
var owner_by_cell: PackedInt32Array
var reservation_bits_by_cell: PackedInt32Array
var support_owner_by_cell: PackedInt32Array
var face_claims: Dictionary  # sparse: encoded (cell, direction) -> face record
var feature_records: Array[WarrenFeatureReservation]
```

All state remains CPU-only and worker-safe. No meshes, resources, nodes, or
physics objects may enter this plan.

## 4. The plan has three separate semantic layers

A single cell enum is not enough. The design separates **volume use**,
**reservations**, and **interfaces** so related facts can coexist without being
conflated.

### 4.1 Volume use: what occupies the 1.5 m cube

Exactly one primary use owns each in-bounds cell:

| Use | Meaning |
|---|---|
| `OUTSIDE` | Outside the town allocation envelope. |
| `ALLOCATABLE` | In the initial inhabited massif, not yet assigned. It never renders implicitly. |
| `PUBLIC_AIR` | Protected exterior circulation headroom: street, stair, tunnel, gallery, court, or market aisle. |
| `DAYLIGHT_AIR` | Deliberate exterior void protected from later filling. |
| `PRIVATE_VOLUME` | Inhabited room volume owned by a building; it need not be a playable interior yet. |
| `STRUCTURAL_VOLUME` | A coarse support, pier, chimney core, or other genuinely solid volume. Thin walls and floors are face claims, not full cells. |
| `SERVICE_VOID` | Deliberate non-public void such as a roof pocket or inaccessible light shaft. |

`ALLOCATABLE` is only search material. At final seal every allocatable cell must
have become a real owned volume or been explicitly discarded to `OUTSIDE`,
`DAYLIGHT_AIR`, or `SERVICE_VOID`. It must never compile as a stone monolith or
invisible support.

### 4.2 Reservation overlay: what future work is forbidden to consume

Reservation bits protect planned features before their final construction is
known. They include:

- public swept clearance;
- private connection clearance;
- visual asset clearance;
- terrain-bearing channels;
- vertical load-transfer channels;
- roof drainage and roof-profile clearance;
- a future balcony, jetty, skywalk, stair, market, prefab, or courtyard feature;
- required daylight and sightline apertures;
- construction seams where measured meshes may deliberately meet.

A reservation names an owner and a typed compatibility policy. It is not a
generic "do not overlap" box. For example, a skywalk reservation requires
private or public link air inside it, structural floor/roof interfaces around
it, public air below it, and two endpoint sockets; those uses are compatible
with the reservation while an unrelated room is not.

### 4.3 Face claims: what exists between neighboring cells

Thin construction is represented on oriented cell faces. A face record is keyed
by `(cell, cardinal_direction)` and may classify:

- public floor;
- private floor;
- exterior facade;
- party wall;
- tunnel wall or soffit;
- roof;
- guard;
- door threshold;
- window opening;
- open seam;
- asset-specific construction joint.

Boundary derivation happens after volume ownership is known:

- `PRIVATE_VOLUME` beside `PUBLIC_AIR` produces an addressed facade candidate;
- `PRIVATE_VOLUME` over `PUBLIC_AIR` produces a tunnel/bridge soffit plus a
  bearing obligation;
- two private volumes with the same owner normally have no facade between them;
- private volumes with different owners produce a compatible party-wall seam or
  require separation;
- private volume below exterior air produces a roof or occupied terrace;
- public floor beside unprotected exterior air produces a guard unless an exact
  transition or door opens the edge.

This makes walls, floors, and openings consequences of the same 3D truth rather
than independent placements that can disagree.

## 5. Authoritative records

### 5.1 `WarrenSpatialPlan`

The sealed source of truth for one town:

```gdscript
class_name WarrenSpatialPlan

var stable_id: StringName
var world_seed: int
var grid: WarrenSpatialGrid
var terrain_bands_by_column: PackedInt32Array
var route_graph: WarrenRouteGraph
var buildings: Array[WarrenBuildingVolume]
var features: Array[WarrenFeatureReservation]
var support_graph: WarrenSupportGraph
var audit: Dictionary
```

It replaces the mass-first path from `WarrenMassif` + `WarrenVolumePlan` +
`WarrenParcelPlan` as the authoritative geometry. Compatibility adapters may
project it into existing `SectionalPublicRealmPlan`, `FabricUnit`, and
`VillageOccupancyVolume` records, but those projections may not re-infer or
modify topology.

### 5.2 `WarrenBuildingVolume`

A building is no longer an extrusion. It owns:

- a connected set of private-volume cells;
- an ordered set of room or bay records;
- per-storey floorplate sets;
- exact public thresholds;
- roof regions at one or more elevations;
- facade regions and party-wall interfaces;
- structural parents and bearing descendants;
- typed feature attachments;
- a private connectivity graph, even if interiors are not yet playable.

One building may narrow, widen, split around a court, bridge a passage, or hand
off upper rooms to a different neighboring owner. Its identity follows connected
rooms and access, not a 2D column.

### 5.3 `WarrenRoomStamp`

Room stamps are small volumetric grammar pieces, typically composed from 3 m
bays:

- 3 × 3 × 3 m single bay;
- 3 × 6 × 3 m narrow/deep room;
- 6 × 6 × 3 m hall;
- L-shaped and stepped two-bay rooms;
- double-height room;
- bridge room;
- corner room with a room-scale projection;
- stair/service core;
- prefab-owned irregular envelope.

Each stamp declares private volume, shell interfaces, entrance/socket options,
support requirements, allowed rotations, roof compatibility, and measured
visual clearance. A stamp is a planning contract, not necessarily one mesh.

When recomposition moves or reshapes a complete room, its doorway phase is
derived again from the final world-space room origin, yaw, frontage, and exact
threshold. Reusing the source parcel's half-cell phase is invalid because it can
move an authored door 1.5 m away from topology. Private balcony and skywalk
endpoints select finite portal variants of every reachable facade family,
including stone upper storeys; they open only the requested socket face and do
not invent a public entrance.

### 5.4 `WarrenFeatureReservation`

Every composed feature is an atomic transaction with:

- stable feature ID and kind;
- required/forbidden volume uses;
- reserved cells and face claims;
- endpoint or address sockets;
- bearing/support obligations;
- visual-clearance envelope;
- asset-contract family;
- deterministic alternatives;
- feature-specific audit facts.

The transaction either commits completely or leaves the grid unchanged.
Partially placed markets, unsupported balconies, one-ended skywalks, and
unroofed room projections are impossible states.

## 6. Generation pipeline

### Phase 1 — terrain frame and allocation massif

Sample immutable terrain at every fine-grid column. Build a Gaussian/terraced
allocation envelope with the requested centre-tall gradient and irregular radial
spurs. Fill only the volume above real terrain as `ALLOCATABLE`.

The envelope is potential inhabited construction, not rock and not a promise to
render every cell. Terrain remains the only natural bearing datum. Maximum
height may reach the current 18 bands at the centre, but final height must emerge
as interlocking rooms, terraces, roofs, and voids.

### Phase 2 — reserve the town's structural motifs

Before generic partitioning, choose a compatible set of town-scale reservations:

1. primary ascending street and secondary lane graph;
2. tunnel/undercroft runs and portal locations;
3. one third-storey courtyard volume when required by the selected scale;
4. one covered market volume;
5. several skywalk corridors with endpoint regions;
6. several room-scale jetty/outcropping regions;
7. major exterior stairs and vertical shafts;
8. two to four large or distinctive prefab/landmark envelopes.

This is a bounded deterministic beam search over **compatible feature sets**.
It does not place decorative details. Reserving the hard features first prevents
generic rooms and roofs from consuming the only legal corridors.

### Phase 3 — carve public negative space

Carve the route graph by changing allocation cells to typed `PUBLIC_AIR` and
claiming their floor surfaces. The carver sweeps the entire player clearance,
not merely a centerline.

It may carve:

- open canyon streets;
- covered tunnels through future occupied mass;
- stairs and landings changing one fine band at a time;
- short galleries and bridges;
- undercroft passages beneath the elevated courtyard or buildings;
- the covered market aisle;
- daylight notches and bounded lightwells.

The route must remain a connected exterior public graph from its terrain portal.
Paths are now literally the negative space between reserved/inhabited volumes.

### Phase 4 — stamp landmarks and composed features

Commit the major structures selected in Phase 2 while enough allocation volume
remains to shape their surroundings. A landmark stamp may replace, occupy, or
protect an irregular 3D region; it is not constrained to a generated rectangular
parcel. Neighboring room growth treats its exact sockets and clearance as fixed
facts.

The courtyard, market, and skywalks receive their complete structural and access
contracts here. They are not late prop passes.

### Phase 5 — partition residual volume into room clusters

Seed room growth from exposed public facades at many elevations, then grow and
merge compatible 3D room stamps through remaining allocation cells. Candidate
selection uses a bounded beam or best-first frontier with these priorities:

1. close every required public boundary with a real facade, opening, support,
   or deliberate exterior continuation;
2. preserve all feature and clearance reservations;
3. create complete bearing ancestry to terrain or an already-supported parent;
4. give each building at least one real threshold or an explicit private parent;
5. maximize useful occupation over discarded allocation;
6. create lateral offsets, setbacks, jetties, terraces, and interlocking owners;
7. avoid repeated vertical facade and floorplate patterns;
8. maintain roofable connected top regions.

Growth operates in three dimensions. It may add a room beside, above, below, or
partly offset from its parent. A new storey does not inherit its parent's whole
footprint by default.

### Phase 6 — resolve supports and ownership

Build a directed acyclic support graph from every private or structural volume
to terrain. Accepted support modes include:

- direct terrain bearing;
- complete wall/party-wall bearing below;
- beam or arch spanning a public passage;
- designed cantilever within an asset contract's limit;
- pier/column support belonging to an undercroft or market recipe;
- attachment to a landmark's declared bearing socket.

No unowned allocation cell, invisible substrate, or decorative mesh may satisfy
support. Where a support path cannot be realized, the affected room/feature is
removed transactionally and the boundary is repartitioned.

### Phase 7 — derive interfaces and construction regions

Classify every oriented boundary face from the sealed volume and ownership
facts. Merge compatible coplanar face cells into construction regions, but keep
doors, windows, corners, material breaks, and feature seams explicit.

Roof solving runs over every exposed upper private boundary, not once per
building. One irregular building may therefore have a low lean-to, an occupied
terrace, a cross-gable, a high dormered roof, and a bridge roof at different
levels. Intermediate rooflines are expected and are one of the main ways a tall
centre avoids reading as towers.

### Phase 8 — asset realization

Compile construction regions through `SettlementFabricProgram` and measured
`FabricModuleContract` records. Reuse existing reviewed room, facade, roof,
dormer, market, prefab, and skywalk assets wherever their contracts fit. Add
new recipes/contracts for balconies, room-scale projections, irregular roof
ends, supports, and landmark sockets as needed.

The compiler may choose visual variants, but it may not change the sealed 3D
topology or repair a bad fit with arbitrary offsets or non-contract scaling.

### Phase 9 — secondary detail and props

Only non-structural enrichment happens here: signs, crates, lamps, banners,
plants, chimneys that do not affect roof closure, and market stock attachments.
These details query remaining visual clearance and commit without rebuilding the
town.

The structural plan, feature placement, boundary derivation, and construction
compile each run once. A detail candidate must never trigger a whole-town solve.

## 7. Required feature contracts

### 7.1 Tunnels and building overpasses

A tunnel is a run of public floor plus at least 3 m of swept public air with
owned structure or inhabited volume above it. It requires:

- a connected public entry and exit;
- exact floor, wall, and soffit interfaces;
- a continuous support path around or across its void;
- at least one occupied room or structurally meaningful public surface above;
- portal treatment where it opens to daylight;
- no terrain shell or collider crossing its void.

An awning does not count as a tunnel. A bridge decoration without occupied or
public volume above does not count as building coverage.

### 7.2 Skywalks

Skywalks are topology-first connections between two distinct building volumes.
The grammar supports two explicit kinds:

- `ENCLOSED_SKYWALK`: a roofed, walled connector with private connection air;
- `PUBLIC_SKYBRIDGE`: a guarded or roofed exterior public walkway integrated
  into the route graph.

Both require two real endpoint sockets, complete floor/support/roof treatment,
measured visual clearance, and protected air below. At least one endpoint must
land at a floorplate that is not vertically identical to the storey beneath it,
so links contribute to the interlocked silhouette rather than joining towers at
their midpoints.

The normal large-town target is **three to six** skywalks, with at least two
visibly crossing a public street or court and no duplicate endpoint pair.
Compact and standard profiles use their smaller explicit ranges, but every
accepted town still contains at least one true occupied connector over public
space.

### 7.3 Balconies

A balcony is an exterior occupied floor reservation, not a shallow facade prop.
It requires:

- minimum usable depth 1.5 m and width 3 m;
- a door from a private room;
- derived guards on every exposed side;
- a declared cantilever, bracket, post, or parent-floor support contract;
- reserved headroom and visual clearance;
- no collision with public headroom below unless it is deliberately part of a
  covered-street contract.

Corner, wraparound, stacked-but-offset, and bridge-adjacent balcony families are
allowed. Repeating the same balcony on every storey of one facade is forbidden.

### 7.4 Room-scale outcroppings and jetties

An outcropping is a private room volume that extends at least one fine cell
(1.5 m) beyond the supporting floorplate below over an area of at least 3 × 3 m.
It requires full side walls, floor, roof or occupied parent above, and a legal
support/cantilever path. It changes the building's floorplate and silhouette.

Shallow bay-window assets remain useful facade details, but they do not satisfy
the room-outcropping requirement.

The current construction vocabulary supports a room-scale cantilever with one
measured diagonal timber support course when its swept envelope avoids public
air, daylight, services, unrelated rooms, and feature clearance. A shallow
bracket course is the explicit fallback. Horizontal trim pasted under a room is
not accepted as proof of support.

### 7.5 Third-storey courtyard

Every accepted `LARGE` or `GRAND` town contains one typed elevated courtyard
(`STANDARD` may contain one when its selected profile and route support it)
with:

- a minimum 6 × 6 m public floor at four fine bands (6 m, the third-storey
  datum) above its local terrain reference;
- protected court air above the floor;
- addressed building facades on at least three sides;
- a connected public route reaching the court;
- a real public passage or occupied construction beneath at least part of it;
- a skywalk, bridge room, gallery, or upper path crossing above or along one
  edge without erasing the court's readable central void;
- exact support, guards, entrances, and daylight classification.

The courtyard is therefore a 3D composed volume with circulation below, at, and
above it—not a stamped platform.

### 7.6 Covered market

The market owns one atomic 3D transaction containing:

- a connected public aisle;
- stocked stall bays on one or both sides;
- a continuous canopy, arcade, or occupied building volume above;
- entrances from the street network;
- authored tables/stock attachments;
- support and visual-clearance cells;
- optional rooms, balconies, or passages over its roof.

It may be a compact 6 × 3 m bazaar or a longer irregular market lane. Empty tent
families remain ineligible. The market must read as a district embedded in the
town's mass, not a detached prop group.

### 7.7 Landmark and prefab structures

Up to two to four distinctive authored structures should anchor a large or
grand town when legal:
tavern, forge, guild hall, gatehouse, shrine, or another catalogued complete
building. Each gets a measured irregular occupancy/clearance contract and named
public/private sockets. Residual rooms, streets, roofs, and skywalks grow around
those facts.

Prefabs are allowed to reserve multi-storey non-rectangular volumes. They are
not forced into a generic parcel envelope, and they may not float as detached
showpieces outside the dense contact component.

## 8. Anti-tower composition rules

These are hard plan audits, not aesthetic scores that a dense but repetitive
town may ignore.

### 8.1 Floorplate change

- No generated building may repeat an identical floorplate for more than two
  consecutive storeys.
- Composition records are indexed one storey at a time. A protected second
  storey therefore preserves indices 0–1 but never exempts an optional third
  storey; a genuinely required third-storey interface must be recomposed or the
  complete candidate is rejected.
- A building of four or more storeys must change at least 25% of its occupied
  X/Z cells across each two-storey composition break, measured by symmetric
  difference over the union of the two floorplates.
- A legal change must produce a real setback, addition, terrace, jetty, bridge,
  or ownership handoff. Merely changing wall material does not satisfy it.

Landmark prefabs may request a narrowly scoped exemption only when their authored
silhouette has already been reviewed as non-repetitive.

### 8.2 Facade rhythm

- Vertically adjacent facade runs may not repeat the same module cadence,
  opening phase, and material family through more than two storeys.
- Every tall central facade needs a major break at least every two storeys:
  roofline, terrace, 1.5 m offset, room projection, balcony, skywalk endpoint,
  or ownership seam.
- The same balcony/outcrop pattern may not occupy equivalent coordinates on
  consecutive composition blocks.

### 8.3 Interlocking mass

- Tall central volume should normally be shared by several building owners,
  not one owner extending from terrain to crown over a constant core.
- At least 60% of buildings must touch another building by a compatible party
  wall, roof junction, supported overpass, or skywalk endpoint.
- The largest connected building-contact component must contain at least 80% of
  generated buildings.
- Central height must descend through occupied setbacks and roofs toward the
  rim; empty masonry podiums and bare structural shafts do not count.

### 8.4 Roofscape

- Roof regions occur wherever private volume terminates, including intermediate
  setbacks.
- Accepted towns need at least four roof geometry families and three roof
  elevations in the central half of the footprint.
- Dormers, chimneys, cross-gables, lean-tos, corner roofs, and flat occupied
  terraces are selected from topology, not sprinkled uniformly.
- When a complete pitched roof cannot coexist with measured neighbouring eaves,
  the finite fallback is a guarded private roof terrace. The compiler first
  tries a lived-in variant whose planters, laundry, stone chimney, or complete
  blue canopy participate in the same visual-clearance transaction, then an
  undressed guarded terrace, and only then the exact bare cap. Partial setback
  strips prefer a rail on a genuinely exposed long edge; an enclosed strip may
  instead receive a measured planter-only roof garden. Every dressed strip has
  the exact plain cap as its transactional fallback, and true one-storey narrow
  closers preferentially use integrated chimney roofs. No public walkability is
  invented.
- Roof qualification intersects every semantic solid cell of the transformed
  candidate with the sealed 3D public-air grid. Checking only the first band
  above the source face is invalid: a two-band gable can clear that band while
  piercing an elevated street above it. Such a candidate is rejected before
  placement and the exact roof face receives a thin non-occupying weather cap.
- No single roof material family may dominate more than 55% of primary roof
  area in a showcase town unless the asset catalog cannot satisfy the measured
  seams; such a failure blocks acceptance rather than silently weakening the
  rule.

## 9. Reservation and transaction rules

All writers use a common transaction API:

```gdscript
var tx := grid.begin_transaction(feature_id)
tx.require_use(cells, allowed_uses)
tx.reserve(cells, reservation_kind)
tx.assign_use(cells, final_use, owner_id)
tx.claim_faces(face_records)
tx.require_support(support_records)
if tx.validate():
	tx.commit()
else:
	tx.rollback()
```

The conflict matrix is centralized. At minimum:

- public/daylight air is incompatible with private or structural volume;
- two private volumes may meet but never overlap;
- visual-clearance reservations may overlap only at named construction seams;
- public headroom may sit beneath an occupied bridge only when the bridge owns
  the separating soffit and support contract;
- roof clearance may be consumed only by the roof family that reserved it;
- terrain-bearing cells may be shared by compatible load paths, never replaced
  by unexplained allocation mass;
- a feature may replace its own provisional reservation but not another
  feature's reservation without a declared alternative transaction.

Stable IDs are hash-derived from world seed, town ID, grammar role, and local
ordinal. They never include search order or streaming chunk ownership.

## 10. Search strategy and performance

The old detail pipeline repeatedly rebuilds a whole town while testing optional
features. That is incompatible with visual iteration and caused individual
showcase solves to take many minutes.

The volumetric solver uses three bounded searches:

1. **topology beam:** route plus compatible hero-feature reservations;
2. **room frontier:** residual 3D partition and support DAG;
3. **construction alternatives:** asset/roof choices inside the sealed topology.

Each search stores reversible transactions or copy-on-write deltas, not a newly
compiled town per candidate. Expensive asset expansion and mesh-envelope audits
run only on sealed finalists. Secondary details never re-enter structural
search.

Performance acceptance will be based on measured corpus percentiles, but the
architectural gate is immediate: the number of complete construction compiles
per town is bounded by the finalist count and is independent of the number of
balcony, dormer, prop, or market-detail candidates.

## 11. Asset-program work

Before construction implementation, inventory the existing catalog and compile
measured contracts for:

- complete buildings and landmarks;
- facade wall, corner, door, window, and party-wall modules;
- room floors and structural soffits;
- pitched, cross, corner, lean-to, flat, and end-cap roofs;
- dormers and chimneys;
- enclosed skywalk lengths and endpoints;
- balcony floors, rails, brackets, and doors;
- support posts, arches, beams, and undercrofts;
- market canopies, stalls, tables, and stock attachments;
- exterior stairs, galleries, and guards.

Missing art is recorded as a contract gap, not substituted with visible
primitive boxes or arbitrary mesh scaling. Composite recipes may assemble
reviewed assets into a larger feature when every seam and support is explicit.

## 12. Sealing invariants

`WarrenSpatialPlan.seal()` must prove all of the following before assets are
selected:

1. all public floor nodes form one exterior-reachable graph;
2. every public node owns full swept headroom;
3. public/daylight air overlaps no private or structural volume;
4. every private-volume component belongs to exactly one building;
5. every building has a public threshold or explicit private attachment to a
   building that does;
6. every private/structural volume has a complete acyclic bearing path;
7. every exposed public edge is a transition, door, wall, or guarded edge;
8. every public/private boundary has a classified interface;
9. every different-owner private boundary is a valid party wall or separation;
10. all mandatory feature reservations are complete and addressed;
11. the courtyard has valid below/at/above circulation;
12. skywalks have two distinct valid endpoints;
13. balconies and outcroppings have full support and shell contracts;
14. no `ALLOCATABLE` cell survives final classification;
15. anti-tower floorplate and facade-break rules pass;
16. all signatures are deterministic under repeated and order-perturbed solve.

After asset realization, the existing visual-envelope and mesh-overlap audits
remain mandatory. The construction plan must also prove that every plan-level
interface was realized exactly once.

## 13. Visual and corpus acceptance

Structural correctness is necessary but not sufficient. Accepted showcase towns
must pass both measurable gates and human review from overview and street-level
cameras.

Initial corpus targets, to be calibrated only with recorded evidence:

| Property | Target |
|---|---|
| Primary route vertical span | at least 8 bands |
| Primary route with a building boundary on both sides | at least 70% |
| Public route with occupied/structural cover | 45–70% |
| Longest unbounded ground-street run | at most 12 m |
| True skywalks | selected scale range; always at least 1 over public space |
| Usable balconies | selected scale range, distributed across buildings |
| Room-scale outcroppings/jetties | selected scale range |
| Landmark/prefab anchors | selected scale range when catalog contracts fit |
| Elevated third-storey courtyard | exactly 1 where the scale requires it |
| Covered market | exactly 1 |
| Dormered roof regions | at least 4 |
| Identical generated floorplate run | at most 2 storeys |
| Public-air/private-volume overlaps | 0 |
| Unsupported occupied cells/features | 0 |
| Unclassified required interfaces | 0 |
| Visual-envelope/mesh conflicts | 0 outside named seams |

Counts are guardrails against silently dropping requested features. They do not
replace visual judgment. A town fails review if it still reads as towers, a
collection of freestanding houses, a stone monument, broad plazas, decorative
bridges, or repeated facade wallpaper even when numeric gates pass.

The review harness captures at minimum:

- four overview obliques;
- the entry street;
- the longest covered route;
- both sides of the market;
- courtyard views from below, at court level, and from the upper crossing;
- every skywalk from street and endpoint viewpoints;
- representative balcony/outcropping clusters;
- the central roofscape.

Every image receives an explicit falsification disposition. Problems found by
review are successful evidence and become new plan/contract tests when they are
structural rather than seed-specific taste.

## 14. Testing strategy

### Unit tests

- fine-grid indexing, transforms, and macro/fine conversion;
- transaction commit/rollback and the full conflict matrix;
- route sweep, stairs, portals, and connected public-air flood;
- room-stamp rotation and ownership;
- boundary-face derivation for facade, party wall, soffit, roof, door, and
  guard cases;
- support DAG cycle and missing-bearing detection;
- atomic balcony, outcrop, skywalk, market, prefab, and courtyard contracts;
- anti-tower floorplate and facade-rhythm audits;
- deterministic signature invariance under candidate visitation order.

### Property and corpus tests

- random valid transactions never produce incompatible cell use;
- every accepted route remains exterior-reachable after partition;
- every accepted private cell reaches terrain in the support DAG;
- town geometry is identical across chunk projections and repeated runs;
- a multi-seed corpus meets topology, feature, variety, and runtime floors;
- a broad deterministic corpus matches the scale weights and monotonically
  increases footprint/route/room budgets from compact through grand;
- the same settlement identity always selects the same scale, including during
  terrain-relative rebuild and chunk-order perturbation;
- the compact production fixture proves a bounded non-greedy two-arcade choice
  survives the same topology gate before and after gallery construction;
- sabotage tests remove one endpoint, support, guard, roof, facade, or air cell
  and prove the corresponding seal fails.

### Visual tests

Use the existing capture/falsification discipline. Add occupancy overlays and
exploded storey views so a reviewer can see building ownership and floorplate
changes directly, not infer them from the final skin.

The spatial review harness also has a production-terrain mode. It must run the
real site selection and terrain-relative rebuild, commit the exact final entry
list including terrain-derived supports, render the surrounding terrain chunks
in the town frame, and omit any diagnostic road skin. A production-terrain
capture therefore judges the actual negative-space streets and bearing result,
not the same town floating over a flat review slab.

## 15. Migration plan

The replacement lands behind a third explicit generation kind, provisionally
`volumetric_mass_first`. It must not change route-first or the current
mass-first signatures while under development.

### Wave 0 — contracts and diagnostic representation

- add fine-grid coordinate/conversion helpers;
- inventory relevant assets and record missing contract families;
- build a debug renderer for cell use, owner, reservation, support, and faces;
- pin current pipelines with byte/signature A/B tests.

### Wave 1 — grid, transactions, and public topology

- implement `WarrenSpatialGrid`, transactions, and seal basics;
- project an existing massif into fine allocation cells;
- carve one connected ascending street with genuine tunnel air;
- adapt public surfaces losslessly into the existing assembler.

### Wave 2 — 3D room partition and shell derivation

- implement room stamps and multi-height building ownership;
- derive facades, floors, party walls, soffits, and roofs from volume boundaries;
- enforce support ancestry and anti-tower rules;
- compile a plain but structurally honest town from existing modular assets.

### Wave 3 — mandatory composed features

- elevated courtyard with below/at/above paths;
- covered market;
- topology-first skywalks;
- balconies and room-scale outcroppings;
- distinctive prefab/landmark anchors.

### Wave 4 — vocabulary and roofscape

- fill measured asset-contract gaps;
- expand roof junctions and intermediate roof regions;
- restore dormers, chimneys, facade stairs, material families, and local style
  correlation without vertical repetition.

### Wave 5 — performance and visual iteration

- remove repeated full-town compiles from candidate search;
- run structural corpus, then detailed showcase corpus;
- review every capture, turn structural visual failures into invariants, and
  iterate until all showcase views satisfy the stated doctrine;
- make the new kind production-default only after it outperforms both previous
  pipelines on density, bounded streets, feature presence, variety, grounding,
  runtime, and visual review.

The old mass-first partitioner should be deleted only after the new production
path has two consecutive green showcase batches and route-first A/B evidence is
archived.

## 16. Explicit non-goals

- Playable private building interiors. Private volume and connectivity are
  planned now so exterior massing is honest; interior gameplay may compile
  later.
- Runtime voxel rendering or destructible terrain.
- Cutting holes in the heightfield. Every tunnel exists above terrain inside
  authored fabric.
- Freeform mesh CSG as a repair mechanism.
- Arbitrary asset scaling, negative scale, or per-instance visual nudges.
- Filling unused allocation mass with rock, blank boxes, or invisible support.
- Treating props, awnings, or detached platforms as substitutes for inhabited
  mass and public topology.

## 17. Cross-section of the intended result

```text
                         dormer roof       offset upper room
                      /-------------\      +---------+
              roof   / private volume\____|         |
        +------------+---------+      skywalk       |
        | setback room         |=======+============+
        +---------+------+-----+       | balcony
 courtyard air    | room | room-scale  +------+
  +===============+======+ jetty              |
  | public court  | facade                     |
  +=====+=========+============================+
  | room| passage below court / covered market |
  +-----+----+----------------------+-----------+
 terrain    narrow public tunnel   terrain
             (negative space)
```

The important property is not the drawing's exact arrangement. It is that every
piece—tunnel, room, court, balcony, projection, roof, market, and skywalk—owns a
compatible part of one sealed 3D plan before construction begins.
