# Control iterations

The first three native role tests fail seven of thirteen assertions before the
change. The candidate passes all three. Expanded checks compare the complete
original reference camera trajectory at 30/60/120 Hz and test focus/pause/click
capture lifecycle, above-horizon facing and physical boom collision in four
orientations. The 22-test native run passes 160 assertions with a clean exit.

The first native village close-mouse image puts the crosshair on the avatar's
face. Reject that framing: raise the focus point to 3.2 m, above the mage hat,
while preserving the original unobstructed eye at 8 m horizontally / 5 m high.
The boom/pitch are derived from that framing; real low ceilings still constrain
the pivot. The harness now also poses the otherwise frozen avatar toward the
close-view aim, matching production facing. Final images and tests are pending.

All sixteen initial final-folder image pairs rendered, with no wholly black
frames. The saved-basis audit nevertheless rejects its four `close_mouse`
comparisons: yaw remained constant because native focus/capture was absent
when those scenarios began. Framing differences are not mouse-response proof.
The corrected harness focuses the native window immediately before F7 and
asserts capture ownership, then requires actual yaw and pitch movement after
replaying mouse events. The first corrected photographed pin passes both
assertions and its rendered scene visibly turns. Other pins are rerunning.

The combined eight-suite native run passes its camera and material tests, then
waits indefinitely for a GPU projection frame. It was stopped without claiming
a complete pass; the short final camera suites are rerun separately. The
previous issue-2 native GPU tests remain recorded, and no bubble implementation
changed during issue 3.

Final acceptance: sixteen valid, judged pairs in `accepted`, with source hashes
and explicit exclusion of the earlier ineffective mouse replays. Four synthetic
handler replays turn right 8.959 degrees / up 4.480 degrees; photo 04 also has a
successful native-capture integration replay. The final focused run passes
24 tests / 166 assertions and exits cleanly. Both enclosed close views retain
their real wall obstruction; no through-wall visibility improvement is claimed.
