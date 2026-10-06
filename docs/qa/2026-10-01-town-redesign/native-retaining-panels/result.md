# October 3 native arched retaining panels

The front wall in41/large stayed blank because its potentially inhabitable
columns(-1,0)/(-1,1) overlap asset.00's ground-level roof clearance. The first
hypothesis (a raised prefab's unbounded lower reservation) was wrong: the actual
reservation is floor0/top4. The interval-clearance trial was removed completely;
no prefab clearance was relaxed and no extra rooms are claimed by this change.

Inspected native WindowSolo1..6 measurements and rendered variants4/6 plus the
narrow stone bracket. Raw source previews had a ground plane through their
centred pivots, so those previews do not establish complete-asset art acceptance.
The complete WindowSolo_3 is now baked as pure_village.stone.retaining_window,
with original materials, unscaled mesh and trimesh collision. No standalone
stone arch or invented texture. This is a closed decorative facade panel on
solid retaining masonry, not a new room, doorway or excavation.

KitRetainingWindows fits staggered native panels on broad retained courses.
It requires a complete emitted plain-stone panel behind the whole ornament,
matching orientation and measured depth, below any retained-ceiling trim.
Only then do complete bounds compete against public air, neighboring pieces,
towers and other ornaments. Panels claim their space before corbels, which now
respect those claims. This replaces some repetitive brackets with arched trim
and dark lattice rather than overlapping two treatments.

Visual iteration caught an important defect: the initial fitter trusted planned
retained cells and floated a panel where assembly omitted the backing. That
candidate is saved as rejected-floating-panel.png. The final emitted-backing
check rejects it. Final41:3panels+5corbels;67:1panel+0corbels. Final41overview and
two public-floor close views inspected: full native frames, solid backing,
visible relief and dark accents.67overview rendered; no unoccluded public-floor
close camera found, so no separate67panel close art claim.

Tests6/6,1437assertions,31.765s: whole unscaled dimensions, unchanged backing,
missing-backing rejection, complete-air rejection, idempotence, real-town
public-air checks, no panel/corbel overlap, payload validity, prior corbel
seating and tall-course checks. The old per-holdout corbel-count assertion now
requires a native panel OR corbel because they intentionally compete; no geometry
or clearance assertion was relaxed. git diff --check passes. No new character
walk for this exterior ornament pass; complete measured public-air bounds are
checked. Bake and render processes completed. No commit/PR.

This is visible progress on the identified face, not full redesign acceptance.
Remaining: integrated regression/performance classification, broader architecture
and density/art review, native terminal-fallback and joined-range fixtures.
