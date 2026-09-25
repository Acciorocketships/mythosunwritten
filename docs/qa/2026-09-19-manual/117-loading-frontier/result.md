# Loading-boundary fog and slow-generation diagnostics

Production now derives fog from committed ground coverage, not requested radius,
feature readiness or a bounding rectangle. A view ray stops at its first missing
192 m ground owner, including holes and gaps before disconnected loaded islands.
The fog is completely opaque at that boundary and beyond it. A smooth inward fade
uses perpendicular distance to the boundary; its width contracts near the camera
to preserve nearby footing. Biome atmosphere supplies the colour. Overhead sky stays
clear. Collision and safe-arrival gating are unchanged.

The first fixed-width candidate washed out too much nearby ground and was rejected
(`rejected-wide-fade`). The final three-angle native replay hides unfinished ground
and the retained hanging cliff/feature pieces. Loading the missing owners reveals
the ordinary scene. See `partial-before-0.png`, `partial-fog-0.png` and
`loaded-fog-0.png`, plus the ±8-degree controls.

The production atmosphere controller owns the pass. Coverage is uploaded only when
resident keys or the camera owner change. A bounded 32×32 map handles transient
teleport residents without treating intervening unknown space as loaded.

## Reproduction and limits

Seed 2697992464, N01's rounded player/crosshair coordinates reconstruct the reported
view. A fresh nine-chunk live run actually reproduced the void beside native cliff
strips (`live-first-ground.png`). Its startup completion log reports **759.255 s**.
The completed scene was frozen into `world.scn`; subsequent comparisons deliberately
omit selected ground owners while retaining every cliff, water and feature piece.
That is a controlled coverage falsification, not a reconstruction of the user's exact
travel chronology. The snapshot does not contain the player; a close actor-sized
object is checked separately on the native GPU. The live baseline predates these
production fog/diagnostic changes. No claim of faster overall startup is made.

Five GPU pixel controls verify unchanged nearby colour, concealment beyond the
boundary, revelation after coverage arrives, close-to-boundary footing, and **exact
opacity at the boundary**: recolouring the hidden object has no effect on its pixel.
Three coverage tests / nine assertions reproduce the geometry error before the fix.
The related queue/yield run has 16 tests / 46 assertions; two observer tests add six
assertions. All pass. GPU frame-time impact and extended moving/underwater arrivals
remain unmeasured. Native runs retain the pre-existing village UID warning.

## What remains slow

The live baseline records 383.992 s in terrain meshing, 284.102 s in feature paths
(including water queries), and 67.198 s in water contexts. Nine main-thread terrain
commits total 52.039 s, with a **17.619 s maximum**. These are diagnostic timings,
not an isolated before/after throughput comparison.

New ordinary-play logs identify the exact outstanding feature generations blocking
ground, active worker phases, loaded ground owners and player freeze state. Meshing
now exposes arches, formations, vegetation and graded cliffs separately. Slow commits
split terrain, water, dressing collision and publication/FX time. Observers retain
identical detached payloads and cannot publish readiness.

Pass 118 moves the identified cliff normal preparation out of main-thread commits.
S01 generation speed and S02 publication ordering remain open. S03 has this scoped
fog implementation and native evidence; broader arrival acceptance remains open.
The additional town, corner, shoreline and bank-water reports in `scope.md` are not
fixed by this pass.
