# Material-variant turret closure audit

The four gable-hole reports in the 53/301/83 grand holdouts were false positives. `kit_roof_audit` recognized only the canonical blue `pure_village.tower.roof`, although actual caps were material variants (`wood_red`, `wood_blue`, `sage`, with optional wood finishes). The 53 native close render shows the actual cap covering the gable cutout. Production geometry is unchanged.

The audit now accepts only the known geometry-preserving native-cap variants, reconstructed from actual present tower parts. It does not trust a role label or stale clipping metadata as proof of closure. The earlier cap-removal test now removes caps by role, including variants, rather than accidentally leaving every recolored roof present.

A new actual-town regression failed before the fix (3/4 assertions), then passed. Removing all caps from that same build still produces both an uncapped-tower failure and an exposed gable-hole failure. Combined with the existing native/variant mesh comparison: **2 tests / 76 assertions pass**. The mesh comparison verifies identical native vertex arrays and retained textures for recolored caps.

Rebuilt 53, 103, 301 and 83 grand: gable holes are now zero in all four. Every other audit metric is unchanged. Remaining genuine eave cuts: 103 two; 301 two; 83 three. Tiny roof wings: 53 one; 103 two. These remain open, as does wider town art acceptance.

The earlier stair-admission report described these gable warnings as actual defects; this closer investigation supersedes that statement. Its before/after comparison remains valid, but those identical warnings did not prove visible holes.

Next root case: 103/grand house.004, roof rect (4,-6,4,6), axis 1, eave band 2. Suntail tight-eave parts k0073/k0074 still meet rising public flight/landing clearance. Native world position k0073 is approximately (14,6,-26). This requires genuine geometric fitting, not an audit exemption.

Stair-profile diagnosis: the second 103 flight and its turning landing select zero margin even when lateral public connections are removed from the selector input. Thus the next repair must inspect the roof reservations/profile bounds or roof placement, rather than weakening the connection safety check.

The older cap-removal test initially failed because its 43/grand fixture now has no towers (both presence and removal assertions failed). It now uses the demonstrated 53/grand source and removes caps by role; final **1 test / 3 assertions passes** (`cap-removal-final.out`). Together with the preceding checks, this turn verified three focused tests / 79 assertions.
