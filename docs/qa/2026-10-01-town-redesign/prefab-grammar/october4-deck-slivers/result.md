# Raised-deck collision repair

Retained production fix: `KitRoofMeshUnion.trim_surface` rejects newly clipped
triangle fragments whose minimum altitude is at or below its existing clipping
tolerance, 0.0001 native metres. The previous area-only degeneracy check retained
long, extremely thin strips. Those almost invisible strips were still concave
collision surfaces and could stop the character across an otherwise open path.
The render and collision consume the same filtered triangles. Untouched authored
triangles are not subject to the new fragment threshold.

Reported reproduction from the preceding canopy pass: 43/grand, court.deck.00,
world position approximately (18, 12.05, -54). Named collision tracing identifies
`kit.spatial.parcel.maze.house.027/k0124.union.0.0`. Its remnant crosses the route
at fabric y=6.559008..6.559018, z=-20.25: around 0.02 mm tall in world space.
The strip's length was sufficient to pass the old area threshold.

The unchanged actual-player route through the finished native town failed in
both directions before the repair and passes in both directions afterwards.
Raw traces are `before-walk.json` and `after-walk.json`. The traversal harness
now records generated surface IDs as well as node paths, making subsequent
collision failures attributable without relying on ephemeral node numbering.
Native Godot views of the court and the crossing were rendered; the retained
crossing image shows the enclosing walls, porch overhang and public timber
surface intact. This repair removes numerical debris, not architectural mass.

Three new regression tests exercise short and long sub-tolerance strips,
centimetre-wide real trim, and preservation of untouched authored thin detail.
Red-first: the two strip assertions fail before the change. After: all three
new tests pass. Combined with September 27 roofs and kit roof junctions:
16/17 tests, 12,150/12,151 assertions pass. The remaining photo-town eave-cut
assertion for 85830433957479026/compact also fails with the new fragment filter
disabled (9/10 assertions); the production filter was restored afterwards.
Keep that independent eave-cut defect open. No full-suite or full-town-design
acceptance is claimed here.
