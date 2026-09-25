# Continuous existing ledges at inner turns — pass 97

The paired wall formations already cover the inner turn, but their independently generated turf ledges meet at different elevations. At the photographed matching-height turn, 34 shared tread samples differ by up to 0.42133379 m. This makes a curved rock slit interrupt an otherwise broad ledge.

The change selects corresponding existing broad treads and gives them a shared elevation near the intersection. The adjustment feathers back into each original wall. It moves existing rock and turf vertices vertically by at most 0.55 m: the tread footprints, triangle topology, buried roots, gray backing and flush crowns stay intact. The final detached bounds still pass the existing complete admission rules. Saved recipes carry the controls so captured scenes reconstruct the actual production geometry.

## Reproduction and rejected alternatives

The matching-height turn is rooted at (-445.5, 32, -301.5), with 8 m parents. The stepped turn is rooted at (-445.5, 28, -277.5). The regression casts downward rays onto both actual turf meshes in the shared corner area. Before the change it fails the 2 cm continuity bound at 0.42133379 m; afterward the same 34 shared samples have a maximum difference of 0.00000047684 m.

A first common-cut study was invalid because its copied generator had not prepared the native shape library; those captures are excluded. After preparation, replacing the parents' cut profiles aligned elevations but changed too much of the surrounding ledges. A finite replacement and a curved replacement introduced new pointed ends at their transitions. Those variants are rejected. The selected vertical adjustment preserves existing ledge topology and does not create new shelf starts or tips.

## Verification

The regression plus inner-connection tests pass eight tests / 83 assertions. The footprint, root/crown, order and saved-recipe checks pass three tests / 53 assertions. The broader rotated-corner, complete-admission, water-ownership and historical-replay set passes 18 tests / 68 assertions. In total, 29 tests / 204 assertions pass. Fresh production completes nine support chunks in 426.832 seconds. This concurrent run is not a controlled performance comparison. Its saved-scene writer retains the previously documented editor-only shader-global query diagnostic; generation and capture exit successfully. The fresh native audit reconstructs all nine inspected corner/connected-wall recipes exactly: four connected walls, four outer turns and one remaining independent inner turn. All 110,741 distinct inspected triangles occur in production collision. All 1,218 foot probes remain buried with no missing ground. Native contact checks pass all 845 samples with a maximum error of 0.00003146 m; all 728 root samples remain buried below actual ground.

## Visual review

The controlled five-camera study removes the curved slit in the broad matching-height inner ledge. Outer geometry and the existing footprints are unchanged. The stepped lower turn retains a sharper crossing of other shelves, so this is not universal corner-art acceptance. Some faces remain plain and some tips remain pointed. Broader cliff art and the original water, town, streaming and biome register remain open.

[Study inner turn](height-warp/inner_above.png) · [Study stepped turn](height-warp/lower_inner_above.png) · [Production delta](production.patch) · [Native contacts](physics.json).

## Fresh final review

Six supplementary close views of the new production snapshot confirm the selected study. The matching-height inner ledge is continuous across the previously visible slit. The outer silhouette is retained. At the stepped lower turn, other shelves still cross sharply; the short independent inner turn retains a visible change in surface rhythm. Neither is marked accepted. Fresh grass and plant placement differ from the frozen study, and no claim of identical vegetation is made.

The original three P12 ReviewCam poses remain in `fresh-P12`. Their close obstruction limits their usefulness for judging corners; the supplemental views provide that evidence. There is no new player-traversal, global-performance, full-suite or overall-cliff acceptance.

[Fresh inner](final-details/inner_above.png) · [Fresh outer](final-details/outer_oblique.png) · [Fresh stepped inner](final-details/lower_inner_above.png) · [Short inner](final-details/short_inner.png) · [Fresh geometry/collision audit](fresh-audit.json).
