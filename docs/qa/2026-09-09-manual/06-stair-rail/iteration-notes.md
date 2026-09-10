# Photo 6: stair rail / native landing post

The consolidated baseline still reproduces the gap. World-space projection
identifies the floating end at `(249,13.38,-343)` as the TOP of gate.01,
not the free lower end covered by September 8's taller end-post repair.

The generated rail uses a 1.15 m local height. The existing native landing
fence post reaches only 0.929951 m above its base, which is lifted 0.025 m.
Its post centre is 0.074 m inside the fence endpoint. Omitting the generated
start post is correct ownership, but the rail endpoint must respect that
native joint.

Considered: extending every native fence post; adding an overlapping stair
post; lowering just the attachment and interpolating to the unchanged stair
guard height. Selected the last option: both beams enter the actual post,
with the upper centre at 0.825 m above the logical landing. The flight and
lower landing keep their treads, width, collision and single post ownership.
Internal stairs and lower landing rails retain their existing heights.

The native-triangle regression checks timber and generated collision at the
same two sockets, both sides, in four orientations. It also checks that the
old constant-height rails miss those sockets. The first test used rays exactly
on the generated beam cap plane; floating-point edge ambiguity gave 0/1 hits.
The final ray crosses 2 cm inside both intersecting members, away from their
boundary planes. This was a test correction, not a second geometry change.
