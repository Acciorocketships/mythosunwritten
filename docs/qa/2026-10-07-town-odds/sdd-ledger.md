# SDD ledger — plan: docs/superpowers/plans/2026-10-07-town-odds-layer.md
Spec: docs/superpowers/specs/2026-10-07-town-odds-layer-design.md
Branch: town-redesign (worktree /Users/ryko/.codex/worktrees/77a0/story); start HEAD 5777689f7

## Pre-flight scan
| Tasks | Shared file/interface | Finding |
|---|---|---|
| T1↔T4↔T9 | tests/harness/town_fingerprint.gd | T1 creates; T4 adds --odds + TOWN_CHARACTER; T9 adds CLEARINGS print. Consistent. |
| T3↔T4 | TownCharacter / TownOddsProgram | T4 adds attach/of to T3 file; signatures match. |
| T3↔T8 | terrain/villages/town_odds.tres | T3 empty table; T8 appends knobs. Consistent. |
| T4↔T5/T8/T9 tests | WarrenMazeSitePlanner.plan(seed, {}, profile[, stop]) | exact signature unverified; each task told to check. OK. |
| T6↔T7..T11 | fingerprint baseline | T6 rewrites baseline (intended output change); later tasks compare to new baseline. Consistent. |
| T7↔T9 | excavation copy-field lists | T7 adds tunnel_attrition, T9 adds court_clearings to same lists. Sequential, fine. |
| T8↔T9↔T10 | propose/carve/court_clearings/is_green_court | names and record keys match across tasks. |
| T10↔T11 | clearing decks + court walk | consistent. |
| T1 self | harness compares source+payload | consistent. |
| T2 self | delete list vs do-not-delete list | consistent; T2 must drop targets still referenced. |
| T3 self | tests vs code | consistent (WEIGHTS jitter per spec as updated). |
| T5 self | test uses MAX_*_STRAIGHT_RUN consts on WarrenMazeSourcePlan | exist (lines 26-27). OK. |
| T8 self | test_thick_blocks assumes numeric block_thickness | flagged in task; implementer verifies. |
| T9 self | test_unconnectable_clearing_leaves_no_trace only checks lanes map to kept clearings | weak but meaningful; see ruling. |

Ruling: T9's unconnectable-clearing test may stay as written (asserts no orphan clearing lanes) — constructing a guaranteed-unconnectable site needs a synthetic massif; the guardrail is also exercised by `continue` path — cost if wrong: an orphan reservation could survive unnoticed until T11 visuals.
Ruling: Production review/test runs use flat-ground towns (kit_town_review payload) for fingerprints — the real-terrain path shares generation code; T11 renders cover visuals — cost if wrong: terrain-only regressions caught later.

## Progress
Task 1: dispatched (BASE 5777689f7, implementer sonnet)
Task 1: ⚠️ resolved — var_to_bytes object-blindness: batches/plots/surface meshes are plain Dictionaries/Arrays/Transforms (EnvironmentInstancePayload.add), no Objects.
Task 1: minor (deferred): baseline.json stores volatile "ms"; no null checks for --out/--compare files; no trailing newline.
Task 1: complete (commits 5777689f7..8bf28947d, review clean)
Task 2: dispatched (BASE 8bf28947d, implementer sonnet)
Ruling: Task 2 kept PlotVoid/RisingRing chain, TARGET_* and MAX_PAIRED_* consts still referenced by tests/defaults — safe-side; cost if wrong: some dead code remains (follow-up cleanup).
Task 2: ⚠️ resolved — WarrenVolumetricSolver function removals verified by FINGERPRINT_MATCH + clean import.
Task 2: minor (deferred): orphaned data classes VillageMassingSlot/Placement, VillageTimberCellCompiler, VillageTimberFabricPlan; PlotVoid/RisingRing chain follow-up.
Task 2: fix round 1 dispatched (FIX_BASE f3c0a4837) — hamlet_walk harness extends deleted script
Task 2: fix round 1/5 (2 addressed, 0 open; commits f3c0a4837..9f051b8b7)
Task 2: complete (commits 8bf28947d..9f051b8b7, review clean)
Task 3: dispatched (BASE 9f051b8b7, implementer sonnet)
Ruling: --odds overrides are numeric-only in this plan; WEIGHTS knobs rejected by parse_overrides/with_overrides — spec only requires numeric A/B; cost if wrong: weights A/B needs a later small extension.
Task 3: minor (deferred): RANGE_INT clamp distorts mean at bounds (undocumented); independence test does not compare knob b; no negative-seed/WEIGHTS-spread tests.
Task 3: fix round 1 dispatched (FIX_BASE 0d1730387) — WEIGHTS override no-op
Task 3: fix round 1/5 (5 addressed, 0 open; commits 0d1730387..06675e8bf)
Task 3: complete (commits 9f051b8b7..06675e8bf, review clean)
Task 4: dispatched (BASE 06675e8bf, implementer sonnet)
Task 4: minor (deferred): solve_selected / from_volume re-derive profiles without character (test-only callers); consumers must read character via source plan's scale_profile (TownCharacter.of on a re-derived profile drops overrides). of() caches by seed only. No test of override propagation via generate.
Task 4: complete (commits 06675e8bf..b9980a069, review clean)
Task 5: dispatched (BASE b9980a069, implementer sonnet)
Task 5: fix round 1 dispatched (FIX_BASE b2ededc05) — loop/straight-run shortfalls diagnostics-only, not in advisory_shortfalls
Task 5: fix round 1/5 (1 addressed, 1 minor partial; commits b2ededc05..d53b75857)
Task 5: minor (deferred): no end-to-end _solve_maze test for forwarded shortfalls; tower_annexes/room_outcroppings writes only shape-tested (dormant paths).
Task 5: complete (commits b9980a069..d53b75857, review clean)
Task 6: dispatched (BASE d53b75857, implementer sonnet)
Ruling: Task 6 facade module pick hashed (plan text) even though the old linear sum intended a window/boarded alternation — the audit flagged the sum's diagonal stripes; cost if wrong: facade rhythm reads more random; revert to an explicit alternation knob in the palette migration.
Ruling: Task 6 skywalk ordering keeps seed 0 — it decides which spans are accepted (layout, not dressing); skywalk odds migrate later; cost if wrong: skywalk order stays shape-determined until then.
Task 6: fix round 1 dispatched (FIX_BASE 277ce20f0) — required seeds, 61/7 unchanged evidence, real seed tests, comment placement
Ruling: task-6-report.md was force-added to git under .superpowers/sdd (gitignored workspace); Task 7 implementer untracks it with git rm --cached — cost if wrong: a scratch report in history.
Task 6: fix round 1/5 (4 addressed, 0 open; commits 277ce20f0..aa326d3ed)
Task 6: minor (deferred): seed-dependence tests are weak (differs > 0 / seen.size() > 1); kit payload path not shown to skip facade-module pick; SKYWALK_ORDER_SALT doc reads oddly.
Task 6: complete (commits d53b75857..aa326d3ed, review clean)
Task 7: dispatched (BASE aa326d3ed, implementer sonnet)
Ruling: Task 8/9 clearings weight by distance-to-nearest-public-column (BFS over massif columns), not plan.block_thickness — block_thickness is a street-spacing ramp from the summit (roundi(lerp(1.5,3.5))), not leftover uncut mass; spec says 'thickness / distance-to-street'. propose()/carve() drop the thickness parameter. Cost if wrong: bias toward a different notion of 'big block'; tunable via clearing_block_bias.
Task 7: fix round 1 dispatched (FIX_BASE c2aec0b95) — attrition.md unit mismatch + released-crown claim
Task 7: fix round 1/5 (4 addressed, 0 open; commits c2aec0b95..12c286597)
Task 7: complete (commits aa326d3ed..12c286597, review clean)
Task 8: dispatched (BASE 12c286597, implementer sonnet)
Ruling: Task 9 connector — _level_gate_connection only walks at ground grade (base_at(next) == candidate.y), so raised clearings could never connect; Task 9 adds an optional parameter allowing same-band paths at any height (keeping slot_is_borable + completes_public_square checks). Cost if wrong: raised connector lanes may need extra support checks; T11 visuals + audits catch it.
Task 8: minor (deferred): candidate generation calls _deck_column_ok for every column x floor (≈2 min per test run; per-town cost when clearings on); no RED step recorded.
Task 8: fix round 1 dispatched (FIX_BASE e40c9f554) — shape fidelity, area attainment, raised floors need same-band street, roll salts
Task 8: ⚠️ resolved — propose has no production callers (grep), so skipped fingerprint rerun is valid.
Task 8: fix round 1/5 (4 addressed, 0 open; commits e40c9f554..6f6878be1)
Task 8: minor (deferred): area/street-reach test classifies ground vs raised via cells[0] and accepts any cell in reach; non-centre cells of a raised clearing may be >6 columns from a street.
Task 8: complete (commits 12c286597..6f6878be1, review clean)
Task 9: dispatched (BASE 6f6878be1, implementer opus)
Ruling: Task 9 fix — apply same-band street-reach filter to ground-floor clearing candidates too (reviewer recommended; ~half of proposals withdrawn otherwise) — cost if wrong: fewer ground clearings in blocks whose ground streets are far; tunable later.
Task 9: carry to Task 10 — after pruning no clearing construction reservation survives (rebuild doesn't copy them) and plot reserve/partition don't read construction_reservations; Task 10 must treat excavation.court_clearings as the blocking authority from the start of WarrenPlotReservations.reserve (and partition must never seed houses on clearing columns).
Task 9: minor (deferred): no test exercises a raised clearing carve (any_band=true path).
Task 9: fix round 1 dispatched (FIX_BASE 6f3a83c04) — reservation-overlap guardrail, ground-floor street filter, flight doorsteps
Ruling: Task 9 clearing supply is low after guardrails (kept 0/2/0/3 of 3 requested on 31/53/13/103); stair links to adjacent bands are new scope — deferred to a follow-up after the owner checkpoint (T11 reports supply). Cost if wrong: checkpoint shows few clearings; follow-up needed before enabling by default.
Task 9: fix round 1/5 (3 addressed, 0 open; commits 6f3a83c04..391e19106)
Task 9: minor (deferred): propose runs once before carving; overlapping proposals at different floors are caught only by carve's clash check (lost clearing); pre-reserved-cell test assertion weak.
Task 9: complete (commits 6f6878be1..391e19106, review clean)
Task 10: dispatched (BASE 391e19106, implementer opus)
Task 10: ⚠️ noted — pruning never drops a clearing in practice (doors are destinations); withdraw path covered by synthetic test only.
Task 10: fix round 1 dispatched (FIX_BASE 398ba4672) — per-green centrepiece, set_planned_plaza per-component check, remove_plot doc placement
Task 10: fix round 1/5 (3 addressed, 1 new; commits 398ba4672..c3b23fc0c)
Ruling: Task 10 cross-component centre-feature AABB clearance raised from Minor to Important — overlapping objects is a guardrail class — cost if wrong: one extra fix round.
Task 10: minor (deferred): maze_plaza_centre_feature_asset audit reports only first green's feature; composition corpus asserts ≤1 centre feature per town (true at default odds only).
Task 10: fix round 2 dispatched (FIX_BASE c3b23fc0c) — cross-feature clearance
Task 10: fix round 2/5 (1 addressed, 0 open; commits c3b23fc0c..d77cda827)
Task 10: minor (deferred): maze_plaza_feature_boxes re-derives clear-check boxes (drift risk); plaza seats/underplants checked against town skin only.
Task 10: complete (commits 391e19106..d77cda827, review clean)
Task 11: dispatched (BASE d77cda827, implementer sonnet)
Task 11: minor (deferred): result.md says "5 of 8 kept at most 1, 2 kept none" — data says 6 of 8 at most 1.
Task 11: complete (commits d77cda827..7210700c0, review clean)
Final review: dispatched (range 5777689f7..7210700c0, opus)
Final review: needs fixes — set_planned_plaza can reject a town when greens at different heights touch sideways (Vector2i keying); AGENTS.md not updated; result.md miscount; minors. Final fix wave dispatched (FIX_BASE 7210700c0, opus).
Final review: fix wave addressed (commits 7210700c0..a114158f3), re-review clean
