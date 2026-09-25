# Building variety — active

Baseline is the accepted issue 5 generator. `before-payload.bin` is an exact
copy of issue 5's final full native payload. The live baseline is
`../05-floating/world-after`; camera reconstruction has the same rounded-overlay
precision limit documented there. `before.json` records this town's rooms,
features and final recipe inventory before issue 6 changes.

## Brainstorm and first candidate

The photographed town has seven upper-room lineages eligible for a facade bay,
ten candidate placements after initial checks, but the compact skywalk-derived
budget stops after two successful commits. One balcony and one dormered roof
are realized. Fifteen crowns request dormers, but most final roofs use tight
terminal or bridge-party profiles; blindly increasing dormer probability does
not address those actual closures.

1. Let each eligible lineage try one supported facade bay. Existing measured
   bounds, complete lower bearing, public air and required roofs remain gates.
2. Investigate private corner walkouts independently of public stair porches:
   corner geometry should not require a stair when it is privately addressed,
   but its deck, full guards and real two-sided support must be proved.
3. Investigate dormers compatible with tight terminal roof geometry, preserving
   the accepted roof seams and native profiles. No forced overlay on a roof.

Candidate 1 addresses the measured bay cap first. The baseline regression must
fail because only two distinct bay owners are realized. Native fixed-light
pairs will isolate this change before any visual acceptance. Later candidates,
physical clearance and the mandatory 48-town matrix remain pending.

## Iteration results

- The bay-only candidate passed the red two-owner regression and added two
  oriels, but retained one balcony and one dormer. Its ten native comparisons
  were insufficient to accept the wider architectural request.
- Complete native five-cell L decks were added in four palette/hand alternatives.
  Body clearance rejected 98 attempts, support rejected two, and eight valid
  lower-wall contacts were misclassified as unrelated room overlaps. The fix
  declares only the four real lower bearing cells; it does not exempt a whole
  building lineage. A missing back bearing socket in candidate 4 prevented
  compilation and was corrected before further rendering.
- Candidate 5 placed a corner but displaced the original straight balcony under
  the old one-balcony cap. Its ten comparisons made the front flatter, so it was
  rejected. Candidate 6 budgets opportunities from eligible upper lineages,
  retaining all existing geometry and public clearance gates. It retains the
  straight balcony and adds two corners.
- Twelve complete native tight-roof dormer alternatives preserve their original
  roof stock and seams. That alone did not change this town: its ground-storey
  roof branch discarded the requested dormer. Preserving that request through
  roof selection gives the photographed town a second dormered roof. Measured
  frame conflicts can still select a plain roof.
- A short axial contact ray falsely missed the corner knee's embedded head
  because both ray ends were inside the floor. Candidate 7 tried an inset head,
  did not repair that diagnostic, and was reverted. The final test measures the
  actual vertical floor triangle interval and confirms the head is inside it.
  Candidate 6 is the final geometry; candidate 7 is not delivered.
- Two related historical assertions were stale: benches now have their accepted
  native collision, and issue 5 already reduced the old photographed room from
  sixteen cells to eight. The tests now assert declared collision and real
  immediate bay bearing; their substantive negative fixtures remain.

Final candidate retains all 28 source rooms byte-for-byte in the exported room
records. It changes realized bays 2→3, balconies 1→3 and dormered roofs 1→2.
The photo town remains 88 clear public positions / 124 clear crossings.
