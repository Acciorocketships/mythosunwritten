# October 3: native turrets emerging through roofs

Status: this tower family is retained as production progress. The overall town
redesign is still open, especially embedded projecting facades, inhabited tunnel
planning, enclosed climbing routes, and the remaining long flat building faces.

## Source grammar

Inspected Pure Village `House_11c.glb`, including its native rendered prefab
(`../october3-prefab-junctions/House_11c-front.png`). Its narrow, complete round
shaft emerges through a roof; it is not an open-backed tower glued to a facade.
The prefab uses `StoneTower_Middle2_15x30`, `StoneTower_Window_15x30`, and
`Roof_Tower_2`. Course origins are approximately 3 m apart and the cap overlaps
the final course by 0.25 m. The source also leans the tower slightly; this
generator keeps the courses vertical to make their shared support deterministic.

Baked those three original meshes, materials and trimesh colliders without
rescaling. Measured indexed window primitives, not the shared accessor bounds:
ornamental sill starts at y=0.881, lattice at 0.940, glass at 0.969. Ridge trim
may meet only the solid foot below y=0.85, leaving the window unobstructed.

## Production rule

`KitRoofTurrets` is a seeded fallback after the larger full-shaft candidates.
It places a complete narrow shaft one module inside a gable, supported inside
the host's upper room. Plain native courses cross the attic and roof; the window
and cap emerge above it. All shaft cells below the eave must belong to an actual
room. It cannot borrow a loggia, public deck or neighboring roof as its bearing.
The host's roof, openings and existing overhangs are preserved.

Admission still protects public headroom, structural/private reservations,
neighboring native pieces, chimneys, ridge ornaments and previously admitted
towers. Neighbor checks use the individual course/cap bounds so a wide cap does
not incorrectly reserve that width down the entire shaft. Public-air checks
remain conservative over the whole assembly. Existing large tower candidates
and their native host edits are unchanged.

Hidden roof cutters are inscribed inside measured cross-sections of the plain
native stone course (radius 0.84728 m). They do not render any substitute
architecture. Each course uses one prism instead of 31 vertical slices. The
audit reconstructs these interiors from present native courses; deleting the
shaft removes its exemption. Both tower families must have an actual cap.

## Tests and native judgment

- Final roof-turret and existing town-tower suites: **9/9 tests, 6,364 assertions**,
  103.88 s. Tests cover repeatability, optional occurrence, whole-room support,
  rejected public/neighbor/reservation overlaps, emitted collision, production
  payload validity, floating-mass/public-roof-air checks, and cap/shaft removal.
- Existing one-course side-applique regression now allows only a complete
  roof-emergent shaft when side attachments cannot be backed. It still rejects
  the former hanging one-course side tower.
- Quiet production-site check: **1/1, 149 assertions; 7,227 ms < 8,000 ms**.
  No whole-suite or fresh player-traversal claim for this turn.
- Production asset-demand/streaming-bounds check: **1/1, 35 assertions**,
  including all three newly baked assets.
- Native finished-payload isolated views: four hosts in 13/large, both sides.
  Inspected .007, .018, .019 and .released.003. The new shaft-to-roof connections
  are closed, windows emerge above the roofs, and the cap seats on its course.
- Native full-town overview and turret views generated for 13/large, 31/large,
  43/grand. Inspected the overview skylines and clear close views of both kit
  families. Some automatic close cameras are occluded by adjoining roofs; those
  are not acceptance views. In particular 31 turret side -1 exposes the junction
  hidden in side +1. The four new 13/large turrets are visible in the overview.
- Counts: 13/large **4** (all new roof turrets), 31/large **1** new roof turret,
  43/grand **7** (the previous three larger shafts plus four roof turrets).

The skyline now contains native roof-emergent spires. This does not solve the
user's apartment-street criticism: tall straight fronts, exposed upper boardwalks
and weak integration of wall housing remain visible and require earlier
room/route/roof co-design. No source-volume or route-planner change in this pass.

## Reproduce

`tests/test_october3_roof_turrets.gd`, `tests/test_october2_town_towers.gd`.

Native: `tests/harness/suntail/stepped_wing_review.gd -- --seed 13 --roof-turrets
--output DIR`; `tests/harness/suntail/kit_town_review.gd -- --cities
13:large,31:large,43:grand --views overview,turrets --output DIR`.

Bake: manifest `tools/environment_bake/manifests/pure_village_roof_turrets.json`,
then `bake_roof_geometry.gd -- --roof-turret` and
`bake_tower_roof_core.gd -- --roof-turret`. The three-part manifest uses the
existing Pure Village texture namespace.
