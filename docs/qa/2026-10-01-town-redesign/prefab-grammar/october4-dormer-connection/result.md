# Dormer and host roof connection — October 4

The reported native close-up showed rear timber bars emerging above two Pure
Village dormer roofs. The old adapter used `Window_Roof_1_1`, a replacement
roof panel containing a separate Wood_3 rear batten above the next course.

Native `House_11c` instead demonstrates the reusable overlay connection:
`Window_Roof_1_3` and `Roof_Base_30x30_1` have the exact same translation,
rotation and reflection. `prefab-connection.json` records both source nodes.
The adapter now composes that pair, plus the existing curved eave for normal
roofs; tight roofs omit the eave. All four roof palettes use the same assembly.
The existing two-metre adapter scales remain; this does not establish full
native three-metre prefab reconstruction.

The overlay's RoofTransition sheet is excluded from the baked adapter (the
imported source sheet stands above the tile contact). Native source files are
unchanged. The complete continuous host panel, tile roof, plaster cheeks,
window framing and both glazing surfaces remain. The asset surface budget
rises from 12 to 13 for this complete assembly; triangle budgets are unchanged.
The first bake failed that original surface budget, then the corrected bake
completed all four palette manifests. Finish variants, worker roof geometry,
and measured window envelopes were rebuilt after the catalog bake completed.

Four connection/dormer-fit tests pass (1,416 assertions): every native host
RoofTiles vertex remains in both dormer assemblies across all four palettes,
all adapted source glazing vertices remain, no replacement-panel rear batten
or transition sheet remains, blocked dormers relocate whole, and clear bays
are preserved. Nine existing roof-junction tests pass (12,002 assertions).
Matched native town before/after views were inspected: the exposed rear bars
are gone and the roof is continuous behind the dormers.

Still open: broad upper cantilever appearance, interrupted canopy endings,
full prefab derivation/reconstruction and town-wide architectural acceptance.

Native complete-roof fixtures in blue, weathered wood, warm wood and sage
were inspected (`native.png`, `wood_blue.png`, `wood_red.png`, `sage.png`).
All show the continuous host and matching dormer canopy without the rear bar.
These are connection fixtures, not approval of the simple test-house shape.
Quiet real-terrain production test passes 125/125 assertions: 6720ms,
unchanged 8000ms reference ceiling, machine factor 1.015.
