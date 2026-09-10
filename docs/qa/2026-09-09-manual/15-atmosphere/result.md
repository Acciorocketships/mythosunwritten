# Biome atmosphere and warm lighting — accepted

Seven continuous profiles now range from brighter Sunwash/Opal through green Lanternwood and pink Cherryveil to blue Moonfen twilight. Their three-second exponential transition retains the sun direction; low mist stays grounded and strongest in wooded/wet biomes. The new owner request supersedes the earlier fixed-global-lighting policy.

Spirit lights keep their existing count with warm 18 m pools. Existing native lanterns gain one 12–18 m, shadow-free, distance-faded light per placement. Native LPFV panes emit through their private atlas swatch; metal, chains and timber retain ordinary shading. The first dark-glass candidate was rejected and corrected using measured pane geometry. No new lantern placement is part of this issue.

Validation:

- 40 tests / 1,379 assertions pass, including frame-independent transitions, fixed shadow direction, actual pane centres under four scaled rotations, and existing field/commit regressions.
- All 14 matched pure-profile comparisons and amplified differences inspected. Sunwash and Opal are measurably brighter; the equal-profile average is darker. Town paths, building silhouettes and the player remain distinguishable in twilight.
- All six native lantern before/after comparisons and differences inspected. Glass is lit, frames stay dark, and warm pools extend smoothly onto the floor.
- Production-streamed Moonfen (95.984% biome weight) has identical grounded player/camera, 168 batches, 853 dressing instances and 268 collision shapes. Both runs complete: startup 210.431 s before / 209.174 s after. The current scene shows blue twilight, grounded haze and warm spirits. Camera evidence and difference are in `stream-verification.json` and `stream-diff`.
- Fourteen 60-frame uncapped samples measure a mean frame-median increase of 0.438 ms, maximum 0.636 ms. This is the measured cost of richer lighting in these views; the Metal GPU-only timer returned zero, so these are frame timings. No generation runs alongside measurement.

`verification.json`, `profile-luminance.json`, `diff/metrics.json`, `lantern-diff/metrics.json`, and `tests.txt` retain numeric evidence. Pure-profile replay uses the older frozen real-world fixture to isolate rendering; it does not revalidate water/construction. It retains three known animation-path errors and teardown warnings, exit 0. The native gallery and current production stream complete cleanly. Unrelated baseline failures remain open.
