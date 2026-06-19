# Heightfield Terrain — Instantiation (Phase 3b) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the heightfield plan into actual tiles: enumerate the cells within a place-radius, convert each to a concrete placement (variant scene + world transform) via `HeightfieldVariant`, and spawn/register them — deterministically and churn-free.

**Architecture:** Three layers, innermost first. (1) An asset-grounded socket→world-direction mapping. (2) A pure `HeightfieldInstantiator.placements()` that maps each cell to a placement record `{variant_tag, world_x, world_z, origin_y, yaw}` (no scene code, unit-tested). (3) An imperative `spawn_placement()` + a region placer that instantiates records into `terrain_index`/`terrain_parent`, idempotently (each cell placed once). The live-generator cutover (disabling socket-growth for structure, keeping water/decoration/reveal) and screenshot iteration are **Phase 3c**.

**Tech Stack:** Godot 4.5 typed GDScript, GUT. Layers 1–2 are pure unit tests; layer 3 uses GUT integration tests that instantiate real tile scenes headlessly.

---

## Scope and Phasing

**Phase 3b of the Phase-3 group.** Phases 1–2 built the numerical plan (`HeightfieldPlan`); Phase 3a built the pure mapping (`HeightfieldVariant.cell_descriptor → {family, variant_tag, rotation_steps, origin_y}`). Phase 3b builds the instantiation layer that produces real tiles from the plan **in a test harness / on demand**, but does **not** yet rewire the live `TerrainGenerator`. Phase 3c does the cutover (make the plan the structural source, disable level/cliff socket-growth, keep water + decorations + reveal) and the visual screenshot iteration.

Why this split: layers 1–2 are deterministic and unit-testable; layer 3 is integration-tested (spawn real scenes, assert transforms/indices) but still side-effect-isolated to a test parent node. The risky live rewrite is quarantined to 3c, behind a flag, where visual verification is the acceptance gate.

## Grounding facts (from exploration)

- `module.spawn() -> TerrainModuleInstance`; `instance.create()` instantiates the scene and sets `root.global_transform = instance.transform`. Structural tiles are **not** tagged `"rotate"`, so `create()` does not apply a random yaw to them (only foliage is randomized).
- Place a tile directly: `var inst = module.spawn(); inst.set_transform(Transform3D(Basis(Vector3.UP, yaw), Vector3(x, origin_y, z))); inst.create(); terrain_parent.add_child(inst.root)`.
- Look up a variant module by tag: `library.get_by_tags(TagList.new([tag])) -> TerrainModuleList`, then `library.get_random(list, true)` for the first. Tag map: HV `"ground"`→`"ground-plain"`; `"cliff-interior"`/`"level-center"`→that tag; every other HV `variant_tag` (e.g. `"cliff-side"`, `"level-corner"`) is itself a module tag.
- Tile origins sit at their top surface, so `origin_y` from `HeightfieldVariant` is the transform's Y directly.
- Yaw convention used by the live edge rules: `yaw = PI * 0.5 * ((4 - rotation_steps) % 4)` (rotate the tile so its canonical wall set lands on the actual missing sides). Task 1 verifies this against a real scene.
- `HeightfieldPlan.tile_plan(cx,cz) -> {storey, level, height}` and `surface_height(cx,cz)` provide the plan inputs. `HeightfieldPlan.TILE = 24.0` is the world grid spacing.

## File Structure

- Create: `scripts/terrain/heightfield/HeightfieldFacing.gd` — the asset-grounded mapping from world (dx,dz) offset → socket name (`front`/`right`/`back`/`left` and the diagonals), plus `yaw_for_rotation_steps`.
- Create: `scripts/terrain/heightfield/HeightfieldInstantiator.gd` — pure `placements()` + `spawn_placement()` + `place_region()`.
- Test: `tests/test_heightfield_facing.gd`, `tests/test_heightfield_instantiator.gd`.

## Conventions

- Run a single suite: `/Applications/Godot.app/Contents/MacOS/Godot -d -s --path "$PWD" addons/gut/gut_cmdln.gd -gdir=res://tests -gconfig=res://tests/gutconfig.json -gselect=<file>.gd`
- Full suite: drop `-gselect`. GUT exits 0 only when all pass.

---

### Task 1: Asset-grounded socket→world-direction mapping (discovery + lock-in)

**Files:**
- Create: `scripts/terrain/heightfield/HeightfieldFacing.gd`
- Test: `tests/test_heightfield_facing.gd`

This task first *discovers* the actual socket directions from a real tile scene, then locks them into constants with a guard test. The implementer MUST inspect the scene before writing the constants.

- [ ] **Step 1: Discover the socket layout.** Run this one-off inspection (from `/Users/ryko/story`) and record the output — the local position of each cardinal Marker3D under `Sockets` in a cliff side tile:

```
/Applications/Godot.app/Contents/MacOS/Godot --headless -s --path "$PWD" res://addons/gut/gut_cmdln.gd -gtest=res://tests/test_heightfield_facing.gd -gexit 2>/dev/null || true
```

Before that test exists it will no-op; instead, inspect directly with a tiny script. Create `tests/test_heightfield_facing.gd` with this DISCOVERY test first:

```gdscript
extends GutTest

# Phase 3b Task 1: discover + lock the socket->world-direction mapping.

func test_discover_cliff_side_socket_positions() -> void:
	var scene: PackedScene = load("res://terrain/scenes/CliffSide.tscn")
	var root: Node3D = scene.instantiate()
	var sockets: Node = root.get_node("Sockets")
	for child in sockets.get_children():
		if child is Marker3D:
			gut.p("%s -> %s" % [child.name, str((child as Marker3D).position)])
	root.free()
	assert_true(true, "discovery print only")
```

Run it and READ the printed socket positions:
```
/Applications/Godot.app/Contents/MacOS/Godot -d -s --path "$PWD" addons/gut/gut_cmdln.gd -gdir=res://tests -gconfig=res://tests/gutconfig.json -gselect=test_heightfield_facing.gd
```
Record which cardinal socket sits at +X, -X, +Z, -Z (e.g. `front` at z=-12 means front faces -Z). You will use this to fill in `OFFSET_TO_SOCKET` in Step 3. **Do not guess — use the printed values.**

- [ ] **Step 2: Replace the discovery test with the real guard tests.** Replace the body of `tests/test_heightfield_facing.gd` with:

```gdscript
extends GutTest

# Socket <-> world-direction mapping for heightfield placement (Phase 3b).

func test_offset_to_socket_covers_four_cardinals_and_four_diagonals() -> void:
	var seen: Dictionary = {}
	for off in HeightfieldFacing.OFFSET_TO_SOCKET.keys():
		seen[HeightfieldFacing.OFFSET_TO_SOCKET[off]] = true
	for name in ["front", "right", "back", "left",
			"frontright", "backright", "backleft", "frontleft"]:
		assert_true(seen.has(name), "mapping includes socket '%s'" % name)

func test_offset_to_socket_matches_scene_for_one_cardinal() -> void:
	# Guard: the socket our mapping calls "front" really sits on the -Z (or +Z)
	# face of the actual tile, matching OFFSET_TO_SOCKET. Verifies against the asset.
	var scene: PackedScene = load("res://terrain/scenes/CliffSide.tscn")
	var root: Node3D = scene.instantiate()
	var sockets: Node = root.get_node("Sockets")
	var front_marker: Marker3D = sockets.get_node("front") as Marker3D
	var p: Vector3 = front_marker.position
	root.free()
	# The non-zero horizontal axis of 'front' must be the axis our mapping assigns
	# the 'front' offset to. (Filled from the Step-1 discovery.)
	var front_offset: Vector2i = HeightfieldFacing.socket_to_offset("front")
	# front_offset points along the same axis as the marker's dominant horizontal axis.
	if absf(p.x) > absf(p.z):
		assert_true(front_offset.x != 0 and front_offset.y == 0, "front is an X-axis face")
	else:
		assert_true(front_offset.y != 0 and front_offset.x == 0, "front is a Z-axis face")

func test_yaw_for_rotation_steps() -> void:
	assert_almost_eq(HeightfieldFacing.yaw_for_rotation_steps(0), 0.0, 0.0001, "0 steps => 0 rad")
	assert_almost_eq(HeightfieldFacing.yaw_for_rotation_steps(1), PI * 0.5 * 3.0, 0.0001, "matches (4-steps)%4 convention")
	assert_almost_eq(HeightfieldFacing.yaw_for_rotation_steps(2), PI, 0.0001, "2 steps => 180 deg")
```

- [ ] **Step 3: Create `scripts/terrain/heightfield/HeightfieldFacing.gd`** using the directions discovered in Step 1. Fill `OFFSET_TO_SOCKET` so each `Vector2i(dx, dz)` maps to the socket name whose marker faces that world direction. Example shown assumes `front`=-Z, `right`=+X, `back`=+Z, `left`=-X (CORRECT THESE to the Step-1 output if they differ):

```gdscript
class_name HeightfieldFacing
extends RefCounted

## World (dx, dz) tile-offset -> socket name, grounded in the tile scene's socket
## markers (see test_heightfield_facing). Used so a wall computed for a given world
## direction maps to the socket the variant system rotates. Diagonals included for
## inner-corner detection.
##
## FILL/VERIFY these from the Step-1 discovery output for CliffSide.tscn.
const OFFSET_TO_SOCKET: Dictionary = {
	Vector2i(0, -1): "front",
	Vector2i(1, 0): "right",
	Vector2i(0, 1): "back",
	Vector2i(-1, 0): "left",
	Vector2i(1, -1): "frontright",
	Vector2i(1, 1): "backright",
	Vector2i(-1, 1): "backleft",
	Vector2i(-1, -1): "frontleft",
}


static func socket_to_offset(socket_name: String) -> Vector2i:
	for off in OFFSET_TO_SOCKET.keys():
		if OFFSET_TO_SOCKET[off] == socket_name:
			return off
	return Vector2i.ZERO


## Yaw (radians) to apply so a variant's canonical wall set lands on its actual
## missing sides — matches LevelEdgeRule/CliffEdgeRule: PI/2 * ((4 - steps) % 4).
static func yaw_for_rotation_steps(rotation_steps: int) -> float:
	return PI * 0.5 * float((4 - rotation_steps) % 4)
```

- [ ] **Step 4: Run, confirm PASS.** Expected: 3 passing. If `test_offset_to_socket_matches_scene_for_one_cardinal` fails, the `OFFSET_TO_SOCKET` directions are wrong — correct them from the Step-1 output (do not change the test).

- [ ] **Step 5: Commit:**
```bash
git add scripts/terrain/heightfield/HeightfieldFacing.gd tests/test_heightfield_facing.gd
git commit -m "feat(terrain): asset-grounded socket<->world-direction mapping + yaw

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: `HeightfieldInstantiator.placements()` — cells → placement records (pure)

**Files:**
- Create: `scripts/terrain/heightfield/HeightfieldInstantiator.gd`
- Test: `tests/test_heightfield_instantiator.gd`

- [ ] **Step 1: Write the failing tests** — create `tests/test_heightfield_instantiator.gd`:

```gdscript
extends GutTest

# Phase 3b: cells -> placement records (pure, no scene instantiation).

func _stepped_plan() -> HeightfieldPlan:
	# A clean E-W step: x<0 is storey 0 (ground), x>=0 is storey 1 (cliff plateau).
	var plan: HeightfieldPlan = HeightfieldPlan.new(1, 100.0, 8, "mean")
	plan.set_raw_height_override(func(cx: int, cz: int) -> float:
		return 4.2 if cx >= 0 else 0.0)
	return plan

func test_placements_cover_every_cell_in_radius() -> void:
	var plan: HeightfieldPlan = _stepped_plan()
	var recs: Array = HeightfieldInstantiator.placements(plan, 0, 0, 1)
	# radius 1 => a 3x3 block => 9 cells, each yields exactly one record.
	assert_eq(recs.size(), 9, "one placement per cell in the (2r+1)^2 block")

func test_placement_record_fields() -> void:
	var plan: HeightfieldPlan = _stepped_plan()
	var recs: Array = HeightfieldInstantiator.placements(plan, 0, 0, 0)
	var r: Dictionary = recs[0]
	for key in ["variant_tag", "family", "world_x", "world_z", "origin_y", "yaw"]:
		assert_true(r.has(key), "record has '%s'" % key)

func test_placement_world_position_uses_tile_spacing() -> void:
	var plan: HeightfieldPlan = _stepped_plan()
	var recs: Array = HeightfieldInstantiator.placements(plan, 2, -3, 0)
	var r: Dictionary = recs[0]
	assert_almost_eq(r["world_x"], 2.0 * HeightfieldPlan.TILE, 0.0001, "world_x = cx * TILE")
	assert_almost_eq(r["world_z"], -3.0 * HeightfieldPlan.TILE, 0.0001, "world_z = cz * TILE")

func test_placement_classifies_the_cliff_edge() -> void:
	# The cell at cx=0 (storey 1) has its west neighbour (cx=-1) a storey lower:
	# a cliff edge => cliff family, cliff-side variant, origin 4.0m.
	var plan: HeightfieldPlan = _stepped_plan()
	var recs: Array = HeightfieldInstantiator.placements(plan, 0, 0, 0)
	var r: Dictionary = recs[0]
	assert_eq(r["family"], "cliff", "the storey-1 edge cell is cliff")
	assert_eq(r["variant_tag"], "cliff-side", "single cliff wall => cliff-side")
	assert_almost_eq(r["origin_y"], 4.0, 0.0001, "cliff plateau top at storey*4")
```

- [ ] **Step 2: Run, confirm FAIL** (`HeightfieldInstantiator` unknown).

- [ ] **Step 3: Create `scripts/terrain/heightfield/HeightfieldInstantiator.gd`:**

```gdscript
class_name HeightfieldInstantiator
extends RefCounted

## Turns the heightfield plan into placement records and (Task 3) real tiles.
## A placement record is {variant_tag, family, world_x, world_z, origin_y, yaw}.

## Build the neighbour-height dictionaries (socket name -> surface height) for a cell.
static func _neighbour_heights(plan: HeightfieldPlan, cx: int, cz: int) -> Array:
	var cardinals: Dictionary = {}
	var diagonals: Dictionary = {}
	for off in HeightfieldFacing.OFFSET_TO_SOCKET.keys():
		var socket_name: String = HeightfieldFacing.OFFSET_TO_SOCKET[off]
		var h: float = plan.surface_height(cx + off.x, cz + off.y)
		if off.x == 0 or off.y == 0:
			cardinals[socket_name] = h
		else:
			diagonals[socket_name] = h
	return [cardinals, diagonals]


## One placement record per cell in the (2*place_radius+1)^2 block around (cx,cz).
static func placements(plan: HeightfieldPlan, cx: int, cz: int, place_radius: int) -> Array:
	var out: Array = []
	for dz in range(-place_radius, place_radius + 1):
		for dx in range(-place_radius, place_radius + 1):
			out.append(placement_for_cell(plan, cx + dx, cz + dz))
	return out


## The placement record for a single cell.
static func placement_for_cell(plan: HeightfieldPlan, cx: int, cz: int) -> Dictionary:
	var tp: Dictionary = plan.tile_plan(cx, cz)
	var h0: float = float(tp["height"])
	var nb: Array = _neighbour_heights(plan, cx, cz)
	var desc: Dictionary = HeightfieldVariant.cell_descriptor(
		h0, int(tp["storey"]), int(tp["level"]), nb[0], nb[1]
	)
	return {
		"variant_tag": desc["variant_tag"],
		"family": desc["family"],
		"world_x": float(cx) * HeightfieldPlan.TILE,
		"world_z": float(cz) * HeightfieldPlan.TILE,
		"origin_y": float(desc["origin_y"]),
		"yaw": HeightfieldFacing.yaw_for_rotation_steps(int(desc["rotation_steps"])),
	}
```

- [ ] **Step 4: Run, confirm PASS.** Expected: 4 passing. (Note: `placements` calls `surface_height`/`tile_plan` per cell, which build windows — slow but fine for small test radii.)

- [ ] **Step 5: Commit:**
```bash
git add scripts/terrain/heightfield/HeightfieldInstantiator.gd tests/test_heightfield_instantiator.gd
git commit -m "feat(terrain): cell -> placement record from the heightfield plan

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: `spawn_placement()` — instantiate one record (integration)

**Files:**
- Modify: `scripts/terrain/heightfield/HeightfieldInstantiator.gd`
- Modify: `tests/test_heightfield_instantiator.gd`

- [ ] **Step 1: Write the failing test** — append to the END of `tests/test_heightfield_instantiator.gd`:

```gdscript
func _library() -> TerrainModuleLibrary:
	var lib: TerrainModuleLibrary = TerrainModuleLibrary.new()
	lib.init()
	return lib

func test_spawn_placement_creates_a_tile_at_the_right_transform() -> void:
	var parent: Node3D = Node3D.new()
	add_child_autofree(parent)
	var lib: TerrainModuleLibrary = _library()
	var rec: Dictionary = {
		"variant_tag": "cliff-side", "family": "cliff",
		"world_x": 48.0, "world_z": -24.0, "origin_y": 4.0, "yaw": 0.0,
	}
	var inst: TerrainModuleInstance = HeightfieldInstantiator.spawn_placement(rec, lib, parent)
	assert_not_null(inst, "a tile instance is produced")
	assert_not_null(inst.root, "the scene was instantiated")
	assert_true(inst.def.tags.has("cliff-side"), "the chosen module is a cliff-side variant")
	assert_almost_eq(inst.transform.origin.x, 48.0, 0.01, "x placed")
	assert_almost_eq(inst.transform.origin.y, 4.0, 0.01, "origin_y placed")
	assert_almost_eq(inst.transform.origin.z, -24.0, 0.01, "z placed")
	assert_eq(inst.root.get_parent(), parent, "tile parented under the target node")

func test_spawn_placement_ground_uses_ground_plain() -> void:
	var parent: Node3D = Node3D.new()
	add_child_autofree(parent)
	var lib: TerrainModuleLibrary = _library()
	var rec: Dictionary = {
		"variant_tag": "ground", "family": "ground",
		"world_x": 0.0, "world_z": 0.0, "origin_y": 0.0, "yaw": 0.0,
	}
	var inst: TerrainModuleInstance = HeightfieldInstantiator.spawn_placement(rec, lib, parent)
	assert_not_null(inst, "ground tile produced")
	assert_true(inst.def.tags.has("ground-plain"), "ground maps to the ground-plain module")
```

- [ ] **Step 2: Run, confirm FAIL** (`spawn_placement` not found).

- [ ] **Step 3: Append to `scripts/terrain/heightfield/HeightfieldInstantiator.gd`:**

```gdscript
## HV variant_tag -> the module tag to look up in the library.
static func _lookup_tag(variant_tag: String) -> String:
	if variant_tag == "ground":
		return "ground-plain"
	return variant_tag


## Instantiate one placement record under `parent` and return the live instance,
## or null if no module matches the tag. Sets the transform directly (origin_y +
## a Y-axis yaw) — no socket attachment. Caller is responsible for indexing.
static func spawn_placement(
	record: Dictionary, library: TerrainModuleLibrary, parent: Node3D
) -> TerrainModuleInstance:
	var tag: String = _lookup_tag(String(record["variant_tag"]))
	var modules: TerrainModuleList = library.get_by_tags(TagList.new([tag]))
	if modules.is_empty():
		push_error("HeightfieldInstantiator: no module for tag '%s'" % tag)
		return null
	var template: TerrainModule = library.get_random(modules, true)
	var inst: TerrainModuleInstance = template.spawn()
	var basis: Basis = Basis(Vector3.UP, float(record["yaw"]))
	var origin: Vector3 = Vector3(float(record["world_x"]), float(record["origin_y"]), float(record["world_z"]))
	inst.set_transform(Transform3D(basis, origin))
	inst.create()
	parent.add_child(inst.root)
	return inst
```

- [ ] **Step 4: Run, confirm PASS.** Expected: 6 passing.

- [ ] **Step 5: Commit:**
```bash
git add scripts/terrain/heightfield/HeightfieldInstantiator.gd tests/test_heightfield_instantiator.gd
git commit -m "feat(terrain): spawn one placement record into the scene

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: `place_region()` — idempotent region placement (integration)

**Files:**
- Modify: `scripts/terrain/heightfield/HeightfieldInstantiator.gd`
- Modify: `tests/test_heightfield_instantiator.gd`

- [ ] **Step 1: Write the failing test** — append to the END of `tests/test_heightfield_instantiator.gd`:

```gdscript
func test_place_region_places_each_cell_once_and_is_idempotent() -> void:
	var parent: Node3D = Node3D.new()
	add_child_autofree(parent)
	var lib: TerrainModuleLibrary = _library()
	var plan: HeightfieldPlan = _stepped_plan()
	var placer: HeightfieldInstantiator = HeightfieldInstantiator.new()
	# First pass over a 3x3 block: 9 tiles spawned.
	placer.place_region(plan, lib, parent, 0, 0, 1)
	assert_eq(parent.get_child_count(), 9, "9 tiles for a 3x3 block")
	# Second pass over the same block: no duplicates (already-placed cells skipped).
	placer.place_region(plan, lib, parent, 0, 0, 1)
	assert_eq(parent.get_child_count(), 9, "re-running places nothing new (idempotent)")

func test_place_region_tiles_sit_at_plan_heights() -> void:
	var parent: Node3D = Node3D.new()
	add_child_autofree(parent)
	var lib: TerrainModuleLibrary = _library()
	var plan: HeightfieldPlan = _stepped_plan()
	var placer: HeightfieldInstantiator = HeightfieldInstantiator.new()
	placer.place_region(plan, lib, parent, 0, 0, 1)
	# Every spawned tile's origin.y equals the plan's surface height for its cell.
	for child in parent.get_children():
		var t: Transform3D = (child as Node3D).global_transform
		var cx: int = int(round(t.origin.x / HeightfieldPlan.TILE))
		var cz: int = int(round(t.origin.z / HeightfieldPlan.TILE))
		assert_almost_eq(t.origin.y, plan.surface_height(cx, cz), 0.01,
			"tile at (%d,%d) sits at its plan surface height" % [cx, cz])
```

- [ ] **Step 2: Run, confirm FAIL** (`place_region` not found).

- [ ] **Step 3: Append to `scripts/terrain/heightfield/HeightfieldInstantiator.gd`:**

```gdscript
# Instance state: cells already placed (so re-running a region is idempotent and
# churn-free). Keyed by Vector2i(cx, cz).
var _placed: Dictionary = {}


## Place every not-yet-placed cell in the (2*place_radius+1)^2 block around the
## center cell, under `parent`. Returns the instances spawned this call. A cell is
## placed at most once for the lifetime of this instance, so repeated calls as the
## player moves never re-place (or churn) settled tiles.
func place_region(
	plan: HeightfieldPlan, library: TerrainModuleLibrary, parent: Node3D,
	center_cx: int, center_cz: int, place_radius: int
) -> Array[TerrainModuleInstance]:
	var spawned: Array[TerrainModuleInstance] = []
	for dz in range(-place_radius, place_radius + 1):
		for dx in range(-place_radius, place_radius + 1):
			var cell: Vector2i = Vector2i(center_cx + dx, center_cz + dz)
			if _placed.has(cell):
				continue
			var rec: Dictionary = placement_for_cell(plan, cell.x, cell.y)
			var inst: TerrainModuleInstance = spawn_placement(rec, library, parent)
			_placed[cell] = true
			if inst != null:
				spawned.append(inst)
	return spawned
```

- [ ] **Step 4: Run, confirm PASS.** Expected: 8 passing.

- [ ] **Step 5: Run the FULL suite (regression):**
```
/Applications/Godot.app/Contents/MacOS/Godot -d -s --path "$PWD" addons/gut/gut_cmdln.gd -gdir=res://tests -gconfig=res://tests/gutconfig.json
```
Report the Run Summary totals. All pass; leaked-RID shutdown lines are normal.

- [ ] **Step 6: Commit:**
```bash
git add scripts/terrain/heightfield/HeightfieldInstantiator.gd tests/test_heightfield_instantiator.gd
git commit -m "feat(terrain): idempotent region placement from the heightfield plan

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage (Phase 3b scope):** Tile instantiation from the plan → Tasks 2–4. Variant scene + rotation + Y from `HeightfieldVariant` → Task 2 (records) + Task 3 (spawn). Plan-vs-place via `place_region`'s `place_radius` and the `_placed` set (churn-free; the plan itself is already final per Phases 1–2) → Task 4. The **live-generator cutover** (disable level/cliff socket-growth; route through the plan; keep water/decoration/reveal), `terrain_index`/`socket_index` registration in the live loop, and **visual/screenshot verification** are explicitly **Phase 3c** (this phase isolates side effects to a test parent node and asserts transforms/tags/heights, not appearance).

**Placeholder scan:** Task 1 is a deliberate discovery-then-lock task (the only honest way to ground socket directions in the asset); its constants are filled from real output, not guessed, and a guard test verifies them. No TBD/TODO elsewhere; all other code steps are complete.

**Type/name consistency:** `HeightfieldFacing.OFFSET_TO_SOCKET`, `socket_to_offset`, `yaw_for_rotation_steps`; `HeightfieldInstantiator.placement_for_cell`, `placements`, `spawn_placement`, `place_region`, `_lookup_tag`, `_neighbour_heights`, `_placed`. Records use keys `{variant_tag, family, world_x, world_z, origin_y, yaw}` consistently across Tasks 2–4. Consumes `HeightfieldPlan.{tile_plan, surface_height, TILE}` and `HeightfieldVariant.cell_descriptor` (real signatures from Phases 1–3a) and `TerrainModuleLibrary.{get_by_tags, get_random}`, `TerrainModule.spawn`, `TerrainModuleInstance.{set_transform, create}` (real APIs).

**Risk notes:** (1) Task 1's socket-direction mapping is the one asset-dependent unknown; the guard test (`test_offset_to_socket_matches_scene_for_one_cardinal`) catches a wrong mapping at test time. (2) `place_region` registers tiles only under a parent `Node3D`; wiring into the live `terrain_index`/reveal/streaming is Phase 3c, where the wrong-facing or wrong-height tiles would also be caught visually. (3) `placements`/`place_region` call the slow reference `surface_height` per cell — fine for tests and modest radii; Phase 3c can batch the plan over a chunk if profiling warrants.
