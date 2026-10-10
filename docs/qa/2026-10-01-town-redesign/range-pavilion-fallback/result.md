# Range pavilion fallback

The seeded end-pavilion rule previously abandoned a long roof when its preferred
end met a taller neighbour or reserved headroom. It now tries the opposite end
with the same complete roof-fit and gable-abutment checks. The preferred valid
choice, seeded admission, footprint and RNG draws are unchanged. Two blocked
ends still leave the original roof intact.

## Evidence

- Red regression: 7 failed assertions before the correction (`red.log`).
- Range grammar, September 29 roof variety and finished roof clearance:
  **14/14 tests, 7,874 assertions**, 149.126 seconds (`tests.log`).
- All six finished town payloads have zero measured roof intrusions into walking
  air. Gable contacts are a separate diagnostic and remain nonzero; this is not
  a claim of universally clean roof junctions.
- Actual seed 58/large house `kit.spatial.parcel.maze.house.023` changes from a
  six-by-two single range to a hall with a transverse end pavilion. Before/after
  range probes are saved here. Other long ranges remain.
- Native 58/large and 41/large overview/street images saved. Both overviews were
  inspected. The affected silhouette improves, while 41 still has broad lower
  retaining faces and several plain ranges. Street images were generated but
  are not yet separately accepted.

## Limits

No character walk was rerun for this roof-only correction. The finished triangle
clearance suite passed. This is a local generator correction, not final art
acceptance: retaining-wall depth, remaining roof ranges, wider holdout coverage,
streaming/memory and full regression classification remain open. All jobs from
this increment exited; the overall goal remains active.
