# Maze Town — Master Plan (single source of truth)

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Phase B is specified task-by-task below; later phases are milestones whose tasks are written when the phase starts, because they depend on Phase B's output.

**Goal:** One deterministic, one-pass village generator — heightfield → carve → tunnel policy → reserve → partition — producing a built, asset-rendered town in the game, with the old searched pipeline deleted.

**Specs (in force):**
- `docs/superpowers/specs/2026-08-21-plot-model-design.md` — the source-layer model (plots, derived rock, one support rule, four-colour view). **Binding for Phase B.**
- `docs/superpowers/specs/2026-08-20-constructive-maze-town-design.md` — the principle (*rules become repairs*), gate disposition, deletion scope, success criteria. Its reservation/stamp/ledger/trim/foundation sections are superseded by the plot model.
- `docs/superpowers/specs/2026-08-16-maze-town-carver-design.md` — the carver (M1/M2 done; its M3–M8 are absorbed into the phases below).

**Superseded plans (history only, do not execute):** `2026-08-16-maze-town-carver-refactor.md` (milestones absorbed here), `2026-08-20-village-solve-optimisation.md` (evidence doc; its tasks optimised the old search, which Phase F deletes), `2026-08-20-constructive-maze-slice1.md`, `2026-08-21-constructive-maze-slice1b.md`, `2026-08-21-constructive-maze-slice1c.md` (all executed; their layer is replaced by Phase B).

## Where we are (2026-08-21, branch `feat/constructive-maze-town`)

| phase | content | status |
|---|---|---|
| A | Constructive source layer (reservations, stamping, ledger, trim, foundations, debug view) — slices 1/1b/1c | **done; being replaced** by B. 22/23 seeds translate 1:1; ownership 0.69/0.69 on seeds 4/12; bridges on 6/6 standard seeds; carver tunnel policy (open by default + seeded spans) is kept |
| B | **Plot-layer rewrite** (plot model) | **next** — tasks below |
| C | Composition consumes plots; delete the hero-feature beam; gate disposition | after B |
| D | Real-terrain sites (production seed + sloped fixtures) | after C |
| E | Noise massif + carver vertical momentum/descent (variation) | after C (independent of D) |
| F | Mode flip; delete searched pipeline, pin cache, budget slicing, `GENERATION_MODE` | after D & E, gated on G |
| G | Built-town visual gate (asset render battery) | runs with C–E; gates F |

The **built-town view** the user keeps asking for arrives at the end of Phase C. Everything before it is blocks.

## Global Constraints (all phases)

- Plain lattice data in the source plan; natural terrain immutable; carved streets and their headroom immutable after the bore.
- Determinism: pure function of (city seed, ground bands, scale profile); sorted iteration wherever order affects output; `deterministic_signature()` covers plots.
- *Rules become repairs*: no new runtime rejection paths; shortfalls are audit facts asserted in tests. Hard runtime rules only: street connectivity/walkability/headroom, no overlap, every plot supported.
- TABS; commit only named files; never `.uid`; carver (`test_warren_maze_carver.gd` 10/10), fabric compiler (11/11), settlement fabric (42/42) stay green in every task; never weaken an assertion silently — re-pin measured floors upward only, report drops.
- Test command: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryko/story -s addons/gut/gut_cmdln.gd -gtest=res://tests/<file>.gd -gexit` (output to a file). New `class_name` ⇒ `--import` once first. GUI renders never use `--headless`.

---

# Phase B — Plot-layer rewrite

Replaces `WarrenMazeReservationPass` (586 lines), `WarrenMazeStampPass` (1722), the ledger half of `WarrenMazeSourcePlan` (798), and re-targets `tests/test_warren_maze_constructive.gd` (1771) and `maze_source_review.gd` (1019). Budget for the replacement plot layer: ≤ 700 lines.

Strategy: **build the new model alongside, switch the planner to it, then delete the old.** Each task leaves the suite green.

### Task B1: Plots and derived solids on the source plan

**Files:** modify `WarrenMazeSourcePlan.gd`; test `tests/test_warren_maze_plots.gd` (new file — the old constructive test file is retired in B4).

**Interfaces (exact):**
- `var plots: Array[Dictionary]` — `{id: StringName, kind: StringName (&"house"|&"asset"|&"deck"|&"bridge"), cells: Array[Vector2i], floor: int, top: int, door_walk: Vector3i, building_id: StringName}`; `top == floor` for decks.
- `func add_plot(plot: Dictionary) -> bool` — validates the support rule for every cell, disjointness against existing plots (column × [floor, top) intervals; decks occupy [floor, floor+1) for disjointness), headroom clearance; false + `last_rejection` otherwise; rejects after seal.
- `func plot_support_ok(cell: Vector2i, floor: int) -> bool` — the one support rule: `solid_at(Vector3i(cell.x, floor - 1, cell.y))` and `floor >= passage_headroom_top(p)` for every passage `p` in the column.
- `func solid_at(cell: Vector3i) -> bool` — per the spec (passage/headroom → false; inside a plot → true; below the lowest plot floor → rock true; no plot → below `rock_shoulder(column)`; else false). Must be O(plots-per-column): build a per-column index on add_plot.
- `func rock_shoulder(column: Vector2i) -> int` — min floor over plots on 4-neighbour columns, else `massif.base_at(column)`.
- `func plot_facts(plot) -> Dictionary` — `{roofed: bool, bears_on_rock: bool, tiered: bool}` per the spec.
- `seal()` validates: stack invariant per column (solids contiguous from terrain; plots in floor order with no gaps between a plot's top and the next plot's floor unless air is intended — i.e. `top_k <= floor_{k+1}`), every plot supported, every passage headroom band is air, plots disjoint. Signature adds `p:` lines (sorted by id).
- The old ledger fields/functions stay untouched in this task (they are deleted in B4).

- [ ] **Tests (red first):** `test_add_plot_enforces_support_and_headroom` (a plot over a passage's headroom band is rejected; a plot one band above headroom on a solid tunnel roof is accepted); `test_solid_at_derives_rock_under_plots_and_air_above` (rock below floor, plot inside, air above top, air in passage headroom); `test_stack_invariant_rejects_a_floating_plot_at_seal`; `test_signature_covers_plots`.
- [ ] Implement; green; carver suite 10/10 unchanged.
- [ ] Commit — `feat(villages): plots and derived solids on the maze source plan`.

### Task B2: WarrenPlotPlanner — assets, decks, partition, bridges

**Files:** create `WarrenPlotPlanner.gd` (`class_name WarrenPlotPlanner`, static); modify `WarrenMazeSitePlanner.gd` (call it instead of reserve/stamp; `stop_after` values become `&"carve"`, `&"reserve"`, `&"partition"`); test `tests/test_warren_maze_plots.gd`.

**Interfaces (exact):**
- `static func reserve(plan: WarrenMazeSourcePlan, profile: WarrenVillageScaleProfile) -> void` — P3a assets then P3b decks (spec algorithms). Asset templates come from `WarrenPrefabSolver.candidate_specs(program, …)`-style footprint data; to keep the source plan program-free, B2 takes a static `ASSET_TEMPLATES: Dictionary` keyed by scale → Array of `{kind_id, width, depth, min_count, max_count}` macro footprints derived once from the catalog's complete-house/landmark families (document the derivation; the exact macro sizes are read from the catalog in a unit test that asserts the table matches). Asset site score = Σ|massif.top_at(c) − datum|; min-cost site wins; deterministic tie-break by (datum, x, z).
- Deck growth: from each street cell in walk order (spine then lanes): BFS over 4-adjacent columns not in a plot, `|massif.top_at(c) − datum| <= 1`, `plot_support_ok(c, datum)`; accept if size ≥ `DECK_MIN[scale]` and cap at `DECK_MAX[scale]`; quota `DECK_QUOTA[scale]` (Vector2i range, seeded roll); record as deck plots.
- `static func partition(plan, profile) -> void` — P4 per the spec: seeds at street-fronting columns (door = that street cell), greedy growth largest-current-building-first into adjacent supported same-floor columns up to `BUILDING_CAP[scale]`, repeat until exhausted; height: tier rule (lowest upper street within footprint+apron ≥ floor + MIN_HOUSE_BANDS) else `STOREY_BUDGET[scale]` seeded roll; cap by any plot above; bridges: every `excavation.bridge_spans` entry → bridge plot at headroom top, 1 storey, building_id of an adjacent house at that floor else its own.
- Every step deterministic; outcomes in `plan.audit["plot_outcomes"]` (assets placed/skipped with reason, decks, buildings, bridges, leftover rock columns).

- [ ] **Tests (red first):** `test_assets_sit_at_the_minimum_modification_site` (enumerate candidates in the test, assert the chosen site's cost is the minimum); `test_decks_are_flat_street_level_regions` (every deck cell supported at datum, region connected, size within bounds); `test_partition_fills_every_street_fronting_column` (100% of street-fronting supportable columns are in a plot; report the share of ALL buildable columns in a plot and pin a floor at measured-minus-guard); `test_houses_rise_to_meet_upper_streets` (tiered facts non-vacuous); `test_bridge_plots_sit_on_retained_spans`; `test_planner_is_deterministic`.
- [ ] Implement; green; carver 10/10.
- [ ] Commit — `feat(villages): plot planner — assets, decks, partition, bridges`.

### Task B3: Adapter and translator on plots

**Files:** modify `WarrenMazeVolumeAdapter.gd` (volume built from `solid_at` — no ledger), `WarrenMazeBlockPartitioner.gd` (translated path reads `plots`: houses/assets → rectangular `WarrenBuildingParcel`s sharing `building_id`, the street-facing rectangle carries the door, remaining rectangles recorded in `plan.audit["back_rooms"]`; decks/bridges → their typed reservation records for composition); test file.

- [ ] **Tests:** `test_volume_matches_solid_at` (for a sealed plan, `volume.has_mass(cell) == plan.solid_at(cell)` over the massif bounds); `test_translator_emits_one_parcel_group_per_building` (every house plot → ≥1 parcel with a served door; rectangles cover the plot's cells exactly; 22+/24 corpus translate); `test_decks_and_bridges_translate_to_typed_records`.
- [ ] Implement; green; carver 10/10; fabric compiler 11/11; settlement fabric 42/42 (parcel contract untouched).
- [ ] Commit — `feat(villages): volume and parcels derived from plots`.

### Task B4: Delete the old layer

**Files:** delete `WarrenMazeReservationPass.gd`, `WarrenMazeStampPass.gd`; strip the ledger (`column_edits`, `record_edit`, `can_record_edit`, `record_trim`, `effective_base/top`, `foundation_depth`, `state_at_raw`, bearing/phase/trimmed validations) from `WarrenMazeSourcePlan.gd`; delete `tests/test_warren_maze_constructive.gd` (its surviving intent lives in `test_warren_maze_plots.gd`); update `warren_maze_mode_sweep.gd --constructive` to report plots/decks/bridges/exterior-rock ratio; `WarrenBuildingParcel`'s tunnel-roof branch now references `WarrenPlotPlanner.PLINTH_BANDS`-equivalent — keep the branch, move the constant.

- [ ] Grep proves no dead references; all suites green; sweep table pasted into this plan under "Phase B measured results".
- [ ] Commit — `refactor(villages): delete the reservation/stamp/ledger layer`.

### Task B5: Four-colour debug view

**Files:** modify `tests/harness/maze_source_review.gd`.

- [ ] Draw exactly: grey rock boxes (derived solid runs not in plots), blue plot boxes (shade per `building_id`; decks excluded), brown floor squares per passage cell, tan squares per deck cell; nothing for air; no lines; legend = seed/scale/state/plots/decks/bridges/exterior-rock + four swatches. States: massif, bore, tunnel, reserve, partition, final. BAND = 1.5 m.
- [ ] Render seeds 4, 3, 9 `--phases all`; the implementer and then the user judge readability.
- [ ] Commit — `feat(villages): four-colour plot debug view`.

### Phase B exit

- Exterior rock ratio (share of above-street-level exterior faces that are rock) ≤ pinned ceiling; share of buildable columns in a plot ≥ pinned floor; 22+/24 translate; pinned seeds' ownership ≥ 0.69; plot-layer code ≤ 700 lines; suites green; view readable.

---

# Phase C — Composition consumes plots (the built town)

Milestone: `WarrenVolumetricSolver._solve_maze` composes from plots: houses/assets → room composition on the translated parcels (back rooms via residual machinery), decks → court/plaza reservations, bridges → occupied-link reservations; the joint hero-feature beam is deleted; gate disposition per the constructive spec (hero quotas → audit facts; structural gates stay). Exit: 22+/24 seeds compose and pass the fabric gate; `warren_spatial_review.tscn --maze-source` renders the asset town; solve ≤ 3 s.

# Phase D — Real-terrain sites

Milestone: production site (seed 2697992464, super (0,-1)) and ≥2 sloped fixtures seal, translate, compose; `SettlementReliefPlan` blending verified; deck/plot datums follow slope. Exit: sites render in `--production-terrain-site`.

# Phase E — Variation

Milestone: noise massif behind the unchanged interface (relief > 0, varied plateaus/terrace ladders, eccentric footprints); carver vertical momentum + post-summit descent. Exit: Phase B/C metrics hold on the noise corpus; silhouettes measurably differ across seeds.

# Phase F — Mode flip and deletion

Milestone: `GENERATION_MODE` removed (maze is the only path); delete the 12-attempt rotation, ranked variants, courtless fallback, budget slicing, `carve_ranked`, the landmark set beam, `WarrenSolutionPinCache` + salt machinery + VillagePlan integration; retire search-only tests/harnesses. Exit: dead-symbol grep clean; full suite green; in-game cold load near settlements measured.

# Phase G — Visual gate

Runs alongside C–E: the M8-style battery (entrance, market, alleys both ways, courtyard, tunnel, skywalk, roofline, orbit) over the corpus; reviewed by the user before F.
