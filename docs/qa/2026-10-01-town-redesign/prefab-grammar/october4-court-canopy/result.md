# Courtyard canopy orientation

Retained: before shrinking a courtyard tree, try all four quarter turns of
its measured asymmetric crown, starting at the seeded orientation. This uses
the existing branch, root-support, finished-roof and public-headroom gates.
It changes neither the planting island nor building/route geometry. An
unobstructed seeded orientation stays unchanged; an obstructed tree is still
rejected if no complete orientation fits.

The eight-town finished-native survey preserves seven planted courts and one
unplanted town. Three courts retain larger trees:

| Town | Before height | After height | Level |
|---|---:|---:|---|
| 43/grand | 2.72 | 7.50 | Raised |
| 8/grand | 6.00 | 7.50 | Raised |
| 9/grand | 6.00 | 7.50 | Ground |

Heights above are fabric coordinates (world vertical scale is 2). The other
five towns, 13/grand, 83/grand, 101/large, 31/large and 7/standard, keep their
previous centre features. Full records are `before.json` and `after.json`.

Validation: `test_october3_street_canopy.gd`, four tests / 18,644 assertions,
passes. It checks an asymmetric collision case, stable seeded placement,
fully blocked rejection, and actual emitted trees in four complete towns.
The native integration test now measures the final emitted tree rather than
assuming that a preliminary tree survives finished roof admission unchanged.
All four towns retain street shading while branches and baked trunk colliders
clear the public headroom; generated roof triangles clear the crowns.

Native Godot courtyard views for 43, 8 and 9 were rendered. Inspected opposite
43/plaza sides and the 8/9 plaza views retained alongside this note. The larger
canopies shelter part of the raised courts; they do not close the remaining
open perimeter decks. The existing LPFV foliage is visibly more angular than
the reference packs. This is an incremental enclosure improvement, not full
massif or architecture art acceptance.

Actual-player traversal in the finished 43/grand town: the changed plaza and
deck.01 pass in both directions (4/4). The broader run is not all green:
deck.00 fails both directions at world (18, 12.05, -54), against a generated
surface collider at approximately (18, 13.12, -54). Re-running deck.00 with
the previous single-orientation placement reproduces both failures at the same
positions. The rotation change was restored after that comparison. Keep this
separate raised-deck traversal defect open; do not count the full town walk as
passing. Raw after and baseline traces are saved here. The changed tree is
centred around world (-10, 18, -50), away from the failed deck route.
