# Warren Terrace-over-Tunnel Motif — Design Spec

**Date:** 2026-08-10
**Status:** Proposed (design only). No production code in this commit.
**Branch:** `feat/mass-first-warren`
**Extends:** `docs/superpowers/specs/2026-08-09-warren-terrain-integration-design.md`
(phase 2 of the reviewer-approved Option C), whose Wave 5 closed with the
synthesis this document answers.
**Refutes, on new evidence:** `task-24-report.md` §6 concern 5 ("a future wave
attacking requirement 3 should RESTORE the reverted sunken-street diff rather
than re-derive it"). §3.1 below shows the reverted mechanism cannot render even
if every plan-level gate passes, because a heightfield has no hole. The
mechanism it replaces is a near-relative, and the difference is one datum.

---

## 1. Problem

The project's reviewer has asked for one thing in every review round: paths
that snake through the city and are frequently covered — "tunnels underneath
skywalks and other buildings", "weaving underneath buildings", "buildings
should be built on paths which themselves are overpasses".

After the terrain-integration waves the towns are hillside villages of grounded
2–3 storey houses on real terrain, and they have **zero covered street cells at
fabric level**: `0 of 174` and `0 of 186` public floor cells carry a building on
the two seeds that reach a sealed fabric, and **zero `INTERIOR_PASSAGE` cells**
on either (task-23-report §5, task-24-report §5).

Six structural attempts have failed, each closed with measured evidence. They
are constraints on this design, not history:

| # | Attempt | Why it died | Ledger |
|---|---|---|---|
| 1 | Bridging houses on the thick massif | A spanning footprint is always `mixed_span`, so it never descends and needs 6 bands above the 3-band slot; the bore left 1–8. Zero legal bridges on 10 seeds. | 152 |
| 2 | Skywalk seeding | Not a seeding shortage — 11–51 corridors form, 0–1 survive. Envelope refusals: authored roofs stand 0.23–0.36 m proud against a 0.10 m tolerance. | 157 |
| 3 | Route-height caps | Cover deepened (spans 4→8) and yielded zero bridges at every setting; refusals migrate from height to bearing. | 157 |
| 4 | Partition over streets | `_admitted` only admits faces for columns that FLANK the route, so a column the route passes THROUGH is never a threshold. 37–77 solid cells/seed stand over streets, unbuilt. | 147 |
| 5 | Thin-layer surface streets | A 4–6 band layer minus 3 bands of headroom leaves ≤3 bands: nothing can stand over a street at all. | 247 |
| 6 | Sunken streets alone | The sink must equal `HEADROOM_BANDS` exactly; 41 tunnel columns, 9 with any adjacent surface public cell, **0 street-wall faces**, because `_minimum_bands` wants a 6-band envelope at an at-grade address. Lanes 50→27, four pinned floors broken. Reverted. | 251 |

Wave 5's closing synthesis, adopted by the controller and the starting point of
this document:

> The covered path needs **four** things — a sunken street, mass above it, rooms
> in that mass, and **public realm on the terrace over the tunnel** for those
> rooms to front onto — and no mechanism owns the fourth. Tunnels are a
> COMPOSED MOTIF. The lane network and the tunnel problem are the same problem
> stacked.

They are the same problem in a second, sharper sense this document establishes:
the lane web collapsed (median 1 lane/town) because a thin layer puts 45% of
route cells at grade and the arcade reserve then haloes almost the whole massif;
and the terrace over a tunnel is precisely a lane the reserve forbids. One
change to how public realm is separated buys both.

---

## 2. What exists today

### 2.1 Two headroom constants, and the street slot

`WarrenExcavation.HEADROOM_BANDS = 3` (`WarrenExcavation.gd:16`) is the void a
street cell removes. `WarrenVolumePlan.HEADROOM_BANDS = 2`
(`WarrenVolumePlan.gd:11`) is the public air a walk cell claims in the sealed
plan. A band is 1.5 m (`WarrenVolumePlan.gd:10`); a storey is
`WarrenBuildingParcel.STOREY_BANDS = 2` = 3 m; a roof reservation is another 2
(`WarrenBuildingParcel.gd:7-8`). A terrain storey is `HeightfieldPlan.STOREY_HEIGHT`
= 4 m = 2.67 bands.

`WarrenMassif.BUILDABLE_LAYER_BANDS = 6` (`WarrenMassif.gd:27`); the builder
tapers the authored layer from `layer_core ∈ [4,6]` at the crown to
`MIN_LAYER_BANDS = 4` at the rim (`WarrenMassifBuilder.gd:34-35,142-145`).
Everything below that layer is terrain.

### 2.2 One inequality governs every house

Four sites state the same rule, and it is the constraint the whole design turns
on. Let `G` be the highest bearing datum under a footprint, `B` the house's base
band (which `WarrenBuildingParcel.seal():46` forces to equal its address band),
`d = B − G`, and `T` the column top.

`WarrenSolidPartitioner._minimum_bands` (`:557-590`):

```
needed = MIN_STOREYS * STOREY_BANDS + ROOF_RESERVATION_BANDS      # = 6
if not grounded: return max(MIN_HOUSE_BANDS, needed)              # = 6
needed -= B - min(G, B)                                           # apparent-face credit
return max(MIN_HOUSE_BANDS, needed - posmod(needed, 2))           # even envelope
```

so the envelope `E` and the required column height above `G` are:

| `d` | `E` | `T ≥` | apparent face | storeys drawn |
|---|---|---|---|---|
| 0 | 6 | `G + 6` | 6 | 2 |
| 1 | 4 | `G + 5` | 5 | 1 + 1-band plinth |
| 2 | 4 | `G + 6` | 6 | 1 + 1 descended |
| 3 | 4 | `G + 7` | 7 | — impossible in the layer |

`d ∈ {0,1}` is therefore the whole reachable space in a 4–6 band layer, and the
matching floors are `MIN_APPARENT_FACE_BANDS = 5`
(`WarrenParcelConstruction.gd:263`, proved a verdict-identical restatement of
`storeys >= 2` over the whole input space in Wave 5) and the audit's independent
copy in `WarrenSolidPartitioner._wall_verdict` (`:511-521`).

**This is why every elevated public realm died in the thin layer.** An address 3
bands above its own ground needs a 7-band column; the layer offers 6.

### 2.3 The bearing datum already exists, and already anticipates a tunnel

`WarrenVolumeEnvelope` carries two datums per column: `ground_at`
(`:107-108`) — "the datum every street, address, arcade and cover rule measures
mass from" — and `bearing_at` (`:111-121`) — "the band a house grounds to".
`_seal` bounds the second inside the first (`:190-194`). `WarrenMassif.bearing_at`
(`:188-209`) computes `maxi(base_at, top_at - BUILDABLE_LAYER_BANDS)` and is
currently degenerate (equal to `base_at` for every column a builder produces).

`WarrenParcelConstruction.retained_terrace_cells` (`:97-110`) already reads
`bearing_at` with this comment, written in Wave 5 for a wave that had not
happened:

> since the undercroft wave `ground_at` may sit below the surface where a street
> tunnels under the column, and a plinth measured from there would fill the
> tunnel with foundation stone… A street cut through the gap — the bore under a
> plinth, or a secondary lane tunnelling beneath a terrace — is void the plan
> already removed.

`WarrenSolidPartitioner._minimum_bands:588` and `_wall_verdict:516` read
`massif.bearing_at`; `WarrenParcelConstruction._support_base_band:241` and
`apparent_face_bands:275` read `envelope.bearing_at`. **One reader has not been
migrated:** `WarrenBuildingParcel._has_continuous_bearing` (`:147-155`) still
reads `envelope.ground_at`. §3.6 shows that single line is what decides whether
a house over a passage is grounded or `mixed_span`.

### 2.4 The arcade reserve binds the lane web and the motif to one constant

`WarrenExcavationCarver.LANE_ARCADE_RESERVE_CELLS` (`:289-290`) is *derived*
from `WarrenGroundArcadeSolver.MIN_BRANCH_SEPARATION_CELLS = 4` (`:20`), and
`_arcade_reserve` (`:501-516`) haloes every **grade** route cell by that radius
in columns. `_lane_stride_cells:716` refuses any lane cell inside it.

The reason is real: `WarrenGroundArcadeSolver._find_path` (`:142-155`) collects
`existing_auxiliary` = every walk cell not on the primary itinerary, and rejects
a secondary root whose **column** distance to any of them is under 4 —
`_distance_to_cells` (`:188-195`) ignores `y` entirely. A lane eight bands
overhead therefore disqualifies a root it can never contest.

Measured cost (ledger 241, 19 towns): the reserve is the sole blocker on
**715 of 955** sole-blocked lane strides (75%), **84%** of anchors sit inside
it, and it covers 21% of all massif columns because a thin layer puts 45% of
route cells exactly at grade. Lanes/town: median 1.

### 2.5 Nothing emits `INTERIOR_PASSAGE`, and the realm forbids it

`PublicRealmSurfacePlan.SurfaceKind.INTERIOR_PASSAGE` (`:9`) is a fully
implemented, rendered surface: `SettlementFabricAssembler` planks it
(`:462-465`) with its own material (`:643`), and
`warren_mass_first_preview._covered_route_eye` (`:436-456`) treats it as the
definition of "the street runs through the inside of a building".

**No producer emits it.** The only two `PublicRealmNode.new` sites are
`WarrenVolumePublicRealmAdapter:52,78` and `SectionalPublicRealmBuilder:125`;
the mass-first classifier is a two-way test —

```gdscript
# WarrenVolumePublicRealmAdapter.gd:311-315
return SurfaceKind.TERRAIN_STREET if cell.y == source.envelope.ground_at(...) \
    else SurfaceKind.STRUCTURAL_COURT
```

— and `SectionalPublicRealmPlan.add_node:36-40` rejects an `INTERIOR_PASSAGE`
node outright in an `EXTERIOR` realm, which is the only realm either adapter
builds (`WarrenVolumePublicRealmAdapter.gd:25-27`).

So the headline acceptance metric is blocked twice over: no geometry produces a
tunnel, **and** if one did it would be labelled a terrain street.

### 2.6 What draws below a house today

Since the buildable-layer wave the fabric draws no substrate. The only thing
under a house is the plinth: `WarrenParcelConstruction.retained_terrace_cells`
(`:76-117`) → `WarrenFabricCompiler.gd:97-110` →
`SettlementFabricPlan.retained_terrace_cells` →
`SettlementFabricAssembler.house_plinth_walls` (`:223-252`), capped at
`WarrenMassif.PLINTH_BUDGET_BANDS = 2` (`:96`). Declared mass that nothing draws
is the exact mechanism of ledger 206's reverted grounding fix: 74/92 and 84/100
houses floating over undrawn substrate.

---

## 3. Architecture — the terrace over an undercroft

### 3.1 First, a refutation: the terrain cannot carry the tunnel

Attempt 6 sank the street below the rising **terrain** so the mass over it was
the stamped hill. Its plan-level failure is recorded. Its rendering failure was
never measured, because zero houses stood over a tunnel and there was nothing to
look at, and it is decisive:

- `SettlementReliefPlan` raises `HeightfieldPlan`'s continuous field before
  quantization (`SettlementReliefPlan.gd:206-234`). A heightfield is one height
  per cell. **There is no expression for a hole.**
- The mesher, the KayKit cliff dressing and the terrain collider all follow that
  single surface. A street sunk under a bench would be inside the terrain shell:
  visually the backfaces of a cliff skirt, and physically a collider across the
  mouth.
- The stamp works on the 24 m terrain lattice; the passage is 3 m wide. A notch
  is not representable even in principle.

There is a second, independent reason. A sink deeper than `HEADROOM_BANDS`
leaves solid bands between the tunnel ceiling and the column's own ground that
are declared as mass and classified by `WarrenPrunedMassPlan.seal:45-51` as
bearing opportunity — declared, and drawn by nothing. That is ledger 206's
defect again.

**Conclusion.** The one storey of structure between a street and the rooms above
it must be **fabric**, not terrain. Everything above the terrain surface is
already rendered and collided by the fabric; everything below it is not. That
single sentence determines the whole design, and it converts the relief budget
from a prerequisite into a supply lever (§3.9).

### 3.2 The motif

> **UNDERCROFT + DECK.** A short run of massif columns is founded one street
> storey above the terrain instead of on it. The `HEADROOM_BANDS` of open air
> beneath them is the **undercroft**, carried by authored supports. A passage is
> bored through the undercroft at terrain grade. The columns' own buildable
> layer, unchanged in thickness, sits on the **deck** above; a lane runs on that
> deck and the houses it addresses stand over the passage.

Every one of the synthesis's four requirements is owned:

| Requirement | Owner |
|---|---|
| a sunken street | the passage, at terrain grade, under a lifted deck — the ground rises by fabric, not by terrain |
| mass above it | the columns' own buildable layer, lifted intact |
| rooms in that mass | the existing partition, with no new rule (§3.6) |
| **public realm on the terrace over the tunnel** | the deck lane, which is an ordinary `WarrenExcavation` lane once the reserve stops forbidding it (§3.4) |

The lift is expressible as **one optional per-column integer on `WarrenMassif`**
and it moves `base_at` and `top_at` together, so `layer_at` — which is what every
massif shape gate now measures (`WarrenMassif.gd:140-152`,
`WarrenMassifBuilder._worst_neighbor_step:201-215`, `widest_plateau_cells:226`,
`terrace_levels:212`) — **is invariant under it.** The massif's whole gate
battery is untouched by construction, not by measurement.

### 3.3 The geometry, band by band

Notation: `g` = the terrain ground band of the motif footprint (a flat run,
which the terraced stamp supplies in abundance — largest constant-band run under
a footprint 767 and 861 columns, ledger 227). `U = WarrenExcavation.HEADROOM_BANDS
= 3`. `D = g + U` is the **deck datum**. `ℓ = layer_at ∈ [4,6]`, unchanged.
`T = D + ℓ` is the column top. `L` is the deck lane's floor. `B = L` is the
house base.

| # | Quantity | Value | Authority |
|---|---|---|---|
| 1 | motif column `base_at` | `D = g + 3` | derived massif |
| 2 | motif column `undercroft_at` | `3` (= `U`) | new accessor, `0` everywhere else |
| 3 | motif column `top_at` | `D + ℓ`, `ℓ` unchanged | `layer_at` invariant |
| 4 | `bearing_at` | `max(base_at, top_at − 6) = D` for every `ℓ ≤ 6` | `WarrenMassif.gd:209` — **already correct, no new datum** |
| 5 | passage floor | `s = g = D − U` | §3.4 |
| 6 | passage slot | `[g, g+3)` — exactly the undercroft, never straddling | amended `_slot_is_borable` (§3.4) |
| 7 | `covered` at a passage cell | `top_at > s + 3` and `s+3` uncarved ⇒ **true** | `_finalize:849-854`, unchanged |
| 8 | `_is_at_grade` at a passage cell | `s ≠ base_at` ⇒ **false** | `:984-988` — the passage adds nothing to `MIN_GRADE_CELLS` and nothing to the arcade reserve |
| 9 | deck lane floor | `L = D` (if `ℓ = 6`) or `L = D + 1` (if `ℓ ≥ 5`) | §2.2 table |
| 10 | lane slot | `[L, L+3) ⊆ [D, D+ℓ)` ⇒ `ℓ ≥ 3` (L=D) or `ℓ ≥ 4` (L=D+1) | `_slot_is_borable:1104-1122` |
| 11 | house base | `B = L` | `WarrenBuildingParcel.seal():46` |
| 12 | house envelope | `E = 6` (d=0) or `E = 4` (d=1) | `_minimum_bands:557-590` |
| 13 | house top | `B + E = D + 6` or `D + 5` ⇒ **`ℓ ≥ 6` or `ℓ ≥ 5`** | `_top_band:976` caps at `massif.top_at` |
| 14 | apparent face | `6` or `5` — `≥ MIN_APPARENT_FACE_BANDS` | `apparent_face_bands:266-276` |
| 15 | plinth | d=0: none. d=1: `resolve_support_band(D, D, D+1, 2)` resolves the parity **up** ⇒ **1 band** of `sfv.foundation.rock` on the deck | `:279-294` |
| 16 | bearing under the house | `range(bearing_at = D, B)` — empty (d=0) or one mass band (d=1) ⇒ **grounded**, `support_mode = "terrain"` | `WarrenBuildingParcel:147-155`, **after §3.6's one-line change** |
| 17 | overpass flag | `B − s = 4 or 5 ≥ WarrenVolumePlan.HEADROOM_BANDS(2)` ⇒ `has_occupied_overpass = true` | `_covers_lower_walk:158-166` |
| 18 | street walls at band `g` | motif columns have `base_at = D > g` ⇒ **excluded from `_raw_street_walls`** and from `_can_carry_house` | `:485-488`, `:545` |
| 19 | composed face at the mouth | `U + face` = 8 or 9 bands, of which the lower 3 are an open colonnade | reviewer question, §9 |

Two readings of the table matter more than the rest.

**Row 18 is the containment proof.** A passage generates no street-wall face and
no raw street wall, because every column beside it is founded *above* the
passage floor. The ownership guarantee — "`unowned` is 0" — is therefore
untouched by the motif rather than defended against it. The columns at the run's
edge are ordinary unlifted columns and behave exactly as they do today.

**Rows 12–13 are the supply constraint.** The motif needs `ℓ ≥ 5`, which the
rescaled Gaussian gives over an annulus when `layer_core ≥ 5`
(`WarrenMassifBuilder.gd:107-108,142-145`) and never when `layer_core = 4`.
This is the design's own falsification test and Wave 0 measures it before a line
of production code is written (§6, §7).

**The relief budget participates in exactly one place, and it is optional.** The
deck datum `D = g + 3` is one warren band above a 4 m terrain riser measured at
either `ceil` phase (`4.0/1.5 = 2.67` ⇒ adjacent bench bands differ by 2 or 3).
Siting a motif against a bench edge therefore makes the deck level, or one band
off level, with the ordinary at-grade street on the bench above — which is what
gives the deck lane a natural anchor and makes the motif read as the town
growing out over its own street. More budget ⇒ more benches ⇒ more such edges.
Nothing in the motif *requires* it: on flat ground the deck lane anchors on the
bore where the bore already stands at `D ± 1`.

### 3.4 Planning order, and why the carver does not own this

**The motif is a stage seam: `WarrenTerraceTunnelMotif.apply(massif, excavation,
world_seed) -> {massif, excavation}`, called from `WarrenTownSolver.mass_first_frontier`
(`:357-439`) between `WarrenExcavationCarver.carve` (`:385`) and
`WarrenExcavationVolumeAdapter.to_volume_plan` (`:390`).** It returns a *derived*
massif and a *derived* excavation, leaving both inputs byte-identical.

The three alternatives and why they lose:

- **Inside `_bore`'s 256-attempt search.** The motif changes `base_at`, and the
  frontier bores ONE massif up to `MASS_FIRST_EXCAVATION_ATTEMPTS` times
  (`:384-386`). Mutating it would contaminate every later bore. Six attempts
  have also now shown that steering a scored search toward a composed structure
  produces the structure's ingredients and never the structure (attempts 2, 3, 6).
- **A solver after the adapter.** The passage is public realm, and public realm
  is only legal as a `WarrenExcavation` lane that `seal()`
  (`WarrenExcavation.gd:90-134`) validates and the adapter tiles into
  `WarrenVolumeTransition`s. Anything added later re-implements that contract —
  the duplication this ledger has punished twice (the audit that shared the
  partitioner's admission rules; `_minimum_bands` in three places).
- **A pre-massif planner.** The lift is only legal where a passage actually runs
  beneath it (§3.5), and the passage is not known until the route is. A
  pre-massif planner would have to guess and then revert, and reverting a lift
  after a bore changes `_is_at_grade` and the grade count the bore was accepted on.

Running after `carve()` and before the adapter gives the motif exactly the
inputs it needs (a finished street network on a finished massif) and exactly one
consumer to satisfy.

**The transaction.** `apply` is atomic and reuses the protocol
`_lane_survives`/`_roll_back_lane` (`:794-827`) established for lanes:

1. Enumerate candidate sites deterministically from `(massif, excavation,
   world_seed)` — no floating-point state, no iteration over a `Dictionary`
   without a sort.
2. For each site, in order, build the derived pair: lift the run's columns,
   append the passage as an ordinary lane record, append the deck lane.
3. Re-measure **every route gate** against the derived pair — `_flank_count`,
   `_wall_count`/`MIN_WALL_RATIO`, `covered`, `_route_addressed_count`,
   `_grade_cells`/`MIN_GRADE_CELLS`, `_grade_spread` — exactly as
   `_lane_survives` does, plus `WarrenExcavation.seal()`. A lift removes mass
   from bands `[g, D)` beside any at-grade route cell that runs past the run, so
   the wall ratio genuinely can move; it is re-measured, never argued.
4. Reject the site wholesale on any regression and continue; accept at most
   `MAX_MOTIFS` sites per town.
5. If no site survives, return the inputs unchanged.

**Site legality** (all measured on the input pair, all integer):

- a 4-connected run of 2..`MAX_PLATEAU_CELLS` columns, every one with equal
  `base_at = g`, `ℓ ≥ 5`, at least 2 columns inside the footprint boundary, and
  no column touched by the bore, a lane, or a portal;
- a public cell at band `g` 4-adjacent to one end of the run (the passage's
  anchor — you walk in off the street);
- a public cell at band `D ± 1` within 2 columns of the run (the deck lane's
  anchor);
- the passage covers **every** lifted column (§3.5).

**Coordination with the relief stamp is by construction.** The stamp is upstream
of `ground_bands`, `ground_bands` is upstream of the massif, and the motif is
downstream of both and writes nothing below the terrain surface. Terrain, street
and lane agree because the terrain never moves. This is the direct dividend of
§3.1's refutation.

### 3.5 The one new carver rule, and one invariant that pays for it

`_slot_is_borable` (`:1104-1122`) currently requires the whole slot to lie
inside `[base_at, top_at)`. The motif needs one clause:

```
borable(cell, bands) :=
      (cell.y >= base_at(c) and cell.y + bands <= top_at(c))          # today
   or (undercroft_at(c) == bands and cell.y + bands == base_at(c))    # the undercroft
```

stated as an **identity**, not a bound. That is task-24's hard-won "the sink
must equal `HEADROOM_BANDS` exactly", re-derived from the lift rather than from
terrain, and it forbids a slot that straddles the deck. With `undercroft_at`
returning 0 for every column no motif lifted, the clause is unreachable and the
predicate is byte-identical — for route-first and for every mass-first town
without a motif.

**The invariant that makes the whole design safe: a column may be lifted only if
the passage carves its entire undercroft.** It buys three separate guarantees at
once:

- no declared-but-undrawn mass (§2.6's floating-house defect cannot recur);
- no unowned street wall — an unlifted-but-uncarved column beside the passage
  would be admitted at band `g` by `_can_carry_house` and housed with a 6–8 band
  envelope, which is the tower the reviewer rejected;
- the envelope's mass continuity (`WarrenVolumeEnvelope._seal:186-189`) and the
  plan's subtraction meet exactly: the adapter declares `[g, T)` as mass and the
  passage removes precisely `[g, D)`.

`_addressable_sides` (`:727-756`) — a lane must front a column that can carry a
house at the lane's own band — is **false at every passage cell** by row 18, and
correctly so: a covered way addresses nothing at its own level; its justification
is the deck above it. The passage is therefore not an ordinary lane and the motif
solver owns that exception explicitly rather than relaxing the rule for all lanes.

### 3.6 Addresses: nothing new in the partition, one line at the parcel

The deck lane enters the plan through the existing path: it is an
`excavation.lanes` record, so `WarrenExcavationVolumeAdapter._add_transitions`
(`:103-110`) gives it walk nodes at its transition endpoints and
`to_volume_plan:118-119` registers every excavated cell as `add_frontage`, which
is the mechanism `WarrenBuildingParcel.seal():47` tests through `has_frontage`
(`WarrenVolumePlan.gd:143-144`).

From there the partition needs **no changes whatsoever**, and this is the
strongest single claim in the document. Traced site by site for a motif column
`c` addressed from a deck lane cell at band `L`:

| Site | Reads | Result |
|---|---|---|
| `_wall_candidates:332-345` | `excavation.public_cells()` | the deck lane is a public cell; `c` is its 4-neighbour |
| `_can_carry_house:536-554` | `base_at(c) = D ≤ L`; `needed` = 6 or 4; `top_at(c) = D+ℓ`; carved scan `range(D, L+needed)` | passes; the passage's carved cells are at `[g, D)`, **below the scan** |
| `_admitted:349-404` | one face per column, highest street first | `c` has exactly one face (row 18 removes the passage's) |
| `_top_band:940-989` | `claimed`, `face_bands`, `top = min(top_at)`, carved scan `range(base, top)` | passes; `settled = D+6` or `D+5`… even by construction |
| `_is_grounded:992-1000` | `range(massif.base_at(c) = D, B)` | empty or one mass band ⇒ **grounded** |
| `_raw_street_walls:472-492` | `base_at(c) > walk.y` at band `g` | passage excluded ⇒ `unowned` cannot grow |
| `_wall_verdict:495-522` | `massif.bearing_at(c) = D` | consistent with `_minimum_bands` |

The single production line that must change lives one class away.
`WarrenBuildingParcel._has_continuous_bearing` (`:147-155`) reads
`volume.envelope.ground_at(column)`, which the adapter lowers to `g` so the
passage cell can satisfy `contains_air_column` (`WarrenVolumeEnvelope.gd:132-135`,
`WarrenVolumePlan.seal():202`). It must read **`bearing_at`**:

```gdscript
var ground := volume.envelope.bearing_at(column)   # was ground_at
```

Without it the scan runs `range(g, B)` across the passage's public air, the
column is not a bearing column, a 1x1 house fails `bearing_columns.size() * 2 <
footprint.size()` (`:87`) outright and a 1x2 becomes `mixed_span` — which
`_support_base_band:234-236` refuses to descend and `_minimum_bands`'s
non-grounded branch charges 6 bands to, reproducing **attempt 1's exact
impossibility**. With it, the house grounds to the deck, which is what physically
carries it.

Route-first safety is the boolean identity the reviewer has already accepted once
for `has_frontage` (ledger 109): `bearing_at` returns `bearing_bands.get(column,
ground_at(column))` (`WarrenVolumeEnvelope.gd:121`), and `bearing_bands` is empty
on every envelope `build()` grows (`:36`), so the two are the *same expression*
for route-first, not merely equal in measurement. The same argument covers every
mass-first column no motif lifted, since the adapter copies
`massif.bearing_at = base_at` there (`WarrenExcavationVolumeAdapter.gd:58`).

Two sibling datum reads move with it, for the same reason and with the same
proof:

- `WarrenGroundArcadeSolver._find_path:148` filters branch roots on
  `root.y != source.envelope.ground_at(column)`. With the undercroft declared, a
  passage cell would look like a grade root and the arcade could root a market
  inside a tunnel. It must read `bearing_at`.
- `WarrenVolumePublicRealmAdapter._episode_kind:302-308` would call a passage
  cell a `STREET`; it is an `UNDERCROFT`, which is an episode kind the enum has
  carried since the beginning (`PublicRealmNode.gd:10`).

`WarrenPlatformInfillSolver` reads `ground_at` in five places (`:79, 433, 527,
699, 804`). Each must be classified — "surface datum" or "envelope floor" — with
a stated reason, not swept. This is the sharpest hidden risk in the design (§7,
R4).

### 3.7 Classification: making `INTERIOR_PASSAGE` reachable

`_surface_kind` (`:311-315`) becomes a three-way test on the datum pair, which
is the same shape as the two-way test it replaces:

```
below the bearing datum and covered  -> INTERIOR_PASSAGE
at the bearing datum                 -> TERRAIN_STREET
otherwise                            -> STRUCTURAL_COURT
```

"covered" is already computed one function down (`_cover_policy:318-324`).
Route-first identity holds by the same empty-`bearing_bands` argument, plus a
stronger one: no route-first cell is ever below its own `ground_at`, so the new
branch is unreachable there.

`SectionalPublicRealmPlan.add_node:36-40` — "interior passage surface is illegal
in exterior realm" — must then be re-derived. The rule is a statement about a
journey that never goes indoors; a street tunnelling under a house is an interior
surface inside an otherwise exterior journey, which is the thing the reviewer has
asked for six rounds running. The re-derivation is cheap to make safe: the kind
has **no producer today** (grep-verified, §2.5), so permitting it cannot change
any existing plan. It should be permitted only for a node whose `cover_policy`
is `COVERED` and which is not the entry, so the rule still refuses an
"interior" open-air court.

### 3.8 Drawing the undercroft

The undercroft is the motif's one new rendering payload, and it is the one place
the design spends art rather than arithmetic.

- The adapter declares `[g, D)` as envelope mass; the passage removes it in the
  passage's own columns. Because §3.5's invariant makes those the *only* lifted
  columns, `WarrenPrunedMassPlan.seal:45-51` classifies nothing new and
  `pruned_exterior_air` does not grow.
- What is drawn is the **exposed faces of the undercroft void** — the piers
  between adjacent passage cells and the arch at each mouth — collected by
  `WarrenFabricCompiler` alongside `retained_terrace_cells` (`:97-110`) and
  emitted by `SettlementFabricAssembler` beside `house_plinth_walls`
  (`:223-252`), which is an exact structural analogue of an existing seam.
- The vocabulary is baked and unused: `sfv.arch.001`, `sfv.arch.002`,
  `sfv.entrance_arch.001`, `sfv.bridge.001`, `sfv.foundation.rock.001`, plus the
  KayKit pillar family (ledger 189/192). It is also the reviewer's own word —
  "the city should be comprised only of buildings, paths, **supports**, and any
  other assets you find in the assets folder" (ledger 188).
- **The no-scaling rule is absolute** and it killed the WWall rampart family for
  exactly this class of use (pieces 3.8–8.0 m on a 1.5 m lattice, ledger 216).
  Wave 0 measures every candidate against a 3.0 m × 4.5 m opening before any
  production code is written; if nothing fits, the answer is authored art and the
  design says so early rather than after five waves.

### 3.9 Determinism

The derived massif and excavation are pure functions of `(massif, excavation,
world_seed)`; the massif is a pure function of `(world_seed, ground_bands)`; and
`ground_bands` is a pure function of the relief stamp, which is a pure function
of `(world_seed, SEED_VERSION, cell)` (`SettlementReliefPlan.gd:29-31`). Site
enumeration sorts by an explicit total order before any selection, exactly as
`_lane_anchors` (`:566-577`) and `street_wall_faces` (`:322-324`) do, so no
`Dictionary` iteration order reaches an output.

---

## 4. The eight tall-massif-calibrated floors

The milestone has re-derived four and left four standing (ledger 235, 238).
Task-24 named a ninth. The motif's interaction with each:

| # | Floor | Where | Motif interaction |
|---|---|---|---|
| 1 | `MIN_CORE_BANDS` 16→8 | `WarrenMassifBuilder.gd:60` | **Satisfied naturally.** A lift raises `base_at` and `top_at` together, so `vertical_development_bands()` (`WarrenMassif.gd:169-185`) can only grow. The gate is a floor. |
| 2 | `MIN_SPAN_BANDS` 8→5 | `WarrenExcavationCarver.gd:61` | **Out of scope.** The motif adds no route cells; the bore's span is measured before `apply` runs and re-measured after, unchanged. |
| 3 | `ADDRESS_BANDS` 6→4 | `WarrenMassif.gd:52` | **Satisfied naturally, and helped.** `_route_addressed_count` (`:519-547`) is re-measured in the transaction and may only be preserved; a lift adds 3 bands of column beside nothing it takes away. |
| 4 | `UPPER_ROUTE_CROSSOVERS` 2→1 | `WarrenMassif.gd:75` | **Helped.** A crossing needs a route cell `≥ HEADROOM_BANDS` above an arcade cell in the same column (`_has_higher_public_walk_in_column`, `WarrenVolumePlan.gd:503-506`); a deck lane at `D = g+3` over an arcade at `g` is exactly that shape, and the two-band window the constant was re-derived against widens to the whole undercroft. |
| 5 | Arcade enclosure audit (`MIN_ENCLOSED_CELLS = 4`, `MIN_GROUNDED_FRONTAGE_CELLS = 4`) | `WarrenGroundArcadeSolver.gd:109-135` | **Helped, but the same solver is edited.** The audit counts arcade cells with grounded frontage *or* overhead building (`:121-124`); a motif over an arcade adds overhead, so `qualified` rises. The **separation** change in `_find_path:151-152` is a genuine constant move and takes the full re-derivation standard (§6, Wave 1) with the committed arcade integration test as the authority on going too far. |
| 6 | Unclassified 3 m apertures (`uncovered_core_column_count == 0`) | `WarrenTownPlan.gd:71-81` via `WarrenPlatformInfillSolver` | **Needs re-derivation — the datum audit, not the threshold.** The solver reads `ground_at` five times and the undercroft lowers it. Each read must be classified as surface datum or envelope floor. The *threshold* is not touched: a covered passage is not an aperture. |
| 7 | `MIN_COMPOSED_WALK_ENCLOSURE_RATIO = 0.50` | `WarrenTownPlan.gd:13` | **Satisfied naturally, and it is the motif's own best evidence.** A passage is bounded on both sides and above. Seeds currently fail at 0.417–0.478. |
| 8 | `MAX_RAW_DAYLIGHT_VOID_COMPONENT_SIZE = 4` | `WarrenTownPlan.gd:23` | **Helped.** A deck of houses removes open core columns; a covered passage is not a daylight void. |
| 9 | `MIN_STOREYS`'s 6-band demand at an at-grade address | `WarrenSolidPartitioner.gd:86,565` | **Deliberately out of scope, and that is the point.** Attempt 6 died on it. The motif does not re-derive a production quality bar; it routes around it by putting the address one band above the deck (`d = 1`, §2.2), which costs one band of plinth stone and nothing else. |

Only floors 5 and 6 need work, and neither is a threshold move: one is a
separation *predicate*, the other a datum *audit*.

---

## 5. Failure containment

The motif is optional per segment, and the guarantee is structural rather than
statistical:

1. **`WarrenTerraceTunnelMotif.apply` returns its inputs unchanged** when no site
   survives. A town without a motif is byte-identical to today's, and that is
   provable with the whole-chain signature instrument Wave 1 of the terrain
   milestone built (massif base/top/bearing per column, four gate readings, carve
   route/carved/lane/portal counts + route digest, frontier plan digests, sorted
   parcel digests — ledger 224).
2. **`undercroft_at` defaults to 0**, so the amended `_slot_is_borable` clause and
   the adapter's undercroft declaration are unreachable without a motif, and
   route-first never reaches them at all.
3. **The three datum reads** (`_has_continuous_bearing`, the arcade root filter,
   `_surface_kind`/`_episode_kind`) are boolean identities when `bearing_bands`
   is empty, which is every route-first envelope and every unlifted mass-first
   column.
4. **The transaction re-measures every route gate** and rolls back on any
   regression, so the four floors attempt 6 broke — `test_warren_excavation`'s
   lane ratio, `test_warren_generation_mode`'s street-wall ownership share,
   `test_warren_solid_partitioner`'s per-seed wall and house counts — cannot move
   in the direction that broke them.
5. **Row 18** means the ownership guarantee (`unowned == 0`) is not merely
   defended but untouched.
6. Wave 1's separation change is the one item that affects towns without a motif.
   It is separated into its own wave for exactly that reason, has its own
   acceptance (the committed arcade floor), and has the envelope-field escape
   hatch (`WarrenVolumeEnvelope`, the pattern that made `ADDRESS_BANDS`,
   `UPPER_ROUTE_CROSSOVERS` and `PLINTH_BUDGET_BANDS` route-first-safe) if the
   controlled A/B shows route-first moving.

---

## 6. Waves

Each wave is independently testable, TDD-able, and has measured acceptance. The
headline for the milestone is **fabric-level cells-over-street > 0 and
`INTERIOR_PASSAGE` > 0 on the corpus**, and it lands in Waves 5–6.

### Wave 0 — Census (read-only; this wave can refute the design)

Extend `tests/harness/warren_mass_first_report.gd` with `--stage motif`. Over
the 40 stamped seeds measure:

- columns with `ℓ ≥ 5` and with `ℓ = 6`, and their 4-connected run lengths;
- **legal sites** under §3.4's full predicate, per seed;
- the bench census: adjacent-column `base_at` steps of exactly 3 bands, and how
  many legal sites sit against one;
- the support vocabulary: every baked asset whose authored bounding box fits a
  3.0 m × 4.5 m opening on the 1.5 m lattice **without scaling**.

Suites: none (harness only). Canary: `test_warren_outcrops` 8/8.
**Acceptance: ≥1 legal site on ≥1/3 of seeds AND ≥1 usable support asset.**
**Falsification: if either is zero, stop and report.** The honest conclusion is
then "the authored vocabulary and a 4–6 band layer cannot roof an excavated
street", which is a legitimate and valuable outcome — the same one the corner
junctions and the skywalks reached.

### Wave 1 — Height-aware public-realm separation (the lane web)

`WarrenGroundArcadeSolver._find_path:142-155` filters `existing_auxiliary` to
realm within a band window of the candidate root; `WarrenExcavationCarver._arcade_reserve:501-516`
becomes band-scoped to match. Window derived from `WarrenVolumePlan.HEADROOM_BANDS`
(realm that cannot physically contest the same ground), not chosen.

Suites: `test_warren_excavation` (the committed carve → adapt →
`GroundArcadeSolver.extend` integration test over seeds 16–31 with its two
independent floors, ≥5 cleared and ≥0.55 rate, must hold **untouched**), plus a
new `test_the_reserve_only_binds_realm_at_the_same_datum` with sabotage;
`test_warren_generation_mode`; canary.
**Acceptance:** lanes/town median 1 → ≥4; addresses and houses recover toward the
pre-thin-layer 92 / 73.8; arcade clearance ≥ the committed floor; route-first
ranked-candidate A/B over seeds 0–11 identical, or the change is gated to
mass-first by an envelope field.

### Wave 2 — The undercroft datum (no motif yet)

`WarrenMassif.undercroft_at()` + a derived-massif constructor;
`_slot_is_borable`'s exactness clause; `WarrenExcavationVolumeAdapter.envelope_from_massif`
declaring `ground_bands = base_at − undercroft_at`, `bearing_bands = massif.bearing_at`,
and the undercroft as mass. Exercised only by synthetic fixtures.

Suites: `test_warren_massif` (undercroft is 0 by default; `layer_at`,
`terrace_levels`, `widest_plateau_cells`, `_worst_neighbor_step` all invariant
under a lift — the claim of §3.2, proved rather than argued);
`test_warren_excavation` (a slot in an undercroft column is borable **iff** it
exactly fills the course; a straddling slot is refused);
`test_warren_excavation_adapter` (the envelope seals; mass continuity; both
datums).
**Acceptance:** the whole-chain signature over seeds 0–11 is byte-identical with
no lifts present.

### Wave 3 — The datum split at the parcel seam

The one line in `WarrenBuildingParcel._has_continuous_bearing`; the arcade root
filter; `_episode_kind`; and the classified audit of
`WarrenPlatformInfillSolver`'s five `ground_at` reads.

Suites: an equivalence sweep proving `bearing_at ≡ ground_at` over the whole
reachable input space whenever `bearing_bands` is empty (the pattern
`test_the_apparent_face_rule_is_the_storey_rule_restated` established in Wave 5);
`test_warren_volume` route-first A/B; `test_warren_solid_partitioner`; canary.
**Acceptance:** route-first ranked candidates identical over seeds 0–11; a
synthetic house on an undercroft column seals with `support_mode == "terrain"`
and `has_occupied_overpass == true`.

### Wave 4 — The motif solver

`WarrenTerraceTunnelMotif.apply`, wired at the `mass_first_frontier` seam.

Suites: new `tests/test_warren_terrace_tunnel_motif.gd` — site enumeration is a
pure function; the transaction is atomic (a rejected site leaves both objects
byte-identical, proved by signature); every row of §3.3's table asserted
cell-by-cell on a synthetic frame; a frame with no legal site produces exactly
the input pair. Plus `test_warren_solid_partitioner` (with a motif present:
`unowned == 0`, and a sealed parcel exists whose footprint covers a passage
cell); `test_warren_excavation`; canary.
**Acceptance:** on the corpus, ≥1 motif on the seeds Wave 0 predicted;
`occupied_overpass_parcel_count > 0` for the first time on this branch;
`unowned == 0`; the four previously-broken floors unmoved.

### Wave 5 — Classification and the supports

`_surface_kind`'s three-way test; the `SectionalPublicRealmPlan` exterior-realm
re-derivation with its no-producer proof; `WarrenFabricCompiler` collecting
`undercroft_support_cells`; `SettlementFabricAssembler` drawing them from the
Wave-0-approved vocabulary.

Suites: `test_warren_production_surfaces`; `test_settlement_fabric` (canary — it
is a baselined pre-existing 20/25 and must not move);
`test_warren_facade_variety`; `test_warren_roof_profiles`.
**Acceptance:** `INTERIOR_PASSAGE > 0`; every passage cell has a drawn support or
arch face; zero floating houses (the Wave-5 grounding measurement, re-run).

### Wave 6 — Corpus acceptance and renders

No new mechanism. Measure over the 40 stamped seeds and report movement rather
than tuning it back: cells-over-street, `INTERIOR_PASSAGE` cells, overhead ratio
against the 0.35 gate, composed walk enclosure against 0.50, raw daylight void,
arcade clearance, houses, lanes, `unowned`, and the composition chain stage by
stage. Render every seed carrying a motif, five views including route-eye
(`warren_mass_first_preview`, whose `_covered_route_eye` already ranks
`INTERIOR_PASSAGE` first).
**Acceptance: fabric-level cells-over-street > 0 and `INTERIOR_PASSAGE` > 0 on
the corpus, with no gate moved.**

---

## 7. Risks

**R1 — SITE SCARCITY. The single most likely failure mode.** The motif needs
runs of columns with `ℓ ≥ 5`, and the buildable layer is 4–6 bands tapering to 4
at the rim, with `layer_core = 4` on roughly a third of seeds producing none at
all. Worse, the columns that do reach 5–6 are near the crown, which is exactly
where the bore already is, and a bored column is disqualified. The design could
therefore be arithmetically perfect and have nowhere to stand.
**Earliest detector: Wave 0's `--stage motif` census**, read-only, no production
code, ~15 s/seed. It reports legal sites per seed under the full §3.4 predicate.
If the count is near zero the honest options are (a) allow the motif to author
`ℓ = 6` on its own run and re-derive `widest_plateau_cells` for a lifted district,
or (b) stop and report that the layer cannot host the motif — and (b) is a
legitimate outcome.

**R2 — No lattice-fitting support asset.** The WWall rampart family was unusable
at 3.8–8.0 m on a 1.5 m lattice and the no-scaling rule held. The undercroft
needs a 3.0 m × 4.5 m pier or arch. Detector: Wave 0's asset census. If it fails,
the covered street joins the corner junctions and the skywalks as a single
authored-art ask, which is a more useful thing to tell the reviewer than three
separate ones.

**R3 — The separation change costs arcade clearance.** Precedent is exact: the
`MIN_GRADE_CELLS = 8` experiment cleared 4 seeds against a committed floor of 5
and was abandoned on that evidence (ledger 162). Detector: the committed arcade
integration test in `test_warren_excavation`, in Wave 1, before anything depends
on it.

**R4 — The lowered `ground_at` leaks.** `WarrenPlatformInfillSolver` reads it five
times and feeds floor #6 (`uncovered_core_column_count == 0`), which already
stops 5 seeds. A passage misread as an unclassified 3 m aperture would kill towns
two stages after the motif that caused it. Detector: Wave 3's classified datum
audit, and Wave 4's stage-by-stage composition chain.

**R5 — The composed face reads as a tower.** 3 bands of colonnade under a 2-storey
house is 8–9 bands of composed section at the passage mouth. The reviewer counts
"multiple visible storeys of house/stone wall" as a tower and counts blank stone
as building. Only a render answers it; Wave 6. See §9.

**R6 — A lift takes a canyon wall.** Lifting a column removes mass from `[g, D)`
beside any at-grade route cell running past the run, which can move
`MIN_WALL_RATIO = 0.70`. Detector: the motif transaction's own re-measure, which
rolls the site back rather than shipping a degraded route.

---

## 8. Non-goals

- **Restoring the reverted terrain sink.** §3.1 refutes it. The mechanism this
  design keeps from task-24 is the *exactness rule*, not the terrain geometry.
- **Re-deriving `MIN_STOREYS` at an at-grade address** (the ninth constant). The
  motif routes around it; if a later wave wants it, it is a separate decision
  with its own evidence.
- **Moving any composition threshold.** Floors 7 and 8 should rise on their own;
  if they do not, that is a measurement to report.
- **Skywalks, corner junctions, and flush-edged roof art.** Named where they
  intersect (R2), owned elsewhere.
- **Widening the massif or changing the relief budget** to buy sites. The budget
  is the reviewer's pending ruling and must not be tuned to compensate for this
  feature (`SettlementReliefPlan.gd:46-64`).

---

## 9. The question only the reviewer can answer

**Does an open colonnade one street-storey deep (4.5 m), carrying a 2-storey
house, with the path running through it, read as the covered street you have
been asking for — or as a 4-storey face?**

The concrete section: 3 bands of authored arch/pier supports at ground level,
which you can see through and walk under; 1 band of foundation stone; 2 storeys
of timber house with a tiled roof above. Total 12–13.5 m at the mouth, of which
the lower third is opening rather than wall. This is the geometry your own words
describe ("buildings built on paths which themselves are overpasses"; "stone
substrate is permissible where houses will cover it anyway"; "supports" listed
among the permitted city elements) and it is also, measured as a continuous
vertical section, taller than the 2–3 storey rule allows. No measurement settles
which one it is.

**Coupled to it, and still open from the terrain milestone:** does a
terrain-authored KayKit cliff count as visible stone? That ruling sets
`RELIEF_BUDGET_METRES`, and the budget sets how many terrain benches a town has,
which sets how many motif sites have a natural terrace connection (§3.3). The
two questions now have one answer's worth of consequence for this feature.
