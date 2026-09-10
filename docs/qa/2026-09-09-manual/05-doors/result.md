# Photo 3: repeated doors

Accepted for the photographed frontage. Three doors on the same continuous face
now share one central entrance; the separate door around the corner remains.
The other two bays use their existing complete window-panel recipes. The town’s
entrance count changes from 14 to 12 without changing its room records or mass.

An entrance domain requires coplanar fronts, equal floor height and complete
mutually open native party-wall modules. Partial walls, gaps and staggered rooms
keep independent access. Selection is deterministic and independent of room
iteration order. The compiler records the shared entrance owner before choosing
its final facade recipes; no town or room is retried, moved or deleted.

The initial render exposed a gap between a new window and a deeper doorway and
was rejected. The existing inline timber joint now accommodates the measured
masonry/door dimensions and continues to both rear reveals within the original
facade plane. Its actual triangles close rays at four heights and five depths
in all four orientations. The earlier rejected images are retained separately.

All six matched views and their pixel differences were inspected. The duplicate
doors and newly exposed gap are gone; windows, the central doorway and the
perpendicular entrance remain complete. The exact view’s mean absolute RGB
difference is 10.64155/255; 20.863% of the full frame changes by more than 20,
primarily the two replacement panels and their joins. Small animation differences
remain. The camera JSON is byte-identical; the original rounded coordinates do
not recover its full precision or animation time.

All four new tests pass, including disconnected/partial/raised negative fixtures
and four-orientation native mesh checks. The final related run passes 45 of 46
tests with 57,676/57,678 assertions in 48.6 s (exit 1). The remaining test’s two
assertion messages exactly match the preserved baseline: missing large-blue-roof
landmark and seven tall-face course mismatches. Neither is introduced here.
All 124 public cells and 179 crossings retain identical physical clearance:
none blocked, four crossings need the same lateral offset as before.

Evidence: `verification.json`, `tests.txt`, `baseline-collateral.json`, paired
source/entrance probes and clearance JSON, source hashes, and `diff/metrics.json`.
The before/after and difference PNGs remain local ignored QA artifacts.
