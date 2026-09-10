# Photo 12 — projected bay support

The matched consolidated baseline reproduces the circled volume. Projection of
actual placement bounds identifies `maze-outcrop/-1/3/11/3` and its neighboring
`maze-outcrop/-3/3/11/3`, rather than an independently stamped small room.
World frame: origin `(289.5,6.08,-1157.5)`, scale 2, yaw -90 degrees.
The two-panel deep bay spans x=252..255, y=12.08..18.08, z=-1165..-1159.
Its parent facade starts at x=255. The bottom plate reaches into the wall but
has no visible supporting frame. A previous removal of ribbed corbels left
only this plate; no source room moved in the present repair.

Considered reducing every deep projection to a shallow bump, adding ground
columns, or supporting the existing bay with plain timber knees. The candidate
uses two plain native pillar members diagonally, from inside the parent wall
to inside the existing bottom plate. No ribbed/stair-shaped corbels return.
The complete frame remains in the reserved band below the bay, and the
headroom preflight checks those same transforms before choosing the profile.

The frozen source is captured from the actual seed and frame as
`tests/fixtures/september9-offset-source.txt`. Production does not read it.
The native geometry test checks both profiles in four orientations and verifies
that the photographed pair emits its four real support members.
