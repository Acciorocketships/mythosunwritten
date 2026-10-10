# Town Taste Knobs (courtyards, deco, wells, lamps, sprawl) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the owner's October 7 visual feedback into tunable knobs on the existing town odds layer (defaults first reproduce today exactly), then move the defaults toward the requested look.

**Architecture:** Every change reads a knob from `TownCharacter` (`terrain/villages/town_odds.tres`, see AGENTS.md October 7 entry). Tasks 1–4 and 6 add knobs whose default values reproduce current output byte-for-byte (fingerprint gate); Task 5 (dark wood lamps) is a fixed change that re-baselines. Task 7 changes defaults (intended visual change) with renders, audits and walks. Only guardrails are hard rules: wells on ground only, door/entrance reachability, support, no overlap, min width.

**Tech Stack:** Godot 4.5, typed GDScript, GUT, existing harnesses.

**Spec:** owner decisions recorded in this plan's "Owner direction" section (October 7 conversation) plus `docs/superpowers/specs/2026-10-07-town-odds-layer-design.md` (odds layer contract) and `docs/qa/2026-10-07-town-rule-audit/audit.md` section 10.

## Owner direction (October 7)

- Courtyards should be surrounded by houses, but placement is a biased draw: more likely inside the town field's Gaussian lobes (where houses end up) and where houses can front more sides; never a hard reject for being open.
- Not every green needs a walking ring; clearings probably look better without one; shapes vary.
- Clearings need more decoration.
- Wells only on the ground (hard rule — a well only makes sense on ground); the current well is too big (size is a knob).
- Lamp posts dark brown wood to match the town — a fixed change, not a knob (owner: "can just be dark wood").
- Satellite houses closer to the core; a suburban band of small detached houses between dense core and countryside; a lone house need not get a road. All three are knobs; today's behaviour must remain reachable.

## Global Constraints

- Worktree `/Users/ryko/.codex/worktrees/77a0/story`, branch `town-redesign`. Never touch `/Users/ryko/story`. Never run the `godot-test` alias.
- Godot `/Applications/Godot.app/Contents/MacOS/Godot`, always `--log-file /tmp/<name>.log`, stdout redirected, exit code checked; no `timeout` on macOS; ignore unrelated Godot processes. Reimport after class_name changes.
- Focused test: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --log-file /tmp/t.log -s addons/gut/gut_cmdln.gd -gtest=res://tests/<file>.gd -gexit > /tmp/t.out 2>&1; tail -30 /tmp/t.out`.
- Fingerprint gate (Tasks 1–4, 6; Task 5 re-baselines): `... --headless --path . --log-file /tmp/fp.log -s res://tests/harness/town_fingerprint.gd -- --out /tmp/fp.json --compare docs/qa/2026-10-07-town-odds/fingerprint/baseline.json > /tmp/fp.out 2>&1; echo EXIT $?; grep FINGERPRINT_ /tmp/fp.out` must print FINGERPRINT_MATCH. Where a task's knob only acts when clearings are on, also run with `--odds clearing_count=3 --towns 53:grand,103:standard` and confirm both build.
- New knobs go in `terrain/villages/town_odds.tres` (TownKnob kinds CHANCE=0, RANGE_FLOAT=1, RANGE_INT=2, WEIGHTS=3) with `notes` naming this plan's task. Numeric `--odds` overrides only (WEIGHTS knobs cannot be overridden from the CLI).
- Read every knob through `TownCharacter.of(profile, world_seed)` with the town (city) seed; rolls keyed by stable decision keys.
- Default value of every new knob reproduces today; no rule rejects a town for an aesthetic reason.
- Commit after each task; messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Never `git add -f`; never commit `.superpowers/`.

## Review Focus

1. A town whose lobes are tiny (compact) — lobe-depth weighting must not divide by zero or make every weight 0 (fall back to uniform).
2. A ringless green whose fronting house door lands mid-edge — the door must still connect to the public walk (strip), and `walk_surface_component_count` must stay 1.
3. A raised green that would have picked the well — must pick another feature (tree/stall) or none, never float a well.
4. Lone-house road chance 0 on a site with no walk node nearby — the house door must still be reachable on foot over open ground (ground-level, terrain walkable), or the site keeps its lane.
5. Suburban band houses on steep or wet ground — use the existing house-site admission guardrails (garden admission, dry, supported); never place on water.

---

### Task 1: Courtyard placement pulls (lobe depth, enclosure) as knobs

**Files:** Modify `scripts/terrain/features/villages/fabric/WarrenCourtClearings.gd`, `terrain/villages/town_odds.tres`; Test `tests/test_court_clearings.gd`.

- Add knobs: `clearing_lobe_bias` (RANGE_FLOAT, default 0.0 = today, clamp 0..4), `clearing_enclosure_bias` (RANGE_FLOAT, default 0.0, clamp 0..4).
- Candidate weight becomes `street_distance^clearing_block_bias × lobe_depth^clearing_lobe_bias × (1 + fronted_sides)^clearing_enclosure_bias × ground_weight`. `lobe_depth` = normalised massif layer height at the column (`massif.layer_at(column)` or the town-field value — read WarrenMassif/WarrenTownField; use whichever measures "inside a Gaussian bump", normalised to (0,1], floor 0.01). `fronted_sides` = `WarrenPlotReservations._plaza_buildable_frontages(plan, cells, floor, streets, blocked)` evaluated on the grown candidate (compute after growth; weight applied as acceptance probability `roll < (1+sides)^bias / 5^bias` so bias 0 always accepts — keep attempts bounded).
- Exponent 0 must reproduce today exactly (multiply by 1.0, no extra rolls consumed on the default path, or rolls on a separate stream so existing rolls don't shift).
- Tests: with biases 0 proposals equal the current output (compare to a call with the knobs absent — snapshot proposals before the change in the test file); with `clearing_lobe_bias=3` mean lobe depth of chosen cells exceeds the mean over candidates; with `clearing_enclosure_bias=3` mean fronted sides of accepted clearings ≥ that with bias 0 (53:grand, 103:standard).
- Gate: fingerprint MATCH; override run builds.

### Task 2: Optional walking ring on green courts

**Files:** Modify `WarrenVolumetricSolver.gd` (`_maze_court_planting_cells` ~2539), `SettlementFabricPlan.gd` (`set_planned_plaza` edge check ~236), possibly `WarrenPlotReservations.gd` (record per-plot `ring` flag); knobs; Test new `tests/test_court_rings.gd`.

- Knobs: `plaza_ring_chance` (CHANCE, default 1.0), `clearing_ring_chance` (CHANCE, default 1.0). Roll per green plot (key: plot id); store `plot["ring"]` when the plot is created (plaza in `_place_plaza`, clearings in `_place_clearings`).
- Ringless green: planting = all deck flat cells except walk strips: for each entrance (`door_walk`, each `doors[]`) and each house door facing the court (doors whose landing is a court edge cell), a 1-cell strip from that edge cell to the nearest other strip or to the court centre so all walk cells form one connected component; the edge check in `set_planned_plaza` allows planting on court edge cells when the plot is ringless (keep the check for ringed greens).
- Guardrails: every door/entrance landing remains public floor and connected; audit `walk_surface_component_count == 1`; planting never covers a landing.
- Tests: ring chance 1.0 reproduces today (byte-identical planting cells); ring chance 0 on 103:standard and 53:grand with clearings on: planting reaches edge cells, every door landing is walk, walk cells connected.
- Gate: fingerprint MATCH; override run (`--odds clearing_count=3 --odds clearing_ring_chance=0`) builds, production audit (copy of `docs/qa/.../production-validation/oct7-range-audit-prod.gd.txt` with `--odds` support) valid / 0 floating / 0 intrusions; actual-player court walk (copy of `docs/qa/2026-10-01-town-redesign/prefab-grammar/october6-integrated-checkpoint/handoff-support/oct6-preview-court-walk.gd`, add `--odds` override) passes for 53:grand.

### Task 3: Clearing decoration by purpose

**Files:** Modify `SettlementFabricAssembler.gd` (garden/plaza dressing for clearing plots) and/or `TownGroundDressing.gd` activity groups; knobs; Test `tests/test_court_clearings.gd`.

- Knob `clearing_deco_density` (RANGE_FLOAT, default 0.0 = today, clamp 0..1).
- For each clearing plot by purpose, place up to `round(density × capacity)` prop groups from existing assets with the existing measured-fit/clearance checks: green → benches, flower beds/bushes, planters, a lamp; paved → stall, crates, barrels, bench; workyard → workbench/anvil (forge asset if present in catalog), firewood, crates. Seeded order, keyed by plot id; props never on walk strips/landings; no overlap (reuse the obstacle accumulation from centre features).
- Tests: density 0 → identical; density 1 on 53:grand/103:standard clearing on → each clearing gets ≥2 props, none intersect walk landings or each other.
- Gate: fingerprint MATCH; override run builds; production audit clean.

### Task 4: Wells only on the ground; well size knob

**Files:** Modify `SettlementFabricAssembler.gd` (`maze_plaza_centre_feature` ~5731 / `maze_plaza_centre_features` ~5683; pass per-component ground flag), knob; Test.

- Hard rule: skip `PLAZA_WELL` for a green component whose floor band is not the terrain bearing (`massif.bearing_at(column)` for its columns; thread from the plot / spatial source). Fall through to the next feature as today's loop does.
- Knob `well_scale` (RANGE_FLOAT, default 1.0, clamp 0.4..1.25); apply via the feature's `scale` and make sure the render path honours it (check KitSubstitution well fit; if substitution ignores feature scale, apply the factor after substitution).
- Tests: a raised green never gets a well (53:grand clearing.00 is raised); `well_scale=0.7` shrinks the placed well's AABB by ~0.7 and it stays clear.
- Gate: fingerprint MATCH (today no evidence town puts a well on a raised green — if one does, the baseline legitimately changes: record which town and re-baseline with before/after render of that plaza, ledger it).

### Task 5: Dark wood lamp posts (fixed change, not a knob)

**Files:** Modify where the garden/plaza lamp role is substituted (`KitSubstitution.gd` prop.lamp / `SuntailBuildingKit.gd` ~162) and path lamps if they render grey (`sfv.light_pole.001`, `PathProgram.gd`); Test.

- All lamp posts use a dark brown wood finish. Prefer the existing `suntail_prop_lamp_1_finish_walnut` descriptor. Verify by a close-up render that the post itself (not only wooden sub-parts) turns dark brown; if the grey parts use a non-wood material, add a descriptor variant (bake manifest `material_tints`) tinting that material dark brown — no runtime hack.
- Tests: lamp asset ids resolve to the dark-wood variant everywhere lamps are placed.
- Gate: this intentionally changes output — fingerprint source hashes must match baseline, payload hashes change; commit a new baseline. Close-up before/after renders archived under docs/qa/2026-10-07-town-odds/taste/lamps/.

### Task 6: Satellites, suburban band, lone-house roads

**Files:** Modify `WarrenTownField.gd` (satellite radius ~48-79; new suburban lobes), `WarrenMazeCarver._carve_house_site_access` (~3478); knobs; Test new `tests/test_town_sprawl.gd`.

- Knobs: `satellite_reach_scale` (RANGE_FLOAT, default 1.0 = today; multiplies the satellite placement radius and MAX_GREEN_REACH ring), `suburb_house_count` (RANGE_INT, default 0 = today; small house lobes in an annulus just outside the core edge, 1.0–1.4× radius, admitted by the same house-site/garden guardrails), `lone_house_path_chance` (CHANCE, default 1.0 = today; per house site, roll before carving its access lane; skipped sites rely on ground-level open walking — guardrail: if the house door is not on ground level reachable over terrain, keep the lane).
- Draw town-field knobs from a stream that does not shift existing town-field rolls (default must be byte-identical).
- Tests: defaults identical; `satellite_reach_scale=0.6` mean satellite distance drops; `suburb_house_count=4` adds ≥2 house sites near the core edge on 13:standard and 53:grand; `lone_house_path_chance=0` carves no `house_site_access` lanes.
- Gate: fingerprint MATCH; override runs build; production audit clean.

### Task 7: New defaults, evidence, owner checkpoint

**Files:** `terrain/villages/town_odds.tres`, `docs/qa/2026-10-07-town-odds/taste/result.md`, new fingerprint baseline.

- Set defaults: `clearing_lobe_bias` 2.0, `clearing_enclosure_bias` 2.0, `plaza_ring_chance` 1.0, `clearing_ring_chance` 0.25, `clearing_deco_density` 0.7, `well_scale` tuned (start 0.7; choose by person-scale render), `satellite_reach_scale` 0.7 (spread 0.15), `suburb_house_count` small 1 → large 4 (spread 1), `lone_house_path_chance` 0.2. `clearing_count` stays 0 by default (owner decides separately) — evidence renders run with `--odds clearing_count=2.5` (large/grand) / 1 (others).
- Evidence: before (previous commit) / after renders for 53:grand, 31:large, 103:standard, 13:standard, 83:grand, 7:compact (overview, orbit, courtyard, street, close lamp/well views); production audit all valid/0/0; court walks pass; new fingerprint baseline committed; result.md with images list, tables, limits.
