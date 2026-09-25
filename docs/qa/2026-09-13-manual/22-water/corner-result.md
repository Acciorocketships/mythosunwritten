# P12 water-corner repair

The existing fine water channel now owns its own shoreline interpolation. A
coarse dry boundary used to cut through that channel and pull connected water
below its receiving reach. The fine interpolation now uses its actual dry
corners, with bounded coarse water supplying any missing fine corner.

This is a general WaterField rule, with no photo coordinate or seed branch.
It does not change terrain, source heights, river routing, or water materials.
The exposed distant water-sheet edges and other reported water sites remain
open. In particular this result does not accept P13, P39 or the mountain pools.

## Red first and rejected alternative

At seed 2697992464, the 601-point bank scan from x=1103 to 1109 at z=35.625
reproduced a minimum level of 4.109342 m beside the 7.95 m lower reach. Adjacent
1 cm samples differed by 3.840657 m. Both regression assertions failed; the
601 wet-support assertions passed. See red.log and field-probe.log.

The first independent-fine-bound candidate fixed P12 but let missing corners
read an unbounded coarse level. It introduced a 0.864768 m discontinuity at
an older shoreline fixture and was rejected. The final candidate uses the
ordinary bounded coarse interpolation for those corners. No test threshold
was relaxed. The retired coarse-only limit mode is removed.

## Verification

- The final focused run passes 19 tests / 1,457 assertions: the new continuity
  and physical swimming sampler checks, previous shoreline constraints, swim
  volumes and completely wet basin coverage.
- Separate path-query, field-context and water-classification consumers pass
  14 tests / 1,472 assertions. Total: 33 tests / 2,929 assertions.
- Three matched frozen game pairs (0 and ±8 degrees) retain the same production
  surroundings, camera, lighting and water material. The V-shaped dip is gone;
  nearby cliff boundaries remain continuous. See game-pairs.png and the three
  game-diff images. Diagnostic opaque native geometry also confirms removal.
- Three fresh complete-game pairs independently show the corrected corner.
  Startup was 305.472 s before and 308.587 s after. See live-pairs.png and
  live-before/P12, live-after/P12. These captures omit grass and do not establish
  grass or startup performance acceptance. Particle positions differ in these
  fresh runs; the frozen comparison isolates the geometry change.
- The P39 local water mesh remains identical across this change: 202 vertices
  within its 24 m review square have the same hash. Its separate triangular
  shoreline mark still needs investigation.

The isolated ordinary-material water captures were initially invalid because
replacing the shader on the existing material left a stale render binding in
that harness. Those images are excluded from water-appearance acceptance.
Fresh ShaderMaterial bindings restore the diagnostic render. Native opaque
geometry and the frozen/fresh full-game comparisons above are valid.

No whole-water-suite, long-swim, streaming or general performance acceptance
is claimed. The complete user water request remains in progress.
