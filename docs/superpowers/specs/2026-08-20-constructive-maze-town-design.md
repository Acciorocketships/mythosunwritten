# Constructive maze town generation — design (2026-08-20)

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
2. **courtyard / park** — lower built mass toward the terrain floor; terrain
   showing through is the park surface.
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

**Bearing (fix round 4, 2026-08-21 — the upper-street unlock).** A column is
also exempt from the ±1 terrain-offender budget when its mass is
*continuous SOLID rock* from its own base up to the candidate's floor
(`_column_bears`, ledger- and occupancy-aware so it never mistakes another
claim's own not-yet-trimmed footprint for open mountain), regardless of how
far above terrain that floor sits — the column isn't floating, and the depth
below the raised floor becomes real deep foundation via the existing
`derive_foundations` accounting. Because candidates are scored once, all up
front, before any of them commit, a bearing verdict computed at enumeration
time can go stale by the time a candidate's turn to commit actually arrives
(an earlier, higher-scored candidate may have claimed the same column's mass
in between), so `_footprint_offenders` is re-run against the live occupancy
map at commit time rather than trusting the cached enumeration-time result.

Lineage grouping's adjacency stays 2D-column-plus-one-band, unchanged: a
stacked claim's floor differs from anything below it by at least
`MIN_HOUSE_BANDS` (4) bands, far outside the 1-band grouping tolerance, so a
stacked pair is never mistaken for one lineage.

**3. Skyline trim (P4.5)**, called from `stamp()` after lineage grouping,
before `derive_foundations`, over every massif column in deterministic sorted
order (skipping only reservation cells — already typed, already leveled by
P3, stay exempt outright): a **claimed** column trims down to the tallest
claim's own top on that column (its real roofline). A **passage-hosting**
column (refined 2026-08-21: no longer exempt outright — that left every
covered tunnel, ~47% of the network, standing under the full massif ceiling)
keeps `keep = max(any claim's own top on the column, highest passage cell y +
WarrenExcavation.HEADROOM_BANDS + WarrenMazeStampPass.TUNNEL_ROOF_BANDS)`
(`TUNNEL_ROOF_BANDS := 1`, a thin roof over the required headroom), folds in
the same 4-neighbour "shoulder" an unclaimed column uses (a tunnel between
two tall buildings should read at least as tall as they do), and trims to
`max(keep, shoulder)`. An **unclaimed, non-passage** column takes its
"shoulder" — the tallest claim among its four cardinal neighbours — trimming
to that, or, with no claimed neighbour at all, discards straight to its own
terrain (the old pipeline's `_discard_unassigned_mass`, now reached by
construction rather than as a separate late step). Every target is computed
first, entirely from pre-trim claim tops and pre-trim `effective_top`, then
applied in the same sorted order — deterministic regardless of Dictionary
iteration order. Outcomes are counted by kind (`claimed_roof`, `tunnel_roof`,
`shoulder`, `discarded`) in `plan.audit["trim_outcomes"]`.
`WarrenMazeStampPass.skyline_trim_enabled` (default true) exists solely so a
test can compare a plan's pre- and post-trim tops.

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

## Out of scope

Multi-entrance boring, async settlement streaming (shrinks but is not
replaced), and biome/theme variation beyond the registry palette.
