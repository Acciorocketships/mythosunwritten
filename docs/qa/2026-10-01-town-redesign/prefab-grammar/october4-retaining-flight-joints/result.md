# October 4 — native retaining panels at flight landings

The slit in 53/grand street2 was masonry projecting through the final part of
flight 07, not a missing deck collision triangle. Triangle ray probes located
the white pixels on `kit.retained/k0122`; adjacent pixels hit the ramp and native
deck board. The native retaining panel crossed the upper landing edge at
lattice z=11.25 by about 0.137 m. Its top met the landing datum but stood above
the approaching slope.

`KitRetainingFlightJoints` seats whole retaining panels behind a flight's upper
landing attachment plane. Admission requires the panel to face that flight,
end at its upper datum, fit wholly within its width, and cross the attachment
plane by at most 0.3 native metres. Ordinary house facades, partial-width
contacts and other levels stay unchanged. Native dimensions, relief, materials
and vertical placement remain intact. The same transform controls collision.
The flight mesh, landing mesh and route topology are unchanged.

Window panels follow the seated backing face before clearance checks. An
initial trial lost some windows because it still checked their old mounting
plane; the final implementation preserves all 40 projecting windows and 12
recessed windows in 53/grand. Its 16 corbels remain. Twenty-two retaining
panels qualify across that town.

Validation:

- Four-direction ascending/descending joint tests, partial-panel and ordinary
  facade controls, idempotence, the actual photographed panels, and attached
  window contact tests pass.
- Recess, existing retaining-window and corbel suites pass. Combined final
  runs: **14 tests, 5,694 assertions** (tests.txt, attached-windows-tests.txt,
  existing-tests.txt).
- Actual character traversal across flight 07 passes both directions with
  full native town collision (walks.json).
- Grand seeds 53, 103, 301 and 83 keep the prior roof audits: zero cut eaves,
  exposed open gables, gable holes, unsupported roof wings or uncapped towers.
  The three previously recorded tiny wings remain unresolved (holdouts.json).
- Matched before/after street views inspected: the masonry slit is gone.
  Additional angled landing view inspected. These validate this joint repair,
  not the whole town's art quality. Large plain masonry spans and broader
  massif/roofline composition remain open.

Images: before.png, after.png, landing.png. Camera metadata is now printed by
kit_town_review for reproducible follow-up views (render.txt).
