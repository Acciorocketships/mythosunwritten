# September 29 town review — stream "floating" (photos 1, 2, 6, 10)

Owner issues: "multiple instances of floating boxes" and "incomplete skywalk
that's just an L shape and not a full corridor". World seed 2697992464.

## What the objects were

Probed on the pinned towns (`tests/harness/floating/probe.gd`, `tunnels.gd`,
`column.gd`, `crowns.gd`):

| photo | town | plan object |
|---|---|---|
| 1 | A 1260018864828801968/compact | ceiling slab of the bored tunnel at macro (-1,1,3)-(-1,1,4): 8 fine cells at band 4, open sky above (`kit.tunnel-ceilings`) |
| 2 | A | two-cell rock shoulder at band 3 over the lane at macro (0,0) (retained terrace, passed the opposing-jamb rule), open sky above; seen from above, its two exposed stone walls around the plank soffit read as an "L-shaped skywalk" |
| 6 | B 1998423929946073270/compact | ceiling slab of the tunnel at macro (0,0,-4)-(1,0,-4): 8 cells at band 3, open sky above |
| 10 | B | ceiling slab of the tunnel at macro (4,0,-3): 4 cells at band 3; half under a house room, half under a legacy facade-bay reservation the kit does not draw. From the photo side it sits behind a roof. |

Photo 2 is not a skywalk: both town skywalks are either an enclosed
bridge-house (storey + roof) or an open railed deck, and the new audit finds
no incomplete skywalk anywhere in the corpus.

World frames (production `_placement` for the site road contact, yaw 270):
Town A `0,0,2.666667,0,2,0,-2.666667,0,0,306,12.08,1088`, Town B
`0,0,2.666667,0,2,0,-2.666667,0,0,202,12.08,504`
(`tests/harness/floating/frames.gd -- CITY PROFILE SITE_X SITE_Z 12.08`,
FRAME3). The older hint (310,12.08,1088 yaw 0) does not reproduce the photos.

## Root cause

A CROWN is stone resting on public air. The carver bores a tunnel promising
"the crown keeps a complete storey above the headroom slot", but the plot
model never builds on a passage column: its only rock above the slot is the
one-band shoulder, so every tunnel column in both towns had `plots=[]` and
open sky one band above the ceiling. `WarrenVolumetricSolver` claims tunnel
ceilings as retained maze stone before composition (so a room above could
prove bearing) and never let go when no room came; `_retain_maze_rock` also
retained rock shoulders over lanes. The kit then drew each as a roofless
stone-walled box with a plank soffit (`KitVillageBuildings` `_retained_mass` /
`kit.tunnel-ceilings`). The Sept 27 layout report already measured 88 of 146
covered street cells with nothing above them.

## Fix (one rule)

Stone has no lintel/cantilever vocabulary of its own: **a crown exists only as
the bearing of construction on it** — a building room's private volume or a
walked public floor on top of its column run
(`WarrenVolumetricSolver.unborne_crown_cells` / `bears_construction`).

- After composition and features, before the shell is derived,
  `_release_unborne_maze_crowns` withdraws every retained-stone crown that
  carries nothing; the passage below is open to the sky
  (`plan.audit.maze_released_unborne_crown_cells`).
- `_retain_maze_rock` does not retain a candidate crown run that carries
  nothing (photo 2's shoulder).
- `WarrenSpatialGrid`/`WarrenSpatialTransaction` gain `release(cells, owner)`:
  an owner may withdraw only its own claims before sealing.
- `KitVillageBuildings`: a surviving tunnel ceiling is drawn as its whole stone
  run up to the room it carries (drawing only the lowest band had left a
  floating slab under 12/grand's gatehouse room, with two invisible bands
  between), and no longer lays its own deck (the room or public floor above
  closes it; a second floor there would only z-fight).
- `KitFloatingMassAudit` (new, pure) counts unborne crowns, roofless kit
  storeys hanging over public air with nothing on top, and skywalks that are
  neither an enclosed roofed corridor nor an open railed deck.

No retries, no site rules: every town composes exactly as before (building
counts identical in all six reviewed towns); only uncarried stone disappears.

## Evidence (JPGs beside this file, gitignored)

Same camera before/after (`kit_town_review` with the production frame,
flat ground):
- `1260018864828801968_compact_p1_before_after.jpg` — photo 1: floating box gone.
- `1260018864828801968_compact_p2_before_after.jpg` — photo 2: the "L" is gone,
  the lane below opens to the sky.
- `1998423929946073270_compact_p6_before_after.jpg` and
  `townB_p6_p10roof_zoom_before_after.jpg` — photo 6 (both boxes over the
  lane gone) and photo 10's box beside the roof/chimney gone.
- `12_grand_tunnel_stack_before_top_after_bottom.jpg` — a carried tunnel
  ceiling now rises continuously into the gatehouse room it bears.
- Overview/orbit pairs for both towns plus 3/standard, 7/standard, 4/large,
  12/grand. Collateral: some roof joins change colour/extent where a released
  crown no longer blocks `KitRoofJunctions` (e.g. `3_standard_orbit3`); no new
  floating or holed geometry seen.
- The photo-10 F3 camera itself does not reproduce the photo's composition in
  the current tree (the house layout there differs), so the box was checked
  from the town-overview angle it is visible from (`p10roof`).

## Tests

- New `tests/test_september29_floating_masses.gd`: pinned towns (zero audit),
  photographed crowns released with lane headroom kept, corpus of 8 more
  towns (1c 3s 4l 6c 8c 9s 11c 12g) at zero, grid release ownership.
  Red with the release/retain hooks disabled (`test_red.log`: 3/4 fail, 264
  corpus violations), green after (`test_green.log`, 4/4, ~100 s).
- Survey before the fix (`tests/harness/floating/survey.gd`): 403 audit
  violations over 14 towns; after: 0.
- 20 focused town/kit/fabric files run in this worktree and the baseline
  (`tests_after.log`, `tests_before.log`): identical results; the pre-existing
  failures (`test_september10_ceiling_courses` 1, `test_warren_spatial_fabric_compiler`
  1, `test_warren_maze_plots` 4) fail identically on baseline.
- Maze corpus sweep (`warren_maze_mode_sweep.gd`, 12 seeds x 4 scales):
  sealed 48/48, clearance blocked=0 / gates_blocked=0 (`sweep_after.log`).
- `test_warren_maze_composition.gd` against that fresh matrix: 71/88 vs
  baseline 70/88 with the identical failure set, except a baseline timing
  failure (loaded machine, noise) and the pre-existing seed 9/compact ashlar
  share, which fails on both (0.0484 before, 0.0469 after). Its unroomed-mass
  accounting identity now includes the new
  `maze_released_unborne_crown_unroomed_plot_cells` term (without it seed
  3/standard's identity was off by the 9 released cells). The pre-existing
  "bored passages must get a stone roof" failures (seeds 9, 12) fail on the
  baseline too; that pin wants exactly the uncarried ceilings this change
  removes, so it should be re-pinned to "carried ceilings only" when those
  seeds are next revisited.

## Open items

- Tunnels still bore where no room will stand on them, and now read as open
  lanes: see the follow-up below.
- The legacy `facade_bay` reservation is PRIVATE volume the kit never draws;
  it no longer bears a crown, but other plan consumers still treat it as mass.
- Photo 4's bridge-house over the street (skywalks stream) is a different
  object (a house mass), not a crown; not changed here.

## Follow-up (coordinator): tunnel-roof rule, closures re-pin

Merged the integration branch (38eade01, 1b403ff0, bc485052, e968681a) into
`town29-floating`.

### Tunnel-roof rule

`WarrenPlotPlanner.cover_tunnels` (plot stage, after heights and bridges,
before ground streets): for each bored walk cell whose crown is solid, whose
passage walls stand solid over the whole headroom on two opposing jambs (or
both outer walls of a turn) as the finished shoulders leave them, and next to
a house plot whose storey floor lands in (crown, crown+3] under its roof
reservation, a `PLOT_OVER` (new kind) is added on the bored column: the host's
storeys continued over the lane, same building and door, never touching the
lane's carved headroom. The partitioner turns it into a back-room record of
the host parcel (`storeys` = host storeys from that floor); composition
reserves its mass for that record (so no lineage eats half the column) and
the directed back-room pass re-proves it on the built town
(`WarrenVolumetricSolver._over_passage_is_borne`: crown is claimed stone, both
jambs are rooms or claimed stone at the lane top and crown, and a real host
storey stands beside it) before stamping. Unborne crowns stay released; a
refused cover releases whole. Lineage-owned envelope overlaps (the host's own
jetty/eave under the cover) are allowed for these records.

Rejected on the way (renders/probes in the session scratchpad):
- Reserving plot-free rock jambs up to the crown: the rock-cube erosion
  (`_release_singleton_unclassified_rock_crowns`) removes such lone piers, and
  6/compact then showed a cover borne on one side only
  (`followup_6_compact_rejected_half_borne_cover.jpg`). Removed; jambs must be
  real at build time.
- Growing the host house one storey to reach over the crown: the ring-terrace
  and edge envelopes (stream "edges") forbid it wherever it would matter on
  this corpus; no measured gain, removed.

### Measurements (14-town survey, `tests/harness/floating/covered.gd`)

Covered = bored walk cells whose four fine columns carry construction within
three bands above the headroom; walks_under = walked fine cells with
construction within four bands above their headroom.

| state | covered bored cells / 31 | walks_under |
|---|---|---|
| before the first fix (crowns kept, `followup_cov_s0.txt`) | 30 | 610 |
| after the first fix (`followup_cov_s1.txt`) | 9 | 336 |
| after the tunnel-roof rule (`followup_cov_s3.txt`) | 9 | 334 |

The 30 "covered" before the first fix were mostly the floating stone slabs.
The rule restores almost nothing on this corpus, and this is the finding:
of the 31 bores (plot-stage outcome records `plot_outcomes.tunnel_roofs`),
17 have walls that do not stand after the plot stage (the shoulder rule
lowers plot-free jamb rock to the lowest bordering house floor, and several
bores sit beside a prefab or open ground), 4 have no adjacent house storey
above the crown (compact houses are 1-2 storeys and the edges stream caps rim
houses, while a ground-level bore's crown sits at band 3 and needs a third
storey at band 4), 6 already carry a plot on the crown, 1 has no crown, and 3
are decided covers, of which 2 pass the built-town re-proof. Net per
town: 12/grand gains its (0,5,-2) cover (house.006's storey over the lane),
10/compact's cover is now a directed back room, 8/compact loses the partial
facade-bay/host cover that composition used to grow (it had no second jamb;
that facade-bay volume is not drawn by the kit anyway). Floating audit: 0 on
all 14 (`followup_survey_s3.txt`).

To really restore the bored paths, the carver and the plot planner have to
decide them together: bore only under mass that the partition will build as
a >= 3-storey house on both sides, or seed a house plot ON the crown (floor =
crown + 1) addressed from an upper street. Both change carving/partition
policy and interact with streams "tiers" (tunnels through raised platforms)
and "edges"; `cover_tunnels` reads `excavation.tunnel_cells`, so tier tunnels
get the same rule for free.

Renders (same camera, before = integration e968681a, after = this branch):
`followup_10_compact_far/out_before_after.jpg` (lane under a house, storey
over the bore), `followup_12_grand_out_before_after.jpg` (new roofed storey
over the bore at centre-left), Town A `followup_1260018864828801968_compact_t0/t2/p1`
and Town B `followup_1998423929946073270_compact_t0/t2/p6/p10roof`
(identical: their bores do not qualify and stay open lanes), 3/standard,
4/large, 7/standard overviews (roof colour flips only).

### test_town_closures re-pin

`test_rooms_over_public_air_have_a_closed_underside` lost its guard at
SITE_TOWN 2695877283924445960 after the merge. Probe
(`tests/harness/floating/closure_site.gd`): with crowns kept, the only storey
cells over public air there were the 4 cells of `kit.tunnel-ceilings` -- the
uncarried tunnel ceiling (a floating box by this stream's definition); the
Sept 27 bridge-house over that lane is now an open timber bridge (stream
"skywalks": spans landing on walk surfaces are open bridges). The site
legitimately has no room over public air. The test now counts rooms only
(roofless retained/tunnel courses excluded) and uses Town B
(1998423929946073270), which keeps two enclosed bridge-houses and two
passage-houses over its lanes (`tests/harness/floating/air_rooms.gd`); the
other closure tests keep SITE_TOWN. 4/4 pass.

### Every carried crown is drawn

Re-pinning "bored passages must get a stone roof" exposed a real hole: the
kit drew only crowns over `excavation.tunnel_cells`; a carried crown over any
other lane (a shoulder under a raised garden or house) was drawn by nobody,
and the course above it has no soffit (its floor sits on stone), so from the
lane one looked into it. `KitVillageBuildings` now closes every maze-stone
crown over public air that is not retained terrace (whole run, soffit), and
the composition check asserts exactly that per carried crown cell
(`followup_3_standard_carried_crown_closed_tinted.jpg`, red = the closure).

### Tests (follow-up, final tree)

- `test_september29_floating_masses` 5/5 (whole-or-absent covers, 12/grand's
  realized cover, floating audit 0 on 10 towns), `test_town_closures` 4/4
  (integration head: 3/4), `test_september29_town_edges` 4/4,
  `test_september29_roofline_variety` 6/6, `test_september29_skywalks` 4/4,
  `test_september29_town_materials` 5/5, and the 20 other focused files:
  identical to the integration head e968681a (`followup_tests_after.log`,
  `followup_tests_integration.log`, `followup_tests_final.log`); pre-existing
  failures unchanged (ceiling_courses 1, spatial_fabric_compiler 1,
  maze_plots 4).
- Maze sweep 48/48 sealed, clearance blocked 0 / gates_blocked 0.
- `test_warren_maze_composition`: 68/88 on both this branch and the
  integration head (each with a fresh sweep matrix); this branch fails 77
  assertions vs 84: the 7 "stone roof / pair passage-roof caps" failures are
  gone, none added (`followup_composition_*.fails`).
