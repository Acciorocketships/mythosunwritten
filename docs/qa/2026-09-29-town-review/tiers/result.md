# Multi-level towns ("tiers") -- result

Scope: addendum bullet 3 (owner, photo 11): "perhaps we can even have a city
with multiple levels ... some parts of the city can be raised on top of a rock
platform (of course just make this a randomly generated thing not in all
cities) ... parts of the city can be almost like a castle". Design (current):
`design.md` beside this file. Round 2 answers the coordinator's follow-up
(the plinth did not yet read as a fortification from a distance; the lower
town hid it; the district on top was half garden).

## What was built

A raised district is a component of the town field (`WarrenTownPlatform`),
carried by the massif as a second datum `WarrenMassif.bearing_at = ground +
plinth`. Every stage reads that datum; towns without a platform are
byte-identical to the baseline (pinned source signature).

Round 1 (a67e5a0b): the field component, the datum, plots/shoulders/prefabs on
the plinth, upper-town lanes, the wall street, `kit.platform-wall` stone, the
probe and review views, tests.

Round 2 (this commit), after merging the integration head (1b403ff0, then
bc485052 edges, then d6eba777 floating follow-up):

* **Fortification.** A plain-stone Suntail wall variant,
  `suntail.stone.stone_wall_plain`, baked through the manifest path with a
  new `exclude_materials` bake option (drops the `Wooden_Planks` surface: no
  timber string course, posts or frame). `BuildingKitAssembler.
  _assemble_fortified` builds the plinth from it alone: plain panels, a
  battered foot course, a stone parapet with merlons on every open rim edge,
  turrets at convex rim corners, piers at the other convex corners, and a
  stone-framed gate (two piers, deep lintel, parapet across) where the flight
  arrives. `PublicRealmSurfaceSolver` takes the parapet as the rim's guard
  (`WarrenTownPlatform.parapet_guard_boxes`), so no timber rails on the wall.
  The plinth counts as podium for the materials stream (`_podium_cells`).
* **Stands out from a distance.** Two-storey plinth only (the 1-storey option
  vanished among the lower town). Within two rings of the wall a lower-town
  house is no taller than the plinth top above its own ground
  (`WarrenTownPlatform.huddle_top`, ground-relative), applied in the massif
  build and in `WarrenPlotPlanner._building_top` as `min(edge envelope,
  huddle_top)` -- it composes with the edges stream's envelope.
* **Way up without boring the plinth.** The stair canyon through the plinth
  is gone: the plinth is never bored. The spine stops in the huddle at the
  wall's foot; after the descent, `WarrenPlatformStreets.carve_gate` lays one
  open-foot flight along the outside of the wall from the spine's summit
  (else any walk node) up to a level step through the rim (`citadel_gate`).
  No natural tunnel is bored on a platform column or in the huddle ring, so
  the floating stream's passage covers (`cover_tunnels`) never land in the
  district (they had produced a half-cover in 12/grand).
* **Dense upper town.** Upper-town lanes serve every platform column (fronted
  or beside a fronted one); no bridge within two columns of the platform (its
  endpoint reservations emptied the top); prefabs never bear in the huddle;
  district lanes are exempt from the maze's straight-run cap.

## Evidence (PNG/JPG on disk only)

Before = baseline tree (merge base, no fortification/huddle), after = this
commit, same cameras (`kit_town_review --views overview,far,platform`; the
far views frame the massif footprint, identical in both trees).

* Distant, before vs after: `before2/<town>_{overview,far0-3}.png` vs
  `after3/<town>_{overview,far0-3}.png` for `33_standard`, `27_large`,
  `6_large`, `34_large`. Best: `after3/33_standard_far1.png` (stone wall with
  turret and parapet under a two-storey upper town),
  `after3/27_large_far1.png`, `after3/34_large_overview.png` /
  `before2/34_large_overview.png` (half-garden top -> built citadel).
* Photo-11-like far view (Town B = city 1998423929946073270 compact, the
  photographed town, which now rolls a citadel):
  `before2/1998423929946073270_compact_{p11,p11tele}.png` vs
  `after3/1998423929946073270_compact_{p11,p11tele}.png`.
* Wall and gate: `after3/34_large_platform_gate_out.png` (gate, turret,
  flight, crenellations over the lower roofs), `after3/34_large_platform_face0.png`,
  `after3/33_standard_platform_face3.png`, `after3/27_large_platform_face0.png`,
  street level `after3/27_large_platform_gate_flight.png` (the flight along the
  wall), `after3/33_standard_platform_gate_flight.png`,
  `after3/<town>_platform_wall<k>.png`, `after3/<town>_platform_far<k>.png`.
  Several street-level and elevated cameras sit inside eaves or on a roof
  ridge (cramped lanes); judge from the named ones.
* `after2/` is the first round-2 render (before the gate moved inside the rim
  and the tunnel rule); `after/`, `r1-r4/` are round 1.

## Corpus

* Source plans (`town_platform_probe --no-build`), seeds 1-40 x
  compact/standard/large: 120/120 seal (baseline 120/120); 38 platforms.
* Full production entry (`WarrenVolumetricSolver.generate` + fabric
  compile), seeds 1-12,24,27,33,34 x compact/standard/large: 48/48 build,
  26 with a platform. Zero plinth holes, zero bored plinth cells, zero plots
  inside a plinth. Houses cover a mean 0.89 (min 0.50) of the platform's
  non-lane columns (round 1: 0.10-0.80).
* Rate over 300 seeds (massif): 98/300 = 33% at production sizes (`select`);
  18% compact, 53% standard, 57% large.
* Production-size towns (`layout_corpus.gd --seeds 1-60 --scale select`, full
  build + `PublicWalkAudit`): 60/60 seal, 0 dead-end nodes in every town
  (the September 27 ceiling).

## Tests

* `tests/test_september29_town_platform.gd` (6): rate/determinism (4-band
  plinth, crowned); plinth solid and district built up (houses >= 45% of
  non-lane platform columns); the lower town huddles under the plinth top;
  one `citadel_gate` flight reaches the upper town, which has houses; the
  plinth is grounded plain stone (`stone_wall_plain` only) with rim pieces;
  a town without a platform keeps its source signature. 6/6. Red on the
  baseline by construction (no platform API).
* Updated to the datum/new town rolls: `test_warren_massif.gd`,
  `test_warren_maze_plots.gd` (unsealed fixture seed 12 -> 9: 12/standard is
  now a citadel town with no deep clean columns),
  `test_september29_floating_masses.gd` (the covered-bore pin 12/grand (0,-2)
  moved to 7/large (-1,1): 12/grand now rolls a citadel and its bores moved).
* Focused runs, this branch vs baseline tree (`/Users/ryko/story-towns29`):

  | file | tiers | baseline |
  |---|---|---|
  | test_september29_town_platform | 6/6 | n/a |
  | test_september29_floating_masses | 5/5 | 5/5 |
  | test_warren_massif | 17/17 | 17/17 |
  | test_warren_maze_carver | 13/13 | 12/13 (descent gain 0.95 < 1.0) |
  | test_warren_maze_plots | 39/42 | 38/42 (same three plus the plaza pin) |
  | test_town_public_walk_dead_ends | 3/3 | 3/3 |
  | test_town_destination_agreement | 3/3 | 3/3 |
  | test_town_closures | 4/4 | 3/4 |
  | test_town_depth | 4/4 | 4/4 |
  | test_town_layout_field | 6/6 | -- |
  | test_warren_inhabited_massif | 3/3 | -- |
  | test_september29_town_edges | 4/4 | -- |
  | test_september29_skywalks | 4/4 | -- |
  | test_september29_town_materials | 5/5 | 5/5 |
  | test_september29_roofline_variety | 5/6 | 6/6 |

## Open / honest limits

* **Roofline variety (variety stream's test), 5/6.** Two causes:
  * Town B (photo 11) now rolls a compact citadel: 14 houses, 2 on the
    platform; the lower town is almost all one-storey edge/huddle houses, so
    rows of equal eaves count as twin gables (3 > 2) and the minority ridge
    axis is 4/14 = 0.286 < 0.35. The twins are lower-town houses, not the
    citadel. Options for the owner/coordinator: keep (the photographed town
    is the one the owner asked to see multi-level), or keep platforms off
    compact towns (production rate would fall from 33% to about 19%).
  * Town A fails independently of this stream: its metric depends on what ran
    earlier in the same process (static state). Alone it measures 0.333 in
    both trees; after the baseline Town B it measures 0.375 and passes. With
    Town B changed, the baseline's lucky order no longer holds.
* Compact towns keep a platform rarely (18%); the one-third rate is met over
  production sizes, not per size.
* Upper-town lanes are elevated public floors, so they render as plank decks
  rather than paving; the gate flight is timber stairs with rails.
* Street-level review cameras often clip into eaves in cramped lanes.
