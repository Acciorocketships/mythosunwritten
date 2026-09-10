# Branch consolidation — September 10, 2026

The September 5–9 working implementation is the integration source. It includes
the reviewed town construction, native facade assets, entrance/stair motion,
river/bank/water fixes, atmosphere rebuild and streaming priority improvements.
The design and construction constraints in `AGENTS.md` still apply; consolidating
Git history does not certify the outstanding world-generation failures as fixed.

## Branch decisions

| Branch | Decision and evidence |
| --- | --- |
| `codex/village-september5-evening-review` (`01a6e1b4`) | Preserve its three commits and commit the continuing September 5–9 work. |
| `codex/long-mountain-rivers` (`48bc502a`) | Already an ancestor of the review branch. |
| `codex/atmosphere-world-rebuild` (`67005ee9`) | Integrate the seven-commit history. Of 97 changed paths, 77 initially matched the working files exactly and 20 had subsequent changes. No changed file was absent or reverted to main. |
| `codex/water-travel-profile` (`fad833ae`) | Integrate its history after preserving the current implementation. Of 4,488 changed paths, 3,403 initially matched exactly and 1,085 had subsequent changes. No changed file was absent or reverted to main. The older snapshot must not overwrite later repairs. |
| `origin/feat/biomes-atmosphere` (`143fc0fe`) | Retire. Both non-merge commits are patch-equivalent to main (`git cherry` reports `-`); the September atmosphere model also supersedes this implementation. |
| Other local and remote feature branches | Retire; every tip is already reachable from main. |

The focused water/travel regression tests, telemetry, field-cache changes,
terminal pond datum and water-skin fix match the current workspace exactly.
Further edits to the streamer, mesher, river inventory and hydraulic fill are
the later September 7–9 fixes described by the review records.

The old `optimistic-edison` worktree contained a shutdown fix and subprocess
probe. The current mesher already separates CPU `compute_chunk` from main-thread
`commit_chunk`; render-resource extraction no longer occurs on the worker.
`test_compute_chunk_payload_is_safe_to_cross_the_worker_boundary` covers that
boundary. The old patch is archived rather than reapplied to the new pipeline.
The other worktree leftovers are shared asset/add-on symlinks, obsolete terrain
scenes from the retired socket engine, and temporary bisect probes.

## Integration repair and artifact handling

The initial test run exposed 49 material references carrying stale UIDs for four
textures copied across worktrees. The texture files no longer carry those UIDs.
Those external references now use their existing canonical paths. Texture bytes,
material settings and geometry are unchanged. A Godot resource-ID census was
used to identify the exact mismatches; existing catalog/dressing tests detected
the warnings before repair. An extra blank line at the end of
`WarrenMassifBuilder.gd` was removed for `git diff --check`.

Bulk September 6–8 manual-review PNG/GIF sequences and raw logs remain local,
ignored artifacts at their existing paths; the new ignore rules do not remove
them. Their reports, numeric evidence, fixtures and harnesses are versioned.
The small atmosphere and water reference galleries remain versioned. Local
links to bulk captures work in this checkout; a fresh clone must regenerate
those captures using the corresponding `tests/harness/september*` harnesses.

## Recovery

Before consolidation, all refs were saved in a verified complete Git bundle at
`.artifacts/consolidation-2026-09-10/branches-before.bundle`. Tracked files and
non-ignored untracked files from the main workspace were saved in
`workspace-before.tar.gz` beside it. Each other worktree's uncommitted diff and
untracked files have separate patch/tar archives in the same directory. Shared
source assets and add-ons in the main workspace remain in place.

The recovery directory is deliberately ignored by Git. It preserves the old
branches without leaving development branches or old worktrees in the active
workspace. Existing historical release/checkpoint tags are retained.

## Validation

The existing September 9 review records 1,195 tests: 1,164 passed, 30 failed,
one pending. Known failures concern historical cliff/water fixtures, the
60-second cold-start deadline and town composition/layout expectations. That
record is at
`/Users/ryko/Documents/Codex/2026-09-08/i-did-a-manual-judging-pass/outputs/final-validation/report.md`.

Fresh consolidation validation and final repository state are recorded below
after the full test run completes. Logs live in the recovery directory.
