# Constructive Maze — Slice 1: Source-Side Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the editable-ledger source pipeline — reservation pass, global largest-first stamping with bounded edits, foundations by construction, translator partition — so every corpus seed produces real building-shaped parcels (no pencil towers) with ≥ 0.85 solid ownership, entirely at the source-plan level.

**Architecture:** All phases mutate one unsealed `WarrenMazeSourcePlan` through a new plain-data edit ledger, then seal once. The massif and natural terrain stay immutable; edits overlay them. `WarrenMazeBlockPartitioner` becomes a 1:1 translator of stamped claims. Composition consumption (slice 2), real-terrain sites (slice 3), and deletion of the searched pipeline (slice 4) are separate follow-up plans.

**Tech Stack:** Godot 4.5 / GDScript, GUT.

**Spec:** `docs/superpowers/specs/2026-08-20-constructive-maze-town-design.md` (approved 2026-08-20). Read it before starting any task.

## Global Constraints

- The source plan owns **plain lattice data only** — no Nodes, meshes, or server resources anywhere in these passes.
- Natural terrain is immutable: every `floor_band` ≥ the terrain sample; `foundation_base` *is* the terrain sample. Streets (carved passage cells) are never edited after the bore.
- Determinism: pure function of `(city_seed, ground_bands, scale_profile)`; no dictionary-iteration order may leak (sort keys before iterating where order matters); `deterministic_signature()` must cover ledger, claims, and reservations.
- P3 edits: reservation patch + 1-column apron only. P4 edits: own footprint + 1-column apron, at most ±1 band from the pre-edit surface.
- New rules discovered during implementation go into `seal()` validation and tests — never new runtime rejection paths (spec: "rules become repairs").
- Run any single test file with:
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryko/story -s addons/gut/gut_cmdln.gd -gtest=res://tests/<file>.gd -gexit`
- Slice-1 exit (from the spec, source-level only): 24/24 seed×scale flat matrix reaches a sealed source + translated parcels; median parcel footprint ≥ 4 columns; zero 1×1 claims above 2 storeys; `maze_owned_solid_ratio ≥ 0.85`; signature stable. Composition is *expected to still fail* until slice 2.

## File Structure

| File | Responsibility |
|---|---|
| `scripts/terrain/features/villages/fabric/WarrenMazeSourcePlan.gd` | Gains the edit ledger, claims, reservations, accessors, seal validation, signature coverage (Task 1). |
| `scripts/terrain/features/villages/fabric/WarrenMazeCarver.gd` | Gains `seal_plan` parameter so phases can run pre-seal (Task 2). |
| `scripts/terrain/features/villages/fabric/WarrenMazeReservationPass.gd` | New: P3 registry + fit→edit→shrink→move→skip (Task 3). |
| `scripts/terrain/features/villages/fabric/WarrenMazeStampPass.gd` | New: P4 global largest-first stamping + P5 foundations (Tasks 4–5). |
| `scripts/terrain/features/villages/fabric/WarrenMazeSitePlanner.gd` | New: orchestrator P0→P5→seal (Task 6). |
| `scripts/terrain/features/villages/fabric/WarrenMazeVolumeAdapter.gd` | Applies ledger overlays when building the volume (Task 7). |
| `scripts/terrain/features/villages/fabric/WarrenMazeBlockPartitioner.gd` | Translator mode: claims → sealed parcels, 1:1 (Task 7). |
| `tests/test_warren_maze_constructive.gd` | New test file for all slice-1 behaviour. |
| `tests/harness/maze_source_review.gd` | Becomes the constructive geometry debug view (Task 8). |
| `tests/harness/warren_maze_mode_sweep.gd` | Gains `--constructive` to report slice-1 exit metrics (Task 9). |

After creating each new `class_name` script, run
`/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryko/story --import`
once so the headless runner can resolve it (project convention).

---

### Task 1: Edit ledger, claims, and reservations on the source plan

**Files:**
- Modify: `scripts/terrain/features/villages/fabric/WarrenMazeSourcePlan.gd`
- Test: `tests/test_warren_maze_constructive.gd` (create)

**Interfaces:**
- Produces (consumed by every later task):
  - `var column_edits: Dictionary` — `Vector2i → {floor_band: int, top_band: int, phase: StringName}`
  - `var parcel_claims: Array[Dictionary]` — `{footprint: Array[Vector2i], floor_band: int, top_band: int, door_walk: Vector3i, door_column: Vector2i, frontage: Vector2i, lineage_hint: StringName, shape_id: StringName}`
  - `var reservations: Array[Dictionary]` — `{kind: StringName, cells: Array[Vector2i], datum_band: int, walk_cells: Array[Vector3i], audit: Dictionary}`
  - `func effective_base(column: Vector2i) -> int` (ledger floor, else `massif.base_at`)
  - `func effective_top(column: Vector2i) -> int` (ledger top, else `massif.top_at`)
  - `func foundation_depth(column: Vector2i) -> int` (`floor_band − massif.base_at(column)`, ≥ 0)
  - `func record_edit(column, floor_band, top_band, phase) -> bool` (false + `last_rejection` when it would touch a carved passage cell or sink below terrain)

- [ ] **Step 1: Write the failing tests**

```gdscript
extends GutTest


func _sealed_fixture() -> WarrenMazeSourcePlan:
	var profile := WarrenVillageScaleProfile.for_id(&"compact")
	var massif := WarrenMassifBuilder.build(12, {}, profile)
	return WarrenMazeCarver.carve(12, massif, profile)


func test_edit_ledger_overlays_the_sealed_massif() -> void:
	var plan := _sealed_fixture()
	assert_not_null(plan, WarrenMazeCarver.last_failure)
	var column: Vector2i = plan.massif.columns.keys()[0]
	var base := plan.massif.base_at(column)
	assert_eq(plan.effective_base(column), base,
		"no edit means the massif value shows through")
	assert_true(plan.record_edit(column, base + 1,
		plan.massif.top_at(column), &"reserve"))
	assert_eq(plan.effective_base(column), base + 1)
	assert_eq(plan.foundation_depth(column), 1,
		"a raised floor is a one-band rock foundation")


func test_edits_may_never_sink_below_terrain_or_touch_streets() -> void:
	var plan := _sealed_fixture()
	var column: Vector2i = plan.massif.columns.keys()[0]
	assert_false(plan.record_edit(column,
		plan.massif.base_at(column) - 1, plan.massif.top_at(column),
		&"reserve"), "terrain is the immutable floor")
	var street := plan.passage_cells()[0]
	assert_false(plan.record_edit(Vector2i(street.x, street.z),
		street.y + 1, street.y + 4, &"reserve"),
		"carved streets are immutable after the bore")


func test_signature_covers_ledger_claims_and_reservations() -> void:
	var first := _sealed_fixture()
	var second := _sealed_fixture()
	assert_eq(first.deterministic_signature(),
		second.deterministic_signature())
	var column: Vector2i = second.massif.columns.keys()[0]
	second.record_edit(column, second.massif.base_at(column) + 1,
		second.massif.top_at(column), &"reserve")
	assert_ne(first.deterministic_signature(),
		second.deterministic_signature(),
		"an edit must change the sealed identity")
```

Note: `record_edit` on an already-sealed fixture must work for these tests —
sealing freezes edits via a `seal()` re-validation, and `record_edit` itself
returns false after seal. Add that check first in `record_edit`, and use the
carver's unsealed mode from Task 2 once it exists; until then the first two
tests exercise the pre-seal path by constructing the plan without carving
(`WarrenMazeSourcePlan.new(...)` per its `_init`). Read the `_init` and adapt
the fixture accordingly — the assertion targets, not the fixture, are the
contract.

- [ ] **Step 2: Run to verify failure** — expected: `record_edit` not found.
- [ ] **Step 3: Implement** the three fields, four accessors, and `record_edit` with the passage/terrain/sealed guards; extend `seal()` to validate all ledger invariants (sorted iteration) and `deterministic_signature()` to append `e:x,z:floor,top`, `c:<claim fields>`, `r:<kind,cells>` lines in sorted order.
- [ ] **Step 4: Run to verify pass**, then run `tests/test_warren_maze_carver.gd` — all 7 must still pass (no behaviour change without edits).
- [ ] **Step 5: Commit** — `feat(villages): maze source plan gains the constructive edit ledger`

---

### Task 2: Unsealed carve mode

**Files:**
- Modify: `scripts/terrain/features/villages/fabric/WarrenMazeCarver.gd` (the `plan.seal()` call near line 122)
- Test: `tests/test_warren_maze_constructive.gd`

**Interfaces:**
- Produces: `WarrenMazeCarver.carve(world_seed, massif, profile, seal_plan := true)` — default preserves every existing caller and test; `false` returns the constructed, validated-but-unsealed plan for the phase pipeline.

- [ ] **Step 1: Failing test**

```gdscript
func test_carve_can_return_an_unsealed_plan_for_the_phase_pipeline() -> void:
	var profile := WarrenVillageScaleProfile.for_id(&"compact")
	var massif := WarrenMassifBuilder.build(12, {}, profile)
	var plan := WarrenMazeCarver.carve(12, massif, profile, false)
	assert_not_null(plan, WarrenMazeCarver.last_failure)
	assert_false(plan.is_sealed())
	assert_true(plan.seal(), plan.last_rejection)
	var sealed := WarrenMazeCarver.carve(12, massif, profile)
	assert_eq(plan.deterministic_signature(),
		sealed.deterministic_signature(),
		"deferred seal must not change what was carved")
```

- [ ] **Step 2: Run to verify failure.**
- [ ] **Step 3: Implement** the parameter; when `seal_plan` is false, skip only the `plan.seal()` call (the excavation still seals).
- [ ] **Step 4: Run new + existing carver tests.**
- [ ] **Step 5: Commit** — `feat(villages): carver supports deferred seal for constructive phases`

---

### Task 3: Reservation pass (P3)

**Files:**
- Create: `scripts/terrain/features/villages/fabric/WarrenMazeReservationPass.gd`
- Test: `tests/test_warren_maze_constructive.gd`

**Interfaces:**
- Produces: `WarrenMazeReservationPass.reserve(plan: WarrenMazeSourcePlan, profile: WarrenVillageScaleProfile) -> bool` (false only on contract violation; feature shortfalls are audit facts). Registry constant:

```gdscript
const REGISTRY: Array[Dictionary] = [
	{"kind": &"courtyard", "optional": false, "quota": {"compact": Vector2i(0, 1),
		"standard": Vector2i(1, 1), "large": Vector2i(1, 2),
		"grand": Vector2i(1, 2)}, "patch": Vector2i(2, 2),
		"edit": &"sink_to_terrain"},
	{"kind": &"large_house", "optional": false, "quota": {"compact": Vector2i(0, 1),
		"standard": Vector2i(1, 2), "large": Vector2i(2, 3),
		"grand": Vector2i(2, 4)}, "patch": Vector2i(3, 2),
		"edit": &"level_to_datum"},
	{"kind": &"landmark_plot", "optional": true, "quota": {"compact": Vector2i(0, 1),
		"standard": Vector2i(0, 1), "large": Vector2i(1, 2),
		"grand": Vector2i(1, 2)}, "patch": Vector2i(3, 3),
		"edit": &"level_to_datum"},
	{"kind": &"skywalk_span", "optional": true, "quota": {"compact": Vector2i(0, 1),
		"standard": Vector2i(1, 2), "large": Vector2i(2, 3),
		"grand": Vector2i(3, 4)}, "patch": Vector2i.ZERO,
		"edit": &"claim_overhead"},
	{"kind": &"garden_terrace", "optional": true, "quota": {"compact": Vector2i(0, 1),
		"standard": Vector2i(0, 1), "large": Vector2i(0, 2),
		"grand": Vector2i(0, 2)}, "patch": Vector2i(2, 1),
		"edit": &"level_to_datum"},
]
```

Per feature: seeded quota roll inside the range (`Helper._mix64(world_seed ^ kind.hash())`), seeded optional-subset selection, candidate patches enumerated adjacent to passage cells (courtyards/gardens also against the massif rim), ladder `fit → edit → shrink (patch minus one column) → move (next candidate) → skip`, every outcome appended to `plan.audit["reservation_outcomes"]` with a reason code. `sink_to_terrain` lowers built mass to the terrain sample (`record_edit(column, massif.base_at(column), massif.base_at(column), &"reserve")` semantics — floor at terrain, no built top); `level_to_datum` picks the patch's majority pre-edit base as datum and records edits; `claim_overhead` selects a retained-overhead passage span from P2 (a passage cell whose column still has mass above it) and records it with its two flanking solid columns as `walk_cells` + endpoint columns.

- [ ] **Step 1: Failing tests** — three: (a) every non-optional kind lands ≥ its quota minimum on seed 12 compact or records a reason-coded skip; (b) all edits carry `phase == &"reserve"` and touch no passage column; (c) two different seeds select different optional subsets somewhere across seeds 1–12 (variation is real).

```gdscript
func test_reservation_pass_lands_features_with_reason_codes() -> void:
	var profile := WarrenVillageScaleProfile.for_id(&"compact")
	var massif := WarrenMassifBuilder.build(12, {}, profile)
	var plan := WarrenMazeCarver.carve(12, massif, profile, false)
	assert_true(WarrenMazeReservationPass.reserve(plan, profile),
		WarrenMazeReservationPass.last_failure)
	var outcomes := plan.audit.get("reservation_outcomes", []) as Array
	assert_gt(outcomes.size(), 0)
	for outcome: Dictionary in outcomes:
		assert_true(outcome.has("kind") and outcome.has("result"))
	for reservation: Dictionary in plan.reservations:
		for cell: Vector2i in reservation.cells:
			for passage: Vector3i in plan.passage_cells():
				assert_ne(cell, Vector2i(passage.x, passage.z),
					"reservations never claim street columns")
```

- [ ] **Step 2: Run to verify failure.**
- [ ] **Step 3: Implement** (class above; sort candidate lists before seeded selection).
- [ ] **Step 4: Run; then `--import`; then the carver suite.**
- [ ] **Step 5: Commit** — `feat(villages): reservation pass with registry, edits, and seeded variation`

---

### Task 4: Global largest-first stamping (P4)

**Files:**
- Create: `scripts/terrain/features/villages/fabric/WarrenMazeStampPass.gd`
- Test: `tests/test_warren_maze_constructive.gd`

**Interfaces:**
- Produces: `WarrenMazeStampPass.stamp(plan: WarrenMazeSourcePlan, profile: WarrenVillageScaleProfile) -> bool`, filling `plan.parcel_claims`. Shape menu (width × depth in door-frontage frame): `2x3, 2x2, L(2x2+1x2), 1x2, 2x1, 1x1`; the L emits **two claims** sharing one `lineage_hint`.
- Reuses `WarrenMazeBlockPartitioner._frontage_faces` for candidate doors (imported, not duplicated).

Algorithm (all deterministic):
1. Enumerate `(face, shape)` pairs town-wide, skipping columns claimed by reservations.
2. Score = `area * 10000 + neighbor_contact * 400 − step_edit_cost * 50 + hash tie`; sort desc.
3. For each candidate in order: if all columns free and same effective base → claim. Else if a majority datum exists and every offender is within ±1 band → `record_edit` the offenders (`phase = &"stamp"`, footprint + 1-column apron rule enforced by `record_edit` caller), then claim. Else skip.
4. Infill pass: repeat with shapes ≤ 2 columns for remaining unclaimed frontage.
5. Forbid 1×1 claims taller than 2 storeys: clamp `top_band = floor_band + 2 * WarrenBuildingParcel.STOREY_BANDS` for 1×1.

- [ ] **Step 1: Failing tests**

```gdscript
func test_stamping_produces_building_shaped_claims_not_pencils() -> void:
	for city_seed: int in [1, 3, 4, 12]:
		var profile := WarrenVillageScaleProfile.for_id(&"compact")
		var massif := WarrenMassifBuilder.build(city_seed, {}, profile)
		var plan := WarrenMazeCarver.carve(city_seed, massif, profile, false)
		if plan == null:
			continue
		assert_true(WarrenMazeReservationPass.reserve(plan, profile))
		assert_true(WarrenMazeStampPass.stamp(plan, profile),
			WarrenMazeStampPass.last_failure)
		var sizes: Array[int] = []
		for claim: Dictionary in plan.parcel_claims:
			var footprint := claim.footprint as Array[Vector2i]
			sizes.append(footprint.size())
			if footprint.size() == 1:
				assert_lte(int(claim.top_band) - int(claim.floor_band),
					2 * WarrenBuildingParcel.STOREY_BANDS,
					"a 1x1 claim may not become a pencil tower")
		sizes.sort()
		assert_gte(sizes[sizes.size() / 2], 4,
			"seed %d: median footprint must be building-shaped" % city_seed)


func test_stamp_edits_stay_within_one_band_and_own_apron() -> void:
	var profile := WarrenVillageScaleProfile.for_id(&"compact")
	var massif := WarrenMassifBuilder.build(12, {}, profile)
	var plan := WarrenMazeCarver.carve(12, massif, profile, false)
	WarrenMazeReservationPass.reserve(plan, profile)
	WarrenMazeStampPass.stamp(plan, profile)
	for column_value: Variant in plan.column_edits.keys():
		var column := column_value as Vector2i
		var edit := plan.column_edits[column] as Dictionary
		if StringName(edit.phase) != &"stamp":
			continue
		assert_lte(absi(int(edit.floor_band) - plan.massif.base_at(column)), 1,
			"stamp edits move at most one band")
```

- [ ] **Step 2: Run to verify failure.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run; carver suite; commit** — `feat(villages): global largest-first stamping with bounded terrace edits`

---

### Task 5: Foundations by construction (P5)

**Files:**
- Modify: `scripts/terrain/features/villages/fabric/WarrenMazeStampPass.gd` (add `derive_foundations(plan) -> void` called after infill)
- Test: `tests/test_warren_maze_constructive.gd`

**Interfaces:**
- Produces: `plan.audit["foundation_columns"]: Dictionary` — `Vector2i → depth_bands` for every claimed/reserved column where `floor_band > massif.base_at`; consumed by the adapter (Task 7) and, in slice 2, by the fabric's retained-foundation machinery.

- [ ] **Step 1: Failing test** — build seed 12 with a synthetic sloped `ground_bands` (e.g. `{}` replaced by a dictionary sloping +1 band per 4 columns east; construct it in the test from the massif footprint), run reserve+stamp+derive, assert every claimed column satisfies `effective_base >= terrain` and every column with `floor_band > terrain` appears in `foundation_columns` with the right depth.
- [ ] **Step 2–4: Red, implement, green** (foundations are a pure derivation — no new rejection paths).
- [ ] **Step 5: Commit** — `feat(villages): foundations derived from datum minus terrain, never checked`

---

### Task 6: The site planner orchestrator

**Files:**
- Create: `scripts/terrain/features/villages/fabric/WarrenMazeSitePlanner.gd`
- Test: `tests/test_warren_maze_constructive.gd`

**Interfaces:**
- Produces: `WarrenMazeSitePlanner.plan(world_seed: int, ground_bands: Dictionary, profile: WarrenVillageScaleProfile, stop_after: StringName = &"") -> WarrenMazeSourcePlan` — massif → carve(unsealed) → reserve → stamp → foundations → `seal()`; null + `last_failure` on any hard failure.
- `stop_after` returns the **unsealed** plan mid-pipeline for the debug view: `&"carve"` (after bore + air), `&"reserve"`, `&"stamp"`; empty runs to the sealed end. Phases are pure and cost milliseconds, so the debug view re-runs the planner per phase instead of the planner keeping snapshot state.

- [ ] **Step 1: Failing test** — 24/24: for seeds 1–12 × {compact, standard}, `plan(...)` returns a **sealed** plan (or the specific carve/adapt failures already known — assert the count of successes ≥ 22 and every failure names carve/adapter, never reserve/stamp/seal), and the signature is identical across two calls. Plus the phase contract:

```gdscript
func test_stop_after_exposes_each_phase_uncontaminated() -> void:
	var profile := WarrenVillageScaleProfile.for_id(&"compact")
	var carved := WarrenMazeSitePlanner.plan(12, {}, profile, &"carve")
	assert_false(carved.is_sealed())
	assert_eq(carved.reservations.size(), 0)
	assert_eq(carved.parcel_claims.size(), 0)
	var reserved := WarrenMazeSitePlanner.plan(12, {}, profile, &"reserve")
	assert_gt(reserved.reservations.size(), 0)
	assert_eq(reserved.parcel_claims.size(), 0,
		"reserve must not have stamped anything yet")
	var stamped := WarrenMazeSitePlanner.plan(12, {}, profile, &"stamp")
	assert_gt(stamped.parcel_claims.size(), 0)
```
- [ ] **Step 2–4: Red, implement, green.**
- [ ] **Step 5: Commit** — `feat(villages): one-pass constructive site planner`

---

### Task 7: Ledger-aware adapter and translator partition

**Files:**
- Modify: `scripts/terrain/features/villages/fabric/WarrenMazeVolumeAdapter.gd`
- Modify: `scripts/terrain/features/villages/fabric/WarrenMazeBlockPartitioner.gd`
- Test: `tests/test_warren_maze_constructive.gd`

**Interfaces:**
- Adapter: when `source.column_edits` is non-empty, build the volume from an **edited massif copy** (duplicate `columns`, apply `effective_base/effective_top`, re-seal the copy) so downstream sees the edited world. Read `WarrenMassif`'s constructor first and add a `WarrenMassif.with_columns(world_seed, columns, core_top_bands)` factory if none fits.
- Partitioner: when `source.parcel_claims` is non-empty, **translate** — one sealed `WarrenBuildingParcel` per claim via the existing constructor `(stable_id, footprint, floor_band, top_band, door_walk, door_column, frontage, door_phase)`, choosing `door_phase` by trying 0 then 1 against `WarrenParcelConstruction.door_serves_address`; no shapes menu, no scoring, no claiming loop. Legacy greedy path remains only for empty claims (deleted in slice 4).

- [ ] **Step 1: Failing test**

```gdscript
func test_translator_partition_is_one_to_one_with_claims() -> void:
	var profile := WarrenVillageScaleProfile.for_id(&"compact")
	var plan := WarrenMazeSitePlanner.plan(12, {}, profile)
	assert_not_null(plan, WarrenMazeSitePlanner.last_failure)
	var volume := WarrenMazeVolumeAdapter.to_volume_plan(plan)
	assert_not_null(volume, WarrenMazeVolumeAdapter.last_failure)
	var parcels := WarrenMazeBlockPartitioner.partition(plan, volume)
	assert_not_null(parcels, WarrenMazeBlockPartitioner.last_failure)
	assert_eq(parcels.parcels.size(), plan.parcel_claims.size(),
		"translation is 1:1 — a dropped claim is a generator bug")
	assert_gte(float(parcels.audit.get("maze_owned_solid_ratio", 0.0)), 0.85,
		"the M4 ownership floor is the slice-1 exit")
```

- [ ] **Step 2–4: Red, implement, green.** If ownership lands below 0.85, the fix belongs in Task 4's enumeration coverage (unclaimed interior columns → back-of-parcel extension pass), not in loosening the assertion.
- [ ] **Step 5: Commit** — `feat(villages): ledger-aware adapter and 1:1 claim translation`

---

### Task 8: Constructive debug view

**Files:**
- Modify: `tests/harness/maze_source_review.gd` (+ existing `.tscn`)

**Purpose:** Separate geometry/partition correctness from texture/asset issues.
The view renders the town as a plain 3D grid — air invisible, solids colored by
*meaning* — so a wrong partition is visible before any asset is involved.

**What it draws (all read from one sealed `WarrenMazeSitePlanner` plan):**

- **Terrain**: one flat quad per column at `massif.base_at(column)` over the
  site footprint + 2-column apron, muted green — the immutable floor, so
  slope moulding is visible.
- **Foundations**: dark grey boxes from `massif.base_at` up to `floor_band`
  for every entry in `audit.foundation_columns` — the rock courses.
- **Parcel claims**: one box per claim from `floor_band` to `top_band`,
  colored by `lineage_hint` hue (golden-ratio HSV walk, as the prototype
  does) — an L-pair shares its color, which is the visual check that pairing
  works.
- **Reservations**: translucent boxes colored by kind — market teal,
  courtyard/park green, landmark purple, large-house orange, garden lime;
  skywalk spans as solid bars at their overhead band.
- **Path**: a piecewise polyline network — segments between every pair of
  adjacent passage cells at floor height +0.2 m; spine thick amber, alleys
  thin ochre, market cells teal. The carved route order (`excavation.route`)
  draws the spine; alley edges come from passage-cell adjacency.
- **Air**: nothing. Unclaimed retained solid: neutral light grey (this is the
  ownership gap made visible — the 0.85 target is literally "little grey").

**Phase sequence:** the view renders SIX states per seed, one directory of
captures each, by calling the planner with increasing `stop_after` (plus the
raw massif drawn directly from `WarrenMassifBuilder` for state 1):

| state | source | what it isolates |
|---|---|---|
| 1 `massif` | `WarrenMassifBuilder.build` directly | terrain anchoring, terrace shape |
| 2 `bore` | `stop_after = &"carve"`, geometry only | spine/alley routing, stride legality |
| 3 `air` | same plan, covered/open coloring (a passage cell with mass above = covered bar) | tunnel vs sky classification |
| 4 `reserve` | `stop_after = &"reserve"` | feature placement + big edits |
| 5 `stamp` | `stop_after = &"stamp"` | claims, L-pairs, small edits |
| 6 `final` | full sealed plan | foundations + everything |

States 2 and 3 come from one carve call — air is a coloring of the carved
plan, not a separate carver stop (no carver surgery needed). Each state gets
iso + top; state 6 gets the full battery + reservation close-ups. Filenames:
`maze-seed-<N>-<state>-<view>.png`.

**Controls:** `--seeds a,b,c --output DIR` (existing), plus `--phases all`
(default: final only) and `--legend` printing the color table; writes
`index.json` with per-seed metrics (parcels, median footprint, ownership,
reservation outcomes). GUI mode only (headless capture hangs — project
convention).

- [ ] **Step 1: Rewrite the draw function** to consume `parcel_claims` /
  `reservations` / `column_edits` / `foundation_columns` instead of the
  legacy partitioner output; keep the environment/camera/capture scaffolding.
- [ ] **Step 2: Run on seeds 4, 7, 12 with `--phases all`**; visually verify
  per state: (1) terraces sit on the terrain floor, (2) the bore enters from
  one portal and stays connected, (3) covered spans sit only over deep blocks,
  (4) reservations claim no streets and their edits read as terraces,
  (5) no pencil forest and L-pairs share color, (6) foundations appear under
  every downhill edge and grey (unowned) is sparse.
- [ ] **Step 3: Commit** — `feat(villages): constructive geometry debug view`

---

### Task 9: Sweep metrics and slice-1 verification

**Files:**
- Modify: `tests/harness/warren_maze_mode_sweep.gd` (add `--constructive`: run `WarrenMazeSitePlanner` + adapter + translator per seed, print per-seed `parcels / median_footprint / ownership / foundation_columns / signature`)
- Modify: `docs/superpowers/plans/2026-08-20-constructive-maze-slice1.md` (record measured results)

- [ ] **Step 1: Implement the flag** (no TDD — harness).
- [ ] **Step 2: Run the matrix** — `--seeds 1,2,3,4,5,6,7,8,9,10,11,12 --constructive` for compact and standard; paste the table into this plan.
- [ ] **Step 3: Full regression** — `tests/test_warren_maze_carver.gd` (7/7) and `tests/test_warren_spatial_fabric_compiler.gd` (11/11) must be unchanged; production route-first profile (`warren_solve_profile.gd --city-seed 166029932451774690 --scale compact`) must still seal.
- [ ] **Step 4: Render** — the Task 8 debug view on seeds 4, 7, 12; attach the capture directory to the results note. Geometry issues found here are slice-1 bugs; texture/asset issues are explicitly out of scope until slice 2.
- [ ] **Step 5: Commit** — `feat(villages): constructive slice-1 metrics and measured corpus results`

---

## Follow-up plans (not this document)

- **Slice 2:** composition consumes `reservations` directly; hero beam deleted; gate disposition table applied; 24/24 composed+fabric on flat ground.
- **Slice 3:** real-terrain sites (production site + sloped fixtures) via `ground_bands`; `SettlementReliefPlan` verification.
- **Slice 4:** mode flip; delete the searched pipeline, pin cache, budget slicing, `GENERATION_MODE`; retire legacy greedy partition path and search harnesses; salt machinery removed with the pin cache.
