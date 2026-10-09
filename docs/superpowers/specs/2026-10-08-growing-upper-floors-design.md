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
see "Amendment (October 8, owner review)", which overrides the sections above it. Amended again
October 9: a growing house steps its LOWER storeys in under a fixed roof and top storey — see
"Amendment 2 (October 9): step in the kit's way", which overrides everything above it.)
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

## Amendment 2 (October 9): step in the kit's way

Binding owner decision after Task 8 (ledger `.superpowers/sdd/2026-10-08-growing-upper-floors/progress.md`,
measurements in `task-8-report.md`). Where it conflicts with anything above (the original sections and
the October 8 amendment), this section wins.

Why: making a stepped-out top storey follow its roof (gable end shifted with a clipped filler, eave faces
capped under the measured cornice, then a one-face ground inset under eaves) collapsed the corpus from
21 stepping faces to 2. No kit jetty fits under a Suntail eave (allowance 0.0 native m), Pure capped
gables cannot move, and most faces met an uncovered crown at their first step.

### Decision

**Option 2: the step-in is the main (and only) way a house grows.** A growing house keeps its roof and its
top storey on the footprint. Each lower storey steps IN cumulatively on its stepping faces, so the ground
storey is the narrowest and every upper storey overhangs the one below on the kit's own jetty (floor
beam on the face, `bracket.jetty` diagonal braces), as in the Suntail reference image (a narrower stone
ground floor with a timber storey jutting over it) and York's Shambles. Accepted cost (owner): upper
floors no longer lean across the lane; facing houses keep today's gap at every upper storey.

### Re-referencing (how it is built)

The cumulative step machinery stays: fronts (lone faces, convex-corner wraps, coplanar row joints,
inside-corner ends), one monotone profile per front from the leader's `growth_step` and the cap, the
closure kinds `return` / `wrap` / `joint` / `bury`, the baked `frontage.*.dNNN` families, the kit's
jetty brace (`bracket.small` for the light 0.5 step), the guardrail framework (a failing step is withdrawn
for the front, a member that cannot hold leaves, withdrawals recorded per cause) and the per-key rolls.
What changes is the reference: each storey's wall offset is expressed relative to the TOP storey of its
face. With the profile `lean_k` (k = 0 is the first storey above the ground storey, as before) and
`T = lean_top`, storey k stands at `lean_k - T` and the ground storey at `-T` (all <= 0, native m). The
old step-out profile [0, 1, 2, 2] becomes [-2, -1, 0, 0]: the ground storey two kit jetties in, the first
upper storey one in, the top two on the lot line. A front steps only up to its shortest active member's
top storey (above it every member holds), so every member's top is the same `T` and joints and wraps
stay equal at every shared storey. The profile is still the monotone capped one; it is now found by
testing the whole face at its final offsets and dropping the cap one step on a failure (identical to the
old "hold from the failing storey up").

Under step-in the closures mean:

- `return` (the run ends convex with open ground beside it): the perpendicular wall's corner panel of
  every stepped-in storey shortens by that storey's inset — the baked `frontage.return.dNNN` strip of the
  remaining length (module minus inset; 1.5 / 1.0 / 0.5 for insets 0.5 / 1.0 / 1.5), or the panel is
  dropped for a whole-module inset and the next panel takes the corner; the corner post moves to the new
  corner. The overhang above closes its open side with the baked return beam.
- `wrap` (a convex corner whose perpendicular face of the same house is in the front): both faces step
  in equally; each corner panel is shortened by the other face's inset; one post at the new corner; the
  floor of a stepped-in upper storey keeps the inner square (`frontage.corner.dNNN`).
- `joint` (another house beside the end whose coplanar face is in the front): both step in equally; no
  piece at the joint.
- `bury` (the house's own cell beside the end: an own wing, or its own wall continuing behind a
  neighbour): the recess is closed on the vertex line by the baked return strip of the inset's depth,
  facing the recess, so no hole opens into the room beside it.
- otherwise `blocked` (another building beside the end not stepping with it, the perpendicular face
  already stepped by an earlier front, or a door, passage, bay or blank on the corner panel the step
  would cut): the step is withdrawn.

Floors: the ground storey keeps its full floor, so the strip it uncovers under the overhang is the house's
own pad (paving under the overhang). A stepped-in UPPER storey's floor is trimmed to its own wall (the
baked `frontage.floor.dNNN` inner strip, or the inner `frontage.corner.dNNN` square at a wrapped corner;
no board for a cell the inset leaves entirely) — a full board would be a ledge outside the wall.

### Supersedes

- Approach: "storey k sits `k * step` outward"; "the ground storey stays on the lot line, so the lane
  keeps its width at street level" (the ground is now the narrowest storey; the lane is never narrowed at
  any height).
- Success: "facing upper floors come within `lane_sky_gap`" (they keep today's gap) and "no lean projects
  past its roof" (nothing leaves the footprint; roofs never move).
- Guardrail 2's purpose (sky gap) and guardrail 7, the Roofs section, and the October 8 amendment's
  Roofs paragraph: no gable shift, no clipped filler, no eave allowance/cap, no crown rule, no one-face
  eave inset. Decision 3's "the attic gable steps out with the top storey".
- Decision 4b's bury semantics (an end run into a plain perpendicular wall in front of the face): under
  step-in nothing moves outward, so a neighbour standing in front of an end no longer matters, and `bury`
  is the own-cell recess closure above. The plain-wall contact test retires.
- Decision 5's closing pieces (extension strips past the old corner, corner floor/ceiling squares outside
  the footprint, `WRAP_INSET`): a wrap now shortens both corner panels inward.
- The knob table (below).

### Recessed doors

A door on the GROUND storey's stepped-in run no longer withdraws the step: the door panel moves in with
its wall (a shopfront under the overhang) and its doorstep dressing moves with it. The walk still reaches
it: a town's public walk (the lane surface) ends at the lot line and the strip between the lot line and
the recessed threshold is the house's own cell, already floored by the ground storey's `deck.board` (kept
whole, above), at the threshold's level; no path paint is extended (towns have none inside a lot; the
kit layer does not paint). Other portals keep their old effect, mapped through the re-referencing: a
storey with a skywalk/bridge passage or a blank on its run, or whose wall (or the storey above's) bears a
balcony, neither steps in nor overhangs the storey below (the cap drops until it stands on the lot line
over a storey on the lot line). A door on a stepped-in UPPER storey still withdraws the step (its landing
is an upper walk at the lot line and the trimmed floor would leave a gap). A bay on a stepped-in run
withdraws the step (it would stand under the overhang's braces); a bay on a storey that only overhangs
is unaffected.

### Brace placement

Growth braces (`bracket.jetty` for a kit step, `bracket.small` for the light step) stand on wall-module
joints of the stepped-in storey below — the panel joints between window/door slots and the corner posts —
never over a window or door head (kit rule since September 27: braces bear on module joints). One brace
per joint: each overhanging slot owns its right joint; it also owns its left joint unless that joint is a
wrapped corner (the perpendicular face's slot owns it) or a row joint (the neighbour's slot owns it). The
kit's own non-growing jetty (`_emit_jetty_trim`, slot-centre braces) is unchanged so zero-chance towns
stay byte-identical; whether it should follow the joint rule too is an open owner question.

### Guardrails under step-in

Every step-in piece stands inside the house's own cells, so guardrails whose purpose was outward
intrusion become trivially satisfied. They stay in the framework; the table says which can still fire.

| Guardrail | Under step-in |
|---|---|
| G1 walking air | Can fire only where public air reaches inside the house (a passage or tunnel through it): the new braces, beams, strips and moved dressing are tested. |
| G2 sky gap | Cannot fire: checked only for an outward offset, and growth writes none. `gap_ok` stays (room projections facing a growth registry entry use it; growth now registers none). |
| G3 neighbours / features | Can fire only for pieces of another building or a tower reaching into the recess. Reserved grid claims are now tested on the recess cells themselves (a passage or podium claim through the stepped-in storey), not on the lane beyond the face. |
| G4 → end rule | `return` / `wrap` / `joint` / `bury` / `blocked` as above. |
| G5 footprint | Unchanged (the face chain walk). |
| G6 portals | As in "Recessed doors". |
| G7 crown | Removed. |
| Bearing (new) | A stepped-in storey still bears the storey above: every overhang is one step (at most the kit jetty) carried by braces, and behind every stepped-in edge at least one module of floor remains, at least two across an axis stepped in from both sides (counting the opposite face's committed or same-front offset; the kit's own jetty never leaves a one-module stalk). |
| Party (new) | A stepped-in storey's run must be exposed at its bands: a party wall or a touching neighbour (including a lower neighbour against the ground storey) never steps in, so such a face stays flush (cause `party`). Beside an end, only a coplanar row stepping together (`joint`) admits a neighbour. |
| Material (new form) | A stepped-in storey is a two-band, non-retaining, non-fortified, non-sunk, non-abutted storey without a kit jetty or a pent eave. A stone (non-timber) storey steps in only by whole modules (no baked stone half strip exists, so a fractional inset of a stone storey withdraws the step; at the default cap the ground storey steps in a whole module). An overhanging storey is timber, as before. |
| Decor (new) | Dressing on a stepped-in run (window boxes, ivy, doorsteps, awnings) moves in with its wall; dressing on a corner panel the step cuts is removed; a porch post standing on the run withdraws the step. Moved or kept dressing that the new braces/beams meet yields if it is a yielding kind (Decision 6 list), else the step is withdrawn. |

Guardrails still withdraw only the failing step (the cap drops one step for the front), never a house or
a town; `growing_house_chance = 0` stays byte-identical (fingerprint MATCH, old-look pin).

### Knobs (supersedes both tables above)

| Knob | Kind | Meaning | Default |
|---|---|---|---|
| `growing_house_chance` | CHANCE | share of eligible houses (2+ stacked storeys, at least one exposed face) that grow | 0.3 small → 0.45 large, spread 0.1 (shipped in the defaults task; 0 until then) |
| `growth_street_face_chance` | CHANCE | per exposed face that fronts public air | 0.85 |
| `growth_other_face_chance` | CHANCE | per other exposed face | 0.85 |
| `growth_step` | WEIGHTS | step per storey, native m | {0.5: 1, 1.0 (the kit jetty): 3} |
| `growth_max_lean` | RANGE_FLOAT | total step-in of the ground storey below the top storey, native m (name kept) | 2.0 (two kit steps; 4 m world) |
| `lane_sky_gap` | RANGE_FLOAT | inert under step-in; kept as the guardrail value for any outward offset (G2, and room projections facing a growth registry entry) | 0.75 |

`growth_gable_front_boost` is removed (knob, designer member and context key): it existed so a top
storey could step under a movable gable end; with roofs fixed it would only reshuffle growing houses'
ridge rolls for no purpose.

### Interactions

Growth records no longer enter the roof-cutting `walls` (nothing new stands beyond the footprint). Room
projections and facade bays still skip a stepping face on every storey of its chain (`storey.growth` holds
the signed offset, 0.0 on held top storeys). Towers and feature masses remain obstacles.

### Testing (adds to the sections above)

Re-referenced offsets per storey (ground included); cut/dropped corner panels and moved corner posts;
upper-floor trim; bury strips; braces on joints only (none over a window or door head) with one owner
per joint; recessed ground door with its doorstep and a floored walk to the threshold; upper-storey door,
passage, balcony and bay rules; bearing (one-side and both-side), stone whole-module rule, party rule;
roofs and top storeys identical to the house without growth. Corpus: stepping faces well above Task 7's
21 (roofs no longer block), counts per cause, zero violations (pieces outside the lot, air, open ends,
broken joints, unbraced overhangs, braces over openings, floor ledges, moved roofs or tops, thin bearing,
floating masses, roof/public-air intrusions). Evidence: street-level views along lanes (Shambles framing),
side views of wrapped corners, rows and buried ends, recessed shopfront doors, and the deviations write-up.
