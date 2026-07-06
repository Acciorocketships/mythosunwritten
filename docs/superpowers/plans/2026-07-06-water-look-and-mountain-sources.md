# Water Look & Mountain Sources Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore normal water animation speed, make rivers read fast/rough via real geometric chop, give the water a clear reference-image look, and start rivers at mountain-top source pools.

**Architecture:** All look changes live in `terrain/water/water_unified.gdshader` (one material for the whole network; flow + steepness arrive per-vertex in CUSTOM0). Chop needs vertex density the 24 m cell quads don't have, so `WaterSurfaceBuilder._sheet_quad` gains a bilinear SUBDIV grid. Source placement is a pure-function change inside `WaterPlan` (gradient ascent + prominence gate), leaving tracing/carving untouched.

**Tech Stack:** Godot 4.5 (Forward+), GDScript, GUT tests, gdshader.

Spec: `docs/superpowers/specs/2026-07-06-water-look-and-mountain-sources-design.md`

---

### Task 1: Subdivide water sheet quads (chop needs vertices)

**Files:**
- Modify: `scripts/terrain/water/WaterSurfaceBuilder.gd` (`_sheet_quad`, new const)
- Test: `tests/test_water_surface_builder.gd`

- [ ] **Step 1: Write the failing test** — sheet triangle count = wet-cells × SUBDIV² × 2, and every vertex stays inside the cell's corner-height envelope (bilinear patch, no new extremes):

```gdscript
func test_sheet_quads_are_subdivided_for_shader_chop() -> void:
	var plan: WaterPlan = _water()
	var river: RiverTrace = _a_river(plan)
	var chunk: Vector2i = _river_chunk(plan, river)
	var node: Node3D = WaterSurfaceBuilder.new().build_chunk(plan, chunk)
	assert_not_null(node, "river chunk builds")
	var mesh: Mesh = null
	for c in node.get_children():
		if c is MeshInstance3D:
			mesh = c.mesh
	assert_not_null(mesh, "water sheet mesh present")
	var field: Dictionary = WaterSurfaceBuilder.compute_field(plan, chunk)
	var lo: Vector2i = Vector2i(chunk.x * 8, chunk.y * 8)
	var quads: int = 0
	for cell in field:
		if cell.x >= lo.x and cell.x < lo.x + 8 and cell.y >= lo.y and cell.y < lo.y + 8:
			quads += 1
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert_eq(verts.size(), quads * WaterSurfaceBuilder.SUBDIV * WaterSurfaceBuilder.SUBDIV * 6,
		"every cell quad is a SUBDIV x SUBDIV bilinear grid")
	node.free()
```

- [ ] **Step 2: Run it, expect FAIL** (`SUBDIV` undefined):
`/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_water_surface_builder.gd -gexit`

- [ ] **Step 3: Implement.** Add const near TILE:

```gdscript
# Sub-quads per cell edge. The shader displaces real chop waves (~14-26m
# wavelength); 24m cell quads can't bend, 3m vertex pitch can.
const SUBDIV := 8
```

Replace the emit loop at the end of `_sheet_quad` (keep pos/cust corner computation) with a bilinear grid emit:

```gdscript
	# Bilinear SUBDIV grid over the quad: chop displacement in the vertex
	# shader needs vertices far denser than the 24m cell pitch. Corners are
	# ordered [min, +x, +xz, +z]; interpolation reproduces the exact corner
	# values at the edges, so adjacent cells stay watertight.
	for sz in SUBDIV:
		for sx in SUBDIV:
			var u0: float = float(sx) / float(SUBDIV)
			var u1: float = float(sx + 1) / float(SUBDIV)
			var v0: float = float(sz) / float(SUBDIV)
			var v1: float = float(sz + 1) / float(SUBDIV)
			var p00: Vector3 = _bilerp_pos(pos, u0, v0)
			var p10: Vector3 = _bilerp_pos(pos, u1, v0)
			var p11: Vector3 = _bilerp_pos(pos, u1, v1)
			var p01: Vector3 = _bilerp_pos(pos, u0, v1)
			var c00: Color = _bilerp_cust(cust, u0, v0)
			var c10: Color = _bilerp_cust(cust, u1, v0)
			var c11: Color = _bilerp_cust(cust, u1, v1)
			var c01: Color = _bilerp_cust(cust, u0, v1)
			for pair in [[p00, c00], [p01, c01], [p11, c11], [p00, c00], [p11, c11], [p10, c10]]:
				st.set_custom(0, pair[1])
				st.set_uv(Vector2(0.0, 0.0))
				st.add_vertex(pair[0])


static func _bilerp_pos(pos: Array, u: float, v: float) -> Vector3:
	return (pos[0].lerp(pos[1], u)).lerp(pos[3].lerp(pos[2], u), v)


static func _bilerp_cust(cust: Array, u: float, v: float) -> Color:
	return (cust[0].lerp(cust[1], u)).lerp(cust[3].lerp(cust[2], u), v)
```

(The `[0,3,2][0,2,1]` corner winding faces +Y; the sub-quad pattern `[00,01,11][00,11,10]` preserves it.)

- [ ] **Step 4: Run the water-surface tests, expect PASS** (same command as Step 2 — the old count test doesn't exist; all existing tests must stay green).

- [ ] **Step 5: Commit** `feat(water): subdivide sheet quads — vertex density for real chop waves`

### Task 2: Shader — normal-speed ripples, steepness-scaled scroll, geometric chop, flow streaks

**Files:**
- Modify: `terrain/water/water_unified.gdshader`
- Modify: `terrain/water/water_common.gdshaderinc` (new `water_chop_h`)

- [ ] **Step 1: Add the chop helper to `water_common.gdshaderinc`:**

```glsl
// Crest-sharpened wave trains advected downstream at `speed` (m/s): sharp
// ridges, flat troughs (1-|sin| profile), two wavelengths (~14m and ~26m),
// decorrelated by world noise so crests never read as parallel bars.
// Roughly zero-mean so the sheet's average level doesn't rise.
float water_chop_h(sampler2D noise_tex, vec2 p, vec2 fdir, float speed, float t) {
	float along = dot(p, fdir);
	float across = dot(p, vec2(-fdir.y, fdir.x));
	float brk = textureLod(noise_tex, p * 0.03, 0.0).r;
	float w1 = 1.0 - abs(sin((along - t * speed) * 0.45 + across * 0.18 + brk * 4.0));
	float w2 = 1.0 - abs(sin((along - t * speed * 1.30) * 0.24 - across * 0.10 + brk * 2.5));
	return w1 * w1 * 0.65 + w2 * w2 * 0.35 - 0.45;
}
```

- [ ] **Step 2: Rework `water_unified.gdshader` vertex/fragment.** Uniform changes: `flow_speed` default back to **3.0**, new `rapids_boost = 1.5`, new `chop_height = 0.22`. Vertex becomes:

```glsl
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	flow_v = CUSTOM0.xyz;
	steep_v = CUSTOM0.w;
	float fs = clamp(length(flow_v.xz), 0.0, 1.0);
	vec2 fdir = fs > 0.001 ? normalize(flow_v.xz) : vec2(1.0, 0.0);
	float t = TIME * wave_speed;
	float scroll = flow_speed * (1.0 + rapids_boost * steep_v);
	// Rivers barely swell; lakes roll. Chop replaces swell as flow rises,
	// and dies with the flow fade at shores (the waterline stays buried).
	float amp = wave_height * (1.0 - 0.7 * fs);
	float camp = chop_height * fs * (0.4 + 0.6 * steep_v);
	float e = 2.0;
	float h = water_wave_h(noise_tex, world_pos.xz, t) * amp
		+ water_chop_h(noise_tex, world_pos.xz, fdir, scroll, TIME) * camp;
	float hx = water_wave_h(noise_tex, world_pos.xz + vec2(e, 0.0), t) * amp
		+ water_chop_h(noise_tex, world_pos.xz + vec2(e, 0.0), fdir, scroll, TIME) * camp;
	float hz = water_wave_h(noise_tex, world_pos.xz + vec2(0.0, e), t) * amp
		+ water_chop_h(noise_tex, world_pos.xz + vec2(0.0, e), fdir, scroll, TIME) * camp;
	VERTEX.y += h;
	world_pos.y += h;
	still_normal = normalize(vec3((h - hx) / e, 1.0, (h - hz) / e));
}
```

Fragment scroll block: same dual-phase dithered mechanism, but sampling in a flow-aligned basis stretched along-flow (streaky fast water), scrolled at `scroll`; the detail perturbation is ADDED to the (chop-bearing) vertex normal instead of replacing it:

```glsl
	float fs = clamp(length(flow_v.xz), 0.0, 1.0);
	vec2 fdir = fs > 0.001 ? normalize(flow_v.xz) : vec2(1.0, 0.0);
	float scroll = flow_speed * (1.0 + rapids_boost * steep_v);
	vec2 fuv = vec2(dot(world_pos.xz, fdir), dot(world_pos.xz, vec2(-fdir.y, fdir.x)));
	// Along-flow stretch as flow rises: ripples elongate into streaks.
	vec2 scale = mix(vec2(0.09), vec2(0.045, 0.13), fs);
	float ph = fract(TIME * 0.5 + texture(noise_tex, world_pos.xz * 0.017).r);
	float n1 = texture(noise_tex, fuv * scale - vec2(scroll * ph * scale.x, 0.0)).r;
	float n2 = texture(noise_tex, fuv * scale - vec2(scroll * (ph - 0.5) * scale.x, 0.0)).r;
	float stream = mix(n1, n2, abs(ph * 2.0 - 1.0));
	vec3 n = still_normal;
	n.xz += (stream - 0.5) * 0.35 * fdir * fs;
	n = normalize(n);
```

(Apparent calm-reach scroll returns to the pre-regression 1.5 m/s; steep reaches hit ~2.5×.)

- [ ] **Step 3: Compile check** — run the surface-builder test file (it loads the material, shader parse errors surface in output):
`/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_water_surface_builder.gd -gexit` — no `SHADER ERROR` lines.

- [ ] **Step 4: Commit** `fix(water): normal-speed ripples; speed+chop live where rivers are steep`

### Task 3: Shader — clear water (refraction, depth tint, fresnel)

**Files:**
- Modify: `terrain/water/water_unified.gdshader`

- [ ] **Step 1: Replace the milky body with refraction.** New uniforms (replace `depth_fade`; keep foam ones):

```glsl
uniform vec3 color_deep : source_color = vec3(0.10, 0.38, 0.36);
uniform vec3 color_shallow : source_color = vec3(0.45, 0.74, 0.64);
uniform float clarity_depth : hint_range(0.5, 12.0) = 3.5;
uniform float refraction_strength : hint_range(0.0, 0.2) = 0.05;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
```

Fragment body (after the normal/ripple block computes `n` and `NORMAL`):

```glsl
	float depth = water_depth_world(depth_texture, SCREEN_UV, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, world_pos.y);
	float depth_t = 1.0 - exp(-depth / clarity_depth);
	// Refraction: offset the screen sample by the view-space normal, fading
	// in over the first metre (shores don't smear). If the offset lands on
	// geometry ABOVE the surface (a bank, the boat), fall back to straight —
	// dry things must never bleed into the water body.
	vec2 roff = NORMAL.xy * refraction_strength * clamp(depth, 0.0, 1.0);
	vec2 suv = SCREEN_UV + roff;
	if (water_depth_world(depth_texture, suv, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, world_pos.y) <= 0.0) {
		suv = SCREEN_UV;
	}
	vec3 scene = texture(screen_texture, suv).rgb;
	vec3 body = mix(scene * mix(vec3(1.0), color_shallow, 0.45), color_deep, depth_t);
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0), 5.0);
	body = mix(body, color_deep, fres * 0.6);
	float foam = water_foam_mask(noise_tex, world_pos.xz, t, depth, foam_width);
	foam += steep_v * smoothstep(0.45, 0.75, stream) * 0.8 * fs;
	foam = clamp(foam, 0.0, 0.9);
	ALBEDO = mix(body, foam_color, foam);
	ALPHA = 1.0;   // clarity comes from refraction; ALPHA write keeps the transparent pass
	ROUGHNESS = mix(roughness, 0.5, foam);
	SPECULAR = mix(0.7, 1.0, fres);
```

`roughness` default drops to 0.03. `depth_draw_always` and the ripple-sim block stay untouched.

- [ ] **Step 2: Compile check** (same command as Task 2 Step 3).

- [ ] **Step 3: Commit** `feat(water): clear water — screen refraction, depth tint, fresnel (reference look)`

### Task 4: WaterPlan — sources ascend to mountain tops

**Files:**
- Modify: `scripts/terrain/water/WaterPlan.gd`
- Test: `tests/test_water_plan.gd`

- [ ] **Step 1: Write the failing tests.** Replace `test_sources_sit_on_hillsides` with:

```gdscript
func test_sources_sit_at_local_peaks() -> void:
	# Sources gradient-ascend to a summit: near-zero local gradient, a
	# prominent ring (real hill/mountain, not plateau), and no ring sample
	# meaningfully higher than the source itself.
	var plan: WaterPlan = _plan()
	var checked: int = 0
	for sc in _sources_in(plan, 6):
		checked += 1
		var p: Vector2 = plan.source_pos(sc)
		assert_true(plan.grad(p).length() < WaterPlan.SOURCE_PEAK_EPS,
			"source %s gradient ~0 (summit)" % sc)
		assert_true(plan._ring_prominence(p) >= WaterPlan.PROMINENCE_MIN,
			"source %s ring is prominent (not plateau)" % sc)
		for i in 8:
			var q: Vector2 = p + Vector2.from_angle(TAU * float(i) / 8.0) * 24.0
			assert_true(plan.smooth_h(q) <= plan.smooth_h(p) + 0.75,
				"source %s is a local top (ring sample %d not above it)" % [sc, i])
	assert_true(checked > 0, "window contains sources to check")

func test_source_pos_is_cached_and_pure() -> void:
	var a: WaterPlan = _plan()
	var b: WaterPlan = _plan()
	for sc in [Vector2i(2, 3), Vector2i(-4, 1), Vector2i(5, -5)]:
		assert_eq(a.source_pos(sc), b.source_pos(sc), "ascent is a pure function")
		assert_eq(a.source_pos(sc), a.source_pos(sc), "cache returns the same point")
```

- [ ] **Step 2: Run, expect FAIL** (`SOURCE_PEAK_EPS` undefined):
`/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_water_plan.gd -gexit`

- [ ] **Step 3: Implement in WaterPlan.gd.** Constants (replace `SOURCE_MIN_SLOPE`):

```gdscript
# Sources ASCEND to the local summit: rivers rise from mountain/hill tops
# (owner request), with the spring pool at the peak. A cell fires only when
# the climb converges on a prominent top — plateaus never qualify.
const ASCEND_STEP := 12.0
const ASCEND_MAX_STEPS := 40          # ≤ 480 m of climb from the jitter point
const SOURCE_PEAK_EPS := 0.02         # |grad| at an accepted summit
const PROMINENCE_R := 48.0            # ring radius for the prominence test
const PROMINENCE_MIN := 0.03          # mean ring |grad| — real hills only
```

`REACH` grows by the ascent bound (and the comment's `= 4` becomes `= 5`):

```gdscript
const REACH := MAX_STEPS * TRACE_STEP + ASCEND_MAX_STEPS * ASCEND_STEP \
	+ POND_R_MAX * (1.0 + PondStamp.WOBBLE) + FEATHER
const REACH_SUPERS := int(ceil(REACH / SUPER))   # = 5
```

New members + rewritten source functions:

```gdscript
var _source_pos_cache: Dictionary = {}   # Vector2i -> Vector2 (ascended)

## Deterministic hill-climb on the smooth field: fixed step uphill, halving
## on overshoot, until the gradient flattens (summit) or the budget runs out.
func _ascend(start: Vector2) -> Vector2:
	var p: Vector2 = start
	var step: float = ASCEND_STEP
	var h: float = smooth_h(p)
	for i in ASCEND_MAX_STEPS:
		var g: Vector2 = grad(p)
		if g.length() < SOURCE_PEAK_EPS * 0.5:
			break
		var q: Vector2 = p + g.normalized() * step
		var hq: float = smooth_h(q)
		if hq <= h:
			step *= 0.5
			if step < 1.0:
				break
			continue
		p = q
		h = hq
	return p

## Mean gradient magnitude on a ring around p — summit prominence: real
## mountain/hill tops have steep flanks; plateaus read ~0 and never fire.
func _ring_prominence(p: Vector2) -> float:
	var acc: float = 0.0
	for i in 8:
		acc += grad(p + Vector2.from_angle(TAU * float(i) / 8.0) * PROMINENCE_R).length()
	return acc / 8.0

## Source point for a super-cell: the jittered candidate ascended to its
## local summit. Pure function of (seed, cell); cached per instance.
func source_pos(sc: Vector2i) -> Vector2:
	if _source_pos_cache.has(sc):
		return _source_pos_cache[sc]
	var jx: float = Helper._hash01(_hash_cell(sc, 101))
	var jz: float = Helper._hash01(_hash_cell(sc, 102))
	var p: Vector2 = _ascend(Vector2((float(sc.x) + jx) * SUPER, (float(sc.y) + jz) * SUPER))
	_source_pos_cache[sc] = p
	return p

## Zero or one river source per super-cell: the ascended candidate must be a
## genuine summit (converged, prominent ring) on high smooth ground, outside
## the spawn ring, and win a density roll.
func has_source(sc: Vector2i) -> bool:
	var p: Vector2 = source_pos(sc)
	if p.length() < SPAWN_WATER_RADIUS:
		return false
	if smooth01(p) < SOURCE_MIN01:
		return false
	if grad(p).length() >= SOURCE_PEAK_EPS:
		return false   # never converged — huge flank, another cell owns this summit
	if _ring_prominence(p) < PROMINENCE_MIN:
		return false   # plateau top, not a mountain/hill
	return Helper._hash01(_hash_cell(sc, 103)) < SOURCE_PROB
```

Update the class-header comment ("river sources on a coarse super-grid, ascended to mountain-top summits, traced downhill…").

- [ ] **Step 4: Run test_water_plan.gd — all PASS.** Also compare source density: count sources in the 13×13 window before/after (git stash trick or read the old count from the test log); tune `SOURCE_MIN01` (0.55→0.6) or `PROMINENCE_MIN` only if density collapsed to 0 or exploded (>3× prior).

- [ ] **Step 5: Run neighbours** `test_water_surface_builder.gd` + `test_heightfield_water_carve.gd` (if present) — PASS.

- [ ] **Step 6: Commit** `feat(water): river sources ascend to mountain-top spring pools`

### Task 5: In-game verification & look tuning

- [ ] **Step 1:** Full targeted suite: `test_water_plan.gd`, `test_water_surface_builder.gd`, `test_cliff_dressing.gd` isolated — PASS (known baseline failure: `test_heightfield_interior_corners.gd`, ignore).
- [ ] **Step 2:** Launch the worktree project via the godot MCP; screenshot a calm river reach, a steep rapids reach, a lake, and a shoreline; check against the reference: ripples at pre-regression speed, visible travelling chop on rivers, clear tinted body, crisp reflections, no shore smearing, no water poking through banks.
- [ ] **Step 3:** Find a river source in-game (F4 teleporter or seed scan) and confirm the spring pool sits on a mountain/hill top.
- [ ] **Step 4:** Tune uniforms (`chop_height`, `clarity_depth`, palette, `rapids_boost`) from the screenshots; recommit as `tune(water): …` if changed.
- [ ] **Step 5:** Final commit + summary for the owner.
