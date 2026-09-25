# Hillside reach routing: broader survey and terminal-basin correction

This is a detached water-planning experiment, not a production water fix. W01 and the full original judging register remain open. Production WaterPlan and every pass-110 fixture are unchanged; the new study subclasses the old one so its evidence remains reproducible.

## Failure found beyond the initial seven sources

The survey covers source cells `[-6,0] × [-6,0]` for seeds 2697992464, 1 and 9: 147 candidates, 103 actual sources. The original study reaches existing raw terminal basins for 102 of them. Source `(-6,-4)` in the reported seed instead exhausts its 360-station budget.

The failure is an incorrect successor at an already completed lake. At its raw last station 239, that river has reached its own terminal pond centre (`footprint_t = 0`, pond surface 1.2 m). The experiment nevertheless jumps 16.94 m into station 46 of river `(-4,-4)`, because it chooses an overlapping higher-priority channel before recognizing the raw endpoint. It then runs out of work before reaching the other lake. Increasing the budget would retain this unnecessary continuation.

`terminal_reach_study.gd` makes the raw terminal an absorbing endpoint. Existing upstream confluences still follow their receiving channel, including downstream reaches newly supplied after their original source diverted. It adds no pond and no fallback to the original production route. A two-channel regression fails two of four assertions before this change and passes afterward. Three final synthetic tests / twelve assertions also check supplied-tail preservation and equal-level query order.

## Measured results

All 103 sampled routes now terminate at existing raw basins within the unchanged work/arc budgets. Their 14,885 station records have no rising bed steps. The forward/reverse survey stores a SHA-256 of every complete station sequence as well as all junctions; `audit.py` compares both orders. See `audit.json` for final verification.

Only three sampled source routes change relative to pass 110, all in seed 2697992464:

| Source | Before | Corrected |
|---|---|---|
| `(-6,-4)` | 360 stations; budget exhausted | 240 stations; own existing lake |
| `(-4,-3)` | 330 stations; continues through that lake | 53 stations; receiving lake `(-6,-4)` |
| `(-4,-4)` | 324 stations; continues through that lake | 47 stations; receiving lake `(-6,-4)` |

The reported `(-2,-1)` route is unchanged: its high channel joins `(-3,-4)` at incoming station 43 / receiving station 285 and finishes in 64 stations. This still removes the proposed high continuation past the missed 24 m confluence; it has not yet been applied to actual game water.

The prior 2,628 m displacement example was caused by the bypassed terminal lake. The corrected corpus stays within 2,400 m, but that observation does **not** prove a universal source-discovery radius for composed routes. The maximum possible arc remains 4,320 m; a future adapter must derive a complete bound rather than retain the raw-prefix bounds filter.

## Remaining risks and next integration requirements

- Ten sampled paths revisit a previously used raw channel. There are no repeated station cycles, but the short switches still need geometric/current review.
- Join drops reach 52.28 m in the reported seed, 28.5 m in seed 1 and 49.58 m in seed 9. The reported seed's source `(-2,-2)` immediately selects a broad alluvial channel 92.90 m away. Its width admits that point mathematically; this does not establish a physically sensible descent, bank opening or water surface.
- Sampling 103 sources does not prove that every possible composed path reaches a basin within the work budget. Budget-exhausted paths remain explicit failures, not accepted rivers.
- Integration still requires consistent spatial discovery, shared downstream geometry, source/terminal basin ownership, land-bar lineage, and actual carved terrain and filled-water checks. Production raw-bound pruning assumes a shortened prefix and is incompatible with these composed paths.
- No native rendering, physics acceptance, fresh P10/P21 comparison, or performance claim is made. The next useful gate is a detached native-plan adapter with complete source discovery and explicit refusal of unresolved routes, followed by matched terrain/water and surrounding-channel review.

## Reproduction

Run `tests/fixtures/september19/hillside-reach-corpus/probe.gd` headlessly with `-- --seed=2697992464` (also 1 and 9). Add `--terminal` for the corrected experiment, and `--reverse` to reverse source-query order. Run the fixture `test_terminal.gd` through GUT. `junction_probe.gd` reproduces the measured terminal and large-drop contacts. Finally run `python3 tests/fixtures/september19/hillside-reach-corpus/audit.py` to compare surveys and verify that production WaterPlan and pass-110 sources retain their recorded hashes.

The headless runs log the existing macOS certificate-store warning. The intentional red test exits 1; all completed surveys and the final tests exit 0. Timings include concurrent experimental runs and are not controlled performance measurements.
