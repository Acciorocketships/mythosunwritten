# Growing Upper Floors Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Amended October 8 (owner review after Task 4's diagnosis).** Tasks 1–3 are done and reviewed (commits 44ceab557, fb0a33125, 8e952f670, 8ce3e55b4) and stay as written. The original Tasks 4–7 are replaced by Tasks 4–10 below. The spec's "Amendment (October 8, owner review)" section is binding; where the text of Tasks 1–3 says "lean", "street face" or "0.25 step", read the amendment.

> **Amended October 9 (owner option 2: step in the kit's way).** Tasks 4–7 are done and reviewed (commits c8963fe9b, d44da4be1, 7e03d12c6, 5651ae7d4, 9419f7dab) and stay as written; they built the step-OUT machinery (fronts, wrap, rows, bury, guardrails) that the step-in re-references. The former Task 8 (roofs follow the step; commits 7a4ad783d, 3607a1ff1, never reviewed) is superseded and its roof code is removed by the new Task 9. The former Tasks 8–10 are replaced by Tasks 8–11 below. The spec's "Amendment 2 (October 9): step in the kit's way" is binding over everything else; where Tasks 1–7 say "step out", "lean over the lane", "sky gap" or "crown", read Amendment 2.

**Goal:** Some town houses grow storey by storey the Suntail/Shambles way: the roof and the top storey stay on the footprint and each lower storey steps IN one kit jetty (1.0 native m; 0.5 for the light step) further than the storey above, so the ground storey is the narrowest and every upper storey overhangs the one below on the kit's own jetty (floor beam, `bracket.jetty` braces on wall-module joints). Adjacent faces of one house step in together round convex corners, terrace neighbours step in as one row, an end beside the house's own wing closes its recess with a strip, and a ground door becomes a recessed shopfront under the overhang. Tunable by town odds; byte-identical to today when `growing_house_chance = 0`.

**Architecture:** A pure kit-layer fitter, `KitGrowingFronts`, runs in `KitVillageBuildings.build` after roofs are joined and towers proposed, before room projections and facade bays. It builds FRONTS (face chains that step as one: a lone face, faces joined at a house's convex corners, coplanar faces of neighbouring houses), gives each front one monotone cumulative profile `lean_k`, and writes it re-referenced to the face's top storey: storey k stands `lean_k - top` inside its line and the ground storey `-top` (`offsets_of`), through `storey.wall_offsets` (negative), `storey.projections` growth records `{growth, dir, edges, centres, band, depth, base, closures}` (signed native m) and `storey.growth[dir]`. `BuildingKitAssembler` shortens (or drops) the perpendicular corner panels to the baked `frontage.return.dNNN` strip, trims a stepped-in upper storey's floor to the baked `frontage.floor` / `frontage.corner` inner piece, carries each overhang on its floor beam with braces on the module joints of the wall below and return beams at open sides, and closes a `bury` end with a strip on the vertex line. Guardrails each withdraw a step (the front's cap drops one step; never a house or town); a front member that cannot hold leaves its front. Roofs never move.

**Tech Stack:** Godot 4.5, typed GDScript, GUT, environment bake (`tools/environment_bake/environment_bake.gd`, `bake_town_frame_variants.gd`, `export_growth_front_manifest.gd`), town fingerprint harness, `growth_corpus_audit`, `kit_town_review` / `building_gallery` render harnesses.

**Spec:** `docs/superpowers/specs/2026-10-08-growing-upper-floors-design.md` (read "Amendment 2 (October 9): step in the kit's way" first, then the October 8 amendment).

## Global Constraints

- Worktree `/Users/ryko/.codex/worktrees/77a0/story`, branch `town-redesign`; never touch `/Users/ryko/story`; never run the `godot-test` alias.
- `godot` below means `/Applications/Godot.app/Contents/MacOS/Godot`; always add `--log-file /tmp/<name>.log`, redirect stdout to a file and check the exit code; ignore unrelated Godot processes; run `godot --headless --path . --import` after adding a `class_name` or new assets.
- Knob `growing_house_chance`: CHANCE, 0.3 small → 0.45 large, spread 0.1 (shipped in Task 11; Tasks 1–10 keep it at 0).
- Knob `growth_street_face_chance`: CHANCE, 0.85.
- Knob `growth_other_face_chance`: CHANCE, 0.85 (every exposed face alike).
- Knob `growth_step`: WEIGHTS, {0.5 native m (1.0 m world, `bracket.small`): 1, 1.0 native m (2.0 m world, the kit jetty, `bracket.jetty`): 3}.
- Knob `growth_max_lean`: RANGE_FLOAT, 2.0 native m: the total step-in of the ground storey below the top storey (name kept).
- Knob `lane_sky_gap`: RANGE_FLOAT, 0.75 native m; inert under step-in (insets never narrow a lane), kept as the guardrail value for any outward offset (G2, room projections facing a growth registry entry).
- Knob `growth_gable_front_boost`: removed in Task 9 (knob, `BOOST_KNOB`, designer member, `gable_boost` context key).
- Units: kit native metres (module 2.0 m, storey 3.0 m; world = native x 2); offsets are sub-module values applied through `wall_offsets` (module fractions, negative = stepped in). Suntail `jetty_depth` = 1.0 native = half a module.
- Step-in invariant: the roof and the top storey of every stepping face never move; every piece growth adds stands inside the house's own cells (lot), within the wall face plus 5 cm.
- Byte-identical at `growing_house_chance = 0`: fingerprint `baseline.json` MATCH and `test_town_old_look` pass after every task 4–10.
- Guardrails withdraw the offending step (the front's cap drops one step), never a house or a town; in a front, a member that cannot hold even the first step leaves the front (the rest refit).
- No runtime asset scaling: every cut, strip, trimmed floor and beam is a baked `frontage.*` variant (d050/d100/d150/d200 for floors, returns, return beams and corner squares exist), steps 0.5 / 1.0, at most four steps (cap 2.0 = one module).
- Braces stand on wall-module joints (panel joints and corner posts) of the stepped-in storey below, never over a window or door head; one brace per joint.
- Worker purity: fitters return plain dictionaries and mutate only `BuildingMass` data; no nodes or server resources; the catalog is a read-only input.
- Deterministic per-key rolls: house rolls keyed by `mass.stable_id`, face rolls by the face key, fronts processed in leader-key order; one knob never moves another knob's draw.
- Every commit message ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; commit only this task's paths (`git commit -m "..." -- <paths>`; another agent commits roof work in this worktree concurrently); never `git add -f`, never commit `.superpowers/`.
- Measurement, not loosening: when a corpus count misses its target, report the per-cause withdrawal counts and stop for a controller ruling; never relax a guardrail to hit a number.

Command forms used below:

- Focused test: `godot --headless --path . --log-file /tmp/t.log -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/<file>.gd -gexit > /tmp/t.out 2>&1; echo EXIT $?; tail -30 /tmp/t.out`
- Fingerprint gate: `godot --headless --path . --log-file /tmp/fp.log -s res://tests/harness/town_fingerprint.gd -- --out /tmp/fp.json --compare res://docs/qa/2026-10-07-town-odds/fingerprint/baseline.json > /tmp/fp.out 2>&1; echo EXIT $?; grep FINGERPRINT_ /tmp/fp.out` must print `FINGERPRINT_MATCH` (harness flags: `--towns`, `--out`, `--compare`, `--parts source,payload,error`, `--odds name=value`, `--old-look`).
- Growth-on smoke (Tasks 3–10): the same command with `--odds growing_house_chance=1 --out /tmp/fp_on.json` and no `--compare`; `grep -c FINGERPRINT_NO_TOWN /tmp/fp.out` must print 0.
- Growth corpus count (Tasks 4–10): `godot --headless --path . --log-file /tmp/gc.log -s res://tests/harness/suntail/growth_corpus_audit.gd -- --odds growing_house_chance=1 --odds growth_street_face_chance=1 --odds growth_other_face_chance=1 --out /tmp/growth_count.json > /tmp/gc.out 2>&1; echo EXIT $?; grep -E "GROWTH_(TOTAL|AUDIT_DONE)" /tmp/gc.out`. Baselines on the same 8 towns: 183 candidate faces (Task 4 Diagnosis 2); 21 stepping faces / 22 storeys after Task 7 (step-out, before roofs); 2 faces after the superseded Task 8.

## Review Focus

1. The step-in invariant: roofs, top storeys and everything outside the lot are untouched — a stepping face's top storey has offset 0, no roof wing carries `lean_min`/`lean_max`, roof parts are identical with and without growth, and every added piece lies inside the lot. Tests: Task 9 `test_roofs_and_the_top_storey_never_move`, Task 10 audit keys `outside_lot`, `roof_moved`, `top_moved`.
2. A storey that cannot take its inset (portal, blocked end, bearing, stone fraction, party wall): the front's cap drops one step and the whole face re-tests at its final offsets, so no storey is ever outward of the storey above (no exposed ledge); a member that cannot take even the first step leaves and the rest refit. The house and town still build. Tests: Task 9 `test_skywalk_portal_storey_stays_on_the_lot_line`, `test_a_member_that_cannot_hold_leaves_the_front`, `test_a_row_member_that_cannot_step_withdraws_the_joint_not_the_town`.
3. Closures under step-in: `return` (perpendicular corner panel shortened or dropped, post at the new corner), `wrap` (both corner panels shortened, one post, inner floor square), `joint` (nothing), `bury` (strip on the vertex line). No end left open, no doubled post or beam. Tests: Task 8 `test_the_corner_panels_beside_a_stepped_in_run_give_way`, `test_a_wrapped_corner_steps_in_both_faces_with_one_post`, `test_a_buried_end_closes_the_recess_against_the_own_wing`, Task 9 `test_a_terrace_row_steps_in_as_one`, Task 10 audit keys `open_ends`, `broken_joints`.
4. Braces on joints and floors without ledges: one brace per wall-module joint, none over a window or door head, none where nothing stands below (a wrapped corner, a cut end); a stepped-in upper floor ends at its wall while the ground floor stays whole as the paving to a recessed door. Tests: Task 8 `test_overhang_braces_stand_on_module_joints_never_over_an_opening`, `test_a_stepped_in_upper_floor_ends_at_its_wall_and_the_ground_floor_stays_whole`, Task 9 `test_a_ground_door_is_a_recessed_shopfront`, Task 10 audit keys `braces_over_openings`, `ledges`.
5. The zero path: at `growing_house_chance = 0` no designer rng draw is skipped or added, no storey/wing key is written, projections/bays see exactly today's inputs, `storey_slots`' `right_extend` / `short` / `dropped` are 0/absent everywhere, and changing one growth knob never moves another knob's draw or another house's roll. Tests: Task 1 `test_house_roll_is_keyed_by_house_and_untouched_by_other_growth_knobs`, `test_build_marks_houses_growing_only_when_the_chance_is_positive`, Task 8 `test_offsets_of_zero_write_nothing`, and the fingerprint gate after every task.

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

### Task 8: Assembler: cumulative step-in (cut corners, trimmed floors, joint braces, bury strips)

Spec Amendment 2, assembler side only. KitGrowingFronts still writes step-out data until Task 9, so every step-out branch stays untouched here; this task teaches the assembler the step-in data contract, and its tests write that contract directly (`FIXTURE.write_step_in`). The superseded Task 8 fix round already added a one-storey version of the step-in pieces (`storey_slots` `short`/`short_side`, `_emit_inset_end`, `_emit_inset_jetty`, `below_growth`); they are the concrete remaining use of that code and are generalised here to cumulative offsets (several stepped-in storeys, whole-module cuts, wrapped corners, joint braces).

**Data contract** (Task 9's `apply` writes exactly this; `write_step_in` writes it for tests): for storey i of a stepping face from the ground storey up, an offset `o_i <= 0` (native m). Where `o_i < 0`, `storey.wall_offsets[edge] = o_i / module_width` on the face's run edges. Every storey with `o_i < 0` or `o_i > o_(i-1)` carries a growth record in `storey.projections`: `{"growth": true, "dir", "edges", "centres" (module centres on the ORIGINAL line, sorted along right_of(dir)), "band", "depth": o_i, "base": o_(i-1) (the ground storey: its own offset), "closures": [left, right]}`; `storey.growth[dir] = o_i`.

**Files:**
- Modify: `scripts/terrain/features/villages/kit/BuildingKitAssembler.gd` (`storey_slots` lines 446–475; `_assemble_storey` slot loop lines 537–580; `_emit_inhabited_floor` lines 79–85; `_emit_front_floors` 88–95 and `_emit_projected_front` 104–144 route step-in records; `_emit_inset_jetty` 1011–1028 rewritten; new `_emit_joint_braces`, `_blocked_beside`, `_emit_trimmed_floor`, `_emit_step_in`)
- Modify: `tests/fixtures/growing_house.gd` (new `write_step_in`)
- Modify: `tests/test_growing_floors_roofs.gd` (two brace counts 3 → 4; the file is deleted in Task 9)
- Test: `tests/test_growing_floors_step_in.gd` (new)

**Interfaces:**
- Consumes: `storey.wall_offsets` (module units), growth records as above, baked roles `frontage.{floor,return,return_beam,corner}.d{050,100,150,200}`, `bracket.jetty`, `bracket.small`, `trim.floor_beam`, `trim.floor_beam_corner`, `post.timber`, `kit.jetty_depth`, `external_blocked`.
- Produces: slot keys `short` (modules cut at `short_side`), `short_side`, `dropped: bool` (a whole-module cut; its inner neighbour on the run takes its convex flag); `BuildingKitAssembler._emit_inset_jetty(ctx, storey, slot, y, lower: float, below: Dictionary)`, `_emit_joint_braces(ctx, storey, slot, y, lower: float, below: Dictionary)`, `_blocked_beside(storey, cell) -> bool`, `_emit_trimmed_floor(ctx, storey, offsets, cell, y) -> bool`, `_emit_step_in(ctx, storey, projection, y)`; fixture `write_step_in(mass, kit, dir, offsets: Array[float], closures: Array = [&"return", &"return"], run: Array[Vector3i] = [])`.

- [ ] **Step 1: Fixture helper.** Append to `tests/fixtures/growing_house.gd`:

```gdscript
## Writes a step-in on face `dir` exactly as KitGrowingFronts.apply does (spec
## Amendment 2): offsets[i] (native m, <= 0) for storey i from the ground up, a growth
## record on every storey that stands in or overhangs the one below. `run` lists the
## face's edges (default: every boundary edge facing `dir` of storey 0).
static func write_step_in(mass: BuildingMass, kit: BuildingKit, dir: int, offsets: Array[float],
		closures: Array = [&"return", &"return"], run: Array[Vector3i] = []) -> void:
	var edges: Array[Vector3i] = run.duplicate()
	if edges.is_empty():
		for cell: Vector2i in mass.storeys[0].cells:
			if not (mass.storeys[0].cells as Dictionary).has(cell + BuildingMass.DIRS[dir]):
				edges.append(BuildingMass.edge_key(cell, dir))
	var centres: Array[Vector2] = []
	for edge: Vector3i in edges:
		centres.append(Vector2(edge.x, edge.y) + Vector2.ONE * 0.5 + Vector2(BuildingMass.DIRS[dir]) * 0.5)
	var right := Vector2(BuildingKitAssembler.right_of(dir))
	centres.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.dot(right) < b.dot(right))
	for index in offsets.size():
		var storey: Dictionary = mass.storeys[index]
		var depth := offsets[index]
		var base := offsets[index - 1] if index > 0 else depth
		var growth: Dictionary = storey.get("growth", {})
		growth[dir] = depth
		storey["growth"] = growth
		if depth >= 0.0 and depth <= base:
			continue
		if depth < 0.0:
			var wall_offsets: Dictionary = storey.get("wall_offsets", {})
			for edge: Vector3i in edges:
				wall_offsets[edge] = depth / kit.module_width
			storey["wall_offsets"] = wall_offsets
		var fronts: Array = storey.get("projections", [])
		fronts.append({"edges": edges, "centres": centres, "dir": dir, "depth": depth, "base": base,
			"band": int(storey.floor_band), "growth": true, "closures": closures})
		storey["projections"] = fronts
```

- [ ] **Step 2: Write the failing tests** `tests/test_growing_floors_step_in.gd`:

```gdscript
extends GutTest
## Step-in assembly (spec Amendment 2): a storey stands `offset` (<= 0, native m) inside
## its line on a stepping face; the top storey and the roof never move. Native frame:
## the south face (dir 3) of Rect2i(0, 0, 3, 2) is the line z = 0, inward is +z.
const FIXTURE := preload("res://tests/fixtures/growing_house.gd")


func _house(storeys := 4, door_dir := 1) -> BuildingMass:
	return FIXTURE.house(&"kit.fixture.front", Rect2i(0, 0, 3, 2), storeys, door_dir)


func _parts(mass: BuildingMass) -> Array[Dictionary]:
	return BuildingKitAssembler.new(SuntailBuildingKit.create()).assemble(mass)


func _box(part: Dictionary) -> AABB:
	return part.transform * EnvironmentCatalog.load_default().descriptor(part.asset_id).measured_aabb


## Parts whose role starts with `prefix` and whose box centre lies in the storey whose floor is y0.
func _at(parts: Array, prefix: String, y0: float) -> Array:
	return parts.filter(func(p: Dictionary) -> bool:
		var y := _box(p).get_center().y
		return String(p.role).begins_with(prefix) and y >= y0 - 0.02 and y <= y0 + 2.98)


## Braces of `role` hanging under the storey whose floor is y0.
func _braces(parts: Array, role: StringName, y0: float) -> Array:
	return parts.filter(func(p: Dictionary) -> bool:
		var box := _box(p)
		return p.role == role and box.end.y >= y0 - 0.3 and box.end.y <= y0 + 0.01)


## The default step-in: ground two jetties in, first upper storey one, top two on the line.
func _stepped(kit: BuildingKit, mass: BuildingMass) -> void:
	FIXTURE.write_step_in(mass, kit, 3, [-2.0, -1.0, 0.0, 0.0] as Array[float])


func test_each_storey_wall_stands_its_offset_inside_the_line() -> void:
	var kit := SuntailBuildingKit.create()
	var mass := _house()
	_stepped(kit, mass)
	var expected := [1.0, 0.5, 0.0, 0.0] # south slot centre z in cells (= -offset / 2)
	for index in 4:
		for slot: Dictionary in BuildingKitAssembler.storey_slots(mass.storeys[index]):
			if int(slot.dir) == 3:
				assert_almost_eq(float(slot.centre.y), float(expected[index]), 1e-5, "storey %d" % index)
	for part: Dictionary in _at(_parts(mass), "wall.", 0.0):
		var box := _box(part)
		if box.size.x > box.size.z and box.get_center().z < 3.0:
			assert_almost_eq(box.get_center().z, 2.0, 0.2, "ground south wall two jetties in")


func test_a_ground_door_moves_in_with_its_wall() -> void:
	var kit := SuntailBuildingKit.create()
	var mass := _house(4, 3)
	_stepped(kit, mass)
	var doors := _parts(mass).filter(func(p: Dictionary) -> bool: return String(p.role) == "wall.timber.door")
	assert_eq(doors.size(), 1)
	assert_almost_eq(_box(doors[0]).get_center().z, 2.0, 0.3, "the shopfront door stands in its stepped-in wall")


func test_the_corner_panels_beside_a_stepped_in_run_give_way() -> void:
	var kit := SuntailBuildingKit.create()
	var mass := _house()
	_stepped(kit, mass)
	var parts := _parts(mass)
	# Ground (a whole module in): the east and west corner panels are gone; each side
	# wall starts at the new corner (z 2), where one post stands.
	for part: Dictionary in _at(parts, "wall.", 0.0):
		var box := _box(part)
		if box.size.z > box.size.x:
			assert_true(box.position.z >= 2.0 - 0.05, "side panel at z %.2f" % box.position.z)
	assert_eq(_at(parts, "frontage.return.d", 0.0).size(), 0, "a whole-module cut takes no strip")
	for x: float in [0.0, 6.0]:
		var posts := _at(parts, "post.timber", 0.0).filter(func(p: Dictionary) -> bool:
			var c := _box(p).get_center()
			return absf(c.x - x) < 0.3 and absf(c.z - 2.0) < 0.3)
		assert_eq(posts.size(), 1, "one post at the ground's new corner x %.0f" % x)
	# First upper storey (one jetty in): the d100 strip on the inner half of each corner panel.
	var strips := _at(parts, "frontage.return.d100", 3.0)
	assert_eq(strips.size(), 2)
	for strip: Dictionary in strips:
		var box := _box(strip)
		assert_almost_eq(box.position.z, 1.0, 0.03, "the strip starts at the stepped-in face")
		assert_almost_eq(box.end.z, 2.0, 0.03, "and meets the next panel")
		assert_true(box.position.y <= 3.05 and box.end.y >= 5.85, "it spans the storey's height")
	for y0: float in [6.0, 9.0]:
		assert_eq(_at(parts, "frontage.return.d", y0).size(), 0, "the top storeys keep full side walls")


func test_overhang_braces_stand_on_module_joints_never_over_an_opening() -> void:
	var kit := SuntailBuildingKit.create()
	var mass := _house(4, 3) # a ground door on the stepping face (x 2..4)
	_stepped(kit, mass)
	var parts := _parts(mass)
	var faces := {1: [-1.0, -2.0], 2: [0.0, -1.0]} # storey: [its offset, the offset below]
	for index: int in faces:
		var y0 := 3.0 * index
		var braces := _braces(parts, &"bracket.jetty", y0)
		var xs := braces.map(func(p: Dictionary) -> float: return snappedf(_box(p).get_center().x, 0.5))
		xs.sort()
		assert_eq(xs, [0.0, 2.0, 4.0, 6.0], "one brace per module joint under storey %d" % index)
		for brace: Dictionary in braces:
			var box := _box(brace)
			assert_almost_eq(box.end.z, -float(faces[index][1]), 0.1, "it bears on the stepped-in wall below")
			assert_true(box.position.z <= -float(faces[index][0]) + 0.05, "it reaches the overhanging face")
			assert_almost_eq(box.position.y, y0 - 1.0, 0.25, "it drops one jetty")
	assert_eq(_braces(parts, &"bracket.jetty", 9.0).size(), 0, "a held storey adds no overhang")
	assert_eq(parts.filter(func(p: Dictionary) -> bool: return p.role == &"bracket.small").size(), 0)


func test_a_half_step_overhang_takes_small_brackets_on_the_joints() -> void:
	var kit := SuntailBuildingKit.create()
	var mass := _house()
	FIXTURE.write_step_in(mass, kit, 3, [-1.5, -1.0, -0.5, 0.0] as Array[float])
	var parts := _parts(mass)
	assert_eq(parts.filter(func(p: Dictionary) -> bool: return p.role == &"bracket.jetty").size(), 0)
	for index: int in [1, 2, 3]:
		var y0 := 3.0 * index
		var xs := parts.filter(func(p: Dictionary) -> bool:
			var c := _box(p).get_center()
			return p.role == &"bracket.small" and c.y < y0 and c.y > y0 - 1.2).map(
				func(p: Dictionary) -> float: return snappedf(_box(p).get_center().x, 0.5))
		xs.sort()
		assert_eq(xs, [0.0, 2.0, 4.0, 6.0], "storey %d" % index)
	assert_eq(_at(parts, "frontage.return.d050", 0.0).size(), 2, "ground 1.5 in: the 0.5 strips")
	assert_eq(_at(parts, "frontage.return.d150", 6.0).size(), 2, "storey 2 0.5 in: the 1.5 strips")


func test_a_stepped_in_upper_floor_ends_at_its_wall_and_the_ground_floor_stays_whole() -> void:
	var kit := SuntailBuildingKit.create()
	var mass := _house()
	_stepped(kit, mass)
	var parts := _parts(mass)
	var boards := func(role: StringName, y: float) -> Array:
		return parts.filter(func(p: Dictionary) -> bool:
			return p.role == role and absf(_box(p).get_center().y - y) < 0.3)
	assert_eq((boards.call(&"deck.board", 0.0) as Array).size(), 6,
		"the ground keeps every board: the paving under the overhang")
	var upper: Array = boards.call(&"deck.board", 3.0)
	assert_eq(upper.size(), 3, "storey 1 keeps only its back row of boards")
	for board: Dictionary in upper:
		assert_gt(_box(board).get_center().z, 2.0)
	var strips: Array = boards.call(&"frontage.floor.d100", 3.0)
	assert_eq(strips.size(), 3, "the front row keeps its inner half")
	for strip: Dictionary in strips:
		var box := _box(strip)
		assert_almost_eq(box.position.z, 1.0, 0.03, "the floor ends at the stepped-in wall")
		assert_almost_eq(box.end.z, 2.0, 0.03)
	assert_eq((boards.call(&"deck.board", 6.0) as Array).size(), 6, "the storeys on the line are whole")


func test_the_overhang_closes_its_open_sides_once() -> void:
	var kit := SuntailBuildingKit.create()
	var mass := _house()
	_stepped(kit, mass)
	var parts := _parts(mass)
	# Storey 1: its own corner strips' bottom beams close the overhang's sides (no
	# second beam there); storey 2 stands on the line: one return beam per side.
	for y0: float in [3.0, 6.0]:
		var z := 1.5 if y0 == 3.0 else 0.5 # mid-overhang, between the two faces
		var beams := parts.filter(func(p: Dictionary) -> bool:
			var c := _box(p).get_center()
			return p.role == &"frontage.return_beam.d100" and absf(c.y - y0) < 0.3 \
				and absf(c.z - z) < 0.3 and (absf(c.x) < 0.3 or absf(c.x - 6.0) < 0.3))
		assert_eq(beams.size(), 2, "one beam per open side at the floor y %.0f" % y0)


func test_a_wrapped_corner_steps_in_both_faces_with_one_post() -> void:
	var kit := SuntailBuildingKit.create()
	var mass := _house()
	# South: its right (west) end wraps; west: its left (south) end wraps.
	FIXTURE.write_step_in(mass, kit, 3, [-2.0, -1.0, 0.0, 0.0] as Array[float], [&"return", &"wrap"])
	FIXTURE.write_step_in(mass, kit, 2, [-2.0, -1.0, 0.0, 0.0] as Array[float], [&"wrap", &"return"])
	var parts := _parts(mass)
	var near := func(p: Dictionary, x: float, z: float, reach: float) -> bool:
		var c := _box(p).get_center()
		return absf(c.x - x) < reach and absf(c.z - z) < reach
	# Storey 1: each face's corner panel keeps a d100 strip; one post at (1, 1).
	assert_eq(_at(parts, "frontage.return.d100", 3.0).filter(func(p: Dictionary) -> bool:
		return near.call(p, 1.5, 1.5, 0.7)).size(), 2, "one strip on each face at the corner")
	assert_eq(_at(parts, "post.timber", 3.0).filter(func(p: Dictionary) -> bool:
		return near.call(p, 1.0, 1.0, 0.3)).size(), 1, "one post at the stepped-in corner")
	var squares := parts.filter(func(p: Dictionary) -> bool:
		return p.role == &"frontage.corner.d100" and absf(_box(p).get_center().y - 3.0) < 0.3)
	assert_eq(squares.size(), 1, "the corner cell's floor keeps its inner square")
	assert_almost_eq(_box(squares[0]).position.x, 1.0, 0.03)
	assert_almost_eq(_box(squares[0]).position.z, 1.0, 0.03)
	# Ground: both corner panels are gone (a whole module); the post stands at (2, 2).
	assert_eq(_at(parts, "post.timber", 0.0).filter(func(p: Dictionary) -> bool:
		return near.call(p, 2.0, 2.0, 0.3)).size(), 1)
	# No brace where nothing stands below: the outer corner of each overhang.
	assert_eq(_braces(parts, &"bracket.jetty", 3.0).filter(func(p: Dictionary) -> bool:
		var c := _box(p).get_center()
		return c.x < 1.4 and c.z < 1.4).size(), 0, "storey 1's corner overhangs the ground's recess")
	assert_eq(_braces(parts, &"bracket.jetty", 6.0).filter(func(p: Dictionary) -> bool:
		var c := _box(p).get_center()
		return c.x < 0.6 and c.z < 0.6).size(), 0, "storey 2's corner overhangs storey 1's recess")
	assert_eq(parts.filter(func(p: Dictionary) -> bool:
		return String(p.role).begins_with("frontage.return_beam") and absf(_box(p).get_center().y - 6.0) < 0.3 \
			and near.call(p, 0.5, 0.5, 0.6)).size(), 0, "no return beam inside a wrapped corner")


func test_a_buried_end_closes_the_recess_against_the_own_wing() -> void:
	# An L: the body (x 0..2, z 0..1) and a wing (x 3, z -1..1) standing out in front of
	# the body's south face. The body's south run steps in; its east end meets the wing.
	var kit := SuntailBuildingKit.create()
	var mass := BuildingMass.new()
	mass.stable_id = &"kit.fixture.front"
	var cells := BuildingMass.rect_cells(Rect2i(0, 0, 3, 2))
	cells.merge({Vector2i(3, -1): true, Vector2i(3, 0): true, Vector2i(3, 1): true})
	for s in 4:
		mass.add_storey(s * 2, cells.duplicate(), BuildingMass.MATERIAL_TIMBER)
	var run: Array[Vector3i] = []
	for x in 3:
		run.append(BuildingMass.edge_key(Vector2i(x, 0), 3))
	FIXTURE.write_step_in(mass, kit, 3, [-2.0, -1.0, 0.0, 0.0] as Array[float], [&"bury", &"return"], run)
	var parts := _parts(mass)
	for index: int in [0, 1]:
		var depth := 2.0 - float(index)
		var strips := _at(parts, "frontage.return.%s" % BuildingKitAssembler.lean_suffix(depth), 3.0 * index) \
			.filter(func(p: Dictionary) -> bool: return absf(_box(p).get_center().x - 6.0) < 0.3)
		assert_eq(strips.size(), 1, "storey %d: one strip on the wing's line" % index)
		var box := _box(strips[0])
		assert_almost_eq(box.position.z, 0.0, 0.05, "from the lot line")
		assert_almost_eq(box.end.z, depth, 0.05, "to the stepped-in wall")


func test_a_stone_ground_storey_steps_in_a_whole_module_without_a_strip() -> void:
	var kit := SuntailBuildingKit.create()
	var mass := _house()
	mass.storeys[0].material = BuildingMass.MATERIAL_STONE
	_stepped(kit, mass)
	var stone := _at(_parts(mass), "wall.stone.", 0.0)
	assert_gt(stone.size(), 0)
	for part: Dictionary in stone:
		var box := _box(part)
		if box.size.x > box.size.z and box.get_center().z < 3.0:
			assert_almost_eq(box.get_center().z, 2.0, 0.3, "the stone run stands a module in")
		elif box.size.z > box.size.x:
			assert_true(box.position.z >= 2.0 - 0.05, "no stone side panel left in the recess")


func test_offsets_of_zero_write_nothing() -> void:
	var kit := SuntailBuildingKit.create()
	var plain := _house()
	var held := _house()
	FIXTURE.write_step_in(held, kit, 3, [0.0, 0.0, 0.0, 0.0] as Array[float])
	assert_eq(str(_parts(held)), str(_parts(plain)))
	for storey: Dictionary in held.storeys:
		for slot: Dictionary in BuildingKitAssembler.storey_slots(storey):
			assert_eq(float(slot.short), 0.0)
			assert_false(bool(slot.get("dropped", false)))
```

- [ ] **Step 3: Run and see them fail.** Focused-test command for `test_growing_floors_step_in.gd`. Expected: the wall/door/offset tests pass already (slots shift by any offset); the corner test fails (the ground's whole-module cut emits a `frontage.return.d000` lookup / a side panel at z 0 because `short` only applies when the slot's own offset is 0 and a 1.0-module cut is not dropped), the brace tests fail (braces at module centres, 3 per storey; no brace under storey 1, whose `below_growth` assumed an upper offset of 0), the floor test fails (6 boards at storey 1), the wrap and bury tests fail (no strips), the stone test fails on the side panels. Record the failure lines.

- [ ] **Step 4: `storey_slots`: cuts from any stepped-in perpendicular face, whole-module drops.** Replace the growth-inset block (lines 460–474) with:

```gdscript
		# A stepped-in perpendicular face (offsets < 0) cuts this slot's corner panel at
		# that end by its inset (also when this face steps in too: a wrapped corner);
		# the corner post moves in with it (modules cut at `short_side`).
		slot["short"]=0.0
		slot["short_side"]=0
		for end:int in [-1,1]:
			if not bool(slot.right_convex if end>0 else slot.left_convex):continue
			var perpendicular:=BuildingMass.DIRS.find(right_of(int(slot.dir))*end)
			var corner:Vector3i=slot.edge
			var cut:=float(offsets.get(BuildingMass.edge_key(Vector2i(corner.x,corner.y),perpendicular),0.0))
			if cut<0.0 and float(slot.wall_offset)<=0.0:
				slot["short"]=-cut
				slot["short_side"]=end
				if end>0:slot["right_extend"]=cut
	# A whole-module cut drops the corner slot; its inner neighbour on the same run
	# takes the corner (its convex flag; its post stands at the new corner). The cap is
	# one module, so no cut reaches past the neighbour (bearing keeps runs >= 2 long).
	for slot:Dictionary in slots:
		if float(slot.short)<1.0-0.0001:continue
		slot["dropped"]=true
		var side:=int(slot.short_side)
		var inner:Vector2=(slot.centre as Vector2)-Vector2(right_of(int(slot.dir)))*float(side)
		for other:Dictionary in slots:
			if int(other.dir)==int(slot.dir) and (other.centre as Vector2).is_equal_approx(inner):
				other["right_convex" if side>0 else "left_convex"]=true
				if side>0:other["right_extend"]=0.0
	return slots
```

- [ ] **Step 5: `_assemble_storey`: cumulative overhangs and joint braces.** Make `below_growth` signed (module units, the storey below's own offset):

```gdscript
	# Stepped-in edges of the storey below (offsets < 0, module units).
	var below_growth: Dictionary = {}
	if not below.is_empty():
		var lower_offsets: Dictionary = below.get("wall_offsets", {})
		for edge: Vector3i in lower_offsets:
			if float(lower_offsets[edge]) < 0.0:
				below_growth[edge] = float(lower_offsets[edge])
```

In the slot loop, first line `if bool(slot.get("dropped", false)): continue`, and replace the short branch and the `below_growth` call with:

```gdscript
		var lower := float(below_growth.get(slot.edge, 0.0))
		var overhang := below_growth.has(slot.edge) and float(slot.wall_offset) > lower + 0.0001
		if float(slot.get("short", 0.0)) > 0.0 and bands == 2:
			_emit_inset_end(ctx, storey, slot, wall_y)
			_emit_corner_post(ctx, slot, wall_y, bands, kit.wall_face)
			if overhang:
				# The strip's bottom beam is its floor edge; it is braced at its uncut end.
				_emit_joint_braces(ctx, storey, slot, y, lower, below)
			continue
		if overhang:
			_emit_inset_jetty(ctx, storey, slot, y, lower, below)
```

Replace `_emit_inset_jetty` and add the helpers:

```gdscript
## The storey over a stepped-in storey carries its overhang the kit's way: the floor
## beam on its own face (the corner variant at a left convex end), braces on the
## wall-module joints of the wall below, and a return beam closing an open convex
## side where this storey's own side wall runs full (a stepped-in storey's cut strip
## closes that side with its bottom beam; a wrapped corner and a row joint have none).
func _emit_inset_jetty(ctx: Dictionary, storey: Dictionary, slot: Dictionary, y: float,
		lower: float, below: Dictionary) -> void:
	var dir := int(slot.dir)
	var out := Vector2(BuildingMass.DIRS[dir])
	var right := Vector2(right_of(dir))
	var yaw := yaw_for_dir(dir)
	var centre: Vector2 = slot.centre
	var cut := float(slot.wall_offset) - lower
	_emit(ctx, &"trim.floor_beam_corner" if bool(slot.left_convex) else &"trim.floor_beam", centre, y, yaw)
	_emit_joint_braces(ctx, storey, slot, y, lower, below)
	if float(slot.wall_offset) < 0.0:
		return
	var lower_offsets: Dictionary = below.get("wall_offsets", {})
	var edge: Vector3i = slot.edge
	var cell := Vector2i(edge.x, edge.y)
	for side: int in [-1, 1]:
		if not bool(slot.right_convex if side > 0 else slot.left_convex):
			continue
		var corner := BuildingMass.edge_key(cell, BuildingMass.DIRS.find(right_of(dir) * side))
		if float(lower_offsets.get(corner, 0.0)) < 0.0 or _blocked_beside(storey, cell + right_of(dir) * side):
			continue
		_emit(ctx, StringName("frontage.return_beam.%s" % lean_suffix(cut * kit.module_width)),
			centre + right * 0.5 * float(side) - out * cut * 0.5, y, yaw + PI * 0.5 * float(side))


## Braces of one overhanging slot, one per wall-module joint it owns: its right joint,
## and its left joint only where no overhanging slot of this storey continues the run
## and no neighbouring building's row continues it (that slot owns the joint at its
## right end). No brace where nothing stands below: the cut end of a shortened slot,
## or a convex end whose perpendicular face is stepped in below (a wrapped corner).
## The kit jetty brace carries a kit step; the small bracket the light step.
func _emit_joint_braces(ctx: Dictionary, storey: Dictionary, slot: Dictionary, y: float,
		lower: float, below: Dictionary) -> void:
	var dir := int(slot.dir)
	var out := Vector2(BuildingMass.DIRS[dir])
	var right := Vector2(right_of(dir))
	var edge: Vector3i = slot.edge
	var cell := Vector2i(edge.x, edge.y)
	var cut := float(slot.wall_offset) - lower
	var lower_offsets: Dictionary = below.get("wall_offsets", {})
	var jetty := absf(cut * kit.module_width - kit.jetty_depth) < 0.001 and kit.has_role(&"bracket.jetty")
	for side: int in [-1, 1]:
		var convex := bool(slot.right_convex if side > 0 else slot.left_convex)
		if float(slot.get("short", 0.0)) > 0.0 and int(slot.short_side) == side:
			continue
		var beside := cell + right_of(dir) * side
		if convex and float(lower_offsets.get(BuildingMass.edge_key(cell,
				BuildingMass.DIRS.find(right_of(dir) * side)), 0.0)) < 0.0:
			continue
		if side < 0 and not convex and (storey.cells as Dictionary).has(beside) \
				and float(lower_offsets.get(BuildingMass.edge_key(beside, dir), 0.0)) < 0.0:
			continue
		if side < 0 and convex and _blocked_beside(storey, beside):
			continue
		var joint: Vector2 = (slot.centre as Vector2) + right * 0.5 * float(side) - out * cut
		if jetty:
			_emit(ctx, &"bracket.jetty", joint, y - kit.jetty_depth, yaw_for_dir(dir))
		else:
			_emit(ctx, &"bracket.small", joint - out * 0.15 / kit.module_width, y - .706295, yaw_for_dir(dir))


## Another building stands in this cell at the storey's floor band (a row partner).
func _blocked_beside(storey: Dictionary, cell: Vector2i) -> bool:
	return not (storey.cells as Dictionary).has(cell) and external_blocked.is_valid() \
		and bool(external_blocked.call(cell, int(storey.floor_band)))
```

(Delete the old body of `_emit_inset_jetty`; its one-storey assumption `centre - out * cut` with `cut` the lower inset is the `upper = 0` case of the code above.)

- [ ] **Step 6: Trimmed upper floors.** Replace `_emit_inhabited_floor`:

```gdscript
func _emit_inhabited_floor(ctx: Dictionary, storey: Dictionary) -> void:
	if bool(storey.get("retaining",false)) or bool(storey.get("fortified",false)):
		return
	var y := float(storey.floor_band)*kit.band_height()
	var mass: BuildingMass = ctx.mass
	var offsets: Dictionary = storey.get("wall_offsets", {})
	# The ground storey keeps every board: the strip a step-in uncovers is the house's
	# own paving under the overhang (and the walk to a recessed door).
	var trim := int(storey.floor_band) > mass.ground_band and not offsets.is_empty()
	for cell: Vector2i in storey.cells:
		if trim and _emit_trimmed_floor(ctx, offsets, cell, y):
			continue
		_emit(ctx,&"deck.board",Vector2(cell)+Vector2(0.5,0.5),y,0.0)
	_emit_front_floors(ctx,storey)


## A stepped-in upper storey's floor ends at its own wall (a full board would stand
## out as a ledge): the cell keeps the baked inner strip (one face stepped in), the
## inner square (a wrapped corner: two perpendicular faces, equal insets by the
## planner's wrap rule), or nothing (a whole-module step). False when no edge of the
## cell is stepped in (its ordinary board follows).
func _emit_trimmed_floor(ctx: Dictionary, offsets: Dictionary, cell: Vector2i, y: float) -> bool:
	var insets: Array[int] = []
	var depth := 0.0
	for dir in 4:
		var offset := float(offsets.get(BuildingMass.edge_key(cell, dir), 0.0))
		if offset < 0.0:
			insets.append(dir)
			depth = -offset * kit.module_width
	if insets.is_empty():
		return false
	var keep := kit.module_width - depth
	if keep <= 0.001:
		return true
	var at := Vector2(cell) + Vector2(0.5, 0.5)
	for dir: int in insets:
		at -= Vector2(BuildingMass.DIRS[dir]) * depth * 0.5 / kit.module_width
	var role := "frontage.corner" if insets.size() == 2 else "frontage.floor"
	_emit(ctx, StringName("%s.%s" % [role, lean_suffix(keep)]), at, y, yaw_for_dir(insets[0]))
	return true
```

- [ ] **Step 7: Step-in records and bury strips.** In `_emit_front_floors` skip a step-in record (`if bool(projection.get("growth", false)) and float(projection.depth) <= 0.0: continue` as the loop's first line). In `_emit_projected_front`, as the loop's first lines:

```gdscript
		if bool(projection.get("growth", false)) and float(projection.get("depth", 0.0)) <= 0.0:
			_emit_step_in(ctx, storey, projection, y)
			continue
```

and add:

```gdscript
## A stepped-in storey's own end closures (its overhang is emitted per slot from the
## offsets, its cut corner panels by storey_slots): a `bury` end closes the recess on
## the vertex line with the baked return strip of the inset's depth, facing the
## recess, so no hole opens into the house's own room beside it; `return`, `wrap` and
## `joint` ends need nothing here.
func _emit_step_in(ctx: Dictionary, storey: Dictionary, projection: Dictionary, y: float) -> void:
	var depth := -float(projection.depth)
	if depth <= 0.0:
		return
	var dir := int(projection.dir)
	var out := Vector2(BuildingMass.DIRS[dir])
	var right := Vector2(right_of(dir))
	var centres: Array = projection.centres
	var closures: Array = projection.get("closures", [&"return", &"return"])
	var suffix := lean_suffix(depth)
	for side: int in [-1, 1]:
		if StringName(closures[0 if side < 0 else 1]) != &"bury":
			continue
		var centre: Vector2 = centres.front() if side < 0 else centres.back()
		var at := centre + right * 0.5 * float(side) - out * depth * 0.5 / kit.module_width
		var yaw := yaw_for_dir(dir) - PI * 0.5 * float(side)
		_emit(ctx, StringName("frontage.return." + suffix), at, y, yaw, 0, Transform3D.IDENTITY,
			storey.get("tint", Color.WHITE))
		_emit(ctx, StringName("frontage.return_beam." + suffix), at, y, yaw)
		_emit(ctx, StringName("frontage.return_beam." + suffix), at, y + kit.storey_height - .143, yaw)
```

The bury strip's yaw is the step-out return's turned half round: the recess lies on the run's side of the vertex line, the wing on the other. If the bury test shows the strip standing in the wing's half (box centre x > 6.15), keep the yaw and move `at` by `- right * side * kit.wall_face / kit.module_width`; record the measured offset in the report.

- [ ] **Step 8: Re-pin the superseded roofs tests' brace counts.** In `tests/test_growing_floors_roofs.gd`, `test_an_eave_face_steps_its_ground_run_in_instead` and `test_a_tall_eave_face_keeps_one_step_at_the_ground`: `assert_eq(_south_braces(f, 1).size(), 4, "one kit jetty brace per module joint")` (the fix-round one-face inset now carries its braces on joints; the file goes in Task 9).

- [ ] **Step 9: Run to pass.** `test_growing_floors_step_in.gd` (11 passing); re-run `test_growing_floors.gd`, `test_growing_floors_guardrails.gd`, `test_growing_floors_wrap.gd`, `test_growing_floors_rows.gd`, `test_growing_floors_bury.gd`, `test_growing_floors_roofs.gd`, `test_growing_floors_knobs.gd`, `test_october3_room_projections.gd`, `test_roof_proportion.gd`, `test_town_old_look.gd` (all green: step-out data writes no negative offsets except the fix-round eave inset, whose expectations Step 8 re-pinned).

- [ ] **Step 10: Gates.** Fingerprint gate → `FINGERPRINT_MATCH` (no negative offset exists at chance 0); growth-on smoke → 0 `FINGERPRINT_NO_TOWN`.

- [ ] **Step 11: Commit** `BuildingKitAssembler.gd`, `tests/fixtures/growing_house.gd`, `tests/test_growing_floors_step_in.gd`, `tests/test_growing_floors_roofs.gd`: message "Towns: step-in assembly (cut corners, trimmed floors, braces on joints, bury strips)" + trailer.

---

### Task 9: Step in, re-referenced to the top storey (planner), recessed doors, roof code removed

Spec Amendment 2, planner side. `KitGrowingFronts` keeps its fronts, joins, closure kinds, monotone capped profile, member-leaves rule, decor ride/yield and per-cause rejections, and writes every profile re-referenced to the face's top storey (`offsets_of`). Every guardrail is re-checked for step-in (spec table "Guardrails under step-in"). The superseded Task 8 roof code is removed (it has no remaining use: roofs and top storeys never move): the gable shift, clipped fillers, eave allowance/cap, crown rule (G7), the one-face eave inset planner path, `growth_gable_front_boost`. Code that can only serve an outward offset is removed with it (spec "Supersedes"); the assembler pieces the fix round added stay (Task 8 generalised them).

**Files:**
- Modify: `scripts/terrain/features/villages/kit/KitGrowingFronts.gd` (see Step 3 for the kept / changed / removed lists)
- Modify: `scripts/terrain/features/villages/kit/BuildingKitAssembler.gd` (remove `roof_parts`, `_lean_roof_end` and its `first_part` call in `_assemble_roof` lines ~1048–1160, `_emit_wrap_end`, `WRAP_INSET`, `face_parts`, `_front_role` (inline the role: only room projections remain on that path), and the growth branches of `_emit_projected_front` (the `bracket.jetty` growth branch and the closures `match`; room projections keep their returns and `bracket.small`))
- Modify: `scripts/terrain/features/villages/kit/BuildingDesigner.gd` (revert the Task 8 boost: member `gable_front_boost`, the first line of `articulate`, the `share` line of `_square_axis` back to `var share := square_axis_weights[preferred] / (square_axis_weights.x + square_axis_weights.y)`)
- Modify: `scripts/terrain/features/villages/kit/KitVillageBuildings.gd` (`GROWTH.fit` call lines 215–223 without the roof geometry argument; delete the `for lean in growth.leans: walls.append(...)` loop (line 224); result keys without `growth_insets` / `growth_roofs` (line 336); delete `context["gable_boost"] = ...` (line 1592))
- Modify: `terrain/villages/town_odds.tres` (delete the `growth_gable_front_boost` sub-resource and its entry in `knobs`; notes of `growing_house_chance`, `growth_max_lean`, `lane_sky_gap`)
- Modify: `tests/fixtures/growing_house.gd` (`block_faces`, `block` / `lone` options, no `reserved_x`, `fit` call)
- Modify: `tests/test_growing_floors.gd`, `tests/test_growing_floors_guardrails.gd`, `tests/test_growing_floors_wrap.gd`, `tests/test_growing_floors_rows.gd`, `tests/test_growing_floors_bury.gd`, `tests/test_growing_floors_knobs.gd` (re-pins, Step 6)
- Delete: `tests/test_growing_floors_roofs.gd`
- Modify: `tests/harness/suntail/building_gallery.gd` (`_grow`: `fit` call without the roof geometry), `tests/harness/suntail/growth_corpus_audit.gd` (`counts()` and totals for step-in, Step 7)

**Interfaces:**
- Consumes: Task 8's assembler contract (negative `wall_offsets`, growth records, `storey.growth`), `BuildingKitAssembler.boundary_runs`, `_inside_cell`, `right_of`, `_assemble_decor`, `KitPublicClearance.intersects_air`, catalog `measured_aabb`.
- Produces: `KitGrowingFronts.fit(masses, kits, base, catalog, character, air, towers, reserved, solid, street) -> {leans, registry, rejections}` (registry always empty: growth writes no outward offset); chain key `ground: int`; `offsets_of(leans: Array[float]) -> Array[float]`; `apply(mass, kit, chain, leans: Array[float], closures: Array) -> {records, moved}` (closures indexed from the ground storey up); lean records `{host, dir, band, lean (signed offset <= 0), base, edges, bounds (the recess), chain, closures, pulled}`; rejections `{chain, storey (-1 = ground), lean (signed), cause}` with causes `material`, `portal`, `party`, `columns`, `bearing`, `decor`, `ends`, `air`, `obstacle.*`; fixture `block_faces(mass, dirs)`.

- [ ] **Step 1: Re-pin the tests first (red).** Fixture: add

```gdscript
## Keeps faces out of their front: a skywalk passage on the first upper storey's panel at
## the far end of each face in `dirs` (the +z or +x end, away from the south face), so
## the face cannot step at all (cause portal) and leaves the front; the panel at the
## south face's corner stays plain (the south step may cut it).
static func block_faces(mass: BuildingMass, dirs: Array) -> void:
	var first: Dictionary = GROWTH._storey_at(mass, mass.ground_band + 2)
	for run: Dictionary in BuildingKitAssembler.boundary_runs(first.cells):
		if not dirs.has(int(run.dir)):
			continue
		var edge := BuildingMass.edge_key(BuildingKitAssembler._inside_cell(int(run.dir), int(run.line),
			int(run.end) - 1), int(run.dir))
		first.openings[edge] = BuildingMass.OPENING_DOOR
		var passages: Dictionary = first.get("passage_edges", {})
		passages[edge] = true
		first["passage_edges"] = passages
```

In `build`: after `prepare`, `var blocked: Array = options.get("block", [0, 2] if bool(options.get("lone", false)) else [])` and `if not blocked.is_empty(): block_faces(front, blocked)`; delete the `reserved_x` block (reserved columns beyond a face mean nothing under step-in); the `fit` call loses its last argument. Update the doc comment: options `block` (dirs of the front kept out of its front), `lone` (= block [0, 2]: only the south face steps; the house's door is on the south ground storey, a recessed shopfront).

`tests/test_growing_floors.gd` (replace these tests; the jetty-roll, projections/bays and knob tests keep their bodies except where noted):

```gdscript
func test_each_lower_storey_steps_in_one_jetty_further() -> void:
	var f := FIXTURE.build({"lone": true})
	assert_eq(FIXTURE.leans_on(f.front, 3), [-2.0, -1.0, 0.0, 0.0] as Array[float],
		"the ground two kit jetties in, the first upper storey one, the top two on the lot line")
	assert_eq(FIXTURE.leans_on(f.front, 1), [0.0, 0.0, 0.0, 0.0] as Array[float],
		"the back face is not rolled (other-face chance 0 in the fixture)")
	for index in 4:
		for slot: Dictionary in BuildingKitAssembler.storey_slots(f.front.storeys[index]):
			if int(slot.dir) == 3:
				assert_almost_eq(float(slot.centre.y), -FIXTURE.leans_on(f.front, 3)[index] / 2.0, 1e-5,
					"offset in module units, storey %d" % index)
	assert_false(f.front.storeys[3].has("wall_offsets"), "the top storey stays on the lot line")


func test_cap_floors_to_whole_steps() -> void:
	var f := FIXTURE.build({"lone": true, "storeys": 5, "character": FIXTURE.character({&"growth_max_lean": 1.5})})
	assert_eq(FIXTURE.leans_on(f.front, 3), [-1.0, 0.0, 0.0, 0.0, 0.0] as Array[float])
	var g := FIXTURE.build({"lone": true, "storeys": 5, "character": FIXTURE.character({&"growth_max_lean": 2.0}, &"0.5")})
	assert_eq(FIXTURE.leans_on(g.front, 3), [-2.0, -1.5, -1.0, -0.5, 0.0] as Array[float])


func test_every_overhang_rides_the_kit_jetty_on_the_joints() -> void:
	var f := FIXTURE.build({"lone": true})
	var catalog := EnvironmentCatalog.load_default()
	for index: int in [1, 2]:
		var y0 := float(f.front.storeys[index].floor_band) * 1.5
		var braces := _braces_under(f, &"bracket.jetty", y0).filter(func(p: Dictionary) -> bool:
			var box: AABB = p.transform * catalog.descriptor(p.asset_id).measured_aabb
			return box.size.z > box.size.x) # the south face's braces
		var xs := braces.map(func(p: Dictionary) -> float:
			return snappedf((p.transform * catalog.descriptor(p.asset_id).measured_aabb).get_center().x, 0.5))
		xs.sort()
		assert_eq(xs, [0.0, 2.0, 4.0, 6.0], "one kit jetty brace per module joint (storey %d)" % index)
		assert_eq(_parts_in(f, &"trim.floor_beam", y0).size() + _parts_in(f, &"trim.floor_beam_corner", y0).size(), 3,
			"the floor beam on the overhanging face (the corner variant at its left convex end)")
	assert_eq(_braces_under(f, &"bracket.jetty", 9.0).size(), 0, "a held storey adds no overhang")
	assert_eq(_braces_under(f, &"bracket.small", 3.0).size(), 0, "a kit step never takes small brackets")


func test_half_step_keeps_the_small_brackets() -> void:
	var f := FIXTURE.build({"lone": true, "character": FIXTURE.character({}, &"0.5")})
	assert_eq(FIXTURE.leans_on(f.front, 3), [-1.5, -1.0, -0.5, 0.0] as Array[float])
	var y0 := float(f.front.storeys[1].floor_band) * 1.5
	assert_eq(_braces_under(f, &"bracket.small", y0).size(), 4, "a bracket at every module joint")
	assert_eq(_braces_under(f, &"bracket.jetty", y0).size(), 0)


func test_growth_result_lists_each_stepped_storey() -> void:
	var f := FIXTURE.build({"lone": true})
	# The ground (stands in), storey 1 (stands in and overhangs), storey 2 (overhangs).
	assert_eq(f.leans.size(), 3)
	for lean: Dictionary in f.leans:
		assert_eq(int(lean.dir), 3)
		assert_true((lean.bounds as AABB).has_volume())
		assert_true(float(lean.lean) <= 0.0)
	assert_true((f.result.registry as Dictionary).is_empty(), "growth never steps outward")
```

In `test_projections_and_bays_skip_leaning_faces`: replace `{"reserved_x": [-1, 5], "replace_front": wide}` with `{"block": [0, 2], "replace_front": wide}`, delete the roof-axis comment, and expect `[-2.0, -1.0, 0.0, 0.0]`. `_parts_in` and `_braces_under` stay.

`tests/test_growing_floors_guardrails.gd` (replace these tests; `_open`, `test_gap_ok_measures_to_the_facing_lean`, `test_face_over_a_lower_neighbour_is_a_candidate` and `test_contact_under_five_centimetres_is_touching` stay; delete `test_sky_gap_withdraws_only_the_later_houses_failing_step` and `test_probe_parts_match_the_final_assembly_at_bay_slots`):

```gdscript
func test_walking_air_withdraws_only_the_step_it_reaches() -> void:
	# A passage's headroom inside the house, where the braces under storey 2 would hang
	# (y 5..6, between storey 1's stepped-in face z 1 and the lot line).
	var air: Array[Dictionary] = [_open(AABB(Vector3(-1, 5.2, 0.2), Vector3(8, 0.6, 0.6)))]
	var f := FIXTURE.build({"lone": true, "air": air})
	assert_eq(FIXTURE.leans_on(f.front, 3), [-1.0, 0.0, 0.0, 0.0] as Array[float],
		"the second step is withdrawn (the cap drops one step)")


func test_insets_never_narrow_the_lane() -> void:
	# Two growing houses facing across a one-cell lane, with a sky gap larger than the
	# lane: under step-in the upper storeys stay on their lot lines, so G2 cannot fire.
	for gap: float in [0.75, 2.75]:
		var f := FIXTURE.build({"lone": true, "facing": true, "back_grows": true,
			"character": FIXTURE.character({&"lane_sky_gap": gap})})
		assert_eq(FIXTURE.leans_on(f.front, 3), [-2.0, -1.0, 0.0, 0.0] as Array[float], "gap %.2f" % gap)
		# The facing house is not kept lone: its pulled east and west faces may hold it
		# at one jetty (bearing), but it only ever steps in, and its top stays on its line.
		var back := FIXTURE.leans_on(f.back, 1)
		assert_lt(back[0], 0.0, "the facing house steps in too")
		assert_eq(back[3], 0.0, "its top storey stays on the lot line")
		for value: float in back:
			assert_true(value <= 0.0)
		assert_false((f.result.rejections as Array).any(func(r: Dictionary) -> bool: return r.cause == &"gap"))


func test_neighbouring_feature_withdraws_only_the_step_it_reaches() -> void:
	var towers: Array[Dictionary] = [{"bounds": AABB(Vector3(-1, 5.2, 0.2), Vector3(8, 0.6, 0.6))}]
	var f := FIXTURE.build({"lone": true, "towers": towers})
	assert_eq(FIXTURE.leans_on(f.front, 3), [-1.0, 0.0, 0.0, 0.0] as Array[float])


func test_a_reserved_recess_keeps_the_face_flush() -> void:
	# A passage claim through the ground storey's front row: it cannot step in at all.
	var f := FIXTURE.build({"lone": true, "reserved": func(_own: StringName, cell: Vector2i, band: int) -> bool:
		return cell.y == 0 and band <= 1})
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 0.0, 0.0, 0.0] as Array[float],
		"the ground cannot stand in, so no storey above may overhang it")


func test_footprint_change_ends_the_face_chain() -> void:
	var mass := FIXTURE.house(&"kit.fixture.front", Rect2i(0, 0, 3, 2), 4, 3)
	mass.add_roof(Rect2i(0, 0, 3, 2), 1, 8, &"red")["union_index"] = 0
	mass.storeys[2].cells.erase(Vector2i(2, 0))
	var chains := FIXTURE.GROWTH.face_chains(mass, Callable(FIXTURE, "nothing_solid"), Callable(FIXTURE, "street"))
	var south := chains.filter(func(c: Dictionary) -> bool: return int(c.dir) == 3 and int(c.line) == 0)
	assert_eq(south.size(), 1)
	assert_eq((south[0].storeys as Array).size(), 1, "storey 2's run differs from storey 1's")
	var f := FIXTURE.build({"lone": true, "replace_front": mass})
	assert_eq(FIXTURE.leans_on(f.front, 3), [-1.0, 0.0, 0.0, 0.0] as Array[float],
		"one storey in the chain: its top (storey 1) stays on the line, the ground steps one jetty in")


func _portal(front: BuildingMass) -> void:
	var edge := BuildingMass.edge_key(Vector2i(1, 0), 3)
	front.storeys[2].openings[edge] = BuildingMass.OPENING_DOOR
	front.storeys[2]["passage_edges"] = {edge: true}


func test_skywalk_portal_storey_stays_on_the_lot_line() -> void:
	# Storey 2 carries a skywalk passage: it neither stands in nor overhangs, so the
	# cap drops until it stands on the line over a storey on the line; below it the
	# face still steps in.
	var f := FIXTURE.build({"lone": true, "prepare": _portal})
	assert_eq(FIXTURE.leans_on(f.front, 3), [-1.0, 0.0, 0.0, 0.0] as Array[float])
	var causes := (f.result.rejections as Array).map(func(r: Dictionary) -> StringName: return r.cause)
	assert_true(causes.has(&"portal"), str(causes))
	# A skywalk on the top storey costs nothing: the top never moves.
	var g := FIXTURE.build({"lone": true, "prepare": func(front: BuildingMass) -> void:
		var edge := BuildingMass.edge_key(Vector2i(1, 0), 3)
		front.storeys[3].openings[edge] = BuildingMass.OPENING_DOOR
		front.storeys[3]["passage_edges"] = {edge: true}})
	assert_eq(FIXTURE.leans_on(g.front, 3), [-2.0, -1.0, 0.0, 0.0] as Array[float])


func test_a_ground_storey_against_a_lower_neighbour_keeps_the_face_flush() -> void:
	# A one-storey neighbour touches the ground storey's south face: a party wall never
	# steps in, so no storey above may overhang it.
	var low := FIXTURE.house(&"kit.fixture.low", Rect2i(0, -1, 3, 1), 1, 3)
	var f := FIXTURE.build({"lone": true, "extra": [low]})
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 0.0, 0.0, 0.0] as Array[float])
	var causes := (f.result.rejections as Array).map(func(r: Dictionary) -> StringName: return r.cause)
	assert_true(causes.has(&"party"), str(causes))


func test_a_bay_keeps_its_storey_on_the_lot_line() -> void:
	# A bay on a stepped-in run would stand under the overhang's braces: storey 1 keeps
	# the line (the cap drops to one light step), the ground still steps in under it.
	var f := FIXTURE.build({"lone": true, "character": FIXTURE.character({}, &"0.5"),
		"prepare": func(front: BuildingMass) -> void:
			front.storeys[1].openings[BuildingMass.edge_key(Vector2i(1, 0), 3)] = BuildingMass.OPENING_BAY})
	assert_eq(FIXTURE.leans_on(f.front, 3), [-0.5, 0.0, 0.0, 0.0] as Array[float])
	var catalog := EnvironmentCatalog.load_default()
	var bays := (f.parts as Array).filter(func(p: Dictionary) -> bool: return String(p.role).begins_with("bay."))
	assert_eq(bays.size(), 1)
	assert_lt((bays[0].transform * catalog.descriptor(bays[0].asset_id).measured_aabb).get_center().z, 0.0,
		"the bay stands on the lot-line face")


func test_dressing_on_a_stepped_in_run_moves_in_or_yields() -> void:
	var f := FIXTURE.build({"lone": true, "prepare": func(front: BuildingMass) -> void:
		front.decor.append({"kind": &"ivy", "centre": Vector2(1.5, 0.0), "dir": 3, "y": 0.0, "proud": 0.0})
		front.decor.append({"kind": &"window_box", "centre": Vector2(0.5, 0.0), "dir": 3, "y": 3.0})})
	assert_eq(FIXTURE.leans_on(f.front, 3), [-2.0, -1.0, 0.0, 0.0] as Array[float])
	for item: Dictionary in f.front.decor:
		if int(item.get("dir", -1)) == 3 and item.kind in [&"ivy", &"window_box"]:
			var expected := 1.0 if float(item.y) < 3.0 else 0.5 # its storey's offset / -2, cells
			assert_almost_eq((item.centre as Vector2).y, expected, 1e-6,
				"%s moved in with its wall (or yielded)" % item.kind)


func test_withdrawn_steps_name_their_guardrail() -> void:
	var f := FIXTURE.build({"lone": true, "reserved": func(_own: StringName, cell: Vector2i, band: int) -> bool:
		return cell.y == 0 and band <= 1})
	var columns := (f.result.rejections as Array).filter(func(r: Dictionary) -> bool: return r.cause == &"columns")
	assert_gt(columns.size(), 0, str(f.result.rejections))
	for record: Dictionary in columns:
		assert_eq(int(record.storey), -1, "the ground storey")
		assert_true(float(record.lean) in [-2.0, -1.0], "at its offset for the cap tried: %s" % record)


## Moved dressing stands somewhere else: its obstacle records are replaced, so a later
## step (another face of the house) tests against where it now is.
func test_moved_decor_refreshes_its_obstacles() -> void:
	var kit := SuntailBuildingKit.create()
	var catalog := EnvironmentCatalog.load_default()
	var mass := FIXTURE.house(&"kit.fixture.front", Rect2i(0, 0, 3, 2), 3, 1)
	var box := {"kind": &"window_box", "centre": Vector2(1.5, 0.0), "dir": 3, "y": 3.0}
	mass.decor.append(box)
	var none := Callable(FIXTURE, "nothing_solid")
	var masses: Array[BuildingMass] = [mass]
	var chain: Dictionary = FIXTURE.GROWTH.face_chains(mass, none, Callable(FIXTURE, "street")).filter(
		func(c: Dictionary) -> bool: return int(c.dir) == 3)[0]
	var member := {"mass": mass, "chain": chain, "kit": kit, "seed": true}
	var ctx := {"catalog": catalog, "air": [] as Array[Dictionary], "towers": [] as Array[Dictionary],
		"reserved": none, "solid": none, "kit": kit, "rejections": [], "yields": {}, "planned": {},
		"front": {"members": [member], "joins": []}, "active": [0] as Array[int],
		"obstacles": FIXTURE.GROWTH._obstacles(masses, {&"fixture.front": kit}, kit, catalog, [], none)}
	var out: Array[Dictionary] = []
	var closures := [[&"return", &"return"], [&"return", &"return"], [&"return", &"return"]]
	FIXTURE.GROWTH._commit(member, [1.0, 2.0] as Array[float], closures, ctx, out)
	assert_almost_eq((box.centre as Vector2).y, 0.5, 1e-6, "the window box moved in with storey 1 (-1.0)")
	var live := (ctx.obstacles as Array).filter(func(o: Dictionary) -> bool:
		return o.has("decor") and is_same(o.decor, box) and not bool(o.get("gone", false)))
	assert_gt(live.size(), 0)
	for obstacle: Dictionary in live:
		assert_gt((obstacle.bounds as AABB).get_center().z, 0.0, "obstacle at the moved box")
```

Also replace `test_own_bay_on_the_stepping_face_moves_with_it`, `test_own_ornaments_under_the_new_braces_yield` and `test_decor_the_step_does_not_move_never_rides` by the bay and dressing tests above (delete those three).

`tests/test_growing_floors_wrap.gd` (replace the first two tests and `_corners_consistent`; delete `_wrapped_pair`, `_within`, `test_a_wrapped_corner_is_closed_by_strips_squares_and_a_post`, `test_extension_strips_are_flush_with_their_face`; keep `test_right_extend_is_zero_without_growth`):

```gdscript
func _closures(f: Dictionary, dir: int, band: int) -> Array:
	for lean: Dictionary in f.leans:
		if lean.host == f.front.stable_id and int(lean.dir) == dir and int(lean.band) == band:
			return lean.closures
	return []


func test_a_growing_face_pulls_its_corner_neighbours_one_hop() -> void:
	var f := FIXTURE.build() # only the south face is rolled; east and west are pulled
	# East and west step in from both sides of a three-module plan: at the two-jetty cap
	# they would leave a one-module stalk (bearing), so the front holds at one jetty.
	for dir: int in [3, 0, 2]:
		assert_eq(FIXTURE.leans_on(f.front, dir), [-1.0, 0.0, 0.0, 0.0] as Array[float], "face %d" % dir)
	assert_eq(FIXTURE.leans_on(f.front, 1), [0.0, 0.0, 0.0, 0.0] as Array[float], "north: not pulled")
	assert_eq(_closures(f, 3, 0), [&"wrap", &"wrap"])
	var causes := (f.result.rejections as Array).map(func(r: Dictionary) -> StringName: return r.cause)
	assert_true(causes.has(&"bearing"), str(causes))


func test_a_member_that_cannot_hold_leaves_the_front() -> void:
	# The east face's ground storey carries a passage: it cannot stand in at any cap, so
	# it leaves; south and west refit without it and reach the cap.
	var f := FIXTURE.build({"prepare": func(front: BuildingMass) -> void:
		var edge := BuildingMass.edge_key(Vector2i(2, 1), 0)
		front.storeys[0].openings[edge] = BuildingMass.OPENING_DOOR
		front.storeys[0]["passage_edges"] = {edge: true}})
	assert_eq(FIXTURE.leans_on(f.front, 0), [0.0, 0.0, 0.0, 0.0] as Array[float], "east left the front")
	for dir: int in [3, 2]:
		assert_eq(FIXTURE.leans_on(f.front, dir), [-2.0, -1.0, 0.0, 0.0] as Array[float], "face %d" % dir)
	assert_eq(_closures(f, 3, 0), [&"return", &"wrap"], "south: east end returns, west end wraps")
	var causes := (f.result.rejections as Array).map(func(r: Dictionary) -> StringName: return r.cause)
	assert_true(causes.has(&"portal"), str(causes))


## Two faces of one storey that meet at a convex corner stand in equally or one is on its line.
func _corners_consistent(mass: BuildingMass) -> bool:
	for storey: Dictionary in mass.storeys:
		var offsets: Dictionary = storey.get("wall_offsets", {})
		for slot: Dictionary in BuildingKitAssembler.storey_slots(storey):
			if not bool(slot.right_convex):
				continue
			var edge: Vector3i = slot.edge
			var side := BuildingMass.DIRS.find(BuildingKitAssembler.right_of(int(slot.dir)))
			var mine := float(offsets.get(edge, 0.0))
			var theirs := float(offsets.get(BuildingMass.edge_key(Vector2i(edge.x, edge.y), side), 0.0))
			if mine < 0.0 and theirs < 0.0 and absf(mine - theirs) > 1e-6:
				return false
	return true
```

(`test_unequal_steps_never_meet_at_a_convex_corner` keeps its body; the options loop stays `[{}, {"character": _all_faces()}, {"lone": true}]`.)

`tests/test_growing_floors_rows.gd` (`_row` and the first three tests; `test_rows_join_only_on_the_same_first_upper_storey` unchanged):

```gdscript
func _row() -> Dictionary:
	# front (x 0..2) and side (x 3..4) share the south line z = 0; the front's west face
	# is kept out of the front, so the row is just the two south faces.
	var side := FIXTURE.roofed(&"kit.fixture.side", Rect2i(3, 0, 2, 2), 4, 3)
	var f := FIXTURE.build({"extra": [side], "block": [2]})
	f["side"] = side
	return f


func test_a_terrace_row_steps_in_as_one() -> void:
	var f := _row()
	assert_false(f.side.grows, "the neighbour did not roll growth: the row pulled it")
	assert_eq(FIXTURE.leans_on(f.front, 3), [-2.0, -1.0, 0.0, 0.0] as Array[float])
	assert_eq(FIXTURE.leans_on(f.side, 3), [-2.0, -1.0, 0.0, 0.0] as Array[float])
	for band: int in [0, 2, 4]:
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
		var role := String(part.role)
		if not (role.begins_with("frontage.") or role.begins_with("bracket.")):
			continue
		var box: AABB = part.transform * catalog.descriptor(part.asset_id).measured_aabb
		assert_false(absf(box.get_center().x - 6.0) < 0.3 and box.get_center().z > 0.0
			and String(part.role).begins_with("frontage.return"), "no return piece at the shared joint x = 6")
	var strips := parts.filter(func(p: Dictionary) -> bool: return String(p.role) == "frontage.return.d100")
	assert_eq(strips.size(), 2, "the two open row ends' corner panels on storey 1 (the ground's are dropped)")
	var joint_braces := parts.filter(func(p: Dictionary) -> bool:
		var box: AABB = p.transform * catalog.descriptor(p.asset_id).measured_aabb
		return p.role == &"bracket.jetty" and absf(box.get_center().x - 6.0) < 0.3 and box.end.y < 3.1)
	assert_eq(joint_braces.size(), 1, "one brace at the row joint under storey 1, not one per house")


func test_a_row_member_with_a_portal_holds_the_row_below_it() -> void:
	# The neighbour's second upper storey carries a portal: it may not overhang, so the
	# whole row holds one jetty (both houses step in one jetty at the ground).
	var side := FIXTURE.roofed(&"kit.fixture.side", Rect2i(3, 0, 2, 2), 4, 3)
	var edge := BuildingMass.edge_key(Vector2i(3, 0), 3)
	side.storeys[2].openings[edge] = BuildingMass.OPENING_DOOR
	side.storeys[2]["passage_edges"] = {edge: true}
	var f := FIXTURE.build({"extra": [side], "block": [2]})
	assert_eq(FIXTURE.leans_on(f.front, 3), [-1.0, 0.0, 0.0, 0.0] as Array[float])
	assert_eq(FIXTURE.leans_on(side, 3), [-1.0, 0.0, 0.0, 0.0] as Array[float])


func test_a_row_member_that_cannot_step_withdraws_the_joint_not_the_town() -> void:
	# The neighbour's ground storey carries a passage: it cannot stand in at all and
	# leaves the row; the front's east end then stands beside a building that does not
	# step (blocked), so the front stays flush too. Both houses still build.
	var side := FIXTURE.roofed(&"kit.fixture.side", Rect2i(3, 0, 2, 2), 4, 1)
	var edge := BuildingMass.edge_key(Vector2i(3, 0), 3)
	side.storeys[0].openings[edge] = BuildingMass.OPENING_DOOR
	side.storeys[0]["passage_edges"] = {edge: true}
	var f := FIXTURE.build({"extra": [side], "block": [2]})
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 0.0, 0.0, 0.0] as Array[float])
	assert_eq(FIXTURE.leans_on(side, 3), [0.0, 0.0, 0.0, 0.0] as Array[float])
	assert_false((f.parts as Array).is_empty(), "the house still builds")
	var causes := (f.result.rejections as Array).map(func(r: Dictionary) -> StringName: return r.cause)
	assert_true(causes.has(&"portal") and causes.has(&"ends"), str(causes))
```

`tests/test_growing_floors_bury.gd` (whole file; the neighbour-in-front fixture now only proves it no longer matters):

```gdscript
extends GutTest
## Inside-corner ends under step-in (spec Amendment 2): an end beside the house's own
## cell closes its recess with a strip (bury); a building standing in front of an end
## no longer matters (nothing moves outward).
const FIXTURE := preload("res://tests/fixtures/growing_house.gd")


## A five-storey neighbour standing in the lane beyond the front's east end (cells
## x 3..4, z -2..-1), windowed on its west wall.
func _corner() -> BuildingMass:
	return FIXTURE.roofed(&"kit.fixture.corner", Rect2i(3, -2, 2, 2), 5, 0)


func _east_closure(f: Dictionary, band: int) -> StringName:
	for lean: Dictionary in f.leans:
		if lean.host == f.front.stable_id and int(lean.dir) == 3 and int(lean.band) == band:
			return lean.closures[0] # dir 3: left = the east end
	return &""


func test_a_neighbour_in_front_of_an_end_no_longer_blocks_it() -> void:
	var f := FIXTURE.build({"extra": [_corner()], "lone": true})
	assert_eq(FIXTURE.leans_on(f.front, 3), [-2.0, -1.0, 0.0, 0.0] as Array[float])
	for band: int in [0, 2]:
		assert_eq(_east_closure(f, band), &"return", "band %d" % band)


## An L-shaped house: a four-storey body (x 0..2) and a five-storey wing (x 3,
## z -1..1) standing out in front of the body's south face.
func _own_wing() -> BuildingMass:
	var mass := BuildingMass.new()
	mass.stable_id = &"kit.fixture.front"
	mass.seed = hash("kit.fixture.front")
	var cells := BuildingMass.rect_cells(Rect2i(0, 0, 3, 2))
	var wing := {Vector2i(3, -1): true, Vector2i(3, 0): true, Vector2i(3, 1): true}
	cells.merge(wing)
	for s in 5:
		mass.add_storey(s * 2, (cells if s < 4 else wing).duplicate(), BuildingMass.MATERIAL_TIMBER)
	mass.storeys[0].openings[BuildingMass.edge_key(Vector2i(1, 0), 3)] = BuildingMass.OPENING_DOOR
	mass.add_roof(Rect2i(0, 0, 3, 2), 1, 8, &"red")["union_index"] = 0
	mass.add_roof(Rect2i(3, -1, 1, 3), 1, 10, &"red")["union_index"] = 1
	return mass


func test_a_concave_end_closes_its_recess_against_the_own_wing() -> void:
	var mass := _own_wing()
	var f := FIXTURE.build({"replace_front": mass, "lone": true})
	assert_eq(FIXTURE.leans_on(mass, 3), [-2.0, -1.0, 0.0, 0.0, 0.0] as Array[float])
	for band: int in [0, 2]:
		assert_eq(_east_closure(f, band), &"bury", "band %d" % band)
	var catalog := EnvironmentCatalog.load_default()
	for depth: float in [2.0, 1.0]:
		var strips := (f.parts as Array).filter(func(p: Dictionary) -> bool:
			var box: AABB = p.transform * catalog.descriptor(p.asset_id).measured_aabb
			return String(p.role) == "frontage.return.%s" % BuildingKitAssembler.lean_suffix(depth) \
				and absf(box.get_center().x - 6.0) < 0.3)
		assert_eq(strips.size(), 1, "one recess strip of depth %.1f on the wing's line" % depth)


func test_an_end_whose_own_wall_continues_behind_the_neighbour_is_buried() -> void:
	# The house runs on (x 3) behind the neighbour standing in the lane: the exposed
	# run ends at x 3 beside the house's own cell, so its recess is closed by a strip.
	var mass := FIXTURE.roofed(&"kit.fixture.front", Rect2i(0, 0, 4, 2), 4, 3, 1, 0)
	var f := FIXTURE.build({"replace_front": mass, "extra": [_corner()], "lone": true})
	assert_eq(FIXTURE.leans_on(mass, 3), [-2.0, -1.0, 0.0, 0.0] as Array[float])
	assert_eq(_east_closure(f, 0), &"bury")
```

`tests/test_growing_floors_knobs.gd`: remove `&"growth_gable_front_boost"` from `KNOBS` and the `BOOST_KNOB` assertion; add `assert_false(program.knobs.has(&"growth_gable_front_boost"), "removed by spec Amendment 2")`.

Run each file: red (offsets are still step-out, `block_faces`/`offsets_of` missing, the roofs file still references removed code — delete it in this step).

- [ ] **Step 2: Remove the superseded roof code.** `git show 9419f7dab:scripts/terrain/features/villages/kit/BuildingDesigner.gd > /tmp/designer_9419.gd` and restore its `articulate` first lines and `_square_axis` (the only Task 8 changes there). In `KitVillageBuildings.gd` apply the four edits listed under Files. In `town_odds.tres` delete the boost sub-resource and its `knobs` entry; notes: `growing_house_chance` "… eligible houses (two stacked storeys and an exposed face) …" (Task 1 deferred minor), `growth_max_lean` "Total step-in of the ground storey below the top storey, native m (2.0 = two kit jetties, 4 m world), floored to whole steps; the top storey and roof never move (spec Amendment 2).", `lane_sky_gap` "Inert under step-in (insets never narrow a lane); the guardrail value for any outward offset (G2, room projections facing a growth registry entry)." In `BuildingKitAssembler.gd` delete the items listed under Files.

- [ ] **Step 3: `KitGrowingFronts` re-referenced.**

Kept as they are: the knob constants (minus `BOOST_KNOB`), `STEP_SIZES`, `MAX_STEPS`, `LEAN_DEPTHS`, `FRONT_ROLES`, `carried_step`, `_own`, `_storey_at`, `ground_index`, `_run_key`, `_exposed_runs`, `_is_street`, `house_grows`, `CLEARANCE`, `_edges`, `_point`, `_joins`, `_convex`, `fronts`, `_closures`, `_obstacles`, `_obstacle`, `_assembler`, `clear_of`, `TOUCH`, `YIELD_DECOR`, `_seated`, `contact_clear`, `_obstacle_cause`, `_drop_decor`, `gap_ok` and `MAX_LANE_MODULES` (room projections use them), `_decor_edge`, `_on_storey`.

Removed (no step-in use): `_front_step` (the leader's step is `carried_step` inline), `_publish_riders`, `_bury_contact`, `PLAIN_CONTACT`, `BURY_DROP`, `_end_open`, `_candidate`, `_moves`, `_yield`, `_bury_owners`, `OWN_OBSTACLES`, `crown_index`, `_face_slab`, the old `_parts_fault`, `_riders_of`, `_host_part`, `_columns_free`, and the whole roofs and eave-inset sections (`UNION`, `EAVE_*`, `roof_geometry`, `crown_wing`, `eave_allowance`, `_gable_shift_fault`, `_skin_meets`, `_on_face`, `_blocks_gable`, `_moves_with_front`, `_behind`, `_crown_fault`, `_eave_cap`, `INSET_DECOR`, `NO_EDGE`, `_inset_cause`, `_inset_corners`, `_corner_edges`, `_write_inset`, `_erase_inset`, `_inset_parts`, `_inset_parts_fault`, `_apply_inset`, `_try_inset`, `_record_roof`). `_decor_edge` returns `Vector3i(-1048576, 0, 0)` inline for dressing without a face.

`face_chains` adds `"ground": g` to every chain. `house_eligible` and `fit` share one predicate (Task 6 deferred minor):

```gdscript
## Houses growth never touches (the town's retaining wall rooms).
static func _excluded(mass: BuildingMass) -> bool:
	return String(mass.stable_id).contains("wall-room")
```

`fit` drops its `roof_geometry` parameter and the roof/inset ctx keys; its ctx is `{"catalog", "air", "towers", "reserved", "solid", "registry": {}, "obstacles", "kit", "rejections": [], "planned": {}, "yields": {}, "front": {}, "active": [], "masses": {}}` and it returns `{"leans", "registry", "rejections"}`. Changed and new functions:

```gdscript
## The storeys of a face from its ground storey up.
static func _storeys(chain: Dictionary) -> Array[int]:
	var out: Array[int] = [int(chain.ground)]
	out.append_array(chain.storeys)
	return out


## Storey index of face storey k (k = -1: the ground storey).
static func _storey_index(chain: Dictionary, k: int) -> int:
	return int(chain.ground) if k < 0 else int(chain.storeys[k])


## Offsets (native m, <= 0) of a face's storeys from the ground up for one profile
## (spec Amendment 2): storey k stands `leans[k] - top` inside its line, the ground
## storey `-top`, so the top storey (and the roof on it) never moves.
static func offsets_of(leans: Array[float]) -> Array[float]:
	var top: float = leans.back() if not leans.is_empty() else 0.0
	var out: Array[float] = [-top]
	for lean: float in leans:
		out.append(lean - top)
	return out


## One front. The leader (its first active member that rolled growth) sets the step
## its kit carries and the cap; a member that leaves is dropped and the rest refit.
## Members that left are fitted alone afterwards if they were seeds.
static func _fit_front(front: Dictionary, character: TownCharacter, ctx: Dictionary,
		out: Array[Dictionary]) -> void:
	var active: Array[int] = []
	for m in (front.members as Array).size():
		active.append(m)
	var left: Array[int] = []
	var leans: Array[float] = []
	ctx.front = front
	ctx.active = active
	while not active.is_empty():
		var leader: Dictionary = front.members[_leader(front, active)]
		var step := carried_step(leader.kit, float(String(character.pick(STEP_KNOB, String(leader.mass.stable_id)))))
		if not STEP_SIZES.has(step):
			return
		var cap := step * float(mini(MAX_STEPS, floori(character.value(CAP_KNOB) / step + 0.0001)))
		var result := _front_profile(front, active, step, cap, ctx)
		if int(result.leaves) < 0:
			leans = result.leans
			break
		active.erase(int(result.leaves))
		left.append(int(result.leaves))
	if not leans.is_empty() and leans.max() > 0.0:
		var closures := {}
		for m: int in active:
			closures[m] = _member_closures(front, active, m, ctx)
		# Dressing on every corner panel a member cuts goes before any member is
		# written (a wrapped partner would otherwise move it along its own run).
		for m: int in active:
			_drop_cut_decor(front.members[m], _slice(leans, front.members[m]), closures[m], ctx)
		for m: int in active:
			ctx.kit = front.members[m].kit
			_commit(front.members[m], _slice(leans, front.members[m]), closures[m], ctx, out)
	for m: int in left:
		if bool(front.members[m].seed):
			_fit_front({"members": [front.members[m]], "joins": []}, character, ctx, out)


## The front's leader: its first active member that rolled growth (a pulled
## neighbour never sets the step; Task 6 deferred minor), else its first member.
static func _leader(front: Dictionary, active: Array[int]) -> int:
	for m: int in active:
		if bool(front.members[m].seed):
			return m
	return active[0]


## A member's part of the front's profile (one lean per storey of its chain).
static func _slice(leans: Array[float], member: Dictionary) -> Array[float]:
	var out: Array[float] = []
	out.assign(leans.slice(0, (member.chain.storeys as Array).size()))
	return out


## [left, right] closures of member m per storey from the ground up (index 0 = ground).
static func _member_closures(front: Dictionary, active: Array[int], m: int, ctx: Dictionary) -> Array:
	ctx.kit = front.members[m].kit
	var out: Array = []
	for i in _storeys(front.members[m].chain).size():
		out.append(_closures(front, active, m, i - 1, ctx))
	return out


## The front's monotone capped profile (index k = k-th storey above the ground storey),
## tested at its final step-in offsets: steps run only up to the shortest active
## member's top storey (every member's top is then the same, so joints and wraps stay
## equal at every shared storey; above it every member holds). On a failure the cap
## drops one step for the whole front (the old "hold from the failing storey up"); a
## member failing at the smallest cap leaves when others remain ({leaves: m}). A lone
## member failing there stays flush.
static func _front_profile(front: Dictionary, active: Array[int], step: float, cap: float,
		ctx: Dictionary) -> Dictionary:
	var depth := 0
	var reach := 1000
	for m: int in active:
		var n := (front.members[m].chain.storeys as Array).size()
		depth = maxi(depth, n)
		reach = mini(reach, n)
	var top := minf(cap, step * float(reach))
	while top > 0.0001:
		var leans: Array[float] = []
		for k in depth:
			leans.append(minf(float(k + 1) * step, top))
		var fault := _front_fault(front, active, leans, ctx)
		if fault.is_empty():
			return {"leans": leans, "leaves": -1}
		_reject(ctx, front, fault)
		if top <= step + 0.0001 and active.size() > 1:
			return {"leaves": int(fault.member), "fault": fault}
		top -= step
	var flat: Array[float] = []
	flat.resize(depth)
	flat.fill(0.0)
	return {"leans": flat, "leaves": -1}


## The first active member whose step-in fails at these leans, as {member, cause,
## storey (-1 = ground), depth}, or {} (each member's yielding ornaments are left in
## ctx.yields). Every storey from the ground up is tested at its final offset;
## ctx.planned holds every active member's offsets so opposite faces of one house see
## each other (bearing).
static func _front_fault(front: Dictionary, active: Array[int], leans: Array[float], ctx: Dictionary) -> Dictionary:
	ctx.planned = {}
	for m: int in active:
		var member: Dictionary = front.members[m]
		var offsets := offsets_of(_slice(leans, member))
		var indices := _storeys(member.chain)
		for i in indices.size():
			for edge: Vector3i in _edges(member.chain):
				ctx.planned["%s|%d|%s" % [member.mass.stable_id, indices[i], edge]] = offsets[i]
	for m: int in active:
		var member: Dictionary = front.members[m]
		var own := _slice(leans, member)
		var offsets := offsets_of(own)
		var closures := _member_closures(front, active, m, ctx)
		ctx.kit = member.kit
		for i in offsets.size():
			var base: float = offsets[i - 1] if i > 0 else offsets[i]
			if offsets[i] >= 0.0 and offsets[i] <= base:
				continue
			var cause := &"ends" if (closures[i] as Array).has(&"blocked") \
				else _fault(member.mass, member.chain, i - 1, offsets[i], base, ctx)
			if cause != &"":
				return {"member": m, "cause": cause, "storey": i - 1, "depth": offsets[i]}
		var parts := _parts_fault(member, own, closures, ctx)
		if not parts.is_empty():
			parts["member"] = m
			return parts
	return {}


static func _reject(ctx: Dictionary, front: Dictionary, fault: Dictionary) -> void:
	ctx.rejections.append({"chain": String(front.members[int(fault.member)].chain.key),
		"storey": int(fault.storey), "lean": float(fault.depth), "cause": fault.cause})


## How one end closes at face storey k (-1 = ground): a join to an active member
## present at k gives its kind; otherwise the step-in end rule (spec Amendment 2).
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
	return _inset_end(member.mass, member.chain, at_end, k, ctx)


## A stepped-in end with no front partner: &"bury" when the house's own cell stands
## beside it at both bands (a strip closes the recess); &"return" when the cell beside
## it is open (the perpendicular corner panel shortens); else &"blocked": another
## building beside it (only a row stepping together admits one), own at one band only,
## the perpendicular face already stepped by an earlier front, or a door, passage, bay
## or blank on the corner panel the step would cut.
static func _inset_end(mass: BuildingMass, chain: Dictionary, at_end: bool, k: int, ctx: Dictionary) -> StringName:
	var storey: Dictionary = mass.storeys[_storey_index(chain, k)]
	var dir := int(chain.dir)
	var along := Vector2i(0, 1) if dir % 2 == 0 else Vector2i(1, 0)
	var sign := 1 if at_end else -1
	var cell := BuildingKitAssembler._inside_cell(dir, int(chain.line),
		int(chain.end) - 1 if at_end else int(chain.start))
	var side := cell + along * sign
	var bands := range(int(storey.floor_band), int(storey.floor_band) + int(storey.get("bands", 2)))
	var own := 0
	for b: int in bands:
		if mass.cells_at_band(b).has(side):
			own += 1
		elif bool((ctx.solid as Callable).call(_own(mass), side, b)):
			return &"blocked"
	if own == bands.size():
		return &"bury"
	if own > 0:
		return &"blocked"
	var corner := BuildingMass.edge_key(cell, BuildingMass.DIRS.find(along * sign))
	if float((storey.get("wall_offsets", {}) as Dictionary).get(corner, 0.0)) != 0.0:
		return &"blocked"
	if StringName(storey.openings.get(corner, storey.default_opening)) in [BuildingMass.OPENING_DOOR,
			BuildingMass.OPENING_BAY, BuildingMass.OPENING_NONE] \
			or (storey.get("passage_edges", {}) as Dictionary).has(corner):
		return &"blocked"
	return &"return"


## The first guardrail face storey k (-1 = ground) fails standing `depth` (<= 0)
## inside its line over a storey standing `base` inside, or &"" when it fits
## (spec Amendment 2 "Guardrails under step-in"; ends are checked by _front_fault).
static func _fault(mass: BuildingMass, chain: Dictionary, k: int, depth: float, base: float,
		ctx: Dictionary) -> StringName:
	var storey: Dictionary = mass.storeys[_storey_index(chain, k)]
	if depth > base and (storey.material != BuildingMass.MATERIAL_TIMBER \
			or bool(storey.get("inset", false)) or bool(storey.get("retaining", false)) \
			or bool(storey.get("fortified", false))):
		return &"material" # an overhanging storey is timber on the kit's jetty
	if not _no_portal(mass, chain, k, depth, base):
		return &"portal"
	if depth < 0.0:
		if not _steps_in(storey, depth, ctx.kit):
			return &"material"
		if not _exposed(mass, chain, k, ctx):
			return &"party"
		if not _recess_free(mass, chain, k, ctx):
			return &"columns"
		if not _bears(mass, chain, k, depth, ctx):
			return &"bearing"
		if not _decor_ok(mass, chain, k):
			return &"decor"
	return &""


## A storey that can stand inside its line: two bands, not a terrace skin, sunk or
## abutted course, kit jetty or pent eave; a non-timber storey only by whole modules
## (the kit bakes no stone half strip).
static func _steps_in(storey: Dictionary, depth: float, kit: BuildingKit) -> bool:
	if int(storey.get("bands", 2)) != 2 or bool(storey.get("retaining", false)) \
			or bool(storey.get("fortified", false)) or bool(storey.get("sunk", false)) \
			or bool(storey.get("abutted", false)) or bool(storey.get("inset", false)) \
			or StringName(storey.get("pent_colour", &"")) != &"":
		return false
	if storey.material == BuildingMass.MATERIAL_TIMBER:
		return true
	var modules := -depth / kit.module_width
	return absf(modules - roundf(modules)) < 0.0001


## Party rule: the run is exposed at both bands (no party wall, no touching neighbour
## in front of it, a lower neighbour against the ground storey included).
static func _exposed(mass: BuildingMass, chain: Dictionary, k: int, ctx: Dictionary) -> bool:
	var storey: Dictionary = mass.storeys[_storey_index(chain, k)]
	var band := int(storey.floor_band)
	for edge: Vector3i in _edges(chain):
		var outward := Vector2i(edge.x, edge.y) + BuildingMass.DIRS[int(chain.dir)]
		for b in range(band, band + int(storey.get("bands", 2))):
			if mass.cells_at_band(b).has(outward) or bool((ctx.solid as Callable).call(_own(mass), outward, b)):
				return false
	return true


## G3 under step-in: the recess cells themselves carry no passage, podium or other
## owner's claim (nothing beyond the face matters any more).
static func _recess_free(mass: BuildingMass, chain: Dictionary, k: int, ctx: Dictionary) -> bool:
	var storey: Dictionary = mass.storeys[_storey_index(chain, k)]
	var band := int(storey.floor_band)
	for edge: Vector3i in _edges(chain):
		for b in range(band, band + int(storey.get("bands", 2))):
			if bool((ctx.reserved as Callable).call(_own(mass), Vector2i(edge.x, edge.y), b)):
				return false
	return true


## Bearing: behind every stepped-in edge at least one module of floor remains, at
## least two across an axis stepped in from both sides (the kit's jetty never leaves a
## one-module stalk), counting the opposite face's committed or same-front offset.
static func _bears(mass: BuildingMass, chain: Dictionary, k: int, depth: float, ctx: Dictionary) -> bool:
	var kit: BuildingKit = ctx.kit
	var index := _storey_index(chain, k)
	var cells: Dictionary = mass.storeys[index].cells
	var dir := int(chain.dir)
	var inward: Vector2i = -BuildingMass.DIRS[dir]
	var back := (dir + 2) % 4
	for edge: Vector3i in _edges(chain):
		var far := Vector2i(edge.x, edge.y)
		var modules := 1
		while cells.has(far + inward):
			far += inward
			modules += 1
		var opposite := _planned(mass, index, BuildingMass.edge_key(far, back), kit, ctx)
		var keep := float(modules) * kit.module_width + depth + opposite
		var need := (2.0 if opposite < 0.0 else 1.0) * kit.module_width
		if keep < need - 0.0001:
			return false
	return true


## The offset (native m, <= 0) one edge will stand at: this front's plan, else committed.
static func _planned(mass: BuildingMass, index: int, edge: Vector3i, kit: BuildingKit, ctx: Dictionary) -> float:
	var key := "%s|%d|%s" % [mass.stable_id, index, edge]
	if (ctx.planned as Dictionary).has(key):
		return minf(0.0, float(ctx.planned[key]))
	return minf(0.0, float((mass.storeys[index].get("wall_offsets", {}) as Dictionary).get(edge, 0.0))) * kit.module_width


## A porch post standing on or within one module in front of the run (at the storey's
## bands) would be left in the recess or cut by the moved wall: the step is withdrawn.
static func _decor_ok(mass: BuildingMass, chain: Dictionary, k: int) -> bool:
	var storey: Dictionary = mass.storeys[_storey_index(chain, k)]
	var lo := int(storey.floor_band)
	var hi := lo + int(storey.get("bands", 2))
	var dir := int(chain.dir)
	var sign := 1.0 if dir < 2 else -1.0
	for item: Dictionary in mass.decor:
		if StringName(item.kind) != &"post" or int(item.get("from_band", hi)) >= hi \
				or int(item.get("to_band", lo)) <= lo:
			continue
		var vertex: Vector2 = item.centre
		var line := vertex.x if dir % 2 == 0 else vertex.y
		var along := vertex.y if dir % 2 == 0 else vertex.x
		var ahead := (line - float(chain.line)) * sign
		if ahead >= -0.001 and ahead <= 1.001 and along >= float(chain.start) - 0.001 \
				and along <= float(chain.end) + 0.001:
			return false
	return true


# G6 under step-in: a storey with a skywalk/bridge passage or a blank on its run, or
# whose wall (or the storey above's) bears a balcony, neither stands in nor overhangs
# (depth == base == 0). A bay or a door on a stepped-in UPPER storey withdraws the
# step; a door on the ground storey is a recessed shopfront (it moves in with its wall).
static func _no_portal(mass: BuildingMass, chain: Dictionary, k: int, depth: float, base: float) -> bool:
	if depth >= 0.0 and base >= 0.0:
		return true
	var storey: Dictionary = mass.storeys[_storey_index(chain, k)]
	if bool(storey.get("bears_balcony", false)):
		return false
	var above := _storey_at(mass, int(storey.floor_band) + int(storey.get("bands", 2)))
	if not above.is_empty() and bool(above.get("bears_balcony", false)):
		return false
	var passages: Dictionary = storey.get("passage_edges", {})
	for edge: Vector3i in _edges(chain):
		if passages.has(edge):
			return false
		var opening := StringName(storey.openings.get(edge, storey.default_opening))
		if opening == BuildingMass.OPENING_NONE:
			return false
		if depth < 0.0 and (opening == BuildingMass.OPENING_BAY or (opening == BuildingMass.OPENING_DOOR and k >= 0)):
			return false
	return true
```

Probe, commit and apply:

```gdscript
## Pieces a step-in adds that dressing may meet (the jetty: braces, beams, strips).
const JETTY_ROLES: Array[String] = ["bracket.", "trim.floor_beam", "frontage."]


## The face storey (k, -1 = ground) a piece at height y belongs to.
static func _storey_at_y(member: Dictionary, y: float, kit: BuildingKit) -> int:
	var indices := _storeys(member.chain)
	var found := -1
	for i in indices.size():
		if float((member.mass as BuildingMass).storeys[indices[i]].floor_band) * kit.band_height() <= y + 0.001:
			found = i - 1
	return found


static func _snapshot(mass: BuildingMass, chain: Dictionary) -> Dictionary:
	var storeys := {}
	for index: int in _storeys(chain):
		var storey: Dictionary = mass.storeys[index]
		var keep := {}
		for key: String in ["wall_offsets", "growth"]:
			if storey.has(key):
				keep[key] = (storey[key] as Dictionary).duplicate(true)
		if storey.has("projections"):
			keep["projections"] = (storey.projections as Array).duplicate(true)
		storeys[index] = keep
	var centres := []
	for item: Dictionary in mass.decor:
		centres.append([item, item.get("centre")])
	return {"storeys": storeys, "centres": centres}


static func _restore(mass: BuildingMass, saved: Dictionary) -> void:
	for index: int in saved.storeys:
		var storey: Dictionary = mass.storeys[index]
		for key: String in ["wall_offsets", "projections", "growth"]:
			storey.erase(key)
		storey.merge(saved.storeys[index])
	for pair: Array in saved.centres:
		(pair[0] as Dictionary)["centre"] = pair[1]


## One member's step-in written onto its house and undone again: the architecture
## it adds (the house assembled with and without it, compared by asset and pose) and
## the dressing it moves, with that dressing's new pieces.
static func _added_parts(member: Dictionary, leans: Array[float], closures: Array, ctx: Dictionary) -> Dictionary:
	var mass: BuildingMass = member.mass
	var assembler := _assembler(mass, member.kit, ctx.solid)
	var decor := mass.decor.duplicate()
	mass.decor.clear()
	var before := {}
	for part: Dictionary in assembler.assemble(mass):
		before["%s|%s" % [part.asset_id, part.transform]] = true
	mass.decor.assign(decor)
	var saved := _snapshot(mass, member.chain)
	var moved: Array = apply(mass, member.kit, member.chain, leans, closures).moved
	mass.decor.clear()
	var added: Array[Dictionary] = []
	for part: Dictionary in assembler.assemble(mass):
		if not before.has("%s|%s" % [part.asset_id, part.transform]):
			added.append(part)
	mass.decor.assign(decor)
	var dressing: Array[Dictionary] = []
	for item: Dictionary in moved:
		var assembly := {"mass": mass, "out": [] as Array[Dictionary], "serial": 0}
		assembler._assemble_decor(assembly, item)
		dressing.append({"item": item, "parts": assembly.out})
	_restore(mass, saved)
	return {"added": added, "moved": dressing}


## G1 + G3 under step-in: the pieces one member's step-in adds clear walking air and
## every other building (its own architecture, and an active row partner's, is what the
## step-in rebuilds). Dressing the new jetty pieces meet — kept dressing of the house or
## a partner, or dressing the step moved — yields when of a yielding kind (ctx.yields),
## else the step is withdrawn (obstacle.own). Returns {cause, storey, depth} or {}.
static func _parts_fault(member: Dictionary, leans: Array[float], closures: Array, ctx: Dictionary) -> Dictionary:
	var mass: BuildingMass = member.mass
	var catalog: EnvironmentCatalog = ctx.catalog
	var probe := _added_parts(member, leans, closures, ctx)
	var partners := {}
	for m: int in ctx.active:
		partners[(ctx.front.members[m].mass as BuildingMass).stable_id] = true
	var moved: Array = (probe.moved as Array).map(func(d: Dictionary) -> Dictionary: return d.item)
	var yields: Array = []
	var top: float = leans.back()
	for part: Dictionary in probe.added:
		var local: AABB = catalog.descriptor(part.asset_id).measured_aabb
		var box: AABB = (part.transform * local).grow(-0.002)
		var fault := {"cause": &"", "storey": _storey_at_y(member, box.get_center().y, member.kit), "depth": -top}
		if CLEARANCE.intersects_air(local, part.transform, ctx.air):
			fault.cause = &"air"
			return fault
		var jetty := JETTY_ROLES.any(func(prefix: String) -> bool: return String(part.role).begins_with(prefix))
		for obstacle: Dictionary in ctx.obstacles:
			if bool(obstacle.get("gone", false)) or contact_clear(box, obstacle.bounds):
				continue
			if not partners.has(obstacle.owner):
				fault.cause = _obstacle_cause(obstacle, mass)
				return fault
			if not jetty or not obstacle.has("decor") or moved.any(func(i: Dictionary) -> bool: return is_same(i, obstacle.decor)):
				continue # rebuilt architecture, or dressing whose new place is tested below
			if StringName(obstacle.decor.kind) in YIELD_DECOR:
				if not yields.any(func(i: Dictionary) -> bool: return is_same(i, obstacle.decor)):
					yields.append(obstacle.decor)
				continue
			fault.cause = &"obstacle.own"
			return fault
		if not jetty:
			continue
		for dressed: Dictionary in probe.moved:
			for piece: Dictionary in dressed.parts:
				if contact_clear(box, piece.transform * catalog.descriptor(piece.asset_id).measured_aabb):
					continue
				if not (StringName(dressed.item.kind) in YIELD_DECOR):
					fault.cause = &"obstacle.own"
					return fault
				if not yields.any(func(i: Dictionary) -> bool: return is_same(i, dressed.item)):
					yields.append(dressed.item)
	for dressed: Dictionary in probe.moved:
		for piece: Dictionary in dressed.parts:
			var local: AABB = catalog.descriptor(piece.asset_id).measured_aabb
			if CLEARANCE.intersects_air(local, piece.transform, ctx.air):
				return {"cause": &"air", "storey": _storey_at_y(member, (piece.transform * local).get_center().y,
					member.kit), "depth": -top}
	(ctx.yields as Dictionary)[String(member.chain.key)] = yields
	return {}


## Dressing on the corner panels this member's stepped-in storeys cut (the
## perpendicular face's end panel at a `return` or `wrap` end; a corner climber on the
## face's own end panel there) goes: its panel is shortened or gone.
static func _drop_cut_decor(member: Dictionary, leans: Array[float], closures: Array, ctx: Dictionary) -> void:
	var mass: BuildingMass = member.mass
	var chain: Dictionary = member.chain
	var dir := int(chain.dir)
	var along := Vector2i(0, 1) if dir % 2 == 0 else Vector2i(1, 0)
	var offsets := offsets_of(leans)
	var indices := _storeys(chain)
	for i in indices.size():
		if offsets[i] >= 0.0:
			continue
		var storey: Dictionary = mass.storeys[indices[i]]
		for at_end: bool in [false, true]:
			# _closures' order: [start, end] for dirs 1 and 2, [end, start] otherwise.
			var side := (1 if at_end else 0) if (dir == 1 or dir == 2) else (0 if at_end else 1)
			if not (StringName(closures[i][side]) in [&"return", &"wrap"]):
				continue
			var sign := 1 if at_end else -1
			var cell := BuildingKitAssembler._inside_cell(dir, int(chain.line), int(chain.end) - 1 if at_end else int(chain.start))
			var cut := [BuildingMass.edge_key(cell, BuildingMass.DIRS.find(along * sign)), BuildingMass.edge_key(cell, dir)]
			for item: Dictionary in mass.decor.duplicate():
				var edge := _decor_edge(item)
				if _on_storey(item, storey, member.kit) and (edge == cut[0] \
						or (StringName(item.kind) == &"ivy_corner" and edge == cut[1])):
					mass.decor.erase(item)
					_drop_decor(ctx, item)


static func _commit(member: Dictionary, leans: Array[float], closures: Array, ctx: Dictionary,
		out: Array[Dictionary]) -> void:
	var mass: BuildingMass = member.mass
	var kit: BuildingKit = member.kit
	var catalog: EnvironmentCatalog = ctx.catalog
	for item: Dictionary in (ctx.yields as Dictionary).get(String(member.chain.key), []):
		mass.decor.erase(item)
		_drop_decor(ctx, item)
	var probe := _added_parts(member, leans, closures, ctx)
	var written := apply(mass, kit, member.chain, leans, closures)
	for item: Dictionary in written.moved:
		_drop_decor(ctx, item)
		var assembly := {"mass": mass, "out": [] as Array[Dictionary], "serial": 0}
		_assembler(mass, kit, ctx.solid)._assemble_decor(assembly, item)
		for part: Dictionary in assembly.out:
			var obstacle := _obstacle(mass, part, catalog)
			obstacle["decor"] = item
			obstacle["host"] = mass
			ctx.obstacles.append(obstacle)
	for part: Dictionary in probe.added:
		ctx.obstacles.append(_obstacle(mass, part, catalog))
	for record: Dictionary in written.records:
		out.append({"host": mass.stable_id, "dir": int(member.chain.dir), "band": int(record.band),
			"lean": float(record.depth), "base": float(record.base), "edges": record.edges,
			"bounds": record.bounds, "chain": member.chain.key, "closures": record.closures,
			"pulled": not mass.grows})


## Writes one face's step-in into its house (spec Amendment 2): storey k of the chain
## stands `leans[k] - top` inside its line and the ground storey `-top` (offsets_of),
## with a growth record on every storey that stands in or overhangs the one below and
## `storey.growth[dir]` on every storey of the face (0.0 on held tops, so room
## projections and bays keep off the face). Dressing on a stepped-in run moves in with
## its wall. `closures[i]` belongs to storey i from the ground up. Returns {records, moved}.
static func apply(mass: BuildingMass, kit: BuildingKit, chain: Dictionary, leans: Array[float],
		closures: Array) -> Dictionary:
	var dir := int(chain.dir)
	var edges := _edges(chain)
	var offsets := offsets_of(leans)
	var indices := _storeys(chain)
	var records: Array[Dictionary] = []
	var moved: Array[Dictionary] = []
	for i in indices.size():
		var storey: Dictionary = mass.storeys[indices[i]]
		var depth: float = offsets[i]
		var base: float = offsets[i - 1] if i > 0 else depth
		var growth: Dictionary = storey.get("growth", {})
		growth[dir] = depth
		storey["growth"] = growth
		if depth >= 0.0 and depth <= base:
			continue
		if depth < 0.0:
			var wall_offsets: Dictionary = storey.get("wall_offsets", {})
			for edge: Vector3i in edges:
				wall_offsets[edge] = depth / kit.module_width
			storey["wall_offsets"] = wall_offsets
			for item: Dictionary in mass.decor:
				if item.has("dir") and int(item.dir) == dir and edges.has(_decor_edge(item)) \
						and _on_storey(item, storey, kit) and not moved.any(func(d: Dictionary) -> bool: return is_same(d, item)):
					item.centre = (item.centre as Vector2) + Vector2(BuildingMass.DIRS[dir]) * depth / kit.module_width
					moved.append(item)
		var record := _record(kit, chain, storey, depth, base, closures[i])
		var fronts_at: Array = storey.get("projections", [])
		fronts_at.append(record.projection)
		storey["projections"] = fronts_at
		records.append(record)
	return {"records": records, "moved": moved}


## One storey's growth record and its recess: the space between its wall (or the wall
## below, whichever stands further in) and the lot line, from one brace drop under its
## floor to its ceiling.
static func _record(kit: BuildingKit, chain: Dictionary, storey: Dictionary, depth: float, base: float,
		closures: Array) -> Dictionary:
	var dir := int(chain.dir)
	var edges := _edges(chain)
	var centres: Array[Vector2] = []
	for edge: Vector3i in edges:
		centres.append(Vector2(edge.x, edge.y) + Vector2.ONE * .5 + Vector2(BuildingMass.DIRS[dir]) * .5)
	var right := Vector2(BuildingKitAssembler.right_of(dir))
	centres.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.dot(right) < b.dot(right))
	var band := int(storey.floor_band)
	var at: Vector2 = centres.front() * kit.module_width
	var pose := Transform3D(Basis(Vector3.UP, BuildingKitAssembler.yaw_for_dir(dir)),
		Vector3(at.x, band * kit.band_height(), at.y))
	var inner := minf(depth, base)
	var body := AABB(Vector3(-kit.module_width * .5, -kit.jetty_depth, inner),
		Vector3(centres.size() * kit.module_width, kit.storey_height + kit.jetty_depth, -inner))
	return {"band": band, "depth": depth, "base": base, "edges": edges, "closures": closures,
		"bounds": pose * body,
		"projection": {"edges": edges, "centres": centres, "dir": dir, "depth": depth, "base": base,
			"band": band, "growth": true, "closures": closures}}
```

`_drop_cut_decor`'s side index follows `_closures`' order; the row test pins it (the front's west end, `closures[i][1]` for dir 3, is the open one).

- [ ] **Step 4: Recessed doors (spec "Recessed doors").** Nothing beyond Step 3 is needed in code: `_no_portal` admits a ground-storey door, `apply` moves its doorstep (and awning, window boxes, ivy) in with the wall, and Task 8 keeps the ground storey's boards whole. Add to `tests/test_growing_floors.gd`:

```gdscript
func test_a_ground_door_is_a_recessed_shopfront() -> void:
	# The fixture's ground door (x 2..4) is on the stepping face, with a doorstep.
	var f := FIXTURE.build({"lone": true, "prepare": func(front: BuildingMass) -> void:
		front.decor.append({"kind": &"doorstep", "centre": Vector2(1.5, 0.0), "dir": 3, "y": 0.0,
			"side": 1.0, "proud": 0.0, "count": 2})})
	assert_eq(FIXTURE.leans_on(f.front, 3), [-2.0, -1.0, 0.0, 0.0] as Array[float], "the door no longer blocks")
	var catalog := EnvironmentCatalog.load_default()
	var box := func(p: Dictionary) -> AABB: return p.transform * catalog.descriptor(p.asset_id).measured_aabb
	var doors := (f.parts as Array).filter(func(p: Dictionary) -> bool: return String(p.role) == "wall.timber.door")
	assert_eq(doors.size(), 1)
	var threshold := (box.call(doors[0]) as AABB).get_center()
	assert_almost_eq(threshold.z, 2.0, 0.3, "the door stands in its stepped-in wall")
	# The walk reaches it: the ground storey's boards cover the strip from the lot line
	# to the threshold at the floor level (the lane surface ends at the lot line).
	var strip := (f.parts as Array).filter(func(p: Dictionary) -> bool:
		var b: AABB = box.call(p)
		return p.role == &"deck.board" and b.position.y < 0.3 and b.has_point(Vector3(threshold.x, b.get_center().y, 1.0)))
	assert_eq(strip.size(), 1, "one ground board under the overhang in front of the door")
	assert_lt((box.call(strip[0]) as AABB).position.z, 0.05, "it starts at the lot line")
	for item: Dictionary in f.front.decor:
		if item.kind == &"doorstep":
			assert_almost_eq((item.centre as Vector2).y, 1.0, 1e-6, "the doorstep moved in with the door")


func test_a_door_on_a_stepped_in_upper_storey_withdraws_the_step() -> void:
	# A door on storey 1 opens onto an upper walk at the lot line; storey 1 keeps the line.
	var f := FIXTURE.build({"lone": true, "prepare": func(front: BuildingMass) -> void:
		front.storeys[1].openings[BuildingMass.edge_key(Vector2i(1, 0), 3)] = BuildingMass.OPENING_DOOR})
	assert_eq(FIXTURE.leans_on(f.front, 3), [-1.0, 0.0, 0.0, 0.0] as Array[float])


func test_roofs_and_the_top_storey_never_move() -> void:
	var f := FIXTURE.build({"lone": true})
	for wing: Dictionary in f.front.roofs:
		assert_false(wing.has("lean_min") or wing.has("lean_max"))
	var plain := FIXTURE.house(&"kit.fixture.front", Rect2i(0, 0, 3, 2), 4, 3)
	plain.add_roof(Rect2i(0, 0, 3, 2), 1, 8, &"red")["union_index"] = 0
	var roof := func(parts: Array) -> Array:
		var out := parts.filter(func(p: Dictionary) -> bool:
			var role := String(p.role)
			return role.begins_with("roof.") or role.begins_with("gable.") or role.begins_with("trim.ridge") \
				or role.begins_with("trim.barge") or role.begins_with("chimney.")).map(
				func(p: Dictionary) -> String: return "%s %s" % [p.asset_id, p.transform])
		out.sort()
		return out
	FIXTURE.block_faces(plain, [0, 2])
	assert_eq(roof.call(f.parts), roof.call(BuildingKitAssembler.new(f.kit).assemble(plain)), "the roof is untouched")
	for slot: Dictionary in BuildingKitAssembler.storey_slots(f.front.storeys[3]):
		assert_eq(float(slot.wall_offset), 0.0, "the top storey stands on its line")
```

- [ ] **Step 5: Run the re-pinned files to pass.** `test_growing_floors.gd`, `test_growing_floors_guardrails.gd`, `test_growing_floors_wrap.gd`, `test_growing_floors_rows.gd`, `test_growing_floors_bury.gd`, `test_growing_floors_knobs.gd`, `test_growing_floors_step_in.gd`, `test_october3_room_projections.gd`, `test_roof_proportion.gd`, `test_town_old_look.gd`. Where an expectation above differs from the run, decide from the spec which side is wrong: a rule-derived number (e.g. the bearing hold in `test_a_growing_face_pulls_its_corner_neighbours_one_hop`, the cap drop in the portal tests) may only change if the spec's rule says so; record any re-derivation and its reason in the task report. Never weaken a rule to match a number.

- [ ] **Step 6: Building gallery.** `_grow` in `building_gallery.gd` loses the `GROWTH.roof_geometry([kit])` argument. Falsification renders (GUI run): `godot --path . --log-file /tmp/gal.log -s res://tests/harness/suntail/building_gallery.gd -- --set designer --count 9 --seed 4 --close --growth 1.0:2.0 --output /tmp/stepin_gallery` and inspect every `b*_c*` close: the ground storey narrowest, each upper storey on the kit jetty (beam on the face, braces on panel joints and corner posts, none over a window or door head), roofs and top storeys unchanged, cut corner panels flush with a post at each new corner, no floor ledge outside an upper wall, no doubled post or beam, recessed doors with their doorsteps. Record what you saw per image in the report; a defect goes red-first into `test_growing_floors_step_in.gd` (assembler) or the owning planner test, then is fixed.

- [ ] **Step 7: Corpus counts.** In `growth_corpus_audit.gd` replace `counts()` and the totals for step-in:

```gdscript
## Faces (chains with any growth record), records (stepped storeys), stepped-in storeys,
## faces whose ground storey stepped in, the deepest offset, recessed ground doors,
## closures by kind (a corner/joint counts once per record end), houses pulled into a row
## without rolling growth, and withdrawals by cause: attempts (`causes`) and distinct
## faces (`faces_withdrawn`; Task 4 deferred minor).
static func counts(built: Dictionary) -> Dictionary:
	var by_id := {}
	for mass: BuildingMass in built.get("houses", []):
		by_id[mass.stable_id] = mass
	var faces := {}
	var ground_faces := {}
	var stepped_in := 0
	var deepest := 0.0
	var doors := 0
	var kinds := {"return": 0, "wrap": 0, "joint": 0, "bury": 0}
	var pulled := {}
	for lean: Dictionary in built.get("growth", []):
		faces[String(lean.chain)] = true
		var depth := float(lean.lean)
		if depth < 0.0:
			stepped_in += 1
			deepest = minf(deepest, depth)
		var mass: BuildingMass = by_id.get(lean.host)
		if mass != null and depth < 0.0 and int(lean.band) == mass.ground_band:
			ground_faces[String(lean.chain)] = true
			var ground: Dictionary = mass.storeys[GROWTH.ground_index(mass)]
			for edge: Vector3i in lean.edges:
				if StringName(ground.openings.get(edge, ground.default_opening)) == BuildingMass.OPENING_DOOR:
					doors += 1
		for kind: StringName in lean.get("closures", []):
			if kinds.has(String(kind)):
				kinds[String(kind)] += 1
		if bool(lean.get("pulled", false)):
			pulled[String(lean.host)] = true
	var causes := {}
	var withdrawn := {}
	for rejection: Dictionary in built.get("growth_rejections", []):
		var cause := String(rejection.cause)
		causes[cause] = int(causes.get(cause, 0)) + 1
		if not withdrawn.has(cause):
			withdrawn[cause] = {}
		withdrawn[cause][String(rejection.chain)] = true
	var faces_withdrawn := {}
	for cause: String in withdrawn:
		faces_withdrawn[cause] = (withdrawn[cause] as Dictionary).size()
	return {"faces": faces.size(), "storeys": (built.get("growth", []) as Array).size(),
		"stepped_in": stepped_in, "ground_faces": ground_faces.size(), "deepest": deepest,
		"recessed_doors": doors, "returns": kinds.return, "wraps": kinds.wrap, "joints": kinds.joint,
		"buried": kinds.bury, "pulled": pulled.size(), "causes": causes, "faces_withdrawn": faces_withdrawn}
```

(preload `KitGrowingFronts.gd` as `GROWTH` in the harness). Totals: sum every int key, `deepest` as the minimum, merge `causes` and `faces_withdrawn` by key.

- [ ] **Step 8: Gates and count.** Fingerprint gate → `FINGERPRINT_MATCH`; growth-on smoke → 0 `FINGERPRINT_NO_TOWN`; `test_town_old_look.gd` passes; growth corpus count: report faces, storeys, stepped-in storeys, ground faces, recessed doors, wraps/joints/buried/returns, pulled, and both withdrawal tables. Expected well above Task 7's 21 faces (no roof blocks; the ends rule no longer sees neighbours in front). If not above 21, stop and report the per-cause tables (Global Constraints: measurement, not loosening).

- [ ] **Step 9: Commit** `KitGrowingFronts.gd`, `BuildingKitAssembler.gd`, `BuildingDesigner.gd`, `KitVillageBuildings.gd`, `terrain/villages/town_odds.tres`, `tests/fixtures/growing_house.gd`, the six growth test files, the deleted `tests/test_growing_floors_roofs.gd`, `building_gallery.gd`, `growth_corpus_audit.gd`: message "Towns: growing houses step in under a fixed roof (re-referenced to the top storey; recessed shopfront doors; roof-following removed)" + trailer.

---

### Task 10: Corpus audit and edge cases (step-in)

The original audit task, adapted to spec Amendment 2: the audit checks the step-in invariants (nothing outside the lot, roofs and tops fixed, closures, braces on joints, no floor ledges, bearing), the harness gains the violation counts, and the edge cases cover the cap, facing houses, skywalk ends, compound houses, set-back tops, unequal rows and wraps. Deferred minors carried here from the ledger, with their disposition: rejection totals counting attempts (closed in Task 9: `faces_withdrawn`); pin storey/lean in `test_withdrawn_steps_name_their_guardrail` (closed in Task 9); test the widened decor move (closed in Task 9: `test_dressing_on_a_stepped_in_run_moves_in_or_yields`); dead store `test_growing_floors_wrap.gd:57` (rewritten in Task 9); strip vertical alignment (closed in Task 8: the strip spans its storey); a wrap partner with fewer storeys and unequal-height rows (this task; the Task 6 ruling "the taller member continues alone above the shorter" is superseded: under step-in a front steps only up to its shortest member's top, so joints and wraps stay equal); leader among seeds and the shared `_excluded` predicate (closed in Task 9); `_publish_riders` O(m²), `ctx.kit` before `_closures`, the bury contact's stone face / windowed-panel exemption / identity match (moot: riders and the plain-wall contact are removed in Task 9; `_member_closures` sets `ctx.kit`); pulled houses' awnings under braces (Task 11 renders).

**Files:**
- Create: `tests/fixtures/growth_audit.gd`
- Modify: `tests/harness/suntail/growth_corpus_audit.gd` (violation counts per town; `bad` counts violations)
- Test: `tests/test_growing_floors_corpus.gd`, `tests/test_growing_floors_edges.gd`

**Interfaces:**
- Consumes: `KitVillageBuildings.build(...)` keys `growth`, `growth_rejections`, `houses`, `house_kits`, `walls`, `masses`; `KitGrowingFronts.TOUCH`, `ground_index`; `BuildingKitAssembler.storey_slots`, `lean_suffix`, `right_of`, `assemble`; `KitFloatingMassAudit.audit(spatial, fabric, masses).count`; `tests/fixtures/kit_roof_public_air_audit.gd`.audit(built, kit).intrusions.
- Produces: `growth_audit.audit(spatial, fabric, built, kit, character) -> Dictionary` with int keys `faces` and every `VIOLATIONS` key: `outside_lot, air_hits, open_ends, broken_joints, braces_over_openings, unbraced, ledges, roof_moved, top_moved, thin_bearing, floating, roof_intrusions`; harness rows gain those keys, `GROWTH_AUDIT_DONE bad=<violations + null towns + invalid payloads>`.

- [ ] **Step 1: Write the audit fixture** `tests/fixtures/growth_audit.gd`:

```gdscript
extends RefCounted
## Growing-floor corpus audit under step-in (spec Amendment 2 "Testing"): every count
## except `faces` must be 0.
const GROWTH := preload("res://scripts/terrain/features/villages/kit/KitGrowingFronts.gd")
const CLEARANCE := preload("res://scripts/terrain/features/villages/kit/KitPublicClearance.gd")
const VIOLATIONS: Array[String] = ["outside_lot", "air_hits", "open_ends", "broken_joints",
	"braces_over_openings", "unbraced", "ledges", "roof_moved", "top_moved", "thin_bearing",
	"floating", "roof_intrusions"]
const ROOF_ROLES: Array[String] = ["roof.", "gable.", "trim.ridge", "trim.barge", "chimney."]


static func audit(spatial: WarrenSpatialPlan, fabric: SettlementFabricPlan, built: Dictionary,
		kit: BuildingKit, _character: TownCharacter) -> Dictionary:
	var catalog := EnvironmentCatalog.load_default()
	var air: Array[Dictionary] = []
	for wall: Dictionary in built.walls:
		if bool(wall.get("open", false)):
			air.append(wall)
	var houses: Array = built.houses
	var out := {"faces": 0}
	for key: String in VIOLATIONS:
		out[key] = 0
	var chains := {}
	for lean: Dictionary in built.growth:
		chains[String(lean.chain)] = true
	out.faces = chains.size()
	for mass: BuildingMass in houses:
		var records := (built.growth as Array).filter(func(l: Dictionary) -> bool: return l.host == mass.stable_id)
		if records.is_empty():
			continue
		var own_kit: BuildingKit = (built.house_kits as Dictionary).get(
			StringName(String(mass.stable_id).trim_prefix("kit.")), kit)
		var w := own_kit.module_width
		var grown := _architecture(mass, own_kit, houses)
		var plain := _without_growth(mass, own_kit, houses)
		var before := {}
		for part: Dictionary in plain:
			before["%s|%s" % [part.asset_id, part.transform]] = true
		var added := grown.filter(func(p: Dictionary) -> bool:
			return not before.has("%s|%s" % [p.asset_id, p.transform]))
		var box := func(p: Dictionary) -> AABB: return p.transform * catalog.descriptor(p.asset_id).measured_aabb
		for part: Dictionary in added:
			var b: AABB = box.call(part)
			if not _in_lot(mass, b.get_center(), own_kit):
				out.outside_lot += 1
			if CLEARANCE.intersects_air(catalog.descriptor(part.asset_id).measured_aabb, part.transform, air):
				out.air_hits += 1
		if _roof_parts(grown) != _roof_parts(plain) \
				or mass.roofs.any(func(r: Dictionary) -> bool: return r.has("lean_min") or r.has("lean_max")):
			out.roof_moved += 1
		for record: Dictionary in records:
			var storey: Dictionary = GROWTH._storey_at(mass, int(record.band))
			var y0 := float(record.band) * own_kit.band_height()
			var depth := float(record.lean)
			if depth > float(record.base) + 0.0001:
				var under := added.filter(func(p: Dictionary) -> bool:
					var b: AABB = box.call(p)
					return String(p.role).begins_with("bracket.") and b.end.y >= y0 - 0.3 and b.end.y <= y0 + 0.01 \
						and (record.bounds as AABB).grow(0.3).has_point(b.get_center()))
				if under.size() < maxi(1, (record.edges as Array).size() - 1):
					out.unbraced += 1
				# Each brace stands on a wall-module joint (a multiple of the module along
				# the face), never over a window or door head.
				for brace: Dictionary in under:
					var c: Vector3 = (box.call(brace) as AABB).get_center()
					var along := c.z if int(record.dir) % 2 == 0 else c.x
					if absf(along / w - roundf(along / w)) * w > 0.2:
						out.braces_over_openings += 1
			if depth < 0.0:
				out.open_ends += _open_ends(record, storey, added, box, own_kit)
				out.thin_bearing += 0 if _bears(storey, record, own_kit) else 1
		out.top_moved += _tops_moved(mass, records)
		out.ledges += _ledges(mass, grown, box, own_kit)
	out.broken_joints = _broken_joints(built.growth)
	out.floating = KitFloatingMassAudit.audit(spatial, fabric, built.masses).count
	out.roof_intrusions = preload("res://tests/fixtures/kit_roof_public_air_audit.gd").audit(built, kit).intrusions
	return out


## The house's architecture (dressing set aside) as the town assembles it.
static func _architecture(mass: BuildingMass, kit: BuildingKit, houses: Array) -> Array[Dictionary]:
	var assembler := BuildingKitAssembler.new(kit)
	assembler.external_blocked = func(cell: Vector2i, band: int) -> bool:
		for other: BuildingMass in houses:
			if other != mass and other.cells_at_band(band).has(cell):
				return true
		return false
	var decor := mass.decor.duplicate()
	mass.decor.clear()
	var parts := assembler.assemble(mass)
	mass.decor.assign(decor)
	return parts


## The same with its growth taken out again (negative offsets and growth records).
static func _without_growth(mass: BuildingMass, kit: BuildingKit, houses: Array) -> Array[Dictionary]:
	var saved := []
	for storey: Dictionary in mass.storeys:
		saved.append([storey.get("wall_offsets"), storey.get("projections")])
		var offsets: Dictionary = (storey.get("wall_offsets", {}) as Dictionary).duplicate()
		for edge: Vector3i in offsets.keys():
			if float(offsets[edge]) < 0.0:
				offsets.erase(edge)
		storey["wall_offsets"] = offsets
		storey["projections"] = (storey.get("projections", []) as Array).filter(
			func(p: Dictionary) -> bool: return not bool(p.get("growth", false)))
	var parts := _architecture(mass, kit, houses)
	for index in mass.storeys.size():
		var storey: Dictionary = mass.storeys[index]
		for slot in 2:
			var key := "wall_offsets" if slot == 0 else "projections"
			if saved[index][slot] == null:
				storey.erase(key)
			else:
				storey[key] = saved[index][slot]
	return parts


static func _roof_parts(parts: Array) -> Array:
	var out := parts.filter(func(p: Dictionary) -> bool:
		return ROOF_ROLES.any(func(prefix: String) -> bool: return String(p.role).begins_with(prefix))).map(
		func(p: Dictionary) -> String: return "%s %s" % [p.asset_id, p.transform])
	out.sort()
	return out


## Inside the house's own cells (any storey), within the wall face plus touching contact.
static func _in_lot(mass: BuildingMass, point: Vector3, kit: BuildingKit) -> bool:
	var w := kit.module_width
	for storey: Dictionary in mass.storeys:
		for cell: Vector2i in storey.cells:
			if Rect2(Vector2(cell) * w, Vector2(w, w)).grow(kit.wall_face + GROWTH.TOUCH).has_point(Vector2(point.x, point.z)):
				return true
	return false


## Ends of one stepped-in storey record left open: a `return` or `wrap` end whose
## perpendicular corner panel still stands whole, or a `bury` end without its strip.
static func _open_ends(record: Dictionary, storey: Dictionary, added: Array, box: Callable, kit: BuildingKit) -> int:
	var dir := int(record.dir)
	var right := BuildingKitAssembler.right_of(dir)
	var edges: Array = record.edges
	var sorted := edges.duplicate()
	sorted.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		return Vector2(a.x, a.y).dot(Vector2(right)) < Vector2(b.x, b.y).dot(Vector2(right)))
	var bad := 0
	var slots := BuildingKitAssembler.storey_slots(storey)
	for side in 2:
		var kind := StringName((record.closures as Array)[side])
		var end: Vector3i = sorted.front() if side == 0 else sorted.back()
		var cell := Vector2i(end.x, end.y)
		var outward := right * (-1 if side == 0 else 1)
		if kind in [&"return", &"wrap"]:
			var corner := BuildingMass.edge_key(cell, BuildingMass.DIRS.find(outward))
			for slot: Dictionary in slots:
				if slot.edge == corner and float(slot.get("short", 0.0)) <= 0.0 and not bool(slot.get("dropped", false)):
					bad += 1
		elif kind == &"bury":
			# The strip stands on the vertex line, half the inset inside the lot line.
			var corner := (Vector2(cell) + Vector2.ONE * 0.5 + Vector2(BuildingMass.DIRS[dir]) * 0.5 \
				+ Vector2(outward) * 0.5) * kit.module_width
			var expected := corner - Vector2(BuildingMass.DIRS[dir]) * (-float(record.lean)) * 0.5
			var suffix := BuildingKitAssembler.lean_suffix(-float(record.lean))
			var strip := added.any(func(p: Dictionary) -> bool:
				var c: Vector3 = (box.call(p) as AABB).get_center()
				return String(p.role) == "frontage.return." + suffix and Vector2(c.x, c.z).distance_to(expected) < 0.6)
			if not strip:
				bad += 1
	return bad


## Bearing: behind every stepped-in edge at least one module of floor remains, two
## across an axis stepped in from both sides.
static func _bears(storey: Dictionary, record: Dictionary, kit: BuildingKit) -> bool:
	var dir := int(record.dir)
	var inward: Vector2i = -BuildingMass.DIRS[dir]
	var back := (dir + 2) % 4
	var offsets: Dictionary = storey.get("wall_offsets", {})
	for edge: Vector3i in record.edges:
		var far := Vector2i(edge.x, edge.y)
		var modules := 1
		while (storey.cells as Dictionary).has(far + inward):
			far += inward
			modules += 1
		var opposite := minf(0.0, float(offsets.get(BuildingMass.edge_key(far, back), 0.0))) * kit.module_width
		var keep := float(modules) * kit.module_width + float(record.lean) + opposite
		if keep < (2.0 if opposite < 0.0 else 1.0) * kit.module_width - 0.0001:
			return false
	return true


## A stepping face whose highest storey is not on its lot line.
static func _tops_moved(mass: BuildingMass, records: Array) -> int:
	var bad := 0
	var dirs := {}
	for record: Dictionary in records:
		dirs[int(record.dir)] = true
	for dir: int in dirs:
		var top := {}
		for storey: Dictionary in mass.storeys:
			if (storey.get("growth", {}) as Dictionary).has(dir) \
					and (top.is_empty() or int(storey.floor_band) > int(top.floor_band)):
				top = storey
		if not top.is_empty() and float(top.growth[dir]) != 0.0:
			bad += 1
	return bad


## A whole board on an upper storey's cell whose edge stands in (a floor ledge
## outside its wall).
static func _ledges(mass: BuildingMass, parts: Array, box: Callable, kit: BuildingKit) -> int:
	var bad := 0
	for part: Dictionary in parts:
		if part.role != &"deck.board":
			continue
		var c: Vector3 = (box.call(part) as AABB).get_center()
		var storey: Dictionary = GROWTH._storey_at(mass, roundi(c.y / kit.band_height()))
		if storey.is_empty() or int(storey.floor_band) <= mass.ground_band:
			continue
		var cell := Vector2i(floori(c.x / kit.module_width), floori(c.z / kit.module_width))
		var offsets: Dictionary = storey.get("wall_offsets", {})
		for dir in 4:
			if float(offsets.get(BuildingMass.edge_key(cell, dir), 0.0)) < 0.0:
				bad += 1
				break
	return bad


## A joint whose partner (another house, same dir, band and offset, joint closure) is missing.
static func _broken_joints(growth: Array) -> int:
	var bad := 0
	for lean: Dictionary in growth:
		if not (lean.closures as Array).has(&"joint"):
			continue
		var partner := growth.any(func(other: Dictionary) -> bool:
			return other.host != lean.host and int(other.dir) == int(lean.dir) \
				and int(other.band) == int(lean.band) and (other.closures as Array).has(&"joint") \
				and absf(float(other.lean) - float(lean.lean)) < 1e-6)
		if not partner:
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
	assert_eq(FIXTURE.leans_on(f.front, 3), [-2.0, -1.0, 0.0, 0.0, 0.0] as Array[float],
		"two kit jetties below the first upper storey, then every storey on the line")
	for wing: Dictionary in f.front.roofs:
		assert_false(wing.has("lean_min") or wing.has("lean_max"))


func test_facing_growing_houses_across_one_cell_lane() -> void:
	# Either roof axis: the roofs never move, so gable and eave fronts step in alike,
	# and the upper storeys keep today's lane (2.0 native) between them.
	for axis: int in [1, 0]:
		var f := FIXTURE.build({"facing": true, "back_grows": true, "lone": true,
			"roof_axis": axis, "back_roof_axis": axis})
		var front := FIXTURE.leans_on(f.front, 3)
		var back := FIXTURE.leans_on(f.back, 1)
		assert_eq(front, [-2.0, -1.0, 0.0, 0.0] as Array[float], "axis %d" % axis)
		for index in 4:
			assert_true(2.0 - front[index] - back[index] >= 2.0 - 1e-6, "storey %d: the lane only widens" % index)


func test_a_skywalk_end_on_the_top_storey_costs_nothing() -> void:
	var f := FIXTURE.build({"lone": true, "prepare": func(front: BuildingMass) -> void:
		var edge := BuildingMass.edge_key(Vector2i(1, 0), 3)
		front.storeys[3].openings[edge] = BuildingMass.OPENING_DOOR
		front.storeys[3]["passage_edges"] = {edge: true}})
	assert_eq(FIXTURE.leans_on(f.front, 3), [-2.0, -1.0, 0.0, 0.0] as Array[float])


func test_merged_compound_house_steps_per_edge_run() -> void:
	# An L of two lots: the front lot's south run (x 0..2, z 0) ends beside the forward
	# lot's own cell (bury); the forward lot's run (x 3..5, z -1) wraps or returns.
	var mass := BuildingMass.new()
	mass.stable_id = &"kit.fixture.front"
	var cells := BuildingMass.rect_cells(Rect2i(0, 0, 3, 2))
	cells.merge(BuildingMass.rect_cells(Rect2i(3, -1, 3, 3)))
	for s in 4:
		mass.add_storey(s * 2, cells.duplicate(), BuildingMass.MATERIAL_TIMBER)
	mass.add_roof(Rect2i(0, 0, 3, 2), 1, 8, &"red")["union_index"] = 0
	mass.add_roof(Rect2i(3, -1, 3, 3), 1, 8, &"red")["union_index"] = 1
	var chains := GROWTH.face_chains(mass, Callable(FIXTURE, "nothing_solid"),
		func(cell: Vector2i, band: int) -> bool: return cell.y <= -1 and cell.y >= -2 and band <= 1)
	assert_eq(chains.filter(func(c: Dictionary) -> bool: return int(c.dir) == 3).size(), 2, "one chain per edge run")
	var f := FIXTURE.build({"replace_front": mass, "lane": 2})
	var south := (f.leans as Array).filter(func(l: Dictionary) -> bool: return int(l.dir) == 3)
	assert_gt(south.size(), 0)
	for lean: Dictionary in south:
		for kind: StringName in lean.closures:
			assert_true(kind in [&"return", &"bury", &"wrap"], str(lean.closures))
	assert_true(south.any(func(l: Dictionary) -> bool: return (l.closures as Array).has(&"bury")),
		"the front lot's run closes its recess against the forward lot")


func test_top_storey_smaller_than_the_one_below() -> void:
	# Storey 3 is set back to the back row: the face's chain is storeys 1-2, whose top
	# (storey 2) stays on the line; the set-back storey and its roof are untouched.
	var f := FIXTURE.build({"storeys": 4, "lone": true, "prepare": func(front: BuildingMass) -> void:
		front.storeys[3].cells = BuildingMass.rect_cells(Rect2i(0, 1, 3, 1))
		front.roofs.clear()
		front.add_roof(Rect2i(0, 0, 3, 1), 0, 6, &"red")["union_index"] = 0
		front.add_roof(Rect2i(0, 1, 3, 1), 0, 8, &"red")["union_index"] = 1})
	assert_eq(FIXTURE.leans_on(f.front, 3), [-2.0, -1.0, 0.0, 0.0] as Array[float])
	assert_false(f.front.storeys[3].has("wall_offsets"))


func test_row_with_a_shorter_neighbour_holds_at_its_top() -> void:
	# A two-storey neighbour (one storey above its ground): the row steps only up to the
	# shorter member's top storey, so both stand one jetty in at the ground and every
	# shared storey stays equal (spec Amendment 2; supersedes the Task 6 ruling).
	var side := FIXTURE.roofed(&"kit.fixture.side", Rect2i(3, 0, 2, 2), 2, 3)
	var f := FIXTURE.build({"extra": [side], "block": [2]})
	assert_eq(FIXTURE.leans_on(f.front, 3), [-1.0, 0.0, 0.0, 0.0] as Array[float])
	assert_eq(FIXTURE.leans_on(side, 3), [-1.0, 0.0] as Array[float])


func test_a_wrapped_front_holds_at_its_shortest_face() -> void:
	# A 3 x 3 house whose top storey lacks its back-west cell: the west face's chain is
	# one storey shorter than the south face's. With light steps the front stops at the
	# west chain's top, so the wrapped corner stays equal at every shared storey.
	var mass := FIXTURE.house(&"kit.fixture.front", Rect2i(0, 0, 3, 3), 4, 1)
	mass.storeys[3].cells.erase(Vector2i(0, 2))
	mass.add_roof(Rect2i(0, 0, 3, 3), 1, 8, &"red")["union_index"] = 0
	var f := FIXTURE.build({"replace_front": mass, "block": [0],
		"character": FIXTURE.character({}, &"0.5")})
	assert_eq(FIXTURE.leans_on(f.front, 3), [-1.0, -0.5, 0.0, 0.0] as Array[float])
	assert_eq(FIXTURE.leans_on(f.front, 2), [-1.0, -0.5, 0.0, 0.0] as Array[float])


func test_every_recorded_end_closes_by_one_rule() -> void:
	for options: Dictionary in [{}, {"character": FIXTURE.character({&"growth_other_face_chance": 1.0})},
			{"lone": true}]:
		var f := FIXTURE.build(options)
		for lean: Dictionary in f.leans:
			for kind: StringName in lean.closures:
				assert_true(kind in [&"return", &"wrap", &"joint", &"bury"], "%s %s" % [str(options), kind])
```

- [ ] **Step 3: Run them.** Focused tests `test_growing_floors_edges.gd` and `test_growing_floors_corpus.gd`. Where an edge case is red it is a real finding: record it in the ledger, pin the failing geometry red-first in the test of the owning function (`_front_profile`, `_inset_end`, `_bears`, `apply`, `storey_slots`, `_emit_joint_braces`, `_emit_trimmed_floor`) and fix there; never weaken the edge assertion. A number derived from a rule (the shortest-member hold, the bearing rule) may be recomputed only from the spec rule; write the reason in the test message.

- [ ] **Step 4: Harness violations.** In `growth_corpus_audit.gd` preload `res://tests/fixtures/growth_audit.gd` as `AUDIT`; per town merge `AUDIT.audit(spatial, fabric, built, kit, profile.character)` into the row (keeping the Task 9 `counts()` keys), add every `AUDIT.VIOLATIONS` value to `bad`, and print the summed violations in `GROWTH_TOTAL`.

- [ ] **Step 5: Run the corpus.**
  1. Fingerprint towns, everything on: `godot --headless --path . --log-file /tmp/ga.log -s res://tests/harness/suntail/growth_corpus_audit.gd -- --odds growing_house_chance=1 --odds growth_street_face_chance=1 --odds growth_other_face_chance=1 --out /tmp/growth_audit_fp.json > /tmp/ga.out 2>&1; echo EXIT $?; grep -E "GROWTH_(TOTAL|AUDIT_DONE)" /tmp/ga.out` → `bad=0`, EXIT 0.
  2. The same with the default face chances (only `--odds growing_house_chance=1`, `--out /tmp/growth_audit_default.json`).
  3. Production sample `--towns 1:compact,2:standard,3:standard,4:large,5:compact,6:standard,8:large,9:grand,10:standard,11:compact,12:standard,14:large,15:standard,16:compact,17:large,18:grand` with `--odds growing_house_chance=1 --out /tmp/growth_audit_sample.json` → `bad=0`.
  Target for run 1: stepping faces well above Task 7's 21 (and the superseded Task 8's 2); report faces, storeys, stepped-in storeys, ground faces, recessed doors, wraps, joints, buried ends, pulled houses, and withdrawals per cause as attempts and as distinct faces (portal, party, bearing, material, columns, decor, ends, air, obstacle.*). Explain any cause that withdraws more than 20 faces. If faces are not above 21, stop and report the per-cause tables for a controller ruling (never relax a guardrail to reach the number). Fix every violation in the owning code, red-first (pin the town and face in a fixture test), before committing.

- [ ] **Step 6: Fingerprint gate** → `FINGERPRINT_MATCH`; `test_town_old_look.gd` passes.

- [ ] **Step 7: Commit** the audit fixture, harness and both tests: message "Towns: step-in corpus audit and edge cases (lot, roofs, tops, joints, braces, ledges, bearing)" + trailer. Keep the three run outputs (`/tmp/growth_audit_*.json`) for Task 11's write-up.

---

### Task 11: Shipped defaults, evidence, write-up

The original defaults task, adapted to spec Amendment 2: street-level Shambles views along lanes of stepped-in fronts, side views of wrapped corners, rows and buried ends, recessed shopfront doors, the corpus counts from Task 10, and the deviations write-up required by ledger ruling F5 (every deviation from the spec, including both amendments' rulings).

**Files:**
- Modify: `terrain/villages/town_odds.tres` (`growing_house_chance` at_small 0.3, at_large 0.45, spread 0.1)
- Modify: `tests/fixtures/town_old_look.gd` (add `&"growing_house_chance": 0.0`)
- Modify: `tests/harness/suntail/kit_town_review.gd` (`growth`, `wrap` and `door` views, ~lines 16, 147, 161, 398)
- Modify: `docs/qa/2026-10-07-town-odds/fingerprint/baseline.json` (re-pinned)
- Create: `docs/qa/2026-10-08-growing-floors/result.md` and render folders `before/`, `after/`, `gallery/`, `audit/`
- Modify: `AGENTS.md` (new top entry)
- Test: `tests/test_growing_floors_knobs.gd` (default assertions), `tests/test_town_old_look.gd`

**Interfaces:**
- Consumes: everything above; `KitVillageBuildings.build(...).growth` (records with signed `lean`, `band`, `bounds` = the recess, `closures`, `host`, `edges`).
- Produces: shipped defaults; review views `growth`, `wrap`, `door` (kit_town_review); re-pinned fingerprint baseline; result write-up with a deviations section.

- [ ] **Step 1: Update the default test first (red).** In `test_growth_knobs_are_in_the_table_with_their_shipped_values` replace `assert_eq(c.value(GROWTH.HOUSE_KNOB), 0.0)` with `assert_between(c.value(GROWTH.HOUSE_KNOB), lerpf(0.3, 0.45, size) - 0.1, lerpf(0.3, 0.45, size) + 0.1)`; in `test_build_marks_houses_growing_only_when_the_chance_is_positive` keep the explicit `0.0` / `1.0` overrides (it pins the zero path). Run it: fails (`0.0` outside `0.2..0.4`).

- [ ] **Step 2: Review views.** `kit_town_review.gd`: add `static var _growth_views: Array[Dictionary] = []`, `static var _wrap_views: Array[Dictionary] = []` and `static var _door_views: Array[Dictionary] = []`, clear them beside `_projection_views.clear()`, and after the projection loop:

```gdscript
		var houses := {}
		for mass: BuildingMass in built.get("houses", []):
			houses[mass.stable_id] = mass
		for lean: Dictionary in built.get("growth", []):
			var direction: Vector2i = BuildingMass.DIRS[int(lean.dir)]
			var right: Vector2i = BuildingKitAssembler.right_of(int(lean.dir))
			var box: AABB = lean.bounds
			var mass: BuildingMass = houses.get(lean.host)
			var ground := mass != null and int(lean.band) == mass.ground_band
			# The recess's outer face (the lot line), where a passer-by stands in front of it.
			var front := box.get_center() + Vector3(direction.x, 0, direction.y) * box.size.dot(
				Vector3(absf(direction.x), 0, absf(direction.y))) * 0.5
			if ground:
				_growth_views.append({"at": KitVillageBuildings.native_to_lattice(kit) * front,
					"direction": Vector3(direction.x, 0, direction.y), "lean": float(lean.lean)})
				var storey: Dictionary = mass.storeys[preload("res://scripts/terrain/features/villages/kit/KitGrowingFronts.gd").ground_index(mass)]
				for edge: Vector3i in lean.edges:
					if StringName(storey.openings.get(edge, storey.default_opening)) == BuildingMass.OPENING_DOOR:
						var door := (Vector3(edge.x + 0.5, 0, edge.y + 0.5) + Vector3(direction.x, 0, direction.y) * 0.5) \
							* kit.module_width
						_door_views.append({"at": KitVillageBuildings.native_to_lattice(kit) * door,
							"direction": Vector3(direction.x, 0, direction.y), "lean": float(lean.lean)})
			for side in 2:
				var kind := StringName((lean.closures as Array)[side])
				if kind in [&"wrap", &"joint", &"bury"]:
					# The end of the recess where the wrap/joint/bury is (side 0 = the -right end).
					var reach := (box.size.x if right.x != 0 else box.size.z) * 0.5 * (-1.0 if side == 0 else 1.0)
					_wrap_views.append({"at": KitVillageBuildings.native_to_lattice(kit) * (front + Vector3(right.x, 0, right.y) * reach),
						"direction": Vector3(direction.x, 0, direction.y), "right": Vector3(right.x, 0, right.y),
						"kind": kind, "lean": float(lean.lean)})
		_growth_views.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.lean) < float(b.lean))
		_door_views.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.lean) < float(b.lean))
```

and the views beside `projections`:

```gdscript
		if _views.has("growth"):
			# Shambles framing: stand in the lane in front of the deepest stepped-in ground
			# storeys and look along the lane at eye height; then look up at the jetties.
			for index in mini(6, _growth_views.size()):
				var view: Dictionary = _growth_views[index]
				var target: Vector3 = town.transform * (view.at as Vector3)
				var outward: Vector3 = (town.transform.basis * (view.direction as Vector3)).normalized()
				var along := outward.cross(Vector3.UP).normalized()
				var foot := target + outward * 2.0
				foot.y = town.transform.origin.y + _ground_y + 1.8
				await _shoot(stage, foot - along * 10.0, foot + along * 20.0 + Vector3.UP * 4.0,
					"%d_%s_growth%d_lane" % [seed_value, scale, index], 70)
				await _shoot(stage, foot + outward * 1.5, target + Vector3.UP * 4.0 - outward * 1.0,
					"%d_%s_growth%d_up" % [seed_value, scale, index], 75)
		if _views.has("wrap"):
			# Wrapped corners, row joints and buried ends: an oblique from the street at eye
			# height and a square-on view from the side.
			_wrap_views.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return String(a.kind) + str(a.lean) < String(b.kind) + str(b.lean))
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
		if _views.has("door"):
			# Recessed shopfront doors: from the lot line at eye height, looking in under the
			# overhang at the door and its doorstep.
			for index in mini(6, _door_views.size()):
				var view: Dictionary = _door_views[index]
				var target: Vector3 = town.transform * (view.at as Vector3)
				var outward: Vector3 = (town.transform.basis * (view.direction as Vector3)).normalized()
				var eye := target + outward * 4.0
				eye.y = town.transform.origin.y + _ground_y + 1.7
				await _shoot(stage, eye, target + Vector3.UP * 1.2,
					"%d_%s_door%d" % [seed_value, scale, index], 70)
```

- [ ] **Step 3: Before renders (defaults still 0).** `godot --path . --log-file /tmp/rb.log -s res://tests/harness/suntail/kit_town_review.gd -- --cities 53:grand,31:large,13:standard,43:large,83:grand,103:standard,7:compact,61:standard --views overview,orbit,street,lane --output docs/qa/2026-10-08-growing-floors/before > /tmp/rb.out 2>&1` (GUI run, no `--headless`).

- [ ] **Step 4: Ship the defaults.** `growing_house_chance`: `at_small = 0.3`, `at_large = 0.45`, `spread = 0.1`, notes "… Shipped (task 11)." Add `&"growing_house_chance": 0.0` to `tests/fixtures/town_old_look.gd` `VALUES`. Run `test_growing_floors_knobs.gd` → green.

- [ ] **Step 5: After renders and gallery.** Same cameras: the Step 3 command with `--views overview,orbit,street,lane,growth,wrap,door --output docs/qa/2026-10-08-growing-floors/after`. Gallery at three knob values: `godot --path . --log-file /tmp/g1.log -s res://tests/harness/suntail/building_gallery.gd -- --set designer --count 9 --seed 4 --close --growth 1.0:2.0 --output docs/qa/2026-10-08-growing-floors/gallery/step100_cap200`, then `--growth 0.5:2.0 --output .../gallery/step050_cap200` and `--growth 1.0:1.0 --output .../gallery/step100_cap100`. Look for: the Suntail reference read (a narrower ground storey — stone where the designer made it stone — with timber storeys jutting over it on the kit's diagonal braces), braces only on panel joints and corner posts (none over a window or door head, none hanging over a recess corner), roofs and top storeys exactly as in `before/`, every overhang carried by its floor beam, cut corner panels flush with one post at each new corner, no floor ledge outside an upper wall, wrapped corners with one post and no doubled beam, row joints seamless (no doubled post, return or brace), buried ends closed by their strip with no slit, recessed doors reachable over the ground boards with their doorsteps, pulled houses' awnings not crossing braces (Task 6 deferred minor). If the `after` towns show no wrap/joint/bury or recessed door at the shipped 0.3–0.45 chance, add one run at `--odds growing_house_chance=1` to `docs/qa/2026-10-08-growing-floors/after_all/` so each closure kind and a door have street and side views. Record any defect red-first (pin seed/face in a fixture test) and fix before continuing.

- [ ] **Step 6: Audits with the new defaults.** `growth_corpus_audit.gd` on the 8 fingerprint towns and the Task 10 production sample with no `--odds` → `bad=0` (save `--out res://docs/qa/2026-10-08-growing-floors/audit/default_fp.json` and `.../default_sample.json`); also the production audit `godot --headless --path . -s res://docs/qa/2026-10-01-town-redesign/prefab-grammar/october6-integrated-checkpoint/unequal-roof-range-study/production-validation/oct7-range-audit-prod.gd.txt` copied to `/tmp/growth_range_audit.gd` and run with `-s /tmp/growth_range_audit.gd -- 53:grand,31:large,13:standard,43:large,83:grand,103:standard` → every row `valid_payload` true, `floating` 0, `roof.intrusions` 0.

- [ ] **Step 7: Fingerprint re-pin and old-look confirmation.**
  1. Source plans must not move: fingerprint gate with `--parts source` → `FINGERPRINT_MATCH` (growth is kit-layer only).
  2. Zero path first, against the pre-default baseline: `git show HEAD:docs/qa/2026-10-07-town-odds/fingerprint/baseline.json > /tmp/fp_prev.json`; `godot --headless --path . --log-file /tmp/fpz.log -s res://tests/harness/town_fingerprint.gd -- --odds growing_house_chance=0 --out /tmp/fp_zero.json --compare /tmp/fp_prev.json > /tmp/fpz.out 2>&1` → `FINGERPRINT_MATCH`.
  3. `godot --headless --path . --log-file /tmp/fpw.log -s res://tests/harness/town_fingerprint.gd -- --out res://docs/qa/2026-10-07-town-odds/fingerprint/baseline.json > /tmp/fpw.out 2>&1`, then the full fingerprint gate → `FINGERPRINT_MATCH`.
  4. `godot --headless --path . --log-file /tmp/fpo.log -s res://tests/harness/town_fingerprint.gd -- --old-look --compare res://docs/qa/2026-10-07-town-odds/fingerprint/old_look_baseline.json --parts source > /tmp/fpo.out 2>&1` → `FINGERPRINT_MATCH`; focused `test_town_old_look.gd` passes.
  5. Re-run every growth test file plus `test_october3_room_projections.gd`, `test_roof_proportion.gd`, `test_town_odds.gd` → green.

- [ ] **Step 8: Write `docs/qa/2026-10-08-growing-floors/result.md`:**
  - What changed: knobs and defaults (`growth_gable_front_boost` removed; `lane_sky_gap` inert); eligibility (any exposed face of a two-storey house); the step-in (roof and top storey fixed, each lower storey one kit jetty further in, the ground narrowest; `offsets_of`); fronts with `return` / `wrap` / `joint` / `bury` closures and their step-in pieces (cut or dropped corner panels, inner floor pieces, recess strips); braces on module joints; recessed ground doors; guardrails under step-in (the spec table, which can still fire and which cannot).
  - Image table: before/after per town and view, `*_growth*_lane` / `*_up` Shambles views, `*_wrap*` / `*_joint*` / `*_bury*` street and side views, `*_door*` recessed doors, the three gallery sets; one honest sentence per image.
  - Corpus tables from Task 10 and Step 6: stepping faces and storeys per town; stepped-in storeys, ground faces, recessed doors, wraps, joints, buried ends, pulled houses; withdrawals per cause as attempts and distinct faces; every violation count 0; production rows; the comparison 45 → 183 candidates (Diagnosis), 1 → 18 → 22 (step-out fixes), 21 (Task 7), 2 (superseded roof following), this plan's count.
  - Fingerprint/old-look results.
  - **Deviations from the spec (ledger ruling F5)**, each with its reason: the original plan rulings that still stand (cap quantisation; monotone profile and cap drop; house-wide jetty removal on growing houses with rolls kept; ordering after towers; street face as a column test; widened G6; returns cut from wall starts; `lane_sky_gap` clamp), the October 8 amendment rulings that still stand (0.25 step retired, pieces kept baked; pulling is one hop; rows pull non-growing eligible neighbours, so more houses step than `growing_house_chance` alone; rows join only on the same first upper storey; a member that cannot hold leaves and is refitted alone only if it was a seed; rails, bays and architecture never yield; ornament yield extends to row members), and the Amendment 2 rulings (re-referencing to the top storey instead of a rewrite; the superseded roof-following code removed, its assembler step-in pieces kept and generalised; a front steps only up to its shortest member's top storey, superseding the Task 6 "taller continues alone" ruling; the profile found by cap iteration on final offsets; bearing: one module behind every stepped-in edge, two across an axis stepped from both sides; party rule: a run against any touching building never steps in, so a face over a lower neighbour stays flush; a stone storey steps in only by whole modules; ground doors recess, upper-storey doors and bays on a stepped-in run withdraw the step, passages/blanks/balconies keep their old effect through the re-referencing; the ground floor stays whole as the paving under the overhang, upper floors trim to their wall; no path paint is extended (towns have none inside a lot); growth braces on module joints while the kit's own non-growing jetty keeps slot-centre braces; outward-only code (step-out returns, wrap extension strips, the plain-wall bury contact, face probes, reserved columns beyond a face) removed rather than left dead; `growth_gable_front_boost` removed).
  - Limits and open owner questions: the kit's own (non-growing) jetty still braces at slot centres, over window heads — apply the joint rule there too (changes zero-chance towns)?; stone storeys step in only by whole modules until a stone half strip is baked; faces over a lower neighbour or against a party wall never step; the planner is unaware of the recesses (the strip under an overhang is the house's own cell); `lane_sky_gap` is inert (remove it, or keep it for a future outward option?).

- [ ] **Step 9: AGENTS.md entry** at the top, one paragraph: "> GROWING UPPER FLOORS (Oct 8–9, spec `docs/superpowers/specs/2026-10-08-growing-upper-floors-design.md` incl. its two owner amendments, result `docs/qa/2026-10-08-growing-floors/result.md`): `KitGrowingFronts` (kit layer only; after towers, before projections/bays in `KitVillageBuildings.build`) makes some houses step IN the Suntail/Shambles way: on any exposed face of a house with two stacked storeys the roof and the top storey stay on the footprint and each lower storey stands one kit jetty (1.0 native m; 0.5 for the light step) further in, so the ground storey is the narrowest and every upper storey overhangs the one below (`growing_house_chance` 0.3→0.45 spread 0.1, both face chances 0.85, `growth_step` {0.5:1, 1.0:3}, `growth_max_lean` 2.0 = the ground storey's total step-in; `lane_sky_gap` inert; no gable-front boost). Faces step as FRONTS with one monotone capped profile re-referenced to the top storey (`offsets_of`: storey k at `lean_k - top`, ground at `-top`); a front steps only up to its shortest member's top. Closures: `return` (the perpendicular corner panel shortens to the baked `frontage.return.dNNN` strip or drops for a whole module; post at the new corner), `wrap` (convex corner of one house, both panels shortened, one post, inner `frontage.corner.dNNN` floor square), `joint` (coplanar row stepping together; no pieces), `bury` (own cell beside the end: a strip on the vertex line closes the recess). Writes negative `wall_offsets` + growth records `projections{growth, depth, base, closures}` (signed) + `storey.growth[dir]`; the assembler trims stepped-in upper floors (ground floor stays whole: paving to a recessed shopfront door), carries each overhang on its floor beam with `bracket.jetty` (`bracket.small`) on wall-module joints only (never over a window/door head), and return beams at open sides. Guardrails (cap drops one step; a member that cannot take the first step leaves): air/obstacles inside the recess, recess claims, portals (passages, blanks, balconies; upper doors and bays on a stepped-in run), material (stone only whole modules), party (never against a touching building), bearing (≥1 module behind, ≥2 across a two-sided axis), porch posts, end closure. Roofs never move (the October 8 roof-following was removed). Withdrawals per cause (`growth_rejections`); audit `growth_corpus_audit.gd` + `tests/fixtures/growth_audit.gd`. Zero chance is byte-identical (old-look fixture pins 0); fingerprint baseline re-pinned for the defaults."

- [ ] **Step 10: Commit** `terrain/villages/town_odds.tres`, `tests/fixtures/town_old_look.gd`, `kit_town_review.gd`, `tests/test_growing_floors_knobs.gd`, `docs/qa/2026-10-07-town-odds/fingerprint/baseline.json`, `docs/qa/2026-10-08-growing-floors/` (result, audits, renders), `AGENTS.md`: message "Towns: growing houses step in by default (0.3-0.45), evidence and re-pinned fingerprint" + trailer.

---

## Self-Review

**Spec coverage (with both amendments).** Knobs → Task 1 (+ amended values Task 4, boost removed and notes Task 9, shipped chance Task 11); baked depth family → Task 2 (+ corner squares Task 5), reused for cuts, trims and strips (Task 8); fronts, joins, eligibility, rows, wraps → Tasks 4–7 (kept); Amendment 2 Decision (step in, roof and top fixed, ground narrowest) → Task 9 `offsets_of` / `apply`, Task 8 assembler; re-referencing (same profile and closures, offsets relative to the top; shortest-member hold; cap iteration ≡ hold-from-failing-storey) → Task 9 `_front_profile`, `_front_fault`; closures under step-in (`return` cut/drop + moved post, `wrap` both cut + one post + inner square, `joint` nothing, `bury` strip, `blocked`) → Task 8 `storey_slots`, `_emit_step_in`, `_emit_trimmed_floor`, Task 9 `_inset_end`; floors (ground whole, upper trimmed) → Task 8 `_emit_inhabited_floor`; "Supersedes" (roof following, gable shift, eave cap/allowance, crown G7, one-face eave inset, outward pieces, plain-wall bury) → Task 9 removals; recessed doors (ground door recesses with its doorstep; walk = ground board from the lot line; upper doors and bays block; passages, blanks, balconies through re-referencing) → Task 9 `_no_portal`, `apply`, `test_a_ground_door_is_a_recessed_shopfront`; brace placement (joints only, one owner, none over a recess) → Task 8 `_emit_joint_braces`, Task 10 `braces_over_openings`; guardrails table (G1/G3 inside the recess, G2 cannot fire, reserved claims on recess cells, G5 kept, G6, bearing, party, material/stone, decor) → Task 9 `_fault` family and its tests; knob table → Global Constraints, Task 9 Step 2, Task 11; interactions (no growth walls for roof cutting; projections/bays skip every storey of a stepping face) → Task 9 (`KitVillageBuildings`, `apply` writes `storey.growth` on held tops); testing additions and corpus targets → Tasks 8–10; evidence (Shambles lane views, side views of wraps/rows/bury, recessed doors, deviations write-up) → Task 11.

**Rulings and conflicts (recorded here, in the ledger and in `result.md`):**
1. *Fix-round assembler code kept.* Ruling 1 asks to remove the Task 8 roof code unless a concrete use remains. `storey_slots` `short`/`short_side`, `_emit_inset_end`, `_emit_inset_jetty` and `below_growth` are exactly the step-in end and overhang closures (one storey deep), so Task 8 generalises them instead of removing them. Everything else from Task 8 goes in Task 9 (gable shift `_lean_roof_end`/`roof_parts`, `eave_allowance`/`_eave_cap`, crown G7, `_try_inset` and the one-face eave inset planner path, `growth_gable_front_boost`).
2. *Unequal fronts.* A row or wrap of members with different chain lengths steps only up to the shortest member's top storey (above it every member holds), so every member's top storey is the same `T` and joints/wraps stay equal at every shared storey. Supersedes the Task 6 ruling "the taller member continues alone above the shorter": under step-in that would make the taller member's lower storeys deeper than the shorter's at the joint.
3. *Profile by cap iteration.* The monotone capped profile is tested as a whole at its final offsets (an inset depends on the final top); on a failure the cap drops one step for the front. This is the same set of outcomes as the old "hold from the failing storey up"; a member failing at the smallest cap leaves (multi-member) or the face stays flush (lone).
4. *Bearing.* "An inset never removes the cells that carry it" is made concrete as: every overhang is one step (≤ the kit jetty) on braces; behind every stepped-in edge at least one module of floor remains, two across an axis stepped in from both sides (the kit's own jetty rule: no one-module stalk). Measured consequence in the fixtures: a 3 × 2 house stepping in south, east and west holds at one jetty.
5. *Party rule.* "A party wall / touching neighbour never insets" applies to every stepped-in storey's run at both bands, so a face over a lower neighbour (a former step-out candidate) stays flush: its ground storey is a party wall. Beside an end only a coplanar row stepping together (`joint`) admits another building.
6. *Recessed doors.* Only ground-storey doors recess (the ruling's shopfront). A door on a stepped-in upper storey still withdraws the step: its landing is an upper walk at the lot line and the trimmed upper floor would leave a gap. No path paint is extended: a town's walk ends at the lot line and the strip to the threshold is the house's own cell, floored by its ground `deck.board` (kept whole); the test proves the board covers it.
7. *Bays.* A bay on a stepped-in run withdraws the step (it would stand under the overhang's braces); a bay on a storey that only overhangs is unaffected. (Under step-out a bay rode out with its face.)
8. *Stone.* Suntail bakes no stone half strip: a stone storey steps in only by whole modules (a dropped corner panel needs no strip). At the default cap the ground storey steps in one whole module, so stone grounds still step in on most houses.
9. *Braces.* The joint rule applies to growth braces; the kit's own non-growing jetty (`_emit_jetty_trim`) keeps its slot-centre braces so zero-chance towns stay byte-identical. Raised as an open owner question in Task 11.
10. *Outward-only code removed, not left dead.* `_emit_wrap_end`, `WRAP_INSET`, the growth branch of `_emit_projected_front`, `_front_role`, `face_parts`, `_candidate`, the ride/rider/slab machinery, `_bury_contact`/`PLAIN_CONTACT`, `_columns_free` (reserved columns beyond a face) and the gap check in the growth fault path have no step-in caller; `gap_ok` stays (room projections use it). The guardrail probe becomes the exact assembly diff (`_added_parts`), so the probe/final parity test is retired with `face_parts`.
11. *Knobs.* `lane_sky_gap` stays as an inert guardrail value (G2 for any outward offset; room projections facing a growth registry entry, which growth no longer writes); `growth_gable_front_boost` is removed (no purpose once roofs are fixed; it would only reshuffle growing houses' ridge rolls). `growth_max_lean` keeps its name and now means the ground storey's total step-in.
12. *Fixture `lone`.* Reserved columns beyond a face no longer withdraw anything, so `lone`/`block` keep faces out of a front with a skywalk passage on the first upper storey's far panel (cause `portal`); `reserved_x` is removed.
13. *Task split.* The controller's suggested Task 8 is split: Task 8 assembler (data contract tested directly), Task 9 planner + removals + recessed doors; the corpus task becomes Task 10 and the defaults/evidence task Task 11.
14. *Original plan rulings that still stand:* cap quantisation (`step · min(4, floor(cap/step))`); monotone profiles; house-wide jetty removal on growing houses (rolls kept); growth after towers and before projections/bays; street face as a column test (selects the face knob only); one-hop pulling; rows join only on the same first upper storey; rows pull non-growing eligible neighbours; yield list (ivy, corner ivy, window boxes, awnings; architecture never yields); 0.25 step retired with its pieces kept baked; `lane_sky_gap` clamp 0.25–4.0.

**Placeholder scan.** No TBD; every new function has code, every test has assertions and an exact command. Measured-but-unknown values have a named action: the bury strip's lateral position (Task 8 Step 7: measure the box centre, the exact correction and where it goes); rule-derived expectations that a run contradicts (Task 9 Step 5, Task 10 Step 3: re-derive only from the spec rule and record why); corpus misses (Task 10 Step 5: stop with the per-cause tables). Tasks 1–7 are unchanged and done.

**Name consistency.** `KitGrowingFronts` (`GROWTH`): `STEP_SIZES` [0.5, 1.0], `TOUCH`, `YIELD_DECOR`, `JETTY_ROLES`, `contact_clear`, `carried_step`, `face_chains` (keys `ground`, `first_band`, `start_convex`, `end_convex`, `storeys`, `key`), `house_eligible`, `_excluded`, `fit(...) -> {leans, registry, rejections}`, `fronts`, `offsets_of`, `apply(...) -> {records, moved}`, `_storeys`, `_storey_index`, `_fit_front`, `_leader`, `_slice`, `_member_closures`, `_front_profile`, `_front_fault`, `_reject`, `_closures`, `_end_kind`, `_inset_end`, `_fault`, `_steps_in`, `_exposed`, `_recess_free`, `_bears`, `_planned`, `_decor_ok`, `_no_portal`, `_storey_at_y`, `_snapshot`, `_restore`, `_added_parts`, `_parts_fault`, `_drop_cut_decor`, `_commit`, `_record`, `gap_ok`, `clear_of`, `_obstacles`, `_obstacle`, `_obstacle_cause`, `_drop_decor`, `_decor_edge`, `_on_storey`; closure kinds `return` / `wrap` / `joint` / `bury` (`blocked` internal); causes `material`, `portal`, `party`, `columns`, `bearing`, `decor`, `ends`, `air`, `obstacle.*`; assembler `lean_suffix`, `OFFSET_WALL_DROP`, `storey_slots` (slot keys `wall_offset`, `right_extend`, `short`, `short_side`, `dropped`), `_emit_inset_end`, `_emit_inset_jetty`, `_emit_joint_braces`, `_blocked_beside`, `_emit_trimmed_floor`, `_emit_step_in`; storey keys `wall_offsets`, `projections[{growth, dir, edges, centres, band, depth, base, closures}]`, `growth`; lean record keys `host, dir, band, lean, base, edges, bounds, chain, closures, pulled`; rejection keys `chain, storey, lean, cause`; build result keys `growth`, `growth_rejections`; fixture `write_step_in`, `block_faces`, options `lone` / `block`; harness `growth_corpus_audit.gd` (`GROWTH_AUDIT`, `GROWTH_TOTAL`, `GROWTH_AUDIT_DONE`, `counts()` keys `faces, storeys, stepped_in, ground_faces, deepest, recessed_doors, returns, wraps, joints, buried, pulled, causes, faces_withdrawn`); audit `growth_audit.gd` (`VIOLATIONS`); knob names match the spec's Amendment 2 table exactly.
