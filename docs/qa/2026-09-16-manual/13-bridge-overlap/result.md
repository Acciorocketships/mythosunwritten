# Neighboring bridge footprints

The P04 doorway review exposed two open bridges placed inside the side walls of neighboring enclosed galleries. Acceptance reserved walking cells, but an enclosed one-lane crossing still emits a two-cell-wide native room. The final revision reserves that full width and vertical extent before accepting another span.

The photographed town keeps its four non-overlapping crossings and original enclosed-gallery alignment. Two redundant, obstructed side bridges withdraw (six native deck/rail instances). One public end guard returns where the withdrawn lane would otherwise advertise an unsafe exit. All other native instances, 101 generated meshes and the explicit generated collision boxes remain identical. Native asset collision follows the instance delta. See [payload comparison](payload-comparison.json).

## Rejected candidate

A candidate preferred paired wide galleries. It passed the collision invariant but moved the gallery centreline and produced poor facade joins in the matched native render. It was rejected; its renders and partial corpus log are in `rejected-paired/`. The final candidate preserves the original correctly aligned galleries.

## Evidence

- [Red test](red.log): two accepted routes cross another bridge's actual generated wall barrier. [Final focused run](green-final.log): three tests / 40 assertions pass, including doorway guard controls.
- [Native clearance](clearance-final.log): the same 312 public stances and 444 adjacent crossings retain identical results. All six repaired doorway sweeps remain clear. The withdrawn neighboring lane remains closed, now deliberately guarded.
- Eight longer flat casts through retained bridge endpoints encounter the same pre-existing obstructions before and after (fractions 0.0625 or 0.73046875). These are regression controls, not full character traversal acceptance. Stepping/traversal across the complete crossings remains to be assessed.
- Six isolated native pairs at P04/P15 and ±8° retain the photographed gallery, door and stair. The P04 side alley now ends in a guard instead of continuing into a bridge wall.
- The final [game replay](../14-rail-fragments/game/after/P04/P04_8.png) also includes the subsequent orphan-post repair. It replays exact native instance and generated-mesh differences in the frozen complete game; it does not regenerate terrain or collision.
- The combined final [48-town sweep](../14-rail-fragments/corpus.log) seals 48/48, with 11,772 clear centres and 16,915 clear route crossings. Twenty-five conservative offset pillar candidates remain, with zero measured centre/gate blocks and zero measured intrusion. The fingerprinted [composition gate](../14-rail-fragments/corpus-gate.log) passes 95 assertions.

Before and after at P04:

![Before](native/before/P04_8.png)

![After](native/after/P04_8.png)

No new startup, streaming or full-suite acceptance. Native logs retain three known material UID fallbacks; headless logs retain the known macOS certificate lookup error. Neither prevents the recorded checks from completing.

Source SHA-256:

- `scripts/terrain/features/villages/fabric/SettlementFabricAssembler.gd`: `765cca3dc49476968162625bba84e4f76f1641a84caf371aa24bcc3fbae1e259`
- `tests/test_september17_bridge_overlap.gd`: `e9d14d5beebe6c6090a3ea142d46620c0d28c7160438ba62d0577b10bbe9efac`
