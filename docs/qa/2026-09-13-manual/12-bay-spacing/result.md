# Centered bay windows — P09

Accepted for the photographed windows and the shared embedded-oriel rule.

The two marked windows belong to the upper bridge-end rooms, not the full roofed
annex below them. Native triangle owner tracing identifies the nearer one as
`spatial.maze_bridge_end.02.01.room01` and the other as
`spatial.maze_bridge_end.01.00.room01`. World seed 2697992464; rounded overlay
feet (-178.3, 8, -904.7), crosshair (-188.9, 11.4, -919.4).

Embedded bays now sit at the centre of an actual 3 m facade panel. All native
window, return, canopy, sill and knee pieces translate together by half a fine
cell. Two rear columns over both occupied heights must meet complete parent
room cells; both possible attachment sockets have real backing. The bay keeps
its original dimensions, UVs and shallow projection. This applies to all three
palette families and every cardinal orientation; there is no seed/site branch.

A finite existing facade phase replaces the underlying shutter with a complete
plain native panel. Selection records that phase before reservation, and both
preferred and fallback room compilation use it. The final compiled bay checks
that its actual parent still contains the one unsuppressed plain backing module.
The replacement cannot expand the original room envelope (10 micrometres of
floating-point comparison slack only; the unchanged final overlap gate remains
strict). If no compatible existing phase exists, the optional bay is declined.

## Rejected candidates and falsification

- The original centring regression fails 84 of 180 assertions. The corrected
  three-theme/four-orientation/three-width test passes all 180.
- The first centred candidate passed a 48-town sweep but left a shutter visible
  beside the small bay. `native-integration` and `native-orbit` record that
  rejected version. They are not final acceptance evidence.
- Disabling the plain-phase application reproduces a backing failure in
  `backing-red.txt`; the exact photographed parent is pinned in the final test.
- The initial backing-phase candidate broke seed 12/grand by introducing a
  facade ornament into an existing corner balcony. `balcony-red.txt` records
  the full failure. Restricting the replacement envelope resolves this case.
  The earlier `backing-corpus.json` is explicitly a rejected 47/48 result.
- Removing any rear bearing cell rejects attachment in all four orientations.

## Visual judgment

All cameras derive from the original overlay through `ReviewCam.solve_cam`.
The stored poses document each offset. Frozen live snapshots use identical
lighting and animation clocks; these are geometry comparisons, not a timing
benchmark or exact reconstruction of the original biome illumination.

- `native-backed`: three matched original/nearby pairs show both bays centred,
  with plain plaster backing and no duplicate shutter. The sill, side cheeks,
  small canopy and lower supports remain joined.
- `native-orbit-final`: the 0 and ±30-degree views give three additional clear
  comparisons. The 90/180/-90 views are occluded context and are not credited.
- `frozen-before` / `frozen-after`: three matched game pairs from actual live
  world snapshots confirm the same change in the production scene.
- `live-backed` contains three fresh game captures and its complete world
  snapshot. Startup was 189.182 seconds; this is not a performance acceptance.
- `differences` and `pixel-differences.json` preserve comparisons. The adjoining
  compact T roof and foreground houses remain intact. The final photo phases
  match the captured phases exactly: 2,4,5,4,4,2,4,4.

Nine final matched pairs are credited. The 3 m backing-panel phase can also
change other window choices on that parent room; three windowbox/plant pairs
are omitted. This is intentional finite facade selection, not a claim that
all other facade placements remain unchanged. Native payload comparison reports
2,000 before / 1,995 after placements, 1,873 exactly unchanged, 119 changed,
eight removed and three added. Twenty-seven changes are enclosure bounds only;
all recorded roof changes are enclosure bounds only, with roof geometry fixed.
One incidental frontage decoration disappears after the final facade changes.

## Validation and limits

- Four focused tests / 215 assertions pass, including the exact photographed
  parent and the reproduced seed-12/grand balcony conflict.
- 48/48 towns construct. All 11,868 tested public standing positions and 17,035
  crossings remain clear, with no split public components or unreachable cells.
- The same 25 conservative off-centre pillar contacts remain, with zero measured
  intrusion. This is not a zero-contact collision claim.
- The local native collision survey is identical at 356 positions / 502 crossings.
- The unchanged composition gate passes all 95 assertions.
- The final related run passes 15/16 tests and 673/674 assertions. It retains
  its historical assertion expecting a full
  gabled bay in the old probe seed. `baseline-related.txt` reproduces that failure
  with the original production code and original tests. No full-suite acceptance
  or general performance improvement is claimed.

The scope is bay placement/backing. Remaining village, terrain and water issues
continue in the consolidated ledger.
