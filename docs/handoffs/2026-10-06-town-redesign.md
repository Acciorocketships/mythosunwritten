# Town redesign handoff — October 6, 2026

## Start here

The redesign is **in progress, not accepted as complete**. The user asked for this handoff rather than another implementation pass. Continue from the existing worktree; do not restart the redesign or infer that the remaining art issues were accepted.

- Workspace: `/Users/ryko/.codex/worktrees/77a0/story`.
- Read the current `AGENTS.md`, then [the plan](../superpowers/plans/2026-10-01-town-redesign.md) and [the integrated checkpoint](../qa/2026-10-01-town-redesign/prefab-grammar/october6-integrated-checkpoint/result.md).
- The worktree has **1,662 modified/untracked entries at handoff**. Much predates the latest repairs. Preserve all existing work; do not reset, replace whole files from experiments, or indiscriminately stage it. No commit or PR was created for this handoff.
- **All known jobs are terminal.** Latest process2141 exited0: existing parallel-roof consolidation regression, **4 tests /24 assertions pass**,54.796s. No job needs polling.
- Most recent production change is the unequal parallel roof-range rule. Its focused tests pass, but its **final integrated native render and broader holdouts are still pending**.
- The separate courtyard-access experiment is **not integrated**.
- All seven stage acceptance checkboxes in the plan remain open. Local repairs and passing tests are not whole-town art acceptance.

Paths below are relative to this repository. “Checkpoint” means `docs/qa/2026-10-01-town-redesign/prefab-grammar/october6-integrated-checkpoint/`.

## What the user wants

The intended result is a seeded town generator whose houses generalize the actual Pure Village and Suntail prefabs. The authored examples should be reproducible special cases of the assembly rules, with believable joints, support and material families.

Important recurring requests:

- Articulated silhouettes, nonrectangular compounds, overhangs, projecting bays, reveals, trim and interesting rooflines; avoid long rectangular roofs and tall flat “apartment” streets.
- Corner-connected turrets/spires on suitable taller buildings, with coherent roof colors. Do not attach them arbitrarily to roofs or short cottages.
- Dense, layered massifs with paths bored through them, inhabited rooms overhead, tunnels and skywalks. Exposed boardwalks around the outside do not satisfy that goal.
- Large town squares **inside** building clusters, including upper-level decks and courtyards; meaningful green clearings with trees/canopy, regional ground color and real grass.
- Purposeful connected paths with softened corners, rather than paving the whole town or making unnecessary circuits.
- Optional procedurally selected fortifications/terraces. Walls should use existing assets and contain inhabited facades and alley/tunnel entrances, not merely houses standing beside blank ramparts. Avoid generic grid accents.
- Warm brownish-white siding closer to Pure Village, coherent primary/accent materials, and consistent colors on projections and roofs. Other palettes can vary between buildings.
- No overlaps into routes, floating parts, hollow roofless buildings, disconnected roof pieces, missing trim or material patchwork.
- Randomized general rules, not seed-specific production fixes; visual iteration and real traversal checks as well as tests.

The latest specific request, warm siding and terrain-consistent courtyard grass, has been implemented and checked locally. The broader architectural/enclosure requests remain open.

## Production work completed

### Warm plaster and regional courtyard lawns

Evidence: `docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-warm-plaster-regional-lawns/result.md`.

- Suntail `Wall` material now uses multiplier `(0.92, 0.86, 0.76)`, retaining its authored texture and normal map. Other categories remain independently controlled. This is a material adjustment, not a newly painted texture.
- `BiomeRegistry.terrain_tint_at` supplies the shared 24m bilinear regional tint field to raised lawns and actual `GrassField`/`GrassStreamer` grass, matching terrain color sampling.
- Raised garden ground already uses `TerrainChunkMesher.field_ground_surface`; the review harness was corrected to display the production world-space tint.
- Focused verification:3 tests/19 assertions; native13/grand review with349 grass instances.
- Broader grass suite:35/36 pass. Remaining failure reads retired `terrain_grades[0]` and also fails with this change disabled. This specific classification does not classify unrelated suite failures.
- The flat green study plane in isolated building images is not evidence of production terrain-color matching.

### Superseded landmark-preview reservations

Code: `scripts/terrain/features/villages/fabric/WarrenMazeCarver.gd`.
Evidence: checkpoint `preview-reservation-repair/`.

Two `_preview_reserved_columns` calls around tower-address creation accumulated the first preview's construction/frontage reservations even after the selected sites changed. This blocked useful frontage and created a62-column orphan house block in53/grand.

The repair snapshots pre-preview construction/frontages, records exact tower-address writes (including overlaps), then restores prior owners plus those tower claims before the second preview. Separate bridge-bearing reservations and earlier court/gate owners are preserved.

Verified outcomes:

-53/grand largest orphan block62→10 columns.
- Six paired towns53/13/31/43/83/103: all12 builds pass; five retain measured layouts/audits.
- Original9-column floor9 court and4-column floor2 court remain; another4-column floor2 court appears.
- Planned bridges1→2, but **finished stamped bridges remain1**: the second legitimately yields to a doorway storey. Do not report two built bridges.
- Covered supply44/164→70/260: more covered length, virtually unchanged share (~26.8%→26.9%).
- Missing roof faces, overlap cells and unsupported transitions remain0.
- New `test_tower_preview_reservations.gd`:1 test/30 assertions pass; five existing tower/frontage tests/41 assertions pass.
- Actual player:4 native entrance passes,18 skywalk/underpass passes,6 courtyard passes. PublicWalkAudit98 nodes,0 unaddressed dead ends.
- Native courtyard/skywalk review contains42 images and376 actual garden-grass instances. Some long repetitive facades remain visible.

### Raised garden structural cap

Code: `KitVillageBuildings.gd`, `_feature_masses`; test `tests/test_garden_bearing_cap.gd`.
Evidence: checkpoint `garden-cap-repair/`.

The small garden at fine x14–15,z4–7 in53/grand had a visible green underside/sky slit. House062 had a complete room ceiling at band3; the native retaining wall began at band4. A legacy structural flat-roof slab between them was removed during native substitution without replacing its side faces. This was a rendering handoff defect, not an unsupported garden or absent inhabited ceiling.

The existing wall-room restoration now also restores ordinary-house flat-roof courses only when the **same fine column already has a retained top course**. It stays inside the source roof-band span, requires structural volume and maze-stone ownership for ordinary additions, and skips empty spans. Gating uses the original retained map, avoiding cascading restoration. Free pitched-roof envelopes and private rooms are not filled.

- Red:8 missing-course assertions failed.
- Green:1 test/26 assertions pass.
- Matched native before/after shows complete native stone from wall to house ceiling; main court retains tree, bench and376 grass instances/6 tiles.
- Six actual-player courtyard routes pass after the repair;98 public nodes,0 dead ends.
- Remaining flat stone faces still need architectural improvement. Closure is not facade-art acceptance.

### Unequal parallel roof ranges — newest integration

Code:

- `scripts/terrain/features/villages/kit/KitRoofJunctions.gd`
- `scripts/terrain/features/villages/kit/KitVillageBuildings.gd`
- `tests/test_parallel_range_footprints.gd`

Evidence: checkpoint `unequal-roof-range-study/`.

In53/grand, `kit.spatial.parcel.maze.house.054` had adjacent parallel6x2 and8x2 roofs at eave band4, plus a separate2x2 branch. Curled gable/verge ends collided. The old short/equal-length consolidation rule could not combine them.

`combine_parallel` retains its original rule and then calls `_combine_same_house_ranges`:

- Same house, axis, eave and color; closed ends; adjacent across the slope; overlap along ridge at least2 modules.
- Merge the common span, preserve projecting end wings at least2 modules, reject1-module remnants.
- Maximum combined depth remains `BuildingDesigner.MAX_ROOF_DEPTH` (4).
- Require full candidate clearance; preserve exact footprint and cell multiplicity. No filling courtyard notches.
- Reset obsolete dormer slots, retain main chimney/ridge-peak flags without duplicating chimneys on remnants; repeat to a fixed point.

The previous callback tested a full ridge-height prism plus an extra band, refusing harmless air over outer slope rows. It now uses `column_clearance_height` and ceil band occupancy for each roof row, retaining occupancy/ownership checks for rooms, passages, crowns and public air.

**Important correction:** the first analytic slope bound missed Suntail ornamental ridge spikes by1.192m. `ridge_clearance_head` now measures ridge-peak assets after kit/asset anchors and includes that height at ridge columns. Final vertex proof checks367,684 authored vertices across both kits, depths2–4 and both axes:0 misses.

Verification so far:

- New regression red:4/12 assertions fail before repair.
- Final new tests:3 tests/25 assertions pass (coverage, refusal/idempotence, authored-vertex bounds).
- Existing consolidation regression:4 tests/24 assertions pass. Latest archived log: `unequal-roof-range-study/oct6-range-existing-tests.out`.
- Pre-integration native candidate images show one complete6x4 gable plus2x2 wing at house054; another residual pair becomes4x6. The overlapping tails disappear locally.
- Candidate53/grand and31/large payloads validate with0 floating masses and0 roof/public-air intrusions;1,405,142 and417,744 triangles respectively. Gable boundary contacts were reported separately, not concealed as clearance success.

**Still pending:** final production render/audits after the measured ornamental-bound refinement, broader seed holdouts and silhouette review. The candidate evidence must not be presented as final production acceptance. Large flat faces and broad roof planes remain.

### Earlier integrated repairs to retain

See checkpoint history for exact evidence and file details; do not repeat these blindly:

- Explicit hanging-crown soffits now survive datum early returns; native retaining ceiling fitting uses measured masonry depth with1cm overlap.2 tests/18 assertions, matched31 native views,20 player checks across13/31.
- `_tunnel_jambs` rejects asset-envelope reservations as real structural bearing. This repairs proof, **does not increase enclosure supply**.
- Roof-clipping optimization retains exact-plane behavior. An AABB shortcut was rejected. Exact serialized31/53 equivalence,7 tests/35 assertions, ~6–8% improvement. Quiet solves7905/7366/7726ms leave little margin under8s.
- Pure bay bake metadata gained missing openings/frames:19 tests/328 assertions.
- Texture inventory recognizes8 Suntail maps shared by Pure material-swapped bays:55 distinct maps=47 native+8 shared, unchanged resources and230MiB native budget;1 test/446 assertions.
- Tower entrance fallback:5 tests/41 assertions and native31 entrance checks.
- Back-room/deferred roof retry/continuous flat-strip cap/slim public posts:14 tests/119 assertions and22 player checks.
- Native prefab reconstruction covers57 examples (49 Pure/5905 meshes,8 Suntail/3003 meshes). Exact reconstruction is groundwork, not proof of randomized grammar quality.

## Experiments not integrated

### Courtyard-owned short access lane

Checkpoint `court-area-prototype/` contains temporary solver/compiler/adapter copies. **Never copy those entire files over production.**

A short lane from an existing court subdivides31/large's29-column orphan block to16; adds12 route floors, roomed cells1826→1802, preserves3 bridges and9-column court. Six paired towns all build, five unchanged; native review and two real-player passes succeeded. Covered-supply count remains4: this is not an enclosure improvement.

The experiment needed an explicit court-area public node, a borrowed graph endpoint and measured shared seams, without duplicate paving/headroom. Single-street rooftop-court attachment otherwise created duplicate surface claims. Before integration, implement canonical area identity in the real adapters, test multiple courts/determinism/ownership, and compare coverage, enclosure, holdouts and cost.

The53 failure led to the separate preview-reservation production repair described above. Do not conflate the two.

An attic-pavilion experiment was rejected because it replaced a broken large roof with a worse uninterrupted slope. Do not revive it without new evidence.

## Continuation plan, in order

1. **Close the newest roof change's validation gap.** Render production53/grand and31/large with actual garden grass; compare deck00 front/reverse and overview. Run current production payload, floating and roof/public-air audits. Extend to established holdouts13/43/83/103. Check exact roof coverage, end-wing widths, roof/room collisions, material coherence and authored junctions. Re-run relevant player routes if changed collision touches public space. Reject joins that merely create larger bland rectangles.
2. **Address source massing and enclosed circulation together.** Remaining apartment-like blocks cannot be solved solely by decoration. Consider integrating the courtyard access prototype through canonical area ownership. Jointly plan room-bearing crowns/jambs and boring so routes actually acquire roofs/rooms above. Natural tunnel chance is already1; turning it up is not a solution. Track planned and finished bridges separately, and covered length separately from covered share.
3. **Continue prefab-derived architectural rules.** Use real attachment/socket/overhang rules for projections, shed roofs, corner turrets, trim and material continuity. Eliminate large flat faces with actual volume changes. Preserve no-spire short cottages, complete caps and overhanging eaves. Avoid random ornament masking structural problems.
4. **Improve internal squares and green space.** Larger interior and elevated courts, region-colored real grass, trees/canopy and supported props, while preserving dense massifs and destination access. Review path economy visually; zero dead ends does not prove no unnecessary circuits.
5. **Finish broad acceptance.** Run meaningful representative and holdout towns in-world, actual-player traversal, geometry/support/floating/roof audits, determinism and performance. Reconcile every plan requirement before checking stages complete. Full GPU memory/export/whole-town budget remains open.

Full isolated suite status at checkpoint:495 files,351 pass,144 fail/errors still needing classification. Logs were `/tmp/oct6-full-isolated.txt` and `/tmp/oct6-full-isolated.logs`; checkpoint `classification.json` preserves classification data. Failures span native arcade/house/turret/projection, court frontages, roof details/eave fits, planting/seating, ranges/upper spans, closures/depth/dead ends. **Do not call all failures baseline.** Reproduce relevant failures against baseline or change-off individually.

## Running checks and preserving evidence

Godot executable: `/Applications/Godot.app/Contents/MacOS/Godot`. Use an explicit `/tmp` log file. Native GUI renders have used escalated execution with this executable as the approved prefix. Do not leave assert/parse-error processes running; some do not exit automatically.

Focused test from repository root:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/town-check.log -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/test_parallel_range_footprints.gd -gexit \
  > /tmp/town-check.out 2>&1
```

Canonical production render:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . \
  --log-file /tmp/town-review.log \
  -s tests/harness/suntail/kit_town_review.gd -- \
  --output /tmp/town-review --cities 53:grand \
  --views overview,courtyard --garden-grass
```

Useful matched cameras:

- Twin gable: `53_grand_court_deck.00_0`, eye44,7.7,52 → target33,8.5,54, FOV80.
- Garden cap: `--view 'cap:40,7.7,40:51,8.5,38:80'`; also deck01_2.

Production actual-player scripts have been preserved in checkpoint `handoff-support/`:

- `oct6-preview-court-walk.gd`: `--seed 53 --profile grand --courts --output /tmp/court-walk.json`.
- `oct6-production-native-walk.gd`: supports native entrances, skywalks, courts and selected covered-cell/flight/court-door modes. Inspect argument handling before running.

These scripts load the current production solver and canonical town payload. The older `unequal-roof-range-study/oct6-range-audit.gd`, `oct6-range-buildings.gd` and review scripts use temporary candidate copies: adapt them to production before final validation. The old roof prototype may now invoke the integrated rule and then its own duplicate rule; it is no longer a trustworthy unmodified baseline.

Archive successful/failing logs, metrics and matched images in QA, and append factual results to the checkpoint. Temporary files alone are not a durable handoff. Preserve both rejected evidence and accepted fixes; do not label a render accepted merely because it completed.
