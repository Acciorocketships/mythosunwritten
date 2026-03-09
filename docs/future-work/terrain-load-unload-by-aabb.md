# Terrain load/unload by player AABB

**Goal:** Unload terrain that leaves an outer AABB around the player, and load it back when it re-enters a smaller (inner) AABB. The landscape is not regenerated—we only show/hide already-generated pieces so that leaving and returning yields the same terrain.

## Behaviour

- **Unload:** When a piece’s AABB leaves the outer AABB around the player (e.g. beyond `RENDER_RANGE` or a configurable unload radius), remove it from the scene tree and mark it as unloaded. Do not delete its definition or position; keep it in a “all pieces” store.
- **Load:** When a piece’s AABB re-enters the inner AABB (smaller than the unload boundary), re-add it to the scene tree from the stored data so it appears exactly as before.
- **Determinism:** No re-rolling or re-sampling. Same seed and same generation order imply identical terrain when revisiting an area.

## Implementation sketch

- **Two indexes:** Keep a terrain index (or equivalent) for **loaded pieces only** (what’s in the scene tree and used for overlap/culling), and a separate store for **all generated pieces** (loaded + unloaded), keyed so we can find pieces by AABB/position.
- **Queries:** Use “query inside AABB” to find pieces that should be loaded (inside inner AABB but not yet loaded). Use “query outside AABB” (or “pieces in all-pieces but not in loaded”) to find pieces that are outside the outer AABB and should be unloaded.
- **Efficient updates:** Each frame (or on a timer), compute player AABB, run the two queries, unload pieces that are outside the outer AABB and load pieces that are inside the inner AABB. Avoid regenerating; only add/remove nodes and update the loaded index.

## Considerations

- **PositionIndex / TerrainIndex:** May need to support “query inside AABB” and “query outside AABB” (or equivalent) and to maintain the loaded-vs-all split without duplicating all logic.
- **Sockets:** Unloaded pieces should not be in the expansion queue or adjacency checks; the generator only expands from loaded sockets. When loading back, do not re-enqueue those sockets for expansion (they were already expanded in the past).
- **Collision / culling:** Loaded index drives what’s in the scene; unloaded pieces are not visible and do not collide.
