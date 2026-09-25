# Larger circular visibility bubble

Status: accepted for the reported bubble shape and nearby ground protection.
Twelve frozen pairs and ten valid live pairs pass visual review, including all
four reconstructed photo angles. Two invalid live nearby captures are excluded.

The tactical camera now derives the bubble radius from a diameter of 50% of the
viewport width. Both horizontal cutoff masks are removed. Instead, upward-facing
surfaces near the physical character floor remain opaque within four metres,
with a one-metre feather and allowance for sloping ground. Vertical walls still
fade through the complete circle. Ground below a jumping/falling character stays
protected. No collision or authored geometry changes.

## Iteration and falsification

The original shader failed seven of sixteen rendered circle-ring directions.
Removing the global/projected height masks passes all sixteen. A first local
support mask incorrectly faded lower ground during a fall; the actual GPU probe
failed at full coverage. Removing its lower height bound repairs that case.
Flat, rising and descending nearby support, vertical wall, elevated obstruction,
near-camera exclusion and both camera aspect modes are covered by the final
31 native tests / 289 assertions, with clean exit 0 (`tests.txt`).

## Matched images and pixel differences

`final/before`, `final/after` and `final/diff` contain twelve pairs: all four
photographed pins and ±8-degree alternatives. All twelve final triptychs were
visually judged. The former small notch becomes a broad circular reveal. Wall
faces below the character fade without a horizontal screen cutoff; the nearby
lawn and wooden floor tops stay present. Open views change much less because
there are fewer foreground obstructions.

`final/circle-metrics.json` measures full-image mean absolute RGB differences
of 0.460–10.264 levels (0–255), with 0.988–18.303% of pixels changing by more
than 20 in any channel. Only 0–209 pixels outside the 960-pixel-diameter circle
(with a two-pixel raster tolerance) exceed that threshold, out of 2,073,600.
These small outside differences include timed details; exact pixel identity
outside the bubble is not claimed. Difference magnitude alone is not acceptance:
the circular shape and intact support surfaces were inspected separately.

The source overlays round player/crosshair positions to 0.1 metres. Replays use
identical reconstructed transforms within each pair; the original full-precision
camera cannot be recovered. Frozen snapshots retain native scene geometry but
lack live biome services, so their ground tint differs from the manual photos.
The ten valid final live comparisons in `final-live-draw` restore the live
biome tint and include grass. All were visually judged: the wide circular reveal
and nearby support preservation agree with the frozen comparisons. Their mean
RGB differences span 0.486–9.467 levels; changed fractions span 0.970–18.181%.
Only 1–213 outside-circle pixels exceed 20 levels. Exclude `01_black_-8` and
`01_black_8`: both sides of these pairs are entirely black readbacks, so their
zero difference is invalid evidence. The original `01_black_0` angle is valid.
Both excluded nearby angles also have valid final frozen pairs.

## Runtime check

The final larger bubble's 720-tick held-forward orbit travels 79.267 metres,
with zero streaming-frozen samples and zero missing requested input. Its 114
stopped samples retain actual collision contacts. Camera CPU median is 2.145 ms,
p95 4.260 ms and maximum 42.595 ms (initial selection). No tick interval exceeds
100 ms. The run is capped at 30 FPS; this is not a whole-game FPS claim.
Numeric evidence is in `performance`.

## Capture limitations

Rejected capture runs and their diagnostics are retained in `iterations.md`.
Early entirely black readbacks also affected baseline images. Completed-frame
window captures and explicit-target controls produced clean pairs. They do not
establish the cause or repair of the owner's separate partial black-screen
report, which remains issue 4. Later live capture stalls are harness failures,
not evidence of corrected gameplay. An explicit deferred draw followed by
`frame_post_draw` completes the final live sequence (exit 0), but two wholly
black pairs remain excluded as above. No general capture or black-screen repair
is claimed. Startup took 165.228 seconds in this run.
