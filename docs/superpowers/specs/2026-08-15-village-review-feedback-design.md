# Village review feedback — design (2026-08-15)

Source: Ryan's annotated review of the seed-1 standard village fixture
captures (`/tmp/mythos-village-roofplates`, commit 64867fe). Five issues,
each grounded in a measured baseline before its fix. This spec chooses an
approach per issue; the living ledger
(`docs/superpowers/plans/2026-08-12-town-quality-remediation.md`) tracks
execution evidence.

## Baseline facts (sealed fixture audit)

- `frontage_ratio` **0.27** — only 27% of eligible route sides are walled
  by proposed mass; most of the "path" is deck edge or open rim, not
  negative space between buildings.
- `through_sightline_count` **122** — the route barely turns.
- `stair_count` **6**, served entrances 14 — vertical connection exists
  but is sparse; the topology gate's village floor is a single ramp
  transition.
- Pitched roofs are all modular-tile families (`roof.tower.*`,
  `roof.slim.*`, `roof.row.short.*`); the two circled "awful" shells are
  therefore from the cap/lean-to/plate vocabulary (5 lean-tos, 3 plate
  sections, 27 caps) — identification needed, not assumption.
- All 3 flat slabs are `roof.flat.long` — long rooms whose pitched
  attempts were rejected; the reasons are recorded per-room in
  `rejected_pitched_details`.
- Exposed-top kind mix: slim 12, tower 8, long 5, row 4, building 1 —
  the crown reads as stacked small boxes because small kinds dominate
  where silhouette matters most.

## Issue 1 — one winding, bounded, level-spanning path network

Ryan's sketch: a single path entering from the terrain, winding between
buildings with turns and stairs, climbing through the settlement,
branching to every building, no disconnected platforms, and long
stretches bounded by buildings on BOTH sides.

Options considered:

- **A. Post-carve dressing** — add stairs between nearby decks and prop
  sheds along open route flanks after composition. Rejected: band-aid on
  the symptom; the carve is the layout authority and stays wrong.
- **B. Carver objective re-weighting + measured gate floors** — make the
  excavation carver *prefer* serpentine, wall-bounded, climbing streets
  and make the topology gate *require* them: new audits for route band
  span, both-sides-bounded route ratio, and walk-surface connectivity;
  floors set from a measured seed corpus, never aspirationally.
- **C. Authored spine-first carve** — generate a switchback spine
  polyline climbing the massif, carve it as primary negative space, then
  branch alleys to parcels. Highest fidelity to the sketch; largest
  surgery.

Chosen: **B now, C only if B's measured ceiling proves too low.** B keeps
the mass-first architecture intact and every step falsifiable. Concretely:

1. New volume-plan audits (measured on fixture + corpus before any gate):
   `route_band_span` (distinct walk bands), `bounded_route_ratio`
   (walk cells with authored mass or massif wall on both flanks),
   `walk_surface_component_count` (fabric-level: walk cells + stairs +
   entrances as one graph; must be 1).
2. Raise village topology-gate floors from the corpus measurements:
   stair/ramp transitions (1 → measured-achievable 2+), minimum band
   span, minimum bounded ratio. Never lower an existing gate.
3. Re-weight carver candidate scoring so bounded, turning, climbing
   streets outrank straight rim promenades (frontage weight up,
   through-sightline penalty up, new band-span term).

## Issue 2 — "these roofs look awful and out of place"

Two teal shells sit tilted/sunken on top of masses. They are not full
pitched roofs (all 11 are accounted for in modular families). Diagnosis
first: a per-unit roof capture battery (every lean-to, plate section, and
macro cap gets a labeled close-up) plus a placement dump naming recipe,
owner, and world bounds. Then fix the *identified* mechanism:

- If lean-to: tighten `_setback_lean_to_placement` seating (full long
  edge against a real upper facade, no crown-top placements), or retire
  lean-tos from shoulder tops entirely.
- If plate section: enforce junction trim or campaign theme continuity
  with the abutting mass; a plate that cannot join coherently falls back
  to a railed terrace cap.
- If cap/garden shell: replace the offending recipe in the spatial
  vocabulary with the modular-family equivalent.

The fix must come with a regression view battery so a reappearance is a
review failure, not a surprise.

## Issue 3 — boxy crown cluster

"Fix with bigger buildings, outcroppings on these buildings, and roofs."
Three levers, all already specified in the ledger, now scoped to land:

1. **Serve-time large-kind preference**: when the composition serves
   summit/crown parcels, try exact 4×4/4×6 covers before 2×2/2×4 so the
   silhouette is fewer, larger masses (the zero-unexploited-pairs audit
   proves post-hoc merging is exhausted; the order of *serving* is the
   remaining lever).
2. **Crown flat-long diagnosis**: read `rejected_pitched_details` for the
   three `roof.flat.long` rooms and remove the actual blocker so long
   crowns pitch.
3. **Crown outcrops**: make top-storey rooms eligible cantilever hosts so
   the circled cluster gains projections.

## Issue 4 — boring rim box

Single-storey flat-roofed box at the cliff edge: no railings, nothing on
top. Chosen: dress and stack, no new hard gate. Exposed single-storey
flat roofs must take the railed/furnished occupied-terrace variant
(vocabulary exists: lived-in/awning/furnished terraces), and residual
backfill scoring gains a stacking bonus on single-storey rim rooms (the
new established-contact rule already requires adjacency; stacking on top
satisfies it and adds silhouette).

## Issue 5 — stray "stairs?" stub

Unidentified tan stepped piece on a gable wall. Diagnosis via the same
placement dump as Issue 2 (stairs, ladders, entrance stairs with world
positions). Fix follows identity: a stair serving a door that reads
floating gets landed on a real deck or the door/stair pair is removed;
a bracket/trim misplacement gets its placement rule corrected.

## Order and testing

Diagnosis (Issues 2/5 dump + battery) → Issue 1 metrics measured on the
corpus → Issue 1 floors + carver scoring → Issue 2 fix → Issue 3 →
Issue 4 → full re-render + corpus spot-check. Every step: GUT tests for
new audits and placement rules, fixture re-solve, ledger evidence entry.
The pre-existing seed-7 review-fixture debt (topology-gate cascade from
the rescale) is tracked separately in the ledger and must not be
worsened: corpus measurements for Issue 1 floors use village seeds that
currently solve.
