# Corner support follow-up — October 3

Retain the support correction; reject the inward-corner experiment. This pass
does not satisfy the remaining request for more frequent corner towers.

## Evidence-driven change

Added rejection diagnostics to the measured tower fitter. In the five-town
sample, most rejected corners failed bearing, not a neighbouring asset overlap.
The callback had accepted only source terrain height, even when a house stands
on actual retained stone. `_tower_bearing` now also accepts the exposed top of
`kit.retained`, `kit.tunnel-ceilings` or `kit.platform-wall` stone, from the
existing podium cells. It accepts neither a private house roof nor a timber
public floor. Every native foot column must have support; the next cell above
must not still be inside that stone course. The native footing's slight embed
below its proven bearing datum is allowed; the remainder of its reserved volume
and all measured public headroom checks stay in force.

Tests cover natural ground, raised exposed stone, absent support, wall-interior
rejection, footing embed and failure when one part of a corner base overhangs
its supporting course. Existing corner, cap removal, public clearance, collision
and material variant tests remain in the final run (`tests.log`).

Five matched towns (13/large,31/large,43/grand,101/large,103/grand) still produce
one corner and one existing half tower, both in 43. Coverage, public cells,
floating-mass counts (zero) and measured roof/public-air intrusions (zero) are
unchanged. More candidates can prove support, but later join/reservation checks
still prevent additional completed towers. `before.json` / `retained.json`.

## Rejected

A temporary three-occupied-quadrant rule admitted inward L corners, with windows
facing the open quadrant. `inner-gallery/` is a controlled procedural fixture;
its front/junction images show the two roofs swallowing the narrow cap. The
five-town survey gained no towers (`rejected-inner.json`). Both the inward-corner
rule and its pose change were reverted; production still requires a consistent
convex corner. These images are not accepted architecture or new production.

## Next

Plan a corner shaft and adjoining lower wing together, before articulation,
with a reserved footprint and real supporting course. Do not bypass public
clearance or count roof ornaments as success. Whole-building palettes, Gothic
composition and the remaining enclosure/art requirements stay open. No new
player traversal or production timing claim in this pass.
