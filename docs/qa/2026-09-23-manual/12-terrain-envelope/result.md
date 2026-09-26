# Sheet style as a terrain envelope (September 25)

Owner, in-game on the green massif (three annotated screenshots):
- **Abrupt ends.** Slopes end abruptly and then drop straight down, both outward and along the wall. Every slope should be gentle, well behaved and continuous, meshing with the others and with the landscape, with no ledges anywhere, as natural as possible.
- **Grey triangles.** Tiny grey triangles show where the rock wall behind pokes out.

Images:
- Owner screenshot | now (approximate pose from the F3 coordinates, tactical camera).
- `4-*`: far and top-down views.
- `5-*`: rock chips before and after.

## Root cause

- **Per-line slopes.** Each slope was a per-foot-line height, evaluated only inside a fixed band: meshing columns reached 18 m, contributions 20 m.
- **Where they stopped.** Tall walls' slopes, and slopes over lower terraces, were still above the ground at that band edge, at line ends (receding 2.5 m, then gone) and wherever no formation was admitted. The solid closed with a vertical face there. These are the circled "curtains".
- **Not a patching problem.** No further patching of per-line slopes removes every such edge.

## Model (`CliffSlopeEnvelope`)

- **Envelope.** The slope is now a rounded envelope of the terrain itself: `F = erode_FOOT(dilate_{SHOULDER+FOOT}(g))`. Both transforms are exact separable parabolic lower envelopes (Felzenszwalb) on a world-aligned 0.5 m grid.
- **Shape.** Every convex lip gets a rounded shoulder (radius 4-11 m) and every concave foot a fillet (10 m).
- **Continuity.** It is one field over the whole ground, so it continues round both kinds of corner, past wall ends and across stacked storeys and narrow terraces. It meets the plateau flush and the ground tangentially.
- **Chunks.** A 56 m pad makes every chunk compute identical values at shared points.
- **Ridges and valleys.** A narrow and a wide shoulder are blended by noise taken at the lip point each point falls from (`q + R grad D`, lightly blurred), so ridges run down the fall lines. Fine bumps ride within the same band and can never rise over a lip or dip through the ground.
- **Keep-out.** Roads, plazas, graded village ground and water cap the envelope by a 1.4 cut rising from their edge, not a wall. The query is per terrain cell, and water is checked only beside carved cells.
- **Foot lines.** These now serve only rock placement. Formations are outlines (pass 11), and rocks sit on the envelope.

## Native pieces and chips

- **Covered pieces.** Native wall rows, lips and skirt quads the slope covers are hidden (`uncovered`, `uncovered_faces`). Where a road cut leaves the wall exposed, they stay.
- **Rock chips.** Rocks under 1.5 m are no longer placed. Rock swells are 60% of the rock (was 75%), with a blend scaled to the rock instead of a fixed metre. Small rocks had been swallowed into chips.
- **Reservations.** Ambient dressing is reserved off the raised slope (2 m row runs), so no terrain-rooted rock or plant is buried with a tip showing.

## Lawn, moss and grass

- **Colour.** The slope's moss grade reads its steepness (`SHEET_MOSS_RISE`): gentle shoulders, benches and feet take the exact lawn colour, and steeper ground grows moss in patches. The straight lawn/moss boundary at every plateau edge is gone.
- **Grass.** Grass grows on the slope through a heightfield support (`GrassSupportSurfaces.at_grid`). It thins with steepness and stays clear of the rocks.
- **Speckle.** A rise under 15 cm stays the terrain's. The envelope rounds the terrain's 1 m level steps by centimetres.

## Cost

- **Profiled chunk.** Envelope 4-5.5 s per chunk: ground 1.5 s, transforms 1.6 s, ridges 1-1.8 s. The keep-out query had taken up to 20 s near water and villages; it now takes about 0.1 s.
- **Green site.** Cliff stages of 9-20 s per chunk (two chunks took 234 and 288 s before the keep-out fix). The default style takes about 43 s on a massif chunk.

## Limits

- **Top-down lines.** From straight above, faint speckled lines remain along some cell boundaries on flat plateaus. They are not visible at play angles; the source is not confirmed.
- **Water.** Cliffs dropping into water get a cut to the shoreline; not reviewed at a water site this pass.
- **Rocks.** Still no collision.

## Tests

The September 23 file passes 27 tests. The new or rewritten ones:
- no ledges anywhere: across stacked storeys, an L plateau, an 8 to 4 m step and a 12 m cliff, every neighbouring 0.5 m pair differs by under 0.9 m;
- flush lip and a gentle descent;
- rolling ridges;
- chunk windows agree exactly at the seam;
- a clean road cut;
- covered native pieces hidden, cut ones kept;
- no visible holes (edges under 2 cm ignored).

## Follow-up: flat ground back, rocks embedded, walkable sides (September 25)

Owner in game:
- the slopes took over, with no flat ground left (top priority), and the fix must not bring back the earlier glitches;
- rock undersides showed over air, when only rock tops should show; tall rocks belong on cliff sides;
- the character could not walk up moderate slopes.

Changes:
- **Tighter envelope.** Same envelope, much smaller radii: shoulder 1.5-4 m, foot 3 m (were 4-11 m and 10 m).
  - A one-storey side runs out 6-7 m (was 13 m or more); a three-storey one 10-12 m.
  - A 24 m terrace keeps its middle flat, and the plain below the massif stays flat to the foot.
  - Continuity is unchanged: the envelope still cannot stop and drop anywhere.
  - Sides are steeper (up to about 70 degrees on tall cliffs, never a sheer step).
  - The pad is down to 32 m.
- **Embedded rocks.** Every rock's footprint (24 points around its base) is sunk until the whole base is 25 cm under the surface.
  - It then shows only 30-60% of its height, and moves down the slope if the face is too steep for that; otherwise it is skipped.
  - Flat rocks lie parallel to the slope; the tall stratified masses stand upright in the (now steep) cliff sides.
- **Walking.** The character walks up 55 degrees (`MAX_WALK_SLOPE_DEGREES`, was Godot's 45).
  - A one-storey side's steepest 0.5 m rise stays under 54.5 degrees, ridges and bumps included.
  - Taller sides remain cliffs.
- **Review spawn.** The player spawns at the massif (`scenes/world.tscn`). The teleport label stays up with the number of areas ready until movement unlocks. A headless run spawned, landed (`floor=true`) and walked 40 m. That run predates the tighter radii; spawn and landing are unaffected by them.

Images: `6-*-flat.jpg` (wide view of the massif and plain, two close views).

Tests: the September 23 file passes 30 tests. New or changed:
- terraces stay flat;
- flat ground beyond a cliff side is exactly flat;
- sides are steep but never a sheer drop (0.5 m rise under 1.4 m);
- every rock's base lies under the surface with its top showing;
- one-storey sides are walkable at the character's 55 degrees.

## Follow-up: spaced rock clusters, compact corners (September 25)

Owner:
- rocks formed giant clusters with large empty areas, particularly round corners; wanted 2-3-rock clusters spaced out;
- the slope next to outer corners went out much further than along edges.

Changes:
- **Rocks.** One rule replaces the outcrops and face rocks: clusters of two or three rocks, 2.5-4.5 m for the largest, on 7 m slots (75% filled).
  - Slots run along every cliff line to its very ends (the old outcrops stopped 2.5 m short, and skipped corners). Every outer corner also gets a slot.
  - Clusters sit at 20-70% of the face height.
- **Corners, measured.** At the massif's outer corners the slope reached 16-20 m along the diagonal against 8-14 m off the edges.
  - The diagonal cell there drops 16-24 m: the terrain lets a diagonal fall two storeys more than an edge.
  - Two terrace walls meet below it as an inner corner of the lower ground, which fills out about 1.4 times a wall's reach.
- **Corners, fix.** Where the relief feeding a slope is tall (from 4 m, fully by 10 m), the envelope blends to a tight profile (shoulder 0.6 m, foot 1.2 m).
  - The relief is measured continuously and spread over the fan it feeds, so no ledge appears.
  - Tall drops get steep, compact sides (up to about 75 degrees); one-storey edges keep the gentle, walkable profile.
  - In the test layout the corner reach falls from 16 m to 9 m against 5.8 m edges.

Tests: 31 pass.
- New: clusters of two or three, no bare stretch over 21 m along an 80 m wall, rocks at the corner, no rock over 6.5 m.
- New: corner reach within 1.6 times the edges'.
