# Constructive maze town generation — design (2026-08-20)

> **Note (2026-08-21):** the reservation pass, stamping pass, edit ledger, skyline trim, and foundation sections below are superseded by `2026-08-21-plot-model-design.md`. The principle, gate disposition, deletion scope, and success criteria remain in force. Roadmap: `../plans/2026-08-21-maze-town-master-plan.md`.


Approved in-chat (Ryan, 2026-08-20). Supersedes the falsification-era rules of
`2026-08-16-maze-town-carver-design.md` for everything downstream of the bore;
the bore itself (spine, alleys, stride legality, air classification) is kept.
Companion evidence: `../plans/2026-08-20-village-solve-optimisation.md`
(measured profiles, the pencil-tower mechanism, and the bisect that found the
one working seed).

## Why this redesign

The measured failure of the current pipeline is architectural, not a tuning
problem:

- Every rule is a **rejection** on immutable geometry, so the only response to
  a violation is to discard the whole town. That forces the 12-attempt search
  (28.5 s best / 85.4 s failing, measured), and it makes the one-pass maze path
  seal **0 of 24** seed×scale combinations.
- The maze block partitioner stamps rectangles that must exactly fit a terraced
  Gaussian heightfield. Measured on seed 12: even with zero competition, 24 of
  50 stampable faces cannot hold anything larger than 1×1 because footprints
  cross terrace steps (`no_top`). The result is pencil towers — median parcel
  footprint 1 column, 7 storeys.
- The hero-feature beam (courts/landmarks/skywalks joint search) is both the
  top rejection reason (14 of 24) and ~91% of composition time.

## Principle: rules become repairs

The town's built mass is **editable during generation** and sealed once at the
end. A rule that today rejects instead *edits the town into compliance* —
lower a column, raise a datum, fill a foundation, build a support. Rules that
cannot be satisfied by an edit become reason-coded audit facts asserted in the
test corpus, never runtime rejections.

Hard runtime rules (the only ones that may reject, and each attempts its
repair first): **playability + grounding** — the street network stays
connected, walkable, and headroomed; no geometry overlap; every inhabited cell
reaches terrain through real mass or built foundation. Grounding is expected
never to fire because Phase P5 constructs it.

The natural terrain heightfield remains immutable (existing project
invariant). "Editable heightfield" always means *built mass above the sampled
terrain floor*. `WarrenMassif.bearing_at()` stays the terrain sample;
`SettlementReliefPlan` keeps blending the surroundings.

## Pipeline

One deterministic pass over one unsealed `WarrenMazeSourcePlan`; mutability
ends at its single `seal()`.

```
P0  massif        terraced heightfield; column base = sampled terrain (unchanged)
P1  bore          spine + alleys, existing carver invariants (unchanged)
P2  air/cover     open-to-sky vs retained-overhead classification (unchanged)
P3  reserve       large features, BIG edit budget (level, sink, claim spans)
P4  stamp         houses, global largest-first, SMALL edit budget (±1 band)
P5  foundations   derived: floor datum − terrain = rock courses, per column
SEAL → adapter → translator partitioner → composition (consumes reservations)
```

Streets are immutable after P1. Edit budgets shrink with commitment: P3 may
reshape empty land; P4 may nudge only its own footprint + a 1-column apron.

## The edit ledger

`WarrenMazeSourcePlan` gains plain-lattice fields (the source plan keeps its
"plain lattice data only" invariant — no Nodes, no resources):

- `column_edits: Dictionary` — `Vector2i column → {floor_band, top_band,
  foundation_base, phase}` overlaying the sealed massif. Accessors
  `effective_base(column)` / `effective_top(column)` /
  `foundation_depth(column)` read through the ledger.
- `parcel_claims: Array[Dictionary]` — the stamped houses as data:
  `{footprint: Array[Vector2i], floor_band, top_band, door_walk: Vector3i,
  door_column: Vector2i, frontage: Vector2i, lineage_hint: StringName,
  shape_id: StringName}`.
- `reservations: Array[Dictionary]` — typed large features (see registry).

`seal()` additionally validates: no edit touches a passage column's carved
cells; every `floor_band` ≥ the terrain sample; every P4 edit within ±1 band
of the pre-edit surface and inside footprint+apron; claims are disjoint.
`deterministic_signature()` covers edits, claims, and reservations.

## P3 — reservation pass and the feature registry

Generalizes the existing universal-market stamp. The ladder per feature is
`fit → edit → shrink → move → skip`, every outcome reason-coded.

A data-driven **registry** (constant on the new `WarrenMazeReservationPass`)
defines each feature kind: quota range per scale profile, patch shapes,
allowed edit ops, and priority. Initial entries:

1. **market** (universal; exists today) — level to one datum.
2. **courtyard / park** — level to the adjoining street, flat, at grade with
   the walk it opens off (`level_to_walk`). Superseded 2026-08-21 by
   controller ruling: the original design here ("lower built mass toward
   the terrain floor; terrain showing through is the park surface") is
   retired -- the user's direction is "no exposed ground," so there is no
   sink-to-terrain fallback for a courtyard or garden terrace at any scale;
   see "Tier-driven heights, street-level courtyards, and the
   bridge-capable ledger" below for the current rule.
3. **landmark plot** — level + clear for the measured prefab families.
4. **large-house plot** — level a 3×2+ macro patch for L/T envelopes.
5. **skywalk span** — claim a retained-overhead span from P2 as a typed
   two-ended occupied-bridge site (feeds the existing occupied-link and
   modular-box contracts instead of fighting them).
6. **plaza well / garden terrace / gatehouse** (variation tier) — small
   authored set-pieces at street junctions, the entrance portal, and rim
   terraces.

**Variation:** each town draws a seeded subset of the optional registry
entries (`Helper._mix64` over city seed + kind), so two adjacent towns carry
different feature palettes. Quota ranges — not fixed counts — are the second
variation lever; the seeded roll picks inside the range. New feature kinds are
added by appending registry entries, not by new passes.

## P4 — stamping pass

Replaces the per-face greedy loop (`WarrenMazeBlockPartitioner`'s search) with
**global largest-first**:

1. Enumerate all (frontage face × shape) candidates town-wide. The shape menu
   keeps the rectangles (2×3 … 1×1) and adds **L-shapes**, emitted as two
   rectangles sharing the door-bearing arm and one `lineage_hint` — the
   composition's existing lineage merge unifies them into one building, so the
   rectangular `WarrenBuildingParcel` contract is untouched.
2. Sort deterministically: area desc → neighbor contact desc → seeded hash.
3. Place in order. A candidate that fails only on a terrace step *edits*:
   choose the majority datum, move offending columns by at most ±1 band
   (footprint + 1-column apron), fill below with foundation. A candidate that
   still fails is skipped, not fatal.
4. Infill pass with the small shapes for leftover frontage.

Success is structural, not searched: the measured `no_top` mechanism (terrace
steps inside the footprint) becomes a datum adjustment, so 1×1 pencils can
only appear where a block is genuinely one column wide — and a 1×1 claim
taller than 2 storeys is forbidden at stamp time (typed watchtower reservations
are the deliberate exception, via the registry).

## P5 — foundations by construction

For every claimed or reserved column, `foundation_base = terrain sample`,
`floor_band` from the claim; the difference is emitted as stone foundation
courses through the **existing** retained-foundation vocabulary (closed
shells, all-perimeter faces, native 3 m course height — those fabric contracts
stay). On slopes this is the moulding: one datum uphill, taller rock courses
downhill, terraced plazas with stone faces. Grounding therefore cannot fail
downstream; the hard gate remains only as a generator-bug tripwire.

## Downstream: translator, composition, gate disposition

`WarrenMazeBlockPartitioner` becomes a **translator**: `parcel_claims` →
sealed `WarrenBuildingParcel`s against the adapted volume, 1:1, no search and
no rejection paths beyond contract violations (which are generator bugs).

Composition consumes `reservations` directly — market, courtyard, landmark,
skywalk sites map onto the existing typed reservation contracts the hero beam
used to emit. **The joint hero-feature beam is deleted**, and with it the
landmark set enumeration (the measured 55 s hotspot).

| Gate today | Fate |
|---|---|
| Hero-feature beam | Deleted; replaced by reservation consumption. |
| ≤4-column tower overhang rule | Moot at stamp time; survives as test assertion. |
| Courtyard sides / balcony / skywalk quotas | Reservation targets; shortfalls are audit facts asserted in tests. |
| Unsupported room transitions | Hard (playability), repair-first; expected never to fire. |
| Connectivity / walkability / headroom / overlap | Hard, unchanged. |
| `feature_quotas_are_advisory()` (2026-08-20 stopgap) | Retired; superseded. |

## Deletion of the searched pipeline (final milestone, gated)

Once the new path meets the success criteria: delete the 12-attempt rotation
and `_solve_frontier`, `_ranked_precomposition_variants`, the courtless
fallback, deadline/budget slicing, `carve_ranked`'s 256-bore search, the
landmark set beam, `WarrenSolutionPinCache` plus its `VillagePlan`
integration and generation-salt machinery (a ~2–3 s pure function needs no
pins), and the `GENERATION_MODE` switch — maze becomes the only path.
Search-specific tests and harnesses are retired the same day. Verified by
dead-symbol grep plus the full suite.

## Success criteria

1. 24/24 seed×scale flat matrix seals end to end (source → composition →
   fabric), **and** the pinned production terrain site (world seed 2697992464,
   super (0,-1)) plus ≥2 additional sloped sites.
2. Solve ≤ ~3 s per town on the measured M1 Pro baseline.
3. Median parcel footprint ≥ 4 columns; zero unclassified 1×1 claims above
   2 storeys; `maze_owned_solid_ratio ≥ 0.85` (the M4 floor).
4. Deterministic signature stable across processes and dictionary orderings.
5. Modular-box, door, balcony, and roof audits clean on the corpus.
6. M8-style visual review battery passes before the mode flip; the deletion
   milestone lands only after that.

## Risks

- **Composition coupling.** Composition dereferences committed feature-set
  shapes (`reservation`, `priority_cells` — two measured crashes prove it).
  The reservation-consumption adapter must produce byte-compatible committed
  structures; verified stage-by-stage with `warren_maze_stage_probe.gd`.
- **L-stamp lineage pairing.** If the lineage merge does not unify the two
  rectangles visually (roof seam, palette), fall back to native L parcels — a
  `WarrenBuildingParcel` shape extension — as a separate decision.
- **Edit-rule creep.** New safeguards go into the seal validation and the
  test corpus as they are discovered (Ryan's "rules we add as we go"), never
  as new runtime rejection paths.

## Noise-based massif (scheduled: slice 1.5)

Measured 2026-08-20: the Gaussian massif is shape-monotone — across 24 builds,
relief is always 0 (no ridges or saddles), the widest plateau is always 6–8
cells, and the terrace ladder `[2,3,4,6,7,8,10,11,12,14]` repeats verbatim
across seeds. Every town is the same concentric mound with ±10% size jitter,
so silhouette variation cannot come from the carve or feature palette alone.

The swap is contained behind the massif interface (`has_column` / `top_at` /
`base_at` / `bearing_at`): `WarrenMassifBuilder` gains a seeded, quantized
noise heightfield (2.5D — noise drives per-column height above the terrain
sample; no overhangs or floating mass). Targets: non-zero relief (ridges,
saddles, occasional twin peaks), varied plateau widths and terrace ladders,
eccentric non-circular footprints — while keeping the buildable-layer bounds
and every carve invariant (connectivity, frontage, stride legality) as the
safety net, and slice 1's exit metrics (median footprint, ownership, no
pencils) re-verified on the noise corpus before slice 2 begins.

Sequenced at 1.5, not 1, deliberately: noise multiplies terrace steps — the
exact geometry the new stamping pass must absorb — so the pipeline is proven
on simple geometry first, then hardened against noise with the debug view's
phase-1 massif renders as the tuning instrument.

## House heights, stacked claims, and skyline trim (slice 1b task 1, approved in chat 2026-08-21)

Measured on the flat-terrain seed corpus (seeds 1–12, compact): P4's ceiling
derivation walked every claim's footprint up through solid mass to the
massif's own top, giving every house the same height as its column — up to a
14-band, 7-storey tower on a compact-scale massif. This section replaces that
with a bounded storey budget, extends claim occupancy to a third dimension so
upper streets can build above lower houses, and trims whatever built mass no
claim ever reaches.

**1. Storey budget.** `WarrenMazeStampPass.STOREY_BUDGET: Dictionary` gives a
per-scale `(min, max)` storey range — `{compact: (2,3), standard: (2,3),
large: (2,4), grand: (3,4)}`. Each claim rolls a storey count once, seeded off
its own door_walk cell (`posmod(Helper._mix64(plan.world_seed ^
Helper._mix64(door_walk.x * 73856093 ^ door_walk.y * 19349663 ^ door_walk.z *
83492791)), max - min + 1) + min`), and its top is
`min(ceiling-derived top, floor_band + storeys * WarrenBuildingParcel.STOREY_BANDS)`.
`MIN_HOUSE_BANDS` and the existing 1×1 pencil clamp (2 storeys max) still
apply on top of the roll — a claim can end up shorter than its storey budget
allows (a shallow ceiling), never taller.

**2. Claim occupancy is a column × band-interval map.** The 2D
`claimed_columns: Dictionary[Vector2i → bool]` becomes `claimed_intervals:
Dictionary[Vector2i → Array[Vector2i(floor_band, top_band)]]` (half-open
ranges). A reservation still claims the whole column, at every band.
`_footprint_available(footprint, floor, top)` now means "no band overlap on
any column, at any existing interval"; `_column_ceiling` additionally stops
at the floor of the lowest claimed interval strictly above the query floor,
so a lower claim's own ceiling walk can never reach up through mass an
already-placed stacked claim owns. Every placement, back-extension, lateral
extension, and small-claim merge site reads and writes this same map.

A column-keyed terrain-offender check (`_footprint_offenders`) exists purely
to correct small (±1 band) mismatches between a candidate's own street
elevation and that column's raw terrain sample — a check that, unmodified,
would reject essentially every candidate whose street climbs more than one
band above grade, since raw terrain stays flat while a maze's streets climb
through the solid mass independent of it. A column already carrying a
claimed interval whose own top lands *exactly* on the new candidate's floor
(flush — no gap) is exempt from that terrain check: it isn't standing on raw
terrain, it's standing on the roof of the claim below. This flush-only rule
is deliberately narrower than "any existing claim below at any gap distance"
— that wider form was tried and measurably over-produced dozens of small,
mutually non-adjacent stacked 1×1 infill claims per town, each an
unavoidable lineage of one, which pulled a town's median lineage footprint (a
protected corpus metric) below 2.

**Bearing (fix round 4, 2026-08-21 — the upper-street unlock; refined fix
round 5 — plinth bearing).** A column is also exempt from the ±1
terrain-offender budget when it *bears* at the candidate's floor
(`_column_bears`): only the `PLINTH_BANDS` (2) immediately below the floor
need be SOLID, not the whole column down to its own base — a room may sit
directly over a covered passage's own roof by design, a real slab
separating the two. The column isn't floating, and the depth below the
raised floor becomes real deep foundation via the existing
`derive_foundations` accounting. Bearing refuses a column that ANY other
claim already occupies, at ANY band, not only a band overlapping the
plinth: `record_edit` overwrites `column_edits[column]` wholesale (a column
carries exactly one ledger entry, floor and top together), so writing a
bearing edit for a column another, non-overlapping claim already touches
would silently erase that claim's own floor the moment
`WarrenMazeVolumeAdapter` reads `effective_base` for it — surfacing much
later, as a translation-time "generator bug" claim drop, far from where the
real conflict was written (measured on the standard-scale sweep, which the
compact-only pinned test corpus never exercised: 22/23 → 14/23 translated
before this hardening, restored to 22/23 after). Because candidates are
scored once, all up front, before any of them commit, a bearing verdict
computed at enumeration time can go stale by the time a candidate's turn to
commit actually arrives (an earlier, higher-scored candidate may have
claimed the same column's mass in between), so `_footprint_offenders` is
re-run against the live occupancy map at commit time rather than trusting
the cached enumeration-time result. `WarrenMazeSourcePlan.seal()` re-derives
the same plinth test for a bearing stamp-phase edit's own ±1-budget
exemption, against the pre-edit, raw massif/excavation
(`state_at_raw`) — never the ledger, and never trusting the recorded
`bearing` flag alone.

Measured effect (compact scale, seeds 1/3/4/12, aggregate): unchanged at
8/63 = 12.7% both before and after the plinth refinement — verified this
is a genuine property of the compact-scale corpus (most of its
high-elevation candidates sit within `HEADROOM_BANDS + PLINTH_BANDS` (5
bands) of some nearby passage, where plinth and continuity-to-base agree),
not a bug in the mechanism itself.

Lineage grouping's adjacency stays 2D-column-plus-one-band, unchanged: a
stacked claim's floor differs from anything below it by at least
`MIN_HOUSE_BANDS` (4) bands, far outside the 1-band grouping tolerance, so a
stacked pair is never mistaken for one lineage.

**3. Skyline trim (P4.5)**, called from `stamp()` after lineage grouping,
before `derive_foundations`, over every massif column in deterministic sorted
order (skipping only a skywalk_span reservation's flank columns —
`claim_overhead` never touches a floor at all, so they stand on grounded
natural rock and stay exempt outright): a **claimed** column trims down to
the tallest claim's own top on that column (its real roofline). A
**reservation** column (refined 2026-08-21: every other reservation kind now
carries a real ledger top of its own — see "Reservation plot heights" below
— so it no longer needs a blanket exemption either) trims down to its own
`plot_top`, the same way a claimed column trims to its own roof, and is
deliberately routed here rather than into the unclaimed shoulder/discard
branch below: a reservation's datum is its own floor, not stray unassigned
mass. A **passage-hosting** column (refined 2026-08-21: no longer exempt
outright — that left every covered tunnel, ~47% of the network, standing
under the full massif ceiling) keeps `keep = max(any claim's own top on the
column, highest passage cell y + WarrenExcavation.HEADROOM_BANDS +
WarrenMazeStampPass.TUNNEL_ROOF_BANDS)` (`TUNNEL_ROOF_BANDS := 1`, a thin
roof over the required headroom), folds in the same 4-neighbour "shoulder" an
unclaimed column uses (a tunnel between two tall buildings should read at
least as tall as they do), and trims to `max(keep, shoulder)`. An
**unclaimed, non-passage, non-reservation** column takes its "shoulder" — the
tallest claim among its four cardinal neighbours — trimming to that, or, with
no claimed neighbour at all, discards straight to its own terrain (the old
pipeline's `_discard_unassigned_mass`, now reached by construction rather
than as a separate late step). Every target is computed first, entirely from
pre-trim claim tops and pre-trim `effective_top`, then applied in the same
sorted order — deterministic regardless of Dictionary iteration order.
Outcomes are counted by kind (`claimed_roof`, `reservation_roof`,
`tunnel_roof`, `shoulder`, `discarded`) in `plan.audit["trim_outcomes"]`.
`WarrenMazeStampPass.skyline_trim_enabled` (default true) exists solely so a
test can compare a plan's pre- and post-trim tops.

**Reservation plot heights (fix round 5, 2026-08-21).**
`WarrenMazeReservationPass.PLOT_STOREYS: Dictionary` gives each non-skywalk
kind a storey budget above its own datum — `{courtyard: 0, garden_terrace:
0, large_house: 3, landmark_plot: 3}` (skywalk_span is absent: `claim_overhead`
never edits a floor). When `_apply_level_to_datum` places a patch
(large_house, landmark_plot, garden_terrace), every column's ledger top
becomes `datum + PLOT_STOREYS[kind] * WarrenBuildingParcel.STOREY_BANDS`,
replacing the old `maxi(effective_top, datum)` — which just preserved
whatever the raw massif ceiling already was, the same
massif-ceiling-derived-height bug Task 1 fixed for houses. A 0-storey kind
is an open flat plot (top == datum). (Superseded 2026-08-21: courtyard
itself moved off `_apply_level_to_datum` onto the new `level_to_walk` op
entirely — see "Street-level courtyards and gardens" below; garden_terrace
moved with it. `_apply_level_to_datum` now governs large_house and
landmark_plot only.) The reservation dict gains `plot_top` for consumers
(the skyline-trim `reservation_roof` branch above, and the debug view).

**4. `WarrenMazeSourcePlan.record_trim(column, top_band) -> bool`** only ever
lowers a column's `top_band` — never raises it, and never touches
`floor_band` or `phase` for a column that already carries an edit (an
offender correction, or a reservation edit); it keeps the existing entry's
`floor_band`/`phase` and marks `trimmed: true`, or, for a column with no
prior edit, creates one at `{floor_band: effective_base, top_band, phase:
&"trim"}`. It rejects (false + `last_rejection`) when the ledger is sealed,
or when the requested `top_band` would sink below the column's own
`effective_base`. Refined 2026-08-21: a passage-hosting column is no longer
rejected outright (`record_edit`/`can_record_edit` still reject ANY other
edit there — a real floor correction or a leveling edit — streets stay
otherwise immutable); instead `record_trim` rejects iff `top_band` would fall
below `(any passage cell y hosted in that column) + HEADROOM_BANDS` — a trim
may never cut into a passage's own required headroom.
`WarrenMazeSourcePlan._passage_headroom_floor(column)` is that shared bound.
`seal()` mirrors both trim gates: no trimmed column's final `top_band` falls
below the tallest claim on that column (a trim may discard mass no claim
reaches, never cut into a house) and, for a passage-hosting column, never
below its own headroom floor. `deterministic_signature()`'s `e:` lines append
`:t` when the edit is a trim, so a trimmed and an untrimmed ledger with
otherwise identical floor/top values still produce distinct signatures.

Derived foundations (P5) are stacking-aware: only the *lowest* claim on a
column ever needs a foundation reaching down to terrain — everything stacked
above it is supported by the mass (and claim) below, not by an independent
foundation of its own — so `derive_foundations` keys `foundation_columns` by
each column's minimum floor_band across every claim that touches it, not by
whichever claim happened to be recorded last.

## Tier-driven heights, street-level courtyards, and the bridge-capable ledger (slice 1c task 1, approved in chat 2026-08-22)

Four changes, building on Task 2's carver `bridge_spans` (`WarrenExcavation.
bridge_spans: Array[Array[Vector3i]]` — contiguous, level-stride runs of
already-public passage cells whose overhead mass the carver retained instead
of opening to the sky, so a skywalk deck can stand on it) and on the
storey-budget/skyline-trim mechanics the prior section describes.

**1. Tier-driven height.** `WarrenMazeStampPass._find_tier_top(plan,
footprint, floor_band)` searches every passage cell hosted in one of
`footprint`'s own columns or its 1-column cardinal apron for the lowest y
that both clears `MIN_HOUSE_BANDS` above `floor_band` and sits at a
`STOREY_BANDS`-aligned distance from it — the same parity
`WarrenBuildingParcel.seal()`'s own
`(top_band - base_band - ROOF_RESERVATION_BANDS) % STOREY_BANDS == 0`
invariant already requires of every claim, pre-filtered here rather than
rounded after the fact so a tiered claim's `top_band` can equal a real
street y exactly. `_claim_top_band` uses this in place of the seeded storey
roll whenever it exists: `top = min(tier_top, ceiling_top, floor_band +
MAX_TIER_STOREYS * STOREY_BANDS)` (`MAX_TIER_STOREYS := 6`, a hard cap for a
pathological street many bands overhead), and records `tiered: true` on the
claim only when the result still equals `tier_top` exactly — a claim whose
street target got cut short by a lower physical ceiling, the tier cap, or
the existing 1×1 clamp reports `tiered: false`, since its roof no longer
matches any real street. With no qualifying street, the pre-task-1
seeded-roll path is unchanged. `_claim_top_band` returns
`{top, tiered}` now (not a bare int); every call site (direct rect/L
placement, back-extension, lateral extension, small-claim merge) threads
`tiered` onto the claim dict it writes.

**2. Street-level courtyards and gardens.** `courtyard` and `garden_terrace`
both move from a terrain-majority datum to a new registry edit op,
`WarrenMazeReservationPass._apply_level_to_walk`: datum is the y of the
lowest passage cell cardinally adjacent to the patch — "the adjoining walk
cell" — never a terrain average, so the plot always reads as a flat
extension of the street it opens off. Every column becomes
`{floor: datum, top: datum}` via `record_edit`; a candidate whose terrain
rises above datum on any column fails fit outright (try shrink/move, same
ladder as every other reservation) rather than partially leveling. A patch
with no adjoining passage cell at all (a candidate anchored purely at the
settlement rim, nowhere near a street) has no datum to level to and fails
fit the same way. **Rim sink-to-terrain retired (2026-08-21, controller
ruling):** the brief's original fallback — sink each column to its own
terrain when a rim-anchored candidate has no adjoining street — is REMOVED
outright, not merely unreachable: `_apply_sink_to_terrain` and the
rim-anchor addition to `_patch_candidates` (`_rim_columns`, the retired
`RIM_KINDS` constant) are deleted from the file. The user's latest
direction is "no exposed ground" — a courtyard or garden terrace is a
street-level flat plot only, at every scale, with no per-column-terrain
escape hatch. Confirmed safe to delete outright (not merely dead code) by
direct measurement: removing the rim-anchor addition produces
byte-identical reservation counts across the full seeds 1-12 x {compact,
standard} corpus, because `_apply_level_to_walk` requires a real adjoining
passage cell regardless of which anchor a candidate footprint was
enumerated from, and every footprint a rim anchor ever reached was already
reachable from a passage-adjacent one. The reservation dict gains
`plot_kind: &"flat"` for both kinds; `PLOT_STOREYS` is unchanged (0 for
both — an open plot, no
built mass above the leveled floor).

**3. Skywalk spans, non-optional, bridge-consuming.** `skywalk_span`'s quota
drops the `optional` flag (compact (1,1), standard (1,2), large (2,3), grand
(3,4) — compact's minimum rises from 0 to 1) — every town now gets at least
one skywalk. `WarrenMazeReservationPass._claim_bridge_span` tries
`plan.excavation.bridge_spans`, in array order, before `claim_overhead`'s
pre-existing flank search: the first span not already consumed by an
earlier instance and not blocked by another reservation/claim becomes a
reservation whose `cells` are the span's OWN passage columns (the retained
deck itself, not flanking walls), `walk_cells` the span's cells, `datum_band
= span y + HEADROOM_BANDS`, `plot_top = datum + STOREY_BANDS`, committed via
`record_edit(column, datum, plot_top, &"reserve")` on every span column —
legal only because of rule 4 below. All-or-nothing (`can_record_edit`
pre-validates every column before any commits), mirroring
`WarrenMazeStampPass._record_offender_batch`'s own atomic-commit pattern. A
town whose bridge_spans is empty, or already exhausted by an earlier
instance, falls through to the unchanged flank search — the quota is
satisfiable either way. `derive_foundations` and `_skyline_trim` both
discriminate a bridge-consumed reservation from a flank one by the
`plot_top` key the flank path never sets: the bridge deck genuinely owns a
raised floor (a real foundation entry, real trim-to-plot_top accounting),
where the flank path's untouched columns still stand on grounded natural
rock and stay exempt exactly as before.

**4. Bridge-capable ledger.** `record_edit`/`can_record_edit` no longer
reject a passage-hosting column outright — they accept it iff `floor_band
>= _passage_headroom_floor(column)` (the same shared bound `record_trim`'s
own gate already used: the highest passage cell that column hosts, plus
`WarrenExcavation.HEADROOM_BANDS`), so a floor that clears the street above
it is a legal "bridge house" standing directly over a passage. `seal()`
mirrors the same rule for every non-trim edit, replacing the old blanket
`_column_has_passage` rejection. `WarrenMazeStampPass._column_bears` gains a
matching exemption: a column bears automatically the instant its floor
lands *exactly* on a hosted passage's own future-trimmed roof slab
(`headroom_floor + TUNNEL_ROOF_BANDS`) — the same flush logic
`_stacks_on_existing_claim` already grants an existing claim's own roof,
extended to the not-yet-claimed tunnel roof skyline trim will leave standing
there regardless; a floor at any other height on a passage-hosting column
still falls through to the unmodified plinth-continuity walk.
`WarrenMazeSourcePlan.seal()`'s own bearing re-validation (the pre-edit,
`state_at_raw` mirror of `_column_bears`) grants the identical exemption, or
a real bearing claim built on this exact mechanism would seal-reject with
"not a bearing edit onto a solid plinth" the instant its floor landed on the
tunnel roof rather than on continuous rock. This is the actual mechanism
behind the "well above 12.7%" upper-street ratio the prior section's plinth
refinement aimed for and measured as unmoved: the blocker was never the
plinth math, it was that `record_edit` rejected the resulting edit outright
regardless of how far above the passage the floor sat. Measured on seeds
1/3/4/12 compact (aggregate): 24/68 = 35.3% of claims are upper-street,
up from 8/63 = 12.7% before this rule.

**Fixed (controller ruling, 2026-08-22): the translator no longer loses a
column's street to a bridge/bearing edit.** `WarrenMazeVolumeAdapter.
_edited_massif` used to overwrite an edited column's reported `[base, top)`
with `effective_base`/`effective_top` wholesale for every edited column —
correct for an ordinary foundation-raising edit (the discarded gap becomes
construction's own foundation courses, below), but for a column whose edit
clears a *hosted passage's* own headroom (rule 3's bridge deck, or rule 4's
bearing-on-tunnel-roof claim), the discarded gap contained that passage's
own walk cell, and `WarrenVolumeEnvelope.contains_air_column` rejected it
as outside its own envelope (`"walk cell leaves the envelope at <cell>"`).
Fixed at the source: a passage-hosting column's ledger floor means "the
house floor above the street", never "the bottom of this column's mass"
(`WarrenMazeSourcePlan.effective_base()` documents this explicitly now).
`_edited_massif` now keeps such a column's `base` at the ORIGINAL massif
base — true terrain, the rock the street itself still stands on — and only
raises `top` to the ledger's own `effective_top`; a non-passage column is
unchanged. `WarrenMazeSourcePlan.state_at()` gained the same two-zone
reading: below the highest hosted passage's own headroom floor, it reports
the RAW massif range (real rock the ledger never legitimately reaches,
since `record_edit`/`record_trim`'s own gates already forbid a
passage-hosting column's floor or trimmed top from ever landing below that
line); at and above it, ledger-aware reporting is unchanged.
`WarrenMazeStampPass.derive_foundations` measures a passage-hosting
column's foundation depth from that same headroom floor rather than
terrain — the rock between terrain and the headroom is real, untouched
massif the street already runs through, not something construction needs
to fabricate.

**Fixed (controller ruling, 2026-08-22, additive-only):
`WarrenBuildingParcel._has_continuous_bearing` gained a second branch for
bearing on a tunnel's own roof.** The legacy check demanded unbroken solid
mass from `envelope.ground_at(column)` up to a parcel's own floor — vacuous
for any edited column under the old `_edited_massif` bug (`ground_at`
collapsed to the edited floor, so the walk range was always empty), and,
once that bug was fixed, genuinely exercised for a passage-hosting column
for the first time, where it necessarily crosses that passage's own carved
headroom and fails. The FIRST branch (full continuity) is byte-for-byte
unchanged and always tried first; a SECOND branch, tried only when the
first fails, passes iff every non-solid cell between ground and the floor
is public realm (`WarrenVolumePlan.has_public_air` — the volume's own
authoritative record of what the excavation carved, read through the
volume rather than the source plan), the `PLINTH_BANDS` bands directly
below the floor are solid (the tunnel's own roof slab) *unless* the floor
lands exactly `TUNNEL_ROOF_BANDS` above the carved run's own top (the one
flush case `WarrenMazeStampPass._column_bears` already grants
unconditionally, for the identical reason), and everything below the
lowest carved cell is solid down to ground. Both constants are referenced
from `WarrenMazeStampPass`, never duplicated. Regression-proven additive:
`test_warren_maze_carver.gd` (10/10), `test_warren_spatial_fabric_compiler.
gd` (11/11), and `test_settlement_fabric.gd` (42/42) — the legacy,
non-maze parcel consumers — all pass unchanged.

Measured effect on the full 24 seed×scale sweep (source seal → volume →
translated `WarrenParcelPlan`), as of the `WarrenBuildingParcel` fix alone
(before the per-cell headroom fix below): 18/23 reachable combinations
translated end-to-end, up from 1/23 with only the `_edited_massif` fix
applied (one seed, compact 7, never reaches translation — a pre-existing
carve-stage floor miss, unrelated). 5 still failed: 2 pre-existing,
unrelated seal rejections (compact 8's route/floor-slab gate, compact 11's
load-path gate); 3 shared one precisely diagnosed, narrower remaining
gap, fixed next.

**Fixed (controller ruling, 2026-08-22): passage headroom is a per-cell
fact, not a constant.** The 3 remaining drops above all shared one root
cause: `WarrenMazeSourcePlan._passage_headroom_floor` measured a hosted
passage's headroom using the fixed `WarrenExcavation.HEADROOM_BANDS`
constant, not that specific cell's own real carved height
(`excavation.slot_bands(cell)`), which is one band taller for a stair's
intermediate stride cell (it carries both treads). `WarrenMazeStampPass.
_column_bears`'s exact-flush exemption then certified a claim as bearing
using the WRONG (too-low) threshold for such a cell — the real carved slot
left its floor resting on one more band of open air than the generic
constant assumed. Fixed at the single source of truth: new
`WarrenMazeSourcePlan.passage_headroom_top(cell) = cell.y +
excavation.slot_bands(cell)`; `_passage_headroom_floor` (the shared bound
every headroom-measuring rule already went through — `record_edit`,
`can_record_edit`, `record_trim`, `seal()`'s headroom validations,
`state_at()`, `_column_bears`'s flush exemption) now computes its per-column
max through this one function. `WarrenMazeStampPass._skyline_trim`'s
tunnel-roof `keep` and `WarrenMazeReservationPass._claim_bridge_span`'s
bridge datum, which read the constant directly rather than through
`_passage_headroom_floor`, were updated to the same per-cell value.
`WarrenBuildingParcel.gd` needed no change — its own tunnel-roof bearing
check already read real carved cells off the volume (`has_public_air`),
never the constant, which is exactly why it caught the 3 claims as
genuinely not bearing on solid rock in the first place.

With this fix, the sweep reaches **22/23** — matching this design's own
pre-slice-1c historical baseline exactly. The one remaining failure
(compact seed 8, the route/floor-slab gate above) is pre-existing and
unrelated to headroom or bearing. Both of `test_translator_partition_is_
one_to_one_with_claims`'s pinned seeds now translate fully clean with no
tolerance branch: seed 4 unchanged at `maze_owned_solid_ratio = 0.6885`
(floor re-pinned 0.62 → 0.66); seed 12 measured for the first time at
`0.6750` (floor re-pinned 0.58 → 0.65).

## Out of scope

Multi-entrance boring, async settlement streaming (shrinks but is not
replaced), and biome/theme variation beyond the registry palette.
