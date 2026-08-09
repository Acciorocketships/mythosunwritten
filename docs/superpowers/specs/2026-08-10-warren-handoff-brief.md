# Warren Towns — Handoff Brief

**Date:** 2026-08-10
**For:** a fresh agent taking over the warren-town visual iteration.
**Branch:** `feat/mass-first-warren` (pushed; `main` still ships the untouched
route-first pipeline behind `WarrenTownSolver.GENERATION_MODE`, default
`route_first`, A/B-verified at every shared-file change).

Read next, in order: this file; the reviewer-notes section below (it is the
spec that outranks every other spec); `docs/superpowers/specs/
2026-08-06-mass-first-warren-design.md` and `2026-08-09-warren-terrain-
integration-design.md` and `2026-08-10-warren-terrace-tunnel-motif-design.md`;
then the decision ledger `.superpowers/sdd/2026-08-06-mass-first-warren/
progress.md` (untracked, ~200 entries — the complete evidence trail; task
reports task-1..26 sit beside it).

## 1. Where the project actually stands

Three eras exist on this branch, and the reviewer's latest feedback is best
understood as: *each era got one thing right that the others lost.*

**Era A — route-first (ships today, `main` + default mode).** Towns of 10-16
buildings packed around a carved route. KEEP-worthy: prefab building anchors
(`TARGET_PREFAB_ANCHORS`), 3-6 roofed skywalks per town, 12 dormered outcrop
bays, markets, the full style system, and the acceptance/showcase machinery.
Known truth surfaced late: no route-first town has ever met its own visual
targets — it ships on best-effort selection.

**Era B — thick massif ("the stone mountain", commits around `33b80f0`..
`c21f428`).** A 16-20 band solid, streets bored through it (55-70% of route
cells carried mass overhead IN DATA), houses partitioned on the carved flanks.
The reviewer HATED the skin (stone monolith, towers) but has now said
explicitly what was RIGHT: houses close enough to touch, streets genuinely
bounded, "the pathway snaked through the mountain itself, lined with
buildings." Density and bounded-ness were structurally correct.

**Era C — terrain + thin layer (current HEAD).** The hill is real heightfield
(stamped via `SettlementReliefPlan`, meshed/cliff-dressed/collided by the
production terrain stack); houses are a 4-6 band buildable layer, honestly
grounded (0 floating of 559; per-column sampling; 216 foundation plinths that
now draw). KEEP-worthy: everything about grounding, terrain, plinths, the
375-asset catalog, the harness discipline. LOST: density — towns are isolated
hamlets (~20 houses, median 1 lane), nothing stands over any street (0
INTERIOR_PASSAGE cells at fabric level), and the reviewer sees "buildings too
isolated to form any kind of path."

## 2. The reviewer's cumulative doctrine (latest notes first — they supersede)

Latest round (2026-08-10, verbatim digests):
1. **Too much stone at the base.** Rock ground-storeys + plinths read heavy.
   The 56 timber wall variants baked earlier make timber-to-ground styles
   possible; ground-storey rock should become one style among several, not
   the universal base. Plinths stay (they are the sanctioned stone) but the
   default look should lighten.
2. **Height gradient, not height cap.** "Buildings at the centre should be
   several stories higher than the ones at the edges." This EVOLVES the older
   "never more than 2-3 storeys" rule, which was a reaction to uniform
   8-storey towers: the standing requirement is now a BELL GRADIENT of
   building height (tall centre, 1-2 storey rim) with facade breaks — a
   composed face may rise beyond 3 storeys only if it breaks every 2-3
   storeys via jetty/setback/material/roofline change. Uniform tall slabs
   remain forbidden; graded stacked mass is wanted.
3. **Size/style variety missing; the "interesting buildings" from the asset
   survey never appear.** Complete prefab buildings exist in the packs
   (`aws_building_003` is already baked; taverns/forges/etc. surveyed in the
   ledger's inventory entry) and route-first's prefab-anchor mechanism was
   never wired into mass-first.
4. **Features:** skywalks — the reviewer's definition is "roofed tunnels
   connecting two or more buildings" (exactly the existing `skywalk.3/6/9`
   recipes, which era-A towns placed 3-6 of); dormers — "there used to be
   more" (era-A placed 12 outcrop bays; the thin layer places few).
5. **Density (the big one):** era-B's touching buildings and bounded snaking
   paths were "a step in the correct direction"; current towns cannot form
   that.

Standing from earlier rounds (still binding): city = catalog assets only, no
primitive boxes; stone hidden as substrate is fine where covered, bare stone
faces ≤ 2 bands; mountain character wanted; chaos over regularity; paths
mostly covered — "tunnels underneath skywalks and other buildings"; terrain
cliffs question OPEN (see §5).

## 3. The failure catalogue — do not retry these

Seven mechanisms for covered streets / height were closed WITH MEASURED
EVIDENCE (ledger has full numbers; one line each here):
1. Bridging houses over streets (thick massif): need 9 bands above street,
   bore leaves 1-8 — zero legal sites in every frontier.
2. Skywalk seeding: supply is not the binder; roof overhangs (0.23-0.36 m
   proud, tolerance 0.10) refuse the envelopes one storey up.
3. Route-height caps: refusals migrate from height to bearing; zero bridges
   at every setting.
4. Storey caps on the thick massif: break street-wall ownership outright.
5. Thin-layer surface streets: 4-6 band layer minus 3 headroom leaves ≤3
   bands — no house fits over a street; arithmetic, not tuning.
6. Sunken streets into terrain: a heightfield HAS NO HOLES — terrain cannot
   render a tunnel; and the fabric-side sweep gave 41 tunnel columns with
   ZERO street-wall faces while breaking four pinned floors.
7. Whole-hill stone rendering / earth-skin boxes: both rejected by the
   reviewer on sight (monument; "boxes look awful").

Also calibrated and settled (do not re-litigate without new evidence): the
excavation wall gate 0.70; two subdivision-invariant metric re-derivations
(contact by footprint cells; isolation by cell share); the corner-inside-cap
`max(36, ceil(1.2 × walk_cells))`; grade floor 9 cells (measured, arcade
integration test is the authority); MIN_SPAN 5 in the thin layer (8 gives
zero towns).

## 4. Brainstormed directions (mining every era)

**D1 — The inhabited massif (recommended core).** Era-B's structure with
era-C's skin: bring back a THICK buildable mass (crown 10-16 bands), but
partition its FULL VOLUME into vertically stacked, individually styled 1-3
storey houses — jetties, setbacks, material and roofline breaks at every
2-3 storeys (doctrine #2's facade-break rule) — instead of either stone or a
single thin layer. Streets bore through the mass exactly as era B did
(55-70% covered in data was already achieved); every carved face resolves to
a facade (the partitioner's ownership machinery already guarantees this);
the mass over each street is ROOMS whose doors open onto higher lanes — the
original design's never-implemented "Resolution: carved ceilings become room
floors" clause, now concretely specified by the terrace-tunnel motif's
four-requirements analysis (sunken street ✗ — instead street at grade with
LIFTED mass, deck lanes above; motif spec `2026-08-10` has the arithmetic
and the census says sites are plentiful once mass exists). Terrain keeps the
site, the skirts, and the under-town bell base; the BUILDING mass provides
the centre-tall gradient the reviewer asked for. This is the only direction
that recovers density + bounded snaking paths + tunnels simultaneously,
because they are the same property: mass adjacent to and above streets.
Cost: the composed-face and one-house-per-column rules must be reworked into
the facade-break form; the eight tall-massif seal() floors get their
calibration argument back the honest way (they were calibrated FOR this
form).

**D2 — Prefab infusion + feature restoration (vocabulary layer, applies
under any structure).** Wire era-A's prefab anchors into mass-first (the
"interesting buildings"); restore outcrop/dormer density (budget raise is
already measured as justified: 12/12 saturated with 1712 candidates); place
era-A's roofed skywalk recipes between stacked masses that now genuinely
face each other (in D1's dense form the 0.23-0.36 m overhang refusals shrink
because gaps do too — re-measure before buying art); widen dormer placement
to the new ridge/chimney pieces. Ground-storey stone becomes per-style
(timber-to-ground variants exist among the 86 baked walls) answering
doctrine #1.

**D3 — Terrain-first acropolis (conservative alternative).** Keep the
current thin layer everywhere EXCEPT a designated core: stamp a steeper
terrain knoll (+4 bands is already measured: motif sites double, zero-site
seeds vanish) and stack 2-3 thin layers only at the crown as terraced tiers.
Cheaper than D1, keeps all of era C untouched at the rim, but tunnels remain
scarce (they only exist where tiers stack) and density improves only at the
centre. Choose if D1's rework risk must be minimized.

**D4 — Art-unblocked track (parallel, independent).** The three authored
asks stand and each unlocks a signature feature regardless of direction:
flush/trimmed roof (corners + skywalk envelopes), lattice-scaled walkway
set (galleries), undercroft span piece (3.0 × 4.5 m opening). The measured
no-art alternative for tunnels: passage headroom 2 bands (3.0 m) puts the
existing 3.61 m load-bearing piece in range (needs the re-derivation
standard on HEADROOM for passages only).

**Recommendation:** D1 + D2 together, D4 in parallel as the reviewer
decides on art; D3 only if D1 is refused. Sequence D1 as: (i) design
addendum reconciling the facade-break doctrine with the stacked partition
(one spec, reviewed before code); (ii) thick-mass partition with stacked
styling; (iii) street resolution + deck lanes (motif spec waves apply
almost verbatim); (iv) feature restoration (D2); (v) acceptance
recalibration against the eight floors with the established evidence
standard; (vi) showcase.

## 5. Open reviewer decisions (blocking listed items only)

1. **Cliff ruling:** do terrain-authored KayKit cliffs read as landscape
   (raise relief budget; +4 bands is measured to double motif supply) or as
   stone-budget (hill stays a swell)? Blocks relief budget; D1 reduces its
   urgency (building mass supplies height) but the hill base still wants it.
2. **Colonnade reading:** does a ~4.5 m open passage under a house read as a
   covered street or a face-with-a-hole? Blocks the undercroft's fronting
   treatment. (If D1 is chosen, most tunnels are room-over-street instead,
   and this question narrows to portal mouths.)
3. **Art asks vs 3 m passages** (§4 D4).

## 6. Machinery a fresh agent must know

- **Preview:** `Godot --path . res://tests/harness/warren_mass_first_preview.tscn
  -- --seed N --output DIR` — terrain mode + full detail phases by default,
  prints gate refusals honestly; `--flat-ground`, `--site origin`,
  `--no-detail` variants documented in the file header. Detail solves are
  ~10 min/seed; seed 11 is a known ~30 min outlier.
- **Measurement:** `tests/harness/warren_mass_first_report.gd` stages:
  `gate`, `compose`, `envelopes`, `skywalk`, `timing`, `routeab`, `motif`,
  `terrain`, plus variety counters. Extend it; never leave scratch probes.
- **Suites** (synchronous; GUT; `-gtest=res://tests/<f>.gd -gexit`): massif
  13, excavation 15, adapter 11, partitioner 25, generation_mode 8,
  production_surfaces 11, facade_variety 16, relief 17, market 2,
  roof_profiles 2; terrain stack (heightfield_plan 43, mesher 45, surface 23,
  streamer 17, + others); canary `test_warren_outcrops` 8 (~8 min, run for
  ANY shared-file change). Pre-existing drifted suites (do not chase):
  warren_volume 5/12, settlement_fabric 20/25, village_plan 2/3,
  village_program 1/2 — all baselined byte-identical in the ledger.
- **Discipline that kept this branch safe** (non-negotiable): route-first
  byte-identity via controlled A/B or envelope-field gating for every shared
  change; gate changes only under the re-derivation standard (property-vs-
  proxy proof, measured derivation, invariance test, A/B); TDD with
  sabotage/teeth proofs; honest negatives are results (seven of them drove
  every real advance here); renders judged by eye at street level AND
  overview — metrics have lied twice (excavation-level cover vs fabric-level;
  declared vs drawn plinths).
- **Diagnostic flags** (off by default, never ship):
  `SettlementFabricPlan.DIAGNOSTIC_ALLOW_CORNER_ENVELOPE_OVERLAP` (corner
  art gap), `_solve_ungated` preview path (labelled loudly in the harness).
- **Idioms:** tabs, typed GDScript, `##` constraint comments; hash-only
  randomness; new `class_name` needs one Godot run to register; never
  `git add -A`; commits `feat(villages): <lowercase>` +
  `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
