# Water Redesign: Continuous Surface, Boundary-Conforming Mesh

**Date:** 2026-07-09
**Status:** Approved direction (owner), ready for implementation planning
**Supersedes:** the patch-and-carve water surface in `WaterSurfaceBuilder.gd`
(per-cell levels, rim overshoot, shore sink, rim-drop, fiction cap, hover
drape, weir bridging). `WaterPlan` / `RiverTrace` / carve are kept.

## Why

The current sheet is built from square per-cell patches whose extent is
decided by cell wetness, then carved back toward the real waterline with
special-case rules. Every rule compensates for the same lie — the mesh's
extent is not the water's boundary — and each compensation created the next
artifact (the "diagonal skirt" saga, rounds 5–17). Continuity was never a
property of the construction.

Owner's issue list this design must kill **by construction**, not by rules:

1. Missing water edges connecting water to the adjacent ground.
2. Visible under the *sides* of waterfalls (water curves down in one
   dimension only).
3. Visual seam line where a waterfall meets the pool below.
4. Static low/high sections at water edges (edges must ride the swells; no
   section may sit permanently lower than the rest).
5. Keep swells, circular ripples, character wake. Slow the too-fast
   high-frequency surface roughness. Add a visible movement cue to rivers.
6. Waterfalls ONLY where the drop exceeds 4 m. Smaller drops are a
   continuous downhill slope of the river surface. (The weir staircase the
   current system builds at every 2 m terrain step is explicitly unwanted.)

## Core principles

- **The water surface is one continuous height field `w(x, z)`**, defined
  wherever water exists. It is discontinuous only at true waterfalls
  (bed drop > `FALL_DROP_MIN = 4.0` m), nowhere else.
- **The mesh boundary IS the waterline.** Water/land intersection is where
  vertices are placed, not something patched afterwards.
- **One uniform edge rule** (the hem) instead of per-situation rules.
- Anything that reasons about "wet cells" as geometry is gone. Cells remain
  only as a sampling grid.

## Architecture

Three small units replace the sheet half of `WaterSurfaceBuilder` (falls
half replaced by the third). Target ≈ 600 lines total, each file one job.

### 1. `WaterField.gd` — the surface function (pure, deterministic)

API (all static, seeded by the plan — same determinism contract as
`HeightfieldPlan`):

- `level(x, z) -> float` — the water surface height `w`, or `-INF` when no
  body claims the point.
- `wet(x, z) -> bool` — `level(x,z) > ground(x,z) + EPS`, where ground is
  `TerrainSurfaceField.surface_y` (the rendered surface, ramps included —
  never raw noise, never flat cell tops).
- `flow(x, z) -> Vector2`, `grade(x, z) -> float` — downstream direction and
  surface slope, for shading and swim current.
- `falls(chunk) -> Array[FallCut]` — the discontinuity segments (see §3).

Definition of `w`:

- **Ponds:** flat at the pond level (storey-quantized as today; ponds are
  contained bowls and read naturally as flat).
- **River reaches:** a continuous, monotone non-increasing profile along the
  trace polyline (the trace already stores monotone beds/levels per sample).
  Interpolate levels along-channel with a monotone smooth interpolant
  (monotone cubic, or linear with smoothstep easing — implementer's choice,
  must be monotone so water never flows uphill); constant across-channel.
  Gentle terrain steps under the reach just mean locally deeper water — the
  carve already keeps the bed below the profile.
- **Falls:** wherever the *bed* drops more than `FALL_DROP_MIN` within a
  short along-window (~half a sample step), the profile is cut: upstream
  holds its level to the lip, then jumps to the downstream level. This is
  the ONLY discontinuity. Reaches entering a pond meet the pond level
  continuously unless the drop exceeds the threshold (then: fall into the
  pond).
- **Junctions:** tributary profile ends at the main stem's level at the
  junction point (continuous), same fall rule applies.

`BRIDGE_MAX` and all weir semantics are deleted; `FALL_DROP_MIN` is the one
threshold constant.

### 2. `WaterMesher.gd` — boundary-conforming sheet

Marching squares over the existing 3 m sub-grid (TILE/SUBDIV), per chunk,
on the sign of `f(x,z) = level(x,z) − ground(x,z)`:

- **Interior samples** (`f > EPS` at all four corners): regular quads,
  vertices at grid points, `y = level(x,z)`. Vertices are WELDED — build
  with an index map (position-keyed dictionary → index buffer), not a
  triangle soup. Continuity becomes checkable, not hoped for.
- **Boundary cells** (sign change): place edge vertices where `f` crosses
  zero — linear interpolation between samples, refined by 1–2 bisection
  steps against the real `surface_y` (linear alone under-shoots on curved
  ramps). Standard marching-squares triangulation for the partial cell;
  pick one fixed saddle-disambiguation rule (e.g. sample the cell centre)
  and document it.
- **The hem** (the single edge rule): every boundary edge extrudes one
  strip outward along the 2D outward normal and *downward* to
  `ground − HEM_DROP` (`HEM_DROP = 1.2` — deeper than max swell amplitude,
  swell ±0.6). The hem is buried inside the bank by construction; when
  swells raise the surface, the waterline slides up the bank instead of
  exposing an edge. This replaces: rim cells, shore sink, hover drape,
  fiction cap, rim-drop, the wetness-contour wobble, and both "dry cell"
  notions. (The wobbled organic shoreline is no longer faked — the contour
  of real terrain IS organic.)
- **Vertex attributes:** CUSTOM0 = (flow.x, shore, flow.y, steep) kept, but
  `shore` is now the true distance-to-boundary (foam lap line hugs the real
  waterline) and `steep` from `grade` (rapids whitewater on genuinely steep
  reaches) plus the plunge-churn band near fall lips (keep the round-15
  plunge bake, keyed on distance to the FallCut line).
- **Chunk seams:** all samples come from the global field with the same
  world-space coordinates, so both sides of a chunk border produce
  identical boundary vertices (same determinism the terrain relies on).
  Cross-border marching cells: sample one sub-grid margin beyond the chunk.

### 3. `FallMesher.gd` — true waterfalls only

A `FallCut` is the lip segment where the field jumps: an ordered polyline
of the *upstream* region's boundary vertices along the cut (taken from the
mesher's contour, so lip vertices are shared with the sheet **by index** —
welded, not float-matched).

- Sweep each lip vertex down the existing ogee curve (`_fall_curve` math
  carries over) to the downstream surface.
- **Sides:** the lip polyline is a waterline contour, so its ends already
  bend into the banks; the swept surface follows — the fall wraps its sides
  into the ground by construction (owner issue #2).
- **Bottom:** columns continue to `downstream_level − 0.5` — the fall dives
  *through* the plunge pool surface. The visible intersection is submerged
  under the churn band; no exposed alpha-fade edge (owner issue #3).
- Back sheet + lip cap as today (thickness, UV2 = (side, drop_h), foam by
  metres fallen). Far fewer falls exist (>4 m only), so this mesh is rare.

### 4. Shaders and motion (mostly parameter work, keep both shaders)

- **Keep:** travelling swell spectrum (and its CPU mirror in
  `character.gd` — constants must stay in sync), ripple sim (wakes, rings,
  splashes), clear refracted body, foam lap line, plunge churn, fall foam
  development.
- **Delete:** shore swell damping (`1 − smoothstep(0.45, 0.9, shore_v)`
  amplitude kill). The hem makes it unnecessary, and it caused owner issue
  #4 (static edge sections). The whole surface rides the swell; the depth
  buffer clips the moving edge against the bank.
- **Slow the roughness:** the animated refraction wobble / normal drift
  (`distort_anim` samples at `TIME * 0.02x`) reads as too-fast micro-chop.
  Halve the drift rates; expose as one uniform.
- **River movement:** advect the refraction wobble and a subtle normal
  perturbation downstream by `flow` (slow flow-map scroll, dual-phase to
  hide the reset). Combined with genuinely sloping reach surfaces, rivers
  read as moving without the old "white streak" foam.

### 5. Swim volumes and character

- Volumes still per wet region (boxes over sub-grid spans are fine), but
  `surface_y` meta becomes a sampled plane: store level + gradient (or the
  four corner levels) so sloped reaches report the right surface height at
  the character's exact position.
- `character.gd`: `water_surface_y = volume.sample(x, z) + _swell_offset()`
  — the swell mirror is unchanged.
- Buoyancy/current: `flow(x,z) * grade` can push swimmers downstream later
  (optional, out of scope).

## What gets deleted (the point of the exercise)

From `WaterSurfaceBuilder.gd`: `compute_field`'s wet/rim ring, `corner_map`
/ `_corner` (crest snap, bounded bury), `sheet_ctx` (wets/contour/droops),
`_sheet_vert` entirely (shore film, waterline band s-term, crest droop for
sub-4 m steps, plunge loop moves to the mesher), `_fiction_cap`,
`_on_dry_cell`, `_clear_of_droops`, `_edge_dist`, the rim-drop rule,
`edge_profile` float-matching welds (replaced by shared indices),
`compute_ribbons`' sub-4 m weirs, crest droop/`CREST_DROOP_RANGE` (the ogee
can start from the flat lip; if a softened lip is wanted it is a *local*
property of FallMesher, not sheet-wide). `SHORE_WOBBLE_*`, `SHORE_SDF_SCALE`,
`BRIDGE_MAX`.

## Tests

Keep the pinned-seed harness (seed 2697992464) and the GUT workflow. The
old skirt/trough/rim invariants retire with the machinery they pinned.
New invariants (red-first where possible against the old builder to prove
they detect the current bugs):

1. **Zero free edges** away from FallCuts and chunk borders: every interior
   triangle edge appears exactly twice. (The test this whole saga lacked.)
2. **Boundary verts on the waterline:** `|level − surface_y| < 0.05` at
   every contour vertex.
3. **Hem buried:** every hem outer vertex ≥ 0.5 below `surface_y`.
4. **No surface vert below the bed**; no vert above its reach level.
5. **Falls only where drop > 4 m** (and: every >4 m bed drop HAS a fall).
6. **Monotone profiles:** `w` never increases downstream along any trace.
7. **Chunk seam identity:** border vertices bit-equal from both chunks.
8. **Swim agreement:** volume-sampled surface == field level at cell
   centres.

Visual gates: the `review_vantages.json` battery at the owner's recorded
frames, plus `ReviewCam.skirt_debug` (expected: ~0 skirt-class vertices —
water with no water under it should no longer exist) and the free-edge
count printed per chunk. The stale-build check (compare his screenshot's
fall silhouette to the current build) stays step one of any review round.

## Implementation order

1. **WaterField** + profile tests (headless; no rendering). Falls detected,
   profiles monotone, junction/pond continuity green.
2. **WaterMesher** with flat debug shading; invariants 1–4, 7 green on the
   pinned seed before any look work.
3. **FallMesher** on the reduced fall set; invariant 5; lip weld by index.
4. **Shader pass:** damping removal, roughness slowdown, flow advection,
   churn rebake. Live-tune via `sheet_material().set_shader_parameter`.
5. **Volumes/character** sampling change; swim tests.
6. **Deletion sweep** of the superseded machinery + memory/docs update, then
   the full visual battery at the owner's frames.

Phases 1–2 are the risk gate: if the contour mesh looks right on the pinned
seed at the owner's vantages, everything else is incremental.

## Open questions (implementer decides, none block phase 1)

- Monotone interpolant choice for reach profiles (monotone cubic vs eased
  linear) — visual smoothness vs simplicity.
- Pond levels: keep storey quantization (flat bowls) or free levels; either
  works with the field as long as junction continuity holds.
- Whitewater threshold on `grade` for rapids foam.
- Whether the swell should attenuate with *depth* (shallow water physically
  swells less) — optional polish, not a shore special case.
- Hem width (one sub-cell, 3 m, is the default guess).
