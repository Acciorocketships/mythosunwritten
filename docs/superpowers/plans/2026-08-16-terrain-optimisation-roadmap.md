# Terrain / settlement optimisation roadmap (2026-08-16)

Companion to `2026-08-15-startup-terrain-profiling.md` (measurements) and
`../specs/2026-08-16-maze-town-carver-design.md` (the town-generation
redesign). This is the list of sub-projects, the decisions already made,
their status, and the recommended order. Sub-projects marked *architectural*
get their own spec before implementation; *bounded* ones go straight to a
short in-chat design + TDD.

## Status of what was measured

| symptom (2026-08-15) | then | now (after A0 + guidance policy, commits 28334d8..fb39622) |
|---|---|---|
| Warren search per settlement | 60–450 s, 2/9 seal | **6–24 s, 8/9 seal** (one seed fails composition) |
| Startup near settlements | 154 s live / 210 s cold headless | not re-measured live; the gate still waits on every settlement in the 16-key halo — expect ~30–60 s cold until A lands |
| Streaming freeze near unsolved settlements | 45–75 s per chunk, world frozen | proportionally smaller (search ~10× cheaper) but the mechanism is unchanged: search still runs on the single terrain worker and terrain still waits on the 3×3 feature halo |
| Steady-state chunk build | 1.35 s (mesh 83 %) | unchanged |
| Cold water trace | ~28 s per boot | unchanged |
| Per-frame gameplay waste | see profiling §6 | unchanged |

## Sub-projects

### A — Async settlement resolution (architectural, spec pending)
Move village record builds off the terrain worker; let terrain integrate when
a halo block is only waiting on a village solve; show a placeholder over the
settlement footprint until it seals.
**Decisions made (chat, 2026-08-15/16):**
- Placeholder (option b): the site is held as a visible placeholder (cleared
  plot / scaffolding / fog pocket — look TBD) until sealed; terrain, paths and
  dressing stream at full speed everywhere.
- Loading screen (option b): waits for a settlement only if spawn is
  inside/adjacent to its footprint; other settlements placeholder.
- Solver speed is in scope (done as A0 + policy + maze carver spec).
**Open:** placeholder look; whether world seeds persist across sessions
(decides how much the pin cache matters beyond one session); thread design
(second worker with its own `WorldFieldBlockCache`; pin-cache writes are the
only shared artefact).
**Priority now:** still required — a hard seed or the one non-composing seed
still stalls the worker for tens of seconds, and startup still gates on the
halo — but no longer the emergency it was.

### A0 — Search speed (done)
Commits `28334d8` (timing-flag `else` fix), `333889a` (ranked bores; the
proxy pre-gate and per-source memo were later removed as guidance), `92f6b46`
and `fb39622` (all enclosure/size metrics guidance; post-composition quality
gate removed; salt `2026-08-16b`). Oracle: 8/9 seal, 6–24 s.

### A1 — Maze town carver (architectural, spec written: `../specs/2026-08-16-maze-town-carver-design.md`)
Solid-first single-pass town generation. Replaces the search entirely for the
mass-first path; expected ≤ 10 s per town, 9/9 seal, density/enclosure by
construction. **Next step:** Ryan reviews the spec → writing-plans.

### B — Streaming priority hygiene (bounded)
`FieldTerrainStreamer`: recompute `priority_distance` on re-request instead
of `mini()`; cancel queued terrain jobs > CHUNK_RADIUS+1 from centre (mirror
grass cancellation); grass tier below terrain (or only above terrain inside
FULL_RADIUS); gate-blocking halo feature jobs inherit tier 0; small
direction-of-motion bias. **Priority:** high — small diff, keeps the worker
honest once A stops starving it; also fixes the observed startup ordering
defect (non-support chunk built before a support chunk).

### C — Cold water trace (bounded-ish)
~28 s of every boot. Options: overlap with a second worker meshing support
chunks; make the trace itself cheaper (121 candidates × depth-2 rings ×
≤ 220-step traces); persist per (seed, salt) only helps reloading the same
world. **Priority:** medium — after A/B, or folded into A's thread design.

### D — Mesher throughput (bounded)
`TerrainChunkMesher.compute_chunk` 1.12 s of a 1.35 s chunk: broad-phase the
path overlay (skip candidacy probes in path-free cells; ~230 k probes today),
flat-cell fast path, batched vertex arrays instead of per-vertex SurfaceTool
calls. Expected ~3×. **Priority:** high for streaming headroom (worker duty
50–75 % at MAX_SPEED today).

### E — Per-frame cleanups (bounded, grab-bag)
CoordOverlay default off; `WaterSampler._corners` allocation-free;
TrampleField epoch hitch amortised + static rebuild keyed to trample-range
chunks; streamer sweeps gated on centre change; grass LOD origin quantised;
cached physics/anim handles; reused camera query params; dirty-flagged
shader params. **Priority:** low effort, do opportunistically.

## Recommended order

1. **A1 maze carver** (spec review → plan → implement behind `GENERATION_MODE`).
2. **B priority hygiene** (small; can run in parallel with A1 as it touches
   only the streamer).
3. **A async settlement resolution** (spec first; A1 shrinks the placeholder
   dwell time it has to hide).
4. **D mesher throughput.**
5. **C cold water trace.**
6. **E per-frame cleanups** whenever touching those files.
