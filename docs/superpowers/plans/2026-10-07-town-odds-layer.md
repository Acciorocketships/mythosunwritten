# Town Odds Layer and Courtyard Clearings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace forced aesthetic rules in the town generator with a seeded, tunable "town odds" layer (defaults reproduce today's towns), fix the seed/shortfall groundwork, measure tunnel attrition, and add courtyard clearings as the layer's first feature.

**Architecture:** A `TownOddsTable` resource (`terrain/villages/town_odds.tres`) is compiled on the main thread into a plain-data `TownOddsProgram` carried by `SettlementFabricProgram`. Each town draws a `TownCharacter` (one value per knob, one independent random stream per knob) that rides on `WarrenVillageScaleProfile`, which already reaches every stage. Call sites roll against the character. Courtyard clearings are chosen in `WarrenMazeCarver.carve` after alleys/loops and realised by the existing deck-plot machinery in `WarrenPlotReservations`.

**Tech Stack:** Godot 4.5, typed GDScript, GUT tests (headless), existing review harnesses.

**Spec:** `docs/superpowers/specs/2026-10-07-town-odds-layer-design.md` (decisions: `docs/qa/2026-10-07-town-rule-audit/audit.md` section 10).

## Global Constraints

- Work in worktree `/Users/ryko/.codex/worktrees/77a0/story`, branch `town-redesign`. Never run the shell `godot-test` alias (it targets `/Users/ryko/story`).
- Godot binary: `/Applications/Godot.app/Contents/MacOS/Godot`. Always pass `--log-file /tmp/<name>.log`. Redirect stdout to a file; check the exit code.
- Focused test command (from the worktree root):
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --log-file /tmp/t.log -s addons/gut/gut_cmdln.gd -gtest=res://tests/<file>.gd -gexit > /tmp/t.out 2>&1; tail -20 /tmp/t.out`
- After adding/renaming/removing any `class_name` script: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import > /tmp/import.out 2>&1`.
- Defaults reproduce today: with the committed default table, town fingerprints (Task 1) must be byte-identical to the baseline, except in tasks that explicitly change output (Task 6).
- Worker purity: town generation runs on a worker thread. Never load meshes/materials or create server resources in it. `TownOddsTable` is a plain-data `Resource` and is compiled once into `TownOddsProgram` (plain dictionaries).
- Hard rules only as guardrails (support, walking clearance, reachability, closure, fit). Aesthetic targets never reject a town; they record shortfalls.
- Evidence seeds: `53:grand,31:large,13:standard,43:large,83:grand,103:standard`; holdouts `7:compact,61:standard` (substitute `9:compact` / `63:standard` if a holdout does not build; record the substitution). Holdouts are never used for tuning.
- Commit after every task with a message ending in `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Never stage files outside the task's list.
- Archive evidence (logs, JSON, images) under `docs/qa/2026-10-07-town-odds/<task-slug>/`.

## Review Focus

1. **A knob table edited badly** (duplicate name, weights array length ≠ options, clamp_min > clamp_max): a person expects a clear error naming the knob, not a silent wrong town. → Task 3 `test_compile_reports_bad_knobs`.
2. **A town generated without a character** (tests or legacy callers that skip `WarrenVolumetricSolver.generate`): expected to behave exactly as today, not crash. → Task 4 `test_direct_planner_call_draws_builtin_character`.
3. **Reusing one profile object for several towns** (harnesses loop seeds with one `for_id` profile): each town must get its own seed's character, not the previous town's. → Task 4 `test_profile_reuse_redraws_per_seed`.
4. **A clearing that cannot connect** to any street: expected to be withdrawn cleanly, leaving no reservation, no orphan lane, and no dead-end. → Task 9 `test_unconnectable_clearing_leaves_no_trace`.
5. **`--odds` given an unknown knob name or a non-number**: expected to fail loudly listing valid knob names, not silently ignore. → Task 3 `test_parse_overrides_rejects_unknown_and_non_numeric`.

---

## File Structure

New:
- `scripts/terrain/features/villages/odds/TownKnob.gd` — one knob definition (Resource).
- `scripts/terrain/features/villages/odds/TownOddsTable.gd` — the editable table (Resource).
- `scripts/terrain/features/villages/odds/TownOddsProgram.gd` — compiled plain data, validation, overrides, builtin loader.
- `scripts/terrain/features/villages/odds/TownCharacter.gd` — per-town draws and per-decision rolls.
- `scripts/terrain/features/villages/fabric/WarrenCourtClearings.gd` — clearing site selection + carving.
- `terrain/villages/town_odds.tres` — the default table.
- `tests/harness/town_fingerprint.gd` — byte-identity fingerprints.
- `tests/harness/tunnel_attrition.gd` — tunnel stage counts.
- Tests: `tests/test_town_odds.gd`, `tests/test_town_character_wiring.gd`, `tests/test_aesthetic_shortfalls.gd`, `tests/test_dressing_seed.gd`, `tests/test_court_clearings.gd`.

Modified (main ones): `WarrenVillageScaleProfile.gd`, `SettlementFabricProgram.gd`, `WarrenVolumetricSolver.gd`, `WarrenMazeSourcePlan.gd`, `WarrenSpatialFeatureSolver.gd`, `SettlementFabricAssembler.gd`, `WarrenMazeCarver.gd`, `WarrenExcavation.gd`, `WarrenMazeSitePlanner.gd`, `WarrenPlotReservations.gd`, `WarrenSpatialFabricCompiler.gd`, `tests/harness/suntail/kit_town_review.gd`, plus copy-field lists that clone `WarrenExcavation` (`WarrenDistrictLandmarkAccess.gd:6`, `WarrenMazeCarver.gd:~2771` and `~2876`, `WarrenMazeSitePlanner.gd:~111`, `WarrenPlatformStreets.gd:~101`).

Out of scope for this plan (later plans, each after an owner checkpoint): covered-edge and fully-covered clearings; retiring the old interior court/plaza; migrations (edge streets, silhouette, market square incl. its rejection path and the `VillageUrbanFabricPlan` ceilings, upper-floor dial, palette, flat roofs, gates, long tail); the tunnel fix itself (designed from Task 7's measurements); the ~12-town character gallery harness (lands with the first migration batch, when knobs first vary per town); world placement.

---

### Task 1: Town fingerprint harness and baseline

**Files:**
- Create: `tests/harness/town_fingerprint.gd`
- Create: `docs/qa/2026-10-07-town-odds/fingerprint/baseline.json`

**Interfaces:**
- Produces: `town_fingerprint.gd` CLI: `-- --towns 53:grand,31:large --out PATH [--compare PATH] [--odds name=value ...]`. Writes JSON `{ "53:grand": {"source": sha, "payload": sha, "ms": int}, ... }`. With `--compare`, exits 1 and prints `FINGERPRINT_MISMATCH <town> <part>` on any difference, else prints `FINGERPRINT_MATCH`. (`--odds` is accepted from Task 4 on; before Task 4 it is ignored with a warning.)

- [ ] **Step 1: Write the harness**

```gdscript
extends SceneTree
## Byte-identity fingerprints for whole towns. A town's source plan (plots,
## passages, stamps, excavation) and its complete flat-ground payload are
## hashed incrementally with var_to_bytes, so identical generation gives
## identical hashes and any change in geometry, placement or dressing shows.

const REVIEW := preload("res://tests/harness/suntail/kit_town_review.gd")
const DEFAULT_TOWNS := "53:grand,31:large,13:standard,43:large,83:grand,103:standard,7:compact,61:standard"

func _init() -> void:
	call_deferred("_run")

func _arg(args: PackedStringArray, name: String, fallback: String) -> String:
	var i := args.find(name)
	return args[i + 1] if i >= 0 and i + 1 < args.size() else fallback

func _hash_values(values: Array) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	for value: Variant in values:
		ctx.update(var_to_bytes(value))
	return ctx.finish().hex_encode()

func _payload_hash(payload: EnvironmentInstancePayload) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	for id: Variant in payload.batches:
		ctx.update(var_to_bytes(id))
		ctx.update(var_to_bytes(payload.batches[id]))
	for box: Dictionary in payload.collision_boxes:
		ctx.update(var_to_bytes(box))
	for mesh: Dictionary in payload.surface_meshes:
		ctx.update(var_to_bytes(mesh))
	for skirt: Dictionary in payload.ground_skirts:
		ctx.update(var_to_bytes(skirt))
	return ctx.finish().hex_encode()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var towns := _arg(args, "--towns", DEFAULT_TOWNS).split(",")
	var out_path := _arg(args, "--out", "/tmp/town_fingerprint.json")
	var compare_path := _arg(args, "--compare", "")
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var results := {}
	for town: String in towns:
		var parts := town.split(":")
		var started := Time.get_ticks_msec()
		var profile := WarrenVillageScaleProfile.for_id(StringName(parts[1]))
		var spatial := WarrenVolumetricSolver.generate(int(parts[0]), {}, program, profile)
		if spatial == null:
			results[town] = {"error": "no town"}
			print("FINGERPRINT_NO_TOWN ", town)
			continue
		var source := spatial.source_volume.mass_context.get(&"maze_source_plan") as WarrenMazeSourcePlan
		var fabric := spatial.compiled_fabric_cache()
		var source_hash := _hash_values([source.plots, source.passage_kinds,
			source.feature_stamps, source.market_square_cells, source.summit_cell,
			source.excavation.carved, source.excavation.lanes,
			source.excavation.tunnel_cells, source.excavation.construction_reservations])
		var payload := REVIEW.town_payload(spatial, fabric, false)
		results[town] = {"source": source_hash, "payload": _payload_hash(payload),
			"ms": Time.get_ticks_msec() - started}
		print("FINGERPRINT ", town, " ", JSON.stringify(results[town]))
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "  "))
	file.close()
	if compare_path.is_empty():
		quit(0)
		return
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(compare_path))
	var ok := true
	for town: String in towns:
		for part: String in ["source", "payload", "error"]:
			if str((expected.get(town, {}) as Dictionary).get(part, "")) \
					!= str((results.get(town, {}) as Dictionary).get(part, "")):
				print("FINGERPRINT_MISMATCH ", town, " ", part)
				ok = false
	print("FINGERPRINT_MATCH" if ok else "FINGERPRINT_DIFFERS")
	quit(0 if ok else 1)
```

- [ ] **Step 2: Run it twice and confirm determinism**

Run:
```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --log-file /tmp/fp1.log -s res://tests/harness/town_fingerprint.gd -- --out /tmp/fp1.json > /tmp/fp1.out 2>&1; echo EXIT $?
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --log-file /tmp/fp2.log -s res://tests/harness/town_fingerprint.gd -- --out /tmp/fp2.json --compare /tmp/fp1.json > /tmp/fp2.out 2>&1; echo EXIT $?; grep FINGERPRINT_ /tmp/fp2.out
```
Expected: both EXIT 0; second prints `FINGERPRINT_MATCH`. If a holdout prints `FINGERPRINT_NO_TOWN`, replace it (`7:compact`→`9:compact`, `61:standard`→`63:standard`) in `DEFAULT_TOWNS`, rerun both commands, and note the substitution in the commit message. If the second run differs, stop: generation is nondeterministic; report which part differs before continuing.

- [ ] **Step 3: Save the baseline and commit**

```bash
mkdir -p docs/qa/2026-10-07-town-odds/fingerprint
cp /tmp/fp1.json docs/qa/2026-10-07-town-odds/fingerprint/baseline.json
git add tests/harness/town_fingerprint.gd docs/qa/2026-10-07-town-odds/fingerprint/baseline.json
git commit -m "Harness: town fingerprints (source + payload hashes) and baseline"
```

---

### Task 2: Dead-code cleanup

**Files (delete — verified unreferenced by any other production script):**
- `scripts/terrain/features/villages/VillageHamletConstruction.gd`, `VillageMassingSolver.gd`, `VillageMarketSolver.gd`, `VillageCirculationSolver.gd`, `VillageTimberFabricSolver.gd`, `VillageSkirtDeckSolver.gd` (and their `.uid` files)
- `scripts/terrain/features/villages/fabric/WarrenPlotVoidPlanner.gd`, `WarrenRisingRingPlanner.gd` (+ `.uid`) — they reference only each other.
- `scripts/terrain/features/villages/grammar/PureVillageNativeHouse.gd` (+ `.uid`)
- Tests/harnesses that exist only for the above: `tests/test_september13_civic.gd`, `tests/test_september10_hamlets.gd`, `tests/harness/september13_civic_payload.gd`, `tests/harness/september10_hamlet_qa.gd`, `tests/test_village_circulation_solver.gd`, `tests/test_village_building_support_solver.gd`, `tests/test_village_massing_solver.gd`, `tests/test_village_rock_core_solver.gd`, `tests/test_village_market_solver.gd`, `tests/harness/village_platform_probe.gd`, `tests/harness/probe_warren_planner.gd`, `tests/fixtures/warren_folded_proof.gd`, `tests/test_pure_village_native_house.gd`, `tests/test_pure_village_native_roof.gd`, `tests/harness/suntail/native_house_grammar_review.gd` (+ `.uid`/`.tscn` siblings)

**Files (modify — remove dead members only):**
- `fabric/WarrenRoomCompositionPlanner.gd`: `_variant_stamp`, `enable_paired_registration_relief` parameter use and `MAX_PAIRED_*` constants (lines ~30-32, ~74, ~3607-3657).
- `fabric/WarrenVolumetricSolver.gd`: `_maze_connectivity_skywalk_plan`, `_maze_connectivity_plan_from_composition`, `_exact_composition_room_probes` (~5247, ~6013, ~6211).
- `fabric/WarrenSpatialFeatureSolver.gd`: unused `TARGET_SKYWALKS`, `TARGET_PREFAB_LANDMARKS`, `TARGET_BALCONIES`, `TARGET_ROOM_OUTCROPPINGS` (keep `MIN_BALCONY_BUILDINGS`, it is read).
- `fabric/WarrenMazeCarver.gd`: `MIN_LOOP_JOINS`, `MAX_LOOP_JOINS` (lines 18-19).
- `fabric/SettlementFabricAssembler.gd`: `FACADE_OUTCROP_KIND_SALT` (~1281), `_is_structural_support_anchor` (~1411) and its test functions in `tests/test_settlement_fabric.gd`.
- `kit/KitRoofTurrets.gd`: `propose()` and `SHARE`; keep `cutters()`. Remove only the `propose`-specific test functions in `tests/test_october3_roof_turrets.gd`.

**Do not delete** (looked dead but are used): `BuildingDesigner.design_standalone` (House_1 replica test), `WarrenOverheadSolver`, `WarrenElevatedFrontageSolver`, `WarrenMarketSolver`, `DECK_MIN` (read by two tests — leave), `_append_terrain_bearing_foundations` (guardrail candidate), NATURAL_ROCK machinery (out of scope), the `VillagePlan` tier/theme rolls (record fields; handled by the market/gates migration).

**Interfaces:** none produced.

- [ ] **Step 1: Re-verify each deletion target is unreferenced**

```bash
for s in VillageHamletConstruction VillageMassingSolver VillageMarketSolver VillageCirculationSolver VillageTimberFabricSolver VillageSkirtDeckSolver WarrenPlotVoidPlanner WarrenRisingRingPlanner PureVillageNativeHouse _variant_stamp _maze_connectivity_skywalk_plan _maze_connectivity_plan_from_composition _exact_composition_room_probes _is_structural_support_anchor FACADE_OUTCROP_KIND_SALT MIN_LOOP_JOINS MAX_LOOP_JOINS TARGET_SKYWALKS TARGET_PREFAB_LANDMARKS TARGET_BALCONIES TARGET_ROOM_OUTCROPPINGS; do echo "== $s"; grep -rlw "$s" scripts tests --include='*.gd' --include='*.tscn'; done
grep -rn "KitRoofTurrets\.propose\|KitRoofTurrets.SHARE" scripts tests
```
Expected: every hit is either the defining file or a file in this task's deletion list. If any other production file references a target, do NOT edit it — drop that target from this task and note it in the commit message.

- [ ] **Step 2: Delete files and members**

Delete the listed files with `git rm`. Remove the listed members with Edit (delete the whole function/constant including its doc comment). For `enable_paired_registration_relief`: remove the parameter from the planner's signature only if every caller passes it positionally-last or by default; otherwise leave the parameter and delete only the unused constants.

- [ ] **Step 3: Reimport and check for parse errors**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import > /tmp/import.out 2>&1; grep -E "SCRIPT ERROR|Parse Error|Could not find" /tmp/import.out | head
```
Expected: no output.

- [ ] **Step 4: Fingerprints must match**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --log-file /tmp/fp.log -s res://tests/harness/town_fingerprint.gd -- --out /tmp/fp-clean.json --compare docs/qa/2026-10-07-town-odds/fingerprint/baseline.json > /tmp/fp-clean.out 2>&1; echo EXIT $?; grep FINGERPRINT_ /tmp/fp-clean.out
```
Expected: `EXIT 0`, `FINGERPRINT_MATCH`.

- [ ] **Step 5: Focused suites still pass**

Run the focused test command for: `test_parallel_range_footprints.gd`, `test_settlement_fabric.gd`, `test_october3_roof_turrets.gd`, `test_building_kit.gd`, `test_warren_maze_plots.gd`, `test_garden_bearing_cap.gd`, `test_tower_preview_reservations.gd`. Expected: same pass counts as before the change minus deleted test functions (record before/after counts in the commit message). Run each file on the pre-change commit first if you need its baseline count.

- [ ] **Step 6: Commit**

```bash
git add -A scripts/terrain/features/villages tests
git commit -m "Cleanup: delete unreached legacy village solvers and dead town-generator members"
```

---

### Task 3: Odds core (knob, table, program, character)

**Files:**
- Create: `scripts/terrain/features/villages/odds/TownKnob.gd`, `TownOddsTable.gd`, `TownOddsProgram.gd`, `TownCharacter.gd`
- Create: `terrain/villages/town_odds.tres` (empty knob list for now)
- Test: `tests/test_town_odds.gd`

**Interfaces:**
- Produces:
  - `TownKnob` (Resource): `name: StringName`, `kind: TownKnob.Kind {CHANCE, RANGE_FLOAT, RANGE_INT, WEIGHTS}`, `at_small: float`, `at_large: float`, `spread: float`, `clamp_min: float`, `clamp_max: float`, `options: PackedStringArray`, `weights_small: PackedFloat32Array`, `weights_large: PackedFloat32Array`, `notes: String`.
  - `TownOddsTable` (Resource): `knobs: Array[TownKnob]`.
  - `TownOddsProgram` (RefCounted): `static func compile(table: TownOddsTable) -> TownOddsProgram`; `var knobs: Dictionary` (StringName → plain Dictionary); `var errors: PackedStringArray`; `static func builtin() -> TownOddsProgram`; `func with_overrides(overrides: Dictionary) -> TownOddsProgram`; `static func parse_overrides(args: PackedStringArray, program: TownOddsProgram) -> Dictionary` (pushes an error and returns `{"error": String}` on bad input).
  - `TownCharacter` (RefCounted): `static func draw(program: TownOddsProgram, town_seed: int, size: float) -> TownCharacter`; `var town_seed: int`, `var size: float`, `var values: Dictionary`, `var overridden: bool`; `func value(name: StringName) -> float`; `func count(name: StringName) -> int`; `func weights(name: StringName) -> Dictionary`; `func roll(name: StringName, key: Variant) -> float`; `func chance(name: StringName, key: Variant, boost := 1.0) -> bool`; `func pick(name: StringName, key: Variant) -> StringName`; `func signature_suffix() -> String`; `static func stable_hash(text: String) -> int`.

- [ ] **Step 1: Write the failing tests**

```gdscript
extends GutTest

func _knob(name: StringName, kind: int, small: float, large: float,
		spread := 0.0, lo := 0.0, hi := 1.0) -> TownKnob:
	var knob := TownKnob.new()
	knob.name = name
	knob.kind = kind
	knob.at_small = small
	knob.at_large = large
	knob.spread = spread
	knob.clamp_min = lo
	knob.clamp_max = hi
	return knob

func _weights(name: StringName, options: PackedStringArray, small: PackedFloat32Array,
		large: PackedFloat32Array, spread := 0.0) -> TownKnob:
	var knob := _knob(name, TownKnob.Kind.WEIGHTS, 0.0, 0.0, spread)
	knob.options = options
	knob.weights_small = small
	knob.weights_large = large
	return knob

func _program(knobs: Array[TownKnob]) -> TownOddsProgram:
	var table := TownOddsTable.new()
	table.knobs = knobs
	var program := TownOddsProgram.compile(table)
	assert_eq(program.errors.size(), 0, str(program.errors))
	return program

func test_spread_zero_is_the_size_blend_and_clamped() -> void:
	var p := _program([_knob(&"a", TownKnob.Kind.RANGE_FLOAT, 0.2, 0.8)])
	assert_almost_eq(TownCharacter.draw(p, 1, 0.5).value(&"a"), 0.5, 1e-6)
	var q := _program([_knob(&"b", TownKnob.Kind.CHANCE, 1.4, 1.4)])
	assert_eq(TownCharacter.draw(q, 1, 0.0).value(&"b"), 1.0)

func test_same_seed_same_values_different_seeds_vary() -> void:
	var p := _program([_knob(&"a", TownKnob.Kind.RANGE_FLOAT, 0.5, 0.5, 0.4)])
	assert_eq(TownCharacter.draw(p, 7, 0.3).value(&"a"), TownCharacter.draw(p, 7, 0.3).value(&"a"))
	var seen := {}
	for seed_value in 50:
		seen[snappedf(TownCharacter.draw(p, seed_value, 0.3).value(&"a"), 0.01)] = true
	assert_gt(seen.size(), 20)

func test_one_knob_change_leaves_other_knobs_and_rolls_untouched() -> void:
	var a := _knob(&"a", TownKnob.Kind.RANGE_FLOAT, 0.5, 0.5, 0.4)
	var before := TownCharacter.draw(_program([a, _knob(&"b", TownKnob.Kind.CHANCE, 0.3, 0.3, 0.1)]), 11, 0.4)
	var after := TownCharacter.draw(_program([_knob(&"z", TownKnob.Kind.CHANCE, 0.9, 0.9), a,
		_knob(&"b", TownKnob.Kind.CHANCE, 0.6, 0.6, 0.3)]), 11, 0.4)
	assert_eq(before.value(&"a"), after.value(&"a"))
	for key in 200:
		assert_eq(before.roll(&"a", Vector3i(key, 2, 3)), after.roll(&"a", Vector3i(key, 2, 3)))

func test_range_int_mean_matches_fractional_centre() -> void:
	var p := _program([_knob(&"n", TownKnob.Kind.RANGE_INT, 0.25, 0.25, 0.0, 0.0, 10.0)])
	var total := 0
	for seed_value in 4000:
		total += TownCharacter.draw(p, seed_value, 0.0).count(&"n")
	assert_almost_eq(float(total) / 4000.0, 0.25, 0.03)

func test_weights_normalised_and_centre_without_spread() -> void:
	var p := _program([_weights(&"w", PackedStringArray(["x", "y"]),
		PackedFloat32Array([1.0, 3.0]), PackedFloat32Array([1.0, 3.0]))])
	var w := TownCharacter.draw(p, 5, 0.5).weights(&"w")
	assert_almost_eq(float(w[&"x"]), 0.25, 1e-6)
	assert_almost_eq(float(w[&"y"]), 0.75, 1e-6)

func test_chance_extremes_and_boost() -> void:
	var p := _program([_knob(&"one", TownKnob.Kind.CHANCE, 1.0, 1.0),
		_knob(&"zero", TownKnob.Kind.CHANCE, 0.0, 0.0),
		_knob(&"half", TownKnob.Kind.CHANCE, 0.25, 0.25)])
	var c := TownCharacter.draw(p, 3, 0.0)
	var boosted := 0
	for key in 1000:
		assert_true(c.chance(&"one", key))
		assert_false(c.chance(&"zero", key))
		if c.chance(&"half", key, 4.0): boosted += 1
	assert_eq(boosted, 1000, "0.25 x 4 clamps to certainty")

func test_overrides_fix_value_and_mark_character() -> void:
	var p := _program([_knob(&"a", TownKnob.Kind.RANGE_FLOAT, 0.2, 0.8, 0.3)])
	var c := TownCharacter.draw(p.with_overrides({&"a": 0.7}), 9, 0.1)
	assert_almost_eq(c.value(&"a"), 0.7, 1e-6)
	assert_true(c.overridden)
	assert_true(c.signature_suffix().begins_with("/odds:"))
	assert_eq(TownCharacter.draw(p, 9, 0.1).signature_suffix(), "")

func test_compile_reports_bad_knobs() -> void:
	var table := TownOddsTable.new()
	var bad := _weights(&"w", PackedStringArray(["x", "y"]), PackedFloat32Array([1.0]), PackedFloat32Array([1.0, 2.0]))
	var inverted := _knob(&"i", TownKnob.Kind.RANGE_FLOAT, 0.5, 0.5, 0.0, 2.0, 1.0)
	table.knobs = [_knob(&"d", TownKnob.Kind.CHANCE, 0.5, 0.5), _knob(&"d", TownKnob.Kind.CHANCE, 0.5, 0.5), bad, inverted]
	var errors := " ".join(TownOddsProgram.compile(table).errors)
	assert_string_contains(errors, "duplicate knob d")
	assert_string_contains(errors, "knob w")
	assert_string_contains(errors, "knob i")

func test_parse_overrides_rejects_unknown_and_non_numeric() -> void:
	var p := _program([_knob(&"a", TownKnob.Kind.CHANCE, 0.5, 0.5)])
	assert_eq(TownOddsProgram.parse_overrides(PackedStringArray(["--odds", "a=0.3"]), p), {&"a": 0.3})
	assert_true(TownOddsProgram.parse_overrides(PackedStringArray(["--odds", "nope=1"]), p).has("error"))
	assert_true(TownOddsProgram.parse_overrides(PackedStringArray(["--odds", "a=lots"]), p).has("error"))

func test_builtin_table_compiles_cleanly() -> void:
	assert_eq(TownOddsProgram.builtin().errors.size(), 0)
```

- [ ] **Step 2: Run to verify failure**

Run the focused test command for `test_town_odds.gd`. Expected: parse errors / "Could not find type TownKnob".

- [ ] **Step 3: Implement `TownKnob.gd`**

```gdscript
class_name TownKnob
extends Resource
## One tunable aesthetic decision. Value at town size 0 (`at_small`) and 1
## (`at_large`) blends linearly; `spread` is how far one town may deviate.
## CHANCE and RANGE_FLOAT draw a float, RANGE_INT draws an integer whose mean
## is the (possibly fractional) centre, WEIGHTS draws per-town option weights
## (each centre weight jittered by +-spread, then normalised).

enum Kind { CHANCE, RANGE_FLOAT, RANGE_INT, WEIGHTS }

@export var name: StringName
@export var kind: Kind = Kind.CHANCE
@export var at_small := 0.0
@export var at_large := 0.0
@export var spread := 0.0
@export var clamp_min := 0.0
@export var clamp_max := 1.0
@export var options: PackedStringArray = PackedStringArray()
@export var weights_small: PackedFloat32Array = PackedFloat32Array()
@export var weights_large: PackedFloat32Array = PackedFloat32Array()
@export_multiline var notes := ""
```

- [ ] **Step 4: Implement `TownOddsTable.gd`**

```gdscript
class_name TownOddsTable
extends Resource
## The editable list of town knobs (terrain/villages/town_odds.tres).

@export var knobs: Array[TownKnob] = []
```

- [ ] **Step 5: Implement `TownOddsProgram.gd`**

```gdscript
class_name TownOddsProgram
extends RefCounted
## Plain-data compilation of a TownOddsTable, safe to hand to the worker.

const BUILTIN_PATH := "res://terrain/villages/town_odds.tres"
static var _builtin: TownOddsProgram

var knobs: Dictionary = {}
var errors: PackedStringArray = PackedStringArray()
var overrides: Dictionary = {}


static func compile(table: TownOddsTable) -> TownOddsProgram:
	var program := TownOddsProgram.new()
	for knob: TownKnob in table.knobs:
		var label := String(knob.name)
		if label.is_empty():
			program.errors.append("knob with an empty name")
			continue
		if program.knobs.has(knob.name):
			program.errors.append("duplicate knob %s" % label)
			continue
		if knob.clamp_min > knob.clamp_max:
			program.errors.append("knob %s has clamp_min above clamp_max" % label)
			continue
		if knob.kind == TownKnob.Kind.WEIGHTS and (knob.options.is_empty() \
				or knob.weights_small.size() != knob.options.size() \
				or knob.weights_large.size() != knob.options.size()):
			program.errors.append("knob %s needs one small and one large weight per option" % label)
			continue
		program.knobs[knob.name] = {"kind": int(knob.kind), "small": knob.at_small,
			"large": knob.at_large, "spread": knob.spread, "min": knob.clamp_min,
			"max": knob.clamp_max, "options": Array(knob.options),
			"weights_small": Array(knob.weights_small), "weights_large": Array(knob.weights_large)}
	for message: String in program.errors:
		push_error("town odds: " + message)
	return program


static func builtin() -> TownOddsProgram:
	if _builtin == null:
		_builtin = compile(load(BUILTIN_PATH) as TownOddsTable)
	return _builtin


func with_overrides(values: Dictionary) -> TownOddsProgram:
	var copy := TownOddsProgram.new()
	copy.knobs = knobs.duplicate(true)
	copy.errors = errors.duplicate()
	copy.overrides = overrides.duplicate()
	for name: StringName in values:
		var knob: Dictionary = copy.knobs[name]
		knob["small"] = float(values[name])
		knob["large"] = float(values[name])
		knob["spread"] = 0.0
		copy.overrides[name] = float(values[name])
	return copy


static func parse_overrides(args: PackedStringArray, program: TownOddsProgram) -> Dictionary:
	var out := {}
	for i in args.size() - 1:
		if args[i] != "--odds":
			continue
		var pair := args[i + 1].split("=")
		var name := StringName(pair[0])
		if pair.size() != 2 or not program.knobs.has(name):
			var message := "unknown --odds knob '%s'; valid: %s" % [pair[0], ", ".join(program.knobs.keys())]
			push_error(message)
			return {"error": message}
		if not pair[1].is_valid_float():
			var message := "--odds %s needs a number, got '%s'" % [pair[0], pair[1]]
			push_error(message)
			return {"error": message}
		out[name] = float(pair[1])
	return out
```

- [ ] **Step 6: Implement `TownCharacter.gd`**

```gdscript
class_name TownCharacter
extends RefCounted
## A town's drawn value for every knob, plus deterministic per-decision
## rolls. Every knob has its own stream (town seed x knob name), and every
## roll adds the decision's key, so changing one knob never moves another
## knob's draw or roll.

const FNV_OFFSET := -3750763034362895579  # 0xcbf29ce484222325 as signed int64
const FNV_PRIME := 1099511628211

var town_seed := 0
var size := 0.0
var values: Dictionary = {}
var overridden := false


static func stable_hash(text: String) -> int:
	var h := FNV_OFFSET
	for byte: int in text.to_utf8_buffer():
		h = (h ^ byte) * FNV_PRIME
	return h


static func _unit(h: int) -> float:
	return float(Helper._mix64(h) & 0x1FFFFFFFFFFFFF) / 9007199254740992.0


static func _key_hash(key: Variant) -> int:
	match typeof(key):
		TYPE_INT: return key
		TYPE_VECTOR2I: return key.x * 73856093 ^ key.y * 19349663
		TYPE_VECTOR3I: return key.x * 73856093 ^ key.y * 19349663 ^ key.z * 83492791
		TYPE_VECTOR4I: return key.x * 73856093 ^ key.y * 19349663 ^ key.z * 83492791 ^ key.w * 2654435761
		TYPE_STRING, TYPE_STRING_NAME: return stable_hash(String(key))
	return stable_hash(var_to_str(key))


func _stream(name: StringName, salt := 0) -> int:
	return town_seed ^ stable_hash(String(name)) ^ Helper._mix64(salt)


static func draw(program: TownOddsProgram, p_seed: int, p_size: float) -> TownCharacter:
	var c := TownCharacter.new()
	c.town_seed = p_seed
	c.size = clampf(p_size, 0.0, 1.0)
	c.overridden = not program.overrides.is_empty()
	for name: StringName in program.knobs:
		var knob: Dictionary = program.knobs[name]
		var spread := float(knob.spread)
		match int(knob.kind):
			TownKnob.Kind.WEIGHTS:
				var out := {}
				var total := 0.0
				var options: Array = knob.options
				for i in options.size():
					var centre := lerpf(float(knob.weights_small[i]), float(knob.weights_large[i]), c.size)
					var jitter := 1.0 + spread * (2.0 * _unit(c._stream(name, i + 1)) - 1.0)
					var w := maxf(0.0, centre * jitter)
					out[StringName(options[i])] = w
					total += w
				for option: StringName in out:
					out[option] = float(out[option]) / total if total > 0.0 else 1.0 / float(out.size())
				c.values[name] = out
			TownKnob.Kind.RANGE_INT:
				var centre := lerpf(float(knob.small), float(knob.large), c.size)
				var v := centre + spread * (2.0 * _unit(c._stream(name, 1)) - 1.0)
				c.values[name] = clampf(floorf(v + _unit(c._stream(name, 2))), float(knob.min), float(knob.max))
			_:
				var centre := lerpf(float(knob.small), float(knob.large), c.size)
				var v := centre + spread * (2.0 * _unit(c._stream(name, 1)) - 1.0)
				c.values[name] = clampf(v, float(knob.min), float(knob.max))
	return c


func value(name: StringName) -> float:
	assert(values.has(name), "unknown town knob %s" % name)
	return float(values[name])


func count(name: StringName) -> int:
	return int(value(name))


func weights(name: StringName) -> Dictionary:
	assert(values.has(name), "unknown town knob %s" % name)
	return values[name]


func roll(name: StringName, key: Variant) -> float:
	return _unit(_stream(name) ^ Helper._mix64(_key_hash(key)))


func chance(name: StringName, key: Variant, boost := 1.0) -> bool:
	return roll(name, key) < clampf(value(name) * boost, 0.0, 1.0)


func pick(name: StringName, key: Variant) -> StringName:
	var r := roll(name, key)
	var last := &""
	for option: StringName in weights(name):
		last = option
		r -= float(values[name][option])
		if r < 0.0:
			return option
	return last


func signature_suffix() -> String:
	if not overridden:
		return ""
	return "/odds:" + var_to_str(values).sha256_text().substr(0, 12)
```

- [ ] **Step 7: Create the empty default table**

Write `terrain/villages/town_odds.tres`:

```
[gd_resource type="Resource" script_class="TownOddsTable" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/terrain/features/villages/odds/TownOddsTable.gd" id="1"]

[resource]
script = ExtResource("1")
knobs = Array[Resource]([])
```

Then reimport (Global Constraints) so the new `class_name`s register.

- [ ] **Step 8: Run tests to verify they pass**

Run the focused test command for `test_town_odds.gd`. Expected: all tests pass, 0 script errors.

- [ ] **Step 9: Commit**

```bash
git add scripts/terrain/features/villages/odds terrain/villages/town_odds.tres tests/test_town_odds.gd
git commit -m "Odds: town knob table, compiled program and per-town character draws"
```

---

### Task 4: Wire the character through the pipeline and review harnesses

**Files:**
- Modify: `fabric/WarrenVillageScaleProfile.gd` (add `var character: TownCharacter`; append `signature_suffix()` in `deterministic_signature()`)
- Modify: `fabric/SettlementFabricProgram.gd` (add `var town_odds: TownOddsProgram`; set in `compile`)
- Modify: `fabric/WarrenVolumetricSolver.gd` (`_generate`: attach character after the profile is resolved)
- Create in `TownCharacter.gd`: `static func attach(profile, program, town_seed) -> TownCharacter` and `static func of(profile, town_seed) -> TownCharacter`
- Modify: `tests/harness/suntail/kit_town_review.gd`, `tests/harness/town_fingerprint.gd` (accept `--odds`, print `TOWN_CHARACTER`)
- Test: `tests/test_town_character_wiring.gd`

**Interfaces:**
- Consumes: Task 3 types.
- Produces: `profile.character: TownCharacter` set for every town built by `WarrenVolumetricSolver.generate`; `TownCharacter.of(profile: WarrenVillageScaleProfile, town_seed: int) -> TownCharacter` (returns the attached character for that seed or draws one from `TownOddsProgram.builtin()` and attaches it); `TownCharacter.attach(profile: WarrenVillageScaleProfile, program: TownOddsProgram, town_seed: int) -> TownCharacter`; `SettlementFabricProgram.town_odds: TownOddsProgram`.

- [ ] **Step 1: Write the failing tests**

```gdscript
extends GutTest

func test_generate_attaches_character_for_its_seed() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var profile := WarrenVillageScaleProfile.for_id(&"standard")
	var spatial := WarrenVolumetricSolver.generate(103, {}, program, profile)
	assert_not_null(spatial)
	assert_not_null(profile.character)
	assert_eq(profile.character.town_seed, 103)
	assert_eq(profile.character.values, TownCharacter.draw(program.town_odds, 103, profile.size).values)

func test_profile_reuse_redraws_per_seed() -> void:
	var profile := WarrenVillageScaleProfile.for_id(&"compact")
	var first := TownCharacter.of(profile, 1)
	var second := TownCharacter.of(profile, 2)
	assert_eq(first.town_seed, 1)
	assert_eq(second.town_seed, 2)
	assert_eq(profile.character, second)

func test_direct_planner_call_draws_builtin_character() -> void:
	var profile := WarrenVillageScaleProfile.for_id(&"standard")
	var plan := WarrenMazeSitePlanner.plan(13, {}, profile)
	assert_not_null(plan)
	assert_eq(TownCharacter.of(profile, 13).values,
		TownCharacter.draw(TownOddsProgram.builtin(), 13, profile.size).values)

func test_signature_unchanged_without_overrides() -> void:
	var profile := WarrenVillageScaleProfile.for_id(&"large")
	var before := profile.deterministic_signature()
	TownCharacter.attach(profile, TownOddsProgram.builtin(), 5)
	assert_eq(profile.deterministic_signature(), before)
```

Note: `WarrenMazeSitePlanner.plan` is the existing static entry (`WarrenMazeSitePlanner.gd`); check its exact signature with `grep -n "static func plan" scripts/terrain/features/villages/fabric/WarrenMazeSitePlanner.gd` and adapt the call's arguments (keep seed 13, profile standard) before running.

- [ ] **Step 2: Run to verify failure**

Run the focused command for `test_town_character_wiring.gd`. Expected: failures on `profile.character` (no such member) / `TownCharacter.of`.

- [ ] **Step 3: Add `attach` and `of` to `TownCharacter.gd`**

```gdscript
static func attach(profile: WarrenVillageScaleProfile, program: TownOddsProgram,
		p_seed: int) -> TownCharacter:
	profile.character = draw(program, p_seed, profile.size)
	return profile.character


static func of(profile: WarrenVillageScaleProfile, p_seed: int) -> TownCharacter:
	if profile.character != null and profile.character.town_seed == p_seed:
		return profile.character
	return attach(profile, TownOddsProgram.builtin(), p_seed)
```

- [ ] **Step 4: Profile field and signature**

In `WarrenVillageScaleProfile.gd` add after `var requires_covered_market: bool`:

```gdscript
## The town's drawn odds (TownCharacter). Set per town by
## WarrenVolumetricSolver._generate / TownCharacter.of; never part of the
## size budgets above.
var character: TownCharacter
```

In `deterministic_signature()`, change `return "%s@..." % [...]` to assign to `var text :=` and then `return text + (character.signature_suffix() if character != null else "")`.

- [ ] **Step 5: Program field**

In `SettlementFabricProgram.gd` add `var town_odds: TownOddsProgram` near the other top-level vars, and inside `static func compile(catalog)` before `return program`: `program.town_odds = TownOddsProgram.builtin()`.

- [ ] **Step 6: Attach in `_generate`**

In `WarrenVolumetricSolver._generate`, immediately after the scale profile is resolved (the line that falls back to `WarrenVillageScaleProfile.select(world_seed)` when null; find it with `grep -n "WarrenVillageScaleProfile.select" scripts/terrain/features/villages/fabric/WarrenVolumetricSolver.gd`), insert:

```gdscript
	TownCharacter.attach(profile,
		construction_program.town_odds if construction_program != null \
			and construction_program.town_odds != null else TownOddsProgram.builtin(),
		world_seed)
```
(use the local variable name `_generate` already uses for the resolved profile).

- [ ] **Step 7: Harness flags**

In `town_fingerprint.gd` `_run()`, after compiling `program`, add:

```gdscript
	var overrides := TownOddsProgram.parse_overrides(args, program.town_odds)
	if overrides.has("error"):
		quit(2)
		return
	if not overrides.is_empty():
		program.town_odds = program.town_odds.with_overrides(overrides)
```
and after `generate`: `print("TOWN_CHARACTER ", town, " ", JSON.stringify(profile.character.values))`.

In `kit_town_review.gd`, at the place it compiles `SettlementFabricProgram` before calling `WarrenVolumetricSolver.generate` (find with `grep -n "SettlementFabricProgram.compile\|WarrenVolumetricSolver.generate" tests/harness/suntail/kit_town_review.gd`), apply the same override block, and after the town is generated print `TOWN_CHARACTER <seed>:<profile> <json>` using the profile object passed to `generate`.

- [ ] **Step 8: Run tests and fingerprints**

Reimport; run `test_town_character_wiring.gd` and `test_town_odds.gd` (all pass); run the fingerprint compare (Task 2 Step 4 command, output `/tmp/fp-wire.json`). Expected: `FINGERPRINT_MATCH`.

- [ ] **Step 9: Commit**

```bash
git add scripts/terrain/features/villages tests/test_town_character_wiring.gd tests/harness/town_fingerprint.gd tests/harness/suntail/kit_town_review.gd
git commit -m "Odds: attach a drawn character to every town; --odds overrides in review harnesses"
```

---

### Task 5: Aesthetic quotas become shortfalls

**Files:**
- Modify: `fabric/WarrenMazeSourcePlan.gd` (seal: loop requirement and straight-run caps)
- Modify: `fabric/WarrenSpatialFeatureSolver.gd` (~348-388: tower-annex and outcropping minimum failures)
- Test: `tests/test_aesthetic_shortfalls.gd`

**Interfaces:**
- Produces: `WarrenMazeSourcePlan.aesthetic_shortfalls(audit: Dictionary, loop_edge_count: int) -> Dictionary` (static; keys `loop_join`, `spine_straight_run`, `alley_straight_run` with `{"limit": int, "found": int}`); sealed plans store it in `audit["aesthetic_shortfalls"]`. Feature-solver shortfalls go to `WarrenVolumetricSolver.last_advisory_shortfalls["tower_annexes"]` / `["room_outcroppings"]` as `{"target": int, "found": int}`.

- [ ] **Step 1: Write the failing test**

```gdscript
extends GutTest

func test_shortfalls_reported_not_rejected() -> void:
	var audit := {"max_spine_straight_run": WarrenMazeSourcePlan.MAX_SPINE_STRAIGHT_RUN + 2,
		"max_alley_straight_run": WarrenMazeSourcePlan.MAX_ALLEY_STRAIGHT_RUN}
	var out := WarrenMazeSourcePlan.aesthetic_shortfalls(audit, 0)
	assert_eq(out["loop_join"], {"limit": 1, "found": 0})
	assert_eq(out["spine_straight_run"], {"limit": WarrenMazeSourcePlan.MAX_SPINE_STRAIGHT_RUN,
		"found": WarrenMazeSourcePlan.MAX_SPINE_STRAIGHT_RUN + 2})
	assert_false(out.has("alley_straight_run"))

func test_clean_audit_has_no_shortfalls() -> void:
	assert_eq(WarrenMazeSourcePlan.aesthetic_shortfalls({"max_spine_straight_run": 1,
		"max_alley_straight_run": 1}, 2), {})

func test_sealed_town_carries_shortfall_record() -> void:
	var plan := WarrenMazeSitePlanner.plan(13, {}, WarrenVillageScaleProfile.for_id(&"standard"))
	assert_not_null(plan)
	assert_true(plan.audit.has("aesthetic_shortfalls"))
```
(Adapt the `WarrenMazeSitePlanner.plan` call exactly as in Task 4.)

- [ ] **Step 2: Run to verify failure** — expected: `aesthetic_shortfalls` not found.

- [ ] **Step 3: Implement in `WarrenMazeSourcePlan.gd`**

Add:

```gdscript
static func aesthetic_shortfalls(audit_facts: Dictionary, loop_edge_count: int) -> Dictionary:
	## Look rules the seal used to enforce. They describe what a town
	## usually has, not what makes it broken, so they are recorded, never
	## rejected (owner principle, October 7).
	var out := {}
	if loop_edge_count < 1:
		out["loop_join"] = {"limit": 1, "found": loop_edge_count}
	var spine := int(audit_facts.get("max_spine_straight_run", 0))
	if spine > MAX_SPINE_STRAIGHT_RUN:
		out["spine_straight_run"] = {"limit": MAX_SPINE_STRAIGHT_RUN, "found": spine}
	var alley := int(audit_facts.get("max_alley_straight_run", 0))
	if alley > MAX_ALLEY_STRAIGHT_RUN:
		out["alley_straight_run"] = {"limit": MAX_ALLEY_STRAIGHT_RUN, "found": alley}
	return out
```

In the seal function shown at lines ~226-243: delete the `if excavation.loop_edges.is_empty(): return _reject(...)` block, and replace the straight-run `if ... return _reject(...)` block with:

```gdscript
	audit["aesthetic_shortfalls"] = aesthetic_shortfalls(audit, excavation.loop_edges.size())
```
(placed right after `audit.merge(built, true)`).

- [ ] **Step 4: Feature solver**

In `WarrenSpatialFeatureSolver.gd` at the `if tower_annex_relief_units < required_tower_annexes:` block, replace the `last_failure = ...` / `return []` pair with:

```gdscript
		WarrenVolumetricSolver.last_advisory_shortfalls["tower_annexes"] = {
			"target": required_tower_annexes, "found": tower_annex_relief_units}
```
(keep building the `annexes_by_source` diagnostic into `last_annex_diagnostic["shortfall_sources"]` instead of discarding it). At `if room_outcropping_count < minimum_outcroppings:` likewise record `["room_outcroppings"] = {"target": minimum_outcroppings, "found": room_outcropping_count}` and continue instead of returning.

- [ ] **Step 5: Run tests and fingerprints**

Run `test_aesthetic_shortfalls.gd` (pass) and the fingerprint compare (`FINGERPRINT_MATCH` — these paths only stop rejections; evidence towns already seal). Also run `test_warren_maze_composition.gd`; record its pass count before/after in the commit message (it reads the sweep matrix and may need `warren_maze_mode_sweep.gd` rerun only if it reports a stale fingerprint — if so, rerun the sweep exactly as AGENTS.md describes).

- [ ] **Step 6: Commit**

```bash
git add scripts/terrain/features/villages/fabric/WarrenMazeSourcePlan.gd scripts/terrain/features/villages/fabric/WarrenSpatialFeatureSolver.gd tests/test_aesthetic_shortfalls.gd
git commit -m "Seal: loop, straight-run, annex and outcrop quotas recorded as shortfalls, never rejections"
```

---

### Task 6: Dressing uses the world seed; placement order shuffled (changes output)

**Files:**
- Modify: `fabric/SettlementFabricAssembler.gd` (`_face_noise` signature at ~6961 and all callers; lamp/furniture station ordering ~6657-6763; facade module pick ~3716)
- Test: `tests/test_dressing_seed.gd`
- Update: `docs/qa/2026-10-07-town-odds/fingerprint/baseline.json` (new baseline after review)

**Interfaces:**
- Produces: `SettlementFabricAssembler._face_noise(face: Vector4i, salt: int, world_seed: int) -> float` (seed now required).

- [ ] **Step 1: Write the failing test**

```gdscript
extends GutTest

func test_face_noise_depends_on_world_seed() -> void:
	var differs := 0
	for x in 64:
		var face := Vector4i(x, 2, 3, 0)
		if SettlementFabricAssembler._face_noise(face, 11, 1) != SettlementFabricAssembler._face_noise(face, 11, 2):
			differs += 1
	assert_gt(differs, 50)
```

- [ ] **Step 2: Run to verify failure** — with today's default parameter the call compiles but values equal only if the seed is ignored inside; if the test already passes (the seed is mixed when given), proceed: the defect is the callers omitting it. Make the parameter required in Step 3 regardless.

- [ ] **Step 3: Make the seed required and fix every caller**

Change the signature to `static func _face_noise(face: Vector4i, salt: int, world_seed: int) -> float:`. Reimport; each caller without a seed now reports a parse error. At each, pass the seed available in that function (`fabric.world_seed`, a `world_seed` parameter, or a `seed`-named local — read the enclosing function). For the NATURAL_ROCK callers (~6927-6949, disabled feature) pass `0` with comment `# natural rock is off; seed irrelevant`. If a static helper has no access to any seed, add a `world_seed: int` parameter to it and thread it from its caller.

- [ ] **Step 4: Shuffle lamp and furniture station order**

In the garden lamp pass (~6657-6700) and furniture pass (~6703-6763), find the line that sorts candidate cells (e.g. `sort_custom(_cell_less)` or similar). Replace the sort so candidates are ordered by `_face_noise(Vector4i(cell.x, cell.y, cell.z, 0), LAMP_ORDER_SALT, world_seed)` (lamps) and `FURNITURE_ORDER_SALT` (furniture), breaking ties with the original comparator. Add constants `const LAMP_ORDER_SALT := 0x4C414D50` and `const FURNITURE_ORDER_SALT := 0x46555252` near the other salts.

- [ ] **Step 5: Facade module pick**

At ~3716 replace the `posmod(x + z + y + w + seed, n)` expression with `int(_face_noise(Vector4i(x, y, z, w), FACADE_MODULE_SALT, world_seed) * float(n)) % n` (add `const FACADE_MODULE_SALT := 0x4D4F4455`), using the same local names the expression used.

- [ ] **Step 6: Tests, audit and renders**

Reimport; run `test_dressing_seed.gd`, `test_settlement_fabric.gd`, `test_garden_bearing_cap.gd` (pass). Run the fingerprint harness without `--compare` to `/tmp/fp-seed.json` (payload hashes are expected to change; source hashes must still match the baseline — verify with `diff <(jq -r 'to_entries[]|.key+" "+.value.source' baseline.json) <(jq -r 'to_entries[]|.key+" "+.value.source' /tmp/fp-seed.json)` and expect no output). Render before (checkout previous commit into `/tmp/before-wt` with `git worktree add`) and after for `53:grand,31:large,43:large` with `--views overview,courtyard,street --garden-grass`; archive in `docs/qa/2026-10-07-town-odds/dressing-seed/{before,after}/`. Inspect: lamps/furniture no longer cluster in one corner; no prop intersects a wall, rail or route (look at street and courtyard views). Run the production audit from `docs/qa/2026-10-01-town-redesign/prefab-grammar/october6-integrated-checkpoint/unequal-roof-range-study/production-validation/oct7-range-audit-prod.gd.txt` (copy to `tests/harness/_odds_audit.gd`, run, delete the copy): every town `valid_payload: true`, `floating: 0`, `intrusions: 0`.

- [ ] **Step 7: New baseline and commit**

```bash
cp /tmp/fp-seed.json docs/qa/2026-10-07-town-odds/fingerprint/baseline.json
git add scripts/terrain/features/villages/fabric/SettlementFabricAssembler.gd tests/test_dressing_seed.gd docs/qa/2026-10-07-town-odds
git commit -m "Dressing: every roll uses the world seed; lamp/furniture order and facade modules hashed"
```

---

### Task 7: Tunnel attrition measurement

**Files:**
- Modify: `fabric/WarrenExcavation.gd` (add `var tunnel_attrition: Dictionary = {}`)
- Modify: `fabric/WarrenMazeCarver.gd` `_natural_tunnel_caps` (~1810-1870): count stages
- Modify: `fabric/WarrenMazeSitePlanner.gd` (~276 copy `tunnel_attrition`; ~305 count pruned cells; after `cover_tunnels` store record count)
- Add `tunnel_attrition` to every excavation copy-field list (`WarrenDistrictLandmarkAccess.gd:6`, `WarrenMazeCarver.gd` ~2771 and ~2876, `WarrenMazeSitePlanner.gd` ~111, `WarrenPlatformStreets.gd` ~101)
- Create: `tests/harness/tunnel_attrition.gd`
- Create: `docs/qa/2026-10-07-town-odds/tunnels/attrition.md`

**Interfaces:**
- Produces: `excavation.tunnel_attrition` keys `walk_cells`, `eligible`, `rolled_out`, `daylight_gap`, `run_capped`, `bored_cells`, `pruned_cells`; `plan.audit["tunnel_covers"]` (int); spatial audit `maze_released_unborne_crown_cells` (exists).

- [ ] **Step 1: Instrument without changing behaviour**

In `_natural_tunnel_caps`, initialise `excavation.tunnel_attrition = {"walk_cells": 0, "eligible": 0, "rolled_out": 0, "daylight_gap": 0, "run_capped": 0, "bored_cells": 0}` after `excavation.tunnel_cells.clear()`. In the walk loop: increment `walk_cells` per visited `i`; increment `run_capped` when `run >= MAX_TUNNEL_RUN`; increment `eligible` when `bore` is non-empty before the roll check; inside the `run == 0` branch increment `daylight_gap` when `daylight < MIN_DAYLIGHT_RUN` and `rolled_out` when the roll fails. After the loop set `bored_cells = excavation.tunnel_cells.size()`. In `WarrenMazeSitePlanner` pruning (~305) count `tunnel_cells.erase` successes into `excavation.tunnel_attrition["pruned_cells"]` (copy the dict from `old` first at ~276). After `WarrenPlotPlanner.cover_tunnels(source_plan)` store `source_plan.audit["tunnel_covers"] = <returned array>.size()` (assign the call's return value to a local).

- [ ] **Step 2: Fingerprint must match**

Reimport; run the fingerprint compare. Expected: `FINGERPRINT_MATCH` (counters only).

- [ ] **Step 3: Write the harness**

```gdscript
extends SceneTree
## Tunnel attrition per town: eligible run -> bored -> pruned -> covered ->
## released. Prints one TUNNEL_ATTRITION JSON line per town.
func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var towns := "53:grand,31:large,13:standard,43:large,83:grand,103:standard,7:compact,61:standard,5:compact,21:standard,37:large,71:grand"
	for town: String in towns.split(","):
		var parts := town.split(":")
		var spatial := WarrenVolumetricSolver.generate(int(parts[0]), {}, program,
			WarrenVillageScaleProfile.for_id(StringName(parts[1])))
		if spatial == null:
			print("TUNNEL_ATTRITION ", JSON.stringify({"town": town, "error": "no town"}))
			continue
		var source := spatial.source_volume.mass_context.get(&"maze_source_plan") as WarrenMazeSourcePlan
		var row: Dictionary = source.excavation.tunnel_attrition.duplicate()
		row["town"] = town
		row["final_tunnel_cells"] = source.excavation.tunnel_cells.size()
		row["tunnel_covers"] = int(source.audit.get("tunnel_covers", -1))
		row["released_crown_cells"] = int(spatial.audit.get("maze_released_unborne_crown_cells", -1))
		print("TUNNEL_ATTRITION ", JSON.stringify(row))
	quit(0)
```
(If `spatial.audit` is not the member holding `maze_released_unborne_crown_cells`, find it with `grep -n "maze_released_unborne_crown_cells" scripts/terrain/features/villages/fabric/WarrenVolumetricSolver.gd` and read from that plan object.)

- [ ] **Step 4: Run and write the report**

Run the harness to `/tmp/tunnels.out`. Write `docs/qa/2026-10-07-town-odds/tunnels/attrition.md` with a table (one row per town, columns = every counter) and per-size totals, and a short "largest loss" paragraph naming the stage with the biggest drop and the code that causes it (read that code). Do not change generation in this task.

- [ ] **Step 5: Commit and stop for review**

```bash
git add scripts/terrain/features/villages tests/harness/tunnel_attrition.gd docs/qa/2026-10-07-town-odds/tunnels
git commit -m "Diagnostics: tunnel attrition counters and per-town report"
```
The tunnel fix is designed from this report in a follow-up plan (spec "Tunnels" step 2–3).

---

### Task 8: Clearing knobs and site selection (pure)

**Files:**
- Modify: `terrain/villages/town_odds.tres` (add clearing knobs, all defaulting to "off")
- Create: `scripts/terrain/features/villages/fabric/WarrenCourtClearings.gd`
- Test: `tests/test_court_clearings.gd`

**Interfaces:**
- Consumes: `TownCharacter.of`, `WarrenMassif`, `WarrenExcavation`, `WarrenPlotReservations._deck_column_ok`, `WarrenPlotPlanner.blocked_columns`, `WarrenPassageLatticeRules.DIRECTIONS`.
- Produces: `WarrenCourtClearings.propose(world_seed: int, massif: WarrenMassif, excavation: WarrenExcavation, profile: WarrenVillageScaleProfile, thickness: Dictionary) -> Array[Dictionary]` — each `{"cells": Array[Vector2i], "floor": int, "shape": StringName, "purpose": StringName, "cover": StringName}`, deterministic, not yet carved.

Knobs (defaults chosen so `clearing_count` is 0 → no clearings until the owner checkpoint turns it on):

| name | kind | at_small | at_large | spread | min | max | options / weights |
|---|---|---|---|---|---|---|---|
| `clearing_count` | RANGE_INT | 0.0 | 0.0 | 0.0 | 0 | 6 | — (checkpoint value: small 0.25, large 2.5, spread 0.75) |
| `clearing_block_bias` | RANGE_FLOAT | 1.5 | 1.5 | 0.5 | 0 | 4 | — |
| `clearing_ground_weight` | RANGE_FLOAT | 2.0 | 2.0 | 0.0 | 1 | 6 | — |
| `clearing_area` | RANGE_INT | 6.0 | 14.0 | 3.0 | 4 | 24 | — |
| `clearing_shape` | WEIGHTS | — | — | 0.3 | — | — | rect 0.4/0.3, two_rect 0.3/0.35, three_rect 0.1/0.15, blob 0.2/0.2 |
| `clearing_extra_link_chance` | CHANCE | 0.4 | 0.4 | 0.15 | 0 | 1 | — |
| `clearing_cover` | WEIGHTS | — | — | 0.0 | — | — | open 1.0/1.0 (covered variants: later plan) |
| `clearing_purpose` | WEIGHTS | — | — | 0.4 | — | — | green 0.45/0.4, paved 0.3/0.3, market 0.1/0.15, workyard 0.15/0.15 |

- [ ] **Step 1: Add the knobs to the table**

Append one `[sub_resource type="Resource" id="clearing_count"]` block per row (script = TownKnob ext_resource, fields as in the table; `kind` values: CHANCE=0, RANGE_FLOAT=1, RANGE_INT=2, WEIGHTS=3) and list them in `knobs = Array[Resource]([SubResource("clearing_count"), ...])`. Add the TownKnob script as a second ext_resource and bump `load_steps`. Run `test_town_odds.gd::test_builtin_table_compiles_cleanly` → pass.

- [ ] **Step 2: Write the failing tests**

```gdscript
extends GutTest

func _setup(seed_value: int, scale: StringName, count: float) -> Dictionary:
	var profile := WarrenVillageScaleProfile.for_id(scale)
	TownCharacter.attach(profile, TownOddsProgram.builtin().with_overrides({&"clearing_count": count}), seed_value)
	var plan := WarrenMazeSitePlanner.plan(seed_value, {}, profile, &"carve")
	return {"profile": profile, "plan": plan}

func test_default_table_proposes_nothing() -> void:
	var profile := WarrenVillageScaleProfile.for_id(&"large")
	TownCharacter.attach(profile, TownOddsProgram.builtin(), 31)
	var plan := WarrenMazeSitePlanner.plan(31, {}, profile, &"carve")
	assert_eq(WarrenCourtClearings.propose(31, plan.massif, plan.excavation, profile, plan.block_thickness).size(), 0)

func test_proposals_are_deterministic_disjoint_and_wide_enough() -> void:
	var s := _setup(31, &"large", 3.0)
	var plan: WarrenMazeSourcePlan = s.plan
	var first := WarrenCourtClearings.propose(31, plan.massif, plan.excavation, s.profile, plan.block_thickness)
	var second := WarrenCourtClearings.propose(31, plan.massif, plan.excavation, s.profile, plan.block_thickness)
	assert_eq(first, second)
	assert_gt(first.size(), 0)
	var used := {}
	for clearing: Dictionary in first:
		for column: Vector2i in clearing.cells:
			assert_false(used.has(column), "clearings overlap")
			used[column] = true
			var wide := false
			for d: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
				wide = wide or (clearing.cells.has(column + d) and clearing.cells.has(column + d + Vector2i(d.y, d.x)) \
					and clearing.cells.has(column + Vector2i(d.y, d.x)))
			assert_true(wide, "every clearing cell belongs to a 2x2 block")

func test_thick_blocks_are_preferred() -> void:
	var s := _setup(53, &"grand", 4.0)
	var plan: WarrenMazeSourcePlan = s.plan
	var chosen := 0.0
	var count := 0
	for clearing: Dictionary in WarrenCourtClearings.propose(53, plan.massif, plan.excavation, s.profile, plan.block_thickness):
		for column: Vector2i in clearing.cells:
			chosen += float(plan.block_thickness.get(column, 0.0))
			count += 1
	var all := 0.0
	for column: Vector2i in plan.block_thickness:
		all += float(plan.block_thickness[column])
	assert_gt(chosen / maxf(1.0, float(count)), all / float(plan.block_thickness.size()))
```

Before running: check `WarrenMazeSitePlanner.plan`'s `stop_after` values (`grep -n "stop_after ==" scripts/terrain/features/villages/fabric/WarrenMazeSitePlanner.gd`). If there is no stop after carving, use the earliest stop (`&"reserve"`) — `propose` only reads massif, excavation and thickness, which carve has finished by then. Also confirm `block_thickness` is a `WarrenMazeSourcePlan` member (`plan.block_thickness = thickness` in the carver) and that its values are numeric.

- [ ] **Step 3: Run to verify failure** — `WarrenCourtClearings` not found.

- [ ] **Step 4: Implement `WarrenCourtClearings.gd`**

```gdscript
class_name WarrenCourtClearings
extends RefCounted
## Courtyard clearings: open rooms reserved inside the massif while streets
## are bored. Placement is a biased draw, never a rule: thick uncut stone is
## more likely, ground level moderately favoured, size/shape/purpose drawn
## from the town's character. Only guardrails are hard (supported floor,
## minimum width 2, no other reservation, reachable -- checked when carved).

const ATTEMPTS_PER_CLEARING := 24
const SALT_CENTRE := 0x434C4552
const SALT_GROW := 0x47524F57


static func propose(world_seed: int, massif: WarrenMassif, excavation: WarrenExcavation,
		profile: WarrenVillageScaleProfile, thickness: Dictionary) -> Array[Dictionary]:
	var character := TownCharacter.of(profile, world_seed)
	var wanted := character.count(&"clearing_count")
	var out: Array[Dictionary] = []
	if wanted <= 0:
		return out
	var empty := WarrenMazeSourcePlan.new(world_seed, profile, massif, excavation)
	var blocked := WarrenPlotPlanner.blocked_columns(empty)
	var taken := {}
	var public_columns := {}
	for cell: Vector3i in excavation.public_cells():
		public_columns[Vector2i(cell.x, cell.z)] = true
	var candidates := _candidates(massif, thickness, public_columns, blocked, character)
	var attempt := 0
	while out.size() < wanted and attempt < wanted * ATTEMPTS_PER_CLEARING and not candidates.is_empty():
		attempt += 1
		var centre := _weighted_pick(candidates, character.roll(&"clearing_block_bias", Vector2i(attempt, SALT_CENTRE)))
		var floor_band := int(centre.floor)
		var area := character.count(&"clearing_area")
		var shape := character.pick(&"clearing_shape", Vector2i(attempt, out.size()))
		var cells := _grow(empty, centre.column as Vector2i, floor_band, area, shape, blocked, taken, public_columns, character, attempt)
		if cells.size() < 4:
			continue
		for column: Vector2i in cells:
			taken[column] = true
		out.append({"cells": cells, "floor": floor_band, "shape": shape,
			"purpose": character.pick(&"clearing_purpose", Vector2i(out.size(), floor_band)),
			"cover": character.pick(&"clearing_cover", Vector2i(out.size(), floor_band))})
	return out


static func _candidates(massif: WarrenMassif, thickness: Dictionary, public_columns: Dictionary,
		blocked: Dictionary, character: TownCharacter) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var bias := character.value(&"clearing_block_bias")
	var ground := character.value(&"clearing_ground_weight")
	var columns := massif.columns.keys()
	columns.sort_custom(WarrenPlotPlanner.column_less)
	for column: Vector2i in columns:
		if public_columns.has(column) or blocked.has(column):
			continue
		var base := massif.base_at(column)
		var top := massif.top_at(column) - WarrenMazeSourcePlan.MIN_HOUSE_BANDS
		var weight := pow(maxf(0.01, float(thickness.get(column, 0.0))), bias)
		for floor_band in range(base, maxi(base, top) + 1, 2):
			out.append({"column": column, "floor": floor_band,
				"weight": weight * (ground if floor_band == base else 1.0)})
	return out


static func _weighted_pick(candidates: Array[Dictionary], r: float) -> Dictionary:
	var total := 0.0
	for c: Dictionary in candidates:
		total += float(c.weight)
	var target := r * total
	for c: Dictionary in candidates:
		target -= float(c.weight)
		if target < 0.0:
			return c
	return candidates.back()


static func _grow(plan: WarrenMazeSourcePlan, centre: Vector2i, floor_band: int, area: int,
		shape: StringName, blocked: Dictionary, taken: Dictionary, public_columns: Dictionary,
		character: TownCharacter, attempt: int) -> Array[Vector2i]:
	## Union of rectangles (1, 2 or 3; a "blob" adds 2x2 blocks one at a time)
	## around the centre, every member a legal deck column at this floor.
	var rect_count := {&"rect": 1, &"two_rect": 2, &"three_rect": 3}.get(shape, 0)
	var cells: Dictionary = {}
	var pieces := rect_count if rect_count > 0 else area / 4
	for piece in pieces:
		var r := character.roll(&"clearing_area", Vector3i(attempt, piece, SALT_GROW))
		var w := 2 + int(r * 3.0)
		var d := maxi(2, area / maxi(1, pieces) / w)
		var anchor := centre if cells.is_empty() else (cells.keys()[int(r * cells.size()) % cells.size()] as Vector2i)
		var offset := Vector2i(-int(r * float(w)), -int(fposmod(r * 7.0, 1.0) * float(d)))
		var block: Array[Vector2i] = []
		var legal := true
		for x in w:
			for z in d:
				var column := anchor + offset + Vector2i(x, z)
				if cells.has(column):
					continue
				if blocked.has(column) or taken.has(column) or public_columns.has(column) \
						or not plan.massif.has_column(column) \
						or not WarrenPlotReservations._deck_column_ok(plan, column, floor_band, {}, blocked, 6):
					legal = false
					break
				block.append(column)
			if not legal:
				break
		if legal:
			for column: Vector2i in block:
				cells[column] = true
	var out: Array[Vector2i] = []
	out.assign(cells.keys())
	out.sort_custom(WarrenPlotPlanner.column_less)
	return out
```

Verify before running: `WarrenPlotPlanner.column_less` exists (`grep -n "static func column_less" scripts/terrain/features/villages/fabric/WarrenPlotPlanner.gd`), `massif.top_at` exists (used by `WarrenInteriorCourt`), and `_deck_column_ok` has the argument order `(plan, column, floor_band, {}, blocked, 6)` as in `WarrenInteriorCourt.gd:45`.

- [ ] **Step 5: Run tests** — reimport; run `test_court_clearings.gd` (pass) and `test_town_odds.gd` (pass). Run fingerprint compare: `FINGERPRINT_MATCH` (nothing calls `propose` yet).

- [ ] **Step 6: Commit**

```bash
git add terrain/villages/town_odds.tres scripts/terrain/features/villages/fabric/WarrenCourtClearings.gd tests/test_court_clearings.gd
git commit -m "Clearings: knobs (off by default) and biased site selection"
```

---

### Task 9: Carve clearings and connect them

**Files:**
- Modify: `fabric/WarrenCourtClearings.gd` (add `carve(...)`)
- Modify: `fabric/WarrenExcavation.gd` (add `var court_clearings: Array[Dictionary] = []`)
- Modify: `fabric/WarrenMazeCarver.gd` `carve()` — call after the second `_carve_loop_joins`
- Modify: every excavation copy-field list (as in Task 7) to include `court_clearings`
- Test: `tests/test_court_clearings.gd` (extend)

**Interfaces:**
- Consumes: Task 8 `propose`; `WarrenMazeCarver._level_gate_connection(massif, excavation, public: Dictionary, walk_nodes: Dictionary, candidate: Vector3i, bool) -> Dictionary` (returns `{"anchor": Vector3i, "cells": Array[Vector3i]}` or `{}`), `WarrenMazeCarver._walk_nodes(excavation)`.
- Produces: `WarrenCourtClearings.carve(world_seed: int, massif: WarrenMassif, excavation: WarrenExcavation, occupied: Dictionary, profile: WarrenVillageScaleProfile, thickness: Dictionary) -> void`, appending to `excavation.court_clearings` entries `{"cells", "floor", "shape", "purpose", "cover", "door_walk": Vector3i, "links": int}` and adding one lane per link (`feature_kind = &"court_clearing_access"`).

- [ ] **Step 1: Write the failing tests (append)**

```gdscript
func test_carved_clearings_are_reachable_and_reserved() -> void:
	var s := _setup(31, &"large", 3.0)
	var plan: WarrenMazeSourcePlan = s.plan
	assert_gt(plan.excavation.court_clearings.size(), 0)
	var walk := {}
	for cell: Vector3i in WarrenMazeCarver._walk_nodes(plan.excavation):
		walk[cell] = true
	for clearing: Dictionary in plan.excavation.court_clearings:
		assert_true(walk.has(clearing.door_walk), "door is a walk node")
		var touches := false
		for column: Vector2i in clearing.cells:
			touches = touches or absi(column.x - clearing.door_walk.x) + absi(column.y - clearing.door_walk.z) == 1
			for band in range(int(clearing.floor) - 1, int(clearing.floor) + WarrenMazeSourcePlan.MIN_HOUSE_BANDS):
				assert_true(plan.excavation.construction_reservations.has(Vector3i(column.x, band, column.y)))
		assert_true(touches, "door is beside the clearing")
		assert_gte(int(clearing.links), 1)

func test_unconnectable_clearing_leaves_no_trace() -> void:
	var s := _setup(31, &"large", 3.0)
	var plan: WarrenMazeSourcePlan = s.plan
	var lanes := plan.excavation.lanes.filter(func(l: Dictionary) -> bool:
		return l.get("feature_kind", &"") == &"court_clearing_access")
	var clearing_doors := {}
	for clearing: Dictionary in plan.excavation.court_clearings:
		clearing_doors[clearing.door_walk] = true
	for lane: Dictionary in lanes:
		assert_true(clearing_doors.has((lane.cells as Array).back()) or clearing_doors.has(lane.anchor),
			"every clearing lane serves a kept clearing")

func test_default_fingerprint_unchanged_is_checked_by_harness() -> void:
	var profile := WarrenVillageScaleProfile.for_id(&"large")
	TownCharacter.attach(profile, TownOddsProgram.builtin(), 31)
	var plan := WarrenMazeSitePlanner.plan(31, {}, profile, &"carve")
	assert_eq(plan.excavation.court_clearings.size(), 0)
```

- [ ] **Step 2: Run to verify failure.**

- [ ] **Step 3: Implement `carve`**

```gdscript
static func carve(world_seed: int, massif: WarrenMassif, excavation: WarrenExcavation,
		occupied: Dictionary, profile: WarrenVillageScaleProfile, thickness: Dictionary) -> void:
	var character := TownCharacter.of(profile, world_seed)
	for proposal: Dictionary in propose(world_seed, massif, excavation, profile, thickness):
		var floor_band := int(proposal.floor)
		var public := {}
		for cell: Vector3i in excavation.public_cells():
			public[cell] = true
		var walk_nodes := {}
		for cell: Vector3i in WarrenMazeCarver._walk_nodes(excavation):
			walk_nodes[cell] = true
		var doorsteps: Array[Vector3i] = []
		for column: Vector2i in proposal.cells:
			for d: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
				var next := column + d
				if (proposal.cells as Array).has(next) or not massif.has_column(next):
					continue
				var step := Vector3i(next.x, floor_band, next.y)
				if not doorsteps.has(step):
					doorsteps.append(step)
		doorsteps.sort_custom(WarrenExcavation._cell_less)
		var connections: Array[Dictionary] = []
		for step: Vector3i in doorsteps:
			var connection: Dictionary = {"anchor": step, "cells": [] as Array[Vector3i]} \
				if walk_nodes.has(step) \
				else WarrenMazeCarver._level_gate_connection(massif, excavation, public, walk_nodes, step, true)
			if connection.is_empty():
				continue
			connections.append(connection)
		if connections.is_empty():
			continue  # guardrail: an unreachable clearing is withdrawn whole
		connections.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return (a.cells as Array).size() < (b.cells as Array).size())
		var chosen: Array[Dictionary] = [connections[0]]
		for i in range(1, connections.size()):
			var far_enough := true
			for c: Dictionary in chosen:
				var a: Vector3i = c.anchor
				var b: Vector3i = connections[i].anchor
				far_enough = far_enough and absi(a.x - b.x) + absi(a.z - b.z) > 3
			if far_enough and character.chance(&"clearing_extra_link_chance", Vector3i(i, floor_band, excavation.court_clearings.size())):
				chosen.append(connections[i])
		var door: Vector3i = Vector3i.ZERO
		for connection: Dictionary in chosen:
			var cells: Array[Vector3i] = connection.cells
			var previous: Vector3i = connection.anchor
			var transitions: Array[Dictionary] = []
			for cell: Vector3i in cells:
				transitions.append({"from": previous, "to": cell, "kind": WarrenVolumeTransition.Kind.LEVEL})
				occupied[cell] = true
				for band in range(cell.y, cell.y + WarrenPassageLatticeRules.HEADROOM_BANDS):
					excavation.carved[Vector3i(cell.x, band, cell.z)] = true
				previous = cell
			if not cells.is_empty():
				excavation.lanes.append({"anchor": connection.anchor, "cells": cells,
					"transitions": transitions, "feature_kind": &"court_clearing_access"})
			if door == Vector3i.ZERO:
				door = previous
		for column: Vector2i in proposal.cells:
			for band in range(floor_band - 1, floor_band + WarrenMazeSourcePlan.MIN_HOUSE_BANDS):
				excavation.construction_reservations[Vector3i(column.x, band, column.y)] = true
		var record := proposal.duplicate()
		record["door_walk"] = door
		record["links"] = chosen.size()
		excavation.court_clearings.append(record)
```

The lane's last cell is the doorstep; when the doorstep is already a walk node, `door = connection.anchor` (cells empty → `previous` stays the anchor). Verify `_level_gate_connection` returns its path ending at the requested candidate (read it: `grep -n "static func _level_gate_connection" -A40 scripts/terrain/features/villages/fabric/WarrenMazeCarver.gd`); if the path is ordered from candidate toward the network instead, reverse `cells` and swap anchor/endpoint so the lane hangs off the public realm (the excavation validator `_lanes_hang_off_the_public_realm` requires the anchor to be public).

- [ ] **Step 4: Call it from the carver and persist the field**

In `WarrenMazeCarver.carve`, directly after the second `_carve_loop_joins(...)` call and before `var secondary_gates := _carve_secondary_gate_lanes(...)`, insert:

```gdscript
	WarrenCourtClearings.carve(world_seed, massif, excavation, occupied, profile, thickness)
```
Add `court_clearings` to `WarrenExcavation` (`var court_clearings: Array[Dictionary] = []`) and to every copy-field list from Task 7 so pruning/rebuilds keep it. In `WarrenMazeSitePlanner` pruning (~298-310), drop a clearing whose `door_walk` was removed and erase its reservations (iterate `excavation.court_clearings`, keep those whose door is still public).

- [ ] **Step 5: Run tests and fingerprints**

Reimport; run `test_court_clearings.gd` (pass) and fingerprint compare (`FINGERPRINT_MATCH` — default count 0). Then run the fingerprint harness with `--odds clearing_count=3 --towns 31:large,53:grand,13:standard,103:standard --out /tmp/fp-clear.json` and confirm every town still builds (no `FINGERPRINT_NO_TOWN`); record per-town clearing counts printed by adding `print("CLEARINGS ", town, " ", source.excavation.court_clearings.size())` in the harness.

- [ ] **Step 6: Commit**

```bash
git add scripts/terrain/features/villages tests/test_court_clearings.gd tests/harness/town_fingerprint.gd
git commit -m "Clearings: carve after alleys, connect to nearest streets with extra links by odds"
```

---

### Task 10: Realise clearings as courts (decks, green purpose)

**Files:**
- Modify: `fabric/WarrenPlotReservations.gd` (`reserve`: place clearings before the plaza; add `is_green_court(plot)`)
- Modify: `fabric/WarrenVolumetricSolver.gd:~2533` and `fabric/WarrenSpatialFabricCompiler.gd:~143` (use `is_green_court`)
- Test: `tests/test_court_clearings.gd` (extend)

**Interfaces:**
- Consumes: `excavation.court_clearings` (Task 9).
- Produces: deck plots with ids `clearing.NN`, `"purpose"` key; `WarrenPlotReservations.is_green_court(plot: Dictionary) -> bool` (true for `PLAZA_PLOT_ID` or `plot.get("purpose") == &"green"`); outcomes `clearings: Array[Dictionary]` (`{"id", "size", "floor", "reason"}`).

- [ ] **Step 1: Write the failing tests (append)**

```gdscript
func test_clearings_become_court_plots_and_greens_are_lawns() -> void:
	var profile := WarrenVillageScaleProfile.for_id(&"large")
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	program.town_odds = program.town_odds.with_overrides({&"clearing_count": 3.0})
	var spatial := WarrenVolumetricSolver.generate(31, {}, program, profile)
	assert_not_null(spatial)
	var source := spatial.source_volume.mass_context.get(&"maze_source_plan") as WarrenMazeSourcePlan
	var courts := source.plots.filter(func(p: Dictionary) -> bool: return String(p.id).begins_with("clearing."))
	assert_eq(courts.size(), source.excavation.court_clearings.size())
	for plot: Dictionary in courts:
		assert_eq(plot.kind, WarrenMazeSourcePlan.PLOT_DECK)
		assert_eq(WarrenPlotReservations.is_green_court(plot), plot.purpose == &"green")

func test_plaza_is_still_green() -> void:
	assert_true(WarrenPlotReservations.is_green_court({"id": WarrenPlotReservations.PLAZA_PLOT_ID}))
	assert_false(WarrenPlotReservations.is_green_court({"id": &"deck.00"}))
```

- [ ] **Step 2: Run to verify failure.**

- [ ] **Step 3: Implement**

In `WarrenPlotReservations.gd` add:

```gdscript
static func is_green_court(plot: Dictionary) -> bool:
	## Lawn courts: the primary plaza, and any clearing whose drawn purpose is
	## a green. Everything else renders as a paved/timber court.
	return StringName(plot.get("id", &"")) == PLAZA_PLOT_ID \
		or StringName(plot.get("purpose", &"")) == &"green"


static func _place_clearings(plan: WarrenMazeSourcePlan, blocked: Dictionary,
		outcomes: Dictionary) -> void:
	var records: Array[Dictionary] = []
	for index in plan.excavation.court_clearings.size():
		var clearing: Dictionary = plan.excavation.court_clearings[index]
		var id := StringName("clearing.%02d" % index)
		var cells: Array[Vector2i] = []
		cells.assign(clearing.cells)
		var record := {"id": id, "size": cells.size(), "floor": int(clearing.floor), "reason": ""}
		if plan.add_plot({"id": id, "kind": WarrenMazeSourcePlan.PLOT_DECK, "cells": cells,
				"floor": int(clearing.floor), "top": int(clearing.floor),
				"door_walk": clearing.door_walk as Vector3i, "building_id": id,
				"purpose": StringName(clearing.purpose)}):
			for column: Vector2i in cells:
				blocked[column] = true
		else:
			record["reason"] = plan.last_rejection
		records.append(record)
	outcomes["clearings"] = records
```

Check `add_plot` keeps unknown keys (`purpose`): read `WarrenMazeSourcePlan.add_plot` (~294-330). If it copies a fixed key set, add `"purpose": plot.get("purpose", &"")` to the stored dictionary.

In `reserve()`, after `blocked` is first built (after the `house_site` loop, before `var plaza := 0`), call `_place_clearings(plan, blocked, outcomes)`. After the later `blocked = WarrenPlotPlanner.blocked_columns(plan)` rebuild, re-merge clearing columns: `for plot in plan.plots: if String(plot.id).begins_with("clearing."): for column in plot.cells: blocked[column] = true`.

Replace the two `PLAZA_PLOT_ID` id checks in `WarrenVolumetricSolver._maze_court_planting_cells` (~2533) and `WarrenSpatialFabricCompiler` (~143) with `not WarrenPlotReservations.is_green_court(plot)` (preserving each `continue` logic).

- [ ] **Step 4: Run tests and fingerprints**

Reimport; run `test_court_clearings.gd` (pass), `test_warren_maze_plots.gd`, `test_garden_bearing_cap.gd` (pass), fingerprint compare (`FINGERPRINT_MATCH` at default).

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/features/villages/fabric tests/test_court_clearings.gd
git commit -m "Clearings: realised as court decks; green clearings render as lawns"
```

---

### Task 11: Clearing evidence and owner checkpoint

**Files:**
- Create: `docs/qa/2026-10-07-town-odds/clearings/result.md` and images/logs beside it

- [ ] **Step 1: Renders with and without clearings**

For each evidence town and both holdouts, render twice with `kit_town_review.gd` (`--views overview,orbit,courtyard,street --garden-grass`), once with defaults and once with `--odds clearing_count=2.5` for large/grand and `--odds clearing_count=1` for compact/standard. Output to `docs/qa/2026-10-07-town-odds/clearings/{off,on}/`.

- [ ] **Step 2: Audits**

Copy the production audit script (Task 6 Step 6) to `tests/harness/_odds_audit.gd`, add `--odds` parsing exactly as in Task 4 Step 7, run it with the clearing override across all eight towns, delete the copy. Required: every town builds, `valid_payload: true`, `floating: 0`, `intrusions: 0`.

- [ ] **Step 3: Player walks**

Copy `docs/qa/2026-10-01-town-redesign/prefab-grammar/october6-integrated-checkpoint/handoff-support/oct6-preview-court-walk.gd` to `tests/harness/_court_walk.gd`, add the same `--odds` override block where it compiles its program, and run `--seed 31 --profile large --courts --odds clearing_count=2.5` and `--seed 53 --profile grand --courts --odds clearing_count=2.5`. Required: every `TOWN_ROUTE_WALK` line `passed=true` (clearing decks are deck plots, so the script's `--courts` mode includes them; confirm by the court ids printed), PublicWalkAudit 0 dead ends. Delete the copy.

- [ ] **Step 4: Measure blocks**

Report largest house plot (columns) and median plot size per town, off vs on (from `source.plots` where `kind == PLOT_HOUSE`), plus clearings per town and their floors (ground vs raised).

- [ ] **Step 5: Write result.md, commit, stop for the owner**

`result.md`: commands, tables (Step 2, 4), walk results, inspected images with notes (what improved, what looks wrong), known limits (covered variants not yet built). Commit:

```bash
git add docs/qa/2026-10-07-town-odds/clearings
git commit -m "QA: courtyard clearings evidence (off vs on) for owner checkpoint"
```

Owner checkpoint: the owner re-judges large blocks with and without clearings and chooses the default `clearing_count` curve; the default is only changed after that decision.
