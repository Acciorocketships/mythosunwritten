# September 16: exposed native cliffs, broader outcrops and biome-colored ledges

The continuous rock facade is removed. Six weathered moss-rock solids now make
individual rooted outcrops, with some broad lower shoulders and visible original
wall between clusters. The original cliff, ambient stone and new outcrops share
one restrained gray-brown palette. Rounded native shrubs replace the fine-leaf
bushes, and trailing vines retain their transparent leaf cutouts.

Moss uses the ordinary terrain grass UV, shader and per-instance biome tint.
Decoration is rejected where its projected solid intersects an existing water
channel, clearing the protrusions in the new waterfall report.

## Report register and reproduction

All sites use seed **2697992464**. `ReviewCam.solve_cam` reconstructs each camera
from the rounded player/crosshair overlays, rather than inventing a new view.
This reproduces the available overlay data; the original unrounded camera was
not recorded. Before/after camera transforms, FOV and pivots are identical for
both new photos, including the two nearby ±8-degree views.

| ID | User image | Feet | Crosshair | Review |
|---|---|---|---|---|
| Q01 | September 16, 9:59:51 AM | 299.3, 18.7, 517.3 | 300.0, 20.9, 518.3 | Facade removal, shape, palette, shrubs, biome moss |
| Q02 | September 16, 10:06:06 AM | 471.5, 30.2, 875.1 | 469.1, 31.8, 878.9 | Highland tint and rock protruding through a cascade |
| P04 | September 15, 9:48:26 AM | Earlier registered pose | Earlier registered pose | Wide amber-biome art control |

## Individual changes and judgment

1. **Facade and coverage.** Removed forms 10–17 and the previous backing-panel
   pass. Whole outcrops vary in width, yaw and height. Lower shoulders project
   farther than upper rocks; they are not miniature ordinary cliff tiles. Four
   orientation controls cover 398, 200, 294 and 430 of 640 wall samples: roughly
   31–67%, replacing the old near-total coverage target at the owner's request.
2. **Shape.** Rejected the first new ring-built forms (`study-01`/`candidate-01`):
   they read as cylinders with green hats. The accepted second study adapts
   Ultimate Nature moss rocks 1, 2, 4 and 7 with one partial subdivision pass.
   Broad broken silhouettes and uneven shoulders fit the existing faceted style.
   They retain some flat planes; this is intentionally not a photoreal rock set.
3. **Stone coherence.** One shared stone-color function serves native wall rock
   texels, new outcrops and ambient KayKit/LPFV stones. Original native wall
   relief, cap geometry, source UVs and terrain collision remain intact. Native
   repeating wall relief is deliberately visible between clusters.
4. **Shrubs and vines.** Reused `kaykit.bush.01` from the surrounding landscape
   at ledge scale. Foliage receives the ordinary biome bush tint. A first vine
   material substitution produced black rectangular cards; that candidate was
   rejected and explicit source-alpha scissoring restored the leaf silhouettes.
5. **Biome moss.** Replaced the fixed green swatch with native turf UV/material
   and `BiomeRegistry.ground_tint_at`. Meadow, amber and highland captures now
   follow their adjacent ground hue, including blended meadow/highland terrain.
   Different slope orientation and lighting still produce natural brightness
   differences. A real-GPU check verifies all three instance colors.
6. **Water corner.** A bare-wall isolation render showed the underlying spill
   continuing correctly while added rock extended through it. Rock admission now
   tests projected vertices plus interior solid samples against the water field
   before publishing either render geometry or collision. Native walls remain
   beneath translucent water; new slabs no longer penetrate the photographed
   spill. This is a decoration/clearance repair, not a hydraulic solver rewrite.

## Render evidence

- [Q01 before / after / absolute RGB difference](comparisons/meadow/Q01_0-comparison.png)
- [Q02 before / after / absolute RGB difference](comparisons/water/Q02_0-comparison.png)
- [Amber wide comparison](comparisons/heath/P04_0-comparison.png)
- [Nearby-angle review sheet](nearby-review.png)
- [Final meadow view](meadow-final/Q01_0.png)
- [Final highland waterfall view](water-material-final/Q02_0.png)
- [Final amber art study](heath-final/P04_0.png)

Q01 and Q02 baselines are fresh original-production captures (`before` and
`water-before`). Q01's accepted geometry is a fresh production generation in
`candidate-02`; `meadow-final` rebinds only the final vine material and biome
instance colors on that saved scene. Q02's final geometry is freshly generated
in `water-final`; `water-material-final` performs the same final vine rebind.
These material replays use production prepared meshes/materials, retaining all
saved geometry and transforms. P04 is explicitly a frozen-world **art study**:
production forms are rooted against saved terrain physics, not a fresh test of
the site's entire feature/water admission pipeline.

All nine final images were inspected. Q01 retains broader lower shoulders,
exposed original corners and rounded shrubs from both nearby angles. Q02's
continuous spill is unobstructed in all three views. P04 shows separated broad
clusters and amber ledges/vines without reintroducing the prior small pyramids.

Unmodified-image differences use a luminance threshold of 12; displayed absolute
RGB differences have labeled 3× gain. Changed pixels are 29.0–30.8% for Q01,
18.2–24.4% for Q02 and 17.8–19.9% for P04. These measurements locate changes;
they are not a substitute for the qualitative review. Animation/readback timing
can contribute small differences. Metrics and camera equality are in `validation`.

## Tests and limits

- Red-first facade/depth/shrub test failed all four assertions against the old
  code. The wet-channel regression retained 77 placements before the repair and
  now rejects them.
- Final focused run: **74 tests / 7,387 assertions pass**. Coverage includes
  native terrain preservation, closed collision geometry, actual ledge probes,
  rooting, grade/public clearance, shared chunk ownership, vegetation, moss UVs,
  and the finite prepared-water query boundary.
- Real GPU tint readback: **1 test / 4 assertions pass**, checking the meadow,
  amber and highland ground tints. The dummy headless renderer returns black for
  this API, so this test explicitly requires native rendering.
- Broader catalog run: **90/93 tests pass**. All three failures are unexpected
  stale UID warnings for existing village door material resources; paths still
  load. They are retained in `validation/related-final.log`. No global green
  catalog or full-suite acceptance is claimed.
- The initial wet rejection queried halo proposals beyond their prepared water
  domain and was rejected (`water-after`). The corrected version only queries
  owned rocks. Dry halo proposals remain conservative grass/plant reservations,
  which may suppress a little decoration beside a rejected wet outcrop.
- Fresh Q02 startup was **334.949 seconds**. No streaming speedup is claimed.
  The snapshot helper also logs its known editor-only shader-global enumeration
  warning while saving; production generation has no out-of-domain assertions.
- Wet admission is intentionally conservative: an outcrop spanning a wet
  footprint is omitted rather than changing the river to accommodate decoration.
  Broad riverbank/hydraulic acceptance and the older issue ledger remain separate.

Reproduce with `tests/harness/september16_cliffs.tscn -- --single --spot Q01`
or `Q02`, plus `--offscreen --grass --output <directory>`. The saved-scene
material review is `september16_material_review.tscn -- --single --spot Q02
--frozen --snapshot <world.scn> --output <directory>`. Test configurations and
logs are retained under `validation`.
