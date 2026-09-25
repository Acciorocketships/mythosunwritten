# Upper cliff relief — pass 80

The height-relative detail fade left the upper quarter of tall cliffs without physical bumps. Production now retains a restrained 40% detail contribution based on actual distance below the crown, while the existing descent rule still controls full-strength lower formations. The crown collar and crown-to-foot projection allowance remain unchanged. All variation is physical geometry; there is no material or crack-network change.

## Evidence

The new 32/64 m fixed-seed geometry regression reproduces red on the saved pass-79 baseline. Final upper-face changes over 0.08 m reach 865 vertices across 111 columns at 32 m, and 5,584 vertices across 180 columns at 64 m. Both preserve the upper 1.3 m exactly.

The full-strength absolute-distance study passes eleven geometry tests / 25 assertions, but looks too busy in the tall view and is rejected. The selected restrained variant retains the lower formations and breaks up the former broad smooth upper band with less contrast. Tall upright composition and overall cliff art are not accepted by this scoped improvement.

The full focused/integration run passed 31 of 32 tests / 106 of 107 assertions. Its one failure was an obsolete pass-69 invariant that held the entire upper quarter unchanged, conflicting with this deliberate upper-face revision. That assertion now protects the actual upper 1.3 m crown collar, while the new test requires physical relief below it on both wall heights. The affected test and upper-face regression then pass together (two tests / twelve assertions). Across the completed run and targeted rerun, all 32 distinct tests / 107 assertions pass; this is not a second full-suite run. The unchanged production mesh also retains 57/57 covered cap samples, 460 treads with none missing or steepened, and 341 grass roots with none escaped or buried. Actual Godot collision samples all 64 changed stone faces successfully; one unchanged baseline miss remains among 887 total probes at `(76.16666, 0.398533, 7.696733)`. Maximum contact error is 0.000010874 m.

Final native Metal views are recorded under `final-world` (17 views) and `final-tall`. Inspected final views are `final-world/P17_front.png`, `final-world/P20_oblique.png`, and `final-tall/oblique.png`. The ordinary game view gains restrained physical relief while retaining connected ledges. The tall study still shows upright forms, broad quiet regions, and occasional angular details; these remain art defects, not an accepted final composition. The game harness replays the frozen world and uses ReviewCam for the reported F3 camera poses. Supplemental oblique views use the fixed study cameras. This is not fresh-world traversal or a controlled performance result.

The original water, village, streaming and biome issue register remains open. This change addresses only the empty upper detail band; it does not close the broader cliff-composition requirements.

[Game view](final-world/P20_oblique.png) · [Tall view](final-tall/oblique.png) · [Production delta](production.patch)
