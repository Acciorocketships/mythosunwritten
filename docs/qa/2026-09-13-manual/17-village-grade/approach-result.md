# P11 approach — accepted September 14

The photographed eastern village approach now admits the actual player uphill and downhill in all three measured lanes. The character's 45-degree floor limit and step handling are unchanged. This is a shared construction-grade rule, with no seed or coordinate branch.

The original collar multiplied the falloffs of overlapping maximal pad rectangles. That steepened the nominal 12 m transition. The new collar blends their boundary distances using a stable smooth minimum, whose gradient is a convex combination of the individual distance gradients, and applies the common slope profile once. A single rectangular pad keeps the exact original 12 m profile. Claimed foundation heights remain fixed; the complete finite expanded influence is published in the grade bounds and used by its target and interval queries.

## Reproduction and validation

- Seed 2697992464; original P11 feet `(980.5,17,-374.7)`, crosshair `(981.3,19.5,-377.4)`. Cameras use `ReviewCam.solve_cam`. `P11-field.txt` freezes the actual region and its single intersecting village grade, including inherited grade layers.
- The new tests first failed at slope 1.1291 on the reported approach and 0.6328 on a synthetic overlapping-pad collar. Final focused run: 20 tests / 19,240 assertions, including the existing construction-grade continuity, target preservation, conservative interval and native cliff tests.
- Original physical survey: maximum slope 1.1282 (about 48.45 degrees). Fresh production after: 0.7269 (about 36.02 degrees). Corrected actual-controller runs pass 4/6 before, with the centre and right uphill lanes stuck, and 6/6 after. Starts and destinations are on ground; the route ends before the building. No jumping is used. The first diagnostic `P11-walk-before` used roof starts downhill and is excluded; `P11-walk-baseline` is the credited baseline.
- Three matched native terrain pairs and three matched complete-world pairs, with differences, retain the buildings and show the relaxed approach. All six pairs were inspected at the source camera and +/-8 degrees. The full-world after was freshly generated, then replayed under the baseline's fixed lighting; the live capture independently confirms complete loading.
- Required corpus: 48/48 constructed towns, identical 11,764 clear walking positions and 16,891 clear crossings, with no disconnected route components. The same 25 conservative pillar contacts have zero measured intrusion. Fingerprinted composition gate: 95/95 assertions.

Fresh loaded startup took 373.793 seconds under concurrent review load. This is not a performance acceptance. Natural steep slopes outside the finite construction grade are unchanged; this does not assert that arbitrary height differences become walkable.

## Separate P24 defect remains open

The western bank still shows rock slivers after the slope repair. `P24-native` deliberately falsifies any claim that changing the collar alone repairs those triangles. The no-rock diagnostic removes most slivers but leaves small backing-face lines. No P24 acceptance is claimed here.

![Matched game comparisons](P11-game-contacts.png)
![Matched native comparisons](P11-native-contacts.png)
