# Rejected height-transition candidate

The candidate passes structural checks but creates prominent diagonal closing faces at adjoining walls of different heights. It is not production code. All five production files are restored to their before copies.

`rejected-candidate/` preserves the exact source used for the final native captures, collision audit and passing replay. `production.patch` in the QA evidence directory records its delta against the restored baseline. The four tests moved here are candidate/reproduction cases outside the ordinary test catalogue; their production imports intentionally reproduce failures on the restored implementation. Their green logs were recorded with the candidate applied. Do not infer current production acceptance from those logs.

`fresh-audit.gd` and `physics.gd` inspect the archived rejected fresh world. Replay auditing requires that candidate implementation. The review image scripts that load a frozen snapshot without reconstruction remain usable independently.

See `docs/qa/2026-09-19-manual/99-height-transition/result.md` for excluded captures, the visual rejection and exact scope.
