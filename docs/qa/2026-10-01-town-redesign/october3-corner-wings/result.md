# Roofed corner wings — October 3

Broad repeated stacks can now become an L-shaped upper dwelling around a lower,
inhabited corner wing. The native roof system roofs the lower corner separately,
joining the upper wings with its existing measured roof profiles. All rooms stay
inside the original building reservation. Both upper arms stay at least two
modules wide; source assets, materials and collision shapes are unchanged.
Seeded corner and height choices vary the composition. Narrow stacks retain the
previous end-wing behavior.

## Root cause and iteration

The first implementation passed its synthetic L-shape test but created no corner
wings in the main eight-town sample. `KitLoggias.recess` ran first and notched
broad crowns, disqualifying them from `KitSteppedWings`' rectangular-stack rule.
Broad houses now decide their main wing shape before loggias. A successful cut is
not applied twice, and loggias preserve the resulting upper arms. If no primary
shape fits, the earlier fallback order remains available. Doors, external
bearing, balcony-bearing storeys and public walks still prevent an unsafe cut.

The final main sample has four corner-wing buildings in three towns. Eight
additional grand-town holdouts add twelve in six towns. Across all sixteen towns,
no floating mass or roof/public-air intrusion was found. Inhabited street cover
is unchanged town by town (328 main-sample quarters and 436 holdout quarters).
The first candidate and final surveys are retained for comparison; this change
improves house silhouettes and does not claim more enclosed streets.

## Validation and native review

The final stepped-wing suite passes 5/5 tests, 127 assertions. It checks connected
L-shaped upper rooms, roofed lower wings, preservation by the loggia pass, unsafe
cut rejection, determinism/variation, and actual production corner wings in the
five-town integration corpus. The earlier combined run passed 12/12 tests and
192 assertions, also covering projecting room fronts; the final stepped suite
adds the production corner-wing assertion and fifth integration town.

Native renders use the finished generated payload, including fitted roof meshes:
`native/` is 7/standard's Pure Village landmark; `ordinary/` is 103/grand's Suntail
ordinary house. Both opposite-side views were inspected. They show actual lower
wings and connected changes in roof height, with closed gables and existing bay
windows. These are generated buildings isolated for inspection, not hand-authored
prefabs or a substitute generator. The isolated harness now accepts `--profile`.

Actual-player testing on 103/grand passed all twelve directed skywalk/underpass
walks. No refreshed full-suite or full-world visual acceptance is claimed.

This is a meaningful silhouette improvement, but not final art acceptance.
Long narrow compounds, stronger inhabited massif enclosure, taller integrated
turrets and Gothic stone architecture remain open under the original plan.

Final isolated real-terrain production gate: 1/1 test, 125 assertions,
6,214 ms town generation against the unchanged 8,000 ms ceiling.
