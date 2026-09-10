# Photo 13: doorway return seam

Accepted. The perpendicular panel already ended at the door's measured back,
but clipping left its thickness open. Baker version 32 closes nonzero return
cuts with their declared native timber stock before floor-cap subtraction.
The room, window relief, UVs and doorway boundary stay fixed. Both native and
floor-owned-cap variants receive the same finishing.

The exact and five nearby/jitter/gameplay views and amplified differences were
inspected. The open vertical strip is now continuous timber, without exposing
the house or changing the window and door. Exact-view mean absolute RGB
difference is 0.6657, with 0.7382% of pixels changing by >20 in a channel. Small
avatar/time differences remain outside the wall. Camera JSON matches byte for
byte; rounded source overlays cannot establish full original camera precision.
Both renders finish ready=true, exit 0 (459.707 / 462.659 seconds startup).

All 15 photographed cut-face samples fail before and pass after. The related
14-test suite passes 661 assertions. The final three targeted tests pass 1,131
assertions, including both hands/floor-cap variants in four orientations and
actual vertex containment for all 674 rebaked variants. The physical census
is identical: 132 walk cells / 188 crossings, all central-clear.

The first broad containment check used stored source AABBs and was rejected:
decoded native vertices exceed that metadata by tens of micrometres. Using
actual native vertices as the reference passes without widening the original
one-micrometre geometry tolerance. The 10.014-micrometre changes in stored
planar mesh boxes do not represent escaping geometry. See the iteration notes,
final targeted/related logs, bake census and physical/visual verification JSON.
