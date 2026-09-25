# Native terrace jump collision

The native turf underside caught the player during close approaches. Ordinary
terrain does not use its decorative cliff/turf mesh for collision. Native
terraces now share that treatment: the actual flat turf top and its outline
continue vertically to the buried base. The outline retains the authored
rounded corners. No rectangular bounding proxy replaces it. Decorative side
recesses and the underside cannot become a low ceiling during a jump.

`NativeTerrainCap` provides the same measured top to collision and grass.
The nine terrace definitions prepare their closed physical columns once;
workers transform detached triangle arrays. `kaykit.rock.05` retains its full
native mesh collision. All still combine into one static concave shape per
nonempty terrain chunk. Visual meshes and placement transforms are unchanged.

## Reproduction and verification

The original native profiles fail 16/16 close jump approaches across four
4 m high assets and all four directions, with 81 underside contacts. Same-size
solid terrain controls pass 16/16 without underside contacts. The candidate
passes all sixteen approaches without underside contacts and retains all
sixteen solid controls. A separate timed repetition retains those outcomes.

The frozen production P18 scene reproduces three failed approaches at offsets
-1, 0 and +1 m along the photographed broad ledge. The candidate passes all
three without underside contacts. The comparison matches 569 exact native
columns to their original collision triangle blocks, replacing those blocks
and preserving the rock triangles. Duplicate depth-view geometry is excluded
from ownership; the initial harness attempts that counted those copies are
not credited. `jump-game-pairs.png` contains three matched photo-angle views
and three paired jump outcomes. Both sides use the same ground, grass and
surroundings from the complete streamed scene.

All 31 related tests pass 649 assertions. All nine assets retain every actual
flat top triangle, have closed physical edges, and have no exposed downward
faces. Grass contact, split chunk identity, wet exclusion and detached worker
checks remain green.

The fresh production world passes all three approaches without underside
contacts, using the actual worker-emitted collision. All three photo angles
and three jump outcomes in `live-collision/P18` were visually inspected.
Startup takes 359.170 s; 15 local grass tiles retain 140 native cap roots.
The harness snapshot emits its existing editor-only shader-list warning; it
does not occur during ordinary game streaming. No fresh-scene replacement
or collision injection was used for this run.

## Shape audit and measured cost

The inventory is in `collision-inventory.json`. Native physical bounds follow
the flat top, leaving only the existing decorative 0.235–0.25 m turf rounding
outside, just as the ordinary cliff decoration extends past its ground sheet.

| Native asset size | Original triangles | Terrain triangles |
| --- | ---: | ---: |
| 2x2x2 | 336 | 64 |
| 2x2x4 | 336 | 64 |
| 2x2x8 | 384 | 64 |
| 4x2x2 | 536 | 100 |
| 4x2x4 | 520 | 100 |
| 4x2x8 | 604 | 100 |
| 4x4x2 | 698 | 124 |
| 4x4x4 | 700 | 124 |
| 8x4x4 | 1,026 | 188 |
| Native rock 05 | 438 | 438 |

In sequential isolated character runs, the median per-approach motion p50 is
0.514 ms before and 0.290 ms after; median per-approach p95 is 1.944 ms and
0.815 ms. The solid controls' median p95 is 0.700 ms and 0.698 ms. These measure
the character's complete motion call during these approaches, whose paths
change when jumping succeeds. They are not an engine-wide performance bound
or a controlled estimate of collision-only speed. Preparation takes 842 ms
including resource loading. No village, streaming, water or full-suite
acceptance is claimed.
