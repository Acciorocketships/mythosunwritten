# Skywalk endpoint investigation

Photo 3 identifies endpoint `spatial.maze_bridge_end.00.01.room00`. Its floor
is at local band 7, while the complete lower house ends at band 6. The lower
roof reserves that remaining band but does not fill it with a building.

Alternatives considered:

- Move the bridge down: rejected because the source bore and bridge floor own
  their clearance, and changing that floor would invalidate the planned passage.
- Fill the gap with another room or masonry course: a one-band gap is not a
  complete authored room; stone would disguise the erroneous support proof.
- Restore independent endpoint bearings through existing native timber frames:
  selected. The final ground-connectivity graph had counted the skywalk itself
  as the connection that supplied its free end. A span must consume bearing
  from both ends, so it cannot return one end's bearing to the other. Roof
  reservation volumes also cannot stand in for actual supporting mass.

The original frozen native construction emits zero supporting posts at the
reported free endpoint. The new regression fails on that zero-versus-four
contract before the compiler changes. The candidate emits four one-band native
posts, retaining the bridge, both endpoint rooms, and their floor elevations.
Actual triangle contacts with the lower roof and upper floor are checked.

Initial endpoint-height assertions incorrectly used logical floor coordinates
instead of the authored board underside, which is 0.1611 m below that datum.
They were replaced by native triangle contact checks rather than moving geometry
away from its existing sockets. Acceptance still requires the matched renders,
physical clearance comparison, and related construction regressions.
