# Cliff Variant Completion Design

Date: 2026-05-24

## Background

The terrain system has 15 distinct **level-tile** variants that together cover every possible pattern of neighboring level-vs-non-level edges and inner-corner notches. The matching **cliff-tile** library only has 4 visual variants today (`CliffSide`, `CliffOuterCorner`, `CliffInnerCorner`, `CliffInnerCornerDiag`) plus `cliff-interior` (which re-uses `GroundTile.tscn`).

Because cliff coverage is incomplete, [CliffEdgeRule.gd](../../../scripts/terrain/rules/CliffEdgeRule.gd) currently includes a `_recursively_validate_via_spawning` workaround that grows neighbor cliffs until each plateau collapses to one of the 4 supported shapes. The goal of this work is to add the missing 10 variants so every cliff configuration has a valid tile, mirroring the level-tile library 1-for-1.

This spec covers **scene authoring, registration, and rule wiring**. It does NOT remove the spawn workaround — once every config is valid, the workaround simply becomes a no-op.

## Goals

- One cliff tile per level pattern (15 total).
- New cliff scenes follow the **level orientation convention** (drops on -Z front, -X left; inner corners anchored at frontleft).
- Existing cliff scenes are re-oriented to match the level convention and renamed for consistency (`CliffOuterCorner` → `CliffCorner`, etc.).
- `CliffEdgeRule` knows about every variant and rotates to align.

## Non-goals

- Removing `_recursively_validate_via_spawning`.
- Changing the cliff-interior tile or its tag semantics.
- Touching `Hill_*.tscn` composite scenes.
- Re-tuning fill probabilities or the `CliffEdgeRule` ordering heuristics.

## Scene inventory

### Renames (3 files; orientation also flipped)

| Old | New |
|---|---|
| `terrain/scenes/CliffOuterCorner.tscn` | `terrain/scenes/CliffCorner.tscn` |
| `terrain/scenes/CliffInnerCorner.tscn` | `terrain/scenes/CliffInCorner.tscn` |
| `terrain/scenes/CliffInnerCornerDiag.tscn` | `terrain/scenes/CliffInCornerDiag.tscn` |

`CliffInCornerDiag` is symmetric under 180° rotation around Y, so its existing geometry is already canonical — only the file name changes.

### Reorient only (1 file)

- `terrain/scenes/CliffSide.tscn` — flip cliff wall from +Z back to -Z front.

### New scenes (10 files)

| File | Mirrors | Missing cardinals | Missing inner-corner diagonals |
|---|---|---|---|
| `CliffLine.tscn` | LevelLine | front, back | — |
| `CliffPeninsula.tscn` | LevelPeninsula | front, back, left | — |
| `CliffIsland.tscn` | LevelIsland | front, back, left, right | — |
| `CliffInCornerSide.tscn` | LevelInCornerSide | — | frontleft, backleft |
| `CliffInCornerThree.tscn` | LevelInCornerThree | — | frontleft, backleft, backright |
| `CliffInCornerAll.tscn` | LevelInCornerAll | — | frontleft, frontright, backleft, backright |
| `CliffInCornerEdge1.tscn` | LevelInCornerEdge1 | back | frontleft |
| `CliffInCornerEdge2.tscn` | LevelInCornerEdge2 | right | frontleft |
| `CliffInCornerEdgeBoth.tscn` | LevelInCornerEdgeBoth | back, right | frontleft |
| `CliffInCornerSideEdge.tscn` | LevelInCornerSideEdge | right | frontleft, backleft |

## Scene construction rules

Each cliff scene = its corresponding level scene's top geometry **+ vertical cliff walls below dropping edges**.

- **Cardinal drop edge**: row of `hill_top_h_side` (flat-top side) along the edge, with `hill_cliff_tall_h_side` at y=-4 directly below each.
- **Outer corner (two adjacent cardinal drops meeting)**: `hill_top_i_outer_corner` at the corner, with `hill_cliff_tall_i_outer_corner` at y=-4 below.
- **Inner corner notch**: `hill_top_a_inner_corner` at the diagonal position (matches level scene), with `hill_cliff_tall_i_inner_corner` at y=-4 below.
- **Interior fill**: `hill_top_e_center` scaled and positioned to fill any remaining top surface (same pattern as the level scenes).
- **Sockets**: identical to the existing cliff scenes — cardinals at y=0 ±12, diagonals at y=0 ±12 ±12, `bottom` at y=-4, `topcenter` at origin.

The top geometry of a cliff scene differs from the matching level scene in **only one way**: cardinal drop edges and outer corners use the `_h_`/`_i_` variants (vertical-edge / vertical-corner tops) instead of the `_b_`/`_a_outer_corner` variants (sloped tops). Inner corners use the same `_a_inner_corner` mesh as the level scene because the concave curve reads naturally above a wrap-around cliff wall.

## Code changes

### [scripts/terrain/TerrainModuleDefinitions.gd](../../../scripts/terrain/TerrainModuleDefinitions.gd)

- Update existing functions to reference the new scene paths:
  - `load_cliff_edge_tile` → `CliffSide.tscn`, tag `cliff-side` (was `cliff-edge`).
  - `load_cliff_outer_corner_tile` → `CliffCorner.tscn`, tag `cliff-corner` (was `cliff-outer-corner`). Rename function to `load_cliff_corner_tile`.
  - `load_cliff_inner_corner_tile` → `CliffInCorner.tscn` (tag unchanged: `cliff-inner-corner`).
  - `load_cliff_inner_corner_diag_tile` → `CliffInCornerDiag.tscn` (tag unchanged: `cliff-inner-corner-diag`).
- Add 10 new functions following the same `_build_cliff_tile(path, tags)` pattern. Each tag list follows the form `["cliff", "<variant-tag>", "24x24x4"]`.

### [scripts/terrain/TerrainModuleLibrary.gd](../../../scripts/terrain/TerrainModuleLibrary.gd)

- Append the 10 new modules in `load_terrain_modules()` alongside the existing cliff registrations.
- Update the renamed call site (`load_cliff_outer_corner_tile` → `load_cliff_corner_tile`).

### [scripts/terrain/rules/CliffEdgeRule.gd](../../../scripts/terrain/rules/CliffEdgeRule.gd)

- Replace `CANONICAL_MISSING_BY_TAG` with the level-orientation entries below.
- Extend `CLIFF_TAG_ORDER` so the most-constrained patterns are matched first.
- Extend `_get_module_for_cliff_tag` to map every variant tag to its module.

```gdscript
const CANONICAL_MISSING_BY_TAG: Dictionary[String, Array] = {
    "cliff-side":                   ["front"],
    "cliff-corner":                 ["front", "left"],
    "cliff-line":                   ["front", "back"],
    "cliff-peninsula":              ["front", "back", "left"],
    "cliff-island":                 ["front", "back", "left", "right"],
    "cliff-inner-corner":           ["frontleft"],
    "cliff-inner-corner-diag":      ["frontleft", "backright"],
    "cliff-inner-corner-side":      ["frontleft", "backleft"],
    "cliff-inner-corner-three":     ["frontleft", "backleft", "backright"],
    "cliff-inner-corner-all":       ["frontleft", "frontright", "backleft", "backright"],
    "cliff-inner-corner-edge1":     ["back", "frontleft"],
    "cliff-inner-corner-edge2":     ["right", "frontleft"],
    "cliff-inner-corner-edge-both": ["back", "right", "frontleft"],
    "cliff-inner-corner-side-edge": ["right", "frontleft", "backleft"],
}
```

`CLIFF_TAG_ORDER` rule: more missing sockets first; among ties, hybrids (cardinal + diagonal) before pure-cardinal or pure-diagonal. A working order:

1. `cliff-island`
2. `cliff-inner-corner-all`
3. `cliff-inner-corner-edge-both`
4. `cliff-inner-corner-side-edge`
5. `cliff-inner-corner-three`
6. `cliff-peninsula`
7. `cliff-inner-corner-edge1`
8. `cliff-inner-corner-edge2`
9. `cliff-inner-corner-diag`
10. `cliff-inner-corner-side`
11. `cliff-line`
12. `cliff-corner`
13. `cliff-inner-corner`
14. `cliff-side`

## Migration notes

- Scene renames preserve `uid://…` headers, so any uid references stay valid.
- `create_24x24x4_test_piece` uses `CliffSide.tscn` for its socket layout — sockets stay unchanged after reorient, so the test piece is unaffected.
- Tag renames (`cliff-edge` → `cliff-side`, `cliff-outer-corner` → `cliff-corner`) propagate through `CliffEdgeRule` and any tests that filter by tag.
- The currently-modified `scripts/terrain/TerrainGenerator.gd` and `tests/test_terrain_generator.gd` aren't directly affected by the scene/tag changes.

## Out of scope (deliberate)

- Removing `_recursively_validate_via_spawning` from `CliffEdgeRule`. With every config now valid the loop will exit on the first check, so it costs nothing and provides defense-in-depth.
- Authoring new GLTF source meshes. Every new scene composes existing pieces from `terrain/gltf/`.
- Adjustments to `level-stack-*` tile variants. Cliffs are physical (4 units tall walls); the stack variants are top-only at the second-storey of a level plateau and aren't affected.
