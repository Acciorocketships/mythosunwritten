# Backed stepped inner connections — pass 94

The inner junction at **(-445.5,28,-277.5)** now continues its actual adjoining walls through the recess. The 12 m wall previously lost its terminal bearing beside the 4 m terrace while a separate corner introduced another set of pointed shelves. This pass extends the existing parents and withdraws that separate corner. The matching-height connection from pass 92 and the uncompressed outer turn remain.

A taller parent is eligible only when an existing collinear upper wall covers the complete extension above the lower terrace. Removing or shortening that backing rejects the extension; the rock cannot simply continue across an exposed lower turf crown. Existing owner IDs, seed, public/grade pair admission and pass-93 per-owner hydraulic admission remain. Equal-height joins still require terminal parents. This is a bounded construction rule, not a general union of arbitrary stepped walls.

## Verification

The corrected red control reproduces one insufficient bearing among nine actual triangle probes through the photographed lower join. All nine pass after the change. An earlier fixture attempt compared a float32 anchor exactly and failed to find its target; that attempt is not used as the red geometric result.

The five-file focused run initially passes 24 of 25 tests, with two assertions failing in an outdated reservation expectation: it assumed rejecting one connection must also reject the now-independent second connection. The corrected test verifies that both blocked parents and their corner remain unchanged while the other junction proceeds. Its isolated rerun passes seven assertions. Across the final test definitions, **25 distinct tests / 148 assertions are verified**, using the full run and corrected targeted rerun; no clean full rerun is claimed. Coverage includes all four orientations, mandatory upper backing, closure/turf membership, production whole-versus-split geometry and ownership, grounding, public reservations, water ownership and saved recipes.

[Red bearing](logs/cliff94-bearing-red.log) · [Focused run](logs/cliff94-tests.log) · [Corrected reservation rerun](logs/cliff94-reservation-test.log) · [Production delta](connections.patch).

Native isolated-body verification covers four connected walls: **856 triangle contacts**, zero misses, maximum error **0.0000315 m**; **728 unique native-ground foot samples**, none exposed or missing. The initial combined-body audit reported 11 wrong-owner hits. Diagnostics showed identical coplanar back faces inside the cliff, not holes; the final audit isolates the expected body by excluding the other test bodies. Both diagnostic and final results are retained. This is not player traversal acceptance.

[Physical result](physics.json) · [Overlap diagnostic](overlap-diagnostic.json) · [Final physics log](logs/cliff94-physics-final.log).

## Fresh production and visual review

A newly generated seed **2697992464** completes nine startup chunks in **425.042 seconds**, includes both connections, and produces no escaped-water assertion. Independent checks ran during startup, so this is not a controlled performance comparison. The existing snapshot-writer diagnostic about an editor-only shader query remains.

The actual generated scene contains four connected wall formations, four outer corners and one retained inner-corner construction in the inspected area. Every inspected rock/turf recipe reconstructs exactly. All **110,073 distinct inspected triangles** occur in the production collision shapes, with canonical keys quantized to 1 mm. **1,218 unique foot probes** remain below the native ground; none lack ground. This audit inspects the generated collision, without substituting test bodies.

[Fresh audit](fresh-audit.json) · [Generation log](logs/cliff94-fresh.log) · [Audit log](logs/cliff94-fresh-audit.log).

Six close views use the freshly generated scene directly. The lower front and elevated views show filled bearing and fewer competing corner shelves. The higher matching-height junction and outer oblique view retain their previous construction. However, pointed shelf ends and striped turf remain around the stepped junction, while other gray faces remain broad and plain. This is useful connection progress, **not finished cliff art**. One short inner junction lacks two eligible parent ends and retains its prior construction. General stepped-corner, cliff-art, player-traversal, water, streaming and original-register acceptance remain open.

[Fresh lower front](final-details/lower_inner_front.png) · [Fresh lower above](final-details/lower_inner_above.png) · [Matching-height inner](final-details/inner_above.png) · [Outer turn](final-details/outer_oblique.png).

Matched prior cameras are under [pass 93](../93-fresh-corner-review/final-details/lower_inner_above.png). The `candidate` directory is a preliminary saved-world reconstruction and is not substituted for fresh production validation. Original P12 F3-based poses/captures are retained under `fresh-P12`; the supplementary close cameras provide the useful corner inspection.
