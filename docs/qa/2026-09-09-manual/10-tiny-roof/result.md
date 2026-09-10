# Photo 14: covered interior crown

Accepted for the photographed town. The small gable occupied two unused bands
below a complete existing public floor. The house now uses those reserved bands
as one upper storey, whose ceiling is owned by that public floor. All 37 existing
rooms retain their cells; only `house.000.part01.room00` is added (eight private
cells). No public surface moves.

The complete ceiling must exist in every exact projected floor cell. Coarse
source markers proved insufficient in a broader regression and were rejected.
Parcel sealing, storey count, identity and roof-band ownership share this fact.
Partial, staggered and open-sky cases keep their ordinary crown reservation.

All six matched before/after views and amplified pixel differences were inspected.
The replacement facade meets the upper deck and adjacent retaining structure;
the tiny gable and recess are gone. The neighboring open roof end is a separate
issue and remains for photo 10. Exact-view mean absolute RGB difference is
9.7152, with 13.257% of pixels changing by more than 20 in a channel. Camera JSON
is identical between runs. Original rounded overlays cannot recover full camera
precision; minor avatar/shadow differences are outside the changed facade.

The related suite passes 21 tests / 110 assertions in 112.28 seconds, exit 0.
Godot reports resource/RID/ObjectDB teardown leaks after the totals, retained in
`tests.txt`. The independent physical census is identical: 132 walk cells and
188 crossings, all clear on their center lines. The targeted regression fails
before and passes after; rotated partial-ceiling negatives pass.

Both graphical runs finish ready=true, exit 0 (458.447 / 462.376 seconds startup).
These render-loading times do not establish broader cold-start performance.
See `verification.json`, `physical-verification.json`, `room-delta.json`,
`iteration-notes.md`, and the six files in each of `before`, `after`, and `diff`.
