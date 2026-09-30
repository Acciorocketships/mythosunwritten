# Mountain water: sources that never left their summit, and cascades buried by the slope

Owner report (seed 2697992464, Opal Highlands, player (468.6, 35.9, 872.1),
crosshair (472.1, 34.3, 878.4), storeys 9/6/3): water did not flow over the
ledges, and appeared to come out of the side of the mountain.

## Diagnosis (numbers)

Harnesses: `tests/harness/mountain_water_probe.gd` (rivers, profile, field vs
heightfield), `mountain_water_corpus.gd` (how every source walk ends),
`mountain_water_cover.gd` (water level vs the rendered `sheet_bedrock`
envelope).

1. **The water at the site came from a spring that never left its summit.**
   Super-cell (0,1) ascends to a narrow 88.3 m peak at (535, 896). Its
   contour walk circled the summit at about 20 m radius; at step 11 every
   candidate lay inside the 60 m self-avoidance radius of its own first
   steps, so the walk stopped. The river was 11 samples long and ended 24 m
   from its source. Its terminal lake was placed on the flank (natural ground
   81.8 m) with a spill level of 3.0 m (the minimum natural height within its
   footprint) and excavated **78.8 m** of mountain. The channel beds (51.5,
   35.5, 19.5 m, contained below a spike's flanks) cut a canyon about 50 m
   deep. The storey clamp then turned the crater into 12 m steps: ground
   48/36/24/12/0 m every 24 m ([site-probe-before.json](site-probe-before.json)).
   The fill relaxed a sloping slab (level 38 down to 9 m) over that staircase,
   up to 12 m deep. This is also the stepped face the September 26 P03 cliff
   passes were reviewing.
   Across the 81-district window, 4 of 55 sources did this (all at exactly 11
   samples, ending 24-48 m from their source, terminal lakes excavating 16-79
   m); the remaining 51 all run at least 221 samples
   ([before](source-corpus-before.json), [after](source-corpus-after.json)).
   Across four seed/amplitude configurations, 10-13% of summit sources were
   such orbits.
2. **The slope envelope buried water crossing a ledge.** A river crossing a
   crest is a sill-riding film 0.10 m deep (`WaterField.DESCENT_CLAMP`).
   `CliffSlopeField._water_level` reported every film shallower than
   `WATER_SINK` (0.4 m) as dry, so `CliffSlopeEnvelope` treated the wet crest
   as a shore and dilated a rounded bank from it over the falling water. At
   the reported site 510 of 1,543 wet grid samples lay under the slope, in
   stripes along every tread edge ([map](cover_site-map.txt)): the "sheets on
   each tread". At the accepted September 15 P10 waterfall (-211, -1482) the
   same mechanism hid the fall: at x = -227 the envelope stood at 7.9 m over
   6-7 m water on ground 0 m; 303 of 924 wet samples and 3 centreline
   samples were covered ([map](cover_p10-map.txt)).

The water solver's ground and the rendered ground do differ (the envelope is
always at or above the heightfield), but the water field itself was
continuous; the defects were the source rule and the envelope's film
classification.

## Changes

- `WaterPlan`: a source fires only if its raw walk ends beyond
  `SUMMIT_REACH` (4 tiles, the radius inside which the walk may circle
  freely and where the outward drift starts). The raw walk moved into
  `_walk()` with its own cache so `has_source()` can read it. Only the orbiting
  sources change; every other trace, bed and junction prefix is identical
  (51/51 in the corpus). Their summit craters, channels and flank lakes
  disappear; the reported mountain keeps its natural 68-80 m ground.
- `CliffSlopeEnvelope` water-cap block (**cliff-owned file, minimal isolated
  change**): water no deeper than `WATER_SINK` over the node's ground is
  marked as a film. A film is neither a shore (no bank grows from it) nor a
  cut/receiver/rock cap; the slope keeps its own shape there.
- `CliffSlopeField._water_level` (**cliff-owned**): returns every supplied
  level, films included; the film decision moved into the envelope.
- `tests/test_p03_cliff_followup.gd` (**cliff-owned**): the film test now
  checks the preserved intent at envelope level (a film leaves the envelope
  identical to the dry build over a ledge) instead of the old sampler
  contract.
- `tests/test_water_terminal_datum.gd`: pinned source (0,1), which is the
  retired orbit, so it now checks the three nearby real rivers.

## Tests

Red first, then green: `tests/test_september27_mountain_water.gd` (3 tests):
every firing source leaves its summit (red: 4 cells); the reported mountain
is not excavated and (0,1) does not fire (red: 13 carved cells); a 0.1 m sill
film over an 8 m ledge does not grow a bank over the cascade and does not cut
its own crest (red: (1,0) buried 7.78 over 7.5 m water).

45 water/cliff test files, before vs after:
- Improved: `test_river_generation` 2 to 1 failing (the ">90% of headwaters
  run 2 km" ratchet, 0.865 before, now passes); `test_water_field_context`
  1 failing to green (the baseline failure was a transient compile error from
  another agent's file).
- Unchanged historical failures: `test_river_generation` (dry-diagonal
  test's pinned source is null on both), `test_september8_night_water_boundaries`,
  `test_september9_flat_water_profile`, `test_september9_water_profile_retention`,
  `test_water_contour` (3), `test_water_plan` (`test_carve_lazy_gates_match_reference`),
  `test_water_skin` (5), `test_september13_water_visibility` (no summary in
  either run).
- `test_p03_cliff_followup`, `test_september26_bedrock`,
  `test_september26_manual_cliffs`, `test_september19_bank_grass_water`,
  `test_september19_inner_water_ownership` and the new file pass (rerun after
  a concurrent cliff edit made the envelope briefly unparsable during the
  bulk run).

Envelope cover at P10 after the change: centreline hidden 3 to 0, grid hidden
303 to 276; the fall column and the two rows across the lip are open
([map](cover_p10_after-map.txt)). The remaining covered samples are side-bank
runout, which is intended ("slopes run into water, then sink").

## Renders

Real streamed sites in `cliff_site_review.tscn` (GUI, `sheet_bedrock` from
`world.tscn`). "Before" swapped in the pre-change `WaterPlan`, envelope and
field only for process start-up, then restored the working files unchanged.

- Reported site ([compare](renders/site-reported-compare.jpg),
  [overview](renders/site-overview-compare.jpg),
  [lifted](renders/site-lifted-compare.jpg)): before shows the pale water
  slab on stacked 12 m treads cut into the mountainside. After, the mountain
  keeps its natural 68-80 m ground and carries no water. The reported pose
  (player y 35.9) now lies inside that restored ground, so the after frame at
  that exact pose is the underside of the terrain; `lifted` repeats the pose
  with the player on the new surface (y 76.5). The overview is the matched
  comparison.
- P10 waterfall ([fall](renders/p10-fall-compare.jpg),
  [photo pose](renders/p10-p10-compare.jpg)): before, a mossy slope mound grown
  from the crest film sits in the fall; after, water crosses the lip as one
  sloped sheet over the wall into the pool.

Judgement limits: single frames at one time of day; no timed animation pairs
or player walks. The cascade reads as a clear sloped sheet (the existing
water design); there is still no whitewater or plunge spray.

## Open

- Long rivers that stop at the 2.4 km reach on a slope still end in a flank
  lake whose spill level can sit far below its end (e.g. seed 2697992464
  (-4,4): end gradient 0.34, excavation 28 m). Not reported here; same class
  of artifact at the far end of a river.
- Source pools on narrow summits still excavate 10-48 m (min natural height
  over the pool footprint). Unchanged.
- The owner's P03 cliff site is the reported crater; it no longer exists in
  the live world. Frozen P03 fixtures still carry the old inputs.
