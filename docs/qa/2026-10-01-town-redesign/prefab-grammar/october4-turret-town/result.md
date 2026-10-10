# Corner-turret houses in generated towns

Complete prefab-derived corner-turret houses now survive production planning,
assembly, kit substitution and actual-character access. The source house has
182 retained modules; the raised-course variant has 199. Neither is replaced
by a generic box or clipped to an unrelated landmark footprint.

Diagnosis refined the previous result. The field has large ground footprints
(e.g. 95 before carving / zero clear bodies afterward at grand seed 211).
A temporary read-only diagnostic inside the existing early landmark preview
found fitting turret sites at grand seeds 7 and 43. Its instrumentation was
removed, restoring WarrenMazeCarver byte-for-byte. Thus the existing early
reservation stage can preserve these sites; a new GMM shape rule was unnecessary
for this repair. The corrected standalone space probe avoids querying doorway
access on its deliberately unsealed, streetless field snapshot.

The exported turret profiles carry corner_turret metadata. A stable seeded
roll gives some towns a preference for one such landmark before optional lanes
fragment the site. This preference stops after one is selected. A held site
still wins; all dimensional, ground-bearing, gate, public-air and roof checks
remain active. No seed coordinates, mandatory turret quota, or regenerated
fallback town was introduced. Over seeds 0..63, 32 take the preference; all 32
source plans build and 15 select a turret. Unpreferred seeds were skipped by
this particular source survey, so it is not a full 64-town completion claim.

Final admission found a second root cause: the authored foundation reaches
below the single negative grid band. The spatial grid now derives its lower
padding from measured native recipe bounds. It reserves the actual buried
geometry instead of dropping the foundation, raising the house, or ignoring
clearance. This adds no terrain, walk floor or bearing support.

Finished checks: grand 8,9,20 all retain the selected turret. Independent final
assembly holdouts 53 and 63 also retain it. No generic duplicate native masses.
Six focused tests / 1504 assertions passed; the town test was then strengthened
to require the turret family explicitly, and that test passed 819 assertions
for both source and raised variants. The test also checks every retained native
module against finished public walking air. Existing native-town controls pass.
Actual-character walks on the finished towns 8 and 9: four of four (up/down at
each). The harness uses the complete turret approach/landing polyline rather
than guessing a straight line to the last door module.

Native town8 overview and orbit views were inspected. Its corner turret is
attached to the authored house, with a matching roof cap and retained facade
projections. Two custom elevated cameras landed inside neighbouring structures;
those shots were rejected as art evidence and are not included here. The
accepted broader views still show tall generic flat faces, exposed decks and
sparse greenery in this urban seed (woodland roll .033). Those broader owner
requests remain open, as do other families and full prefab generalization.
The isolated source-house review supplies closer connection evidence; this
pass is not a full-town aesthetic approval.
