# Architectural variety

The photographed town gains a supported projecting bay, two native wraparound
corner balconies, and another dormered roof. Its original straight balcony and
all 28 source rooms remain. Bay opportunities now follow eligible upper-room
lineages; private corner decks require two real bearing walls and clear public
space. Dormer requests survive compatible compact roof selection while retaining
native roof seams and measured conflict checks.

[Live comparison](live-diff/03_block_0_comparison.png),
[corner and underside comparison](details/close-contact.jpg), and
[reverse comparisons](native-reverse--90.jpg) show the changes and pixel diffs.
Twelve live pairs, sixteen native pairs and eight unobscured detail pairs pass
visual judgment. Two other detail pairs are explicitly excluded for occlusion.
See [image audit](image-audit.md) and [rejected candidates](iterations.md).

Three new tests pass 116 assertions, including twenty actual native knee
contacts, four-orientation placement and preserved roof stock. The related run
initially passed 52/54 tests; the two stale assumptions were corrected and both
files pass all 16 tests / 1,669 assertions in the follow-up. No production change
was made to accommodate those assertions. The photo town retains identical
clearance at 88 positions and 124 crossings.

The mandatory full sweep constructs 48/48 towns and retains 11,112 clear public
positions and 15,923 clear crossings. The existing 27 off-centre pillar contacts
remain without blocked centres or crossings. Whole-town source composition and
skywalk connectivity are the separate following issues. This is acceptance of
the visible variety and construction changes, not a claim that every broader
terrain or performance test is green.

The composition gate is **93/95 assertions on both runs**, with timing failures
only. First run: 9/compact 5,856 ms vs 3,653 and 3/standard 11,509 vs 8,218;
calibration was 1.015x. Repeat: 3/standard 18,065 vs 16,200 and 9/standard
13,247 vs 9,800; calibration was an invalid 3.96x, capped at 2x. The first run
cannot be dismissed as an invalid calibration. Its 3/standard stage attributes
8,084 ms to room partitioning and 962 ms to features. Earlier baseline records
also exceed timing limits, but these measurements do not isolate code cost
from host variability or establish performance equivalence. Timing remains
unresolved; no pin is changed and this gate is not reported green.
