# Growing upper floors (cumulative jetties) — design

Date: October 8, 2026. Branch `town-redesign` (worktree `/Users/ryko/.codex/worktrees/77a0/story`).
First of the owner's reference-building features (order: growing upper floors, then spires,
more skywalks, swooping roofs; then a broader Pure Village building overhaul).
References: York's Shambles (each storey overhangs the one below; facing upper floors nearly
meet over the lane) and the Suntail reference images. Memory: town-reference-buildings.

## Intent

Some houses — not all, by tunable odds — grow outward storey by storey: each storey steps
out further than the one below (walls stay vertical; "lean" in code names means this cumulative
step-out), so upper floors overhang the lane and facing houses nearly touch at the top while the
lane keeps a slot of sky. (Amended October 8: any exposed face, kit-sized steps, wrap-around —
see "Amendment (October 8, owner review)", which overrides the sections above it.)
Hard rules exist only as guardrails against broken-looking geometry; a guardrail withdraws the offending step, never a house or a town. With the knobs at zero,
towns are byte-identical to today.

Success:
- Growing houses read as Shambles-style stepped-out fronts in street-level views.
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

## Amendment (October 8, owner review)

Binding owner decisions after Task 4's diagnosis (ledger
`.superpowers/sdd/2026-10-08-growing-upper-floors/progress.md`, measurements in `task-4-report.md`
"Diagnosis" and "Diagnosis 2"). Where they conflict with the sections above, this section wins.

Why: with the original rules only 1 of 45 rolled street faces stepped out in the 8 fingerprint
towns at `growing_house_chance = 1`. Most rejections were real interpenetration at face ENDS
(inside corners, coplanar terrace neighbours, own wings), three were false blockers, and the
street-face-only pool was small (45 faces). Every-exposed-face eligibility raises the pool to 183;
the three false-blocker fixes alone take it to 18 stepping faces, the coplanar terrace to 22;
the remaining end geometry (26 inside corners against another house, 33 coplanar, 28 projecting
neighbours, 27 own wings, 17 perpendicular faces) is what the wrap-around rules address.

### Decisions

1. **"Step out", not lean.** Each storey juts further than the one below; walls stay vertical.
   User-facing docs say "step out"; code names (`lean`, `growth`, `wall_offsets`) stay.
2. **Eligibility: any exposed face.** A house with at least two stacked storeys (ground storey +
   one above) is eligible on ANY exposed face (not touching another building at the storey's
   bands), not only street faces. Per edge, the face's edges must also be boundary edges of the
   storey below (matching footprint, guardrail 5), whether or not that lower edge is itself
   exposed (a face over a lower neighbour's roof, a garden or the town edge counts). The two
   face knobs stay; by default they are equal (0.85), so all exposed faces are treated alike.
3. **Kit-sized steps on the kit's own jetty.** The default step is the Suntail jetty: `jetty_depth`
   1.0 native m (half a module) per storey, carried by `bracket.jetty` (the kit's diagonal brace,
   1.0 drop / 1.0 span; one per module, placed exactly as the kit's own jetty places it, on the
   storey below's leaned face). A 0.5 native step stays as a lighter, rarer option carried by
   `bracket.small` (as Tasks 2-3 built it). The cap is 2.0 native (two kit steps). The 0.25 step is
   retired (its baked pieces stay in the catalogue; nothing places them). The attic gable steps
   out with the top storey (Roofs).
4. **Wrap-around at neighbours, by rule.** At each end of a stepping face, per storey:
   (a) **Coplanar terrace neighbour** (another house touching the end, facade on the same line,
   same first upper floor band): the two faces step out together over the storeys both have — a
   terrace row jets out as one. No returns at the shared joint; side pieces only at the row's
   open ends. A growing face pulls its coplanar neighbours' faces into its row (their houses need
   not have rolled growth; they must be eligible and pass every guardrail).
   (b) **Inside corner, perpendicular wall** (the cell diagonally beyond the end, in front of the
   face line, is another building — or the house's own wing): the stepped storey's end is run into
   that wall and buried (no visible return) only where that part of the wall is plain: the
   measured contact region (the wall plane over the step's depth and the storey's height,
   brace drop included) meets only plain wall panels, posts and floor beams — no window, door,
   eave/roof, balcony, bay, ornament. A baked abutment piece is added only if measurement shows
   the end panel stops short of the wall surface.
   (c) Otherwise the step is withdrawn, as before.
5. **Wrap around outer (convex) corners of the same house.** Adjacent exposed faces of one house
   meeting at a convex corner step out together, and the corner is closed: each face's wall runs
   on past the old corner by the step depth (a baked return strip turned to face out), a corner
   floor and ceiling square (new baked `frontage.corner.dNNN`), the face beams with it, and the
   corner post at the new corner. A growing face pulls its convex-corner neighbours into its
   front. This overrides the plan ruling "never two faces that meet at a corner"; two faces that
   meet at a convex corner either step equally (wrapped) or one of them is flush at that storey.
6. **Three false blockers fixed.** (i) The house's own bay or ornament on the stepping face of the
   stepping storey rides out with the face (it is part of that face) and is not an obstacle.
   (ii) The house's own ornaments on lower storeys that the new braces or floor strip meet (ivy,
   corner ivy, window boxes, awnings) yield: they are removed, not blocking. Rails, bays and
   architecture still block. (iii) Contact no deeper than 5 cm (`TOUCH`) is touching, not a
   collision.
7. **Principle.** Guardrails withdraw only the offending step — never a house or a town; in a
   front, the member that cannot hold a storey leaves the front at that storey (the rest keep
   stepping). `growing_house_chance = 0` stays byte-identical (fingerprint MATCH, old-look test).

### What changes

**Approach.** The unit that steps out is a FRONT: one or more face chains that step as one, joined
at convex corners of one house (`wrap`) and at coplanar joints between houses (`joint`). A lone
face is a front of one member. Fronts are built from every eligible house's face chains; a front
steps out when at least one member face belongs to a growing house and passed its face roll
(keyed by face key). The front's step and cap come from its leader (first member in key order):
the leader house's `growth_step` pick, quantised to what its kit can carry (1.0 needs
`bracket.jetty` and `jetty_depth` 1.0, else 0.5). One monotone profile per front, indexed by storey
above the shared first upper storey. Each end of each member closes by kind: `return` (open air),
`wrap`, `joint`, `bury`, or the step is withdrawn (`blocked`). Steps are applied through
`wall_offsets` / `projections{growth, base, closures}` as before; `bracket.jetty` replaces
`bracket.small` for a 1.0 increment.

**Knobs** (`terrain/villages/town_odds.tres`; supersedes the table above):

| Knob | Kind | Meaning | Default |
|---|---|---|---|
| `growing_house_chance` | CHANCE | share of eligible houses (2+ stacked storeys, at least one exposed face) that grow | 0.3 small → 0.45 large, spread 0.1 (shipped in the defaults task; 0 until then) |
| `growth_street_face_chance` | CHANCE | per exposed face that fronts public air | 0.85 |
| `growth_other_face_chance` | CHANCE | per other exposed face | 0.85 (equal: all exposed faces alike) |
| `growth_step` | WEIGHTS | step per storey, native m | {0.5 (1.0 m world): 1, 1.0 (2.0 m world, the kit jetty): 3} |
| `growth_max_lean` | RANGE_FLOAT | total step-out cap of the top storey, native m | 2.0 (two kit steps; 4 m world) |
| `lane_sky_gap` | RANGE_FLOAT | minimum open gap between facing upper floors, native m | 0.75 (1.5 m world) |
| `growth_gable_front_boost` | RANGE_FLOAT | odds multiplier toward gable-to-street for growing houses | 2.0 |

**Guardrails.** G1 (walking air), G2 (sky gap, per member), G3 (measured neighbours/features and
reserved columns), G5 (matching footprint per edge) and G6 (portals, balcony bearings) apply to
every member of a front. G3 skips touching contact (≤ 5 cm), pieces that ride with any active
member's face at that storey (own bay/ornament on the face; a terrace neighbour's facade at the
joint), and yielding ornaments (Decision 6). G4 is replaced by the end rule (Decision 4/5): an end
must close as `return`, `wrap`, `joint` or `bury`; anything else withdraws the step. The rejection
of each withdrawn step is recorded with its guardrail cause for the corpus audit. G7 (roof cover)
is unchanged in intent (below).

**Roofs.** Gable to the stepping face: the gable end, barge boards and end roof pieces move out
with the top storey (a full module at the 2.0 cap), the opened strip is filled with a clipped copy
of the end-adjacent roof pieces, as specified above. Eave to the stepping face: the eave does not
move; the top storey's step must stay under the measured cornice (G7). The Suntail cornice reaches
0.986 native m, so a 1.0 kit step cannot pass under an eave: an eave-crowned face falls back to the
0.5 step when the measured allowance admits 0.5, otherwise it stays flush (recorded cause
`crown`). A front member whose crown cannot cover the front's lean at its top storey leaves the
front there.

**Interactions.** Fronts cross houses (terrace rows), so fitting order is by front leader key, and
pulled neighbours are written like growing houses (wall offsets, projections) without changing
their designer choices (a pulled house with inset jetties on the face's storey faults on
`material` and leaves the front). Balconies, bays and room projections are still fitted after
growth around the stepped walls. Towers and feature masses remain obstacles.

**Testing additions.** Per decision: any-face eligibility (incl. a face over a lower neighbour),
kit brace placement and count, each false-blocker fix, outer-corner wrap closure (post, squares,
extension strips coplanar with the face), a terrace row stepping as one with returns only at the
open ends and a member leaving the row, inside-corner bury against a plain wall and withdrawal
against a window. Corpus targets (8 fingerprint towns, `growing_house_chance = 1`, both face
chances 1): stepping faces well above the Diagnosis 2 baseline of 18-22, counts reported per
withdrawal cause; zero violations (air, gap, open returns, open corners, broken joints, buried
ends on non-plain walls, unfloored overhangs, walls beyond their roof, floating masses, roof/public
air intrusions). Evidence adds street-level and side views of wrapped corners, rows and buried
ends, and a deviations write-up (ledger ruling F5).
