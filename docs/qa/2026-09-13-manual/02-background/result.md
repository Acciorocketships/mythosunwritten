# Background architecture — P33, with P06 controls

Disposition: the reported removal of buildings behind the player is fixed at P33 and both nearby angles. This does not close the remaining roof-geometry or general ground/interior issues in the consolidated ledger.

The old closed-shell cutaway continued past the actor to the ground receiver without distinguishing separate buildings. A simple actor-depth cutoff would leave the back wall of the foreground house visible. The selected solution carries complete construction ownership through the resource-free placement payload and chunk projection into native per-instance data. Complete prefabs use their actual combined native bounds. Modular rooms retain their inhabited-building identity; separate roofs and continuous roof components inherit their bearings. Generated wall caps carry the same owner. No native vertices, UVs, collision or authored colors change.

An owner entirely behind the actor's horizontal camera-facing plane stays opaque. All surfaces of a foreground enclosure share its decision. A second failure was found at the soft boundary: different depths received different coverage, exposing deeper house surfaces after the front face disappeared. Each enclosure now evaluates the mask at one camera-facing support plane, using a ray reconstructed from screen coordinates so all its surfaces agree even at the last pixel of the feather. Actual ground depth and its inward feather remain mandatory.

The original implementation damages 2,665 independently rendered background pixels in each of four world orientations. The initial boundary candidate exposes 402/256 interior pixels at radii 3/6 in each orientation. The common mask first reduced this to one inconsistent pixel; screen-coordinate ray reconstruction removes it. The final native test checks three radii in four orientations: every affected pixel is either the original closed exterior or the independently rendered background, within 3/255 channel tolerance. An offset-storey regression failed three ownership assertions before the inhabited-volume change. The final focused run passes **41 tests / 333 assertions** with a clean exit, covering camera roles, ground/void controls, native houses, shared materials, native mesh ownership and payload projection.

Six native matched before/after sets in `enclosure/` were inspected with their difference images: P33 and P06 at reconstructed yaw 0/-8/+8 degrees. P33 keeps the blue-roofed building and its facade behind the player while the foreground clears. P06 keeps the complete background facade instead of exposing its reverse wall. The roof control rectangle [720,180,800,250] in P33's reconstructed original view has 97.43% of pixels differing by more than 3/255 from opaque before; after, none do (maximum channel difference 2/255).

P06's small orange roof initially looked like another visibility leak. The separate `native-control/P06_house/background-only/` renders omit complete foreground owners and use original materials with no cutaway. They show the same orange roof form. This is existing incomplete/joined roof geometry, retained under issues 08/11 rather than declared repaired here. The independent control is diagnostic only: its omitted foreground props and shadows are not a proposed gameplay rendering. The earlier `candidate/`, `roof-owner/` and `shared-mask/` stages are not final evidence.

| View | Mean absolute RGB difference (0–255) | Pixels differing by >20/channel |
|---|---:|---:|
| P33 original | 12.124 | 23.44% |
| P33 -8° | 13.337 | 25.77% |
| P33 +8° | 10.924 | 21.94% |
| P06 original | 12.085 | 21.73% |
| P06 -8° | 11.449 | 20.70% |
| P06 +8° | 12.077 | 21.77% |

These differences locate the repair; they are not by themselves proof of correctness. Receiver-free pixels have no changes above 20/channel; small shadow/readback differences remain (maximum 9/channel). The stricter independent ground/void GPU fixture passes. No black captures are credited. Poses, viewports and frozen shader clocks are paired exactly; the original screenshots contain rounded player/crosshair overlays, so full-precision original camera recovery is not claimed. No global renderer, walking or performance acceptance is claimed.

[Reported view comparisons](enclosure/P33_background/judging.png) · [Earlier house comparisons](enclosure/P06_house/judging.png)
