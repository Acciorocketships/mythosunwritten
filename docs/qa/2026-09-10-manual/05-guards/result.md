# Platform guards — accepted

The four missing railing sections in photo 5 now close the complete exposed
platform edge. Roof reservation cells still reserve construction clearance,
but they no longer masquerade as full vertical walls when deriving guards.
Room mass, retained masonry, real wall panels and named public openings retain
their existing guard ownership. No roof or platform moves.

The smallest frozen regression failed on all four absent segments before the
change (`red.txt`). It now passes alongside sixteen physical probes through
the baked railing collision in four orientations. The final focused run passes
30 tests / 1,076 assertions with a clean exit (`focused-green.txt`). Both earlier
photographed wall towns and the existing stair attachments retain their checks.
The complete photographed town's 112 walking cells and 164 crossings have
identical physical clearance (`clearance-after.json` versus the bench result).

Six matched reconstructed-camera pairs in `before/` and `final/`, with identical
camera records, were judged with their differences in `diff/` and `judging.png`.
All four railing sections are visible and join the platform's existing side
rails. The native posts stand on the deck and the tiles stay behind the guard.
The nearby views expose no detached endpoints or displaced roof. The exact
region changes by 2.694/255 mean RGB, with 7.028% changing over twenty levels;
the difference follows the new rails and their shadows. This accepts the
reported platform and measured physical cases, not every town in every seed.

See `investigation.md` for the rejected first candidate. Its `after/` images
are not the accepted result; the shared roof-role correction is in `final/`.
