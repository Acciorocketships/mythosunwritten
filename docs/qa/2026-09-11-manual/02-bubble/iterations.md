# Circular bubble — verification in progress

The actual shader's circular-ring probe fails seven of sixteen angles before
removing the projected-height cutoff. The candidate passes all sixteen. The
camera radius projects to a half-screen-width diameter across 16:9, square and
ultrawide viewports in both Camera3D aspect modes. Nearby upward-facing support
surfaces use physical foot height, a four-metre protected radius with a one-metre
feather, and a local slope allowance. Vertical walls at the same locations remain
eligible for circular fading. The generic projected and world-height cutoffs are
gone; no geometry or collision changes.

The first direct-window capture sequence (`candidate`) begins rendering entirely
black images after a few views, including subsequent before images. A repeat
using the original grass-free snapshot (`no-grass`) renders ten after images
normally, then gives two entirely black captures. These runs are rejected as
visual acceptance evidence. No script/shader errors accompany the black captures.
Adding a small canvas marker produces twelve complete pairs (`marker`), with
visible, non-minimized windows. An explicit SubViewport (`subviewport`) also
produces all twelve complete before/after pairs with no black frames. This
isolates the capture path as a factor but does not yet prove the cause or repair
of the owner's separately reported intermittent black-screen issue.

All twelve explicit-target pairs have been inspected at the recorded cameras and
±8° offsets. Differences trace the enlarged circular region; nearby floor tops
remain visible while foreground vertical faces fade. Only 0–213 pixels outside
the 960-pixel-diameter circle change by more than 20 RGB levels, out of 2,073,600
pixels. Small outside changes include timed scene details. This is locality
evidence, not an exact-zero whole-scene comparison.

The live terrain/grass/biome run and final related tests are pending. No acceptance
is recorded yet. The baseline adapter is frozen in `BubbleBefore.gd` and
`bubble-before.gdshaderinc`; `september11_bubble_qa.tscn` recreates paired views
using `ReviewCam.solve_cam` and saves transforms and world-space radii.

Capture audit: the inherited direct-window `_shot` calls `force_draw()`, waits
only for `process_frame` (before drawing), then reads the viewport. The new
bubble harness now waits for `RenderingServer.frame_post_draw`, as its working
SubViewport path already did. A direct-window repeat is pending. The first live
SubViewport attempt also reparented a loaded world, invoking streaming shutdown
hooks. It was stopped and the harness now creates its capture viewport before
instantiating the live world. Neither correction changes gameplay rendering.

The corrected direct-window sequence (`completed-window`) now returns all 24
complete images, with no wholly black frames. The output is read only after
`frame_post_draw`, without the inherited forced redraw. The direct-window
sequence, explicit-target sequence and canvas-marker control all render the
candidate successfully. Earlier wholly black readbacks are excluded. The user's
original partial black-screen issue still needs its own in-game stress review.

An airborne-ground falsification probe exposed a second issue: the first local
height mask rejected ground sufficiently below the character, allowing it to
fade during a fall. The GPU probe fails at coverage 1.0. Removing only that lower
height bound retains ground beneath the character while still excluding high
roofs and retaining circular wall coverage. All 31 related native tests / 289
assertions now pass with exit 0. The final frozen views are regenerated and the
final live views are pending. The larger bubble's 720-sample orbit measures
4.260 ms camera CPU p95 and 42.595 ms maximum, with no tick interval over 100 ms
and no zero requested input or streaming-frozen samples. These are camera CPU
measurements under a 30 FPS cap, not a whole-game frame-rate claim.

The final live attempt with an unconsumed offscreen texture stalled before its
first capture. A native one-second stack sample shows the main thread spending
its time in `OS::add_frame_delay`, with idle worker threads; this is not a
terrain solve or main-thread deadlock. The capture viewport now has an explicit
TextureRect display consumer in the main window, matching the successful canvas
control. The final live run is retried with readiness milestones in its log.
One launch's automatic approval review timed out; its authorized retry started.

The display consumer alone did not resolve the stall: readiness and world-pause
milestones completed, but no capture followed. The next run explicitly requests
a deferred draw, awaits frame_post_draw and reads that completed frame. It
finishes with exit 0. Ten live pairs are valid and judged, including all four
original reconstructed angles; the final two nearby pairs are wholly black on
both sides and are rejected. All twelve final frozen pairs are valid, including
those two angles. Acceptance is limited to the bubble shape and nearby support
with this evidence; issue 4 still owns the separate corruption investigation.
