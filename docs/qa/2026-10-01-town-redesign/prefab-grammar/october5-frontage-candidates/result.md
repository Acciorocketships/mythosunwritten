# Complete projecting bays beside obstructions, October 5

Room projection fitting now tries smaller complete two/three-module bays when its preferred frontage fails. Previously a door or neighboring roof at one end could reject the entire facade. The original seeded preference remains first; fallback order is deterministic, and long fronts keep flush shoulders. Every candidate uses the same bearing, upper closure, public-air and measured-neighbor checks. No clearance is weakened and no repeated per-floor grid is added.

## Verification

The four-bay door fixture fails before the change and passes afterward: the door remains unchanged while a smaller clear part of the facade receives a complete projection. Eight tests / 72 assertions pass, including three generated towns, native returns/floors/brackets, public-air rejection and neighboring-room rejection.

Six additional finished towns preserve exactly the same walk/ceiling data (220 compared overhead quarter samples). Floating-mass and roof/public-air audits are zero. Projection counts change: 31 large 2→3, 53 grand 4→6, 63 grand 3→4, 83 grand 1→2; 103 and 301 keep their counts but choose different clear bays for three existing projections. The 63 access street at (-6,0,4) passes actual character traversal both ways. An earlier probe mistakenly targeted a non-route cell and failed explicitly; it is excluded from acceptance evidence.

Native projection views inspected for all six towns. They show closed returns and bracketed undersides; nearby roofs remain intact in the viewed joins. Some surrounding window boxes still obscure panes and the existing tall shafts remain overly regular. This rule improves real facade relief but is not sufficient to accept the overall architectural character or global town redesign. No claim is made that every surface/route has been traversed.
