# Growing Upper Floors Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Amended October 8 (owner review after Task 4's diagnosis).** Tasks 1–3 are done and reviewed (commits 44ceab557, fb0a33125, 8e952f670, 8ce3e55b4) and stay as written. The original Tasks 4–7 are replaced by Tasks 4–10 below. The spec's "Amendment (October 8, owner review)" section is binding; where the text of Tasks 1–3 says "lean", "street face" or "0.25 step", read the amendment.

**Goal:** Some town houses grow outward storey by storey (York's Shambles): on any exposed face, each storey above the ground storey steps out one kit jetty (1.0 native m, on the kit's own `bracket.jetty` brace) further than the one below, walls vertical, closed like today's room projections. Adjacent faces of one house step out together round convex corners, terrace neighbours step out as one row, and a stepped end may run into a plain perpendicular wall; facing upper floors nearly meet while the lane keeps a slot of sky. Tunable by town odds; byte-identical to today when `growing_house_chance = 0`.

**Architecture:** A pure kit-layer fitter, `KitGrowingFronts`, runs in `KitVillageBuildings.build` after roofs are joined and towers proposed, before room projections and facade bays. It builds FRONTS (face chains that step as one: a lone face, faces joined at a house's convex corners, coplanar faces of neighbouring houses), gives each front one monotone cumulative step profile, and writes it through the existing `storey.wall_offsets` / `storey.projections` contract (`projections{growth, base, closures}`). `BuildingKitAssembler._emit_projected_front` closes each step with baked depth variants of `frontage.floor` / `frontage.return` / `frontage.return_beam` / `frontage.corner`, `bracket.jetty` for a kit-sized increment, and per-end closures (`return`, `wrap`, `joint`, `bury`). Guardrails each withdraw a step (never a house or town); a front member that cannot hold a storey leaves its front. The top storey follows its roof (gable end shifts with a clipped filler, or the step is capped under the measured eave).

**Tech Stack:** Godot 4.5, typed GDScript, GUT, environment bake (`tools/environment_bake/environment_bake.gd`, `bake_town_frame_variants.gd`, `export_growth_front_manifest.gd`), town fingerprint harness, `growth_corpus_audit` (new), `kit_town_review` / `building_gallery` render harnesses.

**Spec:** `docs/superpowers/specs/2026-10-08-growing-upper-floors-design.md` (read its "Amendment (October 8, owner review)" first).

## Global Constraints

- Worktree `/Users/ryko/.codex/worktrees/77a0/story`, branch `town-redesign`; never touch `/Users/ryko/story`; never run the `godot-test` alias.
- `godot` below means `/Applications/Godot.app/Contents/MacOS/Godot`; always add `--log-file /tmp/<name>.log`, redirect stdout to a file and check the exit code; ignore unrelated Godot processes; run `godot --headless --path . --import` after adding a `class_name` or new assets.
- Knob `growing_house_chance`: CHANCE, 0.3 small → 0.45 large, spread 0.1 (shipped in Task 10; Tasks 1–9 keep it at 0).
- Knob `growth_street_face_chance`: CHANCE, 0.85.
- Knob `growth_other_face_chance`: CHANCE, 0.85 (equal to the street knob: every exposed face alike; set in Task 4).
- Knob `growth_step`: WEIGHTS, {0.5 native m (1.0 m world, `bracket.small`): 1, 1.0 native m (2.0 m world, the kit jetty, `bracket.jetty`): 3} (set in Task 4; 0.25 retired).
- Knob `growth_max_lean`: RANGE_FLOAT, 2.0 native m (two kit steps; 4 m world) at every size (set in Task 4).
- Knob `lane_sky_gap`: RANGE_FLOAT, 0.75 native m (1.5 m world).
- Knob `growth_gable_front_boost`: RANGE_FLOAT, 2.0.
- Units: kit native metres (module 2.0 m, storey 3.0 m; world = native x 2); steps are sub-module offsets applied through `wall_offsets` (module fractions). Suntail `jetty_depth` = 1.0 native = half a module.
- Byte-identical at `growing_house_chance = 0`: fingerprint `baseline.json` MATCH and `test_town_old_look` pass after every task 4–9.
- Guardrails withdraw the offending step, never a house or a town; in a front, a member that cannot hold a storey leaves the front (the rest keep stepping).
- No runtime asset scaling: every depth is a baked `frontage.*` variant (manifest clip), steps 0.5 / 1.0, at most four steps (cap 2.0).
- Worker purity: fitters return plain dictionaries and mutate only `BuildingMass` data; no nodes or server resources; catalog and roof geometry are read-only inputs.
- Deterministic per-key rolls: house rolls keyed by `mass.stable_id`, face rolls by the face key, fronts processed in leader-key order; one knob never moves another knob's draw.
- Every commit message ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; commit only this task's paths (`git commit -m "..." -- <paths>`; another agent commits roof work in this worktree concurrently); never `git add -f`, never commit `.superpowers/`.
- Measurement, not loosening: when a corpus count misses its target, report the per-cause withdrawal counts and stop for a controller ruling; never relax a guardrail to hit a number.

Command forms used below:

- Focused test: `godot --headless --path . --log-file /tmp/t.log -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/<file>.gd -gexit > /tmp/t.out 2>&1; echo EXIT $?; tail -30 /tmp/t.out`
- Fingerprint gate: `godot --headless --path . --log-file /tmp/fp.log -s res://tests/harness/town_fingerprint.gd -- --out /tmp/fp.json --compare res://docs/qa/2026-10-07-town-odds/fingerprint/baseline.json > /tmp/fp.out 2>&1; echo EXIT $?; grep FINGERPRINT_ /tmp/fp.out` must print `FINGERPRINT_MATCH` (harness flags: `--towns`, `--out`, `--compare`, `--parts source,payload,error`, `--odds name=value`, `--old-look`).
- Growth-on smoke (Tasks 3–9): the same command with `--odds growing_house_chance=1 --out /tmp/fp_on.json` and no `--compare`; `grep -c FINGERPRINT_NO_TOWN /tmp/fp.out` must print 0.
- Growth corpus count (Tasks 4–9, harness created in Task 4): `godot --headless --path . --log-file /tmp/gc.log -s res://tests/harness/suntail/growth_corpus_audit.gd -- --odds growing_house_chance=1 --odds growth_street_face_chance=1 --odds growth_other_face_chance=1 --out /tmp/growth_count.json > /tmp/gc.out 2>&1; echo EXIT $?; grep -E "GROWTH_(TOTAL|AUDIT_DONE)" /tmp/gc.out`. Baselines from `task-4-report.md` Diagnosis 2 on the same 8 towns: 183 candidate faces; 18 stepping faces / 19 storeys with the three false-blocker fixes; 22 / 23 with the coplanar terrace.

## Review Focus

1. Two growing fronts facing across a lane: the later front in leader-key order must see the earlier one's accepted step and withdraw exactly its own failing step, so every facing pair keeps at least `lane_sky_gap`; the earlier front is unchanged. Tests: Task 4 `test_sky_gap_withdraws_only_the_later_houses_failing_step`, Task 9 `test_facing_growing_houses_across_one_cell_lane`.
2. A storey that cannot hold even the inherited step (portal on the face, blocked end, set-back storey above, uncovered crown): in a lone front the face cap drops and the storeys below re-cap, so no storey is ever inward of the one below (no exposed ledge); in a multi-member front the member leaves and the rest refit. The house and town still build. Tests: Task 4 `test_skywalk_portal_face_never_leans_but_other_face_does`, Task 5 `test_a_member_that_cannot_hold_leaves_the_front`, Task 6 `test_a_row_member_that_cannot_step_withdraws_the_joint_not_the_town`.
3. Closures: every stepped end closes by exactly one rule — `return` (open air), `wrap` (strips + corner squares + post at the moved corner), `joint` (no pieces; neighbour steps equally), `bury` (plain wall only). No end is left open, no return is doubled at a joint. Tests: Task 5 `test_a_wrapped_corner_is_closed_by_strips_squares_and_a_post`, Task 6 `test_a_terrace_row_steps_out_as_one`, Task 7 `test_inside_corner_end_is_buried_in_a_plain_wall`, Task 9 audit keys `open_returns`, `open_corners`, `broken_joints`, `buried_on_ornament`.
4. Roofs: an eave-crowned top storey stays under the measured cornice (kit 1.0 steps cannot; the 0.5 fallback or flush), and a gable end that cannot shift cleanly keeps its face flush at the top. Tests: Task 8 `test_eave_face_top_step_stays_under_the_measured_cornice`, `test_unshiftable_gable_end_keeps_the_face_flush`.
5. The zero path: at `growing_house_chance = 0` no designer rng draw is skipped or added, no storey/wing key is written, projections/bays see exactly today's inputs, `storey_slots`' new `right_extend` is 0 everywhere, and changing one growth knob never moves another knob's draw or another house's roll. Tests: Task 1 `test_house_roll_is_keyed_by_house_and_untouched_by_other_growth_knobs`, `test_build_marks_houses_growing_only_when_the_chance_is_positive`, and the fingerprint gate after every task.

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

### Task 4: Guardrails, false-blocker fixes, any-exposed-face eligibility, kit-sized step

One reviewable unit: the guardrails commit already made (c8963fe9b) plus the owner's amendment decisions 1–3, 6 and 7. Task 4's original brief (guardrails 1–6: `_parts_clear` for G1+G3, `gap_ok`, `_columns_free`, `_ends_clear`, `_no_portal`, `crown_index`, `clear_of`, the `KitRoomProjections` sky-gap hook, `tests/test_growing_floors_guardrails.gd` with 8 tests) is implemented at c8963fe9b and is the base of this task; `git show c8963fe9b` is its reference. Do not re-implement it.

**Files:**
- Modify: `scripts/terrain/features/villages/kit/KitGrowingFronts.gd` (`STEP_SIZES`; `face_chains` per-edge footprint and chain keys `first_band`, `start_convex`, `end_convex`; `house_eligible`; `fit` returns `rejections`, carries steps; `_profile` records causes; `_fits` → `_fault`; `_parts_clear` → `_parts_fault` with `TOUCH`, riding pieces, yields; `_obstacles` tags decor; `_commit` moves face decor and removes yields; new `contact_clear`, `carried_step`, `_face_slab`, `_obstacle_cause`)
- Modify: `scripts/terrain/features/villages/kit/BuildingKitAssembler.gd` (`_emit_projected_front`: `bracket.jetty` for a kit-sized increment; `face_parts` emits a bay through the shared `_emit_bay`; `_assemble_storey` uses `_emit_bay`)
- Modify: `scripts/terrain/features/villages/kit/KitVillageBuildings.gd` (result key `growth_rejections`)
- Modify: `terrain/villages/town_odds.tres` (`growth_other_face_chance` 0.85; `growth_step` options `0.5`/`1.0` weights 1/3; `growth_max_lean` 2.0/2.0; notes)
- Modify: `tests/fixtures/growing_house.gd` (`character` defaults step `1.0`, cap 2.0)
- Modify: `tests/test_growing_floors.gd`, `tests/test_growing_floors_guardrails.gd`, `tests/test_growing_floors_knobs.gd` (re-pin to the kit ladder; new tests)
- Create: `tests/harness/suntail/growth_corpus_audit.gd` (count mode; Task 9 adds the violation audit)

**Interfaces:**
- Consumes: c8963fe9b's `gap_ok`, `crown_index`, `clear_of`, `_obstacles`, `_candidate`, `_assembler`; `BuildingKitAssembler._assemble_decor(ctx, item)`, `kit.jetty_depth`, `kit.has_role(&"bracket.jetty")`; `TownOddsProgram.parse_overrides`.
- Produces:
  - `KitGrowingFronts.STEP_SIZES: Array[float] = [0.5, 1.0]`; `const TOUCH := 0.05`; `const YIELD_DECOR: Array[StringName]`; `contact_clear(box: AABB, other: AABB) -> bool`; `carried_step(kit: BuildingKit, step: float) -> float`.
  - `face_chains` chain keys added: `first_band: int`, `start_convex: bool`, `end_convex: bool`.
  - `fit(...)` returns `{"leans", "registry", "rejections"}`; each rejection `{"chain": String, "storey": int, "lean": float, "cause": StringName}` with causes `material`, `portal`, `ends`, `columns`, `gap`, `air`, `obstacle.own`, `obstacle.<owner kind>` (owner kind = the token after `kit.` in the owner id), `obstacle.tower`, `obstacle.lean`.
  - Obstacle records gain `"decor": Dictionary` and `"host": BuildingMass` (the decor item that produced the part and its house) and `"gone": bool`.
  - `KitVillageBuildings.build(...)` result gains `"growth_rejections": Array[Dictionary]`.
  - Harness lines `GROWTH_AUDIT <json row>`, `GROWTH_TOTAL <json>`, `GROWTH_AUDIT_DONE bad=<n>`.

- [ ] **Step 1: Re-pin the fixture and existing tests to the kit ladder (red).**

`tests/fixtures/growing_house.gd`, replace `character`:

```gdscript
## Builtin odds with growth forced on for the house under test; `step` fixes
## growth_step ("1.0" = the kit jetty, the default; "0.5" = the light step).
static func character(values: Dictionary = {}, step := &"1.0") -> TownCharacter:
	var fixed := {&"growing_house_chance": 1.0, &"growth_street_face_chance": 1.0,
		&"growth_other_face_chance": 0.0, &"growth_max_lean": 2.0, &"lane_sky_gap": 0.75}
	fixed.merge(values, true)
	var c := TownCharacter.draw(TownOddsProgram.builtin().with_overrides(fixed), 1, 0.5)
	c.values[&"growth_step"] = {&"0.5": 1.0 if step == &"0.5" else 0.0,
		&"1.0": 1.0 if step == &"1.0" else 0.0}
	return c
```

`tests/test_growing_floors.gd` — replace the first three tests and the registry assertion:

```gdscript
func test_each_street_storey_steps_out_one_jetty_further() -> void:
	var f := FIXTURE.build()
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 1.0, 2.0, 2.0] as Array[float],
		"one kit jetty per storey, capped at two")
	assert_eq(FIXTURE.leans_on(f.front, 1), [0.0, 0.0, 0.0, 0.0] as Array[float],
		"the back face is not rolled (other-face chance 0 in the fixture)")
	for index in range(1, 4):
		var lean := minf(float(index), 2.0)
		for slot: Dictionary in BuildingKitAssembler.storey_slots(f.front.storeys[index]):
			if int(slot.dir) == 3:
				assert_almost_eq(float(slot.centre.y), -lean / 2.0, 1e-5, "offset in module units")
	assert_false(f.front.storeys[0].has("wall_offsets"), "the ground storey keeps the lane's width")


func test_cap_floors_to_whole_steps() -> void:
	var f := FIXTURE.build({"storeys": 5, "character": FIXTURE.character({&"growth_max_lean": 1.5})})
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 1.0, 1.0, 1.0, 1.0] as Array[float])
	var g := FIXTURE.build({"storeys": 5, "character": FIXTURE.character({&"growth_max_lean": 2.0}, &"0.5")})
	assert_eq(FIXTURE.leans_on(g.front, 3), [0.0, 0.5, 1.0, 1.5, 2.0] as Array[float])


func _parts_in(f: Dictionary, role: StringName, y0: float) -> Array:
	var catalog := EnvironmentCatalog.load_default()
	return (f.parts as Array).filter(func(part: Dictionary) -> bool:
		var box: AABB = part.transform * catalog.descriptor(part.asset_id).measured_aabb
		return part.role == role and box.position.y >= y0 - 1.2 and box.position.y <= y0 + 2.9)


func test_every_step_is_closed_by_floor_beam_returns_and_the_kit_brace() -> void:
	var f := FIXTURE.build()
	var catalog := EnvironmentCatalog.load_default()
	for index in range(1, 4):
		var lean := minf(float(index), 2.0)
		var base := minf(float(index - 1), 2.0)
		var suffix := BuildingKitAssembler.lean_suffix(lean)
		var y0 := float(f.front.storeys[index].floor_band) * 1.5
		for part: Dictionary in _parts_in(f, StringName("frontage.floor." + suffix), y0):
			var box: AABB = part.transform * catalog.descriptor(part.asset_id).measured_aabb
			assert_almost_eq(box.position.z, -lean, 0.001)
			assert_almost_eq(box.end.z, 0.0, 0.001, "the strip meets the original room line")
		assert_eq(_parts_in(f, StringName("frontage.floor." + suffix), y0).size(), 6,
			"floor and ceiling strip under each of 3 bays")
		assert_eq(_parts_in(f, StringName("frontage.return." + suffix), y0).size(), 2)
		assert_eq(_parts_in(f, StringName("frontage.return_beam." + suffix), y0).size(), 4)
		var braces := _parts_in(f, &"bracket.jetty", y0)
		assert_eq(_parts_in(f, &"bracket.small", y0).size(), 0, "a kit step never takes small brackets")
		if lean <= base:
			assert_eq(braces.size(), 0, "a held storey adds no overhang to brace")
			continue
		assert_eq(braces.size(), 3, "one kit jetty brace per module, as the kit's own jetty")
		for brace: Dictionary in braces:
			var box: AABB = brace.transform * catalog.descriptor(brace.asset_id).measured_aabb
			assert_almost_eq(box.end.y, y0, 0.08, "the brace meets the floor beam of the step above")
			assert_almost_eq(box.position.y, y0 - 1.0, 0.12, "it drops one jetty depth")
			assert_true(box.position.z >= -lean - 0.05 and box.end.z <= -base + 0.3,
				"it spans from the storey below's (stepped) face to the new face")


func test_half_step_keeps_the_small_brackets() -> void:
	var f := FIXTURE.build({"character": FIXTURE.character({}, &"0.5")})
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 0.5, 1.0, 1.5] as Array[float])
	var y0 := float(f.front.storeys[1].floor_band) * 1.5
	assert_eq(_parts_in(f, &"bracket.small", y0).size(), 4, "a bracket at every module joint")
	assert_eq(_parts_in(f, &"bracket.jetty", y0).size(), 0)
```

In `test_growth_result_lists_each_leaned_storey` replace the registry line with `assert_almost_eq(float(f.result.registry[Vector4i(1, 0, 3, 4)]), 2.0, 1e-6)`.

`tests/test_growing_floors_guardrails.gd` — re-pin:

```gdscript
func test_walking_air_withdraws_only_the_storey_it_reaches() -> void:
	# A landing's headroom in front of the second upper storey (band 4, y 6..9),
	# between the 1.0 and 2.0 planes.
	var air: Array[Dictionary] = [_open(AABB(Vector3(-1, 6.2, -1.9), Vector3(8, 0.8, 0.45)))]
	var f := FIXTURE.build({"air": air})
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 1.0, 1.0, 1.0] as Array[float],
		"the 2.0 step is withdrawn; storeys above keep 1.0")


func test_sky_gap_withdraws_only_the_later_houses_failing_step() -> void:
	# A three-cell (6.0 native m) lane with a 2.75 m sky gap.
	var f := FIXTURE.build({"facing": true, "back_grows": true, "lane": 3,
		"character": FIXTURE.character({&"lane_sky_gap": 2.75})})
	assert_eq(FIXTURE.leans_on(f.back, 1), [0.0, 1.0, 2.0, 2.0] as Array[float],
		"the earlier house in sorted order sees an unleaned facade (6 - 2 = 4)")
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 1.0, 1.0, 1.0] as Array[float],
		"6 - 2 - 2 < 2.75 withdraws the second step; 6 - 1 - 2 = 3 holds")
	for index in range(1, 4):
		var gap := 6.0 - FIXTURE.leans_on(f.front, 3)[index] - FIXTURE.leans_on(f.back, 1)[index]
		assert_true(gap >= 2.75 - 1e-4, "storey %d keeps the lane's sky slot" % index)


func test_neighbouring_feature_withdraws_only_the_storey_it_reaches() -> void:
	var towers: Array[Dictionary] = [{"bounds": AABB(Vector3(-1, 6.2, -1.9), Vector3(8, 0.8, 0.45))}]
	var f := FIXTURE.build({"towers": towers})
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 1.0, 1.0, 1.0] as Array[float])
```

In `test_footprint_change_ends_the_face_chain` change the last expectation to `[0.0, 1.0, 0.0, 0.0]`. In `test_gap_ok_measures_to_the_facing_lean`, `test_reserved_column_keeps_the_face_flush`, `test_neighbour_at_a_face_end_keeps_the_face_flush` and `test_skywalk_portal_face_never_leans_but_other_face_does` nothing changes in this task.

`tests/test_growing_floors_knobs.gd` — in `test_growth_knobs_are_in_the_table_with_their_shipped_values` replace the step/other-face/cap assertions with:

```gdscript
		assert_eq(c.weights(GROWTH.STEP_KNOB).keys(), [&"0.5", &"1.0"])
		assert_gt(float(c.weights(GROWTH.STEP_KNOB)[&"1.0"]), float(c.weights(GROWTH.STEP_KNOB)[&"0.5"]),
			"the kit jetty is the usual step")
		assert_almost_eq(c.value(GROWTH.OTHER_FACE_KNOB), 0.85, 1e-6)
		assert_almost_eq(c.value(GROWTH.OTHER_FACE_KNOB), c.value(GROWTH.STREET_FACE_KNOB), 1e-6,
			"every exposed face is treated alike")
		assert_almost_eq(c.value(GROWTH.CAP_KNOB), 2.0, 1e-6)
```

(delete the two trailing CAP assertions at 1.0 / 1.5), and replace `test_eligible_house_needs_an_upper_storey_on_a_street_face` with:

```gdscript
func test_eligible_house_needs_two_stacked_storeys_and_an_exposed_face() -> void:
	var street := Callable(FIXTURE, "street")
	var none := Callable(FIXTURE, "nothing_solid")
	assert_true(GROWTH.house_eligible(FIXTURE.house(&"kit.a", Rect2i(0, 0, 3, 2), 3, 3), none, street))
	assert_true(GROWTH.house_eligible(FIXTURE.house(&"kit.b", Rect2i(0, 0, 3, 2), 2, 3), none, street),
		"one storey above the ground can grow")
	assert_false(GROWTH.house_eligible(FIXTURE.house(&"kit.d", Rect2i(0, 0, 3, 2), 1, 3), none, street),
		"a ground-only house cannot grow")
	assert_true(GROWTH.house_eligible(FIXTURE.house(&"kit.c", Rect2i(0, 2, 3, 2), 3, 3), none, street),
		"any exposed face counts, not only street faces")
	var walled := func(_own: StringName, cell: Vector2i, _band: int) -> bool:
		return not Rect2i(0, 2, 3, 2).has_point(cell)
	assert_false(GROWTH.house_eligible(FIXTURE.house(&"kit.e", Rect2i(0, 2, 3, 2), 3, 3), walled, street),
		"a house touching other buildings on every face has nothing to step out")
```

- [ ] **Step 2: Write the new failing tests** (append to `tests/test_growing_floors_guardrails.gd`):

```gdscript
func test_face_over_a_lower_neighbour_is_a_candidate() -> void:
	# A one-storey neighbour covers the ground storey's south edges; the first upper
	# storey's south face is exposed and its edges are still boundary edges below.
	var mass := FIXTURE.house(&"kit.fixture.front", Rect2i(0, 0, 3, 2), 3, 1)
	var low := func(_own: StringName, cell: Vector2i, band: int) -> bool:
		return cell.y == -1 and band <= 1
	var south := FIXTURE.GROWTH.face_chains(mass, low, Callable(FIXTURE, "street")).filter(
		func(c: Dictionary) -> bool: return int(c.dir) == 3)
	assert_eq(south.size(), 1)
	assert_eq((south[0].storeys as Array).size(), 2)
	assert_eq(int(south[0].first_band), 2)


func test_contact_under_five_centimetres_is_touching() -> void:
	var a := AABB(Vector3.ZERO, Vector3.ONE)
	assert_true(FIXTURE.GROWTH.contact_clear(a, AABB(Vector3(0.97, 0, 0), Vector3.ONE)), "3 cm")
	assert_false(FIXTURE.GROWTH.contact_clear(a, AABB(Vector3(0.94, 0, 0), Vector3.ONE)), "6 cm")
	assert_true(FIXTURE.GROWTH.contact_clear(a, AABB(Vector3(2, 0, 0), Vector3.ONE)), "apart")


func test_own_bay_on_the_stepping_face_moves_with_it() -> void:
	# Light steps: a 0.5 face passes through the bay's old plane, which used to block.
	var f := FIXTURE.build({"character": FIXTURE.character({}, &"0.5"),
		"prepare": func(front: BuildingMass) -> void:
			front.storeys[1].openings[BuildingMass.edge_key(Vector2i(1, 0), 3)] = BuildingMass.OPENING_BAY})
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 0.5, 1.0, 1.5] as Array[float])
	var catalog := EnvironmentCatalog.load_default()
	var bays := (f.parts as Array).filter(func(p: Dictionary) -> bool: return String(p.role).begins_with("bay."))
	assert_eq(bays.size(), 1)
	assert_lt((bays[0].transform * catalog.descriptor(bays[0].asset_id).measured_aabb).get_center().z, -0.5,
		"the bay stands on the stepped face (0.5 out), not the old plane")


func test_own_ornaments_under_the_new_braces_yield() -> void:
	var f := FIXTURE.build({"prepare": func(front: BuildingMass) -> void:
		front.decor.append({"kind": &"ivy", "centre": Vector2(1.5, 0.0), "dir": 3, "y": 0.0,
			"proud": 0.0})})
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 1.0, 2.0, 2.0] as Array[float])
	assert_false(f.front.decor.any(func(d: Dictionary) -> bool: return d.kind == &"ivy"),
		"the ground-storey ivy under the first brace is removed, not a blocker")


func test_withdrawn_steps_name_their_guardrail() -> void:
	var f := FIXTURE.build({"reserved": func(_own: StringName, cell: Vector2i, band: int) -> bool:
		return cell.y == -1 and band >= 6})
	var causes := (f.result.rejections as Array).map(func(r: Dictionary) -> StringName: return r.cause)
	assert_true(causes.has(&"columns"), str(causes))
```

`tests/test_growing_floors_knobs.gd` gains:

```gdscript
func test_a_kit_without_the_jetty_brace_steps_half_a_jetty() -> void:
	var kit := SuntailBuildingKit.create()
	assert_eq(GROWTH.carried_step(kit, 1.0), 1.0, "Suntail carries a 1.0 step on bracket.jetty")
	assert_eq(GROWTH.carried_step(kit, 0.5), 0.5)
	kit.jetty_depth = 0.0
	assert_eq(GROWTH.carried_step(kit, 1.0), 0.5, "no matching jetty brace: the light step")
```

- [ ] **Step 3: Run and see them fail.** Focused-test command for each of the three files. Expected: the re-pinned lists still show the 0.25 ladder or `[0,0,0,0]` (the fixture's `1.0` pick is not in `STEP_SIZES`), `Nonexistent function 'contact_clear'` / `'carried_step'`, `Invalid access to property or key 'first_band'`, `rejections` missing, and the bay / ivy tests flush.

- [ ] **Step 4: Knob table.** In `terrain/villages/town_odds.tres`: `growth_other_face_chance` `at_small = 0.85`, `at_large = 0.85`, notes "… Amended Oct 8: equal to growth_street_face_chance by default, every exposed face alike."; `growth_step` `options = PackedStringArray("0.5", "1.0")`, `weights_small = PackedFloat32Array(1, 3)`, `weights_large = PackedFloat32Array(1, 3)`, notes "Step added per storey, native m: 1.0 = the Suntail jetty (half a module, 2.0 m world) on bracket.jetty; 0.5 = the light step on bracket.small. Picked per front leader; quantised to what the kit carries (KitGrowingFronts.carried_step)."; `growth_max_lean` `at_small = 2.0`, `at_large = 2.0`, notes "Total step-out cap of the top storey, native m (2.0 = two kit jetties, 4 m world), floored to whole steps."; `growing_house_chance` notes: replace "(2+ storeys above the ground storey on a street face)" by "(2+ stacked storeys and at least one exposed face)".

- [ ] **Step 5: `KitGrowingFronts.gd` — steps, eligibility, causes.**

```gdscript
## Baked step sizes (native m): 0.5 on bracket.small, 1.0 = the kit jetty on bracket.jetty.
const STEP_SIZES: Array[float] = [0.5, 1.0]


## The step this kit can carry: a kit-sized step needs the kit's own jetty brace
## spanning exactly that depth; otherwise the light step.
static func carried_step(kit: BuildingKit, step: float) -> float:
	if step > 0.5 and not (kit.has_role(&"bracket.jetty") and is_equal_approx(kit.jetty_depth, step)):
		return 0.5
	return step
```

In `face_chains` replace the `for key ... in _exposed_runs(mass, first, solid)` loop head with a per-edge footprint test (Decision 2: the lower edge need not be exposed):

```gdscript
	var first_runs := _exposed_runs(mass, first, solid)
	for key: String in first_runs:
		var run: Dictionary = first_runs[key]
		# Guardrail 5 per edge: every edge of the face is also a boundary edge of the
		# storey below (exposed there or not: a lower neighbour or roof may cover it).
		var matching := true
		for along in range(int(run.start), int(run.end)):
			var cell := BuildingKitAssembler._inside_cell(int(run.dir), int(run.line), along)
			if not (ground.cells as Dictionary).has(cell) \
					or (ground.cells as Dictionary).has(cell + BuildingMass.DIRS[int(run.dir)]):
				matching = false
		if not matching:
			continue
```

delete `var below := ...`, and add to the appended chain dictionary `"first_band": int(first.floor_band), "start_convex": bool(run.start_convex), "end_convex": bool(run.end_convex)`. `house_eligible` becomes:

```gdscript
## Two stacked storeys (ground + one above) and at least one exposed face.
static func house_eligible(mass: BuildingMass, solid: Callable, street: Callable) -> bool:
	return not String(mass.stable_id).contains("wall-room") \
		and not face_chains(mass, solid, street).is_empty()
```

In `fit`: initialise `ctx["rejections"] = []`, return `{"leans": leans, "registry": ctx.registry, "rejections": ctx.rejections}` on both paths, and after the `step` pick insert `step = carried_step(kit, step)` (the `kit.has_role` frontage check now uses `STEP_SIZES[0]` = 0.5, `d050`). Replace `_fits` by `_fault` (same order of checks; `&""` means the step fits):

```gdscript
## The first guardrail storey k fails at `lean` over `base`, or &"" when it fits.
static func _fault(mass: BuildingMass, chain: Dictionary, k: int, lean: float, base: float,
		ctx: Dictionary) -> StringName:
	var storey: Dictionary = mass.storeys[chain.storeys[k]]
	if storey.material != BuildingMass.MATERIAL_TIMBER or bool(storey.get("inset", false)) \
			or bool(storey.get("retaining", false)) or bool(storey.get("fortified", false)):
		return &"material"
	if not _no_portal(mass, chain, k):
		return &"portal"
	if not _ends_clear(mass, chain, k, ctx):
		return &"ends"
	if not _columns_free(mass, chain, k, ctx):
		return &"columns"
	if not gap_ok(ctx.registry, ctx.solid, _own(mass), _edges(chain), int(chain.dir),
			int(storey.floor_band), lean, ctx.kit, float(ctx.gap)):
		return &"gap"
	var candidate := _candidate(mass, ctx.kit, chain, k, lean, base, ctx.solid)
	return _parts_fault(mass, candidate, crown_index(mass, chain, k), ctx)
```

In `_profile`, compute `var fault := _fault(mass, chain, k, want, held, ctx) if want > held else &"held"` before the first branch, test `fault == &""`, and on withdrawal (`fault != &"held"`) append `{"chain": String(chain.key), "storey": k, "lean": want, "cause": fault}` to `ctx.rejections`; the hold test becomes `_fault(mass, chain, k, held, held, ctx) == &""`.

- [ ] **Step 6: The three false-blocker fixes in `KitGrowingFronts.gd`.**

```gdscript
## Contact this shallow (native m) is touching, not a collision.
const TOUCH := 0.05
## The house's own ornaments that yield (are removed) where a new step's pieces meet them.
const YIELD_DECOR: Array[StringName] = [&"ivy", &"ivy_corner", &"window_box", &"awning"]


static func contact_clear(box: AABB, other: AABB) -> bool:
	if not box.intersects(other):
		return true
	var overlap := box.intersection(other).size
	return minf(overlap.x, minf(overlap.y, overlap.z)) <= TOUCH


## The stepping storey's own face: its pieces (and a bay or ornament on it) move out with it.
static func _face_slab(candidate: Dictionary, kit: BuildingKit) -> AABB:
	var n := (candidate.centres as Array).size()
	return candidate.pose * AABB(Vector3(-kit.module_width * .5 - .3, 0, -.6),
		Vector3(n * kit.module_width + .6, kit.storey_height, 1.8))


static func _obstacle_cause(obstacle: Dictionary, mass: BuildingMass) -> StringName:
	if obstacle.owner == mass.stable_id:
		return &"obstacle.own"
	if obstacle.owner == &"":
		return &"obstacle.tower" if String(obstacle.role) == "tower" else &"obstacle.lean"
	var token := String(obstacle.owner).trim_prefix("kit.")
	return StringName("obstacle.%s" % token.get_slice(".", 0))


# G1 + G3 with the false blockers removed: touching contact is clear, the face's own
# bay/ornaments ride out with it, the house's own lower ornaments yield.
static func _parts_fault(mass: BuildingMass, candidate: Dictionary, crown: int,
		ctx: Dictionary) -> StringName:
	var catalog: EnvironmentCatalog = ctx.catalog
	var slab := _face_slab(candidate, ctx.kit)
	var yields: Array = []
	candidate["yields"] = yields
	for part: Dictionary in candidate.parts:
		var local: AABB = catalog.descriptor(part.asset_id).measured_aabb
		if CLEARANCE.intersects_air(local, part.transform, ctx.air):
			return &"air"
		var box: AABB = (part.transform * local).grow(-0.002)
		for obstacle: Dictionary in ctx.obstacles:
			if bool(obstacle.get("gone", false)) or not _blocks(obstacle, mass, crown) \
					or contact_clear(box, obstacle.bounds):
				continue
			if obstacle.owner == mass.stable_id:
				var rides := String(obstacle.role).begins_with("bay.") or obstacle.has("decor")
				if rides and slab.has_point((obstacle.bounds as AABB).get_center()):
					continue
				if obstacle.has("decor") and StringName(obstacle.decor.kind) in YIELD_DECOR:
					if not yields.has(obstacle):
						yields.append(obstacle)
					continue
			return _obstacle_cause(obstacle, mass)
	return &""
```

Delete `_parts_clear` (its only caller was `_fits`). `_obstacles` tags decor without changing any part (assemble the house without decor, then each decor item on its own):

```gdscript
static func _obstacles(masses: Array[BuildingMass], kits: Dictionary, base: BuildingKit,
		catalog: EnvironmentCatalog, towers: Array[Dictionary], solid: Callable) -> Array:
	var out: Array = []
	for mass: BuildingMass in masses:
		var assembler := _assembler(mass, kits.get(_own(mass), base), solid)
		var decor := mass.decor.duplicate()
		mass.decor.clear()
		var parts := assembler.assemble(mass)
		mass.decor.assign(decor)
		for part: Dictionary in parts:
			out.append(_obstacle(mass, part, catalog))
		for item: Dictionary in decor:
			var ctx := {"mass": mass, "out": [] as Array[Dictionary], "serial": 0}
			assembler._assemble_decor(ctx, item)
			for part: Dictionary in ctx.out:
				var obstacle := _obstacle(mass, part, catalog)
				obstacle["decor"] = item
				obstacle["host"] = mass
				out.append(obstacle)
	for tower: Dictionary in towers:
		out.append({"owner": &"", "role": "tower", "roof_index": -1, "bounds": tower.bounds})
	return out


static func _obstacle(mass: BuildingMass, part: Dictionary, catalog: EnvironmentCatalog) -> Dictionary:
	return {"owner": mass.stable_id, "role": String(part.role),
		"roof_index": int(part.get("roof_index", -1)),
		"bounds": part.transform * catalog.descriptor(part.asset_id).measured_aabb}
```

In `_commit`, (a) move every decor item on the face of that storey, not only window boxes — replace the window-box loop condition `absf(float(item.get("y", -INF)) - candidate.band * kit.band_height()) > .01` by `float(item.get("y", -INF)) < candidate.band * kit.band_height() - .01 or float(item.get("y", -INF)) >= (candidate.band + 2) * kit.band_height()`; (b) as the first lines of `_commit`, before any storey is written or any part appended to `ctx.obstacles`, remove the ornaments the profile's new pieces meet:

```gdscript
	# Own ornaments the new braces/strips meet yield: remove them and their parts.
	for k in profile.size():
		if profile[k] <= 0.0:
			continue
		var probe := _candidate(mass, kit, chain, k, profile[k], 0.0 if k == 0 else profile[k - 1], ctx.solid)
		_parts_fault(mass, probe, crown_index(mass, chain, k), ctx)
		for obstacle: Dictionary in probe.yields:
			(obstacle.host as BuildingMass).decor.erase(obstacle.decor)
			for other: Dictionary in ctx.obstacles:
				if other.has("decor") and other.decor == obstacle.decor:
					other["gone"] = true
```

- [ ] **Step 7: `BuildingKitAssembler.gd` — kit brace and bay.** In `_emit_projected_front`, after `if depth<=base+.001: continue`:

```gdscript
		if absf(depth-base-kit.jetty_depth)<.001 and kit.has_role(&"bracket.jetty"):
			# A kit-sized step rides the kit's own jetty brace: one per module, on the
			# storey below's (stepped) face, as _emit_jetty_trim places it.
			for centre:Vector2 in centres:
				_emit(ctx,&"bracket.jetty",centre+out*base/kit.module_width,y-kit.jetty_depth,yaw_for_dir(dir))
			continue
```

Room projections (depth 0.65, base 0) never meet the condition, so their placements are unchanged. Extract the bay branch of `_assemble_storey` (the `if kind == BuildingMass.OPENING_BAY:` block that emits `bay_role`) into

```gdscript
## A bay replacing this wall panel (true when one was placed).
func _emit_bay(ctx: Dictionary, storey: Dictionary, slot: Dictionary, wall_y: float, yaw: float,
		pick: int, tint: Color) -> bool:
	var colour := StringName(storey.get("bay_colour", &"red"))
	var bay_role := StringName((storey.get("bay_roles",{}) as Dictionary).get(slot.edge,StringName("bay.%s" % colour)))
	if not kit.has_role(bay_role):
		return false
	var offset: Vector2 = (storey.get("bay_offsets",{}) as Dictionary).get(slot.edge,Vector2.ZERO)
	_emit(ctx, bay_role, (slot.centre as Vector2)+offset, wall_y + kit.band_height() * 2.0 / 3.0, yaw, pick, Transform3D.IDENTITY, tint)
	return true
```

and call it from both `_assemble_storey` (keeping its jetty-trim / spire branches exactly as they are, so payloads are unchanged) and `face_parts` (when the slot's opening is `OPENING_BAY`, emit the bay instead of the wall panel; pick with the same `_hash(mass, index, int(centre.x * 2.0), int(centre.y * 2.0))`).

- [ ] **Step 8: Wire rejections.** In `KitVillageBuildings.build` add `"growth_rejections": growth.rejections` to the returned dictionary.

- [ ] **Step 9: Run to pass.** Focused tests: `test_growing_floors_guardrails.gd` (13 passing), `test_growing_floors.gd` (7), `test_growing_floors_knobs.gd` (6), `test_growth_front_family.gd`, `test_october3_room_projections.gd` (all pass).

- [ ] **Step 10: Corpus count harness** `tests/harness/suntail/growth_corpus_audit.gd` (count mode; Task 9 adds violations):

```gdscript
extends SceneTree
## Growing-floor corpus: stepping faces, stepped storeys and withdrawals per cause.
## godot --headless --path . -s res://tests/harness/suntail/growth_corpus_audit.gd -- \
##   [--towns 53:grand,...] [--odds name=value ...] [--out /tmp/growth_audit.json]
const DEFAULT_TOWNS := "53:grand,31:large,13:standard,43:large,83:grand,103:standard,7:compact,61:standard"


func _init() -> void:
	call_deferred("_run")


## Faces (chains with any step), stepped storeys and withdrawals by cause.
static func counts(built: Dictionary) -> Dictionary:
	var chains := {}
	for lean: Dictionary in built.get("growth", []):
		chains[String(lean.get("chain", ""))] = true
	var causes := {}
	for rejection: Dictionary in built.get("growth_rejections", []):
		causes[String(rejection.cause)] = int(causes.get(String(rejection.cause), 0)) + 1
	return {"faces": chains.size(), "storeys": (built.get("growth", []) as Array).size(), "causes": causes}


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var towns := DEFAULT_TOWNS
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
	var total := {"faces": 0, "storeys": 0, "causes": {}}
	for town: String in towns.split(","):
		var parts := town.split(":")
		var profile := WarrenVillageScaleProfile.for_id(StringName(parts[1]))
		var spatial := WarrenVolumetricSolver.generate(int(parts[0]), {}, program, profile)
		if spatial == null:
			rows.append({"town": town, "error": "no town"})
			bad += 1
			print("GROWTH_AUDIT ", JSON.stringify(rows.back()))
			continue
		var built := KitVillageBuildings.build(spatial, spatial.compiled_fabric_cache(), SuntailBuildingKit.create())
		var row := counts(built)
		row["town"] = town
		row["valid_payload"] = built.payload.validate()
		if not bool(row.valid_payload):
			bad += 1
		total.faces += int(row.faces)
		total.storeys += int(row.storeys)
		for cause: String in row.causes:
			total.causes[cause] = int(total.causes.get(cause, 0)) + int(row.causes[cause])
		rows.append(row)
		print("GROWTH_AUDIT ", JSON.stringify(row))
	print("GROWTH_TOTAL ", JSON.stringify(total))
	FileAccess.open(out_path, FileAccess.WRITE).store_string(JSON.stringify(rows, "  "))
	print("GROWTH_AUDIT_DONE bad=", bad)
	quit(0 if bad == 0 else 1)
```

Run the growth corpus count (command form above). Target: `faces` ≈ 18 (Diagnosis 2 row b: 18 faces / 19 storeys with every exposed face eligible and the three fixes); at least 15. Record `GROWTH_TOTAL` (faces, storeys, causes) in the task report; below 15, stop and report the per-cause counts.

- [ ] **Step 11: Gates.** Fingerprint gate → `FINGERPRINT_MATCH`; growth-on smoke → 0 `FINGERPRINT_NO_TOWN`; `test_town_old_look.gd` passes.

- [ ] **Step 12: Commit** `KitGrowingFronts.gd`, `BuildingKitAssembler.gd`, `KitVillageBuildings.gd`, `terrain/villages/town_odds.tres`, `tests/fixtures/growing_house.gd`, the three test files and the harness: message "Towns: growing floors step out on any exposed face by the kit jetty (false blockers fixed, causes recorded)" + trailer.

---

### Task 5: Fronts and outer-corner wrap

Amendment Decision 5: adjacent exposed faces of one house meeting at a convex corner step out together and the corner is closed. This task introduces the FRONT (faces that step as one), the per-end closure kinds, and the `wrap` closure. Tasks 6 and 7 add the `joint` and `bury` kinds to the same structure.

**Files:**
- Modify: `scripts/terrain/features/villages/kit/KitGrowingFronts.gd` (`fit` builds candidate members and fronts; new `fronts`, `apply`, `_joins`, `_point`, `_fit_front`, `_front_step`, `_front_profile`, `_front_fault`, `_closures`, `_end_kind`, `_end_open`, `_reject`; `_candidate` / `_commit` take closures; `_ends_clear` deleted)
- Modify: `scripts/terrain/features/villages/kit/BuildingKitAssembler.gd` (`storey_slots` writes `right_extend`; `_emit_corner_post` uses it; `_emit_projected_front` closes ends by kind; new `_emit_wrap_end`, `WRAP_INSET`; `face_parts` gives a wrapped right end its partner's offset)
- Modify: `tools/environment_bake/export_growth_front_manifest.gd` (corner squares), `tools/environment_bake/manifests/town_room_fronts.json` (generated), `scripts/terrain/features/villages/kit/SuntailBuildingKit.gd` (role loop gains `corner`), `KitGrowingFronts.FRONT_ROLES` gains `&"frontage.corner"`
- Generated: `terrain/environment/catalog/descriptors/town_frontage_corner_d*.tres` (+ finish variants), visuals/meshes/collisions under `terrain/environment/`, `terrain/environment/catalog/index.tres`
- Modify: `tests/fixtures/growing_house.gd` (options `lone`, `reserved_x`; helper `roofed`)
- Modify: `tests/test_growth_front_family.gd` (corner role), `tests/test_growing_floors.gd`, `tests/test_growing_floors_guardrails.gd` (`"lone": true` re-pins)
- Test: `tests/test_growing_floors_wrap.gd`

**Interfaces:**
- Consumes: Task 4 `_fault`, `_parts_fault`, `_candidate`, `_commit`, `carried_step`, chain keys `first_band`, `start_convex`, `end_convex`; `BuildingKitAssembler.right_of`, `_inside_cell`, `boundary_runs`.
- Produces:
  - Member `{"mass": BuildingMass, "chain": Dictionary, "kit": BuildingKit, "seed": bool}`; front `{"members": Array[Dictionary], "joins": Array[Dictionary]}`, join `{"a": int, "a_end": bool, "b": int, "b_end": bool, "kind": StringName}` (`a_end` true = the end of a's run, false = its start).
  - `KitGrowingFronts.fronts(members: Array[Dictionary]) -> Array[Dictionary]` (members = seeds plus their direct join partners; one front per connected component holding a seed; members sorted by chain key, fronts by leader key).
  - `KitGrowingFronts.apply(mass: BuildingMass, kit: BuildingKit, chain: Dictionary, profile: Array[float], closures: Array) -> Array[Dictionary]` (writes `wall_offsets`, `projections`, `growth`, moves face decor; returns the candidates; `closures[k]` = `[left_kind, right_kind]` for storey k).
  - Projection key `closures: Array[StringName]` = `[left, right]` (left = the `centres.front()` end), kinds `&"return"`, `&"wrap"` (Tasks 6/7 add `&"joint"`, `&"bury"`); growth lean records gain `"closures"`.
  - Slot key `right_extend: float` (module units; 0 except at a wrapped corner); `BuildingKitAssembler.WRAP_INSET: float`.
  - Kit roles `frontage.corner.dNNN` for every `LEAN_DEPTHS` value (a d x d floor/ceiling square).
  - New rejection cause `&"ends"` now means "an end closes by no rule".

- [ ] **Step 1: Fixture options and the red tests.** `tests/fixtures/growing_house.gd` — in `build`, after `var reserved: Callable = ...`:

```gdscript
	# `lone` keeps only the south face stepping: the columns beside the house (x -1
	# and x 3) are reserved, so its corner neighbours leave the front (cause columns).
	var blocked_x: Array = options.get("reserved_x", [-1, 3] if bool(options.get("lone", false)) else [])
	if not blocked_x.is_empty():
		var inner := reserved
		reserved = func(own: StringName, cell: Vector2i, band: int) -> bool:
			return blocked_x.has(cell.x) or bool(inner.call(own, cell, band))
```

and add

```gdscript
## A timber house with a pitched roof over its whole rect (axis 1 = gable to the lane).
static func roofed(id: StringName, rect: Rect2i, storeys: int, door_dir: int, axis := 1,
		union := 7) -> BuildingMass:
	var mass := house(id, rect, storeys, door_dir)
	mass.add_roof(rect, axis, storeys * 2, &"red")["union_index"] = union
	return mass
```

`tests/test_growing_floors_wrap.gd`:

```gdscript
extends GutTest
## Outer-corner wrap (spec amendment Decision 5).
const FIXTURE := preload("res://tests/fixtures/growing_house.gd")
const GROWTH := preload("res://scripts/terrain/features/villages/kit/KitGrowingFronts.gd")


func _all_faces() -> TownCharacter:
	return FIXTURE.character({&"growth_other_face_chance": 1.0})


func _closures(f: Dictionary, dir: int) -> Array:
	for lean: Dictionary in f.leans:
		if lean.host == f.front.stable_id and int(lean.dir) == dir and int(lean.band) == 2:
			return lean.closures
	return []


func test_a_growing_face_pulls_its_corner_neighbours_one_hop() -> void:
	var f := FIXTURE.build() # only the south (street) face is rolled
	for dir: int in [3, 0, 2]:
		assert_eq(FIXTURE.leans_on(f.front, dir), [0.0, 1.0, 2.0, 2.0] as Array[float], "face %d" % dir)
	assert_eq(FIXTURE.leans_on(f.front, 1), [0.0, 0.0, 0.0, 0.0] as Array[float],
		"the north face is two hops away and was not rolled")
	assert_eq(_closures(f, 3), [&"wrap", &"wrap"])
	assert_eq(_closures(f, 0), [&"return", &"wrap"], "east: north end open, south end wrapped")
	assert_eq(_closures(f, 2), [&"wrap", &"return"], "west: south end wrapped, north end open")


func test_all_four_faces_wrap_into_a_ring() -> void:
	var f := FIXTURE.build({"character": _all_faces()})
	for dir in 4:
		assert_eq(FIXTURE.leans_on(f.front, dir), [0.0, 1.0, 2.0, 2.0] as Array[float], "face %d" % dir)
		assert_eq(_closures(f, dir), [&"wrap", &"wrap"], "face %d" % dir)


func test_a_member_that_cannot_hold_leaves_the_front() -> void:
	var f := FIXTURE.build({"character": _all_faces(), "prepare": func(front: BuildingMass) -> void:
		var edge := BuildingMass.edge_key(Vector2i(2, 0), 0)
		front.storeys[2].openings[edge] = BuildingMass.OPENING_DOOR
		front.storeys[2]["passage_edges"] = {edge: true}})
	assert_eq(FIXTURE.leans_on(f.front, 0), [0.0, 0.0, 0.0, 0.0] as Array[float], "the east portal face leaves")
	for dir: int in [3, 1, 2]:
		assert_eq(FIXTURE.leans_on(f.front, dir), [0.0, 1.0, 2.0, 2.0] as Array[float], "face %d" % dir)
	assert_eq(_closures(f, 3), [&"return", &"wrap"], "south: its east end now closes with a return")
	var causes := (f.result.rejections as Array).map(func(r: Dictionary) -> StringName: return r.cause)
	assert_true(causes.has(&"portal"), str(causes))


## Two faces of one storey that meet at a convex corner step equally or one is flush.
func _corners_consistent(mass: BuildingMass) -> bool:
	for storey: Dictionary in mass.storeys:
		var offsets: Dictionary = storey.get("wall_offsets", {})
		for slot: Dictionary in BuildingKitAssembler.storey_slots(storey):
			if not bool(slot.right_convex):
				continue
			var mine := float(slot.wall_offset)
			var theirs := float(slot.right_extend)
			var side := BuildingMass.DIRS.find(BuildingKitAssembler.right_of(int(slot.dir)))
			var edge: Vector3i = slot.edge
			theirs = float(offsets.get(BuildingMass.edge_key(Vector2i(edge.x, edge.y), side), 0.0))
			if mine > 0.0 and theirs > 0.0 and absf(mine - theirs) > 1e-6:
				return false
	return true


func test_unequal_steps_never_meet_at_a_convex_corner() -> void:
	for options: Dictionary in [{}, {"character": _all_faces()}, {"lone": true}]:
		assert_true(_corners_consistent(FIXTURE.build(options).front), str(options))


## Geometry, independent of guardrails and crowns: two faces written directly.
func _wrapped_pair() -> Dictionary:
	var kit := SuntailBuildingKit.create()
	var mass := FIXTURE.house(&"kit.fixture.front", Rect2i(0, 0, 3, 2), 4, 3)
	var chains := GROWTH.face_chains(mass, Callable(FIXTURE, "nothing_solid"), Callable(FIXTURE, "street"))
	var profile: Array[float] = [1.0, 2.0, 2.0]
	for chain: Dictionary in chains:
		if int(chain.dir) == 3: # south: west end (right) wraps, east end (left) returns
			GROWTH.apply(mass, kit, chain, profile, [[&"return", &"wrap"], [&"return", &"wrap"], [&"return", &"wrap"]])
		elif int(chain.dir) == 2: # west: south end (left) wraps, north end returns
			GROWTH.apply(mass, kit, chain, profile, [[&"wrap", &"return"], [&"wrap", &"return"], [&"wrap", &"return"]])
	return {"kit": kit, "mass": mass, "parts": BuildingKitAssembler.new(kit).assemble(mass)}


func _within(parts: Array, prefix: String, y0: float) -> Array:
	var catalog := EnvironmentCatalog.load_default()
	return parts.filter(func(p: Dictionary) -> bool:
		var box: AABB = p.transform * catalog.descriptor(p.asset_id).measured_aabb
		return String(p.role).begins_with(prefix) and box.position.y >= y0 - 1.2 and box.position.y <= y0 + 2.9)


func test_a_wrapped_corner_is_closed_by_strips_squares_and_a_post() -> void:
	var w := _wrapped_pair()
	var catalog := EnvironmentCatalog.load_default()
	for index in range(1, 4):
		var lean := minf(float(index), 2.0)
		var suffix := BuildingKitAssembler.lean_suffix(lean)
		var y0 := float((w.mass as BuildingMass).storeys[index].floor_band) * 1.5
		assert_eq(_within(w.parts, "frontage.corner." + suffix, y0).size(), 2,
			"floor and ceiling square at the one wrapped (south-west) corner")
		assert_eq(_within(w.parts, "frontage.return." + suffix, y0).size(), 4,
			"two side returns (the open ends) and two extension strips (the wrapped ends)")
		var posts := _within(w.parts, "post.timber", y0).filter(func(p: Dictionary) -> bool:
			var c: Vector3 = (p.transform * catalog.descriptor(p.asset_id).measured_aabb).get_center()
			return absf(c.x + lean) < 0.3 and absf(c.z + lean) < 0.3)
		assert_eq(posts.size(), 1, "one post at the moved south-west corner (-lean, -lean)")
		for square: Dictionary in _within(w.parts, "frontage.corner." + suffix, y0):
			var box: AABB = square.transform * catalog.descriptor(square.asset_id).measured_aabb
			assert_almost_eq(box.position.x, -lean, 0.01)
			assert_almost_eq(box.end.x, 0.0, 0.01)
			assert_almost_eq(box.position.z, -lean, 0.01)
			assert_almost_eq(box.end.z, 0.0, 0.01)


func test_extension_strips_are_flush_with_their_face() -> void:
	var w := _wrapped_pair()
	var catalog := EnvironmentCatalog.load_default()
	var y0 := float((w.mass as BuildingMass).storeys[1].floor_band) * 1.5
	var south_face := INF
	for part: Dictionary in _within(w.parts, "wall.timber.", y0):
		var box: AABB = part.transform * catalog.descriptor(part.asset_id).measured_aabb
		if box.get_center().z < -0.5 and box.size.x > box.size.z:
			south_face = minf(south_face, box.position.z)
	assert_lt(south_face, 0.0, "found the stepped south wall panels")
	var strips := _within(w.parts, "frontage.return.d100", y0).filter(func(p: Dictionary) -> bool:
		var box: AABB = p.transform * catalog.descriptor(p.asset_id).measured_aabb
		return box.size.x > box.size.z and box.get_center().x < 0.0)
	assert_eq(strips.size(), 1, "the south face's strip running on past the west corner")
	var strip: AABB = strips[0].transform * catalog.descriptor(strips[0].asset_id).measured_aabb
	assert_almost_eq(strip.position.z, south_face, 0.01, "outer faces coplanar")
	assert_almost_eq(strip.position.x, -1.0, 0.02, "it runs the step's depth past the old corner")


func test_right_extend_is_zero_without_growth() -> void:
	var mass := FIXTURE.house(&"kit.plain", Rect2i(0, 0, 3, 2), 3, 3)
	for storey: Dictionary in mass.storeys:
		for slot: Dictionary in BuildingKitAssembler.storey_slots(storey):
			assert_eq(float(slot.right_extend), 0.0)
```

`tests/test_growth_front_family.gd` — in the `match role:` block add

```gdscript
				&"frontage.corner":
					assert_almost_eq(box.size.x, depth, 0.001, String(id))
					assert_almost_eq(box.size.z, depth, 0.001, String(id))
					assert_almost_eq(box.get_center().x, 0.0, 0.001, String(id))
					assert_almost_eq(box.get_center().z, 0.0, 0.001, String(id))
```

Re-pin: add `"lone": true` to every `FIXTURE.build` options dictionary in `tests/test_growing_floors.gd` and `tests/test_growing_floors_guardrails.gd` (tests of one face; their expectations stay as Task 4 pinned them), except `test_skywalk_portal_face_never_leans_but_other_face_does`'s second build (`g`, which is about other faces and keeps its assertions), `test_reserved_column_keeps_the_face_flush` and `test_neighbour_at_a_face_end_keeps_the_face_flush` (unchanged: the south face stays flush either way).

- [ ] **Step 2: Run and see them fail.** Focused tests `test_growing_floors_wrap.gd` and `test_growth_front_family.gd`: expected `Nonexistent function 'apply'`, missing `closures` / `right_extend`, missing `frontage.corner.*` roles; with `"lone"` added, `test_growing_floors.gd` and `test_growing_floors_guardrails.gd` still pass (the option is inert before fronts pull corner neighbours).

- [ ] **Step 3: Bake the corner squares.** In `export_growth_front_manifest.gd`, inside the depth loop after the floor entry:

```gdscript
		var corner := _entry(template["town.frontage.floor"], "town.frontage.corner." + suffix,
			FLOOR, "z", half, false)
		corner.erase("clip_ranges")
		if half * 2.0 < 2.0 - 0.0001: # Floor_2 is 2.0 x 2.0: clip both axes to d x d
			corner.clip_ranges = {"x": [-half, half], "z": [-half, half]}
		kept.append(corner)
```

and print `GROWTH_FRONTS ` with `GROWTH.LEAN_DEPTHS.size() * 4`. Add `&"frontage.corner"` to `KitGrowingFronts.FRONT_ROLES`, and `"corner"` to the part list of the growth role loop in `SuntailBuildingKit.gd` (~line 158). Then run Task 2 Step 6's four commands (exporter → `GROWTH_FRONTS 24`; `environment_bake.gd --manifest .../town_room_fronts.json` → EXIT 0; `bake_town_frame_variants.gd`; `--import`), and `git status --short terrain/environment` to list the generated files (restore any unrelated pruned files, as Task 2 recorded). Run `test_growth_front_family.gd` → green.

- [ ] **Step 4: Assembler.** `storey_slots`, inside the slot loop after the centre shift:

```gdscript
		# A wrapped convex corner: the face to the right steps out too, so this face's
		# corner (and its post) lies that much further along. 0 without growth.
		slot["right_extend"]=0.0
		if bool(slot.right_convex):
			var side:=BuildingMass.DIRS.find(right_of(int(slot.dir)))
			var edge:Vector3i=slot.edge
			slot["right_extend"]=float(offsets.get(BuildingMass.edge_key(Vector2i(edge.x,edge.y),side),0.0))
```

(Room projections never offset two faces of one storey, so `right_extend` is 0 in every town at zero growth.) In `_emit_corner_post` replace `right * 0.5` by `right * (0.5 + float(slot.get("right_extend", 0.0)))`. In `_emit_projected_front` replace the side-return loop with:

```gdscript
		var closures:Array=projection.get("closures",[&"return",&"return"])
		for side:int in [-1,1]:
			var centre:Vector2=centres.front() if side<0 else centres.back()
			match StringName(closures[0 if side<0 else 1]):
				&"return":
					var at:=centre+right*.5*side+out*depth*.5/kit.module_width
					var yaw:=yaw_for_dir(dir)+PI*.5*side
					_emit(ctx,_front_role(&"frontage.return",projection),at,y,yaw,0,Transform3D.IDENTITY,storey.get("tint",Color.WHITE))
					_emit(ctx,_front_role(&"frontage.return_beam",projection),at,y,yaw)
					_emit(ctx,_front_role(&"frontage.return_beam",projection),at,y+kit.storey_height-.143,yaw)
				&"wrap":
					_emit_wrap_end(ctx,storey,projection,centre,side,y)
				_:
					pass # joint / bury (Tasks 6, 7): the neighbouring face continues the wall
```

and add:

```gdscript
## Native offset (along the face's outward normal) that makes a wrap strip's outer
## face coplanar with the face's wall panels; measured in Task 5 Step 6.
const WRAP_INSET := 0.0


## A wrapped convex corner: the face's wall runs on `depth` past its last module (a
## baked return strip turned to face out) with its floor beam; the face whose RIGHT
## end the corner is also lays the corner floor and ceiling squares (one owner).
func _emit_wrap_end(ctx: Dictionary, storey: Dictionary, projection: Dictionary,
		centre: Vector2, side: int, y: float) -> void:
	var dir := int(projection.dir)
	var depth := float(projection.depth)
	var w := kit.module_width
	var out := Vector2(BuildingMass.DIRS[dir])
	var right := Vector2(right_of(dir))
	var yaw := yaw_for_dir(dir)
	var strip := centre + right * side * (0.5 + depth * 0.5 / w) + out * (depth + WRAP_INSET) / w
	_emit(ctx, _front_role(&"frontage.return", projection), strip, y - OFFSET_WALL_DROP, yaw, 0,
		Transform3D.IDENTITY, storey.get("tint", Color.WHITE))
	_emit(ctx, _front_role(&"frontage.return_beam", projection), strip, y, yaw)
	if side > 0:
		var corner := centre + right * (0.5 + depth * 0.5 / w) + out * depth * 0.5 / w
		_emit(ctx, _front_role(&"frontage.corner", projection), corner, y, yaw)
		_emit(ctx, _front_role(&"frontage.corner", projection), corner, y + kit.storey_height - .12772, yaw)
```

In `face_parts`, after building `offsets`, give a wrapped right end its partner's offset so the candidate's corner post stands where the final one will:

```gdscript
	var closures: Array = projection.get("closures", [&"return", &"return"])
	if StringName(closures[1]) == &"wrap":
		var dir := int(projection.dir)
		var last: Vector2 = (projection.centres as Array).back()
		var cell := Vector2i((last - Vector2(BuildingMass.DIRS[dir]) * .5 - Vector2.ONE * .5).round())
		var side := BuildingMass.DIRS.find(right_of(dir))
		offsets[BuildingMass.edge_key(cell, side)] = float(projection.depth) / kit.module_width
```

- [ ] **Step 5: Fronts in `KitGrowingFronts.gd`.** Replace the chain loop in `fit` (after `ctx.obstacles = ...`) with:

```gdscript
	var members: Array[Dictionary] = []
	for mass: BuildingMass in masses:
		if not mass.grows or not kits.has(_own(mass)):
			continue
		var kit: BuildingKit = kits[_own(mass)]
		if not kit.has_role(StringName("frontage.return.%s" % BuildingKitAssembler.lean_suffix(STEP_SIZES[0]))):
			continue
		for chain: Dictionary in face_chains(mass, solid, street):
			var knob := STREET_FACE_KNOB if bool(chain.street) else OTHER_FACE_KNOB
			members.append({"mass": mass, "chain": chain, "kit": kit,
				"seed": character.chance(knob, String(chain.key))})
	for front: Dictionary in fronts(members):
		_fit_front(front, character, ctx, leans)
```

and add:

```gdscript
## The lattice vertex at one end of a chain's run.
static func _point(chain: Dictionary, at_end: bool) -> Vector2i:
	var along := int(chain.end) if at_end else int(chain.start)
	return Vector2i(int(chain.line), along) if int(chain.dir) % 2 == 0 else Vector2i(along, int(chain.line))


## Joins between candidate faces: two faces of one house that meet at a convex
## corner of the first upper storey (same first band) wrap (Task 6 adds joints).
static func _joins(members: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for a in members.size():
		for b in range(a + 1, members.size()):
			var ca: Dictionary = members[a].chain
			var cb: Dictionary = members[b].chain
			if members[a].mass != members[b].mass or int(ca.dir) % 2 == int(cb.dir) % 2 \
					or int(ca.first_band) != int(cb.first_band):
				continue
			for a_end: bool in [false, true]:
				for b_end: bool in [false, true]:
					if _point(ca, a_end) == _point(cb, b_end) \
							and bool(ca.end_convex if a_end else ca.start_convex) \
							and bool(cb.end_convex if b_end else cb.start_convex):
						out.append({"a": a, "a_end": a_end, "b": b, "b_end": b_end, "kind": &"wrap"})
	return out


## Seeds and their direct join partners; one front per connected component that
## holds a seed (pulling is one hop: a partner pulls nothing further unless it is a
## seed itself). Members sorted by chain key (the first is the leader).
static func fronts(members: Array[Dictionary]) -> Array[Dictionary]:
	var joins := _joins(members)
	var keep := {}
	for m in members.size():
		if bool(members[m].seed):
			keep[m] = true
	for join: Dictionary in joins:
		if bool(members[join.a].seed):
			keep[join.b] = true
		if bool(members[join.b].seed):
			keep[join.a] = true
	var root := {}
	for m: int in keep:
		root[m] = m
	var find := func(m: int, self_ref: Callable) -> int:
		return m if int(root[m]) == m else int(self_ref.call(int(root[m]), self_ref))
	for join: Dictionary in joins:
		if keep.has(join.a) and keep.has(join.b):
			root[find.call(join.a, find)] = find.call(join.b, find)
	var groups := {}
	for m: int in keep:
		var r: int = find.call(m, find)
		if not groups.has(r):
			groups[r] = []
		(groups[r] as Array).append(m)
	var out: Array[Dictionary] = []
	for r: int in groups:
		var ids: Array = groups[r]
		if not ids.any(func(m: int) -> bool: return bool(members[m].seed)):
			continue
		ids.sort_custom(func(x: int, y: int) -> bool:
			return String(members[x].chain.key) < String(members[y].chain.key))
		var index := {}
		var front_members: Array[Dictionary] = []
		for m: int in ids:
			index[m] = front_members.size()
			front_members.append(members[m])
		var front_joins: Array[Dictionary] = []
		for join: Dictionary in joins:
			if index.has(join.a) and index.has(join.b):
				front_joins.append({"a": index[join.a], "a_end": join.a_end, "b": index[join.b],
					"b_end": join.b_end, "kind": join.kind})
		out.append({"members": front_members, "joins": front_joins})
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return String(x.members[0].chain.key) < String(y.members[0].chain.key))
	return out


## One front. The leader (first active member) sets the step its kit carries and the
## cap; a member that leaves the front is dropped and the rest refit (the leader may
## change). Members that left are fitted alone afterwards if they were seeds.
static func _fit_front(front: Dictionary, character: TownCharacter, ctx: Dictionary,
		out: Array[Dictionary]) -> void:
	var active: Array[int] = []
	for m in (front.members as Array).size():
		active.append(m)
	var left: Array[int] = []
	var leans: Array[float] = []
	while not active.is_empty():
		var step := _front_step(front.members[active[0]], character, ctx)
		if not STEP_SIZES.has(step):
			return
		var cap := step * float(mini(MAX_STEPS, floori(character.value(CAP_KNOB) / step + 0.0001)))
		var result := _front_profile(front, active, step, cap, ctx)
		if int(result.leaves) < 0:
			leans = result.leans
			break
		active.erase(int(result.leaves))
		left.append(int(result.leaves))
	for m: int in active:
		var member: Dictionary = front.members[m]
		var profile: Array[float] = []
		var closures: Array = []
		for k in (member.chain.storeys as Array).size():
			profile.append(leans[k])
			ctx.lean = leans[k]
			closures.append(_closures(front, active, m, k, ctx))
		ctx.kit = member.kit
		_commit(member.mass, member.kit, member.chain, profile, ctx, out, closures)
	for m: int in left:
		if bool(front.members[m].seed):
			_fit_front({"members": [front.members[m]], "joins": []}, character, ctx, out)


## The step a leader carries (Task 8 adds the eave fallback here).
static func _front_step(leader: Dictionary, character: TownCharacter, _ctx: Dictionary) -> float:
	return carried_step(leader.kit, float(String(character.pick(STEP_KNOB, String(leader.mass.stable_id)))))


## Monotone cumulative steps for a fixed set of active members (index k = k-th
## storey above the shared first upper storey). A failing step is withdrawn for the
## whole front (every member holds). Returns {leans, leaves: -1}, or {leaves: m} when
## member m cannot hold a storey, or cannot take the first step while others are
## active (it leaves; the caller refits). A lone member that cannot hold drops the
## cap one step and refits (no inward ledge).
static func _front_profile(front: Dictionary, active: Array[int], step: float, cap: float,
		ctx: Dictionary) -> Dictionary:
	var depth := 0
	for m: int in active:
		depth = maxi(depth, (front.members[m].chain.storeys as Array).size())
	var leans: Array[float] = []
	leans.resize(depth)
	leans.fill(0.0)
	var face_cap := cap
	var k := 0
	while k < depth:
		var held := 0.0 if k == 0 else leans[k - 1]
		var want := minf(float(k + 1) * step, face_cap)
		var fault := _front_fault(front, active, k, want, held, ctx) if want > held else {"held": true}
		if fault.is_empty():
			leans[k] = want
			k += 1
			continue
		if not fault.has("held"):
			_reject(ctx, front, fault, k, want)
		face_cap = held
		if held <= 0.0:
			if active.size() > 1 and fault.has("member"):
				return {"leaves": int(fault.member)}
			break
		var hold := _front_fault(front, active, k, held, held, ctx)
		if hold.is_empty():
			leans[k] = held
			k += 1
			continue
		_reject(ctx, front, hold, k, held)
		if active.size() > 1:
			return {"leaves": int(hold.member)}
		face_cap = held - step
		leans.fill(0.0)
		k = 0
	return {"leans": leans, "leaves": -1}


## The first active member present at storey k that fails, as {member, cause}, or {}.
static func _front_fault(front: Dictionary, active: Array[int], k: int, lean: float, base: float,
		ctx: Dictionary) -> Dictionary:
	for m: int in active:
		var member: Dictionary = front.members[m]
		if k >= (member.chain.storeys as Array).size():
			continue
		ctx.kit = member.kit
		var closures := _closures(front, active, m, k, ctx)
		var cause := &"ends" if closures.has(&"blocked") \
			else _fault(member.mass, member.chain, k, lean, base, ctx, closures)
		if cause != &"":
			return {"member": m, "cause": cause}
	return {}


static func _reject(ctx: Dictionary, front: Dictionary, fault: Dictionary, k: int, lean: float) -> void:
	ctx.rejections.append({"chain": String(front.members[int(fault.member)].chain.key),
		"storey": k, "lean": lean, "cause": fault.cause})


## [left, right] closure kinds of member m at storey k (left = the centres.front()
## end; a piece's right points along +along for dirs 1 and 2).
static func _closures(front: Dictionary, active: Array[int], m: int, k: int, ctx: Dictionary) -> Array:
	var start := _end_kind(front, active, m, false, k, ctx)
	var end := _end_kind(front, active, m, true, k, ctx)
	var dir := int(front.members[m].chain.dir)
	return [start, end] if dir == 1 or dir == 2 else [end, start]


## How one end closes at storey k: a join to an active member present at k gives
## its kind; otherwise &"return" where the end is open, else &"blocked".
static func _end_kind(front: Dictionary, active: Array[int], m: int, at_end: bool, k: int,
		ctx: Dictionary) -> StringName:
	for join: Dictionary in front.joins:
		var partner := -1
		if int(join.a) == m and bool(join.a_end) == at_end:
			partner = int(join.b)
		elif int(join.b) == m and bool(join.b_end) == at_end:
			partner = int(join.a)
		if partner >= 0 and active.has(partner) \
				and k < (front.members[partner].chain.storeys as Array).size():
			return StringName(join.kind)
	var member: Dictionary = front.members[m]
	return &"return" if _end_open(member.mass, member.chain, at_end, k, ctx) else &"blocked"


## The former guardrail 4, per end: the run at storey k is the chain's run and
## convex at this end, nothing stands beside or diagonally beyond it, and the
## perpendicular face at this corner does not step.
static func _end_open(mass: BuildingMass, chain: Dictionary, at_end: bool, k: int, ctx: Dictionary) -> bool:
	var storey: Dictionary = mass.storeys[chain.storeys[k]]
	var dir := int(chain.dir)
	var convex := false
	for run: Dictionary in BuildingKitAssembler.boundary_runs(storey.cells):
		if int(run.dir) == dir and int(run.line) == int(chain.line) \
				and int(run.start) == int(chain.start) and int(run.end) == int(chain.end):
			convex = bool(run.end_convex if at_end else run.start_convex)
	if not convex:
		return false
	var along := Vector2i(0, 1) if dir % 2 == 0 else Vector2i(1, 0)
	var sign := 1 if at_end else -1
	var cell := BuildingKitAssembler._inside_cell(dir, int(chain.line),
		int(chain.end) - 1 if at_end else int(chain.start))
	var perp := BuildingMass.DIRS.find(along * sign)
	if float((storey.get("wall_offsets", {}) as Dictionary).get(BuildingMass.edge_key(cell, perp), 0.0)) > 0.0:
		return false
	var side := cell + along * sign
	var diagonal: Vector2i = side + BuildingMass.DIRS[dir]
	var solid: Callable = ctx.solid
	var own := _own(mass)
	for b in [int(storey.floor_band), int(storey.floor_band) + 1]:
		if bool(solid.call(own, side, b)) or bool(solid.call(own, diagonal, b)) \
				or mass.cells_at_band(b).has(diagonal):
			return false
	return true
```

`_assembler` sets `external_blocked` only when `solid.is_valid()` (tests call `apply` without a town). `_fault` gains a trailing `closures: Array = [&"return", &"return"]` parameter, drops its `_ends_clear` check (ends are now `_front_fault`'s), and passes `closures` to `_candidate`, which stores `projection["closures"] = closures`. Delete `_ends_clear` and `_profile`. Split `_commit` into the public writer and the bookkeeping:

```gdscript
## Writes one face's steps into its house (wall offsets, projection with closures,
## storey growth, decor on the face moved out) and returns the candidates.
static func apply(mass: BuildingMass, kit: BuildingKit, chain: Dictionary, profile: Array[float],
		closures: Array, solid := Callable()) -> Array[Dictionary]:
```

`apply` holds the storey-writing body of Task 4's `_commit` (offsets, projections, `growth`, the decor move) with `_candidate(mass, kit, chain, k, lean, base, solid, closures[k])`; `_commit(mass, kit, chain, profile, ctx, out, closures)` runs the yield removal first, then `apply(..., ctx.solid)`, then the registry, obstacles and `out` records (adding `"closures": closures[k]` to each record).

- [ ] **Step 6: Measure `WRAP_INSET`.** Run `test_growing_floors_wrap.gd::test_extension_strips_are_flush_with_their_face` with `-gunit_test_name=test_extension_strips_are_flush_with_their_face`; the failure message prints `strip.position.z` and `south_face`. Set `WRAP_INSET := strip.position.z - south_face` rounded to 1 mm, sign as printed (a positive value moves the strip outward). Re-run: green.

- [ ] **Step 7: Run to pass.** `test_growing_floors_wrap.gd` (7 passing), `test_growth_front_family.gd`, `test_growing_floors.gd`, `test_growing_floors_guardrails.gd`, `test_growing_floors_knobs.gd`, `test_october3_room_projections.gd` (all green).

- [ ] **Step 8: Render check of a wrapped corner.** Copy the Diagnosis 2 render script out of the ledger (`cp .superpowers/sdd/2026-10-08-growing-upper-floors/task-4-diag-kit-step-render.gd /tmp/wrap_render.gd`), make it write the south and west faces exactly as `_wrapped_pair` does (`GROWTH.apply` with the same profile and closures) instead of its own offsets, and run `godot --path . --log-file /tmp/wr.log -s /tmp/wrap_render.gd -- --output docs/qa/2026-10-08-growing-floors/task5-wrap > /tmp/wr.out 2>&1` (GUI run). Inspect the south-west corner from outside, from the side and from below: one post at the moved corner, no slit between strip and face, squares under and over the corner, braces only under module centres. The images stay on disk (gitignored); note what they show in the task report.

- [ ] **Step 9: Gates and count.** Fingerprint gate → `FINGERPRINT_MATCH`; growth-on smoke → 0 `FINGERPRINT_NO_TOWN`; `test_town_old_look.gd` passes; growth corpus count: record `GROWTH_TOTAL` and the number of `wrap` closures (add `wraps` = count of lean records with a `wrap` closure to `counts()` in the harness). Target: faces above Task 4's count (the 17 "perpendicular face already leans" withdrawals of Diagnosis 2 can now step); report per-cause counts.

- [ ] **Step 10: Commit** `KitGrowingFronts.gd`, `BuildingKitAssembler.gd`, `SuntailBuildingKit.gd`, the exporter, the manifest, every generated `terrain/environment/**` file of the corner family, the fixture, the harness, `test_growing_floors_wrap.gd`, `test_growth_front_family.gd`, `test_growing_floors.gd`, `test_growing_floors_guardrails.gd`: message "Towns: growing floors wrap round convex corners (fronts, corner squares)" + trailer.

---

### Task 6: Coplanar terrace rows step out as one

Amendment Decision 4(a): a coplanar side-by-side neighbour (facades in line, touching) steps out together over the storeys both have; side pieces only at the row's open ends. A growing face pulls its coplanar neighbours' faces into its row (one hop); the neighbour house need not have rolled growth but must be eligible and pass every guardrail.

**Files:**
- Modify: `scripts/terrain/features/villages/kit/KitGrowingFronts.gd` (`fit` takes candidate faces from every eligible house, seeds only from growing houses; `_joins` adds coplanar `joint`s; `_front_fault` publishes riders; `_parts_fault` lets the row's facade pieces ride and the row's ornaments yield)
- Modify: `scripts/terrain/features/villages/kit/BuildingKitAssembler.gd` (nothing new: `_emit_projected_front` already emits no pieces for a `joint` end — confirm in Step 4)
- Modify: `tests/test_growing_floors_guardrails.gd` (`test_neighbour_at_a_face_end_keeps_the_face_flush` superseded)
- Test: `tests/test_growing_floors_rows.gd`

**Interfaces:**
- Consumes: Task 5 `fronts`, `_joins`, `_front_fault`, `_closures`, `_end_kind`, `apply`; Task 4 `_parts_fault`, `_face_slab`, `YIELD_DECOR`, obstacle `host`.
- Produces: join kind `&"joint"`; `ctx.riders: Array[Dictionary]` (`{"owner": StringName, "slab": AABB}`, the faces of the other active members at the storey being tested); members of non-growing houses (`seed` false) in fronts; a pulled house is written exactly like a growing one (`wall_offsets`, `projections`, `growth`) and keeps `grows == false` (its designer choices were made before fitting).

Joint rule: two faces of DIFFERENT houses join when they have the same `dir` and `line`, one run's end vertex is the other's start vertex, both are convex there in their own cells, and both chains have the same `first_band` (the same first upper storey; rows on stepped ground do not join). A joint holds at storey k only while both members are active and both have storey k; above the shorter member the taller face's end closes by its own rule (return or withdraw).

- [ ] **Step 1: Write the failing tests** `tests/test_growing_floors_rows.gd`:

```gdscript
extends GutTest
## Terrace rows (spec amendment Decision 4a).
const FIXTURE := preload("res://tests/fixtures/growing_house.gd")
const GROWTH := preload("res://scripts/terrain/features/villages/kit/KitGrowingFronts.gd")


func _record(f: Dictionary, host: StringName, band: int) -> Dictionary:
	for lean: Dictionary in f.leans:
		if lean.host == host and int(lean.dir) == 3 and int(lean.band) == band:
			return lean
	return {}


func _row() -> Dictionary:
	# front (x 0..2) and side (x 3..4) share the south line z = 0; the columns west of
	# the row (x -1) and east of it (x 5) are reserved, so the row is just the two faces.
	var side := FIXTURE.roofed(&"kit.fixture.side", Rect2i(3, 0, 2, 2), 4, 3)
	var f := FIXTURE.build({"extra": [side], "reserved_x": [-1, 5]})
	f["side"] = side
	return f


func test_a_terrace_row_steps_out_as_one() -> void:
	var f := _row()
	assert_false(f.side.grows, "the neighbour did not roll growth: the row pulled it")
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 1.0, 2.0, 2.0] as Array[float])
	assert_eq(FIXTURE.leans_on(f.side, 3), [0.0, 1.0, 2.0, 2.0] as Array[float])
	for band: int in [2, 4, 6]:
		assert_eq(_record(f, &"kit.fixture.front", band).closures, [&"joint", &"return"],
			"front: east end joined, west end open (band %d)" % band)
		assert_eq(_record(f, &"kit.fixture.side", band).closures, [&"return", &"joint"],
			"side: east end open, west end joined (band %d)" % band)


func test_row_ends_close_only_at_the_open_ends() -> void:
	var f := _row()
	var catalog := EnvironmentCatalog.load_default()
	var assembler := BuildingKitAssembler.new(f.kit)
	assembler.external_blocked = func(cell: Vector2i, band: int) -> bool:
		return bool(f.solid.call(&"fixture.side", cell, band))
	var parts: Array = (f.parts as Array) + assembler.assemble(f.side)
	for part: Dictionary in parts:
		if not String(part.role).begins_with("frontage.return."):
			continue
		var box: AABB = part.transform * catalog.descriptor(part.asset_id).measured_aabb
		assert_false(absf(box.get_center().x - 6.0) < 0.3, "no return at the shared joint x = 6")
	var returns := parts.filter(func(p: Dictionary) -> bool:
		return String(p.role).begins_with("frontage.return.") and not String(p.role).begins_with("frontage.return_beam"))
	assert_eq(returns.size(), 6, "two open row ends x three stepped storeys")


func test_a_row_member_that_cannot_step_withdraws_the_joint_not_the_town() -> void:
	# The neighbour's second upper storey carries a portal: it cannot step, so the row
	# cannot either (the front's end would return into the neighbour's flush facade).
	var side := FIXTURE.roofed(&"kit.fixture.side", Rect2i(3, 0, 2, 2), 4, 3)
	var edge := BuildingMass.edge_key(Vector2i(3, 0), 3)
	side.storeys[2].openings[edge] = BuildingMass.OPENING_DOOR
	side.storeys[2]["passage_edges"] = {edge: true}
	var f := FIXTURE.build({"extra": [side], "reserved_x": [-1, 5]})
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 0.0, 0.0, 0.0] as Array[float])
	assert_eq(FIXTURE.leans_on(side, 3), [0.0, 0.0, 0.0, 0.0] as Array[float])
	assert_false((f.parts as Array).is_empty(), "the house still builds")
	var causes := (f.result.rejections as Array).map(func(r: Dictionary) -> StringName: return r.cause)
	assert_true(causes.has(&"portal") and causes.has(&"ends"), str(causes))


func test_rows_join_only_on_the_same_first_upper_storey() -> void:
	var side := FIXTURE.roofed(&"kit.fixture.side", Rect2i(3, 0, 2, 2), 4, 3)
	for storey: Dictionary in side.storeys:
		storey.floor_band = int(storey.floor_band) + 1 # the neighbour stands half a storey up
	side.ground_band = 1
	var none := Callable(FIXTURE, "nothing_solid")
	var street := Callable(FIXTURE, "street")
	var members: Array[Dictionary] = []
	for mass: BuildingMass in [FIXTURE.house(&"kit.fixture.front", Rect2i(0, 0, 3, 2), 4, 3), side]:
		for chain: Dictionary in GROWTH.face_chains(mass, none, street):
			if int(chain.dir) == 3:
				members.append({"mass": mass, "chain": chain, "kit": null, "seed": true})
	assert_eq(GROWTH.fronts(members).size(), 2, "different first bands: two fronts, no joint")
```

In `tests/test_growing_floors_guardrails.gd` delete `test_neighbour_at_a_face_end_keeps_the_face_flush` (superseded by `test_a_terrace_row_steps_out_as_one`; a coplanar neighbour now steps with the face).

- [ ] **Step 2: Run and see them fail.** Focused test `test_growing_floors_rows.gd`: expected the side flush (never a candidate) and the front flush (end `blocked`), and `fronts` returning one front per member.

- [ ] **Step 3: Candidates from every eligible house.** In `fit`, replace the member loop with:

```gdscript
	var members: Array[Dictionary] = []
	for mass: BuildingMass in masses:
		if not kits.has(_own(mass)) or String(mass.stable_id).contains("wall-room"):
			continue
		var kit: BuildingKit = kits[_own(mass)]
		if not kit.has_role(StringName("frontage.return.%s" % BuildingKitAssembler.lean_suffix(STEP_SIZES[0]))):
			continue
		for chain: Dictionary in face_chains(mass, solid, street):
			var knob := STREET_FACE_KNOB if bool(chain.street) else OTHER_FACE_KNOB
			# Only growing houses seed a front (and only they draw face rolls).
			members.append({"mass": mass, "chain": chain, "kit": kit,
				"seed": mass.grows and character.chance(knob, String(chain.key))})
```

(The early return `if character == null or not masses.any(... m.grows)` stays first, so zero growth computes no chains.) In `_joins` add the coplanar case after the corner case, inside the same pair loop:

```gdscript
			if members[a].mass != members[b].mass and int(ca.dir) == int(cb.dir) \
					and int(ca.line) == int(cb.line) and int(ca.first_band) == int(cb.first_band):
				for a_end: bool in [false, true]:
					var b_end := not a_end
					if _point(ca, a_end) == _point(cb, b_end) \
							and bool(ca.end_convex if a_end else ca.start_convex) \
							and bool(cb.end_convex if b_end else cb.start_convex):
						out.append({"a": a, "a_end": a_end, "b": b, "b_end": b_end, "kind": &"joint"})
```

and guard the corner case with `members[a].mass == members[b].mass` (it already requires it). `fronts` needs no change: membership is still seeds plus direct partners.

- [ ] **Step 4: The row's own pieces ride, the row's ornaments yield.** In `_front_fault`, before testing member m at storey k, publish the other active members' faces:

```gdscript
		var riders: Array[Dictionary] = []
		for other: int in active:
			if other == m or k >= (front.members[other].chain.storeys as Array).size():
				continue
			var partner: Dictionary = front.members[other]
			var probe := _candidate(partner.mass, partner.kit, partner.chain, k, lean, base, ctx.solid)
			riders.append({"owner": (partner.mass as BuildingMass).stable_id, "slab": _face_slab(probe, partner.kit)})
		ctx.riders = riders
```

(set `ctx.riders = []` in `fit`, and back to `[]` after the member loop). In `_parts_fault`, before the own-house branch:

```gdscript
			if obstacle.owner != mass.stable_id and _rides_with_row(obstacle, ctx):
				if obstacle.has("decor") and StringName(obstacle.decor.kind) in YIELD_DECOR \
						and not _rider_slab(obstacle, ctx).has_point((obstacle.bounds as AABB).get_center()):
					if not yields.has(obstacle):
						yields.append(obstacle)
				continue
```

with

```gdscript
## The stepping face of the active row member that owns this obstacle (empty when
## the owner is not an active member at this storey).
static func _rider_slab(obstacle: Dictionary, ctx: Dictionary) -> AABB:
	for rider: Dictionary in ctx.get("riders", []):
		if rider.owner == obstacle.owner:
			return rider.slab
	return AABB()


## A piece of another active row member's house on that member's face at this storey
## (wall, post, trim, window box at the joint) steps with the row; that house's
## ornaments under the row's braces yield like the host's own (Decision 6, extended
## to the row).
static func _rides_with_row(obstacle: Dictionary, ctx: Dictionary) -> bool:
	var slab := _rider_slab(obstacle, ctx)
	if not slab.has_volume():
		return false
	return slab.has_point((obstacle.bounds as AABB).get_center()) \
		or (obstacle.has("decor") and StringName(obstacle.decor.kind) in YIELD_DECOR)
```

Factor the riders loop into `_publish_riders(front: Dictionary, active: Array[int], m: int, k: int, lean: float, base: float, ctx: Dictionary) -> void` and call it from `_front_fault` and from `_commit`'s yield probe (Task 4), so the yields removed at commit are exactly those the fit accepted: `_fit_front` passes `front`, `result.active` and the member index to `_commit` (new trailing parameters `front := {}`, `active: Array[int] = []`, `m := -1`; a lone face passes none and publishes no riders). (A row member's ornament on its own stepping face rides; one on a lower storey under the row's braces yields and is removed at commit through `obstacle.host`, Task 4.) Confirm in `BuildingKitAssembler._emit_projected_front` that a `joint` end emits nothing (the `_:` branch from Task 5).

- [ ] **Step 5: Run to pass.** `test_growing_floors_rows.gd` (4 passing); re-run `test_growing_floors_wrap.gd`, `test_growing_floors_guardrails.gd`, `test_growing_floors.gd`, `test_growing_floors_knobs.gd` (green).

- [ ] **Step 6: Gates and count.** Fingerprint gate → `FINGERPRINT_MATCH`; growth-on smoke → 0 `FINGERPRINT_NO_TOWN`; `test_town_old_look.gd` passes. Growth corpus count with `joints` (lean records with a `joint` closure) added to `counts()`: target faces at least 4 above Task 5's count (Diagnosis 2: the coplanar terrace alone took 18 → 22 faces); report per-cause counts and the number of pulled (non-growing) houses that stepped (add `pulled` = distinct hosts in `growth` whose mass has `grows == false`).

- [ ] **Step 7: Commit** `KitGrowingFronts.gd`, the harness, `test_growing_floors_rows.gd`, `test_growing_floors_guardrails.gd`: message "Towns: terrace rows step out as one (coplanar joints)" + trailer.

---

### Task 7: Inside-corner run-into (bury against a plain wall)

Amendment Decision 4(b): where a stepped end meets a perpendicular wall at an inside corner, the end is run into that wall and buried — no visible return — only where the measured part of the wall it meets is plain. Ruling: the same rule covers the house's own wing (a concave run end; Diagnosis 2 counted 25 concave ends and 27 own wings in front), since the geometry and the plainness test are identical.

**Files:**
- Modify: `scripts/terrain/features/villages/kit/KitGrowingFronts.gd` (`_end_kind` returns `&"bury"`; new `_bury_contact`, `PLAIN_CONTACT`, `BURY_DROP`; `_parts_fault` skips the buried contact; `_end_open` untouched)
- Modify: `scripts/terrain/features/villages/kit/BuildingKitAssembler.gd` (only if Step 5 measures a slit: `_emit_abut`, `ABUT_GAP`)
- Modify (only if Step 5 measures a slit): `tools/environment_bake/export_growth_front_manifest.gd`, the manifest, `SuntailBuildingKit.gd`, generated catalog files
- Test: `tests/test_growing_floors_bury.gd`

**Interfaces:**
- Consumes: Task 5 `_end_kind`, `_closures`, `_front_fault`; Task 4 `contact_clear`, obstacle records (`owner`, `role`, `bounds`).
- Produces: closure kind `&"bury"`; `KitGrowingFronts._bury_contact(mass, chain, at_end, k, lean, ctx) -> Array` (the wall's obstacle records the end runs into, or `[]` when the end cannot be buried); `ctx.buried: Array` (contacts of the member being tested, skipped by `_parts_fault`); `const PLAIN_CONTACT: Array[String]`.

Bury geometry, at the end of a member's run at storey k with step `lean`:
- Neighbour inside corner: the cell beside the end (`side`) is open at the storey's bands and the cell diagonally beyond it (`side + out`) is another building's solid at both bands.
- Own inside corner: the run's end is concave at storey k (the house's own cells at `side` and `side + out`).
- Contact box: the wall plane through the end vertex, from the face line out to `lean`, from `floor - BURY_DROP` (the kit brace drop, `jetty_depth`) to the storey's top, 0.05 behind the plane to 0.35 into the wall.
- Plain: every obstacle of the wall's owner whose box meets the contact box (deeper than `TOUCH`) has a role in `PLAIN_CONTACT` (`wall.timber.plain`, `wall.stone.plain`, `post.`, `trim.floor_beam`), and at least one of them is a `wall.` panel. A window, door, bay, roof/eave, balcony, deck, rail, ivy, window box, sign or any other part makes the end `blocked` (the step is withdrawn, rule c).

- [ ] **Step 1: Write the failing tests** `tests/test_growing_floors_bury.gd`:

```gdscript
extends GutTest
## Inside-corner run-into (spec amendment Decision 4b).
const FIXTURE := preload("res://tests/fixtures/growing_house.gd")
const GROWTH := preload("res://scripts/terrain/features/villages/kit/KitGrowingFronts.gd")


## A five-storey neighbour standing in the lane beyond the front's east end
## (cells x 3..4, z -2..-1): its west wall meets the front's south face line at x 3.
func _corner(plain: bool) -> BuildingMass:
	var corner := FIXTURE.roofed(&"kit.fixture.corner", Rect2i(3, -2, 2, 2), 5, 0)
	if plain:
		for storey: Dictionary in corner.storeys:
			for z: int in [-1, -2]:
				storey.openings[BuildingMass.edge_key(Vector2i(3, z), 2)] = BuildingMass.OPENING_PLAIN
	return corner


func _east_closure(f: Dictionary, band: int) -> StringName:
	for lean: Dictionary in f.leans:
		if lean.host == f.front.stable_id and int(lean.dir) == 3 and int(lean.band) == band:
			return lean.closures[0] # dir 3: left = the east end
	return &""


func test_inside_corner_end_is_buried_in_a_plain_wall() -> void:
	var f := FIXTURE.build({"extra": [_corner(true)], "lone": true})
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 1.0, 2.0, 2.0] as Array[float])
	for band: int in [2, 4, 6]:
		assert_eq(_east_closure(f, band), &"bury", "band %d" % band)
	var catalog := EnvironmentCatalog.load_default()
	for part: Dictionary in f.parts:
		if not String(part.role).begins_with("frontage.return"):
			continue
		var box: AABB = part.transform * catalog.descriptor(part.asset_id).measured_aabb
		assert_false(absf(box.get_center().x - 6.0) < 0.3 and box.get_center().z < 0.0,
			"no return piece at the buried end")


func test_inside_corner_against_a_window_withdraws_the_step() -> void:
	var f := FIXTURE.build({"extra": [_corner(false)], "lone": true})
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 0.0, 0.0, 0.0] as Array[float])
	var causes := (f.result.rejections as Array).map(func(r: Dictionary) -> StringName: return r.cause)
	assert_true(causes.has(&"ends"), str(causes))


func test_a_buried_end_meets_the_wall_without_a_slit() -> void:
	var f := FIXTURE.build({"extra": [_corner(true)], "lone": true})
	var catalog := EnvironmentCatalog.load_default()
	var y0 := float(f.front.storeys[1].floor_band) * 1.5
	var panel_end := -INF
	for part: Dictionary in f.parts:
		var box: AABB = part.transform * catalog.descriptor(part.asset_id).measured_aabb
		if String(part.role).begins_with("wall.timber.") and box.get_center().z < -0.5 \
				and box.position.y >= y0 - 1.0 and box.position.y <= y0 + 1.0:
			panel_end = maxf(panel_end, box.end.x)
	var assembler := BuildingKitAssembler.new(f.kit)
	var wall_start := INF
	for part: Dictionary in assembler.assemble(f.masses.back()):
		var box: AABB = part.transform * catalog.descriptor(part.asset_id).measured_aabb
		if String(part.role).begins_with("wall.") and box.get_center().x < 7.0 \
				and box.position.y >= y0 - 1.0 and box.position.y <= y0 + 1.0:
			wall_start = minf(wall_start, box.position.x)
	print("GROWTH_ABUT_GAP %.4f" % (wall_start - panel_end))
	assert_true(wall_start - panel_end <= 0.01, "the stepped wall reaches the plain wall it runs into")
```

(`f.masses.back()` is the corner house: `extra` masses are appended last.)

- [ ] **Step 2: Run and see them fail.** Focused test `test_growing_floors_bury.gd`: expected the plain case flush (end `blocked`), the window case already green, the slit test failing on an empty panel set.

- [ ] **Step 3: The bury rule in `KitGrowingFronts.gd`.**

```gdscript
## Wall pieces a stepped end may run into (anything else on the wall withdraws the step).
const PLAIN_CONTACT: Array[String] = ["wall.timber.plain", "wall.stone.plain", "post.", "trim.floor_beam"]
## The contact reaches below the floor by the kit brace's drop.
const BURY_DROP := 1.0


## The plain wall an end runs into at storey k, as the owner's obstacle records
## the contact box meets, or [] when this end cannot be buried.
static func _bury_contact(mass: BuildingMass, chain: Dictionary, at_end: bool, k: int, lean: float,
		ctx: Dictionary) -> Array:
	var storey: Dictionary = mass.storeys[chain.storeys[k]]
	var dir := int(chain.dir)
	var along := Vector2i(0, 1) if dir % 2 == 0 else Vector2i(1, 0)
	var sign := 1 if at_end else -1
	var cell := BuildingKitAssembler._inside_cell(dir, int(chain.line),
		int(chain.end) - 1 if at_end else int(chain.start))
	var side := cell + along * sign
	var diagonal: Vector2i = side + BuildingMass.DIRS[dir]
	var band := int(storey.floor_band)
	var solid: Callable = ctx.solid
	var own := _own(mass)
	# Own inside corner: the run turns outward (the house's wing stands beside and
	# in front of the end). Neighbour inside corner: open beside, a building in front.
	var concave := mass.cells_at_band(band).has(side) and mass.cells_at_band(band).has(diagonal)
	if not concave:
		for b in [band, band + 1]:
			if bool(solid.call(own, side, b)) or mass.cells_at_band(b).has(side) \
					or not bool(solid.call(own, diagonal, b)):
				return []
	var kit: BuildingKit = ctx.kit
	var vertex := Vector2(_point(chain, at_end)) * kit.module_width
	var out := Vector2(BuildingMass.DIRS[dir])
	var y0 := band * kit.band_height()
	var near := vertex - Vector2(along) * sign * 0.05
	var far := vertex + Vector2(along) * sign * 0.35 + out * lean
	var box := AABB(Vector3(minf(near.x, far.x), y0 - BURY_DROP, minf(near.y, far.y)),
		Vector3(absf(far.x - near.x), kit.storey_height + BURY_DROP, absf(far.y - near.y)))
	var contact: Array = []
	var walls := 0
	for obstacle: Dictionary in ctx.obstacles:
		if bool(obstacle.get("gone", false)) or contact_clear(box, obstacle.bounds):
			continue
		# The wall run into is the own wing (concave) or anything not the host.
		if (obstacle.owner == mass.stable_id) != concave:
			continue
		var plain := false
		for prefix: String in PLAIN_CONTACT:
			plain = plain or String(obstacle.role).begins_with(prefix)
		if not plain:
			return []
		if String(obstacle.role).begins_with("wall."):
			walls += 1
		contact.append(obstacle)
	return contact if walls > 0 else []
```

The host's own stepping-face pieces at the old plane meet the box by at most 0.05 along the run (≤ `TOUCH`), so they never count. Confirm first that the Suntail kit has the plain roles (`SuntailBuildingKit.create().has_role(&"wall.timber.plain")`); if a material has no plain panel the assembler falls back to its window panel and such walls are never plain (correctly: a window is drawn). In `_end_kind`, replace the final line with:

```gdscript
	var member: Dictionary = front.members[m]
	if _end_open(member.mass, member.chain, at_end, k, ctx):
		return &"return"
	var contact := _bury_contact(member.mass, member.chain, at_end, k, float(ctx.get("lean", 0.0)), ctx)
	if not contact.is_empty():
		(ctx.buried as Array).append_array(contact)
		return &"bury"
	return &"blocked"
```

`_front_fault` sets `ctx.lean = lean` and `ctx.buried = []` before computing a member's closures; `_parts_fault` skips any obstacle in `ctx.buried` (the plain wall the end runs into, and its posts and beams; contact with it is the bury). `_commit`'s closures come from `_fit_front` via `_closures`, which must see the committed lean: set `ctx.lean = profile[k]` before each `_closures` call there.

- [ ] **Step 4: Assembler.** A `bury` end already emits nothing (Task 5's `_:` branch). The final assembly still emits the end's corner post where the slot is right-convex; it stands inside the wall it runs into (hidden).

- [ ] **Step 5: Measure the abutment.** Run `test_growing_floors_bury.gd`; read `GROWTH_ABUT_GAP` from `/tmp/t.out`.
  - If the gap is ≤ 0.01 (expected: Suntail wall panels span their full module, so the stepped wall's end panel reaches the cell boundary where the neighbour's wall stands), no piece is needed: record the value in the task report and continue.
  - If the gap is > 0.01, bake an abutment family: in `export_growth_front_manifest.gd` add, per depth, `town.frontage.abut_floor.dNNN` (Floor_2 clipped to `[-g/2, g/2]` on x and `[-d/2, d/2]` on z) and once `town.frontage.abut` (Wall_Start_10x30_0 clipped to `[-g/2, g/2]` on x, pivot `[-g/2, 0, 0]`), with `g` = the measured gap rounded up to 1 cm; add the roles to `SuntailBuildingKit.gd`; set `const ABUT_GAP := g` in `BuildingKitAssembler.gd`; and in `_emit_projected_front`'s `&"bury"` branch emit the wall strip at `centre + right * side * (0.5 + ABUT_GAP * 0.5 / w) + out * (depth + WRAP_INSET) / w` (yaw `yaw_for_dir(dir)`, y `y - OFFSET_WALL_DROP`) and the floor and ceiling strips at `centre + right * side * (0.5 + ABUT_GAP * 0.5 / w) + out * depth * 0.5 / w` (y and `y + kit.storey_height - .12772`). Run the Task 2 Step 6 bake commands, then re-run the test: the gap test measures to the abutment strip's end and passes.

- [ ] **Step 6: Run to pass.** `test_growing_floors_bury.gd` (3 passing); re-run `test_growing_floors_rows.gd`, `test_growing_floors_wrap.gd`, `test_growing_floors_guardrails.gd`, `test_growing_floors.gd` (green).

- [ ] **Step 7: Gates and count.** Fingerprint gate → `FINGERPRINT_MATCH`; growth-on smoke → 0 `FINGERPRINT_NO_TOWN`; `test_town_old_look.gd` passes. Growth corpus count with `buried` (lean records with a `bury` closure) added to `counts()`: target faces above Task 6's count (Diagnosis 2: 26 inside corners against another house, 12 against tunnel crowns, 25 concave ends); report per-cause counts.

- [ ] **Step 8: Commit** `KitGrowingFronts.gd`, the harness, `test_growing_floors_bury.gd` (plus, only in the slit branch, the assembler, exporter, manifest, kit and generated catalog files): message "Towns: a stepped end runs into a plain perpendicular wall (inside corners)" + trailer.

---

### Task 8: Roofs follow the step (gable shift, eave cap, gable-front boost)

The original Task 5, adapted to the amendment: kit steps (a 2.0 top step moves a gable end a full module), fronts (every member's top storey must be closed above; a member whose crown cannot cover the front's step leaves the front), and the eave finding. The Suntail cornice reaches 0.986 native m beyond the wall line and dips 0.6 m at its tip, so no kit jetty (1.0) can pass under an eave: an eave-crowned leader falls back to the 0.5 step when the measured allowance admits it, otherwise eave-crowned faces stay flush (cause `crown`). Consequence, measured in Task 9 and reported to the owner: outer-corner wraps and rows reach a top storey only where every member's crown is a gable end that can move.

**Files:**
- Modify: `scripts/terrain/features/villages/kit/KitGrowingFronts.gd` (`fit` gains `roof_geometry: Dictionary = {}`; `_fault` gains `_crown_fault` as its last check; `_commit` writes the wing lean; `_fit_front` eave fallback; `_publish_riders` records each rider's crown; new `roof_geometry`, `crown_wing`, `eave_allowance`, `_gable_shift_ok`, constants `EAVE_MARGIN`, `EAVE_COVER`, `EAVE_SAMPLE`)
- Modify: `scripts/terrain/features/villages/kit/BuildingKitAssembler.gd` (`_assemble_roof` lines 847–955: record first part, call `_lean_roof_end`; new `roof_parts`, `_lean_roof_end`)
- Modify: `scripts/terrain/features/villages/kit/BuildingDesigner.gd` (member `gable_front_boost`; `articulate`; `_square_axis` lines 616–622)
- Modify: `scripts/terrain/features/villages/kit/KitVillageBuildings.gd` (pass `GROWTH.roof_geometry(house_kits.values() + [kit])` to `GROWTH.fit`)
- Modify: `tests/fixtures/growing_house.gd` (pass `GROWTH.roof_geometry([kit])`)
- Modify: `tests/harness/suntail/building_gallery.gd` (`--growth step:cap`, option parsing lines 18–30, per-mass loop lines 108–112)
- Modify (re-pins, Step 9): `tests/test_growing_floors_guardrails.gd`, `tests/test_growing_floors_wrap.gd`
- Test: `tests/test_growing_floors_roofs.gd`

**Interfaces:**
- Consumes: `KitRoofMeshUnion._load_geometry(kit, geometry: Dictionary, loaded: Dictionary)`, `KitRoofMeshUnion.clip_volumes(wing: Dictionary, kit) -> Array[Dictionary]`, `KitRoofMeshUnion.prepare(roofs, walls, kit) -> Dictionary`, `KitRoofMeshUnion.realize(placement, ctx) -> Dictionary`, `BuildingKitAssembler.tight_eave_sides(wing) -> int`, `kit.anchor(role)`, `kit.asset_anchor(id)`, catalog `measured_aabb`.
- Produces: rejection cause `&"crown"`; rider key `"crown": int` (the partner's crown `union_index`); wing keys `lean_min` / `lean_max: float` (native m); placement keys `lean_end: bool`, `lean_filler: bool`; `BuildingKitAssembler.roof_parts(mass, wing) -> Array[Dictionary]`; `KitGrowingFronts.roof_geometry(kits: Array) -> Dictionary`, `crown_wing(mass, chain, k) -> Dictionary`, `eave_allowance(kit, catalog, geometry, wing, side: int) -> float`; `BuildingDesigner.gable_front_boost: float`.

Measurements this task relies on (catalog, October 8): Suntail eave `suntail.roof.roof_1_cornice_red` measured_aabb z −2.111..0.986 (outer reach 0.986 m beyond the wall line), y −0.599..3.119 (the cornice dips 0.6 m below the wall head at its tip); Pure `pure_village.roof.eave` z −2.276..1.072. The allowance therefore scans the baked roof geometry for the cornice's top surface over a leaned wall head, bounded by the measured reach.

- [ ] **Step 1: Write the failing tests** `tests/test_growing_floors_roofs.gd`:

```gdscript
extends GutTest
const FIXTURE := preload("res://tests/fixtures/growing_house.gd")
const GROWTH := preload("res://scripts/terrain/features/villages/kit/KitGrowingFronts.gd")
const UNION := preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd")


func _causes(f: Dictionary) -> Array:
	return (f.result.rejections as Array).map(func(r: Dictionary) -> StringName: return r.cause)


func test_gable_end_moves_out_with_the_top_storey_and_the_gap_is_filled() -> void:
	var f := FIXTURE.build({"roof_axis": 1, "lone": true})
	var wing: Dictionary = f.front.roofs[0]
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 1.0, 2.0, 2.0] as Array[float])
	assert_almost_eq(float(wing.get("lean_min", 0.0)), 2.0, 1e-6, "front face is the min end")
	var shifted := (f.parts as Array).filter(func(p: Dictionary) -> bool: return bool(p.get("lean_end", false)))
	var fillers := (f.parts as Array).filter(func(p: Dictionary) -> bool: return bool(p.get("lean_filler", false)))
	assert_gt(shifted.size(), 0)
	assert_gt(fillers.size(), 0)
	assert_true(shifted.any(func(p: Dictionary) -> bool: return String(p.role).begins_with("gable.")))
	# Fillers keep only the 2.0 m strip between the last middle piece and the moved end.
	var ctx := UNION.prepare(f.front.roofs, [], f.kit)
	var seam := (0.0 + 0.5) * 2.0
	for filler: Dictionary in fillers:
		var realized := UNION.realize(filler, ctx)
		assert_false(realized.is_empty(), "filler is trimmed by its clip volumes")
		for mesh: Dictionary in realized.meshes:
			for v: Vector3 in mesh.vertices:
				assert_between(v.z, seam - 2.0 - 0.002, seam + 0.002)


func test_eave_face_top_step_stays_under_the_measured_cornice() -> void:
	var f := FIXTURE.build({"roof_axis": 0, "lone": true})
	var wing: Dictionary = f.front.roofs[0]
	var allowance := GROWTH.eave_allowance(f.kit, EnvironmentCatalog.load_default(),
		GROWTH.roof_geometry([f.kit]), wing, 1)
	assert_lt(allowance, 0.986 - f.kit.wall_face)
	assert_lt(allowance, 1.0, "no kit jetty passes under the Suntail cornice")
	# The leader falls back to the light step; the top storey is capped under the
	# eave and, with no inward step allowed, every storey holds that cap.
	var q := 0.5 * floorf(allowance / 0.5 + 0.0001)
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, q, q, q] as Array[float])
	assert_false(wing.has("lean_min"), "an eave never moves")
	if q == 0.0:
		assert_true(_causes(f).has(&"crown"), str(_causes(f)))


func test_unshiftable_gable_end_keeps_the_face_flush() -> void:
	for blocker: String in ["open", "verge", "tight", "dormer", "caps"]:
		var options := {"roof_axis": 1, "lone": true, "prepare": func(front: BuildingMass) -> void:
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


func test_a_wrapped_front_keeps_only_the_faces_its_roof_covers() -> void:
	# Ridge along z: south and north are gable ends (they move), east and west are
	# eaves (a kit jetty cannot pass under them): those two leave the front.
	var f := FIXTURE.build({"character": FIXTURE.character({&"growth_other_face_chance": 1.0})})
	for dir: int in [3, 1]:
		assert_eq(FIXTURE.leans_on(f.front, dir), [0.0, 1.0, 2.0, 2.0] as Array[float], "gable face %d" % dir)
	for dir: int in [0, 2]:
		assert_eq(FIXTURE.leans_on(f.front, dir), [0.0, 0.0, 0.0, 0.0] as Array[float], "eave face %d" % dir)
	assert_true(_causes(f).has(&"crown"), str(_causes(f)))


func test_terrace_row_gables_move_together() -> void:
	var side := FIXTURE.roofed(&"kit.fixture.side", Rect2i(3, 0, 2, 2), 4, 3)
	var f := FIXTURE.build({"extra": [side], "reserved_x": [-1, 5]})
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 1.0, 2.0, 2.0] as Array[float])
	assert_eq(FIXTURE.leans_on(side, 3), [0.0, 1.0, 2.0, 2.0] as Array[float])
	assert_almost_eq(float(f.front.roofs[0].get("lean_min", 0.0)), 2.0, 1e-6)
	assert_almost_eq(float(side.roofs[0].get("lean_min", 0.0)), 2.0, 1e-6)


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
			if not _blocks(obstacle, mass, int(wing.get("union_index", -1))) \
					or contact_clear(box, obstacle.bounds) or _moves_with_front(obstacle, ctx):
				continue
			return false
	return true


## A piece that is not in the way of a moved gable end: a row partner's own moving
## roof end (its crown wing; it steps with the row), or a plain wall this member's
## end is buried in (KitRoofMeshUnion trims roof triangles at walls).
static func _moves_with_front(obstacle: Dictionary, ctx: Dictionary) -> bool:
	for rider: Dictionary in ctx.get("riders", []):
		if rider.owner == obstacle.owner and int(obstacle.get("roof_index", -1)) == int(rider.get("crown", -2)):
			return true
	for contact: Dictionary in ctx.get("buried", []):
		if contact.owner == obstacle.owner:
			for prefix: String in PLAIN_CONTACT:
				if String(obstacle.role).begins_with(prefix):
					return true
	return false


# G7 and the crown rule: the last storey of a face must be closed above its step.
static func _crown_fault(mass: BuildingMass, chain: Dictionary, k: int, lean: float,
		ctx: Dictionary) -> StringName:
	if k < (chain.storeys as Array).size() - 1:
		return &"" # the next storey of the chain steps at least as far
	var wing := crown_wing(mass, chain, k)
	if wing.is_empty():
		return &"crown"
	var dir := int(chain.dir)
	if int(wing.axis) == dir % 2:
		return &"" if _gable_shift_ok(mass, chain, wing, lean, ctx) else &"crown"
	return &"" if lean <= _eave_cap(wing, dir, ctx) + 0.0001 else &"crown"


static func _eave_cap(wing: Dictionary, dir: int, ctx: Dictionary) -> float:
	var side := 0 if dir < 2 else 1
	var key := "%s|%s|%d|%d" % [ctx.kit.kit_id, wing.colour, side, BuildingKitAssembler.tight_eave_sides(wing)]
	if not (ctx.allowances as Dictionary).has(key):
		ctx.allowances[key] = eave_allowance(ctx.kit, ctx.catalog, ctx.geometry, wing, side)
	return float(ctx.allowances[key])
```

In `_fault`, after the parts check: `return _crown_fault(mass, chain, k, lean, ctx)` (the parts cause, when non-empty, still returns first). In `_publish_riders` (Task 6) add `"crown": crown_index(partner.mass, partner.chain, k)` to each rider. `_front_step` gains the eave fallback (it runs again whenever the leader changes, so a front whose gable-crowned leader left is re-stepped by its new leader):

```gdscript
## The step a leader carries. A kit jetty cannot pass under an eave: an eave-crowned
## leader takes the light step where the measured cornice admits it (else its crown
## withdraws the step).
static func _front_step(leader: Dictionary, character: TownCharacter, ctx: Dictionary) -> float:
	var step := carried_step(leader.kit, float(String(character.pick(STEP_KNOB, String(leader.mass.stable_id)))))
	if step > 0.5:
		ctx.kit = leader.kit
		var top := (leader.chain.storeys as Array).size() - 1
		var wing := crown_wing(leader.mass, leader.chain, top)
		if not wing.is_empty() and int(wing.axis) != int(leader.chain.dir) % 2 \
				and _eave_cap(wing, int(leader.chain.dir), ctx) < step:
			step = 0.5
	return step
```

In `_commit`, after the storey loop:

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

- [ ] **Step 6: Run to pass.** `test_growing_floors_roofs.gd` (7 passing); re-run `test_growing_floors.gd` (the gable-front lone fixture keeps `[0, 1, 2, 2]`), `test_growing_floors_rows.gd`, `test_growing_floors_bury.gd` (the plain-wall case keeps `[0, 1, 2, 2]`: its moved gable end meets only the plain wall it is buried in; if it fails on the corner house's wall, check `_moves_with_front`), `test_roof_proportion.gd`, `test_october3_room_projections.gd`.

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

Then render `godot --path . --log-file /tmp/gal.log -s res://tests/harness/suntail/building_gallery.gd -- --set designer --count 9 --seed 4 --close --growth 1.0:2.0 --output docs/qa/2026-10-08-growing-floors/roofs` (GUI run) and inspect the `b*_c*` closes: no wall head above a cornice, no gap or doubled tiles at a moved gable end, barge boards on the moved gable.

- [ ] **Step 8: Re-pin earlier tests to the crown rule.**
  - `tests/test_growing_floors_guardrails.gd::test_footprint_change_ends_the_face_chain`: expectation `[0.0, 0.0, 0.0, 0.0]`, message "storey 2 stands on the stepped strip without stepping: an uncovered ledge, so the face stays flush (crown)".
  - `tests/test_growing_floors_wrap.gd::test_a_growing_face_pulls_its_corner_neighbours_one_hop` (default fixture: ridge along z, so east and west are eave faces): south `[0, 1, 2, 2]` with closures `[&"return", &"return"]`; east, west and north flush; the rejections hold `crown` for the east and west chains (`"kit.fixture.front|0:3:0:2"`, `"kit.fixture.front|2:0:0:2"`) — they were pulled and left.
  - `tests/test_growing_floors_wrap.gd::test_all_four_faces_wrap_into_a_ring`: delete (superseded by `test_a_wrapped_front_keeps_only_the_faces_its_roof_covers`).
  - `tests/test_growing_floors_wrap.gd::test_a_member_that_cannot_hold_leaves_the_front`: east and west flush, south and north `[0, 1, 2, 2]`, south closures `[&"return", &"return"]`, causes hold `portal` and `crown`.
  - The `apply`-based geometry tests of `test_growing_floors_wrap.gd` and `test_unequal_steps_never_meet_at_a_convex_corner` are unchanged.
  Run all growth test files: green.

- [ ] **Step 9: Gates and count.** Fingerprint gate → `FINGERPRINT_MATCH`; growth-on smoke → 0 `FINGERPRINT_NO_TOWN`; `test_town_old_look.gd` passes; growth corpus count: report faces, `crown` withdrawals split by gable/eave crown (add `crown_eave` / `crown_gable` to `counts()` from the rejection's chain and the host's crown wing), wraps, joints, buried. The face total may fall below Task 7's (the crown rule is new); Diagnosis 2 counted 38 own-roof withdrawals.

- [ ] **Step 10: Commit** the five code files, the gallery harness, fixture, the harness and the four test files: message "Towns: growing floors follow their roof (gable shift, eave cap, gable-front boost)" + trailer.

### Task 9: Corpus audit and edge cases

The original Task 6, adapted: the audit checks every closure kind, the harness from Task 4 gains the violation counts, and the edge cases add the wrap, row and bury cases. Measurable targets come from `task-4-report.md` Diagnosis 2 (8 fingerprint towns, `growing_house_chance = 1`, both face chances 1): 183 candidate faces; 18 stepping faces with the three fixes; 22 with the coplanar terrace.

**Files:**
- Create: `tests/fixtures/growth_audit.gd`
- Modify: `tests/harness/suntail/growth_corpus_audit.gd` (violation counts per town; `bad` counts violations)
- Test: `tests/test_growing_floors_corpus.gd`, `tests/test_growing_floors_edges.gd`

**Interfaces:**
- Consumes: `KitVillageBuildings.build(...)` keys `growth`, `growth_rejections`, `houses`, `house_kits`, `walls`, `masses`; `KitGrowingFronts.gap_ok`, `crown_wing`, `eave_allowance`, `roof_geometry`, `PLAIN_CONTACT`; `BuildingKitAssembler.face_parts`, `storey_slots`; `KitFloatingMassAudit.audit(spatial, fabric, masses).count`; `tests/fixtures/kit_roof_public_air_audit.gd`.audit(built, kit).intrusions.
- Produces: `growth_audit.audit(spatial: WarrenSpatialPlan, fabric: SettlementFabricPlan, built: Dictionary, kit: BuildingKit, character: TownCharacter) -> Dictionary` with int keys `faces, air_hits, gap_failures, open_returns, open_corners, broken_joints, buried_on_ornament, unfloored, beyond_roof, floating, roof_intrusions`; `growth_audit.VIOLATIONS: Array[String]` (every key except `faces`); harness rows gain those keys, `GROWTH_AUDIT_DONE bad=<violations + null towns + invalid payloads>`.

- [ ] **Step 1: Write the audit fixture** `tests/fixtures/growth_audit.gd`:

```gdscript
extends RefCounted
## Growing-floor corpus audit (spec "Testing" + amendment): every count except `faces` must be 0.
const GROWTH := preload("res://scripts/terrain/features/villages/kit/KitGrowingFronts.gd")
const CLEARANCE := preload("res://scripts/terrain/features/villages/kit/KitPublicClearance.gd")
const VIOLATIONS: Array[String] = ["air_hits", "gap_failures", "open_returns", "open_corners",
	"broken_joints", "buried_on_ornament", "unfloored", "beyond_roof", "floating", "roof_intrusions"]


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
	var by_id := {}
	for mass: BuildingMass in houses:
		by_id[mass.stable_id] = mass
	var solid := func(own: StringName, cell: Vector2i, band: int) -> bool:
		for mass: BuildingMass in houses:
			if StringName(String(mass.stable_id).trim_prefix("kit.")) != own and mass.cells_at_band(band).has(cell):
				return true
		return false
	var geometry := GROWTH.roof_geometry((built.house_kits as Dictionary).values() + [kit])
	var out := {"faces": 0}
	for key: String in VIOLATIONS:
		out[key] = 0
	var gap := character.value(GROWTH.GAP_KNOB) if character != null else 0.75
	var all_parts := {}
	for mass: BuildingMass in houses:
		var own := StringName(String(mass.stable_id).trim_prefix("kit."))
		var own_kit: BuildingKit = (built.house_kits as Dictionary).get(own, kit)
		var assembler := BuildingKitAssembler.new(own_kit)
		all_parts[mass.stable_id] = assembler.assemble(mass)
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
				var closures: Array = projection.get("closures", [&"return", &"return"])
				if count.call("frontage.return." + suffix) != closures.count(&"return") + closures.count(&"wrap"):
					out.open_returns += 1
				if count.call("frontage.floor." + suffix) != 2 * (projection.centres as Array).size():
					out.unfloored += 1
				if StringName(closures[1]) == &"wrap" and count.call("frontage.corner." + suffix) != 2:
					out.open_corners += 1
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
	out.open_corners += _unequal_corners(houses)
	out.broken_joints = _broken_joints(built.growth, by_id)
	out.buried_on_ornament = _buried_on_ornament(built.growth, by_id, all_parts, kit, catalog)
	out.floating = KitFloatingMassAudit.audit(spatial, fabric, built.masses).count
	out.roof_intrusions = preload("res://tests/fixtures/kit_roof_public_air_audit.gd").audit(built, kit).intrusions
	return out


## The stepped strip is covered by the next storey's equal-or-larger step, by a moved
## gable end of the same step, or stays within the measured eave allowance.
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


## Convex corners where both faces step but unequally (an open corner).
static func _unequal_corners(houses: Array) -> int:
	var bad := 0
	for mass: BuildingMass in houses:
		for storey: Dictionary in mass.storeys:
			var offsets: Dictionary = storey.get("wall_offsets", {})
			for slot: Dictionary in BuildingKitAssembler.storey_slots(storey):
				if not bool(slot.right_convex):
					continue
				var mine := float(slot.wall_offset)
				var theirs := float(slot.right_extend)
				if mine > 0.0 and theirs > 0.0 and absf(mine - theirs) > 1e-6:
					bad += 1
	return bad


## A joint whose partner face (same dir and line, touching end) does not step equally.
static func _broken_joints(growth: Array, by_id: Dictionary) -> int:
	var bad := 0
	for lean: Dictionary in growth:
		if not (lean.closures as Array).has(&"joint"):
			continue
		var partner_equal := false
		for other: Dictionary in growth:
			if other.host != lean.host and int(other.dir) == int(lean.dir) \
					and int(other.band) == int(lean.band) and (other.closures as Array).has(&"joint") \
					and absf(float(other.lean) - float(lean.lean)) < 1e-6:
				partner_equal = true
		if not partner_equal:
			bad += 1
	return bad


## A buried end whose contact meets anything but plain wall pieces.
static func _buried_on_ornament(growth: Array, by_id: Dictionary, all_parts: Dictionary,
		kit: BuildingKit, catalog: EnvironmentCatalog) -> int:
	var bad := 0
	for lean: Dictionary in growth:
		var closures: Array = lean.closures
		for side in 2:
			if StringName(closures[side]) != &"bury":
				continue
			var bounds: AABB = lean.bounds
			# The buried end's side of the stepped body, grown into the wall by 0.35.
			var dir := int(lean.dir)
			var right := Vector3(BuildingKitAssembler.right_of(dir).x, 0, BuildingKitAssembler.right_of(dir).y)
			var end := bounds.get_center() + right * (bounds.size.dot(right.abs()) * 0.5) * (1 if side == 1 else -1)
			var probe := AABB(end - Vector3(0.2, 0, 0.2), Vector3(0.4, bounds.size.y, 0.4))
			for host: StringName in all_parts:
				if host == lean.host:
					continue
				for part: Dictionary in all_parts[host]:
					var box: AABB = part.transform * catalog.descriptor(part.asset_id).measured_aabb
					if not GROWTH.contact_clear(probe, box) \
							and not GROWTH.PLAIN_CONTACT.any(func(p: String) -> bool: return String(part.role).begins_with(p)):
						bad += 1
	return bad
```

- [ ] **Step 2: Write the tests.** `tests/test_growing_floors_corpus.gd`:

```gdscript
extends GutTest
const AUDIT := preload("res://tests/fixtures/growth_audit.gd")


func test_growth_on_builds_clean_towns() -> void:
	var total := 0
	for town: String in ["7:compact", "103:standard"]:
		var parts := town.split(":")
		var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
		program.town_odds = program.town_odds.with_overrides({&"growing_house_chance": 1.0,
			&"growth_street_face_chance": 1.0, &"growth_other_face_chance": 1.0})
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
		for key: String in AUDIT.VIOLATIONS:
			assert_eq(int(row[key]), 0, "%s %s" % [town, key])
	assert_gt(total, 0, "growth on steps at least one face")
```

`tests/test_growing_floors_edges.gd`:

```gdscript
extends GutTest
const FIXTURE := preload("res://tests/fixtures/growing_house.gd")
const GROWTH := preload("res://scripts/terrain/features/villages/kit/KitGrowingFronts.gd")


func test_house_exactly_at_the_cap() -> void:
	var f := FIXTURE.build({"storeys": 5, "lone": true})
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 1.0, 2.0, 2.0, 2.0] as Array[float],
		"two kit jetties, then every storey holds the cap")
	assert_almost_eq(float(f.front.roofs[0].lean_min), 2.0, 1e-6)


func test_facing_growing_houses_across_one_cell_lane() -> void:
	# Gable fronts across a 2.0 native lane: the facing 1.0 verges already meet
	# mid-lane, so no gable end can move (crown) and, with no inward step allowed,
	# neither face steps. Eave fronts: no kit jetty passes under the cornice. One-cell
	# lanes therefore stay flush; the sky slot holds trivially.
	for axis: int in [1, 0]:
		var f := FIXTURE.build({"facing": true, "back_grows": true, "lone": true,
			"roof_axis": axis, "back_roof_axis": axis})
		var back := FIXTURE.leans_on(f.back, 1)
		var front := FIXTURE.leans_on(f.front, 3)
		for index in range(1, 4):
			assert_true(2.0 - back[index] - front[index] >= 0.75 - 1e-4, "storey %d keeps the sky slot" % index)
		if axis == 1:
			assert_eq(front, [0.0, 0.0, 0.0, 0.0] as Array[float])
			assert_eq(back, [0.0, 0.0, 0.0, 0.0] as Array[float])
			var causes := (f.result.rejections as Array).map(func(r: Dictionary) -> StringName: return r.cause)
			assert_true(causes.has(&"crown"), str(causes))


func test_stepping_face_next_to_a_skywalk_end() -> void:
	var character := FIXTURE.character({&"growth_other_face_chance": 1.0})
	var f := FIXTURE.build({"character": character, "prepare": func(front: BuildingMass) -> void:
		var edge := BuildingMass.edge_key(Vector2i(0, 1), 1)
		front.storeys[3].openings[edge] = BuildingMass.OPENING_DOOR
		front.storeys[3]["passage_edges"] = {edge: true}})
	assert_eq(FIXTURE.leans_on(f.front, 1), [0.0, 0.0, 0.0, 0.0] as Array[float], "skywalk face stays flush")
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 1.0, 2.0, 2.0] as Array[float], "street face unaffected")


func test_merged_compound_house_steps_per_edge_run() -> void:
	# An L of two lots: the front lot's face ends in a concave corner against its own
	# wing, whose wall carries windows (not plain), so it stays flush; the forward
	# lot's face is whole and convex and steps.
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
	var f := FIXTURE.build({"replace_front": mass, "lane": 2, "reserved_x": [-1, 6]})
	for edge: Vector3i in (f.front.storeys[1].get("wall_offsets", {}) as Dictionary):
		if edge.z == 3:
			assert_true(edge.x >= 3, "only the convex forward run steps on the south line")


func test_top_storey_smaller_than_the_one_below() -> void:
	var f := FIXTURE.build({"storeys": 4, "roof_axis": 0, "lone": true, "prepare": func(front: BuildingMass) -> void:
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


func test_row_with_a_shorter_neighbour_joins_only_where_both_have_storeys() -> void:
	var side := FIXTURE.roofed(&"kit.fixture.side", Rect2i(3, 0, 2, 2), 3, 3)
	var f := FIXTURE.build({"extra": [side], "reserved_x": [-1, 5]})
	var front := FIXTURE.leans_on(f.front, 3)
	var short := FIXTURE.leans_on(side, 3)
	for index in range(1, 3):
		assert_true(front[index] == short[index] or short[index] == 0.0,
			"a joint steps equally or not at all (storey %d)" % index)
	for lean: Dictionary in f.leans:
		if lean.host == f.front.stable_id and int(lean.band) == 6:
			assert_ne(lean.closures[0], &"joint", "no joint above the shorter neighbour")
	for index in range(1, front.size()):
		assert_true(front[index] >= front[index - 1], "never an inward step")


func test_inside_corner_bury_and_outer_wrap_never_leave_an_open_end() -> void:
	# Every recorded end closes by exactly one rule.
	for options: Dictionary in [{}, {"character": FIXTURE.character({&"growth_other_face_chance": 1.0})},
			{"lone": true}]:
		var f := FIXTURE.build(options)
		for lean: Dictionary in f.leans:
			for kind: StringName in lean.closures:
				assert_true(kind in [&"return", &"wrap", &"joint", &"bury"], "%s %s" % [str(options), kind])
```

- [ ] **Step 3: Run them.** Focused tests `test_growing_floors_edges.gd` and `test_growing_floors_corpus.gd`. Where an edge case is red, it is a real finding: record it in the ledger, pin the failing geometry red-first in the test of the owning function (`_front_profile`, `_end_kind`, `_bury_contact`, `crown_wing`, `gap_ok`) and fix there; never weaken the edge assertion. The one-cell-lane expectations above follow from the rules (2.0 lane, 0.75 gap, 1.0 steps): if the measured eave/gable crowns change them, recompute them from `gap_ok` and the crown rule and record the reason in the test message (ruling F3).

- [ ] **Step 4: Harness violations.** In `growth_corpus_audit.gd` preload `res://tests/fixtures/growth_audit.gd` as `AUDIT`; per town merge `AUDIT.audit(spatial, fabric, built, kit, profile.character)` into the row (keep `faces`/`storeys`/`causes`/`wraps`/`joints`/`buried`/`pulled`/`crown_*` from `counts()`), add every `AUDIT.VIOLATIONS` value to `bad`, and print the summed violations in `GROWTH_TOTAL`.

- [ ] **Step 5: Run the corpus.**
  1. Fingerprint towns, everything on: `godot --headless --path . --log-file /tmp/ga.log -s res://tests/harness/suntail/growth_corpus_audit.gd -- --odds growing_house_chance=1 --odds growth_street_face_chance=1 --odds growth_other_face_chance=1 --out /tmp/growth_audit_fp.json > /tmp/ga.out 2>&1; echo EXIT $?; grep -E "GROWTH_(TOTAL|AUDIT_DONE)" /tmp/ga.out` → `bad=0`, EXIT 0.
  2. The same with the default face chances (only `--odds growing_house_chance=1`).
  3. Production sample `--towns 1:compact,2:standard,3:standard,4:large,5:compact,6:standard,8:large,9:grand,10:standard,11:compact,12:standard,14:large,15:standard,16:compact,17:large,18:grand` with `--odds growing_house_chance=1` → `bad=0`.
  Targets for run 1, against Diagnosis 2's 18 (fixes) / 22 (terrace) stepping faces: well above 22 stepping faces; report faces, stepped storeys, wraps, joints, buried ends, pulled houses, and withdrawals per cause (portal, columns, gap, air, obstacle.*, ends, crown split into eave/gable, material). Explain any cause that still exceeds 20 faces. If faces are not above 22, stop and report the per-cause table for a controller ruling (never relax a guardrail to reach the number). Fix every violation in the owning guardrail, red-first (pin the town and face in a fixture test), before committing.

- [ ] **Step 6: Fingerprint gate** → `FINGERPRINT_MATCH`; `test_town_old_look.gd` passes.

- [ ] **Step 7: Commit** the audit fixture, harness and both tests: message "Towns: growing-floor corpus audit and edge cases (wrap, row, bury)" + trailer. Save the three run outputs (`/tmp/growth_audit_*.json`) for Task 10's write-up.

---

### Task 10: Shipped defaults, evidence, write-up

The original Task 7, adapted: wrap/row/bury views, the corpus counts from Task 9, and the deviations write-up required by ledger ruling F5 (every deviation from the spec, including the amendment's rulings).

**Files:**
- Modify: `terrain/villages/town_odds.tres` (`growing_house_chance` at_small 0.3, at_large 0.45, spread 0.1)
- Modify: `tests/fixtures/town_old_look.gd` (add `&"growing_house_chance": 0.0`)
- Modify: `tests/harness/suntail/kit_town_review.gd` (`growth` and `wrap` views, ~lines 16, 147, 161, 398)
- Modify: `docs/qa/2026-10-07-town-odds/fingerprint/baseline.json` (re-pinned)
- Create: `docs/qa/2026-10-08-growing-floors/result.md` and render folders `before/`, `after/`, `gallery/`, `audit/`
- Modify: `AGENTS.md` (new top entry)
- Test: `tests/test_growing_floors_knobs.gd` (default assertions), `tests/test_town_old_look.gd`

**Interfaces:**
- Consumes: everything above; `KitVillageBuildings.build(...).growth`.
- Produces: shipped defaults; review views `growth` and `wrap` (kit_town_review); re-pinned fingerprint baseline; result write-up with a deviations section.

- [ ] **Step 1: Update the default test first (red).** In `test_growth_knobs_are_in_the_table_with_their_shipped_values` replace `assert_eq(c.value(GROWTH.HOUSE_KNOB), 0.0)` with `assert_between(c.value(GROWTH.HOUSE_KNOB), lerpf(0.3, 0.45, size) - 0.1, lerpf(0.3, 0.45, size) + 0.1)`; in `test_build_marks_houses_growing_only_when_the_chance_is_positive` keep the explicit `0.0` / `1.0` overrides (it pins the zero path). Run it: fails (`0.0` outside `0.2..0.4`).

- [ ] **Step 2: Review views.** `kit_town_review.gd`: add `static var _growth_views: Array[Dictionary] = []` and `static var _wrap_views: Array[Dictionary] = []`, clear both beside `_projection_views.clear()`, and after the projection loop:

```gdscript
		for lean: Dictionary in built.get("growth", []):
			var direction: Vector2i = BuildingMass.DIRS[int(lean.dir)]
			var right: Vector2i = BuildingKitAssembler.right_of(int(lean.dir))
			var box: AABB = lean.bounds
			for side in 2:
				var kind := StringName((lean.closures as Array)[side])
				if kind in [&"wrap", &"joint", &"bury"]:
					# The end of the stepped body where the wrap/joint/bury is.
					var reach := (box.size.x if right.x != 0 else box.size.z) * 0.5 * (1.0 if side == 1 else -1.0)
					_wrap_views.append({"at": KitVillageBuildings.native_to_lattice(kit) * (box.get_center() + Vector3(right.x, 0, right.y) * reach),
						"direction": Vector3(direction.x, 0, direction.y), "right": Vector3(right.x, 0, right.y),
						"kind": kind, "lean": float(lean.lean)})
			_growth_views.append({"at": KitVillageBuildings.native_to_lattice(kit) * box.get_center(),
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
		if _views.has("wrap"):
			# Side views of wrapped corners, row joints and buried ends: one oblique
			# from the street at eye height, one square-on from the side.
			_wrap_views.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return String(a.kind) + str(a.lean) > String(b.kind) + str(b.lean))
			for index in mini(9, _wrap_views.size()):
				var view: Dictionary = _wrap_views[index]
				var target: Vector3 = town.transform * (view.at as Vector3)
				var outward: Vector3 = (town.transform.basis * (view.direction as Vector3)).normalized()
				var side: Vector3 = (town.transform.basis * (view.right as Vector3)).normalized()
				var eye := target + outward * 7.0 + side * 5.0
				eye.y = town.transform.origin.y + _ground_y + 1.8
				await _shoot(stage, eye, target + Vector3.UP * 2.0,
					"%d_%s_%s%d_street" % [seed_value, scale, view.kind, index], 70)
				await _shoot(stage, target + side * 9.0 + outward * 1.0 + Vector3.UP * 1.0, target,
					"%d_%s_%s%d_side" % [seed_value, scale, view.kind, index], 60)
```

- [ ] **Step 3: Before renders (defaults still 0).** `godot --path . --log-file /tmp/rb.log -s res://tests/harness/suntail/kit_town_review.gd -- --cities 53:grand,31:large,13:standard,43:large,83:grand,103:standard,7:compact,61:standard --views overview,orbit,street,lane --output docs/qa/2026-10-08-growing-floors/before > /tmp/rb.out 2>&1` (GUI run, no `--headless`).

- [ ] **Step 4: Ship the defaults.** `growing_house_chance`: `at_small = 0.3`, `at_large = 0.45`, `spread = 0.1`, notes "… Shipped (task 10)." (`growth_other_face_chance` 0.85, `growth_step` {0.5: 1, 1.0: 3} and `growth_max_lean` 2.0 were set in Task 4.) Add `&"growing_house_chance": 0.0` to `tests/fixtures/town_old_look.gd` `VALUES`. Run `test_growing_floors_knobs.gd` → green.

- [ ] **Step 5: After renders and gallery.** Same cameras: the Step 3 command with `--views overview,orbit,street,lane,growth,wrap --output docs/qa/2026-10-08-growing-floors/after`. Gallery at three knob values: `godot --path . --log-file /tmp/g1.log -s res://tests/harness/suntail/building_gallery.gd -- --set designer --count 9 --seed 4 --close --growth 1.0:2.0 --output docs/qa/2026-10-08-growing-floors/gallery/step100_cap200`, then `--growth 0.5:2.0 --output .../gallery/step050_cap200` and `--growth 1.0:1.0 --output .../gallery/step100_cap100`. Look for: Shambles-style stepped-out fronts on the kit's diagonal braces, facing tops within the sky gap, no wall head through an eave, no gap at a moved gable, every overhang floored and braced, returns closed at open ends only, wrapped corners closed (post at the moved corner, squares under and over, strips flush), row joints seamless (no doubled post or return), buried ends with no slit against the wall they run into. If the `after` towns show no wrap/row/bury at the shipped 0.3–0.45 chance, add one run at `--odds growing_house_chance=1` to `docs/qa/2026-10-08-growing-floors/after_all/` so each closure kind has street and side views. Record any defect red-first (pin seed/face in a fixture test) and fix before continuing.

- [ ] **Step 6: Audits with the new defaults.** `growth_corpus_audit.gd` on the 8 fingerprint towns and the Task 9 production sample with no `--odds` → `bad=0` (save `--out res://docs/qa/2026-10-08-growing-floors/audit/default_fp.json` and `.../default_sample.json`); also the production audit `godot --headless --path . -s res://docs/qa/2026-10-01-town-redesign/prefab-grammar/october6-integrated-checkpoint/unequal-roof-range-study/production-validation/oct7-range-audit-prod.gd.txt` copied to `/tmp/growth_range_audit.gd` and run with `-s /tmp/growth_range_audit.gd -- 53:grand,31:large,13:standard,43:large,83:grand,103:standard` → every row `valid_payload` true, `floating` 0, `roof.intrusions` 0.

- [ ] **Step 7: Fingerprint re-pin and old-look confirmation.**
  1. Source plans must not move: fingerprint gate with `--parts source` → `FINGERPRINT_MATCH` (growth is kit-layer only).
  2. `godot --headless --path . --log-file /tmp/fpw.log -s res://tests/harness/town_fingerprint.gd -- --out res://docs/qa/2026-10-07-town-odds/fingerprint/baseline.json > /tmp/fpw.out 2>&1`, then the full fingerprint gate → `FINGERPRINT_MATCH`.
  3. Zero path still reproduces the old payloads: `... town_fingerprint.gd -- --odds growing_house_chance=0 --out /tmp/fp_zero.json --compare /tmp/growth_fp_ref.json` (or the pre-Task-7 `baseline.json` from `git show HEAD:docs/qa/2026-10-07-town-odds/fingerprint/baseline.json > /tmp/fp_prev.json`) → `FINGERPRINT_MATCH`.
  4. `godot --headless --path . -s res://tests/harness/town_fingerprint.gd -- --old-look --compare res://docs/qa/2026-10-07-town-odds/fingerprint/old_look_baseline.json --parts source` → `FINGERPRINT_MATCH`; focused `test_town_old_look.gd` passes.
  5. Re-run every growth test file plus `test_october3_room_projections.gd`, `test_roof_proportion.gd`, `test_town_odds.gd` → green.

- [ ] **Step 8: Write `docs/qa/2026-10-08-growing-floors/result.md`:**
  - What changed: knobs and defaults; eligibility (any exposed face of a two-storey house); kit-sized steps on `bracket.jetty` (0.5 on `bracket.small`); fronts with `return` / `wrap` / `joint` / `bury` closures; guardrails (air, sky gap, measured neighbours with touch/ride/yield, reserved columns, footprint, portals, crown); roof following.
  - Image table: before/after per town and view, `*_growth*_lane` Shambles views, `*_wrap*` / `*_joint*` / `*_bury*` street and side views, the three gallery sets; one honest sentence per image.
  - Corpus tables from Task 9 and Step 6: stepping faces and storeys per town; wraps, joints, buried ends, pulled houses; withdrawals per cause (crown split eave/gable); every violation count 0; production rows; the comparison with Diagnosis 2 (45 → 183 candidates; 1 → 18 → 22 → this plan's count).
  - Fingerprint/old-look results.
  - **Deviations from the spec (ledger ruling F5)**, each with its reason: the original plan rulings (cap quantisation; monotone profile and cap drop; crown rule; house-wide jetty removal; ordering after towers; street face as a column test; widened G6 and G4; Pure capped roofs keep gable faces flush; projections facing a step keep the sky gap; returns above 1.0 cut from the 2.0 wall start; stone/retaining/fortified storeys never step; one-cell lanes and gable verges; `lane_sky_gap` clamp) and the amendment rulings (0.25 step retired but its pieces stay baked; pulling is one hop; rows pull non-growing eligible neighbours, so more houses step than `growing_house_chance` alone; rows join only on the same first upper storey; a front's step comes from its current leader; a member that cannot hold leaves its front and is refitted alone only if it was a seed; rails, bays and architecture never yield; ornament yield extends to row members; own-wing inside corners bury by the same rule; eave-crowned faces cannot take a kit jetty and fall back to 0.5 or stay flush; a buried gable end may meet only the plain wall it runs into).
  - Limits and open owner questions: eave-to-street faces do not step at kit size (options: a pentice over the top ledge, a baked deeper cornice, insetting the storeys below for one-step houses), so wraps and rows reach the top storey only where every member's crown is a movable gable; the planner is unaware of steps; DAYLIGHT_AIR is not a block (the sky gap protects it).

- [ ] **Step 9: AGENTS.md entry** at the top, one paragraph: "> GROWING UPPER FLOORS (Oct 8, spec `docs/superpowers/specs/2026-10-08-growing-upper-floors-design.md` incl. its owner amendment, result `docs/qa/2026-10-08-growing-floors/result.md`): `KitGrowingFronts` (kit layer only; after towers, before projections/bays in `KitVillageBuildings.build`) steps out any exposed face of a house with two stacked storeys, one kit jetty (1.0 native m on the kit's `bracket.jetty`; 0.5 on `bracket.small`) per storey above the ground storey (`growing_house_chance` 0.3→0.45 spread 0.1, both face chances 0.85, `growth_step` {0.5:1, 1.0:3}, `growth_max_lean` 2.0, `lane_sky_gap` 0.75, `growth_gable_front_boost` 2.0). Faces step as FRONTS: convex corners of one house wrap (strips + `frontage.corner.dNNN` squares + the post moved via `storey_slots` `right_extend`), coplanar neighbours on the same first upper storey step as one row (joints, returns only at open ends; non-growing neighbours are pulled one hop), and an end may be buried in a plain perpendicular wall (inside corner, own wing included). Steps write `wall_offsets` + `projections{growth, base, closures}` + `storey.growth`; `_emit_projected_front` closes them with baked `frontage.{floor,return,return_beam,corner}.dNNN`. Profiles are monotone per front; a failing step is withdrawn for the front; a member that cannot hold leaves its front. Guardrails: public air, sky gap, measured neighbours (≤5 cm contact is touching; the face's own bay/ornaments ride; own and row ornaments under braces yield), reserved columns, per-edge footprint, portals/balcony bearings, end closure, crown (moved gable end with clipped filler, else the measured eave allowance — no kit jetty fits under a Suntail eave). Withdrawals are recorded per cause (`growth_rejections`); audit `growth_corpus_audit.gd`. Zero chance is byte-identical (old-look fixture pins 0); fingerprint baseline re-pinned for the defaults."

- [ ] **Step 10: Commit** `terrain/villages/town_odds.tres`, `tests/fixtures/town_old_look.gd`, `kit_town_review.gd`, `tests/test_growing_floors_knobs.gd`, `docs/qa/2026-10-07-town-odds/fingerprint/baseline.json`, `docs/qa/2026-10-08-growing-floors/` (result, audits, renders), `AGENTS.md`: message "Towns: growing upper floors on by default (0.3-0.45), evidence and re-pinned fingerprint" + trailer.

---

## Self-Review

**Spec coverage (with the October 8 amendment).** Knobs → Task 1 (+ amended values Task 4, shipped chance Task 10); baked depth family → Task 2 (+ corner squares Task 5; abutment pieces Task 7 only if measured); fitting, closing pieces, jetty replacement, projections/bays off stepping faces → Task 3; Decision 1 (step-out wording) → spec, Goal, result/AGENTS text (code names unchanged); Decision 2 (any exposed face, per-edge footprint) → Task 4 `face_chains` / `house_eligible`; Decision 3 (kit jetty 1.0 on `bracket.jetty`, 0.5 on `bracket.small`, cap 2.0, attic gable steps) → Task 4 (`STEP_SIZES`, `carried_step`, brace), Task 8 (gable shift at 2.0 = a full module); Decision 4a (coplanar rows) → Task 6; 4b (inside-corner bury, plain walls only, abutment piece if measured) → Task 7; 4c (otherwise withdraw) → `_end_kind` `blocked` (Tasks 5–7); Decision 5 (outer-corner wrap with closure) → Task 5; Decision 6 (three false blockers) → Task 4; Decision 7 (withdraw only the step; zero path byte-identical) → `_front_profile` (front-wide withdrawal, member leaves), fingerprint gate after every task. Guardrails G1–G3, G5, G6 → c8963fe9b + Task 4; G4 replaced by the end rule → Tasks 5–7; G7/crown → Task 8. Corpus targets from Diagnosis 2 (183 candidates, 18 / 22 baselines, per-cause counts) → Tasks 4–9 counts, Task 9 gate; evidence with wrap/row/bury street and side views and the F5 deviations write-up → Task 10.

**Rulings and conflicts (recorded here, in the ledger and in `result.md`):**
1. *Eave faces vs kit steps (main conflict).* The Suntail cornice reaches 0.986 native m beyond the wall and dips at its tip, so a 1.0 kit jetty can never stay under an eave (G7). Ruling: G7 stands; an eave-crowned leader falls back to the 0.5 step where the measured allowance admits it, otherwise eave-crowned faces stay flush (cause `crown`). Consequence: an outer-corner wrap or a row reaches a top storey only where every member's crown is a movable gable end, so on plain rectangular houses Decision 5 rarely shows at the crown storey. Task 9 measures it (`crown_eave`); Task 10 reports it with the options for the owner (a pentice over the top ledge, a baked deeper cornice, insetting the storeys below on one-step houses). No option is built without an owner call.
2. *Pulling is one hop.* A rolled face pulls its direct corner and coplanar partners; a pulled face pulls nothing further. Otherwise a single roll would step a whole block and the face knobs would mean nothing.
3. *Rows pull non-growing neighbours.* A pulled neighbour need not have rolled growth (Decision 4a), so more houses step than `growing_house_chance` alone suggests; the corpus reports `pulled`. Its designer choices are already made: a pulled storey with an inset jetty faults `material` and leaves the row.
4. *Rows join only on the same first upper storey*, so every member's k-th storey is the same band and every increment is one kit step (a brace fits).
5. *Front step and leader.* The leader is the first active member in chain-key order; its house's `growth_step` pick (quantised by `carried_step`, eave fallback in Task 8) sets the front's step and cap, re-derived whenever a member leaves.
6. *Member leaves vs withdraw.* A lean-dependent failure (air, gap, measured hit) withdraws the step for the whole front (every member holds); a member that cannot hold a storey, or cannot take the first step while others can, leaves the front and the rest refit; a member that left is fitted alone afterwards only if it was a seed. A lone face keeps the original cap-drop rule. This keeps "withdraw only the offending step" at front level and never leaves unequal steps at a corner or joint.
7. *Own-wing inside corners bury by the same rule* as neighbours (identical geometry and plainness test); Diagnosis 2 counted 25 concave ends and 27 own wings in front.
8. *Yield list.* Ivy, corner ivy, window boxes and awnings yield (are removed); rails, bays, roofs and other architecture never yield (rails are guards); touching contact (≤ 5 cm) covers the rail grazes Diagnosis 1 saw. Yield extends to the row's other houses (their ornaments under the row's braces).
9. *0.25 step retired.* `STEP_SIZES` = [0.5, 1.0]; the 0.25/0.75 baked pieces stay in the catalogue (no rebake, no catalogue churn); nothing places them.
10. *Original plan rulings that still stand:* cap quantisation (`step · min(4, floor(cap/step))`); monotone profiles with no inward ledge; the crown rule; house-wide jetty removal on growing houses (rolls kept); growth after towers and before projections/bays; street face as a column test (now only selects the face knob); widened G6 (doors/portals/passages/balcony bearings); capped (Pure) roof families keep gable faces flush; projections facing a step keep the sky gap; returns above 1.0 cut from the 2.0 wall start; stone/retaining/fortified storeys never step; `lane_sky_gap` clamp 0.25–4.0. One-cell lanes stay flush (facing verges meet mid-lane; eaves admit no kit step).
11. *Abutment piece.* Baked only if Task 7 measures a slit (> 1 cm) between a buried end and the wall; the expected Suntail geometry needs none.
12. *Buried gable ends.* A moved gable end may meet only the plain wall its storey is buried in (`KitRoofMeshUnion` trims roof triangles at walls); `roof_intrusions` in the audit and the Task 10 side views verify it.

**Placeholder scan.** No TBD; every new function has code, every test has assertions and an exact command. Measured constants (`WRAP_INSET`, the optional `ABUT_GAP`) have the exact measuring test and formula; conditional steps (Task 7 Step 5 slit branch, Task 9 Step 3 red edge cases, Task 10 Step 5 `after_all` run) name the exact action and files. Tasks 1–3 are unchanged and done.

**Name consistency.** `KitGrowingFronts` (`GROWTH`): `STEP_SIZES` [0.5, 1.0], `TOUCH`, `YIELD_DECOR`, `PLAIN_CONTACT`, `BURY_DROP`, `contact_clear`, `carried_step`, `face_chains` (keys `first_band`, `start_convex`, `end_convex`), `house_eligible`, `fit(...) -> {leans, registry, rejections}` (+ `roof_geometry` in Task 8), `fronts`, `apply`, `_fit_front`, `_front_step`, `_front_profile`, `_front_fault`, `_closures`, `_end_kind`, `_end_open`, `_bury_contact`, `_publish_riders`, `_rides_with_row`, `_rider_slab`, `_fault`, `_parts_fault`, `_crown_fault`, `_eave_cap`, `_moves_with_front`, `crown_index`, `crown_wing`, `eave_allowance`, `roof_geometry`, `gap_ok`, `clear_of`; closure kinds `return` / `wrap` / `joint` / `bury` (`blocked` internal); assembler `lean_suffix`, `OFFSET_WALL_DROP`, `WRAP_INSET`, `face_parts`, `roof_parts`, `_emit_bay`, `_emit_wrap_end`, `_front_role`, `_emit_front_floors`, `_lean_roof_end`, slot key `right_extend`; storey keys `wall_offsets`, `projections[{growth, base, closures}]`, `growth`; wing keys `lean_min`/`lean_max`; placement keys `lean_end`/`lean_filler`; build result keys `growth`, `growth_rejections`; harness `growth_corpus_audit.gd` (`GROWTH_AUDIT`, `GROWTH_TOTAL`, `GROWTH_AUDIT_DONE`); audit `growth_audit.gd` (`VIOLATIONS`); knob names match the spec's amended table exactly.
