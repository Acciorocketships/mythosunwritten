# Roofless protruding cells

The blue-circled room's unused front half was removed by the issue-5 composition
repair. This separate review verifies that its remaining slab is necessary:
every floor column has an actual room below and an upper house above. Twenty-five
native triangle probes verify complete closure of the smaller room's ceiling.
The town has zero roofless modular houses and zero unclaimed platform caps.

[Original / current / pixel difference](live-detail.jpg) and
[reconstructed village views](native-0.jpg) show the removed projection.
All sixteen freshly regenerated native pairs and twelve live before/current
pairs were judged, including nearby and reverse views. The live images come
from the original issue-5 baseline and the latest issue-6 replay, with identical
camera records. The circled crop's mean absolute RGB difference is 19.523/255;
37.045% of its pixels change by more than 20/255. The differences also include
accepted issue-6 detail elsewhere; they are not evidence of a new geometry patch.

The new independent regression fails eight assertions on the recorded original
block and passes against the current room. The final three-file run passes all six tests / 157 assertions, including both
new tests, room projection and architectural variety. The unchanged generator uses the issue-6 48-town
matrix and physical clearance evidence; it is not swept again merely for this
additional verification. Existing composition timing failures remain recorded
in the preceding report. No additional production mutation is needed for this
reported defect. Skywalk use and connectivity remain the next separate issue.

See [iterations and ownership](iterations.md), [native unit export](ownership.json)
and [provenance](provenance.json). Original screenshot camera precision remains
limited by the overlay's 0.1 m rounding; the before/current replay transforms
match exactly.
