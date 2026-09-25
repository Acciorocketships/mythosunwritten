# Lower stepped junction studies — pass 103

**Five art variants rejected; production remains pass 102.** The previous goal turn made progress by integrating and verifying the short inner-gap repair. This turn investigates the remaining lower crossing with actual fresh-world geometry. It does not integrate a new production fix.

## Diagnosis

The visible crossing involves three formations: the tall wall at `(-445.5,28,-267)`, its collinear raised-base neighbor at `(-445.5,32,-289.5)`, and the perpendicular low wall at `(-439.5,28,-277.5)`. The tall and raised-base sections overlap along their common wall line, but their treads and rooted profiles differ. The perpendicular low wall contributes the lower shared ledge and the native terrain step.

At world z=-275 the tall wall's upper tread is approximately y=32.959–33.064, while its lower tread is y=30.249–30.251. At z=-279 the raised wall's main tread is y=33.021–33.575 and extends to depth 8.803 m; at z=-282 it is y=33.593–33.772 with depth 5.845 m. These are existing source geometry measurements, not proposed target dimensions. The shared-height lower ledge cannot be discarded merely to hide the overlapping upper profiles.

`logs/cliff103-inspect2.log` preserves those actual profiles. The first inspection used exact equality against float32 transforms and selected no forms; it is not evidence. The corrected inspection uses a position tolerance.

## Native art studies

All variants use the complete saved fresh pass-102 P12 world, 1600×1000 native Metal renders and the same five supplemental camera poses. The two lower-junction views of every variant were explicitly inspected. The other three views were captured but are not a new broad art-acceptance claim. Frozen terrain, grass and collision remain original; rebuilt crevice plants follow the study surfaces. These are isolated geometry studies, not production placement, ownership, hydraulic or physical verification.

1. **Retreat (`study/`)** retracts the tall upper rock near the low crown. It moves 1,426 unique vertices on one wall, but exposes the raised neighbor's closing face and leaves the large blade. Rejected. Source: `retreat-rejected.gd`.
2. **Wide profile loft (`loft/`)** clips the two collinear sections and joins actual profiles over nine metres. It removes the crossing blade but stretches the source's two closely spaced treads into conspicuous long parallel strips. Its 16,564-triangle patch is too plain. Rejected. Source: `loft-wide.gd`.
3. **Shorter profile loft (`narrow/`)** uses six metres and a single upper tread. The upper curve improves, but the interpolated lower profile exposes an undercut at the terrain step. Rejected. Source: `loft-narrow.gd`.
4. **Upper-only loft (`upper/`)** keeps the original lower rock and limits the 12,428-triangle patch to the shared upper elevation range. The lower ledge stays, but the new upper foot still lacks a coordinated bearing into it. Rejected. Source: `loft-upper.gd`.
5. **Supported loft (`supported/`)** expands the tall lower profile to meet the upper patch's foot. It produces a new pointed lateral shelf at the perpendicular receiver and retains an awkward seam. Rejected. Source: current `transition.gd`.

- [Original fresh lower crossing](../102-corner-surface-loft/final-details/lower_inner_above.png)
- [Rejected retreat](study/lower_inner_above.png)
- [Rejected wide loft](loft/lower_inner_above.png)
- [Rejected shorter loft](narrow/lower_inner_above.png)
- [Rejected upper-only loft](upper/lower_inner_above.png)
- [Rejected supporting-base variant](supported/lower_inner_above.png)

The loft fixtures use pinned poses and omit production closure at clipped original faces. Their recipes do not represent the changed geometry. They must not be imported as runtime construction or used as physics evidence. All five native capture processes exit normally; no accepted production source was edited. Source hashes match pass 102 exactly, so its focused/native results remain applicable without an unrelated rerun.

## Next action and remaining scope

A repair needs one coordinated three-way surface through the tall wall, raised-base collinear wall and lower perpendicular receiver. The upper profile transition and its bearing must be solved together while retaining the existing lower tread. Pairwise upper lofting or proportional lower widening alone is insufficient. This diagnosis changes the next implementation target; none of the five images is accepted as the desired cliff appearance.

The lower crossing, broader cliff art and the original water/town/streaming/biome judging register remain open. The verified pass-102 short inner-gap fix is retained. No global or full-suite acceptance is claimed.
