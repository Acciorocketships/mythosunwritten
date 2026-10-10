# Wall-backed shed joins — bounded repair accepted

The lower one-module crown beneath a flush upper room now uses half a complete native roof, clipped at the backing wall. The designer preserves the required ridge direction, reserves plain backing panels, excludes projecting bays at that join, and rejects addressed doors, inset backing and public headroom. The assembler omits the free ridge cap for this monopitch roof; end verges extend 0.25 m, fitting under the upper eave. Existing authored roof assets and materials remain in use.

## Evidence

- Red-first constrained 2x3 lower / 2x2 upper room fixture failed before admission. Final focused shed, junction and gable suites pass 20 tests / 12,023 assertions. The shed suite covers both kits, all four orientations, doorway/headroom/inset rejection, realized backing-plane clipping and absence of ridge caps.
- Active falsification against the saved old assembler restores three stray ridge caps; the current assembler emits zero. See `oct5-shed-ridge-falsify.out`.
- Matched native before/after front/side views for both packs in `native-final` show clean sloping wall contacts, without the prior small ridge/barge remnants. Full town8 matched views in `town-before` / `town-after` show the small double-pitched strip replaced by one slope into the taller wing. `town-alternate/8_grand_alternate.png` provides an unobstructed nearby angle. The earlier reverse and detail cameras were inside other buildings and are explicitly excluded from acceptance.
- Final roof survey: 93 roofs across 8/grand and 103/grand; zero exposed open ends, gable holes, unsupported air roofs or cut eaves. Town8 thin roofs 1→0. Town103 retains one thin bridge-end roof; it lacks complete own-room backing and is not solved by this repair.
- Final safety survey: towns8/13/43/103 all have zero floating pieces and public-air intrusions. Covered quarters112/36/100/40 respectively match the exact pre-shed court baseline. No extra enclosure claimed from this roof change.
- Actual-player town8 courtyard traversal passes four of four routes, forward/reverse for its main square and elevated deck. Raw traces and compact summary are archived here.

The initial renderer omitted generated surfaces by using EnvironmentCommitQueue; those apparent gaps were a harness error. The accepted previews use FeatureCommitQueue. Decorative RNG draws change near the new shed because it does not draw dormers/chimneys/ridge peaks; safety is checked on the resulting complete town.

Reproduction: `Godot --path . --log-file /tmp/shed.log -s tests/harness/suntail/backed_shed_review.gd -- --output /tmp/shed-review`. Focused test: `tests/test_backed_shed_roofs.gd`. Exact production deltas are archived in the three `*-final.patch` files. All associated jobs are terminal.

This accepts only the backed-shed join repair. The 103 bridge-end thin roof, increased fitting spire supply, broader interior-square/circulation acceptance and full October1 redesign remain open.
