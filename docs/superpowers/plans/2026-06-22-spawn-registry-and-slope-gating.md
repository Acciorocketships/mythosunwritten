# Central Spawn Registry + Level/Slope Socket Gating Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create one source-of-truth file for all ground-spawn probabilities and socket→piece rules, and stop hills/structures from spawning on sloped sockets (foliage stays).

**Architecture:** A new `TerrainSpawnConfig.gd` owns every spawn tuning constant, the shared surface-spawn builder, the canonical "structure" key set, the level/slope category rule, and a `filter_for_category` helper. Sockets are tagged `level`/`slope` from their baked Y in `TerrainModuleInstance`. At expansion time the generator passes each socket's size and tag distributions through `filter_for_category`, dropping structures on slope sockets.

**Tech Stack:** Godot 4 (GDScript), GUT test framework.

**Conventions (from project memory):**
- Godot binary: `/Applications/Godot.app/Contents/MacOS/Godot`
- Run ONE test file: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/<file>.gd -gexit`
- Full suite: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json -gexit`
- After creating a NEW `class_name` script, register it once: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import`
- Stage specific files only — never `git add -A`. Do not commit `*.uid` files.
- Pre-existing baseline failure: `test_heightfield_interior_corners.gd` ("every interior corner is an inner-corner variant") fails independent of this work — not a regression.

---

## File Structure

- **Create** `scripts/terrain/TerrainSpawnConfig.gd` — single source of truth: tuning constants, `FOLIAGE_TAG_WEIGHTS`, `surface_spawn_sockets()`, structure key sets, `category_for_y()`, `filter_for_category()`.
- **Create** `tests/test_spawn_config.gd` — unit tests for `filter_for_category` and `category_for_y`.
- **Create** `tests/test_socket_category.gd` — unit test for `TerrainModuleInstance` socket categorization wiring.
- **Create** `tests/test_slope_spawn_gating.gd` — integration test: real slope-variant scenes expose slope sockets that cannot roll structures.
- **Modify** `scripts/terrain/TerrainModuleDefinitions.gd` — remove the tuning block + `surface_spawn_sockets`; reference `TerrainSpawnConfig.*` instead. (Variant tables stay.)
- **Modify** `scripts/terrain/TerrainGenerator.gd` — reference `TerrainSpawnConfig.*` for the 5 moved constants; pass size + tag distributions through `filter_for_category`; reuse `STRUCTURE_SIZES` in cliff-core suppression.
- **Modify** `scripts/terrain/TerrainModuleInstance.gd` — compute and expose each socket's `level`/`slope` category in `_find_sockets`.

---

## Task 1: `TerrainSpawnConfig` gating core (structure sets, category rule, filter)

Creates the new file with ONLY the gating logic and structure key sets (constants are migrated in Task 2). TDD first.

**Files:**
- Create: `scripts/terrain/TerrainSpawnConfig.gd`
- Test: `tests/test_spawn_config.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/test_spawn_config.gd`:

```gdscript
extends GutTest

## Tests for TerrainSpawnConfig gating: filter_for_category + category_for_y.

func _dist(d: Dictionary) -> Distribution:
	var typed: Dictionary[String, float] = {}
	for k in d:
		typed[k] = d[k]
	return Distribution.new(typed)


func test_slope_drops_hill_sizes() -> void:
	var d := _dist({"point": 0.85, "8x8x2": 0.1, "4x4x4": 0.05})
	var out := TerrainSpawnConfig.filter_for_category(d, "slope")
	assert_false(out.dist.has("8x8x2"), "hill size 8x8x2 should be dropped on a slope")
	assert_false(out.dist.has("4x4x4"), "hill size 4x4x4 should be dropped on a slope")
	assert_true(out.dist.has("point"), "point foliage must survive on a slope")
	assert_almost_eq(out.dist["point"], 1.0, 0.0001, "surviving dist must renormalise to 1")


func test_slope_drops_structure_tags() -> void:
	var d := _dist({"grass": 0.3, "rock": 0.2, "hill": 0.05, "cliff-base-side": 0.3})
	var out := TerrainSpawnConfig.filter_for_category(d, "slope")
	assert_false(out.dist.has("hill"), "hill tag should be dropped on a slope")
	assert_false(out.dist.has("cliff-base-side"), "seed tag should be dropped on a slope")
	assert_true(out.dist.has("grass"), "foliage tag must survive on a slope")
	assert_true(out.dist.has("rock"), "foliage tag must survive on a slope")


func test_level_returns_dist_unchanged() -> void:
	var d := _dist({"point": 0.85, "8x8x2": 0.15})
	var out := TerrainSpawnConfig.filter_for_category(d, "level")
	assert_same(out, d, "level category must return the same distribution object untouched")


func test_filter_never_empties_a_dist() -> void:
	var d := _dist({"8x8x2": 1.0})  # nothing but a structure
	var out := TerrainSpawnConfig.filter_for_category(d, "slope")
	assert_true(out.has_positive_weight(), "filter must never produce an unsamplable dist")


func test_category_for_y() -> void:
	assert_eq(TerrainSpawnConfig.category_for_y(0.0), "level", "plateau sockets at y~0 are level")
	assert_eq(TerrainSpawnConfig.category_for_y(-2.0), "slope", "sockets dropped below the plateau are slope")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_spawn_config.gd -gexit`
Expected: FAIL — `TerrainSpawnConfig` is an unknown identifier / class not found.

- [ ] **Step 3: Create the new file with gating logic**

Create `scripts/terrain/TerrainSpawnConfig.gd`:

```gdscript
class_name TerrainSpawnConfig
extends Resource

# Single source of truth for ground-spawn behaviour: which pieces spawn in which
# sockets, with what probabilities, and the level/slope rule that keeps
# structures off sloped surfaces. (Tuning constants + surface_spawn_sockets are
# migrated here in a follow-up step; this block defines the gating contract.)

### Level / slope socket gating ###

# Plateau (walkable, flat) sockets are baked at y~0; sockets sitting over a
# slope band are baked below 0 (see tests/test_slope_socket_grounding.gd). A
# socket more than this far below the plateau is on the slope.
const SLOPE_Y_THRESHOLD: float = -0.5

# Sizes that denote a multi-cell structure (a hill) rather than a point
# decoration. Dropped from slope sockets and from cliff-core suppression — one
# definition, two callers.
const STRUCTURE_SIZES: Array[String] = ["8x8x2", "12x12x2", "4x4x4"]

# Structural seed identifiers a topcenter can roll (the level/cliff tiles it
# seeds). Named so the cliff-core suppression and the slope gate share the
# strings instead of hardcoding them in two places.
const SEED_SIZE_LEVEL: String = "24x24x0.5"
const SEED_SIZE_CLIFF: String = "24x24x4"
const SEED_TAG_LEVEL_GROUND: String = "level-ground-center"
const SEED_TAG_LEVEL_STACK: String = "level-stack-center"
const SEED_TAG_CLIFF_BASE: String = "cliff-base-side"
const SEED_TAG_CLIFF_STACK: String = "cliff-stack-side"

# Tags dropped from a slope socket's roll: hills plus every structural seed.
# Foliage tags (grass/rock/bush/tree) are intentionally absent so they survive.
const SLOPE_BLOCKED_TAGS: Array[String] = [
	"hill",
	SEED_TAG_LEVEL_GROUND, SEED_TAG_LEVEL_STACK,
	SEED_TAG_CLIFF_BASE, SEED_TAG_CLIFF_STACK,
]


# Level vs slope from a socket's baked local Y.
static func category_for_y(y: float) -> String:
	return "slope" if y < SLOPE_Y_THRESHOLD else "level"


# Drop structure entries (hill sizes + structural seed/hill tags) from a
# distribution when the socket is on a slope; return the distribution untouched
# on level sockets. Never empties a distribution (Distribution.sample asserts on
# an empty / zero-sum dist) — point foliage always survives a foliage roll, and
# a dist of only-structures is left as-is rather than nulled.
static func filter_for_category(dist: Distribution, category: String) -> Distribution:
	if category != "slope" or dist == null or dist.is_empty():
		return dist
	var filtered: Distribution = dist.copy()
	var changed: bool = false
	for key: String in STRUCTURE_SIZES:
		if filtered.dist.has(key):
			filtered.dist.erase(key)
			changed = true
	for key: String in SLOPE_BLOCKED_TAGS:
		if filtered.dist.has(key):
			filtered.dist.erase(key)
			changed = true
	if not changed:
		return dist
	if filtered.dist.is_empty() or not filtered.has_positive_weight():
		return dist
	filtered.normalise()
	return filtered
```

- [ ] **Step 4: Register the new class, then run the test to verify it passes**

Run (register the new `class_name` once): `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import`
Then run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_spawn_config.gd -gexit`
Expected: PASS — all 5 tests green.

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/TerrainSpawnConfig.gd tests/test_spawn_config.gd
git commit -m "feat(terrain): add TerrainSpawnConfig gating (structure sets, slope filter)"
```

---

## Task 2: Migrate all spawn tuning + surface builder into `TerrainSpawnConfig`

Move the tuning-constant block and `surface_spawn_sockets()` out of `TerrainModuleDefinitions.gd` into `TerrainSpawnConfig.gd`, and repoint every reference. Variant tables (`LEVEL_VARIANT_TABLE`, `CLIFF_VARIANT_TABLE`, `CLIFF_STACKED_VARIANT_TABLE`, `BANK_VARIANT_TABLE`) stay in `TerrainModuleDefinitions` — they are the piece catalog, not spawn probabilities.

**Files:**
- Modify: `scripts/terrain/TerrainSpawnConfig.gd`
- Modify: `scripts/terrain/TerrainModuleDefinitions.gd` (remove tuning block lines 4-90 and `surface_spawn_sockets` lines 140-218; repoint references)
- Modify: `scripts/terrain/TerrainGenerator.gd:411,542,570,580,581`

- [ ] **Step 1: Append the migrated constants + builder to `TerrainSpawnConfig.gd`**

Add the following to `scripts/terrain/TerrainSpawnConfig.gd` (below the gating block). These values are copied verbatim from the current `TerrainModuleDefinitions` tuning block (do not change numbers):

```gdscript

### Migrated spawn tuning (authoritative home) ###

# --- Level ---
const LEVEL_BASE_LATERAL_FILL_PROB: float = 0.33
const LEVEL_STACK_LATERAL_FILL_PROB: float = 0.7
const LEVEL_TOPCENTER_FILL_PROB: float = 0.9
const LEVEL_REPLACE_EXISTING: bool = false

# --- Cliff ---
const CLIFF_LATERAL_FILL_PROB: float = 0.3
const CLIFF_CONTOUR_BASE: float = 0.56
const CLIFF_CONTOUR_STEP: float = 0.012
const CLIFF_CORE_SEED_FILL_PROB: float = 0.5
const CLIFF_CORE_SEED_MIX_BOOST: float = 3.0
const CLIFF_TOPCENTER_FILL_PROB: float = 1.0
const CLIFF_REPLACE_EXISTING: bool = true

# --- Ground topcenter ---
const GROUND_TOPCENTER_FILL_PROB: float = 0.2
const GROUND_TOPCENTER_LEVEL_PROB: float = 0.7
const GROUND_TOPCENTER_CLIFF_PROB: float = 0.3

# --- Top-edge foliage ---
const GROUND_FOLIAGE_FILL_PROB: float = 0.2
const FOLIAGE_TAG_WEIGHTS: Dictionary[String, float] = {
	"grass": 0.3, "rock": 0.2, "bush": 0.2, "tree": 0.25, "hill": 0.05,
}

# --- Hill stacking ---
const HILL_8X8_STACK_FILL_PROB: float = 0.5
const HILL_12X12_STACK_FILL_PROB: float = 0.3
const HILL_4X4_STACK_FILL_PROB: float = 0.4


# One source of truth for what spawns on top of a walkable surface tile (ground
# tiles, level centers, cliff plateau interiors): foliage on the top cardinal /
# corner sockets and a seeding distribution on topcenter. Returns sub-dicts the
# callers merge into their socket dicts.
static func surface_spawn_sockets(
	topcenter_size: Distribution,
	topcenter_tag_prob: Distribution,
	topcenter_fill_prob: Variant,
	foliage_fill_prob: Variant,
	topcenter_suppression_prob: Variant = null
) -> Dictionary:
	var corner_size: Distribution = Distribution.new({"point": 0.85, "12x12x2": 0.1, "4x4x4": 0.05})
	var cardinal_size: Distribution = Distribution.new({"point": 0.85, "8x8x2": 0.1, "4x4x4": 0.05})
	var foliage_tags: Distribution = Distribution.new(FOLIAGE_TAG_WEIGHTS)
	var socket_size: Dictionary[String, Distribution] = {
		"topfront": cardinal_size,
		"topback": cardinal_size,
		"topleft": cardinal_size,
		"topright": cardinal_size,
		"topfrontright": corner_size,
		"topfrontleft": corner_size,
		"topbackright": corner_size,
		"topbackleft": corner_size,
		"topcenter": topcenter_size,
	}
	var socket_fill_prob: Dictionary[String, Variant] = {
		"topfront": foliage_fill_prob,
		"topback": foliage_fill_prob,
		"topleft": foliage_fill_prob,
		"topright": foliage_fill_prob,
		"topfrontright": foliage_fill_prob,
		"topfrontleft": foliage_fill_prob,
		"topbackright": foliage_fill_prob,
		"topbackleft": foliage_fill_prob,
		"topcenter": topcenter_fill_prob,
	}
	var socket_tag_prob: Dictionary[String, Distribution] = {
		"topfront": foliage_tags,
		"topback": foliage_tags,
		"topleft": foliage_tags,
		"topright": foliage_tags,
		"topfrontright": foliage_tags,
		"topfrontleft": foliage_tags,
		"topbackright": foliage_tags,
		"topbackleft": foliage_tags,
		"topcenter": topcenter_tag_prob,
	}
	var suppression_prob: float = 0.0
	if topcenter_suppression_prob != null:
		suppression_prob = float(topcenter_suppression_prob)
	elif topcenter_fill_prob != null:
		suppression_prob = float(topcenter_fill_prob)
	var suppression_entry: Dictionary = {"socket": "topcenter", "prob": suppression_prob}
	var socket_suppressed_by: Dictionary[String, Dictionary] = {
		"topfront": suppression_entry,
		"topback": suppression_entry,
		"topleft": suppression_entry,
		"topright": suppression_entry,
		"topfrontright": suppression_entry,
		"topfrontleft": suppression_entry,
		"topbackright": suppression_entry,
		"topbackleft": suppression_entry,
	}
	return {
		"socket_size": socket_size,
		"socket_fill_prob": socket_fill_prob,
		"socket_tag_prob": socket_tag_prob,
		"socket_suppressed_by": socket_suppressed_by,
	}
```

- [ ] **Step 2: Remove the moved code from `TerrainModuleDefinitions.gd`**

In `scripts/terrain/TerrainModuleDefinitions.gd`:
- Delete the tuning-constant block: from the `### Tuning knobs ###` comment (line ~4) through `HILL_4X4_STACK_FILL_PROB` and its trailing `####...####` divider (line ~90). **Keep** the `### ... ###` variant-table section that follows (`LEVEL_VARIANT_TABLE` onward).
- Delete the entire `static func surface_spawn_sockets(...)` function (lines ~140-218) including its leading `### Shared surface spawning ###` doc comment.

- [ ] **Step 3: Repoint references inside `TerrainModuleDefinitions.gd`**

Every bare reference to a moved name must become `TerrainSpawnConfig.<NAME>`, and every `surface_spawn_sockets(` call becomes `TerrainSpawnConfig.surface_spawn_sockets(`. The moved names to prefix:

`LEVEL_BASE_LATERAL_FILL_PROB`, `LEVEL_STACK_LATERAL_FILL_PROB`, `LEVEL_TOPCENTER_FILL_PROB`, `LEVEL_REPLACE_EXISTING`, `CLIFF_LATERAL_FILL_PROB`, `CLIFF_CONTOUR_BASE`, `CLIFF_CONTOUR_STEP`, `CLIFF_CORE_SEED_FILL_PROB`, `CLIFF_CORE_SEED_MIX_BOOST`, `CLIFF_TOPCENTER_FILL_PROB`, `CLIFF_REPLACE_EXISTING`, `GROUND_TOPCENTER_FILL_PROB`, `GROUND_TOPCENTER_LEVEL_PROB`, `GROUND_TOPCENTER_CLIFF_PROB`, `GROUND_FOLIAGE_FILL_PROB`, `FOLIAGE_TAG_WEIGHTS`, `HILL_8X8_STACK_FILL_PROB`, `HILL_12X12_STACK_FILL_PROB`, `HILL_4X4_STACK_FILL_PROB`, `surface_spawn_sockets`.

Find every remaining bare reference (these are the call sites to edit) with:

```bash
grep -nE "\b(LEVEL_BASE_LATERAL_FILL_PROB|LEVEL_STACK_LATERAL_FILL_PROB|LEVEL_TOPCENTER_FILL_PROB|LEVEL_REPLACE_EXISTING|CLIFF_LATERAL_FILL_PROB|CLIFF_CONTOUR_BASE|CLIFF_CONTOUR_STEP|CLIFF_CORE_SEED_FILL_PROB|CLIFF_CORE_SEED_MIX_BOOST|CLIFF_TOPCENTER_FILL_PROB|CLIFF_REPLACE_EXISTING|GROUND_TOPCENTER_FILL_PROB|GROUND_TOPCENTER_LEVEL_PROB|GROUND_TOPCENTER_CLIFF_PROB|GROUND_FOLIAGE_FILL_PROB|FOLIAGE_TAG_WEIGHTS|HILL_8X8_STACK_FILL_PROB|HILL_12X12_STACK_FILL_PROB|HILL_4X4_STACK_FILL_PROB)\b" scripts/terrain/TerrainModuleDefinitions.gd | grep -v "TerrainSpawnConfig\."
```

Prefix each hit with `TerrainSpawnConfig.` (skip occurrences that are only inside comments). Also update `surface_spawn_sockets(` call sites (≈lines 232, 561, 737, 805, 892) to `TerrainSpawnConfig.surface_spawn_sockets(`. Re-run the grep — it must return no non-comment hits.

- [ ] **Step 4: Repoint the 5 references in `TerrainGenerator.gd`**

Replace `TerrainModuleDefinitions.` with `TerrainSpawnConfig.` for these (constant names unchanged):
- `TerrainGenerator.gd:411` — `CLIFF_CORE_SEED_MIX_BOOST`
- `TerrainGenerator.gd:542` — `CLIFF_CORE_SEED_FILL_PROB`
- `TerrainGenerator.gd:570` — `CLIFF_CONTOUR_BASE`
- `TerrainGenerator.gd:580` — `CLIFF_CONTOUR_BASE`
- `TerrainGenerator.gd:581` — `CLIFF_CONTOUR_STEP`

Verify none remain:

```bash
grep -rn "TerrainModuleDefinitions\.\(LEVEL_\|CLIFF_\|GROUND_\|FOLIAGE_\|HILL_\)" scripts tests
```

Expected: no output.

- [ ] **Step 5: Verify the library still loads and existing terrain tests pass**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import`
Then run each:
- `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_terrain_module_library.gd -gexit`
- `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_biomes.gd -gexit`
- `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_slope_cliff_integration.gd -gexit`

Expected: PASS (no parse errors, no regressions). A parse error here means a missed reference — re-run the Step 3/4 greps.

- [ ] **Step 6: Commit**

```bash
git add scripts/terrain/TerrainSpawnConfig.gd scripts/terrain/TerrainModuleDefinitions.gd scripts/terrain/TerrainGenerator.gd
git commit -m "refactor(terrain): migrate spawn tuning + surface builder into TerrainSpawnConfig"
```

---

## Task 3: Socket categorization in `TerrainModuleInstance`

Tag each socket `level`/`slope` from its baked local Y when sockets are discovered.

**Files:**
- Modify: `scripts/terrain/TerrainModuleInstance.gd:7,69,71-77`
- Test: `tests/test_socket_category.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/test_socket_category.gd`:

```gdscript
extends GutTest

## TerrainModuleInstance tags each socket level/slope from its baked marker Y.

func test_socket_category_from_marker_y() -> void:
	var inst := TerrainModuleInstance.new(TerrainModuleDefinitions.create_24x24_test_piece())
	var socket_root := Node3D.new()
	var flat := Marker3D.new()
	flat.name = "topfront"
	flat.transform.origin = Vector3(0.0, 0.0, -9.0)
	var low := Marker3D.new()
	low.name = "topback"
	low.transform.origin = Vector3(0.0, -2.0, 9.0)
	socket_root.add_child(flat)
	socket_root.add_child(low)
	inst.socket_node = socket_root
	inst._find_sockets()
	assert_eq(inst.get_socket_category("topfront"), "level", "y~0 socket is level")
	assert_eq(inst.get_socket_category("topback"), "slope", "socket dropped below the plateau is slope")
	assert_eq(inst.get_socket_category("missing"), "level", "unknown socket defaults to level")
	socket_root.free()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_socket_category.gd -gexit`
Expected: FAIL — `get_socket_category` does not exist.

- [ ] **Step 3: Implement categorization**

In `scripts/terrain/TerrainModuleInstance.gd`:

Add the cache field next to `sockets` (after line 7 `var sockets: Dictionary = {}`):

```gdscript
var socket_category: Dictionary = {}  # String name -> "level" | "slope"
```

Replace `_find_sockets` (lines 71-77) with:

```gdscript
func _find_sockets() -> void:
	sockets.clear()
	socket_category.clear()
	if socket_node == null:
		return
	for child in socket_node.get_children():
		if child is Marker3D:
			sockets[child.name] = child
			socket_category[child.name] = TerrainSpawnConfig.category_for_y(child.transform.origin.y)


func get_socket_category(socket_name: String) -> String:
	return socket_category.get(socket_name, "level")
```

Also clear the cache in `destroy()` — add `socket_category.clear()` next to `sockets.clear()` (line 69):

```gdscript
		sockets.clear()
		socket_category.clear()
```

- [ ] **Step 4: Run test to verify it passes**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_socket_category.gd -gexit`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/TerrainModuleInstance.gd tests/test_socket_category.gd
git commit -m "feat(terrain): tag sockets level/slope from baked marker Y"
```

---

## Task 4: Wire the gate into the generator + share the structure-size set

Pass the size roll and the tag roll through `filter_for_category` using the expanding socket's category, and replace the hardcoded hill-size / seed-string literals in cliff-core suppression with the shared `TerrainSpawnConfig` constants.

**Files:**
- Modify: `scripts/terrain/TerrainGenerator.gd:383-391` (size roll), `:650-658` (tag roll), `:410-430` (cliff-core suppression)

- [ ] **Step 1: Gate the size roll**

In `_sample_socket_size` (lines 383-391), replace the final two lines:

```gdscript
		size_prob_dist = _biome_scaled_dist(size_prob_dist, pos)
	return size_prob_dist.sample()
```

with:

```gdscript
		size_prob_dist = _biome_scaled_dist(size_prob_dist, pos)
	size_prob_dist = TerrainSpawnConfig.filter_for_category(
		size_prob_dist, piece.get_socket_category(socket_name)
	)
	return size_prob_dist.sample()
```

(Note: the `filter` step is outside the `if socket != null` block so a slope foliage socket is gated even when biome scaling was skipped.)

- [ ] **Step 2: Gate the tag roll**

In `_resolve_placement_context` (the returned dictionary, lines 650-658), replace the `"dist"` entry:

```gdscript
		"dist": _biome_scaled_dist(library.get_combined_distribution(adjacent).copy(), origin_world),
```

with:

```gdscript
		"dist": TerrainSpawnConfig.filter_for_category(
			_biome_scaled_dist(library.get_combined_distribution(adjacent).copy(), origin_world),
			piece_socket.piece.get_socket_category(socket_name)
		),
```

(`socket_name` and `piece_socket` are both in scope at the top of this function.)

- [ ] **Step 3: Share the structure-size set in cliff-core suppression**

In `_biome_scaled_dist` (lines ~410-430), replace the three hardcoded hill-size lines and the seed-string literals so the keys come from `TerrainSpawnConfig`. Change this block:

```gdscript
		weights["cliff-base-side"] = weights.get("cliff-base-side", 1.0) * boost
		weights["24x24x4"] = weights.get("24x24x4", 1.0) * boost
		weights["level-ground-center"] = 0.0
		weights["24x24x0.5"] = 0.0
		weights["8x8x2"] = 0.0
		weights["12x12x2"] = 0.0
		weights["4x4x4"] = 0.0
```

to:

```gdscript
		weights[TerrainSpawnConfig.SEED_TAG_CLIFF_BASE] = weights.get(TerrainSpawnConfig.SEED_TAG_CLIFF_BASE, 1.0) * boost
		weights[TerrainSpawnConfig.SEED_SIZE_CLIFF] = weights.get(TerrainSpawnConfig.SEED_SIZE_CLIFF, 1.0) * boost
		weights[TerrainSpawnConfig.SEED_TAG_LEVEL_GROUND] = 0.0
		weights[TerrainSpawnConfig.SEED_SIZE_LEVEL] = 0.0
		for structure_size: String in TerrainSpawnConfig.STRUCTURE_SIZES:
			weights[structure_size] = 0.0
```

- [ ] **Step 4: Verify no regressions in the generator-exercising tests**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_biomes.gd -gexit`
Then: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_slope_cliff_integration.gd -gexit`
Expected: PASS (cliff-core suppression behaves identically — same keys, same values; the slope gate is a no-op on the flat tiles these tests use).

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/TerrainGenerator.gd
git commit -m "feat(terrain): gate slope sockets against structures; share structure-size set"
```

---

## Task 5: Integration test — slope scenes cannot roll structures

Proves the end-to-end contract on the real baked slope-variant scenes: at least one top socket per slope tile is categorized `slope`, and filtering its authored size distribution removes every hill size.

**Files:**
- Test: `tests/test_slope_spawn_gating.gd`

- [ ] **Step 1: Write the test**

Create `tests/test_slope_spawn_gating.gd`:

```gdscript
extends GutTest

## End-to-end: real cliff/slope variant scenes expose slope-categorized top
## sockets, and those sockets can never roll a hill size after gating.

func test_slope_sockets_cannot_roll_structures() -> void:
	var modules: Array[TerrainModule] = TerrainModuleDefinitions.load_cliff_variants()
	var slope_sockets_checked := 0
	for m: TerrainModule in modules:
		var inst := TerrainModuleInstance.new(m)
		var root := inst.create()
		if root == null:
			continue
		add_child_autofree(root)
		for socket_name: String in inst.sockets.keys():
			if inst.get_socket_category(socket_name) != "slope":
				continue
			if not m.socket_size.has(socket_name):
				continue
			var filtered := TerrainSpawnConfig.filter_for_category(
				m.socket_size[socket_name], "slope"
			)
			for size_key: String in filtered.dist.keys():
				assert_false(
					size_key in TerrainSpawnConfig.STRUCTURE_SIZES,
					"%s socket %s can still roll structure size %s" % [
						m.tags.tags[0], socket_name, size_key]
				)
			slope_sockets_checked += 1
		inst.destroy()
	assert_gt(slope_sockets_checked, 0,
		"expected at least one slope-categorized top socket across cliff variants")
```

- [ ] **Step 2: Run the test**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_slope_spawn_gating.gd -gexit`
Expected: PASS — `slope_sockets_checked > 0` and no surviving structure size on any slope socket.

If `slope_sockets_checked` is 0: the slope scenes' top sockets are not baked below `SLOPE_Y_THRESHOLD`. Confirm with `tests/test_slope_socket_grounding.gd` that slope-band sockets sit below 0, and adjust `SLOPE_Y_THRESHOLD` only if the grounding data shows a smaller drop.

- [ ] **Step 3: Commit**

```bash
git add tests/test_slope_spawn_gating.gd
git commit -m "test(terrain): slope sockets cannot roll structures end-to-end"
```

---

## Task 6: Full-suite regression check

- [ ] **Step 1: Run the full suite**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json -gexit`
Expected: All pass EXCEPT the known baseline failure `test_heightfield_interior_corners.gd` ("every interior corner is an inner-corner variant"). Any other failure is a regression from this work — investigate before finishing. (Full-suite runs may truncate around the heightfield tests; if so, re-run the affected files in isolation.)

- [ ] **Step 2: Final verification of the manual goal (optional, recommended)**

Launch the project and observe a sloped cliff: foliage (grass/trees/rocks/bushes) appears on the slope, and no hills protrude into the mountain or jut into the air. Flat plateaus and ground still grow hills as before.

---

## Self-Review Notes

- **Spec coverage:** Component 1 (registry) → Tasks 1-2; Component 2 (categorization) → Task 3; Component 3 (gate) → Task 4; shared structure key set → Tasks 1 + 4; testing section → Tasks 1, 3, 5, 6. All spec sections mapped.
- **Type consistency:** `filter_for_category(Distribution, String) -> Distribution`, `category_for_y(float) -> String`, `get_socket_category(String) -> String`, `STRUCTURE_SIZES: Array[String]` used identically across Tasks 1, 3, 4, 5.
- **Distribution API used:** `dist` (Dictionary), `copy()`, `is_empty()`, `has_positive_weight()`, `normalise()`, `sample()` — all confirmed present in `scripts/core/Distribution.gd`.
- **No forwarding shims:** Task 2 deletes the originals and repoints all references (full migration, per spec decision).
```
