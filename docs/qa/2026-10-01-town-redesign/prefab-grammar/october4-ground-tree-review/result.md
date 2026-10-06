# Ground dressing and native maple review

No production tree substitution admitted in this pass.

The previous 83/grand overview omitted `--dressing`. Re-rendering with that
flag shows 80 trees and 10 activity groups (18 props), including trees in the
central clearing. Its woodland draw is 0.722462. The native overview was
inspected; the claim that this town's clearings lacked dressing was a harness
configuration error. This is one town, not a new distribution survey.

The production ground tree pool still contains only LPFV tree01 and tree02.
The new `native_tree_review.gd` harness renders all six imported Pure Village
maples. Maple1, Maple4 and Maple6 views were inspected: the first two are
nearly bare; the sixth has sparse, distorted branch cards. They are unsuitable
for production admission in their current imported state.

Source investigation: the prefab material GUID resolves to MapleLeaves.mat;
its shader is BK/Pure_Common/Shaders/BK_VegetationLeaves.shader. The declared
diffuse property resolves to MapleLeaves_a.tga, matching the converted GLB's
MapleLeaves_a.png. Both images have matching dimensions/channel extrema;
the source itself has the branch atlas and mostly transparent lower half.
The source shader samples that diffuse alpha, with optional view-dependent
dithering, and uses vertex colour for tint weighting. The GLB omits vertex
colour. This investigation does not establish why the foliage is missing;
neither a guessed texture replacement nor a production shader change was made.

Remaining: inspect the original rendered prefab and its mesh/material import
settings, then reproduce the actual foliage rule before baking collision,
canopy profiles and adding these trees to the production pool. Town architecture,
roof joins and broader art acceptance remain open.

## Architecture regression check

Reran facade roof contacts, roof turrets, arcade support retention, and tower
host height: 18/21 tests, 690/694 assertions pass. Three tests fail: the
previously documented upper-street window expectation, the production corner
turret presence/lower-wing presence expectation, and 7/standard's nonzero
tower expectation. The short-house exclusion unit check passes; the generated
presence checks fail because their towns emit no towers. These failures must
not be hidden by removing their assertions. Their cause relative to the newer
native-house integration has not yet been established. No production code
changed in this review pass. Both test processes exited with status 1.
