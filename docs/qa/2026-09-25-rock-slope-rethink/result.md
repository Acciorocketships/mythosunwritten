# Rock/slope rethink: method study (September 25)

Owner asked:
- The rocks don't mesh with the slope. The slope should run seamlessly into rock in places.
- Where moss meets rock, the rock must not jut out, though it may jut out elsewhere.
- Ledges should come back.

Four methods were compared with the same cameras at the massif (seed 2697992464, site 290,25,1005, review harness hot reload). Two further ideas were ruled out without being built.

Production is unchanged. Each study method is its own style, `sheet_<variant>` (`CliffRockStyle.sheet_study`).

## Methods

| | Method | Kind | Result |
|---|---|---|---|
| A | production (`sheet`): Meadow meshes set on the slope | assets | rock and moss are separate meshes, with a crease and dark contact where they meet |
| B | **bedrock** (`sheet_bedrock`): rock exposed in the slope surface itself | generated | **best**: continuous by construction, real ledges, upright faces |
| C | stamp (`sheet_stamp`): Meadow front relief merged into the slope solid | assets → field | rejected: the 0.5 m solid melts the asset shape into grey slabs |
| D | blend (`sheet_blend`): Meadow meshes, with the solid unioned to each rock's relief to fillet the join | assets | marginal: a larger fillet swallows the rock whole, and a small one barely changes production |

**Bedrock (B) — mask.** A world-space patch mask picks parts of steep faces (`CliffSlopeEnvelope._bedrock`).

**Bedrock (B) — shaping inside each patch.** The moss envelope is reshaped by Voronoi blocks (world lattice, 5.5 m):
- **Stretch:** blocks are stretched 2.2 times along the contour.
- **Benches:** each block terraces the slope with its own phase, bench height (3.5-6.5 m) and riser (15-30%). A third of the blocks have no bench and form one tall upright face.
- **Splits:** splits are cut between blocks.
- **Jut:** blocks jut out by up to 1 m, but only well inside a patch and never near the crest.

**Bedrock (B) — join.** The reshaping fades to nothing over about 2 m at the patch edge, so moss runs into rock with no lip.

**Bedrock (B) — shading.**
- Bare rock uses Meadow's `T_Rock_02` stone, triplanar, with flat facet normals for crisp planes.
- Flat benches take the slope's grass colour.
- Meadow boulders stay at the foot.

**Why B.**
- **One surface:** rock, moss and ledges are one mesh and one collision surface, so there is no seam and benches are walkable.
- **Shared seams:** chunks agree at seams, because the fields are world-aligned.

**Why C and D fall short.** Whatever an asset brings (chips, cracks, crisp edges) is below the slope solid's 0.5 m resolution. C loses it. D keeps it only while the join stays a crease.

**Not built.**
- Restoring the old `CliffRockCrags` ledges inside the slope would repeat D's join problem at a larger scale.
- Dual contouring for sharper generated edges would be a larger meshing change. The facet shading covers most of that look.

## Images

- `compare-face.jpg`, `compare-side.jpg`, `compare-wide.jpg`: A/B/C/D from the same camera.
- `bedrock-face.png`, `bedrock-side.png`: B at full size.
- `studio-bedrock.jpg`: B on a synthetic 12 m wall with a 5 m terrace (`tests/harness/slope_study_review.gd`, about 20 s per variant, no world load).

## Limits

- **Holes in the images:** holes and straight seams at the far top of some views are the review harness's artifact. It rebuilds only chunks near the view targets, so a rebuilt study chunk meets an unrebuilt production chunk at z = 960. A plan view of that seam confirms it. The studio render of the whole field has no holes.
- **Not checked in the real streaming path:** B's native-piece hiding and grass support. Where carving recesses the slope just under a lip, native wall pieces may stay visible.
- **Tall faces:** benches still tend to follow the contours and read as lines.
- **Not playable in game:** C and D call rock preparation on the main thread only, so they cannot run in the streamer.

Production tests: 34/34 in `test_september23_cliff_directions.gd` (production path unchanged).
