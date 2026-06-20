# Sloped Cliffs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the 14 sheer-faced cliff variant tiles with parametric, grass-covered, sigmoid-sloped versions generated procedurally and swapped in via the cliff variant table.

**Architecture:** Pure-math profile functions define a smootherstep slope over the outer 6u of a 24×24 tile. A mesh generator turns those functions into 4 reusable 6×6 component meshes (top, edge, outer-corner, inner-corner) with convex-ramp collision and the existing grass material. A data-driven layout maps each variant's edge/corner exposure mask onto a 4×4 grid of those components. A headless bake script writes the component scenes to `terrain/gltf/slope/` and the 14 assembled variant scenes to `terrain/scenes/slope/` (sockets copied from the originals). Finally the variant loader is repointed at the new scenes.

**Tech Stack:** Godot 4 + GDScript, GUT test framework, `SurfaceTool`/`ArrayMesh`, `ConvexPolygonShape3D`, headless `SceneTree` bake script.

---

## Conventions used throughout

- **Godot binary:** `/Applications/Godot.app/Contents/MacOS/Godot` (referred to as `$GODOT`).
- **Run one test file:**
  `$GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json -gtest=res://tests/<file>.gd -gexit`
- **Run all tests:**
  `$GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json -gexit`
- **Tile geometry:** tile is 24×24 (local x,z ∈ [−12, 12]), 4 tall. Plateau top at `y=0`, lower ground at `y=−4`.
- **6u sub-grid:** 4×4 cells, each 6×6. Cell centers at x,z ∈ {−9, −3, 3, 9}. Within a cell, local coords run [−3, 3]. `HALF = 3.0`, `CELL = 6.0`, `HEIGHT = 4.0`.
- **Directions:** front = −Z, back = +Z, left = −X, right = +X. Grid corners: FL = (−9,−9), FR = (9,−9), BL = (−9,9), BR = (9,9).
- **Profile factor for a cell-local coordinate** `c ∈ [−3,3]` ramping toward its negative side: `ss((HALF − c) / CELL)` where `ss` is smootherstep. This is 0 at `c=+3` (inner/plateau side) and 1 at `c=−3` (outer/boundary side).

## File structure

- Create `scripts/terrain/tools/SlopeProfile.gd` — pure math: smootherstep + per-component cell height functions. (`class_name SlopeProfile`)
- Create `scripts/terrain/tools/SlopeAtlas.gd` — samples the grass texel UV from an existing top mesh. (`class_name SlopeAtlas`)
- Create `scripts/terrain/tools/SlopeMeshGenerator.gd` — builds the 4 component `ArrayMesh`es + convex collision shapes. (`class_name SlopeMeshGenerator`)
- Create `scripts/terrain/tools/SlopeVariantLayout.gd` — variant exposure masks + mask→16-cell layout. (`class_name SlopeVariantLayout`)
- Create `scripts/terrain/tools/bake_slope_cliffs.gd` — headless `SceneTree` script that writes all component + variant scenes.
- Create `terrain/gltf/slope/` (4 component `.tscn`) and `terrain/scenes/slope/` (14 variant `.tscn`) — produced by the bake script.
- Modify `scripts/terrain/TerrainModuleDefinitions.gd` — repoint `load_cliff_variant()` scene path to `slope/`.
- Create test files under `tests/`.

---

## Task 1: Slope profile math

**Files:**
- Create: `scripts/terrain/tools/SlopeProfile.gd`
- Test: `tests/test_slope_profile.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/test_slope_profile.gd
extends GutTest

func test_smootherstep_endpoints() -> void:
	assert_almost_eq(SlopeProfile.smootherstep(0.0), 0.0, 1e-6)
	assert_almost_eq(SlopeProfile.smootherstep(1.0), 1.0, 1e-6)
	assert_almost_eq(SlopeProfile.smootherstep(0.5), 0.5, 1e-6)

func test_smootherstep_flat_tangents() -> void:
	# derivative ~0 at both ends -> C1 continuity with flat plateau/ground
	var d0 := (SlopeProfile.smootherstep(0.01) - SlopeProfile.smootherstep(0.0)) / 0.01
	var d1 := (SlopeProfile.smootherstep(1.0) - SlopeProfile.smootherstep(0.99)) / 0.01
	assert_lt(absf(d0), 0.05)
	assert_lt(absf(d1), 0.05)

func test_smootherstep_clamps() -> void:
	assert_almost_eq(SlopeProfile.smootherstep(-1.0), 0.0, 1e-6)
	assert_almost_eq(SlopeProfile.smootherstep(2.0), 1.0, 1e-6)

func test_edge_height_endpoints() -> void:
	# Edge ramps toward front (-z). Inner side z=+3 -> top (0); outer z=-3 -> -4.
	assert_almost_eq(SlopeProfile.edge_height(0.0, 3.0), 0.0, 1e-6)
	assert_almost_eq(SlopeProfile.edge_height(0.0, -3.0), -4.0, 1e-6)
	# independent of x
	assert_almost_eq(SlopeProfile.edge_height(-3.0, 0.0), SlopeProfile.edge_height(3.0, 0.0), 1e-6)

func test_outer_corner_seam_matches_edge() -> void:
	# Along x=+3 the outer corner must equal the front-edge profile (continuity).
	for z in [-3.0, -1.0, 1.0, 3.0]:
		assert_almost_eq(SlopeProfile.outer_corner_height(3.0, z), SlopeProfile.edge_height(0.0, z), 1e-6)
	# Far outer corner fully drops.
	assert_almost_eq(SlopeProfile.outer_corner_height(-3.0, -3.0), -4.0, 1e-6)

func test_inner_corner_seams_flat() -> void:
	# Inner corner: plateau wraps; both inner seams stay at top (0).
	for z in [-3.0, 0.0, 3.0]:
		assert_almost_eq(SlopeProfile.inner_corner_height(3.0, z), 0.0, 1e-6)
	for x in [-3.0, 0.0, 3.0]:
		assert_almost_eq(SlopeProfile.inner_corner_height(x, 3.0), 0.0, 1e-6)
	# Only the far corner dips.
	assert_almost_eq(SlopeProfile.inner_corner_height(-3.0, -3.0), -4.0, 1e-6)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `$GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json -gtest=res://tests/test_slope_profile.gd -gexit`
Expected: FAIL — `SlopeProfile` not found / parse error.

- [ ] **Step 3: Write minimal implementation**

```gdscript
# scripts/terrain/tools/SlopeProfile.gd
class_name SlopeProfile
extends RefCounted

const HALF := 3.0      # half cell width
const CELL := 6.0      # cell / slope band width
const HEIGHT := 4.0    # total drop (top y=0 to bottom y=-4)
const BOTTOM := -4.0

static func smootherstep(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)

# Ramp factor for a cell-local coord ramping toward its negative side.
# 0 at c=+HALF (inner/plateau), 1 at c=-HALF (outer/boundary).
static func _ramp(c: float) -> float:
	return smootherstep((HALF - c) / CELL)

# Edge: ramps toward front (-z), flat across x.
static func edge_height(_x: float, z: float) -> float:
	return BOTTOM * _ramp(z)

# Outer (convex) corner: ramps toward FL (-x,-z). a=front ramp, b=left ramp.
# f(a,b)=a+b-ab so f(a,0)=a and f(0,b)=b -> seams match the two edges.
static func outer_corner_height(x: float, z: float) -> float:
	var a := _ramp(z)
	var b := _ramp(x)
	return BOTTOM * (a + b - a * b)

# Inner (concave) corner: plateau wraps; only the far corner dips. f=a*b.
static func inner_corner_height(x: float, z: float) -> float:
	var a := _ramp(z)
	var b := _ramp(x)
	return BOTTOM * (a * b)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `$GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json -gtest=res://tests/test_slope_profile.gd -gexit`
Expected: PASS (all 6 tests green).

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/tools/SlopeProfile.gd tests/test_slope_profile.gd
git commit -m "feat(terrain): slope profile math for sloped cliffs"
```

---

## Task 2: Grass UV sampling

**Files:**
- Create: `scripts/terrain/tools/SlopeAtlas.gd`
- Test: `tests/test_slope_atlas.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/test_slope_atlas.gd
extends GutTest

func test_grass_uv_in_range() -> void:
	var uv := SlopeAtlas.grass_uv()
	assert_between(uv.x, 0.0, 1.0)
	assert_between(uv.y, 0.0, 1.0)

func test_grass_uv_samples_green() -> void:
	# The sampled texel in the forest palette must read as green (G dominant).
	var uv := SlopeAtlas.grass_uv()
	var tex := load("res://assets/KayKitNature/Assets/gltf/Color1/forest_texture.png") as Texture2D
	var img := tex.get_image()
	var px := img.get_pixel(
		int(clampf(uv.x, 0.0, 0.999) * img.get_width()),
		int(clampf(uv.y, 0.0, 0.999) * img.get_height()))
	assert_gt(px.g, px.r)
	assert_gt(px.g, px.b)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `$GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json -gtest=res://tests/test_slope_atlas.gd -gexit`
Expected: FAIL — `SlopeAtlas` not found.

- [ ] **Step 3: Write minimal implementation**

```gdscript
# scripts/terrain/tools/SlopeAtlas.gd
# Samples the grass (top-surface) texel UV from an existing KayKit top piece so
# generated slope meshes map into the exact same palette swatch.
class_name SlopeAtlas
extends RefCounted

const TOP_PIECE := "res://terrain/gltf/hill_top_e_center_color_12.tscn"

static func grass_uv() -> Vector2:
	var packed := load(TOP_PIECE) as PackedScene
	var inst := packed.instantiate()
	var mi := _first_mesh_instance(inst)
	assert(mi != null, "no MeshInstance3D in top piece")
	var arrays := mi.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	# Average UVs of up-facing (grass top) vertices.
	var sum := Vector2.ZERO
	var n := 0
	for i in verts.size():
		if normals.size() == verts.size() and normals[i].y > 0.9:
			sum += uvs[i]
			n += 1
	var result := (sum / n) if n > 0 else (uvs[0] if uvs.size() > 0 else Vector2.ZERO)
	inst.free()
	return result

static func _first_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for c in node.get_children():
		var found := _first_mesh_instance(c)
		if found != null:
			return found
	return null
```

- [ ] **Step 4: Run test to verify it passes**

Run: `$GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json -gtest=res://tests/test_slope_atlas.gd -gexit`
Expected: PASS. If `test_grass_uv_samples_green` fails, the chosen top piece's up-faces are not grass — switch `TOP_PIECE` to `res://terrain/gltf/hill_top_h_side_color_12.tscn` and re-run (its top face is also grass). Do not hardcode a UV.

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/tools/SlopeAtlas.gd tests/test_slope_atlas.gd
git commit -m "feat(terrain): sample grass texel UV for slope meshes"
```

---

## Task 3: Component mesh generator

**Files:**
- Create: `scripts/terrain/tools/SlopeMeshGenerator.gd`
- Test: `tests/test_slope_mesh_generator.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/test_slope_mesh_generator.gd
extends GutTest

const MAT := "res://terrain/materials/ground.tres"

func _gen() -> SlopeMeshGenerator:
	var g := SlopeMeshGenerator.new()
	g.grass_uv = Vector2(0.25, 0.25)  # deterministic UV for tests
	g.material = load(MAT)
	return g

func _aabb(mesh: ArrayMesh) -> AABB:
	return mesh.get_aabb()

func test_top_is_flat() -> void:
	var mesh := _gen().build_top()
	var box := _aabb(mesh)
	assert_almost_eq(box.position.y, 0.0, 1e-4)
	assert_almost_eq(box.size.y, 0.0, 1e-4)
	assert_almost_eq(box.size.x, 6.0, 1e-3)
	assert_almost_eq(box.size.z, 6.0, 1e-3)

func test_edge_spans_full_drop() -> void:
	var box := _aabb(_gen().build_edge())
	assert_almost_eq(box.position.y, -4.0, 1e-3)   # bottom reaches -4
	assert_almost_eq(box.position.y + box.size.y, 0.0, 1e-3)  # top at 0
	assert_almost_eq(box.size.x, 6.0, 1e-3)
	assert_almost_eq(box.size.z, 6.0, 1e-3)

func test_all_uvs_are_grass() -> void:
	var mesh := _gen().build_edge()
	var uvs: PackedVector2Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	assert_gt(uvs.size(), 0)
	for uv in uvs:
		assert_almost_eq(uv.x, 0.25, 1e-6)
		assert_almost_eq(uv.y, 0.25, 1e-6)

func test_components_have_material_and_normals() -> void:
	for mesh in [_gen().build_top(), _gen().build_edge(), _gen().build_outer_corner(), _gen().build_inner_corner()]:
		assert_not_null(mesh.surface_get_material(0))
		var normals: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
		assert_gt(normals.size(), 0)

func test_collision_shapes_are_convex() -> void:
	var g := _gen()
	assert_true(g.build_edge_collision() is ConvexPolygonShape3D)
	assert_true(g.build_outer_corner_collision() is ConvexPolygonShape3D)
	assert_true(g.build_inner_corner_collision() is ConvexPolygonShape3D)
	assert_true(g.build_top_collision() is BoxShape3D)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `$GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json -gtest=res://tests/test_slope_mesh_generator.gd -gexit`
Expected: FAIL — `SlopeMeshGenerator` not found.

- [ ] **Step 3: Write minimal implementation**

```gdscript
# scripts/terrain/tools/SlopeMeshGenerator.gd
# Builds the 4 reusable 6x6 slope component meshes + convex collision shapes.
# All geometry is authored in cell-local coords (x,z in [-3,3], y in [-4,0]).
class_name SlopeMeshGenerator
extends RefCounted

const SEG := 10                       # segments per 6u cell
const H := SlopeProfile.HALF          # 3.0
const SKIRT := 0.4                    # collision thickness below surface

var grass_uv: Vector2 = Vector2.ZERO
var material: Material = null

# --- meshes ---------------------------------------------------------------

func build_top() -> ArrayMesh:
	return _build(func(_x, _z): return 0.0)

func build_edge() -> ArrayMesh:
	return _build(func(x, z): return SlopeProfile.edge_height(x, z))

func build_outer_corner() -> ArrayMesh:
	return _build(func(x, z): return SlopeProfile.outer_corner_height(x, z))

func build_inner_corner() -> ArrayMesh:
	return _build(func(x, z): return SlopeProfile.inner_corner_height(x, z))

# Build a SEG x SEG grid over [-H,H]^2, height from `hfn` (Callable(x,z)->float).
func _build(hfn: Callable) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := (2.0 * H) / SEG
	for iz in SEG:
		for ix in SEG:
			var x0 := -H + ix * step
			var x1 := x0 + step
			var z0 := -H + iz * step
			var z1 := z0 + step
			var v00 := Vector3(x0, hfn.call(x0, z0), z0)
			var v10 := Vector3(x1, hfn.call(x1, z0), z0)
			var v11 := Vector3(x1, hfn.call(x1, z1), z1)
			var v01 := Vector3(x0, hfn.call(x0, z1), z1)
			_tri(st, v00, v10, v11)
			_tri(st, v00, v11, v01)
	st.generate_normals()
	if material != null:
		st.set_material(material)
	return st.commit()

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	for v in [a, b, c]:
		st.set_uv(grass_uv)
		st.add_vertex(v)

# --- collision (convex ramps) --------------------------------------------

func build_top_collision() -> BoxShape3D:
	var s := BoxShape3D.new()
	s.size = Vector3(6.0, SKIRT, 6.0)
	return s  # caller offsets center to y = -SKIRT/2

func build_edge_collision() -> ConvexPolygonShape3D:
	return _convex_from_hfn(func(x, z): return SlopeProfile.edge_height(x, z))

func build_outer_corner_collision() -> ConvexPolygonShape3D:
	return _convex_from_hfn(func(x, z): return SlopeProfile.outer_corner_height(x, z))

func build_inner_corner_collision() -> ConvexPolygonShape3D:
	return _convex_from_hfn(func(x, z): return SlopeProfile.inner_corner_height(x, z))

# Convex hull of the 4 surface corners + the same 4 pushed down by SKIRT.
func _convex_from_hfn(hfn: Callable) -> ConvexPolygonShape3D:
	var pts := PackedVector3Array()
	for c in [[-H, -H], [H, -H], [H, H], [-H, H]]:
		var y: float = hfn.call(float(c[0]), float(c[1]))
		pts.append(Vector3(c[0], y, c[1]))
		pts.append(Vector3(c[0], y - SKIRT, c[1]))
	var shape := ConvexPolygonShape3D.new()
	shape.points = pts
	return shape
```

- [ ] **Step 4: Run test to verify it passes**

Run: `$GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json -gtest=res://tests/test_slope_mesh_generator.gd -gexit`
Expected: PASS (all 5 tests).

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/tools/SlopeMeshGenerator.gd tests/test_slope_mesh_generator.gd
git commit -m "feat(terrain): procedural slope component mesh generator"
```

---

## Task 4: Variant layout (mask → 4×4 grid)

**Files:**
- Create: `scripts/terrain/tools/SlopeVariantLayout.gd`
- Test: `tests/test_slope_variant_layout.gd`

The layout returns, for a variant name, an `Array` of 16 cell placements. Each placement is a `Dictionary` `{component: String, angle_deg: float, x: float, z: float}` where `component` is one of `"top"`, `"edge"`, `"outer"`, `"inner"`.

Base orientations: **edge** ramps toward front (−Z); **outer** ramps toward FL (−X,−Z); **inner** dips toward FL. Rotation is about +Y. Direction → angle table (verified visually in Task 7; flip sign there if mirrored):
`{front: 0, left: 90, back: 180, right: 270}` for edges, and corner → angle `{FL: 0, BL: 90, BR: 180, FR: 270}`.

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/test_slope_variant_layout.gd
extends GutTest

func _kinds(name: String) -> Dictionary:
	# Returns {component: count} for a variant's 16 cells.
	var counts := {"top": 0, "edge": 0, "outer": 0, "inner": 0}
	for cell in SlopeVariantLayout.layout(name):
		counts[cell.component] += 1
	return counts

func test_all_variants_have_16_cells() -> void:
	for name in SlopeVariantLayout.VARIANT_MASKS.keys():
		assert_eq(SlopeVariantLayout.layout(name).size(), 16, name)

func test_side_one_edge_row() -> void:
	# front slope: 4 edge cells (front row), rest top, no corners.
	var k := _kinds("CliffSide")
	assert_eq(k.edge, 4)
	assert_eq(k.outer, 0)
	assert_eq(k.inner, 0)
	assert_eq(k.top, 12)

func test_corner_has_outer() -> void:
	# front+left slope -> 1 outer (FL) + 3+3 edge cells.
	var k := _kinds("CliffCorner")
	assert_eq(k.outer, 1)
	assert_eq(k.edge, 6)
	assert_eq(k.top, 9)

func test_island_full_ring() -> void:
	# all 4 edges -> 4 outer corners + 8 edge perimeter + 4 interior top.
	var k := _kinds("CliffIsland")
	assert_eq(k.outer, 4)
	assert_eq(k.edge, 8)
	assert_eq(k.top, 4)
	assert_eq(k.inner, 0)

func test_incorner_single_inner() -> void:
	var k := _kinds("CliffInCorner")
	assert_eq(k.inner, 1)
	assert_eq(k.edge, 0)
	assert_eq(k.outer, 0)
	assert_eq(k.top, 15)

func test_incorner_edge_both() -> void:
	# back+right slope (outer at BR) + inner at FL.
	var k := _kinds("CliffInCornerEdgeBoth")
	assert_eq(k.outer, 1)   # BR
	assert_eq(k.inner, 1)   # FL
	assert_eq(k.edge, 6)    # back row (3) + right col (3)
	assert_eq(k.top, 8)

func test_inner_corner_cell_position() -> void:
	# CliffInCorner inner cell sits at FL grid corner (-9,-9).
	var inner_cell := {}
	for cell in SlopeVariantLayout.layout("CliffInCorner"):
		if cell.component == "inner":
			inner_cell = cell
	assert_almost_eq(inner_cell.x, -9.0, 1e-6)
	assert_almost_eq(inner_cell.z, -9.0, 1e-6)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `$GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json -gtest=res://tests/test_slope_variant_layout.gd -gexit`
Expected: FAIL — `SlopeVariantLayout` not found.

- [ ] **Step 3: Write minimal implementation**

```gdscript
# scripts/terrain/tools/SlopeVariantLayout.gd
# Maps each cliff variant's edge/corner exposure to a 4x4 grid of slope
# components. Derived from the original terrain/scenes/Cliff*.tscn geometry.
class_name SlopeVariantLayout
extends RefCounted

const CENTERS := [-9.0, -3.0, 3.0, 9.0]   # index 0..3 -> coord
# edges: set of {"front","back","left","right"}; corners: set of {"FL","FR","BL","BR"}
const VARIANT_MASKS := {
	"CliffSide":              {"edges": ["front"], "inner": []},
	"CliffCorner":           {"edges": ["front", "left"], "inner": []},
	"CliffLine":             {"edges": ["front", "back"], "inner": []},
	"CliffPeninsula":        {"edges": ["front", "left", "back"], "inner": []},
	"CliffIsland":           {"edges": ["front", "back", "left", "right"], "inner": []},
	"CliffInCorner":         {"edges": [], "inner": ["FL"]},
	"CliffInCornerDiag":     {"edges": [], "inner": ["FL", "BR"]},
	"CliffInCornerSide":     {"edges": [], "inner": ["FL", "BL"]},
	"CliffInCornerThree":    {"edges": [], "inner": ["FL", "BL", "BR"]},
	"CliffInCornerAll":      {"edges": [], "inner": ["FL", "FR", "BL", "BR"]},
	"CliffInCornerEdge1":    {"edges": ["back"], "inner": ["FL"]},
	"CliffInCornerEdge2":    {"edges": ["right"], "inner": ["FL"]},
	"CliffInCornerEdgeBoth": {"edges": ["back", "right"], "inner": ["FL"]},
	"CliffInCornerSideEdge": {"edges": ["right"], "inner": ["FL", "BL"]},
}

const EDGE_ANGLE := {"front": 0.0, "left": 90.0, "back": 180.0, "right": 270.0}
const CORNER_ANGLE := {"FL": 0.0, "BL": 90.0, "BR": 180.0, "FR": 270.0}

# col (x index) 0=left,3=right ; row (z index) 0=front,3=back
static func _corner_of(col: int, row: int) -> String:
	if col == 0 and row == 0: return "FL"
	if col == 3 and row == 0: return "FR"
	if col == 0 and row == 3: return "BL"
	if col == 3 and row == 3: return "BR"
	return ""

static func _edges_touching(col: int, row: int) -> Array:
	var e := []
	if row == 0: e.append("front")
	if row == 3: e.append("back")
	if col == 0: e.append("left")
	if col == 3: e.append("right")
	return e

static func layout(name: String) -> Array:
	var mask: Dictionary = VARIANT_MASKS[name]
	var slope_edges: Array = mask.edges
	var inner_corners: Array = mask.inner
	var cells := []
	for row in 4:
		for col in 4:
			var x: float = CENTERS[col]
			var z: float = CENTERS[row]
			var corner := _corner_of(col, row)
			var touching := _edges_touching(col, row)
			var slope_touch := []
			for e in touching:
				if e in slope_edges:
					slope_touch.append(e)
			var comp := "top"
			var ang := 0.0
			if corner != "" and slope_touch.size() == 2:
				comp = "outer"
				ang = CORNER_ANGLE[corner]
			elif slope_touch.size() >= 1:
				comp = "edge"
				ang = EDGE_ANGLE[slope_touch[0]]
			elif corner != "" and corner in inner_corners:
				comp = "inner"
				ang = CORNER_ANGLE[corner]
			cells.append({"component": comp, "angle_deg": ang, "x": x, "z": z})
	return cells
```

- [ ] **Step 4: Run test to verify it passes**

Run: `$GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json -gtest=res://tests/test_slope_variant_layout.gd -gexit`
Expected: PASS (all 7 tests). The counts encode the table in this plan's header.

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/tools/SlopeVariantLayout.gd tests/test_slope_variant_layout.gd
git commit -m "feat(terrain): variant exposure masks and slope grid layout"
```

---

## Task 5: Component scene baker

**Files:**
- Create: `scripts/terrain/tools/bake_slope_cliffs.gd` (component half; variant half added in Task 6)
- Output: `terrain/gltf/slope/top.tscn`, `edge.tscn`, `outer_corner.tscn`, `inner_corner.tscn`
- Test: `tests/test_slope_components.gd`

Each component scene root is a `Node3D` named after the component, containing a `MeshInstance3D` (the generated mesh) and a `StaticBody3D > CollisionShape3D` (the convex/box shape). For `top`, the box collision is centered at `y = -SKIRT/2`.

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/test_slope_components.gd
extends GutTest

const COMPONENTS := ["top", "edge", "outer_corner", "inner_corner"]

func test_component_scenes_exist_and_load() -> void:
	for c in COMPONENTS:
		var path := "res://terrain/gltf/slope/%s.tscn" % c
		assert_true(ResourceLoader.exists(path), path)
		var inst := (load(path) as PackedScene).instantiate()
		assert_not_null(inst)
		# has a mesh and a static body with a collision shape
		assert_not_null(_find(inst, "MeshInstance3D"))
		var body := _find(inst, "StaticBody3D")
		assert_not_null(body)
		assert_not_null(_find(body, "CollisionShape3D"))
		inst.free()

func _find(node: Node, cls: String) -> Node:
	if node.get_class() == cls:
		return node
	for c in node.get_children():
		var f := _find(c, cls)
		if f != null:
			return f
	return null
```

- [ ] **Step 2: Run test to verify it fails**

Run: `$GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json -gtest=res://tests/test_slope_components.gd -gexit`
Expected: FAIL — component scenes don't exist.

- [ ] **Step 3: Write the baker (component half) and run it**

```gdscript
# scripts/terrain/tools/bake_slope_cliffs.gd
# Headless bake: writes slope component scenes and (Task 6) variant scenes.
# Run: $GODOT --headless --path . -s scripts/terrain/tools/bake_slope_cliffs.gd
extends SceneTree

const MAT := "res://terrain/materials/ground.tres"
const GLTF_DIR := "res://terrain/gltf/slope"
const SCENE_DIR := "res://terrain/scenes/slope"
const SKIRT := 0.4

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GLTF_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCENE_DIR))
	var gen := SlopeMeshGenerator.new()
	gen.grass_uv = SlopeAtlas.grass_uv()
	gen.material = load(MAT)
	_bake_components(gen)
	_bake_variants(gen)   # implemented in Task 6
	print("slope bake complete")
	quit()

func _bake_components(gen: SlopeMeshGenerator) -> void:
	_save_component("top", gen.build_top(), gen.build_top_collision(), Vector3(0, -SKIRT * 0.5, 0))
	_save_component("edge", gen.build_edge(), gen.build_edge_collision(), Vector3.ZERO)
	_save_component("outer_corner", gen.build_outer_corner(), gen.build_outer_corner_collision(), Vector3.ZERO)
	_save_component("inner_corner", gen.build_inner_corner(), gen.build_inner_corner_collision(), Vector3.ZERO)

func _save_component(cname: String, mesh: ArrayMesh, shape: Shape3D, col_offset: Vector3) -> void:
	var root := Node3D.new()
	root.name = cname
	var mi := MeshInstance3D.new()
	mi.name = "MeshInstance3D"
	mi.mesh = mesh
	root.add_child(mi)
	mi.owner = root
	var body := StaticBody3D.new()
	body.name = "StaticBody3D"
	root.add_child(body)
	body.owner = root
	var cs := CollisionShape3D.new()
	cs.name = "CollisionShape3D"
	cs.shape = shape
	cs.position = col_offset
	body.add_child(cs)
	cs.owner = root
	var packed := PackedScene.new()
	packed.pack(root)
	var path := "%s/%s.tscn" % [GLTF_DIR, cname]
	var err := ResourceSaver.save(packed, path)
	assert(err == OK, "save failed: %s" % path)
	root.free()

func _bake_variants(_gen: SlopeMeshGenerator) -> void:
	pass  # Task 6
```

Run the baker:
`$GODOT --headless --path . -s scripts/terrain/tools/bake_slope_cliffs.gd`
Expected output: `slope bake complete`, and 4 files under `terrain/gltf/slope/`.

- [ ] **Step 4: Run test to verify it passes**

Run: `$GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json -gtest=res://tests/test_slope_components.gd -gexit`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/tools/bake_slope_cliffs.gd tests/test_slope_components.gd terrain/gltf/slope/
git commit -m "feat(terrain): bake slope component scenes"
```

---

## Task 6: Variant scene baker (assembly + socket parity)

**Files:**
- Modify: `scripts/terrain/tools/bake_slope_cliffs.gd` (implement `_bake_variants`)
- Output: 14 scenes under `terrain/scenes/slope/`
- Test: `tests/test_slope_variant_scenes.gd`

Each variant scene root `Node3D` (named e.g. `CliffSide`) contains: one instance of the relevant component per non-`top` cell (rotated/positioned per layout), plus a `Sockets` node duplicated from the original `res://terrain/scenes/<name>.tscn`. `top` cells are skipped visually (the plateau is covered by the surrounding edge/corner inner edges meeting at `y=0`); include them only if a gap is seen in Task 7 — for now place every cell including `top` so the plateau surface is fully covered and walkable.

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/test_slope_variant_scenes.gd
extends GutTest

const NAMES := [
	"CliffSide", "CliffCorner", "CliffLine", "CliffPeninsula", "CliffIsland",
	"CliffInCorner", "CliffInCornerDiag", "CliffInCornerSide", "CliffInCornerThree",
	"CliffInCornerAll", "CliffInCornerEdge1", "CliffInCornerEdge2",
	"CliffInCornerEdgeBoth", "CliffInCornerSideEdge",
]

func test_all_variant_scenes_load() -> void:
	for n in NAMES:
		var path := "res://terrain/scenes/slope/%s.tscn" % n
		assert_true(ResourceLoader.exists(path), path)
		var inst := (load(path) as PackedScene).instantiate()
		assert_not_null(inst, n)
		inst.free()

func test_socket_parity_with_original() -> void:
	for n in NAMES:
		var orig := (load("res://terrain/scenes/%s.tscn" % n) as PackedScene).instantiate()
		var slope := (load("res://terrain/scenes/slope/%s.tscn" % n) as PackedScene).instantiate()
		var orig_sockets := _socket_names(orig)
		var slope_sockets := _socket_names(slope)
		assert_eq(slope_sockets, orig_sockets, "socket mismatch for %s" % n)
		orig.free()
		slope.free()

func _socket_names(root: Node) -> Array:
	var s := root.get_node_or_null("Sockets")
	if s == null:
		return []
	var names := []
	for c in s.get_children():
		names.append(c.name)
	names.sort()
	return names
```

- [ ] **Step 2: Run test to verify it fails**

Run: `$GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json -gtest=res://tests/test_slope_variant_scenes.gd -gexit`
Expected: FAIL — variant scenes don't exist.

- [ ] **Step 3: Implement `_bake_variants` and re-run the baker**

Replace the `_bake_variants` stub in `scripts/terrain/tools/bake_slope_cliffs.gd` with:

```gdscript
const COMPONENT_PATHS := {
	"top": "res://terrain/gltf/slope/top.tscn",
	"edge": "res://terrain/gltf/slope/edge.tscn",
	"outer": "res://terrain/gltf/slope/outer_corner.tscn",
	"inner": "res://terrain/gltf/slope/inner_corner.tscn",
}

func _bake_variants(_gen: SlopeMeshGenerator) -> void:
	for name in SlopeVariantLayout.VARIANT_MASKS.keys():
		_bake_variant(name)

func _bake_variant(name: String) -> void:
	var root := Node3D.new()
	root.name = name
	var i := 0
	for cell in SlopeVariantLayout.layout(name):
		var comp_scene := load(COMPONENT_PATHS[cell.component]) as PackedScene
		var node := comp_scene.instantiate()
		node.name = "%s_%d" % [cell.component, i]
		var basis := Basis(Vector3.UP, deg_to_rad(cell.angle_deg))
		node.transform = Transform3D(basis, Vector3(cell.x, 0.0, cell.z))
		root.add_child(node)
		_set_owner_recursive(node, root)
		i += 1
	# Copy sockets from the original scene for adjacency parity.
	var orig := (load("res://terrain/scenes/%s.tscn" % name) as PackedScene).instantiate()
	var sockets := orig.get_node_or_null("Sockets")
	if sockets != null:
		var dup := sockets.duplicate()
		root.add_child(dup)
		_set_owner_recursive(dup, root)
	orig.free()
	var packed := PackedScene.new()
	packed.pack(root)
	var path := "%s/%s.tscn" % [SCENE_DIR, name]
	var err := ResourceSaver.save(packed, path)
	assert(err == OK, "save failed: %s" % path)
	root.free()

func _set_owner_recursive(node: Node, owner_root: Node) -> void:
	node.owner = owner_root
	for c in node.get_children():
		_set_owner_recursive(c, owner_root)
```

Re-run the baker:
`$GODOT --headless --path . -s scripts/terrain/tools/bake_slope_cliffs.gd`
Expected: `slope bake complete`, 14 files under `terrain/scenes/slope/`.

- [ ] **Step 4: Run test to verify it passes**

Run: `$GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json -gtest=res://tests/test_slope_variant_scenes.gd -gexit`
Expected: PASS (both tests, all 14 names).

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/tools/bake_slope_cliffs.gd tests/test_slope_variant_scenes.gd terrain/scenes/slope/
git commit -m "feat(terrain): assemble 14 sloped cliff variant scenes"
```

---

## Task 7: Visual verification + orientation fix

**Files:**
- Possibly modify: `scripts/terrain/tools/SlopeVariantLayout.gd` (`EDGE_ANGLE`/`CORNER_ANGLE` signs)
- No new test (visual gate).

- [ ] **Step 1: Render the current world**

Use the godot MCP `run_project` then `game_screenshot` (or `mcp__godot__run_project` with `scenes/world.tscn`). Note: the variant loader still points at the OLD scenes until Task 8, so first render a throwaway scene that instances a few slope variants directly. Create `terrain/scenes/slope/_preview.tscn` by hand or via `mcp__godot__create_scene` + `add_node` instancing `CliffSide`, `CliffCorner`, `CliffInCorner`, `CliffInCornerEdgeBoth` side by side, and screenshot it.

- [ ] **Step 2: Verify orientation**

Confirm for each previewed variant:
- The slope ramps **down toward the exposed edge** (toward lower ground), not inward.
- Outer corners round outward; inner corners dip inward.
- Slopes are continuous across the cell seams (no cracks), grass-textured top to bottom.

If a slope faces the wrong way, the base-orientation angle signs are mirrored. Fix by negating angles in `EDGE_ANGLE` and `CORNER_ANGLE` (e.g. `left: -90/270` swap), re-run the baker, re-render. Repeat until correct.

- [ ] **Step 3: Commit any orientation fix**

```bash
git add scripts/terrain/tools/SlopeVariantLayout.gd terrain/scenes/slope/ terrain/gltf/slope/
git commit -m "fix(terrain): correct slope component orientation"
```

(If no fix was needed, skip the commit.)

---

## Task 8: Swap the variant loader to the slope scenes

**Files:**
- Modify: `scripts/terrain/TerrainModuleDefinitions.gd` (`load_cliff_variant`, ~line 671-681)
- Test: `tests/test_slope_cliff_integration.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/test_slope_cliff_integration.gd
extends GutTest

func test_cliff_variants_resolve_to_slope_scenes() -> void:
	# TerrainModule stores `scene: PackedScene` (path via scene.resource_path)
	# and `tags: TagList` (TagList.has(tag) -> bool). Verified against source.
	var mods := TerrainModuleDefinitions.load_cliff_variants()
	assert_gt(mods.size(), 0)
	var found_side := false
	for m in mods:
		var path: String = m.scene.resource_path
		if path.findn("CliffSide") != -1:
			found_side = true
			assert_true(path.findn("/slope/") != -1, path)
			assert_true(m.tags.has("24x24x4"))
			assert_true(m.tags.has("cliff"))
	assert_true(found_side, "CliffSide variant not found")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `$GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json -gtest=res://tests/test_slope_cliff_integration.gd -gexit`
Expected: FAIL — `scene.resource_path` still points at `terrain/scenes/CliffSide.tscn` (no `/slope/`).

- [ ] **Step 3: Repoint the loader**

In `scripts/terrain/TerrainModuleDefinitions.gd`, change the path in `load_cliff_variant`:

```gdscript
# before
var scene_path: String = "res://terrain/scenes/%s.tscn" % scene_name
# after
var scene_path: String = "res://terrain/scenes/slope/%s.tscn" % scene_name
```

- [ ] **Step 4: Run test to verify it passes**

Run: `$GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json -gtest=res://tests/test_slope_cliff_integration.gd -gexit`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/TerrainModuleDefinitions.gd tests/test_slope_cliff_integration.gd
git commit -m "feat(terrain): use sloped cliff scenes in variant loader"
```

---

## Task 9: Full regression + in-world visual check

**Files:** none (verification only).

- [ ] **Step 1: Run the full test suite**

Run: `$GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json -gexit`
Expected: all tests pass — especially the existing `test_heightfield_*`, `test_module_index`, `test_terrain_module_library`, `test_biomes`, `test_water_rule`. These should be unaffected because tags, size (`24x24x4`), and socket layouts are unchanged.

If a heightfield/module test fails, inspect whether it asserts on the old scene path or on part-node names; update the assertion only if it legitimately encodes the old (sheer) scene structure, not the contract.

- [ ] **Step 2: Render the world**

Use `mcp__godot__run_project` on `scenes/world.tscn`, then `mcp__godot__game_screenshot`. Confirm:
- Cliffs now show grass-covered sigmoid slopes, flat walkable plateau tops.
- No gaps/cracks at tile boundaries between adjacent cliff variants.
- Slopes meet the lower ground continuously.

- [ ] **Step 3: Commit (docs/screenshot note if desired)**

```bash
git commit --allow-empty -m "test(terrain): verify sloped cliffs render and pass regression"
```

---

## Task 10: Update terrain README

**Files:**
- Modify: `terrain/TERRAIN_README.md`

- [ ] **Step 1: Document the slope pipeline**

Append a section to `terrain/TERRAIN_README.md` describing: the procedural slope components live in `terrain/gltf/slope/`, the assembled variants in `terrain/scenes/slope/`, both are regenerated by `scripts/terrain/tools/bake_slope_cliffs.gd` (give the run command), and that profile/scope params live in `SlopeProfile.gd`. Note that the original KayKit cliff scenes remain in `terrain/scenes/` for rollback (repoint `load_cliff_variant`).

- [ ] **Step 2: Commit**

```bash
git add terrain/TERRAIN_README.md
git commit -m "docs(terrain): document sloped cliff bake pipeline"
```

---

## Self-review notes (for the executor)

- **Spec coverage:** profile/continuity (T1), grass texture match (T2), 4 components (T3), collision convex ramp (T3/T5), 14-variant assembly (T4/T6), socket parity / heightfield untouched (T6/T9), swap-in with rollback (T8), subfolders (T5/T6), verification (T7/T9). All spec sections map to a task.
- **Known soft spots requiring the verification gate:** (a) rotation-sign of `EDGE_ANGLE`/`CORNER_ANGLE` — resolved visually in T7; (b) whether `top` cells are needed for plateau coverage — included by default, trimmed only if T7 shows z-fighting/overlap.
- **Type consistency:** component keys `"top"/"edge"/"outer"/"inner"` are consistent across `SlopeVariantLayout` and the baker's `COMPONENT_PATHS`; generator methods `build_top/edge/outer_corner/inner_corner` + `*_collision` consistent between T3 and T5/T6.
