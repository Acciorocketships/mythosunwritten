# Warren Towns — Canyon Urban-Fabric Design Spec

**Date:** 2026-07-28
**Status:** Approved brainstorm direction; implementation not started. Numbers marked
*(Phase 0)* are frozen by probes, not by this document.
**Scope:** The **town tier** of settlement generation changes direction: instead of a
larger roll of the village-tier compact fabric, a town becomes a **warren** — a dense,
chaotic, multi-tiered canyon of buildings, platforms, and skywalks whose covered market
core barely sees the sun. References: the two concept images reviewed 2026-07-28, Old
London Bridge, the Burrow, lower Coruscant. The village tier (~85% roll) keeps the
existing terrain-led compact fabric from the 2026-07-26 villages spec unchanged. Warren
buildings are **solid shells in v1** (no enterable interiors); the playable surface is
the exterior fabric. Terrain is never reshaped. The `SPIRE` and `SPAN` archetypes are
deferred follow-ups; `CANYON` is v1 because it works on arbitrary terrain — the canyon
walls are built mass, so the armature needs only a routable spine.

---

## 1. Decisions

| Question | Decision |
|---|---|
| Tier identity | `town` keeps its `SettlementPlan` identity, roll ratio, plaza, and route landings. Only the content pass changes: `tier == town` selects the warren solver chain instead of the village-tier fabric. The existing town fabric is retained only as a migration source until warren closes, then removed (the `VillageElevatedDistrict` pattern) |
| Archetype | `CANYON` v1: an axis-aligned market spine whose two sides grow dense building walls; the covered market runs between them. `SPIRE` (wrap a tall terrain feature or mega-rock core; likely needs terrain editing) and `SPAN` (inhabited bridge) deferred |
| Generation model | Staged field-guided greedy accretion (armature → voids → bearing → cores → accretion → weave → dressing → skylight), not WFC and not history simulation. Chaos comes from a budgeted sequential accretion loop; coherence from typed constraints reserved up front |
| Aesthetic law | Order at the macro (armature + height/density fields author the silhouette), chaos at the meso (offsets, half levels, cantilevers, era jitter), consistency at the micro (one theme, one timber vocabulary, cardinal frames) |
| Rotation | **90° only, one settlement-wide cardinal frame** aligned to the market spine. Spine direction changes are 90° doglegs. No per-cluster frames, no yaw jitter: kit pieces always seam, and the references are themselves largely cardinal. Chaos is carried by massing, not rotation |
| Vertical grammar | Reuse the module lattice: floors quantize to 1.5 m half-module steps via `VillageVerticalProfile`, but each stack's base seeds from unquantized terrain or deck height. Adjacent stacks therefore sit odd half-steps apart — "no discrete levels" falls out of quantized increments over unquantized seeds |
| Interiors | Deferred for warren v1. Buildings place as solid massing elements (closed-shell bake variants); doors/windows are facade reads, not traversal targets. Existing village-tier enterable behavior is untouched |
| History | Faked in one pass: era index `e = units_placed / budget` loosens offset variance and raises brace/patch/prop probability as accretion proceeds. No epoch simulation |
| Streets | The negative space is reserved **first** as occupancy volumes: market spine protected to a low ceiling (~4.5–6 m *(Phase 0)*), alleys ~3 m, plus 2–3 full-height **light shafts** at plazas. Above the protected ceiling, building over the street is scored positively — the covered market is guaranteed by construction, not by accident |
| Support | A typed **`BearingIndex`** (load-unit accounting, not physics) guarantees every mass a visible load path: terrain, foundation, wall brace, post stack, or deck. Cantilevers require an emitted brace; post stacks have a max unbraced height, forcing mid-level landings. The village-tier ≥70% natural-support rule, 12–18 m link cap, platform-frontage rule, and aerial-loop prohibition are **relaxed inside the warren only**, replaced by bearing-audit and loop-target gates |
| Skywalks | Redundant links are the point: weave targets a cyclomatic loop count and an average ≥1 crossing per spine segment, capped only by headroom and bearing. One budgeted "grand arc" special may span the quarter between two heavy cores |
| Light | A sampled **sky-view factor** (SVF) field gates darkness (spine dark, shafts bright) and drives the glow pass: lantern/string-light density and emissive-window variant probability ∝ (1 − SVF). Emissive materials only; runtime light nodes stay deferred |
| Determinism & bounds | Unchanged contracts: record = f(world_seed, settlement_id); `MAX_ANCHOR_RADIUS` and record-radius compile checks; atomic occupancy transactions; stable ids (accretion order is the id); worker purity; staged `FeatureCommitQueue`; no terrain reshaping; `TraversalEnvelope` for every playable surface |

## 2. Aesthetic model

What the references share, and what each pipeline stage is responsible for:

1. **A strong macro armature** — chaos reads as coherent only when it visibly accretes
   onto a legible skeleton (spire, bridge deck, street canyon). *(Stage 0 fields.)*
2. **Chaos at the meso scale only** — unit offsets, half levels, cantilevers, strapped-on
   walkways. *(Stage 4 accretion + era jitter.)*
3. **Uniform micro vocabulary** — one culture built this over time: one theme roll, one
   timber family, cardinal joints. *(Program constants.)*
4. **Visible structure** — every mass shows its load path; props are the aesthetic.
   *(Stage 2 bearing + emitted braces/posts; the seam-hiding rule in Stage 6.)*
5. **Circulation as ornament** — redundant loops read as "city", trees read as
   "boardwalk". *(Stage 5 loop targets.)*
6. **Light hierarchy** — dark canyon, glowing windows, few bright shafts; lantern
   density inverse to daylight. *(Stages 1 & 7.)*

"Haphazard" in the references is sequential accretion, not randomness: each addition was
locally sensible when made, constraints accumulated, and the result is globally tangled
but locally justified. The greedy loop reproduces exactly this; simultaneous constraint
solvers (WFC) produce uniform texture instead and are rejected for the core. All
stochastic choices draw from per-stage seeded streams.

## 3. Architecture

New classes live in `scripts/terrain/features/villages/warren/`. The chain runs inside
the existing atomic-transaction shape (`VillageUrbanFabricSolver` idiom): producer
solvers stay independently testable; one orchestrator composes typed outputs and does
the final cross-system occupancy proof.

```
WarrenProgram            compiled constants: field params, ceilings, quotas,
                         bearing capacities, budgets, SVF targets
WarrenArmatureSolver     stage 0 → spine polyline + H/D fields
WarrenVoidSolver         stage 1 → street graph, protected prisms, shafts
BearingIndex             stage 2 — bucketed bearing surfaces with load accounting
                         (sibling of VillageOccupancy, same determinism rules)
WarrenAccretionSolver    stages 3–4 → UnitGraph
UnitGraph                nodes = masses/decks; edges = bears_on | abuts | bridges —
                         single source of truth for load audit, seams, undersides
WarrenWeaveSolver        stage 5 → stairs, ladders, skywalks, grand arc
WarrenDressingSolver     stage 6 — consumes UnitGraph seams + SVF
SkylightField            stage 7 — SVF sampling, gates, glow densities
```

Reused unchanged: `FeatureContext`/`WorldFeaturePlan` projection, `FeatureCommitQueue`
staging, `VillageTimberFabricSolver` (deck/railing/support materializer),
`VillageStairSolver` + `VillageGroundRouter` (terraced cardinal streets and public
stairs), `TraversalEnvelope`, foundation/support module vocabularies,
`VillageOccupancy` roles. Light shafts are ordinary HEADROOM prisms with a compiled sky
top; a new role is added only if a real conflict demands it.

### 3.1 Stage 0 — armature and fields

`WarrenArmatureSolver` consumes the existing `VillageTerrainSurvey` view around the
route landing and emits:

- **Spine**: an axis-aligned polyline in the settlement cardinal frame (segments along
  the primary axis with occasional 90° doglegs), total length by tier budget
  *(Phase 0; ~60–100 m)*. The route landing is the canyon mouth — arrival passes from
  open field into the dark market slot. On sloped sites the spine follows gentle grade;
  the floor terraces through the existing street/stair vocabulary.
- **H(x,z)**: target height envelope — a noisy ridge along the spine falling off to the
  edges. Authors the skyline.
- **D(x,z)**: density field — hot core at the spine, falloff outward.

All later stochastic choices are biased by H and D; this is the entire art-direction
surface. Site rejection reuses survey rules (water, cliffs, insufficient room).

### 3.2 Stage 1 — void plan (negative space first)

In dense fabric, streets cannot be carved out of placed mass after the fact; the air is
reserved first as occupancy volumes:

- Ground street web: market spine + branching alleys (biased walk along contours and
  toward gates), 2–4 modules wide.
- Per-edge **protected ceiling**: spine ~4.5–6 m, alleys ~3 m *(Phase 0)*. The volume
  below the ceiling is HEADROOM; the region above it is *positively scored* for
  coverage in Stage 4.
- 2–3 **light shafts**: full-height prisms over plaza/junction cells (~4×4 modules).
  Sun reaches the floor only there.

Ground paint: the market core paints worn ground through `FeatureGroundField` shapes
(grass naturally excluded); dressing clearance flows through the same context as today.

### 3.3 Stage 2 — bearing model

`BearingIndex` stores bearing surfaces with capacities in abstract load units
*(Phase 0 freezes the table)*:

- Sources: terrain, foundation-filled perimeters, rock-core stacks, reviewed prefab
  **bearing zones** (flat roof patches, wall-top edges — bake annotations), deck cells.
- Each placed mass consumes load units at its bearing points; decks re-export reduced
  capacity upward.
- Cantilever ≤ fraction *f* of footprint *(Phase 0; ~0.4)* and only if a brace module
  can attach to a SOLID face below — the brace is then **emitted**, so structure stays
  visible.
- Post stacks: max unbraced height *(Phase 0; ~12 m)*; taller requires an intermediate
  landing on a deck/roof, which forces the mid-level clutter the look wants.

Gates: `unsupported_mass_count == 0`, one brace per cantilever, bounded
`load_path_depth`. This is bookkeeping for plausibility, not physics.

### 3.4 Stage 3 — heavy cores

Closed-shell furnished-family prefabs place on terrain foundations along both sides of
the spine, doors and window facades facing voids, large silhouettes at high-D cells and
shaft plazas. Reuses massing machinery with density raised and frontage-on-void
required; `FoundationSolver` keeps its perimeter fill and water/cliff rejection but the
interior-floor guarantee is vacuous for solid shells. Core walls and bearing zones
become substrate for everything above.

### 3.5 Stage 4 — accretion loop (the chaos engine)

```
frontier = bearing surfaces of cores + terrain perches
while budget_remaining and frontier:
    c = propose()   # weighted: DECK_EXTEND, ROOM_ON_DECK, CANTILEVER_ROOM,
                    # BRIDGE_DECK (deck spanning two masses; becomes bearing),
                    # ROOF_PERCH (hut on a reviewed bearing zone),
                    # STALL_UNDERCROFT (stall beneath a deck ≥ headroom)
    if not (occupancy_ok(c) and voids_ok(c) and bearing_ok(c)): continue
    score = envelope_gap(H, c) * D(c) * picturesque(c) * era_jitter(e)
    accept stochastically by score; place; register new bearing + frontier
    e = units_placed / budget
```

- `picturesque(c)` is explicit scoring: bonuses for overhang-over-street, silhouette
  variance, facade-facing-void, interleaved height bands; penalties for flush aligned
  runs.
- `era_jitter(e)`: later units draw wider offset distributions and more brace/patch
  props — history faked in one pass, deterministic from accretion order.
- Floor heights: half-module quantized increments over unquantized bases (§1).
- Small habitable-looking masses are kit-composed or small closed prefabs; all solid.

### 3.6 Stage 5 — circulation weave

1. **Necessary:** every public deck and platform reaches the ground web within a path
   budget (stairs/ladders on the module lattice; relaxed span caps). Hard gate, as
   today, against `TraversalEnvelope`.
2. **Redundant (the look):** sample deck/roof pairs at similar heights across voids;
   add skywalks with 1–3 bends, every span landed through `BearingIndex` (posts to
   roofs/decks, braces to walls). Targets: cyclomatic loop count per record and mean
   ≥1 crossing per spine segment *(Phase 0)*; capped only by street headroom and
   bearing. One budgeted **grand arc** between two heavy cores may cross the quarter.

### 3.7 Stage 6 — enclosure and dressing

- Stall rows line the spine beneath its reserved ceiling; awning/canvas pieces span
  facade-to-facade where the gap fits — together with the ceiling budget this is the
  covered market.
- **Underside dressing:** lanterns, signs, laundry lines hung from deck undersides —
  constantly visible in a tiered fabric and currently dressed by nothing.
- **Seam-hiding rule:** wherever `UnitGraph` records an awkward mass-to-mass seam, emit
  a prop that explains the joint (brace, trim, ivy, crates). Worst geometry becomes
  charm; coverage is measurable because seams are enumerated.
- Chimneys route upward to open sky, naturally clustering toward shafts and roof gaps.

### 3.8 Stage 7 — skylight validation and glow

`SkylightField` samples SVF per street point: fixed fan of upward rays against
occupancy buckets, `SVF = unblocked / total`.

- Gates *(initial values; tuned during visual review)*: spine ∈ [0.02, 0.15]; shaft
  plazas > 0.5; alleys between. Too bright → one more coverage round over that
  segment; too dark → prune one span.
- Glow: lantern/string-light density and emissive-window bake-variant probability
  ∝ (1 − SVF). Emissive materials only; runtime light nodes remain deferred.

### 3.9 Validation and seal

Connectivity battery, atomic occupancy proof, bearing audit, warren corpus gates (§6),
stable ids, shuffled-order re-solve signatures, record bounds sealed last — the
existing seal discipline unchanged.

## 4. Assets and bake

Phase 0 probes, in the established bake/lineup style:

- **Bearing-zone annotations** per structural asset: flat roof patches and wall-top
  edges that may accept posts/braces/perches, recorded in provenance.
- **Closed-shell variants** of the building families for warren cores (no interior
  guarantee; cheapest collision that keeps facades honest).
- **Spanning vocabulary:** awning/canvas pieces, long beams, ladder; verify the
  existing floor/plank/stair/support kit covers multi-bend skywalks.
- Collision: exterior-reachable surfaces only; pure-visual clutter (undersides
  dressing, high ornament) skips collision via the payload's existing flags.
- Per-asset triangle/size gates and manifest hygiene as in the villages spec.

## 5. Projection, streaming, performance

Projection and commit are unchanged (`WorldFeaturePlan` enumeration, half-open block
ownership, staged `FeatureCommitQueue`). The real risk is scale: a warren is plausibly
5–20× village instance counts **at a 15% roll**, so this is a budget problem, not a
rarity problem:

- Phase 0 freezes a synthetic **worst-warren** payload and re-derives per-block gates:
  instances, collision shapes/triangles, asset-load and collision-commit time, peak
  memory, steady frame time (M1 Pro baseline). Worst-warren replaces worst-town as the
  integration benchmark.
- Accretion/weave budgets are compiled so record cost is bounded by construction;
  eviction/recompute stays identical-output.
- Camera: the canyon + underdeck fabric is the new worst case for the general
  obstruction solver; its battery gains canyon and undercroft orbits.
- Far-LOD impostors stay deferred.

## 6. Verification

**Unit (GUT, headless):** `test_warren_program` (fields, ceilings, budgets, bearing
table, bounds), `test_warren_void_solver` (reserved prisms, shaft placement,
ceiling-above-street scoring inputs, determinism), `test_bearing_index` (capacity
accounting, cantilever/brace rule, post height rule, atomicity),
`test_warren_accretion_solver` (occupancy/void/bearing rejection, era determinism,
stable ids, envelope adherence), `test_warren_weave_solver` (reachability, loop
targets, span landing, headroom preservation), `test_skylight_field` (SVF math, gate
classification, glow densities), plus catalog/bake gate extensions.

**Corpus** (`tests/harness/warren_corpus.gd`): per-seed×site distributions of SVF by
class; loop count and crossings per segment; overhang-over-street fraction;
**half-offset histogram must be multimodal** (≥4 occupied half-level bands, no band
>40%); unsupported-mass count (must be 0); brace-per-cantilever; seam-prop coverage;
dead-end ratio; instance/collision budgets; shuffled-order projection signatures.

**Traversal battery:** the real capsule walks the spine end-to-end, every stair chain,
a sampled skywalk loop, under the lowest awning, and through every undercroft;
obstruction solver runs the same route.

**Adversarial visual review:** the villages §6.2 apparatus extends with warren strata
and required views: canyon interior both directions (low light), shaft god-ray plaza,
deck undersides from street level, skywalk from below and from deck level, grand-arc
endpoints, roofline silhouette against sky, era-patchwork closeups, and lantern-density
vs darkness consistency. Checklist additions: floating or unexplained mass, load path
invisible in pixels, light leak into the covered spine, SVF/lantern mismatch, seam
without prop coverage, kit non-seams at doglegs. Same falsification contract, pinned
repros, fresh-reviewer closure.

## 7. Phases

- **Phase 0 — probes and gates:** bearing-zone annotation pass; closed-shell and
  spanning-vocabulary bake probes; synthetic worst-warren payload against commit
  budgets; SVF sampler cost; freeze ceilings, capacities, budgets, gates.
- **Phase 1 — armature, voids, bearing:** `WarrenProgram`, armature/void solvers,
  `BearingIndex`, unit tests. No streamer changes.
- **Phase 2 — cores and accretion:** heavy-core placement, accretion loop, `UnitGraph`,
  determinism and corpus skeleton.
- **Phase 3 — weave and dressing:** circulation weave, skylight field, glow and seam
  dressing.
- **Phase 4 — integration:** tier switch (`town` → warren chain), projection/streaming,
  worst-warren profiling, traversal battery; old town fabric retained as migration
  source only.
- **Phase 5 — adversarial visual verification:** stratified warren corpus, independent
  falsification review, pinned repros, fresh-corpus final pass.
- **Phase 6 — close:** perf gates, remove the old town fabric path, doc updates.

Warren implementation starts after the current villages visual stage closes; it shares
the review harness and the same reviewer bandwidth.

## 8. Risks

| Risk | Mitigation |
|---|---|
| Floating soup / implausible mass | `BearingIndex` audit is a record-validity gate; braces and posts are emitted, so support is visible in pixels and reviewable |
| Chaos reads as uniform noise | H/D fields author the macro; picturesque scoring shapes the meso; corpus multimodality and silhouette gates falsify wallpaper output |
| Covered market too dark to read or accidentally bright | SVF gates both directions; glow pass scales with darkness; visual review checks lantern/darkness consistency |
| Instance/collision blowup at 15% roll | Worst-warren Phase 0 gates; collision-skip for pure-visual clutter; compiled accretion budgets |
| Kit pieces fail to seam at doglegs | 90°-only rotation in one cardinal frame by construction; lineup review of every dogleg junction family |
| Weave breaks street headroom | Voids are occupancy volumes reserved first; every span passes headroom + bearing before placement |
| Camera unusable in canyon/underdeck | Obstruction-solver battery gains canyon, undercroft, and skywalk-underside orbits before Phase 4 closes |
| Old-town removal regresses villages | Village tier untouched; town migration follows the `VillageElevatedDistrict` retained-source pattern with corpus parity checks |

## 9. Explicitly deferred

Warren interiors (enterable shells, undercroft shops); `SPIRE` archetype (terrain
editing or mega-rock core vocabulary) and `SPAN` archetype; runtime light nodes and the
typed effect payload (emissive-only in v1); NPC habitation and market activity;
free-rotation or per-cluster frames; epoch history simulation; far-landmark impostors;
building-on-pitched-roof literal stacking (bearing zones are flat patches only).
