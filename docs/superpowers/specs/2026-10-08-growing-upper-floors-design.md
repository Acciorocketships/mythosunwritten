# Growing upper floors (cumulative jetties) — design

Date: October 8, 2026. Branch `town-redesign` (worktree `/Users/ryko/.codex/worktrees/77a0/story`).
First of the owner's reference-building features (order: growing upper floors, then spires,
more skywalks, swooping roofs; then a broader Pure Village building overhaul).
References: York's Shambles (each storey overhangs the one below; facing upper floors nearly
meet over the lane) and the Suntail reference images. Memory: town-reference-buildings.

## Intent

Some houses — not all, by tunable odds — grow outward storey by storey on their street faces,
so upper floors lean over the lane and facing houses nearly touch at the top while the lane
keeps a slot of sky. Hard rules exist only as guardrails against broken-looking geometry; a
guardrail withdraws the offending step, never a house or a town. With the knobs at zero,
towns are byte-identical to today.

Success:
- Growing houses read as Shambles-style leaning fronts in street-level views.
- Facing upper floors come within `lane_sky_gap` of each other, never closer.
- No lean enters walking air, clips a neighbour or feature, or projects past its roof.
- Fingerprint and old-look pins hold at `growing_house_chance = 0`.

Out of scope: spires, skywalk counts, swooping roofs (later specs); planner (fabric) changes —
the lean lives entirely in the kit layer and the planner's lots and walks are unchanged.

## Approach (owner choice C: kit layer only)

The kit layer already moves one storey's face outward: `KitRoomProjections` sets
`storey.wall_offsets[edge]` (module units; `BuildingKitAssembler.storey_slots` applies it to
the wall slots) and `_emit_projected_front` closes it with `frontage.floor` + `trim.floor_beam`
under the overhang, `frontage.return` + `frontage.return_beam` on each side and `bracket.small`
at the joints, after testing measured AABBs against public air (`KitPublicClearance`) and
other houses. Returns are baked at one depth (`KitRoomProjections.DEPTH` 0.65 native m).

Growing generalises this to a cumulative per-storey offset on chosen faces:

- Storey `k` above the house's ground storey on a growing face sits `k * step` outward,
  capped at `growth_max_lean`; the ground storey stays on the lot line, so the lane keeps its
  width at street level.
- Units: kit native metres (module 2.0 m, storey 3.0 m; world = native x 2). Steps are
  sub-module offsets applied through `wall_offsets` (module fractions).
- Each step is closed exactly as a projection: floor strip + jetty beam under the overhang,
  side returns from the shifted face back to the unshifted side walls, brackets at joints.
- Returns: bake a finite family of `frontage.return*` / `frontage.return_beam*` variants at
  the cumulative depths the knob values can produce (1–4 steps of each allowed step size),
  through the existing manifest clip mechanism (`town_room_fronts.json`), never by runtime
  scaling. The knob `growth_step` therefore draws from the baked step sizes only.
- A growing face replaces the existing single-step jetty (`BuildingDesigner._assign_jetties`)
  on that face; the two never stack. Non-growing houses keep today's jetties.

## Knobs (`terrain/villages/town_odds.tres`, TownCharacter streams)

| Knob | Kind | Meaning | Default |
|---|---|---|---|
| `growing_house_chance` | CHANCE | share of eligible houses (2+ storeys above ground with a street face) that grow | 0.3 small → 0.45 large, spread 0.1 |
| `growth_street_face_chance` | CHANCE | per street-facing exposed face of a growing house | 0.85 |
| `growth_other_face_chance` | CHANCE | per other exposed face | 0.1 |
| `growth_step` | WEIGHTS | step per storey, from the baked sizes | {0.25 native m (0.5 m world): 1, 0.5 native m (1.0 m world): 1} |
| `growth_max_lean` | RANGE_FLOAT | total lean cap of the top storey, native m | 1.0–1.5 (2–3 m world) |
| `lane_sky_gap` | RANGE_FLOAT | minimum open gap between facing upper floors, native m | 0.75 (1.5 m world) |
| `growth_gable_front_boost` | RANGE_FLOAT | odds multiplier toward gable-to-street in `BuildingDesigner._square_axis` for growing houses | 2.0 |

Rolls are keyed by house stable id (and face/edge), so one knob never reshuffles another
and one house's roll is independent of processing order. `growing_house_chance = 0` (and the
boost then unused) must reproduce today's payloads exactly. The kit reaches the character via
`maze_source_plan.scale_profile` (`TownCharacter.of(profile, seed)`), threaded through the
designer `context`; a null source plan means no growth.

"Street face": an exposed edge whose outward cell is public air (lane, stair, court, plaza)
at the storey's bands per the kit grid callbacks. Party walls and faces whose outward cell is
another building are never eligible.

## Guardrails (each withdraws only the failing step)

Steps are applied storey by storey from the bottom. If a step fails any check, that storey
takes no further step on that face and every storey above it keeps the last accepted lean.

1. **Walking air.** No leaned geometry (wall, floor strip, beam, returns, brackets) intersects
   public air or its headroom (`KitPublicClearance.intersects_air`).
2. **Sky gap.** Measured distance from the leaned face to the facing facade across the lane
   (including that facade's own accepted lean) is at least `lane_sky_gap`. Houses are
   processed in a fixed sorted order (`KitVillageBuildings.sorted_ids`), so the later house of
   a facing pair sees the earlier one's lean.
3. **Neighbours and features.** No intersection with other houses, skywalks/bridge-houses,
   towers, bays/oriels, balconies, porch canopies (measured AABB pattern of
   `KitRoomProjections.fit` / `KitTownFacadeBays.fit`).
4. **Fully exposed face.** The face run and both of its ends are exposed (no `_touches_other`
   contact at the storey's bands), so returns never push into a neighbour.
5. **Matching footprint.** The storey's cells equal the storey below's cells (same rule as
   today's jetties).
6. **Skywalk ends.** A storey bearing a skywalk/bridge-house end does not step on that face.
7. **Roof cover** (see Roofs): the top storey's lean on an eave-facing face never exceeds the
   measured eave overhang minus a margin.

## Roofs

- **Gable to street** (preferred for growing houses via `growth_gable_front_boost` when the
  ridge axis is a free choice): the end gable and end roof pieces move outward with the top
  storey's lean; overlap with the adjacent middle piece is trimmed with the existing roof
  `clip_volumes` / `KitRoofMeshUnion` path, so no coplanar overlap remains.
- **Eave to street:** the roof cannot shift sideways; the top storey's lean on that face is
  capped by guardrail 7, so the wall stays under the eave. Lower storeys may still step.
- `BuildingDesigner.roof_proportion_ok` (Oct 8) still applies unchanged.

## Interactions

- Ordering in `KitVillageBuildings`: growth runs where projections run today (after roofs are
  joined, before `KitTownFacadeBays`), and accepted leans are appended to `walls` for roof
  cutting; towers, bays and balconies are fitted afterwards against the leaned walls.
- A balcony or bay is not placed on a storey face that leans.
- Existing `KitRoomProjections` on a growing face are replaced by the growth (no double
  offset); elsewhere they are unchanged.
- Merged compound houses: growth keys on `(cell, dir)` edges of the merged storeys; the
  matching-footprint and exposed-face guardrails apply per edge run.

## Testing

- Odds: per-knob determinism; changing one growth knob leaves other knobs' draws and other
  houses' rolls unchanged.
- Zero knob: `growing_house_chance = 0` → fingerprint `baseline.json` MATCH and
  `test_town_old_look` pass.
- Geometry: on a growing house, each street-face storey's wall offset equals
  `min(k * step, last accepted lean)`; returns, floor strip and beam present for every step.
- One focused red-first test per guardrail (1–7) where that guardrail must withdraw exactly
  the failing step and leave lower steps.
- Corpus (fingerprint towns + production sample with growth on): zero walking-air
  intrusions, every facing pair ≥ `lane_sky_gap`, every return closed, every overhang floored,
  no wall beyond its roof edge, zero null towns, zero floating masses, zero roof/public-air
  intrusions.
- Edge cases: a house exactly at the lean cap; two growing houses facing across a one-cell
  lane; a leaning face next to a skywalk end; a merged compound house; a top storey smaller
  than the storey below.
- Evidence: before/after renders of the 8 fingerprint towns (same cameras), street-level
  views down the narrowest lanes (Shambles framing), a building gallery of growing houses at
  several knob values; write-up `docs/qa/2026-10-08-growing-floors/result.md` and an AGENTS.md
  entry.

## Risks

- Baked return family size grows with steps x max lean; keep the step set to two sizes and the
  cap to four steps.
- The planner does not know about the lean; later features that reason about upper-floor
  air (rooftop walks, skywalk selection) must ask the kit layer's accepted leans.
- Gable-end shifting depends on roof piece clipping; if a kit roof family cannot be clipped
  cleanly, that family falls back to the eave rule (lean capped under the roof edge).
