# Paths & Manmade Features — Implementation Plan

**Date:** 2026-07-19
**Spec:** `docs/superpowers/specs/2026-07-17-paths-manmade-features-design.md`
**Goal:** Add deterministic 4 m terrain-painted paths, usable bridges, lamp posts, and arches while preserving the field-driven, churn-free terrain invariant and the one-worker purity boundary.

This plan is deliberately staged around the risky facts. Measure bridge sizing, path width, water-approximation error, topology, and halo cost first; consolidate shared environment infrastructure without changing dressing output; implement the entire planner as pure data; then make one atomic streamer change that exposes painted paths and bridge collision together.

Every task ends with the relevant focused tests and the full existing GUT suite green. Do not carry an intentionally red test across a task boundary.

## 1. Non-negotiable implementation rules

- `PathPlan` is the only owner of nodes, accepted routes, bridge legality, prop placement, stable IDs, reservations, and clearance. Consumers query; they do not infer or reroll.
- Keep path code path-specific. Do not add a base feature-plan type, registry, plugin interface, dependency graph, reverse halo map, retry layer, or generic context aggregator in v1.
- Keep one canonical 192 m key grid. Terrain chunks and feature blocks use the same `Vector2i` keys and half-open ownership rule.
- Ordinary route expansion may read exact terrain but must create **zero** exact `WaterFieldContext`s. Only provisional node validation, canonical bridge profiling, and the selected route's final validation may request exact water.
- Candidate rejection is terminal at every level: no second node candidate, no alternate route after exact failure, and no post-route bridge repair.
- The worker returns only primitive containers, transforms, colours, immutable contexts, and typed payloads. No `Node`, `Mesh`, `Material`, `Shape3D`, `MultiMesh`, RID, or resource load crosses into worker computation.
- Feature collision is readiness-critical. Feature visuals remain budgeted and may arrive later.
- Empty feature blocks are readiness facts, not scene objects.
- Use named salts and lexicographic fallbacks for every deterministic ordering. Never depend on `Dictionary` iteration order.
- Keep the route hot path array/index based. Do not allocate a `WaterFieldContext`, `PathContext`, or object per DP state.
- Reuse existing shared material/tint behavior. Path painting changes only the selected UV; it must not alter height, normals, collision, clipping, skirts, aprons, or cliff dressing.
- Run `godot --headless --path /Users/ryko/story --import` after adding, moving, or renaming `class_name` scripts.
- Preserve unrelated changes in the already-dirty worktree. Do not regenerate or stage `project.godot` unless a real project setting changes.

## 2. Final production shape

### 2.1 New pure types

```text
scripts/terrain/field/
  WorldFieldBlockCache.gd

scripts/terrain/features/
  PathProgram.gd
  PathPlan.gd
  PathRouteSolver.gd       # internal pure DP helper; no class_name or ownership
  PathContext.gd
```

`PathRouteSolver.gd` is the one justified internal split: `PathPlan` prepares a compact bounded grid, the helper solves it, and `PathPlan` retains all world decisions and caches. Do not split bridges, lamps, arches, or nodes into sibling plan objects.

### 2.2 Generalized environment-instance types

```text
scripts/terrain/environment/
  EnvironmentInstancePayload.gd
  EnvironmentCollisionBuilder.gd
  EnvironmentCommitQueue.gd
```

These replace the dressing-prefixed equivalents. Dressing and features use separate queue instances but the same implementation.

### 2.3 Locked public contracts

```gdscript
# EnvironmentInstancePayload.gd
class_name EnvironmentInstancePayload
extends RefCounted

var batches: Dictionary = {}
var instance_count: int = 0

# instance_id is omitted for ambient dressing. A batch's IDs are either empty
# or exactly aligned with transforms/colours.
func add(asset_id: StringName, transform: Transform3D, color: Color,
        instance_id: Variant = null) -> void
func asset_ids() -> Array[StringName]
```

```gdscript
# EnvironmentCollisionBuilder.gd
class_name EnvironmentCollisionBuilder
extends RefCounted

static func commit(parent: Node3D, payload: EnvironmentInstancePayload,
        render_cache: EnvironmentRenderCache, body_name: StringName) -> int
```

```gdscript
# EnvironmentCommitQueue.gd
class_name EnvironmentCommitQueue
extends RefCounted

func _init(render_cache: EnvironmentRenderCache, container_name: StringName) -> void
func register_chunk(key: Vector2i, generation: int) -> void
func invalidate_chunk(key: Vector2i) -> void
func enqueue(key: Vector2i, generation: int, parent: Node3D,
        payload: EnvironmentInstancePayload) -> void
func drain(max_batches: int) -> int
func pending_count() -> int
func clear() -> void
```

```gdscript
# WorldFieldBlockCache.gd
class_name WorldFieldBlockCache
extends RefCounted

func _init(plan: HeightfieldPlan, water_plan: WaterPlan,
        query_margin: float, shore_distance_limit: float,
        entry_cap: int) -> void
func region(chunk: Vector2i) -> HeightfieldRegion
func water(chunk: Vector2i) -> WaterFieldContext
func region_at(world_xz: Vector2) -> HeightfieldRegion
func water_at(world_xz: Vector2) -> WaterFieldContext
func stats() -> Dictionary
```

`stats()` exposes build/hit/eviction counters only; it never affects output. Region and water slots are lazy independently. One entry holds `{region, water, last_use}`. Eviction is deterministic LRU with the `Vector2i` key as the tie-break.

```gdscript
# PathProgram.gd
class_name PathProgram
extends RefCounted

static func compile(catalog: EnvironmentCatalog) -> PathProgram

var referenced_asset_ids: Array[StringName]
var query_margin: float
var shore_distance_limit: float
var max_horizontal_footprint_radius: float
var feature_halo: int
```

All other `PathProgram` fields are primitive constants, arrays, or dictionaries: salts, probabilities, costs, route limits, compiled asset metrics, local footprint rectangles, support samples, and cache caps. It must contain no `Resource` references.

```gdscript
# PathPlan.gd
class_name PathPlan
extends RefCounted

func _init(world_seed: int, water_plan: WaterPlan,
        fields: WorldFieldBlockCache, program: PathProgram,
        context_margin: float) -> void
func context_for(chunk: Vector2i) -> PathContext
func node_for(super_cell: Vector2i) -> Dictionary
func route_for(node_a: Dictionary, node_b: Dictionary) -> Dictionary
func bridge_site(site_key: Variant) -> Dictionary
func stats() -> Dictionary
```

The three narrow read methods after `context_for` are canonical plan queries, not alternate ownership paths. They exist so tests, the Phase 0 corpus, and future settlement acceptance can inspect the same facts production uses.

```gdscript
# PathContext.gd
class_name PathContext
extends RefCounted

func corridor_at(world_xz: Vector2) -> bool
func clearance_at(world_xz: Vector2) -> float
func placements() -> EnvironmentInstancePayload
func coverage() -> Rect2
```

Contexts are immutable after construction and memoized only by canonical chunk key. `clearance_at` returns signed distance to the union of corridor rectangles, 12 m plazas, and cardinally oriented prop-footprint rectangles, saturated at the compiled limit.

### 2.4 Streamer state model

Keep one worker queue. A queued job is one dictionary:

```gdscript
{
    "chunk": Vector2i,
    "build_terrain": bool,
    "terrain_generation": int,
    "build_features": bool,
    "feature_generation": int,
    "priority_distance": int,
}
```

A result mirrors those optional outputs and generations. Use dictionaries rather than positional arrays once two independently stale output classes exist.

Main-thread state is explicit:

```text
_built                 Vector2i -> terrain Node3D
_feature_ready         Vector2i -> generation (includes empty blocks)
_feature_nodes         Vector2i -> non-empty block Node3D
_terrain_generation    Vector2i -> latest terrain generation
_feature_generation    Vector2i -> latest feature generation
_pending_terrain       nearest-first completed terrain results awaiting halo
```

Do not encode empty readiness as a null node and do not add dependency lists. `_feature_halo_keys(chunk)` is the only square enumerator used by scheduling, readiness, player priority, and tests.

## 3. Verification commands

Focused GUT file:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryko/story \
  -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/test_name.gd -gexit
```

Full suite:

```bash
godot-test
```

Class cache refresh:

```bash
godot --headless --path /Users/ryko/story --import
```

Environment bake:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor \
  --path /Users/ryko/story \
  -s res://tools/environment_bake/environment_bake.gd -- \
  --manifest res://tools/environment_bake/manifests/fantasy_village_features.json
```

Profile:

```bash
godot --headless --path /Users/ryko/story \
  -s res://tests/harness/profile_terrain.gd
```

## 4. Task order and spec coverage

Execute in order; the Phase 0 gate is the only planned pause:

```text
0.1 -> 0.2 -> 0.3 GO/NO-GO -> 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7
     -> 8 -> 9 -> 10 -> 11 -> 12 -> 13
```

| Spec concern | Owning tasks |
|---|---|
| Phase 0 measurements and frozen budgets | 0.1–0.3 |
| Shared environment payload/collision/visual queue | 1 |
| Assets, collision sources, primitive program | 2 |
| Canonical lazy terrain/water blocks | 3 |
| Shared walkability | 4 |
| Nodes | 5 |
| Canonical pre-route bridge sites | 6 |
| Bounded route DAG and exact final validation | 7 |
| Backbone, loops, merge, contexts, bridge payload | 8 |
| Corridor paint and dressing clearance | 9 |
| Demand-driven feature halo and readiness | 10 |
| Lamps and arches | 11 |
| Statistical/performance gates | 12 |
| Visual/gameplay/export falsification and docs | 13 |

## Phase 0 — Freeze risky facts before the production planner

### Task 0.1: Record the baseline

**Files**

- Create `docs/superpowers/specs/2026-07-19-paths-manmade-features-phase0-results.md`.
- Modify `tests/harness/profile_terrain.gd` only to support a repeat-in-one-process warm pass.
- Do not change runtime behavior.

**Steps**

- [ ] Run `godot-test` at the implementation starting point and record pass/fail counts and elapsed time.
- [ ] Make the profiler's existing single pass remain the default, with an optional second sweep over the same plan/water instances. Run three fresh processes with the warm sweep enabled and record median cold/warm 49-chunk phase totals, peak memory, worst chunk, and main-thread commit totals.
- [ ] Record the exact five SFV source paths from the spec; Task 0.3 independently verifies the raw AABBs through the bake-owned probe.
- [ ] Add a table for the still-unfrozen values: path width verdict, bridge scale vector, usable deck span, crossing coverage target, planning/exact mismatch rate, loop probability, field-cache cap, warm path overhead budget, and player-critical nine-key halo budget.
- [ ] State the machine/Godot version used. Performance thresholds are relative to this baseline, not portable claims about other hardware.

**Acceptance**

- The results document contains reproducible commands and a complete baseline before path code changes terrain output.

### Task 0.2: Add the water-owned segment queries

**Files**

- Modify `scripts/terrain/water/WaterPlan.gd`.
- Modify `scripts/terrain/water/WaterFieldContext.gd`.
- Create `tests/test_water_path_queries.gd`.

**Interfaces**

```gdscript
# Intervals are sorted, disjoint Vector2(t_enter, t_exit) values in [0, 1].
func planning_signed_distance(point: Vector2) -> float
func planning_intervals(a: Vector2, b: Vector2) -> Array[Vector2]
func wet_intervals(a: Vector2, b: Vector2) -> Array[Vector2]
```

**Implementation**

- [ ] Put the one fixed `PATH_WATER_GUARD` and guarded source-footprint distance in `WaterPlan`; `PathPlan` must not reproduce river capsule or pond geometry.
- [ ] Reuse `_region_for` and its river/pond indexes. Add a point index only if profiling proves the existing buckets insufficient.
- [ ] Compute planning intervals from the same variable-width trace-segment capsules and `PondStamp.footprint_t` used by water generation. Refine boundary `t` values to a fixed spatial tolerance and merge touching intervals in canonical order.
- [ ] Implement `WaterFieldContext.wet_intervals` from the context's exact wet predicate and cached shoreline curves. Split at ordered line/contour crossings, classify each open span at its midpoint, include wet endpoints, and merge adjacent wet spans. Ensure contexts used for paths cache the required curves even when no consumer requests a non-zero shore-distance result; do not create a second shoreline approximation.
- [ ] Return identical intervals when endpoints are reversed after mapping `t -> 1-t`.
- [ ] Keep the scan/refinement count bounded by segment length and water's declared minimum feature width. Assert the bridge look-ahead never exceeds the supported bound.

**Tests**

- [ ] River capsule: perpendicular, tangent, oblique, variable-width, and segment-end crossings.
- [ ] Pond: centre, oblique, tangent, and miss cases against the wobbled footprint.
- [ ] Multiple intervals are sorted and merged independent of river enumeration order.
- [ ] Reversing endpoints yields the same world intervals.
- [ ] Planning intervals include the guarded source footprint; exact intervals match `is_wet` samples on both sides of each refined crossing.
- [ ] Positive and negative super-cell boundaries use the same owner/index behavior.

**Run**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryko/story \
  -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/test_water_path_queries.gd -gexit
godot-test
```

### Task 0.3: Run the width, crossing, topology, and halo probe

**Files**

- Create `tools/environment_bake/path_feature_probe.gd`.
- Create `tools/environment_bake/path_feature_probe.tscn` if a windowed review scene is useful.
- Create `tests/harness/probe_paths_phase0.gd` for the deterministic headless corpus.
- Complete `docs/superpowers/specs/2026-07-19-paths-manmade-features-phase0-results.md`.

Only `tools/environment_bake/` may directly load source-pack paths. The headless corpus consumes primitive measurements and water/terrain APIs; it must not add runtime references to `res://assets/`.

**Probe outputs**

- [ ] Show a centred 4 m strip and the rejected offset 6 m alternative over the real 2 m terrain grid, on flats, slopes, corners, and junctions. Include a character-width marker.
- [ ] Render the raw bridge, pole, and arches with one-metre and character markers. For the bridge, sweep a short explicit list of three-axis scale candidates; never test uniform stretching as the default.
- [ ] Across a checked-in seed list, enumerate prospective axis-aligned dry-to-dry crossings independently of route acceptance. Report perpendicular/oblique wet span quantiles, required dry landing span, candidate scale coverage, and exact rejection reasons.
- [ ] Measure planning-versus-exact interval mismatches. Preserve mismatches as expected final-validation drops; do not tune the planning footprint until it emulates exact hydrostatic water.
- [ ] Exercise the local backbone/optional-loop rule over deterministic synthetic feasible-edge sets and representative node-density samples. Report isolation and component-size distributions without implementing a second terrain route solver.
- [ ] Time nine canonical terrain/water block queries, nine empty feature-ready records, and the nine-key readiness scan. This establishes the player-critical halo budget without building dependency bookkeeping.
- [ ] Record a proposed bridge vector scale, authored deck contacts/opening/underside/footprint metrics, `LOOP_EDGE_PROBABILITY`, corpus thresholds, cache caps, and performance gates.

**Gate**

- The default remains a centred 4 m path and `FEATURE_HALO == 1`.
- The selected bridge vector must pass span coverage and visual proportion checks. If no vector does, stop and revise the asset choice before Phase 1.
- Any change to width, bridge asset, halo architecture, or network rule is a spec edit and owner decision, not an implementation-time tune.
- Freeze every numeric corpus/performance threshold in the results document before continuing.

## Phase 1 — Consolidation and final asset bake

### Task 1: Generalize dressing's instance commit infrastructure without changing output

**Files**

- Create `scripts/terrain/environment/EnvironmentInstancePayload.gd`.
- Create `scripts/terrain/environment/EnvironmentCollisionBuilder.gd`.
- Create `scripts/terrain/environment/EnvironmentCommitQueue.gd`.
- Modify `scripts/terrain/dressing/DressingField.gd`.
- Modify `scripts/terrain/field/FieldTerrainStreamer.gd` only enough to use the renamed types.
- Modify `tests/test_dressing_field.gd`, `tests/test_dressing_collision_builder.gd`, `tests/test_dressing_commit_queue.gd`, and `tests/test_field_streamer.gd`.
- Delete the three dressing-prefixed implementation files after all callers migrate.

**Steps**

- [ ] Port `DressingPayload` behavior byte-for-byte, then add optional stable IDs with the invariant `ids.is_empty() or ids.size() == transforms.size()`.
- [ ] Assert that one batch cannot mix identified and unidentified instances. Dressing and features use separate payloads, so no sentinel ID is needed.
- [ ] Parameterize only the collision body name and visual container name. Preserve transform composition, weak parents, batching, generation checks, and stale discard.
- [ ] Instantiate the dressing queue as `EnvironmentCommitQueue.new(cache, &"Dressing")` and commit dressing collision with `&"DressingCollision"`.
- [ ] Rename tests to environment-instance names only if doing so improves discovery; do not keep compatibility wrappers or aliases.
- [ ] Compare a fixed dressing payload before/after: sorted asset IDs, transforms, colours, collision count, MultiMesh count, and node names must match.
- [ ] Refresh the class cache, grep for the deleted class names outside historical docs, then run all tests.

**Acceptance**

- Dressing output and scene shape are unchanged.
- There is one payload, one collision builder, and one visual queue implementation.
- Stable IDs are carried but ignored by the renderer and collision builder.

### Task 2: Bake the five feature assets and compile `PathProgram`

**Files**

- Create `tools/environment_bake/manifests/fantasy_village_features.json`.
- Create reviewed collision scenes under `tools/environment_bake/collision_sources/fantasy_village/`.
- Modify `tools/environment_bake/environment_bake.gd` to reject malformed/scalar scale values instead of silently falling back.
- Create generated descriptors, visuals, meshes, materials, collision shapes, and provenance through the bake tool.
- Create `scripts/terrain/features/PathProgram.gd`.
- Create `tests/test_path_program.gd`.
- Modify `tests/harness/environment_lineup.gd` to show path metrics and a character marker for these assets.

**Steps**

- [ ] Author the manifest exactly as the spec: default `[1,1,1]`, vector scale on every entry, Phase 0's explicit bridge vector, `identity` tint, `supports_instance_color`, feature tags, and `collision_source`.
- [ ] Author simple native-coordinate collision primitives: bridge deck following the walkable arc plus separate rails; lamp pole only; arch legs only. Share an arch collision scene only if measured pivots and bounds prove the two variants equivalent.
- [ ] Bake and refresh imports. Runtime resources must remain self-contained and source-pack free.
- [ ] Put placement semantics in `PathProgram`, not the environment descriptor: bridge deck contacts, usable span, opening, underside, landing/support samples, collision footprint, lamp arm direction, arch openings/legs, and all horizontal bounds.
- [ ] Compile from the lightweight catalogue on the main thread, copying only primitives into the result.
- [ ] Preserve authored prop colour with `identity` tint and compile the lamp as emissive-only. V1 must not create or describe a `Light3D`.
- [ ] Validate all IDs, tags, identity tint, instance colour support, non-empty collision, finite bounds/metrics, metric containment within measured AABBs, query margins, bridge look-ahead, cache caps, and `ceil(max_horizontal_footprint_radius / 192.0) <= MAX_FEATURE_HALO`.
- [ ] Set `feature_halo` from the compiled footprint; never author it separately.
- [ ] Keep the five referenced IDs sorted and expose them for selective visual warming.

**Tests and review**

- [ ] Happy-path compilation yields no `Resource` anywhere in the recursively inspected program.
- [ ] Each missing asset, collision, tag, metric, invalid vector, over-budget halo, and over-budget water margin fails compilation.
- [ ] The bridge collision has no channel-blocking shape below the deck; arch openings have no crossbar collision across the walkable opening; lamp collision stays on the pole.
- [ ] Run the lineup for each asset with collision overlays and path metrics. Verify contacts, under-deck clearance, rail height, opening widths, pole-arm yaw, pivots, and all support samples.
- [ ] Run `tests/tools/verify_environment_pack.gd` against an export/source-pack-absent copy.

## Phase 2 — Pure canonical planning core

### Task 3: Add the independently lazy canonical field cache

**Files**

- Create `scripts/terrain/field/WorldFieldBlockCache.gd`.
- Create `tests/test_world_field_block_cache.gd`.
- Modify pure harness helpers to consume it.
- Leave the live streamer on its existing build path until Task 10.

**Steps**

- [ ] Implement half-open key ownership with `floor(world_xz / 192.0)` for both axes, including exact positive and negative borders.
- [ ] Reproduce the existing `TerrainChunkMesher.chunk_region` region exactly for a canonical key. During migration, compare both paths; Task 10 deletes the mesher helper so the cache becomes the sole production owner.
- [ ] `region(key)` builds only the `HeightfieldRegion`.
- [ ] `water(key)` reuses that region and builds exactly one `WaterFieldContext` covering `core.grow(combined_query_margin)` with the combined shore limit.
- [ ] The caller computes combined limits once from `DressingProgram` and `PathProgram`. Compilation must reject a combination outside `WaterField`/`WaterContour`'s fixed coverage contract.
- [ ] Implement bounded deterministic LRU. Touching an entry updates performance state only; it cannot change field values.
- [ ] Add counters for region builds, water builds, hits, and evictions.

**Tests**

- [ ] Positive/negative half-open ownership at `-192`, `0`, `192`, and one ULP to either side.
- [ ] Cold, warm, reverse-order, and evict/rebuild values are equal over fixed terrain/water sample sets.
- [ ] `region()` leaves water absent and the water-build counter unchanged.
- [ ] Repeated exact consumers receive the same live region/water object until eviction.
- [ ] Building water after region does not rebuild region.
- [ ] Capacity is never exceeded and LRU tie-breaking is deterministic.

### Task 4: Add the shared terrain-edge walkability classifier

**Files**

- Modify `scripts/terrain/field/TerrainSurfaceField.gd`.
- Modify `tests/test_terrain_surface_field.gd`.

**Interface**

```gdscript
static func is_walkable_edge(region: HeightfieldRegion,
        cell: Vector2i, direction: Vector2i) -> bool
```

**Steps**

- [ ] Accept only cardinal unit directions.
- [ ] Classify from the same shared edge profiles and flat/exposed-edge facts the mesher uses. Ordinary storey and level smootherstep seams are legal; either direction of a vertical cliff/wall discontinuity is illegal.
- [ ] Make the result symmetric: querying `(cell, d)` equals `(cell + d, -d)`.
- [ ] Do not add path-specific grade or water logic to this classifier.

**Tests**

- [ ] Flat, level slope, storey slope, cliff, inner corner, diagonal cliff, and higher-flat-neighbour fixtures.
- [ ] Direction symmetry and invariance under translation, including negative cells.
- [ ] Existing seam/mesher tests remain green.

### Task 5: Implement deterministic node selection

**Files**

- Create `scripts/terrain/features/PathPlan.gd` with node/cache foundations.
- Create `tests/test_path_plan_nodes.gd`.

**Steps**

- [ ] Define `PATH_SEED_VERSION = 1` and one named salt per existence, candidate X/Z, score tie, node ID, route, loop, bridge, lamp, and arch decision.
- [ ] Hash five cell candidates into the central half of each 32-cell super-cell. Sort/evaluate candidates by canonical candidate key, not container order.
- [ ] Score exact cached terrain support span over the 12 m plaza, planning dryness/source-shore clearance, meadow weight, and rocky weight.
- [ ] Choose one provisional passing winner using `(score, candidate_hash, cell)`.
- [ ] Request exact water only for that winner's plaza samples. Failure produces no node; do not inspect the next candidate.
- [ ] Add no spawn-specific exclusion or retry. The existing terrain/water/biome fields make the origin ordinary input.
- [ ] Cache by super-cell. The cached node record contains only `id` and `cell`; absence uses one explicit sentinel.
- [ ] Bound and instrument the cache. Eviction may recompute but must not change the answer.

**Tests**

- [ ] Seed/version determinism, query-order independence, cache eviction equality, and negative super-cells.
- [ ] Candidate score tie resolves by hash then cell.
- [ ] Flatness, dryness, shore, meadow, and rocky score floors each reject as intended.
- [ ] Field-cache counters prove all candidates may read exact terrain, but only the provisional winner requests exact water.
- [ ] Exact failure does not fall through.
- [ ] Node output has no settlement radius, acceptance stencil, biome content, or retry metadata.

### Task 6: Implement canonical bridge sites before route solving

**Files**

- Extend `scripts/terrain/features/PathPlan.gd`.
- Create `tests/test_path_bridge_sites.gd`.

**Steps**

- [ ] Derive a fixed cell look-ahead from compiled usable bridge span plus both dry landing bands. Reject a program whose bound is not finite and small.
- [ ] From a dry graph cell and axis, use `planning_intervals` to find a complete prospective wet run and its first dry landing cells. Never make a partially wet cell a route state.
- [ ] Canonicalize the site as `(axis, sorted dry landing endpoints)`.
- [ ] Separate `_bridge_raw` from `_bridge_resolved` caches. Raw profiling never asks another site's resolved state.
- [ ] Transform authored centreline, lateral, deck contact, landing, footprint, underside, and support samples through one candidate transform.
- [ ] Validate exact wet intervals across several lateral lines, complete landing dryness/support, usable span, both end steps `<= 0.4 m`, bank height, water-level spread, under-deck static-water plus dynamic-wave clearance, and beneath-deck terrain grade.
- [ ] Enumerate the fixed-radius set of potentially overlapping valid raw sites. Resolve survival with `(priority_hash, site_key)` and a flat comparison.
- [ ] Expose only surviving sites as complete dry-landing-to-dry-landing macro-edges. Store every traversed cell connection and conservative deck-profile vertical variation.
- [ ] Bound raw and resolved bridge caches with deterministic eviction sized from the Phase 0 active-window measurements.

**Tests**

- [ ] Identical discovery paths coalesce to one key and one exact profile.
- [ ] Perpendicular/oblique banks, tangency, multiple wet intervals, unsupported landings, excessive steps, water spread, underside collision, and terrain-grade failures.
- [ ] Compatible collinear sites are one identity; incompatible perpendicular/overlapping sites have exactly one deterministic winner.
- [ ] Raw/resolved cache order does not change survival.
- [ ] No wet T/X or partial macro-edge is exposed.
- [ ] Bridge transform used for placement is byte-identical to the transform validated by profiling.

### Task 7: Implement and prove the monotone route solver

**Files**

- Create `scripts/terrain/features/PathRouteSolver.gd` without `class_name`.
- Extend `scripts/terrain/features/PathPlan.gd`.
- Create `tests/test_path_route_solver.gd`.

**Preparation in `PathPlan`**

- [ ] Canonicalize endpoint order by sorted node IDs.
- [ ] Reject pairs unless their nodes occupy cardinally neighbouring super-cells; there are no diagonal or long-range route candidates in v1.
- [ ] Build a dense local record for the finite Manhattan bounding box: cell heights in rendered level units, rocky cost, legal dry monotone edges, and surviving bridge macro-edges.
- [ ] Use packed arrays and integer local indices. Exact terrain and planning-water work happens once per local cell/edge, not once per DP state.
- [ ] Assert DAG expansion does not change `WorldFieldBlockCache.water_build_count`.

**Solver**

- [ ] State is `(cell_index, previous_direction, vertical_variation_units)`.
- [ ] Advance only east/west and north/south directions that reduce Manhattan distance to the destination.
- [ ] Accumulate absolute rendered height change into vertical variation. Prune using `(variation + abs(current_height - start_height)) / 2` against the symmetric vertical budget.
- [ ] A bridge macro-edge adds its conservative profile variation and lands atomically on its far dry cell.
- [ ] Expose a bridge macro-edge to this solve only when its far landing also reduces Manhattan distance; the route remains a monotone DAG.
- [ ] Cost is absolute surface change + rocky weight + turn cost + compiled bridge cost. Signed east/north elevation must never affect legality.
- [ ] At one cell/direction, discard a state dominated in both cost and variation.
- [ ] Resolve exact cost ties with the named pair/predecessor/destination hash, then lexicographic predecessor state.
- [ ] Reconstruct one route with all cell connections and bridge keys.

**Final exact validation in `PathPlan`**

- [ ] Validate the selected route only: exact wet intervals on centreline and both corridor edges, plus every dry quad centre that would be painted. Canonical bridge macro-edges are already exact.
- [ ] Exact failure returns absence and increments a reason counter. Never rerun the DP.
- [ ] Cache present/absent route results by sorted pair key with the fixed measured cap. Eviction changes work only.

**Tests**

- [ ] Compare every result on many small synthetic DAGs with an exhaustive test-only oracle.
- [ ] Bounding-box containment, endpoint reversal, deterministic tie cases, turn penalties, rocky costs, and bridge macro-edge traversal.
- [ ] Prove the one-value variation formula equals independently accumulated ascent/descent for exhaustive short height sequences.
- [ ] Prove dominance pruning preserves the oracle winner.
- [ ] Known planning/exact mismatches drop only at final validation.
- [ ] Instrumentation proves zero exact-water creation during DP and exactly one solve on exact failure.

### Task 8: Select the local network and build bridge-only `PathContext`

**Files**

- Create `scripts/terrain/features/PathContext.gd`.
- Extend `scripts/terrain/features/PathPlan.gd`.
- Create `tests/test_path_context.gd`.

**Steps**

- [ ] For a requested context window, enumerate the fixed two-super-cell neighbourhood whose possible endpoint boxes can intersect the context coverage grown by maximum bridge footprint.
- [ ] Materialize every cardinal candidate pair and exact feasibility before selecting the local network.
- [ ] For each node with feasible incident routes, select the minimum `(route_cost, pair_hash, pair_key)` backbone edge. Accept an edge if either endpoint selects it.
- [ ] Apply one pair-key loop roll to each remaining feasible edge using the Phase 0 probability.
- [ ] Merge accepted route connections into one cardinal bitmask per cell. Keep bridge macro-edge connections continuous through wet cells.
- [ ] Add 12 m node plazas. Represent each connection/plaza as an axis-aligned rectangle on the centred graph; do not add a second raster or offset coordinate system.
- [ ] Add one placement for each accepted canonical bridge, owned by the half-open block containing its anchor. Carry the canonical stable feature ID in `EnvironmentInstancePayload`.
- [ ] Derive every feature ID from `(world_seed, PATH_SEED_VERSION, feature_type, canonical_site_key)`; no chunk or contributing-route identity participates.
- [ ] Build signed clearance as the minimum signed distance to corridor/plaza rectangles and cardinally transformed bridge footprints, saturated at the program limit.
- [ ] Cache exactly one immutable context per chunk key with a bounded deterministic LRU.

**Tests**

- [ ] Every node with a feasible incident route gets at least one accepted backbone edge.
- [ ] Pair acceptance is invariant under endpoint, query, and enumeration order.
- [ ] Loop decisions are one roll per undirected pair.
- [ ] Overlapping routes union into correct straight/L/T/X masks.
- [ ] `corridor_at` yields a centred two-column 4 m strip on the real 2 m quad-centre grid and a 12 m plaza.
- [ ] Signed clearance is negative inside, zero at boundaries, positive outside, includes bridge footprints, and saturates.
- [ ] Placements are half-open anchor-owned, stable-ID preserving, deduplicated, and identical after context-cache eviction.

## Phase 3 — Atomic terrain, dressing, and streaming integration

### Task 9: Paint paths and suppress dressing in the pure worker payloads

**Files**

- Modify `scripts/terrain/tools/SlopeAtlas.gd`.
- Modify `scripts/terrain/field/TerrainChunkMesher.gd`.
- Modify `scripts/terrain/dressing/model/DressingSet.gd`.
- Modify `scripts/terrain/dressing/DressingCompiler.gd` and `DressingProgram.gd`.
- Modify `scripts/terrain/dressing/DressingField.gd`.
- Modify active resources under `terrain/dressing/sets/`.
- Modify `tests/test_slope_atlas.gd`, `tests/test_terrain_chunk_mesher.gd`, `tests/test_dressing_field.gd`, and `tests/test_dressing_ecology.gd` as needed.

**Terrain painting**

- [ ] Add `SlopeAtlas.path_uv()` using the centre of the Phase 0 verified tan island. Add an image-level test that the sample lies safely inside one island with mip/filter padding.
- [ ] Change the mesher worker signature to receive `region`, `water`, and `paths` explicitly. Remove its fallback region creation after all callers migrate.
- [ ] At the existing walkable-sheet UV choice only, select `_path_uv` when the quad centre is in the corridor and exact water says dry; otherwise select `_grass_uv`.
- [ ] Preserve the existing inner-corner `_cliff_uv` override and every geometry/collision path.

**Dressing clearance**

- [ ] Add finite non-negative `feature_clearance` to `DressingSet`, compile it as a primitive, and expose the program maximum.
- [ ] Pass `PathContext` to `DressingField.compute` and `_qualify`.
- [ ] Reject a candidate unless `paths.clearance_at(anchor) >= feature_clearance`; `0.0` still rejects the reservation interior.
- [ ] Author approximately `2.0` for structural tree/rock/deadwood sets, `0.3` for ground cover/bush/flower/grass/mushroom/reeds, and `0.0` for floating lilies unless visual review justifies more. Store the final exact values in resources, not tags or code branches.
- [ ] Do not change eligibility, choice, yaw, scale, brightness, or arbitration hashes.

**Tests**

- [ ] Inspect emitted triangle UVs for stub, straight, corner, T, X, plaza, dry/wet, positive seam, negative seam, and inner-corner cases.
- [ ] Path paint changes only UV arrays; vertex, index, normal, colour, collision, apron, and cliff payloads remain equal to a feature-free build.
- [ ] Dressing margins work at interior/boundary/exterior points.
- [ ] Candidate identities and hashes are unchanged; anchors farther than reservation + clearance + arbitration influence are bit-identical to a feature-free run.

### Task 10: Integrate canonical feature blocks with the demand-driven halo

**Files**

- Modify `scripts/terrain/field/FieldTerrainStreamer.gd`.
- Modify `scripts/terrain/field/TerrainChunkMesher.gd` callers.
- Modify `tests/test_field_streamer.gd`.
- Create `tests/test_feature_halo.gd` if separating the pure scheduling tests keeps `test_field_streamer` readable.
- Modify `tests/harness/profile_terrain.gd` with phase counters.

**Startup**

- [ ] Compile dressing, then `PathProgram`, on the main thread.
- [ ] Warm the sorted union of dressing, cliff, and active feature asset IDs.
- [ ] Create separate `EnvironmentCommitQueue`s for `Dressing` and `Visuals`.
- [ ] Create one `ManmadeFeatures` root under the streamer.
- [ ] Compute `combined_query_margin = max(dressing_program.query_margin, path_program.query_margin)` and the corresponding maximum shore limit. Pass that query margin as `PathPlan.context_margin`, construct worker-confined `WorldFieldBlockCache`, then `PathPlan`. From this point only the worker touches their mutable caches.
- [ ] Delete `TerrainChunkMesher.chunk_region` and migrate profiles/tests so exact production regions have one owner.

**Scheduling**

- [ ] Replace positional jobs/results with the dictionaries in section 2.4.
- [ ] A terrain-radius request ORs both missing flags into one queued key. A feature-only halo request sets only `build_features`. A later terrain request for a feature-ready key sets only terrain.
- [ ] If a queued job for the key exists, widen its flags instead of adding another job. If the key is already active, record the missing output as one follow-up request after completion; the single worker and canonical caches prevent parallel duplicate work.
- [ ] Sort jobs by `(priority_distance, feature_first_on_tie, chunk.x, chunk.y)`. A halo request inherits the nearest pending terrain distance.
- [ ] The worker calls `paths.context_for(chunk)` once, then conditionally extracts placements and/or computes terrain/water/dressing from the shared fields.

**Readiness and commit**

- [ ] Implement one lexicographically sorted `_feature_halo_keys(chunk)` over `[-feature_halo, +feature_halo]^2`.
- [ ] When a terrain result arrives, place it in one nearest-first `_pending_terrain` list and request only its missing halo feature keys.
- [ ] Commit valid feature results before rechecking pending terrain: empty -> ready record only; non-empty -> block root, collision body, add to `ManmadeFeatures`, ready record, register feature generation, queue visuals.
- [ ] `EnvironmentCollisionBuilder` commits the full feature payload as `FeatureCollision` before readiness is recorded.
- [ ] Each integration drain rescans at most nine keys per pending terrain result. Do not add subscribers, reverse edges, wake-up lists, or reference counts.
- [ ] Commit a terrain result only when every derived feature key is ready; then use the existing terrain -> water -> dressing collision -> add -> FX -> dressing visual order.
- [ ] Release the player only when their terrain key is built and its feature square is ready.
- [ ] Evict terrain beyond `KEEP_RADIUS`; evict feature ready records/nodes beyond `KEEP_RADIUS + feature_halo`, invalidating feature visual generation first.

**Tests**

- [ ] `_feature_halo_keys` is complete, sorted, duplicate-free, and correct at positive/negative keys.
- [ ] With v1 metrics it returns nine keys; a 7x7 terrain window's union is at most 9x9.
- [ ] Max-footprint bridges centred on all four edges and four corners commit collision before either intersected terrain chunk becomes built.
- [ ] Empty blocks become ready without a root, body, queue item, or server resource.
- [ ] Player-critical feature requests outrank unrelated terrain at equal/greater distance.
- [ ] A feature-only job followed by terrain does not rebuild feature data; a widened queued job returns both outputs once.
- [ ] Terrain/feature generations invalidate independently; stale feature visuals cannot attach after eviction.
- [ ] Worker payload recursion contains no scene/render/physics resource.
- [ ] Teleport, outrun, return, and shutdown paths leave no duplicate block, stuck player, or live worker.

**Atomic visual gate**

- Run the real streamer only after all focused tests pass. A visible path reaching water must already have its bridge collision and visual block scheduled; never land painted paths in the live world one task before usable bridges.

## Phase 4 — Lamps and arches from the final merged network

### Task 11: Add deterministic lamp and arch placements

**Files**

- Extend `scripts/terrain/features/PathPlan.gd` and `PathContext.gd`.
- Create `tests/test_path_props.gd`.
- No new streamer or commit implementation.

**Common ordering**

- [ ] Place in fixed precedence: shared bridges, gate arches, entrance arches, lamps.
- [ ] Use final merged connection masks. Key candidates by network cell/site, never by contributing route.
- [ ] Reject later candidates against complete earlier horizontal footprints.
- [ ] Add every accepted footprint to `clearance_at` and every owned transform/ID to the existing environment payload.

**Lamps**

- [ ] Restrict to dry straight degree-2 cells outside bridge, node, and arch reservations.
- [ ] Apply one keep roll and one-cell rank thinning for a 48 m minimum centre spacing.
- [ ] Assign an eligible cell to the lowest-key accepted route crossing it. Order accepted lamps along that route and compute side from `(accepted_index + route_phase) % 2`.
- [ ] Put the anchor about 4.5 m from centreline; validate the full pole/arm footprint for dry support and face the arm toward the path.
- [ ] Keep the corpus mean between one lamp per 48–72 route metres while preserving the hard 48 m minimum; long deterministic gaps remain legal.

**Arches**

- [ ] Choose at most two node approaches at node scope; place gate arches one or two straight cells from the plaza.
- [ ] Validate both legs, dryness, support, and an opening containing the 4 m corridor plus authored margin.
- [ ] Place rare entrance arches on straight mid-route cells with authored character-clearance opening; their legs may enter the painted corridor.
- [ ] Use one named compiled probability for entrance-arch rarity; never infer rarity from asset choice or route enumeration count.
- [ ] Orient every opening along the route axis.

**Tests**

- [ ] Stable IDs/transforms, query-order independence, context eviction equality, and deduplication at merged routes.
- [ ] Lamp minimum spacing, target gap distribution on the smoke corpus, and strict observed side alternation.
- [ ] No lamp on nodes, bridges, arches, water, corners, or junctions.
- [ ] At most two gate approaches per node; full leg support/dryness/opening/yaw checks for both gate sizes.
- [ ] Reservations and precedence prevent all prop collisions without a special-case commit filter.

## Phase 5 — Statistical, visual, and performance falsification

### Task 12: Turn the Phase 0 corpus into permanent smoke and release gates

**Files**

- Create `tests/test_path_corpus_smoke.gd`.
- Create or extend `tests/harness/profile_paths.gd` for the full corpus.
- Modify `tests/harness/profile_terrain.gd`.
- Update the Phase 0 results document with final before/after numbers.

**Steps**

- [ ] Check in a small fixed seed list for normal GUT and a larger fixed list for the harness.
- [ ] Report every metric and rejection reason required by spec section 8.2.
- [ ] Put frozen thresholds in one dictionary in the corpus harness/test; do not duplicate threshold literals across individual tests.
- [ ] Attribute 49-chunk time to region creation, exact water creation, planning water, bridge profiling, route solve, final validation, context query, path UV lookup, feature compute, collision commit, and visual batches.
- [ ] Report cold and warm caches, player-critical halo latency, requested/empty/non-empty feature keys, pending scan count, and final feature union size.
- [ ] Hard-assert zero exact-water builds during ordinary DAG expansion and zero main-thread node/resource work for empty feature keys.
- [ ] Compare warm worker and main-thread overhead with the Phase 0 budgets. If a budget fails, profile and simplify before tuning density downward.
- [ ] Inspect cache hit/eviction rates. Increase a fixed cap only with measured active-window evidence; never make caches unbounded.

**Acceptance**

- All frozen distribution thresholds pass without seed cherry-picking.
- Performance stays within the recorded gates.
- No optimization changes deterministic output; cold/warm/evicted result hashes match.

### Task 13: Build the pinned visual and gameplay review battery

**Files**

- Create `tests/harness/path_features_review.gd` and `.tscn`, or extend the existing teleport harness if that produces less code.
- Add deterministic review spots through the existing `review_teleports.json` workflow.
- Update `AGENTS.md` with the final path/feature architecture and invariants.

**Review spots**

- [ ] Straight, L, T, and X masks; node plaza; merged routes; long ordinary slope; mountain/no-route rejection.
- [ ] Two-column centred width and positive/negative chunk seam pans.
- [ ] Perpendicular and oblique bridges; all chunk-edge/corner orientations; walk over, swim under, and wade at both banks.
- [ ] Lamp spacing and true alternation over a long route.
- [ ] Both gate arches and the entrance arch; opening clearance, support, yaw, and collision overlays.
- [ ] Dressing clearance around corridors, plazas, bridge landings, poles, and arch legs.
- [ ] Fast travel/teleport while streaming to falsify readiness, duplication, popping collision, and stale visuals.

**Final checks**

- [ ] Run the complete GUT suite.
- [ ] Run the full deterministic corpus and both cold/warm profiles.
- [ ] Run the environment lineup with collision/path metrics for all five assets.
- [ ] Run the export/source-pack-absence verifier.
- [ ] Search for obsolete types and forbidden duplication:

```text
DressingPayload
DressingCollisionBuilder
DressingCommitQueue
chunk_region(
alternate route retry / fallback candidate logic
feature reverse dependencies / subscribers
runtime res://assets/FantasyVillageFBX references
```

- [ ] Confirm one worker, one `PathPlan`, one canonical field cache, one environment payload/builder/queue implementation, and one halo enumerator remain.
- [ ] Update `AGENTS.md` in the same change with the path pipeline, feature-block readiness rule, asset addition workflow, profiler command, and new tests/harness.

## 5. Definition of done

The work is complete only when all of the following are true:

- Terrain generation remains a deterministic pure function of seed and canonical fields; streaming order does not change path or feature output.
- Paths are centred 4 m atlas-painted corridors on existing geometry, with correct masks/plazas and no new path mesh or terrain deformation.
- The route solver is bounded, monotone, dominance-pruned, oracle-verified, and never materializes exact water during expansion.
- Bridges are canonical pre-route macro-edges whose committed transform and collision are exactly the footprint that passed validation.
- Dressing and all props respect one signed `PathContext` clearance field.
- Terrain readiness follows only the compiled footprint halo. Empty keys allocate nothing; non-empty collision is present before dependent terrain becomes traversable.
- Existing dressing behavior uses the generalized environment infrastructure without a compatibility layer.
- The statistical, visual, export, and performance gates pass, and `AGENTS.md` describes the resulting architecture.

## 6. Intentionally deferred

Do not expand implementation to include path flattening, settlements, buildings, path decals, organic splines, navigation, real lamp lights, day/night behavior, interaction, destruction, persistence, or a multi-plan aggregator. Stable node and feature IDs plus generic environment payloads are the extension points; v1 should not contain scaffolding for the deferred systems.
