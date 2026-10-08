# Town taste knobs: new defaults and owner checkpoint (October 7)

## In plain language

The nine taste knobs from this plan now ship at the values you asked for, so a new town
looks different by default:

- Courtyards are drawn toward the town field's lobes (where houses stand) and toward spots
  houses can front on several sides. It is a weighted draw, never a rejection.
- The plaza always keeps its walking ring (1.0). Other green clearings keep one only a
  quarter of the time, so most read as plain lawns with the walk kept only where doors and
  streets need it.
- Clearings are furnished (benches, planters, plants, lantern post, or stalls/crates/anvils
  by purpose) at 70 percent of capacity.
- Wells shrink to 0.7 of the kit size (chosen by eye, see below) and now stand only on
  ground-level greens.
- Satellite lobes sit 0.7 of the old distance from the core (spread 0.15).
- A suburban band of small detached cottages sits just outside the core: 1 for a compact town
  up to 4 for a grand one (spread 1).
- A cottage keeps a painted road only 20 percent of the time; otherwise it gets a footway
  (walkable, no worn-path paint) when its approach is open ground.
- Lamp posts are fixed dark wood (not a knob).
- `clearing_count` stays 0 by default (your call). The "after" renders use
  `--odds clearing_count=2.5` (large/grand) and `=1` (compact/standard) so clearings show.

Result: the town cores are tighter, a ring of small cottages stands apart from them, and
greens are looser and better furnished. Every evidence town still builds, with 0 floating
masses and 0 roof intrusions, and the court walks pass with 0 dead ends.

## Defaults

| Knob | Old (reproduces) | New default | Note |
|---|---|---|---|
| clearing_lobe_bias | 0 | 2.0 | all sizes |
| clearing_enclosure_bias | 0 | 2.0 | all sizes |
| plaza_ring_chance | 1.0 | 1.0 | unchanged |
| clearing_ring_chance | 1.0 | 0.25 | |
| clearing_deco_density | 0 | 0.7 | |
| well_scale | 1.0 | 0.7 | picked from 1.0 vs 0.7 close-ups (wells/well_1.0 vs well_0.7): 0.7 sits in the green instead of towering over the benches; 0.65-0.8 all read fine |
| satellite_reach_scale | 1.0 | 0.7, spread 0.15 | clamp 0.3..1.5 |
| suburb_house_count | 0 | small 1, large 4, spread 1 | RANGE_INT |
| lone_house_path_chance | 1.0 | 0.2 | |
| clearing_count | 0 | 0 | unchanged, owner decides |

## Before / after images

Before = commit ea4725fb9 with the old table. After = this commit. PNGs are gitignored and
live on disk under `docs/qa/2026-10-07-town-odds/taste/final/{before,after}/`
(`<seed>_<size>_<view>.png`; views overview, orbit0-3, street0-5, lamp0, plaza_0-2,
court_<id>_0-3). Towns: 53:grand, 31:large, 103:standard, 13:standard, 83:grand, 7:compact.

| Image | What it shows |
|---|---|
| `53_grand_overview.png` (before/after) | The core is more compact and crowded; two detached cottages now stand out in the lawn at the edge (the suburb band); street edges are no longer ragged with far satellites. |
| `31_large_overview.png` | A tighter core with a cottage ring and two lone cottages with footways, no painted roads. |
| `103_standard_overview.png` | Before: long painted road spurs to far cottages. After: a compact core, cottages and trees close by; one exterior clearing outside. |
| `103_standard_court_clearing.00_1.png` (after only) | An exterior clearing on open lawn outside the core: a tree, two benches, flowers and a plant on the grass, with a worn path on most sides. It has no fronting houses, so it is not the enclosed courtyard you described and it is not a ringless green; the walk stays on its open edges (effectively a ring). |
| `53_grand_plaza_1.png` (after) | The plaza: ringed lawn, tree, two benches, plants and flowers in the pools of grass under the arcade. |
| `*_plaza_*.png`, `*_lamp0.png` | Close-ups of wells (0.7 scale; wells only where the green stands on the ground) and dark-wood lamp posts. |
| `wells/well_1.0` vs `wells/well_0.7` | The size A/B behind the 0.7 pick (31:large plaza). |

## Audits

Production audit (payload, roof/public-air intrusion, floating masses), new defaults:

| Town | valid | floating | intrusions | parallel joins |
|---|---|---|---|---|
| 53:grand | yes | 0 | 0 | 0 |
| 31:large | yes | 0 | 0 | 0 |
| 103:standard | yes | 0 | 0 | 0 |
| 13:standard | yes | 0 | 0 | 0 |
| 83:grand | yes | 0 | 0 | 1 |
| 7:compact | yes | 0 | 0 | 0 |
| 43:large | yes | 0 | 0 | 0 |
| 3:standard | yes | 0 | 0 | 1 |

Same with `clearing_count=2.5` (53, 31, 83, 43) and `=1` (103, 13, 7, 3): all valid, 0 floating,
0 intrusions (83 and 3 keep their one parallel roof join, as with default clearings). Raw
rows: `final/audit_*.json`.

Clearings actually built with the override: 53:grand 0, 31:large 1 (green, blob, 2 links),
83:grand 2 (paved), 103:standard 1 (green, 4 cells), 13:standard 0, 7:compact 0.

Court walks (actual player, `--courts`), all `passed=true`, 0 dead ends:

| Town | odds | routes | dead-end nodes |
|---|---|---|---|
| 53:grand | default | plaza 2/2 | 0 |
| 53:grand | clearing_count=2.5 | plaza 2/2 (no clearing built) | 0 |
| 103:standard | default | plaza, deck 4/4 | 0 |
| 103:standard | clearing_count=1 | clearing, plaza, deck 6/6 | 0 |

Fingerprint: all 8 default towns build; the baseline is re-pinned to the new defaults
(`fingerprint/baseline.json`, source and payload hashes all changed, as expected).

## Two fixes this checkpoint needed

1. Clearing links (`WarrenCourtClearings.carve`): an extra link was searched against the same
   street network as the first, so two links could share lane cells and the volume plan
   refused the town ("duplicate walk cell"). 31:large with clearings on and the new defaults
   hit it. Extra links are now kept disjoint from the chosen ones (test
   `test_extra_links_never_share_lane_cells`). Default towns (no clearings) were unaffected.
2. `PublicWalkAudit.destination_cells` now counts a courtyard clearing as a destination. A
   4-cell green (12 ring cells, below the 16-cell overlook threshold) with one access lane
   was flagged as a "pathway to nowhere" (103:standard, `clearing_count=1`).

## Tests

Focused set, all green: test_town_odds 12/12, test_court_clearings 22/22, test_court_rings
4/4, test_clearing_deco 6/6, test_plaza_wells 5/5, test_lamp_finish 5/5, test_town_sprawl
8/8, test_town_character_wiring 4/4. Tests that pinned old behaviour now pin the knobs
explicitly via `tests/fixtures/town_old_look.gd` (`Old.merge(...)`): test_court_clearings,
test_court_rings, test_clearing_deco; test_town_sprawl pins its three knobs through its
`DEFAULTS`; test_plaza_wells now asserts the default well scale is 0.7. `test_default_table_
proposes_and_carves_no_clearings` still reads the real table. New:
`test_shipped_defaults_are_the_taste_values`.

Also run: test_town_destination_agreement (2/3) and test_town_public_walk_dead_ends (2/3
now, 1/3 before) fail on seed 141 / a photo town with "macro setback roof ... rejected";
the same failures reproduce at ea4725fb9 with the old table, so they are older than this
change (a 24-seed production-size build sample: 1 failure under the new defaults, 1 under the
old ones, a different seed, so no extra failure rate from the knobs).

## Known limits

- The enclosure pull is a weighted draw, so it still allows exterior clearings with no fronting houses (103:standard's clearing is one). Ringless only drops walk on edges facing built mass; an isolated clearing keeps walk on its open edges, which reads as a ring.
- Clearing supply is low: with the new biases and `clearing_count` 2.5 or 1, 53:grand,
  13:standard and 7:compact grew none; more needs a higher count. A lower bias does not
  help: the pulls cost no built clearings (see "Do the pulls reduce clearings built?").
- Wells are rare: only ground-level greens qualify, and the plaza is often raised.
- Raised clearings keep their edge walk (a ringless raised green still needs it for the guards).
- Paved courts read as storage (crates, barrels, stall) rather than squares; deco is
  purpose-driven and low-density.
- A ringless green's lawn reaches house walls; some house doors meet the lawn directly with
  only a one-cell strip.
- Seed 1 / grand (`for_id`) no longer builds under the new defaults: the same hard setback-roof gate that already rejects seed 141 at d912cd332 ("macro setback roof ... rejected") now rejects a core wall-room roof there. Either satellite_reach_scale=1 or suburb_house_count=0 alone avoids it, so it is a shifted town hitting an existing roof/public-air gate, not a rule added by this plan. Sample: 64 production-size towns, 1 failure under the new defaults (and 1 under the old: seed 141); d912cd332's own corpus had 6/grand with one dead end. Not fixed here. Fixed October 8: the roof gate withdraws the room instead (docs/qa/2026-10-08-roof-proportion/result.md).


## Do the pulls reduce clearings built? (final review, October 8)

Measured on the eight fingerprint towns with `--odds clearing_count=3` and both pulls
overridden together (`clearing_lobe_bias` = `clearing_enclosure_bias`), every other knob at
its shipped default. Proposed = carved `court_clearings`; built = `clearing.NN` deck plots
(`CLEARINGS` / `CLEARING_PLOTS` lines of `tests/harness/town_fingerprint.gd`).

| town | bias 0 carved / built | bias 2 carved / built |
|---|---|---|
| 53:grand | 0 / 0 | 0 / 0 |
| 31:large | 1 / 1 | 1 / 1 |
| 13:standard | 0 / 0 | 0 / 0 |
| 43:large | 3 / 3 | 3 / 3 |
| 83:grand | 3 / 3 | 3 / 3 |
| 103:standard | 3 / 3 | 3 / 3 |
| 7:compact | 1 / 1 | 1 / 1 |
| 61:standard | 1 / 1 | 1 / 1 |
| total | 12 / 12 | 12 / 12 |

The pulls change WHICH clearings are taken (43:large: a floor-4 paved court instead of a
floor-6 one; 83:grand two_rect courts instead of a three_rect; different shapes in 103 and
61), never how many: every carved clearing became a plot under both settings, and the
towns short of three (53, 13, 31, 7, 61) are short at bias 0 as well -- candidate supply,
not the pulls, limits them. The pull fallback (best-kept rejected clearings fill a short
draw) already keeps the count; no carve/placement fall-through was needed, and the shipped
defaults (2.0 / 2.0) stand. Bias 0 is untouched (old-look source pin below).

## Old-look pin (final review, October 8)

`docs/qa/2026-10-07-town-odds/fingerprint/old_look_baseline.json` is the fingerprint of the
eight towns at d912cd332 (the commit before the taste work, built in a /tmp worktree).
Under `tests/fixtures/town_old_look.gd` values today's tree reproduces all eight SOURCE
hashes exactly (no legitimate source differences: disjoint clearing links are inert at
`clearing_count` 0). Payloads match for 13, 103, 7 and 61 and differ for 53, 31, 43 and 83
(the towns with lamps: every lamp is dark wood now). Compare:

    godot --headless --path . -s res://tests/harness/town_fingerprint.gd -- --old-look \
      --compare res://docs/qa/2026-10-07-town-odds/fingerprint/old_look_baseline.json --parts source

`tests/test_town_old_look.gd` checks 7:compact and 103:standard in the suite;
`test_town_sprawl::test_old_values_reproduce_the_pre_sprawl_field_exactly` pins the town
field of four towns to d912cd332.
