# October 4 — arcade middle frontage

The three varied arcade configurations now replace the two blank middle-front
wall bays with complete native Window_1_2 panels. The windows bring authored
shutters, projecting sills and trim into the recessed façade. Flush panels suit
the space beneath the inhabited arcade floor and between its curved side
brackets; no independent hood or generated trim is added.

The exact source configuration (two upper courses, no façade variation) remains
unchanged and sampleable. Only the two measured 3 m front interfaces at y=3,
z=1.375 are substituted. Source matrices, lower doors, arcade posts, floor,
roof and rear projections stay intact. No new stock bake was necessary.

## Verification

- Seven geometry/grammar tests / 3,089 assertions pass, including exact source
  reconstruction, all four configurations, roof and upper-wall closure, baked
  bounds, site frames and complete recipe parts. New real-mesh probes cover
  the substituted middle course around openings and at the bay joints.
- Two generated-town tests / 909 assertions pass in 7/standard, 31/large and
  holdout 103/grand: complete pieces survive and clear finished public air.
- Native close views in all three towns inspected. The window heads and sills
  are visible beneath the floor, with no new hood/support interference in
  these views. The former large blank panel reads as an inhabited storey.
- Regenerated production vocabulary is byte-identical (SHA-1
  30cb9f998d56e31b9ecd9ac5155c49e62ec94fa6): no altered town reservation extent.

This fixes the identified arcade panel. It does not establish final acceptance
for all façades, long roof runs, exposed decks, massif enclosure or natural
terrain integration. The wider redesign remains active.
