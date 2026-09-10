# Broadleaf habitat — accepted

The four related broadleaf plant variants now belong to Jade Estuary and its continuous biome blend. The photographed Moonfen/highland community selects small flowers instead. Pure Jade Estuary retains its exact previous distribution. Terrain, spacing, support qualification and the other flower weights are unchanged.

The first attempt restricted only the photographed `lpfv.plant.02`; it was rejected after the game substituted the visually similar `lpfv.plant.01`. That candidate and its pixel differences are retained. The final family restriction passes 16 related tests with 660 assertions in 63.228 seconds (exit 0).

All six final before/after comparisons were inspected. The tall bright broadleaf is gone, with a small orange flower visible among the grass. The exact view and nearby angles remain coherent. Camera JSON is identical. Exact-view mean absolute RGB difference is 4.59684/255; 5.5355% of pixels differ by more than 20 in at least one channel. The difference highlights the removed plant, other species substitutions in the distance, and lower-amplitude grass wind; minor avatar/orb animation is also present. These are actual game renders, not image edits. Rounded source coordinates cannot recover the original full-precision camera.

Both renders exit 0 with ready=true. Startup takes 446.061 and 451.876 seconds; this existing cold-start cost is not a habitat improvement.

[Exact comparison](diff/11_fern_exact_comparison.png) · [Nearby left](diff/11_fern_near_left_comparison.png) · [Nearby right](diff/11_fern_near_right_comparison.png) · [Numeric verification](verification.json) · [Tests](tests.txt) · [Iteration notes](iteration-notes.md)
