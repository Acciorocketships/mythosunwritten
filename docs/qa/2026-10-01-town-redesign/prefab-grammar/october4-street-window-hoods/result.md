# October 4: source-backed projecting window hoods

Pure Village street houses can now replace a complete lower wall/window bay with
stock `Window_5_2`. Its gabled hood and sill give the facade real depth. This is a
modest window projection, not a projecting room. House_12/12b supplies the source
precedent: Window_5_2 below another wall/window bay, clear of the main eave.

The seeded rule allows at most one hood per lower frontage, with a 65% chance on
each eligible frontage. Upper rows keep flush modules because a hood there can
intersect the main roof. Corner and return modules keep their existing ownership.
The default source reconstruction remains unchanged. Materials are the native
blue roof, wood and plaster; no new texture or arbitrary overlay was added.

The manifest now contains 79 stock modules, explicitly including the projection.
The baked asset is `pure_village.native.window_5_2`. Regenerated production
vocabulary remains 36 derivations / 9 measured profiles; the existing full roof
envelope already contains this lower hood.

## Verification

- Street grammar: 5 tests / 3,127 assertions pass, including outward rays from
  actual indexed glass triangles against every other module, lower-only placement,
  deterministic variation and side-wall closure.
- Native site and town integration: 5 tests / 1,426 assertions pass after baking.
- Fresh 53/grand holdout: 1 test / 635 assertions pass, requiring the projecting
  asset in the complete finished house and checking public walking clearance.
- Eight surveyed towns build; five hoods appear across four towns (7/standard,
  211/grand, 53/grand and 103/grand). Other towns need not select this family.
  No duplicate generic house appears over the native payload.
- Four actual-player entrance walks in 7/standard pass, both directions for each
  native house, using the finished town collision.
- Native close views in towns 7 and 53 plus isolated underside/back views inspected.
  The hood clears the upper beam and main roof, glazing remains visible, and trim
  joins remain intact. Representative images and raw reports accompany this file.

An early integration run started before baking finished and reported the missing
new asset. Its result is superseded by the complete post-bake checks above.

## Still open

This adds safe local variation to one admitted family. It does not resolve broad
flat party walls, large building shapes, the compact photo-town roof/stair contact,
or the remaining town-wide art acceptance. Pure Village source coverage is 49/49,
but randomized production admission still covers only the three established
families. Suntail articulated source variants remain separate unfinished work.
