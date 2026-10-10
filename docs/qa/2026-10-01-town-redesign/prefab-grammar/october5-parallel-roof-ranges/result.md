# Short parallel roof ranges, October 5

The six-town finished-roof survey found side-by-side short parallel piles that the existing end-to-end junction rule could not combine. In 103/grand, the bridge house at roof rectangle (0,-4; 2x2), band 9, and its landing at (2,-4; 2x2) had intersecting eaves. Native before views confirmed protruding valley fragments and two disconnected gable compositions.

`KitRoofJunctions.combine_parallel` now joins aligned, edge-touching short piles at the same datum into a complete rectangular range and chooses its long ridge axis. It never fills gaps or staggered corners, and does not rewrite already-open branch ends. The town assembler admits the complete new height envelope using actual room cells, public air/crowns, passage claims, owner reservations and the selected kit's roof profile. Compatible kit families share one roof finish; old dormer slots are discarded because their slope coordinates no longer apply. Source asset geometry/materials remain native.

This is a specific roof-composition repair, not a claim that long roofs or all town architecture are solved. In six towns only the 103/grand pair consolidated; the other close pairs stayed unchanged. Later existing collinear reconciliation makes the accepted range continuous with its aligned neighbour. No seed-specific production rule is used.

Validation so far: the three small tests pass 19 assertions; disabling the new rule reproduces 10 failed assertions in the combination test. This disabled-rule check was performed after the initial candidate implementation, not claimed as chronological red-first development. The existing native roof-junction suite passes 9 tests / 11,975 assertions. Six-town enclosure records are identical to the prior stacked-balcony baseline, including all 220 covered quarters; every town has zero floating masses and zero roof/public-air intrusions.

Matched native 103/grand views were inspected from both sides: eye (40,48,-48), target (8,28,-12), FOV45; reverse eye (-25,44,14), same target/FOV. The united roof removes the crossed short eaves and reads as one closed range. The wider street still has tall flat-sided stacks; that broader requested redesign remains open. A final real-town regression and actual player traversal are recorded below after completion.

Actual-character traversal completed successfully on all three 103/grand skywalk/source-bridge routes in both directions (6/6), including source_bridge.01 beneath the changed roof. The same isolated ray-at-endpoint miss reported by the prior harness remains, but continuous traversal reaches the destination; no claim of a complete ray audit is made.

The initial real-town test expected the intermediate 4x2 union exactly and failed despite both old piles being absent and both safety audits passing. Existing end-to-end reconciliation subsequently extends that union to the neighbouring range, as seen in both native views. The assertion now requires one continuous ridge enclosing both original piles, rather than freezing an intermediate footprint.

Final focused suite: 4 tests / 24 assertions pass, including the 103/grand built-town regression. All processes completed; temporary disabled-rule source was restored.
