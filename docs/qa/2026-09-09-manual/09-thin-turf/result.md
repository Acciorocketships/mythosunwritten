# Photo 9 — enclosed suspended turf

Status: accepted for the photographed lawn edge.

Suspended lawns now have a closed soil bed seated in their actual wooden deck
and a continuous timber retaining border. Their flat grass surface ends inside
that frame. Ordinary grounded gardens retain their native rounded lips. The
original walking surface, rooms, stairs and railings retain identical collision.

Four iterations were rejected before this result: incomplete soil beneath the
native lips, a protruding soil corner, a visually ineffective soil-only repair,
and a timber frame overlapping the old rounded lip. The final 16 related tests
pass with 7,654 assertions in 24.955 seconds, exit 0. Actual native-deck rays,
closed soil boundaries, four orientations, concave/disconnected beds, top-area
coverage and outward timber faces are checked. Before/after collision SHA-256
is identical; the original visual ground hash changes as intended.

All six paired game views and differences were inspected. The clear left and
right views show the thin exposed green edge replaced by a solid timber face,
with clean corners and no floating soil. Their mean absolute RGB differences
are 1.356424 and 1.094599/255; 1.899728% and 1.570075% of pixels respectively
change by more than 20 in a channel. The heatmaps locate the changes at the
lawn perimeter, with small animation/shadow differences elsewhere.

The reconstructed exact camera and both jitter views remain behind a foreground
awning in the merged town. They are retained, not used to claim an unobstructed
match to the old photograph. Before/after camera JSON is identical; the original
full-precision camera cannot be recovered. The final game capture completes
with all nine chunks ready and exit 0. Its 460.875-second cold start remains a
known performance limitation, not evidence of a turf-related speed improvement.
