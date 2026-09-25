# Near-camera visibility — P03 and P32

Disposition: fixed at both reported poses and four nearby controls. This acceptance concerns expanding foreground coverage, not P33 background-building preservation (next issue).

The original cone shrank to the camera, producing an almost constant screen-space opening. Increasing only the global circle would also enlarge the player's neighbourhood. A constant world-radius foreground segment instead preserves the player-plane footprint and naturally expands on screen toward the camera. The existing broad phase already encloses this cylinder. Actual ground depth still gates every revealed pixel.

The new shader regression first failed three of seven assertions (half-distance and both near-camera viewport corners). The final focused suite passes 37 tests / 285 assertions, including ground support, void rejection, four native house orientations, resource ownership, camera controls and ordinary rear-of-player rejection.

Visual iteration rejected the initial cylinder's residual canopy tint. The final camera default uses zero residual obstacle opacity, retaining spatial and temporal feathering. A depth-dependent residual-opacity trial was also rejected because the rear canopy/trunk still overlaid the landscape. The ground-mask feather now clamps sampling at viewport boundaries: leaving the viewport does not imply a hole in the ground; a real missing center sample still vetoes the reveal.

Native evidence is in `verified/`: two exact-pair reconstructed photo poses, plus -8/+8 degree rotations at each site. All six before/after/opaque/receiver sets and their differences were inspected. The P32 canopy no longer masks most of the screen; ground, bushes, rocks and lights are visible around the player. The P03 near-camera wall/obstacle clears at 0/+8 degrees. The already-open -8 degree control stays visually stable. Narrow spatial transitions remain at actual obstacle boundaries. No black frames were credited. Every pixel in these two landscapes has a real ground receiver; void rejection is independently tested in the mixed real-ground/void fixture, not inferred from that vacuous control.

The frozen snapshots were saved from the production world at each source position. Pair transforms, viewports and shader clocks are identical. `ReviewCam.solve_cam` reconstructs the rounded original overlays; the screenshot does not encode a full-precision camera transform. P32 uses its 16:9 game viewport. Static poses are not a physical traversal or a performance acceptance.

| View | Mean absolute RGB difference (0–255) | Pixels differing by >20 in any channel |
|---|---:|---:|
| P03_near_-8 | 0.377 | 0.03% |
| P03_near_0 | 17.357 | 65.57% |
| P03_near_8 | 16.459 | 64.10% |
| P32_canopy_-8 | 15.944 | 66.02% |
| P32_canopy_0 | 14.076 | 67.28% |
| P32_canopy_8 | 14.030 | 56.84% |

[Canopy before/after/difference](verified/P32_canopy/judging.png) · [Original near-obstacle before/after/difference](verified/P03_near/judging.png)
