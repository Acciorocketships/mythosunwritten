# Preserving original shallow bank relief — incomplete

The previous contact repair still compressed independent shallow rock geometry
into the repeating native backing. A red control demonstrates 60,903 altered
vertices among 63,257 exposed source vertices within the first 1.4 m of depth.
The revised mapper retains that entire shallow profile. A smooth transition then
reduces the derivative from 1 to 0.3; a distant soft limit keeps depth below 3 m.
It also retains the previous native-contact floor for originally exposed faces.
Two focused tests / six assertions pass: shallow preservation, monotone depth
ordering, no expansion beyond the source, and bounded maximum projection.

## Visual study

The same seed-2697992464 N04 F3 reconstruction and five angles (0, ±10, ±35), plus
two close views, compare the 41-form trial with pass 126. The new close views have
more independent protrusions and less of the repeated narrow upper columns.
This moves toward the requested shape; the broad lower faces and some rounded
corner shelves still need judgment and improvement. It is not final art acceptance.

The initial native study uses all 41 previously admitted IDs. Fresh hydraulic
admission is separate and retains only 39. Therefore `bank-after-*` is a geometry
study, not proof that all displayed forms are admissible. `photo-*-after` instead
uses the actual 39 freshly admitted forms and their 58 selected plants. Both
comparisons retain the same frozen terrain, water and 503 restored baseline grass
instances. No production terrain, water or bank implementation changes here.

## Native contact and hydraulic findings

On the initial 36 formations inside the complete saved collision footprint,
65,159 wet backing probes produce one exact ray miss; 5,544 base probes remain
buried, no sampled outward passage is obstructed, and maximum projection is
1.499 m. The missed ray is at (-492.0250244, 8.1999998, 299.9749756), pointing at
the native corner edge (-492, 8.2, 300). All eight one-millimetre lateral/vertical
offsets hit the native wall. This isolates an exact-edge physics precision miss;
the strict original native command nevertheless exits 1 and is not reported green.
`native-contact.json` retains the original miss and all surrounding observations.
Five formations remain outside the complete snapshot and are excluded explicitly.

Fresh admission rechecks all 47 owned wet candidates (50 dry forms remain dry).
All 39 admitted results match the rendered study geometry exactly. Two previously
admitted corners now fail; the overall 41-form identity gate exits 1.
`corner-conflicts.json` separates their causes:

- (-586.5, 20, 205.5): outward probes encounter dry 24 m ground beyond roughly
  15.402 m water. This is a real limiting neighboring bank, not permission to
  expand the water or ignore clearance.
- (-541.5, 20, 205.5): outward water remains over two metres deep, but its level
  falls by more than the fitter's 0.25 m bound over the probe distance. That is
  a graded-water rejection, not demonstrated obstruction. Admission needs to
  distinguish an actual obstructed corridor from an otherwise clear slope.

The known wall rejection at (-541.5, 20, 217.5) remains rejected as well.
The diagnostic does not relax any hydraulic threshold.

## Remaining attachment failure

The actual admitted candidate has 58 mapped plants. Native rays verify 57;
one near (-443.2067, 14.10013, 366.6249) hits a surface 0.0649 m before its
intended support. `native-plants.json` and the native command retain this failure.
The current source-based canopy/occlusion reservations are insufficient to prove
visibility against every deformed solid. This needs actual fitted-surface
occlusion handling, not a looser contact tolerance or a claim of 58 passing roots.

No production promotion. The next integration work must resolve the limiting bank,
graded-water admission and fitted-geometry attachment exposure, while retaining
canonical ownership and continuous joining faces. Joined mixed-height recipes,
useful ledge grass, independent domains, native swims, broader cliff art and all
other original town/water/loading reports remain open. Native rendering retains
the known frozen village material UID warning.
