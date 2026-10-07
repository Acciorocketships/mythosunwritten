# Grass Render Distance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Push the dense grass edge out from 60 m full / 84 m gone to the farthest radius that keeps the frame-feel numbers, so grass no longer visibly appears close to the player.

**Architecture:** The two grass radii become one runtime-tunable source of truth (`GrassStreamer` static vars mirrored to two global shader uniforms) instead of constants duplicated in GDScript and `grass.gdshader`. A harness option sweeps candidate radii under the real streamer, measuring frame time, grass fill-in latency and screenshots. The winning pair becomes the default, and the dressing grass/flower visibility range follows it. If fill-in latency is the limit, grass tiles get a second worker thread.

**Tech Stack:** Godot 4.5.1 .NET (`/Applications/Godot_mono.app/Contents/MacOS/Godot`), typed GDScript, GUT tests, `tests/harness/frame_feel_profile.tscn`.

**Spec:** the owner's request (2026-10-07): "now that we have grass LOD, can we increase its render distance? it has always bugged me a bit that you can see it appear nearby". The constraints come from the October 7 frame-smoothness entry at the top of `AGENTS.md`.

## Global Constraints

- Camera smoothness first. In `frame_feel_profile` at 1920x1080 with `--no-vsync`:
  - `run_turn` dt p95 must not rise more than 1.5 ms over the 60/84 baseline;
  - `run_turn` process p95 must stay ≤ 6 ms;
  - no new frame over 10 ms of process time.
- The grass worker stays visual-only: no collision, no gameplay identity, no scene-tree work off the main thread (AGENTS.md "Purity boundary").
- Never swap a live MultiMesh's mesh (an 18 ms stall). LOD stays engine mesh LOD.
- Far grass must still converge to the exact terrain colour (`grass.gdshader` far tint path). The fade band is where the edge hides; keep it at least 24 m wide.
- Profile under the .NET binary; the standard binary plans ~12x slower.
- Do not push or move `main`.

## Review Focus

- **Teleport / cold area:** a larger radius means more tiles waiting on chunk commits. Grass must still never be requested for a tile whose parent chunk is not committed, and the warm spin must still finish (`_grass_streamer.pending_count()==0`, FieldTerrainStreamer.gd ~464). Task 3 measures startup time.
- **Economical quality (`AtmosphereDirector.ECONOMICAL_GRASS_DENSITY` 0.65):** a lower density scale must still thin the far ring rather than leave a hard edge. Task 1's shader test covers the density curve.
- **Tactical camera (F7):** the camera sits farther from the player than in the close view, so a radius tuned for the close view could show its edge. Task 3 captures both views.
- **Running across chunk borders at 10 m/s:** fill-in latency is the user-visible metric. Task 3 records the pending-tile count while running.
- **Memory:** instance buffers grow with tile count. Task 3 records static memory at each radius.

---

## File Structure

- Modify `scripts/terrain/grass/GrassStreamer.gd`: radii become `static var`s; `keep_radius()` replaces the `KEEP_RADIUS` const; `set_radii()` publishes the shader globals.
- Modify `terrain/grass/grass.gdshader`: replace the `FULL_RADIUS` / `GRASS_RADIUS` consts with `global uniform float grass_full_radius; global uniform float grass_radius;`.
- Modify `project.godot` (`[shader_globals]`): declare `grass_full_radius` and `grass_radius`.
- Modify `scripts/terrain/grass/GrassWorkQueue.gd`: read `GrassStreamer.keep_radius()`. Task 4 (only if needed) adds N worker threads.
- Modify `scripts/terrain/environment/EnvironmentCommitQueue.gd`: the grass/flower visibility range derives from `GrassStreamer.GRASS_RADIUS`.
- Modify `tests/harness/frame_feel_profile.gd`: `--grass-radius FULL,EDGE`; summarize `grass_tiles` and the new `grass_pending`; `--grass-shots` saves one fixed set per radius.
- Modify tests: `tests/test_grass_streamer.gd`, `tests/test_september10_grass_latency.gd`.

---

### Task 1: One source of truth for the grass radii

**Files:**
- Modify: `scripts/terrain/grass/GrassStreamer.gd:4-6, 71-100, 128-194, 339-390`
- Modify: `terrain/grass/grass.gdshader:34-35, 66-68`
- Modify: `project.godot` (`[shader_globals]`)
- Modify: `scripts/terrain/grass/GrassWorkQueue.gd:27-59`
- Test: `tests/test_grass_streamer.gd`

**Interfaces:**
- Produces:
  - `GrassStreamer.FULL_RADIUS: float` and `GrassStreamer.GRASS_RADIUS: float` (static vars; same names as today);
  - `static func keep_radius() -> float` (`GRASS_RADIUS + GrassField.TILE_WORLD`);
  - `static func set_radii(full: float, edge: float) -> void` (asserts `edge - full >= 24.0`, sets both, then `RenderingServer.global_shader_parameter_set` for `grass_full_radius` / `grass_radius`).
- Every `GrassStreamer.KEEP_RADIUS` reader becomes `GrassStreamer.keep_radius()`. Find them with `grep -rn "KEEP_RADIUS" scripts tests | grep -i grass`.

- [ ] **Step 1: Write the failing tests**

Add to `tests/test_grass_streamer.gd`:

```gdscript
func test_radii_have_one_source_of_truth() -> void:
	var code := (load("res://terrain/grass/grass.gdshader") as Shader).code
	assert_false(code.contains("const float GRASS_RADIUS"), "the shader reads the streamer's radius")
	assert_false(code.contains("const float FULL_RADIUS"), "the shader reads the streamer's radius")
	assert_true(code.contains("global uniform float grass_radius"))
	assert_true(code.contains("global uniform float grass_full_radius"))
	assert_true(ProjectSettings.has_setting("shader_globals/grass_radius"))
	assert_true(ProjectSettings.has_setting("shader_globals/grass_full_radius"))

func test_set_radii_moves_the_whole_ring() -> void:
	var full := GrassStreamer.FULL_RADIUS
	var edge := GrassStreamer.GRASS_RADIUS
	GrassStreamer.set_radii(90.0, 140.0)
	assert_eq(GrassStreamer.density(90.0), 1.0)
	assert_eq(GrassStreamer.density(140.0), 0.0)
	assert_eq(GrassStreamer.keep_radius(), 140.0 + GrassField.TILE_WORLD)
	for tile: Vector2i in GrassStreamer.desired_tiles(Vector2.ZERO):
		assert_lt(GrassStreamer.distance_to_tile(Vector2.ZERO, tile), 140.0)
	GrassStreamer.set_radii(full, edge)
```

Replace the pinned `assert_eq(tiles.size(), 52)` (line ~23) with a count derived from the radius:

```gdscript
	var expected := 0
	var reach := int(ceil(GrassStreamer.GRASS_RADIUS / GrassField.TILE_WORLD)) + 1
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			if GrassStreamer.distance_to_tile(Vector2.ZERO, Vector2i(dx, dz)) < GrassStreamer.GRASS_RADIUS:
				expected += 1
	assert_eq(tiles.size(), expected)
	assert_eq(expected, 52, "60/84 m ring (update with the default radius)")
```

Also widen that test's ±144 m coverage loop to `±(GRASS_RADIUS + 48)`.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/test_grass_streamer.gd -gexit`
Expected: FAIL. `test_radii_have_one_source_of_truth` finds the shader consts, and `set_radii` does not exist.

- [ ] **Step 3: Implement**

In `GrassStreamer.gd`, replace lines 4-6:

```gdscript
## Full density to FULL_RADIUS, gone by GRASS_RADIUS (player distance). One
## source of truth: set_radii() mirrors both into the grass shader's globals.
static var FULL_RADIUS := 60.0
static var GRASS_RADIUS := 84.0

static func keep_radius() -> float:
	return GRASS_RADIUS + GrassField.TILE_WORLD

static func set_radii(full: float, edge: float) -> void:
	assert(edge - full >= 24.0, "the fade band hides the edge; keep it at least one tile wide")
	FULL_RADIUS = full
	GRASS_RADIUS = edge
	RenderingServer.global_shader_parameter_set(&"grass_full_radius", full)
	RenderingServer.global_shader_parameter_set(&"grass_radius", edge)
```

- Replace every `KEEP_RADIUS` in `GrassStreamer.gd` (the `_evict_far` comparisons) with `keep_radius()`. In `GrassWorkQueue.gd:35`, replace `GrassStreamer.KEEP_RADIUS` with `GrassStreamer.keep_radius()`.
- In `GrassStreamer._init` (after `_prepare_wind()`), call `set_radii(FULL_RADIUS, GRASS_RADIUS)` so the globals always match.
- In `grass.gdshader`, replace lines 34-35 with:

```glsl
global uniform float grass_full_radius;
global uniform float grass_radius;
```

  Then rename the uses in `density_at` (66-68) to `grass_full_radius` / `grass_radius`.
- In `project.godot` under `[shader_globals]`, add these two entries (same format as the existing `grass_lod_origin` entry):

```
grass_full_radius={
"type": "float",
"value": 60.0
}
grass_radius={
"type": "float",
"value": 84.0
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run the Step 2 command, plus the same command for `tests/test_september10_grass_latency.gd` and `tests/test_grass_field.gd`.
Expected: all PASS. `test_field_streamer` has a known cold-start timeout (`test_background_builds_populate_radius`); ignore that one.

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/grass/GrassStreamer.gd scripts/terrain/grass/GrassWorkQueue.gd terrain/grass/grass.gdshader project.godot tests/test_grass_streamer.gd
git commit -m "Grass radii: one runtime source of truth shared with the shader"
```

---

### Task 2: Measure candidate radii in the real game

**Files:**
- Modify: `tests/harness/frame_feel_profile.gd` (option parsing in `_ready` ~55-75, per-frame record ~121-135, `_finish` ~317-353, `_grass_shots` ~210-249)
- Modify: `scripts/terrain/grass/GrassStreamer.gd` (add `pending_tiles() -> int`, the count of desired tiles that are not built yet)

**Interfaces:**
- Consumes: `GrassStreamer.set_radii(full, edge)` from Task 1.
- Produces:
  - harness flag `--grass-radius FULL,EDGE`, applied before the world scene instantiates (so the first ring uses it);
  - a `grass_pending` per-frame field;
  - a per-phase summary of `grass_tiles` / `grass_pending` p50/max;
  - `memory_static_mb` sampled at `idle_end`.

- [ ] **Step 1: Add the harness option and metrics**

In `_ready` option parsing:

```gdscript
		if args[i] == "--grass-radius" and i + 1 < args.size():
			var pair := args[i + 1].split(",")
			GrassStreamer.set_radii(float(pair[0]), float(pair[1]))
```

In `GrassStreamer.gd`:

```gdscript
## Desired tiles (within GRASS_RADIUS of the last LOD origin) not yet built:
## how far grass fill-in lags the player.
func pending_tiles() -> int:
	var count := 0
	for tile: Vector2i in desired_tiles(_lod_origin):
		if not _built.has(tile):
			count += 1
	return count
```

In the per-frame record, add `"grass_pending": _streamer._grass_streamer.pending_tiles()`. In `_finish`, add `"grass_tiles": _stats(pick.call("grass_tiles"))` and `"grass_pending": _stats(pick.call("grass_pending"))` to each phase summary. Also add `"memory_static_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0` to the result.

- [ ] **Step 2: Run the baseline and three candidates**

```bash
S=/private/tmp/grass-radius; mkdir -p $S
for pair in 60,84 80,120 90,140 100,170; do
  /Applications/Godot_mono.app/Contents/MacOS/Godot --path . res://tests/harness/frame_feel_profile.tscn -- \
    --no-vsync --size 1920x1080 --phase-seconds 8 --grass-radius $pair \
    --report $S/feel_$pair.json --grass-shots $S/shots_$pair > $S/feel_$pair.log 2>&1
done
```

Run them one at a time (one heavy Godot process at a time). Expected: four reports and four shot folders.

- [ ] **Step 3: Tabulate**

```bash
python3 - <<'EOF'
import json
S='/private/tmp/grass-radius/'
for pair in ['60,84','80,120','90,140','100,170']:
    rows=json.load(open(S+'feel_'+pair+'.frames.json'))
    for ph in ['turn','run','run_turn']:
        r=[x for x in rows if x['phase']==ph]; dt=sorted(x['dt'] for x in r); pr=sorted(x['process'] for x in r)
        q=lambda a,p:round(a[min(len(a)-1,int(p*len(a)))],1)
        print(pair,ph,'dt p50/p95',q(dt,.5),q(dt,.95),'proc p95',q(pr,.95),'prims p50',q(sorted(x['prims'] for x in r),.5),
              'pending max',max(x.get('grass_pending',0) for x in r))
EOF
```

Record the table in `docs/qa/2026-10-07-grass-distance/result.md` together with the screenshots (pitches 12.7, 3, 30).

- [ ] **Step 4: Pick the default**

Choose the largest pair that meets every Global Constraint and whose `run` phase `grass_pending` max is ≤ 6 tiles. If the frame-time gate passes but the pending gate fails, do Task 4 first and then re-run Step 2 for that pair.

- [ ] **Step 5: Commit the harness and the result**

```bash
git add tests/harness/frame_feel_profile.gd scripts/terrain/grass/GrassStreamer.gd docs/qa/2026-10-07-grass-distance/result.md
git commit -m "Grass radius sweep: harness option, fill-in lag metric, measured candidates"
```

---

### Task 3: Ship the chosen radius

**Files:**
- Modify: `scripts/terrain/grass/GrassStreamer.gd` (default values)
- Modify: `project.godot` (global defaults to match)
- Modify: `scripts/terrain/environment/EnvironmentCommitQueue.gd:111-125`
- Modify: `tests/test_grass_streamer.gd` (the pinned ring count)
- Modify: `AGENTS.md` (grass paragraph: replace "60 m full-density / 84 m fade / 108 m eviction" with the new numbers)

**Interfaces:**
- Consumes: Task 2's chosen `(FULL, EDGE)`.

- [ ] **Step 1: Write the failing test**

In `tests/test_dressing_commit_queue.gd`:

```gdscript
func test_dressing_grass_and_flowers_end_with_the_grass_ring() -> void:
	var bounds := AABB(Vector3.ZERO, Vector3.ONE)
	var range_end := EnvironmentCommitQueue.visibility_range([&"grass"], bounds)
	assert_almost_eq(range_end, GrassStreamer.GRASS_RADIUS + 6.0 + EnvironmentCommitQueue._TILE_HALF_DIAGONAL, 0.01,
		"sparse grass/flower dressing fades with the dense carpet, not 6 m before or 40 m after it")
```

- [ ] **Step 2: Run it to verify it fails**

Run: `.../Godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/test_dressing_commit_queue.gd -gexit`
Expected: FAIL (90 m is hard-coded).

- [ ] **Step 3: Implement**

- Set the chosen defaults in `GrassStreamer.gd` and `project.godot`.
- In `EnvironmentCommitQueue.visibility_range`, replace the grass/flower `90.0` with `GrassStreamer.GRASS_RADIUS + 6.0`.
- Update the pinned count in `test_grass_streamer.gd` (the `assert_eq(expected, 52, ...)` line) to the new ring's count. Print it once from the test to get the number.

- [ ] **Step 4: Run the grass and dressing tests, and look at the result**

Run `test_grass_streamer`, `test_grass_field`, `test_september10_grass_latency`, `test_dressing_commit_queue` and `test_trample_field`; expect PASS.

Then run the game (`/Applications/Godot_mono.app/Contents/MacOS/Godot --path .`). Run across open meadow in both views (F7 toggles), and confirm grass no longer visibly appears at the near edge. Re-run the Task 2 command for the chosen pair, and confirm the numbers match the sweep.

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/grass/GrassStreamer.gd project.godot scripts/terrain/environment/EnvironmentCommitQueue.gd tests/test_grass_streamer.gd tests/test_dressing_commit_queue.gd AGENTS.md
git commit -m "Grass reaches <FULL>/<EDGE> m; sparse grass dressing fades with it"
```

---

### Task 4 (only if Task 2's fill-in gate fails): two grass workers

**Files:**
- Modify: `scripts/terrain/grass/GrassWorkQueue.gd` (one `Thread` becomes `WORKERS` threads, sharing `_jobs` under the existing `_mutex`; `_active` becomes a Dictionary `tile -> true`)
- Test: `tests/test_september10_grass_latency.gd`

**Interfaces:**
- Produces: `GrassWorkQueue.WORKERS := 2`. The `request` / `drain_results` / `update_origin` / `stop` signatures are unchanged.

- [ ] **Step 1: Write the failing test**

```gdscript
func test_two_tiles_compute_at_once() -> void:
	var f := _fixture()
	var work := GrassWorkQueue.new(f.program, 4242)
	work.update_origin(Vector2(12, 12))
	assert_true(work.request(Vector2i(0, 0), 1, f.sampling))
	assert_true(work.request(Vector2i(1, 0), 1, f.sampling))
	var began := Time.get_ticks_msec()
	while work.active_count() < 2 and Time.get_ticks_msec() - began < 2000:
		await get_tree().create_timer(0.005).timeout
	assert_eq(work.active_count(), 2, "both workers pick up a tile")
	work.stop()
```

- [ ] **Step 2: Run it to verify it fails** (`active_count` does not exist).

- [ ] **Step 3: Implement**

- Start `WORKERS` threads in `_init`.
- Each worker pops the nearest job under `_mutex`, marks `_active[tile] = true`, computes outside the lock, then removes it and appends the result.
- `request` refuses a tile already in `_active` (today it compares `_active.tile`).
- `stop()` posts the semaphore `WORKERS` times and joins every thread.
- Add `active_count() -> int`.
- The grass compute reads only detached `GrassSamplingContext` copies, so two workers share no mutable state.

- [ ] **Step 4: Run** `test_september10_grass_latency`, `test_grass_streamer` and `test_field_streamer`. Expect PASS, apart from the known cold-start timeout.

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/grass/GrassWorkQueue.gd tests/test_september10_grass_latency.gd
git commit -m "Grass: two placement workers (fill-in keeps up with the wider ring)"
```
