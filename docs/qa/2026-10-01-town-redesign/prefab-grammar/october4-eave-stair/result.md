# Eave/stair contact diagnosis

No production substitution admitted. This is the unresolved eave-cut assertion
from the preceding roof-fragment repair, not another invisible collision strip.

Reproduction: September 27 photo-town test, seed 85830433957479026/compact,
`kit.spatial.parcel.maze.house.000/k0062`. The roof is a 4x2-module rectangle
at (-2,4), ridge axis X, eave band 2. It already selects the tight negative-side
eave. The affected complete asset is `pure_village.roof.slope.end` at native
(-4,3,8), facing -Z.

The adjacent landing and first stair tread intrude into that asset's corner.
The tread air comes from `volume.transition.07.mesh`, not from a railing or a
spurious underside: its native bounds start at (-4,3.1875,4), size (.5,1.2,4).
The public-clearance compiler correctly builds air from the upward tread.

Measured alternatives, using the actual authored triangles:

- Current Pure Village end cap loses about 0.8515 square native metres to
  walking clearance. Its adjacent straight slope loses another 0.4594.
- Retracting the complete minimum end cap to a flush verge still loses
  0.5471; retracting the other end or both does not resolve that contact.
- A complete Suntail tight-eave assembly at the same roof datum still loses
  0.4286 from its first piece. The tiny differences on its other pieces are
  floating-point noise, not evidence that every piece has a real overlap.

Native Godot view inspected and saved here. The roof remains present, but the
corner beside the stair is cut. Other roof audit categories are zero for this
town: tiny wings, open exposed ends, gable holes, unsupported roofs and uncapped
towers. The eave-cut count remains one.

The focused read-only reproduction is
`tests/harness/suntail/eave_stair_contact_probe.gd`; `probe.txt` records the
native roof, walking volumes and measured alternatives. The next repair must
co-design the corner roof assembly and the stair interface. Do not weaken the
headroom gate, hide the failing assertion, or substitute a complete roof kit
under the assumption that it fits. Existing source-prefab roof connections
remain the reference for a new corner arrangement. Overall goal stays open.
