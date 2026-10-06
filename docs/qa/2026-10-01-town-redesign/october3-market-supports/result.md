# Market support integration

World3's bridge-house support intersected the butcher canopy. Each vertical
post column now tries the four corners of its existing bearing cell as one
aligned shaft, keeping its original choice if already clear. Alternative
positions must clear the declared public-floor prisms, native component
bounds and the unchanged measured seam checks. No room, street, canopy or
column is removed. All courses move together; source load paths remain on the
same bearing cells. The complete16-world-seed source/record survey changed
from15/16 valid to16/16 valid (before the rendering fixes below).

Native review then revealed two separate integration defects. Expanded
placements now carry their exact `unit_id`; kit replacement uses that field
instead of splitting at the first slash, which mistakenly discarded a
replaced room's independent ground-frame children. Finally, only the top
course of a retained frame is extended from the legacy floor underside to
the explicitly supported kit room's datum. The measured gap was0.1611m in
lattice coordinates. Whole native post assets, lower endpoints and intermediate
course joins are preserved. Visibility ownership expands with the top course.

Evidence:
- Existing photographed-skywalk-bearing and13 roof-construction tests passed.
- The initial new contact probe incorrectly required every intermediate
  course to touch a non-post asset; corrected to complete-column endpoints.
- Source-floor contact passed, but the stronger production-kit test exposed
  missing columns and then the actual native-floor gap. A subsequent test
  corrected its aggregation to include every native tiled post piece.
- Final new regression passes48 assertions: unchanged record validation,
  retained canopy, all four columns/eight courses in production, source
  clearance, aligned contiguous courses, and actual production native-floor
  triangle contacts. `market-bearing-final.log`.
- Building-kit suite8/8 passed in the combined run; that run's one failure was
  the pre-aggregation new contact test, retained in the log.
- Finished native roof-air six-town survey passes19 assertions (combined
  with the earlier production-presence test2/2,67 assertions). This preceded
  the top-course seating change and does not prove all native post clearances.
- Native isolated `seated/` side view inspected: post now reaches the underside;
  the canopy is intact and separate. `isolated/` omits posts before the ownership
  fix; `retained/` shows the old gap. These are diagnostic isolated scenes,
  not whole-town visual acceptance.

Fresh quiet production timing is running in session38201. Current full native
post-clearance/discovery corpus must be refreshed after the rendering fixes.
Broader regression classification, visual acceptance and runtime/memory review
remain open. No completion claim.

Quiet production38201 completed: 6941ms < unchanged8000ms,149 assertions; total55.065s includes world setup. No live jobs.
