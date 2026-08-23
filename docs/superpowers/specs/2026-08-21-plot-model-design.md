# Plot-model town generation — design (2026-08-21)

Approved in-chat (Ryan, 2026-08-21). **Supersedes** the reservation pass,
stamping pass, edit ledger, skyline trim, and foundation sections of
`2026-08-20-constructive-maze-town-design.md` and everything slices 1b/1c
added on top of them. The massif, the carver (with its 1c tunnel policy), the
volume adapter, the translator partitioner, and the principle *rules become
repairs* all stand.

## Why

Slices 1–1c proved the constructive approach works (22/23 towns translate,
ownership 0.69) but accreted concepts faster than they removed them:
reservations vs claims, four edit ops, a registry, storey rolls, lineage
grouping, ledger flags (`phase`, `trimmed`, `bearing`), a trim pass, a
foundation pass, and five overlapping support rules (bearing, plinth, flush
stack, headroom, tier). The debug view needed twelve colours to show it. Most
of these are the same idea under different names. This design collapses them.

## The model

```
Plot {
  id: StringName           # stable, deterministic
  kind: house | asset | deck | bridge
  cells: Array[Vector2i]   # connected footprint, macro columns
  floor: int               # band
  top: int                 # band; deck ⇒ top == floor
  door_walk: Vector3i      # house/asset only: the street cell the door faces
  building_id: StringName  # group id for translation/composition
}
```

- **A deck is a plot with zero height** (courtyard, plaza, roof deck).
- **A bridge is a plot whose floor is a street's headroom top** (it spans a
  retained bridge span; `cells` are the span's columns).
- **An asset is a plot with a catalog footprint** (complete-house prefab,
  landmark); its `cells` are the template's macro footprint at the chosen
  site.
- **A house is anything the partition grows.**

**Rock is never stored.** On a column, solid mass is derived:

```
solid_at(cell):
  passage cell or its headroom           → false      (carved street)
  inside some plot's [floor, top)        → true       (building / bridge)
  below the lowest plot floor on column  → true       (rock, down to terrain)
  column has no plot: below rock shoulder→ true       (rock shoulder)
  otherwise                              → false      (air)
rock_shoulder(column) = min over 4-neighbour plots of their floor, else terrain
```

There is no edit ledger, no `effective_top`, no trim pass, no foundation map.
The massif is the buildable envelope; the excavation is the carved network;
the plots are the town. `deterministic_signature()` covers plots.

## One support rule

A plot may occupy column `c` at floor `F` iff:

1. `solid_at(c, F − 1)` — the band below the floor is solid (rock, a retained
   tunnel-roof slab, or another plot's top),
2. no carved air stands in the `MIN_HOUSE_BANDS` of clearance above the floor
   — `_first_carved_band(c, F, F + MIN_HOUSE_BANDS) < 0` — which is the
   per-cell reading of "a plot never sits inside a passage's headroom", and
3. `F ≥ massif.base_at(c)` — the floor stands **on** this column's terrain
   rather than inside it.

This single rule replaces bearing, plinth, flush-stack, tunnel-roof, and
per-cell headroom. Tiers, bridges, and stacking all fall out of it.

Clause 3 is clause 1's other half and only has content once the ground is not
flat (task D1). `solid_at` answers TRUE for **every** band below
`massif.base_at` — terrain is untouched sample, and that is exactly what lets a
house fronting a grade street stand at `F == base_at` — so clause 1 alone is
satisfied at any depth: a footprint reaching from a low street onto a column
three bands further uphill passed it while buried three bands inside the bank.
On a flat frame every base is zero and no plot floor is negative, so clause 3
is unreachable and the flat corpus is unchanged by it.

## Pipeline

```
P0  massif         terraced heightfield on the terrain sample (unchanged)
P1  carve          spine + alleys (unchanged)
P2  tunnel policy  open every passage to sky; keep seeded bridge spans where
                   both flanks are solid (1c carver, unchanged)
P3  reserve        assets (min-cost site) and decks (grown flat regions)
P4  partition      greedy largest-first buildings until every buildable
                   column is in a plot; heights tier-driven
SEAL → adapter → translator → composition (slice 2)
```

### P3a — assets

For each catalog template the scale quota asks for (complete houses,
landmarks; quotas per `WarrenVillageScaleProfile` scale id), enumerate every
site where the template's footprint is street-fronting and supportable; score
it by **terrain modification cost** = Σ over footprint columns of
`|massif.top_at(c) − datum|` where `datum` is the fronting street's band; take
the minimum-cost site (deterministic tie-break by position). What "cost"
measures is how much *derived* mass — rock above the terrain, or air where the
envelope stood — the site rearranges. **Natural terrain is immutable**: the
site's datum may stand on the ground or on retained mass above it, never below
it (support rule clause 3), so a bank is never cut to make a site cheap. Skip
with a reason when no site exists.

### P3b — decks

For each street cell (walk order), grow the largest connected region of
columns adjacent to it whose `massif.top_at` is within ±1 band of the street's
datum and which satisfy the support rule at that datum, cheapest-first, up to
the scale's deck area cap; reject regions smaller than the deck minimum.
Accepted regions become decks at the datum. Because the support rule accepts a
plot top as support, the same growth run at an *upper* street over house
roofs yields **roof decks**. Quotas per scale; seeded choice among candidates
for variation.

### P4 — partition

1. Seed a house at every street-fronting column not yet in a plot (door = the
   fronting street cell; floor = its band).
2. Grow each seed greedily into adjacent columns that satisfy the support rule
   at the same floor and are not in a plot, largest current building first,
   up to the scale's building area cap.
3. Repeat until no buildable column remains. Columns left over (no street
   reachable within the cap) stay rock and are lowered to the rock shoulder.
4. **Height**: `top` = the lowest upper street band within the footprint or
   its 1-column apron that is ≥ floor + MIN_HOUSE_BANDS (the roof meets that
   street: a tier); else the scale's storey budget. Capped by any plot above.
5. Bridges: every retained span becomes a `bridge` plot at its headroom top,
   one storey, `building_id` of the adjoining house if one is adjacent at that
   floor, else its own.

### Content facts (derived, consumed by composition)

- `roofed(plot)` — no plot occupies any of its columns at `top`.
- `bears_on_rock(plot)` — `floor − 1` is rock (not another plot) on its
  columns → the stone base family (this is the existing
  `terrain_bearing → .base.rock` rule, now explicit at the source).
- `tiered(plot)` — `top` equals an upper street's band.

## Boundary with the translator and composition

`WarrenMazeBlockPartitioner` keeps its 1:1 job: each plot becomes one or more
rectangular `WarrenBuildingParcel`s sharing `building_id`; the street-facing
rectangle carries the door; remaining rectangles are recorded as
`back_rooms` on the parcel plan for composition's residual-room machinery.
Decks and bridges translate to their existing typed reservation contracts.
`WarrenMazeVolumeAdapter` builds the volume from `solid_at` (rock + plots),
never from a ledger.

## What is deleted

`WarrenMazeReservationPass`, `WarrenMazeStampPass`, the source plan's
`column_edits` / `record_edit` / `record_trim` / `effective_base` /
`effective_top` / `foundation_columns` / bearing-phase-trimmed flags, the
skyline trim, `derive_foundations`, the reservation registry and edit ops,
lineage grouping, the storey roll, and every seal validation that policed
those (replaced by: plots disjoint per column-band, every plot supported,
headroom clear). `WarrenBuildingParcel`'s tunnel-roof branch stays (it is
the support rule at the parcel level).

Replacement: `WarrenPlotPlanner` (P3 + P4, target ≤ 600 lines) and
`WarrenMazeSourcePlan.solid_at` (≤ 40 lines).

## Tests

`tests/test_warren_maze_constructive.gd` is re-targeted to model invariants:

- stack invariant: on every column, solids are contiguous from terrain (rock,
  then plots in floor order, no gaps);
- every plot satisfies the support rule; every passage cell's headroom is air;
- decks are flat at a street datum; assets sit at the minimum-cost site among
  enumerated candidates; bridges sit on retained spans;
- buildable coverage: share of street-fronting columns inside a plot ≥ a
  pinned floor; exterior rock ratio ≤ a pinned ceiling (both measured, pinned
  at measured-minus-guard, reported honestly);
- corpus: ≥ 22/24 seeds seal and translate 1:1; deterministic signatures.

Carver, fabric compiler, and settlement fabric suites stay green (legacy
untouched).

## Visualisation

`maze_source_review.gd` draws exactly four things, opaque, no lines:

- **grey boxes** — rock (derived `solid_at` runs that are not plots);
- **blue boxes** — plots, one shade per `building_id` (decks excluded);
- **brown floor squares** — one per passage cell at its band (the void above
  is the tunnel/street — nothing is drawn for air);
- **tan squares** — one per deck cell at the deck's floor (courtyards, plazas,
  roof decks).

Legend: seed / scale / state / plots / decks / bridges / exterior-rock ratio
and the four colours. The six-phase loop stays (massif, bore, tunnel, reserve,
partition, final).

## Success criteria

1. Exterior rock ratio on the corpus ≤ the pinned ceiling (goal: near zero
   above street level; rock is interior structure).
2. ≥ 22/24 seeds seal and translate; pinned seeds' ownership ≥ slice-1c values.
3. Suites green; plot-layer code ≤ 700 lines total.
4. The debug view is readable at a glance by someone new to the project.

## Out of scope

Composition consuming plots (slice 2), the noise massif (slice 1.5), carver
vertical momentum/descent, the pinned-seed 0.85 ownership target.
