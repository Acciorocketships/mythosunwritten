# Growing Upper Floors Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Some town houses grow outward storey by storey on their street faces (York's Shambles): each upper storey leans one baked step further over the lane, closed like today's room projections, so facing upper floors nearly meet while the lane keeps a slot of sky. Tunable by town odds; byte-identical to today when `growing_house_chance = 0`.

**Architecture:** A new pure kit-layer fitter, `KitGrowingFronts`, runs in `KitVillageBuildings.build` where `KitRoomProjections` runs today (after roofs are joined and towers proposed, before projections and facade bays). It turns a per-house/per-face odds decision into a monotone cumulative lean profile per face, written through the existing `storey.wall_offsets` / `storey.projections` contract and closed by a generalised `BuildingKitAssembler._emit_projected_front` that picks baked depth variants of `frontage.floor` / `frontage.return` / `frontage.return_beam`. Seven guardrails each withdraw a step (never a house or town); the top storey follows its roof (gable end shifts with a clipped filler, or the lean is capped under the measured eave).

**Tech Stack:** Godot 4.5, typed GDScript, GUT, environment bake (`tools/environment_bake/environment_bake.gd`, `bake_town_frame_variants.gd`), town fingerprint harness, `kit_town_review` / `building_gallery` render harnesses.

**Spec:** `docs/superpowers/specs/2026-10-08-growing-upper-floors-design.md`

## Global Constraints

- Worktree `/Users/ryko/.codex/worktrees/77a0/story`, branch `town-redesign`; never touch `/Users/ryko/story`; never run the `godot-test` alias.
- `godot` below means `/Applications/Godot.app/Contents/MacOS/Godot`; always add `--log-file /tmp/<name>.log`, redirect stdout to a file and check the exit code; ignore unrelated Godot processes; run `godot --headless --path . --import` after adding a `class_name` or new assets.
- Knob `growing_house_chance`: CHANCE, 0.3 small → 0.45 large, spread 0.1 (shipped in Task 7; Tasks 1–6 keep it at 0).
- Knob `growth_street_face_chance`: CHANCE, 0.85.
- Knob `growth_other_face_chance`: CHANCE, 0.1.
- Knob `growth_step`: WEIGHTS, {0.25 native m (0.5 m world): 1, 0.5 native m (1.0 m world): 1}.
- Knob `growth_max_lean`: RANGE_FLOAT, 1.0–1.5 native m (2–3 m world).
- Knob `lane_sky_gap`: RANGE_FLOAT, 0.75 native m (1.5 m world).
- Knob `growth_gable_front_boost`: RANGE_FLOAT, 2.0.
- Units: kit native metres (module 2.0 m, storey 3.0 m; world = native x 2); steps are sub-module offsets applied through `wall_offsets` (module fractions).
- Byte-identical at `growing_house_chance = 0`: fingerprint `baseline.json` MATCH and `test_town_old_look` pass after every task 1–6.
- Guardrails withdraw the offending step, never a house or a town.
- No runtime asset scaling: every cumulative depth is a baked `frontage.*` variant (manifest clip), two step sizes, at most four steps.
- Worker purity: fitters return plain dictionaries and mutate only `BuildingMass` data; no nodes or server resources; catalog and roof geometry are read-only inputs.
- Deterministic per-key rolls: house rolls keyed by `mass.stable_id`, face rolls by the face key, houses processed in `KitVillageBuildings.sorted_ids` order; one knob never moves another knob's draw.
- Every commit message ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; commit only this task's paths (`git commit -m "..." -- <paths>`; another agent commits roof work in this worktree concurrently); never `git add -f`, never commit `.superpowers/`.

Command forms used below:

- Focused test: `godot --headless --path . --log-file /tmp/t.log -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/<file>.gd -gexit > /tmp/t.out 2>&1; echo EXIT $?; tail -30 /tmp/t.out`
- Fingerprint gate: `godot --headless --path . --log-file /tmp/fp.log -s res://tests/harness/town_fingerprint.gd -- --out /tmp/fp.json --compare res://docs/qa/2026-10-07-town-odds/fingerprint/baseline.json > /tmp/fp.out 2>&1; echo EXIT $?; grep FINGERPRINT_ /tmp/fp.out` must print `FINGERPRINT_MATCH` (harness flags: `--towns`, `--out`, `--compare`, `--parts source,payload,error`, `--odds name=value`, `--old-look`).
- Growth-on smoke (Tasks 3–6): the same command with `--odds growing_house_chance=1 --out /tmp/fp_on.json` and no `--compare`; `grep -c FINGERPRINT_NO_TOWN /tmp/fp.out` must print 0.

## Review Focus

1. Two growing houses facing across a lane: the later house in sorted order must see the earlier one's accepted lean and withdraw exactly its own failing step, so every facing pair keeps at least `lane_sky_gap`; the earlier house is unchanged. In a one-cell (2.0 native m) lane the facing 1.0 m verges already meet, so gable ends cannot move there and growth comes from eave faces. Test: Task 4 `test_sky_gap_withdraws_only_the_later_houses_failing_step`, Task 6 `test_facing_growing_houses_across_one_cell_lane`.
2. A storey that cannot hold even the inherited lean (a skywalk/balcony portal on the face, a neighbour at a face end, a set-back storey above): the face cap must drop to what that storey can hold and re-cap the storeys below, so no storey is ever inward of the one below (no exposed ledge); the house and town still build. Tests: Task 4 `test_skywalk_portal_face_never_leans_but_other_face_does`, `test_neighbour_at_a_face_end_keeps_the_face_flush`, Task 6 `test_top_storey_smaller_than_the_one_below`.
3. Eave-to-street top storey: a leaned wall head must stay under the cornice's measured top surface; the face cap becomes the quantised eave allowance, lower storeys still step up to it, never past it. Test: Task 5 `test_eave_face_top_lean_stays_under_the_measured_cornice`.
4. A gable end that cannot shift cleanly (open/junction end, verge or clip key, tight eave, end dormer, capped roof family, filler asset without baked roof geometry): the chain-end storey takes no lean, so a gable is never stranded behind a leaned wall. Test: Task 5 `test_unshiftable_gable_end_keeps_the_face_flush`.
5. The zero path: at `growing_house_chance = 0` no designer rng draw is skipped or added, no storey/wing key is written, projections/bays see exactly today's inputs, and changing one growth knob never moves another knob's draw or another house's roll. Tests: Task 1 `test_house_roll_is_keyed_by_house_and_untouched_by_other_growth_knobs`, `test_build_marks_no_house_growing_at_the_default`, and the fingerprint gate after every task.

---

### Task 1: Growth knobs, `BuildingMass.grows`, and the town character in the kit

**Files:**
- Modify: `terrain/villages/town_odds.tres` (header `load_steps` line 1; insert 7 sub-resources before `[resource]` ~line 192; extend the `knobs` array, last line)
- Modify: `scripts/terrain/features/villages/kit/BuildingMass.gd` (add `grows` after `ground_band`, ~line 31)
- Create: `scripts/terrain/features/villages/kit/KitGrowingFronts.gd`
- Modify: `scripts/terrain/features/villages/kit/KitVillageBuildings.gd` (`build` lines 56–95: character + callables; `_mass_for` signature line 1425 and context block lines 1540–1554)
- Create: `tests/fixtures/growing_house.gd`
- Test: `tests/test_growing_floors_knobs.gd`

**Interfaces:**
- Consumes: `TownCharacter.of(profile: WarrenVillageScaleProfile, seed: int) -> TownCharacter`, `TownCharacter.chance(name: StringName, key: Variant, boost := 1.0) -> bool`, `TownCharacter.pick(name, key) -> StringName`, `TownCharacter.value(name) -> float`, `WarrenMazeSourcePlan.scale_profile`, `.world_seed`, `BuildingKitAssembler.boundary_runs(cells: Dictionary, exposed: Callable) -> Array[Dictionary]`, `BuildingKitAssembler.exposure_for(mass, floor_band: int, bands: int, blocked: Callable) -> Callable`, `BuildingKitAssembler._inside_cell(dir: int, line: int, along: int) -> Vector2i`.
- Produces: `BuildingMass.grows: bool`; `KitGrowingFronts` constants `HOUSE_KNOB`, `STREET_FACE_KNOB`, `OTHER_FACE_KNOB`, `STEP_KNOB`, `CAP_KNOB`, `GAP_KNOB`, `BOOST_KNOB`, `STEP_SIZES: Array[float]`, `MAX_STEPS: int`, `LEAN_DEPTHS: Array[float]`, `FRONT_ROLES: Array[StringName]`; `KitGrowingFronts.ground_index(mass: BuildingMass) -> int`, `face_chains(mass: BuildingMass, solid: Callable, street: Callable) -> Array[Dictionary]` (each `{dir:int, line:int, start:int, end:int, storeys:Array[int], street:bool, key:String}`), `house_eligible(mass, solid: Callable, street: Callable) -> bool`, `house_grows(character: TownCharacter, mass, solid: Callable, street: Callable) -> bool`; callables `solid(own: StringName, cell: Vector2i, band: int) -> bool` (another building's solid) and `street(cell: Vector2i, band: int) -> bool` (grid PUBLIC_AIR); designer context keys `grows: bool`, `gable_boost: float` (read from Task 3 / Task 5).

- [ ] **Step 0: Confirm the gate reference before any edit.** Run the fingerprint gate on the untouched tree. If it prints `FINGERPRINT_DIFFERS` (the concurrent roof work may have moved payloads), regenerate the reference from the untouched tree with `--out /tmp/growth_fp_ref.json` and no `--compare`, record that in `.superpowers/sdd/2026-10-08-growing-floors/ledger.md`, and use `--compare /tmp/growth_fp_ref.json` as "the fingerprint gate" for Tasks 1–6.

- [ ] **Step 1: Write the fixture and the failing test.**

`tests/fixtures/growing_house.gd` (Task 3 adds `build`):

```gdscript
extends RefCounted
## Growing-floor fixtures. A house under test fronts a one-cell lane at z = -1
## (native z -2..0); an optional facing house stands across it. Native frame:
## module 2 m, band 1.5 m, storey = 2 bands.

## A plain timber house of `storeys` identical floors with a ground door on `door_dir`.
static func house(id: StringName, rect: Rect2i, storeys: int, door_dir: int) -> BuildingMass:
	var mass := BuildingMass.new()
	mass.stable_id = id
	mass.seed = hash(String(id))
	mass.ground_band = 0
	for s in storeys:
		mass.add_storey(s * 2, BuildingMass.rect_cells(rect), BuildingMass.MATERIAL_TIMBER)
	var row := rect.position.y if door_dir == 3 else rect.end.y - 1
	mass.storeys[0].openings[BuildingMass.edge_key(Vector2i(rect.position.x + 1, row), door_dir)] = \
		BuildingMass.OPENING_DOOR
	return mass


## Builtin odds with growth forced on for the house under test; `step` fixes growth_step.
static func character(values: Dictionary = {}, step := &"0.25") -> TownCharacter:
	var fixed := {&"growing_house_chance": 1.0, &"growth_street_face_chance": 1.0,
		&"growth_other_face_chance": 0.0, &"growth_max_lean": 1.0, &"lane_sky_gap": 0.75}
	fixed.merge(values, true)
	var c := TownCharacter.draw(TownOddsProgram.builtin().with_overrides(fixed), 1, 0.5)
	c.values[&"growth_step"] = {&"0.25": 1.0 if step == &"0.25" else 0.0,
		&"0.5": 1.0 if step == &"0.5" else 0.0}
	return c


static func street(cell: Vector2i, band: int) -> bool:
	return cell.y == -1 and band <= 1


static func nothing_solid(_own: StringName, _cell: Vector2i, _band: int) -> bool:
	return false
```

`tests/test_growing_floors_knobs.gd`:

```gdscript
extends GutTest
const GROWTH := preload("res://scripts/terrain/features/villages/kit/KitGrowingFronts.gd")
const FIXTURE := preload("res://tests/fixtures/growing_house.gd")
const KNOBS: Array[StringName] = [&"growing_house_chance", &"growth_street_face_chance",
	&"growth_other_face_chance", &"growth_step", &"growth_max_lean", &"lane_sky_gap",
	&"growth_gable_front_boost"]


func test_growth_knobs_are_in_the_table_and_off_by_default() -> void:
	var program := TownOddsProgram.builtin()
	assert_eq(program.errors.size(), 0, str(program.errors))
	for name: StringName in KNOBS:
		assert_true(program.knobs.has(name), String(name))
	for size: float in [0.0, 1.0]:
		var c := TownCharacter.draw(program, 53, size)
		assert_eq(c.value(GROWTH.HOUSE_KNOB), 0.0)
		assert_eq(c.weights(GROWTH.STEP_KNOB).keys(), [&"0.25", &"0.5"])
		assert_almost_eq(c.value(GROWTH.STREET_FACE_KNOB), 0.85, 1e-6)
		assert_almost_eq(c.value(GROWTH.OTHER_FACE_KNOB), 0.1, 1e-6)
		assert_almost_eq(c.value(GROWTH.GAP_KNOB), 0.75, 1e-6)
		assert_almost_eq(c.value(GROWTH.BOOST_KNOB), 2.0, 1e-6)
	assert_almost_eq(TownCharacter.draw(program, 53, 0.0).value(GROWTH.CAP_KNOB), 1.0, 1e-6)
	assert_almost_eq(TownCharacter.draw(program, 53, 1.0).value(GROWTH.CAP_KNOB), 1.5, 1e-6)


func test_eligible_house_needs_two_upper_storeys_on_a_street_face() -> void:
	var street := Callable(FIXTURE, "street")
	var none := Callable(FIXTURE, "nothing_solid")
	assert_true(GROWTH.house_eligible(FIXTURE.house(&"kit.a", Rect2i(0, 0, 3, 2), 3, 3), none, street))
	assert_false(GROWTH.house_eligible(FIXTURE.house(&"kit.b", Rect2i(0, 0, 3, 2), 2, 3), none, street),
		"one storey above the ground cannot grow")
	assert_false(GROWTH.house_eligible(FIXTURE.house(&"kit.c", Rect2i(0, 2, 3, 2), 3, 3), none, street),
		"no face fronts the lane")


func test_house_roll_is_keyed_by_house_and_untouched_by_other_growth_knobs() -> void:
	var a := TownCharacter.draw(TownOddsProgram.builtin().with_overrides(
		{&"growing_house_chance": 0.4}), 9, 0.5)
	var b := TownCharacter.draw(TownOddsProgram.builtin().with_overrides(
		{&"growing_house_chance": 0.4, &"growth_max_lean": 1.5, &"lane_sky_gap": 1.2,
		&"growth_street_face_chance": 0.1}), 9, 0.5)
	var grown := 0
	for i in 300:
		var key := "kit.house.%03d" % i
		assert_eq(a.chance(GROWTH.HOUSE_KNOB, key), b.chance(GROWTH.HOUSE_KNOB, key), key)
		assert_eq(a.pick(GROWTH.STEP_KNOB, key), b.pick(GROWTH.STEP_KNOB, key), key)
		if a.chance(GROWTH.HOUSE_KNOB, key):
			grown += 1
	assert_between(grown, 90, 150)


func test_zero_chance_never_grows_and_one_always_does() -> void:
	var street := Callable(FIXTURE, "street")
	var none := Callable(FIXTURE, "nothing_solid")
	var mass := FIXTURE.house(&"kit.a", Rect2i(0, 0, 3, 2), 4, 3)
	var off := TownCharacter.draw(TownOddsProgram.builtin(), 3, 0.5)
	var on := TownCharacter.draw(TownOddsProgram.builtin().with_overrides(
		{&"growing_house_chance": 1.0}), 3, 0.5)
	assert_false(GROWTH.house_grows(off, mass, none, street))
	assert_true(GROWTH.house_grows(on, mass, none, street))
	assert_false(GROWTH.house_grows(null, mass, none, street))


func test_build_marks_no_house_growing_at_the_default() -> void:
	for chance: float in [0.0, 1.0]:
		var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
		program.town_odds = program.town_odds.with_overrides({&"growing_house_chance": chance})
		var growing := 0
		for town: String in ["7:compact", "103:standard"]:
			var parts := town.split(":")
			var spatial := WarrenVolumetricSolver.generate(int(parts[0]), {}, program,
				WarrenVillageScaleProfile.for_id(StringName(parts[1])))
			assert_not_null(spatial, town)
			var built := KitVillageBuildings.build(spatial, spatial.compiled_fabric_cache(),
				SuntailBuildingKit.create())
			growing += (built.houses as Array).filter(func(m: BuildingMass) -> bool: return m.grows).size()
		if chance == 0.0:
			assert_eq(growing, 0)
		else:
			assert_gt(growing, 0, "the two towns have eligible street houses")
```

- [ ] **Step 2: Run it and see it fail.** `godot --headless --path . --log-file /tmp/t.log -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/test_growing_floors_knobs.gd -gexit` — expected failure: parse error "Could not preload resource ... KitGrowingFronts.gd" (file missing) and unknown knobs.

- [ ] **Step 3: Add the knobs.** In `terrain/villages/town_odds.tres` raise `load_steps=20` to `load_steps=27`, add before `[resource]`:

```
[sub_resource type="Resource" id="growing_house_chance"]
script = ExtResource("2")
name = &"growing_house_chance"
kind = 0
at_small = 0.0
at_large = 0.0
spread = 0.0
clamp_min = 0.0
clamp_max = 1.0
notes = "Growing upper floors (Oct 8) task 1: share of eligible houses (2+ storeys above the ground storey on a street face) whose upper storeys lean over the lane, rolled per house stable id (KitGrowingFronts.house_grows). A growing house takes no inset jetties. 0 = today. Shipped default (task 7): 0.3 small -> 0.45 large, spread 0.1."

[sub_resource type="Resource" id="growth_street_face_chance"]
script = ExtResource("2")
name = &"growth_street_face_chance"
kind = 0
at_small = 0.85
at_large = 0.85
spread = 0.0
clamp_min = 0.0
clamp_max = 1.0
notes = "Growing upper floors (Oct 8) task 1: per street-facing exposed face of a growing house (every edge's outward column is public air at some band from the ground up to the storey), rolled per face key."

[sub_resource type="Resource" id="growth_other_face_chance"]
script = ExtResource("2")
name = &"growth_other_face_chance"
kind = 0
at_small = 0.1
at_large = 0.1
spread = 0.0
clamp_min = 0.0
clamp_max = 1.0
notes = "Growing upper floors (Oct 8) task 1: per other exposed face of a growing house, rolled per face key."

[sub_resource type="Resource" id="growth_step"]
script = ExtResource("2")
name = &"growth_step"
kind = 3
at_small = 0.0
at_large = 0.0
spread = 0.0
clamp_min = 0.0
clamp_max = 1.0
options = PackedStringArray("0.25", "0.5")
weights_small = PackedFloat32Array(1, 1)
weights_large = PackedFloat32Array(1, 1)
notes = "Growing upper floors (Oct 8) task 1: lean added per storey, native m (0.25 = 0.5 m world, 0.5 = 1.0 m world), picked per house. Options must be KitGrowingFronts.STEP_SIZES (the baked family)."

[sub_resource type="Resource" id="growth_max_lean"]
script = ExtResource("2")
name = &"growth_max_lean"
kind = 1
at_small = 1.0
at_large = 1.5
spread = 0.0
clamp_min = 0.0
clamp_max = 2.0
notes = "Growing upper floors (Oct 8) task 1: total lean cap of the top storey, native m (1.0-1.5 = 2-3 m world), floored to whole steps and to KitGrowingFronts.MAX_STEPS (4)."

[sub_resource type="Resource" id="lane_sky_gap"]
script = ExtResource("2")
name = &"lane_sky_gap"
kind = 1
at_small = 0.75
at_large = 0.75
spread = 0.0
clamp_min = 0.25
clamp_max = 4.0
notes = "Growing upper floors (Oct 8) task 1: minimum open gap between a leaned face and the facing facade (including its accepted lean), native m (0.75 = 1.5 m world). Guardrail 2."

[sub_resource type="Resource" id="growth_gable_front_boost"]
script = ExtResource("2")
name = &"growth_gable_front_boost"
kind = 1
at_small = 2.0
at_large = 2.0
spread = 0.0
clamp_min = 1.0
clamp_max = 8.0
notes = "Growing upper floors (Oct 8) task 5: multiplies the gable-to-street share in BuildingDesigner._square_axis for growing houses (a gable end can follow the lean; an eave caps it)."
```

and append `, SubResource("growing_house_chance"), SubResource("growth_street_face_chance"), SubResource("growth_other_face_chance"), SubResource("growth_step"), SubResource("growth_max_lean"), SubResource("lane_sky_gap"), SubResource("growth_gable_front_boost")` inside the `knobs = Array[Resource]([...])` list.

- [ ] **Step 4: Add `BuildingMass.grows`.** After `var ground_band := 0`:

```gdscript
## Set by the town adapter (KitGrowingFronts.house_grows): this house's upper
## storeys may lean over its street faces. False everywhere else.
var grows := false
```

- [ ] **Step 5: Create `KitGrowingFronts.gd` with selection only** (fitting arrives in Task 3):

```gdscript
extends RefCounted
## Growing upper floors (spec docs/superpowers/specs/2026-10-08-growing-upper-floors-design.md).
## On chosen street faces of a growing house each storey above the ground storey
## leans one baked step further over the lane, closed like a room projection.
## Pure: reads masses, kits, catalog and callables; writes only BuildingMass data.

const HOUSE_KNOB := &"growing_house_chance"
const STREET_FACE_KNOB := &"growth_street_face_chance"
const OTHER_FACE_KNOB := &"growth_other_face_chance"
const STEP_KNOB := &"growth_step"
const CAP_KNOB := &"growth_max_lean"
const GAP_KNOB := &"lane_sky_gap"
const BOOST_KNOB := &"growth_gable_front_boost"
## Baked step sizes and the cumulative depths 1-4 steps of each produce (native m).
const STEP_SIZES: Array[float] = [0.25, 0.5]
const MAX_STEPS := 4
const LEAN_DEPTHS: Array[float] = [0.25, 0.5, 0.75, 1.0, 1.5, 2.0]
const FRONT_ROLES: Array[StringName] = [&"frontage.floor", &"frontage.return", &"frontage.return_beam"]


static func _own(mass: BuildingMass) -> StringName:
	return StringName(String(mass.stable_id).trim_prefix("kit."))


static func _storey_at(mass: BuildingMass, floor_band: int) -> Dictionary:
	for storey: Dictionary in mass.storeys:
		if int(storey.floor_band) == floor_band:
			return storey
	return {}


## Index of the storey standing at the house datum (else the lowest storey).
static func ground_index(mass: BuildingMass) -> int:
	for index in mass.storeys.size():
		if int(mass.storeys[index].floor_band) == mass.ground_band:
			return index
	return 0 if not mass.storeys.is_empty() else -1


static func _run_key(run: Dictionary) -> String:
	return "%d:%d:%d:%d" % [int(run.dir), int(run.line), int(run.start), int(run.end)]


## Exposed boundary runs of one storey, keyed by _run_key.
static func _exposed_runs(mass: BuildingMass, storey: Dictionary, solid: Callable) -> Dictionary:
	var own := _own(mass)
	var blocked := func(cell: Vector2i, band: int) -> bool: return bool(solid.call(own, cell, band))
	var out := {}
	for run: Dictionary in BuildingKitAssembler.boundary_runs(storey.cells,
			BuildingKitAssembler.exposure_for(mass, int(storey.floor_band),
				int(storey.get("bands", 2)), blocked)):
		if bool(run.exposed):
			out[_run_key(run)] = run
	return out


## A face fronts a street when every edge's outward column is public air at
## some band from the house datum up to the storey (lane, stair, court, plaza).
## Upper bands over a lane are not guaranteed PUBLIC_AIR, so this is a column test.
static func _is_street(mass: BuildingMass, run: Dictionary, floor_band: int, street: Callable) -> bool:
	var dir := int(run.dir)
	for along in range(int(run.start), int(run.end)):
		var outward: Vector2i = BuildingKitAssembler._inside_cell(dir, int(run.line), along) \
			+ BuildingMass.DIRS[dir]
		var open := false
		for band in range(mass.ground_band, floor_band + 2):
			open = open or bool(street.call(outward, band))
		if not open:
			return false
	return true


## Faces that can grow: an exposed run on the first storey above the ground
## storey, identical (guardrail 5, per edge run) on the storey below, followed
## upward while each next storey repeats the same run. Sorted by key.
static func face_chains(mass: BuildingMass, solid: Callable, street: Callable) -> Array[Dictionary]:
	var chains: Array[Dictionary] = []
	var g := ground_index(mass)
	if g < 0:
		return chains
	var ground: Dictionary = mass.storeys[g]
	var first := _storey_at(mass, int(ground.floor_band) + int(ground.get("bands", 2)))
	if first.is_empty():
		return chains
	var below := _exposed_runs(mass, ground, solid)
	for key: String in _exposed_runs(mass, first, solid):
		if not below.has(key):
			continue
		var run: Dictionary = below[key]
		var storeys: Array[int] = [mass.storeys.find(first)]
		var band := int(first.floor_band) + int(first.get("bands", 2))
		while true:
			var upper := _storey_at(mass, band)
			if upper.is_empty() or not _exposed_runs(mass, upper, solid).has(key):
				break
			storeys.append(mass.storeys.find(upper))
			band += int(upper.get("bands", 2))
		chains.append({"dir": int(run.dir), "line": int(run.line), "start": int(run.start),
			"end": int(run.end), "storeys": storeys,
			"street": _is_street(mass, run, int(first.floor_band), street),
			"key": "%s|%s" % [mass.stable_id, key]})
	chains.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.key) < String(b.key))
	return chains


## 2+ storeys above the ground storey on one street face.
static func house_eligible(mass: BuildingMass, solid: Callable, street: Callable) -> bool:
	if String(mass.stable_id).contains("wall-room"):
		return false
	for chain: Dictionary in face_chains(mass, solid, street):
		if bool(chain.street) and (chain.storeys as Array).size() >= 2:
			return true
	return false


## Eligibility first, so an ineligible house consumes no roll (rolls are keyed,
## so this changes nothing for other houses either).
static func house_grows(character: TownCharacter, mass: BuildingMass, solid: Callable,
		street: Callable) -> bool:
	if character == null or not house_eligible(mass, solid, street):
		return false
	return character.chance(HOUSE_KNOB, String(mass.stable_id))
```

- [ ] **Step 6: Thread the character through `KitVillageBuildings`.** At the top of the file add `const GROWTH := preload("res://scripts/terrain/features/villages/kit/KitGrowingFronts.gd")`. In `build`, before `var payload := ...` (line ~78):

```gdscript
	# Growing upper floors read the town's odds; a fixture without a source plan never grows.
	var growth_character: TownCharacter = null
	if spatial.source_volume != null:
		var growth_source := spatial.source_volume.mass_context.get(&"maze_source_plan") as WarrenMazeSourcePlan
		if growth_source != null and growth_source.scale_profile != null:
			growth_character = TownCharacter.of(growth_source.scale_profile, growth_source.world_seed)
	var growth_solid := func(own: StringName, cell: Vector2i, band: int) -> bool:
		return _solid_other(grid, owner_at, own, Vector3i(cell.x, band, cell.y))
	var growth_street := func(cell: Vector2i, band: int) -> bool:
		var at := Vector3i(cell.x, band, cell.y)
		return grid.contains(at) and grid.use_at(at) == WarrenSpatialGrid.Use.PUBLIC_AIR
	var growth_context := {} if growth_character == null else \
		{"character": growth_character, "solid": growth_solid, "street": growth_street}
```

Pass `growth_context` as a new last argument of the `_mass_for(...)` call in the house loop, add the parameter `growth: Dictionary = {}` to `_mass_for`, and directly before `designer.articulate(mass, context)`:

```gdscript
	if not growth.is_empty():
		mass.grows = GROWTH.house_grows(growth.character, mass, growth.solid, growth.street)
		if mass.grows:
			context["grows"] = true
			context["gable_boost"] = (growth.character as TownCharacter).value(GROWTH.BOOST_KNOB)
```

(`owner_at` is rebuilt after `merge_houses`, so the lambdas capture the final map; the designer ignores both context keys until Tasks 3 and 5.)

- [ ] **Step 7: Run the test to pass.** Same command as Step 2; expected `All tests passed` / 5 passing, EXIT 0. Run `godot --headless --path . --import` first if Godot reports the new preload as missing.

- [ ] **Step 8: Fingerprint gate.** Run the fingerprint gate; expect `FINGERPRINT_MATCH`. Run `tests/test_town_old_look.gd` with the focused-test command; expect pass.

- [ ] **Step 9: Commit.** `git add terrain/villages/town_odds.tres scripts/terrain/features/villages/kit/BuildingMass.gd scripts/terrain/features/villages/kit/KitGrowingFronts.gd scripts/terrain/features/villages/kit/KitVillageBuildings.gd tests/fixtures/growing_house.gd tests/test_growing_floors_knobs.gd` then `git commit -m "Towns: growing-floor knobs and per-house growth roll (off by default)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" -- <same paths>` (include any `.uid` files Godot created for the new scripts).

---

### Task 2: Baked lean-depth front family

**Files:**
- Create: `tools/environment_bake/export_growth_front_manifest.gd`
- Modify: `tools/environment_bake/manifests/town_room_fronts.json` (generated `assets` entries after line ~150)
- Modify: `scripts/terrain/features/villages/kit/SuntailBuildingKit.gd` (after the `frontage.` role loop, ~line 155)
- Modify: `scripts/terrain/features/villages/kit/BuildingKitAssembler.gd` (add `lean_suffix` near `yaw_for_dir`, ~line 127)
- Generated: `terrain/environment/catalog/descriptors/town_frontage_{floor,return,return_beam}_d*.tres` (+ `_finish_oak` / `_finish_walnut`), `terrain/environment/visuals/town_room_fronts/*`, `terrain/environment/meshes/...`, `terrain/environment/collisions/...`, `terrain/environment/catalog/index.tres`
- Test: `tests/test_growth_front_family.gd`

**Interfaces:**
- Consumes: `KitGrowingFronts.LEAN_DEPTHS`, `FRONT_ROLES`; manifest keys `source`, `pivot`, `clip_ranges`; `EnvironmentCatalog.has(id)`, `.descriptor(id).measured_aabb`, `.collision_piece_count`; `TownFramePalette.variant_id(id, finish)`.
- Produces: `BuildingKitAssembler.lean_suffix(depth: float) -> String` (`0.25 -> "d025"`); kit roles `frontage.floor.dNNN`, `frontage.return.dNNN`, `frontage.return_beam.dNNN` for every `LEAN_DEPTHS` value, assets `town.frontage.<part>.dNNN` plus walnut/oak finish variants.

Measured sources (headless probe, October 8): `Wall_Start_10x30_0.glb` x −1.0..0 (end finished at x = 0), `Wall_Start_20x30_0.glb` x −2.0..0, `Floor_2.glb` z −1.0..1.0, `Crossbar_2.glb` x −1.0..1.0. The existing 0.65 return (`pivot` −0.325, clip x ±0.325) keeps source x −0.65..0; the family follows the same rule with `pivot = -d/2`, clip ±d/2.

- [ ] **Step 1: Write the failing catalog test** `tests/test_growth_front_family.gd`:

```gdscript
extends GutTest
const GROWTH := preload("res://scripts/terrain/features/villages/kit/KitGrowingFronts.gd")
const PALETTE := preload("res://scripts/terrain/features/villages/kit/TownFramePalette.gd")


func test_lean_suffix_names_the_depth_in_centimetres() -> void:
	assert_eq(BuildingKitAssembler.lean_suffix(0.25), "d025")
	assert_eq(BuildingKitAssembler.lean_suffix(1.5), "d150")
	assert_eq(BuildingKitAssembler.lean_suffix(2.0), "d200")


func test_every_lean_depth_has_a_measured_floor_return_and_beam() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var kit := SuntailBuildingKit.create()
	for depth: float in GROWTH.LEAN_DEPTHS:
		var suffix := BuildingKitAssembler.lean_suffix(depth)
		for role: StringName in GROWTH.FRONT_ROLES:
			var variant := StringName("%s.%s" % [role, suffix])
			assert_true(kit.has_role(variant), String(variant))
			var id := kit.asset(variant)
			assert_true(catalog.has(id), String(id))
			for finish: StringName in [&"walnut", &"oak"]:
				assert_true(catalog.has(PALETTE.variant_id(id, finish)), "%s %s" % [id, finish])
			var box := catalog.descriptor(id).measured_aabb
			match role:
				&"frontage.floor":
					assert_almost_eq(box.size.z, depth, 0.001, String(id))
					assert_almost_eq(box.position.z, -depth * 0.5, 0.001, String(id))
					assert_gt(catalog.descriptor(id).collision_piece_count, 0, String(id))
				&"frontage.return":
					assert_almost_eq(box.size.x, depth, 0.001, String(id))
					assert_almost_eq(box.position.x, -depth * 0.5, 0.001, String(id))
					assert_almost_eq(box.size.y, 3.0, 0.001, String(id))
					assert_gt(catalog.descriptor(id).collision_piece_count, 0, String(id))
				&"frontage.return_beam":
					assert_almost_eq(box.size.x, depth, 0.001, String(id))


func test_existing_projection_fronts_are_unchanged() -> void:
	var catalog := EnvironmentCatalog.load_default()
	assert_eq(catalog.descriptor(&"town.frontage.return").measured_aabb,
		AABB(Vector3(-0.325, 0, -0.125), Vector3(0.65, 3, 0.25)))
	assert_eq(catalog.descriptor(&"town.frontage.floor").measured_aabb.size.z, 0.65)
	assert_almost_eq(catalog.descriptor(&"town.frontage.return_beam").measured_aabb.size.x, 0.65, 1e-6)
```

- [ ] **Step 2: Run it and see it fail.** Focused-test command with `test_growth_front_family.gd`; expected failures: `Invalid call. Nonexistent function 'lean_suffix'` and missing roles.

- [ ] **Step 3: Add `lean_suffix` to `BuildingKitAssembler`** (static, after `yaw_for_dir`):

```gdscript
## Name suffix of the baked front family for one cumulative lean, native m:
## 0.25 -> "d025" (`frontage.return.d025`).
static func lean_suffix(depth: float) -> String:
	return "d%03d" % roundi(depth * 100.0)
```

- [ ] **Step 4: Register the roles in `SuntailBuildingKit.create`** directly after the `for part: String in ["floor","return","return_beam"]` loop:

```gdscript
	# Growing upper floors: one baked floor strip, return and return beam per
	# cumulative lean (KitGrowingFronts.LEAN_DEPTHS), never a scaled piece.
	for depth: float in preload("res://scripts/terrain/features/villages/kit/KitGrowingFronts.gd").LEAN_DEPTHS:
		var suffix := BuildingKitAssembler.lean_suffix(depth)
		for part: String in ["floor", "return", "return_beam"]:
			r[StringName("frontage.%s.%s" % [part, suffix])] = [StringName("town.frontage.%s.%s" % [part, suffix])]
```

(`PureVillageBuildingKit.create` starts from `SuntailBuildingKit.create`, so Pure houses inherit them; `TownFramePalette.source_ids` reads `kit.all_asset_ids`, so the finish bake picks them up.)

- [ ] **Step 5: Write the manifest generator** `tools/environment_bake/export_growth_front_manifest.gd`:

```gdscript
extends SceneTree
## Adds the growing-floor depth family to town_room_fronts.json: one floor strip,
## return and return beam per cumulative lean (KitGrowingFronts.LEAN_DEPTHS).
## Each source is measured; a depth is cut from the narrowest source at least that
## wide (never scaled). Existing entries are kept; regenerated entries replaced.
## godot --headless --editor --path . -s res://tools/environment_bake/export_growth_front_manifest.gd
const MANIFEST := "res://tools/environment_bake/manifests/town_room_fronts.json"
const GROWTH := preload("res://scripts/terrain/features/villages/kit/KitGrowingFronts.gd")
const FLOOR := "res://assets/Raygeas/Models/Building_Modules/Indoor_Modules/Floor_2.glb"
const BEAM := "res://assets/Raygeas/Models/Building_Modules/Decor/Crossbar_2.glb"
## Pure Village wall starts, finished at x = 0 and extending toward -x.
const RETURNS: Array[String] = ["res://assets/PureVillage/Models/Architecture/Wall_Start_10x30_0.glb",
	"res://assets/PureVillage/Models/Architecture/Wall_Start_20x30_0.glb"]


func _init() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var template := {}
	var kept: Array = []
	var family := RegEx.create_from_string("\\.d\\d{3}$")
	for entry: Dictionary in manifest.assets:
		template[String(entry.id)] = entry
		if family.search(String(entry.id)) == null:
			kept.append(entry)
	for depth: float in GROWTH.LEAN_DEPTHS:
		var suffix := BuildingKitAssembler.lean_suffix(depth)
		var half := depth * 0.5
		kept.append(_entry(template["town.frontage.floor"], "town.frontage.floor." + suffix,
			FLOOR, "z", half, false))
		kept.append(_entry(template["town.frontage.return_beam"], "town.frontage.return_beam." + suffix,
			BEAM, "x", half, false))
		var source := ""
		for candidate: String in RETURNS:
			if source.is_empty() and _extent(candidate).size.x >= depth - 0.0001:
				source = candidate
		assert(not source.is_empty(), "no Pure Village wall start is %.2f m wide" % depth)
		kept.append(_entry(template["town.frontage.return"], "town.frontage.return." + suffix,
			source, "x", half, true))
	manifest.assets = kept
	var file := FileAccess.open(MANIFEST, FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "  ") + "\n")
	file.close()
	print("GROWTH_FRONTS ", GROWTH.LEAN_DEPTHS.size() * 3)
	quit()


## Copy budgets, tags and collision from the 0.65 m entry; clip only when the
## depth is narrower than the source (a full-width clip would remove nothing).
func _entry(template: Dictionary, id: String, source: String, axis: String, half: float,
		pivoted: bool) -> Dictionary:
	var entry := template.duplicate(true)
	entry.id = id
	entry.source = source
	var extent := _extent(source)
	var index := 0 if axis == "x" else 2
	var width := extent.size[index]
	entry.erase("clip_ranges")
	entry.erase("pivot")
	if pivoted:
		entry.pivot = [-half, 0.0, 0.0]
	if half * 2.0 < width - 0.0001:
		entry.clip_ranges = {axis: [-half, half]}
	return entry


func _extent(path: String) -> AABB:
	var root: Node3D = (load(path) as PackedScene).instantiate()
	get_root().add_child(root)
	var boxes: Array[AABB] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			boxes.append((node as MeshInstance3D).global_transform * (node as MeshInstance3D).get_aabb())
		stack.append_array(node.get_children())
	var box: AABB = boxes[0]
	for other: AABB in boxes:
		box = box.merge(other)
	root.free()
	return box
```

- [ ] **Step 6: Generate and bake.**
  1. `godot --headless --editor --path . --log-file /tmp/gm.log -s res://tools/environment_bake/export_growth_front_manifest.gd > /tmp/gm.out 2>&1; echo EXIT $?; grep GROWTH_FRONTS /tmp/gm.out` → `GROWTH_FRONTS 18`.
  2. `godot --headless --editor --path . --log-file /tmp/bake.log -s res://tools/environment_bake/environment_bake.gd -- --manifest res://tools/environment_bake/manifests/town_room_fronts.json > /tmp/bake.out 2>&1; echo EXIT $?` → EXIT 0, no `_fail` lines.
  3. `godot --headless --path . --log-file /tmp/fv.log -s res://tools/environment_bake/bake_town_frame_variants.gd > /tmp/fv.out 2>&1; grep FRAME_VARIANTS /tmp/fv.out`.
  4. `godot --headless --path . --import`.

- [ ] **Step 7: Run the test to pass.** Focused-test command; expected 3 passing.

- [ ] **Step 8: Visual check of every new piece.** `godot --path . --log-file /tmp/lineup.log -s res://tests/harness/environment_lineup.tscn -- --asset town.frontage.return.d150 --show-collision --collision-closeup` and the same for `.d025`, `.d200`, `town.frontage.floor.d100`, `town.frontage.return_beam.d075`: the return's finished plaster end sits at x = +d/2 (outer end), collision hugs the mesh. Save captures under `docs/qa/2026-10-08-growing-floors/bake/`.

- [ ] **Step 9: Fingerprint gate** → `FINGERPRINT_MATCH` (new roles and catalog entries place nothing yet).

- [ ] **Step 10: Commit** the generator, manifest, kit, assembler, test and every generated `terrain/environment/**` file the bake wrote (list them from `git status --short terrain/environment`): message "Towns: baked lean-depth front family for growing floors" + trailer, using `git commit -- <paths>`.

---

### Task 3: Growth planner and closing pieces

**Files:**
- Modify: `scripts/terrain/features/villages/kit/KitGrowingFronts.gd` (add `fit`, `_profile`, `_fits`, `_candidate`, `_commit`, `_edges`)
- Modify: `scripts/terrain/features/villages/kit/BuildingKitAssembler.gd` (`OFFSET_WALL_DROP` const; `_emit_inhabited_floor` lines 76–87; `_emit_projected_front` lines 90–111; `_assemble_storey` line 421; new `face_parts`, `_front_role`)
- Modify: `scripts/terrain/features/villages/kit/BuildingDesigner.gd` (`articulate` lines 80–95; `_assign_jetties` lines 113–150; porch canopy line ~1173)
- Modify: `scripts/terrain/features/villages/kit/KitRoomProjections.gd` (storey skip line 74; run loop line 87; commit lines 168–178)
- Modify: `scripts/terrain/features/villages/kit/KitTownFacadeBays.gd` (storey filter line 22; slot loop line 26)
- Modify: `scripts/terrain/features/villages/kit/KitVillageBuildings.gd` (call between the tower loop and `room_projections`, ~line 198; `ornament_clear` ~line 252; return dict line 306)
- Modify: `tests/fixtures/growing_house.gd` (add `build`)
- Test: `tests/test_growing_floors.gd`

**Interfaces:**
- Consumes: Task 1 `face_chains`, `ground_index`, knob constants; Task 2 `lean_suffix` and roles; `BuildingKitAssembler.storey_slots(storey, exposed) -> Array[Dictionary]`, `_emit`, `_emit_corner_post`, `yaw_for_dir`, `right_of`.
- Produces:
  - `KitGrowingFronts.fit(masses: Array[BuildingMass], kits: Dictionary, base: BuildingKit, catalog: EnvironmentCatalog, character: TownCharacter, air: Array[Dictionary], towers: Array[Dictionary], reserved: Callable, solid: Callable, street: Callable) -> Dictionary` returning `{"leans": Array[Dictionary], "registry": Dictionary}`; each lean `{host: StringName, dir: int, band: int, lean: float, base: float, edges: Array[Vector3i], bounds: AABB, chain: String}`; registry `Vector4i(cell.x, cell.z, dir, band) -> float`.
  - Storey keys written by growth: `wall_offsets[edge] = lean / module_width`, `projections` entry `{edges, centres, dir, depth: lean, base: lean_below, band, growth: true}`, `growth: Dictionary dir -> lean`.
  - `BuildingKitAssembler.OFFSET_WALL_DROP := 0.14`, `face_parts(mass: BuildingMass, index: int, projection: Dictionary) -> Array[Dictionary]`.
  - `BuildingDesigner` honours context `grows`: no inset storeys, no flush porch canopies (rng draws kept).
  - `KitVillageBuildings.build(...)` result gains `"growth": Array[Dictionary]` and `roof_audit["growth_faces"]: int`.

Profile rule (spec "Guardrails" preamble, with the ruling recorded in Self-Review): storey k (0 = first storey above the ground storey) wants `min((k+1)·step, cap)` where `cap = step · min(MAX_STEPS, floor(growth_max_lean / step))`; a failing step is withdrawn (cap := last accepted lean) and every storey above keeps that lean; if the storey cannot hold even that, the face cap drops one step and the face is re-fitted from the bottom, so leans never decrease upward.

- [ ] **Step 1: Extend the fixture** (`tests/fixtures/growing_house.gd`):

```gdscript
const GROWTH := preload("res://scripts/terrain/features/villages/kit/KitGrowingFronts.gd")


## {kit, front, back, masses, result, leans, parts, solid}. `front` (Rect2i(0,0,3,2),
## south face dir 3 on the lane) is the house under test; `back` faces it across
## a lane of `lane` cells (z -lane..-1) when options.facing. Options: storeys (4),
## roof_axis / back_roof_axis (1 = gable to the lane, 0 = eave), lane (1), facing,
## back_grows, character, air, towers, reserved, kit, extra (more masses),
## prepare (Callable(front) run before fitting), replace_front (a mass with its
## own roofs, id kit.fixture.front).
static func build(options: Dictionary = {}) -> Dictionary:
	var kit: BuildingKit = options.get("kit", SuntailBuildingKit.create())
	var storeys := int(options.get("storeys", 4))
	var lane := int(options.get("lane", 1))
	var front: BuildingMass = options.get("replace_front", null)
	if front == null:
		front = house(&"kit.fixture.front", Rect2i(0, 0, 3, 2), storeys, 3)
		var front_roof := front.add_roof(Rect2i(0, 0, 3, 2), int(options.get("roof_axis", 1)), storeys * 2, &"red")
		front_roof["union_index"] = 0
	front.grows = true
	if options.has("prepare"):
		(options.prepare as Callable).call(front)
	var masses: Array[BuildingMass] = []
	var back: BuildingMass = null
	if bool(options.get("facing", false)):
		var back_rect := Rect2i(0, -lane - 2, 3, 2)
		back = house(&"kit.fixture.back", back_rect, storeys, 1)
		var back_roof := back.add_roof(back_rect, int(options.get("back_roof_axis", 1)), storeys * 2, &"red")
		back_roof["union_index"] = 1
		back.grows = bool(options.get("back_grows", false))
		masses.append(back) # "kit.fixture.back" sorts before "kit.fixture.front"
	masses.append(front)
	for mass: BuildingMass in options.get("extra", []):
		masses.append(mass)
	var kits := {}
	for mass: BuildingMass in masses:
		kits[StringName(String(mass.stable_id).trim_prefix("kit."))] = kit
	var solid := func(own: StringName, cell: Vector2i, band: int) -> bool:
		for mass: BuildingMass in masses:
			if StringName(String(mass.stable_id).trim_prefix("kit.")) != own \
					and mass.cells_at_band(band).has(cell):
				return true
		return false
	var reserved: Callable = options.get("reserved",
		func(_own: StringName, _cell: Vector2i, _band: int) -> bool: return false)
	var street := func(cell: Vector2i, band: int) -> bool:
		return cell.y <= -1 and cell.y >= -lane and band <= 1
	var result := GROWTH.fit(masses, kits, kit, EnvironmentCatalog.load_default(),
		options.get("character", character()), options.get("air", [] as Array[Dictionary]),
		options.get("towers", [] as Array[Dictionary]), reserved, solid, street)
	var assembler := BuildingKitAssembler.new(kit)
	assembler.external_blocked = func(cell: Vector2i, band: int) -> bool:
		return solid.call(&"fixture.front", cell, band)
	return {"kit": kit, "front": front, "back": back, "masses": masses, "result": result,
		"leans": result.leans, "parts": assembler.assemble(front), "solid": solid}


## Lean of `mass` on face `dir` per storey index (0.0 where flush).
static func leans_on(mass: BuildingMass, dir: int) -> Array[float]:
	var out: Array[float] = []
	for storey: Dictionary in mass.storeys:
		out.append(float((storey.get("growth", {}) as Dictionary).get(dir, 0.0)))
	return out
```

(Task 5 adds a `roof_geometry` argument to the `GROWTH.fit` call above.)

- [ ] **Step 2: Write the failing test** `tests/test_growing_floors.gd`:

```gdscript
extends GutTest
const FIXTURE := preload("res://tests/fixtures/growing_house.gd")
const GROWTH := preload("res://scripts/terrain/features/villages/kit/KitGrowingFronts.gd")


func test_each_street_storey_leans_one_step_further() -> void:
	var f := FIXTURE.build()
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 0.25, 0.5, 0.75] as Array[float])
	assert_eq(FIXTURE.leans_on(f.front, 1), [0.0, 0.0, 0.0, 0.0] as Array[float],
		"the back face is not a street and other-face chance is 0")
	for index in range(1, 4):
		var lean := 0.25 * index
		for slot: Dictionary in BuildingKitAssembler.storey_slots(f.front.storeys[index]):
			if int(slot.dir) == 3:
				assert_almost_eq(float(slot.centre.y), -lean / 2.0, 1e-5, "offset in module units")
			else:
				assert_eq(float(slot.wall_offset), 0.0, "other faces stay on the lot line")
	assert_false(f.front.storeys[0].has("wall_offsets"), "the ground storey keeps the lane's width")


func test_cap_floors_to_whole_steps() -> void:
	var f := FIXTURE.build({"storeys": 5, "character": FIXTURE.character({&"growth_max_lean": 0.9})})
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 0.25, 0.5, 0.75, 0.75] as Array[float])
	var g := FIXTURE.build({"storeys": 5, "character": FIXTURE.character({&"growth_max_lean": 1.5}, &"0.5")})
	assert_eq(FIXTURE.leans_on(g.front, 3), [0.0, 0.5, 1.0, 1.5, 1.5] as Array[float])


func test_every_step_is_closed_by_floor_beam_returns_and_brackets() -> void:
	var f := FIXTURE.build()
	var catalog := EnvironmentCatalog.load_default()
	for index in range(1, 4):
		var lean := 0.25 * index
		var base := 0.25 * (index - 1)
		var suffix := BuildingKitAssembler.lean_suffix(lean)
		var y0 := float(f.front.storeys[index].floor_band) * 1.5
		var floors := 0
		var returns := 0
		var beams := 0
		var brackets := 0
		for part: Dictionary in f.parts:
			var box: AABB = part.transform * catalog.descriptor(part.asset_id).measured_aabb
			if box.position.y < y0 - 1.0 or box.position.y > y0 + 2.9:
				continue
			if part.role == StringName("frontage.floor." + suffix):
				floors += 1
				assert_almost_eq(box.position.z, -lean, 0.001)
				assert_almost_eq(box.end.z, 0.0, 0.001, "the strip meets the original room line")
			elif part.role == StringName("frontage.return." + suffix):
				returns += 1
				assert_almost_eq(box.position.z, -lean, 0.001)
				assert_almost_eq(box.end.z, 0.0, 0.001)
			elif part.role == StringName("frontage.return_beam." + suffix):
				beams += 1
			elif part.role == &"bracket.small" and box.end.y < y0 + 0.01:
				brackets += 1
				assert_almost_eq(box.end.z, 0.15 - base - 0.0727, 0.02,
					"brackets bear on the lower storey's (leaned) face")
		assert_eq(floors, 6, "floor and ceiling strip under each of 3 bays")
		assert_eq(returns, 2, "both side returns closed")
		assert_eq(beams, 4, "two return beams per side")
		assert_eq(brackets, 4, "a bracket at every module joint")


func test_growth_result_lists_each_leaned_storey() -> void:
	var f := FIXTURE.build()
	assert_eq(f.leans.size(), 3)
	for lean: Dictionary in f.leans:
		assert_eq(int(lean.dir), 3)
		assert_true((lean.bounds as AABB).has_volume())
	assert_almost_eq(float(f.result.registry[Vector4i(1, 0, 3, 4)]), 0.5, 1e-6)


func test_growing_house_takes_no_jetty_and_no_flush_canopy_but_keeps_its_rolls() -> void:
	var kit := SuntailBuildingKit.create()
	var found := false
	for seed_value in 60:
		var plain := FIXTURE.house(StringName("kit.j%d" % seed_value), Rect2i(0, 0, 4, 3), 3, 3)
		var grown := FIXTURE.house(StringName("kit.j%d" % seed_value), Rect2i(0, 0, 4, 3), 3, 3)
		BuildingDesigner.new(kit).articulate(plain, {"terrain_storey": 0})
		BuildingDesigner.new(kit).articulate(grown, {"terrain_storey": 0, "grows": true})
		if not plain.storeys.any(func(s: Dictionary) -> bool: return bool(s.inset)):
			continue
		found = true
		assert_false(grown.storeys.any(func(s: Dictionary) -> bool: return bool(s.inset)))
		assert_eq(grown.storeys[1].tint, plain.storeys[1].tint, "finish roll unchanged")
		assert_eq(grown.roofs.size(), plain.roofs.size(), "roof design unchanged")
		assert_false(grown.decor.any(func(d: Dictionary) -> bool:
			return d.kind == &"awning" and not bool(d.get("sheltered", false))))
	assert_true(found, "some seed jetties the plain house")


func test_projections_and_bays_skip_leaning_faces() -> void:
	var f := FIXTURE.build()
	var masses: Array[BuildingMass] = [f.front]
	var kits := {&"fixture.front": f.kit}
	var none := func(_own: StringName, _cell: Vector2i, _band: int) -> bool: return false
	var projections := preload("res://scripts/terrain/features/villages/kit/KitRoomProjections.gd").fit(
		masses, kits, f.kit, EnvironmentCatalog.load_default(), [], [], none, func(_o: StringName, _c: Vector2i, _b: int) -> bool: return true)
	for projection: Dictionary in projections:
		assert_ne(int(projection.dir), 3)
		assert_ne(int(projection.dir) % 2, 0, "no perpendicular front on a leaning storey")
	var bays := preload("res://scripts/terrain/features/villages/kit/KitTownFacadeBays.gd").fit(
		masses, kits, f.kit, EnvironmentCatalog.load_default(), [], [], none)
	for bay: Dictionary in bays:
		assert_ne((bay.edge as Vector3i).z, 3)
```

- [ ] **Step 3: Run it and see it fail.** Focused-test command with `test_growing_floors.gd`; expected failure: `Invalid call. Nonexistent function 'fit' in base 'GDScript'`.

- [ ] **Step 4: Generalise the assembler.** In `BuildingKitAssembler.gd`:

```gdscript
## A leaned or projected storey's walls stand this far below its floor so the
## panels overlap the jetty beam (shared by growth guardrails).
const OFFSET_WALL_DROP := 0.14
```

Replace `var wall_y := y - (0.14 if ...)` in `_assemble_storey` with `var wall_y := y - (OFFSET_WALL_DROP if float(slot.get("wall_offset",0.0))>0.0 else 0.0)`. Replace the projection part of `_emit_inhabited_floor` and the whole `_emit_projected_front` with:

```gdscript
func _emit_inhabited_floor(ctx: Dictionary, storey: Dictionary) -> void:
	if bool(storey.get("retaining",false)) or bool(storey.get("fortified",false)):
		return
	var y := float(storey.floor_band)*kit.band_height()
	for cell: Vector2i in storey.cells:
		_emit(ctx,&"deck.board",Vector2(cell)+Vector2(0.5,0.5),y,0.0)
	_emit_front_floors(ctx,storey)


func _emit_front_floors(ctx: Dictionary, storey: Dictionary) -> void:
	var y := float(storey.floor_band)*kit.band_height()
	for projection:Dictionary in storey.get("projections",[]):
		var dir:=int(projection.dir)
		var out:=Vector2(BuildingMass.DIRS[dir])
		for centre:Vector2 in projection.centres:
			_emit(ctx,_front_role(&"frontage.floor",projection),centre+out*float(projection.depth)*.5/kit.module_width,y,yaw_for_dir(dir))


## Growth fronts use the baked piece for their cumulative depth.
func _front_role(role: StringName, projection: Dictionary) -> StringName:
	if not bool(projection.get("growth", false)):
		return role
	return StringName("%s.%s" % [role, lean_suffix(float(projection.depth))])


func _emit_projected_front(ctx:Dictionary,storey:Dictionary)->void:
	var y:=float(storey.floor_band)*kit.band_height()
	for projection:Dictionary in storey.get("projections",[]):
		var dir:=int(projection.dir)
		var depth:=float(projection.depth)
		# A growing storey's brackets bear on the leaned face of the storey below.
		var base:=float(projection.get("base",0.0))
		var out:=Vector2(BuildingMass.DIRS[dir])
		var right:=Vector2(right_of(dir))
		var centres:Array=projection.centres
		for centre:Vector2 in centres:
			_emit(ctx,_front_role(&"frontage.floor",projection),centre+out*depth*.5/kit.module_width,y+kit.storey_height-.12772,yaw_for_dir(dir))
			_emit(ctx,&"trim.floor_beam",centre+out*depth/kit.module_width,y,yaw_for_dir(dir))
		for side:int in [-1,1]:
			var centre:Vector2=centres.front() if side<0 else centres.back()
			var at:=centre+right*.5*side+out*depth*.5/kit.module_width
			var yaw:=yaw_for_dir(dir)+PI*.5*side
			_emit(ctx,_front_role(&"frontage.return",projection),at,y,yaw,0,Transform3D.IDENTITY,storey.get("tint",Color.WHITE))
			_emit(ctx,_front_role(&"frontage.return_beam",projection),at,y,yaw)
			_emit(ctx,_front_role(&"frontage.return_beam",projection),at,y+kit.storey_height-.143,yaw)
		if depth<=base+.001:
			continue # a held storey adds no overhang: nothing to bracket
		var lift:=out*.15/kit.module_width if base==0.0 else out*(.15-base)/kit.module_width
		for joint in range(centres.size()+1):
			var at:Vector2=centres.front()+right*(joint-.5)-lift
			_emit(ctx,&"bracket.small",at,y-.706295,yaw_for_dir(dir))


## The pieces one candidate front adds (its moved wall slots, corner post,
## floor/ceiling strips, beams, returns, brackets), for fitters to test before
## committing. The storey itself is not changed.
func face_parts(mass: BuildingMass, index: int, projection: Dictionary) -> Array[Dictionary]:
	var storey: Dictionary = mass.storeys[index]
	var probe := storey.duplicate()
	var offsets: Dictionary = (storey.get("wall_offsets", {}) as Dictionary).duplicate()
	var edges := {}
	for edge: Vector3i in projection.edges:
		offsets[edge] = float(projection.depth) / kit.module_width
		edges[edge] = true
	probe["wall_offsets"] = offsets
	probe["projections"] = [projection]
	var out: Array[Dictionary] = []
	var ctx := {"mass": mass, "out": out, "serial": 0}
	var y := float(probe.floor_band) * kit.band_height()
	var bands := int(probe.get("bands", 2))
	for slot: Dictionary in storey_slots(probe, _edge_exposure(mass, int(probe.floor_band), bands)):
		if not edges.has(slot.edge):
			continue
		var kind := StringName(probe.openings.get(slot.edge, probe.default_opening))
		var role := StringName("wall.%s.%s" % [probe.material, kind])
		if not kit.has_role(role):
			role = StringName("wall.%s.window" % probe.material)
		_emit(ctx, role, slot.centre, y - OFFSET_WALL_DROP, yaw_for_dir(int(slot.dir)))
		_emit_corner_post(ctx, slot, y - OFFSET_WALL_DROP, bands, kit.wall_face)
	_emit_front_floors(ctx, probe)
	_emit_projected_front(ctx, probe)
	return out
```

(At zero growth `base` is 0 and `lift` is the original `out*.15/kit.module_width`, so every existing placement is bit-identical.)

- [ ] **Step 5: Designer: a growing house takes no jetty and no flush porch canopy.** In `articulate`, read `var grows := bool(context.get("grows", false))` and pass it: `_assign_jetties(mass, terrain_storey, rng, grows)`. In `_assign_jetties` add the parameter `grows := false` and replace the last line with:

```gdscript
		# Growth replaces the single jetty on a growing house (inset is storey-wide);
		# the roll is still drawn so every later choice of the house is unchanged.
		var jetty := rng.randf() < chance
		storey.inset = jetty and not grows
```

In `_assign_dressing` (porch canopy, ~line 1173) change `and _awning_room(slot, int(storey.floor_band)):` to `and _awning_room(slot, int(storey.floor_band)) and not bool(context.get("grows", false)):` — the `rng.randf() < 0.9` term before it is still evaluated, so the roll sequence is unchanged.

- [ ] **Step 6: Implement fitting in `KitGrowingFronts.gd`** (append):

```gdscript
const CLEARANCE := preload("res://scripts/terrain/features/villages/kit/KitPublicClearance.gd")


static func _edges(chain: Dictionary) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var dir := int(chain.dir)
	for along in range(int(chain.start), int(chain.end)):
		out.append(BuildingMass.edge_key(BuildingKitAssembler._inside_cell(dir, int(chain.line), along), dir))
	return out


## Leans every growing house in `masses` (already in sorted id order). Returns
## {leans, registry}: one entry per leaned storey face, and the accepted lean per
## Vector4i(cell.x, cell.z, dir, band) for facing-gap checks by later fitters.
static func fit(masses: Array[BuildingMass], kits: Dictionary, base: BuildingKit,
		catalog: EnvironmentCatalog, character: TownCharacter, air: Array[Dictionary],
		towers: Array[Dictionary], reserved: Callable, solid: Callable,
		street: Callable) -> Dictionary:
	var leans: Array[Dictionary] = []
	var ctx := {"catalog": catalog, "air": air, "towers": towers, "reserved": reserved,
		"solid": solid, "registry": {}, "obstacles": [], "gap": 0.0, "kit": base}
	if character == null or not masses.any(func(m: BuildingMass) -> bool: return m.grows):
		return {"leans": leans, "registry": ctx.registry}
	ctx.gap = character.value(GAP_KNOB)
	for mass: BuildingMass in masses:
		if not mass.grows or not kits.has(_own(mass)):
			continue
		var kit: BuildingKit = kits[_own(mass)]
		ctx.kit = kit
		if not kit.has_role(StringName("frontage.return.%s" % BuildingKitAssembler.lean_suffix(STEP_SIZES[0]))):
			continue
		var step := float(String(character.pick(STEP_KNOB, String(mass.stable_id))))
		if not STEP_SIZES.has(step):
			continue
		var cap := step * float(mini(MAX_STEPS, floori(character.value(CAP_KNOB) / step + 0.0001)))
		for chain: Dictionary in face_chains(mass, solid, street):
			var knob := STREET_FACE_KNOB if bool(chain.street) else OTHER_FACE_KNOB
			if not character.chance(knob, String(chain.key)):
				continue
			_commit(mass, kit, chain, _profile(mass, chain, step, cap, ctx), ctx, leans)
	return {"leans": leans, "registry": ctx.registry}


## Monotone cumulative leans for one face (index k = k-th storey of the chain).
static func _profile(mass: BuildingMass, chain: Dictionary, step: float, cap: float,
		ctx: Dictionary) -> Array[float]:
	var n := (chain.storeys as Array).size()
	var leans: Array[float] = []
	leans.resize(n)
	leans.fill(0.0)
	var face_cap := cap
	var k := 0
	while k < n:
		var held := 0.0 if k == 0 else leans[k - 1]
		var want := minf(float(k + 1) * step, face_cap)
		if want > held and _fits(mass, chain, k, want, held, ctx):
			leans[k] = want
			k += 1
			continue
		# Withdraw this storey's step: it and every storey above keep the last accepted lean.
		face_cap = held
		if held <= 0.0:
			break
		if _fits(mass, chain, k, held, held, ctx):
			leans[k] = held
			k += 1
			continue
		# This storey cannot hold even the lean below it: an inward step would leave
		# an open ledge, so the whole face drops one step and is fitted again.
		face_cap = held - step
		leans.fill(0.0)
		k = 0
	return leans


## Guardrails for storey k of a face at `lean` over `base` (Tasks 4 and 5 extend).
static func _fits(mass: BuildingMass, chain: Dictionary, k: int, _lean: float, _base: float,
		_ctx: Dictionary) -> bool:
	var storey: Dictionary = mass.storeys[chain.storeys[k]]
	return storey.material == BuildingMass.MATERIAL_TIMBER and not bool(storey.get("inset", false)) \
		and not bool(storey.get("retaining", false)) and not bool(storey.get("fortified", false))


static func _candidate(mass: BuildingMass, kit: BuildingKit, chain: Dictionary, k: int,
		lean: float, base: float) -> Dictionary:
	var index: int = chain.storeys[k]
	var storey: Dictionary = mass.storeys[index]
	var dir := int(chain.dir)
	var edges := _edges(chain)
	var centres: Array[Vector2] = []
	for edge: Vector3i in edges:
		centres.append(Vector2(edge.x, edge.y) + Vector2.ONE * .5 + Vector2(BuildingMass.DIRS[dir]) * .5)
	var right := Vector2(BuildingKitAssembler.right_of(dir))
	centres.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.dot(right) < b.dot(right))
	var band := int(storey.floor_band)
	var projection := {"edges": edges, "centres": centres, "dir": dir, "depth": lean,
		"base": base, "band": band, "growth": true}
	var at: Vector2 = centres.front() * kit.module_width
	var pose := Transform3D(Basis(Vector3.UP, BuildingKitAssembler.yaw_for_dir(dir)),
		Vector3(at.x, band * kit.band_height(), at.y))
	var body := AABB(Vector3(-kit.module_width * .5, 0, 0),
		Vector3(centres.size() * kit.module_width, kit.storey_height, lean + kit.wall_face))
	return {"index": index, "projection": projection, "edges": edges, "centres": centres,
		"band": band, "pose": pose, "bounds": pose * body,
		"parts": BuildingKitAssembler.new(kit).face_parts(mass, index, projection)}


static func _commit(mass: BuildingMass, kit: BuildingKit, chain: Dictionary,
		profile: Array[float], ctx: Dictionary, out: Array[Dictionary]) -> void:
	var dir := int(chain.dir)
	for k in profile.size():
		var lean := profile[k]
		if lean <= 0.0:
			continue
		var base := 0.0 if k == 0 else profile[k - 1]
		var candidate := _candidate(mass, kit, chain, k, lean, base)
		var storey: Dictionary = mass.storeys[candidate.index]
		var offsets: Dictionary = storey.get("wall_offsets", {})
		for edge: Vector3i in candidate.edges:
			offsets[edge] = lean / kit.module_width
		storey["wall_offsets"] = offsets
		var fronts: Array = storey.get("projections", [])
		fronts.append(candidate.projection)
		storey["projections"] = fronts
		var leaning: Dictionary = storey.get("growth", {})
		leaning[dir] = lean
		storey["growth"] = leaning
		# Window boxes on the face move out with it (as projections do).
		for item: Dictionary in mass.decor:
			if not item.has("dir") or int(item.dir) != dir \
					or absf(float(item.get("y", -INF)) - candidate.band * kit.band_height()) > .01:
				continue
			if (candidate.centres as Array).has(item.centre):
				item.centre += Vector2(BuildingMass.DIRS[dir]) * lean / kit.module_width
				item.y = float(item.y) - BuildingKitAssembler.OFFSET_WALL_DROP
		for band in [candidate.band, candidate.band + 1]:
			for edge: Vector3i in candidate.edges:
				ctx.registry[Vector4i(edge.x, edge.y, dir, band)] = lean
		for part: Dictionary in candidate.parts:
			ctx.obstacles.append({"owner": &"", "role": String(part.role), "roof_index": -1,
				"bounds": part.transform * (ctx.catalog as EnvironmentCatalog).descriptor(part.asset_id).measured_aabb})
		out.append({"host": mass.stable_id, "dir": dir, "band": candidate.band, "lean": lean,
			"base": base, "edges": candidate.edges, "bounds": candidate.bounds, "chain": chain.key})
```

- [ ] **Step 7: Let projections and bays coexist.** In `KitRoomProjections.fit` replace `if storey.has("projections"):` with:

```gdscript
				if (storey.get("projections", []) as Array).any(
						func(p: Dictionary) -> bool: return not bool(p.get("growth", false))):
					continue
				var leaning: Dictionary = storey.get("growth", {})
```

inside the run loop after `var dir := int(run.dir)` add `if leaning.has(dir) or leaning.has((dir + 1) % 4) or leaning.has((dir + 3) % 4): continue` (a front on the leaning face or beside its returns), and replace the commit lines `storey["projections"] = [projection]` / `storey["wall_offsets"] = {}` with:

```gdscript
					var fronts: Array = storey.get("projections", [])
					fronts.append(projection)
					storey["projections"] = fronts
					var offsets: Dictionary = storey.get("wall_offsets", {})
					storey["wall_offsets"] = offsets
					for edge: Vector3i in edges:
						offsets[edge] = DEPTH / kit.module_width
```

In `KitTownFacadeBays.fit` replace `or not storey.get("projections",[]).is_empty(): continue` with `or (storey.get("projections",[]) as Array).any(func(p: Dictionary) -> bool: return not bool(p.get("growth",false))): continue`, and at the top of the slot loop add `if (storey.get("growth",{}) as Dictionary).has(int(slot.dir)): continue`.

- [ ] **Step 8: Wire `KitVillageBuildings.build`.** After the tower `for tower ...` loop and before `var room_projections := ...`:

```gdscript
	# Growing upper floors (after roof joins and towers, before projections and
	# bays): accepted leans cut roofs like any wall and are fitted around later.
	var growth := GROWTH.fit(masses,house_kits,kit,tower_catalog,growth_character,ornament_air,towers,
		func(own: StringName,cell: Vector2i,band: int) -> bool:
			var at := Vector3i(cell.x,band,cell.y)
			if passages.has(at) or podium.has(at): return true
			if owner_at.has(at): return owner_at[at] != own
			return grid.contains(at) and grid.use_at(at) in [WarrenSpatialGrid.Use.STRUCTURAL_VOLUME,
				WarrenSpatialGrid.Use.SERVICE_VOID,WarrenSpatialGrid.Use.PRIVATE_VOLUME],
		growth_solid,growth_street)
	for lean: Dictionary in growth.leans:
		walls.append(union_script.box_volume(lean.bounds))
```

In `assembler.ornament_clear` after the `room_projections` loop add `for lean: Dictionary in growth.leans: if lean.host != mass.stable_id and box.intersects(lean.bounds): return false`. Add `roof_audit["growth_faces"] = growth.leans.size()` and `"growth": growth.leans` to the returned dictionary.

- [ ] **Step 9: Run the test to pass.** Focused-test command for `test_growing_floors.gd` (6 passing); also re-run `test_october3_room_projections.gd` and `test_growing_floors_knobs.gd` (all pass).

- [ ] **Step 10: Fingerprint gate** → `FINGERPRINT_MATCH`; growth-on smoke → 0 `FINGERPRINT_NO_TOWN`; old-look test passes.

- [ ] **Step 11: Commit** the eight modified/created files: message "Towns: growing upper floors lean storey by storey (planner and closing pieces)" + trailer, `git commit -- <paths>`.

---

### Task 4: Guardrails 1–6

**Files:**
- Modify: `scripts/terrain/features/villages/kit/KitGrowingFronts.gd` (`fit` builds obstacles; `_fits` gains checks; new `gap_ok`, `_clear_of_air`, `_obstacles`, `_blocks`, `_clear_of_obstacles`, `_columns_free`, `_ends_clear`, `_no_portal`, `crown_index`)
- Modify: `scripts/terrain/features/villages/kit/KitRoomProjections.gd` (`fit` signature: `facing: Dictionary = {}`, `sky_gap := 0.0`; check before `var projection := {...}`)
- Modify: `scripts/terrain/features/villages/kit/KitVillageBuildings.gd` (pass `growth.registry`, `growth_character` gap to projections)
- Test: `tests/test_growing_floors_guardrails.gd`

**Interfaces:**
- Consumes: `KitPublicClearance.intersects_air(box: AABB, pose: Transform3D, volumes: Array[Dictionary]) -> bool`, Task 3 `_candidate`, `_edges`, registry.
- Produces: `KitGrowingFronts.gap_ok(registry: Dictionary, solid: Callable, own: StringName, edges: Array[Vector3i], dir: int, band: int, depth: float, kit: BuildingKit, gap: float) -> bool`; `KitGrowingFronts.crown_index(mass: BuildingMass, chain: Dictionary, k: int) -> int`; `const MAX_LANE_MODULES := 4`; `const OWN_OBSTACLES: Array[String]`; `KitRoomProjections.fit(..., facing: Dictionary = {}, sky_gap := 0.0)`.

Guardrail mapping: G1 `_clear_of_air` (every candidate part's measured AABB vs open public air and skywalk air); G2 `gap_ok`; G3 `_clear_of_obstacles` (other houses, skywalk/bridge-house masses, towers, balconies, own awnings/ivy/bays/rails/roofs other than the crown wing) and `_columns_free` (reserved grid claims); G4 `_ends_clear`; G5 is `face_chains` (Task 1, tested here); G6 `_no_portal`.

- [ ] **Step 1: Write the failing tests** `tests/test_growing_floors_guardrails.gd`:

```gdscript
extends GutTest
const FIXTURE := preload("res://tests/fixtures/growing_house.gd")
const UNION := preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd")


func _open(box: AABB) -> Dictionary:
	var volume := UNION.box_volume(box)
	volume["open"] = true
	return volume


func test_walking_air_withdraws_only_the_storey_it_reaches() -> void:
	# A stair landing's headroom in front of the second upper storey (band 4, y 6..9).
	var air: Array[Dictionary] = [_open(AABB(Vector3(-1, 6.2, -0.9), Vector3(8, 0.8, 0.45)))]
	var f := FIXTURE.build({"air": air})
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 0.25, 0.25, 0.25] as Array[float],
		"the 0.5 step is withdrawn; storeys above keep 0.25")


func test_sky_gap_withdraws_only_the_later_houses_failing_step() -> void:
	# A two-cell (4.0 native m) lane with a 2.75 m sky gap: the gap binds before the
	# facing gable verges (1.0 m each) can meet, so this isolates guardrail 2.
	var f := FIXTURE.build({"facing": true, "back_grows": true, "lane": 2,
		"character": FIXTURE.character({&"lane_sky_gap": 2.75})})
	assert_eq(FIXTURE.leans_on(f.back, 1), [0.0, 0.25, 0.5, 0.75] as Array[float],
		"the earlier house in sorted order sees an unleaned facade")
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 0.25, 0.5, 0.5] as Array[float],
		"4.0 - 0.75 - 0.75 < 2.75: only the top step is withdrawn")
	for index in range(1, 4):
		var gap := 4.0 - FIXTURE.leans_on(f.front, 3)[index] - FIXTURE.leans_on(f.back, 1)[index]
		assert_true(gap >= 2.75 - 1e-4, "storey %d keeps the lane's sky slot" % index)


func test_neighbouring_feature_withdraws_only_the_storey_it_reaches() -> void:
	var towers: Array[Dictionary] = [{"bounds": AABB(Vector3(-1, 6.2, -0.9), Vector3(8, 0.8, 0.45))}]
	var f := FIXTURE.build({"towers": towers})
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 0.25, 0.25, 0.25] as Array[float])


func test_reserved_column_keeps_the_face_flush() -> void:
	var f := FIXTURE.build({"reserved": func(_own: StringName, cell: Vector2i, band: int) -> bool:
		return cell.y == -1 and band >= 6})
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 0.0, 0.0, 0.0] as Array[float],
		"a storey that cannot lean at all pins the face (no inward ledge below it)")


func test_neighbour_at_a_face_end_keeps_the_face_flush() -> void:
	var neighbour := FIXTURE.house(&"kit.fixture.side", Rect2i(3, 0, 1, 2), 4, 0)
	var f := FIXTURE.build({"extra": [neighbour]})
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 0.0, 0.0, 0.0] as Array[float],
		"the face run is not wholly exposed, so its returns would meet the neighbour")


func test_footprint_change_ends_the_face_chain() -> void:
	var f := FIXTURE.build({"storeys": 4})
	var mass := FIXTURE.house(&"kit.fixture.step", Rect2i(0, 0, 3, 2), 4, 3)
	mass.storeys[2].cells.erase(Vector2i(2, 0))
	var chains := FIXTURE.GROWTH.face_chains(mass, Callable(FIXTURE, "nothing_solid"), Callable(FIXTURE, "street"))
	var south := chains.filter(func(c: Dictionary) -> bool: return int(c.dir) == 3 and int(c.line) == 0)
	assert_eq(south.size(), 1)
	assert_eq((south[0].storeys as Array).size(), 1, "storey 2's run differs from storey 1's")
	assert_eq(FIXTURE.leans_on(f.front, 3)[1], 0.25)


func test_skywalk_portal_face_never_leans_but_other_face_does() -> void:
	var character := FIXTURE.character({&"growth_other_face_chance": 1.0})
	var f := FIXTURE.build({"character": character, "prepare": func(front: BuildingMass) -> void:
		var edge := BuildingMass.edge_key(Vector2i(1, 0), 3)
		front.storeys[2].openings[edge] = BuildingMass.OPENING_DOOR
		front.storeys[2]["passage_edges"] = {edge: true}})
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 0.0, 0.0, 0.0] as Array[float])
	assert_gt(FIXTURE.leans_on(f.front, 1)[1], 0.0, "the opposite face still grows")
```

- [ ] **Step 2: Run and see them fail.** Focused-test command for `test_growing_floors_guardrails.gd`; expected: every lean list is the unguarded `[0.0, 0.25, 0.5, 0.75]` (6 failures; the footprint test passes).

- [ ] **Step 3: Implement the guardrails** (append to `KitGrowingFronts.gd`; `fit` sets `ctx.obstacles = _obstacles(masses, kits, base, catalog, towers)` right after `ctx.gap = ...`):

```gdscript
const MAX_LANE_MODULES := 4
## Own-house parts a lean must also clear (the rest of the house is its host).
const OWN_OBSTACLES: Array[String] = ["awning", "ivy.", "bay.", "deck.platform", "rail.",
	"chimney.", "roof.", "trim.ridge", "trim.barge", "gable."]


static func _obstacles(masses: Array[BuildingMass], kits: Dictionary, base: BuildingKit,
		catalog: EnvironmentCatalog, towers: Array[Dictionary]) -> Array:
	var out: Array = []
	for mass: BuildingMass in masses:
		for part: Dictionary in BuildingKitAssembler.new(kits.get(_own(mass), base)).assemble(mass):
			out.append({"owner": mass.stable_id, "role": String(part.role),
				"roof_index": int(part.get("roof_index", -1)),
				"bounds": part.transform * catalog.descriptor(part.asset_id).measured_aabb})
	for tower: Dictionary in towers:
		out.append({"owner": &"", "role": "tower", "roof_index": -1, "bounds": tower.bounds})
	return out


## union_index of the roof wing whose eave or gable closes this storey's face (else -1).
static func crown_index(mass: BuildingMass, chain: Dictionary, k: int) -> int:
	var storey: Dictionary = mass.storeys[chain.storeys[k]]
	var top := int(storey.floor_band) + int(storey.get("bands", 2))
	var dir := int(chain.dir)
	for wing: Dictionary in mass.roofs:
		if int(wing.eave_band) != top:
			continue
		var rect: Rect2i = wing.rect
		var boundary := rect.end.x if dir == 0 else rect.end.y if dir == 1 \
			else rect.position.x if dir == 2 else rect.position.y
		if boundary != int(chain.line):
			continue
		if _edges(chain).all(func(e: Vector3i) -> bool: return rect.has_point(Vector2i(e.x, e.y))):
			return int(wing.get("union_index", -1))
	return -1


static func _blocks(obstacle: Dictionary, mass: BuildingMass, crown: int) -> bool:
	if obstacle.owner != mass.stable_id:
		return true
	if crown >= 0 and int(obstacle.roof_index) == crown:
		return false
	for prefix: String in OWN_OBSTACLES:
		if String(obstacle.role).begins_with(prefix):
			return true
	return false


# G1: no leaned piece enters public walking air or a skywalk's air.
static func _clear_of_air(candidate: Dictionary, ctx: Dictionary) -> bool:
	for part: Dictionary in candidate.parts:
		if CLEARANCE.intersects_air((ctx.catalog as EnvironmentCatalog).descriptor(part.asset_id).measured_aabb,
				part.transform, ctx.air):
			return false
	return true


# G2: distance to the facing facade across the lane, minus both leans, keeps the sky gap.
static func gap_ok(registry: Dictionary, solid: Callable, own: StringName, edges: Array[Vector3i],
		dir: int, band: int, depth: float, kit: BuildingKit, gap: float) -> bool:
	var step: Vector2i = BuildingMass.DIRS[dir]
	var back := (dir + 2) % 4
	for edge: Vector3i in edges:
		var cell := Vector2i(edge.x, edge.y)
		for n in range(1, MAX_LANE_MODULES + 1):
			var column := cell + step * n
			if not (bool(solid.call(own, column, band)) or bool(solid.call(own, column, band + 1))):
				continue
			var facing := maxf(float(registry.get(Vector4i(column.x, column.y, back, band), 0.0)),
				float(registry.get(Vector4i(column.x, column.y, back, band + 1), 0.0)))
			if float(n - 1) * kit.module_width - depth - facing < gap - 0.0001:
				return false
			break
	return true


# G3: no other building, skywalk, tower, balcony, canopy or own roof/ornament.
static func _clear_of_obstacles(mass: BuildingMass, candidate: Dictionary, crown: int,
		ctx: Dictionary) -> bool:
	for part: Dictionary in candidate.parts:
		var box: AABB = (part.transform * (ctx.catalog as EnvironmentCatalog).descriptor(part.asset_id).measured_aabb).grow(-0.002)
		for obstacle: Dictionary in ctx.obstacles:
			if _blocks(obstacle, mass, crown) and box.intersects(obstacle.bounds):
				return false
	return true


# G3: reserved grid claims (structure, service voids, other owners, passages) beyond the face.
static func _columns_free(mass: BuildingMass, chain: Dictionary, k: int, ctx: Dictionary) -> bool:
	var storey: Dictionary = mass.storeys[chain.storeys[k]]
	var band := int(storey.floor_band)
	for edge: Vector3i in _edges(chain):
		var outward := Vector2i(edge.x, edge.y) + BuildingMass.DIRS[int(chain.dir)]
		for b in [band, band + 1]:
			if bool((ctx.reserved as Callable).call(_own(mass), outward, b)):
				return false
	return true


# G4: the run is a whole convex face with nothing beside or diagonally beyond its
# ends, and no perpendicular face of this storey leans (returns would collide).
static func _ends_clear(mass: BuildingMass, chain: Dictionary, k: int, ctx: Dictionary) -> bool:
	var storey: Dictionary = mass.storeys[chain.storeys[k]]
	var dir := int(chain.dir)
	var leaning: Dictionary = storey.get("growth", {})
	if leaning.has((dir + 1) % 4) or leaning.has((dir + 3) % 4):
		return false
	var whole := false
	for run: Dictionary in BuildingKitAssembler.boundary_runs(storey.cells):
		if int(run.dir) == dir and int(run.line) == int(chain.line) \
				and int(run.start) == int(chain.start) and int(run.end) == int(chain.end):
			whole = bool(run.start_convex) and bool(run.end_convex)
	if not whole:
		return false
	var own := _own(mass)
	var band := int(storey.floor_band)
	var along := Vector2i(0, 1) if dir % 2 == 0 else Vector2i(1, 0)
	for end: Array in [[int(chain.start), -1], [int(chain.end) - 1, 1]]:
		var side: Vector2i = BuildingKitAssembler._inside_cell(dir, int(chain.line), end[0]) + along * int(end[1])
		var diagonal: Vector2i = side + BuildingMass.DIRS[dir]
		for b in [band, band + 1]:
			if bool((ctx.solid as Callable).call(own, side, b)) \
					or bool((ctx.solid as Callable).call(own, diagonal, b)) \
					or mass.cells_at_band(b).has(diagonal):
				return false
	return true


# G6: a storey whose face carries a door, a skywalk/bridge-house portal or a
# passage, or whose wall bears a balcony's rakers (it or the storey above), stays put.
static func _no_portal(mass: BuildingMass, chain: Dictionary, k: int) -> bool:
	var storey: Dictionary = mass.storeys[chain.storeys[k]]
	if bool(storey.get("bears_balcony", false)):
		return false
	var above := _storey_at(mass, int(storey.floor_band) + int(storey.get("bands", 2)))
	if not above.is_empty() and bool(above.get("bears_balcony", false)):
		return false
	var passages: Dictionary = storey.get("passage_edges", {})
	for edge: Vector3i in _edges(chain):
		if passages.has(edge):
			return false
		if StringName(storey.openings.get(edge, storey.default_opening)) \
				in [BuildingMass.OPENING_DOOR, BuildingMass.OPENING_NONE]:
			return false
	return true
```

Replace `_fits` with:

```gdscript
static func _fits(mass: BuildingMass, chain: Dictionary, k: int, lean: float, base: float,
		ctx: Dictionary) -> bool:
	var storey: Dictionary = mass.storeys[chain.storeys[k]]
	if storey.material != BuildingMass.MATERIAL_TIMBER or bool(storey.get("inset", false)) \
			or bool(storey.get("retaining", false)) or bool(storey.get("fortified", false)):
		return false
	if not _no_portal(mass, chain, k) or not _ends_clear(mass, chain, k, ctx) \
			or not _columns_free(mass, chain, k, ctx):
		return false
	if not gap_ok(ctx.registry, ctx.solid, _own(mass), _edges(chain), int(chain.dir),
			int(storey.floor_band), lean, ctx.kit, float(ctx.gap)):
		return false
	var candidate := _candidate(mass, ctx.kit, chain, k, lean, base)
	return _clear_of_air(candidate, ctx) \
		and _clear_of_obstacles(mass, candidate, crown_index(mass, chain, k), ctx)
```

- [ ] **Step 4: Projections keep the sky gap to a leaned face.** Add parameters `facing: Dictionary = {}, sky_gap := 0.0` to `KitRoomProjections.fit` and, just before `var projection := {...}`:

```gdscript
					if not facing.is_empty() and solid.is_valid() and not preload(
							"res://scripts/terrain/features/villages/kit/KitGrowingFronts.gd").gap_ok(
							facing, func(o: StringName, c: Vector2i, b: int) -> bool: return bool(solid.call(o, c, b)),
							own, edges, dir, band, DEPTH, kit, sky_gap):
						continue
```

and in `KitVillageBuildings.build` pass `growth.registry` and `growth_character.value(GROWTH.GAP_KNOB) if growth_character != null else 0.0` as the two new trailing arguments of the `KitRoomProjections.fit` call (the registry is empty at zero growth, so projections are unchanged there).

- [ ] **Step 5: Run to pass.** `test_growing_floors_guardrails.gd` (7 passing), then `test_growing_floors.gd`, `test_growing_floors_knobs.gd`, `test_october3_room_projections.gd` (all pass).

- [ ] **Step 6: Fingerprint gate** → `FINGERPRINT_MATCH`; growth-on smoke → 0 `FINGERPRINT_NO_TOWN`.

- [ ] **Step 7: Commit** `KitGrowingFronts.gd`, `KitRoomProjections.gd`, `KitVillageBuildings.gd`, `tests/test_growing_floors_guardrails.gd`: message "Towns: growing-floor guardrails (air, sky gap, neighbours, exposed ends, footprint, portals)" + trailer.

---

### Task 5: Roofs follow the lean (gable shift, eave cap, gable-front boost)

**Files:**
- Modify: `scripts/terrain/features/villages/kit/KitGrowingFronts.gd` (`fit` gains `roof_geometry: Dictionary = {}`; `_fits` gains `_crown_allows`; `_commit` writes the wing lean; new `roof_geometry`, `crown_wing`, `eave_allowance`, `_gable_shift_ok`, constants `EAVE_MARGIN`, `EAVE_COVER`, `EAVE_SAMPLE`)
- Modify: `scripts/terrain/features/villages/kit/BuildingKitAssembler.gd` (`_assemble_roof` lines 847–955: record first part, call `_lean_roof_end`; new `roof_parts`, `_lean_roof_end`)
- Modify: `scripts/terrain/features/villages/kit/BuildingDesigner.gd` (member `gable_front_boost`; `articulate`; `_square_axis` lines 616–622)
- Modify: `scripts/terrain/features/villages/kit/KitVillageBuildings.gd` (pass `GROWTH.roof_geometry(house_kits.values() + [kit])` to `GROWTH.fit`)
- Modify: `tests/fixtures/growing_house.gd` (pass `GROWTH.roof_geometry([kit])`)
- Modify: `tests/harness/suntail/building_gallery.gd` (`--growth step:cap`, option parsing lines 18–30, per-mass loop lines 108–112)
- Test: `tests/test_growing_floors_roofs.gd`

**Interfaces:**
- Consumes: `KitRoofMeshUnion._load_geometry(kit, geometry: Dictionary, loaded: Dictionary)`, `KitRoofMeshUnion.clip_volumes(wing: Dictionary, kit) -> Array[Dictionary]`, `KitRoofMeshUnion.prepare(roofs, walls, kit) -> Dictionary`, `KitRoofMeshUnion.realize(placement, ctx) -> Dictionary`, `BuildingKitAssembler.tight_eave_sides(wing) -> int`, `kit.anchor(role)`, `kit.asset_anchor(id)`, catalog `measured_aabb`.
- Produces: wing keys `lean_min` / `lean_max: float` (native m); placement keys `lean_end: bool`, `lean_filler: bool`; `BuildingKitAssembler.roof_parts(mass, wing) -> Array[Dictionary]`; `KitGrowingFronts.roof_geometry(kits: Array) -> Dictionary`, `crown_wing(mass, chain, k) -> Dictionary`, `eave_allowance(kit, catalog, geometry, wing, side: int) -> float`; `BuildingDesigner.gable_front_boost: float`.

Measurements this task relies on (catalog, October 8): Suntail eave `suntail.roof.roof_1_cornice_red` measured_aabb z −2.111..0.986 (outer reach 0.986 m beyond the wall line), y −0.599..3.119 (the cornice dips 0.6 m below the wall head at its tip); Pure `pure_village.roof.eave` z −2.276..1.072. The allowance therefore scans the baked roof geometry for the cornice's top surface over a leaned wall head, bounded by the measured reach.

- [ ] **Step 1: Write the failing tests** `tests/test_growing_floors_roofs.gd`:

```gdscript
extends GutTest
const FIXTURE := preload("res://tests/fixtures/growing_house.gd")
const GROWTH := preload("res://scripts/terrain/features/villages/kit/KitGrowingFronts.gd")
const UNION := preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd")


func test_gable_end_moves_out_with_the_top_storey_and_the_gap_is_filled() -> void:
	var f := FIXTURE.build({"roof_axis": 1})
	var wing: Dictionary = f.front.roofs[0]
	assert_almost_eq(float(wing.get("lean_min", 0.0)), 0.75, 1e-6, "front face is the min end")
	var shifted := (f.parts as Array).filter(func(p: Dictionary) -> bool: return bool(p.get("lean_end", false)))
	var fillers := (f.parts as Array).filter(func(p: Dictionary) -> bool: return bool(p.get("lean_filler", false)))
	assert_gt(shifted.size(), 0)
	assert_gt(fillers.size(), 0)
	assert_true(shifted.any(func(p: Dictionary) -> bool: return String(p.role).begins_with("gable.")))
	# Fillers keep only the 0.75 m strip between the last middle piece and the moved end.
	var ctx := UNION.prepare(f.front.roofs, [], f.kit)
	var seam := (0.0 + 0.5) * 2.0
	for filler: Dictionary in fillers:
		var realized := UNION.realize(filler, ctx)
		assert_false(realized.is_empty(), "filler is trimmed by its clip volumes")
		for mesh: Dictionary in realized.meshes:
			for v: Vector3 in mesh.vertices:
				assert_between(v.z, seam - 0.75 - 0.002, seam + 0.002)


func test_eave_face_top_lean_stays_under_the_measured_cornice() -> void:
	var f := FIXTURE.build({"roof_axis": 0, "storeys": 4})
	var wing: Dictionary = f.front.roofs[0]
	var allowance := GROWTH.eave_allowance(f.kit, EnvironmentCatalog.load_default(),
		GROWTH.roof_geometry([f.kit]), wing, 1)
	assert_gt(allowance, 0.0)
	assert_lt(allowance, 0.986 - f.kit.wall_face)
	var leans := FIXTURE.leans_on(f.front, 3)
	var cap := 0.25 * floorf(allowance / 0.25 + 0.0001)
	assert_eq(leans, [0.0, minf(0.25, cap), minf(0.5, cap), minf(0.75, cap)] as Array[float],
		"the top storey is capped under the eave; lower storeys step up to that cap")
	for index in range(1, 3):
		assert_true(leans[index] <= leans[index + 1], "never an inward step")
	assert_false(wing.has("lean_min"), "an eave never moves")


func test_unshiftable_gable_end_keeps_the_face_flush() -> void:
	for blocker: String in ["open", "verge", "tight", "dormer", "caps"]:
		var options := {"roof_axis": 1, "prepare": func(front: BuildingMass) -> void:
			var wing: Dictionary = front.roofs[0]
			match blocker:
				"open": wing.open_min = true
				"verge": wing["verge_min"] = 0.3
				"tight": wing["tight_eave"] = true
				"dormer": (wing.dormers as Dictionary)[Vector2i(0, 0)] = true}
		if blocker == "caps":
			options["kit"] = preload("res://scripts/terrain/features/villages/kit/PureVillageBuildingKit.gd").roof_study(0)
		var f := FIXTURE.build(options)
		assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 0.0, 0.0, 0.0] as Array[float], blocker)


func test_growing_houses_prefer_a_gable_to_the_street() -> void:
	var kit := SuntailBuildingKit.create()
	var counts := [0, 0]
	for boosted in 2:
		for seed_value in 400:
			var mass := FIXTURE.house(StringName("kit.g%d" % seed_value), Rect2i(0, 0, 3, 3), 2, 3)
			var designer := BuildingDesigner.new(kit)
			designer.gable_front_boost = 2.0 if boosted == 1 else 1.0
			if designer._square_axis(mass) == 1:
				counts[boosted] += 1
	assert_between(counts[0], 150, 250, "even mix without growth")
	assert_eq(counts[1], 400, "share 0.5 x 2 = 1: every square growing crown faces the lane with a gable")


func test_articulate_reads_the_boost_only_for_growing_houses() -> void:
	var kit := SuntailBuildingKit.create()
	var designer := BuildingDesigner.new(kit)
	designer.articulate(FIXTURE.house(&"kit.b1", Rect2i(0, 0, 3, 3), 3, 3), {"gable_boost": 2.0})
	assert_eq(designer.gable_front_boost, 1.0)
	designer.articulate(FIXTURE.house(&"kit.b2", Rect2i(0, 0, 3, 3), 3, 3), {"grows": true, "gable_boost": 2.0})
	assert_eq(designer.gable_front_boost, 2.0)
```

- [ ] **Step 2: Run and see them fail.** Focused-test command for `test_growing_floors_roofs.gd`; expected: `Nonexistent function 'eave_allowance'` / `'roof_geometry'`, invalid member `gable_front_boost`.

- [ ] **Step 3: Assembler: a leaned gable end moves with a trimmed filler.** In `_assemble_roof` add `var first_part: int = (ctx.out as Array).size()` as its first line and, as its last lines, `if wing.has("lean_min") or wing.has("lean_max"): _lean_roof_end(ctx, wing, first_part, p_min, p_max)`. Add:

```gdscript
## One roof wing's placements (fitters test a candidate wing before committing it).
func roof_parts(mass: BuildingMass, wing: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_assemble_roof({"mass": mass, "out": out, "serial": 0}, wing)
	return out


## A growing house's top storey leans past its gable end: that end of the roof
## (gable, barge boards, end slope/eave/top pieces, ridge end) moves out with it,
## and a copy of each moved roof piece, clipped to the opened strip between the
## last middle piece and the moved end, closes the roof. KitGrowingFronts only
## sets lean_* on wings of kits without edge caps (pieces centred on modules).
func _lean_roof_end(ctx: Dictionary, wing: Dictionary, first_part: int, p_min: int, p_max: int) -> void:
	if kit.roof_edge_caps:
		return
	var axis := int(wing.axis)
	var coordinate := 0 if axis == 0 else 2
	var fillers: Array[Dictionary] = []
	for end: int in [0, 1]:
		var lean := float(wing.get("lean_max" if end == 1 else "lean_min", 0.0))
		if lean <= 0.0:
			continue
		var sign := 1.0 if end == 1 else -1.0
		var edge := float(p_max if end == 1 else p_min)
		var seam := edge - sign * 0.5
		var reach := lean / kit.module_width
		var offset := Vector3.ZERO
		offset[coordinate] = sign * lean
		for i in range(first_part, (ctx.out as Array).size()):
			var part: Dictionary = ctx.out[i]
			var role := String(part.role)
			if role.begins_with("chimney.") or role == "trim.ridge_peak":
				continue
			var original: Transform3D = part.transform
			if sign * (original.origin[coordinate] / kit.module_width - edge) < -0.25:
				continue
			part.transform = Transform3D(original.basis, original.origin + offset)
			part["lean_end"] = true
			if role.begins_with("roof.") or role.begins_with("trim.ridge"):
				var filler := part.duplicate()
				filler.transform = original
				filler.erase("lean_end")
				filler["lean_filler"] = true
				filler["stable_id"] = StringName("%s.lean" % String(part.stable_id))
				filler["clip_volumes"] = preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd").clip_volumes(
					{"axis": axis, "clip_min": minf(seam, seam + sign * reach),
						"clip_max": maxf(seam, seam + sign * reach)}, kit)
				fillers.append(filler)
	(ctx.out as Array).append_array(fillers)
```

- [ ] **Step 4: Guardrail 7 and the crown rule in `KitGrowingFronts.gd`** (add `roof_geometry: Dictionary = {}` as the last `fit` parameter and `"geometry": roof_geometry, "allowances": {}` to `ctx`):

```gdscript
const UNION := preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd")
## Keep the leaned wall face this far inside the eave's measured reach.
const EAVE_MARGIN := 0.1
## The cornice's top surface must stand this far above a leaned wall head.
const EAVE_COVER := 0.05
const EAVE_SAMPLE := 0.05


## Baked roof skins of every kit (read once on the caller's thread).
static func roof_geometry(kits: Array) -> Dictionary:
	var geometry := {}
	var loaded := {}
	for kit: BuildingKit in kits:
		UNION._load_geometry(kit, geometry, loaded)
	return geometry


## The roof wing closing this storey's crown over the face, or {} when the face is
## covered by a storey above (not the next leaned storey), a deck, or nothing.
static func crown_wing(mass: BuildingMass, chain: Dictionary, k: int) -> Dictionary:
	var storey: Dictionary = mass.storeys[chain.storeys[k]]
	var top := int(storey.floor_band) + int(storey.get("bands", 2))
	var above := mass.cells_at_band(top)
	for edge: Vector3i in _edges(chain):
		if above.has(Vector2i(edge.x, edge.y)):
			return {}
	var index := crown_index(mass, chain, k)
	for wing: Dictionary in mass.roofs:
		if int(wing.eave_band) == top and int(wing.get("union_index", -1)) == index:
			var rect: Rect2i = wing.rect
			if _edges(chain).all(func(e: Vector3i) -> bool: return rect.has_point(Vector2i(e.x, e.y))):
				return wing
	return {}


## How far (native m) a top storey may lean under this eave: the measured reach
## bounds the scan; the baked roof skin gives the cornice's top surface, which
## must cover the leaned wall head (lowered by OFFSET_WALL_DROP, posts +0.074).
static func eave_allowance(kit: BuildingKit, catalog: EnvironmentCatalog, geometry: Dictionary,
		wing: Dictionary, side: int) -> float:
	var colour := StringName(wing.colour)
	if bool(BuildingKitAssembler.tight_eave_sides(wing) & (1 << side)) \
			and kit.has_role(StringName("roof.%s.eave_tight" % colour)):
		return 0.0
	var role := StringName("roof.%s.eave" % colour)
	var id := kit.asset(role)
	var local := kit.anchor(role) * kit.asset_anchor(id)
	var reach: float = (local * catalog.descriptor(id).measured_aabb).end.z
	var surfaces: Array = geometry.get(id, geometry.get(kit.geometry_aliases.get(id, id), []))
	if surfaces.is_empty():
		return 0.0
	var head := -BuildingKitAssembler.OFFSET_WALL_DROP + 0.074 + EAVE_COVER
	var allowed := 0.0
	var z := kit.wall_face
	while z <= reach - EAVE_MARGIN:
		var top := -INF
		for surface: Dictionary in surfaces:
			for v: Vector3 in local * (surface.vertices as PackedVector3Array):
				if absf(v.z - z) <= EAVE_SAMPLE:
					top = maxf(top, v.y)
		if top < head:
			break
		allowed = z - kit.wall_face
		z += EAVE_SAMPLE
	return allowed


static func _gable_shift_ok(mass: BuildingMass, chain: Dictionary, wing: Dictionary,
		lean: float, ctx: Dictionary) -> bool:
	var kit: BuildingKit = ctx.kit
	if kit.roof_edge_caps:
		return false # capped families cannot be clipped cleanly (spec risk)
	var axis := int(wing.axis)
	var positive := int(chain.dir) < 2
	var rect: Rect2i = wing.rect
	if bool(wing.open_max if positive else wing.open_min) \
			or int(wing.extend_max if positive else wing.extend_min) != 0 \
			or BuildingKitAssembler.tight_eave_sides(wing) != 0:
		return false
	for key: String in (["verge_max", "clip_max"] if positive else ["verge_min", "clip_min"]):
		if wing.has(key):
			return false
	var end_slot := rect.end[axis] if positive else rect.position[axis]
	for side in 2:
		if (wing.dormers as Dictionary).has(Vector2i(side, end_slot)):
			return false
	if rect.position[1 - axis] != int(chain.start) or rect.end[1 - axis] != int(chain.end):
		return false
	var probe := wing.duplicate()
	probe["lean_max" if positive else "lean_min"] = lean
	for part: Dictionary in BuildingKitAssembler.new(kit).roof_parts(mass, probe):
		if bool(part.get("lean_filler", false)) and not (ctx.geometry as Dictionary).has(part.asset_id):
			return false # an unclippable filler would overlap the moved end
		if not bool(part.get("lean_end", false)) and not bool(part.get("lean_filler", false)):
			continue
		var local: AABB = (ctx.catalog as EnvironmentCatalog).descriptor(part.asset_id).measured_aabb
		if CLEARANCE.intersects_air(local, part.transform, ctx.air):
			return false
		var box: AABB = (part.transform * local).grow(-0.002)
		for obstacle: Dictionary in ctx.obstacles:
			if _blocks(obstacle, mass, int(wing.get("union_index", -1))) and box.intersects(obstacle.bounds):
				return false
	return true


# G7 and the crown rule: the last storey of a face must be closed above its lean.
static func _crown_allows(mass: BuildingMass, chain: Dictionary, k: int, lean: float,
		ctx: Dictionary) -> bool:
	if k < (chain.storeys as Array).size() - 1:
		return true # the next storey of the chain leans at least as far
	var wing := crown_wing(mass, chain, k)
	if wing.is_empty():
		return false
	var dir := int(chain.dir)
	if int(wing.axis) == dir % 2:
		return _gable_shift_ok(mass, chain, wing, lean, ctx)
	var side := 0 if dir < 2 else 1
	var key := "%s|%s|%d|%d" % [ctx.kit.kit_id, wing.colour, side, BuildingKitAssembler.tight_eave_sides(wing)]
	if not (ctx.allowances as Dictionary).has(key):
		ctx.allowances[key] = eave_allowance(ctx.kit, ctx.catalog, ctx.geometry, wing, side)
	return lean <= float(ctx.allowances[key]) + 0.0001
```

In `_fits`, return `... and _crown_allows(mass, chain, k, lean, ctx)` as the last term. In `_commit`, after the storey loop:

```gdscript
	var top := profile.size() - 1
	if top >= 0 and profile[top] > 0.0:
		var wing := crown_wing(mass, chain, top)
		if not wing.is_empty() and int(wing.axis) == dir % 2:
			wing["lean_max" if dir < 2 else "lean_min"] = profile[top]
```

Pass `GROWTH.roof_geometry([kit])` from the fixture and, in `KitVillageBuildings.build`, `GROWTH.roof_geometry(house_kits.values() + [kit])` only when `growth_character != null` (else `{}`), as the new last `fit` argument.

- [ ] **Step 5: Designer gable-front boost.** Add member `## Growing houses favour a gable to the street (growth_gable_front_boost).\nvar gable_front_boost := 1.0`; first line of `articulate`: `gable_front_boost = float(context.get("gable_boost", 1.0)) if bool(context.get("grows", false)) else 1.0`; in `_square_axis` replace the `share` line with:

```gdscript
	var share := minf(1.0, square_axis_weights[preferred] / (square_axis_weights.x + square_axis_weights.y) * gable_front_boost)
```

(×1.0 is exact, so non-growing houses are unchanged.)

- [ ] **Step 6: Run to pass.** `test_growing_floors_roofs.gd` (5 passing); re-run `test_growing_floors.gd` (gable-front fixture keeps `[0, .25, .5, .75]`), `test_growing_floors_guardrails.gd`, `test_roof_proportion.gd`, `test_october3_room_projections.gd`.

- [ ] **Step 7: Gallery flag and falsification render of both roof cases.** In `building_gallery.gd`: parse `"--growth": _growth = args[i + 1]` (`var _growth := ""`); before assembling each mass when `_growth` is set:

```gdscript
		if not _growth.is_empty():
			var setting := _growth.split(":")
			var mass := masses[i]
			for storey: Dictionary in mass.storeys:
				storey.inset = false # growing houses take no jetty
			mass.grows = true
			var character := TownCharacter.draw(TownOddsProgram.builtin().with_overrides({
				&"growing_house_chance": 1.0, &"growth_street_face_chance": 1.0,
				&"growth_other_face_chance": 1.0, &"growth_max_lean": float(setting[1])}), _seed, 0.5)
			character.values[&"growth_step"] = {StringName(setting[0]): 1.0}
			var footprint := mass.cells_at_band(mass.ground_band)
			var grow_masses: Array[BuildingMass] = [mass]
			preload("res://scripts/terrain/features/villages/kit/KitGrowingFronts.gd").fit(grow_masses,
				{StringName(String(mass.stable_id).trim_prefix("kit.")): kit}, kit, EnvironmentCatalog.load_default(),
				character, [], [], func(_o: StringName, _c: Vector2i, _b: int) -> bool: return false,
				func(_o: StringName, _c: Vector2i, _b: int) -> bool: return false,
				func(cell: Vector2i, band: int) -> bool: return band <= mass.ground_band + 1 and not footprint.has(cell),
				preload("res://scripts/terrain/features/villages/kit/KitGrowingFronts.gd").roof_geometry([kit]))
```

Then render `godot --path . --log-file /tmp/gal.log -s res://tests/harness/suntail/building_gallery.gd -- --set designer --count 9 --seed 4 --close --growth 0.25:1.0 --output docs/qa/2026-10-08-growing-floors/roofs` (GUI run) and inspect the `b*_c*` closes: no wall head above a cornice, no gap or doubled tiles at a moved gable end, barge boards on the moved gable.

- [ ] **Step 8: Fingerprint gate** → `FINGERPRINT_MATCH`; growth-on smoke → 0 `FINGERPRINT_NO_TOWN`.

- [ ] **Step 9: Commit** the five code files, the gallery harness, fixture and test: message "Towns: growing floors follow their roof (gable shift, eave cap, gable-front boost)" + trailer.

---

### Task 6: Corpus audit and edge cases

**Files:**
- Create: `tests/fixtures/growth_audit.gd`
- Create: `tests/harness/suntail/growth_corpus_audit.gd`
- Test: `tests/test_growing_floors_corpus.gd`, `tests/test_growing_floors_edges.gd`

**Interfaces:**
- Consumes: `KitVillageBuildings.build(...)` keys `growth`, `houses`, `house_kits`, `walls`, `masses`; `KitGrowingFronts.gap_ok`, `crown_wing`, `eave_allowance`, `roof_geometry`; `BuildingKitAssembler.face_parts`; `KitFloatingMassAudit.audit(spatial, fabric, masses).count`; `tests/fixtures/kit_roof_public_air_audit.gd`.audit(built, kit).intrusions.
- Produces: `growth_audit.audit(spatial: WarrenSpatialPlan, fabric: SettlementFabricPlan, built: Dictionary, kit: BuildingKit, character: TownCharacter) -> Dictionary` with int keys `faces, air_hits, gap_failures, open_returns, unfloored, beyond_roof, floating, roof_intrusions`; harness line `GROWTH_AUDIT <json>`.

- [ ] **Step 1: Write the audit fixture** `tests/fixtures/growth_audit.gd`:

```gdscript
extends RefCounted
## Growing-floor corpus audit (spec "Testing"): every count except `faces` must be 0.
const GROWTH := preload("res://scripts/terrain/features/villages/kit/KitGrowingFronts.gd")
const CLEARANCE := preload("res://scripts/terrain/features/villages/kit/KitPublicClearance.gd")


static func audit(spatial: WarrenSpatialPlan, fabric: SettlementFabricPlan, built: Dictionary,
		kit: BuildingKit, character: TownCharacter) -> Dictionary:
	var catalog := EnvironmentCatalog.load_default()
	var air: Array[Dictionary] = []
	for wall: Dictionary in built.walls:
		if bool(wall.get("open", false)):
			air.append(wall)
	var registry := {}
	for lean: Dictionary in built.growth:
		for band in [int(lean.band), int(lean.band) + 1]:
			for edge: Vector3i in lean.edges:
				registry[Vector4i(edge.x, edge.y, int(lean.dir), band)] = float(lean.lean)
	var houses: Array = built.houses
	var solid := func(own: StringName, cell: Vector2i, band: int) -> bool:
		for mass: BuildingMass in houses:
			if StringName(String(mass.stable_id).trim_prefix("kit.")) != own and mass.cells_at_band(band).has(cell):
				return true
		return false
	var geometry := GROWTH.roof_geometry((built.house_kits as Dictionary).values() + [kit])
	var out := {"faces": 0, "air_hits": 0, "gap_failures": 0, "open_returns": 0, "unfloored": 0,
		"beyond_roof": 0, "floating": 0, "roof_intrusions": 0}
	var gap := character.value(GROWTH.GAP_KNOB) if character != null else 0.75
	for mass: BuildingMass in houses:
		var own := StringName(String(mass.stable_id).trim_prefix("kit."))
		var own_kit: BuildingKit = (built.house_kits as Dictionary).get(own, kit)
		var assembler := BuildingKitAssembler.new(own_kit)
		for index in mass.storeys.size():
			var storey: Dictionary = mass.storeys[index]
			for projection: Dictionary in storey.get("projections", []):
				if not bool(projection.get("growth", false)):
					continue
				out.faces += 1
				var suffix := BuildingKitAssembler.lean_suffix(float(projection.depth))
				var parts := assembler.face_parts(mass, index, projection)
				var count := func(role: String) -> int:
					return parts.filter(func(p: Dictionary) -> bool: return String(p.role) == role).size()
				if count.call("frontage.return." + suffix) != 2:
					out.open_returns += 1
				if count.call("frontage.floor." + suffix) != 2 * (projection.centres as Array).size():
					out.unfloored += 1
				for part: Dictionary in parts:
					if CLEARANCE.intersects_air(catalog.descriptor(part.asset_id).measured_aabb, part.transform, air):
						out.air_hits += 1
				var edges: Array[Vector3i] = []
				edges.assign(projection.edges)
				if not GROWTH.gap_ok(registry, solid, own, edges, int(projection.dir), int(projection.band),
						float(projection.depth), own_kit, gap):
					out.gap_failures += 1
				if not _closed_above(mass, storey, projection, own_kit, catalog, geometry):
					out.beyond_roof += 1
	out.floating = KitFloatingMassAudit.audit(spatial, fabric, built.masses).count
	out.roof_intrusions = preload("res://tests/fixtures/kit_roof_public_air_audit.gd").audit(built, kit).intrusions
	return out


## The leaned strip is covered by the next storey's equal-or-larger lean, by a
## moved gable end of the same lean, or stays within the measured eave allowance.
static func _closed_above(mass: BuildingMass, storey: Dictionary, projection: Dictionary,
		kit: BuildingKit, catalog: EnvironmentCatalog, geometry: Dictionary) -> bool:
	var dir := int(projection.dir)
	var lean := float(projection.depth)
	var top := int(storey.floor_band) + int(storey.get("bands", 2))
	for upper: Dictionary in mass.storeys:
		if int(upper.floor_band) == top:
			return float((upper.get("growth", {}) as Dictionary).get(dir, 0.0)) >= lean - 0.0001
	for wing: Dictionary in mass.roofs:
		if int(wing.eave_band) != top:
			continue
		if int(wing.axis) == dir % 2:
			if absf(float(wing.get("lean_max" if dir < 2 else "lean_min", -1.0)) - lean) < 0.0001:
				return true
		elif lean <= GROWTH.eave_allowance(kit, catalog, geometry, wing, 0 if dir < 2 else 1) + 0.0001:
			return true
	return false
```

- [ ] **Step 2: Write the failing tests.** `tests/test_growing_floors_corpus.gd`:

```gdscript
extends GutTest
const AUDIT := preload("res://tests/fixtures/growth_audit.gd")


func test_growth_on_builds_clean_towns() -> void:
	var total := 0
	for town: String in ["7:compact", "103:standard"]:
		var parts := town.split(":")
		var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
		program.town_odds = program.town_odds.with_overrides({&"growing_house_chance": 1.0})
		var profile := WarrenVillageScaleProfile.for_id(StringName(parts[1]))
		var spatial := WarrenVolumetricSolver.generate(int(parts[0]), {}, program, profile)
		assert_not_null(spatial, town)
		if spatial == null:
			continue
		var fabric := spatial.compiled_fabric_cache()
		var kit := SuntailBuildingKit.create()
		var built := KitVillageBuildings.build(spatial, fabric, kit)
		assert_true(built.payload.validate(), town)
		var row := AUDIT.audit(spatial, fabric, built, kit, profile.character)
		total += int(row.faces)
		for key: String in ["air_hits", "gap_failures", "open_returns", "unfloored", "beyond_roof",
				"floating", "roof_intrusions"]:
			assert_eq(int(row[key]), 0, "%s %s" % [town, key])
	assert_gt(total, 0, "growth on leans at least one face")
```

`tests/test_growing_floors_edges.gd`:

```gdscript
extends GutTest
const FIXTURE := preload("res://tests/fixtures/growing_house.gd")
const GROWTH := preload("res://scripts/terrain/features/villages/kit/KitGrowingFronts.gd")


func test_house_exactly_at_the_lean_cap() -> void:
	var f := FIXTURE.build({"storeys": 5, "character": FIXTURE.character({&"growth_max_lean": 1.0})})
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 0.25, 0.5, 0.75, 1.0] as Array[float])
	assert_almost_eq(float(f.front.roofs[0].lean_min), 1.0, 1e-6)


func test_facing_growing_houses_across_one_cell_lane() -> void:
	# Eave fronts: both lean up to the measured eave cap and keep the sky slot.
	var f := FIXTURE.build({"facing": true, "back_grows": true, "roof_axis": 0, "back_roof_axis": 0})
	var allowance := GROWTH.eave_allowance(f.kit, EnvironmentCatalog.load_default(),
		GROWTH.roof_geometry([f.kit]), f.front.roofs[0], 1)
	var cap := 0.25 * floorf(allowance / 0.25 + 0.0001)
	assert_gt(cap, 0.0, "the measured Suntail cornice covers at least one 0.25 m step")
	var expected: Array[float] = [0.0, minf(0.25, cap), minf(0.5, cap), minf(0.75, cap)]
	assert_eq(FIXTURE.leans_on(f.back, 1), expected)
	assert_eq(FIXTURE.leans_on(f.front, 3), expected)
	for index in range(1, 4):
		assert_true(2.0 - expected[index] * 2.0 >= 0.75 - 1e-4)
	# Gable fronts: the facing verges (1.0 m each) already meet mid-lane, so no
	# gable end can move and, with no inward step allowed, both faces stay flush.
	var g := FIXTURE.build({"facing": true, "back_grows": true, "roof_axis": 1, "back_roof_axis": 1})
	assert_eq(FIXTURE.leans_on(g.back, 1), [0.0, 0.0, 0.0, 0.0] as Array[float])
	assert_eq(FIXTURE.leans_on(g.front, 3), [0.0, 0.0, 0.0, 0.0] as Array[float])


func test_leaning_face_next_to_a_skywalk_end() -> void:
	var character := FIXTURE.character({&"growth_other_face_chance": 1.0})
	var f := FIXTURE.build({"character": character, "prepare": func(front: BuildingMass) -> void:
		var edge := BuildingMass.edge_key(Vector2i(0, 1), 1)
		front.storeys[3].openings[edge] = BuildingMass.OPENING_DOOR
		front.storeys[3]["passage_edges"] = {edge: true}})
	assert_eq(FIXTURE.leans_on(f.front, 1), [0.0, 0.0, 0.0, 0.0] as Array[float], "skywalk face stays flush")
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 0.25, 0.5, 0.75] as Array[float], "street face unaffected")


func test_merged_compound_house_leans_per_edge_run() -> void:
	# An L of two lots: the front lot's face ends in a concave corner (stays flush);
	# the forward lot's face is whole and convex (grows).
	var mass := BuildingMass.new()
	mass.stable_id = &"kit.fixture.front"
	var cells := BuildingMass.rect_cells(Rect2i(0, 0, 3, 2))
	cells.merge(BuildingMass.rect_cells(Rect2i(3, -1, 3, 3)))
	for s in 4:
		mass.add_storey(s * 2, cells, BuildingMass.MATERIAL_TIMBER)
	mass.add_roof(Rect2i(0, 0, 3, 2), 1, 8, &"red")["union_index"] = 0
	mass.add_roof(Rect2i(3, -1, 3, 3), 1, 8, &"red")["union_index"] = 1
	var chains := GROWTH.face_chains(mass, Callable(FIXTURE, "nothing_solid"),
		func(cell: Vector2i, band: int) -> bool: return cell.y <= -1 and cell.y >= -2 and band <= 1)
	var south := chains.filter(func(c: Dictionary) -> bool: return int(c.dir) == 3)
	assert_eq(south.size(), 2, "one chain per edge run")
	var f := FIXTURE.build({"replace_front": mass, "lane": 2})
	assert_eq(float((f.front.storeys[1].get("growth", {}) as Dictionary).get(3, 0.0)), 0.25)
	for edge: Vector3i in (f.front.storeys[1].get("wall_offsets", {}) as Dictionary):
		assert_true(edge.x >= 3, "only the convex forward run leans")


func test_top_storey_smaller_than_the_one_below() -> void:
	var f := FIXTURE.build({"storeys": 4, "roof_axis": 0, "prepare": func(front: BuildingMass) -> void:
		front.storeys[3].cells = BuildingMass.rect_cells(Rect2i(0, 1, 3, 1))
		front.roofs.clear()
		var shed := front.add_roof(Rect2i(0, 0, 3, 1), 0, 6, &"red")
		shed["union_index"] = 0
		var top := front.add_roof(Rect2i(0, 1, 3, 1), 0, 8, &"red")
		top["union_index"] = 1})
	var leans := FIXTURE.leans_on(f.front, 3)
	assert_eq(leans[3], 0.0, "the set-back top storey is not part of the face")
	var allowance := GROWTH.eave_allowance(f.kit, EnvironmentCatalog.load_default(),
		GROWTH.roof_geometry([f.kit]), f.front.roofs[0], 1)
	assert_true(leans[2] <= allowance + 1e-4, "storey 2 ends the face under its own eave")
	assert_true(leans[1] <= leans[2] + 1e-4, "never an inward step")
```

- [ ] **Step 3: Run and see them fail / pass.** Run both focused tests; expected red where Tasks 3–5 still miss a case (record any red in the ledger and fix the owning function — `_profile`, `_ends_clear`, `crown_wing` — before continuing); the final state is all green.

- [ ] **Step 4: Write the corpus harness** `tests/harness/suntail/growth_corpus_audit.gd`:

```gdscript
extends SceneTree
## godot --headless --path . -s res://tests/harness/suntail/growth_corpus_audit.gd -- \
##   --towns 53:grand,31:large,... [--odds growing_house_chance=1] [--out res://.../audit.json]
const AUDIT := preload("res://tests/fixtures/growth_audit.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var towns := "53:grand,31:large,13:standard,43:large,83:grand,103:standard,7:compact,61:standard"
	var out_path := "/tmp/growth_audit.json"
	for i in args.size() - 1:
		if args[i] == "--towns": towns = args[i + 1]
		if args[i] == "--out": out_path = args[i + 1]
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var overrides := TownOddsProgram.parse_overrides(args, program.town_odds)
	if overrides.has("error"):
		quit(2)
		return
	if not overrides.is_empty():
		program.town_odds = program.town_odds.with_overrides(overrides)
	var rows := []
	var bad := 0
	for town: String in towns.split(","):
		var parts := town.split(":")
		var profile := WarrenVillageScaleProfile.for_id(StringName(parts[1]))
		var spatial := WarrenVolumetricSolver.generate(int(parts[0]), {}, program, profile)
		if spatial == null:
			rows.append({"town": town, "error": "no town"})
			bad += 1
			print("GROWTH_AUDIT ", JSON.stringify(rows.back()))
			continue
		var fabric := spatial.compiled_fabric_cache()
		var kit := SuntailBuildingKit.create()
		var built := KitVillageBuildings.build(spatial, fabric, kit)
		var row := AUDIT.audit(spatial, fabric, built, kit, profile.character)
		row["town"] = town
		row["valid_payload"] = built.payload.validate()
		for key: String in ["air_hits", "gap_failures", "open_returns", "unfloored", "beyond_roof",
				"floating", "roof_intrusions"]:
			bad += int(row[key])
		rows.append(row)
		print("GROWTH_AUDIT ", JSON.stringify(row))
	FileAccess.open(out_path, FileAccess.WRITE).store_string(JSON.stringify(rows, "  "))
	print("GROWTH_AUDIT_DONE bad=", bad)
	quit(0 if bad == 0 else 1)
```

- [ ] **Step 5: Run the corpus.** `godot --headless --path . --log-file /tmp/ga.log -s res://tests/harness/suntail/growth_corpus_audit.gd -- --odds growing_house_chance=1 --out /tmp/growth_audit_fp.json > /tmp/ga.out 2>&1; echo EXIT $?; grep GROWTH_AUDIT_DONE /tmp/ga.out` → `bad=0`, EXIT 0; then the production sample `--towns 1:compact,2:standard,3:standard,4:large,5:compact,6:standard,8:large,9:grand,10:standard,11:compact,12:standard,14:large,15:standard,16:compact,17:large,18:grand` → `bad=0`. Fix any finding in the owning guardrail (red-first: pin the town and face in a fixture test) before committing.

- [ ] **Step 6: Fingerprint gate** → `FINGERPRINT_MATCH`.

- [ ] **Step 7: Commit** the audit fixture, harness and both tests: message "Towns: growing-floor corpus audit and edge cases" + trailer.

---

### Task 7: Shipped defaults, evidence, write-up

**Files:**
- Modify: `terrain/villages/town_odds.tres` (`growing_house_chance` at_small 0.3, at_large 0.45, spread 0.1)
- Modify: `tests/fixtures/town_old_look.gd` (add `&"growing_house_chance": 0.0`)
- Modify: `tests/harness/suntail/kit_town_review.gd` (`growth` view, ~lines 16, 147, 161, 398)
- Modify: `docs/qa/2026-10-07-town-odds/fingerprint/baseline.json` (re-pinned)
- Create: `docs/qa/2026-10-08-growing-floors/result.md` and render folders `before/`, `after/`, `gallery/`, `audit/`
- Modify: `AGENTS.md` (new top entry)
- Test: `tests/test_growing_floors_knobs.gd` (default assertions), `tests/test_town_old_look.gd`

**Interfaces:**
- Consumes: everything above; `KitVillageBuildings.build(...).growth`.
- Produces: shipped defaults; review view `growth` (kit_town_review); re-pinned fingerprint baseline; result write-up.

- [ ] **Step 1: Update the default test first (red).** In `test_growth_knobs_are_in_the_table_and_off_by_default` rename it `test_growth_knobs_are_in_the_table_with_shipped_defaults` and replace `assert_eq(c.value(GROWTH.HOUSE_KNOB), 0.0)` with `assert_between(c.value(GROWTH.HOUSE_KNOB), lerpf(0.3, 0.45, size) - 0.1, lerpf(0.3, 0.45, size) + 0.1)`; in `test_build_marks_no_house_growing_at_the_default` keep the explicit `0.0` override (it pins the zero path). Run it: fails (`0.0` outside `0.2..0.4`).

- [ ] **Step 2: Review view.** `kit_town_review.gd`: add `static var _growth_views: Array[Dictionary] = []`, clear it beside `_projection_views.clear()`, and after the projection loop:

```gdscript
		for lean: Dictionary in built.get("growth", []):
			var direction: Vector2i = BuildingMass.DIRS[int(lean.dir)]
			_growth_views.append({"at": KitVillageBuildings.native_to_lattice(kit) * (lean.bounds as AABB).get_center(),
				"direction": Vector3(direction.x, 0, direction.y), "lean": float(lean.lean)})
		_growth_views.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.lean) > float(b.lean))
```

and a view beside `projections`:

```gdscript
		if _views.has("growth"):
			# Shambles framing: stand in the lane in front of the deepest leans and look along it.
			for index in mini(6, _growth_views.size()):
				var view: Dictionary = _growth_views[index]
				var target: Vector3 = town.transform * (view.at as Vector3)
				var outward: Vector3 = (town.transform.basis * (view.direction as Vector3)).normalized()
				var along := outward.cross(Vector3.UP).normalized()
				var foot := target + outward * 2.0
				foot.y = town.transform.origin.y + _ground_y + 1.8
				await _shoot(stage, foot - along * 10.0, foot + along * 20.0 + Vector3.UP * 4.0,
					"%d_%s_growth%d_lane" % [seed_value, scale, index], 70)
				await _shoot(stage, foot + outward * 1.5, target + Vector3.UP * 3.0,
					"%d_%s_growth%d_up" % [seed_value, scale, index], 75)
```

- [ ] **Step 3: Before renders (defaults still 0).** `godot --path . --log-file /tmp/rb.log -s res://tests/harness/suntail/kit_town_review.gd -- --cities 53:grand,31:large,13:standard,43:large,83:grand,103:standard,7:compact,61:standard --views overview,orbit,street,lane --output docs/qa/2026-10-08-growing-floors/before > /tmp/rb.out 2>&1` (GUI run, no `--headless`).

- [ ] **Step 4: Ship the defaults.** `growing_house_chance`: `at_small = 0.3`, `at_large = 0.45`, `spread = 0.1`, notes "… Shipped (task 7)." Add `&"growing_house_chance": 0.0` to `tests/fixtures/town_old_look.gd` `VALUES`. Run `test_growing_floors_knobs.gd` → green.

- [ ] **Step 5: After renders and gallery.** Same cameras: the Step 3 command with `--views overview,orbit,street,lane,growth --output docs/qa/2026-10-08-growing-floors/after`. Gallery at three knob values: `godot --path . --log-file /tmp/g1.log -s res://tests/harness/suntail/building_gallery.gd -- --set designer --count 9 --seed 4 --close --growth 0.25:1.0 --output docs/qa/2026-10-08-growing-floors/gallery/step025_cap100`, then `--growth 0.5:1.5 --output .../gallery/step050_cap150` and `--growth 0.25:0.5 --output .../gallery/step025_cap050`. Look for: Shambles-style leaning fronts, facing tops within the sky gap, no wall head through an eave, no gap at a moved gable, every overhang floored and bracketed, returns closed. Record any defect red-first (pin seed/face in a fixture test) and fix before continuing.

- [ ] **Step 6: Audits with the new defaults.** `growth_corpus_audit.gd` on the 8 fingerprint towns and the Task 6 production sample with no `--odds` → `bad=0` (save `--out res://docs/qa/2026-10-08-growing-floors/audit/default_fp.json` and `.../default_sample.json`); also the production audit `godot --headless --path . -s res://docs/qa/2026-10-01-town-redesign/prefab-grammar/october6-integrated-checkpoint/unequal-roof-range-study/production-validation/oct7-range-audit-prod.gd.txt` copied to `/tmp/growth_range_audit.gd` and run with `-s /tmp/growth_range_audit.gd -- 53:grand,31:large,13:standard,43:large,83:grand,103:standard` → every row `valid_payload` true, `floating` 0, `roof.intrusions` 0.

- [ ] **Step 7: Fingerprint re-pin and old-look confirmation.**
  1. Source plans must not move: fingerprint gate with `--parts source` → `FINGERPRINT_MATCH` (growth is kit-layer only).
  2. `godot --headless --path . --log-file /tmp/fpw.log -s res://tests/harness/town_fingerprint.gd -- --out res://docs/qa/2026-10-07-town-odds/fingerprint/baseline.json > /tmp/fpw.out 2>&1`, then the full fingerprint gate → `FINGERPRINT_MATCH`.
  3. Zero path still reproduces the old payloads: `... town_fingerprint.gd -- --odds growing_house_chance=0 --out /tmp/fp_zero.json --compare /tmp/growth_fp_ref.json` (or the pre-Task-7 `baseline.json` from `git show HEAD:docs/qa/2026-10-07-town-odds/fingerprint/baseline.json > /tmp/fp_prev.json`) → `FINGERPRINT_MATCH`.
  4. `godot --headless --path . -s res://tests/harness/town_fingerprint.gd -- --old-look --compare res://docs/qa/2026-10-07-town-odds/fingerprint/old_look_baseline.json --parts source` → `FINGERPRINT_MATCH`; focused `test_town_old_look.gd` passes.
  5. Re-run every growth test file plus `test_october3_room_projections.gd`, `test_roof_proportion.gd`, `test_town_odds.gd` → green.

- [ ] **Step 8: Write `docs/qa/2026-10-08-growing-floors/result.md`:** what changed (knobs and defaults, planner, guardrails 1–7, roof following), the image table (before/after per town and view, `*_growth*_lane` Shambles views, the three gallery sets) with one honest sentence per image, audit tables (faces leaned per town, every violation count 0, production rows), fingerprint/old-look results, rulings from this plan's Self-Review, limits (Pure-roof houses grow only on eave faces; a set-back top storey or portal keeps its face flush; DAYLIGHT_AIR is not a block, the sky gap protects it; planner still unaware of leans).

- [ ] **Step 9: AGENTS.md entry** at the top, one paragraph: "> GROWING UPPER FLOORS (Oct 8, spec `docs/superpowers/specs/2026-10-08-growing-upper-floors-design.md`, result `docs/qa/2026-10-08-growing-floors/result.md`): `KitGrowingFronts` (kit layer only; after towers, before projections/bays in `KitVillageBuildings.build`) leans chosen street faces of growing houses one baked step per storey above the ground storey (`growing_house_chance` 0.3→0.45 spread 0.1, `growth_street_face_chance` 0.85, `growth_other_face_chance` 0.1, `growth_step` 0.25/0.5 native m, `growth_max_lean` 1.0–1.5 floored to whole steps and 4 steps, `lane_sky_gap` 0.75, `growth_gable_front_boost` 2.0). Leans write `wall_offsets` + `projections{growth:true, base}` + `storey.growth`; `_emit_projected_front` closes them with baked `frontage.{floor,return,return_beam}.dNNN` (`town_room_fronts.json`, `export_growth_front_manifest.gd`). Profiles are monotone: a failing step is withdrawn, a storey that cannot hold the inherited lean drops the face cap (no inward ledge). Guardrails: public air, sky gap (also applied to projections facing a lean), neighbours/features/reserved columns, whole convex exposed run with clear ends and no perpendicular lean, per-run footprint chain, no door/portal/balcony bearing, crown (next leaned storey, moved gable end with clipped filler on uncapped roofs, or the measured eave allowance from `eave_allowance`). A growing house takes no inset jetty and no flush porch canopy (rolls kept). Zero chance is byte-identical (old-look fixture pins 0); fingerprint baseline re-pinned for the defaults; audit `growth_corpus_audit.gd`."

- [ ] **Step 10: Commit** `terrain/villages/town_odds.tres`, `tests/fixtures/town_old_look.gd`, `kit_town_review.gd`, `tests/test_growing_floors_knobs.gd`, `docs/qa/2026-10-07-town-odds/fingerprint/baseline.json`, `docs/qa/2026-10-08-growing-floors/` (result, audits, renders), `AGENTS.md`: message "Towns: growing upper floors on by default (0.3-0.45), evidence and re-pinned fingerprint" + trailer.

---

## Self-Review

**Spec coverage.** Intent/knobs → Task 1 (+ defaults Task 7); baked return family at cumulative depths, no runtime scaling → Task 2; per-house/per-face selection keyed by stable ids, cumulative `wall_offsets`, closing pieces through `_emit_projected_front`, replacing the jetty on growing houses, projections replaced on leaning faces, bays/balconies kept off leaning faces → Task 3; guardrails 1–6 each with a focused test → Task 4 (G5 is the chain rule from Task 1, tested in Task 4); roof following (gable-end shift with `clip_volumes` filler realised by `KitRoofMeshUnion`, eave cap = guardrail 7, gable-front boost in `_square_axis`, `roof_proportion_ok` untouched) → Task 5; corpus (fingerprint towns + production sample: air, sky gap, closed returns, floored overhangs, wall under roof, null towns, floating masses, roof/public-air) and the five listed edge cases → Task 6; evidence renders, gallery at several knob values, `result.md`, AGENTS.md entry, defaults with fingerprint re-pin and old-look confirmation → Task 7. Zero-knob byte identity is gated after every task.

**Rulings and spec conflicts (recorded here and in `result.md`):**
1. *Cap quantisation.* "capped at growth_max_lean" is applied as `step · min(4, floor(cap/step))`, so every lean is a baked depth and the cap is at most four steps (spec Risks); depth family = {0.25, 0.5, 0.75, 1.0, 1.5, 2.0}.
2. *"Every storey above keeps the last accepted lean" vs a storey that cannot hold any lean.* Taken literally, a storey failing a lean-independent guardrail (portal, neighbour at an end, reserved column, set-back storey above, unshiftable gable) would keep an inherited lean that itself violates the guardrail, or sit inward of the storey below (an open ledge). Ruling: leans are monotone; such a storey drops the face cap and the face is re-fitted, so those guardrails withdraw the whole face's steps up to that storey, while lean-dependent guardrails (air, sky gap, neighbours by geometry, eave cover) withdraw exactly the failing step as the spec's tests require.
3. *Crown rule.* The last storey of a face must be closed above its lean: by the next leaned storey, a moved gable end, or the eave allowance; a deck, open crown or an unleaned storey above means no lean at the chain end (no exposed ledge).
4. *Jetty replacement.* `inset` is storey-wide in `BuildingDesigner`, so a growing house takes no inset jetties at all (the spec's "on that face" cannot be expressed per face); the jetty and canopy rolls are still drawn so the house's other choices are unchanged.
5. *Ordering.* The spec says towers/bays/balconies are fitted after growth; in code towers already precede projections and balconies are feature masses built before houses. Growth therefore runs after towers (towers and balconies are obstacles, `bears_balcony` storeys do not step) and before projections and bays, which fit around the leaned walls.
6. *Street face* is a column test (public air at any band from the datum up to the storey), because the grid does not guarantee PUBLIC_AIR over a lane at upper bands; DAYLIGHT_AIR is not a growth block (the sky gap protects light slots).
7. *Guardrail 6 generalised* to any door/portal/passage on the face and to walls bearing balcony rakers; *guardrail 4 extended*: a storey leans on at most two opposite faces (no perpendicular returns meeting).
8. *Roof families.* Gable shift only on kits without edge caps (Suntail roofs); capped Pure roof families, open/junction ends, verge/clip keys, tight eaves and end dormers keep the face flush at a gable end (spec Risk fallback; an unmoved gable over a leaned wall would leave a ledge). Eave allowance is measured: reach from the eave piece's `measured_aabb`, cover from the baked roof skin (`suntail_roofs.bin`).
9. *Projections facing a lean* also respect `lane_sky_gap` (only when the growth registry is non-empty, so zero growth is unchanged).
10. *Returns above 1.0 m* are cut from `Wall_Start_20x30_0.glb` (2.0 m), measured, not scaled.
11. Wall-room houses and stone/retaining/fortified storeys never lean (as projections).
12. *Finding for the owner (gable-front boost):* Suntail verges and eaves overhang 1.0 native m, so across a one-cell (2.0 m) lane the facing roofs already meet mid-lane; a gable end there cannot move without entering the facing roof (guardrail 3), and with no inward step allowed such a face stays flush. In one-cell lanes growth therefore comes from eave faces (capped by the measured allowance); gable-front leans need two-cell lanes or open fronts. `growth_gable_front_boost` still applies as specified; Task 7's audit reports leaned faces per lane width so the owner can retune it.
13. `lane_sky_gap` clamp is 0.25–4.0 native m (the spec gives only the default) so a test can make the gap bind in a two-cell lane.

**Placeholder scan.** No TBD/"handle edge cases"/"similar to"; every new function has code, every test has assertions and an exact command. Conditional steps (Task 1 Step 0 reference, Task 6 Step 3/5 fixes) name the exact action and file.

**Name consistency.** `KitGrowingFronts` (preloaded as `GROWTH`), `fit(...) -> {leans, registry}` with `roof_geometry` appended in Task 5 (fixture and `KitVillageBuildings` updated in the same task), `face_chains`, `house_eligible`, `house_grows`, `crown_index`, `crown_wing`, `eave_allowance`, `roof_geometry`, `gap_ok`; assembler `lean_suffix`, `OFFSET_WALL_DROP`, `face_parts`, `roof_parts`, `_front_role`, `_emit_front_floors`, `_lean_roof_end`; storey keys `wall_offsets`, `projections[{growth, base}]`, `growth`; wing keys `lean_min`/`lean_max`; placement keys `lean_end`/`lean_filler`; designer `gable_front_boost`, context `grows`/`gable_boost`; knob names match the spec table exactly.
