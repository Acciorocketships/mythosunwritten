# October 3 — high native windows above retained backing

The long Suntail house beside 2/grand's upper street had blank panels before
finished-mesh fitting: `BuildingDesigner` rejected every opening whenever any
lower-band outside cell was solid. This also rejected a window wholly above
that backing.

A two-band facade backed only in its lower band now records the minimum
opening height. The fitter tests actual catalog glazing bounds against that
height and the existing finished roof/floor contacts. Fully backed faces stay
plain; doors retain their original rules. Seeded plain panels remain plain.
Pure Village's authored Window_12_3 panel (`window_open`) supplies a high opening
in a compatible 2 m by 3 m bay. This is a constrained fallback for both families,
not a moved/scaled window or a generated texture. Suntail fallback panels receive
native support/crossbar joints because the Pure source has no integral frame.

2/grand: rejected windows 50 -> 37, fitted alternatives 3 -> 16. Seven high
windows survive on `kit.spatial.parcel.maze.house.003`. Instances 4198 -> 4225
(the added timber joins); building layout and roof statistics unchanged.

Validation: facade contacts + range roofs **24/24 tests, 4,803 assertions**,
47.595 s. Includes measured sill clearance, fully backed negative case, actual
reported house, neighboring floor contacts, and whole-town roof/bearing/air
checks from the range suite. Native overview and upper-join close view inspected.
The initial fallback lacked edge timbers; the final render adds them. No new
player walk for this facade-only change. Test/native logs copied here.

This improves the specific blank strip without claiming the full architecture
matches the reference. Sparse central-lawn dressing, broader facade composition,
terminal-roof positive fixture and broad final acceptance remain open.
