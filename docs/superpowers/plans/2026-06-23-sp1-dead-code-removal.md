# SP-1: Reclaim dead heightfield-migration code — Implementation Plan

> **For agentic workers:** implement task-by-task. Each task: make the change, run the listed tests, commit. Behavior-preserving throughout.

**Goal:** Delete code proven dead by the deletion-map trace, guarded by a characterization-test safety net. Zero runtime behavior change.

**Branch:** `refactor/terrain-simplification`.

**Conventions:**
- Godot: `/Applications/Godot.app/Contents/MacOS/Godot`
- One test file: `… -s addons/gut/gut_cmdln.gd -gtest=res://tests/<file>.gd -gexit`
- After a new `class_name` or new test file: `… --headless --path . --import` once.
- Stage specific files only (never `git add -A`); never commit `*.uid`.
- **The working tree has pre-existing `terrain/scenes/Cliff*.tscn` deletions** that break scene-loading suites. For any test that instantiates cliff scenes, restore them first with `git checkout -- $(git status --short | grep '^ D' | awk '{print $2}')` then `--import`; re-delete with `rm` afterward to preserve the user's state. Tests that only read module *defs/tags* (via `lib.get_random(...).spawn()` without `create()`) do NOT need scenes.

**Harness reference (study `tests/test_heightfield_cutover.gd` first):**
- `var gen = preload("res://scripts/terrain/TerrainGenerator.gd").new()`; `add_child_autofree(gen)`; `gen.init_for_test()`.
- `gen.HEIGHTFIELD_PLACE_RADIUS = 1` keeps placement small.
- `gen._drive_heightfield_structure(Vector3.ZERO)` places structural tiles.
- `gen.heightfield_plan.surface_height(cx, cz)` gives a cell's surface Y.
- `_spawn(lib, tag)` = `lib.get_random(lib.get_by_tags(TagList.new([tag])), true).spawn()` — a def-only instance (no scene) for socket-classification checks.
- `gen.load_terrain()` runs one generation step (queue processing).

---

## Task 1: Characterization safety net

Lock the surviving decoration/water/orphan/suppression behavior BEFORE any deletion. These tests must pass against the CURRENT (unchanged) code.

**Files:** Create `tests/test_terrain_decoration_characterization.gd`.

**Approach:** Study `tests/test_heightfield_cutover.gd` for the driving harness and `tests/test_biomes.gd` for density helpers. Write deterministic assertions where possible; where the live loop is too stochastic, assert the nearest deterministic proxy and add a `# proxy:` comment explaining what it stands in for.

- [ ] **Step 1 — Write the characterization tests.** Cover, each as its own `test_*` function:
  1. **Decoration enqueues + can place on a surface.** Drive a single ground tile region (`HEIGHTFIELD_PLACE_RADIUS=1`, `_drive_heightfield_structure(ZERO)`), then run `gen.load_terrain()` a bounded number of times (e.g. up to 200 frames or until a displaceable child appears). Assert at least one piece tagged `grass`/`rock`/`bush`/`tree` (any displaceable) becomes a child of the terrain parent at a position on top of a ground tile. If full placement is too stochastic to guarantee in-bounds, fall back to asserting (proxy) that a foliage top socket of a placed ground tile is enqueued by `add_piece_to_queue` (queue size increases / `_is_socket_expandable` true for a `topfront`-family socket and `_effective_fill_prob` > 0 at a low-density position).
  2. **Hill-stacking is reachable.** For an `8x8x2` hill instance, assert `_sample_socket_size(hill, "topcenter")` can yield a stack (the `topcenter` socket has a non-empty size distribution and `_effective_fill_prob` > 0 at a normal position), i.e. the stacking path is live. (Proxy for a full stacked placement.)
  3. **Orphan sweep removes an unsupported hill.** Construct a ground tile + a hill instance positioned on top via the generator's placement helpers (or register both, then `remove_piece` the ground), call `gen._purge_orphaned_stacks()`, and assert the hill is removed (no longer a child / not in the index). Use the existing index API.
  4. **Water/bank expansion** is already covered by `test_heightfield_ground_becomes_water_in_water_field` in `test_heightfield_cutover.gd`; add an assertion-level reference test only if a gap is found — otherwise note it as covered.
  5. **Cliff-core foliage suppression.** At a high macro-density position (find one via `Helper.macro_density01` ≥ the cliff-core threshold, or reuse `test_biomes.gd`'s approach), assert `_effective_fill_prob(ground, <foliage socket>, pos)` is 0 (ground foliage suppressed in a core), and at a low-density position it is > 0.
  6. **Heightfield coverage/eviction** is covered by `test_heightfield_cutover.gd` + `test_heightfield_coverage.gd`; only add a test if the multi-storey place→evict→return-no-orphans case is not already asserted there (check first; if covered, note it).

- [ ] **Step 2 — Register + run.** `--import` once, then run the new file. Restore Cliff scenes first only if any test instantiates them (tests 1/3/4 may place real tiles). Expected: all green against current code.

- [ ] **Step 3 — Commit.**
```bash
git add tests/test_terrain_decoration_characterization.gd
git commit -m "test(terrain): characterization net for decoration/water/orphan/suppression (SP-1)"
```

---

## Task 2: Delete `load_start_tile()`

**Files:** `scripts/terrain/TerrainGenerator.gd`.

- [ ] **Step 1 — Confirm zero callers.** `grep -rn "load_start_tile" scripts tests` → only the definition. (If any caller exists, STOP and report.)
- [ ] **Step 2 — Delete the function** (`func load_start_tile(...)` and its body).
- [ ] **Step 3 — Verify.** Run `test_heightfield_cutover.gd` (covers `test_no_start_tile_when_heightfield_on`) and the new characterization file. Expected: green.
- [ ] **Step 4 — Commit.**
```bash
git add scripts/terrain/TerrainGenerator.gd
git commit -m "refactor(terrain): delete unused load_start_tile (SP-1)"
```

---

## Task 3: Delete the unreachable `replace_existing` stack cascade

**Files:** `scripts/terrain/TerrainGenerator.gd`.

Context: only cliff tiles set `replace_existing=true`, and cliffs are never placed via the queue (`add_piece`); `HeightfieldInstantiator` bypasses `add_piece`. So the stacked-cascade in `add_piece`'s `replace_existing` block is unreachable.

- [ ] **Step 1 — Read `add_piece` and `_collect_stacked_above`.** Identify in `add_piece` the `replace_existing` block: it has (a) a loop removing directly-overlapping pieces and (b) a `_collect_stacked_above`-based collection + a second removal loop for stacked-above pieces. 
- [ ] **Step 2 — Delete** the `_collect_stacked_above()` function and the (b) cascade portion in `add_piece` (the stacked-set collection and second removal loop). **Keep** the (a) direct-overlap removal loop intact.
- [ ] **Step 3 — Confirm** `grep -rn "_collect_stacked_above" scripts tests` → no references remain.
- [ ] **Step 4 — Verify.** Run characterization file + `test_water_rule.gd` (WaterRule uses replace/swap) + `test_heightfield_cutover.gd`. Restore Cliff scenes if needed for water_rule. Expected: green.
- [ ] **Step 5 — Commit.**
```bash
git add scripts/terrain/TerrainGenerator.gd
git commit -m "refactor(terrain): delete unreachable replace_existing stack cascade (SP-1)"
```

---

## Task 4: Delete dead stack-support check + purge branches

**Files:** `scripts/terrain/TerrainGenerator.gd`.

Context: `_purge_orphaned_stacks` has a `level-stack` branch and a `cliff-stack` branch (both calling `_has_valid_stack_support`) that are dead — those tiers are placed/evicted atomically by the heightfield, never orphaned. The hill `_support_sweep_pieces` / `_has_surface_support` sweep that follows is LIVE and must stay.

- [ ] **Step 1 — Read `_purge_orphaned_stacks` and `_has_valid_stack_support`.** Identify the `level-stack` and `cliff-stack` blocks (the ones gating on `tags.has("level-stack")` / `tags.has("cliff-stack")` and calling `_has_valid_stack_support`). Identify the hill/displaceable surface-support sweep (keep it).
- [ ] **Step 2 — Delete** the two dead branches and the now-unreferenced `_has_valid_stack_support()` function. Keep the hill sweep and `_has_surface_support`.
- [ ] **Step 3 — Confirm** `grep -rn "_has_valid_stack_support" scripts tests` → none.
- [ ] **Step 4 — Verify.** Run the characterization file (esp. the orphan-sweep test #3) + `test_heightfield_cutover.gd`. Expected: green — the hill orphan sweep still works.
- [ ] **Step 5 — Commit.**
```bash
git add scripts/terrain/TerrainGenerator.gd
git commit -m "refactor(terrain): delete dead level/cliff-stack orphan checks (SP-1)"
```

---

## Task 5: Delete `create_24x24x4_test_piece`

**Files:** `scripts/terrain/TerrainModuleDefinitions.gd`, `scripts/terrain/TerrainModuleLibrary.gd`.

Context: `24x24x4` size only exists on suppressed structural sockets and is never sampled at runtime; no test instantiates this piece.

- [ ] **Step 1 — Confirm usage.** `grep -rn "create_24x24x4_test_piece\|24x24x4" scripts tests` — confirm the only references are the factory definition, its registration in `load_test_pieces`, and tag-string checks in `test_biomes`/`test_slope_cliff_integration` that do NOT instantiate the piece. (If a test instantiates it, STOP and report.)
- [ ] **Step 2 — Delete** the `create_24x24x4_test_piece()` factory and the `terrain_modules.append(TerrainModuleDefinitions.create_24x24x4_test_piece())` line in `TerrainModuleLibrary.load_test_pieces`.
- [ ] **Step 3 — Verify.** Run `test_terrain_module_library.gd` (restore Cliff scenes first), `test_biomes.gd`, the characterization file. Expected: green.
- [ ] **Step 4 — Commit.**
```bash
git add scripts/terrain/TerrainModuleDefinitions.gd scripts/terrain/TerrainModuleLibrary.gd
git commit -m "refactor(terrain): delete unused 24x24x4 test piece (SP-1)"
```

---

## Task 6: Remove dead structural-seed module data (test-guarded, one family at a time)

**Files:** `scripts/terrain/TerrainModuleDefinitions.gd` (and `TerrainSpawnConfig.surface_spawn_sockets` only if needed).

Delete suppressed structural-seed DATA so definitions reflect what is live. Do this LAST, one family per commit, re-running tests between each. **If a test breaks on an item, revert that item and record it as an SP-2 follow-up in the commit message — do not force it.**

For each of the following, read the factory first, remove only the named dead data, KEEP everything marked live:

- [ ] **Step 1 — Ground tile topcenter seed data.** In `load_ground_tile`, the `topcenter` SEED size distribution (`{level:0.7, cliff:0.3}`-style) and its `topcenter` tag distribution are structural/suppressed. Remove them **without** changing: the `topcenter` `socket_fill_prob` value (the foliage suppressor derives its prob from it), and the ground cardinal `socket_required`/`socket_tag_prob` (LIVE for water/bank expansion). Because `surface_spawn_sockets` builds the topcenter entries from its parameters, this likely means passing a null/blank topcenter size+tag (or an empty distribution) while preserving the fill/suppression value — inspect `surface_spawn_sockets` and choose the minimal change that drops the seed size/tag but keeps the suppressor prob identical. Run the characterization suite (esp. #1, #5) + `test_biomes` + `test_water_rule` (scenes restored). Commit `refactor(terrain): drop dead ground topcenter seed data (SP-1)`.
- [ ] **Step 2 — Level/cliff topcenter seed data.** In the level/cliff interior/center builders, remove the suppressed `topcenter` SEED size/tag distributions (the next-storey seeds), preserving the `socket_fill_prob`/suppressor value. Run characterization + `test_terrain_module_library` + `test_heightfield_cutover` (scenes restored). Commit `refactor(terrain): drop dead level/cliff topcenter seed data (SP-1)`.
- [ ] **Step 3 — Level/cliff lateral required/tag data.** Remove the `socket_required`/`socket_tag_prob` on level/cliff `front/back/left/right` sockets (structural laterals, never enqueued). KEEP the ground and water/bank lateral `socket_required`/`socket_tag_prob`. Run characterization + `test_terrain_module_library` + `test_water_rule` (scenes restored). Commit `refactor(terrain): drop dead level/cliff lateral adjacency data (SP-1)`.

If any step reverts, note which item survived and why in the commit message and the SP-2 backlog note at the end of this plan.

---

## Task 7: Clean stale dead-rule comments

**Files:** `TerrainGenerationRuleLibrary.gd`, `rules/WaterRule.gd`, `TerrainModuleDefinitions.gd`, `TerrainGenerator.gd`, `TerrainSpawnConfig.gd`.

- [ ] **Step 1 — Find them:** `grep -rn "CliffEdgeRule\|LevelEdgeRule\|ClusterFillRule" scripts`.
- [ ] **Step 2 — Fix each.** If the comment only names a dead rule, delete that clause. If it explains live behavior while naming a dead rule, rewrite to describe the behavior without the dead name (don't lose the rationale). Touch comments only — no code.
- [ ] **Step 3 — Verify** `grep -rn "CliffEdgeRule\|LevelEdgeRule\|ClusterFillRule" scripts` → none. Quick parse check via any one test.
- [ ] **Step 4 — Commit.**
```bash
git add scripts/terrain/TerrainGenerationRuleLibrary.gd scripts/terrain/rules/WaterRule.gd scripts/terrain/TerrainModuleDefinitions.gd scripts/terrain/TerrainGenerator.gd scripts/terrain/TerrainSpawnConfig.gd
git commit -m "docs(terrain): remove references to deleted edge/cluster rules (SP-1)"
```

---

## Task 8: Full-suite regression gate

- [ ] **Step 1 — Restore scenes, run full suite.**
```bash
git checkout -- $(git status --short | grep '^ D' | awk '{print $2}')
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import >/dev/null 2>&1
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json -gexit 2>/dev/null | grep -E "Tests|Passing|Failing"
```
Expected: same pass count as the pre-SP-1 baseline (188/188 with scenes present). Any new failure is a regression — investigate before finishing.
- [ ] **Step 2 — Restore the user's working state** (re-delete the scenes):
```bash
rm -f $(git status --short | grep '^ D' | awk '{print $2}' 2>/dev/null); true
# (the scenes were tracked-deleted before this work; re-remove the ones git just restored)
```
Verify `git status --short | grep 'scenes/Cliff'` shows the 14 `D` entries again, plus untracked `terrain/scenes/cliff/`.

---

## SP-2 backlog (items deferred from Task 6 if any reverted)

_Record here any structural-seed data that turned out to be live and was kept._
