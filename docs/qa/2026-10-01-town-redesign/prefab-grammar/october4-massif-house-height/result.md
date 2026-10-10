# Massif-bound house-height experiment, October 4

**Rejected candidate. Production height behavior restored.** The retained change is an enclosure diagnostic improvement; the broad architectural task remains open.

## Finding and trial

63/grand's conspicuous house.010 and house.015 each had five native storeys above the citadel. Their floorplates already alternate, but the resulting facade still reads as a tall shaft. The initial massif beneath them ends at bands 10–12 above bearing band 4, while the later optional house-height roll allows walls up to band 14. The saved `before-tall-masses.json` identifies their actual footprints and field values.

The experiment clamped optional rolled storeys to the minimum massif top under the lot, while allowing existing upper streets and carried rooms to override the optional roll. The candidate reduced the conspicuous stacks in the native render. Its 32-plan sweep built, eight finished-town probes had no floating or roof/public-air failures, and the 63/grand character climbed/descended the gate. The candidate tests passed, including explicit required-street/room support tests. Those checks did not establish architectural acceptance.

## Why rejected

Compared with the exact old height rule, several finished towns lost overhead room coverage. The unchanged bridge-cell count was insufficient evidence: bridges and low room ceilings are different features. Seeds 31, 53 and 7 lost respectively four, eight and four quarter-cell ceilings only **two bands above the path**. This directly conflicts with the requested enclosure and overhead rooms. The narrower height fix cannot be shipped as a solution to apartment-like buildings.

63's three lost fully covered cells had ceilings eight to eleven bands above the path, not low tunnels. The initial aggregate coverage count conflated these cases. The review harness now records `ceiling_band_histogram` and `full_cover_max_ceiling_band_histogram`, distinguishing ceiling distances without silently treating every overhead room as equally useful enclosure.

## Evidence and next action

- `comparison.json`: all eight before/trial coverage comparisons and exact lost ceiling-distance distributions.
- `rejected-candidate.patch` and `rejected-candidate-tests.gd.txt`: the discarded implementation and tests; neither is active production/test code.
- `before-*` / `after-*`: native 63/grand reference/trial images. The earlier reference also predates the small public-masonry correction, so this is a skyline comparison, not a claim that every changed pixel comes from height.
- `after-finished.json` and `candidate-player-walks.json` describe the rejected trial, not the restored current code.
- The production rule was restored, and a fresh 63/grand probe verifies restoration and the new histogram fields.

Next structural work must track and preserve overhead room cells during silhouette changes, or co-plan lower tunnel coverage before changing the height distribution. Simply capping tall parcels is insufficient. No claim is made that the tall-facade requirement is complete.
