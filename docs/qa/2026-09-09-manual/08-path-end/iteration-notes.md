# Photo 4 — remove the invented country spur

The current merged game reproduces the photographed endpoint. The source
probe identifies settlement `15289ce93c11a72d` at `(288, -1176)`, with one
incident world-road direction: south. Its south boundary handoff runs from
`(288, -1113)` to `(288, -1104)`. Independently, the primary north-facing gate
invented an approach from `(288, -1191)` to `(288, -1247.867)`. That 56.867 m
length came from the largest house envelope, not a road destination.

Alternatives considered:

1. Round or fade the path end. This would retain an exit without a destination.
2. Extend the spur until it finds another road. This would invent another
   connection and change the world-road network.
3. Remove the unconditional approach. Existing canonical road crossings already
   supply boundary handoffs and reserve their clearance before house allocation.
   This implements the owner's suggested behavior and was selected.

The primary and secondary gates still connect straight to the same perimeter.
The four-sided circuit and actual world-road handoffs remain. Frontage can use
space formerly reserved for an invented approach. Town construction still runs
once; no town removal, placement retry or diagnostic rejection was introduced.

The first regression reproduced the 56.8668 m overrun in all four orientations.
An unrelated assertion that every synthetic rotated flat fixture must have
outskirts houses also failed once; that assertion was removed because this
fixture tests street topology. The existing full terrain frontage test still
requires a populated, non-overlapping neighborhood and passes with nine houses.
Its obsolete hard-coded empty approach rectangle was replaced by the new
no-invented-approach requirement. Actual street/house clearance remains tested.

The initial candidate passes 15 related tests / 5,662 assertions. A second
regression freezes the actual photographed road masks and checks both the
removed north stripe and continuous south handoff. Final visual review and
test totals are recorded in `result.md` and `verification.json`.
