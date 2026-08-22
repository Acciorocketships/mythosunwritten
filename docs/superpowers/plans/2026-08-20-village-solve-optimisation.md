# Village Solve Optimisation Implementation Plan

> **SUPERSEDED (2026-08-21).** History only — do not execute. The single live plan is `docs/superpowers/plans/2026-08-21-maze-town-master-plan.md`.


> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cut one production village solve from a measured 28.5 s (best case) / 85.4 s (failing case) toward the ~2 s target, by deleting provably-wasted search work rather than by weakening any gate.

**Architecture:** Production still runs a three-level generate-and-test search (attempt bore → ranked candidate → composition → fabric gate). This plan removes waste at each level in measured order: stop searching once a town has sealed, bound the landmark set beam to the sets actually tried, shrink the bore's ranked carve corpus, and instrument the unattributed core of composition so the remaining 2.6 s can be attacked with evidence. It changes no gate and no accepted output.

**Tech Stack:** Godot 4.5 / GDScript, GUT test framework, existing `SKYWALK_TIMING` trace instrumentation.

**Spec:** This plan's evidence base is the measured profile below, reproduced with `tests/harness/warren_solve_profile.gd` (added alongside this plan). Companion design docs: `2026-08-16-maze-town-carver-refactor.md` (the strategic fix), `2026-08-16-terrain-optimisation-roadmap.md` (sub-project ordering).

## Global Constraints

- No gate may be weakened, removed, or made advisory to gain speed. Every optimisation must be output-identical or strictly-better-quality; a faster solve that seals a worse town is a failed task.
- Determinism is non-negotiable: `deterministic_signature()` must match across processes before and after every task. Dictionary iteration order must never leak into a result.
- The worker pipeline creates no Nodes, meshes, materials, or server-backed resources.
- `WarrenSolutionPinCache.GENERATION_SALT` must be bumped in the final task of any change that alters which candidate seals, or stale failure pins will suppress newly-fixed seeds.
- Measure before and after every task with the same harness invocation. A task that does not move its stated number is reverted, not kept "because it should help".

## Measured baseline (2026-08-20, commit 2bba69b)

Reproduce:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryko/story -s res://tests/harness/warren_solve_profile.gd -- --city-seed 166029932451774690 --scale compact
```

**Case A — compact, seals, 28.5 s** (city seed `166029932451774690`; the production village at super cell (0,-1) of world seed 2697992464):

| stage | runs | total | mean | accepted |
|---|---|---|---|---|
| bore (`frontier_attempt`) | 1 | 0.8 s | 0.8 s | — |
| composition (`partition_spatial`) | 6 | 22.9 s | 3.8 s | 3 |
| fabric gate (`partition_fabric`) | 3 | 4.6 s | 1.5 s | 1 |

12.7 s (45%) went into candidates that were rejected. The **first sealing fabric was the 2nd fabric call, after the 4th composition** — the remaining 2 compositions and 1 fabric ran *after* a good town already existed.

**Case B — standard, exhausts and fails, 85.4 s** (city seed `6357506428441529412`):

| stage | runs | total | mean |
|---|---|---|---|
| bore | 12 | 10.4 s | 0.87 s |
| composition | 8 | 74.8 s | 9.3 s |
| fabric gate | 0 | 0 s | — |

**11 of 12 bores returned zero candidates**, 9 of them failing the same cheap topology gate (`ramp transitions 0 < 1`). All 85.4 s was discarded.

**The landmark set beam is the dominant sub-cost and scales superlinearly.** Note the `SKYWALK_TIMING landmark_*` timers are *cumulative from one stage start*, so they nest rather than add; subtracting gives:

| scale | landmark candidates | sets built | sets ever tried | set-build cost |
|---|---|---|---|---|
| compact | 51 | 98 | ≤ 12 | ~0.35 s |
| standard | 116 | 334–384 | ≤ 12 | **~6.3 s** |

2.3× the candidates produces 18× the set-build cost, and `MAX_LANDMARK_SET_ATTEMPTS` is 12 in both cases — **97% of the sets built are never looked at.** On Case B this is ~50 s of the 85 s solve.

`landmark_sets_by_corpus` (`WarrenVolumetricSolver.gd:1354`) exists to avoid this but is declared inside the market-candidate loop of `_partition_rooms`, so it cannot survive across compositions. Every one of the 14 measured calls logged `cache=false`.

### Honest reachability of the ~2 s target

Search pruning alone cannot reach 2 s. Even a perfect search that composes exactly one candidate costs **~5.3 s compact** (3.8 s composition + 1.5 s fabric) and **~9.3 s standard** today. Tasks 1–3 target 28.5 s → ~15 s and 85.4 s → ~25 s. Reaching ~2 s additionally requires Task 4's findings to shrink a single composition below ~1 s, and ultimately the maze carver (M3–M5 of `2026-08-16-maze-town-carver-refactor.md`), which removes the search rather than pruning it. **This plan does not claim to reach 2 s; it makes the existing pipeline tolerable and produces the evidence needed to decide whether to finish the carver instead.**

## File Structure

| File | Responsibility |
|---|---|
| `tests/harness/warren_solve_profile.gd` | Cold-solve profiler (already written). Extended in Task 4 with a per-stage composition report. |
| `scripts/terrain/features/villages/fabric/WarrenVolumetricSolver.gd` | Owns the search. Modified in Tasks 1, 2, 4. |
| `scripts/terrain/features/villages/fabric/WarrenTownSolver.gd` | Owns the bore and `GENERATION_MODE`. Modified in Task 3. |
| `tests/test_warren_volumetric_solver.gd` | Search behaviour tests. Extended in Tasks 1, 2. |
| `tests/test_warren_town_solver.gd` | Bore/massif tests. Extended in Task 3. |

---

### Task 1: Accept the first sealed town instead of exhausting the ranked list

**Why:** `prefer_route_court` is `profile != null and not profile.requires_elevated_courtyard`, which is **true for compact and standard** (both pass `false` for `p_requires_elevated_courtyard` in `WarrenVillageScaleProfile.for_id`). So for the two most common scales, a fully sealed town with no route-connected rooftop court is stashed as `courtless_fallback_plan` and the search *continues through every remaining ranked candidate*, only using the fallback after exhausting them. On Case A this burned ~8.8 s of 28.5 s.

**This post-filter is pure redundancy.** `_precomposition_quality_score` (`WarrenVolumetricSolver.gd:834-853`) **already ranks on court supply**:

```gdscript
	+ minf(24.0, float(audit.get("broad_rooftop_court_cell_count", 0))) * 4.0 \
	+ (180.0 if int(audit.get("broad_rooftop_court_cell_count", 0)) \
		>= 12 else 0.0) \
```

Court-likely candidates are therefore *already tried first*. The exhaustive fallback then additionally refuses to accept a courtless winner until every remaining candidate has been composed — paying full composition cost to re-discover an ordering the ranking has already applied. No new ranking term is needed; the fix is a deletion. This is the same change already made for enclosure and sightline metrics in commits `92f6b46` and `fb39622`.

**Files:**
- Modify: `scripts/terrain/features/villages/fabric/WarrenVolumetricSolver.gd:355-380` (the `prefer_route_court` branch in `_solve_frontier`) and the post-loop `courtless_fallback_plan` block
- Test: `tests/test_warren_volumetric_solver.gd`

**Interfaces:**
- Consumes: `_ranked_precomposition_variants(frontier, program) -> Array[Dictionary]`, each entry `{volume, variant, audit, variant_rank, score}`, already sorted by `_precomposition_quality_score`.
- Produces: no signature changes. `_solve_frontier` returns on the first sealed candidate; the `courtless_fallback_plan` / `_fabric` / `_volume` / `_audit` / `_variant` / `_rank` locals, the deadline-fallback block at `:298-308`, and the post-loop fallback block are all deleted. `route_court_variant_fallback_used` remains in the audit and is always `false`.

- [ ] **Step 1: Write the failing test**

Add to `tests/test_warren_volumetric_solver.gd`:

```gdscript
func test_search_returns_the_first_sealed_town_without_exhausting_the_list() -> void:
	# A courtless-but-sealed compact town is a valid production result. The
	# elevated-court preference is a ranking term, so the search must not keep
	# composing candidates after one has already sealed every gate.
	var program := SettlementFabricProgram.compile(
		EnvironmentCatalog.load_default())
	assert_not_null(program)
	if program == null:
		return
	var profile := WarrenVillageScaleProfile.for_id(
		WarrenVillageScaleProfile.COMPACT)
	assert_false(profile.requires_elevated_courtyard,
		"compact is the scale this preference silently exhausted")
	var plan := WarrenVolumetricSolver.solve(166029932451774690, {}, program,
		profile)
	assert_not_null(plan, WarrenVolumetricSolver.last_failure)
	if plan == null:
		return
	assert_false(bool(plan.audit.get("route_court_variant_fallback_used", false)),
		"a sealed town must be returned directly, never as an exhausted fallback")
	assert_lte(int(plan.audit.get("route_court_variant_probe_count", 99)), 4,
		"the search must stop at the first sealed candidate (measured: it " \
		+ "sealed on probe 4 but ran 6 before this change)")
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryko/story -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_warren_volumetric_solver.gd -gunit_test_name=test_search_returns_the_first_sealed_town_without_exhausting_the_list -gexit
```

Expected: FAIL — `route_court_variant_probe_count` is 6 and `route_court_variant_fallback_used` is `true`.

- [ ] **Step 3: Confirm the ranking already carries the preference**

Read `_precomposition_quality_score` at `WarrenVolumetricSolver.gd:834-853` and confirm the two `broad_rooftop_court_cell_count` terms are present and unmodified. **Do not add a ranking term** — the preference already exists there. If those terms have been removed by a later change, stop and re-plan: deleting the post-filter without them would drop the court preference entirely.

- [ ] **Step 4: Return on the first seal**

In `_solve_frontier`, replace the `prefer_route_court` stash-and-continue branch with a direct return, and delete the now-unreachable `courtless_fallback_plan` / `courtless_fallback_fabric` / `courtless_fallback_volume` / `courtless_fallback_audit` / `courtless_fallback_variant` / `courtless_fallback_rank` locals and the post-loop fallback block:

```gdscript
			else:
				# Enclosure and size metrics (sightlines, overhead, alley ratio,
				# room count) are guidance carried in the audit and the ranking,
				# never a reason to discard a compiled town here. The elevated
				# court is the same kind of preference: ranked earlier, never
				# searched for after a town has sealed.
				var finalized := _finalize_ranked_candidate(volume, variant,
					construction_program, ranked.audit as Dictionary, plan,
					fabric)
				if finalized != null:
					finalized.audit["route_court_variant_probe_count"] = \
						partition_attempt_count
					finalized.audit["route_court_variant_fallback_used"] = false
					return finalized
```

- [ ] **Step 5: Run the test to verify it passes**

Run the same command as Step 2. Expected: PASS.

- [ ] **Step 6: Verify no gate regressed and measure the win**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryko/story -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_warren_spatial_fabric_compiler.gd -gexit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryko/story -s res://tests/harness/warren_solve_profile.gd -- --city-seed 166029932451774690 --scale compact
```

Expected: 11/11 pass; `PROFILE solve total_ms` drops from ~28500 to ~20000, `sealed=true`.

- [ ] **Step 7: Commit**

```bash
git add tests/test_warren_volumetric_solver.gd scripts/terrain/features/villages/fabric/WarrenVolumetricSolver.gd
git commit -m "perf(villages): the elevated court is a ranking term, not an exhaustive search"
```

---

### Task 2: Bound the landmark set beam to the sets actually tried

**Why:** The measured hotspot. `_landmark_candidate_sets` is called once per count in `range(scale_profile.landmark_range.y, target_landmarks - 1, -1)` and its results are concatenated, ranked, and then **only the first `MAX_LANDMARK_SET_ATTEMPTS` (12) are used**. Standard builds 334–384 sets at ~6.3 s to use 12; compact builds 98 at ~0.35 s to use 12. Across Case B's 8 compositions this is ~50 s of an 85 s solve.

**Files:**
- Modify: `scripts/terrain/features/villages/fabric/WarrenVolumetricSolver.gd:2758` (`_landmark_candidate_sets`), `:2794` (`_landmark_candidate_set_beam`), `:1444-1470` (the enumerate-then-rank block in `_partition_rooms`)
- Test: `tests/test_warren_volumetric_solver.gd`

**Interfaces:**
- Consumes: `_landmark_candidate_sets(candidates: Array[Dictionary], world_seed: int, target_count: int) -> Array[Dictionary]`, `_rank_landmark_sets_for_skywalks(sets: Array[Dictionary], corpus, target_skywalks) -> void` (ranks in place).
- Produces: `_landmark_candidate_sets` gains a fourth parameter `retain_limit: int = -1` (`-1` retains everything, preserving every existing caller). `_landmark_candidate_set_beam` gains the same parameter and stops expanding once `retain_limit` complete sets survive at the current rank.

- [ ] **Step 1: Write the failing test**

Add to `tests/test_warren_volumetric_solver.gd`:

```gdscript
func test_landmark_set_enumeration_honours_a_retain_limit() -> void:
	# 97% of enumerated landmark sets were discarded unread: standard built
	# 334-384 to try 12. The bounded enumeration must return the same leading
	# sets the unbounded one would, in the same order, for a fraction of the work.
	var program := SettlementFabricProgram.compile(
		EnvironmentCatalog.load_default())
	assert_not_null(program)
	if program == null:
		return
	var profile := WarrenVillageScaleProfile.for_id(
		WarrenVillageScaleProfile.STANDARD)
	var frontier := WarrenTownSolver.mass_first_attempt_frontier(
		6357506428446529427, 5, {}, profile)
	assert_false(frontier.is_empty(), WarrenTownSolver.last_failure)
	if frontier.is_empty():
		return
	var candidates := WarrenVolumetricSolver \
		._landmark_candidates_for_profile_probe(frontier[0], program)
	assert_gt(candidates.size(), 12,
		"this fixture must have a corpus large enough for the beam to blow up")
	var unbounded := WarrenVolumetricSolver._landmark_candidate_sets(
		candidates, 6357506428446529427, 5)
	var bounded := WarrenVolumetricSolver._landmark_candidate_sets(
		candidates, 6357506428446529427, 5,
		WarrenVolumetricSolver.MAX_LANDMARK_SET_ATTEMPTS)
	assert_lte(bounded.size(), WarrenVolumetricSolver.MAX_LANDMARK_SET_ATTEMPTS)
	assert_gt(unbounded.size(), bounded.size(),
		"the unbounded enumeration is the thing we are avoiding")
	for index in bounded.size():
		assert_eq(
			WarrenVolumetricSolver._landmark_set_diagnostic_key(
				(bounded[index] as Dictionary).get("reservations", []) \
					as Array[Dictionary]),
			WarrenVolumetricSolver._landmark_set_diagnostic_key(
				(unbounded[index] as Dictionary).get("reservations", []) \
					as Array[Dictionary]),
			"bounding may not change which sets are tried, only how many " \
			+ "are built")
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryko/story -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_warren_volumetric_solver.gd -gunit_test_name=test_landmark_set_enumeration_honours_a_retain_limit -gexit
```

Expected: FAIL — `_landmark_candidate_sets` takes 3 arguments, and the `_landmark_candidates_for_profile_probe` helper does not exist.

- [ ] **Step 3: Add the test-only candidate probe helper**

The test needs the landmark corpus without running a whole composition. Add next to `_landmark_candidate_corpus_key`:

```gdscript
static func _landmark_candidates_for_profile_probe(volume: WarrenVolumePlan,
		construction_program: SettlementFabricProgram) -> Array[Dictionary]:
	## Test/profiling seam: the landmark corpus for one source volume without
	## paying for a whole composition. Production always reaches this corpus
	## through _partition_rooms; this exists so the beam's cost and ordering
	## can be measured directly.
	var out: Array[Dictionary] = []
	var massif := volume.mass_context.get(&"massif") as WarrenMassif
	if massif == null or not massif.is_sealed():
		return out
	var bounds := _grid_bounds(massif)
	var grid := WarrenSpatialGrid.new(bounds.minimum, bounds.size)
	if not grid.is_valid() or not _project_massif(grid, massif):
		return out
	if _carve_public_volume(grid, volume).is_empty():
		return out
	var plan := _preplan_spatial_landmarks(grid, volume, construction_program,
		{}, {}, [] as Array[Dictionary], {})
	out.assign(plan.get("candidates", []) as Array)
	return out
```

- [ ] **Step 4: Thread the retain limit through enumeration**

Change the signature and pass it to the beam:

```gdscript
static func _landmark_candidate_sets(candidates: Array[Dictionary],
		world_seed: int, target_count: int = 2,
		retain_limit: int = -1) -> Array[Dictionary]:
```

and at the `target_count > 3` branch:

```gdscript
	if target_count > 3:
		out = _landmark_candidate_set_beam(candidates, world_seed,
			target_count, retain_limit)
```

In `_landmark_candidate_set_beam`, accept `retain_limit: int = -1` and, after each rank's survivors are scored and sorted, truncate when the limit is set:

```gdscript
		if retain_limit >= 0 and survivors.size() > retain_limit:
			survivors.resize(retain_limit)
```

- [ ] **Step 5: Run the test to verify it passes**

Run the same command as Step 2. Expected: PASS.

- [ ] **Step 6: Use the limit from the composition call site**

In `_partition_rooms`, pass the limit so production stops building unread sets. The concatenation across counts must still be able to fill 12 from the richest count first:

```gdscript
				for landmark_count in range(scale_profile.landmark_range.y,
						target_landmarks - 1, -1):
					if landmark_sets.size() >= MAX_LANDMARK_SET_ATTEMPTS:
						break
					landmark_sets.append_array(_landmark_candidate_sets(
						landmark_candidates, volume.world_seed, landmark_count,
						MAX_LANDMARK_SET_ATTEMPTS - landmark_sets.size()))
```

- [ ] **Step 7: Verify the sealed output is unchanged and measure**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryko/story -s res://tests/harness/warren_solve_profile.gd -- --city-seed 166029932451774690 --scale compact
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryko/story -s res://tests/harness/warren_solve_profile.gd -- --city-seed 6357506428441529412 --scale standard --no-rank-probe
```

Expected: compact still `sealed=true` and its selected attempt/probe count unchanged from Task 1; standard `total_ms` drops from ~85000 to ~35000. If the compact town's `deterministic_signature()` changes, the truncation reordered the beam — fix the ordering rather than accepting the new town.

- [ ] **Step 8: Commit**

```bash
git add tests/test_warren_volumetric_solver.gd scripts/terrain/features/villages/fabric/WarrenVolumetricSolver.gd
git commit -m "perf(villages): build only the landmark sets the search will actually try"
```

---

### Task 3: Shrink the bore's ranked carve corpus

**Why:** The bore is ~870 ms × 12 attempts = 10.4 s, **12% of the failing solve**. Measured directly on 2026-08-20:

```
massif_build_ms=5   massif_build_ms=4   massif_build_ms=5
carve_ranked_ms=1048  count=5
```

**A memoised massif is a falsified hypothesis — do not implement it.** `WarrenMassifBuilder.build` costs **5 ms**; caching it across 12 attempts saves ~55 ms of an 85 s solve. The source comment at `WarrenTownSolver.gd:105-107` already said so and it is correct. Essentially the entire bore is `WarrenExcavationCarver.carve_ranked`, which runs a 256-bore search to keep 5–8 ranked survivors, of which `_gate_preferred_volume` uses the **first one that passes the topology gate**.

Also already done, and not to be re-implemented: the topology gate runs at `WarrenTownSolver.gd:592`, *before* `WarrenGroundArcadeSolver.extend_preserving_topology` at `:598`; and `_gate_preferred_volume` (`:620-633`) already short-circuits on the first passing excavation, walking all 8 only when none pass.

So the only real lever here is `TOPOLOGY_GATE_CANDIDATES` (8) and the carver's internal 256-bore corpus. **Do this task only after Tasks 1, 2 and 4** — at 12% of the cost it is not worth touching while composition is 87%.

**Files:**
- Modify: `scripts/terrain/features/villages/fabric/WarrenTownSolver.gd:118` (`TOPOLOGY_GATE_CANDIDATES`)
- Test: `tests/test_warren_town_solver.gd`

**Interfaces:**
- Consumes: `WarrenExcavationCarver.carve_ranked(seed: int, massif: WarrenMassif, profile: WarrenVillageScaleProfile, keep: int) -> Array[WarrenExcavation]`.
- Produces: no signature changes. `TOPOLOGY_GATE_CANDIDATES` becomes whatever value the sweep in Step 1 shows is sufficient.

- [ ] **Step 1: Measure how deep the gate actually reaches**

Add a temporary counter to `_gate_preferred_volume` recording the index of the excavation that passed, then run the corpus sweep:

```gdscript
	for excavation_index in excavations.size():
		var excavation := excavations[excavation_index]
		var volume := WarrenExcavationVolumeAdapter.to_volume_plan(massif,
			excavation)
		if volume == null:
			continue
		_attach_scale_profile(volume, profile)
		if WarrenPublicRealmCarver.passes_topology_gate(volume):
			print("GATE_DEPTH index=%d of=%d" % [excavation_index,
				excavations.size()])
			return volume
		if fallback == null:
			fallback = volume
```

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryko/story -s res://tests/harness/warren_maze_mode_sweep.gd -- --seeds 1,2,3,4,5,6,7,8,9 --mode route_first 2>&1 | grep GATE_DEPTH | sort | uniq -c
```

- [ ] **Step 2: Lower the constant to the measured depth and re-verify the corpus**

If every passing bore is found at index ≤ N, set `TOPOLOGY_GATE_CANDIDATES := N + 1`. Remove the temporary print. Then confirm the seal rate is unchanged:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryko/story -s res://tests/harness/warren_maze_mode_sweep.gd -- --seeds 1,2,3,4,5,6,7,8,9 --mode route_first
```

Expected: `SWEEP RESULT ... sealed=` is **not lower** than the pre-change baseline. If it drops, revert — the deeper candidates were load-bearing.

- [ ] **Step 3: Commit**

```bash
git add scripts/terrain/features/villages/fabric/WarrenTownSolver.gd tests/test_warren_town_solver.gd
git commit -m "perf(villages): keep only the ranked bores the topology gate reaches"
```

---

### Task 4: Instrument the unattributed core of composition

**Why:** After Tasks 1–3, composition remains the dominant cost and ~2.6 s of each compact composition (3.8 s total, ~1.2 s traced) is **unattributed**. No further optimisation should be guessed at. This task adds the stage timers that turn the remaining cost into evidence, and reports them from the profiler.

**Files:**
- Modify: `scripts/terrain/features/villages/fabric/WarrenVolumetricSolver.gd` (`from_volume`, `_partition_rooms`)
- Modify: `tests/harness/warren_solve_profile.gd`

**Interfaces:**
- Consumes: `WarrenVolumetricSolver.diagnostic_trace_skywalk_timing : bool`.
- Produces: new `SKYWALK_TIMING composition_stage name=<stage> ms=<int>` lines with **non-cumulative, per-stage** durations for `project_massif`, `carve_public_volume`, `partition_parcels`, `partition_rooms`, and `finalize`. The existing cumulative `landmark_*` timers are left alone so historical logs stay comparable.

- [ ] **Step 1: Add per-stage timers to `from_volume`**

Around each existing stage in `from_volume` (lines 868–891 and following), record and emit an independent duration:

```gdscript
	var stage_started := Time.get_ticks_msec()
	var bounds := _grid_bounds(massif)
	var grid := WarrenSpatialGrid.new(bounds.minimum, bounds.size)
	if not grid.is_valid() or not _project_massif(grid, massif):
		return null
	if diagnostic_trace_skywalk_timing:
		print("SKYWALK_TIMING composition_stage name=project_massif ms=",
			Time.get_ticks_msec() - stage_started)
	stage_started = Time.get_ticks_msec()
	var route_floors := _carve_public_volume(grid, volume)
	if route_floors.is_empty():
		return null
	if diagnostic_trace_skywalk_timing:
		print("SKYWALK_TIMING composition_stage name=carve_public_volume ms=",
			Time.get_ticks_msec() - stage_started)
	stage_started = Time.get_ticks_msec()
	var parcel_plan := WarrenTownSolver.partition_parcels(volume,
		partition_variant, construction_program)
	if parcel_plan == null:
		last_failure = WarrenTownSolver.last_partition_failure
		return null
	if diagnostic_trace_skywalk_timing:
		print("SKYWALK_TIMING composition_stage name=partition_parcels ms=",
			Time.get_ticks_msec() - stage_started)
```

Add the same pattern around the `_partition_rooms` call and the finalisation that follows it, using `name=partition_rooms` and `name=finalize`.

- [ ] **Step 2: Report the stages from the profiler**

In `tests/harness/warren_solve_profile.gd`, after the solve, the caller aggregates the printed lines. Add a closing hint so the log is self-describing:

```gdscript
	print("PROFILE note composition_stage lines are PER-STAGE (not cumulative); " \
		+ "landmark_* lines remain cumulative from one stage start")
```

- [ ] **Step 3: Run the profiler and confirm the stages account for composition**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryko/story -s res://tests/harness/warren_solve_profile.gd -- --city-seed 166029932451774690 --scale compact
```

Expected: for each `partition_spatial` line, the five `composition_stage` durations preceding it sum to within ~10% of it. If they do not, a stage is missing — add it before drawing any conclusion.

- [ ] **Step 4: Record the findings in this plan**

Append a "Composition stage breakdown (measured)" section to this file with the per-stage table, then decide the next task from the evidence rather than from intuition.

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/features/villages/fabric/WarrenVolumetricSolver.gd tests/harness/warren_solve_profile.gd docs/superpowers/plans/2026-08-20-village-solve-optimisation.md
git commit -m "perf(villages): per-stage composition timers and measured breakdown"
```

---

### Task 5: Re-measure, bump the salt, and decide search-vs-carver

**Files:**
- Modify: `scripts/terrain/features/villages/fabric/WarrenSolutionPinCache.gd:16` (`GENERATION_SALT`)
- Modify: `docs/superpowers/plans/2026-08-20-village-solve-optimisation.md`
- Modify: `docs/superpowers/plans/2026-08-16-terrain-optimisation-roadmap.md`

- [ ] **Step 1: Run the full village test suite**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryko/story -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_warren_spatial_fabric_compiler.gd -gexit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryko/story -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_settlement_fabric.gd -gexit
```

Expected: 11/11 and 42/42. Note that `test_warren_volumetric_solver.gd`'s `test_seed_seven_becomes_a_sealed_fine_grid_town` is a **pre-existing failure** (verified at `2bba69b` and its parent) and takes 25–35 minutes; it is not a regression from this plan, but re-check that its failure *reason* is unchanged.

- [ ] **Step 2: Re-measure both profile cases**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryko/story -s res://tests/harness/warren_solve_profile.gd -- --city-seed 166029932451774690 --scale compact
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryko/story -s res://tests/harness/warren_solve_profile.gd -- --city-seed 6357506428441529412 --scale standard --no-rank-probe
```

Record both `total_ms` against the 28532 / 85392 baseline in this plan.

- [ ] **Step 3: Bump the generation salt**

Tasks 1 and 2 can change which candidate seals, so stale failure pins must not suppress newly-fixed seeds:

```gdscript
const GENERATION_SALT := "2026-08-20a"
```

- [ ] **Step 4: Write the verdict**

Append to this plan: the measured before/after, and an explicit recommendation on whether the remaining gap to ~2 s is better closed by continuing to optimise the search or by finishing the maze carver's M3–M5 (which removes the search entirely and targets ≤10 s by construction with 9/9 seal). Update the roadmap's sub-project table with the new numbers.

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/features/villages/fabric/WarrenSolutionPinCache.gd docs/superpowers/plans/2026-08-20-village-solve-optimisation.md docs/superpowers/plans/2026-08-16-terrain-optimisation-roadmap.md
git commit -m "perf(villages): record measured solve optimisation and bump the generation salt"
```

---

## MODE_MAZE: wired, measured, not viable (2026-08-20)

`MODE_MAZE` is now implemented end to end — `WarrenTownSolver.MODE_MAZE` plus
`WarrenVolumetricSolver._solve_maze`, which runs massif → `WarrenMazeCarver.carve`
→ `WarrenMazeVolumeAdapter.to_volume_plan` → one `from_volume` → one fabric gate,
with no attempt rotation and no ranked corpus. `solve_pinned` re-solves directly
in this mode because a deterministic single source carries no pin information.

**It seals 0 of 9 corpus seeds**, so `GENERATION_MODE` remains `MODE_ROUTE_FIRST`.
Re-measure with:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryko/story -s res://tests/harness/warren_maze_mode_sweep.gd -- --seeds 1,2,3,4,5,6,7,8,9 --mode maze
```

| failure | seeds | scale | milestone |
|---|---|---|---|
| `courtyard partition forms only 0 exact room sides` | 1, 5, 6, 7 | grand/large | M3 — courtyard stamp |
| `hero-feature beam found court=0, 0 landmarks, and 0 skywalks` | 2, 3, 4 | standard/compact | M3 — landmark + occupied-link stamps |
| `retained 2 unsupported room transitions` | 8 | standard | M4 — partition ownership (0.394 vs 0.85) |
| `only 0 balconies across 0 buildings fit` | 9 | standard | M3/M6 |

The failures are all *downstream contract* rejections, not integration errors —
the maze source itself builds in ~150–300 ms, which is the speed the whole
solid-first thesis promises. **The blocking work is M3's three missing stamps
(courtyard, landmark, occupied-link) plus M4 ownership**, in that order: four of
the nine seeds die on the courtyard stamp alone.

Note the two slow failures (seeds 2 and 8, ~35 s each) are seeds where the maze
source passed and composition ran before rejecting — they will get *faster*, not
slower, once the stamps exist, because the search that currently retries around
them does not exist in this mode.

### One-pass gate policy (2026-08-20, second pass)

Measured with `tests/harness/warren_maze_stage_probe.gd`: **every one of the 9
seeds builds a real town and is then discarded.**

```
seed=1 grand    massif=ok carve=ok adapt=ok parcels=54  compose=REJECTED
seed=5 large    massif=ok carve=ok adapt=ok parcels=35  compose=REJECTED
seed=8 standard massif=ok carve=ok adapt=ok parcels=25  compose=REJECTED
seed=4 compact  massif=ok carve=ok adapt=ok parcels=18  compose=REJECTED
```

18–54 building parcels exist before rejection. The carver is not failing to
build; composition is throwing built towns away over missing richness.

`WarrenTownSolver.feature_quotas_are_advisory()` implements the correct policy:
in a no-retry mode a quota shortfall must be an audit fact, not a rejection,
because there is no second candidate — rejecting yields no village at all.
Applied to four gates (courtyard parcel sides, covered-market requirement,
hero-feature quotas, balcony quota), each recording into
`WarrenVolumetricSolver.last_advisory_shortfalls`. Structural correctness
(unsupported rooms, envelope intersection) stays fatal in every mode.

**Remaining blocker — the joint hero-feature beam is all-or-nothing.**
`market_reservation` is only assigned inside the beam's success branch, so a
town that satisfies none of court/landmarks/skywalks commits *nothing*, not
even its market. A best-effort fallback to the `optional_absent` sentinels was
added and does execute, but ~27 later `return {}` sites in `_partition_rooms`
each assume a committed hero-feature set. Making them tolerate an absent set is
the real M3/M5 work.

Debuggability fixed on the way: five `return null` sites in `from_volume`, one
in `_backfill_residual_rooms`, and a `_partition_rooms` entry breadcrumb now
carry reasons. Before this, a rejected town reported an empty string — which is
how the market blocker stayed hidden.

**Status: still 0/9 sealed. `GENERATION_MODE` stays `MODE_ROUTE_FIRST`.**
Route-first re-verified after all of the above: compact seed seals in 33.7 s,
`test_warren_spatial_fabric_compiler.gd` 11/11.

### Why "all checks at test time" is not a flag (2026-08-20, third pass)

The gates are **not a validation layer that runs after generation** — composition
*consumes* the hero features as inputs to room, support, and envelope decisions.
Attempting to feed it an empty feature set did not produce a plainer village; it
produced GDScript runtime errors on missing dictionary keys:

```
Invalid access to property or key 'reservation'    at _partition_rooms:1970
Invalid access to property or key 'priority_cells'  at _partition_rooms
```

A runtime error in a static function aborts and returns `{}` **silently** — which
is why the rejection reported no reason at all for several iterations. Each key
fixed revealed the next.

Concretely, `ordered_court_alternatives` is seeded with `courtyard_bridge_candidate`
and every entry is dereferenced for `.reservation`; `skywalk_plan` entries are
dereferenced for `.priority_cells`. Roughly 27 `return {}` sites downstream of the
beam each assume a committed set.

**Conclusion: implement M3's stamps (make the features exist) rather than teach
composition to run without them.** Giving composition a real "no court / no
landmarks / no skywalks" path is a larger change than adding the stamps, and the
stamps are already scoped in
`2026-08-16-maze-town-carver-refactor.md`.

Also recorded: normalizing an absent court to `{}` **breaks route-first** —
optional-absent courts occur in normal operation there and the alternatives list
is expected to carry them. Caught by regression (compact seed stopped sealing,
`test_warren_spatial_fabric_compiler.gd` 10/11) and reverted. Production
re-verified: 11/11, compact seals in 33.9 s.

### Bisect: `5686959` closed the one working maze combination (2026-08-20)

Measured in a worktree at `.claude/worktrees/maze-bisect`, running maze source →
adapt → partition → `from_volume` → fabric over 12 seeds × {compact, standard}:

| commit | date | composed |
|---|---|---|
| `25e3aee` carver lands | 08-19 | **1/24** — seed 12 compact, 27 buildings, fabric gate passing |
| `5686959` refine volumetric town construction | 08-19 | **0/24** |
| `2bba69b` HEAD | 08-19 | **0/24**, failure reasons byte-identical to `5686959` |

Seed 12 compact went from `COMPOSED buildings=27 fabric=true` to
`3D composition retained 2 unsupported room transitions before silhouette relief`.

`5686959` is +2,601/-254 across 16 files, including +425 to
`WarrenRoomCompositionPlanner` and +243 to `WarrenVolumetricSolver` — the
support/bearing path the new failure names. **The five quality commits after it
(`be00305`..`2bba69b`) changed nothing for the maze path**, which falsifies the
earlier hypothesis that the gate tightening was responsible.

The `25e3aee` seed-12 town renders correctly through the normal asset pipeline
(`warren_spatial_review.tscn --maze-source --seed 12 --scale compact`), proving
the maze source can drive composition, fabric compile, and asset assembly end to
end. Recovering that one combination is a far cheaper first target than M3's
stamps: it is a support/bearing regression in a known 16-file commit, not
missing vocabulary.

Two adjacent findings, both pre-existing at `5686959` and NOT caused by the
quality commits:

- The documented review fixture (seed 7, large, candidate `8000031`, variant 1)
  fails identically at `5686959` and HEAD — same signature `8ea89ed2…`, same
  `joint_attempt_count=39`.
- `--solve-production --seed 7 --scale standard` exhausts all 12 attempts at
  HEAD, though the ledger records this settlement sealing in 12.2 s on
  2026-08-15.
