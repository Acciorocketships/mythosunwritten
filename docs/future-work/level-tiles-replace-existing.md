# Restore replace_existing for level tiles

**Goal:** Add back `replace_existing` for level tiles (previously present, currently not there).

- Re-enable `replace_existing` on level tile module definitions where desired (e.g. center/stack variants).
- Ensure `TerrainGenerator.add_piece` and overlap/placement logic correctly handle level tiles with `replace_existing` (remove overlapping non-ground before placing).
- Verify no regressions with level stacking and edge retile behaviour.
