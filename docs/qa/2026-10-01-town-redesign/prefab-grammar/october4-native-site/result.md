# Door-owned native site adapter

`NativeHouseSite.cross` derives a seeded compound shell and its scale-appropriate
foundation, then anchors the complete assembly by a world-space ground arrival
and outward facing. The approach stands 0.75 world metres beyond the measured
stair. Door floor, roof, returns, foundation, stair and bounds share one rigid
uniform-scale pose. Missing catalog parts or invalid frames/scales/dimensions
refuse the whole derivation.

The result publishes full measured assembly bounds, separate conservative
foundation contact outlines at the requested grade datum, the door frame and
an exterior entry route. It does not load source scenes. These are site inputs,
not permission to grade terrain or overwrite an existing plot.

Evidence:
- Site tests: 2 tests / 2370 assertions pass. Three sampled doors, both scales
  and four facings compile every part inside the published bounds; uniform
  scale, door/ground elevation and clear standing margin are checked.
- Actual-player probe now consumes this adapter rather than choosing a manual
  centred transform. Four cases at a translated, elevated site, including
  different seeded doors and all four orientations: 8/8 ascent/descent routes
  pass on the full compiled house collision. See `native-site-walk.json`.
- No appearance changes to the assembly, so no new art acceptance claim.

Integration finding: `WarrenPlotReservations` costs existing asset sites from
entrance-relative extents. `KitVillageBuildings._houses` then turns each
`prefab_landmark` reservation into `_landmark_house` and rebuilds a generic
kit mass. Simply adding these derivations to that vocabulary would discard
their construction rules. A native grammar site needs an explicit reservation
and realization path carrying its selected derivation, with actual terrain,
public route and neighbor clearance checks before sealing. That production
path remains open; this adapter is not yet called by town generation.
