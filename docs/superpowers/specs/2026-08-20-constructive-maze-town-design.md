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

## Out of scope

Noise-based massif (later contained swap behind the same massif interface),
multi-entrance boring, async settlement streaming (shrinks but is not
replaced), and biome/theme variation beyond the registry palette.
