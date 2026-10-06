# October 3: projecting inhabited wall fronts

This pass adds shallow extensions to existing inhabited wall rooms. It does not
complete the broader request for bored massifs, enclosed climbing streets or
elimination of long flat faces.

## Construction

Eligible upper timber rooms project 0.65 native metres (1.3 world metres).
Their original lower room remains the bearing and keeps its doorway. The front
panels move outward; original Suntail floor boards close both the extension floor
and its ceiling, Pure Village plaster panels close both returns, and native
crossbars and small brackets connect the extension to the lower wall. No new
texture or visible primitive architecture is used. The new manifest crops native
stock to the required lengths without changing texture scale.

Long frontages select a seeded two- or three-bay section, leaving recessed
shoulders. Selection uses the normal room seed and geometry; there are no
seed-specific placements. The extension requires backing or an existing walked
cap above. Where masonry carries a hood, the shallow Pure Village roof course
remains attached to the original wall plane. Its seat rises 0.35 m over a
projection to clear the native front head. A public walking cap may instead
cover the room directly; its walking air remains immutable.

Fronts are assembled before optional facade ornaments. Their actual added body
participates in roof/facade fitting and excludes neighboring ornaments. The
ordinary final window/roof/floor fitter still checks relocated window panels.

## Fit corrections and rejected trials

The first isolated assembly put the native front head through the shed roof.
Lowering the full front panel by 0.14 m (its foot concealed by the floor beam),
closing the ceiling exactly at the walking plane, and lifting the hood corrected
that junction. Initial gallery images are rejected; `gallery-fitted/` is the
corrected isolated grammar study.

An initial four-metre-high neighbor box treated all space beneath the extension
as occupied. It also treated the bracket attachment ends inside the host wall
as new interference. The final neighbor test uses a room/beam envelope plus
individual measured native bracket tips. The 0.30 m wall attachment strip is
excluded only from neighbor-part fitting; it is not excluded from public-air
checks or private-grid reservations. The attempted blanket exemption for low
masonry was removed. Actual neighboring upper walls, plinths, floors and doors
continue to reject an extension. Neighbor parts use the same external-solid
and walked-floor callbacks as the production assembler.

## Evidence

- Generated 58/large and 67/large each admit one inhabited projection. The
  bridge-side 13/large candidate stays rejected by an actual neighboring stone
  base. These are production generator results, not the isolated fixture.
- `close/58_large_oblique58.png` and `close/67_large_oblique67.png` show native
  returns, floor beams and supported fronts in the finished towns. The latter
  shows recessed shoulders around a shorter projecting section.
- `towns/` wide custom cameras were roof-occluded and are not acceptance evidence.
- Initial targeted suites: 7/7 tests, 109 assertions. Final expanded regressions:
  10/10 tests, 182 assertions, 112.496 s (projection, wall hood and skywalk
  landing suites). No parse/script errors in those checks or the final renders.
- Quiet existing production-site check: 1/1 test, 149 assertions; solve
  7,362 ms under the unchanged 8,000 ms ceiling (whole test 52.639 s). This is
  the established compact production fixture, not a large-town performance survey.
- Actual player doorway approaches: 58/large 8/8 and 67/large 8/8 directions,
  including the hosts below the new projections (`doors58.json`, `doors67.json`).
  These are local threshold approaches, not whole-town traversal claims.
- The initial 58/large `--skywalks` player request selected no routes and returned
  an empty result. It is not a passing traversal test (`player58.json`).

## Remaining work

The inspected streets still contain tall masonry stretches and exposed upper
walks. The fronts improve depth and inhabit existing walls but do not add tunnel
coverage, overhead occupied rooms, tree canopy, or new courtyard space. The
larger massif/route/roof co-design and overall architectural acceptance remain
open. No full-suite or world-streaming claim; no commit or PR.
