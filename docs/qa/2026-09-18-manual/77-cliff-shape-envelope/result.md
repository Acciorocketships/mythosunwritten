# Physical rock-face variation — pass 77

Production adds local physical bumps sampled from the existing detached Nature rock body profiles. Their widths, heights, depths, lean and spacing vary. The completed closed shell is displaced consistently across shared vertices; render geometry, collision and placement bounds therefore retain the same surface. No material, crack overlay or normal-map change is involved.

The existing grass ledges, pointed turf tips, adjoining support triangles, upper attachment and buried roots are protected. Added projection fades into neighboring protected regions and is reduced where an existing large shoulder already projects. The crown-to-foot limit remains in force.

## Verification

- Red-first photo-anchor regression: baseline has zero added face displacement and fails the three variation assertions. Production moves 841 exterior vertices outward by more than 0.08 m across 82 columns; crown change is zero and all 1,230 original turf points remain.
- Final production GUT run: 28 tests / 92 assertions pass (`production-tests.log`). Includes 460 tread endpoints with no missing or steepened caps, 31 closed photo shells without bad edges or degenerate faces, 16/32/64 m corner cases, ownership and admission checks, and 347 actual grass-worker roots without escaped or buried roots.
- Actual Godot collision: 201 sampled changed stone faces have zero missed contacts. The complete 887-contact survey has one miss at `(76.16666, 0.398533, 7.696733)`; the exact same miss reproduces on the saved pass-76 baseline. Maximum contact error is 0.0000106624 m. The all-sample diagnostic remains failing; the changed-surface diagnostic passes. See `physical-changes.json`, `physical-treads.json` and `before-physical-treads.json`.
- Seventeen final frozen-world views and a 32 m tall study were captured with native Metal rendering. Inspected final views include P20 reported, P20 oblique, P17 front, P12 side and tall oblique. This is not a claim that all seventeen received individual visual acceptance.

## Art judgment and rejected studies

The selected change adds integrated local volume while retaining the ledges and upper edge. Broad plain faces, inherited upright composition and some thin ledges remain visible, especially on tall upper walls. This is incremental improvement, not complete acceptance of the requested cliff style.

Whole-body replacements weakened ledges or created excessive upper projection. Strong plane and ellipsoid studies looked embossed, wrinkled or muddy. Dense Nature bumps crowded the tall wall. Partial tread protection moved pointed turf ends or created sharp shading slivers; the selected version protects complete finished tread supports and their neighboring columns. A subdivision experiment introduced bad edges and degenerate triangles and was rejected. Study sources and captures remain beside the selected evidence.

The surface-profile test now honors its candidate-generator environment override consistently; two older candidate logs tested production for their first two assertions and are not candidate acceptance evidence. No thresholds were relaxed.

## Scope and limitations

Production matches `tests/fixtures/september18/cliff-shape-envelope/finished-native.gd`; the exact delta from pass 76 is in `production.patch`. Captures replay a frozen world, not fresh generation. No actual player traversal or controlled performance comparison was performed. One unchanged baseline collision sample remains unresolved. C01–C03 and the original water, village, streaming and biome register remain open.

[Final game view](production-world/P20_oblique.png) · [Tall study](production-tall/oblique.png)
