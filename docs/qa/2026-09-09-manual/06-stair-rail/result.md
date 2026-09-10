# Photo 6 — native landing / stair rail attachment

Status: accepted for the reported attachment.

The before render reproduces the floating top rail. The existing fix for free
stair ends did not cover a flight attached to a shorter authored landing fence.
The two beam ends now enter that fence's measured post profile before blending
to the normal guard height down the flight. The existing post remains the sole
owner of the attachment. No tread, landing, or walking width is changed.

See [iteration notes](iteration-notes.md) for the measured geometry, alternatives,
and the native-triangle test. Matching cameras are reconstructed from rounded
player/crosshair coordinates; the original full-precision camera is unavailable.

All 18 related tests pass with 1,507 assertions (68.88 s, exit 0). Six real
streamed traversals pass: ascent/descent at the centre and both side lanes.
All 124 town walk cells and 179 crossings retain identical clearance.

The exact reconstruction, both nearby angles, both jitter samples and the
production camera view were inspected with their pixel differences. The free
rail end is gone, both rails meet the native post, and the adjacent fence and
treads remain intact. Exact-view mean absolute RGB difference is 1.64224/255;
2.30498% of pixels change by more than 20 in any channel. The walking harness
changes the avatar's facing direction; its silhouette/shadow and small ambient
animation differences are not attributed to the repair. See the attachment
crop for the unobstructed joint. Source hashes record one production file
changed for this issue, `WarrenTransitionSurfaceBuilder.gd`.
