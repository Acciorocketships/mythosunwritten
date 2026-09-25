# Water review — accepted for the reported sites

Photos 15, 18 and 19 exposed real water-surface discontinuities, rather than a material defect. Overlapping river reaches supplied different fixed heads over the same connected excavation. The coarse surface and fine shoreline restoration now reconcile those connected heads downward at a maximum 0.30 grade, retaining the existing bed floor, dry barriers and enclosed lakes.

Photo 16 had an additional shoreline defect. Dry corners on different terrain bands interpolated a virtual plane above the actual grass ledge. The field now removes that excess height continuously across the shore cell. Fine interpolation receives the same physical bound, so it cannot introduce a second shore plane at a refinement boundary. Existing fine water anchors contribute to that support; a coarse dry edge cannot drain a real lower channel. The water mesh and material need no workaround.

## Verification

- The original three flat-bed probes had 6.156–8.5 m rises over 3 m. The repaired probes retain water on both sides and limit the rise to 0.9 m.
- A 73,322-point ledge survey checks both directions at 1 cm intervals. The continuous correction has 60 dry/wet crossings, a maximum entry depth of 0.053971 m, and a maximum neighboring wet-height change of 0.005733 m. The pre-shoreline source entered as high as 2.929 m above ground. Intermediate candidates introduced 1.204 m and 0.424 m steps and were rejected.
- The actual emitted rim's unpaired edges meet ground or connected water at the photographed ledge. This tests the geometry rather than an arbitrary allowed contour height.
- The final 6,724-point census changes no terrain and floods no new sample. One upper-bank sample at (684,-1725) becomes dry; the lower fine channel at (879,-1815) retains its 1.2 m head.
- Both neighboring chunk interfaces agree exactly at all 385 sampled points each.
- The final related run has 93 tests: 85 pass, and the eight historical failures retain all 12 identical failure assertions (24,605/24,617 assertions, 438.711 s). All nine new tests pass. Existing old-chute and pond assertions remain unchanged.
- All four real-character traversals pass: 23.327 m downstream, 24.069 m upstream, 23.250 m along the channel and 23.485 m beside the ledge, with zero frozen ticks. These are four measured routes, not universal water traversal acceptance.
- All 24 matched before/after views and amplified pixel differences were inspected. The four recorded source/camera JSONs match exactly. Photo 15's flat-water cliffs become continuous descents; photo 16's suspended sheet closes at the grass ledge; photo 18 loses the folded vertical water boundary while retaining the actual raised bank; photo 19's foreground folds disappear.

Initial loading remains expensive: the final graphical replay takes 405.216 s and the headless walk 398.214 s before movement. These runs shared the machine with validation work, so they are not isolated performance benchmarks. Terrain loading is the next separate investigation.

## Evidence and limits

The baseline and final cameras use the same `ReviewCam` reconstruction of the rounded player/crosshair overlays, the original 8 m / 5 m orbit and 75-degree FOV. They do not recover the original full-precision camera. Each photograph has its reconstructed view, left/right views, two small camera/position variations and the collision-resolved gameplay view.

`investigation.md` records the alternatives and rejected candidates. Numeric field and dense-shore scans are retained with the harnesses. Bulk game PNGs are local QA artifacts. Historical contour and skin failures are compared assertion by assertion; this review does not claim a globally green water suite or resolve terrain loading performance.

## Pixel judgment

`candidate14/` contains the accepted 24 images and four-route trace; `before/` contains the baseline. `after-diff/` holds each matched crop and a four-times-amplified difference, plus a six-view sheet for each photo. The exact-view ROI mean absolute RGB differences are 6.616, 7.783, 5.427 and 6.858 for photos 15, 16, 18 and 19. Differences concentrate on the removed cliffs, sheet and folded edge; water shading, animated light and the character add incidental pixel changes. These metrics locate changes; the matched views, field checks and actual mesh/character evidence establish acceptance.
