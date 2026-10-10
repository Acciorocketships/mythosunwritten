# Inhabited support for tunnel rooms

Implementation retained after focused tests, a 16-town survey and native art review.
This is a bounded enclosure improvement; the full redesign remains open.

Room composition now treats the occupied columns supporting an admitted tunnel
cover as required contacts. Merge, handoff, variation, crown termination and
metadata-copy paths carry that requirement, while wider/varied rooms may still
satisfy it. It constrains only source-proposed rooms, not empty stone mass.

A lower house whose existing flat roof meets the crown also retains that roof
course as bearing, as an existing stacked parent already does. The final crown,
complete jamb and host-storey proof remains unchanged. This is not the previously
rejected recovery of uninhabited stone piers.

101/large exposes the cause and repair. Its middle storey was handed to a shifted
neighbour, losing half a planned jamb; the opposite low-house flat roof was not
retained early. Together the two constraints produce the actual room over
(-1,4,2), with four covered quarters. Two other partially covered walk cells lose
their overhangs, so aggregate covered quarters remain 24. The source tunnel count
and public path are unchanged. No claim of aggregate coverage growth.

Focused bearing/floor-alignment tests pass 5/5, 72 assertions. Composition
diagnostics and skywalk bearing pass 7/7, 33 assertions. Actual player traverses
the recovered passage both ways, 2/2. Matched 101 before/after close and overhead native renders inspected: the new
room occupies the gap above the lane with continuous inhabited sides and trim.
83/grand native close and overview also inspected; its new overhead room covers
a destination approach. Wider town art acceptance remains open.

## Corpus and limits

All 16 representative/holdout towns build. Every town has zero floating masses
and zero public-air roof intrusions. Fully covered macro cells increase 186 ->
188; covered fine quarters 798 -> 802. All 36 supported bridge cells, 197 source
tunnel cells and 1306 public cells remain. Only 101/large and 83/grand change
coverage; the latter gains four covered quarters without losses. The holdout
baseline is the previous cover-chain survey, which admitted no chained covers
in those eight towns, so it has the prior production geometry.

No seed or coordinate is used by the production rule. Tests pin the reported
101 case, but the contacts derive from admitted PLOT_OVER jambs and proposed
room cells; the flat-roof course derives from the adjacent house's measured
source roof-band span. Missing supports are still rejected. Empty stone piers
are not introduced, and no public floor/headroom is consumed.

Still open: most routes remain unenclosed, and the broader building vocabulary,
facade depth, roofs, greens, and full art/performance acceptance need more work.

Holdout actual-player approach: 83/grand reaches the covered destination and
returns to the town entry, 2/2 passing. Initial through-route probe was inapplicable
because the destination has one level graph edge; the successful probe follows
its published approach including elevation changes.

Final real-terrain production integration passes: 1 test / 125 assertions.
Combined focused/composition/skywalk/terrain verification: 13 tests / 230
assertions. This is correctness evidence, not performance acceptance.
