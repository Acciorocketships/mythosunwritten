# Mossy external cliff rocks — September 15

The latest owner direction replaces sparse stacks of normal cliff tiles with
external mossy rock formations. The original terrain, cliff faces, rounded lips,
corners and flat grass-grid crowns remain the underlying construction.

## Implemented

- Four adapted CC0 Ultimate Nature rock forms (`Rock_Moss_1/2/4/7`) supply broken
  ribs and irregular outcrops. Eight original closed ledged ribs supply continuous
  backing. Broad matte facets and restrained stone/green colors match the low-poly
  asset reference. No bought mountain pack or reference-image geometry is used.
- Unequal heights, overlapping widths, yaw and lateral shoulders vary the relief.
  Whole solids reach the actual neighboring ground, including intermediate native
  terraces. Upper pieces cannot become unsupported hanging sheets.
- Green shelves are part of the rock geometry. Bush roots use exposed upward
  triangles, reject buried/intersecting sites, and stay above sampled water.
- Canonical panels use native cell boundaries at `-12 + 24n`. Neighboring chunks
  consider the same halo before emitting only their own rocks/plants. Full rock
  bounds reserve ground dressing and avoid grading/public route reservations.
- Main-thread preparation loads the baked catalogue; workers receive only detached
  geometry and bounds. Each rock's actual transformed visual triangles become its
  collision. The obsolete native terrace producer is no longer called by the mesher.

## Qualitative iteration

The numbered study images are real Godot renders in the frozen P04 world.

| Candidate | Judgment |
|---|---|
| Earlier native-tile candidate | Rejected: smaller cliff tiles still read as pyramids. |
| Moss 01 | Rejected: repeated upright rods and pale smooth shading. |
| Moss 02 | Better silhouettes; rejected for smooth shading and exposed upper strips. |
| Moss 03 | Flat shading and darker stone improve the match; insufficient coverage. |
| Moss 04 | Invalid inward winding; rejected before visual acceptance. |
| Moss 05 | Closed ribs cover the wall but look too much like a block wall. |
| Moss 06 | Uneven shelf heights improve relief, but the rear ribs still dominate. |
| Moss 07 | Layered broken foreground outcrops obscure the regular backing; chosen direction. |
| First production render | Rejected red foliage: source leaf palette differed from the study. |
| Final production | Green material restored; actual terrain roots, halo ownership, collision and plant occlusion checked. |

The final dry view has substantially less exposed repetitive stock and a varied
silhouette. The lower banks read as broad mossy outcrops rather than miniature hills.
The reference's much taller landforms and realistic detail are not reproduced;
the flat grid topology and stylized faceted appearance are deliberate. Native corner
returns remain visible in some places. Protected routes/graded areas may remain bare.

## Render evidence

- [P04 matched before/after/difference](moss-rocks/comparison-P04/P04_0-comparison.png):
  full production rebuild; all three camera transforms and FOVs equal the baseline.
  Changed image area above the existing luminance threshold: 22.58–25.97%.
- [P04 nine-view review sheet](moss-rocks/P04-review-sheet.png): reconstructed photo
  and ±8°, plus wide 0/±30/±90/180° views. Flat crowns remain intact; no unsupported
  underside is visible in the inspected oblique views.
- [P06 final riverbank](moss-rocks/final-P06/P06_0.png) and
  [nine-view review sheet](moss-rocks/P06-review-sheet.png): the same rock treatment
  reaches the submerged foot and covers the formerly bare exposed banks.
- [P06 isolated dressing comparison](moss-rocks/comparison-P06/P06_0-comparison.png):
  new rock/bush batches hidden versus visible in the same final frozen world.
  This is an isolation control, **not a historical full-generation baseline**.
  All camera transforms/FOVs match; changed area is 6.94–7.61%.
- P07/P08 are additional geometry controls loaded from the final P06 snapshot.
  Their dense grass was outside that snapshot's prepared radius; these cannot be
  credited as grass-streaming comparisons. P07 retains the previously repaired
  ordinary slopes and clear house frontage.
- P08's raw 22.3 m photographed feet are below the present 24 m terrain surface.
  The obstructed replay remains obstructed with new rock visuals **and collision**
  removed; neither raw view counts as a pass. Reusing the earlier recorded camera
  confirms the cap geometry but leaves the actor buried. A separate downward
  physics probe places the actor at 24 m in both versions; the three resulting
  camera poses match exactly, retain a clear rounded crown, and show no new camera
  restriction. [Supported P08 comparison](moss-rocks/comparison-P08/P08_0-comparison.png).
  This is a supported-position control, not the original photographed height.

The pixel differences show where the change occurs; they do not prove aesthetic
quality. The direct and oblique images were judged separately. Camera reconstruction
uses rounded original player/crosshair overlays, not an exact recorded camera.

## Tests and falsification

The initial production regression failed with 17 ordinary native terraces and no
new rock formations. The final producer passes that regression while retaining
the original `CliffDressing.compute` data exactly.

- Final terrain/rock/panel/vegetation run: **69 tests / 6,744 assertions pass**.
- Related retained native-library run: **35 tests / 5,079 assertions pass**
  (overlaps the final run). Historical library tests now explicitly exercise that
  library; they no longer assert that it is the selected production art.
- Eight moss-rock tests pass **1,317 assertions**, including actual committed
  downward physics probes, public reservations, main/worker agreement, unique
  ownership and real neighboring chunk rock/plant agreement.
- Actual ray/triangle coverage hits **640/640 points in each of four cardinal
  orientations** on the sampled straight face. This is not a claim that every
  corner or protected face in the world is covered.
- Closed-solid checks use a measured 0.0002 source-unit weld tolerance: independent
  material surfaces export shared coordinates up to one 0.0001 step apart per
  component. Winding, degenerate triangles, and complete collision faces are checked.
- An initially failing root test assumed every base was at zero. Inspection showed
  the normal terrain clamp creates a real 16 m intermediate terrace. The corrected
  invariant compares each root with the actual sampled neighboring surface.

Logs, red evidence, coverage output and difference metrics are in
[`moss-rocks/validation`](moss-rocks/validation).

## Scope and remaining work

This accepts the inspected cliff art and its construction contract, not all earlier
reported defects. Path gaps, roof finishes, missing door and remaining older items
retain their separate issue-ledger statuses. No complete water or full-suite claim.

Cold production startup took 248.427 s at P04 and 230.845 s at P06. Terrain mesh
phases ranged 0.606–2.111 s/chunk in those runs; much longer feature/water preparation
still dominates arrival. These measurements are not a controlled speed comparison
or a streaming-performance acceptance.
