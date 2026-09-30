# Restored cliff faces and ledges

The flat rock was a regression introduced by the cut-out repair. The 25 cm inward limit clipped away almost the entire terracing profile. Water-bank height ceilings then flattened projecting geometry as well.

## Change

The original 3.5–6.5 m block spacing, irregular phases and chipped treads now build **outside** the continuous hillside. Following the owner’s live correction, the faces use 60–75% of the fall-line run instead of 15–30%: they lean with the slope rather than forming nearly vertical walls. Level ledges occupy the remaining run. Occasional taller blocks interrupt the shelves; they no longer become texture-only slope patches. Adjacent profiles blend and the existing fin filter joins their ends. The local crest caps rock height, and the established 3–7 m crown guard remains intact.

Roads remain hard constraints. Submerged channel samples remain submerged, with room for relief increasing smoothly above the waterline. The 8 m water-core cut-out fix and 25 cm inward limit remain. No material palette changes, imported rock changes or replacement mesher.

## Face-normal correction

The owner flagged the upright faces in the intermediate comparison. The benchmark explicitly measures geometric normals against the uncarved hillside on ordinary slopes, excluding level treads and pre-existing steep channel cuts. Median deviation falls from **16.81° to 11.05°**, and the 90th percentile from **26.67° to 20.07°**. The test fails against `upright-envelope.gd.txt` and passes after the correction (`red-upright-normals.txt`). Combined with the tread-area test, it cannot pass by flattening the rock away again.

`leaning-neutral-*-comparison.jpg` compares the upright and inclined faces without textures. `leaning-*-comparison.jpg` compares the same production cameras before/after the inclination correction. The ordinary `*-comparison.jpg` files compare the original flattened version against the final restoration.

## Iteration and evidence

- Initial outward-only trial restored some ledges but retained flat banks; rejected as incomplete.
- Allowing bank relief exposed the receiver ceiling as another flattening source.
- Broader original-size benches looked closer to the reference, but raised shallow water and a few peaks. Added water-contact clearance and local crest protection.
- An attempted displacement taper flattened upper treads again; rejected. An absolute crest-height limit preserves horizontal ledges.
- Kept the existing broad crown guard after the narrower trial left a distant projecting peak.

The selected native input fixture changes from **zero** qualifying treads to **63** qualifying half-metre grid samples; gently graded exposed treads occupy **12** spatial patches. Each qualifying point has exposed rock, over 35 cm of actual relief, a gentle tread over at least one metre in the original fall direction, and a formerly sloping backing. These are geometry measurements, independent of texture. Maximum vertical addition is 2.409 m; maximum inward change remains 0.25 m.

Neutral front/side matched renders and amplified pixel differences are in `neutral-*-comparison.jpg`. These show broad faces with attached treads instead of the former smooth hillside. The owner reference is linked and enumerated in [issues.md](issues.md).

The new tread regression fails against the saved flattened baseline (0 treads / 0 patches), then passes on the restored geometry. See `red-baseline.txt` and `tests.txt`.

37 tests / 615 assertions pass, including the native tread regression, previous cut-outs, crown height, channel coverage, support, normals and surface mesh tests. All nine production chunks were rebuilt for the final version (`native/03`). Front, side and overhead images and pixel differences were inspected. The neutral comparison confirms actual changes in silhouette and face inclination; the production comparisons show retained moss treads and attached face ends.

Native checks:
- **526 horizontal ledge triangles**, covering **42.83 m²**, have exact matching collision contacts; no misses.
- **170 cliff surface samples**: 149 exposed exact contacts, 21 intentionally covered by nearer ground, zero misses.
- **175 grass roots**: zero missing contacts.
- **1,449 shared height samples**: maximum disagreement 1.78e-14 m; **208 shared normals** match exactly.
- **Six actual character walks** through the three previously circled mountain shoulders pass in both directions and remain on the floor.

The final images are [inclination before/after/difference](leaning-side-comparison.jpg), [front](leaning-front-comparison.jpg), [above](leaning-above-comparison.jpg), and [original flat rock versus restored geometry](side-comparison.jpg). P03 itself is foreground-occluded, so the exterior views are the art evidence.

This addresses the geometry restoration and the live face-inclination correction; it does not claim closure of every older issue in the original cliff judging register.
