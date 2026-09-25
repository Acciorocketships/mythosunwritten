# Issue 06: green, widening mountain terraces

**Accepted for the reusable source assets and the existing art study. Production
grid-cliff replacement is still issue 08; this result does not close it.**

The five tall assets now widen toward the base and have uneven intermediate
shoulders at three height ranges, with different elevations and widths on each
constituent column. Their actual upward surfaces receive the existing moss
material and native vegetation. The fractured stone vocabulary remains. The
three old separate shelf assets are unchanged; their study placement is issue 07.

![Matched hero and pixel difference](diffs/hero-comparison.png)

The generator splits the closed fracture surfaces at the shoulder elevations
before applying the shared stepped profile. Opening joints after that shaping
avoids stretching small gaps into large notches. Only sub-centimetre sliver
edges are collapsed. Original finite-coordinate, outward closed-solid,
determinism and 15,000-triangle limits are retained.

Four Python source tests pass. The original source fails nine asset-specific
ledge/width checks; buried fracture caps do not count as plantable ledges.
Two native tests pass **184 assertions**, checking every render/collision
triangle, five-direction contact rays and the catalogue against fresh GLB
geometry. All eight assets remain inside the existing triangle budget.

The first catalogue replay was rejected: its almost-empty differences revealed
that the ordinary baker had loaded stale editor imports. `bake_kit.gd` now loads
the generated GLBs directly into held PackedScenes before invoking the unchanged
environment baker. The new source-to-catalogue test reproduces fifteen failed
assertions on that stale result and passes after the fresh bake. No broad editor
import or source-pack permission change is needed.

Fourteen matched pairs were inspected: seven planted views in `diffs/`, and
seven bare geometry controls in `bare-diffs/` and the two review sheets. The
hero/gameplay views show widened rock feet and more green ledges; close and
overlook views confirm real upward surfaces; left/right/wide views retain
connected masses and the open valley. All camera poses and FOV values agree
exactly with the before captures. Pixel metrics are in `metrics.json` and
`bare-metrics.json`; foliage placement also changes because it samples the new
surface, so these differences are not a geometry-only mask.

Every final study retains **41 clear standing-capsule samples**, no missing
ground, and **18 matching physical/visual surface contacts**. These are static
study queries, not a real-player traversal, runtime performance acceptance or
proof that the remaining separate shelf placements are grounded. The unchanged
study lighting, backdrop and ground are outside this issue's scope.

## Reproduce

Run `build_kit.py`, then Godot headless with
`-s res://tools/mountain_art/bake_kit.gd -- --manifest
res://tools/environment_bake/manifests/mythos_mountains.json --keep-existing`.
Run `september15_mountain_study.tscn -- --catalogue` for the seven fixed views;
`--bare` supplies the geometry controls. The native test configuration is
`native-config.json`. Python requires NumPy and SciPy.
