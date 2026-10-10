# Native tree in a notched court planting bed — October 5

Previous goal turn: verified progress on court-addressed houses. This pass repairs its observed 301/grand planting regression; it does not complete broader internal-square planning.

## Diagnosis and correction

The new court doorway removes one of the four interior planting cells, leaving an L-shaped three-cell bed. `maze_plaza_centre_feature` formerly required a complete 2x2 planting block before trying any measured native tree. The remaining island can hold a tree, but the search never reached the root/crown test. The preceding report's attribution to a roof collision was incorrect and has been corrected.

When no 2x2 block exists on a planned planting island, `TownCourtTrees.fit_island` searches actual available planting-cell centres in stable nearest-centroid order. It retains the existing native asset vocabulary, height alternatives and quarter-turn fitting. Every low trunk/root section must remain inside owned planting ground; measured crowns, roof triangles and swept public headroom still pass the existing clearance checks. Public entries and walked cells are excluded. Existing successful rectangular placements are unchanged.

## Evidence

- Red first: the L-shaped bed fails the existing centre-feature rule (one failed assertion).
- Final focused suite: two tests / six assertions pass. It proves a mature-height measured tree can fit while preserving the missing doorway cell; fully occupied beds and roofs still reject placement.
- Native 301 regression: one test / 3,898 assertions passes, checking emitted tree, actual canopy/roof triangles, baked trunk collider and walking headroom. The helper now includes seed/failure messages.
- Matched before/after native camera angles 2 and 3 inspected. The new court-facing house and its door remain; the tree and one seat return to the notched bed. All four angles captured, only 2/3 claimed as inspected.
- Actual player: town entry to court and around its walking ring, both ways; court to built door threshold, both ways. Four traversals pass after tree placement.
- Four additional towns (13/43/8/9 grand) build with zero floating/roof-air failures. The older canopy test has two missing preliminary-tree assertions. Restoring both prior production files reproduces those failures (8,172/8,174 assertions); the full candidate run similarly fails that one test. They are not town-generation failures and are not attributed to this change.

The baseline source switch completed and restored the candidate. All processes are terminal.

## Remaining

The raised court remains small and exposed on some sides; its bare turf rendering is not final environmental art. Broad internal decks, three-sided inhabited frontage, durable planting capacity in the layout, extra supported skywalks/tunnels and the remaining architectural requirements are still active. This fixes one actual planting loss without weakening clearance; it is not evidence that every town has a satisfactory square or tree canopy.
