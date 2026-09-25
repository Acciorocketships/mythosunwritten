# P14 floating lawn — accepted September 14

The full grass/stone/timber bed is removed by a shared support rule. The three complete native houses retain their placements and geometry. Two ordinary native guard sections close the newly exposed landing edge. The separate request to improve the purpose of this upper stair deck remains issue 14.

## Reproduction and cause

World seed 2697992464, town seed 2695877283924445960, supercell (1,0), compact town. F3 feet (1233.9,24,521.1), crosshair (1225.9,24,541), reconstructed with ReviewCam. `current-source.txt` freezes the original source; `probe-before.json` and `support.json` record ownership.

Eight retained cells at x=0..1, y=3, z=0..3 crossed public air. One end met retained stone, but the other stopped at a prefab's conservative occupied box. That box does not guarantee an actual wall along its boundary. The original check also admitted PRIVATE_VOLUME reservations without built material. Neither is sufficient evidence of a complete earth-crown jamb.

`WarrenSpatialFabricCompiler` now checks tunnel crowns against ordinary built solid cells, excluding the prefab occupied-box layer. Real retained stone and plinth jambs remain eligible. PRIVATE_VOLUME alone no longer supplies a jamb. Prefab foundations and their ground connectivity retain their existing support contracts.

## Red-first and physical evidence

- Original code fails both new tests, with 20 failed assertions: all eight stone/turf cells and four rotated reservation-only jamb cases. Real opposing-jamb controls pass.
- Final six tests / 92 assertions pass across the new photo regression, retained-earth controls and native-only settlement tests.
- Photo clearance is identical: 76 walking positions / 108 crossings.
- Mandatory corpus seals 48/48 towns, 11,868 clear positions / 17,035 clear crossings; no blocked centres, crossings, splits or unreachable cells. The existing 25 conservative off-centre pillar contacts remain, with zero reported intrusion.
- Composition gate passes 95/95 assertions.
- Payload changes: 275 to 252 native placements, 250 unchanged, 25 removed and two guards added; no retained placement changes. Removed pieces all belong to the rejected bed, its joints, underside or furnishings.

## Visual falsification

Twelve pairs were inspected at full capture resolution: three native photo views (0, ±8 degrees), six native surrounding views (0, ±30, ±90,180), and three fixed-lighting game views (0, ±8). All show the complete bed gone and neighboring houses, paths, stairs and roofs retained. The side and rear views show no remaining timber or floating garden props. The new guard follows the landing edge. See `visual-review.json` and `differences/` for per-pair dispositions and pixel differences.

The first six `native-wide` views cropped the bed and are excluded; `native-orbit` uses the bed's construction centre and the F3-derived direction. Frozen game before/after camera records match exactly. Fresh generated snapshots took 305.765 s before and 308.340 s after under varying load; these are not a performance comparison. Snapshot capture retains its existing editor-API warning, and lighting reparenting emits owner warnings in both frozen runs. Captures are valid and nonblack. No full-suite, global streaming or renderer acceptance is claimed.
