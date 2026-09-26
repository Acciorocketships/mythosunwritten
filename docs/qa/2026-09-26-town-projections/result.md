# Larger town projections — September 26

Follow-up to the owner’s request for more variation, larger balconies and overhangs, and corner support posts. Implemented in the existing separate `codex/town-shapes-wood` worktree.

Eight seeded lot variants replace the previous five. Wings extend two or more cells down the lot, with shifted upper rooms, broad upper halls, longer terraces and independently stepped third floors. Reserved lot boundaries and the planned ground entrance remain intact. Unsupported convex corners receive timber posts on stone feet down to the nearest bearing floor or flat lot ground; underside boards and wall brackets remain. More window boxes and ivy dress these freestanding houses, and pots sit beside terrace rails. Every disconnected terrace has its own house door.

The first regression fails on the prior implementation: only 32 multi-cell decks and 16 multi-cell projections across the 80 sampled houses, with no corner posts (`red.log`). The expanded candidate exposed a native roof collision miss on seed 1006: its broad upper hall exceeded the preferred roof axis’s supported depth. Oversized crowns now use the existing bounded roof splitter/orientation selection (`broad-roof-red.log`).

Final focused suite: **35 tests / 3,412 assertions pass**. It covers roof and balcony native collision, connected rooms, lot boundaries, four frontage directions, multi-cell projections and support posts, per-terrace access, roof joins, wood materials, kit inventory, hamlet construction and bake geometry. **18/18 actual player walks pass** across the flat hamlet square and approaches in both directions. These are scoped checks; the prior unrelated outskirts planner-envelope failure remains documented in the preceding review.

Five matched gallery pairs plus six alternate views inspect corners, lower bearing, roof intersections, balcony rail/door relationships and denser decoration. The reviewed native previews show larger terraces and projecting rooms supported by corner posts. Both wood finishes are retained.

The reported in-world site uses seed 2697992464, player (235.1,12,449.2), the existing `--reported` camera, and eight 65 m / 32 m orbit cameras. The prior pass’s final captures serve as this follow-up’s baseline. All nine chunks and nine captures completed. The reported view and orbit 0/2/4/6 pairs were inspected: longer terraces and supported overhangs are visible, the square and approaches remain open, and roof joins remain closed in these views. Pixel-difference measurements cover these five site pairs and five gallery pairs; live grass and particles prevent treating them as terrain identity checks.

Reproduce with the preceding review’s commands, using `/tmp/town-expanded-site` as the site output and the current code. No source-pack rebake is required.
