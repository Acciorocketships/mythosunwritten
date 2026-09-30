# Multi-level towns ("tiers"): design note

Owner direction (photo 11 follow-up, September 29): "some parts of the city can
be raised on top of a rock platform (of course just make this a randomly
generated thing not in all cities). this should make the bored paths through
the city more interesting too. parts of the city can be almost like a castle".
For those towns this supersedes the older "no stone cliffs inside the city"
direction. Stone stays on the platform's own walls; the houses on top stay
Suntail timber/plaster with pitched roofs.

Coordinator follow-up (first renders): the plinth must read as a
fortification from a distance -- plain coursed stone, a batter at the foot, a
stone parapet instead of timber rails, towers, a stone-framed gate; the lower
town at its foot must stay under the plinth top; the district on top must be
densely built. This note describes the design after that follow-up.

## The platform is a field component, not a post-pass

`WarrenTownField.sample` (Gaussian mixture of lobes, satellites and
clearings) also returns a `platform`, sampled by `WarrenTownPlatform`:

* **Rate.** An independent roll from the city seed (`hash([seed,
  "town-platform"])`, `CHANCE = 0.6`), on its own RNG stream, so every town
  without a platform is byte-identical to the baseline (pinned by a source
  signature test). After the shape rules about a third of production towns
  (`WarrenVillageScaleProfile.select`) keep one: 98/300 seeds; 18% of compact,
  53% of standard, 57% of large sites.
* **Height.** Two storeys of plinth (4 bands, 12 m in the production frame).
  The one-storey option was dropped: from a distance it disappeared among the
  lower town's two-storey houses.
* **Shape.** A rounded rectangle on the crown lobe over massif columns at
  least `MIN_RING_DEPTH = 3` rings in from the boundary (so the "edges"
  stream's two low perimeter rings always wrap its foot), opened by a 3x3
  square (no slivers), largest piece, at least 9 columns.
* **Clear of the mouth.** `clear_forecourt` slides the outline away from the
  town mouth until the market approach stands in the lower town.
* The platform's most central column becomes the massif's crown.

`WarrenMassifBuilder._raise_platform` records `"plinth"` per column.
`WarrenMassif.bearing_at` = ground + plinth is the one datum the rest reads.

## The lower town huddles under the wall (same field stage)

`WarrenTownPlatform.huddle_top(massif, column)`: within `HUDDLE_RINGS = 2`
columns of the plinth, a lower-town house may rise no higher than the plinth
top above its own ground (at least one storey). It is ground-relative, so the
rule is invariant to terrain relief. It is applied where the massif is built
(`_raise_platform` caps the envelope there and re-clamps the neighbouring
risers) and where house heights are drawn
(`WarrenPlotPlanner._building_top` takes `min(edge envelope, huddle_top)`, so
it composes with the edges stream's perimeter envelope; `_join` refuses a
lot that would overtop it, and `cover_tunnels` never covers a bore there).
The result from a distance: the citadel's houses stand a full two storeys
above every roof at its foot.

## How each stage reads it

* **Plots** (`WarrenMazeSourcePlan.plot_support_ok`): no floor below
  `bearing_at`; bridge plots never inside a plinth. Rock shoulder never below
  `bearing_at`.
* **Prefab assets** (`WarrenPlotReservations._fine_box_bears`): wholly on the
  plinth or wholly off it, and never bearing in the huddle ring.
* **Borability** (`WarrenPassageLatticeRules.slot_is_borable`): the plinth is
  never bored. On a platform column nothing runs above the grade and the
  grade itself is laid only by the upper-town stage. In the huddle ring a
  flight may climb with its slot open to the sky (`open_foot`), so the way up
  runs along the outside of the wall rather than through it.
* **Tunnels** (`WarrenMazeCarver._natural_tunnel_caps`): no natural tunnel
  on a platform column or in the huddle ring -- the citadel and the street at
  its foot stay open to the sky, which also keeps passage covers
  (`cover_tunnels`, PLOT_OVER) out of the district.
* **Spine**: it climbs to the huddle at the wall's foot (for a platform town
  `_summit_reaches_crown` means "in the huddle ring", span goal 0, minimum
  length the market prefix). The descent follows as usual.
* **Gate flight** (`WarrenPlatformStreets.carve_gate`, after the descent):
  breadth first from the spine's summit (else from every walk node),
  open-foot climbing strides along the wall through the huddle, one flight
  cell per column, ending in a level step through the rim onto the grade.
  The lane is tagged `citadel_gate`; its last transition marks the rim edge
  the gate opens.
* **Upper town** (`WarrenPlatformStreets.carve`): level lanes from the gate
  over the platform grade until every platform column fronts a lane or sits
  beside a fronted one -- the district is built up, gardens are the exception.
* **Wall street** (`carve_wall_street`): a ground lane round the plinth's
  foot, so the wall stands free above a street.
* **Bridges** never within two columns of a platform (their endpoint
  reservations would empty the district). District lane kinds
  (`citadel_gate`, `upper_town`, `wall_street`) are exempt from the maze's
  straight-run cap: a wall street is straight by nature.

## The fortification (kit)

* `KitVillageBuildings`: retained cells inside a plinth become one
  `kit.platform-wall` mass flagged `fortified`, carrying the gate edges. It
  counts as podium (the materials stream's `_podium_cells`).
* `BuildingKitAssembler._assemble_fortified` builds it from one role,
  `wall.fort` = `suntail.stone.stone_wall_plain`: the Suntail stone wall baked
  without its `Wooden_Planks` surface (new bake option `exclude_materials`,
  `EnvironmentBakeGeometry.drop_material_surfaces`), i.e. plain coursed stone
  with no timber string course, posts or frame.
  * every exposed face: plain stone panels up to the grade;
  * a battered foot course (`FORT_FOOT_*`) along the base of the lowest
    storey;
  * a stone parapet with merlons along every open rim edge (not where a house
    stands on the rim, not across the gate);
  * turrets at convex rim corners, piers at other exposed convex corners;
  * the gate: two stone piers inside the rim, a deep lintel and a parapet
    across -- a stone-framed opening where the flight arrives.
* `PublicRealmSurfaceSolver` takes the parapet as the guard of those rim
  edges (`WarrenTownPlatform.parapet_guard_boxes`), so no timber railing is
  drawn on the wall top.

## Invariants (tests/test_september29_town_platform.gd)

1. Platform towns are a deterministic subset (share 0.25-0.5 at production
   sizes, never all), each at least 9 columns, 4 bands, crowned.
2. The plinth is solid (never bored) and the district is built up: houses
   cover at least 45% of the platform's non-lane columns.
3. The lower town within two rings of the wall stays under the plinth top.
4. The upper town is reached from the gate through the walk graph by exactly
   one `citadel_gate` flight, and carries houses.
5. The plinth renders as plain coursed stone (`stone_wall_plain` only) that
   reaches the ground, with parapet/rim pieces.
6. A town without a platform keeps its baseline source signature.
