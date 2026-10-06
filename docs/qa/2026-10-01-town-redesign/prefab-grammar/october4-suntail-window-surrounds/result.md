# October 4 Suntail window surrounds

Suntail window trim shares Wooden_Planks with the house structure. Selecting
that whole material would count corner posts and horizontal building beams as
window surrounds and needlessly suppress openings. The bake now starts at the
measured glazing envelope and follows contacts between separate authored timber
components (1 mm contact tolerance). Only the selected components become frame
clearance bounds. Runtime geometry is not enlarged or modified.

Measured Frame_Wall_1_W and Frame_Wall_2_W each select eight window timbers:
inner frame, mullion/crossbars, two jambs, head and sill. The full-height corner
post, upper beam and lower wall framing stay out. Native bay and dormer windows
are also measured; stone-window trim selects five components. Existing material
variants use canonical source data through the facade fitter.

Regression: a horizontal skin at 2.3 m misses the glazing but intersects the
Suntail header. Detaching frame metadata reproduces the missed contact. The
new check catches it at all four orientations. A skin crossing the detached
house beam at 0.6 m remains legal for the window. Component bounds explicitly
exclude the corner and top/bottom structural beams.

Full facade-contact suite: **18 tests / 338 assertions pass**. Native 7/standard
street views inspected; window and doorway openings remain visible. These
views also expose unresolved broad blank retaining faces and a board end near
the overhead masonry: they are not evidence of whole-town art acceptance.
No new player traversal claim is made for this frame-metadata change.
