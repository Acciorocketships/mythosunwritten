# Entrance overhang — accepted

The photo 10 facade bay extended an already projecting upper room and introduced
a second, laterally offset shell. Optional bays now require the complete lower
edge of their parent wall to have an immediate bearing. Roof-only reservations
cannot supply that bearing. The parent room retains its footprint and support;
the additional occupied projection and its offset joint are removed.

Shortening the native bay or adding more supports would preserve the unwanted
two-stage silhouette. The feature selector now rejects the compounded overhang
before reserving construction. Other eligible faces retain complete native bays.

Twenty focused tests pass 700 assertions. The photographed invariant fails before
and passes after; four orientations cover complete, partial, absent and roof-only
bearing. An older three-bay census required two bays on unborne faces, proven by
an isolated pre-change solver. Its updated test retains a real bay and its native
geometry/material checks. See `legacy-bays.txt` and `investigation.md`.

Six matched game pairs and five native pairs, including ±30-degree views, were
visually inspected along with their pixel differences. The added shell disappears,
the parent's complete wall becomes visible, and the original entrance remains
clear. Camera metadata is identical. The reconstructed photo's mean difference
is 2.166/255 over the image and 9.453/255 in the marked region; 20.725% of region
pixels differ by more than 20. Differences outside the building include incidental
orb/character motion and changed shadowing, not additional evidence of repair.

All 112 walking cells and 164 crossings have identical physical clearance in
`clearance-before.json` and `clearance-after.json`. Nearby roof, wall-return and
skywalk regressions pass. Acceptance covers this reported construction and the
focused checks, not the full generation corpus. Camera pins are rounded player
and crosshair coordinates, so these are matched reconstructions rather than
provably exact recovered original poses.

Evidence: `before`, `after`, `diff`, `native-before`, `native-after`, `native-diff`,
`focused-tests.txt`, `red.txt`, `rotation-tests.txt`, `validation.json`.
