# Coordinated native roof families — October 3

Retained after native and production review. Pure Village houses now choose one seeded
roof family per merged house: original blue slate (40%), warm wood (20%),
weathered wood (20%) or muted sage (20%). These percentages are selection
weights, not guaranteed shares in an individual town. Suntail's existing warm
and weathered roofs remain. No town seed is special-cased.

`TownRoofPalette` remaps the complete native roof roles, preserving anchors and
cap dimensions. Corner and half-tower caps inherit the host's family. Native
walls, framing, underside and window materials keep their contrast. This is
roof material variety, not yet the study gallery's full facade palettes.

The variants retain original mesh vertices, UVs and collision. Wood roofs use
existing Suntail board albedo/normal maps on the Pure Village roof surfaces;
sage uses the native slate texture with a muted green tint. No source texture
was painted or overwritten. Wood names describe visual tones, not species scans.
Worker clipping geometry is exported for every variant. The streamed village
program explicitly references the variants, just as it does the original roofs.

## Iteration and evidence

The first native render exposed blue ridge tiles on the new families. The
separate native `RoofTopTiles` material now receives the family alongside
`RoofTiles`; regression coverage includes both. Untinted timber and dormer
flashing remain accent materials. Initial controlled `sage/` and `wood/`
images preceded this ridge repair; generated `towns/` images include it.

Nine targeted tests / 7,067 assertions passed: unchanged native geometry,
worker geometry availability, seeded family variation, matching caps,
corner support, generated 13/large and 43/grand roof/public-air and floating
mass audits, plus intentional missing-cap failures. Native town views of
13/large and 43/grand were inspected, including the warm corner tower in
`towns/13_large_turret1_1.png` and the mixed 43/grand skyline.

The first isolated production check exposed missing variant IDs in the sealed
streaming program. That integration was corrected; final rerun recorded below.
No full-suite, refreshed player traversal or streamed-world acceptance is
claimed for this material-only pass. Broader architecture, taller integrated
compound towers, enclosure and whole-building trim/stone palettes remain open.
The limestone/charcoal authored-prefab study is still a material direction,
not a completed Gothic generator.

Final isolated real-terrain production check: 1/1 test, 125 assertions,
5,518 ms town build against the unchanged 8,000 ms ceiling. `production.log`
records the accepted sealed town. Final corrected controlled captures are
`sage-final/` and `weathered/`; earlier first-pass images are retained as
iteration evidence, not final examples.
