# Photo 10: open roof end

Accepted. The flush-end bake clipped off the native plaster gable at +/-1.5 m;
the authored gable lies just beyond that plane. Eight end/color/width variants
now fit their complete native section longitudinally into the same short
interval. The inner seam, full height, transverse geometry and UVs survive.
No runtime patch or construction retry is added.

All 72 actual gable triangle samples fail before and pass after. The final two
targeted tests pass with 55,048 assertions; the related roof suite passes 25
tests / 55,200 assertions. Both exit 0. All 132 walk cells and 188 crossings
retain identical central clearance.

The exact and five nearby/jitter/gameplay comparisons were inspected, including
amplified pixel differences. Every visible gable opening is closed by its native
plaster and timber, with the roof and wall joins intact. Mean absolute RGB
difference is 1.9333; 2.7655% of pixels change by >20 in a channel. Small orb and
avatar differences occur outside the roof. Camera JSON is identical; rounded
source overlays cannot recover full original precision. Both graphical runs
finish ready=true, exit 0, after 455.065 / 457.397 seconds loading.

`roof-verification.json`, `roof-tests.txt`, `roof-related-tests.txt`,
`roof-physical-verification.json`, and `roof-iteration-notes.md` record evidence.
Photo 13's wall seam remains the next separate review within issue 11.
