# Startup + terrain-generation profiling — findings and optimization plan (2026-08-15)

Profiled on branch `feat/mass-first-warren`, world seed pinned to `2697992464`
([world.tscn:57](../../../scenes/world.tscn)). Three evidence sources:

1. **Live game log** of Ryan's editor-embedded run (Aug 15 21:29,
   `~/Library/Application Support/Godot/app_userdata/Story/logs/godot.log`) —
   the streamer's own `[terrain-streamer]` heartbeat/phase instrumentation.
2. **Headless production-faithful profiler**
   `tests/harness/profile_startup_pipeline.gd` (new; mirrors
   `FieldTerrainStreamer._ready()` exactly), run twice with an isolated
   `user://`: **warm** (copy of the current pin cache) and **cold** (empty pin
   cache = true first boot).
3. Code audit (startup path, streaming pipeline, per-frame costs) with
   file:line evidence.

---

## TL;DR

| Symptom | Root cause | Measured |
|---|---|---|
| Startup takes minutes | Warren/settlement production search runs **inside the startup loading gate**, serialized on the **single** terrain worker, in 20 s budget slices whose *first attempt is uncapped* | Live: **154.5 s** to `startup_complete`. Cold headless: ~128 s of the gate is search + cold water trace |
| Terrain doesn't load before the player reaches the edge | Same search monopolizes the one worker for 15–75 s **per chunk** near unsolved settlements, while finished terrain **cannot integrate** because its 3×3 feature halo isn't ready | Live: `built` frozen at 9 chunks for ~8 minutes with 16–28 computed chunks stuck in `pending` |
| Streaming feels slow even away from villages | Terrain mesh compute is **83 %** of a chunk build — ~9 216 quads × dozens of interpreted GDScript calls each | 1.35 s avg/chunk (mesh 1.12 s); worst 2.8 s |
| (bonus) frame-time waste in normal play | Debug overlay raycasting every frame, allocation storms in water sampling, trample-field rebuilds | see §6 |

The **startup problem and the streaming problem are the same problem**: the
village solver owns the only build thread, and the integration gate turns one
slow feature block into a frozen world.

---

## 1. Measured startup timeline (live run, seed 2697992464)

`startup_complete elapsed_ms=154532`. Where it went:

| t (s) | Phase | Evidence (log) |
|---|---|---|
| 0–~2 | `world.tscn` instantiate + `FieldTerrainStreamer._ready()` (program compiles, asset prepare) | headless: `READY_TOTAL 1775 ms` (feature program compile **981 ms**, dressing compile **460 ms**, catalog **186 ms**, render-cache prepare 62 assets **139 ms**) |
| ~0–36 | Chunk (0,0) `feature_context` = **36.1 s** — contains the **cold water trace/region cache (~28 s)** (cold_plan hit 1.0 at t≈30) + spawn settlement search slice | `worker_phase … phase=feature_placements previous=feature_context previous_ms=36083` |
| 36–37 | Chunk (0,0) mesh 824 ms, dressing 231 ms | `previous_ms=824`, `previous_ms=231` |
| 37–45 | Chunk (-1,-1): feature_context **7.3 s**, then ~1.1 s build | `previous_ms=7286` |
| 45–58 | Ring-1 chunks ~1–2.4 s each. **Defect observed:** non-support chunk (-1,1) built before support (0,-1) — see §4.3 | job_complete lines |
| 58–116 | Chunk (-2,-2) — a **halo feature key** the gate waits on — `feature_context` = **55.8 s** (village search slice) | `previous_ms=55838`; heartbeats stuck at `progress=0.9025 ready=1/4` for 55 s |
| 116–142 | Chunk (-2,-1) `feature_context` = **25.3 s** | `previous_ms=25291` |
| 142–154.5 | Remaining halo keys + supports integrate; gate opens | `startup_complete … elapsed_ms=154532` |

**Startup ≈ 28 s cold water plan + ~90 s settlement searches + ~20 s meshing
+ ~2 s setup + tail.** The loading bar sat at 0.90 for a full minute because
the gate's 16 feature keys include halo chunks that touch a settlement
super-cell.

Headless replay of the same gate work:

| | contexts (16 keys) | 4 support builds | total gate work |
|---|---|---|---|
| **Warm** (current pins) | 33.9 s (key (-2,-2) alone 31.3 s) | 3.6 s | **37.5 s** |
| **Cold** (first boot, no pins) | **206.6 s** | 3.6 s | **210.2 s** |

Cold per-key: (-2,-2) **73.3 s**, (0,1) **71.7 s**, (0,0) **21.6 s**,
(-2,-1) **20.6 s**, (0,-2) **12.0 s**, (1,0) 6.4 s — separate
searches/slices for the settlements whose discovery radius overlaps the spawn
halo. After that entire 3.5-minute "first boot", the pin cache held two
failure pins and one `attempts_tried: 3` progress pin — i.e. a **second**
boot still resumes searching. The search journey spans launches by design;
today the player's loading screen and streaming worker pay for it.

## 2. Post-startup: why the world stops streaming (live log)

Immediately after the gate opened, the player walked south-west toward a
settlement. The single worker then spent **45–75 s per chunk** in
`feature_context`:

```
elapsed 180s..225s  chunk -3,-3  feature_context ≥60 s   built=9  pending=16
elapsed 253s..298s  chunk -4,-3  feature_context ≥60 s   built=9  pending=18
elapsed 326s..386s  chunk -4,-2  feature_context ≥75 s   built=9  pending=19
elapsed 406s..451s  chunk -3,-2  feature_context ≥60 s   built=9  pending=21
elapsed 469s..607s  -3,-1 / -5,* … 15–30 s each          built 9→35
```

For ~8 minutes `built` stayed at 9 while 16–28 fully-computed terrain
payloads sat in `_pending_terrain` — they may not integrate until every block
of their 3×3 feature halo is ready
([FieldTerrainStreamer.gd:852](../../../scripts/terrain/field/FieldTerrainStreamer.gd),
`_feature_square_ready`), and those blocks were queued behind one
village search after another on the one worker. **This is the
"terrain doesn't load before I reach the edge of the world" bug.** It is not
meshing throughput and not (primarily) prioritization — it is the search
serialized in front of everything else.

Mechanics of the search cost
([VillageWarrenFabricSolver.gd:13,49-52](../../../scripts/terrain/features/villages/VillageWarrenFabricSolver.gd),
[WarrenVolumetricSolver.gd:136-142](../../../scripts/terrain/features/villages/fabric/WarrenVolumetricSolver.gd),
[VillagePlan.gd:44-47](../../../scripts/terrain/features/villages/VillagePlan.gd)):

- `PRODUCTION_SEARCH_BUDGET_MS = 20000` per record build, but **the first
  attempt of each slice runs to completion** (observed 45–75 s phases).
- A budget-interrupted record is **deliberately not cached**, so *every*
  feature key whose discovery radius touches the same unsolved settlement
  re-enters the solver and burns another slice. The pin cache
  (`user://warren_solution_pins.json`) persists progress
  (`attempts_tried`) across slices/boots, so the search does converge — but
  the worker pays the whole journey in the player's face.
- Docs already record 78–408 s per settlement full searches
  (2026-08-12-town-quality-remediation.md).

## 3. Steady-state chunk economics (headless, warm caches)

21-chunk sweep, radius 2, away from unsolved-village slices:

| Phase | avg ms/chunk | share |
|---|---|---|
| `mesher.compute_chunk` | **1 124** | **83 %** |
| `DressingField.compute` | 165 | 12 % |
| commit (main thread: meshes+collision+multimesh) | 40 | 3 % |
| heightfield region | 10 | — |
| water context (warm) | 2 | — |
| feature context (warm) | 3 | — |
| **Total** | **1 349** | worst 2 799 (near village: mesh 1.75–1.9 s) |

Grass: 52 tiles built in 1.85 s (**36 ms avg**, worst 55 ms) — cheap.

**Demand vs supply at MAX_SPEED = 10 m/s** (192 m chunks, radius 3):
straight-line movement needs a new 7-chunk column every 19.2 s →
0.365 chunk/s → **49 % worker duty** at 1.35 s/chunk; diagonal ~65 %; grass
adds ~10 %. So normal streaming *just about* keeps up — there is no slack.
One 20–75 s search slice costs 15–55 chunks of build time; the ring collapses
and the player reaches the frontier. The mesher's 1.1 s is what makes the
system fragile; the search is what breaks it.

Why the mesh phase is 1.1 s
([TerrainChunkMesher.gd:99-282](../../../scripts/terrain/field/TerrainChunkMesher.gd)):
`GRID = 96` → **9 216 quads/chunk**; per quad: 4 baked samples, 4 clip-vert
checks, a path-candidacy probe fan (`_emit_path_surface` — up to ~20+
`FeatureGroundField` probes on the rejection path, ~230 k queries/chunk even
when no path exists anywhere near), and ~18 SurfaceTool per-vertex calls;
then `st.index()` + `generate_normals()` over ~55 k verts. It is interpreter-
call-bound, not math-bound.

## 4. Prioritization defects (secondary, but they bite at saturation)

1. **Stale distance ratchet.** `_request_job_locked` takes
   `mini(old, new)` for `priority_distance`/`priority_tier`
   ([FieldTerrainStreamer.gd:1028-1029](../../../scripts/terrain/field/FieldTerrainStreamer.gd)).
   Distances are never *raised*, so chunks behind a moving player keep their
   old close-distance priority and tie with (or beat) the chunks ahead.
   Terrain jobs are also never cancelled when they leave the radius (only
   grass has `_cancel_far_grass_jobs_locked`) — the worker happily spends
   1.35 s each on chunks the player is running away from, and `_drain_results`
   then throws the payload away if it's beyond KEEP_RADIUS.
2. **Grass outranks far terrain.** Grass jobs are tier 2; terrain beyond the
   84 m grass radius is tier 3 ([:967-974,:1093](../../../scripts/terrain/field/FieldTerrainStreamer.gd)).
   While moving, ~2.9 new grass tiles/s continuously pre-empt the terrain
   frontier — pretty grass at your feet, void on the horizon.
3. **Halo-tier leakage, both directions.** `_drain_results` requests the 8
   feature-halo jobs with the *drained chunk's* tier/distance ([:791-802]).
   For the centre chunk that is tier 0 — observed live: non-support chunk
   (-1,1) (merged into a full terrain job) built **before** support chunk
   (0,-1) during startup. For non-centre chunks the halo jobs land at tier
   1/3 even though integration (and the startup gate, and the player
   unfreeze) is blocked on them.
4. **No direction-of-motion bias.** `desired_chunks` is a symmetric square;
   priority is Chebyshev distance only. At 10 m/s the ~8 s lead time of the
   tier-1 band is marginal.
5. **FIFO commit queues.** `FeatureCommitQueue` (1 asset load/frame, 24
   shapes, 2.5 ms) and `EnvironmentCommitQueue` (2 batches/frame) drain in
   insertion order — a far village block consumes the budget ahead of the
   near block the player is frozen on.

## 5. Startup-specific costs outside the worker

- `_ready` main-thread block ≈ **1.8 s** headless (feature program compile
  981 ms — ~146 `FabricRecipe` literals; dressing compile 460 ms; catalog
  load + 394 `ResourceLoader.exists` probes 186 ms; 62 visual loads 139 ms).
- Loading screen itself: ~7.9 MB of PNGs decoded before anything else.
- Every chunk integrate builds `BiomeChunkFx` (GPUParticles3D + FogVolume +
  OmniLight3D) with **no particle warm-up** → first-use shader-compile
  hitches during/after loading.
- Gate tail: `MAX_BUILD_PER_FRAME = 1` (≥4 frames) + 0.45 s fade.

## 6. Normal-gameplay per-frame findings (bonus audit)

Ranked by value-per-effort:

1. **`CoordOverlay` ships enabled** ([CoordOverlay.gd:12](../../../scripts/terrain/tools/CoordOverlay.gd)):
   every frame does a **4 000 m `intersect_ray`**, two absolute-path
   `get_node_or_null` lookups, 5-noise biome sampling, ~6 format strings, 9
   `loaded_storey_at` calls, and an unconditional `Label.text` assignment
   (TextServer re-shape). Default it off / throttle to 10 Hz.
2. **`WaterSampler._corners` allocates 4 nested Arrays per call**
   ([WaterSampler.gd:157-171](../../../scripts/terrain/water/WaterSampler.gd));
   `level_at`/`velocity_at`/`flow_diagnostics_at` each re-call it.
   `WaterRippleSim._refresh_flow_texture` runs a 32×32 grid × linear scan of
   all water samplers every ≤0.5 s (~20–40 k allocations per refresh);
   the character's swim probe pays the same per physics tick. Return packed
   floats / locals instead; add a Rect2 bounds pre-test per sampler;
   refresh samplers only on chunk load/evict.
3. **`TrampleField`**: 256² `get_pixel`/`set_pixel` epoch loop = a
   **guaranteed hitch every 60 s** ([TrampleField.gd:172-183](../../../scripts/terrain/grass/TrampleField.gd));
   `_publish_globals` re-sets 5 global shader params every frame; and the
   static-stamp image is fully rebuilt (all ~81 chunks' stamps, deep-copied)
   on **every chunk integrate and evict** ([FieldTerrainStreamer.gd:865-866,702-703,876-888])
   — i.e. precisely when streaming is already busy.
4. **Streamer `_process` sweeps**: `desired_chunks` allocation + O(49 ×
   pending) `_has_pending_terrain` scans + three full `_built`/`_feature_ready`
   keys() sweeps run every frame regardless of movement; `_pending_terrain`
   sort_custom runs even when empty; `_request_job_locked` re-sorts the whole
   job queue under the mutex for every already-queued chunk each frame
   (~dozens of sorts/frame with a deep backlog). Gate on `centre` change.
5. **`GrassStreamer`**: exact-float LOD origin means `origin_changed` every
   frame → full tile×batch visible-count walk + evict rebuild; `desired_tiles`
   sort allocates ~700 Rect2/frame in its comparator. Quantize the origin.
6. **`character.gd`**: fresh `PhysicsPointQueryParameters3D` +
   `get_first_node_in_group("water_dynamics")` every swim tick; string-path
   `anim_tree.get/set` per tick; `KinematicCollision3D.new()` in step-up.
   Cache all four.
7. **`camera.gd`/`CameraObstructionSolver`**: 2 shape-casts/tick with fresh
   query params — reuse members.
8. **`WaterRippleSim`**: ~16 `set_shader_parameter`/frame of which 4–6 are
   constants; 3 drop params written even when inert.

## 7. Optimization brainstorm

### A. Kill the terrain-loading failure (highest impact)

1. **Ship pins for the shipped seed.** The world seed is pinned in
   `world.tscn`; run the existing seed-corpus harness offline for
   `2697992464`'s reachable cities and bundle the resulting
   `warren_solution_pins.json` as a res:// default (user:// overlays it).
   Sealed pins re-seal in ~10 s and failure pins are free — the in-game
   search should be a fallback, not the common path. This alone removes
   ~90 s of the live startup and the 45–75 s streaming stalls near the
   spawn settlements.
2. **Move the warren search off the terrain worker** (second thread with its
   own `WorldFieldBlockCache`; solver state is already self-contained, pin
   cache writes are the only shared artifact). `record_for` returns a
   "pending" record immediately; feature blocks that only await a village
   solve report ready-with-placeholder so terrain integrates now and the
   village pops in when sealed (or fade/scaffold it in). The worker then
   never stalls > ~2 s.
3. **Relax the integration gate.** Let terrain commit when its halo blocks
   are pending *only on a village solve* (terrain geometry doesn't depend on
   it in route-first mode — `make_relief` is inert). Keep the player-freeze
   tied to terrain collision + the chunk's own features only.
4. **Priority hygiene** (cheap, do regardless):
   - Recompute `priority_distance` from the current centre when re-requesting
     (assign, don't `mini`), and drop queued terrain jobs > CHUNK_RADIUS+1
     from centre (mirror the grass cancellation).
   - Give startup support chunks a dedicated tier below everything else, and
     make gate-blocking halo feature jobs inherit tier 0.
   - Put grass at the bottom tier (or only above terrain inside FULL_RADIUS).
   - Add a motion bias: effective_distance −1 for chunks within ±45° of the
     velocity direction.

### B. Startup wall-time

5. **Persist the cold water trace/region cache** keyed by (seed, salt) —
   ~28 s of every boot is recomputing identical pure data for a pinned seed.
   Serialize after first trace (or bake at export). Fallback: keep the
   compute but overlap it with a second worker meshing the support chunks —
   region builds only need the fill/trace for wet chunks.
6. **Compile programs off the main thread / cache them.** The 1.8 s `_ready`
   block (SettlementFabricProgram 981 ms + dressing 460 ms + catalog probes)
   can run on the worker before its first job, or be cached as a built
   resource; the window and loading screen then appear ~2 s sooner.
7. **Warm particle/shader pipelines during the loading screen** (one hidden
   GPUParticles3D per material + the water/ripple shaders) to remove
   first-chunk hitches at gate-open.

### C. Chunk throughput (makes everything resilient)

8. **Broad-phase the path overlay.** Precompute once per chunk whether any
   path/feature surface intersects it (features.context already knows);
   skip `_emit_path_surface` candidacy entirely for the ~majority of quads
   in path-free cells. Expected to remove a large slice of the 1.12 s mesh
   phase (~230 k probe calls today).
9. **Flat-cell fast path.** Cells whose baked 13×13 samples are constant
   (most meadow cells) emit 2 triangles instead of 288; tint continuity is
   preserved by the existing corner-lattice interpolation.
10. **Batch vertex emission.** Replace per-vertex SurfaceTool calls with
    directly-built PackedArrays (positions/uv/color/index) — one
    `commit`-equivalent per surface; skip `index()` by emitting indexed
    quads natively. 55 k × ~3 native calls → ~10 array writes.
11. If still needed: adaptive `SAMPLES_PER_CELL` (12 on slope bands, 4–6 on
    flats), or port the quad loop to GDExtension. A second general terrain
    worker thread is also viable once the caches are split per-thread —
    but items 8–10 likely triple throughput in GDScript alone.

### D. Frame-time cleanups (normal play)

12. §6 items 1–8, in that order: overlay off, `_corners` allocation-free,
    trample epoch amortized + static rebuild keyed to trample-range chunks,
    streamer sweeps gated on centre change, grass origin quantized, cached
    physics/anim handles, reused camera query params, dirty-flagged shader
    params.

### Expected outcome (rough)

| | today | after A+B | after A–C |
|---|---|---|---|
| First boot near settlements | 150–250 s | ~30–40 s (cold water still paid once) | **~8–15 s** |
| Warm boot | ~40 s live | ~10 s | **~5 s** |
| Streaming stall near unsolved village | 45–75 s × N chunks, world frozen | none (search off-thread / pinned) | none |
| Sustained chunk rate | 0.74/s | 0.74/s | **~2–3/s** |

---

*Harness: `tests/harness/profile_startup_pipeline.gd` (new). Run:*
```
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryko/story \
  -s res://tests/harness/profile_startup_pipeline.gd -- --radius=2 --grass
```
*Use a scratch `HOME` to avoid touching the real pin cache; `--seed=N` to vary.*
