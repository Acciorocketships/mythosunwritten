# Contrasting native wood finishes — October 3

Pure Village buildings now select native pale timber, oak-toned or walnut-toned
framing once per merged house. The selected finish covers native window frames,
shutters, structural wood, gables, roof undersides and tower wood surfaces; roof
tiles retain the previously selected roof family. Plaster, stone, glazing and
metal are separate. Suntail-only buildings retain their authored finishes.
These are wood-tone multipliers over existing grain/normal maps, not new wood
species texture scans. Native roof material families remain independently seeded.

## Implementation

`EnvironmentAssetDescriptor.material_tints` defines named surface multipliers.
`EnvironmentRenderCache` creates private mesh/material wrappers on the main
thread, sharing source textures and collision resources without altering source
materials. 294 lightweight descriptors refer to the original native visual
files. No additional geometry/texture bake is needed for these finishes.
`TownFramePalette` remaps kit roles, anchors and cap bounds. Worker roof triangles
are shared through explicit kit geometry aliases, including when another finish
has already loaded the same geometry file. `KitTowerPalette` applies the same
finish after choosing a matching cap roof. The streaming program includes all
variant IDs.

Regenerate descriptors after changing native asset metadata with:

```
Godot --headless --path . -s tools/environment_bake/bake_town_frame_variants.gd
```

The ordinary baker preserves derived finish descriptors while their canonical
source remains in an active manifest. It does not refresh their measurements;
run the command above after source geometry changes. Geometry aliases do not
require duplicate worker triangle exports.

## Iteration and validation

The controlled `walnut/` native render demonstrated useful roof/frame contrast.
The first descriptor suffix collided with Suntail's existing `suntail.frame.*`
namespace. Those candidate descriptors were removed and regenerated with the
unambiguous `.finish_` suffix. Catalog tests enumerate every resulting variant.

The first mixed-town run exposed bypassed facade-opening metadata on new IDs.
Both facade and dormer checks now resolve material variants to canonical opening
IDs. This also repairs the earlier roof-colour suffix bypass. On 13/large, roof
fitting, window substitutions and dressing counts match the previous roof-palette
run exactly. On 43/grand, the restored dormer check omits two obstructed dormers;
other roof audit fields match. Tunnels, stepped house masses and town bounds
match on both towns (`geometry-comparison.json`).

Final targeted regression: seven tests / 6,457 assertions, including all 294
descriptors, source immutability, geometry/physics preservation, shared geometry
aliases, opening clearance, generated corner caps, no floating mass, no public-air
roof intrusion and intentional cap-removal failures. An earlier seven-test pass
also exercised the previous roof-family and cap material tests; the final pass
adds the suffix/opening corrections. Logs retained alongside this report.

`review/` contains final generated 13/large and 43/grand views. The review harness
was then corrected to include finish-variant towers, and `corners/` captures both
13/large corner towers. Inspected the 43/grand skyline and 13's warm wood corner
with dark window/gable trim. Earlier `towns/` and `towns-final/` captures precede
the opening correction and are not final acceptance evidence.

Smooth stone/Gothic architecture, taller integrated compounds, broader enclosure,
and final world/holdout acceptance remain open. This pass does not claim a full
suite or refreshed player traversal.

Final quiet real-terrain production gate: 1/1 test, 125 assertions, 5584 ms
town build against the unchanged 8,000 ms ceiling (`production.log`).
