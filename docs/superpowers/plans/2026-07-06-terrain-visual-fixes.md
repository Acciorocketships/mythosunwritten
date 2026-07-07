# Terrain / Water / Biome Visual Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the eight owner-reported visual issues (cliff lip mis-tiling at short↔tall junctions, lip/skirt/ground colour seams, floating water planes, streaky water texture, missing waterfalls, ugly/disappearing glow orbs + 2d-square particles, too-small biomes, fog everywhere) with failing-tests-first, then verify each fix visually in-game at seed 2697992464 via new F4 review teleports.

**Architecture:** All terrain/water computation is pure `RefCounted` (headless-testable); fixes land in `CliffDressing.corner_map`/`_ghost_mode` (piece selection), one shared tint pipeline (`BiomeRegistry.blended_ground_tint` applied to sheet+aprons+skirt+dressing instances), `WaterSurfaceBuilder.compute_field` Pass-1 anchoring (channel membership instead of raw depth), a rewritten `water_unified.gdshader` fragment (swells, no streak foam), a new `WaterfallBuilder` emitting ribbon curtains at profile drops, and `BiomeChunkFx` (one soft-glow billboard recipe family + correct emission/visibility AABBs).

**Tech Stack:** Godot 4.5, typed GDScript, GUT (headless), godot-mcp for run/screenshot iteration.

---

## Repro context (read first)

- Seed **2697992464 is already pinned** (`SEED_OVERRIDE` on `FieldTerrain` node, [scenes/world.tscn](scenes/world.tscn) line 56). Terrain is a pure function of (seed, cell) — every reported spot reproduces deterministically.
- Cell convention: cells are CENTERED at multiples of 24 (`cell = round(world/24)` per axis, implemented by `TerrainSurfaceField._cell_of`). Storeys are 4 m. The F3 overlay 3×3 grid prints rows N→S (dz −1,0,+1), cols W→E (dx −1,0,+1).
- Reported spots (world → cell → issue):

| # | world pos | cell | issue |
|---|-----------|------|-------|
| 1 | (87.1, 16.0, −1094.4) | (4,−46), storeys `0 1 2 / 2 [4] 5 / 3 6 6` | lip junction wrong: missing corner cap where run meets taller wall; spurious inner corner where lip should extend. Sits on river "WATER 0" steepest reach → carved-water branches involved |
| 2 | (912.7, 12.0, −825.7) | (38,−34), twilight_marsh 1.00 | lip↔ground and apron↔ground colour seams |
| 3 | (−79.5, 12.0, −997.7) | (−3,−42), highland | floating water planes mid-air + streaky texture (on "WATER 1" steepest reach) |
| 4 | (−17.7, 20.0, −1041.5) | (−1,−43) | floating pond/river sheet ~3 m above a storey-5 terrace; wants channel bounding + waterfalls |
| 5 | (690.3, 4.0, −981.4) | (29,−41), deep_forest | glow particles: hard-outlined yellow circles (fireflies), tiny 2d squares (motes), disappear when player approaches |

- **Run tests** (full): `/Applications/Godot.app/Contents/MacOS/Godot -d --path /Users/ryko/story -s res://addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json`
  Single file: append `-gselect=test_cliff_dressing.gd` (works for any test file name).
- **Run game:** `/Applications/Godot.app/Contents/MacOS/Godot --path /Users/ryko/story` (or godot-mcp `run_project`), F4 cycles review teleports, F3 overlay.
- After renaming/moving any `class_name` script: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryko/story --import`.
- New `class_name` files: Godot generates `*.uid` next to them; `.gitignore` already ignores `*.uid`.

## File structure (what changes where)

- Modify: `review_teleports.json` — add 5 review spots (Task 1).
- Modify: `scripts/core/Helper.gd` — biome scale constants (Task 2).
- Modify: `scripts/terrain/biome/BiomeRegistry.gd` — fog-free meadow/highland (Task 2).
- Modify: `scripts/terrain/biome/BiomeChunkFx.gd` — soft-glow sprite pipeline, AABB/emission fix (Task 3).
- Modify: `scripts/terrain/field/CliffDressing.gd` — `shared_material()` vertex-colour, tinted `build()`/`_multimesh()` (Task 4); `_ghost_mode()` carved-branch fix (Task 5).
- Modify: `scripts/terrain/field/TerrainChunkMesher.gd` — tint aprons + skirt, pass seed to dressing (Task 4).
- Modify: `scripts/terrain/water/WaterSurfaceBuilder.gd` — Pass-1 channel anchoring (Task 6), waterfall ribbon emission (Task 8).
- Modify: `terrain/water/water_unified.gdshader` — remove streak system, boost swells (Task 7).
- Create: `terrain/water/waterfall.gdshader` — ribbon curtain shader (Task 8).
- Tests: `tests/test_biomes.gd`, `tests/test_biome_registry.gd`, `tests/test_biome_chunk_fx.gd`, `tests/test_cliff_dressing.gd`, `tests/test_water_surface_builder.gd`, new `tests/test_terrain_tinting.gd`.

---

### Task 1: Review teleports for every reported spot

**Files:**
- Modify: `review_teleports.json`

- [ ] **Step 1: Append the five REVIEW entries** to the JSON array (keep the existing WATER/FIX entries; add before the closing `]`):

```json
 {
  "name": "REVIEW 1: lip junction into taller cliff (corner cap + no spurious inner)",
  "pos": [87.1, 18.0, -1094.4],
  "look": [100.0, -1090.0]
 },
 {
  "name": "REVIEW 2: marsh colour seams - lip/apron/ground must match",
  "pos": [912.7, 14.0, -825.7],
  "look": [900.0, -812.0]
 },
 {
  "name": "REVIEW 3: floating water + streak texture (steep reach)",
  "pos": [-79.5, 14.0, -997.7],
  "look": [-95.0, -985.0]
 },
 {
  "name": "REVIEW 4: floating pond sheet over terrace / waterfall site",
  "pos": [-17.7, 22.0, -1041.5],
  "look": [-30.0, -1052.0]
 },
 {
  "name": "REVIEW 5: glow orbs soft + persistent, no 2d squares (deep forest)",
  "pos": [690.3, 6.0, -981.4],
  "look": [676.0, -975.0]
 }
```

(y is +2 over the reported player y so the character never spawns intersecting ground; `look` faces each annotated defect — adjust after first visual pass if the camera faces the wrong way.)

- [ ] **Step 2: Validate the JSON parses**

Run: `python3 -c "import json;json.load(open('/Users/ryko/story/review_teleports.json'));print('ok')"`
Expected: `ok`

- [ ] **Step 3: Commit**

```bash
git add review_teleports.json && git commit -m "tools(review): F4 teleports for the five reported visual-bug spots"
```

---

### Task 2: Bigger biomes + fog-free meadow/highland

**Files:**
- Modify: `scripts/core/Helper.gd:103-104,121-123`
- Modify: `scripts/terrain/biome/BiomeRegistry.gd:84,118`
- Test: `tests/test_biomes.gd`, `tests/test_biome_registry.gd`

- [ ] **Step 1: Write the failing tests.** In `tests/test_biome_registry.gd` add:

```gdscript
func test_meadow_and_highland_are_fog_free() -> void:
	assert_eq(BiomeRegistry.profile(&"meadow").fog_density, 0.0, "meadow must have no fog")
	assert_eq(BiomeRegistry.profile(&"highland").fog_density, 0.0, "highland must have no fog")
	assert_gt(BiomeRegistry.profile(&"twilight_marsh").fog_density, 0.0, "marsh keeps its fog")
	assert_gt(BiomeRegistry.profile(&"deep_forest").fog_density, 0.0, "forest keeps its fog")
```

In `tests/test_biomes.gd` add (biome persistence: dominant biome must survive a 100 m run far more often than today — with 190 m noise it flips constantly):

```gdscript
func test_biomes_persist_over_a_running_stretch() -> void:
	# Walk 25 straight 100m hops; the dominant biome should change on well under
	# half of them once biome noise wavelengths are ~2.5x longer.
	var seed := 2697992464
	var changes := 0
	var prev: StringName = Helper.biome_at(Vector3.ZERO, seed)
	for i in range(1, 26):
		var b := Helper.biome_at(Vector3(float(i) * 100.0, 0.0, 0.0), seed)
		if b != prev:
			changes += 1
		prev = b
	assert_lt(changes, 8, "biome flips every ~100m — biomes too small (%d changes)" % changes)
```

- [ ] **Step 2: Run to verify failure**

Run: `/Applications/Godot.app/Contents/MacOS/Godot -d --path /Users/ryko/story -s res://addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json -gselect=test_biome_registry.gd` (and same for `test_biomes.gd`)
Expected: both new tests FAIL (fog 0.0003 ≠ 0.0; changes ≥ 8).

- [ ] **Step 3: Scale the biome noise 2.5×** in `scripts/core/Helper.gd` (values only; comments stay):

```gdscript
const BIOME_FOREST_SCALE: float = 480.0
const BIOME_ROCKY_SCALE: float = 380.0
...
const BIOME_MOISTURE_SCALE: float = 575.0
const BIOME_BLOSSOM_SCALE: float = 650.0
const BIOME_MARSH_SCALE: float = 750.0
```

- [ ] **Step 4: Zero the clear-biome fog** in `BiomeRegistry.gd`: `_meadow()` → `p.fog_density = 0.0`, `_highland()` → `p.fog_density = 0.0`. (Their `fog_color` stays — it still colours the blend when mixed with foggy neighbours.)

- [ ] **Step 5: Run the two files again + the full suite** — the new tests pass. If `test_biomes.gd`'s existing pocket-census test fails because pockets are now sparser, widen its sampling extent by the same 2.5× factor (pockets are rarer but bigger by design) — do NOT loosen a determinism assertion.

- [ ] **Step 6: Commit** — `git commit -m "tune(biomes): 2.5x biome wavelengths; meadow+highland fog-free"`

---

### Task 3: One soft-glow particle look; orbs never vanish

**Files:**
- Modify: `scripts/terrain/biome/BiomeChunkFx.gd`
- Test: `tests/test_biome_chunk_fx.gd`

**Root causes:** (a) glow particles are textureless quads (hard-edged squares/circles) or hard-silhouette spheres; (b) `visibility_aabb` starts at the node origin (chunk min-corner) while the world-space emission box is CENTERED on that corner — 3/4 of the particles live outside the AABB, so frustum culling kills the system when the in-AABB quadrant leaves view (the "disappear when close" bug); (c) emission y-band (−12..+12 around y=0) ignores terrain height.

- [ ] **Step 1: Failing tests** in `tests/test_biome_chunk_fx.gd`:

```gdscript
func test_glow_recipes_are_soft_billboards() -> void:
	for recipe in [&"orbs", &"fireflies", &"motes"]:
		var e := BiomeChunkFx._emitter(recipe, 0.5, 0.0, 24.0)
		var mesh: QuadMesh = e.draw_pass_1 as QuadMesh
		assert_not_null(mesh, "%s must be a billboard quad" % recipe)
		var mat: StandardMaterial3D = mesh.material
		assert_not_null(mat.albedo_texture, "%s needs the radial soft-glow texture (no hard outline)" % recipe)
		assert_eq(mat.blend_mode, BaseMaterial3D.BLEND_MODE_ADD, "%s must be additive (soft edges)" % recipe)
		assert_true(mat.emission_enabled, "%s must bloom" % recipe)

func test_emitter_aabb_contains_emission_box() -> void:
	var e := BiomeChunkFx._emitter(&"orbs", 0.5, 4.0, 28.0)
	var m: ParticleProcessMaterial = e.process_material
	var lo := m.emission_shape_offset - m.emission_box_extents
	var hi := m.emission_shape_offset + m.emission_box_extents
	assert_true(e.visibility_aabb.has_point(lo) and e.visibility_aabb.has_point(hi),
		"visibility AABB %s must contain emission box %s..%s (culling bug)" % [e.visibility_aabb, lo, hi])
	assert_true(e.local_coords, "local coords: AABB and emission must share the node's space")

func test_emission_band_follows_surface_heights() -> void:
	var e := BiomeChunkFx._emitter(&"orbs", 0.5, 8.0, 20.0)
	var m: ParticleProcessMaterial = e.process_material
	assert_between(m.emission_shape_offset.y, 8.0, 20.0, "emission band must sit in the surface y range")
```

- [ ] **Step 2: Run** `-gselect=test_biome_chunk_fx.gd` — new tests FAIL (signature mismatch / sphere mesh / AABB).

- [ ] **Step 3: Implement in `BiomeChunkFx.gd`.**
  1. Add a shared radial soft-glow texture and switch every glow recipe to it:

```gdscript
static var _glow_tex: GradientTexture2D = null

# Radial white→transparent falloff: the ONE soft-glow sprite every ambient
# particle uses — no hard silhouette at any size, bloom supplies the halo.
static func glow_texture() -> GradientTexture2D:
	if _glow_tex != null:
		return _glow_tex
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 64
	t.height = 64
	_glow_tex = t
	return _glow_tex
```

  2. Rewrite RECIPES: `orbs` become big soft-glow billboards (drop the sphere), `fireflies`/`motes` become small ones (same look, different size/energy/tint), `petals` keep alpha-blend but get the radial texture too (soft pink puffs, not squares):

```gdscript
const RECIPES := {
	&"fireflies": {
		"size": 0.35, "albedo": Color(1.0, 0.85, 0.45, 0.9),
		"emission": Color(1.0, 0.8, 0.4), "emission_energy": 2.5,
		"turbulence": Vector2(0.05, 0.15),
	},
	# Slowly drifting glowing balls of light — soft radial sprites; bloom + the
	# additive falloff hide any silhouette (owner: "much more glowy, no hard outline").
	&"orbs": {
		"size": 1.6, "albedo": Color(1.0, 0.75, 0.35, 1.0),
		"emission": Color("ffb347"), "emission_energy": 5.0,
		"amount_per_density": 24.0, "amount_max": 24,
		"lifetime": 22.0,
		"turbulence": Vector2(0.01, 0.04),
		"scale": Vector2(0.6, 1.5),
		"lights": true, "light_energy": 1.6, "light_range": 14.0,
	},
	&"petals": {
		"size": 0.35, "albedo": Color(0.95, 0.72, 0.85, 0.9), "soft_alpha": true,
		"gravity": Vector3(0.4, -0.6, 0.2), "velocity": Vector2(0.2, 0.8),
	},
	&"motes": {
		"size": 0.2, "albedo": Color(1.0, 0.95, 0.8, 0.6),
		"emission": Color(1.0, 0.95, 0.8), "emission_energy": 1.5,
		"turbulence": Vector2(0.02, 0.06),
	},
}
```

  3. `_emitter(recipe, density, surf_lo := 0.0, surf_hi := 12.0)` — every particle is now a billboard with the glow texture; center emission + AABB on the chunk and band on the surface range:

```gdscript
static func _emitter(recipe: StringName, density: float, surf_lo := 0.0, surf_hi := 12.0) -> GPUParticles3D:
	var r: Dictionary = RECIPES.get(recipe, {})
	if r.is_empty():
		push_warning("BiomeChunkFx: unknown particle recipe '%s' (add it to RECIPES)" % recipe)
		return null
	var e := GPUParticles3D.new()
	e.name = String(recipe)
	e.amount = int(clampf(density * r.get("amount_per_density", 48.0),
			r.get("amount_min", 4.0), r.get("amount_max", 96.0)))
	e.lifetime = r.get("lifetime", 8.0)
	e.local_coords = true
	var band_lo := surf_lo + 0.5
	var band_hi := surf_hi + 10.0
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(CHUNK * 0.5, (band_hi - band_lo) * 0.5, CHUNK * 0.5)
	m.emission_shape_offset = Vector3(CHUNK * 0.5, (band_lo + band_hi) * 0.5, CHUNK * 0.5)
	e.visibility_aabb = AABB(Vector3(0, band_lo - 8.0, 0), Vector3(CHUNK, band_hi - band_lo + 24.0, CHUNK))
	... # gravity/velocity/turbulence/scale exactly as today
	var mat := StandardMaterial3D.new()
	var size: float = r.get("size", 0.25)
	mat.albedo_color = r.get("albedo", Color.WHITE)
	mat.albedo_texture = glow_texture()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if not r.get("soft_alpha", false):
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.no_depth_test = false
	if r.has("emission"):
		mat.emission_enabled = true
		mat.emission = r["emission"]
		mat.emission_energy_multiplier = r.get("emission_energy", 2.0)
	var qm := QuadMesh.new()
	qm.size = Vector2(size, size)
	qm.material = mat
	e.process_material = m
	e.draw_pass_1 = qm
	return e
```

  4. `build(profile, light_points, surf_lo := 0.0, surf_hi := 12.0)` threads the band through to `_emitter`. In `FieldTerrainStreamer` pass the chunk's surface min/max (it already holds the region for the FX light points — compute `region.surface_height` min/max over the chunk's 8×8 cells there, alongside `_biome_fx_data`).

- [ ] **Step 4: Run** `-gselect=test_biome_chunk_fx.gd` then the full suite. Fix any existing orb-sphere assertions in that file to the new billboard reality (that's this refactor's point — update them deliberately).

- [ ] **Step 5: Commit** — `git commit -m "fix(biomes): one soft-glow sprite for all ambient particles; culling-safe emitter AABBs"`

---

### Task 4: One tint source for ground, aprons, skirt, and dressing pieces

**Files:**
- Modify: `scripts/terrain/field/CliffDressing.gd` (shared_material, build, _multimesh)
- Modify: `scripts/terrain/field/TerrainChunkMesher.gd` (aprons, skirt, dressing call)
- Create: `tests/test_terrain_tinting.gd`

**Root cause:** the walkable sheet multiplies the shared KayKit palette by the per-vertex **biome ground tint** (`BiomeRegistry.blended_ground_tint`), but aprons, the rock skirt, and every dressing piece (grass lips included) render the palette RAW. In twilight_marsh (tint 0.42,0.58,0.55) the untinted lip/apron grass glows bright green against the dark ground — the reported seams. Fix = every terrain surface multiplies by the SAME tint field: change the grass colour once, everything follows.

- [ ] **Step 1: Failing test** — create `tests/test_terrain_tinting.gd`:

```gdscript
extends GutTest
# Every terrain surface must pull albedo from THE shared material and modulate it
# by the SAME biome ground tint — lips/aprons/skirt may never drift from the sheet.

const SEED := 2697992464

func test_shared_material_reads_vertex_colour() -> void:
	var mat := CliffDressing.shared_material() as StandardMaterial3D
	assert_not_null(mat)
	assert_true(mat.vertex_color_use_as_albedo,
		"shared material must modulate by COLOR so instance/vertex tints apply")

func test_dressing_instances_carry_biome_tint() -> void:
	# A marsh-area chunk: instance colours must equal the blended ground tint at
	# each instance origin (not white). Cell (38,-34) is twilight_marsh 1.00.
	var region := _region_around(38, -34)
	var dressing := CliffDressing.build(region, 38 - 4, -34 - 4, 8, SEED)
	var any := false
	for child in dressing.get_children():
		var mm: MultiMesh = (child as MultiMeshInstance3D).multimesh
		assert_true(mm.use_colors, "%s must use per-instance colours" % child.name)
		for i in mm.instance_count:
			var t := mm.get_instance_transform(i)
			var want := BiomeRegistry.blended_ground_tint(
				Helper.biome_weights5(t.origin, SEED))
			var got := mm.get_instance_color(i)
			assert_almost_eq(got.r, want.r, 0.02, "instance tint tracks the biome field")
			any = true
	assert_true(any, "the marsh chunk should have at least one dressing piece")

func _region_around(cx: int, cz: int):
	var plan := HeightfieldPlan.new(SEED, 22.0, 8)
	plan.set_water_plan(WaterPlan.new(SEED, 22.0, 8))
	return plan.compute_region(cx, cz, 8)
```

(Mirror the exact plan/water constructor arity from `tests/test_water_plan.gd` / `tests/test_cliff_dressing.gd` if they differ — the suite is the source of truth. NOTE: headless MultiMesh does NOT read back `get_instance_transform`; if that bites, have `build()` also return/expose the computed tint array via a `compute_tints()` static that the test asserts directly — keep the pure-data pattern.)

- [ ] **Step 2: Run** `-gselect=test_terrain_tinting.gd` — FAILS (`vertex_color_use_as_albedo` false; `build()` has no seed param).

- [ ] **Step 3: Implement.**
  1. `CliffDressing.shared_material()` — after the existing de-sheen block add:

```gdscript
		mat.vertex_color_use_as_albedo = true   # sheet/apron vertex tints + per-instance piece tints
```

  2. `CliffDressing.build(region, lo_cx, lo_cz, cells, world_seed := 0)` — compute per-instance tints and pass them down; `_multimesh(piece, transforms, nm, tints)` sets `mm.use_colors = true` and `mm.set_instance_color(i, tints[i])` (tint = `BiomeRegistry.blended_ground_tint(Helper.biome_weights5(t.origin, world_seed))`, sampled once per transform in `build`, seed 0 → `Color(1,1,1)` white so headless/dressing-only tests keep working). Add a pure `static func compute_tints(transforms: Array, world_seed: int) -> Array[Color]` so tests can assert without MultiMesh readback.
  3. `TerrainChunkMesher.build_chunk` line 357: `CliffDressing.build(region, lo_cx, lo_cz, CELLS_PER_CHUNK, _water_seed)`.
  4. Aprons: `_emit_aprons`/`_apron_quad` gain a tint — sample once per cell in the apron loop (`BiomeRegistry.blended_ground_tint(Helper.biome_weights5(Vector3(cx*TILE,0,cz*TILE), _water_seed))`) and `st.set_color(tint)` before each `add_vertex` in `_apron_quad`. Aprons keep `_material` (the now-vertex-colour shared material).
  5. Skirt: same pattern in `_emit_wall`→`_skirt_quad` (tint sampled per wall cell, `st.set_color` per vertex). The rock texel × tint keeps rock/grass consistent per biome (marsh rock goes moody teal like its foliage rocks — intended; verify visually in Task 9).
  6. `_ground_tinted_mat()` — the duplicate becomes unnecessary (shared material already reads COLOR); return `_material` directly after `_ensure_skirt_style()` so the sheet, aprons, skirt and pieces share literally ONE `Material` instance.

- [ ] **Step 4: Run** `-gselect=test_terrain_tinting.gd` (PASS) then full suite (existing `test_cliff_dressing.gd` calls `build(region, lo, lo, n)` — default seed keeps arity compatible).

- [ ] **Step 5: Commit** — `git commit -m "fix(terrain): one tint source — biome ground tint modulates sheet, aprons, skirt and dressing pieces"`

---

### Task 5: Cliff lip pieces at short-cliff↔tall-cliff junctions

**Files:**
- Modify: `scripts/terrain/field/CliffDressing.gd` (`_ghost_mode`)
- Test: `tests/test_cliff_dressing.gd`

**Root cause hypothesis:** `_ghost_mode()` lines 134-147 — the CARVED branch returns **1 (full inner piece) unconditionally** for unequal-arm pockets over water, skipping the "does the taller wall CONTINUE past the corner?" test that the land branch (lines 148-158) applies. Where the taller arm's wall runs straight on (screenshot: "the cliff lip edge should be extended here but instead there is an inner corner"), a full inner lip notches the continuing edge. Conversely the run-end cap logic then sees `_inner_joined()` true → "abut" → the run's end module gets NO cap where the owner wants a corner tile. Both reported defects are the same wrong branch.

- [ ] **Step 1: Characterize the real spot first (throwaway harness).** Before asserting expectations, print what the algorithm currently does at the real cells:

```gdscript
# tests/harness/junction_probe.gd  (temporary, delete after the fix)
extends SceneTree
func _initialize():
	var plan := HeightfieldPlan.new(2697992464, 22.0, 8)
	plan.set_water_plan(WaterPlan.new(2697992464, 22.0, 8))
	var region = plan.compute_region(4, -46, 8)
	for cz in range(-48, -43):
		var row := ""
		for cx in range(2, 7):
			row += " %2d" % region.storey_at(cx, cz)
		print(row)
	for cell in [Vector2i(4, -46), Vector2i(3, -46), Vector2i(3, -45), Vector2i(4, -45)]:
		print(cell, " carved=", region.is_carved(cell.x, cell.y),
			" corners=", CliffDressing.corner_flags(region, cell.x, cell.y))
		for cdir in CliffDressing.CORNERS:
			var m := CliffDressing._ghost_mode(region, cell.x, cell.y, cdir)
			if m != 0:
				print("  ghost ", cdir, " mode=", m)
	quit()
```

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryko/story -s res://tests/harness/junction_probe.gd`
Confirm the printed 3×3 around (4,−46) matches the screenshot (`0 1 2 / 2 4 5 / 3 6 6`; adjust plan-constructor params to the streamer's exports if not — check `FieldTerrainStreamer` `HEIGHTFIELD_AMPLITUDE`/`HEIGHTFIELD_MAX_STOREYS` and `world.tscn` overrides). Note which cell emits the spurious ghost mode-1 and which junction lacks its cap.

- [ ] **Step 2: Failing regression tests** in `tests/test_cliff_dressing.gd`, following the file's existing synthetic-layout helpers (it already builds unequal-arm carved pockets — copy the closest existing fixture, e.g. `test_carved_pocket_with_unequal_arms_gets_full_corner`, and vary it):

```gdscript
func test_carved_pocket_where_taller_wall_continues_keeps_the_edge_straight() -> void:
	# Owner (seed 2697992464 cell 4,-46): "the cliff lip edge should be extended
	# here but instead there is an inner corner". Unequal higher arms over a
	# CARVED pocket, with the taller arm's wall CONTINUING straight across the
	# lower arm's line (the diagonal walls the same way): NO full inner piece —
	# seam walls at most, and the lower run keeps its straight modules.
	var region := _carved_unequal_arm_pocket_with_continuing_wall()   # build like the
	# existing carved fixtures: pocket at P, arm A one storey up, arm B two up,
	# diagonal D two up (walling across A's line), pocket cell carved.
	assert_eq(CliffDressing._ghost_mode(region, P.x, P.y, CDIR), 2,
		"continuing taller wall: seam walls only, no inner lip notching the edge")
	var pieces := CliffDressing.compute(region, P.x - 2, P.y - 2, 5)
	assert_eq(_lips_at(pieces["inner_lip"], _corner_pos(P, CDIR)).size(), 0,
		"no inner lip on the continuing edge")

func test_carved_run_end_at_taller_wall_gets_its_corner_cap() -> void:
	# Owner: "this should be a corner tile" — the lower run dies against the
	# taller cliff over carved water and must carry the turned ext_outer cap
	# one slot into the taller cell (with wall rows down to the pocket).
	var region := _carved_unequal_arm_pocket_with_continuing_wall()
	var flags := CliffDressing.corner_flags(region, RUN_CELL.x, RUN_CELL.y)
	assert_eq(flags.get(RUN_CORNER, ""), "ext_outer",
		"the run end into the taller wall carries the turned cap")
```

(Concrete storeys for the fixture — derived from the probe in Step 1; encode the REAL layout `0 1 2 / 2 4 5 / 3 6 6` with the river carve stamped via the same override helpers the existing carved tests use. Positions `P`, `CDIR`, `RUN_CELL`, `RUN_CORNER` come from the probe output.)

- [ ] **Step 3: Run** `-gselect=test_cliff_dressing.gd` — new tests FAIL (mode 1 emitted; abut instead of ext_outer).

- [ ] **Step 4: Fix `_ghost_mode` (root-cause, minimal special-casing).** Restructure so carved-ness only changes WHAT a junction emits (walls needed on carved banks where land runs get merge rows), never WHETHER the junction is a continuing wall:

```gdscript
	if sa != sb:
		var ct := ca if sa > sb else cb   # the taller arm
		var cl := cb if sa > sb else ca   # the lower arm
		var carved := region.has_method("is_carved") and region.is_carved(cx, cz)
		if carved and _diagonal_owns_pocket_corner(region, cx, cz, cdir):
			return 0
		if TerrainSurfaceField.is_exposed_edge(region, cx + cdir.x, cz + cdir.y, Vector2i(-ct.x, -ct.y)):
			# The taller wall CONTINUES past the corner across the lower arm's
			# side: never a full inner piece — it would notch the continuing
			# walkable edge (owner: "should just be an edge", land AND water).
			if TerrainSurfaceField.is_exposed_edge(region, cx + cdir.x, cz + cdir.y, Vector2i(-cl.x, -cl.y)):
				return 2
			# Land runs' ext_straight merge rows already round the seam; carved
			# banks have no merge rows — keep their seam walls.
			return 2 if carved else 0
		# True concave junction (taller wall does NOT continue): full piece.
		return 1
```

Then re-check `_inner_joined`/corner_map interplay: with the spurious mode-1 gone, the run-end junction at the taller wall takes the `ext_outer` branch (its cap + carved wall rows already exist at lines 456-484). No other emission change.

- [ ] **Step 5: Run** `-gselect=test_cliff_dressing.gd` — new tests PASS; fix any pre-existing carved-junction tests whose expectations the owner's two screenshots contradict (cite the screenshot in the updated test comment), leave all land-run tests untouched (they must pass unmodified).

- [ ] **Step 6: Delete `tests/harness/junction_probe.gd`, commit** — `git commit -m "fix(cliffs): carved junctions respect continuing walls — no spurious inner lip, run-end caps restored"`

---

### Task 6: No floating water sheets

**Files:**
- Modify: `scripts/terrain/water/WaterSurfaceBuilder.gd` (Pass 1)
- Test: `tests/test_water_surface_builder.gd`

**Root cause:** Pass 1's anchoring test (line 182) accepts `ground < level - FLOOD_MIN_DEPTH` — "deep enough = anchored". At cascade lips and beside steep reaches, a DRY terrace one-plus storey below an upstream sample's level is inside the sample's influence band (`widths + FEATHER + CHANNEL_MARGIN`) and *deeper mistakes pass more easily* — the sheet renders at the upstream level, hanging in air (screenshots 3 & 4). Depth alone is not evidence of water; channel membership is.

- [ ] **Step 1: Failing test** in `tests/test_water_surface_builder.gd`:

```gdscript
const OWNER_SEED := 2697992464

func test_no_uncarved_deep_cells_in_the_field() -> void:
	# Screenshot spots: chunks containing cells (-3,-42) and (-1,-43) grew
	# floating sheets. Invariant: a cell may carry water ABOVE its ground by
	# more than FLOOD_MIN_DEPTH only if the water plan actually carved it (bed
	# channel / pond bowl) — depth alone must never anchor a sheet.
	var water := WaterPlan.new(OWNER_SEED, 22.0, 8)
	for chunk in [Vector2i(-1, -6), Vector2i(0, -6)]:   # cover both spots' cells
		var field := WaterSurfaceBuilder.compute_field(water, chunk)
		for cell in field:
			var e: Dictionary = field[cell]
			if not e.wet:
				continue
			if e.level - e.ground > WaterSurfaceBuilder.FLOOD_MIN_DEPTH + 0.01:
				assert_gt(water.carve_at_cell(cell.x, cell.y), 0.05,
					"wet cell %s floats %.1fm over uncarved ground" % [cell, e.level - e.ground])
```

(Cell→chunk: chunk = floor(cell/8) → (−3,−42)→(−1,−6), (−1,−43)→(−1,−6); include (0,−6) for margin. Verify with the probe if unsure; keep the assert message rich — it's the repro record.)

- [ ] **Step 2: Run** `-gselect=test_water_surface_builder.gd` — FAILS at the screenshot cells.

- [ ] **Step 3: Fix Pass 1** — track channel membership, drop depth-anchoring:

```gdscript
				# ... inside the river loop, alongside best_j/best_d:
				var in_channel := false
				# after the level assignment:
				if best_j >= 0 and best_d <= infl_best:
					...
					if best_d <= river.widths[best_j]:
						in_channel = true
				# ...
				# ANCHORED water only: the cell is part of a carved bowl/channel, or
				# lies within the channel's own half-width (flat-valley reaches carve
				# ~0 where bed meets ground — still real water). DEPTH is not evidence:
				# a dry terrace below an upstream reach's level is not water (owner's
				# floating sheets at cascades).
				var anchored: bool = in_channel \
					or water.carve_at_cell(cell.x, cell.y) > 0.05
```

Pond cells stay anchored via carve (the stamp carves its whole footprint). Passes 2 (shelf flood) and 3 (rim) are untouched — they only extend from wet cells and already refuse drop-offs.

- [ ] **Step 4: Run** the water tests + full suite. Watch specifically for pond-shore "missing tile" regressions in existing tests; if a legit shore cell fails, widen anchoring by `pond.footprint_t(p) < 1.05` membership — NOT by restoring depth-anchoring.

- [ ] **Step 5: Commit** — `git commit -m "fix(water): anchor sheets to channel/carve membership — no more floating planes at cascades"`

---

### Task 7: Water look — moving swells, no white streaks

**Files:**
- Modify: `terrain/water/water_unified.gdshader`

Visual-only (shader): no unit test — Task 9's screenshot loop is the verification. The reference look (owner's earlier screenshot): clean teal water, soft moving swells, foam ONLY as a shore lap line.

- [ ] **Step 1: Remove the streak system** from `fragment()`: delete the `fuv/uvscale/ph/n1/n2/stream` block (lines 82-91), the `n.xz += (stream - 0.5) * ...` perturbation (line 95), and the rapids foam term `foam += steep_v * smoothstep(0.45, 0.75, stream) * 0.8 * ff;` (line 137). Keep refraction, depth tint, fresnel, shore `water_foam_mask` untouched (owner-approved "clear water" look).

- [ ] **Step 2: Make the swells carry the motion.** In `vertex()` the swell amplitude currently dies on rivers (`amp = wave_height * (1.0 - 0.7 * ff)`). Swells must stay visible and READ as travelling on flowing reaches:

```glsl
	// Swells everywhere — slightly deeper on flowing reaches (moving water
	// shows moving swells; owner reference). Chop stays the steep-reach extra.
	float amp = wave_height * (1.0 + 0.35 * ff);
	float camp = chop_height * ff * steep_v * 0.6;
```

and raise the default `wave_height` uniform `0.15 → 0.22`. In `fragment()` add a soft normal shimmer that advects DOWNSTREAM so flow stays legible without foam — one gentle isotropic sample, no flow-aligned stretching:

```glsl
	vec2 drift = fdir * TIME * (0.35 + 0.65 * scroll * 0.08) * ff;
	float rn = texture(noise_tex, world_pos.xz * 0.045 - drift).r;
	vec3 n = still_normal;
	n.xz += (rn - 0.5) * 0.22;
	n = normalize(n);
```

- [ ] **Step 3: Steep reaches keep some white** — but from the smooth shore-style mask, not streaks (only where genuinely waterfall-adjacent):

```glsl
	foam += smoothstep(0.75, 1.0, steep_v) * (0.25 + 0.2 * sin(TIME * 2.1 + rn * 6.0));
```

- [ ] **Step 4: Sanity-run the game** (godot-mcp `run_project` — shader compile errors surface in the log). Screenshot verification happens in Task 9 (REVIEW 3 spot).

- [ ] **Step 5: Commit** — `git commit -m "feat(water): moving swells carry the flow — streak/foam gate removed (owner reference look)"`

---

### Task 8: Waterfall ribbons at profile drops

**Files:**
- Modify: `scripts/terrain/water/WaterSurfaceBuilder.gd`
- Create: `terrain/water/waterfall.gdshader`
- Test: `tests/test_water_surface_builder.gd`

Where the monotone surface profile drops more than `BRIDGE_MAX` between neighbouring samples, the sheet deliberately splits (no bridging curtain) — that vertical gap is exactly where a waterfall belongs.

- [ ] **Step 1: Failing test:**

```gdscript
func test_steep_profile_drops_emit_waterfall_ribbons() -> void:
	# The REVIEW 3/4 cascades must produce at least one ribbon whose top/bottom
	# match the adjacent sheet levels.
	var water := WaterPlan.new(OWNER_SEED, 22.0, 8)
	var ribbons := WaterSurfaceBuilder.compute_ribbons(water, Vector2i(-1, -6))
	assert_gt(ribbons.size(), 0, "cascade chunk must carry waterfall ribbons")
	for r in ribbons:
		assert_gt(r.top - r.bottom, WaterSurfaceBuilder.BRIDGE_MAX,
			"a ribbon spans a real drop")

func test_ribbons_are_deterministic_and_chunk_owned() -> void:
	var water := WaterPlan.new(OWNER_SEED, 22.0, 8)
	var a := WaterSurfaceBuilder.compute_ribbons(water, Vector2i(-1, -6))
	var b := WaterSurfaceBuilder.compute_ribbons(water, Vector2i(-1, -6))
	assert_eq(a.size(), b.size(), "pure function of (plan, chunk)")
```

- [ ] **Step 2: Run** — FAILS (`compute_ribbons` doesn't exist).

- [ ] **Step 3: Implement `compute_ribbons` (pure data) + build integration:**

```gdscript
# A cascade ribbon: where the surface profile drops > BRIDGE_MAX between two
# neighbouring samples, hang a vertical curtain across the channel at the drop
# line. Data-only (headless-testable); build_chunk turns them into meshes.
# Owned by the chunk containing the drop's midpoint — deterministic, no doubles.
static func compute_ribbons(water: WaterPlan, chunk: Vector2i) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var centre_cx: int = chunk.x * CELLS_PER_CHUNK + CELLS_PER_CHUNK / 2
	var centre_cz: int = chunk.y * CELLS_PER_CHUNK + CELLS_PER_CHUNK / 2
	var bodies: Dictionary = water.bodies_near(
		Vector2i(centre_cx, centre_cz), CELLS_PER_CHUNK / 2 + 1 + FIELD_MARGIN)
	var lo := Vector2(float(chunk.x), float(chunk.y)) * CHUNK_WORLD
	var owner_rect := Rect2(lo, Vector2(CHUNK_WORLD, CHUNK_WORLD))
	for river in bodies.rivers:
		var prof := surface_profile(river)
		for i in river.points.size() - 1:
			var drop: float = prof[i] - prof[i + 1]
			if drop <= BRIDGE_MAX:
				continue
			var mid: Vector2 = (river.points[i] + river.points[i + 1]) * 0.5
			if not owner_rect.has_point(mid):
				continue
			var t: Vector2 = (river.points[i + 1] - river.points[i]).normalized()
			out.append({
				"mid": mid, "tangent": t, "half_width": river.widths[i],
				"top": prof[i], "bottom": prof[i + 1],
			})
	return out
```

In `build_chunk`, after the sheet, add a `MeshInstance3D` "Waterfalls" when `compute_ribbons` is non-empty: for each ribbon, a curtain of quads across the channel (`across = (-t.y, t.x)`, from `mid - across*half_width` to `mid + across*half_width`), from `top + 0.15` to `bottom - 0.6` (plunges just under the lower sheet), leaning downstream by `t * 1.8` at the bottom, UV.y 0→1 top→bottom, double-sided winding like `_skirt_quad`. Material: `waterfall_material()` (static, cached, mirrors `sheet_material()`).

  `terrain/water/waterfall.gdshader` (new file — falling-band look, matches the sheet palette):

```glsl
// Waterfall curtain: bands of foam falling fast, tinted with the shared water
// palette. UV.y runs top(0) -> bottom(1); world-x/z noise decorrelates columns.
shader_type spatial;
render_mode specular_schlick_ggx, cull_disabled, depth_draw_always;
uniform vec3 color_deep : source_color = vec3(0.13, 0.46, 0.44);
uniform vec3 foam_color : source_color = vec3(0.95, 0.98, 0.98);
uniform float fall_speed : hint_range(0.5, 8.0) = 2.6;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
varying vec3 world_pos;
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float col = texture(noise_tex, vec2(world_pos.x + world_pos.z, world_pos.y * 0.02) * 0.11).r;
	float fall = texture(noise_tex, vec2((world_pos.x + world_pos.z) * 0.07,
		UV.y * 0.6 - TIME * fall_speed * 0.25 + col)).r;
	float band = smoothstep(0.35, 0.75, fall);
	vec3 body = mix(color_deep, foam_color, 0.35 + 0.6 * band);
	ALBEDO = body;
	ALPHA = 0.82 + 0.15 * band;
	ROUGHNESS = 0.35;
}
```

Reuse the builder's `NoiseTexture2D` (extract the noise-texture creation from `_make_material()` into a shared `static func _noise_tex()`).

- [ ] **Step 4: Run** `-gselect=test_water_surface_builder.gd` + full suite; PASS.

- [ ] **Step 5: Commit** — `git commit -m "feat(water): waterfall ribbon curtains at cascade drops"`

---

### Task 9: Visual verification loop (godot-mcp)

No files — protocol. For each REVIEW spot: run, teleport, screenshot, judge against the owner's annotation, iterate on the owning task's code until solved.

- [ ] **Step 1: Launch** via godot-mcp `run_project` (project at /Users/ryko/story). Wait for the world to stream (~5 s).
- [ ] **Step 2: Teleport + frame.** Use `game_eval` to set the player's `global_position` to a REVIEW spot (same data as F4) and let the chunk stream (~3 s). Use `game_set_camera`/orbit only if the default framing hides the defect.
- [ ] **Step 3: Screenshot** via `game_screenshot`; read the image; compare against the corresponding user annotation:
  - REVIEW 1: the lip line extends cleanly to the taller wall; a turned cap sits at the junction; NO inner-corner notch mid-edge; no bare teal/skirt rectangle at the seam.
  - REVIEW 2: lip scallop tops, apron band, and ground read as ONE green (marsh-dark); zoom the seam lines.
  - REVIEW 3: no detached horizontal planes; river shows moving swells (take 2 shots ~2 s apart — the surface must differ), no white streak stripes.
  - REVIEW 4: terrace carries no hovering sheet; the drop carries a waterfall curtain connecting upper→lower water.
  - REVIEW 5: soft glow orbs (no hard circle edge, no squares); walk the player INTO the swarm (`game_eval` position nudges) — particles must stay visible from inside the chunk.
- [ ] **Step 4: Iterate.** Any failed check → fix in the owning task's files → `stop_project`, re-run, re-shoot. Tuning knobs live in the shaders' uniforms, RECIPES, and the constants named in each task. Repeat until all five spots pass. Save final screenshots to the scratchpad for the report.

---

### Task 10: Full suite, docs, wrap-up

- [ ] **Step 1: Full GUT suite** — zero failures.
- [ ] **Step 2: Update `AGENTS.md`** — its Water section still describes the retired single-plane; one paragraph on WaterPlan/WaterSurfaceBuilder + ribbons, and note the shared-tint invariant in the mesher section.
- [ ] **Step 3: Commit any stragglers; leave the tree clean** (do not commit `project.godot`'s empty autoload block or scratch screenshots).

## Self-review notes

- Spec coverage: orbs(T3) ✓ size/fog(T2) ✓ colour(T4) ✓ lip tiling(T5) ✓ floating water(T6) ✓ streaks(T7) ✓ waterfalls(T8) ✓ teleports(T1) ✓ failing-tests-first (T2-T6, T8) ✓ visual iteration (T9) ✓.
- Constructor arities (`HeightfieldPlan.new`, `WaterPlan.new`) and `region.is_carved` MUST be mirrored from the existing passing tests before writing new ones — noted inline in T4/T5/T6.
- T5's fix code is a hypothesis until Step 1's probe confirms which branch fires at the real cells; the tests encode the OWNER's expected behaviour either way.
