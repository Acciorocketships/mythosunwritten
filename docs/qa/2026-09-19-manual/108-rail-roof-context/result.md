# P15 roof-side stair guards

The photographed stair now has continuous rails and supporting posts down to the lower landing. Guard clipping uses the prefab's measured native parts rather than empty space in its coarse construction reservation. The stair treads, houses, doors and other town geometry retain their placement.

## Verification

- The exact photographed geometry fails eleven rail/post checks before the fix. The final focused run passes 13 tests / 114 assertions, including prior rail-fragment, landing, roof and skywalk controls.
- A complete physics replay includes native collisions, generated boxes and generated surface triangles. All eleven previously absent rail/post contacts are present. The 312 lattice stance and 444 crossing classifications remain identical before/after: 66 stances and 71 crossings are clear, while 246 and 373 respectively contact geometry. These coarse fixed-height probes are regression controls, not evidence of globally clear routes.
- All six actual character walks in the fresh world pass: uphill and downhill at three lateral positions. Each completes in 73 movement ticks. The six saved walk endpoints were inspected; two downhill endpoint cameras are occluded by a foreground roof and are not independent visual proof of passage. The recorded character positions and remaining endpoint views establish the completed walks.
- Original P04/P15 poses and both ±8-degree views were inspected in the fresh, grass-enabled world. P15's roof-side cut is closed; the doorway and stair width remain clear. Native matched views and close details agree. P04's separate upper rail/house termination is still awkward and remains open.
- The full 48-town / four-scale sweep seals all 48 towns. Native construction clearance retains 11,772 clear centres and 16,915 crossings, with the same 25 conservative offset pillar candidates, zero measured centre/gate blocks and zero worst intrusion. The fingerprinted gate passes 1 test / 95 assertions. This corpus does not independently exercise every generated guard surface.
- Payload comparison changes only mesh 93 of 101 generated surfaces. Native batches and generated collision boxes are identical.

## Collision-harness correction and limits

The earlier `clearance.json` contains native stock and boxes only; it omitted generated stair/rail triangles and cannot validate this repair. `complete-collision.json` and its final log include those triangles using the production shape settings. An old mouth sample previously classified clear now contacts `public-structural-skin_1` identically on baseline and candidate. Its obsolete clear-stance assertion failed; it is now explicitly retained as a baseline contact, not passage evidence. The additional eleven before/after physical rail checks establish the repaired collision.

Door casts and long bridge casts retain their old results. They are regression controls, not a claim that every route is traversable; the long bridge casts still encounter endpoint trim. Broader T09 traversal remains open.

Fresh startup took 617.572 seconds during concurrent validation. No performance improvement or full-suite acceptance is claimed. Three known material UID fallback warnings and the snapshot helper's editor-only shader-parameter warning remain. The original cliff, water, streaming, town-art and biome issues remain active.

See [diagnosis](diagnosis.md), [production patch](production.patch), [complete collision](complete-collision.json), [walks](fresh/walks.json), [source comparison](after/source-comparison.json), and [fresh P15](fresh/P15/P15_0.png).
