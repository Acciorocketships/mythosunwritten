# Paths & Manmade Features (v1) — Design Spec

**Date:** 2026-07-17
**Status:** Proposed design, awaiting owner review.
**Scope:** The first slice of the master design's settlement-and-path layer (§11.6): a
deterministic, terrain-aware **path network** rendered as tan trails painted into the
terrain surface, plus the three prop types that hang off it with precise situational
placement rules — **bridges** at water crossings, **lamp posts** along routes, and
**arches** as gateways. Network nodes are published as future settlement sites but no
settlement content is built here.

---

## 1. Decisions (locked during design)

| Question | Decision |
|---|---|
| What paths ARE | Painted into the walkable terrain mesh (a tan swatch in the existing KayKit atlas, per 3 m sample), not mesh tiles — no pack has dirt-path pieces, and painting gives slope conformance, junctions, and chunk seams for free |
| Path geometry | Axis-aligned corridors on the 24 m cell grid, 6 m (2-sample) wide; straight runs, L/T/X junctions, and node plazas all emerge from one per-cell connection mask |
| Network model | Nodes (future settlement sites) on a 768 m super-grid at locally flat/dry spots; routes are Manhattan-monotone staircase traces between neighbouring nodes, terrain-cost-steered, dropped whole when blocked |
| Terrain reshaping | **None in v1.** Paths conform to the existing surface (slopes read as ramps). Flattening needs a signed pre-quantization height field — a new mechanism, deferred with a named hook |
| Props | Identity-free static features (no interaction/persistence), placed by `PathPlan`, committed like structural dressing: collision before chunk readiness, budgeted MultiMesh visuals |
| Bridge span problem | River carve half-widths are 9–16 m (18–32 m channels) vs a 10.5 m bridge at raw scale. Resolve with a bake scale chosen from measured wet-width statistics (start 1.75×) **and** per-site legality gating — roads cross rivers only where a bridge actually fits |
| Prop tinting | `tint_group: "identity"` — manmade props keep their painted look; the painted path surface itself still multiplies the shared ground tint like every terrain texel |
| Lamp light | Emissive material only in v1; real warm `OmniLight3D`s later via the existing per-chunk biome-FX light-point payload (named hook, deferred) |
| Asset sources | All four props come from **FantasyVillageFBX** (the request's `BattlePackFBX/FBX/Lamp/SFV_Light_Pole_001` doesn't exist; the SFV light pole lives in `FantasyVillageFBX/FBX/Exterior Props/Light Pole/`, and BattlePack has only hand/wagon lamps) |

Measured raw-scale asset sizes (probed from the imported FBX):

| Asset | Size (m, W×H×D) | Note |
|---|---|---|
| `SFV_Light_Pole_001` | 0.35 × 2.97 × 1.36 | pole with a 1.36 m lantern arm |
| `SFV_Arch_001` / `002` | 10.55 × 8.15 × 3.83 | town-gate scale |
| `SFV_Entrance_Arch_001` | 3.87 × 4.20 × 0.25 | small garden gateway |
| `SFV_Bridge_001` | 4.69 × 2.27 × 10.51 | deck along Z |

The pack is metric-sane at 1×: lamp and arches bake at 1.0; only the bridge takes a
span-driven scale. Every choice is reviewed in the catalogue lineup against the 1 m
marker before tuning.

---

## 2. Invariants

Inherited from the terrain architecture and binding here:

- **Pure, deterministic, churn-free.** The network is a function of `(world_seed, cell)`
  via splitmix64 named-salt hashing, exactly like `WaterPlan`. No chunk order, worker
  timing, enumeration order, or clock participates. A route is identical no matter which
  chunk asks first.
- **Bounded windows.** A Manhattan-monotone route lies inside its endpoints' bounding box
  (+1 cell) by construction — tighter than river traces. Chunk queries enumerate the
  bounded super-cell neighbourhood; traces are memoized on the worker-owned plan instance
  (the `_region_for` pattern).
- **Half-open ownership.** Props are cell-keyed; a chunk emits only anchors inside its
  half-open bounds. Overlapping queries agree bit-for-bit.
- **One-directional coupling.** `PathPlan` **reads** `HeightfieldPlan`, biome fields, and
  water data; it never modifies terrain or water. Dressing and grass read the path
  clearance field pointwise (the exact integration the deco spec reserved); nothing reads
  back from streamed nodes.
- **Pure worker boundary.** Worker payloads are asset IDs, transforms, and colours — no
  `Resource`, `Shape3D`, node, or RID. (The corridor mask never travels: painting happens
  inside the terrain compute itself.) Collision-bearing features
  attach before the chunk enters the built set (atomic physical readiness).
- **One tint field / one material.** The path texel lives in the same KayKit atlas and
  multiplies the same per-vertex ground tint as grass and rock. Props resolve tint through
  their descriptor's `tint_group` like all environment assets.

---

## 3. Components

```text
scripts/terrain/features/
  PathPlan.gd       # nodes, routes, crossing profiles, corridor + clearance queries (pure, memoized)
  FeatureField.gd   # per-chunk pure compute: prop placements from the plan + region + water
  FeatureCommit.gd  # thin main-thread adapter: collision StaticBody3D + queued visuals

tools/environment_bake/
  manifests/fantasy_village_features.json
  collision_sources/  (bridge deck+rails, arch legs, lamp pole templates)
```

- **`PathPlan`** — worker-owned (like `_water`), seeded once. Public surface:
  `routes_near(window) -> Array[PathRoute]`, `corridor_at(sample_xz) -> bool`,
  `clearance_at(xz) -> float` (distance beyond corridor/prop footprints, saturated at a
  small limit), `settlement_sites(window) -> Array[Vector2i]` (published for the future
  settlement generator).
- **`FeatureField.compute(plan, world_seed, core, region, water) -> Dictionary`** — pure;
  returns `{placements: [{asset_id, transform}, …]}` for anchors the chunk owns.
- **`FeatureCommit`** — mirrors `DressingCollisionBuilder`/`DressingCommitQueue` usage:
  one `StaticBody3D` ("FeatureCollision") attached before readiness, visuals through the
  existing budgeted commit queue (reuse it if its payload shape fits; else the same
  budget/generation rules in ~30 lines). Prop counts per chunk are tiny (≤ ~10).

`TerrainChunkMesher` gains `set_path_plan(plan)` (duck-typed `corridor_at`), mirroring
`HeightfieldPlan.set_water_plan` in spirit: one query at the one place UVs are chosen.

---

## 4. The path network

### 4.1 Nodes (future settlement sites)

Per 768 m super-cell (same pitch as `WaterPlan.SUPER`, distinct salts):

1. Existence roll `p ≈ 0.75`. No special spawn suppression: the flat spawn disk is tiny
   (60 m) against the 768 m pitch, and a road or plaza brushing the starting clearing is
   a feature, not a bug.
2. K = 5 candidate cells hashed inside the central half of the super-cell; each scored by
   a bounded stencil: storey span (flatness), dryness (`shore_distance`), and meadow
   weight (`Helper.biome_weights5`). Lowest score wins, hash tie-break.
3. The node is that cell, snapped to the cell grid. Highland/rocky super-cells usually
   fail the score floor and produce no node — mountains stay trackless.

### 4.2 Routes

For each node pair on 4-neighbouring super-cells (edge keep-roll ≈ 0.7, traced once from
the lexicographically smaller node so both sides agree):

- **Monotone staircase.** From A toward B, each step picks between the 1–2 axis-forward
  neighbour cells by local cost: storey delta, slope-vs-cliff class (a cliff edge between
  cells is illegal; a walkable smootherstep slope is allowed but costed), wet cells
  (legal **only** through a viable bridge crossing, §5.1), rocky-biome weight, plus a
  straight-run hysteresis bonus so legs stay long instead of dithering every cell.
  Hash tie-break.
- **Whole-route drop.** If no legal step exists, or the climb budget is exceeded
  (default: ≤ 6 total storeys of ascent, tunable), the route is dropped deterministically. Sparse networks in rough country are
  the intended look, not a failure.
- A route record carries: ordered cells, per-cell connection directions, bridge sites,
  and its two node endpoints.

### 4.3 Corridor mask and painting

Each route cell knows its connection set `C ⊆ {N, E, S, W}`. The painted mask on the 3 m
sample grid is: the central 2-sample (6 m) band from cell centre toward each connected
edge — one formula that yields stubs, straights, corners, Ts, and crosses. Node cells
paint a 12 × 12 m plaza square. Junction variety is emergent, never enumerated.

Mesher integration, at the single point `compute_chunk` assigns `uv := _grass_uv`:

- `SlopeAtlas.path_uv()` returns a tan swatch from the same atlas (candidate texels
  confirmed present, e.g. `#c5825a` near uv (0.25, 0.25–0.30); final pick at lineup).
- Only walkable grass-sheet quads may repaint — never cliff-tuck triangles, skirts,
  or aprons.
- Only **dry** samples paint; a corridor's wet run is the bridge's job.
- Painted vertices keep their ground-tint vertex colour, so trails shift with biome
  palette exactly like rock and grass. If the tint reads too green over tan, choose a
  brighter swatch (multiplication only darkens) — a QA knob, not a mechanism.
- Optional tuning lever: hash-dither the outermost mask samples for frayed edges. Off by
  default; the crisp 3 m quantization matches the storey aesthetic.

Painting is visual only — collision, height, and classification are untouched.

---

## 5. Props — situational placement rules

Common rules. Identity is cell-keyed — `(world_seed, PATH_SEED_VERSION, cell, salt)` — so
overlapping routes dedupe by construction. Anchors ground on `TerrainSurfaceField` at
final positions with a support stencil (reject height span / grade beyond limits, the
`GROUND_SUPPORT` idea). Water facts come from `WaterFieldContext`. Priority ordering is
deterministic: bridge sites and node/arch cells are excluded from lamp eligibility before
lamps roll; no runtime arbitration needed.

### 5.1 Bridges — `sfv.bridge.001`

At each corridor wet run, measure the **crossing profile** along the path axis at 3 m
samples (the run the deck must actually span — correct even for oblique rivers):

- wet run length `L`, first-dry bank heights `h_a`, `h_b`, water level `w`
  (centerline/width facts recoverable from `raw_context().rivers` → `RiverTrace`, same
  segment projection the carve uses);
- **legal iff** `L + 2·LANDING ≤ DECK_SPAN` (`LANDING ≥ 1.5 m` of dry deck per bank),
  `|h_a − h_b| ≤ 1.0 m`, deck underside clears `w` plus the wave bound, and both bank
  support stencils pass.

Placement: centred on the run midpoint, deck along the path axis, base at the bank
midpoint height `(h_a + h_b) / 2` — with the 1.0 m bank-delta gate, each deck end then
sits within the character's step-up of its bank. An illegal crossing makes
that trace step illegal — the staircase shifts to hunt a narrower reach, or the route
drops. Bridges therefore appear exactly where crossing is plausible, which is the natural
look. `DECK_SPAN` comes from the baked scale: probe wet-width statistics at the pinned
review seed and pick the manifest scale (starting guess 1.75×) so the narrow-to-median
reaches are spannable; verify bulk/rail height against the character in the lineup.

Collision: authored `collision_source` template — deck boxes following the arc (walkable)
plus rail boxes; **no shape blocks the channel under the deck**, preserving swim-under.
The static-depth swim gate already handles a character standing on the deck above water
(depth goes negative; no false swim/wade).

### 5.2 Lamp posts — `sfv.light_pole.001`

- Eligible cells: straight (degree-2) corridor cells that are not node, arch, or bridge
  cells.
- Keep-roll tuned to ~1 lamp per 2–3 route cells (48–72 m spacing), with a 1-cell
  adjacency thin-out by hash rank so lamps never crowd.
- Anchor: corridor edge offset (≈ ±4.5 m perpendicular from centreline), side alternating
  by hash; require dry (`shore_distance` margin) and a flat local stencil.
- Yaw: lantern arm (the 1.36 m overhang) faces the path.
- Collision: slim pole box template. Emissive lantern material in v1; no light node.

### 5.3 Arches — `sfv.arch.001/002` (gates), `sfv.entrance_arch.001` (waypoint)

- **Gate arch**: candidate cells 1–2 route cells out from a node along each approach;
  requires a straight segment and a flat, dry 12 m support stencil across the path axis.
  Hash-select at most 2 approaches per node; centred on the corridor, yaw perpendicular
  to the path so the road passes under the span. Variant 001/002 by hash.
- **Entrance arch**: rare hash-gated waypoint marker on straight flat mid-route cells
  (4 m stencil), same orientation rule — a small "you are somewhere" beat between nodes.
- Collision: leg-box templates only, so the opening stays walkable; verify the gate's
  clear opening comfortably passes the 6 m painted corridor at lineup (legs standing on
  the tan edge is acceptable town-gate framing).

---

## 6. Pipeline integration

Worker (`FieldTerrainStreamer._worker`, after the dressing payload — region and water
context are already in hand):

```gdscript
features_data = FeatureField.compute(_paths, world_seed, core, region, water_context)
```

`_paths` is a worker-owned `PathPlan` (no locks, memoized traces), created beside
`_water`; the mesher gets `set_path_plan(_paths)` at startup so painting happens inside
the existing terrain compute. Feature visuals warm at startup alongside cliff visuals.

Main-thread commit order (unchanged pattern): terrain → water → dressing collision →
**feature collision** → `add_child` (built) → FX → queued dressing + feature visuals.

Suppression (the deco spec's reserved read): `DressingField._qualify` gains the plan (or
a thin context) and a `_feature_ok` twin of `_water_ok` — structural sets reject anchors
with `clearance_at(anchor)` under ~2 m beyond the corridor edge; ground-cover sets use a
smaller margin. The grass carpet, when it lands, adds the same one-line qualification
(`clearance_at ≥ 0.3 m`) next to its shore-distance check.

**No terrain reshaping in v1** — and the hook for later is named: a signed, target-level
field applied before storey quantization (water's `carve_at_cell` slot only lowers, and
flat decks fight the 4 m quantize + monotone clamp; that mechanism is its own design).

---

## 7. Assets & bake

New manifest `fantasy_village_features.json` (pack `fantasy_village`, `default_scale`
1.0 — deliberately separate from the 1.5× lily-pad file):

| id | source (FantasyVillageFBX/FBX/Exterior Props/…) | scale | collision | tint_group |
|---|---|---|---|---|
| `sfv.light_pole.001` | `Light Pole/SFV_Light_Pole_001.fbx` | 1.0 | `collision_source` pole box | identity |
| `sfv.arch.001` | `Arch/SFV_Arch_001.fbx` | 1.0 | `collision_source` leg boxes | identity |
| `sfv.arch.002` | `Arch/SFV_Arch_002.fbx` | 1.0 | `collision_source` leg boxes | identity |
| `sfv.entrance_arch.001` | `Arch/SFV_Entrance_Arch_001.fbx` | 1.0 | `collision_source` leg boxes | identity |
| `sfv.bridge.001` | `Bridge/SFV_Bridge_001.fbx` | ~1.75 (from wet-width stats) | `collision_source` deck+rails | identity |

Tags: `feature` plus one of `lamp`/`arch`/`bridge` (new tags; none trip the
tree/rock/deadwood forced-collision rule — these declare `collision_source` explicitly).
`supports_instance_color: true` with identity tint keeps the stable brightness roll
available. Bake, then review in `environment_lineup.tscn -- --show-collision` beside the
1 m marker and a character for scale, opening widths, and collision fit.

---

## 8. Verification

**GUT** (mirroring the pipeline suites):

- `test_path_plan` — determinism and window-independence (identical routes regardless of
  query order/window); canonical trace direction; monotone containment (route ⊆ endpoint
  bbox + 1); whole-route drop determinism; node scoring stability; clearance-query
  agreement with the corridor mask.
- Corridor seam — two adjacent chunks paint bit-identical shared-edge samples; mask
  formula produces exactly the connection shapes (stub/straight/L/T/X/plaza).
- Crossing profile — synthetic heightfield override + water: legality thresholds (span,
  bank delta, clearance) each rejected/accepted at the boundary; deck ends within step-up
  of banks.
- `test_feature_field` — half-open ownership (no duplicate/missing props across
  windows); support-stencil rejection; lamp exclusion near bridges/arches/nodes; payload
  purity (no Resource/Shape3D/Node recursively).
- Dressing suppression — structural anchors inside the corridor+margin rejected; far
  anchors bit-identical to a plan-less run (adding features must not reroll distant
  dressing).

**Visual battery** — `review_features.json` pinned-seed teleports through the godot-MCP
loop: straight run, L corner, T and X junctions, node plaza, lamp line spacing/side
alternation, gate arch approach, bridge crossing (walk over, swim under, wade at banks),
path ramp over a walkable slope, a mountain super-cell with no network, dressing/grass
clearance edges, and a chunk-seam pan along a corridor. Screenshot before/after per the
falsification workflow.

**Perf gates** — 49-chunk profile attributes path trace + feature compute separately;
corridor sampling must not measurably move mesher time (it is one bucketed lookup per
3 m sample); startup unchanged (traces are lazy + memoized).

---

## 9. Delivery phases (each lands runnable)

1. **Bake wave** — manifest + collision templates + lineup QA; wet-width statistics probe
   at the pinned seed to fix the bridge scale.
2. **Network + paint** — `PathPlan` nodes/routes, corridor mask, `SlopeAtlas.path_uv()`,
   mesher painting, and the minimal structural-dressing clearance (trees can't stand on
   the road). GUT + teleport battery. The world visibly gains roads.
3. **Bridges** — crossing profiles, route-legality coupling, placement + collision,
   swim/walk QA.
4. **Lamps + arches** — placement rules above, exclusion ordering, lineup-verified yaw
   and offsets.
5. **Polish** — clearance margins per dressing set, tint/swatch tuning, perf gates,
   AGENTS.md update; decide whether lamp FX lights ride the biome light-point payload or
   stay deferred.

---

## 10. Explicitly deferred

- Terrain flattening/cuttings under paths (signed target-level field pre-quantization).
- Settlements and buildings on the published node sites; plaza content.
- Fences, direction signs at junctions, carts, and other route furniture.
- Real lamp light nodes (named hook: the per-chunk biome-FX ground-anchored light
  points), day/night behaviour.
- Path wear variation, non-right-angle organic trails, navigation integration.
- Persistence, interaction, or gameplay identity for any feature — that graduation stays
  with the future world-feature/entity layer per the deco spec's ownership table.
