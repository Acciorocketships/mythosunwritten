# Biomes, Atmosphere & Asset Backend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Named biomes with per-biome atmosphere/tint/particles on the field terrain, plus an asset-backend refactor (single catalog, placer, dead-code removal) per `docs/superpowers/specs/2026-07-04-biomes-atmosphere-design.md`.

**Architecture:** Refactor first (AssetCatalog + DecorationPlacer + TerrainMaterials; world visually identical except a one-time variant reshuffle), then pure biome fields + profiles, then visuals (vertex tint, instance-uniform foliage tint, AtmosphereDirector blend, fog pockets, particles). Everything deterministic per `(pos, world_seed)`; heightfield untouched (guarded by a golden-hash test).

**Tech Stack:** Godot 4 / GDScript, GUT tests. Godot binary: `/Applications/Godot.app/Contents/MacOS/Godot` (below: `$GODOT`).

**Two deliberate simplifications vs the spec** (both keep the schema, drop file noise):
1. Catalog data is a `const` dict inside `AssetCatalog.gd`, not `terrain/asset_catalog.tres` — diffable, matches project style.
2. Biome profiles are code-constructed in `BiomeRegistry.gd`, not five `.tres` files — same `BiomeProfile` resource class, export to `.tres` later if editor tuning is ever wanted.

**Project conventions (memorize):**
- Run one test file: `$GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/<file>.gd -gexit`
- After creating a NEW `class_name` script: `$GODOT --headless --path . --import` once (registers the class; otherwise tests can't resolve it).
- `*.uid` files are gitignored — never commit them. Stage specific files, never `git add -A`.
- Known baseline failure (not yours): `test_heightfield_interior_corners.gd`.

---

### Task 1: Golden heightfield guard

The whole plan must never change terrain shape. Bake a golden hash first.

**Files:**
- Test: `tests/test_heightfield_golden.gd` (create)

- [ ] **Step 1: Write the test (self-baking golden hash)**

```gdscript
extends GutTest
## Golden-hash guard for the biomes/asset-backend work: terrain SHAPE must not change.
## First run prints the hash; paste it into GOLDEN. If this ever fails afterwards,
## a refactor touched height math — fix the refactor, do NOT re-bake.

const SEED := 991177
const GOLDEN := ""   # baked in Step 3

func test_surface_hash_unchanged() -> void:
	var plan := HeightfieldPlan.new(SEED, 22.0, 8, "mean", 3)
	var water := WaterPlan.new(SEED, 22.0, 8)
	plan.set_water_plan(water)
	var acc := PackedFloat32Array()
	for cz in range(-24, 25, 4):
		for cx in range(-24, 25, 4):
			var region = plan.compute_region(cx, cz, 1)
			acc.append(TerrainSurfaceField.surface_y(region, float(cx) * 24.0, float(cz) * 24.0))
	var h := acc.to_byte_array().hex_encode().md5_text()
	if GOLDEN == "":
		gut.p("GOLDEN HASH: " + h)
		fail_test("first run — paste the printed hash into GOLDEN")
		return
	assert_eq(h, GOLDEN, "surface_y changed — this plan must not alter terrain shape")
```

- [ ] **Step 2: Run it — expect the baking failure and a printed hash**

Run: `$GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_heightfield_golden.gd -gexit`
Expected: 1 failing test, output contains `GOLDEN HASH: <32 hex chars>`.

- [ ] **Step 3: Paste the hash into `GOLDEN`, re-run — expect PASS**

- [ ] **Step 4: Commit**

```bash
git add tests/test_heightfield_golden.gd
git commit -m "test(terrain): golden surface hash guard for biome/asset refactor"
```

---

### Task 2: AssetCatalog

**Files:**
- Create: `scripts/core/AssetCatalog.gd`
- Test: `tests/test_asset_catalog.gd` (create)

- [ ] **Step 1: Write the failing test**

```gdscript
extends GutTest
## The single tag → scene mapping. Everything placement-related resolves through it.

func test_audit_is_clean() -> void:
	assert_eq(AssetCatalog.audit(), [], "every tag has ≥1 variant, every path loads, weights positive")

func test_expected_tags_exist() -> void:
	for tag in ["grass", "bush", "rock", "tree",
			"cliff_wall", "cliff_lip", "cliff_outer_wall", "cliff_outer_lip",
			"cliff_inner_wall", "cliff_inner_lip"]:
		assert_gt(AssetCatalog.variants(tag).size(), 0, "tag %s must have variants" % tag)
	# All existing KayKit variants wired (old dicts used only 2-3 of each).
	assert_eq(AssetCatalog.variants("grass").size(), 4)
	assert_eq(AssetCatalog.variants("bush").size(), 6)
	assert_eq(AssetCatalog.variants("rock").size(), 6)
	assert_eq(AssetCatalog.variants("tree").size(), 8)

func test_pick_is_cumulative_and_deterministic() -> void:
	var first: Dictionary = AssetCatalog.pick("tree", 0.0)
	var last: Dictionary = AssetCatalog.pick("tree", 0.9999)
	assert_eq(first["path"], AssetCatalog.variants("tree")[0]["path"])
	assert_eq(last["path"], AssetCatalog.variants("tree")[-1]["path"])
	assert_eq(AssetCatalog.pick("tree", 0.37), AssetCatalog.pick("tree", 0.37))

func test_scene_cache_returns_packed_scenes() -> void:
	for tag in AssetCatalog.tags():
		for v in AssetCatalog.variants(tag):
			assert_not_null(AssetCatalog.scene(v["path"]), "loads: " + v["path"])
```

- [ ] **Step 2: Run to verify it fails** — Expected: parse error / `AssetCatalog` not resolved.

- [ ] **Step 3: Implement `scripts/core/AssetCatalog.gd`**

```gdscript
# scripts/core/AssetCatalog.gd
# THE single tag → asset mapping (master design §11.11 indirection). Game code
# references tags, never res://assets paths. kind "scene" is the only kind today;
# "multimesh" is reserved so batching can be added without another refactor.
class_name AssetCatalog

const CATALOG := {
	"grass": {"kind": "scene", "variants": [
		{"path": "res://terrain/scenes/grass/Grass1.tscn", "weight": 1.0, "scale": 1.0},
		{"path": "res://terrain/scenes/grass/Grass2.tscn", "weight": 1.0, "scale": 1.0},
		{"path": "res://terrain/scenes/grass/Grass3.tscn", "weight": 1.0, "scale": 1.0},
		{"path": "res://terrain/scenes/grass/Grass4.tscn", "weight": 1.0, "scale": 1.0},
	]},
	"bush": {"kind": "scene", "variants": [
		{"path": "res://terrain/scenes/bush/Bush1.tscn", "weight": 1.0, "scale": 1.0},
		{"path": "res://terrain/scenes/bush/Bush2.tscn", "weight": 1.0, "scale": 1.0},
		{"path": "res://terrain/scenes/bush/Bush3.tscn", "weight": 1.0, "scale": 1.0},
		{"path": "res://terrain/scenes/bush/Bush4.tscn", "weight": 1.0, "scale": 1.0},
		{"path": "res://terrain/scenes/bush/Bush5.tscn", "weight": 1.0, "scale": 1.0},
		{"path": "res://terrain/scenes/bush/Bush6.tscn", "weight": 1.0, "scale": 1.0},
	]},
	"rock": {"kind": "scene", "variants": [
		{"path": "res://terrain/scenes/rock/Rock1.tscn", "weight": 1.0, "scale": 1.0},
		{"path": "res://terrain/scenes/rock/Rock2.tscn", "weight": 1.0, "scale": 1.0},
		{"path": "res://terrain/scenes/rock/Rock3.tscn", "weight": 1.0, "scale": 1.0},
		{"path": "res://terrain/scenes/rock/Rock4.tscn", "weight": 1.0, "scale": 1.0},
		{"path": "res://terrain/scenes/rock/Rock5.tscn", "weight": 1.0, "scale": 1.0},
		{"path": "res://terrain/scenes/rock/Rock6.tscn", "weight": 1.0, "scale": 1.0},
	]},
	"tree": {"kind": "scene", "variants": [
		{"path": "res://terrain/scenes/tree/Tree1.tscn", "weight": 1.0, "scale": 1.0},
		{"path": "res://terrain/scenes/tree/Tree2.tscn", "weight": 1.0, "scale": 1.0},
		{"path": "res://terrain/scenes/tree/Tree3.tscn", "weight": 1.0, "scale": 1.0},
		{"path": "res://terrain/scenes/tree/Tree4.tscn", "weight": 1.0, "scale": 1.0},
		{"path": "res://terrain/scenes/tree/Tree5.tscn", "weight": 1.0, "scale": 1.0},
		{"path": "res://terrain/scenes/tree/Tree6.tscn", "weight": 1.0, "scale": 1.0},
		{"path": "res://terrain/scenes/tree/Tree7.tscn", "weight": 1.0, "scale": 1.0},
		{"path": "res://terrain/scenes/tree/TreeBare1.tscn", "weight": 0.3, "scale": 1.0},
	]},
	"cliff_wall": {"kind": "scene", "variants": [
		{"path": "res://terrain/gltf/hill/hill_cliff_tall_h_side_color_12.tscn", "weight": 1.0, "scale": 1.0}]},
	"cliff_lip": {"kind": "scene", "variants": [
		{"path": "res://terrain/gltf/hill/hill_top_h_side_color_12.tscn", "weight": 1.0, "scale": 1.0}]},
	"cliff_outer_wall": {"kind": "scene", "variants": [
		{"path": "res://terrain/gltf/hill/hill_cliff_tall_i_outer_corner_color_12.tscn", "weight": 1.0, "scale": 1.0}]},
	"cliff_outer_lip": {"kind": "scene", "variants": [
		{"path": "res://terrain/gltf/hill/hill_top_i_outer_corner_color_12.tscn", "weight": 1.0, "scale": 1.0}]},
	"cliff_inner_wall": {"kind": "scene", "variants": [
		{"path": "res://terrain/gltf/hill/hill_cliff_tall_i_inner_corner_color_12.tscn", "weight": 1.0, "scale": 1.0}]},
	"cliff_inner_lip": {"kind": "scene", "variants": [
		{"path": "res://terrain/gltf/hill/hill_top_a_inner_corner_color_12.tscn", "weight": 1.0, "scale": 1.0}]},
}

static var _scene_cache: Dictionary = {}

static func tags() -> Array:
	return CATALOG.keys()

static func variants(tag: String) -> Array:
	return CATALOG.get(tag, {}).get("variants", [])

# Cumulative-weight pick; deterministic for a given roll ∈ [0,1).
static func pick(tag: String, roll01: float) -> Dictionary:
	var vs := variants(tag)
	if vs.is_empty():
		return {}
	var total := 0.0
	for v: Dictionary in vs:
		total += v["weight"]
	var acc := 0.0
	for v: Dictionary in vs:
		acc += v["weight"] / total
		if roll01 <= acc:
			return v
	return vs[-1]

static func scene(path: String) -> PackedScene:
	if not _scene_cache.has(path):
		_scene_cache[path] = load(path)
	return _scene_cache[path]

static func audit() -> Array:
	var problems: Array = []
	for tag: String in CATALOG:
		var vs := variants(tag)
		if vs.is_empty():
			problems.append("tag '%s' has no variants" % tag)
		for v: Dictionary in vs:
			if float(v.get("weight", 0.0)) <= 0.0:
				problems.append("%s: non-positive weight for %s" % [tag, v.get("path", "?")])
			if not ResourceLoader.exists(str(v.get("path", ""))):
				problems.append("%s: missing file %s" % [tag, v.get("path", "?")])
	return problems
```

Check actual filenames first (`Grass3` vs `Grass4`, `TreeBare1`): `ls terrain/scenes/grass terrain/scenes/tree terrain/scenes/bush terrain/scenes/rock` — if names differ (e.g. `Tree_Bare1.tscn`), fix the CATALOG paths **and** the counts in the test to match reality. The audit test is the referee.

- [ ] **Step 4: Register the class, run the test**

```bash
$GODOT --headless --path . --import
$GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_asset_catalog.gd -gexit
```
Expected: PASS (4/4).

- [ ] **Step 5: Commit**

```bash
git add scripts/core/AssetCatalog.gd tests/test_asset_catalog.gd
git commit -m "feat(assets): AssetCatalog — single tag→scene mapping with weighted variants"
```

---

### Task 3: Variant roll in scatter + DecorationPlacer; mesher stops instantiating

**Files:**
- Modify: `scripts/terrain/field/DecorationScatter.gd` (add `variant` roll)
- Create: `scripts/terrain/field/DecorationPlacer.gd`
- Modify: `scripts/terrain/field/TerrainChunkMesher.gd:29-34` (delete `FOLIAGE_SCENES`) and `:190-212` (replace decoration loop)
- Test: `tests/test_decoration_scatter.gd` (extend)

- [ ] **Step 1: Add the failing test to `tests/test_decoration_scatter.gd`**

```gdscript
func test_variant_roll_present_and_independent_of_yaw() -> void:
	var ds := DecorationScatter.cell_decorations(Vector2i(7, -3), 991177, 4.0)
	for d: Dictionary in ds:
		assert_true(d.has("variant"), "each decoration carries a variant roll")
		assert_between(d["variant"], 0.0, 1.0)
	# Determinism.
	assert_eq(ds, DecorationScatter.cell_decorations(Vector2i(7, -3), 991177, 4.0))
```

Run: `$GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_decoration_scatter.gd -gexit`
Expected: new test FAILS (`variant` missing); existing tests still pass.

- [ ] **Step 2: Add the roll in `DecorationScatter.cell_decorations`** — in the `out.append({...})` dict, after the `yaw` line:

```gdscript
				"variant": Helper._cell_hash01(world_seed + 6000 + i, cell.x, cell.y),
```

Run the file again — expected: PASS.

- [ ] **Step 3: Create `scripts/terrain/field/DecorationPlacer.gd`**

```gdscript
# scripts/terrain/field/DecorationPlacer.gd
# Final stage of the decoration pipeline:
#   DecorationScatter (position→tag) → AssetCatalog (tag→scene) → DecorationPlacer (scene→instances)
# Owns instantiation so the mesher builds geometry only.
class_name DecorationPlacer
extends RefCounted

const TILE := 24.0
const CELLS_PER_CHUNK := 8

static func build(region, chunk: Vector2i, world_seed: int) -> Node3D:
	var deco := Node3D.new()
	deco.name = "Decorations"
	for cz in range(chunk.y * CELLS_PER_CHUNK, chunk.y * CELLS_PER_CHUNK + CELLS_PER_CHUNK):
		for cx in range(chunk.x * CELLS_PER_CHUNK, chunk.x * CELLS_PER_CHUNK + CELLS_PER_CHUNK):
			var wc := Vector3(float(cx) * TILE, 0.0, float(cz) * TILE)
			if Helper.is_water(wc, world_seed):
				continue
			var sy := TerrainSurfaceField.surface_y(region, wc.x, wc.z)
			for d: Dictionary in DecorationScatter.cell_decorations(Vector2i(cx, cz), world_seed, sy):
				var v := AssetCatalog.pick(d["tag"], d["variant"])
				if v.is_empty():
					continue
				var inst: Node3D = AssetCatalog.scene(v["path"]).instantiate()
				# Sit each decoration on the surface at ITS OWN jittered position, not the
				# cell centre — cell-centre height differs from local height on slopes.
				var dp: Vector3 = d["pos"]
				inst.position = Vector3(dp.x, TerrainSurfaceField.surface_y(region, dp.x, dp.z), dp.z)
				inst.rotation.y = d["yaw"]
				if v["scale"] != 1.0:
					inst.scale = Vector3.ONE * float(v["scale"])
				deco.add_child(inst)
	return deco
```

- [ ] **Step 4: Slim the mesher**
  - Delete the `FOLIAGE_SCENES` const (lines 29–34).
  - Replace the whole decoration block (lines 190–212, from `# Decorations: scatter foliage...` through `root.add_child(deco)`) with:

```gdscript
	root.add_child(DecorationPlacer.build(region, chunk, _water_seed))
```

- [ ] **Step 5: Register + run the mesher/streamer/golden tests**

```bash
$GODOT --headless --path . --import
for f in test_terrain_chunk_mesher test_field_streamer test_decoration_scatter test_heightfield_golden; do \
  $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/$f.gd -gexit; done
```
Expected: all PASS. (Decoration *placement points* are unchanged; only which model variant appears changed — that reshuffle is the accepted one-time break from decoupling variants from yaw.)

- [ ] **Step 6: Commit**

```bash
git add scripts/terrain/field/DecorationScatter.gd scripts/terrain/field/DecorationPlacer.gd \
  scripts/terrain/field/TerrainChunkMesher.gd tests/test_decoration_scatter.gd
git commit -m "refactor(assets): DecorationPlacer + catalog picks; variant roll decoupled from yaw"
```

---

### Task 4: TerrainMaterials + CliffDressing through the catalog

**Files:**
- Create: `scripts/terrain/field/TerrainMaterials.gd`
- Modify: `scripts/terrain/field/CliffDressing.gd` (`SCENES` → catalog tags; `shared_material` moves out)
- Modify: `scripts/terrain/field/TerrainChunkMesher.gd:36-73` (`_ensure_skirt_style` shrinks)

- [ ] **Step 1: Create `scripts/terrain/field/TerrainMaterials.gd`**

```gdscript
# scripts/terrain/field/TerrainMaterials.gd
# One home for terrain material derivation (was split between
# CliffDressing.shared_material and TerrainChunkMesher._ensure_skirt_style).
class_name TerrainMaterials
extends RefCounted

static var _shared: Material = null
static var _ground_tinted: Material = null
static var _grass_uv := Vector2.INF

# THE shared de-sheened KayKit material: dressing pieces, skirt, aprons.
static func shared() -> Material:
	if _shared == null:
		CliffDressing._ensure_loaded()
		var mat: Material = (CliffDressing._pieces["wall"][0] as Mesh).surface_get_material(0)
		if mat is StandardMaterial3D:
			mat = mat.duplicate()
			mat.roughness = 1.0
			mat.metallic_specular = 0.0
		_shared = mat
	return _shared

# Grass texel UV sampled from the lip piece's top face, so the walkable sheet
# matches the lip grass exactly (owner round 8: one texture for everything).
static func grass_uv() -> Vector2:
	if _grass_uv == Vector2.INF:
		CliffDressing._ensure_loaded()
		_grass_uv = Vector2.ZERO
		var lip_mesh: Mesh = CliffDressing._pieces["lip"][0]
		var arr := lip_mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
		for i in verts.size():
			if norms[i].y > 0.9 and verts[i].y > -0.05:
				_grass_uv = uvs[i]
				break
	return _grass_uv

# Walkable-sheet duplicate with per-vertex biome tint enabled (Task 9 writes the colors).
static func ground_tinted() -> Material:
	if _ground_tinted == null:
		var mat := shared()
		if mat is StandardMaterial3D:
			mat = mat.duplicate()
			mat.vertex_color_use_as_albedo = true
			_ground_tinted = mat
		else:
			_ground_tinted = mat
	return _ground_tinted
```

- [ ] **Step 2: Rewire `CliffDressing.gd`**
  - Replace the `SCENES` const (lines 13–20) with:

```gdscript
const PIECE_TAGS := {
	"wall": "cliff_wall", "lip": "cliff_lip",
	"outer_wall": "cliff_outer_wall", "outer_lip": "cliff_outer_lip",
	"inner_wall": "cliff_inner_wall", "inner_lip": "cliff_inner_lip",
}
```

  - In `_ensure_loaded()` replace the loop body:

```gdscript
static func _ensure_loaded() -> void:
	if _pieces.is_empty():
		for key: String in PIECE_TAGS:
			var v := AssetCatalog.pick(PIECE_TAGS[key], 0.0)
			_pieces[key] = _piece(v["path"])
```

  - In `_piece()`, swap `load(path) as PackedScene` for `AssetCatalog.scene(path)`.
  - Replace the body of `shared_material()` with a delegation (callers elsewhere keep working):

```gdscript
static func shared_material() -> Material:
	return TerrainMaterials.shared()
```

  - Delete the now-unused `static var _shared_mat` line.

- [ ] **Step 3: Shrink the mesher's `_ensure_skirt_style` (lines 45–73) to:**

```gdscript
func _ensure_skirt_style() -> void:
	if _skirt_material != null:
		return
	_skirt_material = TerrainMaterials.shared()
	if _skirt_material == null:
		_skirt_material = _material
		_skirt_uv = _cliff_uv
		return
	_skirt_uv = Vector2.ZERO
	_material = _skirt_material
	_grass_uv = TerrainMaterials.grass_uv()
```

(Keep the `_material`/`_grass_uv`/`_skirt_uv` vars and their declarations at lines 36–43 as-is.)

- [ ] **Step 4: Register + run**

```bash
$GODOT --headless --path . --import
for f in test_cliff_dressing test_terrain_chunk_mesher test_field_streamer test_heightfield_golden; do \
  $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/$f.gd -gexit; done
```
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/field/TerrainMaterials.gd scripts/terrain/field/CliffDressing.gd \
  scripts/terrain/field/TerrainChunkMesher.gd
git commit -m "refactor(assets): cliff pieces via catalog; TerrainMaterials owns material derivation"
```

---

### Task 5: Dead code removal

Verified orphans (grep shows zero non-self references): `terrain/scenes/hill/`, `terrain/scenes/base/`, `terrain/materials/forest.tres`, `scripts/core/TagList.gd`, `scripts/core/Distribution.gd`, and `Helper.biome_weights` (only its own tests reference it — Task 8 rewrites those tests anyway; delete the function there, not here).

- [ ] **Step 1: Re-verify then delete**

```bash
grep -rn "scenes/hill\|scenes/base\|forest.tres\|TagList\|Distribution" scripts/ scenes/ tests/ --include="*.gd" --include="*.tscn" | grep -v "core/TagList.gd\|core/Distribution.gd"
```
Expected: no output. Then:

```bash
git rm -r terrain/scenes/hill terrain/scenes/base
git rm terrain/materials/forest.tres scripts/core/TagList.gd scripts/core/Distribution.gd
git rm --ignore-unmatch tests/test_priority_queue.gd 2>/dev/null; git checkout tests/test_priority_queue.gd 2>/dev/null || true
```
(That last line is a no-op guard: `PriorityQueue.gd` stays — it is used by water tracing. Only remove Distribution/TagList.)
If `Distribution`/`TagList` have test files (`ls tests/ | grep -i "distribution\|taglist"`), `git rm` those too.

- [ ] **Step 2: Full suite + commit**

```bash
$GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json -gexit
```
Expected: green except the known baseline failure (`test_heightfield_interior_corners.gd`). Prefer isolated re-runs if the full suite is flaky.

```bash
git commit -m "chore(assets): delete orphaned socket-era scenes, materials, and helpers"
```

---

### Task 6: Biome fields + five-way resolver

**Files:**
- Modify: `scripts/core/Helper.gd` (after `biome_rocky01`, line ~114)
- Test: `tests/test_biomes.gd` (extend; full rewrite comes in Task 8)

- [ ] **Step 1: Write failing tests (append to `tests/test_biomes.gd`)**

```gdscript
func test_weights5_normalized_and_deterministic() -> void:
	var s := 991177
	for i in range(48):
		var p := Vector3(i * 311.0 - 7000.0, 0.0, i * -173.0 + 2000.0)
		var w := Helper.biome_weights5(p, s)
		assert_eq(w.size(), 5)
		var total := 0.0
		for k: StringName in w:
			assert_between(w[k], 0.0, 1.0, "weight %s in range" % k)
			total += w[k]
		assert_almost_eq(total, 1.0, 1e-5, "weights sum to 1")
		assert_eq(w, Helper.biome_weights5(p, s), "deterministic")

func test_biome_at_is_argmax() -> void:
	var s := 991177
	var p := Vector3(1234.0, 0.0, -987.0)
	var w := Helper.biome_weights5(p, s)
	var best: StringName = &""
	var best_w := -1.0
	for k: StringName in w:
		if w[k] > best_w:
			best_w = w[k]
			best = k
	assert_eq(Helper.biome_at(p, s), best)

func test_pocket_census() -> void:
	var s := 991177
	var marsh := 0
	var blossom := 0
	var n := 0
	for iz in range(60):
		for ix in range(60):
			var p := Vector3(ix * 210.0 - 6300.0, 0.0, iz * 210.0 - 6300.0)
			n += 1
			match Helper.biome_at(p, s):
				&"twilight_marsh": marsh += 1
				&"blossom_grove": blossom += 1
	assert_between(float(marsh) / float(n), 0.01, 0.06, "marsh pockets ~2-4%% of area")
	assert_between(float(blossom) / float(n), 0.02, 0.08, "blossom groves ~4-6%% of area")
```

Run: expected FAIL (`biome_weights5` not defined).

- [ ] **Step 2: Implement in `Helper.gd` (insert after `biome_rocky01`)**

```gdscript
const BIOME_MOISTURE_SCALE: float = 230.0
const BIOME_BLOSSOM_SCALE: float = 260.0
const BIOME_MARSH_SCALE: float = 300.0
const BIOME_NAMES: Array[StringName] = [
	&"meadow", &"deep_forest", &"highland", &"blossom_grove", &"twilight_marsh",
]

# Moisture/mood axis (master §11.2): wet side boosts marsh; later gates reeds
# and decorative meadow ponds.
static func biome_moisture01(pos: Vector3, world_seed: int) -> float:
	return _value_noise01(pos, world_seed + 41, BIOME_MOISTURE_SCALE)

# Sparse pocket fields: high smoothstep thresholds carve isolated cores.
static func biome_blossom_pocket01(pos: Vector3, world_seed: int) -> float:
	return smoothstep(0.78, 0.90, _value_noise01(pos, world_seed + 43, BIOME_BLOSSOM_SCALE))

static func biome_marsh_pocket01(pos: Vector3, world_seed: int) -> float:
	var n := _value_noise01(pos, world_seed + 47, BIOME_MARSH_SCALE)
	return smoothstep(0.82, 0.92, n + 0.15 * biome_moisture01(pos, world_seed))

# Five normalized biome weights. Pockets claim their share first (their cores
# saturate and suppress the rest); forest/rocky split what remains; meadow is
# the leftover baseline — ≥ 0 by construction, so weights always sum to 1.
static func biome_weights5(pos: Vector3, world_seed: int) -> Dictionary:
	var marsh := biome_marsh_pocket01(pos, world_seed)
	var blossom := biome_blossom_pocket01(pos, world_seed) * (1.0 - marsh)
	var rest := 1.0 - marsh - blossom
	var f01 := biome_forest01(pos, world_seed)
	var r01 := biome_rocky01(pos, world_seed)
	var forest := f01 * rest
	var highland := r01 * (1.0 - f01) * rest
	var meadow := rest - forest - highland
	return {
		&"meadow": meadow, &"deep_forest": forest, &"highland": highland,
		&"blossom_grove": blossom, &"twilight_marsh": marsh,
	}

# Dominant biome — for discrete choices only (fog volumes, F3 readout, prop sets).
static func biome_at(pos: Vector3, world_seed: int) -> StringName:
	var w := biome_weights5(pos, world_seed)
	var best: StringName = &"meadow"
	var best_w := -1.0
	for k: StringName in w:
		if w[k] > best_w:
			best_w = w[k]
			best = k
	return best
```

- [ ] **Step 3: Run the file.** If only the census bounds fail, tune thresholds — marsh too rare → lower `0.82`; too common → raise it (same for blossom's `0.78`); re-run until in-band. Everything else must pass untouched.

- [ ] **Step 4: Commit**

```bash
git add scripts/core/Helper.gd tests/test_biomes.gd
git commit -m "feat(biomes): moisture axis, pocket fields, five-way biome resolver"
```

---

### Task 7: BiomeProfile + BiomeRegistry

**Files:**
- Create: `scripts/terrain/biome/BiomeProfile.gd`, `scripts/terrain/biome/BiomeRegistry.gd`
- Test: `tests/test_biome_registry.gd` (create)

- [ ] **Step 1: Write the failing test**

```gdscript
extends GutTest

func test_all_five_profiles_load_complete() -> void:
	for name: StringName in Helper.BIOME_NAMES:
		var p := BiomeRegistry.profile(name)
		assert_not_null(p, "profile %s exists" % name)
		assert_eq(p.biome_name, name)
		assert_gt(p.fog_density, 0.0)
		assert_gt(p.ambient_energy, 0.0)
		assert_gt(p.foliage_density, 0.0)
		assert_gt(p.tag_weights.size(), 0)
		assert_ne(p.ground_tint, Color.WHITE, "ground tint must be set, not default white")

func test_blend_atmosphere_endpoints_and_midpoint() -> void:
	var pure := {&"meadow": 1.0, &"deep_forest": 0.0, &"highland": 0.0,
			&"blossom_grove": 0.0, &"twilight_marsh": 0.0}
	var a := BiomeRegistry.blend_atmosphere(pure)
	var meadow := BiomeRegistry.profile(&"meadow")
	assert_almost_eq(a[&"fog_density"], meadow.fog_density, 1e-6)
	assert_eq(a[&"fog_color"], meadow.fog_color)
	var half := {&"meadow": 0.5, &"deep_forest": 0.0, &"highland": 0.0,
			&"blossom_grove": 0.0, &"twilight_marsh": 0.5}
	var marsh := BiomeRegistry.profile(&"twilight_marsh")
	var m := BiomeRegistry.blend_atmosphere(half)
	assert_almost_eq(m[&"fog_density"], (meadow.fog_density + marsh.fog_density) * 0.5, 1e-6)

func test_blended_scatter_helpers() -> void:
	var pure_forest := {&"meadow": 0.0, &"deep_forest": 1.0, &"highland": 0.0,
			&"blossom_grove": 0.0, &"twilight_marsh": 0.0}
	var tw := BiomeRegistry.blended_tag_weights(pure_forest)
	assert_gt(tw["tree"], tw["rock"], "deep forest favours trees")
	assert_almost_eq(BiomeRegistry.blended_density(pure_forest),
			BiomeRegistry.profile(&"deep_forest").foliage_density, 1e-6)
```

- [ ] **Step 2: Create `scripts/terrain/biome/BiomeProfile.gd`**

```gdscript
# scripts/terrain/biome/BiomeProfile.gd
# Everything downstream reads about one biome: atmosphere, palette, scatter,
# particles. Constructed in code by BiomeRegistry (spec deviation: no .tres
# files until editor tuning is wanted — same schema).
class_name BiomeProfile
extends Resource

@export var biome_name: StringName
# atmosphere
@export var fog_color: Color
@export var fog_density: float
@export var pocket_fog_density: float = 0.0   # >0 ⇒ chunk FogVolumes when dominant
@export var sky_top: Color
@export var sky_horizon: Color
@export var ambient_color: Color
@export var ambient_energy: float = 1.0
# palette — MULTIPLIERS over the shared KayKit grass texel, not absolute colors
@export var ground_tint: Color
@export var foliage_tints: Dictionary = {}    # tag (String) → Color multiplier
# scatter
@export var foliage_density: float = 1.0
@export var tag_weights: Dictionary = {}      # tag (String) → weight
# particles: recipe → density (marsh carries two: orbs + fireflies)
@export var particles: Dictionary = {}        # StringName → float
```

- [ ] **Step 3: Create `scripts/terrain/biome/BiomeRegistry.gd`**

```gdscript
# scripts/terrain/biome/BiomeRegistry.gd
# Profile lookup + pure blending helpers (unit-testable, no scene tree).
class_name BiomeRegistry
extends RefCounted

static var _profiles: Dictionary = {}

static func profile(name: StringName) -> BiomeProfile:
	_ensure()
	return _profiles.get(name)

static func blend_atmosphere(w: Dictionary) -> Dictionary:
	_ensure()
	var fog := Color(0, 0, 0, 0)
	var sky_t := Color(0, 0, 0, 0)
	var sky_h := Color(0, 0, 0, 0)
	var amb := Color(0, 0, 0, 0)
	var fd := 0.0
	var ae := 0.0
	for name: StringName in w:
		var p: BiomeProfile = _profiles[name]
		var k: float = w[name]
		fog += p.fog_color * k
		sky_t += p.sky_top * k
		sky_h += p.sky_horizon * k
		amb += p.ambient_color * k
		fd += p.fog_density * k
		ae += p.ambient_energy * k
	return {&"fog_color": fog, &"fog_density": fd, &"sky_top": sky_t,
			&"sky_horizon": sky_h, &"ambient_color": amb, &"ambient_energy": ae}

static func blended_density(w: Dictionary) -> float:
	_ensure()
	var d := 0.0
	for name: StringName in w:
		d += (_profiles[name] as BiomeProfile).foliage_density * w[name]
	return d

static func blended_tag_weights(w: Dictionary) -> Dictionary:
	_ensure()
	var out: Dictionary = {}
	for name: StringName in w:
		var p: BiomeProfile = _profiles[name]
		for tag: String in p.tag_weights:
			out[tag] = out.get(tag, 0.0) + p.tag_weights[tag] * w[name]
	return out

static func blended_ground_tint(w: Dictionary) -> Color:
	_ensure()
	var c := Color(0, 0, 0, 0)
	for name: StringName in w:
		c += (_profiles[name] as BiomeProfile).ground_tint * w[name]
	return c

static func blended_foliage_tint(w: Dictionary, tag: String) -> Color:
	_ensure()
	var c := Color(0, 0, 0, 0)
	for name: StringName in w:
		var p: BiomeProfile = _profiles[name]
		c += (p.foliage_tints.get(tag, Color(1, 1, 1)) as Color) * w[name]
	return c

static func _ensure() -> void:
	if not _profiles.is_empty():
		return
	for p: BiomeProfile in [_meadow(), _deep_forest(), _highland(), _blossom_grove(), _twilight_marsh()]:
		_profiles[p.biome_name] = p

static func _make(name: StringName) -> BiomeProfile:
	var p := BiomeProfile.new()
	p.biome_name = name
	return p

static func _meadow() -> BiomeProfile:
	var p := _make(&"meadow")
	p.fog_color = Color("dcebdd")
	p.fog_density = 0.0008
	p.sky_top = Color("8ec9e8")
	p.sky_horizon = Color("d7e8f2")
	p.ambient_color = Color(0.72, 0.70, 0.62)
	p.ambient_energy = 0.9
	p.ground_tint = Color(1.05, 1.0, 0.85)
	p.foliage_tints = {"grass": Color(1.05, 1.0, 0.8), "bush": Color(1.0, 1.0, 0.9),
			"tree": Color(1.0, 1.0, 0.95), "rock": Color(1, 1, 1)}
	p.foliage_density = 0.8
	p.tag_weights = {"grass": 0.45, "rock": 0.1, "bush": 0.2, "tree": 0.15}
	p.particles = {&"motes": 0.3}
	return p

static func _deep_forest() -> BiomeProfile:
	var p := _make(&"deep_forest")
	p.fog_color = Color("557567")
	p.fog_density = 0.004
	p.pocket_fog_density = 0.015
	p.sky_top = Color("6e93a8")
	p.sky_horizon = Color("87a5ad")
	p.ambient_color = Color(0.45, 0.52, 0.48)
	p.ambient_energy = 0.7
	p.ground_tint = Color(0.55, 0.75, 0.55)
	p.foliage_tints = {"grass": Color(0.6, 0.8, 0.6), "bush": Color(0.55, 0.75, 0.55),
			"tree": Color(0.6, 0.8, 0.62), "rock": Color(0.85, 0.9, 0.85)}
	p.foliage_density = 1.9
	p.tag_weights = {"grass": 0.15, "rock": 0.08, "bush": 0.22, "tree": 0.55}
	p.particles = {&"fireflies": 0.4}
	return p

static func _highland() -> BiomeProfile:
	var p := _make(&"highland")
	p.fog_color = Color("c2ccc9")
	p.fog_density = 0.0015
	p.sky_top = Color("a8bcc8")
	p.sky_horizon = Color("ccd6da")
	p.ambient_color = Color(0.60, 0.63, 0.60)
	p.ambient_energy = 0.85
	p.ground_tint = Color(0.85, 0.9, 0.8)
	p.foliage_tints = {"grass": Color(0.85, 0.9, 0.75), "bush": Color(0.8, 0.85, 0.72),
			"tree": Color(0.8, 0.88, 0.78), "rock": Color(1, 1, 1)}
	p.foliage_density = 1.2
	p.tag_weights = {"grass": 0.2, "rock": 0.45, "bush": 0.12, "tree": 0.08,
			"standing_stone": 0.03}
	p.particles = {&"motes": 0.2}
	return p

static func _blossom_grove() -> BiomeProfile:
	var p := _make(&"blossom_grove")
	p.fog_color = Color("f2dce8")
	p.fog_density = 0.0015
	p.sky_top = Color("c8d8f0")
	p.sky_horizon = Color("ecdce8")
	p.ambient_color = Color(0.75, 0.68, 0.70)
	p.ambient_energy = 0.9
	p.ground_tint = Color(1.0, 0.95, 0.9)
	p.foliage_tints = {"grass": Color(1.0, 0.95, 0.85), "bush": Color(1.05, 0.85, 0.95),
			"tree": Color(1.35, 0.85, 1.05), "rock": Color(1, 1, 1)}   # pink canopies
	p.foliage_density = 1.1
	p.tag_weights = {"grass": 0.3, "rock": 0.05, "bush": 0.15, "tree": 0.45}
	p.particles = {&"petals": 0.6}
	return p

static func _twilight_marsh() -> BiomeProfile:
	var p := _make(&"twilight_marsh")
	p.fog_color = Color("24505c")
	p.fog_density = 0.012
	p.pocket_fog_density = 0.06
	p.sky_top = Color("2a3560")
	p.sky_horizon = Color("24505c")
	p.ambient_color = Color(0.30, 0.35, 0.45)
	p.ambient_energy = 0.55
	p.ground_tint = Color(0.45, 0.6, 0.55)
	p.foliage_tints = {"grass": Color(0.4, 0.6, 0.55), "bush": Color(0.35, 0.55, 0.5),
			"tree": Color(0.4, 0.55, 0.5), "rock": Color(0.7, 0.8, 0.8)}
	p.foliage_density = 0.9
	p.tag_weights = {"grass": 0.35, "rock": 0.08, "bush": 0.3, "tree": 0.1, "lantern": 0.02}
	p.particles = {&"orbs": 0.5, &"fireflies": 0.8}
	return p
```

Note: `lantern` and `standing_stone` tags don't exist in the catalog yet — `AssetCatalog.pick` returns `{}` for them and the placer skips (already handled). Task 12b adds the assets.

- [ ] **Step 4: Register + run**

```bash
$GODOT --headless --path . --import
$GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_biome_registry.gd -gexit
```
Expected: PASS (3/3).

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/biome/BiomeProfile.gd scripts/terrain/biome/BiomeRegistry.gd tests/test_biome_registry.gd
git commit -m "feat(biomes): BiomeProfile + BiomeRegistry with five code-built profiles"
```

---

### Task 8: Scatter composition through profiles

**Files:**
- Modify: `scripts/terrain/field/DecorationScatter.gd` (drop `TAG_WEIGHTS`, use registry)
- Modify: `scripts/core/Helper.gd` (delete `biome_weights` + `biome_foliage_density`)
- Modify: `tests/test_biomes.gd` (rewrite the two legacy tests)

- [ ] **Step 1: Rewire `DecorationScatter.cell_decorations`** — replace the `density` line (19) and the tag pick:

```gdscript
	var w5 := Helper.biome_weights5(world, world_seed)
	var density: float = BiomeRegistry.blended_density(w5)   # ~0.8..1.9
```
and change `_pick_tag(ht)` → `_pick_tag(ht, BiomeRegistry.blended_tag_weights(w5))`, delete the `TAG_WEIGHTS` const, and make `_pick_tag` take the dict:

```gdscript
static func _pick_tag(roll: float, weights: Dictionary) -> String:
	var total := 0.0
	for w: float in weights.values():
		total += w
	if total <= 0.0:
		return "grass"
	var acc := 0.0
	for tag: String in weights:
		acc += weights[tag] / total
		if roll <= acc:
			return tag
	return "grass"
```

- [ ] **Step 2: Delete `Helper.biome_weights` (lines 116–138) and `Helper.biome_foliage_density` (lines 141–151)** — both now superseded by registry blends; grep confirms no other callers:

```bash
grep -rn "biome_weights\b\|biome_foliage_density" scripts/ tests/ --include="*.gd"
```
Expected after edit: only `test_biomes.gd` hits (fixed next step).

- [ ] **Step 3: Rewrite the two legacy tests in `tests/test_biomes.gd`** — replace `test_biome_fields_deterministic_and_varying` and `test_biome_weights_shape` bodies:

```gdscript
func test_biome_fields_deterministic_and_varying() -> void:
	var world_seed: int = 99
	var pos: Vector3 = Vector3(300, 0, -120)
	assert_eq(Helper.biome_weights5(pos, world_seed), Helper.biome_weights5(pos, world_seed))
	var min_forest: float = 1.0
	var max_forest: float = 0.0
	for i in range(64):
		var p: Vector3 = Vector3(i * 97.0, 0.0, i * -53.0)
		var f: float = Helper.biome_forest01(p, world_seed)
		min_forest = minf(min_forest, f)
		max_forest = maxf(max_forest, f)
	assert_gt(max_forest - min_forest, 0.5, "forest field should span a wide range")

func test_biome_composition_shifts_with_fields() -> void:
	var world_seed: int = 7
	var forest_pos: Vector3 = Vector3.INF
	var rocky_pos: Vector3 = Vector3.INF
	for i in range(4000):
		var p: Vector3 = Vector3((i % 64) * 53.0, 0.0, (i / 64) * 47.0)
		if forest_pos == Vector3.INF and Helper.biome_forest01(p, world_seed) > 0.9 \
				and Helper.biome_rocky01(p, world_seed) < 0.3:
			forest_pos = p
		if rocky_pos == Vector3.INF and Helper.biome_rocky01(p, world_seed) > 0.9 \
				and Helper.biome_forest01(p, world_seed) < 0.3:
			rocky_pos = p
		if forest_pos != Vector3.INF and rocky_pos != Vector3.INF:
			break
	assert_ne(forest_pos, Vector3.INF)
	assert_ne(rocky_pos, Vector3.INF)
	var fw := BiomeRegistry.blended_tag_weights(Helper.biome_weights5(forest_pos, world_seed))
	var rw := BiomeRegistry.blended_tag_weights(Helper.biome_weights5(rocky_pos, world_seed))
	assert_gt(fw["tree"], rw["tree"], "forests favour trees")
	assert_gt(rw["rock"], fw["rock"], "highlands favour rocks")
	assert_gt(BiomeRegistry.blended_density(Helper.biome_weights5(forest_pos, world_seed)), 1.0)
```

- [ ] **Step 4: Run** `test_biomes`, `test_decoration_scatter`, `test_field_streamer`, `test_heightfield_golden` — all PASS. (If `test_decoration_scatter.gd` references the deleted `TAG_WEIGHTS` const anywhere, replace that assertion with `BiomeRegistry.blended_tag_weights(Helper.biome_weights5(Vector3.ZERO, <seed>))` equivalents.)

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/field/DecorationScatter.gd scripts/core/Helper.gd tests/test_biomes.gd tests/test_decoration_scatter.gd
git commit -m "feat(biomes): scatter composition + density driven by biome profiles"
```

---

### Task 9: Ground vertex tint

**Files:**
- Modify: `scripts/terrain/field/TerrainChunkMesher.gd` (`build_chunk` grid loop, `_tri`, sheet material)

- [ ] **Step 1: Precompute the tint grid** — in `build_chunk`, right before the `for iz in GRID:` loop:

```gdscript
	# Per-vertex biome ground tint (multiplier over the grass texel). Sampled on
	# the shared (GRID+1)² lattice so adjacent chunks tint identically at seams.
	var tints: Array[Color] = []
	tints.resize((GRID + 1) * (GRID + 1))
	for tz in GRID + 1:
		for tx in GRID + 1:
			var tw := Vector3(o.x + tx * STEP, 0.0, o.y + tz * STEP)
			tints[tz * (GRID + 1) + tx] = BiomeRegistry.blended_ground_tint(
					Helper.biome_weights5(tw, _water_seed))
```

- [ ] **Step 2: Add a tinted triangle helper next to `_tri` (line ~251)**

```gdscript
func _tri_tinted(st: SurfaceTool, vs: Array, uv: Vector2, cs: Array) -> void:
	for i in 3:
		st.set_uv(uv)
		st.set_color(cs[i])
		st.add_vertex(vs[i])
```

- [ ] **Step 3: Use it for the VISUAL sheet only** — replace the two `_tri(st, c00, ...)` calls (lines ~127–128):

```gdscript
				var t00: Color = tints[iz * (GRID + 1) + ix]
				var t10: Color = tints[iz * (GRID + 1) + ix + 1]
				var t11: Color = tints[(iz + 1) * (GRID + 1) + ix + 1]
				var t01: Color = tints[(iz + 1) * (GRID + 1) + ix]
				_tri_tinted(st, [c00, c10, c11], uv, [t00, t10, t11])
				_tri_tinted(st, [c00, c11, c01], uv, [t00, t11, t01])
```
Collision sheet (`stc`), skirt, and aprons keep plain `_tri` — untinted.

- [ ] **Step 4: Point the visual sheet at the tinted material** — find where the visual sheet mesh gets its material in `build_chunk` (the `st.set_material(_material)` / surface-material call for the "Surface" MeshInstance3D) and replace `_material` with `TerrainMaterials.ground_tinted()`.

- [ ] **Step 5: Run** `test_terrain_chunk_mesher`, `test_field_streamer`, `test_heightfield_golden` — all PASS. Launch the editor/game briefly (`$GODOT --path . &`) and confirm ground color shifts between regions (forest darker, highland grey-green).

- [ ] **Step 6: Commit**

```bash
git add scripts/terrain/field/TerrainChunkMesher.gd
git commit -m "feat(biomes): per-vertex biome ground tint on the walkable sheet"
```

---

### Task 10: Foliage tint (instance uniform)

**Files:**
- Create: `terrain/materials/foliage_tint.gdshader`
- Modify: `scripts/terrain/field/TerrainMaterials.gd` (add `foliage_material()`)
- Modify: `scripts/terrain/field/DecorationPlacer.gd` (apply override + tint)

- [ ] **Step 1: Create `terrain/materials/foliage_tint.gdshader`**

```glsl
shader_type spatial;
// Shared foliage material: KayKit palette texture × per-instance biome tint.
uniform sampler2D albedo_tex : source_color;
instance uniform vec3 tint : source_color = vec3(1.0);

void fragment() {
	ALBEDO = texture(albedo_tex, UV).rgb * tint;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
```

- [ ] **Step 2: Add to `TerrainMaterials.gd`**

```gdscript
static var _foliage: ShaderMaterial = null

# One ShaderMaterial for ALL foliage (batch-friendly); per-instance biome tint
# via instance uniform. Blossom trees = KayKit trees with pink canopy tint.
static func foliage_material() -> ShaderMaterial:
	if _foliage == null:
		_foliage = ShaderMaterial.new()
		_foliage.shader = load("res://terrain/materials/foliage_tint.gdshader")
		var base := shared()
		if base is StandardMaterial3D:
			_foliage.set_shader_parameter("albedo_tex", (base as StandardMaterial3D).albedo_texture)
	return _foliage
```

- [ ] **Step 3: Apply in `DecorationPlacer.build`** — after `inst.rotation.y = d["yaw"]`:

```gdscript
				var tint := BiomeRegistry.blended_foliage_tint(
						Helper.biome_weights5(dp, world_seed), d["tag"])
				_apply_tint(inst, tint)
```
and add at the bottom of the class:

```gdscript
static func _apply_tint(node: Node, tint: Color) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		mi.material_override = TerrainMaterials.foliage_material()
		mi.set_instance_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	for c in node.get_children():
		_apply_tint(c, tint)
```

- [ ] **Step 4: Run** `test_field_streamer` + `test_terrain_chunk_mesher` (PASS), then eyeball in-game: trees in blossom pockets are pink, marsh flora is dark teal.

- [ ] **Step 5: Commit**

```bash
git add terrain/materials/foliage_tint.gdshader scripts/terrain/field/TerrainMaterials.gd scripts/terrain/field/DecorationPlacer.gd
git commit -m "feat(biomes): per-instance foliage tint via shared shader material"
```

---

### Task 11: AtmosphereDirector + global grade

**Files:**
- Create: `scripts/terrain/biome/AtmosphereDirector.gd`
- Modify: `scenes/world.tscn` (add node + wire paths)

- [ ] **Step 1: Create `scripts/terrain/biome/AtmosphereDirector.gd`**

```gdscript
# scripts/terrain/biome/AtmosphereDirector.gd
# Applies the fixed-time global grade once, then continuously eases fog/sky/
# ambient toward the biome blend at the player position. Master §11.9 / spec §3+§6.
class_name AtmosphereDirector
extends Node

@export var environment_node: WorldEnvironment
@export var sun: DirectionalLight3D
@export var camera: Camera3D
@export var streamer: FieldTerrainStreamer
@export var player: Node3D

const SAMPLE_INTERVAL := 0.2
const EASE_SPEED := 1.5          # fraction of remaining distance per second

# — the global grade, one place to tune —
const SUN_COLOR := Color("ffeacc")
const SUN_ENERGY := 1.3
const SUN_ANGLE_DEG := Vector3(-35.0, 40.0, 0.0)   # low golden hour
const GLOW_BLOOM := 0.15
const GLOW_HDR_THRESHOLD := 1.05
const DOF_FAR_DISTANCE := 220.0
const DOF_FAR_TRANSITION := 120.0
const DOF_NEAR_DISTANCE := 6.0
const DOF_NEAR_TRANSITION := 4.0
const DOF_AMOUNT := 0.08

var _accum := SAMPLE_INTERVAL   # sample immediately on first frame
var _target: Dictionary = {}

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	_apply_grade()

func _apply_grade() -> void:
	var env := environment_node.environment
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_bloom = GLOW_BLOOM
	env.glow_hdr_threshold = GLOW_HDR_THRESHOLD
	env.fog_enabled = true
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.0    # pockets only (FogVolumes)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sun.light_color = SUN_COLOR
	sun.light_energy = SUN_ENERGY
	sun.rotation_degrees = SUN_ANGLE_DEG
	var attrs := CameraAttributesPractical.new()
	attrs.dof_blur_far_enabled = true
	attrs.dof_blur_far_distance = DOF_FAR_DISTANCE
	attrs.dof_blur_far_transition = DOF_FAR_TRANSITION
	attrs.dof_blur_near_enabled = true
	attrs.dof_blur_near_distance = DOF_NEAR_DISTANCE
	attrs.dof_blur_near_transition = DOF_NEAR_TRANSITION
	attrs.dof_blur_amount = DOF_AMOUNT
	camera.attributes = attrs

func _process(dt: float) -> void:
	if streamer == null or streamer.world_seed == 0 or player == null:
		return
	_accum += dt
	if _accum >= SAMPLE_INTERVAL:
		_accum = 0.0
		_target = BiomeRegistry.blend_atmosphere(
				Helper.biome_weights5(player.global_position, streamer.world_seed))
	if _target.is_empty():
		return
	var k := clampf(EASE_SPEED * dt, 0.0, 1.0)
	var env := environment_node.environment
	env.fog_light_color = env.fog_light_color.lerp(_target[&"fog_color"], k)
	env.fog_density = lerpf(env.fog_density, _target[&"fog_density"], k)
	env.ambient_light_color = env.ambient_light_color.lerp(_target[&"ambient_color"], k)
	env.ambient_light_energy = lerpf(env.ambient_light_energy, _target[&"ambient_energy"], k)
	var sky_mat := env.sky.sky_material as ProceduralSkyMaterial
	sky_mat.sky_top_color = sky_mat.sky_top_color.lerp(_target[&"sky_top"], k)
	sky_mat.sky_horizon_color = sky_mat.sky_horizon_color.lerp(_target[&"sky_horizon"], k)
```

- [ ] **Step 2: Wire into `scenes/world.tscn`** — add an ext_resource + node (adjust the id to the next free one in the file):

```
[ext_resource type="Script" path="res://scripts/terrain/biome/AtmosphereDirector.gd" id="30_atmo"]
```
and after the `FieldTerrain` node:

```
[node name="AtmosphereDirector" type="Node" parent="." node_paths=PackedStringArray("environment_node", "sun", "camera", "streamer", "player")]
script = ExtResource("30_atmo")
environment_node = NodePath("../WorldEnvironment")
sun = NodePath("../DirectionalLight3D")
camera = NodePath("../Camera3D")
streamer = NodePath("../FieldTerrain")
player = NodePath("../Characters/Character")
```

- [ ] **Step 3: Register class + verify** — `$GODOT --headless --path . --import`, then run the game and walk from meadow toward a forest core: fog/ambient/sky ease over ~1 s; bloom + DoF visibly on. Headless suite still green (`test_field_streamer`).

- [ ] **Step 4: Commit**

```bash
git add scripts/terrain/biome/AtmosphereDirector.gd scenes/world.tscn
git commit -m "feat(atmosphere): fixed-time grade + camera-blended per-biome fog/sky/ambient"
```

---

### Task 12: Fog pockets + particles (chunk FX)

**Files:**
- Create: `scripts/terrain/biome/BiomeChunkFx.gd`
- Modify: `scripts/terrain/field/FieldTerrainStreamer.gd` (`_ensure_chunk`)

- [ ] **Step 1: Create `scripts/terrain/biome/BiomeChunkFx.gd`**

```gdscript
# scripts/terrain/biome/BiomeChunkFx.gd
# Render-only per-chunk children: pocket FogVolume + particle emitters from the
# dominant biome profile. Built by the streamer (never in headless); freed with
# the chunk. Spec §3 (pockets) + §5 (particles).
class_name BiomeChunkFx
extends RefCounted

const CHUNK := 192.0

static func build(profile: BiomeProfile, orb_light_points: Array) -> Node3D:
	var root := Node3D.new()
	root.name = "BiomeFx"
	if profile.pocket_fog_density > 0.0:
		var fv := FogVolume.new()
		fv.name = "PocketFog"
		fv.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
		fv.size = Vector3(CHUNK, 40.0, CHUNK)
		fv.position = Vector3(CHUNK * 0.5, 16.0, CHUNK * 0.5)
		var fm := FogMaterial.new()
		fm.density = profile.pocket_fog_density
		fm.albedo = profile.fog_color
		fv.material = fm
		root.add_child(fv)
	for recipe: StringName in profile.particles:
		root.add_child(_emitter(recipe, profile.particles[recipe]))
	for p: Vector3 in orb_light_points:
		var l := OmniLight3D.new()
		l.light_color = Color("ffb347")
		l.light_energy = 1.6
		l.omni_range = 14.0
		l.position = p
		root.add_child(l)
	return root

static func _emitter(recipe: StringName, density: float) -> GPUParticles3D:
	var e := GPUParticles3D.new()
	e.name = String(recipe)
	e.amount = int(clampf(density * 48.0, 4.0, 96.0))
	e.lifetime = 8.0
	e.visibility_aabb = AABB(Vector3(0, -8, 0), Vector3(CHUNK, 48, CHUNK))
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(CHUNK * 0.5, 12.0, CHUNK * 0.5)
	m.gravity = Vector3.ZERO
	var mesh := QuadMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	match recipe:
		&"fireflies":
			mesh.size = Vector2(0.25, 0.25)
			mat.albedo_color = Color(1.0, 0.85, 0.45, 0.9)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.8, 0.4)
			mat.emission_energy_multiplier = 2.5
			m.turbulence_enabled = true
			m.turbulence_influence_min = 0.05
			m.turbulence_influence_max = 0.15
		&"orbs":
			mesh.size = Vector2(1.2, 1.2)
			mat.albedo_color = Color(1.0, 0.7, 0.28, 0.85)
			mat.emission_enabled = true
			mat.emission = Color("ffb347")
			mat.emission_energy_multiplier = 3.5
			e.lifetime = 14.0
			m.turbulence_enabled = true
			m.turbulence_influence_min = 0.02
			m.turbulence_influence_max = 0.08
		&"petals":
			mesh.size = Vector2(0.35, 0.35)
			mat.albedo_color = Color(0.95, 0.72, 0.85, 0.9)
			m.gravity = Vector3(0.4, -0.6, 0.2)
			m.initial_velocity_min = 0.2
			m.initial_velocity_max = 0.8
		&"motes":
			mesh.size = Vector2(0.12, 0.12)
			mat.albedo_color = Color(1.0, 0.95, 0.8, 0.35)
			m.turbulence_enabled = true
			m.turbulence_influence_min = 0.02
			m.turbulence_influence_max = 0.06
	mesh.material = mat
	e.process_material = m
	e.draw_pass_1 = mesh
	e.position = Vector3.ZERO
	return e
```

- [ ] **Step 2: Build FX in the streamer** — add a headless flag + hook in `_ensure_chunk` after `_built[c] = node`:

```gdscript
var _headless: bool = DisplayServer.get_name() == "headless"
```
(member var near the top), and in `_ensure_chunk`:

```gdscript
	if not _headless:
		var origin := Vector3(float(c.x) * CHUNK_WORLD, 0.0, float(c.y) * CHUNK_WORLD)
		var centre := origin + Vector3(CHUNK_WORLD * 0.5, 0.0, CHUNK_WORLD * 0.5)
		var prof := BiomeRegistry.profile(Helper.biome_at(centre, world_seed))
		var orb_points: Array = []
		if prof.particles.has(&"orbs"):
			for i in 3:
				var hx := Helper._cell_hash01(world_seed + 7000 + i, c.x, c.y)
				var hz := Helper._cell_hash01(world_seed + 8000 + i, c.x, c.y)
				var lx := origin.x + hx * CHUNK_WORLD
				var lz := origin.z + hz * CHUNK_WORLD
				var lcx := int(floor(lx / 24.0))
				var lcz := int(floor(lz / 24.0))
				var reg = _plan.compute_region(lcx, lcz, 1)
				var ly := TerrainSurfaceField.surface_y(reg, lx, lz) + 2.5
				orb_points.append(Vector3(lx - origin.x, ly, lz - origin.z))
		var fx := BiomeChunkFx.build(prof, orb_points)
		fx.position = Vector3.ZERO
		node.add_child(fx)
```
Note `BiomeChunkFx` positions are chunk-local; the chunk node's origin is the chunk's world origin (mesher builds world-space geometry under a root at origin — verify: if chunk root sits at world origin with world-space verts, then set `fx.position = origin` instead; check one built chunk's `node.position` in the editor and pick the branch that puts fog over the chunk).

- [ ] **Step 3: Register + verify** — `--import`, run `test_field_streamer` + `test_heightfield_golden` (PASS, headless skips FX). In-game with a pinned marsh seed: mist bank visible from outside the pocket, orbs glowing inside, petals in blossom groves.

- [ ] **Step 4: Commit**

```bash
git add scripts/terrain/biome/BiomeChunkFx.gd scripts/terrain/field/FieldTerrainStreamer.gd
git commit -m "feat(atmosphere): marsh fog pockets, biome particles, glowing orb lights"
```

---

### Task 12b: Lantern + standing-stone catalog entries

**Files:**
- Modify: `scripts/core/AssetCatalog.gd` (two new tags)
- Test: `tests/test_asset_catalog.gd` (extend `test_expected_tags_exist` loop with the two tags)

- [ ] **Step 1: Locate candidate assets (they are FBX packs — imported scenes)**

```bash
find assets/ForgeFBX assets/LowPolyFantasyVillage -iname "*lantern*" | head
find assets/KayKitDungeon -iname "*pillar*" -o -iname "*column*" -o -iname "*wall*single*" | head
find assets/AlchemyPackFBX assets/CraftingFBX -iname "*mushroom*" -o -iname "*shroom*" | head
```

- [ ] **Step 2: Add entries** — for each found model, confirm it loads (`ResourceLoader.exists("res://assets/...")` via the audit test), then add to `CATALOG`:

```gdscript
	"lantern": {"kind": "scene", "variants": [
		{"path": "<best lantern found>", "weight": 1.0, "scale": 1.0},
	]},
	"standing_stone": {"kind": "scene", "variants": [
		{"path": "<best 1-3 stone pieces found>", "weight": 1.0, "scale": 1.0},
	]},
```
Add `"lantern", "standing_stone"` to the tag loop in `test_expected_tags_exist`. If a Mistage FBX imports with wrong materials, note it and pick the LowPolyFantasyVillage (GLB) lantern instead — GLB imports clean. If NO mushroom props fit, skip a `toadstool` tag entirely (spec accepts this; marsh stands on tint + orbs + fog).
Scale check: instance one of each next to a KayKit tree in the editor; if badly sized, set the catalog `scale` (data fix, not scene edit).

- [ ] **Step 3: Run** `test_asset_catalog` (audit stays clean) + in-game marsh check: rare warm lanterns in the murk.

- [ ] **Step 4: Commit**

```bash
git add scripts/core/AssetCatalog.gd tests/test_asset_catalog.gd
git commit -m "feat(assets): lantern + standing_stone catalog entries from owned packs"
```

---

### Task 13: F3 biome readout + acceptance pass

**Files:**
- Modify: `scripts/terrain/tools/CoordOverlay.gd` (`_process`, after the player line ~58)

- [ ] **Step 1: Add the readout**

```gdscript
		if wseed != null and int(wseed) != 0:
			var w5 := Helper.biome_weights5(pp, int(wseed))
			var parts: Array[String] = []
			for k: StringName in w5:
				if w5[k] >= 0.05:
					parts.append("%s %.2f" % [k, w5[k]])
			lines.append("biome %s   (%s)" % [Helper.biome_at(pp, int(wseed)), ", ".join(parts)])
```
(Inside the existing `if player != null:` block so `pp` is in scope.)

- [ ] **Step 2: Full suite**

```bash
$GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json -gexit
```
Expected: green except the known baseline failure.

- [ ] **Step 3: Visual acceptance (pin `SEED_OVERRIDE`, F3 on, screenshot each)**
- Meadow: bright warm green, thin haze, motes.
- Deep forest: dark saturated flora, teal-green fog, fireflies.
- Highland: grey-green, pale sky, standing stones present.
- Blossom grove: pink canopies, petals drifting.
- Twilight marsh: fog bank visible from OUTSIDE the pocket; inside — orbs glowing with bloom, dark teal flora, a rare lantern.
- Tilt-shift DoF visible (near/far blur), bloom only on emissives.

- [ ] **Step 4: Commit**

```bash
git add scripts/terrain/tools/CoordOverlay.gd
git commit -m "feat(tools): F3 overlay biome readout"
```

---

## Self-review notes (already applied)

- Spec §7.1 named `pick(tag, hash)`; plan uses `pick(tag, roll01)` with the roll from `DecorationScatter`'s dedicated `variant` hash stream — same design, clearer name.
- Spec §2 `.tres` profiles and §7.1 `asset_catalog.tres` are simplified to code-built data (header note) — schema unchanged.
- `Helper.biome_weights`/`biome_foliage_density` deletion replaces the spec's "re-express" wording: grep proved there are no live consumers, so re-expressing would preserve dead API.
- Chunk-local vs world-space FX positioning is flagged in Task 12 Step 2 — verify against a built chunk before committing.
