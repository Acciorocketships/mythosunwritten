# Mass-First Warren Towns — Design

**Date:** 2026-08-06
**Status:** Approved direction (round-6 review) — supersedes the route-first
carve order of `2026-07-28-warren-towns-design.md` while keeping its
construction, socket, and asset layers.

## 1. Problem

Five rounds of lever tuning proved a structural ceiling: with a route-first
pipeline (carve a path through empty space → pack buildings around it → patch
coverage), *bounded-ness is a preference, not a property*. Routes plateau at a
4–6 band vertical span regardless of scoring pressure, overhead cover sits
below the 45–65% target on most seeds, and streets read as "next to" the town
rather than cut through it. The round-6 review restated the goal:

> The paths should be **bounded** by the buildings — tall buildings on either
> side, often over the path too. The negative space itself should be what
> creates the path; then all that's left is to add flooring. Taller cities
> give more vertical space to work with, and varied terraced houses look more
> visually interesting.

## 2. Reframing

Invert the order of operations. The city mass is primary; the public realm is
subtraction.

1. **Massif** — generate a dense, tall, terraced solid: the whole town as
   stacked occupiable volume (target 18–20 bands at the core, up from 12–14),
   shaped by a warped Gaussian with terrace steps, never a smooth dome.
2. **Excavation** — carve the route *through* the massif as a tunnel-borer:
   remove walk cells + headroom along a snaking, climbing itinerary;
   occasionally punch daylight wells and open-air notches. A tunnel through
   solid mass cannot fail to have walls and a ceiling — bounded-ness holds by
   construction, not by reward.
3. **Resolution** — every carved face must resolve to real construction:
   carved flanks become inhabited facades (rooms partitioned from the
   remaining solid), carved ceilings become room floors or bridge undersides,
   carved floor becomes street flooring (planks on structure, dirt at ground).
4. **Partition** — the remaining solid is partitioned into terraced houses
   (footprints 1×1 to 2×3, stepped tops following the massif terraces), which
   then flow into the *existing* fabric construction: recipes, sockets, roof
   junction tables, outcrop bays, market mass-adjacency.

## 3. Components

### WarrenMassifBuilder (new)
Deterministic terraced solid from a world seed: warped Gaussian core height
field quantised into terrace steps (1–2 band risers), with radial spurs and
notches so silhouettes vary. Output: solid column map (per column: base band,
top band) plus terrace metadata. Gates: core height ≥ 16 bands, ≥ 5 distinct
terrace levels, no plateau wider than 6 cells.

### WarrenExcavationCarver (new, replaces route-first carver entry)
Bores the itinerary through the massif: 22–26 cell route, monotone-ish climb
from a ground-level portal to an upper terrace (target span ≥ 8 bands),
headroom clearing, stair/ramp cells on rises. Carve style alternates covered
tunnel (mass left overhead) with open canyon (top cells removed to sky) and
occasional light wells. Quality gates operate on *negative space*: max cavern
cell count, min covered ratio (55–70%), no through-sightlines longer than N
cells, portal count 1–2.

### WarrenSolidPartitioner (new, replaces parcelizer's packing role)
Partitions the post-excavation solid into house volumes aligned to carved
faces: every facade touching the route must belong to exactly one house with
a real frontage (door/window walls), interior leftover volume becomes
courtyard shafts or is trimmed. Existing composition metrics (family
diversity, stepped pairs, band counts) become *audits* of the partition
rather than packing search objectives — diversity should largely fall out of
the terraced massif.

### Street-section realization (mechanism, reuses fabric layer)
Carved boundary cells compile through the existing recipe machinery: flank
faces → wall modules with the existing style graph; ceilings → floor/bridge
modules; floor → the existing surface union (planks structural, dirt at
grade). Skywalks/outcrops remain as *optional* enrichment over an
already-covered route rather than the mechanism that creates coverage.

### Mesh-overlap audit (new acceptance gate #5)
Post-construction: sample placed module faces; reject coplanar-face overlap
(z-fighting pairs) and shell interpenetration beyond tolerance (0.02 m for
coplanarity, 0.10 m for interpenetration excluding declared junction bites).
Runs on the built plan in tests and in the review harness; failures list the
offending placement pairs so they are fixable at the recipe/junction table.

## 4. What survives unchanged

FabricRecipe/socket bonding, SettlementFabricProgram recipe vocabulary (rooms,
roofs, dormers, corner turrets, skywalks, markets), WarrenAssetCompiler,
FabricRoofTopologyPlan + junction tables, the surface/flooring union,
production adapters (VillageWarrenFabricSolver, payload channels), and the
review harness. The change is confined to *who decides where mass is*: the
massif + excavation replace the carver/parcelizer front half.

## 5. Migration and rollback

New pipeline lands behind `WarrenTownSolver.GENERATION_MODE`
(`route_first` | `mass_first`), default `route_first` until the mass-first
corpus meets: acceptance ≥ 6/12, route span ≥ 8 bands median, covered ratio
0.45–0.70, all existing warren battery tests green, mesh-overlap audit clean
on accepted seeds. The route-first path is deleted only after two green
showcase batches.

## 6. Testing

TDD per component: massif shape gates; excavation negative-space gates
(covered ratio, cavern caps, span); partition audits (every route-facing
face owned by a house, no orphan solids); mesh-overlap audit with a seeded
known-overlap fixture proving detection. Corpus: the 12-seed
probe_height_variety sweep gains covered_ratio and span columns; showcase
batches remain the visual gate.

## 7. Open questions carried forward

Terraced-house interior partitioning granularity (per-storey rooms vs whole
stacks); daylight-well frequency tuning; whether market plazas become carved
chambers (grotto markets) or stay surface-adjacent; performance budget for
the mesh-overlap audit on 30+ seed sweeps.

## Status checkpoint (2026-08-08)

The pipeline is built end to end behind `GENERATION_MODE = &"mass_first"`
(route_first remains the shipping default, A/B-verified untouched at every
shared-file change): terraced massif (radius 16, rim rising in <=4-band
steps against empty neighbours), excavated primary route (walks at grade,
climbs 9-13 bands, 55-70% covered), secondary lane network (addresses
~92/town, houses ~74 mean, 100 on seed 11), solid partitioner with split
support datum, detail phases (skywalks, outcrops, markets) and a
best-effort preview harness (`tests/harness/warren_mass_first_preview.tscn`)
that renders pre-gate towns and prints gate refusals honestly.

Visual state per the reviewer's rounds: buildings 2-3 storeys with
setbacks (stone included), boxes removed, city composed of catalog assets
only, stone as hidden substrate + foundation plinths, mountain character
kept. Open: whole-house stone facades (cap to ground storey), facade/wall
uniformity (unbaked variant bake wave), towns still fail legacy visual
gates (overhead 0.11-0.21 vs 0.35 — calibration vs mountain form to be
argued from measurement), corner-junction art to retire the diagnostic
overlap exemption, elevated houses on bare support pillars where substrate
is unresolved, seed-6 contact regression, richness-blind topology_score.

Strategic fork presented to the reviewer (decision pending): terrain-
integrated hill (massif -> heightfield + existing cliff dressing) vs
maturing the fabric-substrate path vs phased hybrid (shared variety work
first, then terrain milestone). Decision ledger for the whole build:
`.superpowers/sdd/2026-08-06-mass-first-warren/progress.md` (untracked).
