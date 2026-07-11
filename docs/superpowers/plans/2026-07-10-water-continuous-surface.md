# Water as a Continuous Substance — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the marching-squares water skin with smooth waterline curves + a meniscus rim, motion from wave trains (zero white), Sea-of-Solitude clarity, and field-sampled swim classification — killing the owner's three round-3 artifacts at his exact frames.

**Architecture:** WaterField (unchanged, verified) supplies WHERE water is and at what level; a new WaterContour turns the waterline into G1 curves; a new WaterSkin builds interior lattice + conforming boundary + meniscus rim and bakes continuous flow frames; the rebuilt shader displaces wave trains along the river's arc length; the character samples the field directly through a WaterSampler handle.

**Tech Stack:** Godot 4.5.1 GDScript (TABS), GUT, godot-MCP for in-game verification, seed 2697992464.

**Spec:** docs/superpowers/specs/2026-07-10-water-continuous-surface-design.md (the requirements; this plan implements it 1:1).

## Global Constraints (verbatim from spec + standing rules)

- Zero albedo whitening anywhere: no foam mask, no steep wash, no plunge whitening, no streaks.
- Nothing per-cell may drive appearance; per-vertex data must be continuous samples of continuous fields (CUSTOM0 = s, d, slope, shore_dist).
- Reflections: fresnel + sky + sun only.
- WaterField, WaterPlan, all field oracles, and profiles stay untouched (any needed helper is additive).
- Free-edge invariant: only the meniscus rim's buried outer row and true chunk borders may be free edges.
- Chunk-seam determinism: border curve points bit-equal across neighbouring chunks.
- Swim hysteresis unchanged (enter >0.8 / exit <0.6; wading 0.05/0.03; wading ⊇ swimming).
- Look targets (tune at battery frames, then bake): body_floor ≈0.12, clarity_depth ≈12, shallow tint ≤0.10, refraction_strength ≈0.11, roughness ≈0.12.
- Verification is test-based AND visual AND falsification-based, at the owner's exact F3 frames; R3-A adds a motion-pair diff.
- GDScript TABS; never stage project.godot or mcp_interaction_server.gd; class-cache refresh via `--import`, NEVER `--quit`; commit per task with trailer `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- GUT command per file: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/<file>.gd -gexit`.
- Water tests must reuse the static per-seed plan/region caches in tests/test_water_field.gd (fresh plans re-trace cold → timeouts).

## File Structure (locked)

- Create `scripts/terrain/water/WaterContour.gd` — waterline → smooth curves (pure; no nodes).
- Create `scripts/terrain/water/WaterSkin.gd` — curves + field → mesh arrays, flow frames, trigger rects (pure; replaces WaterMesher.gd, which is DELETED at Task 7).
- Create `scripts/terrain/water/WaterSampler.gd` — RefCounted `level_at(xz)` handle frozen at build.
- Create `terrain/water/water_waves.gdshaderinc` — the single wave-constants table (shader + character mirror read the SAME numbers).
- Rewrite look/motion in `terrain/water/water_unified.gdshader` (same file; body/refraction/fresnel machinery survives).
- Modify `scripts/terrain/water/WaterSurfaceBuilder.gd` (adapter: contour → skin → nodes), `characters/character.gd` (_update_in_water + river-train mirror), `scripts/terrain/tools/ReviewCam.gd` (shoot_pair), `tests/tools/review_vantages.json` (+3 frames).
- Tests: create `tests/test_water_contour.gd`, `tests/test_water_skin.gd`; modify `tests/test_water_swim_volumes.gd`; delete `tests/test_water_mesher.gd` (port the two survivors named in Task 7).

## Phase 0 — Diagnostics + instruments (before any behavior change)

### Task 1: R3-B ghost discriminating experiment

**Files:** none committed except `.superpowers/sdd/progress.md` (verdict entry).
**Procedure (godot-MCP, exact):** run the game; `ReviewCam.pose(Vector3(80.7, 4.0, -1177.7))`; wait for streaming; shoot `r3b_base.png` with crosshair `(80.3, 4.2, -1177.8)`. Then eval:

```gdscript
var ch = ((Engine.get_main_loop() as SceneTree).root).get_node("World/Characters/Character")
for mi in ch.find_children("*", "GeometryInstance3D", true, false):
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
```

Re-shoot as `r3b_noshadow.png`. **Ghost gone ⇒ SHADOW verdict** (fix in Task 10 = `shadows_disabled`). **Ghost persists ⇒ REFRACTION verdict** (fix in Task 10 = guard hardening). Restore `SHADOW_CASTING_SETTING_ON`, record verdict + both PNG paths in the ledger. No code change in this task.

### Task 2: Instruments — red-first turn-angle oracle + motion-pair capture

**Files:** create `tests/test_water_contour.gd` (first test only), modify `scripts/terrain/tools/ReviewCam.gd`.
**Produces:** `ReviewCam.shoot_pair(player: Vector3, crosshair: Vector3, path_a: String, path_b: String, dt := 0.7)` — two frames dt apart (uses `await (Engine.get_main_loop() as SceneTree).create_timer(dt).timeout` between two force-draw captures; camera solved once).

- [ ] Write `test_current_boundary_has_marching_square_corners` in tests/test_water_contour.gd: extract the CURRENT WaterMesher boundary polyline at site chunk (0,-6) (walk mesh free/waterline edges via the existing build, chain into polylines ≥ 20 points), compute `max_turn = max over consecutive segment pairs of angle between them`, and assert `max_turn_deg < 25.0` for non-wall points. **Expected: FAIL at current HEAD** (marching squares produces ~45–90° turns) — this proves the instrument measures the artifact. Print the offending corners.
- [ ] Run it; confirm RED with the corner list. Commit test + ReviewCam helper (test stays red until Task 3 flips the boundary source; mark with `# RED until WaterContour lands (plan Task 3)` and skip-guard it behind `if not ClassDB.class_exists("WaterContour")`... NO — GUT has no ClassDB for user classes; instead: `if not ResourceLoader.exists("res://scripts/terrain/water/WaterContour.gd"): pass_test("pre-WaterContour baseline recorded"); return` so the suite stays green in CI while the red evidence lives in the task report).
- [ ] Commit: `test(water): r3 instruments — turn-angle oracle (red evidence recorded) + shoot_pair`.

## Phase 1 — WaterContour

### Task 3: waterline → smooth welded curves

**Files:** create `scripts/terrain/water/WaterContour.gd`; extend `tests/test_water_contour.gd`.
**Interfaces (Produces — later tasks depend on these exact names):**

```gdscript
class_name WaterContour
## curves(ctx, rect) -> Array[Dictionary], each:
##   pts: PackedVector2Array      # world xz, ~1.5 m spacing, G1-smooth
##   levels: PackedFloat32Array   # water level at each pt (field truth)
##   normals: PackedVector2Array  # outward (dry-side) unit normals
##   wall: PackedByteArray        # 1 where local ground slope across the line > WALL_SLOPE (1.2)
##   closed: bool
static func curves(ctx: Dictionary, rect: Rect2) -> Array
```

Algorithm (implement exactly this shape):
1. Presence grid at `STEP := 3.0` over `rect.grow(MARGIN := 12.0)`, `wet := WaterField.level_at(ctx, p) - ground(p) > 0.02` (ground = region surface_y via the ctx region; out-of-rect ground reads are inside the grown rect only — never beyond MARGIN).
2. For each grid edge with a sign change, refine the crossing by 3 bisection steps at 1.5 m→0.4 m resolution.
3. Chain crossings into polylines (shared-edge adjacency, closed loops when ends meet within 0.5 m).
4. Smooth: TWO Chaikin passes (corner-cutting 1/4–3/4), then resample uniformly at `SPACING := 1.5`.
5. Clip to `rect`: polyline points outside are dropped; the two border-crossing points are interpolated EXACTLY onto the rect edge (both neighbouring chunks compute the same crossing because sampling is world-grid-aligned and the field is deterministic — this is the weld).
6. Per point: level from `level_at`, outward normal from the polyline frame oriented toward the dry side, wall flag = ground rises > `WALL_SLOPE := 1.2` per metre along +normal (probe at +0.5 m and +1.5 m).

Tests (all in tests/test_water_contour.gd, reusing the static seed caches):
- [ ] `test_pond_yields_smooth_closed_curve` — pinned site lake chunk (0,-47): ≥1 closed curve, `max_turn_deg < 25` on non-wall points, spacing within [1.0, 2.0]. (This is the Task-2 oracle now measuring the NEW boundary — remove the pre-WaterContour skip; expected GREEN, and the red→green pair is the artifact evidence.)
- [ ] `test_border_curves_weld` — for chunk pairs ((0,-6),(1,-6)) and ((0,-47),(0,-46)) on seeds 2697992464 and 991177: collect each side's border-edge points, assert one-to-one match with `is_equal_approx` (bit-equality target; tolerance 1e-4 max).
- [ ] `test_wall_stays_straight` — the I4 wall reach (cell (2,-46) east wall, x≈36–48, z≈-1104..-1080): consecutive wall-flagged points are collinear within 0.15 m deviation.
- [ ] `test_curve_levels_match_field` — every pt: `abs(level - WaterField.level_at(ctx, pt)) < 0.05`.
- [ ] Run suite; class-cache `--import` first (new class_name). Commit: `feat(water): WaterContour — smooth welded waterline curves`.

## Phase 2 — WaterSkin

### Task 4: interior lattice + conforming boundary strip (flat look, no rim yet)

**Files:** create `scripts/terrain/water/WaterSkin.gd`, `tests/test_water_skin.gd`; modify `scripts/terrain/water/WaterSurfaceBuilder.gd` (call skin when curves exist; WaterMesher path still present for fallback until Task 7).
**Interfaces (Produces):**

```gdscript
class_name WaterSkin
## build(water, chunk, region) -> {} when dry, else:
##   arrays: Array           # Mesh.ARRAY_MAX arrays, indexed, welded
##   triggers: Array[Dictionary]  # {rect: Rect2, top: float, bottom: float}
##   sampler: WaterSampler
static func build(water: WaterPlan, chunk: Vector2i, region) -> Dictionary
```

- Interior vertices on a 3.0 m world-aligned lattice at points ≥ 2.0 m inside a curve (point-in-polygon by winding over the chunk's curves + presence-grid acceleration); height = `level_at`.
- Boundary strip: for each curve point, one vertex ON the curve at its level; stitch curve ring ↔ nearest interior ring as a triangle strip walk (no T-junctions: interior lattice rows adjacent to the strip connect only through strip vertices).
- Weld everything into one indexed surface; vertex key = quantized (x, z, y·64).
- [ ] Tests first: `test_skin_builds_on_site_chunk` (non-empty, indexed, tri count within 2× of old mesher's for the same chunk — print both), `test_no_free_edges_except_border` (port the free-edge walker from test_water_mesher.gd; until Task 5 the boundary-strip outer edge IS the waterline: assert free edges lie on curves or chunk border), `test_interior_rides_field` (50 random interior verts: `abs(y - level_at) < 0.03`).
- [ ] Implement; suites green; visual gate: battery frames R3-C + r5-V1 — waterline visibly curved, no corners (screenshot into scratchpad, path in report).
- [ ] Commit: `feat(water): WaterSkin interior+boundary — curved waterline mesh`.

### Task 5: meniscus rim

**Files:** modify `scripts/terrain/water/WaterSkin.gd`, `tests/test_water_skin.gd`.
Profile per curve point (local frame: outward normal n̂, level L, ground g(p)):

```
row0: p - 0.6·n̂,  y = L            (weld into boundary strip vertex — same index)
row1: p,          y = L - 0.02
row2: p + 0.35·n̂, y = L - 0.18
row3: p + 0.55·n̂, y = min(L - 0.30, g(p + 0.55·n̂) - 0.30)   (ALWAYS ≥0.30 under ground — the seal)
```

Wall-flagged points pinch rows 2–3 to +0.05·n̂ (water meets wall flush, no bulge into rock).
- [ ] Tests: `test_rim_outer_row_is_buried` (every row3 vert ≥ 0.25 below region ground), `test_free_edges_only_buried_rim_or_border` (tighten Task 4's invariant to final form), `test_rim_welds_to_strip` (row0 indices == strip indices; no duplicate positions).
- [ ] Visual gate at the owner's old blob frame (9.3, 0.0, -1120.6) + R3-A frame: rounded curling edge visible.
- [ ] Commit: `feat(water): meniscus rim — water curls into its banks (the blob)`.

### Task 6: flow frames (CUSTOM0)

**Files:** modify `scripts/terrain/water/WaterSkin.gd`, `tests/test_water_skin.gd`.
- CUSTOM0 per vertex (ARRAY_CUSTOM0, CUSTOM_RGBA_FLOAT): `(s, d, slope, shore_dist)`.
  - Rivers: project vertex to nearest trace polyline → s = arc length from source (metres), d = signed cross distance, slope = profile slope at s via `(prof[i+1]-prof[i])/seg_len` sampled continuously, all from ctx traces. Junction zones (two traces within 12 m): weight by 1/d², blend s direction only.
  - Ponds/lakes (no trace within 18 m): s = 0, d = 0, slope = 0.
  - shore_dist = distance to nearest curve point (clamped 0..8).
- [ ] Tests: `test_s_is_continuous_along_river` (walk 30 consecutive river verts along flow: |Δs − spatial step| < 0.5, strictly increasing), `test_slope_is_continuous` (adjacent verts |Δslope| < 0.15), `test_pond_frames_are_calm` (lake verts: slope==0 and d==0).
- [ ] Commit: `feat(water): continuous flow frames — arc length, cross, slope, shore distance`.

### Task 7: triggers + sampler; delete WaterMesher

**Files:** create `scripts/terrain/water/WaterSampler.gd`; modify `WaterSkin.gd`, `WaterSurfaceBuilder.gd`; DELETE `scripts/terrain/water/WaterMesher.gd`, `tests/test_water_mesher.gd`.

```gdscript
class_name WaterSampler
extends RefCounted
## Frozen chunk water: level_at(xz) -> float (NAN when dry). Read-only after
## build; safe to query from the main thread every physics frame.
func level_at(xz: Vector2) -> float
```

- Triggers: one box per 24 m wet coverage tile (footprint from the presence grid, top = max level in tile + 1.7, bottom = min ground − 5.0); every Area3D carries `set_meta("sampler", sampler)` — surface_c/surface_g metas are GONE.
- WaterSurfaceBuilder.build_chunk: contour → skin → WaterSheet MeshInstance3D + trigger Area3Ds (layer 1<<7). Delete the WaterMesher fallback path.
- Port the two surviving mesher tests into test_water_skin.gd verbatim: `test_no_waterfall_nodes`, the swim STEEP no-volume rule becomes `test_no_trigger_where_unswimmably_steep` (max |grade| > 0.45 over a tile ⇒ no trigger box for that tile — same 0.45 constant, same rationale comment).
- [ ] Straggler grep: `WaterMesher|wet_cells|surface_c|surface_g|_hem|HEM_W|hem_start` — zero hits outside docs/superpowers/, .superpowers/, and git history.
- [ ] All suites + `--import` first. Commit: `feat(water): triggers+sampler; marching-squares mesher deleted`.

## Phase 3 — Look, motion, classification

### Task 8: shader rebuild — waves not white

**Files:** create `terrain/water/water_waves.gdshaderinc`; rewrite motion/look sections of `terrain/water/water_unified.gdshader`.
- DELETE from the shader: `water_foam_mask` usage, steep wash, streak scroll, plunge whitening, `foam_width` uniform, the CUSTOM0 shore/steep semantics.
- water_waves.gdshaderinc — the single constants table (shader + character read THESE names):

```glsl
// Pond spectrum: EXISTING five travelling sines verbatim (copy current
// constants — they are owner-approved; do not retune).
// River trains (s = CUSTOM0.x, slope = CUSTOM0.z, shore = CUSTOM0.w):
const float RIVER_K1 = 1.9;        // λ≈3.3 m primary train
const float RIVER_K2 = 3.4;        // λ≈1.8 m crossed train (steep only)
const float RIVER_SPEED1 = 2.6;    // m/s downstream
const float RIVER_SPEED2 = 3.8;
const float RIVER_AMP_BASE = 0.055;
const float RIVER_AMP_SLOPE_GAIN = 2.4;   // A = BASE*(1+GAIN*slope)
const float RIVER_CROSS_RAD = 0.31;       // ~18° cross angle for train 2
const float PLUNGE_RING_K = 2.2;
const float PLUNGE_RING_SPEED = 3.1;
const float PLUNGE_RING_AMP = 0.10;       // fades over 4 m from steep-span base
```

- vertex(): displacement = pond spectrum (world xz, shore-faded by `smoothstep(0.0, 4.0, CUSTOM0.w)`) + river train1 `A·sin(RIVER_K1·s − RIVER_SPEED1·RIVER_K1·t)` + train2 gated `smoothstep(0.15, 0.45, slope)` with phase `RIVER_K2·(s·cos(CROSS) + d·sin(CROSS)) − …` + plunge rings where the fragment is within 4 m of a steep-span base (bake that distance INTO shore_dist's unused range? NO — add it to CUSTOM1.x at Task 6's bake if needed; simpler: rings ride slope>0.3 && d-based radial term — keep it train-based, no new streams).
- fragment(): body/refraction/fresnel survive; ripple normals advect by `vec2(s, d)` where slope>0 else world xz; clarity params per Global Constraints; `roughness 0.12`.
- [ ] `shader_compile_check` passes; screenshots at R3-C frame: no white anywhere, motion visible in stills as waveform shading. Commit: `feat(water): motion from waves — white deleted, SoS clarity`.

### Task 9: field-sampled classification + CPU mirror

**Files:** modify `characters/character.gd`, `tests/test_water_swim_volumes.gd` (rename intent: triggers), extend `tests/test_water_skin.gd`.
- `_update_in_water`: for each overlapping trigger, `var lvl = area.get_meta("sampler").level_at(Vector2(gp.x, gp.z))`; skip NAN; `depth = lvl + _swell_offset(gp, t) - gp.y`; take max depth over triggers; hysteresis + wading unchanged (`wading = in_water or best_wading`).
- `_swell_offset` gains the river-train terms mirrored from water_waves.gdshaderinc constants (same names in a `const` table with a comment pointing at the include; pond spectrum already mirrored). Rivers need s/d/slope at the character: sampler exposes `flow_frame_at(xz) -> Vector3(s, d, slope)` (bilinear from the skin's bake grid — add to WaterSampler in this task, frozen like level_at).
- [ ] `test_classification_parity`: 60 points per class (deep interior, waterline ±0.3 m, dry bank, steep chute) on the pinned site: field-truth depth class (level_at − ground vs thresholds) == the character-math class (sampler + zero-time swells). Zero mismatches.
- [ ] Live gates (godot-MCP, physics on, settle, read): I4 spot (36.4→ in_water=false, wading=true), I1 slope (false/false), I5 bank (false/false), lake centre (9.3,-1120.6 → in_water=true).
- [ ] Commit: `feat(water): swim depth from the field itself — plane metas gone`.

### Task 10: R3-B fix per Task 1 verdict

**Files:** `terrain/water/water_unified.gdshader` (+ character.gd only if REFRACTION verdict requires no shader-side fix).
- SHADOW verdict: add `shadows_disabled` to render_mode; comment: `// R3-B: object shadows on the clear surface read as ghosts (owner frame (80.7,4,-1177.7)); the reference look has none. Depth tint keeps the surface grounded.`
- REFRACTION verdict: in the guard, replace the graded fallback for ABOVE-SURFACE samples with outright rejection (`ok = 0.0` when water_depth_world(suv) < 0.0), widen the near-geometry margin `VERTEX.z + 0.05 → + 0.35`, and re-test the round-5 lens-edge frame (r5-V2) to prove the old artifact does not return.
- Then raise `refraction_strength` to 0.11 (both verdicts).
- [ ] Falsification check at the exact R3-B frame (shadow ON, normal game state): ghost unfindable. Commit: `fix(water): R3-B ghost — <mechanism>`.

## Phase 4 — Battery + cleanup + review

### Task 11: 19-frame falsification battery, docs, close

- [ ] `tests/tools/review_vantages.json` += (exact):

```json
{"name": "owner-r3-A shore crease, obvious with motion", "player": [68.3, 4.0, -1172.4], "crosshair": [68.3, 4.2, -1172.0], "motion_pair": true},
{"name": "owner-r3-B ghost hat in water", "player": [80.7, 4.0, -1177.7], "crosshair": [80.3, 4.2, -1177.8]},
{"name": "owner-r3-C marching corners + texture cutoff", "player": [34.4, 8.0, -1107.1], "crosshair": [34.3, 8.2, -1107.4], "motion_pair": true}
```

- [ ] Full battery: all 19 frames, one pose/shoot per eval (stale-overlay rule), full-frame streaming verified before each shot; `motion_pair` frames use `shoot_pair` and an offline pixel diff along the waterline band (python PIL, report the max coherent-edge magnitude); EVERY frame reviewed falsification-first against its named issue.
- [ ] AGENTS.md water section rewritten (contour/skin/sampler architecture, zero-white rule, wave constants discipline); assistant memory updated; straggler grep from Task 7 re-run plus `foam|steep_v|shore_v`.
- [ ] All suites green (field, contour, skin, swim/triggers, plan, shared terrain); performance: log contour+skin build ms vs the old mesher baseline captured in Task 4 (budget ≤1.5×).
- [ ] Ledger roll-up for the whole-run reviewer; final whole-branch review (fable) over this plan's commit range; fix wave if needed; close.

## Verification principles (binding, apply to every task)

- Red-first wherever an existing artifact can be pinned (Task 2 turn-angle oracle is the template); oracles measure issue-level properties, never fix internals.
- Test + visual: suites green AND battery frames reviewed by trying to PROVE the issue persists, at the owner's exact coordinates; motion artifacts need the frame-pair diff, stills lie.
- The owner judges the substance/clarity feel (R3-D) — screenshots at battery frames are the deliverable for that judgment, not a metric.

## Self-review notes (kept honest)

- Spec coverage: every spec section maps to a task (contour §2→T3; skin/rim §2→T4-5; flow §2→T6; triggers/sampler §6→T7,9; shader §3-4→T8; bugs §5→T1,10; verification §7→T2,11). No gaps found.
- Type consistency: `WaterContour.curves(ctx, rect)`, `WaterSkin.build(water, chunk, region)`, `WaterSampler.level_at(xz)/flow_frame_at(xz)`, CUSTOM0 (s,d,slope,shore_dist) — names used identically across Tasks 3–9.
- Known judgment points delegated to implementers WITH the decision recorded in reports: boundary-strip stitch tactic (Task 4), junction blend falloff (Task 6), plunge-ring keying without new vertex streams (Task 8).

## Erratum (2026-07-10, during Task 3)

Task 3's test coordinates confused 24 m CELLS with 192 m streamer CHUNKS: "lake chunk (0,-47)" and the weld pair "((0,-47),(0,-46))" are dry as chunks (they were cell ids). Task 3's implementer verified substitutes and documented them in tests/test_water_contour.gd docstrings + r3-task-3-report.md: isolated pond chunk (-4,-18) for the closed-curve test, and verified wet border pairs (one per seed) for the weld test. Later tasks: all `Vector2i` chunk arguments are 192 m streamer chunks (site = (0,-6), which also contains the I3 lake at world (9.3, -1120.6)); world-coordinate frames in Tasks 1/5/9/11 are unaffected.

## Round-4 addendum (2026-07-11, owner feedback at fa7925f)

### Task 12: smooth pool-to-pool descent (R4-C)

**Files:** modify `scripts/terrain/water/WaterField.gd` (`_descend_segment` and its callers), `tests/test_water_field.gd`.
Owner directive (verbatim intent): the down slope must NOT be based on the shape of the terrain below — one continuous curve from the higher pool to the lower pool; no sharp angles anywhere in water. This REVERSES run-2's terrain-hugging descent.
- New descent: anchors = span start (upper level) and span end (lower pool level). Surface = C1 monotone smoothstep-shaped ease between anchors. Clamp ≥ ground + 0.05 where terrain pokes through the ramp, then re-smooth the clamped profile with a ≥8 m window so clamp bumps stay soft (target: max |Δslope| per 1.5 m below the turn-angle oracle's threshold when projected into the contour).
- The stepped-cascade tiles' level spreads change → re-derive/re-verify TRIGGER_SUB_TILE_SPREAD_MAX semantics (the I1 chute pin and I4 pin MUST still hold — they are the regression net; if the smooth ramp legitimately changes a pin's static depth, STOP and report, don't retune silently).
- Red-first: `test_descent_is_smooth_pool_to_pool` — along the site chute's descent line, second differences of the profile bounded (no step > 0.5 m per 4 m sample); must FAIL at fa7925f (stepped) then pass. Keep `test_profiles_monotone_and_continuous` green.

### Task 13: river motion rework — flow-advected normals, no geometric aliasing (R4-A + R4-D)

**Files:** modify `terrain/water/water_waves.gdshaderinc`, `terrain/water/water_unified.gdshader`, `characters/character.gd` (mirror), `tests/` (mirror parity if asserted).
- Root cause of R4-A: λ1.8/3.3 m trains vertex-displace a 3 m lattice (below Nyquist) → moiré terraces. Fix structurally: river trains LEAVE the vertex domain. Geometry displaces only pond swells + ONE long river undulation (λ ≥ 8 m, gentle). CPU float mirror updated identically (constants stay name-mirrored).
- R4-D: fragment-side **flow-map-style normal advection** (Valve/Portal-2 two-phase technique): advect the detail normal texture along the baked flow direction (from CUSTOM0 (s,d) frame — analytic, no flow-map texture needed), TWO phases offset by half a cycle, triangle-wave crossfade to hide resets; advection speed scales with slope (rapids rush); ponds keep isotropic ripple drift. Zero white stays absolute.
- Verify: moiré unfindable at R4-A's exact frame (44.2, 7.0, -1084.4)/(44.2, 7.2, -1084.1); motion-pair diff still shows coherent downstream movement; compile check.

### Task 14: water touches walls (R4-B)

**Files:** modify `scripts/terrain/water/WaterSkin.gd` (`_rim` wall branch), `tests/test_water_skin.gd`.
- Wall-flagged rim rows currently pinch to +0.05·n̂ at the exact waterline, leaving a visible slot at vertical faces. Fix: wall-flagged rows 2-3 extend INTO the rising face (+0.40·n̂ at surface level, row3 buried as usual) — the depth buffer clips the overshoot invisibly; water meets the wall flush (pre-refactor behaviour, but only where the wall flag says ground RISES — never over drops).
- Test: `test_wall_rim_reaches_the_face` — at the R4-B frame's wall reach (62.1, -1138.5 area), rim outer verts' xz sit ≥ 0.3 beyond the waterline into the wall; free-edge invariant still holds. Visual gate at the exact frame: no gap.

### Sequencing
Task 12 → 13 → 14 (12 changes the field that 13/14 render); Task 10 (ghost, in flight) is independent; Task 11's battery grows to 22 frames (+R4-A/B/C exact frames) and runs LAST as before.

## Round-5 addendum (2026-07-11, owner feedback at 3cd407d-era build)

Owner frames: R5-A maze texture + dry band, player (46.2, 4.0, -1102.9) crosshair (46.1, 4.2, -1103.3); R5-B edges + diagonal corner, player (129.6, 4.0, -1166.1) crosshair (129.7, 4.2, -1165.8). Binding process (owner, verbatim intent): failing tests first that try to prove it's still failing; screenshots from HIS exact positions trying to prove the issues are NOT fixed.

### Task 13 (REWRITTEN — owner-specified): moving water = flow-advected, slowly-morphing refraction distortion, entirely clear

Owner spec (2026-07-11, verbatim intent): "the scroll motion should not have any white in it, it should be entirely clear. the only thing that will make it visible is changes in refraction (a bit like the distortion effect in the water right now, but the distortion pattern moves). also the distortion should slowly morph as it moves."
- DELETE from the shader: all geometric river trains (RIVER_K1/K2 vertex displacement — the maze/moiré source) and the slope-gated train2 seam. Geometry keeps ONLY the pond swell spectrum (long λ, owner-approved) shore-faded as today.
- The refraction distortion field becomes the sole river-motion carrier: advect the distortion-noise sampling along the flow frame — u = (s − flow_speed(slope)·t, d) — with the TWO-PHASE half-offset blend (phase A and phase B offset by half a cycle, triangle-wave crossfade) so the scroll never visibly resets; each phase samples an independently TIME-EVOLVING noise coordinate so the pattern MORPHS while travelling (no rigid conveyor look).
- Ponds/trace-free water: the same distortion field with slow isotropic drift + morph — ONE code path; direction/speed vary continuously via the flow frame (river↔pool discontinuity structurally impossible).
- ZERO albedo modulation from motion. Distortion perturbs the refraction offset ONLY (never the lighting normal — existing convention); rides the hardened above-surface sample guard.
- Constants into water_waves.gdshaderinc (mirror-block style); the character mirror needs NO river term anymore (geometric river displacement is gone — float height = level + pond swells only where present); update character.gd mirror accordingly (deletion).
- Verify falsification-first at R5-A's exact frame: the maze class (parallel right-angle interference lines) unfindable in stills AND in a motion pair; the pool/chute texture seam unfindable (walk the crosshair across the slope-gate line).

### Task 14 (UPGRADED): water reaches every shore — universal overshoot + bulgier meniscus

- Rim overshoot into RISING ground everywhere (not walls only): outer rows extend +0.40·n̂ into any bank whose ground rises above the level within 1 m of the waterline (the pre-refactor film behaviour the owner cited as better); buried row3 seals as today. Over falling/level ground the rim keeps the current profile (no films over drops).
- Meniscus bulge: row1/row2 gain a slight positive bulge (+0.04/+0.02 above L) before curling down — the blob/surface-tension read.
- Red-first at R5-B's exact frame: a probe ray from the annotated gap must currently find bank pixels between waterline and wall (prove the gap), then not (fixed). Free-edge invariant maintained.

### Task 15 (NEW): diagonal saddle corners

- WaterContour._presence_segments: resolve marching-squares SADDLE cells (two wet + two dry corners diagonally) by sampling the field at the CELL CENTRE (standard disambiguation) instead of the current fixed tie-break; the chosen topology must connect the water wedge where two land corners meet diagonally.
- Red-first: reproduce the R5-B junction (find the saddle cell near (129.7, -1165.8)-adjacent water); test asserts the contour connects the wedge (no missing corner); show RED at HEAD with the saddle cell's coordinates, then GREEN.

### Sequencing (round 5)
Task 12-v2 (in flight) → Task 15 (contour bug; small) → Task 14 (rim) → Task 13 (texture redesign) → Task 11 battery grows to 24 frames (+R5-A, R5-B exact frames, each with motion pairs).
