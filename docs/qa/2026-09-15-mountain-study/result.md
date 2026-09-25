# Mountain-face art study — September 15, 2026

Implemented the proposed original mountain/valley study and iterated through six
visual revisions. The result uses eight new real 3D limestone assets, Quaternius
trees, ferns, bushes and rocks, existing MegaKit vines, and authored stone/moss
shading. No new pack purchase or SimplePolygon asset was needed.

![Final Godot catalogue render](final/hero.png)

## What changed

Large connected buttresses frame a winding valley. Taller split crowns and narrow
pillars vary the skyline and establish depth. Irregular volumetric fractures
replace the earlier small square/pyramid vocabulary. Recessed, planted shelves,
green crown clusters, face vines, ferns and grouped rock-foot vegetation provide
several scales of detail. Warm grey stone, moss, soft shadows and restrained
distance haze keep the main forms readable.

All custom geometry was authored from original mathematical profiles. Native
plant models retain their geometry; study-only palette adapters make the selected
tree leaves and vines read green. The study lighting and ground material are
local to its own viewport and do not change the game's biome profiles.

## Iteration and visual judgement

The same six cameras were retained for v1–v6: wide, gameplay, left, right, close
and overlook. V6 adds a seventh hero frame with the whole mage visible. These are
real Godot Metal/Forward+ renders, not generated concept images.

- V1: rejected smooth post-like forms and sparse dressing.
- V2: introduced closed fracture stones and larger connected masses. Rejected
  tiny degenerate bevel triangles found by geometry tests.
- V3: improved grass distribution and ground/path shading; reduced haze.
- V4: added richer relief and erosion. Rejected excessive warp because close
  views revealed large triangular ridges. Fixed the last tiny mesh slivers.
- V5: reduced warp, shortened grass, widened grass clusters, refined sky and
  foliage scale. Rejected pale-looking vines and bare shelf tops.
- V6: irregularized fracture heights, applied green vine shading, planted the
  actual shelf surfaces and fixed the mage idle pose/framing.

V6 is the retained study direction. It is a substantial improvement over the
initial study; this is an art judgement, not a claim that further improvement
is impossible. The surrounding hills remain a simple study backdrop. Broader
terrain composition and the foliage's distant alpha detail still need evaluation
in the real biomes before production integration.

The final catalogue replay preserves the source study in all seven views.
Mean absolute RGB error is 0.00095–0.00763 on a 0–255 scale; at most 0.01475% of
pixels differ by more than eight in any channel. The comparison report is
`final/source-catalogue-comparison.json`. `bare/` contains matching unplanted
geometry controls. Version directories retain the earlier images and source
snapshots so rejected choices remain reviewable.

## Native assets and validation

| Runtime suffix | Triangles |
| --- | ---: |
| pillar_slender | 10,066 |
| pillar_split | 10,830 |
| pillar_crown | 11,236 |
| buttress_tall | 9,370 |
| buttress_wide | 9,984 |
| shelf_long | 516 |
| shelf_end | 528 |
| shelf_corner | 556 |

Each ID begins `mythos.mountain.` and has one merged runtime visual piece and one
native triangle-collision owner. The normal environment manifest, descriptor,
index and provenance pipeline owns these assets. No new baker behaviour was
required. The baker rejected the first material location inside the source asset
folder; the final shader/material use runtime-owned paths and pass that gate.

- Two Python mesh tests pass: deterministic generation, finite coordinates,
  native scale/triangle budgets, closed edges, consistent winding, positive
  volume and nondegenerate triangles for every independent stone component.
- One native GUT test passes **152 assertions** across all eight catalogue assets.
  The pre-bake red run failed for all eight missing descriptors.
- Imported render/collision vertices differ by at most **0.0853 mm** due to mesh
  compression. Five-direction native ray surveys stay within **1 mm**; the
  largest measured oblique-ray difference was 0.382 mm. Exact float-array equality
  was therefore replaced with explicit measured precision bounds, not hidden.
- The assembled final study has **41/41 clear standing-capsule samples**, zero
  missing ground, and **18/18 matching physical/visual surface contacts**.
  Overlapping shelf/host queries compare the complete visible union; the initial
  three shelf-centre mismatches were upper host crowns intercepting those rays.

These are static collision queries, not a real-player long walk or a world-wide
terrain test. Source and catalogue study renders were inspected at wide,
gameplay, side, close and elevated viewpoints. Final console logs are in `logs/`.
The first headless invocation crashed in Godot's user-log rotation under the
sandbox; explicit `/tmp` log paths allowed the checks to run. A broad editor
import encountered read-only Quaternius source directories and was stopped after
the eight new GLBs had imported. The successful final source/catalogue renders
and focused tests do not depend on that broad import completing.

## Inspect in Godot

Open `tests/harness/september15_mountain_study.tscn`, or from the project root:

```sh
godot --path . tests/harness/september15_mountain_study.tscn -- --catalogue --interactive --output=res://docs/qa/2026-09-15-mountain-study/inspection
```

The scene first saves the seven review frames, then exposes the free-flight
camera: WASD movement, Q/E vertical movement, Shift faster movement, mouse look,
Escape releases the mouse, click captures it. It is an inspection scene, not a
replacement for the real player controller.

## Scope

This completes the proposed mountain-face art study and reusable source/runtime
asset kit. It does **not** replace the procedural world's cliffs yet. Global
placement must still respect its full public/path/water footprints, grounded
bearings, chunk ownership and biome palettes. That integration, shipping LODs,
streaming cost and actual player traversal remain unvalidated. Existing terrain,
village, water and camera repairs are not superseded by this isolated study.
