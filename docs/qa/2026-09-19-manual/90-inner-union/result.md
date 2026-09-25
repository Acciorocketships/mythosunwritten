# Inner shelf union studies — pass 90

All three studies are rejected. Production cliffs remain on pass 89.

The experiment projected finished inner-corner surfaces outward toward adjoining wall outcrops, with a smooth depth maximum. This tested whether existing shelves could be connected after triangulation. The unbounded version moved 1,952 vertices across three corners, by as much as 6.791 m, and collapsed 127 triangles. Restricting candidate walls to the actual adjoining planes produced the same result; unrelated parents were not the cause.

A 0.35 m displacement limit retained 1,945 moved vertices without collapsed triangles, but the elevated native view still has pointed shelf junctions and pinched turf. Neither closed geometry nor a bounded displacement establishes acceptable art. The next attempt should connect shelf boundaries before final mesh construction, rather than deform already finished overlapping treads.

[Rejected unbounded join](study/inner_above.png) · [Rejected bounded join](bounded/inner_above.png). These replay the pass-88 saved world; no new world generation or physical acceptance is claimed. The experimental hook was removed from the ordinary replay harness. Standalone sources remain in `tests/fixtures/september19/inner-union/`.

The editor-scan command in `cliff90-parse.log` is excluded as a clean parse gate: it scanned unrelated historical imports and reported case-sensitive source-path errors. Native study runs completed. No production cliff code changed in this pass.
