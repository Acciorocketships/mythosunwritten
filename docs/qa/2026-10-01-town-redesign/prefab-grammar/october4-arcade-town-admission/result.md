# October 4 — arcade family in generated towns

The production vocabulary now includes four arcade configurations across two
measured reservation profiles (40 native configurations / 11 profiles total).
Selection uses the existing procedural plot/variant mechanism. There are no
seed-specific placements. The source prefab, tall window variants and shortened
arcade are available; native geometry stays intact through kit substitution.

The actual-character town harness recognizes the arcade's material-bound door
asset. The town integration audit counts the new asset namespace as well as the
older native namespace, so complete-placement and public-clearance assertions
cover the entire new family rather than silently skipping its pieces.

## Evidence

Eight surveyed towns build. Arcade houses survive into the final payload in
7/standard, 31/large, 43/grand and 103/grand. The first is a tall hooded variant;
31 is the shortened flush-window variant. The survey records an arcade selected
but not accepted in 211/grand; selection alone is not counted as realization.
Other native families remain available. Corner-turret seeds 8 and 9 still pass.

Generated-town integration: four tests / 1,277 assertions pass, including both
short and tall arcade towns. Holdout 103: one test / 266 assertions pass. Existing
corner-turret regression: one test / 1,077 assertions pass. These verify complete
parts, preserved collisions/transforms, no generic-house substitution, and
clearance from finished public walking air. Six actual-character routes pass:
seed 7's two native entrances both directions, and seed 31's arcade both ways.

Two town overviews and close arcade frontages in 7, 31 and 103 were inspected.
The covered ground recess, curved native supports and boarded inhabited floor
read clearly and remain grounded in these flat review scenes. The nearby houses
retain their distinct kit materials. This is not a terrain-streaming verification
on naturally sloped ground, nor an exhaustive inter-building triangle audit.

## Art findings and remaining scope

The front middle course is a large blank plaster panel in the source prefab,
which remains too quiet at town/player scale. A compatible whole-window-bay
variant should address it while keeping the exact source configuration possible.
The broad overview also retains long simple roof runs and exposed decks elsewhere;
this family does not resolve the full massif/enclosure and skyline requests.
Continue those areas and whole-town visual/player verification. The overall
October 1 goal remains active.
