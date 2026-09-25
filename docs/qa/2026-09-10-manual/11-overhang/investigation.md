# Entrance overhang investigation

Photo 10 rays identify `spatial.feature.facade-bay.00` on upper room
`spatial.parcel.maze.house.006.part01.room00`. The lower room owns X=4..5,
Z=2..3 at bands 0..1; the upper room owns X=4..7, Z=2..3 at bands 2..3.
The facade bay then extends its east wall again, at a different transverse
phase. The source therefore contains two consecutive occupied projections.

Alternatives: shorten the bay mesh, add more support beneath the doubled
projection, or forbid optional bays on already projecting room faces. The
first would alter the native shell and preserve its offset junction; the
second would preserve the excessive silhouette. Select the third in the
feature reservation pass, before topology and construction are sealed.

The photographed regression fails before: one bay extends that unsupported
east face. It passes after while preserving all 16 private cells of the parent
room and retaining bays elsewhere. Face eligibility checks every base cell
on the outward edge against the immediately lower grid. Real private/structural
mass counts; an empty roof reservation does not. Four-orientation cases cover
empty, partial, private, structural and roof-only lower edges.

A legacy test expected three bays in seed 6357506428441529412. An isolated
pre-change solver confirms two use unborne edges: (-8,7,-5)/(-7,7,-5) and
(5,7,-10)/(5,7,-9). See `legacy-bays.txt`. Requiring all three would require the
newly prohibited pattern. Its check now requires surviving facade relief and
retains native bay, roof, material and geometry invariants. One full native
bay remains in that seed.

The isolated baseline is `/tmp/september10-overhang-baseline`: current scripts
and assets except the original HEAD version of WarrenSpatialFeatureSolver,
which had no earlier changes in this review. No production source was swapped.
Both physical surveys have 112 cells and 164 crossings, with identical results.
