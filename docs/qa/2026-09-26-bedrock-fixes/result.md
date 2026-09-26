# Bedrock in game, and the owner's September 26 issues

The owner chose bedrock with ledges. `scenes/world.tscn` now sets `CLIFF_STYLE = "sheet_bedrock"`. The game was still on the previous `sheet` style: Meadow meshes on the slopes, which are the "smooshed" rocks.

Every issue was reproduced at the owner's F3 coordinates on seed 2697992464, from the tactical camera (26 m back, 16 m up, `ReviewCam.solve_cam`), with grass on. Each image pair is the first bedrock render against the final one.

## Owner's in-game issues

**Light/dark green seam beside paths, on ordinary ground (s5, s6).** Three causes:
- **Level steps got a slope.** The envelope rounded the terrain's own 1 m level steps, laying slope strips over ordinary ground in a different colour and with different grass.
  - The slope now fades back to the terrain wherever the local relief (highest minus lowest ground within 14 m) is under 2-3.2 m.
  - A storey cliff keeps its slope; a level step does not.
- **Staircase road cuts.** The road keep-out was sampled on 2 m blocks, so the cut beside a path was a staircase. Blocks on the mask's edge are now resolved per 0.5 m node.
- **Gentle slope was darker.** It carried moss patches, detail and brightness drift. It is now exactly the terrain's lawn colour, and moss comes in only from about 18 to 40 degrees.

**Gaps in the ground (s3).** Where the slope hides a native lip, the terrain surface stops 2.5 m behind the cell edge. The slope solid covered only 2.5 m back from its raised part, which left a slit showing the void. The margin is now 4 m; there, the solid lies 2 cm under the terrain.

**Tiny triangles in slopes (s4).** Where the slope was too steep for grass, its grass support returned nothing. Grass fell back to the terrain underneath, and blades rooted under the slope poked their tips through. Two changes:
- A steep point is now claimed with zero grass.
- Where the slope sinks under the terrain (its foot), the terrain's own grass grows.

Grass on slopes also thins more gradually: full density to 26 degrees, none past 52.

**Cliffs at water (s1, s2).**
- **Before:** water was a keep-out, so the slope was cut down to the water's edge by a 54-degree plane. That plane showed as flat green walls, with see-through panels where native pieces had been hidden.
- **Now:** the slope runs into the water for up to 5 m from the shore, then sinks under the surface by the same cut. It can never fill a channel.
- **Rock at cut faces:** any face a road or water cut exposes (0.3 m or more) is bare bedrock.

**Rocks pasted on slopes (s7).** Under bedrock the rock is part of the slope. Loose rocks are Meadow boulders only, at 2-6% of the wall height (the foot).

## From the bedrock study screenshots

- **Rocks in walls:** foot rocks only, as above.
- **Void gaps:** the study harness rebuilt only some chunks (its artifact), plus the lip slit above.
- **Lip seam, two options tried:**
  - `sheet_bedrock+underlip` keeps the native lip. The slope leaves the wall about 1.2 m under it, with small shoulders. It is rejected: native walls and dark voids show between the wall and the slope (`lip-options.jpg`, `water-lip-options.jpg`).
  - **Chosen: no lips.** Lips hide wherever the slope covers them, and the slope rounds straight off the plateau with matched lawn colour and continuous grass. Lips the slope does not cover (road cuts, banks) stay: hiding every lip opened slits.

## Review tooling

- **Chunk rebuild:** `FieldTerrainStreamer.rebuild_terrain(chunks)` and `GrassStreamer.discard_parent` let the review harness rebuild whole chunks (terrain, native-piece hiding, grass) with the current scripts. They are for review only.
- **Harness modes:** `cliff_site_review` gains `--full` (full rebuild on each reload), `--shot id:player:crosshair` (owner F3 poses) and grass that follows each shot.

## Tests

- **New:** `tests/test_september26_bedrock.gd`, 6 tests:
  - carved rock leaves no hole;
  - level steps take no slope;
  - cliffs keep theirs;
  - the slope runs into water, then sinks;
  - a steep slope claims its grass points;
  - underlip keeps the lip.
- **Existing:** September 23 cliff directions 34/34, grass field 16/16, grass streamer 7/7, September 16 cliff grass 4/4.
- **Known failures, unrelated:** `test_field_streamer` (1 of 16) and the September 13 terrace grass stale-UID error.

## Limits

- **Road-cut lines:** s5 keeps two faint lines along the path, much milder than before.
- **Rock under water:** it reads pale and blotchy through the water.
- **No grass on steep slopes:** steep slopes carry no grass, so they read smooth next to grassy terrace tops.
- **Not verified in the running game:** these checks used the review harness, not a play session.
