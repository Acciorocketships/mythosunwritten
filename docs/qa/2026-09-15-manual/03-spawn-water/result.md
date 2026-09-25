# Spawn water cutoff repaired

P11's floating rectangular water sheet is removed. The spawn is continuous
dry grass in the reconstructed original view, both ±8° views, and six wider
orbit views. This is a shared hydraulic rule, with no coordinate exception.

## Cause and change

A distant source initially flooded this basin at 31 m. Spill containment then
lowered it to 7.9499998 m, below the 8 m sill that had supplied it. The field
kept all 12,561 disconnected wet samples despite their having no surviving
source. Different source inventories therefore produced a wet sheet in three
chunks and dry ground in the fourth.

Actual river/pond seed indices now survive as provenance through the initial
fill. After containment, one finite graph traversal retains only wet components
containing surviving seeds. Dry banks and propagated flood labels cannot supply
water. Fine topology rescue follows this step, so genuine narrow passages can
resupply pockets from retained water. Terrain, source placement, river profiles,
water materials and world coordinates are unchanged.

The earlier domain-boundary hypothesis was incomplete: the smaller domain was
already dry before containment. Merely enlarging a rectangle until its edge
was dry would not fix this case. See [investigation](investigation.md).

## Evidence

- Original ownership regression: five failed comparisons, 20/25 assertions.
  Three new source-connectivity invariants also fail on original behavior.
- Final related run: **51/51 tests, 3,629 assertions**. This includes 81 spawn
  positions through all four chunk owners, independent ponds, dried sources,
  fine-passage recovery, physical spill containment, existing chunk borders,
  river continuity, the prior corner and shallow-turf repairs, path queries,
  frozen samplers and swim/wade classification.
- Three fresh game pairs have identical saved camera records. The absolute
  RGB differences change 37.29–40.57% of pixels above the comparison threshold,
  covering the removed water and restored dry-land dressing. The original
  foreground remains, with small ambient/grass differences between fresh runs.
  [Original-angle comparison](differences/P11_0-comparison.png).
- Six saved-world orbit pairs at 0°, ±30°, ±90° and 180° expose all sides of
  the former sheet. Each is visually inspected; none retains the cutoff or
  substitutes another water plane. [Side review](side-review.png).

The camera is reconstructed from rounded F3 coordinates, not claimed to be
the original unrounded transform. Pixel differences locate changes; the
source-connectivity tests and visual inspection establish the repair.

Fresh startup measured 322.649 s before and 304.776 s after, with other review
work running on the host. These are not controlled performance measurements.
No general startup speedup, whole-water acceptance or universal source-domain
independence is claimed. Motion range, cliff-drop flow, mountain water placement
and the remaining issue list continue separately.
