# P10 — water crossing native cliff lips

Status: **accepted for both photographed dry strips and the tested controls**. The shared water field now carries supplied upper water to the actual cliff crest before descending to existing receiving water. Both coarse and fine fields use the same bounded rule. Terrain and the water material are unchanged.

The first candidate fixed the larger strip but left the smaller one visible. The second fixed most of that strip but rejected five corner samples because a neighboring higher crown contributed to a zero-width approach bound. Both were rejected as complete repairs. The final rule uses the actual crown owner's native surface extrema when the complete approach belongs to that tile. It still rejects intervening ridges, unsupplied banks and empty receiving basins. It never raises the crest above the incoming head.

## Verification

- The original right-hand approach had 134 dry samples out of 180, with up to 4.011 m negative cover. All 180 now stay wet. The twenty left-hand points also pass. The neighboring high bank stays dry. Four orientations, repeated application, ordinary slopes, missing receivers and one-sided corner bounds have explicit controls.
- The detached physics sampler agrees within 0.00001 m at 186 positions through both approaches and descents. This is sampling verification, not a new real-character swimming survey.
- [Water-only comparisons](final-water-diffs/) retain the original world, grass and camera. All three views repair the cut water at both lips. Changed pixels above the comparison threshold occupy 1.786–2.391% of each frame.
- [Complete rebuilt comparisons](final-live-diffs/) also regenerate vegetation against the new wet field. The former dry grass strips disappear. Three matched views retain nearby dry banks and foreground terrain.
- Nine timed pairs use the original reconstructed angle and ±8° at 0, 1.75 and 4.25 seconds. See [photo-angle review](timed-review-0.png), [left](timed-review--8.png) and [right](timed-review-8.png). Both lips remain continuous through ambient animation. Timed differences occupy 2.001–2.617% of full frames. These are shader-time controls; the independent interactive current replay remains the issue-04 evidence.
- Recorded camera transforms, FOV and feet match exactly across all four final capture sets. They reconstruct rounded screenshot overlays, not the unavailable original full-precision camera.

## Older shoreline control

The broader run passed 57/59 tests but exposed two outdated expectations at September 10 photo 16: the newly supported outlet is wet throughout the test's former inland shoreline. The field probe confirms a 16 m upper crown, supplied water upstream, a real 8 m lower bank and existing 13.7 m receiving water. The neighboring 20 m crown remains dry.

The original free-shore **inputs** are retained as a primitive fixture. All existing shoreline-count, entry-depth and continuity thresholds remain unchanged and run through current interpolation. A new production-field test checks 4,503 points through the full outlet and preserves the high dry bank. All nine shoreline tests / 375 assertions pass. Combined with the 51 unchanged passing tests from the broader run, the final coverage is **60 distinct tests / 3,847 assertions**. This is a combined result from the broad run and the focused rerun, not a claim that the earlier broad invocation exited green. See [broad log](broad-review.log), [focused shoreline log](shore-controls.log) and [fixture explanation](../../../../tests/fixtures/september15/water-drops/README.md).

The older native-geometry diagnostic additionally shows the connected outlet and unchanged higher crown. It uses isolated terrain and an explicitly opaque diagnostic water material. It is not a recreation of the original complete environment, and its finite chunk boundary is not a natural shoreline. Close controls obscured by the higher wall are excluded from visual acceptance.

## Limits

The full production rebuild took 154.549 seconds while other checks were running; this is not a performance benchmark. Cold loading remains open. Parse-invalid harness attempts and the empty test-filter invocation are excluded. Native asset UID fallback warnings resolve by path; the snapshot helper's unsupported runtime global-list diagnostic remains documented. Neither is treated as evidence of a visual pass.

These results close P10's reported premature dry strips. Broader water topology, the older remaining water reports, and the cliff dressing/architecture/path queue retain their separate status.
