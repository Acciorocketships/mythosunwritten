# Native compound host shell — October 4

`PureVillageCrossHouse` adds a dimensioned ground-floor perimeter to the cross
roof: four main-wing panels, paired gable facade panels, four short returns,
and paired short-wing facades. Whole-bay extensions add native middle panels.
The source House_5 roof, attic and ground-floor wall geometry reconstructs
within 0.2 mm, with original topology, textures, UVs and materials.
Foundation pieces are explicitly excluded from this reconstruction claim.

Validation: eight reconstruction tests / 10400 assertions pass. Four geometry
tests / 6732 assertions pass across four wing-dimension combinations, including
2736 lower-host perimeter rays. Native extended eaves/front/back views inspected.
Source/reconstruction differences >8/255: front 1, back 3, above 8, eaves 2
pixels; maximum channel mean difference <0.001/255.

The first render exposed missing external corner trim on extended wings:
end panels had stayed at the old end while middle panels were appended outside.
The rule now moves end panels outward and inserts middle panels behind them,
for both ground-floor and short attic walls. The corrected low-eave render
confirms the external corner post is retained. Coverage tests alone had passed
and did not catch this art defect.

This is a blank source-shell benchmark, not approved town architecture.
Foundations, usable door/window sampling, corner towers, public-clearance
placement and production integration remain. The sampler must add compatible
openings before this family is eligible for towns; the broad flat source panels
shown here are not the intended final appearance.
