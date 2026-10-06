# Town odds layer and courtyard clearings — design

Date: October 7, 2026. Branch `town-redesign` (worktree `/Users/ryko/.codex/worktrees/77a0/story`).
Inputs: rule audit `docs/qa/2026-10-07-town-rule-audit/audit.md` (sections 1–9) and the owner's
decisions (section 10). Continues the October 1 town redesign plan
(`docs/superpowers/plans/2026-10-01-town-redesign.md`), whose stage gates remain open.

## Intent

The owner wants towns that vary among many possibilities instead of converging on one
look. Principle: **hard rules exist only as guardrails** against things that look broken
and must never happen; every aesthetic choice is a **parameter with tunable odds**, so we
shift behaviour toward what we want rather than force it. Success means:

- Every aesthetic decision in the audit is driven by one tunable table, with today's
  behaviour as the default (turning the layer on changes no town).
- Each town draws its own **character** (palette, density, silhouette, enclosure), so
  towns differ from each other, not just house to house.
- Tuning one knob never reshuffles unrelated decisions, so before/after comparisons on
  fixed seeds are fair.
- No aesthetic quota ever rejects a town; shortfalls are recorded instead.
- Courtyard clearings exist at every town size, vary in size/shape/height/cover, and
  break up large blocks probabilistically.

Out of scope: world-level town placement (density, hillside sites, waterside towns) —
a later, separate task. Pillared courtyard halls — later.

## Order of work

1. **Dead-code cleanup** (audit section 8). Remove unreached solvers and helpers, the
   unused tier/theme rolls, `KitRoofTurrets.propose` and its constants, dead constants
   and functions. Acceptance: tests that passed still pass; towns are byte-identical
   (serialized payload equality) on the evidence seed set.
2. **Town odds layer** (this document, "Odds layer"). Defaults reproduce today.
   Acceptance: determinism and stream-independence tests; byte-identical towns.
3. **Groundwork fixes using the layer**:
   - Aesthetic quotas that reject towns become recorded shortfalls (audit section 4):
     market square, straight-run caps, loop requirement, tall-tower annex quota,
     dormant outcrop quotas, the hard ceilings in `VillageUrbanFabricPlan`.
   - Dressing rolls receive the world seed (`SettlementFabricAssembler._face_noise`
     callers), placement order for lamps/furniture/stations is seed-shuffled, and the
     facade-module pick uses a hash instead of a linear sum.
   - These intentionally change output; each gets matched before/after renders.
4. **Tunnel attrition investigation** ("Tunnels").
5. **Courtyard clearings** ("Courtyard clearings"). Owner checkpoint: re-judge large
   blocks on the same seeds, with and without clearings.
6. **Migrations in batches**, owner checkpoint after each: edge streets, silhouette,
   market square, upper-floor dial, town palette, flat roofs, gates, then the long tail
   of section 2 of the audit.

## Odds layer

### Knob table

One editable resource, `terrain/villages/town_odds.tres` (class `TownOddsTable`, a
`Resource` with an array of `TownKnob` sub-resources), editable in the Godot inspector and
as text. Each `TownKnob` has:

- `name: StringName` — stable identifier, e.g. `&"tunnel_cover_share"`.
- `kind` — one of:
  - `CHANCE` — a probability in [0, 1];
  - `RANGE_INT` / `RANGE_FLOAT` — a value drawn per town within bounds;
  - `WEIGHTS` — named options with weights (e.g. roof families).
- `at_small` / `at_large` — the knob's centre value (or weights) at town size 0 and 1;
  the value at a given size is a linear blend (an optional `size_curve: Curve` may
  replace the blend).
- `spread` — how far one town's drawn value may deviate from the size-blended centre
  (for `WEIGHTS`: each option's centre weight is jittered by ±spread, then the weights are normalised).
- `clamp_min` / `clamp_max` — absolute bounds (e.g. a chance stays in [0, 1]).
- `notes` — what the knob does and which audit ID it implements.

A knob that is "always" today has centre 1.0 and spread 0; a fixed count has equal
min/max. These defaults make the layer a no-op until a knob is moved.

### Compilation and threading

`TownOddsTable` is loaded and compiled once on the main thread into a plain-data
`TownOddsProgram` (dictionaries of floats/arrays, no `Resource` references), alongside
`SettlementFabricProgram.compile`. The worker pipeline only sees `TownOddsProgram`,
preserving the pure, resource-free worker contract.

### Town character

`TownCharacter.draw(program: TownOddsProgram, town_seed: int, size: float) -> TownCharacter`
draws every knob's per-town value once:

- Each knob's draw uses its own stream: `Helper._mix64(town_seed ^ hash(knob.name))`.
  Adding, removing or retuning one knob never changes another knob's draw.
- The character is attached to `WarrenVillageScaleProfile` (`profile.character`), which
  already reaches the carver, plot planner, feature solver, fabric compiler and — via
  `WarrenMazeSourcePlan.scale_profile` — the kit layer. No new plumbing through stages.
- The character's values enter `profile.deterministic_signature()` so caches and frozen
  fixtures distinguish towns with different characters.

### Per-decision rolls

Call sites ask the character instead of using literal constants:

- `character.value(&"knob")` — the town's drawn number.
- `character.chance(&"knob", key: Variant, boost := 1.0) -> bool` — a deterministic roll
  for one instance; `key` identifies the instance (a cell, house id, face). The roll's
  stream is `(town_seed, knob name, key)`, independent of call order.
- `character.pick(&"knob", key) -> StringName` — weighted pick for `WEIGHTS` knobs.
- `boost` multiplies the odds for situational context (e.g. flat roof level with a
  walkway). How strong a boost is is itself a knob (e.g. `flat_roof_walkway_boost`).

Existing deterministic hashes at call sites are replaced by these calls one knob at a
time; where today's behaviour depends on a specific hash, the migration preserves it
exactly while the knob sits at its default (verified by byte-identical output).

### Inspection

- Each town record stores its drawn character (knob → value).
- `kit_town_review.gd` prints the character with every render and accepts
  `--odds name=value` (repeatable) to override a knob for A/B renders without editing
  the table.
- A character-gallery harness renders ~12 towns side by side with their characters.

### Shortfalls instead of rejections

A knob that sets a target (count of skywalks, courtyards, markets) never rejects a town
when unmet. The sealed plan's existing `advisory_shortfalls` records the target and the
achieved count. Guardrails still reject or withdraw only the offending piece.

## Tunnels

The tunnel chance (`WarrenMazeCarver.TUNNEL_START_CHANCE`) is already 1.0, yet few
covered passages survive. Before adding the per-town `tunnel_cover_share` knob:

1. Instrument attrition on the evidence seeds, counting stretches at each stage:
   eligible run → both jambs solid at carve → jambs still solid after partition →
   room or walked floor built over the crown (`cover_tunnels` / over-plots) → survives
   destination pruning and final release of unborne crowns.
2. Identify the largest loss and fix it at its cause (likely co-planning jambs and the
   room over the bore with the carve, per plan stage 4), with a red-first test.
3. Re-measure. Then add `tunnel_cover_share` (per-town, e.g. 0.2–0.9) and
   `max_tunnel_run` (2–4), with defaults tuned so the corpus mean count of finished
   covered stretches does not fall below the post-fix level.

Planned and finished bridges, and covered length vs covered share, are reported
separately (per the October 6 handoff).

## Courtyard clearings

A new carving step that reserves courtyard space inside the massif while streets are
bored. It coexists with the existing interior court and plot-planner plaza/decks (which
become knobs with today's defaults); those are retired in a later step once clearings
have been judged.

### When

In `WarrenMazeCarver.carve`, after the second `_carve_loop_joins` (alleys and loops are
known, so `_block_thickness_field` and the frontage/reservation masks reflect the real
leftover blocks) and before secondary gate lanes, `_open_passages_to_air` and
`_finalize_excavation`. Clearings are therefore known to plot partition, which never
builds houses inside them.

### Knobs (defaults are starting points for tuning)

| Knob | Meaning | Small → large town |
|---|---|---|
| `clearing_count` | courtyards per town (RANGE_INT, drawn) | 0–1 (≈25% ≥ 1) → 1–4 |
| `clearing_block_bias` | pull toward thick uncut stone (exponent on thickness / distance-to-street) | 1.5 → 1.5 |
| `clearing_ground_weight` | extra weight for ground-level floors | 2.0 |
| `clearing_area` | target area in macro cells | 4–9 → 6–20 |
| `clearing_shape` | WEIGHTS {rect, two-rect L/T, three-rect, grown blob} | — |
| `clearing_extra_link_chance` | chance per additional nearby street to connect | 0.4 |
| `clearing_cover` | WEIGHTS {open, covered edges, fully covered (narrow only)} | — |
| `clearing_purpose` | WEIGHTS {green, paved square, market, workyard} | — |

Covered-edge courts keep building storeys overhanging one or more sides; fully covered
courts are allowed only when narrow enough to be borne by their walls (same bearing
rules as tunnel crowns).

### Placement algorithm

1. Candidate centres: massif columns not already public or reserved, with a usable floor
   band. Weight = `thickness(column) ^ clearing_block_bias`, multiplied by
   `clearing_ground_weight` when the floor is at the column's ground band.
2. Floor band: any band the massif supports at that column with headroom; ground level
   weighted as above.
3. Shape: grow the drawn shape to the drawn area around the centre, cells restricted to
   eligible columns at that floor; min width 2 cells (guardrail). Reject and retry with
   a new centre (bounded attempts) if the shape cannot reach the minimum.
4. Connections: shortest legal connector (existing level/stair/ramp stride rules) to the
   nearest public cell; then for each other public street within a reach bound, connect
   with `clearing_extra_link_chance`.
5. Cover: roll `clearing_cover`; open courts clear massif above to the sky; covered
   edges and fully covered courts reserve the bearing jambs and the room/floor above,
   like a tunnel crown.
6. Record the clearing on the source plan (`feature_stamps` kind `&"court_clearing"`,
   with cells, floor, cover, purpose, links) so later stages (plots, surfaces, dressing,
   grass, trees) consume it explicitly.

### Guardrails (hard)

Reachable from a gate; supported floor (solid below or a supported deck); walking
headroom; fall-edge guards at real drops; minimum width 2; never overlaps another
feature's reservation (market, landmark, bridge bearings, plinth); a connector that
fails its stride rules withdraws the clearing rather than leaving it isolated.

### Dressing

Purpose drives dressing: green = regional-tint terrain surface with real grass and
trees (existing `TownCourtTrees`/`GrassField` paths); paved square = paved surface with
a centrepiece by odds; market = stalls; workyard = activity group. Placement order is
seed-shuffled.

## Testing and evidence

- **Cleanup and odds layer**: serialized-payload equality on seeds 53/grand, 31/large,
  13/standard, 43/large, 83/grand, 103/standard plus two holdout seeds (one compact, one standard) fixed in the implementation plan and never used for tuning; existing focused
  suites pass.
- **Odds layer unit tests**: per-knob determinism from seed; changing one knob leaves
  every other knob's draw and every other call site's rolls unchanged; size blending
  and clamps; `WEIGHTS` draws sum to 1; `--odds` override.
- **Each behaviour change**: red-first test for any guardrail it touches; six-town
  production audit (payload valid, 0 floating, 0 roof/public-air intrusions);
  actual-player walks through new courtyards and gates; matched before/after renders
  on the evidence seeds plus holdouts; character gallery for variety.
- **Tunnels**: attrition table before and after the fix, per size.
- Full isolated suite run and failure classification before claiming any stage complete
  (144 failing files at the October 6 checkpoint remain unclassified).

## Owner checkpoints

1. After courtyard clearings: re-judge large blocks (same seeds, with/without).
2. After each migration batch, before the next begins.

## Risks

- Byte-identical defaults require care where today's code uses specific hashes; each
  migration keeps the old hash under default values.
- Clearings change plot partition inputs; seal costs measured in plot-planner comments
  are stale and must be re-measured.
- Performance: production town solve is already near the 8 s gate; clearings and extra
  connectors add carve work. Measure per stage.
