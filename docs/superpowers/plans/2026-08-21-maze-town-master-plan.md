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
| A | Constructive source layer (reservations, stamping, ledger, trim, foundations, debug view) — slices 1/1b/1c | **done; replaced** by B. 22/23 seeds translate 1:1; ownership 0.69/0.69 on seeds 4/12 **on the old owned-solid metric** (`maze_owned_solid_ratio`, the ledger-era 2D-footprint ratio, deleted with the ledger in B4 — history only, not comparable with the live metric below); bridges on 6/6 standard seeds; carver tunnel policy (open by default + seeded spans) is kept |
| B | **Plot-layer rewrite** (plot model) | **done** (B1–B5 + whole-branch review fix wave). Tasks below; measurements under *Phase B measured results* |
| C | Composition consumes plots; delete the hero-feature beam; gate disposition | **done with two misses** (C1–C6). 20/24 towns compose + pass the fabric gate against a 22+/24 exit; solve 2.4–10.4 s against a ≤ 3 s exit, which moves to Phase F. Measurements under *Phase C measured results* |
| D | Real-terrain sites (production seed + sloped fixtures) | after C |
| E | Noise massif + carver vertical momentum/descent (variation) | after C (independent of D) |
| F | Mode flip; delete searched pipeline, pin cache, budget slicing, `GENERATION_MODE` | after D & E, gated on G |
| G | Built-town visual gate (asset render battery) | runs with C–E; gates F |

The **built-town view** the user keeps asking for arrives at the end of Phase C. Everything before it is blocks.

## Global Constraints (all phases)

- Plain lattice data in the source plan; natural terrain immutable; carved streets and their headroom immutable after the bore.
- Determinism: pure function of (city seed, ground bands, scale profile); sorted iteration wherever order affects output; `deterministic_signature()` covers plots.
- *Rules become repairs*: no new runtime rejection paths; shortfalls are audit facts asserted in tests. Hard runtime rules only: street connectivity/walkability/headroom, no overlap, every plot supported. Street walkability is the goal; the carver's own over/under crossings at exact headroom distance leave 0–6 floor gaps per town today (measured corpus-wide 2026-08-23; the plan's earlier "1–3" understated it), carried to Phase C gate disposition / Phase E carver — the plot layer is pinned to add none (`test_streets_keep_their_floor` asserts sealed `street_floor_gaps` equals the carve-stage count on every sealing seed).
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

- Exterior rock ratio (share of the town's exposed skin that is rock) ≤ pinned ceiling; share of buildable columns in a plot ≥ pinned floor; 22+/24 translate; **`maze_ownership_ratio` ≥ its per-seed pinned floor** on the four planner seeds; plot-layer code ≤ 700 lines; suites green; view readable.

The ownership metric is `maze_ownership_ratio` = plot-owned solid cells (parcel cells + back-room cells) / solid cells, both counted through `solid_at` over `[massif.base_at, column_ceiling)`; bridge bands are in neither (a bridge is a typed record, never a parcel). Its four floors, measured minus a 0.05 guard (`OWNERSHIP_FLOOR` in `tests/test_warren_maze_plots.gd`, re-pinned upward only):

| seed | scale | measured | floor | measured before the 2026-08-23 fix wave |
|---|---|---|---|---|
| 12 | compact | 0.6667 | 0.61 | 0.6667 (no bridge on this seed) |
| 4 | compact | 0.7253 | 0.67 | 0.7227 |
| 3 | standard | 0.6803 | **0.63** (was 0.62) | 0.6762 |
| 9 | standard | 0.7727 | **0.72** (was 0.71) | 0.7685 |

Three of the four rose when bridge mass left the denominator (whole-branch review, minor 15): a bridge translates to an occupied-link reservation, never to a parcel, so counting its bands as solid-the-translation-failed-to-own charged a town for having skywalks. Floors re-pinned upward accordingly.

*History:* the phase originally read "pinned seeds' ownership ≥ 0.69", carried from slice 1c's 0.69/0.69 on seeds 4/12. Those two numbers are the **old owned-solid metric** (`maze_owned_solid_ratio`), which died with the edit ledger in B4; it counted a different numerator and a different denominator and is not comparable with the live metric above.


### Phase B measured results

`Godot --headless --path . -s res://tests/harness/warren_maze_mode_sweep.gd -- --seeds 1,2,3,4,5,6,7,8,9,10,11,12 --mode maze --constructive`, re-run 2026-08-23 after the whole-branch review's fix wave. Exterior rock is the WIDENED metric (band `base_at` included, up-facing rock counted as skin) and ownership excludes bridge bands, so both of those columns differ from B4's own table in `task-4-report.md`; every other column is unchanged.

**sealed 23/24 · translated 22/23 (22/24 overall)**

| seed | scale | sealed | plots | houses | assets | decks | bridges | tiered | mean fp | ext. rock | raised shoulders | parcels | back-room cells | ownership | translated |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | compact | yes | 34 | 31 | 1 | 1 | 1 | 3 | 1.77 | 0.2006 | 0 | 32 | 88 | 0.7468 | yes |
| 2 | compact | yes | 19 | 17 | 2 | 0 | 0 | 4 | 4.06 | 0.1411 | 2 | 19 | 267 | 0.7632 | yes |
| 3 | compact | yes | 20 | 17 | 2 | 1 | 0 | 3 | 3.18 | 0.2013 | 0 | 19 | 169 | 0.7302 | yes |
| 4 | compact | yes | 34 | 32 | 1 | 0 | 1 | 7 | 2.44 | 0.1878 | 7 | 33 | 173 | 0.7253 | yes |
| 5 | compact | yes | 30 | 27 | 1 | 1 | 1 | 4 | 2.26 | 0.1715 | 0 | 28 | 144 | 0.7751 | yes |
| 6 | compact | yes | 28 | 26 | 1 | 1 | 0 | 6 | 3.04 | 0.1575 | 0 | 27 | 207 | 0.7179 | yes |
| 7 | compact | **no** | — | — | — | — | — | — | — | — | — | — | — | — | `stage=carve` — alley budget reached 0.850 frontage, below 0.900 |
| 8 | compact | yes | 32 | 29 | 1 | 1 | 1 | 4 | 2.41 | 0.1889 | 0 | — | — | — | **no** — `stage=adapter`: plan seal rejected: exact public route expands into a broad floor slab |
| 9 | compact | yes | 31 | 28 | 1 | 1 | 1 | 5 | 2.00 | 0.2629 | 1 | 29 | 98 | 0.6273 | yes |
| 10 | compact | yes | 22 | 19 | 2 | 1 | 0 | 3 | 2.95 | 0.2192 | 1 | 21 | 186 | 0.6685 | yes |
| 11 | compact | yes | 27 | 23 | 2 | 1 | 1 | 5 | 2.09 | 0.1747 | 0 | 25 | 111 | 0.7778 | yes |
| 12 | compact | yes | 31 | 29 | 1 | 1 | 0 | 11 | 2.41 | 0.2605 | 11 | 30 | 136 | 0.6667 | yes |
| 1 | standard | yes | 32 | 29 | 2 | 0 | 1 | 5 | 2.59 | 0.1469 | 0 | 31 | 196 | 0.7685 | yes |
| 2 | standard | yes | 49 | 47 | 0 | 1 | 1 | 4 | 2.02 | 0.1583 | 3 | 47 | 162 | 0.7617 | yes |
| 3 | standard | yes | 39 | 35 | 1 | 1 | 2 | 6 | 2.06 | 0.2255 | 0 | 36 | 144 | 0.6803 | yes |
| 4 | standard | yes | 46 | 41 | 1 | 2 | 2 | 17 | 2.39 | 0.2334 | 12 | 42 | 208 | 0.6494 | yes |
| 5 | standard | yes | 38 | 32 | 3 | 2 | 1 | 11 | 1.88 | 0.2146 | 0 | 35 | 155 | 0.7056 | yes |
| 6 | standard | yes | 41 | 37 | 2 | 0 | 2 | 5 | 2.22 | 0.1286 | 0 | 39 | 205 | 0.8101 | yes |
| 7 | standard | yes | 45 | 43 | 0 | 0 | 2 | 4 | 2.09 | 0.1367 | 0 | 43 | 194 | 0.7922 | yes |
| 8 | standard | yes | 53 | 49 | 2 | 0 | 2 | 7 | 1.84 | 0.1399 | 0 | 51 | 166 | 0.7848 | yes |
| 9 | standard | yes | 44 | 41 | 0 | 1 | 2 | 5 | 2.32 | 0.1358 | 2 | 41 | 194 | 0.7727 | yes |
| 10 | standard | yes | 42 | 38 | 2 | 0 | 2 | 5 | 2.00 | 0.1240 | 0 | 40 | 200 | 0.8109 | yes |
| 11 | standard | yes | 44 | 40 | 1 | 1 | 2 | 8 | 2.00 | 0.1598 | 0 | 41 | 148 | 0.7738 | yes |
| 12 | standard | yes | 44 | 40 | 1 | 1 | 2 | 7 | 2.27 | 0.1459 | 0 | 41 | 234 | 0.7865 | yes |

**Exit numbers**

- **Buildable coverage** 0.965 (pinned floor 0.91) — share of street-fronting columns inside a plot.
- **Fronting (column, band) slot share** 0.897 (pinned floor 0.85).
- **Exterior rock** 0.124–0.263 across the corpus; the four planner seeds read 0.2605 / 0.1878 / 0.2255 / 0.1358, so `EXTERIOR_ROCK_CEILING` is pinned at **0.32** (worst + 0.05, rounded up). These are the WIDENED metric of minor 6 (band `base_at` included, up-facing rock counted as skin); under the older side-faces-only definition the same corpus read 0.069–0.188 with the ceiling at 0.24. The two are not comparable — a later movement of this ceiling is a real change.
- **Seal / translate** 23/24 seal, 22/24 translate (seed 7 compact fails at `carve`, seed 8 compact at `adapter`).
- **Mean house footprint** 1.77–4.06 macro columns (pinned floor 1.8 on the four planner seeds).
- **Street floors** sealed `street_floor_gaps` equals the carve-stage count on all 23 sealing towns; the plot layer adds none. The bore itself leaves 0–6 per town.
- **Raised shoulders** (instrumentation, no rule): 39 no-plot columns across the 23 sealing towns stand above their own massif envelope, in 8 towns, worst 12 (seed 4 standard). `rock_shoulder` has no upper clamp; whether it needs one is a Phase C/E question.
- **Plot-layer size** 1033 code lines against the spec's ≤ 700 — **recorded as MISSED and accepted** (B4 ruling): the layer replaced 4,632 deleted lines with ~1,500 and each file has one responsibility.

---

# Phase C — Composition consumes plots (the built town)

Milestone: `WarrenVolumetricSolver._solve_maze` composes from plots: houses/assets → room composition on the translated parcels (back rooms via a directed residual pre-pass), decks → walkable public floors (plazas/terraces), bridges → spatial skywalk reservations, assets → landmark reservations; the hero-feature beam is **bypassed** in maze mode (deleted in Phase F with the modes that still share it); gate disposition per the constructive spec (hero quotas → audit facts; structural gates stay). Exit: 22+/24 seeds compose and pass the fabric gate; `warren_spatial_review.tscn --maze-source` renders the asset town; solve ≤ 3 s.

**Map (read before any task):** `.superpowers/sdd/2026-08-21-maze-town-master-plan/phase-c-map.md` — the call graph, reservation contracts, gates, residual-room machinery, and the two facts that shape this phase: (1) `_solve_maze` and `warren_spatial_review --maze-source` still call `WarrenMazeCarver.carve` (no plots); (2) in advisory mode the beam still demands `skywalk_range.x` skywalks at `_partition_rooms:1625-1628` and rejects unconditionally when `market_reservation` is empty at `:1918-1926`, so maze-mode composition cannot currently succeed at all.

**Global constraints for Phase C (in addition to the plan's):** route-first and mass-first paths stay byte-identical until Phase F (`tests/test_warren_generation_mode.gd`, fabric compiler 11/11, settlement fabric 42/42, and `tests/test_warren_volumetric_solver.gd` minus its two full-solve tests stay green); every maze-mode branch is keyed on `WarrenTownSolver.GENERATION_MODE == MODE_MAZE` or on `volume.mass_context.has(&"maze_source_plan")`, never on a new global; no new search loops — one pass, audit facts for shortfalls; the composition test file `tests/test_warren_maze_composition.gd` stays under ~4 min (program compile once per file; the four planner seeds 12/4 compact, 3/9 standard; the 24-seed matrix lives in the sweep harness).

### Task C1: Plots into production; composition baseline

**Files:** modify `WarrenVolumetricSolver.gd` (`_solve_maze`), `tests/harness/warren_spatial_review.gd` (`--maze-source` branch; add `--mode maze` that sets/restores `WarrenTownSolver.GENERATION_MODE`), `tests/harness/warren_maze_mode_sweep.gd` (`--mode maze` rows report the failing gate name); create `tests/test_warren_maze_composition.gd`.

- `_solve_maze` and the harness build the source with `WarrenMazeSitePlanner.plan(world_seed, ground_bands, profile)` (plots) — `last_failure` carries the planner's stage failure; `WarrenMazeCarver.carve` is no longer called from either.
- `tests/test_warren_maze_composition.gd`: `_program()` compiled once (`SettlementFabricProgram.compile(EnvironmentCatalog.load_default())`); `test_maze_mode_reaches_composition` — for the four planner seeds run `WarrenVolumetricSolver.solve(seed, {}, program, profile)` with `GENERATION_MODE = MODE_MAZE` (restored in `after_each`), print per seed: sealed?, `last_failure` (first 160 chars), ms; assert the failure, when present, is NOT at the source/adapter/translator stage (i.e. composition was reached — the string does not start with `maze massif`/`maze carve`/`maze volume adapter`/`sealed maze source carries no plots`); `test_maze_mode_is_deterministic` on seed 12 compact when it seals (skip with a printed reason when it does not — this task establishes the baseline, C2 makes it seal).
- The sweep's `--mode maze` prints the 24-row matrix with the gate each town dies at; paste it into the report as the Phase C baseline.
- [x] Commit — `feat(villages): maze mode composes from the plot planner; composition baseline`.

### Task C2: Gate disposition — maze-mode feature pass replaces the beam

**Files:** modify `WarrenVolumetricSolver.gd` (`_partition_rooms`: a maze-mode branch `_maze_feature_pass` taken when the volume carries a maze source; the legacy beam untouched for the other modes), `WarrenSpatialFeatureSolver.gd` (`:98` landmark floor and `:119` skywalk floor become advisory shortfalls in maze mode like `:240-252` balconies), `WarrenTownSolver.gd` (`feature_quotas_are_advisory` stays the switch); test file.

- `_maze_feature_pass` (one pass, no search): market = the first viable `_preplan_spatial_market` candidate (or the absent sentinel → `advisory_shortfalls["covered_market"]`); courtyard bridge = the absent sentinel unless `requires_elevated_courtyard` (large/grand keep the existing cantilever candidates but take the first that seals — no ranking loop); landmarks = asset plots translated into landmark reservations (`maze_assets` record from the translator — add it in this task: `{id, kind_id, cells, floor, door_walk}` — mapped to `recipe_id = kind_id`, `origin`/`yaw_quarters` from the footprint and the door facing, run through the same `_reserve_landmark_preplan` commit; an asset whose recipe cannot be placed at that site is an audited shortfall, never a rejection); skywalks = none in this task (C4 adds bridges). The pass then continues into the existing exact-composition code (`:2101` onward) unchanged.
- The unconditional `market_reservation.is_empty()` reject at `:1918-1926` and the `skywalk_range.x` floors at `:1625-1628`/`:1650-1653` are not reached on the maze branch; on the legacy branch they are unchanged.
- Tests: `test_maze_mode_seals_the_planner_seeds` (all four seal through `solve`; report ms), `test_hero_shortfalls_are_audit_facts` (`advisory_shortfalls` keys present with counts; no hero quota rejects), determinism on seed 12 compact (signature equality across two solves), route-first mode test file green.
- [x] Commit — `feat(villages): maze-mode feature pass — hero quotas become audit facts`.

### Task C3: Back rooms and stacked houses

**Files:** modify `WarrenMazeBlockPartitioner.gd` (stacked plots: `support_parent_parcel_id`/`support_parent_storey_index` from the plot whose `[floor, top)` contains `floor − 1`; bridges excluded), `WarrenBuildingParcel.gd`/`WarrenParcelPlan.gd` (`_building_support_is_valid` and `roof_base_band()` accept a child at a flat-roof parent's `top_band` — the slab is the seam), `WarrenVolumetricSolver.gd` (a directed residual pre-pass `_stamp_maze_back_rooms` before `_backfill_residual_rooms`: each `maze_back_rooms` record decomposed into rectangles from the five-kind vocabulary (2×3, 2×2, 1×2, 2×1, 1×1), each stamped as a `WarrenRoomStamp` at the plot's `[floor, top)` with private access from the parcel's building (`add_private_parent`), envelope-checked with the same `_residual_room_envelope_fits`; cells that cannot be stamped are recorded in `composition_audit["maze_back_room_unstamped_cells"]` and left to the greedy backfill); test file.
- Tests: `test_stacked_houses_declare_their_parent` (every house plot with a plot below carries a valid parent after `WarrenParcelPlan.seal`), `test_back_rooms_become_rooms` (share of back-room cells stamped, reported and pinned at measured − 0.05 on the four seeds), suites green.
- [x] Commit — `feat(villages): back rooms stamped from plots; stacked houses declare their parent`.

### Task C4: Decks and bridges

**Files:** modify `WarrenMazeVolumeAdapter.gd` (deck cells → `volume.courtyard_cells` at the deck floor AND public floor surfaces so `_carve_public_volume` paves them as walkable `PUBLIC_FLOOR`; the plan's `maze_decks` records are the source), `WarrenVolumetricSolver.gd` (`_maze_feature_pass` skywalks: each `maze_bridges` record → a spatial skywalk reservation between the two flank parcels' room sockets at the bridge floor via the existing `_raw_straight_skywalk_reservation` builder; when no socket pair matches, `advisory_shortfalls["bridges"] += 1` and the span's retained mass is released to rock — audited, never rejected), `WarrenMazeBlockPartitioner.gd` (bridge record gains `flank_parcel_ids`); test file.
- Tests: `test_decks_are_walkable_public_floor` (every deck cell has a `PUBLIC_FLOOR` face in the sealed spatial plan and is reachable from the route), `test_bridges_become_skywalks_or_audited_shortfalls` (count of skywalk features + shortfalls == bridge plots on the four seeds; report the ratio).
- [x] Commit — `feat(villages): decks pave as plazas; bridge plots become skywalks`.

### Task C5: Flat roofs, stone bases, first built-town render

**Files:** modify `WarrenParcelConstruction.gd` (`proposal()` emits `flat_roof`), `WarrenRoomStamp.gd` (carries `flat_roof`), `WarrenSpatialFabricCompiler.gd` (`compile_roof_units` honours a stamp's `flat_roof` — the tiered house's roof is the upper street's slab/terrace, never a pitched roof), `WarrenMazeBlockPartitioner.gd` (`bears_on_rock` → the parcel's terrain-bearing fact so stacked houses do not get a stone base), harness; the user's built-town captures.
- Render seeds 4, 3, 9 with `warren_spatial_review.tscn -- --maze-source --mode maze --seed N --scale <id> --output .../scratchpad/phase-c-view` (GUI); the implementer reads the iso/street/orbit captures and writes an honest verdict; every blocker that stops a capture is fixed in this task or recorded with its gate.
- Tests: `test_tiered_parcels_get_flat_roofs` (fabric audit `flat_roof_count` ≥ tiered parcel count on a seed with tiers), fabric compiler 11/11, settlement 42/42.
- [x] Commit — `feat(villages): flat roofs and stone bases from plot facts; first built maze town`.

### Task C5b: Stone skin, realisable assets, the built-town battery

**Files:** modify `SettlementFabricAssembler.gd` (retained maze stone is skinned: every exposed face of a retained stone cell — side faces whose neighbour is air/outside/public air, top faces whose cell above is air and not a paved public floor — emits the rock module the plinth path already uses; internal faces between stone and stone, stone and a building, or stone and a paved floor emit nothing), `WarrenSpatialFabricCompiler.gd` (`_foundation_shell_audit` counts expected vs rendered stone faces for maze stone the same way it does for plinths; `maze_stone_face_count`), `WarrenPlotReservations.gd` + `tests/test_warren_maze_plots.gd` (asset templates carry the recipe's entrance offset and clearance extents so the planner's site test mirrors `_maze_asset_landmark`'s realisation checks — body inside the plot, bearing at the street datum, clearance clear of other plots; ≥ 1 asset lands on the planner seeds or the 24-seed corpus, reported), `tests/test_warren_maze_composition.gd` (`test_retained_stone_is_skinned`: rendered stone faces == audited exposed faces on the sealing seeds; `test_assets_land` — the landmark success path asserted through the production pass), `tests/harness/warren_spatial_review.gd` only if a capture is needed.
- Render seeds 12/compact, 4/compact, 3/standard (GUI, `--maze-source --mode maze`); read overview, street, foundation, and plaza captures; write the honest verdict (stone mountain present? plazas on stone? stone bases? roofs? what is broken); fix what blocks a capture.
- [x] Commit — `feat(villages): retained stone skinned; assets realisable; built-town battery`.

### Task C5c: Compose the plot mass

The quarry-block verdict (C5b) is unroomed PLOT mass retained as stone: only 23–37 % of back-room cells become rooms, 2–6 parcels per town compose no lineage, the residual budget (6–8 rooms per town) caps the greedy backfill, and stacked children drop. In the plot model every plot cell is a building; composition must build it.

**Files:** modify `WarrenVolumetricSolver.gd` (`_retain_maze_rock` tags cells `rock` (derived rock: `solid_at` true and inside no plot) vs `unroomed_plot_mass` (inside a plot's `[floor, top)`, claimed by no room/roof/feature) — two audit counts `maze_retained_rock_cells` / `maze_unroomed_plot_cells` and the share `maze_unroomed_plot_share` = unroomed / plot mass; maze mode lifts `residual_room_budget`/`residual_kind_budget` (the greedy backfill, already confined to plot mass, runs until no candidate fits); the directed back-room pass stamps street-fronting back-room rectangles as ADDRESSED rooms (their own authored threshold onto the street's public floor) before private ones; the `_residual_room_envelope_fits` roof preflight applies only to rectangles whose top is the plot's top; parcels that compose no lineage are diagnosed — `composition_audit["maze_uncomposed_parcels"]` with the gate that dropped each (`_parcel_address_has_public_floor`, exact composition yield, bearing) — and the fixable causes fixed; `_reserve_landmark_preplan` skips (does not claim) a ROOF face the route already owns and accepts bearing on retained maze stone, so assets realise), `WarrenSpatialFabricCompiler.gd` (the stone audit reports both tags), `tests/test_warren_maze_composition.gd`.
- Tests: `test_unroomed_plot_mass_is_bounded` (share reported per seed; CEILING pinned at measured + 0.05 after the work — goal ≤ 0.15, report honestly if missed with the remaining causes), `test_back_rooms_become_rooms` re-pinned upward, `test_assets_land` un-pended when ≥ 1 realises (report which seed), `test_uncomposed_parcels_are_explained` (every uncomposed parcel carries a gate name).
- Render seeds 12 and 3 after; read the overviews: does the stone recede to bases, shoulders, slabs and tunnel roofs with houses on top?
- [x] Commit — `feat(villages): compose the plot mass — back rooms, lifted residual budget, assets realised`.

### Task C5d: Flat-roof-first composition

C5c measured that the binding constraint on plot-mass composition is the authored PITCHED roof vocabulary (eave halos, macro setbacks, 1-cell slivers), not composition: two relaxations that would have taken the unroomed share toward 0.2 each cost sealing seeds their towns at roof gates. The plot model's town is a tiered hill town; its vernacular is the flat roof (a 1-band slab + parapet course, already wired in C5).

**Files:** modify `WarrenMazeBlockPartitioner.gd` (`flat_roof = true` for every house parcel and back room in maze mode; a pitched roof is a seeded PREFERENCE recorded on the parcel (`roof_preference = &"pitched"`) for houses whose plot top is strictly above every 4-neighbour plot's top and above the adjacent street bands — the only places a pitched unit can fit without a halo conflict), `WarrenSpatialFabricCompiler.gd` (`compile_roof_units`: a maze stamp composes its flat unit unless `roof_preference == pitched` AND the pitched unit fits with no displacement and no halo conflict — then pitched; never the reverse; audit `maze_pitched_roof_count` / `maze_flat_roof_count` / `maze_pitched_refused_count`), `WarrenParcelConstruction.gd` + `WarrenVolumetricSolver.gd` (re-apply C5c's two reverted relaxations — full no-descent in maze mode; back-room bearing mirroring the compiler's `stone_borne` branch — now that the roof gate is gone; keep them only if the three sealing seeds keep sealing, else report the gate), `tests/test_warren_maze_composition.gd`.
- Measure: unroomed share per seed before → after (re-pin the ceiling DOWN only if measured lower), pitched/flat counts, 9/standard status (its pin removed if it clears), corpus seal count via the sweep (`--mode maze`, 24 seeds — report how many now seal; the Phase C exit wants 22+/24).
- Render seeds 12 and 3; verdict: a terraced town of flat-roofed stone-and-timber houses with the occasional pitched roof on a freestanding house — does it read that way?
- [x] Commit — `feat(villages): flat-roof-first maze composition; pitched roofs where they fit`.

### Task C5e: Partial plates tile; roofs are terraces

C5d left two things: 8 of the 13 non-sealing corpus seeds (and 9/standard, and the reverted relaxation 1) die at a partial-plate roof gate — a flat crown only partly covered by a stacked room has no authored `roof.flat.*` unit that matches the uncovered shape; and the flat roof's parapet course is retained STONE, so from above every house reads as a stone block with a timber sill instead of a terrace.

**Files:** modify `WarrenSpatialFabricCompiler.gd` (a partial plate is tiled: the uncovered cells of a flat crown are covered greedily with `roof.flat.tower`/`.slim` (and `.square` where a 2×2 fits) units in sorted order, each a normal roof unit in the face identity; `maze_partial_plate_tiled_count` / `_tile_count`; the `macro setback roof 0`, `exact setback roof`, and `1-cell exposed sliver` gates are not reached for flat crowns), `WarrenVolumetricSolver.gd` + `WarrenParcelConstruction.gd` (the flat parcel's parapet band above the slab is NOT retained stone: it is released to air, so the plot's `top` stays the massing envelope while the built crown is slab + open terrace; re-apply relaxation 1 (full no-descent) now that the partial-plate gate is gone, keeping it only if the three sealing seeds still seal), `SettlementFabricAssembler.gd` (a railing — `RAILING_MEDIUM`, already referenced by the program — on every exposed edge of a flat crown's slab whose neighbour at the slab band is air; no railing against a stacked room, a deck at the same band, or a street on the roof; audit `maze_terrace_railing_count`), `tests/test_warren_maze_composition.gd`.
- Measure: unroomed share (ceiling DOWN only), corpus seal count via the sweep (report; C6 pins), 9/standard (remove the pin if cleared), per-seed ms.
- Render seeds 12 and 3; verdict: terraces with railings, stone only as bases/shoulders/slabs, houses visible from above?
- [x] Commit — `feat(villages): partial plates tile; flat roofs are open terraces with railings`.

### Task C6: Corpus exit and performance

**Files:** `tests/harness/warren_maze_stage_probe.gd` (stage timings per seed incl. composition sub-stages from `SKYWALK_TIMING`), `tests/test_warren_maze_composition.gd` (`test_corpus_composes` — the four seeds must seal; the 24-seed matrix is asserted via the sweep's JSON summary written to the scratchpad: ≥ 22/24 compose + fabric), `docs/superpowers/plans/2026-08-21-maze-town-master-plan.md` ("Phase C measured results": per-seed ms, gates, shortfalls).
- Solve ≤ 3 s per town on the measured baseline (report the distribution; if a seed exceeds it, name the stage and the fix or the ruling).
- [x] Commit — `test(villages): maze composition corpus exit; stage timings`.

### Phase C exit
- 22+/24 compose and pass the fabric gate; hero quotas are audit facts; the four planner seeds render as asset towns; solve ≤ 3 s; legacy modes byte-identical; suites green.

### Phase C measured results

`Godot --headless --path . -s res://tests/harness/warren_maze_mode_sweep.gd -- --seeds 1,2,3,4,5,6,7,8,9,10,11,12 --mode maze --scale compact,standard`, at Task C6. The run writes its matrix to `user://warren_maze_mode_sweep.json`, which is what `tests/test_warren_maze_composition.gd::test_corpus_composes` asserts against (pinned at measured − 1 = **19**).

**sealed 20/24 · exit bar 22+/24 — MISSED by two**

| seed | scale | ms | outcome / gate |
|---|---|---|---|
| 1 | compact | 2073 | sealed |
| 1 | standard | 6523 | sealed |
| 2 | compact | 2455 | sealed |
| 2 | standard | 14360 | sealed |
| 3 | compact | 1467 | sealed |
| 3 | standard | 5550 | sealed |
| 4 | compact | 3944 | sealed |
| 4 | standard | 8068 | **fabric** — `spatial modular-box contract failed: "classification":"roofless_house" … spatial.maze_back.04.room00` |
| 5 | compact | 2157 | sealed |
| 5 | standard | 3545 | sealed |
| 6 | compact | 2837 | sealed |
| 6 | standard | 9919 | sealed |
| 7 | compact | 43 | **source** — `carve: alley budget reached 0.850 frontage, below 0.900` (pre-existing Phase B gate) |
| 7 | standard | 7263 | sealed |
| 8 | compact | 212 | **adapter** — `plan seal rejected: exact public route expands into a broad floor slab` (pre-existing Phase B gate) |
| 8 | standard | 8801 | sealed |
| 9 | compact | 1825 | **fabric** — `public realm adaptation failed: realm seal failed: invalid or duplicate edge volume.edge.34` |
| 9 | standard | 10341 | sealed |
| 10 | compact | 2177 | sealed |
| 10 | standard | 8680 | sealed |
| 11 | compact | 2605 | sealed |
| 11 | standard | 6304 | sealed |
| 12 | compact | 2478 | sealed |
| 12 | standard | 7142 | sealed |

Two of the four misses (7/compact, 8/compact) are the Phase B source/adapter gates already recorded above; they have never composed and are the two allowed misses. The other two are one seed each at two different gates — a back room the modular-box contract calls roofless, and a duplicate public-realm edge — and neither is a family.

**The corpus ladder**

| | C5b | C5c | C5d | C5e | **C6** |
|---|---|---|---|---|---|
| towns sealed of 24 | — | — | 11 | 18 | **20** |
| unroomed plot mass (12/c · 4/c · 3/s · 9/s) | 0.321 / 0.390 / 0.341 / — | 0.267 / 0.305 / 0.319 / — | 0.226 / 0.211 / 0.281 / — | 0.226 / 0.211 / 0.281 / 0.260 | **0.156 / 0.142 / 0.224 / 0.176** |
| uncomposed parcels | 9 / 12 / 7 / — | 6 / 3 / 5 / — | 6 / 3 / 4 / — | 6 / 3 / 4 / 6 | **1 / 1 / 2 / 1** |
| back-room stamped share | — | 0.556 / 0.179 / 0.400 / — | 0.806 / 0.692 / 0.587 / — | 0.806 / 0.692 / 0.587 / 0.558 | **0.838 / 0.700 / 0.739 / 0.585** |

C6 shipped two things: the `authored room envelope gate failed: room … failed measured phase selection` family was diagnosed as an ORDERING defect (an optional phase-B facade projection reaching into a room whose mandatory shell had not been compiled yet) and closed by `WarrenSpatialFabricCompiler._required_room_clearance`, which took 12/standard; and full no-descent for maze parcels (`WarrenParcelConstruction._support_base_band`), reverted three times before, then shipped because with the family closed it loses no seed and gains 6/compact. The unroomed goal of 0.15 is met on 4/compact (0.142) and missed on the other three, worst 0.224.

**Exit numbers**

- **Seal + fabric** 20/24 against 22+/24 — **MISSED**, by 4/standard and 9/compact; the other two misses are the pre-existing Phase B source/adapter gates.
- **Solve time** 2442 / 3935 / 5554 / 10383 ms on the four planner seeds (12/compact, 4/compact, 3/standard, 9/standard) against a **≤ 3 s** exit — **MISSED** on three of four; 1.5–14.4 s across the 20 sealing towns of the corpus. Pinned at measured × 1.5 in `PLANNER_SOLVE_MS_CEILING`. **The ≤ 3 s target moves to the Phase F exit** on the controller's note — as a SCHEDULING decision, not because F's deletions pay for it. The table below is the measurement, and it says the cost is **`room_composition`** (`WarrenVolumetricSolver._composition_offsets` plus `WarrenRoomCompositionPlanner.solve`), which is 43–76 % of the composition and superlinear in room count (60 → 98 rooms is 632 → 5659 ms). That code is on the maze path and F does **not** delete it: F deletes the searched frontier, the 12-attempt rotation, the landmark set beam and the pin cache, and the hero beam those belong to is already down to 24–36 ms here. **F's performance task must therefore name the exact block solve / room composition as its subject**; a phase that only removes the search will arrive at the same 10 s on 9/standard.
- **Where the time goes** (`tests/harness/warren_maze_stage_probe.gd`, per planner seed, ms): it is NOT the hero beam — advisory quotas collapse that to 24–36 ms.

| stage | 12/compact | 4/compact | 3/standard | 9/standard |
|---|---|---|---|---|
| massif | 3 | 4 | 4 | 4 |
| carve | 59 | 55 | 44 | 47 |
| plots (reserve + partition + seal) | 84 | 100 | 183 | 157 |
| adapter | 11 | 9 | 10 | 11 |
| parcels | 15 | 17 | 19 | 24 |
| hero beam | 30 | 24 | 31 | 36 |
| **room composition** | **632** | **723** | **2370** | **5659** |
| residual / back rooms | 200 | **1219** | 265 | 234 |
| feature pass | 53 | 39 | 65 | 135 |
| authored room envelope gate | 244 | 229 | 645 | 801 |
| composition remainder | 305 | 330 | 405 | 522 |
| fabric compile | 784 | 1163 | 1509 | 2795 |

`room_composition` — the per-parcel exact block solve plus `WarrenRoomCompositionPlanner` — is 43–76 % of the composition and scales with room count (60 → 98 rooms is 632 → 5659 ms). The fabric compile is second. 4/compact is the one town where the residual backfill dominates instead.

- **Hero quotas** are audit facts on every sealing town (`advisory_shortfalls`: covered_market, landmarks, skywalks, balconies, bridges, assets), never rejections.
- **Legacy byte-identity** holds: fabric compiler 11/11, settlement fabric 42/42, generation-mode 6/8 (the same two pre-existing seed-7 failures).
- **Still open into D/E/F:** the two one-seed gates above; the 0.15 unroomed goal on three of four planner seeds; the ≤ 3 s solve.

# Phase D — Real-terrain sites

Milestone: the maze pipeline runs on real sampled ground (production site seed 2697992464, super (0,-1), plus ≥2 sloped fixtures) end to end — seal, translate, compose, render — with deck/plot datums following the slope. The production entry (`VillageWarrenFabricSolver.solve`) works in maze mode on sloped placements.

### Task D1: Sloped ground through the plot pipeline; solve_selected for maze

**Files:** modify `VillageWarrenFabricSolver.gd` (`solve_selected` gains a maze branch: one-pass re-solve `WarrenVolumetricSolver._solve_maze(city_seed, ground_bands, program, profile)` — no attempt/frontier machinery, no `mass_first_attempt_index`; the preview-entry comparison stays and its refusal rate is measured), `WarrenVolumetricSolver.gd` only if `_solve_maze` mishandles non-empty bands; the plot layer only where a measured sloped defect demands it (each such change named); test `tests/test_warren_maze_composition.gd` + `tests/test_warren_maze_plots.gd`.
- Fixtures: `tests/fixtures/warren_stamped_ground.gd` (existing) plus one more sloped profile; ≥2 sloped fixtures × 2 seeds: seal, translate (parcels), compose, fabric-gate; deck datums equal their fronting street bands on slope; house floors follow street bands; route-on-stone 1.000; unroomed share reported (pin at measured + 0.05 for sloped only).
- `solve_selected` maze: on a sloped fixture, the re-solve seals and the entry matches the preview on at least one quarter (report the per-quarter refusal reasons).
- [ ] Commit — `feat(villages): the plot pipeline solves on real ground; maze solve_selected`.

### Task D2: The production site, rendered

**Files:** harness flags only (`tests/harness/warren_spatial_review.gd` `--production-terrain-site --super-x 0 --super-z -1` in maze mode; check what it needs), `VillagePlan`/pin-cache interplay only if it blocks (maze pins carry no attempt — store/consume must round-trip).
- Run the pinned production settlement (world seed 2697992464, super (0,-1) — reported settlement 29bc5c240c52f84a) through the REAL production path in maze mode; render the battery; read the captures; verdict (terraces on real slope? entry lift legal? anything floating?). Measure wall-clock for the full production solve on the terrain worker path (the old searched pipeline took 154-210 s of startup; report the maze number).
- Tests: a composition test pinning the production site seals in maze mode (skip-with-reason if the terrain fixture cannot load headless — say why).
- [ ] Commit — `feat(villages): the production site builds a maze town on real terrain`.

### Phase D exit
- ≥2 sloped fixtures + the production site seal/translate/compose in maze mode; datums follow slope; the battery renders; the production solve time is reported.

# Phase E — Variation

Milestone: noise massif behind the unchanged interface (relief > 0, varied plateaus/terrace ladders, eccentric footprints); carver vertical momentum + post-summit descent; house/roof variation and outcroppings. **Binding visual direction (user, 2026-08-24):** (1) stone faces concentrate in the bottom 1–2 storeys relative to local ground/street level — not everywhere, some areas only (a per-band exterior-stone metric replaces the flat ratio); (2) the city's silhouette falls toward its edges in CLUSTERS — terraced descent, never sheer multi-storey rim walls and never per-column noise; (3) more variation in house and roof types (pitched where free-standing, storey diversity, façade families) and more outcroppings/cantilevers (re-enable the outcropping machinery for maze mode). Exit: Phase B/C metrics hold on the noise corpus; silhouettes measurably differ across seeds; the three directions above are each measured and shown in the battery.

### Task E1: Noise massif — clustered descent to the rim

**Files:** `WarrenMassifBuilder.gd` (behind the unchanged `build(world_seed, ground_bands, profile)` interface: a seeded terraced height field — low-frequency value noise quantized to whole terrace levels (storey multiples), a radial envelope so height falls toward the rim in CLUSTERS (terrace steps of 1-2 storeys, plateaus merged so neighbouring columns cluster rather than dither), core height from the profile as today; determinism and the massif's seal invariants unchanged), `tests/test_warren_massif*.gd` (find the massif's own suite), the plots/composition suites re-measured.
- Exit metrics (pinned, measured-first): rim wall height — for every massif boundary column, `top_at − terrain` ≤ 2 storeys + 1 band (no sheer multi-storey rim walls); terrace cluster count ≥ 2 and mean cluster size ≥ 4 columns per town (clusters, not noise); silhouette variance — max `top_at` and terrace-ladder histograms differ across the 4 planner seeds (report). The 24-seed corpus re-runs (expect a reshuffle; re-pin `CORPUS_SEALED_FLOOR` honestly in either direction WITH a ruling if it drops); the four-colour debug view renders the massif state readably.
- [ ] Commit — `feat(villages): noise massif — clustered terraced descent`.

### Task E2: Carver momentum and descent

**Files:** `WarrenMazeCarver.gd` (spine stride selection gains momentum — a climb continues in its direction unless the terrace forces a turn; after the summit the spine DESCENDS toward the far rim rather than wandering level; alleys prefer contour-following on the new massif), tests (route span, turn count, descent-after-summit fact pinned at measured).
- [ ] Commit — `feat(villages): carver momentum and post-summit descent`.

### Task E3: Variation — roofs, storeys, outcroppings

**Files:** `WarrenPlotPlanner.gd` (wider seeded storey budgets; pitched-preference eligibility naturally broadens on the descending massif — measure the pitched rate and tune the preference probability to land 20-40% of eligible crowns pitched), `WarrenVolumetricSolver.gd` (re-enable the residual outcropping/bracketed-jetty forms for maze plot mass; balconies already advisory — measure), `WarrenPlotReservations.gd` (deck quotas up on the new terraces if cheap), tests (per-town measured counts: pitched roofs, outcroppings/cantilevers, balconies, deck cells — pinned as floors at measured − guard; the user's "more variation" is judged in G).
- [ ] Commit — `feat(villages): roof, storey, and outcropping variation`.

### Task E3b: The two vocabulary gates

E3 measured eight variation changes (storey widenings, outcropping enablements, density levers) and every one died at the same two Phase C composition gates: (a) the partial-plate flat module cannot tile ACROSS LINEAGE BOUNDARIES (C5e's tiling stops at a lineage edge, so a crown shared by a house and its stacked/back-room lineage has an untileable seam), and (b) the cross-lineage 1-cell sliver repair (the roof remainder family) cannot repair a sliver whose neighbour belongs to another lineage. Fixing both unlocks storeys, density and outcroppings at once. Also: `is_bracketed_jetty` is read in three places and set in none — the jetty/outcropping form is dead code; wire it.

**Files:** `WarrenSpatialFabricCompiler.gd` (the two gates: tiling and sliver repair become lineage-agnostic for maze flat crowns — a tile/repair may span lineages when both rooms are maze stamps; audit counts), `WarrenVolumetricSolver.gd` (`_residual_bridge_span` sets `is_bracketed_jetty` where the jetty form actually holds — read the three consumers for the intended semantics; the outcropping enablement re-applied from E3's recorded attempt), `WarrenPlotPlanner.gd` (the storey widenings re-applied from E3's recorded attempts, one at a time), tests.
- Discipline: each re-applied change lands only if the corpus holds 24/24 and no sloped row is lost; measured at each step; every E3-recorded attempt either ships or gets its stop-evidence updated with the post-gate-fix numbers.
- Exit: compact towns ≥ 3 distinct house heights; outcroppings ≥ 1 on at least half the corpus towns (measured-first floors); the variation tables re-printed; renders (seed 12 + 3) read for the verdict.
- [ ] Commit — `feat(villages): cross-lineage plates and slivers; the variation attempts ship`.

### Task E4: Stone concentrates low

**Files:** `WarrenMazeSourcePlan.gd` (a per-band exterior-stone profile relative to the LOCAL street/ground band replaces the flat `exterior_rock_ratio` as the pinned metric: stone faces ≤ 2 storeys above local datum vs above; the raised-shoulder instrumentation (39 columns) becomes a clamp if the measurement says so), the sweep, tests (pin: share of exterior stone faces above 2 storeys over local datum ≤ ceiling at measured + guard, expected to FALL with E1-E3; report the per-band histogram per seed).
- Render seeds 12, 3 + one noise seed; verdict against the user's three directions.
- [ ] Commit — `feat(villages): stone concentrates in the bottom storeys`.

### Phase E exit
- The three user directions measured and met on the battery seeds: no sheer rim walls (E1 pin), stone low (E4 pin), variation counts (E3 pins); corpus re-pinned honestly; silhouettes differ across seeds; solve time regression < 20%.


# Phase F — Mode flip and deletion

Milestone: `GENERATION_MODE` removed (maze is the only path); delete the 12-attempt rotation, ranked variants, courtless fallback, budget slicing, `carve_ranked`, the landmark set beam, `WarrenSolutionPinCache` + salt machinery + VillagePlan integration; retire search-only tests/harnesses. Exit: dead-symbol grep clean; full suite green; in-game cold load near settlements measured.

**Phase C's ≤ 3 s solve target lands here, and it needs its own task.** The deletions above do not pay for it: Phase C measured the hero beam at 24–36 ms and `room_composition` — `WarrenVolumetricSolver._composition_offsets` plus `WarrenRoomCompositionPlanner.solve` — at 632 / 723 / 2370 / 5659 ms on the four planner seeds, superlinear in room count and squarely on the maze path. F's performance task must attack that, with the fabric compile (784 → 2795 ms) second; see *Phase C measured results* for the full stage table.

### Task F1: The mode flip and the great deletion

Maze becomes the ONLY generation path, and everything that existed to serve the search dies. The deletion is output-preserving: the 24-town sweep's per-town summary numbers (sealed count, stone faces, trims, rooms, spans — every printed metric) must be IDENTICAL before and after, in both former modes' invocations collapsed to one.

**The inventory (mapped 2026-08-24; the implementer re-verifies each with a caller grep before deleting):**
- `WarrenTownSolver.gd`: `GENERATION_MODE` / `MODE_ROUTE_FIRST` / `MODE_MASS_FIRST` / `MODE_MAZE` and every branch on them; `feature_quotas_are_advisory()` collapses to true (keep the doc comment's structural-vs-richness distinction where the advisory behaviour lives); the searched entries `solve`, `solve_attempt`, `ranked_candidates`, `infill_variants` and their constants (`MASS_FIRST_EXCAVATION_ATTEMPTS`, `TOPOLOGY_GATE_CANDIDATES`, `MASS_FIRST_ATTEMPT_STRIDE`, `TOPOLOGY_ATTEMPTS`, `COMPOSED_PLAN_FRONTIER`, `INFILL_VARIANT_BUDGETS`) — the maze path never enters them (production is `VillagePlan.gd:71 → VillageWarrenFabricSolver.solve → WarrenVolumetricSolver.solve`'s maze branch). If the whole file empties, delete the file.
- `VillageWarrenFabricSolver.gd`: the `searched` flag and both pin branches (`pin_for`/`store_failure`/`store_progress`/`store_success`, `PRODUCTION_SEARCH_BUDGET_MS` budget slicing, `attempts_tried` resume); `WarrenVolumetricSolver.solve_pinned` (dead from this adapter since D2) and `solve`'s searched branch (`last_search_exhausted`, `last_search_attempts_tried`, the `production_selected_attempt/source_id/variant` audit keys).
- `WarrenSolutionPinCache.gd` + `tests/test_warren_solution_pin_cache.gd` + whatever persistence/salt wiring the cache pulls in (map it from the cache outward, not from "salt" greps — `VillagePlan._roll`'s salt is village seeding, NOT pin machinery; leave it).
- `WarrenVolumetricSolver.gd`: the hero-feature/landmark set beam (bypassed in maze since Phase C), the ranked-variant/courtless-fallback machinery, `_solve_frontier` and the attempt plumbing. `solve_selected` keeps only its maze branch (D1).
- `WarrenBuiltTownSolver.gd`: zero production callers (doc mentions only) — the old searched production path; delete with its exclusive helpers if the caller grep confirms.
- Route-first/mass-first-exclusive stages, each deleted only after a caller grep proves exclusivity (the maze realm comes from `WarrenVolumePublicRealmAdapter`, not these): `WarrenPublicRealmCarver`, `WarrenGroundArcadeSolver`, `WarrenElevatedFrontageSolver`, `WarrenParcelizer`, `WarrenVolumeEnvelope`, `WarrenExcavationCarver`, `WarrenMarketSolver` (check), and any stage `phase-c-map.md` marks searched-only. Shared code (`_partition_rooms`, the compiler, the assembler) stays.
- `WarrenMassifBuilder.gd`: the `is_maze_mode()` key and the legacy flat profile die; the terraced field is the only field (E1's ruling named this removal point).
- `SettlementReliefPlan.gd:156`: the mass-first check resolves to its maze value.
- Tests/harnesses retired with the code: `test_warren_generation_mode.gd` (its two pre-existing reds die with it), `test_warren_excavation_adapter.gd` (5/11 pre-existing), `test_warren_search_pregates.gd`, `test_warren_volume.gd`'s searched-entry tests, mass-first tests inside `test_warren_solid_partitioner.gd` (shared-partitioner tests stay), `warren_mass_first_preview/report.gd`, `probe_warren_attempt_layout.gd`, and any harness whose subject is deleted. The sweep's `--mode`/`--constructive` flag pair collapses to one path (keep the flag as an accepted no-op or drop it; pick one and say so). `test_warren_massif.gd`'s pre-existing `MIN_CORE_BANDS` red is RESOLVED here one way or the other: it either tested the legacy profile (dies with it) or it is a real terraced-field miss (fix it) — no tolerated red survives F1.
- The stale "NOT production-ready … seals 0 of 9" comment block at `WarrenTownSolver.gd:98-103` dies with the enum. C3's deferred shared stamp helper: only if it falls out free; do not chase it.

**Discipline:** deletions land in reviewable slices (one commit per coherent subsystem is fine; a single 10k-line commit is not); after each slice the maze suites stay green (composition 46/46, plots 38/38, carver 12/12, compiler 11/11, settlement 42/42); after the last slice the FULL test directory runs green with zero tolerated reds, the 24-town sweep holds 24/24 with per-town numbers identical to E4's record (then re-fingerprint the corpus gate), and the four planner towns' audits are unchanged. Dead-symbol grep clean: `GENERATION_MODE|MODE_ROUTE_FIRST|MODE_MASS_FIRST|route_first|mass_first|ranked_candidates|solve_attempt|solve_pinned|WarrenSolutionPinCache|WarrenBuiltTownSolver|WarrenExcavationCarver` (and each deleted class name) appears nowhere under `scripts/` or `tests/` except historical docs; deleted `class_name` scripts need the one-shot `--import` and their `.uid` files removed.
- Exit: production (`VillagePlan` → `VillageWarrenFabricSolver`) generates maze towns with no mode anywhere; line counts reported (expect several thousand deleted); the production settlement 29bc5c240c52f84a still builds its town with an unchanged audit.
- [ ] Commit(s) — `feat(villages)!: maze is the only path — delete the searched pipeline`.

### Task F2: Solve time — room composition

The ≤ 3 s target, attacked at the measured hotspot. C6's stage table (four planner seeds 12/compact, 4/compact, 3/standard, 9/standard): totals 2442 / 3935 / 5554 / 10383 ms; `room_composition` (`WarrenVolumetricSolver._composition_offsets` + `WarrenRoomCompositionPlanner.solve`) 632 / 723 / 2370 / 5659 ms — 43–76 % of composition and SUPERLINEAR in room count (60 → 98 rooms is 632 → 5659 ms); fabric compile second (784 → 2795 ms); C5b's deferred "shell derived 4× per solve"; E3b's sweep slowdown (50–70 % over E3, storeys+repair paths). Work on the post-F1 tree only.

**Files:** `WarrenVolumetricSolver.gd` (`_composition_offsets` — profile WHY it is superlinear: candidate-offset enumeration per room against all placed rooms suggests an index/occupancy-grid fix, but measure first with `tests/harness/warren_maze_stage_probe.gd` / `warren_solve_profile.gd` before touching anything), `WarrenRoomCompositionPlanner.gd`, `WarrenSpatialFabricCompiler.gd` (compile second; the 4× shell derivation), the stage probe (extend it to break `room_composition` into its inner loops if the split is not already visible).
- **Discipline (binding):** every optimisation is OUTPUT-IDENTICAL — the four planner towns' audits and the 24-town sweep's per-town numbers are byte-for-byte unchanged after every commit; determinism preserved (no unordered-dict iteration order leaks into output); algorithmic fixes preferred over caches, and any cache must be per-solve (no cross-solve state — the terrain worker rules from the water/terrain work apply: no RenderingServer, no globals that outlive a solve). A commit that changes any town is a defect regardless of speed.
- Exit metrics: all four planner seeds ≤ 3000 ms end-to-end (the 9/standard 10383 → ≤ 3000 is the real bar); `PLANNER_SOLVE_MS_CEILING` re-pinned at new-measured × 1.5; sweep wall time reported against E4's 177 s record (expect a large recovery; pin nothing, report honestly); the composition suite stays under its ~4 min budget.
- In-game cold load: the production settlement 29bc5c240c52f84a at super (0,-1) — measure end-to-end from the game (D2 baseline 4.1 s pre-E; use the HOME-isolated launch harness from the profiling work, GUI, not --headless), report before/after.
- [ ] Commit — `perf(villages): room composition off the superlinear path`.

### Phase F exit
- No `GENERATION_MODE` anywhere; full suite green with zero tolerated reds; corpus 24/24 with towns byte-identical through F1 and byte-identical through F2; all four planner seeds ≤ 3 s; cold load measured in-game; line-count delta reported.

# Phase G — Visual gate

The M8-style battery (entrance, market, alleys both ways, courtyard, tunnel, skywalk/bridge, roofline, orbit) over the corpus, presented for the user's judgment against his three directions (stone low, clustered fall-off, variation/outcroppings). Originally scoped to run before F; the user's explicit ordering ("continue to C, D, E F, G") puts it after, and the branch stays unmerged until he reviews, so nothing F deletes is unrecoverable. G also carries the open questions ledgered for him: rail the trimmed stone plateaus or leave them as terraces; the outcropping/notch design conversation (carved-solid towns have no voids — oriel bays, street jetties and bridge rooms are the current equivalents); compact grade-2 terrace steps; the two flat-scaffold composition gates carried from Phase C if they still reproduce on the final corpus.
