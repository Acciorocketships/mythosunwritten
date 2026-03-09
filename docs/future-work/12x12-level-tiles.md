# 12×12 level tiles for steeper hills

**Goal:** Add 12×12 level tiles in addition to 24×24 so we can have steeper hills.

- Introduce level module variants at 12×12 size (same tier/socket semantics as existing level tiles).
- Ensure library, tag rules, and `LevelEdgeRule` support 12×12 level pieces (sizes, adjacency, edge variants).
- Tune sampling/weights so 12×12 level tiles appear where appropriate to create steeper elevation changes.
