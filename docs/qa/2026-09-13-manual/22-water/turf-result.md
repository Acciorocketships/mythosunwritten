# P39 wave exposure — verified repair

Seed 2697992464, feet (829.8,16,341.5), crosshair (830.4,16,346.4).
The ordinary water wave could cut through the higher native turf cap even
when its moving vertices individually cleared the physical ground below.
The cap is at 16.05 m; a reproduced water intersection was 15.98143 m.

WaterSkin now limits displacement using the complete swept triangle footprint
and the native turf lift. A shoreline joining span remains anchored. Deeper
water regains its ordinary wave spectrum. Conservative amplitude budgets are
blended on the shared world lattice so a cliff leaving the clearance range
cannot create a new abrupt wave boundary. The visual mesh and buoyancy sampler
use the same rule. No seed, town, or photographed coordinate selects the fix.

## Falsification and checks

A point-depth fix and a shoreline-only fix were rejected: the latter exposed
13 of 1,053 statically wet native terrain samples during the maximum trough.
A moving maximum over the full footprint prevented exposure but introduced a
0.335714 amplitude jump over 1 cm; that candidate was also rejected.

The final complete native survey has zero exposed samples at maximum (-1.4 m)
and moderate (-0.5 m) troughs, with a minimum 0.00828743 m remaining gap. The
survey includes actual detached native cliff placements and mesh triangles;
headless MultiMesh transform readback was not suitable for this check.
Ten focused tests pass 2,032 assertions. Two existing shallow-water and shared
current-border tests pass another ten assertions. The focused run also retains
the previously repaired P12 corner and ordinary buoyancy/current behavior.

Fifteen matched diagnostic phase pairs cover the static surface, twelve
ambient times, and both full displacement extremes. The original exposed
strip is removed. Three matched frozen game views and three fresh game views
at the reconstructed angle and +/-8 degrees retain coverage and the ordinary
water material. See P39-trough-pairs4.png, P39-ambient-pairs4.png and
P39-game-pairs4.png. Full images are retained in the corresponding folders.

## Limits

The original screenshot does not record wave time. The exact original moving
triangle is therefore supported by the native intersection and forced-extreme
reproduction, not a claim that TIME=0 recreated the original moment. Game
captures lack grass at this arrival. Fresh candidate startup took 339.914 s;
no performance improvement is claimed. Static field-domain cutoffs, P13,
mountain pool placement, and the distant simulation boundary remain open.
No global water or full-suite acceptance is claimed.
