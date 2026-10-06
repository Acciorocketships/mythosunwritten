# Turret-house course variation

PureVillageTurretHouse now derives the exact source case or one additional
complete upper storey. Sampling is seeded and contains both cases. The repeat
interface is the authored y=10.5 m course: eleven facade pieces and one full
round turret course. Main crown, dormers, brackets, chimney and cap move up
together by3 m. The low side wing remains fixed. Native pieces are translated,
not stretched, and material-binding asset IDs remain attached to each part.

The first native render exposed a new blank strip behind the house. Five
WindowSolo_6 modules now dress full-width repeated bays. An initially proposed
sixth faced into the corner cylinder; the shaft-facing bay remains solid.
The shaft sightline rule uses the native round radius and window reach, not
a prefab node ID. Lowering the window seat to0.8 m clears the hanging roof
brackets while preserving the original stock window frame.

Tests:3/3,980 assertions. Source case repeatability, both seeded choices,
unchanged module bases/material IDs, course contact and all added exterior
glass checked. Glass rays are tested against actual baked triangles after
AABB rejection: initial38 blocked rays, then4, final0. The test was not relaxed
to accept blocked glazing. The early course seam assertion used absolute AABB
separation and falsely rejected authored overlapping trim; the final assertion
checks for positive gaps instead. This is contact evidence, not a complete
intersection audit.

Native final front/back inspected:199 placements and199 collision pieces.
No detached turret cap or new roof gap observed in these views. Earlier blank
and blocked-window candidates were not accepted. The house remains tall and
some original source faces remain plain; this is not full town art acceptance.

Still not registered in production town sampling. Entrance/terrain datum,
whole-building reservation, compiler preservation of bound asset IDs and
actual-player traversal remain next. This bounded course family is only one
part of the requested broad prefab-generalizing grammar.
