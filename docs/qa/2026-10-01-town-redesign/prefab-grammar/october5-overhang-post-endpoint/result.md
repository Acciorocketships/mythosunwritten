# Overhang post endpoint repair, October 5

The exposed timber at the new 63/grand stepped wing is fixed. The previous primary-wing candidate's join is accepted for these reviewed views; the full redesign is still incomplete.

## Root cause

The member was **not** one of the reshaped house's corner posts. A diagnostic tint of the entire house left it unchanged. Projecting final placement bounds into the matching camera identified `kit.spatial.feature.room_overhang.00/k0005`, an independently generated overhang support.

`KitVillageBuildings._support_mass` treated the maximum Y of the feature's reserved room volume as the support endpoint. That is the room ceiling. The support therefore extended a complete storey through the carried room; the original wall hid it, and the new lower wing roof exposed it. The support now ends at the minimum Y of the reserved room: its floor bearing plane. Landing, corner joints, native footing/timber assets and collision remain.

In this example the new lower roof plate lies at that same bearing band, so the post still reaches the plate while the exposed shaft above it disappears. No corner post was deleted, and no seed-specific rule was added.

## Evidence

- Red-first regression: 8 of 15 assertions failed with the ceiling endpoint. The repaired test proves all four native posts remain, stop below the supported room and still reach its floor beam.
- Eight tests / 313 assertions pass: endpoint regression, stepped-wing suite with seven finished towns, and native arcade-support retention.
- The seven-town suite retains zero floating-mass and roof/public-air failures. This endpoint-only change does not edit any room or roof records; the previous eight-town exact 300-quarter ceiling comparison remains evidence for the wing changes, not a new probe run.
- Actual character passes the adjacent 63/grand street in both directions after the repair.
- Matched right view and opposite left view inspected in the native renderer. The protruding member is gone; the two roof levels and their wall joins remain closed in these views.

Saved before/after images, diagnostic tint, final placement bounds, red/passing test output and player traces are beside this report. The diagnostic placement bounds describe the pre-fix offending shaft.

## Remaining scope

The five-storey house.010/house.015 shafts, broader roofline variation, enclosure and remaining full-town/material/terrain review requirements remain open. This correction closes the exposed-post issue introduced by the primary-wing candidate; it does not establish completion of all building or town art.
