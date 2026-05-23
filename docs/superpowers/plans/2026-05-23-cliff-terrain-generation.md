# Cliff Terrain Generation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add cliff-bordered plateaus (4-unit tall vertical drops) to terrain generation, mirroring the existing level edge-rule pattern with a 4-variant cliff set (edge / outer-corner / inner-corner / inner-corner-diag) plus a cliff-interior that reuses the ground-tile scene.

**Architecture:** All cliff variants share an identical socket layout. They are placed by the standard generator with `required=["cliff"]` cardinals and high lateral fill. A new `CliffEdgeRule` re-tiles each placed cliff piece based on its actual connectivity, falling back to "leave unchanged" for transient invalid configurations. Includes a one-shot migration to 3D size tags (`"24x24"` → `"24x24x0.5"`, etc.) so cliffs (`"24x24x4"`) can share the size-tag mechanism for test-piece lookup at the correct heights.

**Tech Stack:** Godot 4, typed GDScript. Test framework: GUT. Run tests with `godot --path /Users/ryko/story -s res://addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json`.

**Spec:** [docs/superpowers/specs/2026-05-23-cliff-terrain-generation-design.md](../specs/2026-05-23-cliff-terrain-generation-design.md)

---

## File Structure

**New files:**
- `terrain/scenes/CliffSide.tscn` — cliff edge variant (user-authored)
- `terrain/scenes/CliffCorner.tscn` — cliff outer-corner variant (user-authored)
- `terrain/scenes/CliffInCorner.tscn` — cliff inner-corner variant (user-authored)
- `terrain/scenes/CliffInCornerDiag.tscn` — cliff inner-corner-diag variant (user-authored)
- `scripts/terrain/rules/CliffEdgeRule.gd` — cliff retiling rule
- `docs/future-work/directional-socket-tags.md` — future-work note

**Modified files:**
- `scripts/terrain/TerrainModuleDefinitions.gd` — 3D size tag migration, cliff module loaders, `_build_cliff_tile()` helper, `create_24x24x4_test_piece()`, ground-tile seeding update
- `scripts/terrain/TerrainModuleLibrary.gd` — register cliff modules and cliff test piece
- `scripts/terrain/TerrainGenerationRuleLibrary.gd` — register `CliffEdgeRule`
- `tests/test_terrain_generator.gd` — size-tag string updates, cliff integration tests, `CliffEdgeRule.module_by_cliff_tag.clear()` in `after_each()`
- `tests/test_terrain_module_library.gd` — size-tag string updates
- `terrain/TERRAIN_README.md` — note convention for tall tiles

**Deleted files:**
- `docs/future-work/cliffs-and-floating-islands.md` — superseded by this spec

---

## Task 1: Migrate hard-coded size tags to 3D format

**Files:**
- Modify: `scripts/terrain/TerrainModuleDefinitions.gd` (all occurrences of `"24x24"`, `"12x12"`, `"8x8"`)
- Modify: `tests/test_terrain_module_library.gd` (lines 17, 26, 132)
- Modify: `tests/test_terrain_generator.gd` (any occurrences of size strings — verify with grep below)

- [ ] **Step 1: Grep for all hardcoded size strings to confirm scope**

Run: `grep -rn '"24x24"\|"12x12"\|"8x8"' scripts tests`

Expected: occurrences in `TerrainModuleDefinitions.gd` (~30 lines), `test_terrain_module_library.gd` (3 lines), possibly `test_terrain_generator.gd`. Note every line so none are missed in the replace.

- [ ] **Step 2: Replace size strings in TerrainModuleDefinitions.gd**

In [scripts/terrain/TerrainModuleDefinitions.gd](../../../scripts/terrain/TerrainModuleDefinitions.gd), perform exact-text replacements:
- `"24x24"` → `"24x24x0.5"` (everywhere)
- `"12x12"` → `"12x12x2"` (everywhere)
- `"8x8"` → `"8x8x2"` (everywhere)

Verify no `"point"` is touched — that one stays the same.

- [ ] **Step 3: Replace size strings in test files**

In [tests/test_terrain_module_library.gd](../../../tests/test_terrain_module_library.gd) and [tests/test_terrain_generator.gd](../../../tests/test_terrain_generator.gd) (only where they match the same literals), apply the same renames as Step 2.

- [ ] **Step 4: Run the full test suite**

Run: `godot --path /Users/ryko/story -s res://addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json`

Expected: all tests pass. Size tag rename is mechanical — any failure means a hardcoded string was missed.

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/TerrainModuleDefinitions.gd tests/test_terrain_module_library.gd tests/test_terrain_generator.gd
git commit -m "refactor(terrain): migrate size tags to 3D (24x24x0.5, 12x12x2, 8x8x2)"
```

---

## Task 2: Verify cliff scene files and their socket layouts

**Files:**
- Verify: `terrain/scenes/CliffSide.tscn`
- Verify: `terrain/scenes/CliffCorner.tscn`
- Verify: `terrain/scenes/CliffInCorner.tscn`
- Verify: `terrain/scenes/CliffInCornerDiag.tscn`
- Add test: `tests/test_terrain_generator.gd` (new test function)

This task verifies that the user has authored the cliff scenes with the socket layout required by the spec. Required sockets and local positions:

| Socket | Local position |
|---|---|
| `front` | `(0, 0, -12)` |
| `back` | `(0, 0, 12)` |
| `left` | `(-12, 0, 0)` |
| `right` | `(12, 0, 0)` |
| `frontleft` | `(-12, 0, -12)` |
| `frontright` | `(12, 0, -12)` |
| `backleft` | `(-12, 0, 12)` |
| `backright` | `(12, 0, 12)` |
| `bottom` | `(0, -4, 0)` |
| `topcenter` | `(0, 0, 0)` |

- [ ] **Step 1: Confirm all 4 cliff scene files exist on disk**

Run: `ls terrain/scenes/Cliff*.tscn`

Expected: 4 files listed. If any are missing, stop and ask the user to create them before proceeding.

- [ ] **Step 2: Add a socket-layout verification test in tests/test_terrain_generator.gd**

Append this test to [tests/test_terrain_generator.gd](../../../tests/test_terrain_generator.gd) (place near other unit tests, not integration tests):

```gdscript
func test_cliff_scenes_have_correct_socket_layout() -> void:
	var expected_sockets: Dictionary[String, Vector3] = {
		"front": Vector3(0, 0, -12),
		"back": Vector3(0, 0, 12),
		"left": Vector3(-12, 0, 0),
		"right": Vector3(12, 0, 0),
		"frontleft": Vector3(-12, 0, -12),
		"frontright": Vector3(12, 0, -12),
		"backleft": Vector3(-12, 0, 12),
		"backright": Vector3(12, 0, 12),
		"bottom": Vector3(0, -4, 0),
		"topcenter": Vector3(0, 0, 0),
	}
	var scene_paths: Array[String] = [
		"res://terrain/scenes/CliffSide.tscn",
		"res://terrain/scenes/CliffCorner.tscn",
		"res://terrain/scenes/CliffInCorner.tscn",
		"res://terrain/scenes/CliffInCornerDiag.tscn",
	]
	for path in scene_paths:
		var scene: PackedScene = load(path)
		assert_not_null(scene, "Scene must load: %s" % path)
		var root: Node = scene.instantiate()
		_track_node_for_cleanup(root)
		var sockets_node: Node = root.get_node_or_null("Sockets")
		assert_not_null(sockets_node, "Scene must have Sockets node: %s" % path)
		var actual_sockets: Dictionary[String, Vector3] = {}
		for child in sockets_node.get_children():
			var marker: Marker3D = child as Marker3D
			if marker == null:
				continue
			actual_sockets[String(marker.name)] = marker.transform.origin
		for socket_name in expected_sockets.keys():
			var expected_pos: Vector3 = expected_sockets[socket_name]
			assert_true(
				actual_sockets.has(socket_name),
				"Scene %s missing socket '%s'" % [path, socket_name]
			)
			assert_eq(
				actual_sockets[socket_name],
				expected_pos,
				"Scene %s socket '%s' position mismatch" % [path, socket_name]
			)
		assert_eq(
			actual_sockets.size(),
			expected_sockets.size(),
			"Scene %s has extra sockets: %s" % [path, str(actual_sockets.keys())]
		)
```

- [ ] **Step 3: Run the new test**

Run: `godot --path /Users/ryko/story -s res://addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json -gtest=res://tests/test_terrain_generator.gd -gunit_test_name=test_cliff_scenes_have_correct_socket_layout`

Expected: PASS. If FAIL, the offending scene needs socket-layout corrections from the user before proceeding.

- [ ] **Step 4: Commit**

```bash
git add tests/test_terrain_generator.gd
git commit -m "test(terrain): verify cliff scene socket layouts match spec"
```

---

## Task 3: Add `create_24x24x4_test_piece()` to TerrainModuleDefinitions

**Files:**
- Modify: `scripts/terrain/TerrainModuleDefinitions.gd` (add new function near other `create_*_test_piece` functions, ~line 690)
- Modify: `scripts/terrain/TerrainModuleLibrary.gd` (register in `load_test_pieces()`, ~line 31)
- Test: `tests/test_terrain_generator.gd` (new test)

- [ ] **Step 1: Write the failing test**

Append to [tests/test_terrain_generator.gd](../../../tests/test_terrain_generator.gd):

```gdscript
func test_24x24x4_test_piece_uses_cliff_socket_layout() -> void:
	var lib: TerrainModuleLibrary = TerrainModuleLibrary.new()
	_track_node_for_cleanup(lib)
	lib.init_test_pieces()

	var matches: TerrainModuleList = lib.get_by_tags(TagList.new(["24x24x4"]))
	assert_eq(matches.size(), 1, "Should have exactly one 24x24x4 test piece")
	var module: TerrainModule = matches.library[0]

	var inst: TerrainModuleInstance = module.spawn()
	_pieces_to_destroy.append(inst)
	inst.create()

	assert_eq(inst.sockets["bottom"].transform.origin, Vector3(0, -4, 0))
	assert_eq(inst.sockets["front"].transform.origin, Vector3(0, 0, -12))
	assert_eq(inst.sockets["back"].transform.origin, Vector3(0, 0, 12))
	assert_eq(inst.sockets["left"].transform.origin, Vector3(-12, 0, 0))
	assert_eq(inst.sockets["right"].transform.origin, Vector3(12, 0, 0))
```

- [ ] **Step 2: Run test, verify it fails**

Run: `godot --path /Users/ryko/story -s res://addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json -gtest=res://tests/test_terrain_generator.gd -gunit_test_name=test_24x24x4_test_piece_uses_cliff_socket_layout`

Expected: FAIL with `Should have exactly one 24x24x4 test piece` (size 0).

- [ ] **Step 3: Implement `create_24x24x4_test_piece()`**

In [scripts/terrain/TerrainModuleDefinitions.gd](../../../scripts/terrain/TerrainModuleDefinitions.gd), add this function just below `create_24x24_test_piece()` (~end of file):

```gdscript
static func create_24x24x4_test_piece() -> TerrainModule:
	# Test piece for cliffs (24x24 footprint, 4 units tall).
	# Uses CliffSide.tscn for its socket layout (cardinals at local y=0, bottom at local y=-4).
	# The visual is irrelevant — only sockets matter for adjacency probing.
	var scene = load("res://terrain/scenes/CliffSide.tscn")
	var tags: TagList = TagList.new(["24x24x4"])
	var tags_per_socket: Dictionary[String, TagList] = {}
	# Override AABB to match cliff dimensions: 24x24x4, base at y=-4 relative to origin.
	var bb: AABB = AABB(Vector3(-12, -4, -12), Vector3(24, 4, 24))

	var socket_size: Dictionary[String, Distribution] = {
		"front": Distribution.new({"24x24x4": 1.0}),
		"back": Distribution.new({"24x24x4": 1.0}),
		"left": Distribution.new({"24x24x4": 1.0}),
		"right": Distribution.new({"24x24x4": 1.0}),
		"topcenter": Distribution.new({"24x24x4": 1.0}),
		"bottom": Distribution.new({"24x24x0.5": 1.0}),
	}
	var socket_required: Dictionary[String, TagList] = {}
	# Every scene socket must have an entry (asserted by TerrainModule).
	# Test pieces don't expand; null = blocking-but-not-fillable.
	var socket_fill_prob: Dictionary[String, Variant] = {
		"front": 0.0,
		"back": 0.0,
		"left": 0.0,
		"right": 0.0,
		"frontleft": null,
		"frontright": null,
		"backleft": null,
		"backright": null,
		"bottom": 0.0,
		"topcenter": 0.0,
	}
	var socket_tag_prob: Dictionary[String, Distribution] = {}

	return TerrainModule.new(
		scene,
		bb,
		tags,
		tags_per_socket,
		[],
		socket_size,
		socket_required,
		socket_fill_prob,
		socket_tag_prob,
		false
	)
```

- [ ] **Step 4: Register the test piece in TerrainModuleLibrary**

In [scripts/terrain/TerrainModuleLibrary.gd](../../../scripts/terrain/TerrainModuleLibrary.gd), update `load_test_pieces()` (~line 31):

```gdscript
func load_test_pieces() -> void:
	terrain_modules.append(TerrainModuleDefinitions.create_8x8_test_piece())
	terrain_modules.append(TerrainModuleDefinitions.create_12x12_test_piece())
	terrain_modules.append(TerrainModuleDefinitions.create_24x24_test_piece())
	terrain_modules.append(TerrainModuleDefinitions.create_24x24x4_test_piece())
```

- [ ] **Step 5: Run the test, verify it passes**

Run: `godot --path /Users/ryko/story -s res://addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json -gtest=res://tests/test_terrain_generator.gd -gunit_test_name=test_24x24x4_test_piece_uses_cliff_socket_layout`

Expected: PASS.

- [ ] **Step 6: Run the full test suite to catch regressions**

Run: `godot --path /Users/ryko/story -s res://addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json`

Expected: all tests pass.

- [ ] **Step 7: Commit**

```bash
git add scripts/terrain/TerrainModuleDefinitions.gd scripts/terrain/TerrainModuleLibrary.gd tests/test_terrain_generator.gd
git commit -m "feat(terrain): add 24x24x4 test piece for cliff adjacency probing"
```

---

## Task 4: Add `_build_cliff_tile()` helper and cliff-edge module loader

**Files:**
- Modify: `scripts/terrain/TerrainModuleDefinitions.gd` (add `_build_cliff_tile()` helper and `load_cliff_edge_tile()`)
- Test: `tests/test_terrain_generator.gd` (new test)

- [ ] **Step 1: Write the failing test**

Append to [tests/test_terrain_generator.gd](../../../tests/test_terrain_generator.gd):

```gdscript
func test_cliff_edge_tile_has_correct_tags_and_socket_config() -> void:
	var module: TerrainModule = TerrainModuleDefinitions.load_cliff_edge_tile()
	assert_not_null(module)
	assert_true(module.tags.has("cliff"))
	assert_true(module.tags.has("cliff-edge"))
	assert_true(module.tags.has("24x24x4"))
	assert_true(module.replace_existing)

	# Cardinal sockets must require cliff and have high fill prob.
	for socket_name in ["front", "back", "left", "right"]:
		assert_true(
			module.socket_required.has(socket_name),
			"Missing socket_required for %s" % socket_name
		)
		assert_true(
			module.socket_required[socket_name].has("cliff"),
			"Cardinal %s must require cliff" % socket_name
		)
		assert_almost_eq(
			float(module.socket_fill_prob[socket_name]),
			0.7,
			0.001,
			"Cardinal %s must have high fill prob" % socket_name
		)

	# Bottom is non-expandable (attaches to ground, doesn't seek neighbors).
	assert_eq(module.socket_fill_prob["bottom"], null)
```

- [ ] **Step 2: Run test, verify it fails**

Run: `godot --path /Users/ryko/story -s res://addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json -gtest=res://tests/test_terrain_generator.gd -gunit_test_name=test_cliff_edge_tile_has_correct_tags_and_socket_config`

Expected: FAIL — `load_cliff_edge_tile` doesn't exist.

- [ ] **Step 3: Add constants and `_build_cliff_tile()` helper**

In [scripts/terrain/TerrainModuleDefinitions.gd](../../../scripts/terrain/TerrainModuleDefinitions.gd), add these constants near the top of the class (just after the existing `LEVEL_BASE_LATERAL_FILL_PROB` / `LEVEL_TOPCENTER_FILL_PROB`):

```gdscript
const CLIFF_LATERAL_FILL_PROB: float = 0.7
```

Then add `_build_cliff_tile()` near `_build_level_tile()` (around line 545):

```gdscript
static func _build_cliff_tile(
	scene_path: String,
	tags: TagList
) -> TerrainModule:
	# All cliff edge variants share an identical socket layout:
	#   - Cardinals at top elevation, required=cliff, high lateral fill.
	#   - Diagonals are null (markers for inner-corner detection only).
	#   - Bottom attaches to a ground tile below (no expansion).
	#   - Topcenter inherits ground-tile distribution (grass/trees/multi-storey cliffs).
	var scene: PackedScene = load(scene_path)
	var tags_per_socket: Dictionary[String, TagList] = {}
	var bb: AABB = AABB(Vector3(-12, -4, -12), Vector3(24, 4, 24))

	var socket_size: Dictionary[String, Distribution] = {
		"front": Distribution.new({"24x24x4": 1.0}),
		"back": Distribution.new({"24x24x4": 1.0}),
		"left": Distribution.new({"24x24x4": 1.0}),
		"right": Distribution.new({"24x24x4": 1.0}),
		"topcenter": Distribution.new({"24x24x0.5": 1.0}),
		"bottom": Distribution.new({"24x24x0.5": 1.0}),
	}
	var socket_required: Dictionary[String, TagList] = {
		"front": TagList.new(["cliff"]),
		"back": TagList.new(["cliff"]),
		"left": TagList.new(["cliff"]),
		"right": TagList.new(["cliff"]),
		"bottom": TagList.new(["ground"]),
	}
	var socket_fill_prob: Dictionary[String, Variant] = {
		"front": CLIFF_LATERAL_FILL_PROB,
		"back": CLIFF_LATERAL_FILL_PROB,
		"left": CLIFF_LATERAL_FILL_PROB,
		"right": CLIFF_LATERAL_FILL_PROB,
		"frontleft": null,
		"frontright": null,
		"backleft": null,
		"backright": null,
		"bottom": null,
		"topcenter": 0.2,
	}
	# Cliff cardinals favor more cliff growth; topcenter mirrors a ground tile's mix.
	var cliff_lateral_dist: Distribution = Distribution.new({"cliff": 1.0})
	var topcenter_dist: Distribution = Distribution.new({
		"grass": 0.3,
		"rock": 0.2,
		"bush": 0.2,
		"tree": 0.2,
		"hill": 0.1,
	})
	var socket_tag_prob: Dictionary[String, Distribution] = {
		"front": cliff_lateral_dist,
		"back": cliff_lateral_dist,
		"left": cliff_lateral_dist,
		"right": cliff_lateral_dist,
		"topcenter": topcenter_dist,
	}

	return TerrainModule.new(
		scene,
		bb,
		tags,
		tags_per_socket,
		[],
		socket_size,
		socket_required,
		socket_fill_prob,
		socket_tag_prob,
		true  # replace_existing
	)
```

- [ ] **Step 4: Add `load_cliff_edge_tile()`**

In the same file, add this loader function just after the level loaders (before `_build_level_tile`):

```gdscript
static func load_cliff_edge_tile() -> TerrainModule:
	return _build_cliff_tile(
		"res://terrain/scenes/CliffSide.tscn",
		TagList.new(["cliff", "cliff-edge", "24x24x4"])
	)
```

- [ ] **Step 5: Run the test, verify it passes**

Run: `godot --path /Users/ryko/story -s res://addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json -gtest=res://tests/test_terrain_generator.gd -gunit_test_name=test_cliff_edge_tile_has_correct_tags_and_socket_config`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add scripts/terrain/TerrainModuleDefinitions.gd tests/test_terrain_generator.gd
git commit -m "feat(terrain): add cliff-edge module loader and _build_cliff_tile helper"
```

---

## Task 5: Add the remaining 3 cliff edge variant loaders

**Files:**
- Modify: `scripts/terrain/TerrainModuleDefinitions.gd`
- Test: `tests/test_terrain_generator.gd`

- [ ] **Step 1: Write the failing test**

Append:

```gdscript
func test_all_cliff_edge_variants_load() -> void:
	var variants: Dictionary[String, Callable] = {
		"cliff-outer-corner": TerrainModuleDefinitions.load_cliff_outer_corner_tile,
		"cliff-inner-corner": TerrainModuleDefinitions.load_cliff_inner_corner_tile,
		"cliff-inner-corner-diag": TerrainModuleDefinitions.load_cliff_inner_corner_diag_tile,
	}
	for variant_tag in variants.keys():
		var module: TerrainModule = variants[variant_tag].call()
		assert_not_null(module, "Module loader failed for %s" % variant_tag)
		assert_true(module.tags.has("cliff"), "%s missing 'cliff' tag" % variant_tag)
		assert_true(module.tags.has(variant_tag), "%s missing '%s' tag" % [variant_tag, variant_tag])
		assert_true(module.tags.has("24x24x4"), "%s missing '24x24x4' tag" % variant_tag)
		assert_true(module.replace_existing, "%s must have replace_existing" % variant_tag)
```

- [ ] **Step 2: Run test, verify it fails**

Expected: FAIL with `load_cliff_outer_corner_tile` undefined.

- [ ] **Step 3: Add the 3 remaining loaders**

In [scripts/terrain/TerrainModuleDefinitions.gd](../../../scripts/terrain/TerrainModuleDefinitions.gd), just after `load_cliff_edge_tile()`:

```gdscript
static func load_cliff_outer_corner_tile() -> TerrainModule:
	return _build_cliff_tile(
		"res://terrain/scenes/CliffCorner.tscn",
		TagList.new(["cliff", "cliff-outer-corner", "24x24x4"])
	)


static func load_cliff_inner_corner_tile() -> TerrainModule:
	return _build_cliff_tile(
		"res://terrain/scenes/CliffInCorner.tscn",
		TagList.new(["cliff", "cliff-inner-corner", "24x24x4"])
	)


static func load_cliff_inner_corner_diag_tile() -> TerrainModule:
	return _build_cliff_tile(
		"res://terrain/scenes/CliffInCornerDiag.tscn",
		TagList.new(["cliff", "cliff-inner-corner-diag", "24x24x4"])
	)
```

- [ ] **Step 4: Run test, verify it passes**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/TerrainModuleDefinitions.gd tests/test_terrain_generator.gd
git commit -m "feat(terrain): add cliff outer-corner, inner-corner, inner-corner-diag loaders"
```

---

## Task 6: Add the cliff-interior module loader

**Files:**
- Modify: `scripts/terrain/TerrainModuleDefinitions.gd`
- Test: `tests/test_terrain_generator.gd`

- [ ] **Step 1: Write the failing test**

Append:

```gdscript
func test_cliff_interior_tile_uses_ground_scene_with_cliff_tag() -> void:
	var module: TerrainModule = TerrainModuleDefinitions.load_cliff_interior_tile()
	assert_not_null(module)
	# Visually a ground tile.
	assert_eq(module.scene.resource_path, "res://terrain/scenes/GroundTile.tscn")
	# Tagged for cliff connectivity AND ground-style topcenter behavior.
	assert_true(module.tags.has("cliff"), "cliff-interior must have 'cliff' tag")
	assert_true(module.tags.has("ground-type"), "cliff-interior must have 'ground-type' tag")
	assert_true(module.tags.has("24x24x4"), "cliff-interior must use cliff size tag")
	assert_true(module.replace_existing, "cliff-interior must replace_existing for rule swap")
	# Lateral cardinals are NON-expandable (the perimeter is covered by cliff-edges).
	for socket_name in ["front", "back", "left", "right"]:
		assert_eq(
			module.socket_fill_prob[socket_name],
			null,
			"cliff-interior %s must be non-expandable" % socket_name
		)
```

- [ ] **Step 2: Run test, verify it fails**

Expected: FAIL — `load_cliff_interior_tile` undefined.

- [ ] **Step 3: Add `load_cliff_interior_tile()`**

In [scripts/terrain/TerrainModuleDefinitions.gd](../../../scripts/terrain/TerrainModuleDefinitions.gd), add this function right after `load_cliff_inner_corner_diag_tile()`:

```gdscript
static func load_cliff_interior_tile() -> TerrainModule:
	# Cliff plateau interior: visually a ground tile, but tagged "cliff" so neighbour
	# cliff-edges' required-tag filters remain satisfied. Lateral cardinals are
	# non-expandable because the plateau perimeter is covered by cliff-edges; we
	# don't want the interior to spawn more lateral tiles. Topcenter mirrors a
	# normal ground tile (grass/trees/multi-storey cliff seeding).
	var scene: PackedScene = load("res://terrain/scenes/GroundTile.tscn")
	var tags: TagList = TagList.new(["cliff", "cliff-interior", "ground-type", "24x24x4"])
	var tags_per_socket: Dictionary[String, TagList] = {}
	var bb: AABB = AABB(Vector3(-12, -0.5, -12), Vector3(24, 0.5, 24))

	var top_size_dist_corners: Distribution = Distribution.new({"point": 0.9, "12x12x2": 0.1})
	var top_size_dist_cardinal: Distribution = Distribution.new({"point": 0.9, "8x8x2": 0.1})
	var top_size_dist_center: Distribution = Distribution.new({"24x24x0.5": 1.0})
	var top_tag_prob_corners: Distribution = Distribution.new({"grass": 0.3, "rock": 0.2, "bush": 0.2, "tree": 0.2, "hill": 0.1})
	var top_tag_prob_cardinal: Distribution = top_tag_prob_corners
	var top_tag_prob_center: Distribution = Distribution.new({"level-ground-center": 0.95, "cliff-edge": 0.05})

	var socket_size: Dictionary[String, Distribution] = {
		"front": Distribution.new({"24x24x4": 1.0}),
		"back": Distribution.new({"24x24x4": 1.0}),
		"right": Distribution.new({"24x24x4": 1.0}),
		"left": Distribution.new({"24x24x4": 1.0}),
		"topfront": top_size_dist_cardinal,
		"topback": top_size_dist_cardinal,
		"topleft": top_size_dist_cardinal,
		"topright": top_size_dist_cardinal,
		"topcenter": top_size_dist_center,
		"topfrontright": top_size_dist_corners,
		"topfrontleft": top_size_dist_corners,
		"topbackright": top_size_dist_corners,
		"topbackleft": top_size_dist_corners,
	}
	var socket_required: Dictionary[String, TagList] = {}
	var socket_fill_prob: Dictionary[String, Variant] = {
		"front": null,
		"back": null,
		"right": null,
		"left": null,
		"topfront": 0.05,
		"topback": 0.05,
		"topleft": 0.05,
		"topright": 0.05,
		"topfrontright": 0.05,
		"topfrontleft": 0.05,
		"topbackright": 0.05,
		"topbackleft": 0.05,
		"topcenter": 0.2,
		"bottom": null,
	}
	var socket_tag_prob: Dictionary[String, Distribution] = {
		"topfront": top_tag_prob_cardinal,
		"topback": top_tag_prob_cardinal,
		"topleft": top_tag_prob_cardinal,
		"topright": top_tag_prob_cardinal,
		"topfrontright": top_tag_prob_corners,
		"topfrontleft": top_tag_prob_corners,
		"topbackright": top_tag_prob_corners,
		"topbackleft": top_tag_prob_corners,
		"topcenter": top_tag_prob_center,
	}

	return TerrainModule.new(
		scene,
		bb,
		tags,
		tags_per_socket,
		[],
		socket_size,
		socket_required,
		socket_fill_prob,
		socket_tag_prob,
		true  # replace_existing
	)
```

- [ ] **Step 4: Run test, verify it passes**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/TerrainModuleDefinitions.gd tests/test_terrain_generator.gd
git commit -m "feat(terrain): add cliff-interior module (GroundTile scene with cliff tag)"
```

---

## Task 7: Register cliff modules in TerrainModuleLibrary

**Files:**
- Modify: `scripts/terrain/TerrainModuleLibrary.gd`
- Test: `tests/test_terrain_module_library.gd`

- [ ] **Step 1: Write the failing test**

Append to [tests/test_terrain_module_library.gd](../../../tests/test_terrain_module_library.gd):

```gdscript
func test_library_registers_all_cliff_variants() -> void:
	var lib: TerrainModuleLibrary = TerrainModuleLibrary.new()
	lib.init()

	for variant_tag in ["cliff-edge", "cliff-outer-corner", "cliff-inner-corner", "cliff-inner-corner-diag", "cliff-interior"]:
		assert_true(
			lib.modules_by_tag.has(variant_tag),
			"Library missing variant: %s" % variant_tag
		)
	# The "cliff" tag should map to all 5 variants.
	assert_eq(lib.modules_by_tag["cliff"].size(), 5, "All 5 cliff modules should carry 'cliff' tag")
```

- [ ] **Step 2: Run test, verify it fails**

Expected: FAIL — `modules_by_tag` doesn't contain `cliff-edge` etc.

- [ ] **Step 3: Register cliff modules in `load_terrain_modules()`**

In [scripts/terrain/TerrainModuleLibrary.gd](../../../scripts/terrain/TerrainModuleLibrary.gd), update `load_terrain_modules()` (~line 19):

```gdscript
func load_terrain_modules() -> void:
	terrain_modules.append(TerrainModuleDefinitions.load_ground_tile())
	terrain_modules.append(TerrainModuleDefinitions.load_grass_tile())
	terrain_modules.append(TerrainModuleDefinitions.load_bush_tile())
	terrain_modules.append(TerrainModuleDefinitions.load_rock_tile())
	terrain_modules.append(TerrainModuleDefinitions.load_tree_tile())
	terrain_modules.append(TerrainModuleDefinitions.load_8x8x2_tile())
	terrain_modules.append(TerrainModuleDefinitions.load_12x12x2_tile())
	terrain_modules.append(TerrainModuleDefinitions.load_level_middle_tile())
	terrain_modules.append(TerrainModuleDefinitions.load_level_stack_middle_tile())
	terrain_modules.append(TerrainModuleDefinitions.load_cliff_edge_tile())
	terrain_modules.append(TerrainModuleDefinitions.load_cliff_outer_corner_tile())
	terrain_modules.append(TerrainModuleDefinitions.load_cliff_inner_corner_tile())
	terrain_modules.append(TerrainModuleDefinitions.load_cliff_inner_corner_diag_tile())
	terrain_modules.append(TerrainModuleDefinitions.load_cliff_interior_tile())
```

- [ ] **Step 4: Run test, verify it passes**

Expected: PASS.

- [ ] **Step 5: Run full test suite**

Run: `godot --path /Users/ryko/story -s res://addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json`

Expected: all tests pass (no regressions from added modules).

- [ ] **Step 6: Commit**

```bash
git add scripts/terrain/TerrainModuleLibrary.gd tests/test_terrain_module_library.gd
git commit -m "feat(terrain): register cliff modules in TerrainModuleLibrary"
```

---

## Task 8: Update ground-tile seeding to spawn cliffs

**Files:**
- Modify: `scripts/terrain/TerrainModuleDefinitions.gd` (`load_ground_tile()`, ~line 9)
- Test: `tests/test_terrain_generator.gd`

- [ ] **Step 1: Write the failing test**

Append:

```gdscript
func test_ground_tile_topcenter_can_seed_cliff() -> void:
	var module: TerrainModule = TerrainModuleDefinitions.load_ground_tile()
	var topcenter_dist: Distribution = module.socket_tag_prob.get("topcenter")
	assert_not_null(topcenter_dist)
	assert_true(topcenter_dist.dist.has("cliff-edge"), "Ground topcenter must seed cliff-edge")
	assert_true(topcenter_dist.dist.has("level-ground-center"), "Ground topcenter must still seed level")

	var top_size_dist: Distribution = module.socket_size.get("topcenter")
	assert_true(top_size_dist.dist.has("24x24x4"), "Ground topcenter must include 24x24x4 size for cliffs")
	assert_true(top_size_dist.dist.has("24x24x0.5"), "Ground topcenter must still include 24x24x0.5 size for levels")
```

- [ ] **Step 2: Run test, verify it fails**

Expected: FAIL — topcenter dist doesn't include `cliff-edge` or `24x24x4`.

- [ ] **Step 3: Update `load_ground_tile()` distributions**

In [scripts/terrain/TerrainModuleDefinitions.gd](../../../scripts/terrain/TerrainModuleDefinitions.gd), find the lines defining `top_size_dist_center` and `top_tag_prob_center` (~lines 20, 25) and change them to:

```gdscript
	var top_size_dist_center: Distribution = Distribution.new({"24x24x0.5": 0.95, "24x24x4": 0.05})
	...
	var top_tag_prob_center: Distribution = Distribution.new({"level-ground-center": 0.95, "cliff-edge": 0.05})
```

- [ ] **Step 4: Run the test, verify it passes**

Expected: PASS.

- [ ] **Step 5: Run the full test suite**

Expected: all tests pass. Existing level tests should still pass (95% rate means levels still dominate seeding).

- [ ] **Step 6: Commit**

```bash
git add scripts/terrain/TerrainModuleDefinitions.gd tests/test_terrain_generator.gd
git commit -m "feat(terrain): seed cliffs from ground tile topcenter at 5% (1% net rate)"
```

---

## Task 9: Implement `CliffEdgeRule` (skeleton + matches)

**Files:**
- Create: `scripts/terrain/rules/CliffEdgeRule.gd`
- Test: `tests/test_terrain_generator.gd`

- [ ] **Step 1: Write the failing test**

Append:

```gdscript
func test_cliff_edge_rule_matches_cliff_tagged_pieces_only() -> void:
	var rule: CliffEdgeRule = CliffEdgeRule.new()
	var cliff: TerrainModuleInstance = TerrainModuleDefinitions.load_cliff_edge_tile().spawn()
	_pieces_to_destroy.append(cliff)
	cliff.create()
	var grass: TerrainModuleInstance = TerrainModuleDefinitions.load_grass_tile().spawn()
	_pieces_to_destroy.append(grass)
	grass.create()

	assert_true(rule.matches({"chosen_piece": cliff}))
	assert_false(rule.matches({"chosen_piece": grass}))
	assert_false(rule.matches({}))
	assert_false(rule.matches({"chosen_piece": null}))
```

- [ ] **Step 2: Run test, verify it fails**

Expected: FAIL — `CliffEdgeRule` not defined.

- [ ] **Step 3: Create the skeleton CliffEdgeRule**

Create [scripts/terrain/rules/CliffEdgeRule.gd](../../../scripts/terrain/rules/CliffEdgeRule.gd):

```gdscript
class_name CliffEdgeRule
extends TerrainGenerationRule

const CARDINAL_SOCKETS: Array[String] = ["front", "right", "back", "left"]
const DIAGONAL_SOCKETS: Array[String] = ["frontright", "backright", "backleft", "frontleft"]
const SAME_LEVEL_EPS: float = 0.1

# Canonical missing-socket patterns for each cliff variant.
const CANONICAL_MISSING_BY_TAG: Dictionary[String, Array] = {
	"cliff-edge": ["front"],
	"cliff-outer-corner": ["front", "left"],
	"cliff-inner-corner": ["frontleft"],
	"cliff-inner-corner-diag": ["frontleft", "backright"],
}
# Order checked: most-constrained first (so inner-corner-diag with both diagonals
# wins over inner-corner with just one).
const CLIFF_TAG_ORDER: Array[String] = [
	"cliff-inner-corner-diag",
	"cliff-inner-corner",
	"cliff-outer-corner",
	"cliff-edge",
]
const INNER_CORNER_CARDINALS_BY_DIAGONAL: Dictionary[String, Array] = {
	"frontleft": ["front", "left"],
	"frontright": ["front", "right"],
	"backright": ["back", "right"],
	"backleft": ["back", "left"]
}

static var module_by_cliff_tag: Dictionary = {}


func matches(context: Dictionary) -> bool:
	if not context.has("chosen_piece"):
		return false
	var chosen_piece: TerrainModuleInstance = context["chosen_piece"]
	if chosen_piece == null:
		return false
	return chosen_piece.def.tags.has("cliff")


func apply(context: Dictionary) -> Dictionary:
	# Stub for now; filled in over the next tasks.
	return {"chosen_piece": context.get("chosen_piece", null), "piece_updates": {}}
```

- [ ] **Step 4: Run the test, verify it passes**

Expected: PASS.

- [ ] **Step 5: Update `after_each()` to clear the static module cache**

In [tests/test_terrain_generator.gd](../../../tests/test_terrain_generator.gd), find the `after_each()` function and add a cache-clear line right after the existing `LevelEdgeRule.module_by_level_tag.clear()` (~line 95):

```gdscript
	# Reset static module caches to release loaded resources between tests.
	LevelEdgeRule.module_by_level_tag.clear()
	CliffEdgeRule.module_by_cliff_tag.clear()
```

- [ ] **Step 6: Commit**

```bash
git add scripts/terrain/rules/CliffEdgeRule.gd tests/test_terrain_generator.gd
git commit -m "feat(terrain): add CliffEdgeRule skeleton with matches() and constants"
```

---

## Task 10: Implement `CliffEdgeRule.apply()` — affected pieces & connectivity analysis

**Files:**
- Modify: `scripts/terrain/rules/CliffEdgeRule.gd`
- Test: `tests/test_terrain_generator.gd`

- [ ] **Step 1: Implement helper methods on CliffEdgeRule**

In [scripts/terrain/rules/CliffEdgeRule.gd](../../../scripts/terrain/rules/CliffEdgeRule.gd), append after `apply()`:

```gdscript
func _has_cliff_connection(
	piece: TerrainModuleInstance,
	socket_name: String,
	socket_index: PositionIndex
) -> bool:
	if not piece.sockets.has(socket_name):
		return false
	var piece_socket: TerrainModuleSocket = TerrainModuleSocket.new(piece, socket_name)
	var other: TerrainModuleSocket = socket_index.query_other(
		piece_socket.get_socket_position(),
		piece
	)
	return (
		other != null
		and other.piece != null
		and other.piece.def.tags.has("cliff")
	)


func _is_same_height(a: float, b: float) -> bool:
	return abs(a - b) <= SAME_LEVEL_EPS


func _diagonal_target_center(piece: TerrainModuleInstance, diagonal_socket_name: String) -> Variant:
	var required_cardinals: Array = INNER_CORNER_CARDINALS_BY_DIAGONAL.get(diagonal_socket_name, [])
	if required_cardinals.size() != 2:
		return null
	var first_cardinal: String = required_cardinals[0]
	var second_cardinal: String = required_cardinals[1]
	if not piece.sockets.has(first_cardinal) or not piece.sockets.has(second_cardinal):
		return null
	var center: Vector3 = piece.transform.origin
	var first_pos: Vector3 = TerrainModuleSocket.new(piece, first_cardinal).get_socket_position()
	var second_pos: Vector3 = TerrainModuleSocket.new(piece, second_cardinal).get_socket_position()
	var first_offset: Vector3 = first_pos - center
	var second_offset: Vector3 = second_pos - center
	return center + (first_offset + second_offset) * 2.0


func _get_diagonal_cliff_neighbor_piece(
	piece: TerrainModuleInstance,
	diagonal_socket_name: String,
	terrain_index: TerrainIndex
) -> TerrainModuleInstance:
	var diagonal_target: Variant = _diagonal_target_center(piece, diagonal_socket_name)
	if not (diagonal_target is Vector3):
		return null
	var target_pos: Vector3 = diagonal_target
	var query_box: AABB = AABB(target_pos + Vector3(-0.6, -2.0, -0.6), Vector3(1.2, 4.0, 1.2))
	var hits: Array = terrain_index.query_box(query_box)
	for hit in hits:
		if not (hit is TerrainModuleInstance):
			continue
		var other: TerrainModuleInstance = hit
		if other == piece:
			continue
		if not other.def.tags.has("cliff"):
			continue
		if not _is_same_height(piece.transform.origin.y, other.transform.origin.y):
			continue
		var delta: Vector3 = other.transform.origin - target_pos
		if abs(delta.x) <= 0.6 and abs(delta.z) <= 0.6:
			return other
	return null


func _has_diagonal_cliff_neighbor(
	piece: TerrainModuleInstance,
	diagonal_socket_name: String,
	terrain_index: TerrainIndex
) -> bool:
	return _get_diagonal_cliff_neighbor_piece(piece, diagonal_socket_name, terrain_index) != null


func _missing_sockets_for_piece(
	piece: TerrainModuleInstance,
	socket_index: PositionIndex,
	terrain_index: TerrainIndex
) -> Array[String]:
	var missing_cardinals: Array[String] = []
	var connected_cardinals: Dictionary[String, bool] = {}
	for socket_name in CARDINAL_SOCKETS:
		var connected: bool = _has_cliff_connection(piece, socket_name, socket_index)
		connected_cardinals[socket_name] = connected
		if not connected:
			missing_cardinals.append(socket_name)
	var missing_inner_diagonals: Array[String] = []
	for socket_name in DIAGONAL_SOCKETS:
		var required_cardinals: Array = INNER_CORNER_CARDINALS_BY_DIAGONAL.get(socket_name, [])
		if required_cardinals.size() != 2:
			continue
		var first_cardinal: String = required_cardinals[0]
		var second_cardinal: String = required_cardinals[1]
		if not connected_cardinals.get(first_cardinal, false):
			continue
		if not connected_cardinals.get(second_cardinal, false):
			continue
		if _has_diagonal_cliff_neighbor(piece, socket_name, terrain_index):
			continue
		missing_inner_diagonals.append(socket_name)
	return missing_cardinals + missing_inner_diagonals


func _get_cliff_neighbors(
	piece: TerrainModuleInstance,
	socket_index: PositionIndex,
	terrain_index: TerrainIndex
) -> Array[TerrainModuleInstance]:
	var neighbors: Array[TerrainModuleInstance] = []
	var seen: Dictionary = {}
	for socket_name in CARDINAL_SOCKETS:
		if not piece.sockets.has(socket_name):
			continue
		var piece_socket: TerrainModuleSocket = TerrainModuleSocket.new(piece, socket_name)
		var other: TerrainModuleSocket = socket_index.query_other(
			piece_socket.get_socket_position(),
			piece
		)
		if other == null or other.piece == null:
			continue
		if not other.piece.def.tags.has("cliff"):
			continue
		if seen.has(other.piece):
			continue
		seen[other.piece] = true
		neighbors.append(other.piece)
	for socket_name in DIAGONAL_SOCKETS:
		var diagonal_neighbor: TerrainModuleInstance = _get_diagonal_cliff_neighbor_piece(
			piece, socket_name, terrain_index
		)
		if diagonal_neighbor == null:
			continue
		if seen.has(diagonal_neighbor):
			continue
		seen[diagonal_neighbor] = true
		neighbors.append(diagonal_neighbor)
	return neighbors


func _add_unique_piece(
	pieces: Array[TerrainModuleInstance],
	seen: Dictionary,
	piece: TerrainModuleInstance
) -> void:
	if piece == null:
		return
	if seen.has(piece):
		return
	seen[piece] = true
	pieces.append(piece)
```

- [ ] **Step 2: Commit (pure helpers, no behaviour change yet)**

```bash
git add scripts/terrain/rules/CliffEdgeRule.gd
git commit -m "feat(terrain): CliffEdgeRule connectivity-analysis helpers"
```

---

## Task 11: Implement `CliffEdgeRule.apply()` — variant selection & rotation alignment

**Files:**
- Modify: `scripts/terrain/rules/CliffEdgeRule.gd`
- Test: `tests/test_terrain_generator.gd`

- [ ] **Step 1: Write the failing test**

Append:

```gdscript
func test_cliff_edge_rule_aligns_outer_corner_with_neighbors() -> void:
	# Place an outer-corner cliff with cliff neighbors on back and left only.
	# Rule should align canonical missing ["front","left"] to actual missing ["front","right"]
	# via rotation, ultimately producing an outer-corner facing back+right toward the cliffs.
	# Verify by checking the rule's canonical-missing lookup for a known pattern.
	var rule: CliffEdgeRule = CliffEdgeRule.new()
	var missing: Array[String] = ["front", "right"]
	# In CliffEdgeRule's logic this should map to cliff-outer-corner (rotated).
	var target_tag: String = rule._tag_for_missing_sockets(missing)
	assert_eq(target_tag, "cliff-outer-corner")
```

- [ ] **Step 2: Run test, verify it fails**

Expected: FAIL — `_tag_for_missing_sockets` undefined.

- [ ] **Step 3: Add variant-selection and rotation methods**

In [scripts/terrain/rules/CliffEdgeRule.gd](../../../scripts/terrain/rules/CliffEdgeRule.gd), append after the helpers from Task 10:

```gdscript
func _rotate_socket_names_once(socket_names: Array) -> Array:
	var out: Array = []
	for socket_name in socket_names:
		out.append(Helper.rotate_socket_name(socket_name))
	return out


func _same_socket_set(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for socket_name in a:
		if not b.has(socket_name):
			return false
	return true


func _rotation_steps_to_align_canonical(target_tag: String, desired_missing: Array[String]) -> int:
	var canonical: Array = CANONICAL_MISSING_BY_TAG.get(target_tag, []).duplicate()
	for step in range(4):
		if _same_socket_set(canonical, desired_missing):
			return step
		canonical = _rotate_socket_names_once(canonical)
	return -1


func _tag_for_missing_sockets(missing_sockets: Array[String]) -> String:
	# Empty -> swap to interior (signaled by special tag).
	if missing_sockets.is_empty():
		return "cliff-interior"
	for cliff_tag in CLIFF_TAG_ORDER:
		if _rotation_steps_to_align_canonical(cliff_tag, missing_sockets) >= 0:
			return cliff_tag
	# No match: signal "keep piece as-is" via empty string.
	return ""


func _current_cliff_tag(module_def: TerrainModule) -> String:
	if module_def == null:
		return ""
	for cliff_tag in CLIFF_TAG_ORDER:
		if module_def.tags.has(cliff_tag):
			return cliff_tag
	if module_def.tags.has("cliff-interior"):
		return "cliff-interior"
	return ""


func _get_module_for_cliff_tag(cliff_tag: String) -> TerrainModule:
	if module_by_cliff_tag.is_empty():
		module_by_cliff_tag = {
			"cliff-edge": TerrainModuleDefinitions.load_cliff_edge_tile(),
			"cliff-outer-corner": TerrainModuleDefinitions.load_cliff_outer_corner_tile(),
			"cliff-inner-corner": TerrainModuleDefinitions.load_cliff_inner_corner_tile(),
			"cliff-inner-corner-diag": TerrainModuleDefinitions.load_cliff_inner_corner_diag_tile(),
			"cliff-interior": TerrainModuleDefinitions.load_cliff_interior_tile(),
		}
	return module_by_cliff_tag.get(cliff_tag, null)


func _create_replacement_for_target(
	source_piece: TerrainModuleInstance,
	target_tag: String,
	steps_to_align: int
) -> TerrainModuleInstance:
	var existing_tag: String = _current_cliff_tag(source_piece.def)
	if existing_tag == target_tag and steps_to_align == 0:
		return source_piece
	var module_template: TerrainModule = _get_module_for_cliff_tag(target_tag)
	if module_template == null:
		return source_piece
	if module_template == source_piece.def and steps_to_align == 0:
		return source_piece
	var replacement: TerrainModuleInstance = module_template.spawn()
	replacement.set_transform(source_piece.transform)
	replacement.create()

	if steps_to_align > 0:
		var yaw: float = PI * 0.5 * float((4 - steps_to_align) % 4)
		var rotated_basis: Basis = Basis(Vector3.UP, yaw) * replacement.transform.basis
		replacement.set_basis(rotated_basis)
	return replacement
```

- [ ] **Step 4: Run the test, verify it passes**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/rules/CliffEdgeRule.gd tests/test_terrain_generator.gd
git commit -m "feat(terrain): CliffEdgeRule variant selection and rotation alignment"
```

---

## Task 12: Implement `CliffEdgeRule.apply()` — wire helpers into apply()

**Files:**
- Modify: `scripts/terrain/rules/CliffEdgeRule.gd`
- Test: `tests/test_terrain_generator.gd`

- [ ] **Step 1: Replace the stub `apply()` with the full implementation**

In [scripts/terrain/rules/CliffEdgeRule.gd](../../../scripts/terrain/rules/CliffEdgeRule.gd), replace the stub:

```gdscript
func apply(context: Dictionary) -> Dictionary:
	return {"chosen_piece": context.get("chosen_piece", null), "piece_updates": {}}
```

with the full implementation:

```gdscript
func apply(context: Dictionary) -> Dictionary:
	if (
		not context.has("chosen_piece")
		or not context.has("socket_index")
		or not context.has("terrain_index")
	):
		return {"chosen_piece": context.get("chosen_piece", null), "piece_updates": {}}

	var chosen_piece: TerrainModuleInstance = context["chosen_piece"]
	var socket_index: PositionIndex = context["socket_index"]
	var terrain_index: TerrainIndex = context["terrain_index"]
	var piece_updates: Dictionary = {}

	# Walk affected pieces: chosen + direct cliff neighbors + their neighbors.
	var affected: Array[TerrainModuleInstance] = []
	var seen: Dictionary = {}
	_add_unique_piece(affected, seen, chosen_piece)
	var direct_neighbors: Array[TerrainModuleInstance] = _get_cliff_neighbors(
		chosen_piece, socket_index, terrain_index
	)
	for neighbor_piece in direct_neighbors:
		_add_unique_piece(affected, seen, neighbor_piece)
	for neighbor_piece in direct_neighbors:
		var indirect: Array[TerrainModuleInstance] = _get_cliff_neighbors(
			neighbor_piece, socket_index, terrain_index
		)
		for indirect_neighbor in indirect:
			_add_unique_piece(affected, seen, indirect_neighbor)

	var chosen_replacement: TerrainModuleInstance = chosen_piece
	for affected_piece in affected:
		var missing: Array[String] = _missing_sockets_for_piece(
			affected_piece, socket_index, terrain_index
		)
		var target_tag: String = _tag_for_missing_sockets(missing)
		if target_tag == "":
			# No matching variant — leave piece as-is. Eventually-consistent fallback.
			continue
		var steps_to_align: int = _rotation_steps_to_align_canonical(target_tag, missing)
		# cliff-interior has no canonical missing pattern (always 0 missing); skip rotation.
		if target_tag == "cliff-interior":
			steps_to_align = 0
		var replacement: TerrainModuleInstance = _create_replacement_for_target(
			affected_piece, target_tag, steps_to_align
		)
		if affected_piece == chosen_piece:
			chosen_replacement = replacement
		elif replacement != affected_piece:
			piece_updates[affected_piece] = replacement
	return {"chosen_piece": chosen_replacement, "piece_updates": piece_updates}
```

- [ ] **Step 2: Add an integration-style unit test for the apply() flow**

Append to [tests/test_terrain_generator.gd](../../../tests/test_terrain_generator.gd):

```gdscript
func test_cliff_edge_rule_keeps_isolated_piece_unchanged() -> void:
	# An isolated cliff (no neighbors) is invalid; the rule must keep it as-is,
	# not delete it — otherwise seeding could never form a plateau.
	var rule: CliffEdgeRule = CliffEdgeRule.new()
	var cliff: TerrainModuleInstance = TerrainModuleDefinitions.load_cliff_edge_tile().spawn()
	_pieces_to_destroy.append(cliff)
	cliff.create()

	var socket_index: PositionIndex = PositionIndex.new()
	_track_node_for_cleanup(socket_index)
	for socket_name in cliff.sockets.keys():
		socket_index.insert(TerrainModuleSocket.new(cliff, socket_name))
	var terrain_index: TerrainIndex = TerrainIndex.new()
	terrain_index.insert(cliff)

	var result: Dictionary = rule.apply({
		"chosen_piece": cliff,
		"socket_index": socket_index,
		"terrain_index": terrain_index,
	})
	assert_eq(result["chosen_piece"], cliff, "Isolated cliff should be kept as-is")
	assert_eq((result["piece_updates"] as Dictionary).size(), 0, "No piece updates for isolated cliff")
```

- [ ] **Step 3: Run test, verify it passes**

Run: `godot --path /Users/ryko/story -s res://addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json -gtest=res://tests/test_terrain_generator.gd -gunit_test_name=test_cliff_edge_rule_keeps_isolated_piece_unchanged`

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add scripts/terrain/rules/CliffEdgeRule.gd tests/test_terrain_generator.gd
git commit -m "feat(terrain): CliffEdgeRule.apply() with eventually-consistent fallback"
```

---

## Task 13: Register `CliffEdgeRule` in the rule library

**Files:**
- Modify: `scripts/terrain/TerrainGenerationRuleLibrary.gd`
- Test: `tests/test_terrain_generator.gd`

- [ ] **Step 1: Write the failing test**

Append:

```gdscript
func test_rule_library_includes_cliff_edge_rule() -> void:
	var lib: TerrainGenerationRuleLibrary = TerrainGenerationRuleLibrary.new()
	var has_cliff_rule: bool = false
	for rule in lib.rules:
		if rule is CliffEdgeRule:
			has_cliff_rule = true
			break
	assert_true(has_cliff_rule, "Rule library should include CliffEdgeRule")
```

- [ ] **Step 2: Run test, verify it fails**

Expected: FAIL — CliffEdgeRule not in rules.

- [ ] **Step 3: Register CliffEdgeRule**

Update [scripts/terrain/TerrainGenerationRuleLibrary.gd](../../../scripts/terrain/TerrainGenerationRuleLibrary.gd):

```gdscript
class_name TerrainGenerationRuleLibrary
extends Resource

# Array of TerrainGenerationRule instances
@export var rules: Array[TerrainGenerationRule] = []


func _init() -> void:
	rules.append(CliffEdgeRule.new())
	rules.append(LevelEdgeRule.new())
```

- [ ] **Step 4: Run test, verify it passes**

Expected: PASS.

- [ ] **Step 5: Run the full test suite**

Expected: all tests pass. The CliffEdgeRule's `matches()` is tag-gated so it won't fire on level/ground pieces.

- [ ] **Step 6: Commit**

```bash
git add scripts/terrain/TerrainGenerationRuleLibrary.gd tests/test_terrain_generator.gd
git commit -m "feat(terrain): register CliffEdgeRule in TerrainGenerationRuleLibrary"
```

---

## Task 14: Integration test — cliff seeding produces variants in a generated region

**Files:**
- Test: `tests/test_terrain_generator.gd`

- [ ] **Step 1: Write the integration test**

This test follows the same setup pattern as `test_integration_default_level_generation_not_sparse_or_isolated` (line 1167). Append to [tests/test_terrain_generator.gd](../../../tests/test_terrain_generator.gd):

```gdscript
func _collect_cliff_pieces(gen: Variant) -> Array[TerrainModuleInstance]:
	var search_half_extent: float = 450.0
	if gen != null:
		var render_range_value: Variant = gen.get("RENDER_RANGE")
		if render_range_value is float or render_range_value is int:
			search_half_extent = float(render_range_value) + 120.0
	var search_box: AABB = AABB(
		Vector3(-search_half_extent, -10, -search_half_extent),
		Vector3(search_half_extent * 2.0, 200, search_half_extent * 2.0)
	)
	var pieces: Array = gen.terrain_index.query_box(search_box)
	var out: Array[TerrainModuleInstance] = []
	var seen: Dictionary = {}
	for piece in pieces:
		if not (piece is TerrainModuleInstance):
			continue
		var cliff_piece: TerrainModuleInstance = piece
		if not cliff_piece.def.tags.has("cliff"):
			continue
		if seen.has(cliff_piece):
			continue
		seen[cliff_piece] = true
		out.append(cliff_piece)
	return out


func _cliff_cardinal_connected(
	gen: Variant, cliff: TerrainModuleInstance, socket_name: String
) -> bool:
	if not cliff.sockets.has(socket_name):
		return false
	var ps: TerrainModuleSocket = TerrainModuleSocket.new(cliff, socket_name)
	var other: TerrainModuleSocket = gen.socket_index.query_other(
		ps.get_socket_position(), cliff
	)
	return other != null and other.piece != null and other.piece.def.tags.has("cliff")


func test_integration_cliff_seeding_produces_variants() -> void:
	# Seed generation, run until a cliff seeds and a small plateau forms.
	# Assert: at least one cliff piece exists; each fully-surrounded cliff has either
	# ≥3 cliff cardinals (edge variant or interior) OR exactly 2 ADJACENT cardinals
	# (outer-corner). 2-opposite (line) is forbidden.
	var gen: Variant = _new_generator()
	_set_generator_library(gen, TerrainModuleLibrary.new())
	gen.library.init()
	_set_generator_test_pieces_library(gen, TerrainModuleLibrary.new())
	gen.test_pieces_library.init_test_pieces()
	gen.player.global_position = Vector3.ZERO
	gen.RENDER_RANGE = 300
	gen.MAX_LOAD_PER_STEP = 20
	seed(12345)  # Adjust if no cliff seeds in this run; test should never PASS without ≥1 cliff.
	_run_generator_ready(gen)

	# Push the generator forward enough to seed and grow at least one cliff.
	# 5% seed chance × hundreds of ground placements -> expected ≥1 cliff.
	for _i in range(800):
		gen.load_terrain()

	var cliff_pieces: Array[TerrainModuleInstance] = _collect_cliff_pieces(gen)
	assert_true(
		cliff_pieces.size() > 0,
		"Expected at least one cliff to seed (seed=12345, iter=800). If consistently failing here, raise iter count or change seed."
	)

	# Verify each fully-surrounded cliff has a valid configuration.
	# "Fully-surrounded" = all 4 cardinal positions have *something* in the socket index
	# (so the piece is not at the generation frontier). This avoids penalizing
	# the eventually-consistent fallback for transient frontier states.
	for cliff in cliff_pieces:
		var has_neighbor_on_all_cardinals: bool = true
		for socket_name in ["front", "back", "left", "right"]:
			var ps: TerrainModuleSocket = TerrainModuleSocket.new(cliff, socket_name)
			if gen.socket_index.query_other(ps.get_socket_position(), cliff) == null:
				has_neighbor_on_all_cardinals = false
				break
		if not has_neighbor_on_all_cardinals:
			continue

		var connected: Dictionary[String, bool] = {}
		var cliff_cardinal_count: int = 0
		for socket_name in ["front", "back", "left", "right"]:
			var is_cliff: bool = _cliff_cardinal_connected(gen, cliff, socket_name)
			connected[socket_name] = is_cliff
			if is_cliff:
				cliff_cardinal_count += 1

		assert_true(
			cliff_cardinal_count >= 2,
			"Fully-surrounded cliff must have ≥2 cliff cardinals (got %d)" % cliff_cardinal_count
		)
		if cliff_cardinal_count == 2:
			var has_adjacent_pair: bool = (
				(connected["front"] and connected["left"])
				or (connected["front"] and connected["right"])
				or (connected["back"] and connected["left"])
				or (connected["back"] and connected["right"])
			)
			assert_true(
				has_adjacent_pair,
				"2-cardinal cliffs must be adjacent (outer-corner), not opposite (line)"
			)

	_dispose_generator_immediately(gen)
	await _flush_deferred_frees()
```

- [ ] **Step 2: Run the test**

Run: `godot --path /Users/ryko/story -s res://addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json -gtest=res://tests/test_terrain_generator.gd -gunit_test_name=test_integration_cliff_seeding_produces_variants`

Expected: PASS. If FAIL because no cliff seeded: adjust the seed value (try `seed(7)`, `seed(99)`, etc.) until one seeds in 800 iterations. If FAIL on the ≥2-cardinal assertion: the rule isn't classifying correctly — investigate.

- [ ] **Step 3: Commit**

```bash
git add tests/test_terrain_generator.gd
git commit -m "test(terrain): integration test for cliff seeding and ≥2x2 invariant"
```

---

## Task 15: Manual verification — visually inspect cliffs in the running game

**Files:**
- None (manual step)

- [ ] **Step 1: Launch the game**

Run: `godot --path /Users/ryko/story`

Move the character around for a couple minutes. Look for cliff-bordered plateaus — they should:
- Be visibly taller than the existing level pads (4 units vs 0.5 units).
- Form clustered regions (not scattered isolated 1x1 cliffs).
- Have correctly oriented edge / outer-corner / inner-corner tiles around the perimeter.
- Have grass / trees / etc. spawning on top of the interior.

- [ ] **Step 2: If no cliffs appear within ~3 minutes of play**

Either the seed rate is too low (raise from 0.05 to 0.10 temporarily for debugging in [TerrainModuleDefinitions.gd `load_ground_tile()`](../../../scripts/terrain/TerrainModuleDefinitions.gd)) or there's an integration issue. Drop a `print()` in `CliffEdgeRule.matches()` to confirm it's being invoked. Don't commit the debug changes.

- [ ] **Step 3: If cliffs appear visually wrong (orientations, edges)**

Common issues to check:
- Socket positions in the .tscn files don't match what the rule expects (run the Task 2 socket-layout test).
- The rule's CANONICAL_MISSING_BY_TAG entries don't match the actual visual "drop face" direction of each scene (e.g., if your `CliffSide.tscn` has its drop face on `back` rather than `front`, update CANONICAL_MISSING_BY_TAG accordingly).

- [ ] **Step 4: No commit needed for this task** — visual verification only.

---

## Task 16: Add `directional-socket-tags.md` future-work doc

**Files:**
- Create: `docs/future-work/directional-socket-tags.md`

- [ ] **Step 1: Create the future-work doc**

Create [docs/future-work/directional-socket-tags.md](../../../docs/future-work/directional-socket-tags.md):

```markdown
# Directional Socket Tags

**Status:** future work

## Motivation

Some terrain features want adjacency rules that depend on *direction*, not just
presence: rivers that flow in a consistent direction, paths that connect end-
to-end, edge tiles that match their neighbor's facing.

The cliff and level edge systems work around this by placing a generic seed
variant and re-tiling visually after the fact (LevelEdgeRule, CliffEdgeRule).
This works but it means we can't enforce shape invariants at placement time —
we get "eventually-consistent" shapes that may briefly look wrong.

A directional tag system would let a tile constrain its own facing relative to
neighbors. e.g., a river-source tile could require an adjacent tile tagged
`river[flow=south]` on its south side, and the lookup would prefer tiles whose
own `flow` tag is east-or-west (90° relative to incoming flow).

## What this would unlock

- **Rivers and paths.** Connected linear features that can't be done with
  isotropic socket constraints.
- **Direct-placement edge variants for cliffs and levels.** Replace the rule-
  based retiling with placement-time selection — simpler runtime, fewer
  transient invalid states.
- **Asymmetric tiles.** Bridges, ramps, doorways where which side faces "in"
  vs "out" matters.

## Sketch

Tags become parameterized: `river[flow=south]`. `socket_required` uses a
binding syntax: `"river[flow=$X]"` — the `$X` placeholder gets resolved at
placement time against the neighbor's tag, and the placed tile must have a
corresponding `flow` parameter that matches the rule (e.g., 90° rotated).

Implementation challenges:
- Tag parsing and binding semantics (still string-keyed, but with parameter
  resolution).
- Rotation handling — rotating a tile must update its directional tags.
- Backward compatibility — existing non-directional tags continue to work.

## Previous attempts

None on record. The "Level Stacking Sparsity with Self Socket Requirements"
issue solved a different problem (`!ground-type` self-requirement).
```

- [ ] **Step 2: Commit**

```bash
git add docs/future-work/directional-socket-tags.md
git commit -m "docs: future-work note for directional socket tags"
```

---

## Task 17: Delete the superseded `cliffs-and-floating-islands.md` future-work doc

**Files:**
- Delete: `docs/future-work/cliffs-and-floating-islands.md`

- [ ] **Step 1: Verify scope of cliffs-and-floating-islands.md**

Run: `cat docs/future-work/cliffs-and-floating-islands.md`

Confirm its contents are about (a) more cliff variants, (b) cliff composition, (c) floating islands. (a) and (b) are addressed (in part) by this spec's implementation; (c) remains future work but is mentioned in the design doc.

- [ ] **Step 2: Delete the file**

Run: `rm docs/future-work/cliffs-and-floating-islands.md`

- [ ] **Step 3: Verify no other docs reference this file**

Run: `grep -rn "cliffs-and-floating-islands" docs/`

Expected: only the design doc references it (mentioning its deletion). If other docs link to it, update them to point to the new design doc instead.

- [ ] **Step 4: Commit**

```bash
git add -u docs/future-work/cliffs-and-floating-islands.md
git commit -m "docs: remove superseded cliffs-and-floating-islands future-work doc"
```

---

## Task 18: Update `terrain/TERRAIN_README.md` with cliff-tile convention

**Files:**
- Modify: `terrain/TERRAIN_README.md`

- [ ] **Step 1: Append the cliff convention note**

Read [terrain/TERRAIN_README.md](../../../terrain/TERRAIN_README.md), then append at the end:

```markdown
## Tall tiles (cliffs, ≥4 units)

Tall tiles like the cliff variants follow the same conventions as ground/level tiles, with one extension:
- Origin is at the **top surface** (lateral sockets at local `y=0`).
- `bottom` socket is at local `y=-H` where H is the tile height (e.g., `(0, -4, 0)` for a 4-unit cliff). It attaches to a ground tile at world `y=0` below.
- Use a height-suffixed size tag (e.g., `"24x24x4"`) so adjacency probing uses the correct test piece with sockets at the right height.
- Register a corresponding test piece in `TerrainModuleLibrary.load_test_pieces()` if no existing one matches the height.
```

- [ ] **Step 2: Commit**

```bash
git add terrain/TERRAIN_README.md
git commit -m "docs(terrain): note conventions for tall tiles (cliffs)"
```

---

## Task 19: Final verification — full test suite + manual game run

**Files:**
- None (verification only)

- [ ] **Step 1: Run the full test suite one more time**

Run: `godot --path /Users/ryko/story -s res://addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json`

Expected: every test passes, no warnings about missing modules or sockets.

- [ ] **Step 2: Run the game and visually verify cliffs**

Run: `godot --path /Users/ryko/story`

Move around for ~3 minutes. Confirm:
- At least one cliff plateau appears.
- Plateaus look coherent (proper edges + corners around the perimeter).
- Multi-storey cliffs occasionally appear (cliff on top of cliff via interior topcenter seeding).
- Existing level plateaus are unchanged in look and frequency.

- [ ] **Step 3: If everything passes, mark the implementation complete**

No commit needed — the previous commits cover all changes.

---

## Follow-up notes (not part of this plan)

The following are noted for future PRs but explicitly out of scope:

1. **Generalize tag-specific code in TerrainGenerator.gd.** The level-specific filter in `can_place` (lines 380-388) and the level-stack-specific topcenter preservation in `_replace_piece` (lines 319-327) could be generalized via a `"stackable"` or `"elevated"` tag. Not needed for cliffs (they bypass via `replace_existing=true`), but cleaner long-term.

2. **Refactor LevelEdgeRule + CliffEdgeRule to share a base.** They're ~80% identical structurally. A base `EdgeRetilingRule` parameterized by tag-set, canonical-missing-by-tag, and module-loader would consolidate them. Out of scope; cliff-specific behavior (cliff-interior swap, eventually-consistent fallback) makes a shared base non-trivial.

3. **Floating islands.** Air/void tile support so cliffs can have gaps underneath. Logged in the spec's "Future work" section.
