# Heightfield Terrain — Live Cutover (Phase 3c) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the heightfield plan the **structural source of truth in the live game** — behind a flag — so cliffs and level terraces are placed deterministically from the plan instead of by emergent socket-growth, while water, decorations, the base ground plane, and the reveal margin keep working unchanged. The acceptance gate is **zero structural churn (burst harness) + correct appearance (screenshots)**.

**Architecture:** Add a flag `use_heightfield` to `TerrainGenerator`. When on: each frame, drive `HeightfieldInstantiator.place_region` around the player to place structural tiles (cliff/level/ground) directly from a `HeightfieldPlan`, registering them in `terrain_index`/`socket_index` and applying the existing reveal-margin visibility; and **suppress emergent structural seeding** (ground-topcenter no longer seeds level/cliff; level/cliff laterals off) so the only structure comes from the plan. Water (`WaterRule`), foliage/decoration sockets, and base-ground lateral tiling stay live. `_placed` gains distance eviction so memory is bounded over long play.

**Tech Stack:** Godot 4.5 typed GDScript, GUT for integration tests, the existing `tests/harness/burst_harness.gd` for churn measurement, and headless screenshots for visual acceptance.

---

## Scope, risk, and validation

This is the **highest-risk phase** and the first that modifies the live `TerrainGenerator`. It is gated behind `use_heightfield` (default **false**) so the existing emergent generator remains the shipping path until the heightfield path is proven. Much of the acceptance is **not unit-testable**: it is (a) the churn harness reporting **0** structural (cliff/level) churn while running, and (b) screenshots showing terraced hills, cliff staircases, terraces at cliff feet, and no vertical gaps. Each task states its verification explicitly; where a task is visual, that is called out — do not fabricate a unit test that pretends to cover appearance.

Carried over from Phase 3b review (now in scope here): **(I1)** `_placed` must evict distant cells (bounded memory) — Task 3; **(M1)** dropped-null placements (missing module/scene) must be surfaced, not silently swallowed — Task 3.

## Grounding facts (from earlier exploration of TerrainGenerator.gd)

- `register_piece(piece, "")` inserts a piece into `socket_index` (per socket) and `terrain_index`, and calls `_apply_initial_visibility` (the reveal-margin hide). A directly-placed structural tile must be registered this way so water/decoration/adjacency and reveal all work.
- `_apply_initial_visibility(piece)` hides a piece if it is beyond `_reveal_radius()` (`RENDER_RANGE - REVEAL_MARGIN`); `_reveal_settled_pieces()` (called each `load_terrain`) reveals them once the player is close. This mechanism is reused as-is.
- `add_piece_to_queue(piece)` seeds a piece's expandable sockets into the queue (foliage, water-relevant ground laterals, and — today — the ground-topcenter structural seed). Structural seeding is driven by the fill-prob constants in `TerrainModuleDefinitions.gd`: `GROUND_TOPCENTER_FILL_PROB`, `GROUND_TOPCENTER_LEVEL_PROB`/`CLIFF_PROB`, `LEVEL_BASE_LATERAL_FILL_PROB`, `CLIFF_LATERAL_FILL_PROB`, `*_TOPCENTER_FILL_PROB`.
- `WaterRule` fires on any `ground`-family tile in `terrain_index` regardless of how it was placed; foliage spawns from tiles' top sockets via the queue. Both are independent of structural socket-growth.
- World grid is 24u; player cell = `Vector3(snappedf(p.x,24)/24, _, snappedf(p.z,24)/24)`. `HeightfieldPlan.TILE = 24.0`.
- `HeightfieldInstantiator.place_region(plan, library, parent, center_cx, center_cz, place_radius)` spawns+parents structural tiles and returns the new instances; it does NOT yet index them.

## File Structure

- Modify: `scripts/terrain/TerrainGenerator.gd` — add `use_heightfield` flag, a `HeightfieldPlan`/`HeightfieldInstantiator` member, a `_drive_heightfield_structure()` step in `load_terrain`, and structural-seed suppression when the flag is on.
- Modify: `scripts/terrain/heightfield/HeightfieldInstantiator.gd` — `_placed` eviction + dropped-null reporting.
- Modify: `scripts/terrain/TerrainModuleDefinitions.gd` — gate structural seed probabilities behind the flag (via a settable module-build parameter or a generator-side suppression — see Task 2).
- Test: `tests/test_heightfield_cutover.gd` (integration), reuse `tests/harness/burst_harness.gd` (churn), screenshots (visual).

## Conventions

- Run a suite: `/Applications/Godot.app/Contents/MacOS/Godot -d -s --path "$PWD" addons/gut/gut_cmdln.gd -gdir=res://tests -gconfig=res://tests/gutconfig.json -gselect=<file>.gd`
- The flag defaults to **false**; every existing test must stay green with it off.

---

### Task 1: `_placed` eviction + dropped-null reporting (instantiator hardening)

**Files:**
- Modify: `scripts/terrain/heightfield/HeightfieldInstantiator.gd`
- Modify: `tests/test_heightfield_instantiator.gd`

- [ ] **Step 1: Write the failing tests** — append to the END of `tests/test_heightfield_instantiator.gd`:

```gdscript
func test_evict_placed_outside_radius_prunes_distant_cells() -> void:
	var parent: Node3D = Node3D.new()
	add_child_autofree(parent)
	var lib: TerrainModuleLibrary = _library()
	var plan: HeightfieldPlan = _stepped_plan()
	var placer: HeightfieldInstantiator = HeightfieldInstantiator.new()
	placer.place_region(plan, lib, parent, 0, 0, 1)            # places cells around (0,0)
	assert_eq(placer.placed_count(), 9, "9 cells tracked")
	# Evict everything not within radius 0 of a far center => all 9 pruned.
	placer.evict_placed_outside(100, 100, 0)
	assert_eq(placer.placed_count(), 0, "distant cells pruned from the placed set")

func test_place_region_reports_dropped_cells_for_unknown_tag() -> void:
	# A record whose tag has no module is dropped; place_region must count it.
	var parent: Node3D = Node3D.new()
	add_child_autofree(parent)
	var lib: TerrainModuleLibrary = _library()
	var placer: HeightfieldInstantiator = HeightfieldInstantiator.new()
	var dropped: int = placer.spawn_count_dropped({
		"variant_tag": "no-such-variant", "family": "cliff",
		"world_x": 0.0, "world_z": 0.0, "origin_y": 0.0, "yaw": 0.0,
	}, lib, parent)
	assert_eq(dropped, 1, "an unknown tag is reported as a dropped placement")
```

- [ ] **Step 2: Run, confirm FAIL** (`placed_count` / `evict_placed_outside` / `spawn_count_dropped` not found).

- [ ] **Step 3: Append to `scripts/terrain/heightfield/HeightfieldInstantiator.gd`:**

```gdscript
## Number of cells currently tracked as placed.
func placed_count() -> int:
	return _placed.size()


## Drop placed-cell records whose Chebyshev distance from (center_cx, center_cz)
## exceeds `keep_radius`, so the set stays bounded as the player roams. Cells
## re-enter the world via place_region exactly as first time (the plan is
## deterministic, so re-placement is identical — no churn).
func evict_placed_outside(center_cx: int, center_cz: int, keep_radius: int) -> void:
	var survivors: Dictionary = {}
	for cell in _placed.keys():
		if absi(cell.x - center_cx) <= keep_radius and absi(cell.y - center_cz) <= keep_radius:
			survivors[cell] = true
	_placed = survivors


## Spawn one record; return 1 if it was dropped (no module / failed create), else 0.
## Lets a caller surface gaps that spawn_placement reports only via push_error.
func spawn_count_dropped(record: Dictionary, library: TerrainModuleLibrary, parent: Node3D) -> int:
	return 0 if spawn_placement(record, library, parent) != null else 1
```

- [ ] **Step 4: Run, confirm PASS.** Expected: 14 passing.

- [ ] **Step 5: Commit:**
```bash
git add scripts/terrain/heightfield/HeightfieldInstantiator.gd tests/test_heightfield_instantiator.gd
git commit -m "feat(terrain): bounded _placed eviction + dropped-placement reporting

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: `use_heightfield` flag + structural-seed suppression (no behaviour change when off)

**Files:**
- Modify: `scripts/terrain/TerrainGenerator.gd`
- Test: `tests/test_heightfield_cutover.gd`

This task adds the flag and the suppression path but does NOT yet place plan tiles (Task 3). Goal: with the flag ON, the emergent generator stops producing level/cliff tiles (so they can't fight the plan); with it OFF, nothing changes.

- [ ] **Step 1: Write the failing test** — create `tests/test_heightfield_cutover.gd`:

```gdscript
extends GutTest

# Phase 3c: the heightfield cutover flag suppresses emergent structural growth.

func _make_generator(use_hf: bool) -> Node:
	var gen = preload("res://scripts/terrain/TerrainGenerator.gd").new()
	gen.use_heightfield = use_hf
	return gen

func test_flag_defaults_off() -> void:
	var gen = _make_generator(false)
	assert_false(gen.use_heightfield, "heightfield path is off by default")
	gen.free()

func test_structural_seeding_suppressed_when_flag_on() -> void:
	# With the flag on, the generator must not treat ground-topcenter / level /
	# cliff sockets as structural seeds (those come from the plan instead).
	var gen = _make_generator(true)
	assert_true(gen.structural_seeding_suppressed(), "structural seeds off under heightfield")
	gen.free()

func test_structural_seeding_active_when_flag_off() -> void:
	var gen = _make_generator(false)
	assert_false(gen.structural_seeding_suppressed(), "emergent structural seeds on by default")
	gen.free()
```

- [ ] **Step 2: Run, confirm FAIL** (`use_heightfield` / `structural_seeding_suppressed` unknown):
```
/Applications/Godot.app/Contents/MacOS/Godot -d -s --path "$PWD" addons/gut/gut_cmdln.gd -gdir=res://tests -gconfig=res://tests/gutconfig.json -gselect=test_heightfield_cutover.gd
```

- [ ] **Step 3: Implement the flag + suppression.** In `scripts/terrain/TerrainGenerator.gd`:

(a) Add the export near the other exports (after `@export var MAX_LOAD_PER_STEP`):
```gdscript
## When true, structural tiles (level/cliff) come from the deterministic
## heightfield plan instead of emergent socket-growth. Water, decorations, the
## base ground plane, and the reveal margin are unaffected.
@export var use_heightfield: bool = false
```

(b) Add the predicate:
```gdscript
func structural_seeding_suppressed() -> bool:
	return use_heightfield
```

(c) Gate structural seeding in `add_piece_to_queue`. Find the structural-seed enqueue path. The simplest correct gate: in `_effective_fill_prob` (or at the enqueue roll), when `structural_seeding_suppressed()` is true, return 0 for STRUCTURAL sockets — the ground-topcenter seed and any `level`/`cliff` lateral/topcenter sockets — while leaving foliage (point-capable) and base ground laterals untouched. Add this guard at the TOP of `_effective_fill_prob(piece, socket_name, pos)`:
```gdscript
	if structural_seeding_suppressed() and _is_structural_socket(piece, socket_name):
		return 0.0
```
and add the helper:
```gdscript
## A socket whose expansion would place a level/cliff structural tile: the
## ground-topcenter seed, and any lateral/topcenter on a level or cliff tile.
## (Foliage top sockets and base-ground cardinal laterals are NOT structural.)
func _is_structural_socket(piece: TerrainModuleInstance, socket_name: String) -> bool:
	if piece.def.tags.has("level") or piece.def.tags.has("cliff"):
		return socket_name in ["front", "back", "left", "right", "topcenter"]
	if piece.def.tags.has("ground-plain") and socket_name == "topcenter":
		return true
	return false
```

- [ ] **Step 4: Run, confirm PASS.** Expected: 3 passing.

- [ ] **Step 5: Run the FULL suite with the flag OFF (regression — nothing should change):**
```
/Applications/Godot.app/Contents/MacOS/Godot -d -s --path "$PWD" addons/gut/gut_cmdln.gd -gdir=res://tests -gconfig=res://tests/gutconfig.json
```
Report totals. All existing tests must still pass (flag defaults off).

- [ ] **Step 6: Commit:**
```bash
git add scripts/terrain/TerrainGenerator.gd tests/test_heightfield_cutover.gd
git commit -m "feat(terrain): use_heightfield flag + structural-seed suppression

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Drive plan placement in the live loop (registered + revealed)

**Files:**
- Modify: `scripts/terrain/TerrainGenerator.gd`
- Modify: `tests/test_heightfield_cutover.gd`

- [ ] **Step 1: Write the failing test** — append to the END of `tests/test_heightfield_cutover.gd`:

```gdscript
func test_heightfield_places_and_indexes_structural_tiles() -> void:
	# With the flag on, after driving the structure step the terrain index holds
	# tiles at the plan's surface heights around the player origin.
	var gen = _make_generator(true)
	gen.init_for_test()  # builds library + indices + a HeightfieldPlan (test seam)
	gen.drive_heightfield_structure(Vector3.ZERO)
	var plan: HeightfieldPlan = gen.heightfield_plan
	var found: int = 0
	for cz in range(-1, 2):
		for cx in range(-1, 2):
			var center: Vector3 = Vector3(cx * 24.0, plan.surface_height(cx, cz), cz * 24.0)
			var box: AABB = AABB(center - Vector3(1, 2, 1), Vector3(2, 4, 2))
			for hit in gen.terrain_index.query_box(box):
				if hit is TerrainModuleInstance:
					found += 1
					break
	assert_gt(found, 0, "structural tiles were placed and indexed near the player")
	gen.free()
```

- [ ] **Step 2: Run, confirm FAIL** (`init_for_test` / `drive_heightfield_structure` / `heightfield_plan` not found).

- [ ] **Step 3: Implement.** In `scripts/terrain/TerrainGenerator.gd`:

(a) Add members near the other state:
```gdscript
@export var HEIGHTFIELD_PLACE_RADIUS: int = 8
var heightfield_plan: HeightfieldPlan = null
var _heightfield_placer: HeightfieldInstantiator = null
```

(b) In `_ready()` (and a small `init_for_test()` seam that sets up `library`/indices/plan without the full scene), construct the plan + placer when the flag is on:
```gdscript
	if use_heightfield:
		heightfield_plan = HeightfieldPlan.new(world_seed)
		_heightfield_placer = HeightfieldInstantiator.new()
```
Add:
```gdscript
## Test seam: minimal setup (library, indices, plan) without the world scene.
func init_for_test() -> void:
	if library == null:
		library = TerrainModuleLibrary.new()
		library.init()
	if terrain_index == null:
		terrain_index = TerrainIndex.new()
	if socket_index == null:
		socket_index = PositionIndex.new()
	if heightfield_plan == null:
		heightfield_plan = HeightfieldPlan.new(world_seed)
	if _heightfield_placer == null:
		_heightfield_placer = HeightfieldInstantiator.new()
```

(c) Add the drive step and call it from `load_terrain()` when the flag is on (before the queue loop):
```gdscript
## Place (and index) plan structural tiles around the player, then evict far ones.
func drive_heightfield_structure(player_pos: Vector3) -> void:
	if not use_heightfield or heightfield_plan == null:
		return
	var cx: int = int(round(player_pos.x / HeightfieldPlan.TILE))
	var cz: int = int(round(player_pos.z / HeightfieldPlan.TILE))
	var spawned: Array = _heightfield_placer.place_region(
		heightfield_plan, library, terrain_parent, cx, cz, HEIGHTFIELD_PLACE_RADIUS
	)
	for inst in spawned:
		register_piece(inst, "")       # index + reveal-margin visibility
		add_piece_to_queue(inst)       # seed ONLY foliage/water (structural seeds suppressed by Task 2)
	_heightfield_placer.evict_placed_outside(cx, cz, HEIGHTFIELD_PLACE_RADIUS + 2)
```
In `load_terrain()`, near the top (after computing the player position), add:
```gdscript
	if use_heightfield:
		drive_heightfield_structure(player.global_position if player != null else Vector3.ZERO)
```

- [ ] **Step 4: Run, confirm PASS.** Expected: 4 passing (the cutover suite).

- [ ] **Step 5: Run the FULL suite (flag still defaults off elsewhere):**
```
/Applications/Godot.app/Contents/MacOS/Godot -d -s --path "$PWD" addons/gut/gut_cmdln.gd -gdir=res://tests -gconfig=res://tests/gutconfig.json
```
Report totals; all pass.

- [ ] **Step 6: Commit:**
```bash
git add scripts/terrain/TerrainGenerator.gd tests/test_heightfield_cutover.gd
git commit -m "feat(terrain): drive heightfield structural placement in the live loop

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Churn-harness + visual acceptance (the real gate)

**Files:**
- Modify: `tests/harness/burst_harness.gd` (enable the flag for a heightfield run) or add a small variant scene.
- Visual: screenshots via the project's run/screenshot path.

This task is **validation, not new feature code**. It is partly NOT unit-testable; the acceptance is the harness churn number and the screenshots.

- [ ] **Step 1: Churn gate.** Run the burst harness with `use_heightfield = true` on the world's `TerrainGenerator`. The harness already classifies removals by family and reports `churn_by_family`. Acceptance: **`replaced` + `vanished` for `cliff/bank` and `level` families is 0** while running (structural tiles never retile or pop, because placement is deterministic and final). Record the harness output. If structural churn > 0, STOP and report — it means a plan cell is being re-placed differently (a determinism or eviction bug) and must be fixed before proceeding.

- [ ] **Step 2: Visual acceptance (screenshots).** Run the game/world headlessly with the flag on and capture screenshots at a few player positions (reuse the project's existing screenshot mechanism used in prior terrain iterations). Inspect for: terraced hills (0.5m steps), cliff staircases for mountains (4m faces), terraces at the feet of cliffs, **no vertical gaps** between adjacent tiles, and no appear/disappear churn while moving. Record observations with the screenshots. Iterate on tuning (`HeightfieldPlan` amplitude / `max_storeys` / band edges, `HEIGHTFIELD_PLACE_RADIUS` vs `RENDER_RANGE`) until the look is correct.

- [ ] **Step 3: Document results.** Append a short "Phase 3c results" note to the design spec or a results file: the churn numbers, the screenshots, and any tuning values landed on. Commit any tuning changes.

```bash
git add -A scripts/terrain/ docs/
git commit -m "test(terrain): heightfield cutover churn + visual acceptance

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage (Phase 3c scope):** Make the plan the structural source behind a flag → Tasks 2–3. Keep water/decoration/ground/reveal → Task 2's targeted suppression (only level/cliff/ground-topcenter structural sockets are gated; foliage + base laterals untouched) + reuse of `register_piece`/`add_piece_to_queue`. Churn-free + visual acceptance → Task 4. The Phase-3b carry-overs (`_placed` eviction, dropped-null reporting) → Task 1.

**Placeholder scan:** Tasks 1–3 have complete code and concrete tests. Task 4 is explicitly a validation task (harness + screenshots) and says so — it is not a disguised TODO; it has concrete acceptance criteria (0 structural churn; named visual checks) and a stop condition.

**Type/name consistency:** New `TerrainGenerator` members/methods: `use_heightfield`, `structural_seeding_suppressed`, `_is_structural_socket`, `heightfield_plan`, `_heightfield_placer`, `HEIGHTFIELD_PLACE_RADIUS`, `init_for_test`, `drive_heightfield_structure`. New `HeightfieldInstantiator` methods: `placed_count`, `evict_placed_outside`, `spawn_count_dropped`. All consume real APIs (`register_piece`, `add_piece_to_queue`, `terrain_index.query_box`, `HeightfieldPlan`, `HeightfieldInstantiator.place_region`).

**Risk notes (high):**
- Task 2's `_is_structural_socket` gate is the crux: it must suppress exactly the structural seeds and nothing else. The full-suite-with-flag-off regression (Task 2 Step 5) protects the shipping path; a flag-on integration test plus the churn/visual gate (Task 4) protect the new path. The exact socket list may need adjustment once observed in-situ — verify against `TerrainModuleDefinitions` socket names during implementation.
- `drive_heightfield_structure` registers plan tiles and also calls `add_piece_to_queue` so foliage/water still seed; because structural seeds are suppressed (Task 2), the queue only produces decorations/water on these tiles. Confirm in Task 4 that decorations still appear and water/banks still form.
- Visual correctness (facing, heights, gaps) is only fully verifiable in Task 4. The asset-grounded facing (Phase 3b Task 1) and the `0/0.5/4` invariant (Phases 1–2) make gaps/wrong-facing unlikely, but Task 4 is where it is confirmed; budget iteration there.
- Eviction radius (`HEIGHTFIELD_PLACE_RADIUS + 2`) must exceed the place radius so tiles aren't evicted while still visible; reconcile with `RENDER_RANGE`/`REVEAL_MARGIN` during Task 4 tuning.
