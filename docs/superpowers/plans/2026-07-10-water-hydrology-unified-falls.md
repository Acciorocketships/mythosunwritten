# Water Hydrology + Unified Falls — Experimentation & Implementation Plan

**Date:** 2026-07-10
**Status:** Approved direction (owner review of the boundary-mesh build, 5 annotated screenshots)
**Amends:** `docs/superpowers/specs/2026-07-09-water-boundary-mesh-design.md`.
The mesher (marching squares, welded indices, hem) and the shader/swim layers
stay; this plan replaces the FIELD's claim logic with computed hydrostatics
and deletes discrete waterfalls in favour of a continuous steep surface.

## Owner-reported issues this plan must kill

(Reference positions are from the owner's F3 overlays, seed 2697992464.)

- I1 — a waterfall stands where the terrain has only slopes, no >4 m cliff
  (player (53.0, 7.2, -1083.9), the 8 m cut near (57.7, -1082.5)).
- I2 — an oddly-shaped water blob spills onto a bank ABOVE the adjacent
  surface; sharp polygon edges; walking through it is not detected as water
  (player (70.1, 4.0, -1140.5)).
- I3 — a dry hole inside an otherwise full lake (player (9.3, 0.0, -1120.6),
  ground 0, lake level ~3).
- I4 — a dry wedge with sharp corners at a wall inside a pool; unbounded
  water must have curvy perimeters (player (36.4, 2.8, -1108.7)).
- I5 — waterfall dent/gap: the curtain stops short, the sheet beside it has
  a gap; the fall reads as a plane while the water is a blob
  (player (33.9, 10.8, -1099.0)) — and the character standing on that bank
  thinks it is in water.
- I6 — swim/land misclassification in both directions (I2: real water not
  detected; I5: dry bank detected as water).

## Root-cause hypotheses (each with a falsifiable prediction)

- H1 (→I1): falls are detected on the TRACE BED profile; containment clamps
  quantize the bed into storey steps, so the bed can drop 8 m where the
  rendered terrain only slopes. Prediction: dumping `trace.beds` vs
  `TerrainSurfaceField.surface_y` along the channel through (57.7, -1082.5)
  shows a bed window-drop > 4 m where the surface never drops > 4 m in any
  24 m window.
- H2 (→I2): `level_at`'s nearest-claimant pick at meanders selects an
  UPSTREAM (higher) sample for bank points; the flood extension then paints
  the bank at that higher level. Prediction: at (70, -1140) the claimant
  sample's level exceeds the level of the hydraulically adjacent channel
  sample, and the blob's boundary follows the claim radius (straight cuts),
  not a terrain contour.
- H3 (→I3): the flood depth gate (`FLOOD_DEPTH_MAX = 2.5`) amputates basin
  bottoms deeper than 2.5 m; the 24 m flood radius also cannot reach far
  sides of wide pockets. Prediction: at (9.3, -1120.6), `level_at` returns
  −INF while ground (0) sits ~3 m below the surrounding claimed level (3).
- H4 (→I4): tributary profiles are never pinned to the main stem
  (junction-continuity gap); between two claimants with different levels a
  sliver satisfies neither claim. Prediction: claim dumps along the wedge
  show two claimant traces with a level disagreement bracketing a −INF gap.
- H5 (→I5): the fall curtain is swept only from generated cut vertices, so
  it ends before the waterline contour turns into the bank; the sheet's two
  cut sides leave uncovered free faces at the flank. Prediction: the cut
  record's lip end-vertices sit > 1 lattice step from where the upstream
  waterline contour meets the cut line.
- H6 (→I6): volumes are built wherever CLAIMS said water — bank-claim blobs
  produce volumes over land (I5's bank: an upper-level claim covers the
  cell; box contains the player; maxf gating reports surface 13.7), and
  flood-only cells anchored to a different sample under-report real shallow
  water (I2). Prediction: headless containment math at the two exact player
  positions reproduces both misclassifications with current build_chunk
  output.

Root cause behind H2/H3/H4: the field's wetness is CLAIM GEOMETRY (nearest
sample + radius + depth gate), not hydrology. There is no randomness in the
water heightmap itself; the arbitrariness is these gates. Fix = compute the
static surface the way water behaves; keep the animated swells as the only
stochastic layer (owner's static/dynamic split, confirmed).

## Phase 0 — Diagnostics first (fix-independent oracles)

Everything in this phase is built BEFORE any fix and expresses the ISSUE,
not the fix — these are the falsifiers later phases must satisfy, and they
must fail (red) on the current build where the owner saw the issue.

Create `tests/tools/hydro_probe.gd` (headless SceneTree tool, pinned seed):

1. `--path` A: profile-vs-terrain dump along the trace through
   (57.7, -1082.5): per sample print bed, level, surface_y at the point, and
   the 24 m window drops of each. (H1 evidence.)
2. B: claimant dump on a 1 m grid over each owner rectangle
   (I2: (58..84, -1152..-1128); I3: (0..24, -1132..-1108); I4:
   (24..48, -1120..-1096)): claimant trace id/sample, level, ground, wet.
   (H2/H3/H4 evidence: wrong-sample claims, −INF holes with low ground,
   dual-claim gaps.)
3. C: lip-coverage check per cut record: distance from each lip end to the
   nearest upstream boundary-contour vertex on the cut line. (H5.)
4. D: volume containment math at the two player positions
   ((70.1, 4.0, -1140.5) expect in-water TRUE post-fix; (33.9, 10.8,
   -1099.0) expect in-water FALSE post-fix) via build_chunk output — the
   same math `character.gd` uses. (H6.)

New standing oracles appended to `tests/test_water_field.gd` (RED now, GREEN
after Phase 1 — written against the ISSUE definition, no fix knowledge):

- `test_no_dry_holes_inside_water`: for every lattice sample S in the site
  chunks with `level_at(S) == -INF`: no 4-connected neighbour sample may be
  wet with a level ≥ ground(S) + 0.3. (A dry sample bordered by water
  standing above its own ground is a hole — I3/I4.)
- `test_water_never_stands_above_its_source`: every wet sample's level must
  be ≤ the level of the channel/pond sample it is connected to (walk the
  fill provenance; in the current build, assert per-claim: claimed level ≤
  max level among trace samples within the channel that the claim's
  connected region touches). (I2.)
- `test_waterline_is_a_terrain_contour`: for every boundary vertex not on a
  chunk border: |level − surface_y| ≤ 0.6 OR the ground within 1.5 m on the
  dry side rises above the level (wall). (Sharp radius-cut edges fail this;
  terrain-contour edges pass — I2/I4 "curvy perimeter".)

In-game falsification battery additions (`tests/tools/review_vantages.json`):
add the owner's five annotated frames verbatim (player+crosshair pairs from
the screenshots). Every later phase re-shoots ALL of them; the reviewer
instruction is "prove the issue is still there", not "confirm the fix".

Exit gate for Phase 0: all four probes reproduce their predicted evidence;
the three new tests are RED at HEAD at the predicted sites. Any hypothesis
whose prediction FAILS gets revised before its fix phase is planned in
detail (that is the experiment part of this plan).

## Phase 1 — Hydrostatic fill (replaces claim logic)

`WaterField` gains a per-chunk-neighbourhood rasterized surface:

- Seeds: for each trace sample, mark lattice samples within the CHANNEL
  (distance ≤ widths[i]) wet at `profile.levels[i]`; pond footprints wet at
  `pond.surface_y()`.
- Fill: BFS/queue over the 3 m lattice (chunk + margin): a dry sample
  becomes wet at level L when 4-adjacent to a wet sample of level L and
  `surface_y < L − EPS`. Unlimited distance, no depth cap. Where two levels
  reach one sample, the LOWER wins (water drains to the lower connection);
  re-relax on lower arrivals (standard shortest-path style, keys are
  levels).
- `level_at(ctx, p)` = bilinear over the filled lattice (−INF outside);
  `wet` likewise. `flow_at`/`grade_at` unchanged (channel-based).
- Junction continuity (H4): in `profile()`, a `joined` trace's tail eases
  onto the stem: final sample level := stem's level at the join point
  (lazily via the stem's own profile; memoized; monotone clamp preserved).
- DELETE: `CLAIM_FEATHER`-beyond-channel logic, `FLOOD_EXT`,
  `FLOOD_DEPTH_MAX`, the region-gated flood extension, `_claim`'s margin
  competition (only channel membership + fill remain).
- Perf note: fill runs once per ctx (worker thread), O(lattice) with a
  small queue; budget ≤ 15 ms per chunk — measure in Phase 0's harness
  first; if the 3 m lattice fill exceeds budget, fill at 6 m and bilinear
  down (decide on data, record in the ledger).

Tests (in addition to Phase 0's oracles turning GREEN):
- Monotone/continuity suite from the existing field tests stays green
  (profiles unchanged except junction easing — the continuity probe's jump
  count may DROP; tighten the bound accordingly).
- `test_fill_is_deterministic_across_chunks`: neighbouring ctxs agree on
  shared-lattice levels bit-exactly (seam identity depends on it).
- Owner-position probes (Phase 0.D) flip to their expected values.

Visual gate: the five annotated frames + the standard battery; I2's blob
must be gone or terrain-contour-bounded; I3's hole filled; I4's wedge wet
with a curvy line; no NEW dry holes or floaters anywhere in frame
(falsification wording in the review step).

## Phase 2 — Unified falls (continuous steep surface; delete cut machinery)

- `profile()`: no cuts. Where the terrain (not the bed) demands descent, the
  level follows: `levels[i] = max(raw_i, terrain_min_i + STANDOFF)` is NOT
  the rule — instead: monotone descent with slope shaped by the RENDERED
  ground along the channel: sample `surface_y` along the segment; where the
  ground's 24 m window drop exceeds FALL_DROP_MIN, the profile descends
  steeply hugging the face (per-sub-sample: level = clamp(level_prev,
  ground_path + FILM (0.3), level_prev) descending to the downstream
  level, with C1 easing over ~2 m at lip and base — the 1D ogee). Falls are
  now a PROFILE SHAPE, not an object. `fall_cuts` is deleted; a new
  `steep_spans(ctx, rect)` (lip point, direction, drop) feeds ONLY the
  shader churn band and (later) mist — no geometry.
- Mesher: delete `_cell_cut`, `_mesh_cut_cell`, `_synth_cut`, `_lvl_side`,
  `_cut_vert`, `_register_cut_hit`, the multi-seam guard, `cut_records`,
  CUT_JUMP-based splitting (levels are continuous now; adjacent-sample jumps
  cannot exceed the profile's max slope). `_near_cut` hem exemption dies
  with it (falls are ordinary sheet + hem now). The triangle-span invariant
  is replaced by a max-slope sanity bound (surface faces ≤ ~85°).
- FallMesher.gd: DELETED. Waterfall material/shader: the sheet shader gains
  the falling-look blend keyed continuously on steep_v (scroll ∝ slope along
  flow dir, foam by slope, the existing plunge churn keyed on
  `steep_spans`); `waterfall.gdshader` retired after the blend matches.
- Swim volumes: cells whose max grade exceeds a threshold get NO volume
  (steep water is not swimmable) — deletes the split/stacked-volume
  machinery (wet_cells back to one entry; keep the min-ground floor and the
  plane metas).
- Character (I6 + wading): `in_water` requires depth at the character's xz
  (`surface − ground`) > 0.8 in the containing volume's plane sample;
  shallower contact sets a (new, minimal) `wading` flag that does NOT switch
  movement but can drive effects later. Bank cells no longer have volumes at
  all post-Phase-1, so the I5 misclassification dies twice.

Tests:
- Field: every adjacent-sample level difference ≤ MAX_SLOPE·S (continuity
  by construction — the invariant that replaces CUT_JUMP splitting).
- Mesher: free edges = border|buried only (no cut class left); winding +Y
  for ALL non-hem triangles (exemption list shrinks); steep faces ≤ 85°.
- The I1 oracle: no steep-span (fall look) where the ground's 24 m window
  drop < FALL_DROP_MIN along the channel — directly encodes the owner's
  ">4 m only" rule against the TERRAIN.
- Swim: no volume on steep cells; wading/swim gate unit probes at pinned
  points (owner positions again).

Visual gate: fall sites from the battery + behind/side/base angles; the
"only slopes" site (I1) must show chute texture with NO curtain; the 8 m
cliff (if the terrain probe confirms a real one nearby) shows a steep
continuous face with fall texture; I5's dent/gap class extinct (single
mesh). Plane-vs-blob: the fall region must visibly share the sheet's body
(refraction/foam), verified at the owner's screenshot-5 frame.

## Phase 3 — Cleanup + full battery

- Deletion sweep of retired symbols/files (FallMesher, cut tests →
  re-expressed, waterfall shader if fully retired), AGENTS.md + memory
  updates, straggler grep.
- All suites + the full vantage battery INCLUDING the five annotated owner
  frames, natural + `skirt_debug` (still valid: water with no volume under
  it… note volumes now absent on steep cells — teach skirt_debug to treat
  steep faces as expected) + the hole/overflow oracles.
- Falsification review wording (binding, from the owner's process rule):
  each frame is reviewed to PROVE the annotated issue is still present;
  only failing to find it counts as fixed. Anything that "looks like" a
  prior artifact IS the artifact until identified otherwise.

## Verification principles (apply to every phase)

- Red-first: every oracle/test lands before its fix and must fail at the
  pre-fix HEAD at the predicted site (else the hypothesis is wrong —
  revise, don't proceed).
- Test + visual: suites green AND the battery frames reviewed
  falsification-first at the owner's exact coordinates.
- Independence: oracles are written from the issue definitions above, never
  from fix internals (no mirroring fix formulas into asserts where an
  issue-level property exists).

## Open questions (resolved by Phase 0 data, not upfront)

- Fill lattice resolution (3 m vs 6 m) — perf measurement decides.
- MAX_SLOPE / face angle for unified falls (start ~80°, judge visually).
- Whether any true vertical cliffs need a local "double sample" column to
  avoid a visible slant — decide at the 8 m site with real data.
- Wading polish (splashes, slow-walk) — out of scope; only the flag lands.
