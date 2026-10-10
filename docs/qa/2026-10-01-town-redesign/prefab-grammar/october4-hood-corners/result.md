# Native canopy outer corners — October 4

Status: outer-corner rule implemented and visually reviewed. Inward corners,
large overhang composition and the overall prefab grammar remain unfinished.

The previous canopy assembler capped each face independently. It now first
admits each complete run, then joins adjacent accepted runs at a shared convex
vertex and common height. Pure Village `Roof_Bottom_OutCorner_5x5_1` supplies
the intact outer corner, placed at the left endpoint of its owning face. The
two adjoining end caps become middle pieces. The placement relation follows
the four outer corner/middle pairs measured in native `StreetHouse_7` (which
uses the corresponding curved family); the current shallow canopy uses the
matching straight family throughout. The corner is not scaled or clipped.

The corner and both replacement middle pieces must pass the existing whole-
asset public/neighbor clearance callback. If either run is absent, or the new
connection is obstructed, the surviving runs retain their original closed
caps. New corners inherit the house's timber finish through the same palette
catalog as all other native details. Stable IDs of replaced straight pieces
are preserved; each shared corner has one owner.

## Evidence

- Native isolated fixture: `outer-corner.png`, `outer-corner-close.png`.
  Inspected the continuous tiled hip, shared height and closed underside.
- Full reported 7/standard town: both `kit.spatial.feature.landmark.01_context`
  views. The canopy on the right now turns its outer corner with the authored
  hip instead of overlapping two independently capped strips.
- Six wall-frontage tests / 85 assertions pass. They cover complete closed
  perimeter, rejection of one run without deleting other frontages, blocked
  corner fallback to caps, single corner ownership, all four rotations, native
  placement scale, and actual 13/large public-air clearance of every hood.
- Eight-town finished-kit corpus: covered quarters unchanged and zero
  floating-mass / roof-air audit violations. `corpus-summary.json` records it.
  The roof-air corpus metric is not a claim that every new hood triangle was
  independently walked; hood admission and the actual 13/large test are the
  relevant new-asset clearance checks.
- Production real-terrain test passes 125/125 assertions: 6582 ms, under the unchanged machine-calibrated budget (8,000 ms reference, factor 1.058). See `production.log`.

## Next connection rule

`hood-inner-source.log` measures native House_10. Its inward corner at
(3,9.125,3), facing +X, shares the junction with a +Z-facing middle piece
centred at (6,9.125,3). The inward corner occupies a 1.5 m run on each side;
that room must be reserved from the adjacent middle runs. It is not an outer
quarter rotated into the recess. The production builder still uses separate
closed caps at these inward junctions; do not count them as fixed.

A test-file append initially mixed indentation and failed to load. It was
corrected before the final six-test run; no test was skipped or weakened to
avoid that parse failure. The updated existing test now expects connected
corners rather than eight independent caps on a rectangular perimeter.
