# Atmosphere review — September 7

The captures use seed 2697992464 and the real streaming world, including water,
terrain collision, nature, grass and feature reservations.

- `before.png`: former renderer, wide camera at (48, -1500).
- `cherryveil.png`: rebuilt pink grove at (672, 96), close camera.
- `amber-heath.png`: final amber landscape at (-480, -384), close camera.
- `meadow-woodland.png`: spatial colour/atmosphere boundary at (0, -96), wide camera.

These are iteration/review views, not matched before/after comparisons.
The cherry capture is updated to the final shader pass. The boundary capture
precedes the final reduction of mist self-emission and water tint correction.

Validation:

- Combined snapshot with concurrent town changes: 156 / 156 tests passed,
  10,977 assertions, 62.2 s (atmosphere, biomes, dressing, grass, cliffs, mesher,
  and both September 6 settlement regressions).
- Final atmosphere field after adding water-height anchoring: 10 / 10 passed,
  1,162 assertions. This adds one regression to the combined test set.
- Water suite: 111 / 112 initially passed, including all 26 production river
  tests. The sole failure was the old five-entry test-only flora budget; its
  corrected rerun below passes. Total: 112 distinct water tests passing across
  the suite and corrected rerun. The initial run took 588 s under concurrent
  rendering and ended with a native shutdown error after reporting results.
- Historical water context after canonical seven-biome slot sizing: 1 / 1 passed,
  1,370 assertions. Historical trace fixtures now also pin their original height
  input; live contour, skin and swimming assertions are unchanged.

The full repository suite is not a clean acceptance run: the isolated base
contains obsolete village material UIDs and older town tests that conflict with
the current single-town/no-road-rejection construction policy. Those tests are
owned by the ongoing town work; they were not weakened for this change.

The complete Amber Heath capture at (-480, -384) passed after a long
settlement feature solve at chunk (-5, -4). The review waits for all nine chunks.
Some settlement-heavy tour stops therefore still take several minutes to load.

Use F6 in the game for the biome tour, or run
`res://tests/harness/atmosphere_review.tscn` with `--x`, `--z`, `--capture`,
and optionally `--wide`. The harness pins horizontal motion while loading so
river currents cannot move the review to another region.
