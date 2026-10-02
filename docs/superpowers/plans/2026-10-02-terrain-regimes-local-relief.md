# Terrain Regimes and Local Relief Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the province-averaged `LandformField` with a regime-driven structured height field (base + sparse set pieces + per-region relief primitives) so the terrain has tile-scale structure and regionally distinct character.

**Architecture:** Five new scene-free static modules under `scripts/terrain/heightfield/` compose a metre-valued field `TerrainField.height_m(p, seed, include_detail)`. `HeightfieldPlan.height01` delegates to it, so quantization, clamp, `TerrainTileField`, mesher, water and villages are unchanged consumers. Three harnesses (region map, structure survey, archetype gallery) drive visual iteration.

**Tech Stack:** Godot 4.5 typed GDScript, GUT tests, headless SceneTree harnesses.

**Spec:** `docs/superpowers/specs/2026-10-02-terrain-regimes-local-relief-design.md`

## Global Constraints

- Terrain stays a pure function of `(world_seed, position)`; every cache is bounded, mutex-guarded when static, and output-identical.
- No scene/render resources in field code (AGENTS.md purity boundary).
- `HeightfieldPlan.height01(pos, seed, include_detail)` keeps its signature and `[0, 1]` range; `include_detail=false` is what `WaterPlan.smooth01` traces and must exclude `relief`.
- Lattice unchanged: points 12 m apart, storey 4 m, `MAX_CLIFF_STEP` 3, amplitude `TerrainWorldTuning.HEIGHTFIELD_AMPLITUDE` = 128 m.
- Feature sizes in metres (`*_m` params, scaled by region `scale`), heights in storeys (`*_st`, ×4 m).
- Spawn falloff `smootherstep((r - 60) / 180)` still multiplies the whole field.
- Geography-pinned tests are re-pinned, never loosened.
- Godot binary: `/Applications/Godot.app/Contents/MacOS/Godot` (below: `$GODOT`). One test file: `$GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/<file>.gd -gexit`. After creating a new `class_name` script: `$GODOT --headless --path . --import`.
- Full suite only via `tests/tools/run_suite_isolated.sh OUT 2` (memory-gated).
- Stage specific files; never `git add -A` (the worktree has `addons`/`assets` symlinks).

## Deviations from the spec (decided while planning)

- Voronoi site jitter is ±30% (offsets in [0.2, 0.8] of a cell) with a 5×5 search so F1/F2 are exact; spec said ±40%/3×3.
- `base` is a smootherstep-bilinear interpolation of region base levels on a 320 m node grid (cheaper and exactly continuous) instead of a Gaussian-weighted site mean; same intent (km-scale, never a border wall).
- Gullies orient along the gradient of the region's own ridged term (ridge/massif only), not the smooth field: ridges are where the slope is, and the smooth field is too gentle to gate them.
- Set-piece lengths capped at 840 m so every footprint radius ≤ 480 m (5×5 Matérn neighbourhood guarantees no overlaps).
- Border escarpments are deferred to iteration (spec marked them optional).
- The archetype gallery captures oblique and top views; the F9 view is deferred (the overlay needs the stand-in streamer from `tile_gallery`).
- Archetype relief recipes live in a sixth module, `RegimeRelief.gd`, keeping the catalogue pure data.

## Review Focus

1. Discontinuities at region borders, base-node cells, Worley cells and set-piece edges: height must be continuous everywhere off deliberate steep risers. Pinned by the refinement continuity test in Task 6.
2. Query-order / threading dependence of the static caches: same values when evaluated forward, reversed, or from three threads. Pinned in Tasks 4 and 5.
3. Height clipping at 128 m (flat clipped mountain tops): the catalogue ranges must keep `height_m` below 128. Pinned in Task 6.
4. River sources disappearing (smooth field too flat): ≥ 30 sources per 81 districts. Pinned by the retained `test_september11_landforms` test in Task 6.
5. Spawn must stay flat and meadow-like. Pinned in Task 6.

---

### Task 1: ReliefPrimitives

**Files:**
- Create: `scripts/terrain/heightfield/ReliefPrimitives.gd`
- Test: `tests/test_relief_primitives.gd`

**Interfaces:**
- Produces (all `static`):
  - `vnoise01(p: Vector2, seed: int, wavelength_m: float) -> float` in [0, 1]
  - `vnoise(p: Vector2, seed: int, wavelength_m: float) -> float` in [-1, 1]
  - `warp(p: Vector2, seed: int, amplitude_m: float, wavelength_m: float) -> Vector2`
  - `hummock(p: Vector2, seed: int, wavelength_m: float, octaves: int) -> float` in [0, 1]
  - `ridged(p: Vector2, seed: int, wavelength_m: float, octaves: int, sharpness: float) -> float` in [0, 1]
  - `ridged_gradient(p: Vector2, seed: int, wavelength_m: float, sharpness: float) -> Vector2` (per metre)
  - `pass_mod(p: Vector2, seed: int, spacing_m: float, depth: float) -> float` in [1 - depth, 1]
  - `gully(p: Vector2, seed: int, spacing_m: float, downhill: Vector2) -> float` in [-1, 1]
  - `sites_bump(p: Vector2, seed: int, spacing_m: float, density: float, radius_m: float, edge: float) -> float` in [0, 1]
  - `worley(p: Vector2, seed: int, spacing_m: float) -> Vector3` = (F1 m, F2 m, nearest-cell hash in [0, 1])
  - `terrace(h: float, step: float, riser_frac: float) -> float`

- [ ] **Step 1: Write the failing test**

`tests/test_relief_primitives.gd`:

```gdscript
extends GutTest

const SEED := 2697992464

func _grid() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for z in range(-12, 13):
		for x in range(-12, 13):
			out.append(Vector2(x * 37.3 + 0.17, z * 41.9 - 0.31))
	return out

func test_noise_primitives_are_deterministic_and_bounded() -> void:
	for p in _grid():
		var h := ReliefPrimitives.hummock(p, SEED, 90.0, 3)
		assert_eq(h, ReliefPrimitives.hummock(p, SEED, 90.0, 3))
		assert_between(h, 0.0, 1.0)
		var r := ReliefPrimitives.ridged(p, SEED, 200.0, 4, 2.0)
		assert_between(r, 0.0, 1.0)
		assert_between(ReliefPrimitives.pass_mod(p, SEED, 300.0, 0.6), 0.4, 1.0)
		assert_between(ReliefPrimitives.gully(p, SEED, 40.0, Vector2(0.6, 0.8)), -1.0, 1.0)
		assert_between(ReliefPrimitives.sites_bump(p, SEED, 120.0, 0.5, 60.0, 0.3), 0.0, 1.0)

func test_wavelengths_scale_the_domain() -> void:
	for p in _grid():
		assert_almost_eq(ReliefPrimitives.hummock(p * 2.0, SEED, 180.0, 3),
			ReliefPrimitives.hummock(p, SEED, 90.0, 3), 1e-6)
		assert_almost_eq(ReliefPrimitives.ridged(p * 3.0, SEED, 600.0, 4, 2.0),
			ReliefPrimitives.ridged(p, SEED, 200.0, 4, 2.0), 1e-6)

func test_terrace_treads_land_on_step_multiples() -> void:
	var previous := -INF
	for i in 4000:
		var h := i * 0.013
		var t := ReliefPrimitives.terrace(h, 8.0, 0.15)
		var k := floorf(h / 8.0)
		assert_between(t, k * 8.0, (k + 1.0) * 8.0)
		if h / 8.0 - k < 0.85:
			assert_eq(t, k * 8.0, "tread is flat at a step multiple (h=%f)" % h)
		assert_gte(t, previous, "terrace is monotone")
		previous = t

func test_sites_bump_is_continuous() -> void:
	var prev := ReliefPrimitives.sites_bump(Vector2(-600, 13), SEED, 100.0, 0.6, 90.0, 0.2)
	for i in range(1, 4800):
		var v := ReliefPrimitives.sites_bump(Vector2(-600 + i * 0.25, 13), SEED, 100.0, 0.6, 90.0, 0.2)
		assert_lt(absf(v - prev), 0.03, "no jump at x=%f" % (-600 + i * 0.25))
		prev = v

func test_worley_distances_are_ordered_and_continuous() -> void:
	var prev := ReliefPrimitives.worley(Vector2(-400, 7), SEED, 80.0)
	for i in range(1, 3200):
		var w := ReliefPrimitives.worley(Vector2(-400 + i * 0.25, 7), SEED, 80.0)
		assert_lte(w.x, w.y)
		assert_lt(absf((w.y - w.x) - (prev.y - prev.x)), 0.51, "F2-F1 continuous")
		prev = w
```

- [ ] **Step 2: Run test to verify it fails**

Run: `$GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_relief_primitives.gd -gexit`
Expected: FAIL / script error, `ReliefPrimitives` not declared.

- [ ] **Step 3: Write the implementation**

`scripts/terrain/heightfield/ReliefPrimitives.gd`:

```gdscript
class_name ReliefPrimitives
extends RefCounted

## Structural noise building blocks for regime relief (spec 2026-10-02 §4).
## Every function is static and a pure function of position, seed and explicit
## parameters in metres. Value noise comes from Helper._value_noise01; octaves
## are rotated about the origin so lattice axes never line up.

const OCTAVE_TURN := 0.61


static func vnoise01(p: Vector2, seed: int, wavelength_m: float) -> float:
	return Helper._value_noise01(Vector3(p.x, 0.0, p.y), seed, wavelength_m)


static func vnoise(p: Vector2, seed: int, wavelength_m: float) -> float:
	return vnoise01(p, seed, wavelength_m) * 2.0 - 1.0


static func warp(p: Vector2, seed: int, amplitude_m: float, wavelength_m: float) -> Vector2:
	if amplitude_m <= 0.0:
		return p
	return p + Vector2(vnoise(p, seed + 11, wavelength_m), vnoise(p, seed + 13, wavelength_m)) * amplitude_m


## Billowy |noise| sum in [0, 1]: gentle rolling ground.
static func hummock(p: Vector2, seed: int, wavelength_m: float, octaves: int) -> float:
	var total := 0.0
	var norm := 0.0
	var amp := 1.0
	var lam := wavelength_m
	for o in octaves:
		total += absf(vnoise(p.rotated(OCTAVE_TURN * o), seed + 17 * o, lam)) * amp
		norm += amp
		amp *= 0.5
		lam *= 0.5
	return total / norm


## Ridged multifractal in [0, 1]: crests (1) form connected networks. Each octave
## is weighted by the previous one so detail concentrates on the ridges.
static func ridged(p: Vector2, seed: int, wavelength_m: float, octaves: int, sharpness: float) -> float:
	var total := 0.0
	var norm := 0.0
	var amp := 1.0
	var weight := 1.0
	var lam := wavelength_m
	for o in octaves:
		var r := pow(1.0 - absf(vnoise(p.rotated(OCTAVE_TURN * o), seed + 17 * o, lam)), sharpness)
		r *= weight
		weight = clampf(r * 1.6, 0.0, 1.0)
		total += r * amp
		norm += amp
		amp *= 0.5
		lam *= 0.5
	return total / norm


## Central-difference gradient (per metre) of a two-octave ridged field.
static func ridged_gradient(p: Vector2, seed: int, wavelength_m: float, sharpness: float) -> Vector2:
	var e := wavelength_m * 0.02
	var dx := ridged(p + Vector2(e, 0.0), seed, wavelength_m, 2, sharpness) \
		- ridged(p - Vector2(e, 0.0), seed, wavelength_m, 2, sharpness)
	var dz := ridged(p + Vector2(0.0, e), seed, wavelength_m, 2, sharpness) \
		- ridged(p - Vector2(0.0, e), seed, wavelength_m, 2, sharpness)
	return Vector2(dx, dz) / (2.0 * e)


## Multiplier that lowers crests into passes at roughly spacing_m intervals.
static func pass_mod(p: Vector2, seed: int, spacing_m: float, depth: float) -> float:
	return 1.0 - depth * smoothstep(0.55, 0.8, vnoise01(p, seed, spacing_m))


## Grooves and spurs running downhill: a Gabor-like sum of jittered kernels,
## each a cosine across the downhill direction, Gaussian-windowed.
static func gully(p: Vector2, seed: int, spacing_m: float, downhill: Vector2) -> float:
	if downhill.length_squared() < 1e-12:
		return 0.0
	var across := Vector2(-downhill.y, downhill.x).normalized()
	var q := p / spacing_m
	var c := Vector2i(floori(q.x), floori(q.y))
	var total := 0.0
	var weights := 0.0
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var cell := c + Vector2i(dx, dz)
			var centre := Vector2(cell) + Vector2(
				0.25 + 0.5 * Helper._cell_hash01(seed, cell.x, cell.y),
				0.25 + 0.5 * Helper._cell_hash01(seed + 1, cell.x, cell.y))
			var d := q - centre
			var w := exp(-d.length_squared() / (2.0 * 0.45 * 0.45))
			var phase := Helper._cell_hash01(seed + 2, cell.x, cell.y) * TAU
			total += w * cos(TAU * d.dot(across) + phase)
			weights += w
	return clampf(total / maxf(weights, 1e-6), -1.0, 1.0)


## Max over the 3x3 neighbouring cells of a radial bump around each admitted
## site (hash < density). Sites sit in [0.2, 0.8] of their cell, so any site
## outside the 3x3 block is at least 1.2 cells away: radius_m <= spacing_m keeps
## the field exactly continuous. edge in [0, 1) flattens the bump's top/floor.
static func sites_bump(p: Vector2, seed: int, spacing_m: float, density: float, radius_m: float, edge: float) -> float:
	assert(radius_m <= spacing_m, "ReliefPrimitives.sites_bump: radius must not exceed spacing")
	var q := p / spacing_m
	var c := Vector2i(floori(q.x), floori(q.y))
	var best := 0.0
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var cell := c + Vector2i(dx, dz)
			if Helper._cell_hash01(seed + 3, cell.x, cell.y) >= density:
				continue
			var site := (Vector2(cell) + Vector2(
				0.2 + 0.6 * Helper._cell_hash01(seed, cell.x, cell.y),
				0.2 + 0.6 * Helper._cell_hash01(seed + 1, cell.x, cell.y))) * spacing_m
			var size := 0.6 + 0.4 * Helper._cell_hash01(seed + 2, cell.x, cell.y)
			var r := radius_m * size
			var d := p.distance_to(site)
			if d < r:
				best = maxf(best, (1.0 - smoothstep(edge, 1.0, d / r)) * size)
	return best


## Worley F1/F2 (metres) over a 5x5 block (exact for sites in [0.25, 0.75]),
## plus the nearest cell's hash for per-cell variation.
static func worley(p: Vector2, seed: int, spacing_m: float) -> Vector3:
	var q := p / spacing_m
	var c := Vector2i(floori(q.x), floori(q.y))
	var f1 := INF
	var f2 := INF
	var id := 0.0
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			var cell := c + Vector2i(dx, dz)
			var site := Vector2(cell) + Vector2(
				0.25 + 0.5 * Helper._cell_hash01(seed, cell.x, cell.y),
				0.25 + 0.5 * Helper._cell_hash01(seed + 1, cell.x, cell.y))
			var d := q.distance_to(site)
			if d < f1:
				f2 = f1
				f1 = d
				id = Helper._cell_hash01(seed + 2, cell.x, cell.y)
			elif d < f2:
				f2 = d
	return Vector3(f1 * spacing_m, f2 * spacing_m, id)


## Treads on multiples of step; each riser occupies the top riser_frac of its
## step interval. Monotone, continuous, exact on treads.
static func terrace(h: float, step: float, riser_frac: float) -> float:
	var k := floorf(h / step)
	var t := smoothstep(1.0 - riser_frac, 1.0, h / step - k)
	return (k + t) * step
```

- [ ] **Step 4: Register the class and run the test**

Run: `$GODOT --headless --path . --import` then the Step 2 command.
Expected: all 5 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/heightfield/ReliefPrimitives.gd tests/test_relief_primitives.gd
git commit -m "Terrain: ReliefPrimitives noise building blocks"
```

---

### Task 2: TerrainRegimeCatalog

**Files:**
- Create: `scripts/terrain/heightfield/TerrainRegimeCatalog.gd`
- Test: `tests/test_terrain_regime_catalog.gd`

**Interfaces:**
- Produces:
  - `const STOREY := 4.0`
  - `const ARCHETYPES: Array[StringName]` (8 ids, below)
  - `const PARAMS: Dictionary` archetype → `{name: [min, max] or [min, max, group]}`
  - `const AFFINITY: Dictionary` biome → `{archetype: weight}`; `const AFFINITY_FLOOR := 0.03`
  - `const SETPIECE_DENSITY: Dictionary` archetype → `{kind: probability}`
  - `const SETPIECE_PARAMS: Dictionary` kind → ranges
  - `static func draw(seed: int, key: Vector2i, salt: int, spec: Dictionary, scale: float) -> Dictionary`
  - `static func choose(weights: Dictionary, u: float) -> StringName`

- [ ] **Step 1: Write the failing test**

`tests/test_terrain_regime_catalog.gd`:

```gdscript
extends GutTest

func test_catalogue_is_complete_and_consistent() -> void:
	for a: StringName in TerrainRegimeCatalog.ARCHETYPES:
		assert_true(TerrainRegimeCatalog.PARAMS.has(a), "params for %s" % a)
		assert_true(TerrainRegimeCatalog.SETPIECE_DENSITY.has(a), "densities for %s" % a)
		assert_true(TerrainRegimeCatalog.PARAMS[a].has("base_level_st"), "base level for %s" % a)
		for name: String in TerrainRegimeCatalog.PARAMS[a]:
			var r: Array = TerrainRegimeCatalog.PARAMS[a][name]
			assert_lte(float(r[0]), float(r[1]), "%s.%s range" % [a, name])
		for kind: StringName in TerrainRegimeCatalog.SETPIECE_DENSITY[a]:
			assert_true(TerrainRegimeCatalog.SETPIECE_PARAMS.has(kind), "setpiece %s" % kind)
	for biome: StringName in Helper.BIOME_NAMES:
		assert_true(TerrainRegimeCatalog.AFFINITY.has(biome), "affinity for %s" % biome)
		for a: StringName in TerrainRegimeCatalog.AFFINITY[biome]:
			assert_has(TerrainRegimeCatalog.ARCHETYPES, a)

func test_draw_respects_ranges_and_scales_only_lengths() -> void:
	var spec := {"wave_m": [10.0, 20.0], "rise_st": [1.0, 2.0], "frac": [0.2, 0.4]}
	for i in 200:
		var d := TerrainRegimeCatalog.draw(7, Vector2i(i, -i), 5, spec, 1.5)
		assert_between(d.wave_m, 15.0, 30.0)
		assert_between(d.rise_st, 1.0, 2.0)
		assert_between(d.frac, 0.2, 0.4)
	assert_eq(TerrainRegimeCatalog.draw(7, Vector2i(3, 4), 5, spec, 1.0),
		TerrainRegimeCatalog.draw(7, Vector2i(3, 4), 5, spec, 1.0))

func test_grouped_parameters_share_a_draw() -> void:
	var spec := {"a": [0.0, 1.0, "g"], "b": [0.0, 1.0, "g"]}
	for i in 50:
		var d := TerrainRegimeCatalog.draw(11, Vector2i(i, 2 * i), 3, spec, 1.0)
		assert_eq(d.a, d.b)

func test_choose_follows_biome_affinity() -> void:
	var counts := {}
	var n := 4000
	for i in n:
		var a := TerrainRegimeCatalog.choose({&"twilight_marsh": 1.0}, (i + 0.5) / n)
		counts[a] = counts.get(a, 0) + 1
	var table: Dictionary = TerrainRegimeCatalog.AFFINITY[&"twilight_marsh"]
	var total := 0.0
	for a: StringName in TerrainRegimeCatalog.ARCHETYPES:
		total += maxf(TerrainRegimeCatalog.AFFINITY_FLOOR, float(table.get(a, 0.0)))
	var expected := maxf(TerrainRegimeCatalog.AFFINITY_FLOOR, float(table[&"low_flats"])) / total
	assert_almost_eq(float(counts[&"low_flats"]) / n, expected, 0.01)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `$GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_terrain_regime_catalog.gd -gexit`
Expected: FAIL, `TerrainRegimeCatalog` not declared.

- [ ] **Step 3: Write the implementation**

`scripts/terrain/heightfield/TerrainRegimeCatalog.gd`:

```gdscript
class_name TerrainRegimeCatalog
extends RefCounted

## Curated terrain archetypes (spec 2026-10-02 §5). Each parameter is a
## [min, max] range drawn once per region; an optional third element names a
## shared draw group. Suffixes: *_m metres (multiplied by the region's scale),
## *_st storeys (x STOREY m), anything else unitless. Values are a starting
## point for visual review, not a contract.

const STOREY := 4.0

const ARCHETYPES: Array[StringName] = [&"rolling_downs", &"ridge_and_pass",
	&"escarpment_country", &"terraced_valleys", &"karst_hollows", &"tableland",
	&"highland_massif", &"low_flats"]

const PARAMS := {
	&"rolling_downs": {
		"base_level_st": [1.0, 6.0], "relief_st": [1.0, 2.0], "hummock_wl_m": [60.0, 140.0],
		"knoll_spacing_m": [150.0, 300.0], "knoll_radius_m": [30.0, 60.0],
		"knoll_density": [0.3, 0.6], "knoll_st": [1.0, 2.0]},
	&"ridge_and_pass": {
		"base_level_st": [4.0, 12.0], "ridge_spacing_m": [60.0, 200.0], "ridge_st": [2.0, 5.0],
		"pass_spacing_m": [150.0, 400.0], "pass_depth": [0.5, 0.8],
		"gully_spacing_m": [30.0, 60.0], "gully_st": [0.5, 1.0]},
	&"escarpment_country": {
		"base_level_st": [2.0, 8.0], "relief_st": [0.5, 1.0], "hummock_wl_m": [80.0, 160.0],
		"tread_rise_st": [2.0, 3.0], "tread_depth_m": [40.0, 150.0], "riser_frac": [0.08, 0.18],
		"steps": [2.0, 4.0]},
	&"terraced_valleys": {
		"base_level_st": [1.0, 6.0], "valley_half_width_m": [40.0, 120.0], "treads": [3.0, 6.0],
		"tread_depth_m": [24.0, 60.0], "riser_frac": [0.2, 0.4], "relief_st": [0.25, 0.75],
		"hummock_wl_m": [60.0, 120.0]},
	&"karst_hollows": {
		"base_level_st": [2.0, 8.0], "relief_st": [0.5, 1.0], "hummock_wl_m": [80.0, 160.0],
		"sink_spacing_m": [60.0, 120.0], "sink_radius_m": [10.0, 30.0], "sink_density": [0.3, 0.6],
		"sink_st": [1.0, 3.0], "hollow_spacing_m": [150.0, 300.0], "hollow_radius_m": [40.0, 100.0],
		"hollow_density": [0.3, 0.6], "hollow_st": [1.0, 2.0], "knob_spacing_m": [100.0, 200.0],
		"knob_radius_m": [15.0, 30.0], "knob_st": [1.0, 2.0]},
	&"tableland": {
		"base_level_st": [4.0, 12.0], "cell_m": [80.0, 250.0], "channel_m": [15.0, 40.0],
		"rim_st": [2.0, 4.0]},
	&"highland_massif": {
		"base_level_st": [8.0, 18.0], "ridge_spacing_m": [120.0, 300.0], "ridge_st": [4.0, 8.0],
		"pass_spacing_m": [250.0, 600.0], "pass_depth": [0.3, 0.6],
		"gully_spacing_m": [40.0, 80.0], "gully_st": [0.75, 1.5]},
	&"low_flats": {
		"base_level_st": [0.0, 2.0], "relief_st": [0.0, 1.0], "hummock_wl_m": [80.0, 200.0],
		"mound_spacing_m": [120.0, 260.0], "mound_radius_m": [30.0, 80.0], "mound_st": [0.5, 1.0]},
}

## Visual biome -> archetype weights; every archetype also gets AFFINITY_FLOOR.
const AFFINITY_FLOOR := 0.03
const AFFINITY := {
	&"meadow": {&"rolling_downs": 0.45, &"terraced_valleys": 0.25, &"escarpment_country": 0.20},
	&"deep_forest": {&"rolling_downs": 0.35, &"karst_hollows": 0.30, &"ridge_and_pass": 0.25},
	&"highland": {&"highland_massif": 0.40, &"ridge_and_pass": 0.25, &"tableland": 0.20,
		&"escarpment_country": 0.15},
	&"blossom_grove": {&"terraced_valleys": 0.45, &"rolling_downs": 0.35},
	&"twilight_marsh": {&"low_flats": 0.65, &"karst_hollows": 0.25},
	&"amber_heath": {&"tableland": 0.45, &"escarpment_country": 0.35},
	&"jade_wetlands": {&"low_flats": 0.50, &"terraced_valleys": 0.30},
}

## Probability that a 512 m set-piece cell in this archetype hosts each kind.
const SETPIECE_DENSITY := {
	&"rolling_downs": {&"escarpment": 0.05},
	&"ridge_and_pass": {&"big_ridge": 0.25},
	&"escarpment_country": {&"escarpment": 0.35, &"cleft": 0.10},
	&"terraced_valleys": {&"amphitheatre": 0.20},
	&"karst_hollows": {&"cleft": 0.15},
	&"tableland": {&"mesa": 0.30, &"cleft": 0.10},
	&"highland_massif": {&"hanging_valley": 0.20, &"big_ridge": 0.20},
	&"low_flats": {},
}

const SETPIECE_PARAMS := {
	&"escarpment": {"length_m": [400.0, 840.0], "rise_st": [2.0, 4.0], "face_m": [16.0, 32.0],
		"back_m": [120.0, 200.0]},
	&"amphitheatre": {"radius_m": [100.0, 240.0], "wall_st": [2.0, 4.0]},
	&"mesa": {"radius_m": [60.0, 200.0], "height_st": [3.0, 6.0], "face_m": [12.0, 24.0]},
	&"big_ridge": {"length_m": [500.0, 840.0], "height_st": [3.0, 5.0],
		"half_width_m": [40.0, 90.0], "pass_frac": [0.5, 0.75]},
	&"cleft": {"length_m": [200.0, 600.0], "slot_m": [24.0, 40.0], "shoulder_st": [2.0, 4.0],
		"shoulder_m": [60.0, 120.0]},
	&"hanging_valley": {"length_m": [300.0, 800.0], "trunk_half_m": [40.0, 80.0],
		"trunk_st": [3.0, 5.0], "trib_half_m": [16.0, 30.0], "lip_st": [2.0, 3.0]},
}


## Draw every parameter of spec for one key. Each parameter (or group) uses its
## own hash stream; *_m values are multiplied by scale.
static func draw(seed: int, key: Vector2i, salt: int, spec: Dictionary, scale: float) -> Dictionary:
	var out := {}
	for name: String in spec:
		var r: Array = spec[name]
		var group: String = String(r[2]) if r.size() > 2 else name
		var u := Helper._cell_hash01(seed + salt + (group.hash() & 0xFFFF), key.x, key.y)
		var v := lerpf(float(r[0]), float(r[1]), u)
		if name.ends_with("_m"):
			v *= scale
		out[name] = v
	return out


## Pick an archetype for biome weights with a uniform draw u in [0, 1).
static func choose(weights: Dictionary, u: float) -> StringName:
	var scores: Array[float] = []
	var total := 0.0
	for a: StringName in ARCHETYPES:
		var s := 0.0
		for biome: StringName in weights:
			var table: Dictionary = AFFINITY.get(biome, {})
			s += float(weights[biome]) * maxf(AFFINITY_FLOOR, float(table.get(a, 0.0)))
		scores.append(s)
		total += s
	var t := u * total
	for i in ARCHETYPES.size():
		t -= scores[i]
		if t < 0.0:
			return ARCHETYPES[i]
	return ARCHETYPES[ARCHETYPES.size() - 1]
```

- [ ] **Step 4: Register and run the test**

Run: `$GODOT --headless --path . --import` then the Step 2 command.
Expected: 4 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/heightfield/TerrainRegimeCatalog.gd tests/test_terrain_regime_catalog.gd
git commit -m "Terrain: TerrainRegimeCatalog archetypes, affinities and set-piece ranges"
```

---

### Task 3: TerrainRegimeField (regions, base, borders)

**Files:**
- Create: `scripts/terrain/heightfield/TerrainRegimeField.gd`
- Test: `tests/test_terrain_regime_field.gd`

**Interfaces:**
- Consumes: `TerrainRegimeCatalog.draw/choose/PARAMS/ARCHETYPES`, `ReliefPrimitives.warp`, `Helper.biome_weights5`, `Helper._cell_hash01`, `SlopeProfile.smootherstep`.
- Produces:
  - Region record (read-only Dictionary): `{archetype: StringName, params: Dictionary, base_m: float, scale: float, rot: float, salt: int, site: Vector2, cell: Vector2i}`
  - `const REGION_CELL := 640.0`, `const BAND_M := 120.0`, `const BASE_NODE := 320.0`
  - `static func site_of(seed: int, cell: Vector2i) -> Vector2`
  - `static func region(seed: int, cell: Vector2i) -> Dictionary`
  - `static func region_at(seed: int, p: Vector2) -> Dictionary` (nearest site, unwarped)
  - `static func sample(seed: int, p: Vector2) -> Array` = `[region_a: Dictionary, region_b: Dictionary, w_a: float]`, w_a in [0.5, 1]
  - `static func base_m(seed: int, p: Vector2) -> float`
  - `static func set_force_archetype(a: StringName) -> void` (`&""` clears) and `static func clear_caches() -> void`

- [ ] **Step 1: Write the failing test**

`tests/test_terrain_regime_field.gd`:

```gdscript
extends GutTest

const SEED := 2697992464

func after_each() -> void:
	TerrainRegimeField.set_force_archetype(&"")

func _points() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in 300:
		out.append(Vector2(fposmod(i * 911.7, 6000.0) - 3000.0, fposmod(i * 577.3, 6000.0) - 3000.0))
	return out

func _snapshot(points: Array[Vector2]) -> Array:
	var out := []
	for p in points:
		var s := TerrainRegimeField.sample(SEED, p)
		out.append([s[0].archetype, s[1].archetype, s[2], TerrainRegimeField.base_m(SEED, p)])
	return out

func test_sampling_is_query_order_independent() -> void:
	var points := _points()
	var forward := _snapshot(points)
	TerrainRegimeField.clear_caches()
	var reversed_points := points.duplicate()
	reversed_points.reverse()
	var backward := _snapshot(reversed_points)
	backward.reverse()
	assert_eq(forward, backward)

func test_threads_agree_with_sequential_sampling() -> void:
	var points := _points()
	var expected := _snapshot(points)
	TerrainRegimeField.clear_caches()
	var workers: Array[Thread] = []
	for i in 3:
		var t := Thread.new()
		assert_eq(t.start(_snapshot.bind(points)), OK)
		workers.append(t)
	for t in workers:
		assert_eq(t.wait_to_finish(), expected)

func test_one_regime_outside_the_border_band() -> void:
	var inside := 0
	for p in _points():
		var s := TerrainRegimeField.sample(SEED, p)
		assert_between(float(s[2]), 0.5, 1.0)
		if s[2] < 1.0:
			inside += 1
	assert_gt(inside, 0, "some points fall in a border band")
	assert_lt(inside, 150, "most points have exactly one regime")

func test_region_parameters_respect_catalogue_ranges() -> void:
	for x in range(-4, 5):
		for z in range(-4, 5):
			var r := TerrainRegimeField.region(SEED, Vector2i(x, z))
			assert_has(TerrainRegimeCatalog.ARCHETYPES, r.archetype)
			assert_between(r.scale, 0.6, 1.7)
			var spec: Dictionary = TerrainRegimeCatalog.PARAMS[r.archetype]
			for name: String in spec:
				var lo := float(spec[name][0]) * (r.scale if name.ends_with("_m") else 1.0)
				var hi := float(spec[name][1]) * (r.scale if name.ends_with("_m") else 1.0)
				assert_between(float(r.params[name]), lo - 1e-6, hi + 1e-6, name)
			assert_almost_eq(r.base_m, float(r.params.base_level_st) * 4.0, 1e-6)

func test_base_is_continuous_across_node_lines() -> void:
	for i in range(-6, 7):
		var x := i * TerrainRegimeField.BASE_NODE
		assert_almost_eq(TerrainRegimeField.base_m(SEED, Vector2(x - 0.01, 77.0)),
			TerrainRegimeField.base_m(SEED, Vector2(x + 0.01, 77.0)), 0.01)

func test_force_archetype_overrides_every_region() -> void:
	TerrainRegimeField.set_force_archetype(&"tableland")
	for p in _points():
		assert_eq(TerrainRegimeField.region_at(SEED, p).archetype, &"tableland")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `$GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_terrain_regime_field.gd -gexit`
Expected: FAIL, `TerrainRegimeField` not declared.

- [ ] **Step 3: Write the implementation**

`scripts/terrain/heightfield/TerrainRegimeField.gd`:

```gdscript
class_name TerrainRegimeField
extends RefCounted

## Terrain regime layer (spec 2026-10-02 §3). Regions are jittered Voronoi cells
## (one site per REGION_CELL, offsets in [0.2, 0.8], 5x5 search: exact F1/F2).
## Each region holds one archetype from TerrainRegimeCatalog chosen with the
## visual-biome bias at its site, and sampled parameters. Relief cross-fades
## only inside a BAND_M border band (warped so borders never look straight);
## base elevation is a smootherstep-bilinear field on a BASE_NODE grid so
## regions with different base levels never meet at a wall.

const REGION_CELL := 640.0
const BAND_M := 120.0
const BORDER_WARP_M := 60.0
const BORDER_WARP_WL := 240.0
const BASE_NODE := 320.0
const MERGE_CHANCE := 0.2
const CACHE_LIMIT := 4096

static var _force: StringName = &""
static var _regions: Dictionary = {}     # seed -> {Vector2i: Dictionary}
static var _region_keys: Array = []
static var _region_cursor := 0
static var _nodes: Dictionary = {}       # seed -> {Vector2i: float}
static var _node_keys: Array = []
static var _node_cursor := 0
static var _mutex := Mutex.new()


static func set_force_archetype(a: StringName) -> void:
	_force = a
	clear_caches()
	LandformSetpieces.clear_caches()


static func clear_caches() -> void:
	_mutex.lock()
	_regions.clear()
	_region_keys.clear()
	_region_cursor = 0
	_nodes.clear()
	_node_keys.clear()
	_node_cursor = 0
	_mutex.unlock()


static func site_of(seed: int, cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(
		0.2 + 0.6 * Helper._cell_hash01(seed + 1401, cell.x, cell.y),
		0.2 + 0.6 * Helper._cell_hash01(seed + 1402, cell.x, cell.y))) * REGION_CELL


## The region's own draw, before territory merging.
static func _own_region(seed: int, cell: Vector2i) -> Dictionary:
	var site := site_of(seed, cell)
	var archetype := _force
	if archetype == &"":
		var weights := Helper.biome_weights5(Vector3(site.x, 0.0, site.y), seed)
		archetype = TerrainRegimeCatalog.choose(weights, Helper._cell_hash01(seed + 1403, cell.x, cell.y))
	var scale := lerpf(0.6, 1.7, Helper._cell_hash01(seed + 1404, cell.x, cell.y))
	var params := TerrainRegimeCatalog.draw(seed, cell, 1410, TerrainRegimeCatalog.PARAMS[archetype], scale)
	return {
		"archetype": archetype, "params": params, "scale": scale, "site": site, "cell": cell,
		"base_m": float(params.base_level_st) * TerrainRegimeCatalog.STOREY,
		"rot": Helper._cell_hash01(seed + 1405, cell.x, cell.y) * TAU,
		"salt": int(Helper._cell_hash01(seed + 1406, cell.x, cell.y) * 1000000.0),
	}


## Region record for a Voronoi cell. With MERGE_CHANCE a cell adopts the own
## draw of its west or north neighbour (never recursively), so some territories
## span two cells.
static func region(seed: int, cell: Vector2i) -> Dictionary:
	_mutex.lock()
	var per_seed: Dictionary = _regions.get(seed, {})
	var cached = per_seed.get(cell)
	_mutex.unlock()
	if cached != null:
		return cached
	var donor := cell
	if Helper._cell_hash01(seed + 1407, cell.x, cell.y) < MERGE_CHANCE:
		donor += Vector2i(-1, 0) if Helper._cell_hash01(seed + 1408, cell.x, cell.y) < 0.5 else Vector2i(0, -1)
	var value := _own_region(seed, donor)
	_mutex.lock()
	per_seed = _regions.get(seed, {})
	cached = per_seed.get(cell)
	if cached == null:
		if _region_keys.size() == CACHE_LIMIT:
			var old: Array = _region_keys[_region_cursor]
			(_regions.get(old[0], {}) as Dictionary).erase(old[1])
			_region_keys[_region_cursor] = [seed, cell]
			_region_cursor = (_region_cursor + 1) % CACHE_LIMIT
		else:
			_region_keys.append([seed, cell])
		per_seed[cell] = value
		_regions[seed] = per_seed
		cached = value
	_mutex.unlock()
	return cached


## Nearest and second-nearest sites around p: [cell1, d1, cell2, d2].
static func _nearest_two(seed: int, p: Vector2) -> Array:
	var c := Vector2i(floori(p.x / REGION_CELL), floori(p.y / REGION_CELL))
	var d1 := INF
	var d2 := INF
	var c1 := c
	var c2 := c
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			var cell := c + Vector2i(dx, dz)
			var d := p.distance_to(site_of(seed, cell))
			if d < d1:
				d2 = d1
				c2 = c1
				d1 = d
				c1 = cell
			elif d < d2:
				d2 = d
				c2 = cell
	return [c1, d1, c2, d2]


static func region_at(seed: int, p: Vector2) -> Dictionary:
	return region(seed, _nearest_two(seed, p)[0])


## [nearest region, second region, weight of nearest] at p. Outside the border
## band the weight is exactly 1.
static func sample(seed: int, p: Vector2) -> Array:
	var q := ReliefPrimitives.warp(p, seed + 1409, BORDER_WARP_M, BORDER_WARP_WL)
	var n := _nearest_two(seed, q)
	var e := float(n[3]) - float(n[1])
	var w := 1.0 if e >= BAND_M else 0.5 + 0.5 * SlopeProfile.smootherstep(e / BAND_M)
	return [region(seed, n[0]), region(seed, n[2]), w]


static func _node_base(seed: int, node: Vector2i) -> float:
	_mutex.lock()
	var per_seed: Dictionary = _nodes.get(seed, {})
	var cached = per_seed.get(node)
	_mutex.unlock()
	if cached != null:
		return cached
	var value: float = region_at(seed, Vector2(node) * BASE_NODE).base_m
	_mutex.lock()
	per_seed = _nodes.get(seed, {})
	if not per_seed.has(node):
		if _node_keys.size() == CACHE_LIMIT * 4:
			var old: Array = _node_keys[_node_cursor]
			(_nodes.get(old[0], {}) as Dictionary).erase(old[1])
			_node_keys[_node_cursor] = [seed, node]
			_node_cursor = (_node_cursor + 1) % (CACHE_LIMIT * 4)
		else:
			_node_keys.append([seed, node])
		per_seed[node] = value
		_nodes[seed] = per_seed
	_mutex.unlock()
	return value


## Continental base elevation (m): smootherstep-bilinear over BASE_NODE nodes,
## each node holding the base level of the region containing it.
static func base_m(seed: int, p: Vector2) -> float:
	var q := p / BASE_NODE
	var c := Vector2i(floori(q.x), floori(q.y))
	var fx := SlopeProfile.smootherstep(q.x - c.x)
	var fz := SlopeProfile.smootherstep(q.y - c.y)
	var a := lerpf(_node_base(seed, c), _node_base(seed, c + Vector2i(1, 0)), fx)
	var b := lerpf(_node_base(seed, c + Vector2i(0, 1)), _node_base(seed, c + Vector2i(1, 1)), fx)
	return lerpf(a, b, fz)
```

Note: `set_force_archetype` calls `LandformSetpieces.clear_caches()`, created in Task 5. Until then create a stub so this task compiles: in Task 3 write `scripts/terrain/heightfield/LandformSetpieces.gd` with only

```gdscript
class_name LandformSetpieces
extends RefCounted

static func clear_caches() -> void:
	pass
```

(Task 5 replaces the file.)

- [ ] **Step 4: Register and run the test**

Run: `$GODOT --headless --path . --import` then the Step 2 command.
Expected: 6 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/heightfield/TerrainRegimeField.gd scripts/terrain/heightfield/LandformSetpieces.gd tests/test_terrain_regime_field.gd
git commit -m "Terrain: TerrainRegimeField Voronoi regions, base elevation, border bands"
```

---

### Task 4: RegimeRelief (archetype recipes)

**Files:**
- Create: `scripts/terrain/heightfield/RegimeRelief.gd`
- Test: `tests/test_regime_relief.gd`

**Interfaces:**
- Consumes: region record (Task 3), `ReliefPrimitives` (Task 1).
- Produces:
  - `static func relief_m(region: Dictionary, p: Vector2) -> float` (metres, added to base)
  - `static func terrace_of(region: Dictionary) -> Vector2` = (step m, riser_frac); step 0 = no terrace

- [ ] **Step 1: Write the failing test**

`tests/test_regime_relief.gd`:

```gdscript
extends GutTest

const SEED := 2697992464

func after_each() -> void:
	TerrainRegimeField.set_force_archetype(&"")

func _region(a: StringName, cell: Vector2i) -> Dictionary:
	TerrainRegimeField.set_force_archetype(a)
	return TerrainRegimeField.region(SEED, cell)

func test_every_archetype_is_deterministic_finite_and_bounded() -> void:
	for a: StringName in TerrainRegimeCatalog.ARCHETYPES:
		var r := _region(a, Vector2i(2, -3))
		var lo := INF
		var hi := -INF
		for i in 400:
			var p: Vector2 = r.site + Vector2(fposmod(i * 37.1, 600.0) - 300.0, fposmod(i * 53.3, 600.0) - 300.0)
			var h := RegimeRelief.relief_m(r, p)
			assert_eq(h, RegimeRelief.relief_m(r, p))
			assert_false(is_nan(h))
			lo = minf(lo, h)
			hi = maxf(hi, h)
		assert_between(lo, -30.0, 60.0, "%s min" % a)
		assert_between(hi, -30.0, 60.0, "%s max" % a)

func test_structured_archetypes_produce_storey_scale_relief() -> void:
	for a: StringName in [&"ridge_and_pass", &"escarpment_country", &"terraced_valleys",
			&"tableland", &"highland_massif", &"karst_hollows"]:
		var r := _region(a, Vector2i(1, 1))
		var lo := INF
		var hi := -INF
		for i in 900:
			var p: Vector2 = r.site + Vector2(i % 30, i / 30) * 12.0 - Vector2(180, 180)
			var h := RegimeRelief.relief_m(r, p)
			lo = minf(lo, h)
			hi = maxf(hi, h)
		assert_gt(hi - lo, 8.0, "%s spans at least two storeys over 360 m" % a)

func test_terrace_regimes_use_storey_steps() -> void:
	for a: StringName in TerrainRegimeCatalog.ARCHETYPES:
		var t := RegimeRelief.terrace_of(_region(a, Vector2i(0, 4)))
		if t.x > 0.0:
			assert_almost_eq(fmod(t.x, 4.0), 0.0, 1e-6, "%s step is whole storeys" % a)
			assert_between(t.y, 0.0, 1.0)
	assert_gt(RegimeRelief.terrace_of(_region(&"escarpment_country", Vector2i(0, 0))).x, 0.0)
	assert_eq(RegimeRelief.terrace_of(_region(&"rolling_downs", Vector2i(0, 0))).x, 0.0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `$GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_regime_relief.gd -gexit`
Expected: FAIL, `RegimeRelief` not declared.

- [ ] **Step 3: Write the implementation**

`scripts/terrain/heightfield/RegimeRelief.gd`:

```gdscript
class_name RegimeRelief
extends RefCounted

## Archetype recipes (spec 2026-10-02 §5): each turns a region record and a
## world position into relief metres added to the continental base. Noise is
## evaluated in the region's rotated frame with the region's own salt, so two
## regions of one archetype never share a pattern.

const ST := TerrainRegimeCatalog.STOREY


static func relief_m(region: Dictionary, p: Vector2) -> float:
	var q: Dictionary = region.params
	var s: int = region.salt
	var pr: Vector2 = p.rotated(region.rot)
	match region.archetype:
		&"rolling_downs":
			return ReliefPrimitives.hummock(pr, s, q.hummock_wl_m, 3) * q.relief_st * ST \
				+ ReliefPrimitives.sites_bump(pr, s + 5, q.knoll_spacing_m, q.knoll_density,
					minf(q.knoll_radius_m, q.knoll_spacing_m), 0.1) * q.knoll_st * ST
		&"ridge_and_pass", &"highland_massif":
			return _ridges(q, s, pr, 4 if region.archetype == &"ridge_and_pass" else 5)
		&"escarpment_country":
			var pw := ReliefPrimitives.warp(pr, s + 1, q.tread_depth_m * 0.5, q.tread_depth_m * 2.0)
			var stair := ReliefPrimitives.vnoise01(pw, s + 2, q.tread_depth_m * q.steps * 2.0)
			return stair * q.steps * q.tread_rise_st * ST \
				+ ReliefPrimitives.hummock(pr, s, q.hummock_wl_m, 2) * q.relief_st * ST
		&"terraced_valleys":
			var axis := Vector2.from_angle(region.rot).orthogonal()
			var rel := ReliefPrimitives.warp(p - region.site, s + 1, 40.0, 300.0)
			var side := maxf(0.0, absf(rel.dot(axis)) - q.valley_half_width_m)
			return minf(side / q.tread_depth_m, q.treads) * ST \
				+ ReliefPrimitives.hummock(pr, s, q.hummock_wl_m, 2) * q.relief_st * ST
		&"karst_hollows":
			return ReliefPrimitives.hummock(pr, s, q.hummock_wl_m, 2) * q.relief_st * ST \
				- ReliefPrimitives.sites_bump(pr, s + 5, q.sink_spacing_m, q.sink_density,
					q.sink_radius_m, 0.55) * q.sink_st * ST \
				- ReliefPrimitives.sites_bump(pr, s + 6, q.hollow_spacing_m, q.hollow_density,
					q.hollow_radius_m, 0.0) * q.hollow_st * ST \
				+ ReliefPrimitives.sites_bump(pr, s + 7, q.knob_spacing_m, 0.3,
					q.knob_radius_m, 0.3) * q.knob_st * ST
		&"tableland":
			var w := ReliefPrimitives.worley(ReliefPrimitives.warp(pr, s + 1, q.channel_m, q.cell_m), s + 7, q.cell_m)
			var interior := smoothstep(q.channel_m * 0.5, q.channel_m, w.y - w.x)
			return interior * lerpf(0.55, 1.0, w.z) * q.rim_st * ST
		&"low_flats":
			return ReliefPrimitives.hummock(pr, s, q.hummock_wl_m, 2) * q.relief_st * ST \
				+ ReliefPrimitives.sites_bump(pr, s + 5, q.mound_spacing_m, 0.4,
					minf(q.mound_radius_m, q.mound_spacing_m), 0.0) * q.mound_st * ST
	return 0.0


## Ridged spines, lowered into passes, with downhill gullies on their flanks.
static func _ridges(q: Dictionary, s: int, pr: Vector2, octaves: int) -> float:
	var wl: float = q.ridge_spacing_m * 2.0
	var pw := ReliefPrimitives.warp(pr, s + 1, q.ridge_spacing_m * 0.35, q.ridge_spacing_m * 1.5)
	var height: float = q.ridge_st * ST
	var r := ReliefPrimitives.ridged(pw, s + 2, wl, octaves, 2.0) \
		* ReliefPrimitives.pass_mod(pr, s + 3, q.pass_spacing_m, q.pass_depth)
	var grad := ReliefPrimitives.ridged_gradient(pw, s + 2, wl, 2.0) * height
	var gate := smoothstep(0.05, 0.25, grad.length())
	return r * height + ReliefPrimitives.gully(pr, s + 4, q.gully_spacing_m, -grad) \
		* q.gully_st * ST * gate


## (step metres, riser fraction) of the regime's storey-aligned terrace, or
## Vector2.ZERO when the archetype does not terrace.
static func terrace_of(region: Dictionary) -> Vector2:
	var q: Dictionary = region.params
	match region.archetype:
		&"escarpment_country":
			return Vector2(roundf(q.tread_rise_st) * ST, q.riser_frac)
		&"terraced_valleys":
			return Vector2(ST, q.riser_frac)
		&"tableland":
			return Vector2(ST, 0.15)
	return Vector2.ZERO
```

- [ ] **Step 4: Register and run the test**

Run: `$GODOT --headless --path . --import` then the Step 2 command.
Expected: 3 tests PASS. If `test_structured_archetypes_produce_storey_scale_relief` fails for one archetype, widen that archetype's amplitude range in the catalogue (Task 2 file) rather than the assertion, and note it in the commit.

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/heightfield/RegimeRelief.gd tests/test_regime_relief.gd
git commit -m "Terrain: RegimeRelief archetype recipes"
```

---

### Task 5: LandformSetpieces

**Files:**
- Replace: `scripts/terrain/heightfield/LandformSetpieces.gd` (stub from Task 3)
- Test: `tests/test_landform_setpieces.gd`

**Interfaces:**
- Consumes: `TerrainRegimeField.region_at`, `TerrainRegimeCatalog.SETPIECE_DENSITY/SETPIECE_PARAMS/draw`.
- Produces:
  - Set-piece record: `{kind: StringName, pos: Vector2, rot: float, params: Dictionary, priority: float, radius: float, cell: Vector2i}`
  - `const CELL := 512.0`, `const MAX_RADIUS := 480.0`, `const FEATHER := 48.0`
  - `static func admitted(seed: int, cell: Vector2i) -> Dictionary` (`{}` if none)
  - `static func sample(seed: int, p: Vector2) -> Vector2` = (delta m, mask in [0, 1])
  - `static func setpieces_in_rect(seed: int, rect: Rect2) -> Array[Dictionary]`
  - `static func shape(kind: StringName, params: Dictionary, local: Vector2, phase: float) -> Vector2` = (delta m, mask)
  - `static func footprint_radius(kind: StringName, params: Dictionary) -> float`
  - `static func clear_caches() -> void`

- [ ] **Step 1: Write the failing test**

`tests/test_landform_setpieces.gd`:

```gdscript
extends GutTest

const SEED := 2697992464
const ST := 4.0

func _max_params(kind: StringName) -> Dictionary:
	var out := {}
	var spec: Dictionary = TerrainRegimeCatalog.SETPIECE_PARAMS[kind]
	for name: String in spec:
		out[name] = float(spec[name][1])
	return out

func test_footprints_fit_the_neighbourhood_and_shapes_vanish_at_the_edge() -> void:
	for kind: StringName in TerrainRegimeCatalog.SETPIECE_PARAMS:
		var q := _max_params(kind)
		var r := LandformSetpieces.footprint_radius(kind, q)
		assert_lte(r, LandformSetpieces.MAX_RADIUS, String(kind))
		for i in 16:
			var edge := Vector2.from_angle(i * TAU / 16.0) * r
			var v := LandformSetpieces.shape(kind, q, edge, 0.3)
			assert_almost_eq(v.x, 0.0, 1e-4, "%s delta at edge" % kind)
			assert_almost_eq(v.y, 0.0, 1e-4, "%s mask at edge" % kind)

func test_shapes_have_their_silhouettes() -> void:
	var e := {"length_m": 600.0, "rise_st": 3.0, "face_m": 20.0, "back_m": 160.0}
	assert_gt(LandformSetpieces.shape(&"escarpment", e, Vector2(0, 40), 0.0).x
		- LandformSetpieces.shape(&"escarpment", e, Vector2(0, -40), 0.0).x, 3.0 * ST * 0.8, "escarpment step")
	var m := {"radius_m": 120.0, "height_st": 4.0, "face_m": 16.0}
	assert_almost_eq(LandformSetpieces.shape(&"mesa", m, Vector2.ZERO, 0.0).x,
		LandformSetpieces.shape(&"mesa", m, Vector2(60, 0), 0.0).x, 1e-4, "flat mesa crown")
	var g := {"length_m": 700.0, "height_st": 4.0, "half_width_m": 60.0, "pass_frac": 0.6}
	assert_gt(LandformSetpieces.shape(&"big_ridge", g, Vector2(200, 0), 0.0).x,
		LandformSetpieces.shape(&"big_ridge", g, Vector2.ZERO, 0.0).x + 4.0, "pass in the ridge")
	var c := {"length_m": 400.0, "slot_m": 30.0, "shoulder_st": 3.0, "shoulder_m": 80.0}
	assert_gt(LandformSetpieces.shape(&"cleft", c, Vector2(0, 50), 0.0).x
		- LandformSetpieces.shape(&"cleft", c, Vector2(0, 0), 0.0).x, 3.0 * ST * 0.8, "cleft walls")
	var h := {"length_m": 600.0, "trunk_half_m": 60.0, "trunk_st": 4.0, "trib_half_m": 20.0, "lip_st": 2.0}
	assert_gt(LandformSetpieces.shape(&"hanging_valley", h, Vector2(0, 150), 0.0).x
		- LandformSetpieces.shape(&"hanging_valley", h, Vector2(0, 0), 0.0).x, 2.0 * ST * 0.8, "lip above trunk floor")
	var a := {"radius_m": 160.0, "wall_st": 3.0}
	assert_gt(LandformSetpieces.shape(&"amphitheatre", a, Vector2(-160, 0), 0.0).x,
		LandformSetpieces.shape(&"amphitheatre", a, Vector2.ZERO, 0.0).x + 8.0, "back wall")
	assert_gt(LandformSetpieces.shape(&"amphitheatre", a, Vector2(-160, 0), 0.0).x,
		LandformSetpieces.shape(&"amphitheatre", a, Vector2(160, 0), 0.0).x + 6.0, "open mouth")

func test_admitted_footprints_never_overlap_and_are_order_independent() -> void:
	var cells: Array[Vector2i] = []
	for z in range(-8, 9):
		for x in range(-8, 9):
			cells.append(Vector2i(x, z))
	var forward := []
	for c in cells:
		forward.append(LandformSetpieces.admitted(SEED, c))
	LandformSetpieces.clear_caches()
	var backward := []
	for i in range(cells.size() - 1, -1, -1):
		backward.push_front(LandformSetpieces.admitted(SEED, cells[i]))
	assert_eq(forward, backward)
	var live := forward.filter(func(a): return not a.is_empty())
	assert_gt(live.size(), 3, "some set pieces exist")
	for i in live.size():
		for j in range(i + 1, live.size()):
			assert_gt(live[i].pos.distance_to(live[j].pos), live[i].radius + live[j].radius - 1e-3)

func test_sample_matches_rect_query() -> void:
	var rect := Rect2(-2000, -2000, 4000, 4000)
	var pieces := LandformSetpieces.setpieces_in_rect(SEED, rect)
	for i in 2000:
		var p := Vector2(fposmod(i * 97.3, 4000.0) - 2000.0, fposmod(i * 61.7, 4000.0) - 2000.0)
		var v := LandformSetpieces.sample(SEED, p)
		if v.y > 0.0:
			var hit := pieces.any(func(a): return p.distance_to(a.pos) < a.radius)
			assert_true(hit, "masked point %s lies in a listed footprint" % p)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `$GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_landform_setpieces.gd -gexit`
Expected: FAIL (stub has no `shape`).

- [ ] **Step 3: Write the implementation**

`scripts/terrain/heightfield/LandformSetpieces.gd`:

```gdscript
class_name LandformSetpieces
extends RefCounted

## Sparse, individually placed landforms (spec 2026-10-02 §6). One candidate per
## CELL; its kind is drawn from the region archetype's set-piece densities.
## Matern-II priority over the 5x5 neighbouring cells rejects every candidate
## whose footprint meets a higher-priority one, so admitted footprints never
## overlap and composition is a plain sum (no averaging of shapes). Footprint
## radius <= MAX_RADIUS keeps both the 5x5 rejection and the 3x3 evaluation
## exact. Shapes are in a local frame: x along the piece, y across it.

const CELL := 512.0
const MAX_RADIUS := 480.0
const FEATHER := 48.0
const ST := TerrainRegimeCatalog.STOREY
const CACHE_LIMIT := 4096

static var _candidates: Dictionary = {}   # seed -> {cell: Dictionary}
static var _admitted: Dictionary = {}
static var _keys: Array = []
static var _cursor := 0
static var _mutex := Mutex.new()


static func clear_caches() -> void:
	_mutex.lock()
	_candidates.clear()
	_admitted.clear()
	_keys.clear()
	_cursor = 0
	_mutex.unlock()


static func _cached(store: Dictionary, seed: int, cell: Vector2i):
	_mutex.lock()
	var value = (store.get(seed, {}) as Dictionary).get(cell)
	_mutex.unlock()
	return value


static func _store(store: Dictionary, seed: int, cell: Vector2i, value: Dictionary) -> Dictionary:
	_mutex.lock()
	var per_seed: Dictionary = store.get(seed, {})
	var existing = per_seed.get(cell)
	if existing != null:
		_mutex.unlock()
		return existing
	if _keys.size() == CACHE_LIMIT:
		var old: Array = _keys[_cursor]
		(_candidates.get(old[0], {}) as Dictionary).erase(old[1])
		(_admitted.get(old[0], {}) as Dictionary).erase(old[1])
		_keys[_cursor] = [seed, cell]
		_cursor = (_cursor + 1) % CACHE_LIMIT
	else:
		_keys.append([seed, cell])
	per_seed[cell] = value
	store[seed] = per_seed
	_mutex.unlock()
	return value


static func _candidate(seed: int, cell: Vector2i) -> Dictionary:
	var cached = _cached(_candidates, seed, cell)
	if cached != null:
		return cached
	var pos := (Vector2(cell) + Vector2(
		0.15 + 0.7 * Helper._cell_hash01(seed + 1501, cell.x, cell.y),
		0.15 + 0.7 * Helper._cell_hash01(seed + 1502, cell.x, cell.y))) * CELL
	var densities: Dictionary = TerrainRegimeCatalog.SETPIECE_DENSITY[TerrainRegimeField.region_at(seed, pos).archetype]
	var u := Helper._cell_hash01(seed + 1503, cell.x, cell.y)
	var kind: StringName = &""
	for k: StringName in densities:
		u -= float(densities[k])
		if u < 0.0:
			kind = k
			break
	var value := {}
	if kind != &"":
		var params := TerrainRegimeCatalog.draw(seed, cell, 1510, TerrainRegimeCatalog.SETPIECE_PARAMS[kind], 1.0)
		value = {"kind": kind, "pos": pos, "params": params, "cell": cell,
			"rot": Helper._cell_hash01(seed + 1504, cell.x, cell.y) * TAU,
			"priority": Helper._cell_hash01(seed + 1505, cell.x, cell.y),
			"radius": footprint_radius(kind, params)}
	return _store(_candidates, seed, cell, value)


static func _outranks(a: Dictionary, b: Dictionary) -> bool:
	if a.priority != b.priority:
		return a.priority > b.priority
	return a.cell.x < b.cell.x or (a.cell.x == b.cell.x and a.cell.y < b.cell.y)


static func admitted(seed: int, cell: Vector2i) -> Dictionary:
	var cached = _cached(_admitted, seed, cell)
	if cached != null:
		return cached
	var c := _candidate(seed, cell)
	var value := c
	if not c.is_empty():
		for dz in range(-2, 3):
			for dx in range(-2, 3):
				if dx == 0 and dz == 0:
					continue
				var o := _candidate(seed, cell + Vector2i(dx, dz))
				if not o.is_empty() and _outranks(o, c) \
						and c.pos.distance_to(o.pos) < c.radius + o.radius:
					value = {}
	return _store(_admitted, seed, cell, value)


## (delta metres, mask) at p from the one admitted set piece covering it.
static func sample(seed: int, p: Vector2) -> Vector2:
	var c := Vector2i(floori(p.x / CELL), floori(p.y / CELL))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var a := admitted(seed, c + Vector2i(dx, dz))
			if a.is_empty() or p.distance_to(a.pos) >= a.radius:
				continue
			return shape(a.kind, a.params, (p - a.pos).rotated(-a.rot), a.priority * TAU)
	return Vector2.ZERO


static func setpieces_in_rect(seed: int, rect: Rect2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var lo := Vector2i(floori(rect.position.x / CELL) - 1, floori(rect.position.y / CELL) - 1)
	var hi := Vector2i(floori(rect.end.x / CELL) + 1, floori(rect.end.y / CELL) + 1)
	for z in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			var a := admitted(seed, Vector2i(x, z))
			if not a.is_empty() and rect.grow(a.radius).has_point(a.pos):
				out.append(a)
	return out


static func footprint_radius(kind: StringName, q: Dictionary) -> float:
	match kind:
		&"escarpment", &"big_ridge", &"hanging_valley":
			return q.length_m * 0.5 + FEATHER * 0.5
		&"amphitheatre":
			return q.radius_m * 1.35 + FEATHER
		&"mesa":
			return q.radius_m + FEATHER
		&"cleft":
			return maxf(q.length_m * 0.5, q.slot_m * 0.5 + q.shoulder_m + FEATHER) + FEATHER * 0.5
	return 0.0


## Envelope reaching exactly 0 at the footprint radius.
static func _envelope(r: float, radius: float) -> float:
	return 1.0 - smoothstep(radius - FEATHER, radius, r)


## Fade to 0 over the last 2 FEATHER of a half-length.
static func _along(u: float, half: float) -> float:
	return 1.0 - smoothstep(half - 2.0 * FEATHER, half, absf(u))


static func shape(kind: StringName, q: Dictionary, local: Vector2, phase: float) -> Vector2:
	var env := _envelope(local.length(), footprint_radius(kind, q))
	var delta := 0.0
	var mask := 0.0
	match kind:
		&"escarpment":
			var half: float = q.length_m * 0.5
			var v: float = local.y + sin(local.x / q.length_m * TAU * 1.5 + phase) * q.face_m * 1.5
			var step := smoothstep(-q.face_m * 0.5, q.face_m * 0.5, v)
			var across := 1.0 - smoothstep(q.back_m * 0.5, q.back_m, absf(local.y))
			var along := _along(local.x, half)
			delta = (step - 0.5) * q.rise_st * ST * across * along
			mask = across * along
		&"amphitheatre":
			var r := local.length()
			var radius: float = q.radius_m
			var ring := exp(-pow((r - radius) / (0.25 * radius), 2.0))
			var mouth := smoothstep(-0.2, 0.5, local.x / maxf(r, 1.0))
			delta = q.wall_st * ST * ring * (1.0 - 0.9 * mouth)
			mask = 1.0 - smoothstep(radius, radius * 1.35, r)
		&"mesa":
			var r := local.length()
			delta = q.height_st * ST * (1.0 - smoothstep(q.radius_m - q.face_m, q.radius_m, r))
			mask = 1.0 - smoothstep(q.radius_m, q.radius_m + FEATHER, r)
		&"big_ridge":
			var across := exp(-pow(local.y / q.half_width_m, 2.0))
			var saddle := 1.0 - q.pass_frac * exp(-pow(local.x / (0.12 * q.length_m), 2.0))
			var along := _along(local.x, q.length_m * 0.5)
			delta = q.height_st * ST * across * saddle * along
			mask = smoothstep(0.0, 0.3, across) * along
		&"cleft":
			var a := absf(local.y + sin(local.x / q.length_m * TAU + phase) * q.slot_m)
			var inner: float = q.slot_m * 0.5
			var outer: float = inner + q.shoulder_m
			var shoulders := smoothstep(inner, inner + 16.0, a) * (1.0 - smoothstep(outer, outer + FEATHER, a))
			var along := _along(local.x, q.length_m * 0.5)
			delta = q.shoulder_st * ST * shoulders * along
			mask = (1.0 - smoothstep(outer, outer + FEATHER, a)) * along
		&"hanging_valley":
			var half: float = q.length_m * 0.5
			var along := _along(local.x, half)
			var trunk := (1.0 - smoothstep(q.trunk_half_m, q.trunk_half_m + 32.0, absf(local.y))) * along
			var trib := (1.0 - smoothstep(q.trib_half_m, q.trib_half_m + 24.0, absf(local.x))) \
				* smoothstep(q.trunk_half_m, q.trunk_half_m + 8.0, local.y) * _along(local.y, half)
			var trib_depth := maxf(q.trunk_st - q.lip_st, 1.0)
			delta = -q.trunk_st * ST * trunk - trib_depth * ST * trib * (1.0 - trunk)
			mask = maxf(trunk, trib)
	return Vector2(delta * env, clampf(mask, 0.0, 1.0) * env)
```

- [ ] **Step 4: Run the test**

Run: the Step 2 command (no new class name).
Expected: 4 tests PASS. If a silhouette assertion fails, check the sign conventions in the shape against the test's local coordinates (x along, y across, escarpment high side +y, amphitheatre mouth +x, hanging-valley tributary +y) before touching the test.

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/heightfield/LandformSetpieces.gd tests/test_landform_setpieces.gd
git commit -m "Terrain: LandformSetpieces sparse placed landforms with Matern-II placement"
```

---

### Task 6: TerrainField composition and HeightfieldPlan integration

**Files:**
- Create: `scripts/terrain/heightfield/TerrainField.gd`
- Modify: `scripts/terrain/heightfield/HeightfieldPlan.gd` (`height01`, lines ~150-170)
- Delete: `scripts/terrain/heightfield/LandformField.gd`, `tests/test_september15_landform_cache.gd`, `tests/harness/september11_landmark_survey.gd`, `tests/harness/september15_streaming_qa.gd`, `tests/harness/september15_landform_cost.gd`
- Modify: `tests/test_september11_landforms.gd` (replace the third test), `tests/test_atmosphere_field.gd` (drop the two `LandformField` tests)
- Test: `tests/test_terrain_field.gd`

**Interfaces:**
- Consumes: Tasks 1-5.
- Produces:
  - `const REF_AMPLITUDE := TerrainWorldTuning.HEIGHTFIELD_AMPLITUDE`
  - `static func height_m(p: Vector2, seed: int, include_detail: bool) -> float`
  - `HeightfieldPlan.height01(pos, seed, include_detail)` = `clamp(height_m / REF_AMPLITUDE * spawn_falloff, 0, 1)`

- [ ] **Step 1: Write the failing test**

`tests/test_terrain_field.gd`:

```gdscript
extends GutTest

const SEED := 2697992464

func after_each() -> void:
	TerrainRegimeField.set_force_archetype(&"")

func test_smooth_field_is_base_plus_setpieces() -> void:
	for i in 200:
		var p := Vector2(fposmod(i * 311.3, 5000.0) - 2500.0, fposmod(i * 197.9, 5000.0) - 2500.0)
		assert_almost_eq(TerrainField.height_m(p, SEED, false),
			TerrainRegimeField.base_m(SEED, p) + LandformSetpieces.sample(SEED, p).x, 1e-9)

func test_height01_is_bounded_and_spawn_is_flat() -> void:
	assert_eq(HeightfieldPlan.height01(Vector3.ZERO, SEED), 0.0)
	assert_eq(HeightfieldPlan.height01(Vector3(40, 0, -30), SEED), 0.0)
	for z in range(-30, 31, 3):
		for x in range(-30, 31, 3):
			var h := HeightfieldPlan.height01(Vector3(x * 97.0, 0, z * 89.0), SEED)
			assert_between(h, 0.0, 1.0)

func test_no_archetype_clips_at_the_amplitude() -> void:
	for a: StringName in TerrainRegimeCatalog.ARCHETYPES:
		TerrainRegimeField.set_force_archetype(a)
		var top := 0.0
		for z in range(-20, 21):
			for x in range(-20, 21):
				top = maxf(top, TerrainField.height_m(Vector2(x * 61.0 + 3000.0, z * 59.0), SEED, true))
		assert_lt(top, TerrainField.REF_AMPLITUDE - 0.5, "%s stays under the ceiling" % a)

## A real jump does not shrink when re-sampled finer; a steep riser does.
func _assert_continuous_along(from: Vector2, to: Vector2, step: float) -> void:
	var n := int(from.distance_to(to) / step)
	var dir := (to - from).normalized()
	var prev := TerrainField.height_m(from, SEED, true)
	for i in range(1, n + 1):
		var p := from + dir * (i * step)
		var h := TerrainField.height_m(p, SEED, true)
		var d := absf(h - prev)
		if d > 0.5:
			var fine := 0.0
			var q_prev := prev
			for k in range(1, 65):
				var q := TerrainField.height_m(p - dir * step + dir * (k * step / 64.0), SEED, true)
				fine = maxf(fine, absf(q - q_prev))
				q_prev = q
			assert_lt(fine, d * 0.5, "jump of %.2f m at %s does not shrink when refined" % [d, p])
		prev = h

func test_field_is_continuous_across_regions_and_setpieces() -> void:
	for line in [[Vector2(-2600, 211), Vector2(2600, 211)], [Vector2(-433, -2600), Vector2(-433, 2600)],
			[Vector2(-1800, -1700), Vector2(1900, 1650)]]:
		_assert_continuous_along(line[0], line[1], 0.5)

func test_relief_now_survives_storey_quantization() -> void:
	var plan := TerrainWorldTuning.make_heightfield(SEED)
	var structured := 0
	var windows := 0
	for wz in range(-40, 40, 5):
		for wx in range(-40, 40, 5):
			var lo := 999
			var hi := -999
			for j in 4:
				for i in 4:
					var s := plan.storey_at(wx * 4 + i + 200, wz * 4 + j + 200)
					lo = mini(lo, s)
					hi = maxi(hi, s)
			windows += 1
			structured += int(hi > lo)
	assert_gt(float(structured) / windows, 0.4, "most 48 m windows hold a storey change")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `$GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_terrain_field.gd -gexit`
Expected: FAIL, `TerrainField` not declared.

- [ ] **Step 3: Write `TerrainField.gd`**

```gdscript
class_name TerrainField
extends RefCounted

## The natural terrain height in metres (spec 2026-10-02 §2):
##   H = base + setpieces + relief * (1 - 0.7 setpiece_mask), then each side of
##   a regime border applies its own storey-aligned terrace and the two results
##   cross-fade with the border weight.
## include_detail=false is base + setpieces: the smooth field rivers trace.

const REF_AMPLITUDE := TerrainWorldTuning.HEIGHTFIELD_AMPLITUDE
const SETPIECE_RELIEF_SUPPRESSION := 0.7


static func height_m(p: Vector2, seed: int, include_detail: bool) -> float:
	var sp := LandformSetpieces.sample(seed, p)
	var h := TerrainRegimeField.base_m(seed, p) + sp.x
	if not include_detail:
		return h
	var s := TerrainRegimeField.sample(seed, p)
	var a: Dictionary = s[0]
	var b: Dictionary = s[1]
	var w: float = s[2]
	var blended := w < 1.0 and not is_same(a, b)
	var keep := 1.0 - SETPIECE_RELIEF_SUPPRESSION * sp.y
	var ha := h + RegimeRelief.relief_m(a, p) * keep
	ha = _terraced(ha, RegimeRelief.terrace_of(a))
	if not blended:
		return ha
	var hb := _terraced(h + RegimeRelief.relief_m(b, p) * keep, RegimeRelief.terrace_of(b))
	return lerpf(hb, ha, w)


static func _terraced(h: float, t: Vector2) -> float:
	return h if t.x <= 0.0 else ReliefPrimitives.terrace(h, t.x, t.y)
```

Note: `ha`/`hb` include `h`, so the border blend is `h + lerp(relief_b, relief_a, w)` for non-terraced regimes, as the spec requires.

- [ ] **Step 4: Rewire `HeightfieldPlan.height01`**

Replace the body and doc comment of `static func height01` in `scripts/terrain/heightfield/HeightfieldPlan.gd` with:

```gdscript
## Natural terrain in [0, 1] (spec 2026-10-02): TerrainField's metre field over
## the production amplitude. include_detail=false is the SMOOTH field (continental
## base + placed set pieces) that river tracing descends; include_detail=true adds
## the regime relief and terraces and is the rendered field (raw_height).
## A flat clearing near the world origin keeps the spawn gentle.
static func height01(pos: Vector3, p_world_seed: int, include_detail: bool = true) -> float:
	var h := TerrainField.height_m(Vector2(pos.x, pos.z), p_world_seed, include_detail) / TerrainField.REF_AMPLITUDE
	var falloff: float = SlopeProfile.smootherstep(clampf((Vector2(pos.x, pos.z).length() - 60.0) / 180.0, 0.0, 1.0))
	return clampf(h * falloff, 0.0, 1.0)
```

Also edit the class doc comment line referencing `LandformField` if present (`grep -n Landform scripts/terrain/heightfield/HeightfieldPlan.gd`).

- [ ] **Step 5: Retire LandformField and its tests/harnesses**

```bash
git rm scripts/terrain/heightfield/LandformField.gd tests/test_september15_landform_cache.gd \
  tests/harness/september11_landmark_survey.gd tests/harness/september15_streaming_qa.gd \
  tests/harness/september15_landform_cost.gd
grep -rn "LandformField" scripts tests | grep -v "tests/fixtures/"
```

Expected remaining hits: only `tests/test_september11_landforms.gd` and `tests/test_atmosphere_field.gd`.

In `tests/test_atmosphere_field.gd` delete the functions `test_landforms_have_distinct_structural_silhouettes` and `test_landform_provinces_do_not_introduce_grid_seams` (silhouettes and seams are now covered by `test_landform_setpieces` and `test_terrain_field`).

In `tests/test_september11_landforms.gd` replace `test_biome_relief_and_shapes_are_distinct_and_continuous` with:

```gdscript
func test_archetypes_have_distinct_elevations() -> void:
	var means: Dictionary = {}
	for a: StringName in [&"low_flats", &"rolling_downs", &"highland_massif", &"tableland"]:
		TerrainRegimeField.set_force_archetype(a)
		var total := 0.0
		for z in range(-8, 9):
			for x in range(-8, 9):
				total += TerrainField.height_m(Vector2(x * 127 + 2000, z * 131), 2697992464, true)
		means[a] = total / 289.0
	TerrainRegimeField.set_force_archetype(&"")
	assert_gt(means.highland_massif, means.low_flats + 30.0)
	assert_gt(means.tableland, means.low_flats + 12.0)
	assert_gt(means.rolling_downs, means.low_flats)
```

The first two tests (mountain height > 60 m, ≥ 30 river sources per 81 districts) stay unchanged: they are the Review Focus guards for clipping/height and river sources.

- [ ] **Step 6: Import and run the integration tests**

Run: `$GODOT --headless --path . --import`, then each of:
`tests/test_terrain_field.gd`, `tests/test_september11_landforms.gd`, `tests/test_atmosphere_field.gd`, `tests/test_heightfield_plan.gd`, `tests/test_heightfield_region.gd`, `tests/test_heightfield_clamp_step.gd`, `tests/test_heightfield_lowpass.gd`, `tests/test_terrain_tile_field.gd`.
Expected: all pass, except geography-pinned assertions that assumed the old landforms. For each such failure: confirm it pins a seed/coordinate to a specific old landform (read the test), then re-pin it to an equivalent site found programmatically (scan for a point meeting the test's stated condition under the new field) and record old → new in the commit message. Never relax a threshold.

If `test_relief_now_survives_storey_quantization` fails, print the measured fraction and raise relief amplitudes in the catalogue; if `test_no_archetype_clips_at_the_amplitude` fails, lower that archetype's `base_level_st` max.

- [ ] **Step 7: Commit**

```bash
git add scripts/terrain/heightfield/TerrainField.gd scripts/terrain/heightfield/HeightfieldPlan.gd \
  tests/test_terrain_field.gd tests/test_september11_landforms.gd tests/test_atmosphere_field.gd
git commit -m "Terrain: TerrainField composes regimes, set pieces and relief; retire LandformField"
```

---

### Task 7: Region map, structure survey and cost harnesses

**Files:**
- Create: `tests/harness/terrain_regime_map.gd`
- Create: `tests/harness/terrain_structure_survey.gd`
- Create: `tests/harness/terrain_field_cost.gd`

**Interfaces:**
- Consumes: `TerrainField`, `TerrainRegimeField`, `LandformSetpieces`, `TerrainWorldTuning.make_heightfield/make_water`, `HeightfieldRegion.storey_at`, `TerrainTileField.edge_category/EdgeCategory`.
- Produces: CLI tools (no code consumers).

- [ ] **Step 1: Region map**

`tests/harness/terrain_regime_map.gd`:

```gdscript
extends SceneTree

## Top-down review map of the natural terrain field (spec 2026-10-02 §7).
## Hillshaded storey bands tinted by regime archetype, border bands darkened,
## set-piece footprints outlined. Also writes one F4 review spot per archetype.
##   Godot --headless --path . -s res://tests/harness/terrain_regime_map.gd -- \
##     --seed 2697992464 --center 0,0 --size 4096 --mpp 8 --output /tmp/map.png [--spots spots.json]

const TINT := {
	&"rolling_downs": Color(0.55, 0.75, 0.40), &"ridge_and_pass": Color(0.70, 0.55, 0.40),
	&"escarpment_country": Color(0.85, 0.70, 0.40), &"terraced_valleys": Color(0.45, 0.70, 0.55),
	&"karst_hollows": Color(0.55, 0.60, 0.75), &"tableland": Color(0.85, 0.50, 0.35),
	&"highland_massif": Color(0.65, 0.65, 0.70), &"low_flats": Color(0.40, 0.65, 0.70),
}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var seed := 2697992464
	var center := Vector2.ZERO
	var size := 4096.0
	var mpp := 8.0
	var output := "/tmp/terrain_regime_map.png"
	var spots_path := ""
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		var next := args[i + 1] if i + 1 < args.size() else ""
		match args[i]:
			"--seed": seed = int(next)
			"--center":
				var parts := next.split(",")
				center = Vector2(float(parts[0]), float(parts[1]))
			"--size": size = float(next)
			"--mpp": mpp = float(next)
			"--output": output = next
			"--spots": spots_path = next
	var n := int(size / mpp)
	var origin := center - Vector2(size, size) * 0.5
	var heights := PackedFloat32Array()
	heights.resize(n * n)
	var started := Time.get_ticks_msec()
	for z in n:
		for x in n:
			var p := origin + Vector2(x + 0.5, z + 0.5) * mpp
			heights[z * n + x] = HeightfieldPlan.height01(Vector3(p.x, 0, p.y), seed) * TerrainField.REF_AMPLITUDE
	var image := Image.create(n, n, false, Image.FORMAT_RGB8)
	var counts := {}
	var examples := {}
	for z in n:
		for x in n:
			var p := origin + Vector2(x + 0.5, z + 0.5) * mpp
			var s := TerrainRegimeField.sample(seed, p)
			var a: StringName = s[0].archetype
			counts[a] = counts.get(a, 0) + 1
			if not examples.has(a) and s[2] == 1.0 and p.distance_to(s[0].site) < 120.0:
				examples[a] = p
			var h := heights[z * n + x]
			var hx := heights[z * n + mini(x + 1, n - 1)] - heights[z * n + maxi(x - 1, 0)]
			var hz := heights[mini(z + 1, n - 1) * n + x] - heights[maxi(z - 1, 0) * n + x]
			var shade := clampf(0.75 + (-hx - hz) / (4.0 * mpp), 0.35, 1.25)
			var band := 0.85 + 0.15 * float(int(floorf(h / 4.0)) % 2)
			var c: Color = TINT[a] * shade * band
			if s[2] < 0.55:
				c = c.darkened(0.45)
			image.set_pixel(x, z, Color(clampf(c.r, 0, 1), clampf(c.g, 0, 1), clampf(c.b, 0, 1)))
	var outlined := 0
	for piece in LandformSetpieces.setpieces_in_rect(seed, Rect2(origin, Vector2(size, size))):
		outlined += 1
		for k in 256:
			var e: Vector2 = piece.pos + Vector2.from_angle(k * TAU / 256.0) * piece.radius
			var px := Vector2i(((e - origin) / mpp).floor())
			if px.x >= 0 and px.y >= 0 and px.x < n and px.y < n:
				image.set_pixelv(px, Color(1, 1, 1))
	image.save_png(output)
	print("REGIME_MAP %s %dx%d in %d ms, %d set pieces" % [output, n, n, Time.get_ticks_msec() - started, outlined])
	var total := float(n * n)
	for a: StringName in TerrainRegimeCatalog.ARCHETYPES:
		print("  %-20s %5.1f%%  tint %s" % [a, 100.0 * counts.get(a, 0) / total, TINT[a].to_html(false)])
	if spots_path != "":
		var spots := []
		for a: StringName in examples:
			var p: Vector2 = examples[a]
			var y := HeightfieldPlan.height01(Vector3(p.x, 0, p.y), seed) * TerrainField.REF_AMPLITUDE
			spots.append({"name": "regime %s" % a, "pos": [p.x, y + 7.0, p.y], "look": [p.x + 40.0, p.y]})
		FileAccess.open(spots_path, FileAccess.WRITE).store_string(JSON.stringify(spots, " "))
		print("REGIME_SPOTS %s (%d)" % [spots_path, spots.size()])
	quit()
```

- [ ] **Step 2: Structure survey**

`tests/harness/terrain_structure_survey.gd`:

```gdscript
extends SceneTree

## Tactical-structure metrics on the final storey lattice (spec 2026-10-02 §7).
## Uses only HeightfieldPlan/HeightfieldRegion/TerrainTileField APIs that also
## exist before the change, so the same file measures the baseline.
##   Godot --headless --path . -s res://tests/harness/terrain_structure_survey.gd -- \
##     --seed 2697992464 --center 0,0 --points 256 [--no-water] --output /tmp/survey.json

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var seed := 2697992464
	var center := Vector2i.ZERO
	var size := 256
	var water := true
	var output := "/tmp/terrain_structure_survey.json"
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		var next := args[i + 1] if i + 1 < args.size() else ""
		match args[i]:
			"--seed": seed = int(next)
			"--center":
				var parts := next.split(",")
				center = Vector2i(int(parts[0]), int(parts[1]))
			"--points": size = int(next)
			"--no-water": water = false
			"--output": output = next
	var started := Time.get_ticks_msec()
	var plan := TerrainWorldTuning.make_heightfield(seed, TerrainWorldTuning.make_water(seed) if water else null)
	var lo := center - Vector2i(size / 2, size / 2)
	var region := plan.compute_rect_region(Rect2i(lo, Vector2i(size, size)))
	var build_ms := Time.get_ticks_msec() - started
	var walls := 0
	var slopes := 0
	var edges := 0
	var longest_run := 0
	var runs: Array[int] = []
	for axis in 2:
		var d := Vector2i(1, 0) if axis == 0 else Vector2i(0, 1)
		var side := Vector2i(0, 1) if axis == 0 else Vector2i(1, 0)
		for a in size - 1:
			var run := 0
			for b in size:
				var p := lo + d * a + side * b
				var cat := TerrainTileField.edge_category(region, p, d)
				edges += 1
				if cat == TerrainTileField.EdgeCategory.CLIFF:
					walls += 1
					run += 1
				else:
					if cat == TerrainTileField.EdgeCategory.SLOPE:
						slopes += 1
					if run > 0:
						runs.append(run)
					longest_run = maxi(longest_run, run)
					run = 0
			if run > 0:
				runs.append(run)
			longest_run = maxi(longest_run, run)
	var speckle := 0
	for j in range(1, size - 1):
		for i in range(1, size - 1):
			var p := lo + Vector2i(i, j)
			var s := region.storey_at(p.x, p.y)
			var higher := 0
			var lower := 0
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var o := region.storey_at(p.x + d.x, p.y + d.y)
				higher += int(o > s)
				lower += int(o < s)
			speckle += int(higher == 4 or lower == 4)
	var windows := 0
	var structured := 0
	var tactical := 0
	for wz in range(0, size - 4, 4):
		for wx in range(0, size - 4, 4):
			var has_wall := false
			var has_climb := false
			var smin := 9999
			var smax := -9999
			for j in 4:
				for i in 4:
					var p := lo + Vector2i(wx + i, wz + j)
					var s := region.storey_at(p.x, p.y)
					smin = mini(smin, s)
					smax = maxi(smax, s)
					for d in [Vector2i(1, 0), Vector2i(0, 1)]:
						var cat := TerrainTileField.edge_category(region, p, d)
						has_wall = has_wall or cat == TerrainTileField.EdgeCategory.CLIFF
						has_climb = has_climb or cat == TerrainTileField.EdgeCategory.SLOPE
			windows += 1
			structured += int(smax > smin)
			tactical += int(has_wall and has_climb)
	var seen := {}
	var small_area := 0
	for j in size:
		for i in size:
			var start := lo + Vector2i(i, j)
			if seen.has(start):
				continue
			var stack: Array[Vector2i] = [start]
			seen[start] = true
			var component := 0
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				component += 1
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var o: Vector2i = p + d
					if o.x < lo.x or o.y < lo.y or o.x >= lo.x + size or o.y >= lo.y + size or seen.has(o):
						continue
					if TerrainTileField.is_walkable_edge(region, p, d):
						seen[o] = true
						stack.append(o)
			if component < 50:
				small_area += component
	runs.sort()
	var km2 := pow(size * 12.0 / 1000.0, 2.0)
	var result := {
		"seed": seed, "center": [center.x, center.y], "points": size, "water": water, "build_ms": build_ms,
		"structured": float(structured) / windows, "tactical": float(tactical) / windows,
		"speckle_per_km2": speckle / km2, "wall_edges_per_km2": walls / km2,
		"slope_edges_per_km2": slopes / km2,
		"wall_run_p50": runs[runs.size() / 2] if not runs.is_empty() else 0,
		"wall_run_p95": runs[int(runs.size() * 0.95)] if not runs.is_empty() else 0,
		"wall_run_max": longest_run, "trapped_area": float(small_area) / (size * size),
	}
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(result, "  "))
	print("STRUCTURE_SURVEY ", JSON.stringify(result))
	quit()
```

Note: `wall_run` counts consecutive cliff edges across parallel lattice lines (a wall running along an axis), measured per scan line.

- [ ] **Step 3: Cost harness**

`tests/harness/terrain_field_cost.gd`:

```gdscript
extends SceneTree

## Per-sample cost of the natural field (smooth vs detailed), spec §7 budget.
##   Godot --headless --path . -s res://tests/harness/terrain_field_cost.gd

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var points: Array[Vector3] = []
	for i in 20000:
		points.append(Vector3(float(i % 200) * 6 - 1000, 0, float(i / 200) * 6 - 1200))
	for detail in [false, true, false, true]:
		var start := Time.get_ticks_usec()
		var sum := 0.0
		for point in points:
			sum += HeightfieldPlan.height01(point, 2697992464, detail)
		print("FIELD_COST detail=%s us_per_sample=%.2f checksum=%.6f" % [detail,
			float(Time.get_ticks_usec() - start) / points.size(), sum])
	quit()
```

This uses only `HeightfieldPlan.height01`, so it runs unchanged on the baseline.

- [ ] **Step 4: Run all three on this branch**

```bash
mkdir -p docs/qa/2026-10-02-terrain-regimes
$GODOT --headless --path . -s res://tests/harness/terrain_regime_map.gd -- --seed 2697992464 --size 4096 --mpp 8 --output docs/qa/2026-10-02-terrain-regimes/map-0-0.png --spots /tmp/regime_spots.json
$GODOT --headless --path . -s res://tests/harness/terrain_structure_survey.gd -- --seed 2697992464 --center 60,40 --points 256 --output docs/qa/2026-10-02-terrain-regimes/survey-after.json
$GODOT --headless --path . -s res://tests/harness/terrain_field_cost.gd
```

Expected: a PNG, a JSON with all keys, and four `FIELD_COST` lines. Open the PNG (Read tool) and check for regions, borders and set-piece outlines.

- [ ] **Step 5: Baseline numbers**

Create a baseline worktree at the pre-change commit and run the survey and cost harness there:

```bash
git worktree add /Users/ryko/story-regimes-base b8e130d9
cd /Users/ryko/story-regimes-base && ln -s /Users/ryko/story/addons addons && ln -s /Users/ryko/story/assets assets && cp -cR /Users/ryko/story/.godot .godot
cp <branch>/tests/harness/terrain_structure_survey.gd <branch>/tests/harness/terrain_field_cost.gd tests/harness/
$GODOT --headless --path . --import
$GODOT --headless --path . -s res://tests/harness/terrain_structure_survey.gd -- --seed 2697992464 --center 60,40 --points 256 --output <branch>/docs/qa/2026-10-02-terrain-regimes/survey-before.json
$GODOT --headless --path . -s res://tests/harness/terrain_field_cost.gd
```

Record the cost lines from both in `docs/qa/2026-10-02-terrain-regimes/cost.txt`. Budget check: smooth ≤ 1.5× baseline smooth, detailed ≤ 3× baseline detailed. If over budget, profile which primitive dominates and note it (no blocking; owner decides).

- [ ] **Step 6: Commit**

```bash
git add tests/harness/terrain_regime_map.gd tests/harness/terrain_structure_survey.gd tests/harness/terrain_field_cost.gd docs/qa/2026-10-02-terrain-regimes/
git commit -m "Terrain harnesses: regime map, structure survey, field cost; first measurements"
```

---

### Task 8: Archetype gallery, F3 readout, F4 spots

**Files:**
- Create: `tests/harness/regime_gallery.gd`, `tests/harness/regime_gallery.tscn`
- Modify: `scripts/terrain/tools/CoordOverlay.gd` (`_process`, after the biome line)
- Modify: `review_teleports.json` (append regime spots)

**Interfaces:**
- Consumes: `TerrainRegimeField.set_force_archetype/sample`, `TerrainChunkMesher` (`set_seed`, `prepare_resources`, `compute_chunk(chunk, region)`, `commit_chunk`), `CliffRockStyle.apply`, `HeightfieldPlan.compute_region`.

- [ ] **Step 1: Gallery script**

`tests/harness/regime_gallery.gd`:

```gdscript
extends Node3D

## Archetype gallery (spec 2026-10-02 §7): for each archetype and sample, force
## the archetype everywhere, mesh a 3x3-chunk site through the production
## TerrainChunkMesher (no water), and capture an oblique and a top view.
##   Godot --path . res://tests/harness/regime_gallery.tscn -- --output DIR \
##     [--archetype NAME|all] [--samples N] [--seed S]
const Mesher := preload("res://scripts/terrain/field/TerrainChunkMesher.gd")
const STYLE := preload("res://scripts/terrain/field/CliffRockStyle.gd")
const SPACING := 7168.0   # metres between samples: distinct regions per sample

var _output := "/tmp/regime_gallery"
var _archetypes: Array[StringName] = []
var _samples := 2
var _seed := 2697992464
var _camera := Camera3D.new()
var _terrain := Node3D.new()


func _ready() -> void:
	var only := "all"
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		var next := args[i + 1] if i + 1 < args.size() else ""
		match args[i]:
			"--output": _output = next
			"--archetype": only = next
			"--samples": _samples = int(next)
			"--seed": _seed = int(next)
	_archetypes = TerrainRegimeCatalog.ARCHETYPES.duplicate() if only == "all" else [StringName(only)]
	get_window().size = Vector2i(1600, 900)
	DirAccess.make_dir_recursive_absolute(_output)
	_environment()
	_camera.current = true
	_camera.far = 6000.0
	add_child(_camera)
	add_child(_terrain)
	_run.call_deferred()


func _environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.27, 0.46, 0.75)
	sky_material.sky_horizon_color = Color(0.71, 0.82, 0.92)
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-42.0), deg_to_rad(-70.0), 0.0)), Vector3.ZERO)
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.5
	sun.directional_shadow_max_distance = 1500.0
	add_child(sun)


func _run() -> void:
	STYLE.apply("sheet_bedrock")
	var mesher := Mesher.new()
	mesher.set_seed(_seed)
	mesher.prepare_resources()
	for a: StringName in _archetypes:
		TerrainRegimeField.set_force_archetype(a)
		for k in _samples:
			var centre_chunk := Vector2i(int((k + 1) * SPACING / 192.0), 3)
			var plan := HeightfieldPlan.new(_seed, TerrainWorldTuning.HEIGHTFIELD_AMPLITUDE,
				TerrainWorldTuning.HEIGHTFIELD_MAX_STOREYS, "mean", TerrainWorldTuning.MAX_CLIFF_STEP)
			var centre_point := centre_chunk * Mesher.POINTS_PER_CHUNK + Vector2i(8, 8)
			var region := plan.compute_region(centre_point.x, centre_point.y, 36)
			for child in _terrain.get_children():
				child.queue_free()
			var top := -INF
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					var node := mesher.commit_chunk(mesher.compute_chunk(centre_chunk + Vector2i(dx, dz), region))
					_terrain.add_child(node)
					await get_tree().process_frame
			for j in range(-24, 25, 4):
				for i in range(-24, 25, 4):
					top = maxf(top, region.surface_height(centre_point.x + i, centre_point.y + j))
			var focus := Vector3(centre_point.x * 12.0, top * 0.5, centre_point.y * 12.0)
			var name := "%s_%d" % [a, k]
			await _shoot("%s/%s_oblique.png" % [_output, name], focus + Vector3(-260, 230, 330), focus)
			await _shoot("%s/%s_top.png" % [_output, name], focus + Vector3(0, 700, 0.01), focus)
			print("[regime_gallery] %s" % name)
	TerrainRegimeField.set_force_archetype(&"")
	print("[regime_gallery] done -> ", _output)
	get_tree().quit(0)


func _shoot(path: String, from: Vector3, target: Vector3) -> void:
	_camera.fov = 50.0
	_camera.look_at_from_position(from, target, Vector3.UP)
	for unused in 8:
		await get_tree().process_frame
	RenderingServer.force_draw()
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(path)
```

`tests/harness/regime_gallery.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://tests/harness/regime_gallery.gd" id="1"]

[node name="RegimeGallery" type="Node3D"]
script = ExtResource("1")
```

Before running, verify `HeightfieldRegion.surface_height(i, j)` exists (`grep -n "func surface_height" scripts/terrain/heightfield/HeightfieldRegion.gd`); if its name differs, use the existing per-point height accessor.

- [ ] **Step 2: Run the gallery**

Run: `$GODOT --path . res://tests/harness/regime_gallery.tscn -- --output docs/qa/2026-10-02-terrain-regimes/gallery --samples 2` (windowed; run in background, it takes minutes).
Expected: 32 PNGs. Inspect at least one oblique per archetype with the Read tool; record anything broken (holes, wrong scale, flat) in the QA notes.

- [ ] **Step 3: F3 readout**

In `scripts/terrain/tools/CoordOverlay.gd`, directly after the `lines.append("biome %s ...")` line inside `if wseed != 0:`, add:

```gdscript
			var regime := TerrainRegimeField.sample(int(wseed), Vector2(pp.x, pp.z))
			lines.append("terrain %s   (site %.0f, %.0f; border w %.2f%s)" % [regime[0].archetype,
				regime[0].site.x, regime[0].site.y, regime[2],
				"" if regime[2] >= 1.0 else ", with %s" % regime[1].archetype])
```

- [ ] **Step 4: F4 spots**

Append the entries of `/tmp/regime_spots.json` (from Task 7 Step 4) to the array in `review_teleports.json` (keep existing entries; JSON array merge with a short python one-liner or by hand).

- [ ] **Step 5: Commit**

```bash
git add tests/harness/regime_gallery.gd tests/harness/regime_gallery.tscn scripts/terrain/tools/CoordOverlay.gd review_teleports.json docs/qa/2026-10-02-terrain-regimes/gallery
git commit -m "Terrain review: regime archetype gallery, F3 regime readout, F4 regime spots"
```

---

### Task 9: Suite comparison, profile, docs

**Files:**
- Modify: `AGENTS.md` (terrain pipeline `HeightfieldPlan` bullet; new top entry)
- Create: `docs/qa/2026-10-02-terrain-regimes/result.md`
- Modify: `docs/superpowers/specs/2026-10-02-terrain-regimes-local-relief-design.md` (status line + deviations)

- [ ] **Step 1: Full suite, both trees**

```bash
tests/tools/run_suite_isolated.sh /tmp/suite-after.txt 2
(cd /Users/ryko/story-regimes-base && tests/tools/run_suite_isolated.sh /tmp/suite-before.txt 2 tests/test_*.gd /Users/ryko/story-regimes-base)
```

Compare per-file lines. Every file failing after but not before is either fixed (re-pin geography per Task 6 Step 6, or a genuine bug) or listed in `result.md` with its reason. Deleted test files are expected to be missing.

- [ ] **Step 2: Startup profile**

Run `$GODOT --headless --path . -s res://tests/harness/profile_terrain.gd` in both trees; paste both summaries into `result.md`.

- [ ] **Step 3: Write `result.md`**

Sections: what changed; maps (`map-*.png`); gallery (`gallery/`); survey before/after table (all keys); cost table vs budget; suite comparison; open items for owner review (border escarpments deferred, valley damping deferred, F9 gallery view deferred, any over-budget cost).

- [ ] **Step 4: Update AGENTS.md**

Add a dated top entry (October 2 terrain regimes) summarising the new layers, module names, harness commands, and measured numbers. In the `heightfield/HeightfieldPlan.gd` bullet, replace "layered value noise + rocky-biome mountain spines + `LandformField`" with "`TerrainField` (continental base + `LandformSetpieces` + per-regime `RegimeRelief` from `TerrainRegimeField`/`TerrainRegimeCatalog`)". Update "Tuning terrain shape" to point at `TerrainRegimeCatalog`.

- [ ] **Step 5: Update the spec**

Set status to "phase 1 implemented" and add a "Deviations" section copied from this plan's deviations list.

- [ ] **Step 6: Commit and remove the baseline worktree**

```bash
git add AGENTS.md docs/qa/2026-10-02-terrain-regimes/result.md docs/superpowers/specs/2026-10-02-terrain-regimes-local-relief-design.md
git commit -m "Docs: terrain regimes phase 1 result, AGENTS.md"
git worktree remove /Users/ryko/story-regimes-base --force
```
