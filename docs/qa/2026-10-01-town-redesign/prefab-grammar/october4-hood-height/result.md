# Connected canopy height — October 4

The reported 7/standard wall room emitted its projecting +Z frontage at
native y=7.2 and the adjoining -X frontage at y=6.85. Their separate height
adjustments prevented the existing native corner rule from joining them.

Canopy slots now form connected courses through shared endpoints. A course
uses the highest attachment datum required by its projecting facade; separate
courses retain their own datum. Existing complete-run and complete-corner
clearance checks still decide whether the assets fit. No native mesh is scaled.

Both full-context native views were inspected. The previously stepped corner
on the right now wraps continuously with the authored hip. This does not imply
that every obstructed or incomplete canopy run is solved.

Nine frontage tests / 149 assertions pass. The new test was then expanded to
check actual emitted corner pieces as well as heights: its separate rerun
passes all 26 assertions, including eight hips and zero stranded end caps on
two disconnected rectangular courses. The suite includes actual 13/large
public-air clearance for every canopy placement.

The large upper cantilever and blocked/short canopy fallback remain open.
The eight-town check (7/standard; 13,14,24,31/large; 40,43,92/grand)
builds every town with zero floating-mass and roof-air audit violations.
These existing audits concern structural mass and main roofs, not all canopy
triangles; the real 13/large frontage test is the direct canopy-clearance check.

`7_standard_canopy.png` is an additional native close-up at eye (-3,20,64),
target (18,12,37), FOV 45. It verifies the continuous reported corner and also
exposes a different unresolved problem: rear timber bars protrude above two
foreground Pure Village dormer roofs. Record that as a new connection defect,
not as an accepted part of this canopy repair.

Quiet real-terrain production check passes 125/125 assertions: 6721 ms,
reference ceiling 8000 ms, machine factor 1.022. No timing threshold changed.
