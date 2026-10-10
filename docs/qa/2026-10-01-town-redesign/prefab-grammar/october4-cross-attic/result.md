# Compound roof attic sides — October 4

`PureVillageCrossRoof` now includes the short 1 m attic walls under the eaves,
using native 3 m main-wing and 1.5 m return pieces. Whole-bay extensions insert
native middle panels alongside the extended roof courses. Handed start/end
interfaces and the source's 36.16 mm rear return offset are retained.

Seven reconstruction tests / 8070 assertions pass. House_5's compared assembly
now includes roofs, all gables, and all short attic sides, with source topology,
UVs, textures, material assignments and world vertices within 0.2 mm.
Three geometry tests / 3996 assertions pass on four combinations of arm lengths.
Attic probes inspect only short wall triangles (not roof or gable triangles),
so other geometry cannot conceal a missing side panel. Coverage is sampled,
not a watertightness proof.

Native extended front/back/eaves views were inspected. Roof-to-wall contacts
and corner returns remain closed at the visible joins. Source/reconstruction
front/back/above/eaves differences >8/255: 1/3/8/1 pixels respectively; maximum
mean channel difference <0.001/255. The review intentionally omits the lower
host and floor: the component is floating in this study, not in a town.

Remaining work: derive the ground-floor/foundation host, opening sockets,
corner-tower assemblies, then integrate into the production envelope and test
actual towns. This component does not yet generate production buildings.
