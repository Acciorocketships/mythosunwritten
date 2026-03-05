# Known Issues Dossier

This folder contains deep-dive issue reports for terrain generation behavior and performance.

## Files

- `socket-fill-prob-semantics.md`
  - Fill-prob semantics drift (`0`, `null`, missing key).
  - Blocking vs non-blocking adjacency behavior.
  - Current mismatch between desired and actual behavior.
- `generation-lag-and-stall.md`
  - Generation lag / "edge of map" stall symptoms.
  - Runtime profiling findings and bottleneck analysis.
  - Queue-focused root cause, fix details, and post-fix movement/requeue logs.
- `adjacency-coverage-gaps.md`
  - Why diagonal relationships can still appear.
  - Test-piece socket coverage mismatch vs level rules.
  - Socket-level evidence and implications.
- `current-regressions-and-test-state.md`
  - Known failing tests in current branch.
  - Which failures are pre-existing vs introduced.
  - Verification status and risk notes.

## Scope

These documents capture:

- Repro steps
- Low-level logs
- Root cause hypotheses and confirmed findings
- Fixes attempted
- Outcome of each attempt (failed / partial / successful / introduced side effect)
- Recommended next actions

