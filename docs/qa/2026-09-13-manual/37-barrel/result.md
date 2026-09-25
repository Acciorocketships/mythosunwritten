# Issue 37 — barrel embedded in a public ramp

P36's barrel was placed on the ground beneath a ramp. The ramp's actual surface crosses world Y 21.955 at the barrel, while the barrel spans Y 20.08615–22.145894. Its logical upper-half claim belongs to band 1, above the bands checked for this short prop. The native-module obstacle index did not contain generated public surfaces.

Optional decoration clearance now includes the sealed public-surface triangles alongside native module bounds. A separating-axis intersection check rejects true penetration while preserving floor contact, high-bridge headroom and empty space inside a sloped triangle's bounding box. Assigning a public surface invalidates any earlier footprint cache. The rule is shared by frontage and other optional dressing, with no seed/coordinate exception. The barrel is omitted rather than lifted onto the public route.

## Verification and visual judgment

- The original code fails the photographed owner regression and all four rotated ramp controls (two tests, five failures). Final focused and related frontage/walkway runs pass 11 tests / 94 assertions. Additional measured-native frontage checks pass four tests / 1,973 assertions.
- Thin crossings, flat floors, underside/top contact, high bridges, empty diagonal corners and cache refresh are covered by the focused controls.
- The full photographed payload removes exactly one placement: `maze-frontage/-7/0/-2/1`, the reported barrel. No placements are added or moved. All 52 generated surface payloads, generated collision boxes and walking claims are identical (`placements.json`).
- Actual native collision clearance remains identical across 164 walking positions and 235 crossings (`clearance.json`).
- The mandatory matrix seals 48/48 towns with 11,868 clear centers / 17,035 crossings, no blocked centers or crossings, no disconnected routes, and the same 24 off-center pillar contacts. The fingerprinted composition gate passes 95 assertions. No broad performance or full-suite claim is made.
- Three original-photo/±8-degree live pairs and three isolated native pairs were inspected. They consistently remove the barrel from the floor without leaving a hole or changing the adjoining walls, floor and steps. Live poses match exactly. The differences contain the barrel and a slight character animation difference; unrelated character pixels are not credited to the repair. See `live-pairs.jpg`, `live-differences.jpg` and `native-reproduction/pairs.jpg`.

The camera is reconstructed from P36's rounded overlay: player `(965,20.8,-436.2)`, crosshair `(964.5,21.3,-434)`, through `ReviewCam.solve_cam` and production obstruction handling. The plain ramp finish in that same screenshot remains issue 38 and is not claimed fixed here.
