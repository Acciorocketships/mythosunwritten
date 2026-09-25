# Prefab foundations — accepted

Photos 2 and 17, seed 2697992464. The source overlays contain rounded player
and crosshair coordinates. Before/after use identical reconstructed cameras,
75-degree FOV and a 1718 × 1035 game viewport.

## Diagnosis and alternatives

The LPFV house in both photos uses `anchor.prefab.10`. Its original recipe
supplied the native house and door but no floor. The conservative shell masked
the retained mass's top, leaving only public approach boards visible beneath
the house. Adding arbitrary posts would not close this horizontal interface;
moving the house or public route would change a valid address. The selected
construction gives the prefab its own complete native timber platform.

The first candidate closed photo 17 but failed photo 2: the outer stone ledge
still intersected its timber cap. Native ray hits identified the actual retaining
panels, whose highest vertex was 1.500122547 m against a 1.5 m finished floor.
The ledge's real underside is 1.338947669 m. Public decking already recessed its
retaining wall, but private floors and unwalked timber shoulders did not.

## Implementation

Every prefab recipe tiles its existing rectangular footprint with the same
native floor used by modular rooms. Placement corrects the floor asset's
measured 1.02 mm pivot offset once. The house, door and native floor thickness
remain unchanged. The complete platform declares lower bearing cells before
landmark admission, including interior cells and margins beyond the house feet.
The catalog-derived source templates carry those enlarged bearing requirements;
two formerly distinct templates now have identical envelopes, leaving 17 unique
templates. This may change allocation in other towns; it is not a photo-only rule.

The floor ownership classifier tolerates 10 micrometres of float roundoff at a
complete cell boundary without moving vertices. Retaining sides below private
floors or exposed timber shoulders end beneath the native board thickness,
using the existing vertical finish operation. Turf, public flooring and all
source assets keep their existing finish rules.

## Verification

- Original native-floor regression failed for all 32 prefab recipes; all measured
  bearing points now meet actual native floor triangles.
- Four rotated platform ownership cases pass. The initial candidate still
  failed until the measured source pivot was corrected.
- Full-platform support regression failed for all 32 recipes before support
  reservations were extended; it now passes.
- The photographed native stone/ledge regression failed before the retaining
  finish correction and passes after it.
- The regenerated source-template table matches the catalog: 207 assertions.
- Paired physical surveys are identical for every sampled cell and crossing:
  photo 17 town has 112 cells / 164 crossings; photo 2 town has 297 / 424.
  Photo 2 retains two pre-existing blocked crossings and one cell requiring
  an offset stance; no new restriction is introduced. Baseline surveys used
  original prefab/assembler/template source while keeping
  the already accepted wall repair; candidate source was restored afterward.
- The 18 related focused tests pass with 1,295 assertions and a clean exit.
  All 12 final production views and their paired differences have been inspected.

`after/` contains the rejected intermediate floor-only candidate. `final/` is
the final candidate; it passes against `before/` and its pixel differences. Isolated gray-background images are diagnostic evidence only.


Both camera records compare equal between before and final. Photo 17 has a
continuous platform beneath the entire house frontage and joins its approach;
photo 2 has a coherent timber edge above the existing retained stone with no
stone-colored facets interrupting its top. Both oblique views, both small
jitters and the production collision camera retain these repairs. The pixel
hotspots follow the newly closed floor and recessed stone edges, rather than
an unrelated change in camera or town layout.

| Photo | Exact ROI mean absolute RGB | ROI pixels differing by >20/255 |
| --- | --- | --- |
| 2 | 4.114941/255 | 8.704526% |
| 17 | 3.108476/255 | 5.782159% |

The common ROI is (533,207)–(1392,527); complete metrics are in
`differences/metrics.json`. `02-review.png` and `17-review.png` show all paired
crops and heatmaps, and `02-full-final.png` / `17-full-final.png` show the complete
final frames. Moving character/orb shading and cursor pixels are not credited
as repairs. This accepts these foundation sites and their general native floor
contract; later turf, roof and city-cohesion issues remain separate.
