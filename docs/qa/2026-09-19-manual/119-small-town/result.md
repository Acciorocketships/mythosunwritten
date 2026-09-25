# N02 path colour and terminal platform

Scoped production repair, September 19. Other town design and street-outline complaints remain open.

The fresh seed 2697992464 capture at player (-231.7,18.1,422.5), crosshair (-233.5,18.1,424.2) reproduces both the pink ground paths and the empty upper side platform. It is a compact village, not the separate hamlet generator. Startup completed in 537.439 seconds; this different-location run is not a performance comparison with pass 117.

## Path colour

The atlas supplies the correct tan path texel (0.7725,0.6824,0.5804), but terrain applied the local turf multiplier (0.6613,0.6112,1.075), turning it pink. `SlopeAtlas.path_tint` now owns neutral earth and its subtle darker marks. Native terrain triangles, edge aprons and retained village streets use that same value. Turf keeps its original biome colour, and geometry, UVs, normals and collision are unchanged by the colour repair.

Two red-first tests reproduce the colour failure in native triangle output and retained street projection. The focused run including existing terrain tint tests passes 10 tests / 265 assertions. Three matched native Metal views of the frozen full game show the pink path becoming tan. This replay changes only path vertex colours through the production palette helper; it does not claim a fresh full-world regeneration after the repair. The initial replay assertion compared GPU-decoded normal arrays across a second upload and failed on compression round trips; the final harness checks exact unchanged geometry inputs instead. The initial render is not used as evidence.

The jagged, rectangular street outline remains visible and is not accepted as fixed.

## Terminal platform

The public route continued one level cell beyond its last real entrance, from (-1,2,-2) to (-1,2,-1). The old destination rule only withdrew climbs above all destinations. It now also removes unoccupied level tails, preserving actual entrances, gates, civic destinations, connecting lanes and loops. The existing source compiler produces the shortened walkway and its closing guard; house plots and their stairs remain.

Two new red-first tests and the existing destination suite pass 6 tests / 30 assertions. The actual native collision survey retains 92 clear positions and 138 clear crossings (previously 96 / 144); the removed positions belonged to the unused extension. Three matched native detail pairs and six wider orbit pairs are saved. The inspected side/rear views retain the upper house approach, supporting structure and end railing. Native studies deliberately omit surrounding terrain; they do not establish fresh full-world support or grass acceptance.

The mandatory 48-town matrix seals 48/48, with 11,708 clear centres and 16,819 clear crossings, no disconnected routes or unreachable cells. It retains the same 25 conservative off-centre pillar candidates with zero reported intrusion. The separate fingerprinted composition gate passes 95/95 assertions (logs/deck119-composition.log).

This removes the photographed purposeless extension, not every stair serving a single house. Reworking small-town elevation complexity and the remaining street outline is still open. C05/C06 corner and waterside dressing, W09 bank water, and overall streaming performance also remain open.

![Tan paths in the matched game replay](path-after-0.png)

![Shortened house-access walkway in the native study](deck-native/after/detail_0.png)
