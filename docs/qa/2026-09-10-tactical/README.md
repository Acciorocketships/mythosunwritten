# Tactical camera and directional movement

Feature branch: `codex/tactical-camera-controls`, based on `f3203d96`.
This work is isolated from the concurrently active main checkout.

## Controls and framing

- Camera: 14 m horizontal distance, 16 m above the player's feet, looks at 1 m
  above the feet, 50-degree perspective FOV. Approximately 47 degrees downward.
- WASD moves relative to the current camera. Mouse aim controls facing even
  while stationary, airborne, or travelling sideways/backwards.
- Outward horizontal mouse motion in the outer 22.5% on either side rotates the camera
  at 0.006 radians per viewport pixel. No button is required. The central 55%
  does not rotate; leaving the mouse stationary never rotates. Returning toward
  the centre keeps the chosen view, so repeated outward gestures can orbit fully.
  Q/E still works.
- The aim ray meets a plane at the player's feet, so foreground roofs cannot
  steal aim. A 25 cm zone at the player's feet holds the last facing direction.
- Physics speed caps for AI/test controllers remain unchanged. Player movement
  follows the measured clips at two gait cycles per second: approximately
  4.2 m/s forward, 4.66 m/s sideways and 1.6 m/s backward. Diagonal weights and
  travel speed follow the blended stride rather than cancelling or sliding feet.

## Animation evidence

The source clips have different durations **and different foot phases**. Their
`.res` loop modes are also disabled. Equalizing duration alone leaves their
left/right support phases misaligned, and node-level looping alone does not
turn on interpolation across the source resource's loop boundary.

`gait_phase_report.gd` samples the real Mage skeleton at 120 phases per source
clip. `source-gaits.json` retains foot/toe positions; `phase-analysis.json`
compares normalized left-minus-right foot heights against Running_A.

| Clip | Source duration | Applied phase offset | Error before → after |
|---|---:|---:|---:|
| Running_A | 0.800 s | 0 | 0 → 0 |
| Walking_A | 1.067 s | 1/6 cycle | 1.018 → 0.028 |
| Walking_Backwards | 1.067 s | 3/4 cycle | 2.051 → 0.014 |
| Running_Strafe_Left | 0.800 s | 0 | 0.122 → 0.122 |
| Running_Strafe_Right | 0.800 s | 0 | 0.116 → 0.116 |

The strafe signals' optimum is within one sample of zero; the existing phase
is retained. The aligned sources use a common one-second timeline and one
cadence controller, with sync enabled even at zero blend weight. Idle is a
separate blend, so diagonals never pull in an unintended idle pose. The editable
`characters/animations/DirectionalAnimationTree.tres` exposes the blend and phase
settings in Godot. Each character owns private animation graph/library copies.
Direction and cadence transitions are smoothed to avoid abrupt reversal pops. Jump and swim-entry
one-shot behavior remains intact.

Godot applies start_offset before stretching the timeline, so these offsets
are **normalized timeline seconds**, not original-clip seconds. This was checked
against [Godot 4.5's animation implementation](https://github.com/godotengine/godot/blob/4.5/scene/animation/animation_blend_tree.cpp).

Actual AnimationTree tests inspect eight directions through two full cycles:
ankles remain above the floor, adjacent 1/120 s samples stay continuous through
wraps, and each direction retains alternating leg lift. Rendered review uses
30 frames across two cycles, with additional views of diagonals and backpedal.
These are blend/continuity checks; this feature does not add foot-placement IK.

## Visibility bubble

The camera performs a render-bounds query every 100 ms, or immediately after
moving more than a metre. A corridor narrow phase excludes the floor and distant
objects. Using rendered geometry rather than physics rays also catches
non-collidable trim, foliage and independent neighbouring building components.

A material adapter evaluates world-space coverage per fragment between the
player and the camera, fading smoothly across a 3.8 m radius. The core leaves
12% pixel coverage. Depth ordering and shadows are retained; separate layers
share the coverage pattern rather than compounding opaque fragments. The
player's own descendants, surfaces below their feet, and geometry behind the
view corridor remain visible normally. A moving bubble restores original
material references, including MultiMesh resources, when they leave its bounds.
Shader variants are shared among matching material sources. Live source uniforms,
including water's changing textures, continue to propagate to faded wrappers.
The protected floor uses the physical foot height independently of the smoothed
visual focus, so stepping up does not fade the supporting floor.

The effect is **dithered transparency**, not sorted alpha blending. It works
with the project's MeshInstance3D/MultiMeshInstance3D world, including collision-free
components; CSG roots are also handled. Custom spatial shader code is preserved.
The native PBR adapter preserves the project's texture sampling, vertex colour,
albedo, normal, metallic, roughness, AO, emission, cull and transparency settings.
Exotic future native-material features such as parallax/triplanar mapping are
not covered by this adapter; they should use an equivalent custom spatial
shader or extend the shared adapter, never per-object fade scripts. Particle
systems and labels are not selected as solid occluders.

## Reproduction

Run with the Godot 4.5.1 executable and this worktree as `--path`:

```text
--headless -s res://tests/harness/gait_phase_report.gd
res://tests/harness/tactical_review.tscn
res://tests/harness/tactical_review.tscn -- --gaits
res://tests/harness/tactical_world_review.tscn -- --all --output <output-directory>
```

Small synthetic captures go to `.artifacts/tactical/`. Bulk render frames remain
ignored local QA artifacts, following the repository's consolidation policy.
`pixel-checks.json` records the synthetic comparisons: restoring the original
resources is pixel-exact; the distant member of the same MultiMesh and an
unobstructed floor region remain pixel-exact during fading. The native adapter
at zero fade differs by at most 2/255 per channel from Godot's generated shader.
That small difference is a renderer/material-adapter limit, not a geometry change.

## Validation

Final focused controls, animation, camera, visibility, stair and swim checks pass:
28 tests, 241 assertions. The additional GPU checks also exercise actual MultiMesh
buffer transforms and live shader-uniform updates. The final GPU repeat passed six tests / 27 assertions and exited 0. An earlier
GPU-only run passed its assertions but hit signal 11 during engine shutdown;
that event and the successful rerun are retained in `focused-tests.json`.
Both final graphical capture harnesses exited 0 without script/shader errors.

The production render harness uses the current streamed town at
(237.4, 8.0, -370.2), with matched before/zero-fade/after views in four orientations.
An additional balcony review uses (227.1, 20.1, -369.7). The numeric CPU timings
measure warmed bubble updates, including periodic bounds queries; they do not
measure GPU frame cost, first-use shader compilation, or total streaming performance.

Across four town views the final bubble selected 60–64 components and 63–69
source materials, sharing 6–7 shader variants. Warm median update cost was
1.463–1.647 ms and the largest sampled update was 2.245 ms while the broad suite
also ran on this machine. See `town-metrics.json` for each view.

![Matched town visibility and directional pose comparison](review.jpg)

The local animation loop is available at
[directional-gaits.gif](../../../.artifacts/tactical/directional-gaits.gif).
The image above is one pose sample; the 30-frame render sequence and skeleton
continuity checks provide the motion evidence.

The repository-wide run completed **1,208 tests in 157 scripts**: 1,177 passed,
30 failed and one was pending, with 401,374 / 401,467 passing assertions in
3,239.537 seconds. Every failing test name matches the September 10 consolidation
baseline; there are no added or missing failure names. The baseline cliff,
cold-start, composition and historical-water failures remain unresolved.
The process exited 134 after the complete summary with the same
`recursive_mutex lock failed` shutdown error recorded in that baseline.
See `full-suite.json` for the exact comparison.

The broad run used a frozen feature copy. The later physical-floor protection,
live material-uniform synchronization and return-to-centre orbit guard were
verified by the final focused run; visibility was also checked on the GPU and
in matched synthetic/town renders. The frozen source files and complete logs
are retained locally under `.artifacts/tactical/validation/`; both the frozen
and final source hashes are recorded in the versioned JSON reports.
