# Reopened — owner rejected the silhouette approach

The owner requires contextual see-through obstacles rather than a glowing character. The marker integration was removed. The prior candidate report below is retained as rejected evidence; its acceptance is withdrawn.

# Ground remains opaque in tactical view

Accepted for the four reported ground-cutaway sites and the measured controls. The broader September 12 review remains in progress.

## Reproduction and alternatives

The old visibility adapter protected upward surfaces only within five metres of the player, with an additional slope/height bound. The reported crescent lies beyond that protection. Native GPU controls at 0, +12, -12 and +35 degrees reproduced all four failures before the fix (`red.txt`).

Considered a larger protection radius, excluding whole terrain batches, and identifying actual upward terrain surfaces through the shared ground material. A larger radius merely moves the defect; excluding whole batches also removes vertical cliffs from occlusion handling. The common ground-style material now identifies terrain, paths, native caps and grass, and its upward faces stay opaque at every distance. Vertical faces retain their existing behavior. No terrain mesh, placement, collision shape, water field or movement rule changes in this issue.

The first ground-only change left a bare grass crescent; it was rejected. The shared ground-style definition fixes ground cover too. The original grass control fails four assertions (`grass-red.txt`); the final terrain and grass controls pass.

## Maintaining character visibility

At the two heath poses, actual collision probes find a six/eight-metre cliff less than a metre behind the actor. Preserving solid ground genuinely hides the actor. A small camera lift cannot clear that bank; an inward boom would end almost against the actor. The camera remains fixed, with a muted silhouette when the head is occluded.

The initial material-overlay silhouette exposed self-occluded body parts; it was rejected. The final marker compares opaque scene depth with an actor-only depth render of the **same world, meshes and skeletons**. Reserved render layer 20 isolates that pass; a depth-copy quad encodes millimetres, and the main camera composite draws only occluded actor pixels. Visible head/hat suppresses the marker, so ordinary grass around the feet does not highlight the legs. Source materials remain untouched. Camera switches and scene exit release the pass and restore only the owned layer bit. A motion replay reproduced an unsafe tree-exit deletion in the first implementation; deferred exit cleanup and a reparent/re-entry regression resolve it (`motion.txt`, `motion-retry.txt`).

## Matched visual judging

`accepted-live/` contains twelve freshly streamed native before/after pairs, four `world.scn` snapshots, camera transforms and amplified pixel differences. Each source angle is reconstructed with `ReviewCam.solve_cam` from the original rounded player/crosshair overlays, using the original tactical distance 26, height 16, look height 1 and FOV 50. Each pair uses an identical camera transform and a 1716 × 1033 game viewport. Original full-precision camera positions cannot be recovered from rounded overlays; these are matched reconstructions, not a claim of bit-exact source-camera recovery. Shader clocks are frozen within each pair.

All twelve pairs and their differences were visually inspected. Spawn/town retain the visible actor and surrounding structures while removing the grey ground crescent. Both heath sites retain continuous ground and grass over the formerly exposed backsides; the silhouette locates the actor. Eight nearby views at ±8 degrees retain those outcomes. The floating water at spawn remains visible and belongs to the separate pending water issue.

Intermediate `final/`, `silhouette/`, `depth-marker/`, `head-marker/` and `motion/` are native frozen-world replays. Those snapshots do not reproduce the live biome palette, so their green terrain is not credited as live colour evidence. The final accepted images use the live world and correct biome palette.

| View | Mean absolute RGB difference / 255 | Pixels changing by more than 20 |
|---|---:|---:|
| 23_town_-8 | 2.815 | 8.02% |
| 23_town_0 | 2.865 | 8.03% |
| 23_town_8 | 2.914 | 8.02% |
| 24_spawn_-8 | 2.818 | 8.01% |
| 24_spawn_0 | 2.843 | 8.00% |
| 24_spawn_8 | 2.861 | 8.00% |
| 28_heath_-8 | 5.462 | 15.02% |
| 28_heath_0 | 5.840 | 14.66% |
| 28_heath_8 | 5.804 | 14.23% |
| 30_heath_-8 | 3.998 | 11.93% |
| 30_heath_0 | 3.994 | 11.85% |
| 30_heath_8 | 3.949 | 11.77% |

These difference magnitudes locate changes; visual judgement and controls determine acceptance. The diff images show the former crescent/holes and hidden actor, with the surrounding landscape retained.

## Verification and limits

- Seven focused visibility/render/marker suites pass 19 tests / 193 assertions (`integrated-tests.txt`).
- Camera roles and close-view obstruction pass 15 tests / 70 assertions (`camera-role-tests.txt`). Total: 34 tests / 263 assertions.
- A 600-frame alternating marker-off/on camera-orbit and synthetic-jump replay completes. Six matched motion pairs retain solid ground and a readable marker. This is deterministic motion replay, not an additional real-player walk.
- On the loaded host at 1716 × 1033, adjacent off/on frame medians are 15.046/15.861 ms and 14.884/16.011 ms; marker CPU p95 is 0.041 ms. This measures roughly 0.8–1.1 ms extra frame time in these runs, not a global performance bound. A concurrent cold world was generating during this measurement.
- Final fresh startup takes 280.559 seconds and remains expensive. No streaming, water, town-generation, collision-performance or full-suite acceptance is claimed.
