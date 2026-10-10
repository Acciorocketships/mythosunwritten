# Primary roofed wings, October 4

**Active implementation candidate; art acceptance remains open.** This pass changes actual silhouettes without changing parcel heights or the room composition upstream. Do not call the broad tall-facade/roofline requirement complete.

## Changes

`KitSteppedWings.shape` now tries a one-storey cut after the sampled two-storey cut fails. All original doorway, bearing, balcony, external construction and walked-surface checks still apply. The new middle-floor-balcony regression failed before this change and passes afterward. This fallback alone changed none of the eight sampled towns.

`KitVillageBuildings._mass_for` now attempts the primary wing before loggia notches for long crowns too (minimum dimension 2 modules, maximum at least 4). Previously only crowns at least 4 modules in both dimensions had that order. A loggia notch made many long crowns nonrectangular, so they could never reach the primary wing rule.

This adds a roofed wing in 53/grand house.018 and 63/grand house.001. The other six survey towns have unchanged stepped-wing records. No hard-coded town choice is in generation; these IDs are regression fixtures only.

## Verification

- Six tests / 221 assertions pass, including seven finished towns, deterministic shape choices, protection of doors/balconies/walks/bearing and actual lower pitched roofs on both regression houses.
- Eight finished towns (7,31,43,53,63,83,103,301): zero floating masses and roof/public-air intrusions.
- Every baseline walk/quarter ceiling-distance record matches exactly. The comparison checks all 300 recorded inhabited overhead quarters, including distant rooms, and reports zero losses.
- Actual CharacterBody traversals of the streets beside both changed houses pass forward and reverse (four routes total). These are street traversals, not a claim to have walked building interiors.
- Matched 53 left/right and 63 right cameras saved; both new wing views inspected. Source swaps used for references restored the full candidate in `finally`.

## Visual result and outstanding defect

53 now has a lower connected roofed wing instead of a continuous three-storey front with a long top roof. Its visible join is coherent in both matched views. 63 gains staggered Pure roof levels, but a vertical timber member visibly protrudes beside the new lower roof. The matched old assembly did not show this exposed defect. The current candidate is therefore not fully art-approved.

`63-wing-parts.json` records the resulting house storeys, roof records, decor and final timber placements. The upper room now occupies (-2..-1,5..6) at band 4. Its four corner posts extend from native Y=6 to roughly 9; candidate members at the new junction include k0149 at (0.0277,6,14.0277) and k0155 at (-4.0277,6,14.0277). These are diagnostic candidates, not yet a proven identification of the visible member. Diagnose the wall/roof junction and supported post geometry before accepting this candidate; do not simply hide a potentially structural post. The earlier five-storey shafts house.010/.015 remain unchanged.

The broad town redesign remains active. Next work is this native join defect, followed by further compound silhouettes preserving real enclosed streets.

## October 5 follow-up

The exposed member was an independently generated room-overhang support ending at the original room ceiling, not a house corner post. Its endpoint now uses the floor bearing plane. Eight tests / 313 assertions, two character routes and both native join views pass. See `../october5-overhang-post-endpoint/result.md`. The primary-wing join defect is resolved; the broad redesign remains open.
