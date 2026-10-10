# Native curved eave / ridge contact candidate

Applied, not yet accepted. The previous goal turn verified the completed palette change but did not advance the remaining roof work. This turn changes production roof emission and adds focused regression coverage.

`KitRoofMeshUnion.fit_ridge_contacts` measures the already-realized upward eave triangles of other roofs. Where that skin covers a ridge cap bearing, vertical prisms terminate the complete cap height, keeping the native curved eave intact. Same-roof contacts, lower eaves, underside faces and degenerate projected triangles are excluded. Placement clip volumes flow through the existing render/collision clipping path.

Frozen actual seed127/large geometry identifies landmark00/k0229 and k0231 as affected: 11/15 cutters respectively; exposed k0229 survives, buried end k0231 has zero vertices. Both opposite native close views inspected. The large cap protrusion is removed, but a small sliver remains at the reverse seam. This is NOT full junction art acceptance. Need identify/resolve that remnant, repeat final views (the projected-area guard was added after these renders), and run broader roof/clearance/collision/holdout checks before accepting this and the crown repacking candidate.

Focused suite: 11 tests, 98 assertions pass (contact fitting, backed sheds, crown repacking). `git diff --check` passes. Source backup and exact scoped candidate patch are attached. All run handles terminal. Full redesign goal remains active.

## Full-width termination follow-up

Actual triangle picking corrected the initial visual inference: the remnant is landmark00/k0229 surface2, still the ridge cap (pixels766,366 /770,378 /766,382). Full-width termination removes those side flutes. Admission is restricted to caps whose base is at/below the other roof's low rim (nominal eave + existing0.2 union backing tolerance). Once admitted, the full covering pitch terminates the ornament. Restricting only cutter triangles to that rim was rejected: it left an isolated cap fragment above the removed band. Applying the rule to higher caps was also rejected: it notched an unrelated upper ridge. Final opposite close views show both defects resolved and the covering cornice retained.

Final-source focused suite:27 tests/12,099 assertions pass, covering cap bearing/width/high junction exclusion, clipping/collision slivers, measured eave preservation, junctions, backed sheds and crown repacking. The earlier candidate's broader run:18 tests/12,662 assertions, including six finished public-air fixtures, all pass. Earlier-candidate four-town survey127/83/103/8:204 roofs, open/gable holes/unsupported/eaves-cut all0; one known thin103 crown. Those broader runs predate the final full-width/rim-admission refinement and must not be presented as final-source corpus proof.

This is local visual acceptance of the repaired127 contact; final corpus/player acceptance of the crown/roof candidate remains outstanding. No live processes remain. Full redesign stays active.

## Final source bounded acceptance

Final-source four-town survey127large/83grand/103grand/8grand reproduces204 roofs: zero exposed open ends, gable holes, unsupported air roofs or lost eaves; only the existing103 thin crown remains. Final127 actual-player skywalk/source-bridge routes6/6 pass in both directions (these are circulation checks, not a walk on the roof itself). Together with final27-test suite and matched opposite views, this accepts the bounded mixed-kit cap-contact repair and127 crown repacking, not the full redesign. The six-fixture public-air run above remains explicitly earlier-candidate evidence.
