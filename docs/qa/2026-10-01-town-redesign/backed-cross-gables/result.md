# Lower cross-gables beside taller buildings

The 2/grand overview still contained two plain 8x2 roof ranges. Existing
transverse-pavilion candidates all failed because the neighboring facade
partially overlapped their taller gables. This is a legitimate rejection;
a partially buried gable can leave exposed cuts.

The generator now tries a complete lower native cross-gable after the taller
pavilion candidates. It may terminate against another house only when the
entire gable envelope is backed, and at least one end must remain visible.
Partial wall contacts remain rejected. The footprint, room ownership and
public reservations do not change. The two formerly plain ranges (house.003
and house.019) now have two roof axes within the same original footprint.

The first native close-up exposed a ridge-trim/rail intersection at the low
blue wing. Rejected image: rejected-railing-contact.png. Low cross-gables now
keep their ridge-height trim away from a walked deck's one-cell rim, including
the exact top boundary omitted by the ordinary interior-band roof test.
The same house finds a clear end on the other side. This added guard applies
to the new lower profile; applying it indiscriminately to existing taller
pavilions disturbed a photo-town roof join and was rejected.

Native close views show closed mixed-kit joins and the clear stair railing;
the overhead view shows the added street-facing gable. They do not establish
whole-town art completion. Tall background walls still show broad plaster
panels, and some long ranges remain. No new character traversal was run for
this roof-only change; finished-mesh headroom is checked separately.

Final validation: **19/19 tests, 8,022 assertions**, 183.543 s. Includes
range grammar, both changed grand-town roofs and their whole-town closure /
public-air checks, September roofline variety, and the six-town finished mesh
clearance corpus. Every finished-air count is zero; raw roof cuts and gable
contacts remain separate diagnostics. No audit threshold was relaxed.

Holdout 17/large was rendered with dressing enabled. Its seeded woodland value
is exactly zero, so zero trees is intentional, not an asset/rendering failure.
However, its huge empty middle and long outer access route are not accepted as
the owner's intended public realm. Street0 also exposes a large undecorated
masonry face; street1 has native detail and a supported covered route. This is
explicit remaining work, not visual acceptance of the full redesign.
