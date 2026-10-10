# October 3: tunnel-bearing experiments and narrow masonry windows

Status: **tunnel experiments rejected and reverted**. Only the independently
validated narrow-wall window fitting change remains from this pass. This does
not complete the owner's architecture or enclosure requests.

## Retained change

`KitRetainingWindows.fit` now considers a complete native decorative window on
2-module retaining faces. Previously it rejected every run shorter than three
modules before measuring fit. Actual emitted masonry must fully back the panel;
its native size, public-air checks, collision checks, tower clearance and
competition with other ornaments remain unchanged. Structural backing is not
excavated and these panels do not claim to create inhabited rooms.

Final window/relief suites: **7/7 tests, 7,354 assertions**, 38.265 seconds.
Native 41/large views in `retained-windows/` were inspected: panels sit on the
masonry between native timber and below floors without clipped geometry. This
is a modest facade improvement, not acceptance of the large flat street faces.
Quiet production: **7,208 ms < 8,000 ms**, all 149 assertions pass (53.027 s
for the complete test); no simultaneous Godot jobs.

## Rejected recovery experiment

The source carver preserves tunnel jambs, but the regional no-plot shoulder
flood can lower them to an adjacent house floor before `cover_tunnels` admits a
room. A candidate recovered only original unexcavated side mass for admitted
over-passage plots. A 100-seed source survey initially found seven recoveries.

Source recovery alone did not produce the intended completed rooms. The grid
retained tunnel crowns before composition, but retained no-plot piers afterward.
Retaining both early enabled whole covers in 35/large, 32/grand and 24/grand.
A stronger ground-to-crown proof then correctly rejected 35/large because its
proposed support crossed lower carved air. Cleanup returned unused recovered
piers unless another real room, shared cover or walked surface needed them.
The recovery and floating-mass suites passed 10/10, 217 assertions; the actual
player passed the recovered 32/grand route in both directions. These are results
of the **rejected candidate**, not claims about the retained implementation.

Matched native images decided against it. `before/32_grand_bore-mouth.png` and
`final32/32_grand_bore-mouth.png` show that the baseline already had an overhead
bridge. Recovery spent a potential house frontage on a taller, plainer stone
pier; the extra source-labelled cover did not mean better street enclosure.
The raised comparison likewise replaces a detailed low house with stone.
Adding a native window did not redeem that architectural regression.

All changes to `WarrenPlotPlanner`, `WarrenMazeSourcePlan`, and
`WarrenVolumetricSolver` from this experiment were restored byte-for-byte to
this pass's starting files. Patches and candidate tests are archived here as
rejected evidence, outside executable test paths. The temporary player route
flag was removed too. Earlier accepted work in those files was preserved.

## Rejected late-composition retry

A second experiment retried only reserved passage rooms after ordinary residual
rooms had been built. The reviewed 31/large, 43/grand, 103/grand, 101/large and
7/standard towns gained no covers; the retry was removed. Several source jambs
are house plots whose solid planning envelope includes unused crown/roof bands,
not whole built rooms or claimed stone at the crown. The kit can roof these
shorter completed rooms below the intended cover. Others lack the matching built host storey.
Changing pass order alone does not provide the missing architectural support.

## Next work

Boring and house partition must reserve a complete inhabited support/cover
compound together, accounting for the actual storey and roof contract before
rooms are assigned. Do not recover a no-plot pier early at the expense of a
later house frontage. Measure finished geometric overhead coverage, distinguishing
existing bridge/deck enclosure from newly labelled source covers. Keep the
owner's tower junctions, stepped massing, shallow embedded wall facades and
sheltered climbs open until native visual comparisons improve them.

The 35/large and distant 32/grand candidate cameras in `after/` were either
rejected candidates or occluded and are not art acceptance. `close/`, `before/`
and `final32/` contain the diagnostic matched/nearby views. No production
terrain change, seed-specific layout override, commit or PR was made.
