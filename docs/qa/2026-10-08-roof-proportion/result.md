# Roof proportion guardrail and roof withdrawal (October 8)

## In plain language

**Defect A, the "apartment building" roof (31/large).** The tall orange roof in
`taste/final/after/31_large_overview.png` was not a house. It was an enclosed
bridge-house (skywalk `kit.skywalk.2.6.-3.0.1`) that crosses a lane one module
(2 m) wide and eight modules (16 m) long. A one-module bridge-house turns its ridge
across the span (the owner's earlier "tiny roof" ruling made short bridges read as
gatehouses), so its roof spanned all eight modules. Roof height grows with span, so
that roof stood 12 m tall on a 2 m ridge, and the gable infill was four storeys of
windowed timber: the "apartment building" face. Short bridges (two to four modules)
are fine; an eight-module one is not.

Note: that render used `--odds clearing_count=2.5` (as all taste "after" renders do);
under the shipped defaults (`clearing_count` 0) 31/large builds a different core and
has only a four-module gatehouse, which is within the limit.

**What the guardrail does.** Every kit pitched roof must pass one geometric check
(`BuildingDesigner.roof_proportion_ok`): its gable may expose at most two storeys,
and the roof may stand at most three times as tall as its ridge is long. A roof
that fails is never a reason to drop the town:

- a one-module bridge-house too long for one transverse roof gets a row of small
  transverse gables (two modules each, three for the odd last one), each 3-4.6 m
  tall, instead of one 12 m gable;
- a house wing that fails turns its ridge, becomes a double pile, or becomes a
  railed terrace (the same fallbacks a roof that hits kept-clear space already had).
  No current house roof fails, so no house changes.

**Defect B, towns that returned null (1/grand, 141).** Both died at
`macro setback roof ... and its complete fallbacks were rejected` in the fabric
roof compiler. In 1/grand a one-column wall-room's upper storey
(`house.wall-room.001.part01`) had grown sideways under a bridge-house end that
starts one band above it, with a public deck's support stone over the other half:
one band of air, and no roof in the vocabulary fits one band beside public air. In
141 the upper part of `house.009` could not take a roof that did not run into its
neighbour's tower roof. This is a real generator issue, not an obsolete test: the
roof gate was acting as a town veto.

**What the fix does.** The roof gate now withdraws the piece instead of the town.
When the roof compiler fails on one room, it names that room
(`WarrenSpatialFabricCompiler.last_failure_room_id`); the volumetric solver marks the
room's cells with the composition planner's existing room-support clearance token
(the same mechanism that already ends an optional crown under a hero feature) and
composes the same source again (`WarrenVolumetricSolver.compose_maze_source`). The
room's storey and anything standing on it are not built; everything below stays. A
room the town cannot do without (a required door, market or bridge course) still
fails the town, as before. At most four withdrawals. Towns that built before are
untouched: their first composition is the old one, byte for byte.

## Before / after images

PNGs are gitignored; they are on disk under `docs/qa/2026-10-08-roof-proportion/`.
Rendered with `kit_town_review` (same cameras before and after):

    Godot --path . -s res://tests/harness/suntail/kit_town_review.gd -- \
      --output <dir> --cities 31:large --views overview,orbit --odds clearing_count=2.5

| Image | What it shows |
|---|---|
| `before/31_large_overview.png`, `after/31_large_overview.png` | Owner's camera. Before: the tall narrow gable at centre-left. After: the bridge carries a row of four small gables at the height of its neighbours. |
| `before/31_large_orbit1.png`, `after/31_large_orbit1.png` | Closest view of the bridge: the four-storey windowed gable is gone; the small gables read as one row with the houses either side. |
| `before|after/31_large_orbit0,2,3.png` | Other sides; nothing else changes. |
| `withdrawal/1_grand_{overview,orbit0-3}.png` | 1/grand, which produced no town before. |
| `withdrawal/141_standard_{overview,orbit0-3}.png` | 141 at production size (`--production-size`), which produced no town before; house.009 is now one storey with its own roof beside the tower house. |

Production audit (payload validity, roof/public-air intrusions, floating masses) on
the two rescued towns: 1/grand valid, 0 floating, 0 intrusions (2 parallel joins);
141 valid, 0 floating, 0 intrusions (1 parallel join).

## 64-town production sample

Sample: the 24 corpus towns (seeds 1-6 x compact/standard/large/grand, `for_id`)
plus production-size seeds 101-140, plus seed 141 (65 towns, shipped defaults).

| | failed |
|---|---|
| before (HEAD 291bd6a13) | 2: 1/grand and 141 (both the setback-roof gate) |
| after | 0 (1/grand and 141 each built after one room withdrawal) |

"Before" is exact by construction: a town's first composition is unchanged, and the
two towns that needed a withdrawal are exactly the two that returned null before
(both failures were also reproduced directly on HEAD).

## Tests

- New `tests/test_roof_proportion.gd` (red first: gap 5-8 bridges and 31/large with
  clearings failed; green after): bridge-houses of every gap keep proportioned roofs
  covering every bay; gap 2-4 keep their one gatehouse roof; five built towns
  (31/large with and without clearings, 53/grand, 13/standard, 7/compact) have no
  out-of-proportion roof.
- New `tests/test_town_roof_withdrawal.gd` (red first: both null): 1/grand and 141
  build, are sealed, carry a compiled fabric, and 1/grand records its withdrawal
  (`roof_withdrawn_room_ids` in the plan audit).
- `test_town_public_walk_dead_ends`: the `pending()` skip for 1/grand is removed;
  the corpus test runs all 24 towns again.
- Focused suites after both changes: test_town_public_walk_dead_ends 6/6 (corpus now
  includes 1/grand), test_court_clearings 22/22, test_town_sprawl 8/8,
  test_town_old_look 1/1, test_september29_roofline_variety 8/8,
  test_town_destination_agreement 3/3 (was 2/3: its photo town hit the same gate),
  test_enclosed_skywalk_ceiling 2/2, test_backed_shed_roofs 6/6,
  test_kit_roof_junctions 9/9, test_roof_proportion 3/3,
  test_town_roof_withdrawal 2/2. test_september29_town_edges 5/6: the 3/standard
  rim-stone assertion (13 of 96) fails identically on HEAD 291bd6a13 (pre-existing).
- Sample script and output: `sample64.gd.txt`, `sample64_after.out`; audit rows:
  `audit_withdrawal.out`.
- Fingerprint: `town_fingerprint.gd --compare .../fingerprint/baseline.json` prints
  FINGERPRINT_MATCH after both changes (no default fingerprint town has a long
  one-module bridge or a withdrawn room), so the baseline is not re-pinned. The
  old-look pin (`test_town_old_look`) compares source plans only and is unaffected.
- Pre-existing failures, identical before and after: `test_october2_range_roofs`
  (3 tests, 7742/7760 asserts) and `test_parallel_roof_consolidation` (103/grand
  ridge continuity).

## Known limits

- Four-module one-wide gatehouses sit exactly at the slenderness limit (6 m roof on a
  2 m ridge). They pass, by design, to keep the reviewed gatehouse vocabulary; if the
  owner finds them tall too, lowering `MAX_ROOF_SLENDERNESS` to 1.5 turns them into
  piles as well (it changes 31/large and 53/grand defaults).
- The row of small gables over a long bridge is the existing double-pile vocabulary;
  it is lower and in proportion but reads as a sawtooth. A covered-bridge roof with a
  ridge along the span would need a deeper (two-module) bridge.
- Withdrawal recomposes the whole town once per withdrawn room (1/grand: about 96 s
  to 150 s). It only runs for towns that would otherwise have no town.
- `kit_town_review` and other harnesses that use `tests/fixtures/frozen_maze_source.gd`
  now go through the same withdrawal path.

## Follow-up: one long gable instead of the row (owner ruling)

**The ruling.** The row of side-by-side transverse gables over the long bridge read as
a sawtooth. The owner asked for ONE long gable running the other way (ridge along the
span), made interesting with dormers or similar kit details.

**What changed.** `KitVillageBuildings._skywalk_mass`: a one-module bridge-house whose
transverse gatehouse roof fails `roof_proportion_ok` (gap 5 and longer) now turns its
ridge along the span and keeps a single roof over every bay. Bridges of two to four
modules keep their one transverse gatehouse roof (the earlier "tiny roof" ruling), and
house roofs are unchanged. The long roof is 1.62 m tall over a 16 m ridge, well inside
the guardrail.

**Why no dormers.** A roof one module (2 m) deep is the kit's ridge-top course alone
(`roof_profile(1)`: zero eave rows, only `roof.<colour>.top`). The kit's only dormer is
an eave-row piece (`suntail.roof.roof_1_cornice_w_*`, role `eave_dormer`) that replaces
one module of the first slope row, so it exists only on roofs at least two modules deep;
the Suntail pack has no standalone dormer. Fitting one would mean scaling a piece or
widening the roof past the bridge walls, both ruled out. The closest legitimate details,
both pieces the kit already uses on house roofs, are on the ridge:

- crest finials along the ridge (`trim.ridge_peak`, `ridge_peaks = true`), the iron
  cresting some house ridges carry;
- a rubble chimney stack straddling the ridge at mid-span (`chimney`, `chimney_u` = the
  middle bay). `KitRoofMeshUnion.fit_chimneys` moves it along the ridge or withdraws it if
  it meets anything (31/large: kept, `chimneys` checked 4, moved 0, omitted 0); a detail
  never rejects the bridge or the town.

The gables face the bridge ends. In 31/large both ends meet same-eave endpoint roofs, so
`KitRoofJunctions` opens them into the host roofs (`open_min`/`open_max`); the gallery
roof runs into its neighbours rather than ending in two small gables.

**Images** (on disk, `long_gable/`, same `kit_town_review` command and cameras as
`before/` and `after/`, plus close views):

| Image | What it shows |
|---|---|
| `long_gable/31_large_overview.png` | Owner's camera. The bridge is now a long low roof with a chimney at mid-span, between the taller house roofs; no sawtooth. |
| `long_gable/31_large_orbit0-3.png` | Same orbit cameras; `orbit1` is the closest overview of the bridge. |
| `long_gable/31_large_bridge_close.png` | Close oblique (`--view bridge_oblique:-12,38,-14:8,22,6:60`): the covered gallery with its windowed side, ridge cresting and chimney; both ends run into the endpoint roofs. |
| `long_gable/31_large_bridge_side.png` | Side view from the courtyard (`--view bridge_nx:-14,30,10:8,22,6:55`). |
| `long_gable/31_large_skywalk*.png` | The harness's automatic skywalk cameras; most start inside neighbouring houses and are not useful. |

Judgement: the bridge reads as one covered gallery in proportion with its neighbours.
Seen from close above, the finials read a little like a fence rail along the ridge; if
the owner prefers a plain ridge, drop `ridge_peaks` and keep the chimney.

**Tests.**

- `test_roof_proportion` (red first: 3 of 4 failed, gap 5-8 had 2-4 roofs and the
  31/large bridge 4; green after, 4/4, 115 asserts): every gap 2-8 bridge has one roof
  covering every bay; gap 5-8 have their ridge along the span with chimney and finials;
  gap 2-4 keep the transverse gatehouse; the five towns have no out-of-proportion roof and
  the 31/large (clearings) bridge `kit.skywalk.2.6.-3.0.1` has one along-span roof.
- test_town_roof_withdrawal 2/2, test_september29_skywalks 5/5,
  test_september29_roofline_variety 8/8, test_kit_roof_junctions 9/9,
  test_enclosed_skywalk_ceiling 2/2, test_backed_shed_roofs 6/6.
- `town_fingerprint.gd --compare docs/qa/2026-10-07-town-odds/fingerprint/baseline.json`:
  FINGERPRINT_MATCH (no default fingerprint town has a bridge of five or more modules),
  baseline not re-pinned.
