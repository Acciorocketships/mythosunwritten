# P04 rail / upper floor joint

The original saved P04 camera points to generated transition 12. Its upper rail crosses the lower fascia of `spatial.fabric.spatial.parcel.maze.house.015.part00.room00/floor` (`sfv.fabric.floor.l.001`). The floor underside is at local y=7.338948, whereas its walls begin at y=7.5. Guard clipping included walls but omitted this hanging floor depth.

The first red test finds the old rail at three positions inside that fascia. Including the measured native floor in the existing barrier union removes all three intersections, without moving the house, stairs or floor. Native review then shows a newly cut handrail end between the regular posts. That floor-only candidate is retained under `floor-only/`, but is not the selected result.

A second red check pins the missing support below the new cut. Exposed upper-rail endpoints now add flight-seated posts when no existing post supports them. Posts use the same building clipping and rail-contact rule. Four rotated flight controls prove that the new support follows the flight rather than a world axis.

Final source comparison changes only generated meshes 90 and 94 out of 101. Native batches and generated collision boxes are identical. Complete physics changes the three reported ray hits from the intersecting rail to the actual native floor, and adds the new post contact. The previously repaired P15 rail contacts remain present. Fresh-world and full-town results are recorded separately in the final result.
