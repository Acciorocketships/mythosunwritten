# Cliff Variant Completion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Author 10 new cliff-tile variants + reorient/rename the existing 3 cliff-corner scenes, then update the registration and rule code so every level-tile pattern has a matching cliff-tile pattern at the level-orientation convention (-Z front, -X left).

**Architecture:** Each new cliff scene is a 1:1 copy of its matching level scene's top geometry, with `hill_top_b_side` → `hill_top_h_side` (vertical-edge top), `hill_top_a_outer_corner` → `hill_top_i_outer_corner` (vertical-corner top), `hill_top_a_inner_corner` left as-is, plus a `hill_cliff_tall_*` wall placed at y=-4 below every drop-edge piece. Sockets follow the existing cliff layout (cardinals at y=0 ±12, diagonals at y=0 ±12 ±12, bottom at y=-4, topcenter at origin).

**Tech Stack:** Godot 4, GDScript, GUT test framework.

**Spec:** [docs/superpowers/specs/2026-05-24-cliff-variant-completion-design.md](../specs/2026-05-24-cliff-variant-completion-design.md)

---

## Reference: Construction Conventions

These rules apply to **every** cliff scene authored in this plan. Hold them in mind while writing tasks.

**Asset uids (`ext_resource`):**

| Mesh | uid |
|---|---|
| `hill_top_e_center_color_12.tscn` | `uid://bnpt5wxld3xvq` |
| `hill_top_b_side_color_12.tscn` | `uid://d26h5651ssk36` |
| `hill_top_h_side_color_12.tscn` | `uid://72nb7fb13apc` |
| `hill_top_a_inner_corner_color_12.tscn` | `uid://begwnakrt5py5` |
| `hill_top_a_outer_corner_color_12.tscn` | `uid://bknoepwfsrkrk` |
| `hill_top_i_outer_corner_color_12.tscn` | `uid://dlrq6d5kq6380` |
| `hill_cliff_tall_h_side_color_12.tscn` | `uid://s7hlq6puc3vl` |
| `hill_cliff_tall_i_outer_corner_color_12.tscn` | `uid://dvihclfiaajr3` |
| `hill_cliff_tall_i_inner_corner_color_12.tscn` | `uid://b8esdhwy7hfi1` |

**Common rotation transforms** (rotation around +Y axis, applied as the basis of `Transform3D`):

| Rotation | Basis (col0, col1, col2) |
|---|---|
| 0° (identity) | `(1, 0, 0), (0, 1, 0), (0, 0, 1)` |
| 90° CCW (looking down +Y) | `(-4.371139e-08, 0, 1), (0, 1, 0), (-1, 0, -4.371139e-08)` |
| 180° | `(-1, 0, -8.742278e-08), (0, 1, 0), (8.742278e-08, 0, -1)` |
| 270° CCW (= 90° CW) | `(1.1924881e-08, 0, -1), (0, 1, 0), (1, 0, 1.1924881e-08)` |

**Edge piece layout (per cardinal drop):**
- For an **isolated** cardinal drop (no adjacent cardinal drops to form a corner): place 8 top pieces and 8 cliff wall pieces along the edge at the 8 positions `{-10.5, -7.5, -4.5, -1.5, 1.5, 4.5, 7.5, 10.5}` perpendicular to the drop direction.
- For a cardinal drop that **shares a corner** with another cardinal drop (forming an outer corner): the corner position is occupied by `hill_top_i_outer_corner` + `hill_cliff_tall_i_outer_corner`. Omit the top piece at that corner position. Place the cliff wall piece at the corner position **with `visible = false`** to match the existing CliffCorner pattern.

**Inner corner piece (per inner-corner notch):**
- 1 × `hill_top_a_inner_corner` (top) at the diagonal position (e.g., `(-10.5, 0, -10.5)` for frontleft).
- 1 × `hill_cliff_tall_i_inner_corner` (wall) at the same x,z but at y=-4.
- Both rotated so the concave curve and wall face into the tile correctly. Per-diagonal rotations:

| Diagonal | Position (x, z) | Rotation |
|---|---|---|
| frontleft | (-10.5, -10.5) | 0° |
| backleft  | (-10.5,  10.5) | 90° CCW |
| backright | ( 10.5,  10.5) | 180° |
| frontright | ( 10.5, -10.5) | 270° CCW |

**Outer corner piece (per outer corner = 2 adjacent cardinal drops meeting):**
- 1 × `hill_top_i_outer_corner` (top) at the corner position.
- 1 × `hill_cliff_tall_i_outer_corner` (wall) at the same x,z but at y=-4.
- Per-corner rotations:

| Corner | Position (x, z) | Rotation |
|---|---|---|
| frontleft | (-10.5, -10.5) | 0° |
| backleft  | (-10.5,  10.5) | 90° CCW |
| backright | ( 10.5,  10.5) | 180° |
| frontright | ( 10.5, -10.5) | 270° CCW |

**Center fill (`hill_top_e_center`):**
- Scale X to `0.875` if the right edge has a drop; scale X to `0.875` if the left edge has a drop; if both drop, scale X to `0.75`.
- Same for Z scaling with front/back drops.
- Position offset: shift the center toward the non-dropping side(s) by 1.5 units when only one side of an axis drops.
- The interior is then filled with additional small `hill_top_e_center` strips at the corner gaps when there are inner corner notches — this mirrors how the level scenes split the center mesh up (e.g., `LevelInCorner.tscn` uses 4 small `hill_top_e_center` instances along the right edge with notch).

**Socket layout — identical for all cliff scenes:**

```
[node name="Sockets" type="Node3D" parent="."]

[node name="front" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, -12)
[node name="back" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 12)
[node name="left" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -12, 0, 0)
[node name="right" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12, 0, 0)
[node name="frontleft" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -12, 0, -12)
[node name="frontright" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12, 0, -12)
[node name="backleft" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -12, 0, 12)
[node name="backright" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12, 0, 12)
[node name="bottom" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -4, 0)
[node name="topcenter" type="Marker3D" parent="Sockets"]
```

---

## File Structure

**Scenes (terrain/scenes/):**

- Reorient: `CliffSide.tscn` (drops at -Z instead of +Z).
- Rewrite at new path: `CliffCorner.tscn` (from `CliffOuterCorner.tscn`), `CliffInCorner.tscn` (from `CliffInnerCorner.tscn`), `CliffInCornerDiag.tscn` (from `CliffInnerCornerDiag.tscn`).
- Delete (after registrations updated): `CliffOuterCorner.tscn`, `CliffInnerCorner.tscn`, `CliffInnerCornerDiag.tscn`.
- New: `CliffLine.tscn`, `CliffPeninsula.tscn`, `CliffIsland.tscn`, `CliffInCornerSide.tscn`, `CliffInCornerThree.tscn`, `CliffInCornerAll.tscn`, `CliffInCornerEdge1.tscn`, `CliffInCornerEdge2.tscn`, `CliffInCornerEdgeBoth.tscn`, `CliffInCornerSideEdge.tscn`.

**Code:**

- `scripts/terrain/TerrainModuleDefinitions.gd` — rename `load_cliff_outer_corner_tile` → `load_cliff_corner_tile`, swap tag `cliff-edge` → `cliff-side` and `cliff-outer-corner` → `cliff-corner` (others unchanged), update scene paths, add 10 new `load_cliff_*_tile()` builders.
- `scripts/terrain/TerrainModuleLibrary.gd` — register the new modules.
- `scripts/terrain/rules/CliffEdgeRule.gd` — replace `CANONICAL_MISSING_BY_TAG`, extend `CLIFF_TAG_ORDER`, extend `_get_module_for_cliff_tag`.

**Tests:**

- `tests/test_terrain_generator.gd` — update tag strings and scene paths to match the new naming.
- `tests/test_terrain_module_library.gd` — update tag strings.

---

## Task 1: Rewrite CliffSide.tscn (reorient to -Z front)

**Files:**
- Modify: `terrain/scenes/CliffSide.tscn`

The existing `CliffSide.tscn` has its drop on +Z back; we rewrite it from scratch with the drop on -Z front. This mirrors `LevelSide.tscn` (which already drops on -Z front), with `hill_top_b_side` swapped for `hill_top_h_side`, the slope-edge sockets dropped (cliffs only use cardinal/diagonal sockets at y=0 plus bottom + topcenter), and a `hill_cliff_tall_h_side` wall placed below each top edge piece.

- [ ] **Step 1: Overwrite `terrain/scenes/CliffSide.tscn`**

```
[gd_scene load_steps=4 format=3 uid="uid://dfgnqefug3201"]

[ext_resource type="PackedScene" uid="uid://s7hlq6puc3vl" path="res://terrain/gltf/hill_cliff_tall_h_side_color_12.tscn" id="1_wall"]
[ext_resource type="PackedScene" uid="uid://72nb7fb13apc" path="res://terrain/gltf/hill_top_h_side_color_12.tscn" id="2_top"]
[ext_resource type="PackedScene" uid="uid://bnpt5wxld3xvq" path="res://terrain/gltf/hill_top_e_center_color_12.tscn" id="3_center"]

[node name="CliffSide" type="Node3D"]

[node name="Wall_1" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, 10.5, -4, -10.5)
[node name="Wall_2" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, 7.5, -4, -10.5)
[node name="Wall_3" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, 4.5, -4, -10.5)
[node name="Wall_4" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, 1.5, -4, -10.5)
[node name="Wall_5" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, -1.5, -4, -10.5)
[node name="Wall_6" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, -4.5, -4, -10.5)
[node name="Wall_7" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, -7.5, -4, -10.5)
[node name="Wall_8" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, -10.5, -4, -10.5)

[node name="Top_1" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, 10.5, 0, -10.5)
[node name="Top_2" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, 7.5, 0, -10.5)
[node name="Top_3" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, 4.5, 0, -10.5)
[node name="Top_4" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, 1.5, 0, -10.5)
[node name="Top_5" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, -1.5, 0, -10.5)
[node name="Top_6" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, -4.5, 0, -10.5)
[node name="Top_7" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, -7.5, 0, -10.5)
[node name="Top_8" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, -10.5, 0, -10.5)

[node name="Center" parent="." instance=ExtResource("3_center")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 0.875, 0, 0, 1.5)

[node name="Sockets" type="Node3D" parent="."]

[node name="front" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, -12)
[node name="back" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 12)
[node name="left" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -12, 0, 0)
[node name="right" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12, 0, 0)
[node name="frontleft" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -12, 0, -12)
[node name="frontright" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12, 0, -12)
[node name="backleft" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -12, 0, 12)
[node name="backright" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12, 0, 12)
[node name="bottom" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -4, 0)
[node name="topcenter" type="Marker3D" parent="Sockets"]
```

- [ ] **Step 2: Commit**

```bash
git add terrain/scenes/CliffSide.tscn
git commit -m "feat(terrain): reorient CliffSide drop to -Z front"
```

---

## Task 2: Create CliffCorner.tscn (rename + reorient from CliffOuterCorner)

**Files:**
- Create: `terrain/scenes/CliffCorner.tscn`

Drops on **front (-Z)** and **left (-X)**, with the outer corner at frontleft. Mirrors `LevelCorner.tscn` with the b→h, a_outer→i_outer swaps and walls below.

- [ ] **Step 1: Create `terrain/scenes/CliffCorner.tscn`**

Use this exact content. (The wall pieces at the frontleft corner position — Wall_Front_8 at x=-10.5 and Wall_Left_8 at z=-10.5 — are marked `visible = false` because they are overlapped by `CornerWall`. This matches the existing CliffOuterCorner pattern.)

```
[gd_scene load_steps=6 format=3 uid="uid://dcu2doob1bio8"]

[ext_resource type="PackedScene" uid="uid://s7hlq6puc3vl" path="res://terrain/gltf/hill_cliff_tall_h_side_color_12.tscn" id="1_wall"]
[ext_resource type="PackedScene" uid="uid://72nb7fb13apc" path="res://terrain/gltf/hill_top_h_side_color_12.tscn" id="2_top"]
[ext_resource type="PackedScene" uid="uid://bnpt5wxld3xvq" path="res://terrain/gltf/hill_top_e_center_color_12.tscn" id="3_center"]
[ext_resource type="PackedScene" uid="uid://dlrq6d5kq6380" path="res://terrain/gltf/hill_top_i_outer_corner_color_12.tscn" id="4_corner_top"]
[ext_resource type="PackedScene" uid="uid://dvihclfiaajr3" path="res://terrain/gltf/hill_cliff_tall_i_outer_corner_color_12.tscn" id="5_corner_wall"]

[node name="CliffCorner" type="Node3D"]

[node name="Wall_Front_1" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, 10.5, -4, -10.5)
[node name="Wall_Front_2" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, 7.5, -4, -10.5)
[node name="Wall_Front_3" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, 4.5, -4, -10.5)
[node name="Wall_Front_4" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, 1.5, -4, -10.5)
[node name="Wall_Front_5" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, -1.5, -4, -10.5)
[node name="Wall_Front_6" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, -4.5, -4, -10.5)
[node name="Wall_Front_7" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, -7.5, -4, -10.5)
[node name="Wall_Front_8" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, -10.5, -4, -10.5)
visible = false

[node name="Wall_Left_1" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1.1924881e-08, 0, -1, 0, 1, 0, 1, 0, 1.1924881e-08, -10.5, -4, 10.5)
[node name="Wall_Left_2" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1.1924881e-08, 0, -1, 0, 1, 0, 1, 0, 1.1924881e-08, -10.5, -4, 7.5)
[node name="Wall_Left_3" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1.1924881e-08, 0, -1, 0, 1, 0, 1, 0, 1.1924881e-08, -10.5, -4, 4.5)
[node name="Wall_Left_4" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1.1924881e-08, 0, -1, 0, 1, 0, 1, 0, 1.1924881e-08, -10.5, -4, 1.5)
[node name="Wall_Left_5" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1.1924881e-08, 0, -1, 0, 1, 0, 1, 0, 1.1924881e-08, -10.5, -4, -1.5)
[node name="Wall_Left_6" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1.1924881e-08, 0, -1, 0, 1, 0, 1, 0, 1.1924881e-08, -10.5, -4, -4.5)
[node name="Wall_Left_7" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1.1924881e-08, 0, -1, 0, 1, 0, 1, 0, 1.1924881e-08, -10.5, -4, -7.5)
[node name="Wall_Left_8" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1.1924881e-08, 0, -1, 0, 1, 0, 1, 0, 1.1924881e-08, -10.5, -4, -10.5)
visible = false

[node name="CornerWall" parent="." instance=ExtResource("5_corner_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -10.5, -4, -10.5)

[node name="Top_Front_1" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, 10.5, 0, -10.5)
[node name="Top_Front_2" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, 7.5, 0, -10.5)
[node name="Top_Front_3" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, 4.5, 0, -10.5)
[node name="Top_Front_4" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, 1.5, 0, -10.5)
[node name="Top_Front_5" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, -1.5, 0, -10.5)
[node name="Top_Front_6" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, -4.5, 0, -10.5)
[node name="Top_Front_7" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, -7.5, 0, -10.5)

[node name="Top_Left_1" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1.1924881e-08, 0, -1, 0, 1, 0, 1, 0, 1.1924881e-08, -10.5, 0, 10.5)
[node name="Top_Left_2" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1.1924881e-08, 0, -1, 0, 1, 0, 1, 0, 1.1924881e-08, -10.5, 0, 7.5)
[node name="Top_Left_3" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1.1924881e-08, 0, -1, 0, 1, 0, 1, 0, 1.1924881e-08, -10.5, 0, 4.5)
[node name="Top_Left_4" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1.1924881e-08, 0, -1, 0, 1, 0, 1, 0, 1.1924881e-08, -10.5, 0, 1.5)
[node name="Top_Left_5" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1.1924881e-08, 0, -1, 0, 1, 0, 1, 0, 1.1924881e-08, -10.5, 0, -1.5)
[node name="Top_Left_6" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1.1924881e-08, 0, -1, 0, 1, 0, 1, 0, 1.1924881e-08, -10.5, 0, -4.5)
[node name="Top_Left_7" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1.1924881e-08, 0, -1, 0, 1, 0, 1, 0, 1.1924881e-08, -10.5, 0, -7.5)

[node name="CornerTop" parent="." instance=ExtResource("4_corner_top")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -10.5, 0, -10.5)

[node name="Center" parent="." instance=ExtResource("3_center")]
transform = Transform3D(0.875, 0, 0, 0, 1, 0, 0, 0, 0.875, 1.5, 0, 1.5)

[node name="Sockets" type="Node3D" parent="."]

[node name="front" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, -12)
[node name="back" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 12)
[node name="left" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -12, 0, 0)
[node name="right" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12, 0, 0)
[node name="frontleft" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -12, 0, -12)
[node name="frontright" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12, 0, -12)
[node name="backleft" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -12, 0, 12)
[node name="backright" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12, 0, 12)
[node name="bottom" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -4, 0)
[node name="topcenter" type="Marker3D" parent="Sockets"]
```

- [ ] **Step 2: Commit**

```bash
git add terrain/scenes/CliffCorner.tscn
git commit -m "feat(terrain): add CliffCorner.tscn (replaces CliffOuterCorner)"
```

---

## Task 3: Create CliffInCorner.tscn (rename + reorient from CliffInnerCorner)

**Files:**
- Create: `terrain/scenes/CliffInCorner.tscn`

Single inner-corner notch at frontleft (matches LevelInCorner.tscn).

- [ ] **Step 1: Create the file**

```
[gd_scene load_steps=4 format=3 uid="uid://qfy86l82dnch"]

[ext_resource type="PackedScene" uid="uid://b8esdhwy7hfi1" path="res://terrain/gltf/hill_cliff_tall_i_inner_corner_color_12.tscn" id="1_wall"]
[ext_resource type="PackedScene" uid="uid://bnpt5wxld3xvq" path="res://terrain/gltf/hill_top_e_center_color_12.tscn" id="2_center"]
[ext_resource type="PackedScene" uid="uid://begwnakrt5py5" path="res://terrain/gltf/hill_top_a_inner_corner_color_12.tscn" id="3_inner_top"]

[node name="CliffInCorner" type="Node3D"]

[node name="InnerWall_FL" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -10.5, -4, -10.5)

[node name="InnerTop_FL" parent="." instance=ExtResource("3_inner_top")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -10.5, 0, -10.5)

[node name="Center" parent="." instance=ExtResource("2_center")]
transform = Transform3D(0.9, 0, 0, 0, 1, 0, 0, 0, 0.9, 1.2, 0, 1.2)
[node name="Center_Strip_Left" parent="." instance=ExtResource("2_center")]
transform = Transform3D(0.1, 0, 0, 0, 1, 0, 0, 0, 0.9, -10.8, 0, 1.2)
[node name="Center_Strip_Front" parent="." instance=ExtResource("2_center")]
transform = Transform3D(0.9, 0, 0, 0, 1, 0, 0, 0, 0.1, 1.2, 0, -10.8)

[node name="Sockets" type="Node3D" parent="."]

[node name="front" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, -12)
[node name="back" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 12)
[node name="left" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -12, 0, 0)
[node name="right" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12, 0, 0)
[node name="frontleft" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -12, 0, -12)
[node name="frontright" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12, 0, -12)
[node name="backleft" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -12, 0, 12)
[node name="backright" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12, 0, 12)
[node name="bottom" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -4, 0)
[node name="topcenter" type="Marker3D" parent="Sockets"]
```

- [ ] **Step 2: Commit**

```bash
git add terrain/scenes/CliffInCorner.tscn
git commit -m "feat(terrain): add CliffInCorner.tscn (replaces CliffInnerCorner)"
```

---

## Task 4: Create CliffInCornerDiag.tscn (rename from CliffInnerCornerDiag)

**Files:**
- Create: `terrain/scenes/CliffInCornerDiag.tscn`

Two inner-corner notches on the frontleft / backright diagonals (matches LevelInCornerDiag.tscn). Symmetric under 180° rotation around Y so the geometry is the same as the existing CliffInnerCornerDiag.tscn — only the file name changes.

- [ ] **Step 1: Create the file**

```
[gd_scene load_steps=4 format=3 uid="uid://bl2grwmyuxwoj"]

[ext_resource type="PackedScene" uid="uid://b8esdhwy7hfi1" path="res://terrain/gltf/hill_cliff_tall_i_inner_corner_color_12.tscn" id="1_wall"]
[ext_resource type="PackedScene" uid="uid://bnpt5wxld3xvq" path="res://terrain/gltf/hill_top_e_center_color_12.tscn" id="2_center"]
[ext_resource type="PackedScene" uid="uid://begwnakrt5py5" path="res://terrain/gltf/hill_top_a_inner_corner_color_12.tscn" id="3_inner_top"]

[node name="CliffInCornerDiag" type="Node3D"]

[node name="InnerWall_FL" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -10.5, -4, -10.5)
[node name="InnerWall_BR" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, 10.5, -4, 10.5)

[node name="InnerTop_FL" parent="." instance=ExtResource("3_inner_top")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -10.5, 0, -10.5)
[node name="InnerTop_BR" parent="." instance=ExtResource("3_inner_top")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, 10.5, 0, 10.5)

[node name="Center" parent="." instance=ExtResource("2_center")]
transform = Transform3D(0.8, 0, 0, 0, 1, 0, 0, 0, 0.8, 0, 0, 0)
[node name="Center_Strip_Left" parent="." instance=ExtResource("2_center")]
transform = Transform3D(0.1, 0, 0, 0, 1, 0, 0, 0, 0.8, -10.8, 0, 0)
[node name="Center_Strip_Right" parent="." instance=ExtResource("2_center")]
transform = Transform3D(0.1, 0, 0, 0, 1, 0, 0, 0, 0.8, 10.8, 0, 0)
[node name="Center_Strip_Front" parent="." instance=ExtResource("2_center")]
transform = Transform3D(0.8, 0, 0, 0, 1, 0, 0, 0, 0.1, 0, 0, -10.8)
[node name="Center_Strip_Back" parent="." instance=ExtResource("2_center")]
transform = Transform3D(0.8, 0, 0, 0, 1, 0, 0, 0, 0.1, 0, 0, 10.8)

[node name="Sockets" type="Node3D" parent="."]

[node name="front" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, -12)
[node name="back" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 12)
[node name="left" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -12, 0, 0)
[node name="right" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12, 0, 0)
[node name="frontleft" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -12, 0, -12)
[node name="frontright" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12, 0, -12)
[node name="backleft" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -12, 0, 12)
[node name="backright" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12, 0, 12)
[node name="bottom" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -4, 0)
[node name="topcenter" type="Marker3D" parent="Sockets"]
```

- [ ] **Step 2: Commit**

```bash
git add terrain/scenes/CliffInCornerDiag.tscn
git commit -m "feat(terrain): add CliffInCornerDiag.tscn (replaces CliffInnerCornerDiag)"
```

---

## Task 5: Create CliffLine.tscn (drops on front + back, opposite cardinals)

**Files:**
- Create: `terrain/scenes/CliffLine.tscn`

Two opposite cardinal drops with no corners (since neither pair of drops is adjacent). Mirrors LevelLine.tscn.

- [ ] **Step 1: Create the file**

```
[gd_scene load_steps=4 format=3]

[ext_resource type="PackedScene" uid="uid://s7hlq6puc3vl" path="res://terrain/gltf/hill_cliff_tall_h_side_color_12.tscn" id="1_wall"]
[ext_resource type="PackedScene" uid="uid://72nb7fb13apc" path="res://terrain/gltf/hill_top_h_side_color_12.tscn" id="2_top"]
[ext_resource type="PackedScene" uid="uid://bnpt5wxld3xvq" path="res://terrain/gltf/hill_top_e_center_color_12.tscn" id="3_center"]

[node name="CliffLine" type="Node3D"]

[node name="Wall_Front_1" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, 10.5, -4, -10.5)
[node name="Wall_Front_2" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, 7.5, -4, -10.5)
[node name="Wall_Front_3" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, 4.5, -4, -10.5)
[node name="Wall_Front_4" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, 1.5, -4, -10.5)
[node name="Wall_Front_5" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, -1.5, -4, -10.5)
[node name="Wall_Front_6" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, -4.5, -4, -10.5)
[node name="Wall_Front_7" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, -7.5, -4, -10.5)
[node name="Wall_Front_8" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, -10.5, -4, -10.5)

[node name="Wall_Back_1" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 10.5, -4, 10.5)
[node name="Wall_Back_2" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 7.5, -4, 10.5)
[node name="Wall_Back_3" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 4.5, -4, 10.5)
[node name="Wall_Back_4" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 1.5, -4, 10.5)
[node name="Wall_Back_5" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -1.5, -4, 10.5)
[node name="Wall_Back_6" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -4.5, -4, 10.5)
[node name="Wall_Back_7" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -7.5, -4, 10.5)
[node name="Wall_Back_8" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -10.5, -4, 10.5)

[node name="Top_Front_1" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, 10.5, 0, -10.5)
[node name="Top_Front_2" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, 7.5, 0, -10.5)
[node name="Top_Front_3" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, 4.5, 0, -10.5)
[node name="Top_Front_4" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, 1.5, 0, -10.5)
[node name="Top_Front_5" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, -1.5, 0, -10.5)
[node name="Top_Front_6" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, -4.5, 0, -10.5)
[node name="Top_Front_7" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, -7.5, 0, -10.5)
[node name="Top_Front_8" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, -10.5, 0, -10.5)

[node name="Top_Back_1" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 10.5, 0, 10.5)
[node name="Top_Back_2" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 7.5, 0, 10.5)
[node name="Top_Back_3" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 4.5, 0, 10.5)
[node name="Top_Back_4" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 1.5, 0, 10.5)
[node name="Top_Back_5" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -1.5, 0, 10.5)
[node name="Top_Back_6" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -4.5, 0, 10.5)
[node name="Top_Back_7" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -7.5, 0, 10.5)
[node name="Top_Back_8" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -10.5, 0, 10.5)

[node name="Center" parent="." instance=ExtResource("3_center")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 0.75, 0, 0, 0)

[node name="Sockets" type="Node3D" parent="."]

[node name="front" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, -12)
[node name="back" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 12)
[node name="left" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -12, 0, 0)
[node name="right" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12, 0, 0)
[node name="frontleft" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -12, 0, -12)
[node name="frontright" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12, 0, -12)
[node name="backleft" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -12, 0, 12)
[node name="backright" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12, 0, 12)
[node name="bottom" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -4, 0)
[node name="topcenter" type="Marker3D" parent="Sockets"]
```

- [ ] **Step 2: Commit**

```bash
git add terrain/scenes/CliffLine.tscn
git commit -m "feat(terrain): add CliffLine variant"
```

---

## Task 6: Create CliffPeninsula.tscn (drops on front + left + back; level only on right)

**Files:**
- Create: `terrain/scenes/CliffPeninsula.tscn`

Three cardinal drops forming an outer corner at frontleft AND another at backleft. Mirrors LevelPeninsula.tscn.

- [ ] **Step 1: Create the file**

```
[gd_scene load_steps=6 format=3]

[ext_resource type="PackedScene" uid="uid://s7hlq6puc3vl" path="res://terrain/gltf/hill_cliff_tall_h_side_color_12.tscn" id="1_wall"]
[ext_resource type="PackedScene" uid="uid://72nb7fb13apc" path="res://terrain/gltf/hill_top_h_side_color_12.tscn" id="2_top"]
[ext_resource type="PackedScene" uid="uid://bnpt5wxld3xvq" path="res://terrain/gltf/hill_top_e_center_color_12.tscn" id="3_center"]
[ext_resource type="PackedScene" uid="uid://dlrq6d5kq6380" path="res://terrain/gltf/hill_top_i_outer_corner_color_12.tscn" id="4_corner_top"]
[ext_resource type="PackedScene" uid="uid://dvihclfiaajr3" path="res://terrain/gltf/hill_cliff_tall_i_outer_corner_color_12.tscn" id="5_corner_wall"]

[node name="CliffPeninsula" type="Node3D"]

[node name="Wall_Front_1" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, 10.5, -4, -10.5)
[node name="Wall_Front_2" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, 7.5, -4, -10.5)
[node name="Wall_Front_3" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, 4.5, -4, -10.5)
[node name="Wall_Front_4" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, 1.5, -4, -10.5)
[node name="Wall_Front_5" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, -1.5, -4, -10.5)
[node name="Wall_Front_6" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, -4.5, -4, -10.5)
[node name="Wall_Front_7" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, -7.5, -4, -10.5)
[node name="Wall_Front_8" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, -10.5, -4, -10.5)
visible = false

[node name="Wall_Left_1" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1.1924881e-08, 0, -1, 0, 1, 0, 1, 0, 1.1924881e-08, -10.5, -4, 10.5)
visible = false
[node name="Wall_Left_2" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1.1924881e-08, 0, -1, 0, 1, 0, 1, 0, 1.1924881e-08, -10.5, -4, 7.5)
[node name="Wall_Left_3" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1.1924881e-08, 0, -1, 0, 1, 0, 1, 0, 1.1924881e-08, -10.5, -4, 4.5)
[node name="Wall_Left_4" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1.1924881e-08, 0, -1, 0, 1, 0, 1, 0, 1.1924881e-08, -10.5, -4, 1.5)
[node name="Wall_Left_5" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1.1924881e-08, 0, -1, 0, 1, 0, 1, 0, 1.1924881e-08, -10.5, -4, -1.5)
[node name="Wall_Left_6" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1.1924881e-08, 0, -1, 0, 1, 0, 1, 0, 1.1924881e-08, -10.5, -4, -4.5)
[node name="Wall_Left_7" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1.1924881e-08, 0, -1, 0, 1, 0, 1, 0, 1.1924881e-08, -10.5, -4, -7.5)
[node name="Wall_Left_8" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1.1924881e-08, 0, -1, 0, 1, 0, 1, 0, 1.1924881e-08, -10.5, -4, -10.5)
visible = false

[node name="Wall_Back_1" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 10.5, -4, 10.5)
[node name="Wall_Back_2" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 7.5, -4, 10.5)
[node name="Wall_Back_3" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 4.5, -4, 10.5)
[node name="Wall_Back_4" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 1.5, -4, 10.5)
[node name="Wall_Back_5" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -1.5, -4, 10.5)
[node name="Wall_Back_6" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -4.5, -4, 10.5)
[node name="Wall_Back_7" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -7.5, -4, 10.5)
[node name="Wall_Back_8" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -10.5, -4, 10.5)
visible = false

[node name="CornerWall_FL" parent="." instance=ExtResource("5_corner_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -10.5, -4, -10.5)
[node name="CornerWall_BL" parent="." instance=ExtResource("5_corner_wall")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, -10.5, -4, 10.5)

[node name="Top_Front_1" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, 10.5, 0, -10.5)
[node name="Top_Front_2" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, 7.5, 0, -10.5)
[node name="Top_Front_3" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, 4.5, 0, -10.5)
[node name="Top_Front_4" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, 1.5, 0, -10.5)
[node name="Top_Front_5" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, -1.5, 0, -10.5)
[node name="Top_Front_6" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, -4.5, 0, -10.5)
[node name="Top_Front_7" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, -7.5, 0, -10.5)

[node name="Top_Left_2" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1.1924881e-08, 0, -1, 0, 1, 0, 1, 0, 1.1924881e-08, -10.5, 0, 7.5)
[node name="Top_Left_3" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1.1924881e-08, 0, -1, 0, 1, 0, 1, 0, 1.1924881e-08, -10.5, 0, 4.5)
[node name="Top_Left_4" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1.1924881e-08, 0, -1, 0, 1, 0, 1, 0, 1.1924881e-08, -10.5, 0, 1.5)
[node name="Top_Left_5" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1.1924881e-08, 0, -1, 0, 1, 0, 1, 0, 1.1924881e-08, -10.5, 0, -1.5)
[node name="Top_Left_6" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1.1924881e-08, 0, -1, 0, 1, 0, 1, 0, 1.1924881e-08, -10.5, 0, -4.5)
[node name="Top_Left_7" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1.1924881e-08, 0, -1, 0, 1, 0, 1, 0, 1.1924881e-08, -10.5, 0, -7.5)

[node name="Top_Back_1" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 10.5, 0, 10.5)
[node name="Top_Back_2" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 7.5, 0, 10.5)
[node name="Top_Back_3" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 4.5, 0, 10.5)
[node name="Top_Back_4" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 1.5, 0, 10.5)
[node name="Top_Back_5" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -1.5, 0, 10.5)
[node name="Top_Back_6" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -4.5, 0, 10.5)
[node name="Top_Back_7" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -7.5, 0, 10.5)

[node name="CornerTop_FL" parent="." instance=ExtResource("4_corner_top")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -10.5, 0, -10.5)
[node name="CornerTop_BL" parent="." instance=ExtResource("4_corner_top")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, -10.5, 0, 10.5)

[node name="Center" parent="." instance=ExtResource("3_center")]
transform = Transform3D(0.875, 0, 0, 0, 1, 0, 0, 0, 0.75, 1.5, 0, 0)

[node name="Sockets" type="Node3D" parent="."]

[node name="front" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, -12)
[node name="back" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 12)
[node name="left" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -12, 0, 0)
[node name="right" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12, 0, 0)
[node name="frontleft" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -12, 0, -12)
[node name="frontright" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12, 0, -12)
[node name="backleft" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -12, 0, 12)
[node name="backright" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12, 0, 12)
[node name="bottom" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -4, 0)
[node name="topcenter" type="Marker3D" parent="Sockets"]
```

- [ ] **Step 2: Commit**

```bash
git add terrain/scenes/CliffPeninsula.tscn
git commit -m "feat(terrain): add CliffPeninsula variant"
```

---

## Task 7: Create CliffIsland.tscn (drops on all 4 cardinals)

**Files:**
- Create: `terrain/scenes/CliffIsland.tscn`

All four cardinals drop, outer corners at all four corners. Mirrors LevelIsland.tscn.

- [ ] **Step 1: Create the file**

```
[gd_scene load_steps=6 format=3]

[ext_resource type="PackedScene" uid="uid://s7hlq6puc3vl" path="res://terrain/gltf/hill_cliff_tall_h_side_color_12.tscn" id="1_wall"]
[ext_resource type="PackedScene" uid="uid://72nb7fb13apc" path="res://terrain/gltf/hill_top_h_side_color_12.tscn" id="2_top"]
[ext_resource type="PackedScene" uid="uid://bnpt5wxld3xvq" path="res://terrain/gltf/hill_top_e_center_color_12.tscn" id="3_center"]
[ext_resource type="PackedScene" uid="uid://dlrq6d5kq6380" path="res://terrain/gltf/hill_top_i_outer_corner_color_12.tscn" id="4_corner_top"]
[ext_resource type="PackedScene" uid="uid://dvihclfiaajr3" path="res://terrain/gltf/hill_cliff_tall_i_outer_corner_color_12.tscn" id="5_corner_wall"]

[node name="CliffIsland" type="Node3D"]

[node name="Wall_Front_1" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, 10.5, -4, -10.5)
visible = false
[node name="Wall_Front_2" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, 7.5, -4, -10.5)
[node name="Wall_Front_3" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, 4.5, -4, -10.5)
[node name="Wall_Front_4" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, 1.5, -4, -10.5)
[node name="Wall_Front_5" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, -1.5, -4, -10.5)
[node name="Wall_Front_6" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, -4.5, -4, -10.5)
[node name="Wall_Front_7" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, -7.5, -4, -10.5)
[node name="Wall_Front_8" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, -10.5, -4, -10.5)
visible = false

[node name="Wall_Right_1" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, -4, -10.5)
visible = false
[node name="Wall_Right_2" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, -4, -7.5)
[node name="Wall_Right_3" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, -4, -4.5)
[node name="Wall_Right_4" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, -4, -1.5)
[node name="Wall_Right_5" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, -4, 1.5)
[node name="Wall_Right_6" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, -4, 4.5)
[node name="Wall_Right_7" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, -4, 7.5)
[node name="Wall_Right_8" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, -4, 10.5)
visible = false

[node name="Wall_Back_1" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 10.5, -4, 10.5)
visible = false
[node name="Wall_Back_2" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 7.5, -4, 10.5)
[node name="Wall_Back_3" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 4.5, -4, 10.5)
[node name="Wall_Back_4" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 1.5, -4, 10.5)
[node name="Wall_Back_5" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -1.5, -4, 10.5)
[node name="Wall_Back_6" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -4.5, -4, 10.5)
[node name="Wall_Back_7" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -7.5, -4, 10.5)
[node name="Wall_Back_8" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -10.5, -4, 10.5)
visible = false

[node name="Wall_Left_1" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1.1924881e-08, 0, -1, 0, 1, 0, 1, 0, 1.1924881e-08, -10.5, -4, 10.5)
visible = false
[node name="Wall_Left_2" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1.1924881e-08, 0, -1, 0, 1, 0, 1, 0, 1.1924881e-08, -10.5, -4, 7.5)
[node name="Wall_Left_3" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1.1924881e-08, 0, -1, 0, 1, 0, 1, 0, 1.1924881e-08, -10.5, -4, 4.5)
[node name="Wall_Left_4" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1.1924881e-08, 0, -1, 0, 1, 0, 1, 0, 1.1924881e-08, -10.5, -4, 1.5)
[node name="Wall_Left_5" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1.1924881e-08, 0, -1, 0, 1, 0, 1, 0, 1.1924881e-08, -10.5, -4, -1.5)
[node name="Wall_Left_6" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1.1924881e-08, 0, -1, 0, 1, 0, 1, 0, 1.1924881e-08, -10.5, -4, -4.5)
[node name="Wall_Left_7" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1.1924881e-08, 0, -1, 0, 1, 0, 1, 0, 1.1924881e-08, -10.5, -4, -7.5)
[node name="Wall_Left_8" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1.1924881e-08, 0, -1, 0, 1, 0, 1, 0, 1.1924881e-08, -10.5, -4, -10.5)
visible = false

[node name="CornerWall_FL" parent="." instance=ExtResource("5_corner_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -10.5, -4, -10.5)
[node name="CornerWall_FR" parent="." instance=ExtResource("5_corner_wall")]
transform = Transform3D(1.1924881e-08, 0, -1, 0, 1, 0, 1, 0, 1.1924881e-08, 10.5, -4, -10.5)
[node name="CornerWall_BR" parent="." instance=ExtResource("5_corner_wall")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, 10.5, -4, 10.5)
[node name="CornerWall_BL" parent="." instance=ExtResource("5_corner_wall")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, -10.5, -4, 10.5)

[node name="Top_Front_2" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, 7.5, 0, -10.5)
[node name="Top_Front_3" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, 4.5, 0, -10.5)
[node name="Top_Front_4" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, 1.5, 0, -10.5)
[node name="Top_Front_5" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, -1.5, 0, -10.5)
[node name="Top_Front_6" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, -4.5, 0, -10.5)
[node name="Top_Front_7" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, -7.5, 0, -10.5)

[node name="Top_Right_2" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, 0, -7.5)
[node name="Top_Right_3" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, 0, -4.5)
[node name="Top_Right_4" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, 0, -1.5)
[node name="Top_Right_5" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, 0, 1.5)
[node name="Top_Right_6" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, 0, 4.5)
[node name="Top_Right_7" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, 0, 7.5)

[node name="Top_Back_2" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 7.5, 0, 10.5)
[node name="Top_Back_3" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 4.5, 0, 10.5)
[node name="Top_Back_4" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 1.5, 0, 10.5)
[node name="Top_Back_5" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -1.5, 0, 10.5)
[node name="Top_Back_6" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -4.5, 0, 10.5)
[node name="Top_Back_7" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -7.5, 0, 10.5)

[node name="Top_Left_2" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1.1924881e-08, 0, -1, 0, 1, 0, 1, 0, 1.1924881e-08, -10.5, 0, 7.5)
[node name="Top_Left_3" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1.1924881e-08, 0, -1, 0, 1, 0, 1, 0, 1.1924881e-08, -10.5, 0, 4.5)
[node name="Top_Left_4" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1.1924881e-08, 0, -1, 0, 1, 0, 1, 0, 1.1924881e-08, -10.5, 0, 1.5)
[node name="Top_Left_5" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1.1924881e-08, 0, -1, 0, 1, 0, 1, 0, 1.1924881e-08, -10.5, 0, -1.5)
[node name="Top_Left_6" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1.1924881e-08, 0, -1, 0, 1, 0, 1, 0, 1.1924881e-08, -10.5, 0, -4.5)
[node name="Top_Left_7" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1.1924881e-08, 0, -1, 0, 1, 0, 1, 0, 1.1924881e-08, -10.5, 0, -7.5)

[node name="CornerTop_FL" parent="." instance=ExtResource("4_corner_top")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -10.5, 0, -10.5)
[node name="CornerTop_FR" parent="." instance=ExtResource("4_corner_top")]
transform = Transform3D(1.1924881e-08, 0, -1, 0, 1, 0, 1, 0, 1.1924881e-08, 10.5, 0, -10.5)
[node name="CornerTop_BR" parent="." instance=ExtResource("4_corner_top")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, 10.5, 0, 10.5)
[node name="CornerTop_BL" parent="." instance=ExtResource("4_corner_top")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, -10.5, 0, 10.5)

[node name="Center" parent="." instance=ExtResource("3_center")]
transform = Transform3D(0.75, 0, 0, 0, 1, 0, 0, 0, 0.75, 0, 0, 0)

[node name="Sockets" type="Node3D" parent="."]

[node name="front" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, -12)
[node name="back" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 12)
[node name="left" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -12, 0, 0)
[node name="right" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12, 0, 0)
[node name="frontleft" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -12, 0, -12)
[node name="frontright" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12, 0, -12)
[node name="backleft" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -12, 0, 12)
[node name="backright" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12, 0, 12)
[node name="bottom" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -4, 0)
[node name="topcenter" type="Marker3D" parent="Sockets"]
```

- [ ] **Step 2: Commit**

```bash
git add terrain/scenes/CliffIsland.tscn
git commit -m "feat(terrain): add CliffIsland variant"
```

---

## Task 8: Create CliffInCornerSide.tscn (2 adjacent inner corners on left edge)

**Files:**
- Create: `terrain/scenes/CliffInCornerSide.tscn`

Inner-corner notches at frontleft and backleft (both on -X side). Mirrors LevelInCornerSide.tscn.

- [ ] **Step 1: Create the file**

```
[gd_scene load_steps=4 format=3]

[ext_resource type="PackedScene" uid="uid://b8esdhwy7hfi1" path="res://terrain/gltf/hill_cliff_tall_i_inner_corner_color_12.tscn" id="1_wall"]
[ext_resource type="PackedScene" uid="uid://bnpt5wxld3xvq" path="res://terrain/gltf/hill_top_e_center_color_12.tscn" id="2_center"]
[ext_resource type="PackedScene" uid="uid://begwnakrt5py5" path="res://terrain/gltf/hill_top_a_inner_corner_color_12.tscn" id="3_inner_top"]

[node name="CliffInCornerSide" type="Node3D"]

[node name="InnerWall_FL" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -10.5, -4, -10.5)
[node name="InnerWall_BL" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, -10.5, -4, 10.5)

[node name="InnerTop_FL" parent="." instance=ExtResource("3_inner_top")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -10.5, 0, -10.5)
[node name="InnerTop_BL" parent="." instance=ExtResource("3_inner_top")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, -10.5, 0, 10.5)

[node name="Center" parent="." instance=ExtResource("2_center")]
transform = Transform3D(0.9, 0, 0, 0, 1, 0, 0, 0, 0.875, 1.2, 0, 0)
[node name="Center_Strip_Left" parent="." instance=ExtResource("2_center")]
transform = Transform3D(0.1, 0, 0, 0, 1, 0, 0, 0, 0.75, -10.8, 0, 0)

[node name="Sockets" type="Node3D" parent="."]

[node name="front" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, -12)
[node name="back" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 12)
[node name="left" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -12, 0, 0)
[node name="right" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12, 0, 0)
[node name="frontleft" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -12, 0, -12)
[node name="frontright" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12, 0, -12)
[node name="backleft" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -12, 0, 12)
[node name="backright" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12, 0, 12)
[node name="bottom" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -4, 0)
[node name="topcenter" type="Marker3D" parent="Sockets"]
```

- [ ] **Step 2: Commit**

```bash
git add terrain/scenes/CliffInCornerSide.tscn
git commit -m "feat(terrain): add CliffInCornerSide variant"
```

---

## Task 9: Create CliffInCornerThree.tscn (3 inner corners: frontleft + backleft + backright)

**Files:**
- Create: `terrain/scenes/CliffInCornerThree.tscn`

Mirrors LevelInCornerThree.tscn.

- [ ] **Step 1: Create the file**

```
[gd_scene load_steps=4 format=3]

[ext_resource type="PackedScene" uid="uid://b8esdhwy7hfi1" path="res://terrain/gltf/hill_cliff_tall_i_inner_corner_color_12.tscn" id="1_wall"]
[ext_resource type="PackedScene" uid="uid://bnpt5wxld3xvq" path="res://terrain/gltf/hill_top_e_center_color_12.tscn" id="2_center"]
[ext_resource type="PackedScene" uid="uid://begwnakrt5py5" path="res://terrain/gltf/hill_top_a_inner_corner_color_12.tscn" id="3_inner_top"]

[node name="CliffInCornerThree" type="Node3D"]

[node name="InnerWall_FL" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -10.5, -4, -10.5)
[node name="InnerWall_BL" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, -10.5, -4, 10.5)
[node name="InnerWall_BR" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, 10.5, -4, 10.5)

[node name="InnerTop_FL" parent="." instance=ExtResource("3_inner_top")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -10.5, 0, -10.5)
[node name="InnerTop_BL" parent="." instance=ExtResource("3_inner_top")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, -10.5, 0, 10.5)
[node name="InnerTop_BR" parent="." instance=ExtResource("3_inner_top")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, 10.5, 0, 10.5)

[node name="Center" parent="." instance=ExtResource("2_center")]
transform = Transform3D(0.75, 0, 0, 0, 1, 0, 0, 0, 0.75, 0, 0, 0)
[node name="Center_Strip_Left" parent="." instance=ExtResource("2_center")]
transform = Transform3D(0.1, 0, 0, 0, 1, 0, 0, 0, 0.75, -10.8, 0, 0)
[node name="Center_Strip_Right" parent="." instance=ExtResource("2_center")]
transform = Transform3D(0.1, 0, 0, 0, 1, 0, 0, 0, 0.75, 10.8, 0, 0)
[node name="Center_Strip_Front" parent="." instance=ExtResource("2_center")]
transform = Transform3D(0.875, 0, 0, 0, 1, 0, 0, 0, 0.1, 1.5, 0, -10.8)
[node name="Center_Strip_Back" parent="." instance=ExtResource("2_center")]
transform = Transform3D(0.75, 0, 0, 0, 1, 0, 0, 0, 0.1, 0, 0, 10.8)

[node name="Sockets" type="Node3D" parent="."]

[node name="front" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, -12)
[node name="back" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 12)
[node name="left" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -12, 0, 0)
[node name="right" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12, 0, 0)
[node name="frontleft" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -12, 0, -12)
[node name="frontright" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12, 0, -12)
[node name="backleft" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -12, 0, 12)
[node name="backright" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12, 0, 12)
[node name="bottom" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -4, 0)
[node name="topcenter" type="Marker3D" parent="Sockets"]
```

- [ ] **Step 2: Commit**

```bash
git add terrain/scenes/CliffInCornerThree.tscn
git commit -m "feat(terrain): add CliffInCornerThree variant"
```

---

## Task 10: Create CliffInCornerAll.tscn (all 4 inner corners)

**Files:**
- Create: `terrain/scenes/CliffInCornerAll.tscn`

Mirrors LevelInCornerAll.tscn.

- [ ] **Step 1: Create the file**

```
[gd_scene load_steps=4 format=3]

[ext_resource type="PackedScene" uid="uid://b8esdhwy7hfi1" path="res://terrain/gltf/hill_cliff_tall_i_inner_corner_color_12.tscn" id="1_wall"]
[ext_resource type="PackedScene" uid="uid://bnpt5wxld3xvq" path="res://terrain/gltf/hill_top_e_center_color_12.tscn" id="2_center"]
[ext_resource type="PackedScene" uid="uid://begwnakrt5py5" path="res://terrain/gltf/hill_top_a_inner_corner_color_12.tscn" id="3_inner_top"]

[node name="CliffInCornerAll" type="Node3D"]

[node name="InnerWall_FL" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -10.5, -4, -10.5)
[node name="InnerWall_FR" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1.1924881e-08, 0, -1, 0, 1, 0, 1, 0, 1.1924881e-08, 10.5, -4, -10.5)
[node name="InnerWall_BR" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, 10.5, -4, 10.5)
[node name="InnerWall_BL" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, -10.5, -4, 10.5)

[node name="InnerTop_FL" parent="." instance=ExtResource("3_inner_top")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -10.5, 0, -10.5)
[node name="InnerTop_FR" parent="." instance=ExtResource("3_inner_top")]
transform = Transform3D(1.1924881e-08, 0, -1, 0, 1, 0, 1, 0, 1.1924881e-08, 10.5, 0, -10.5)
[node name="InnerTop_BR" parent="." instance=ExtResource("3_inner_top")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, 10.5, 0, 10.5)
[node name="InnerTop_BL" parent="." instance=ExtResource("3_inner_top")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, -10.5, 0, 10.5)

[node name="Center" parent="." instance=ExtResource("2_center")]
transform = Transform3D(0.75, 0, 0, 0, 1, 0, 0, 0, 0.75, 0, 0, 0)
[node name="Center_Strip_Left" parent="." instance=ExtResource("2_center")]
transform = Transform3D(0.1, 0, 0, 0, 1, 0, 0, 0, 0.75, -10.8, 0, 0)
[node name="Center_Strip_Right" parent="." instance=ExtResource("2_center")]
transform = Transform3D(0.1, 0, 0, 0, 1, 0, 0, 0, 0.75, 10.8, 0, 0)
[node name="Center_Strip_Front" parent="." instance=ExtResource("2_center")]
transform = Transform3D(0.75, 0, 0, 0, 1, 0, 0, 0, 0.1, 0, 0, -10.8)
[node name="Center_Strip_Back" parent="." instance=ExtResource("2_center")]
transform = Transform3D(0.75, 0, 0, 0, 1, 0, 0, 0, 0.1, 0, 0, 10.8)

[node name="Sockets" type="Node3D" parent="."]

[node name="front" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, -12)
[node name="back" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 12)
[node name="left" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -12, 0, 0)
[node name="right" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12, 0, 0)
[node name="frontleft" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -12, 0, -12)
[node name="frontright" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12, 0, -12)
[node name="backleft" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -12, 0, 12)
[node name="backright" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12, 0, 12)
[node name="bottom" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -4, 0)
[node name="topcenter" type="Marker3D" parent="Sockets"]
```

- [ ] **Step 2: Commit**

```bash
git add terrain/scenes/CliffInCornerAll.tscn
git commit -m "feat(terrain): add CliffInCornerAll variant"
```

---

## Task 11: Create CliffInCornerEdge1.tscn (back cardinal drop + frontleft inner corner)

**Files:**
- Create: `terrain/scenes/CliffInCornerEdge1.tscn`

Cardinal drop on back (+Z) and inner-corner notch at frontleft. Mirrors LevelInCornerEdge1.tscn.

- [ ] **Step 1: Create the file**

```
[gd_scene load_steps=5 format=3]

[ext_resource type="PackedScene" uid="uid://s7hlq6puc3vl" path="res://terrain/gltf/hill_cliff_tall_h_side_color_12.tscn" id="1_wall"]
[ext_resource type="PackedScene" uid="uid://72nb7fb13apc" path="res://terrain/gltf/hill_top_h_side_color_12.tscn" id="2_top"]
[ext_resource type="PackedScene" uid="uid://bnpt5wxld3xvq" path="res://terrain/gltf/hill_top_e_center_color_12.tscn" id="3_center"]
[ext_resource type="PackedScene" uid="uid://b8esdhwy7hfi1" path="res://terrain/gltf/hill_cliff_tall_i_inner_corner_color_12.tscn" id="4_inner_wall"]
[ext_resource type="PackedScene" uid="uid://begwnakrt5py5" path="res://terrain/gltf/hill_top_a_inner_corner_color_12.tscn" id="5_inner_top"]

[node name="CliffInCornerEdge1" type="Node3D"]

[node name="Wall_Back_1" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 10.5, -4, 10.5)
[node name="Wall_Back_2" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 7.5, -4, 10.5)
[node name="Wall_Back_3" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 4.5, -4, 10.5)
[node name="Wall_Back_4" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 1.5, -4, 10.5)
[node name="Wall_Back_5" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -1.5, -4, 10.5)
[node name="Wall_Back_6" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -4.5, -4, 10.5)
[node name="Wall_Back_7" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -7.5, -4, 10.5)
[node name="Wall_Back_8" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -10.5, -4, 10.5)

[node name="Top_Back_1" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 10.5, 0, 10.5)
[node name="Top_Back_2" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 7.5, 0, 10.5)
[node name="Top_Back_3" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 4.5, 0, 10.5)
[node name="Top_Back_4" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 1.5, 0, 10.5)
[node name="Top_Back_5" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -1.5, 0, 10.5)
[node name="Top_Back_6" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -4.5, 0, 10.5)
[node name="Top_Back_7" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -7.5, 0, 10.5)
[node name="Top_Back_8" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -10.5, 0, 10.5)

[node name="InnerWall_FL" parent="." instance=ExtResource("4_inner_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -10.5, -4, -10.5)
[node name="InnerTop_FL" parent="." instance=ExtResource("5_inner_top")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -10.5, 0, -10.5)

[node name="Center" parent="." instance=ExtResource("3_center")]
transform = Transform3D(0.875, 0, 0, 0, 1, 0, 0, 0, 0.75, 1.5, 0, 0)
[node name="Center_Strip_Left" parent="." instance=ExtResource("3_center")]
transform = Transform3D(0.125, 0, 0, 0, 1, 0, 0, 0, 0.75, -10.5, 0, 0)
[node name="Center_Strip_Front" parent="." instance=ExtResource("3_center")]
transform = Transform3D(0.875, 0, 0, 0, 1, 0, 0, 0, 0.125, 1.5, 0, -10.5)

[node name="Sockets" type="Node3D" parent="."]

[node name="front" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, -12)
[node name="back" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 12)
[node name="left" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -12, 0, 0)
[node name="right" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12, 0, 0)
[node name="frontleft" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -12, 0, -12)
[node name="frontright" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12, 0, -12)
[node name="backleft" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -12, 0, 12)
[node name="backright" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12, 0, 12)
[node name="bottom" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -4, 0)
[node name="topcenter" type="Marker3D" parent="Sockets"]
```

- [ ] **Step 2: Commit**

```bash
git add terrain/scenes/CliffInCornerEdge1.tscn
git commit -m "feat(terrain): add CliffInCornerEdge1 variant"
```

---

## Task 12: Create CliffInCornerEdge2.tscn (right cardinal drop + frontleft inner corner)

**Files:**
- Create: `terrain/scenes/CliffInCornerEdge2.tscn`

Cardinal drop on right (+X) and inner-corner notch at frontleft. Mirrors LevelInCornerEdge2.tscn.

- [ ] **Step 1: Create the file**

```
[gd_scene load_steps=5 format=3]

[ext_resource type="PackedScene" uid="uid://s7hlq6puc3vl" path="res://terrain/gltf/hill_cliff_tall_h_side_color_12.tscn" id="1_wall"]
[ext_resource type="PackedScene" uid="uid://72nb7fb13apc" path="res://terrain/gltf/hill_top_h_side_color_12.tscn" id="2_top"]
[ext_resource type="PackedScene" uid="uid://bnpt5wxld3xvq" path="res://terrain/gltf/hill_top_e_center_color_12.tscn" id="3_center"]
[ext_resource type="PackedScene" uid="uid://b8esdhwy7hfi1" path="res://terrain/gltf/hill_cliff_tall_i_inner_corner_color_12.tscn" id="4_inner_wall"]
[ext_resource type="PackedScene" uid="uid://begwnakrt5py5" path="res://terrain/gltf/hill_top_a_inner_corner_color_12.tscn" id="5_inner_top"]

[node name="CliffInCornerEdge2" type="Node3D"]

[node name="Wall_Right_1" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, -4, -10.5)
[node name="Wall_Right_2" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, -4, -7.5)
[node name="Wall_Right_3" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, -4, -4.5)
[node name="Wall_Right_4" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, -4, -1.5)
[node name="Wall_Right_5" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, -4, 1.5)
[node name="Wall_Right_6" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, -4, 4.5)
[node name="Wall_Right_7" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, -4, 7.5)
[node name="Wall_Right_8" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, -4, 10.5)

[node name="Top_Right_1" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, 0, -10.5)
[node name="Top_Right_2" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, 0, -7.5)
[node name="Top_Right_3" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, 0, -4.5)
[node name="Top_Right_4" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, 0, -1.5)
[node name="Top_Right_5" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, 0, 1.5)
[node name="Top_Right_6" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, 0, 4.5)
[node name="Top_Right_7" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, 0, 7.5)
[node name="Top_Right_8" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, 0, 10.5)

[node name="InnerWall_FL" parent="." instance=ExtResource("4_inner_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -10.5, -4, -10.5)
[node name="InnerTop_FL" parent="." instance=ExtResource("5_inner_top")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -10.5, 0, -10.5)

[node name="Center" parent="." instance=ExtResource("3_center")]
transform = Transform3D(0.75, 0, 0, 0, 1, 0, 0, 0, 0.875, 0, 0, 1.5)
[node name="Center_Strip_Left" parent="." instance=ExtResource("3_center")]
transform = Transform3D(0.125, 0, 0, 0, 1, 0, 0, 0, 0.875, -10.5, 0, 1.5)
[node name="Center_Strip_Front" parent="." instance=ExtResource("3_center")]
transform = Transform3D(0.75, 0, 0, 0, 1, 0, 0, 0, 0.125, 0, 0, -10.5)

[node name="Sockets" type="Node3D" parent="."]

[node name="front" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, -12)
[node name="back" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 12)
[node name="left" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -12, 0, 0)
[node name="right" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12, 0, 0)
[node name="frontleft" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -12, 0, -12)
[node name="frontright" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12, 0, -12)
[node name="backleft" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -12, 0, 12)
[node name="backright" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12, 0, 12)
[node name="bottom" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -4, 0)
[node name="topcenter" type="Marker3D" parent="Sockets"]
```

- [ ] **Step 2: Commit**

```bash
git add terrain/scenes/CliffInCornerEdge2.tscn
git commit -m "feat(terrain): add CliffInCornerEdge2 variant"
```

---

## Task 13: Create CliffInCornerEdgeBoth.tscn (back + right cardinals + frontleft inner corner)

**Files:**
- Create: `terrain/scenes/CliffInCornerEdgeBoth.tscn`

Cardinal drops on back + right (forming outer corner at backright) and inner-corner notch at frontleft. Mirrors LevelInCornerEdgeBoth.tscn.

- [ ] **Step 1: Create the file**

```
[gd_scene load_steps=7 format=3]

[ext_resource type="PackedScene" uid="uid://s7hlq6puc3vl" path="res://terrain/gltf/hill_cliff_tall_h_side_color_12.tscn" id="1_wall"]
[ext_resource type="PackedScene" uid="uid://72nb7fb13apc" path="res://terrain/gltf/hill_top_h_side_color_12.tscn" id="2_top"]
[ext_resource type="PackedScene" uid="uid://bnpt5wxld3xvq" path="res://terrain/gltf/hill_top_e_center_color_12.tscn" id="3_center"]
[ext_resource type="PackedScene" uid="uid://dlrq6d5kq6380" path="res://terrain/gltf/hill_top_i_outer_corner_color_12.tscn" id="4_corner_top"]
[ext_resource type="PackedScene" uid="uid://dvihclfiaajr3" path="res://terrain/gltf/hill_cliff_tall_i_outer_corner_color_12.tscn" id="5_corner_wall"]
[ext_resource type="PackedScene" uid="uid://b8esdhwy7hfi1" path="res://terrain/gltf/hill_cliff_tall_i_inner_corner_color_12.tscn" id="6_inner_wall"]
[ext_resource type="PackedScene" uid="uid://begwnakrt5py5" path="res://terrain/gltf/hill_top_a_inner_corner_color_12.tscn" id="7_inner_top"]

[node name="CliffInCornerEdgeBoth" type="Node3D"]

[node name="Wall_Back_1" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 10.5, -4, 10.5)
visible = false
[node name="Wall_Back_2" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 7.5, -4, 10.5)
[node name="Wall_Back_3" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 4.5, -4, 10.5)
[node name="Wall_Back_4" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 1.5, -4, 10.5)
[node name="Wall_Back_5" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -1.5, -4, 10.5)
[node name="Wall_Back_6" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -4.5, -4, 10.5)
[node name="Wall_Back_7" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -7.5, -4, 10.5)
[node name="Wall_Back_8" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -10.5, -4, 10.5)

[node name="Wall_Right_1" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, -4, -10.5)
[node name="Wall_Right_2" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, -4, -7.5)
[node name="Wall_Right_3" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, -4, -4.5)
[node name="Wall_Right_4" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, -4, -1.5)
[node name="Wall_Right_5" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, -4, 1.5)
[node name="Wall_Right_6" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, -4, 4.5)
[node name="Wall_Right_7" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, -4, 7.5)
[node name="Wall_Right_8" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, -4, 10.5)
visible = false

[node name="CornerWall_BR" parent="." instance=ExtResource("5_corner_wall")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, 10.5, -4, 10.5)

[node name="Top_Back_2" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 7.5, 0, 10.5)
[node name="Top_Back_3" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 4.5, 0, 10.5)
[node name="Top_Back_4" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 1.5, 0, 10.5)
[node name="Top_Back_5" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -1.5, 0, 10.5)
[node name="Top_Back_6" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -4.5, 0, 10.5)
[node name="Top_Back_7" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -7.5, 0, 10.5)
[node name="Top_Back_8" parent="." instance=ExtResource("2_top")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -10.5, 0, 10.5)

[node name="Top_Right_1" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, 0, -10.5)
[node name="Top_Right_2" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, 0, -7.5)
[node name="Top_Right_3" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, 0, -4.5)
[node name="Top_Right_4" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, 0, -1.5)
[node name="Top_Right_5" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, 0, 1.5)
[node name="Top_Right_6" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, 0, 4.5)
[node name="Top_Right_7" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, 0, 7.5)

[node name="CornerTop_BR" parent="." instance=ExtResource("4_corner_top")]
transform = Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, 10.5, 0, 10.5)

[node name="InnerWall_FL" parent="." instance=ExtResource("6_inner_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -10.5, -4, -10.5)
[node name="InnerTop_FL" parent="." instance=ExtResource("7_inner_top")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -10.5, 0, -10.5)

[node name="Center" parent="." instance=ExtResource("3_center")]
transform = Transform3D(0.75, 0, 0, 0, 1, 0, 0, 0, 0.75, 0, 0, 0)
[node name="Center_Strip_Left" parent="." instance=ExtResource("3_center")]
transform = Transform3D(0.125, 0, 0, 0, 1, 0, 0, 0, 0.875, -10.5, 0, 1.5)
[node name="Center_Strip_Front" parent="." instance=ExtResource("3_center")]
transform = Transform3D(0.875, 0, 0, 0, 1, 0, 0, 0, 0.125, 1.5, 0, -10.5)

[node name="Sockets" type="Node3D" parent="."]

[node name="front" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, -12)
[node name="back" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 12)
[node name="left" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -12, 0, 0)
[node name="right" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12, 0, 0)
[node name="frontleft" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -12, 0, -12)
[node name="frontright" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12, 0, -12)
[node name="backleft" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -12, 0, 12)
[node name="backright" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12, 0, 12)
[node name="bottom" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -4, 0)
[node name="topcenter" type="Marker3D" parent="Sockets"]
```

- [ ] **Step 2: Commit**

```bash
git add terrain/scenes/CliffInCornerEdgeBoth.tscn
git commit -m "feat(terrain): add CliffInCornerEdgeBoth variant"
```

---

## Task 14: Create CliffInCornerSideEdge.tscn (right cardinal + frontleft + backleft inner corners)

**Files:**
- Create: `terrain/scenes/CliffInCornerSideEdge.tscn`

Cardinal drop on right (+X) and two inner-corner notches on the left side (frontleft + backleft). Mirrors LevelInCornerSideEdge.tscn.

- [ ] **Step 1: Create the file**

```
[gd_scene load_steps=5 format=3]

[ext_resource type="PackedScene" uid="uid://s7hlq6puc3vl" path="res://terrain/gltf/hill_cliff_tall_h_side_color_12.tscn" id="1_wall"]
[ext_resource type="PackedScene" uid="uid://72nb7fb13apc" path="res://terrain/gltf/hill_top_h_side_color_12.tscn" id="2_top"]
[ext_resource type="PackedScene" uid="uid://bnpt5wxld3xvq" path="res://terrain/gltf/hill_top_e_center_color_12.tscn" id="3_center"]
[ext_resource type="PackedScene" uid="uid://b8esdhwy7hfi1" path="res://terrain/gltf/hill_cliff_tall_i_inner_corner_color_12.tscn" id="4_inner_wall"]
[ext_resource type="PackedScene" uid="uid://begwnakrt5py5" path="res://terrain/gltf/hill_top_a_inner_corner_color_12.tscn" id="5_inner_top"]

[node name="CliffInCornerSideEdge" type="Node3D"]

[node name="Wall_Right_1" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, -4, -10.5)
[node name="Wall_Right_2" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, -4, -7.5)
[node name="Wall_Right_3" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, -4, -4.5)
[node name="Wall_Right_4" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, -4, -1.5)
[node name="Wall_Right_5" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, -4, 1.5)
[node name="Wall_Right_6" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, -4, 4.5)
[node name="Wall_Right_7" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, -4, 7.5)
[node name="Wall_Right_8" parent="." instance=ExtResource("1_wall")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, -4, 10.5)

[node name="Top_Right_1" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, 0, -10.5)
[node name="Top_Right_2" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, 0, -7.5)
[node name="Top_Right_3" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, 0, -4.5)
[node name="Top_Right_4" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, 0, -1.5)
[node name="Top_Right_5" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, 0, 1.5)
[node name="Top_Right_6" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, 0, 4.5)
[node name="Top_Right_7" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, 0, 7.5)
[node name="Top_Right_8" parent="." instance=ExtResource("2_top")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10.5, 0, 10.5)

[node name="InnerWall_FL" parent="." instance=ExtResource("4_inner_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -10.5, -4, -10.5)
[node name="InnerWall_BL" parent="." instance=ExtResource("4_inner_wall")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, -10.5, -4, 10.5)

[node name="InnerTop_FL" parent="." instance=ExtResource("5_inner_top")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -10.5, 0, -10.5)
[node name="InnerTop_BL" parent="." instance=ExtResource("5_inner_top")]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, -10.5, 0, 10.5)

[node name="Center" parent="." instance=ExtResource("3_center")]
transform = Transform3D(0.75, 0, 0, 0, 1, 0, 0, 0, 0.75, 0, 0, 0)
[node name="Center_Strip_Left" parent="." instance=ExtResource("3_center")]
transform = Transform3D(0.1, 0, 0, 0, 1, 0, 0, 0, 0.75, -10.8, 0, 0)

[node name="Sockets" type="Node3D" parent="."]

[node name="front" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, -12)
[node name="back" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 12)
[node name="left" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -12, 0, 0)
[node name="right" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12, 0, 0)
[node name="frontleft" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -12, 0, -12)
[node name="frontright" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12, 0, -12)
[node name="backleft" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -12, 0, 12)
[node name="backright" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12, 0, 12)
[node name="bottom" type="Marker3D" parent="Sockets"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -4, 0)
[node name="topcenter" type="Marker3D" parent="Sockets"]
```

- [ ] **Step 2: Commit**

```bash
git add terrain/scenes/CliffInCornerSideEdge.tscn
git commit -m "feat(terrain): add CliffInCornerSideEdge variant"
```

---

## Task 15: Update TerrainModuleDefinitions.gd (rename existing, add new loaders)

**Files:**
- Modify: `scripts/terrain/TerrainModuleDefinitions.gd:26` (ground tile topcenter distribution tag)
- Modify: `scripts/terrain/TerrainModuleDefinitions.gd:546-571` (existing cliff loaders)
- Modify: `scripts/terrain/TerrainModuleDefinitions.gd` (append 10 new loaders)

- [ ] **Step 1: Rename `cliff-edge` references to `cliff-side` and update existing loaders**

Change line 26 from:
```gdscript
	var top_tag_prob_center: Distribution = Distribution.new({"level-ground-center": 0.95, "cliff-edge": 0.05})
```
to:
```gdscript
	var top_tag_prob_center: Distribution = Distribution.new({"level-ground-center": 0.95, "cliff-side": 0.05})
```

Replace lines 546–571 (the entire `load_cliff_edge_tile`, `load_cliff_outer_corner_tile`, `load_cliff_inner_corner_tile`, `load_cliff_inner_corner_diag_tile` block) with:

```gdscript
static func load_cliff_side_tile() -> TerrainModule:
	return _build_cliff_tile(
		"res://terrain/scenes/CliffSide.tscn",
		TagList.new(["cliff", "cliff-side", "24x24x4"])
	)


static func load_cliff_corner_tile() -> TerrainModule:
	return _build_cliff_tile(
		"res://terrain/scenes/CliffCorner.tscn",
		TagList.new(["cliff", "cliff-corner", "24x24x4"])
	)


static func load_cliff_line_tile() -> TerrainModule:
	return _build_cliff_tile(
		"res://terrain/scenes/CliffLine.tscn",
		TagList.new(["cliff", "cliff-line", "24x24x4"])
	)


static func load_cliff_peninsula_tile() -> TerrainModule:
	return _build_cliff_tile(
		"res://terrain/scenes/CliffPeninsula.tscn",
		TagList.new(["cliff", "cliff-peninsula", "24x24x4"])
	)


static func load_cliff_island_tile() -> TerrainModule:
	return _build_cliff_tile(
		"res://terrain/scenes/CliffIsland.tscn",
		TagList.new(["cliff", "cliff-island", "24x24x4"])
	)


static func load_cliff_inner_corner_tile() -> TerrainModule:
	return _build_cliff_tile(
		"res://terrain/scenes/CliffInCorner.tscn",
		TagList.new(["cliff", "cliff-inner-corner", "24x24x4"])
	)


static func load_cliff_inner_corner_diag_tile() -> TerrainModule:
	return _build_cliff_tile(
		"res://terrain/scenes/CliffInCornerDiag.tscn",
		TagList.new(["cliff", "cliff-inner-corner-diag", "24x24x4"])
	)


static func load_cliff_inner_corner_side_tile() -> TerrainModule:
	return _build_cliff_tile(
		"res://terrain/scenes/CliffInCornerSide.tscn",
		TagList.new(["cliff", "cliff-inner-corner-side", "24x24x4"])
	)


static func load_cliff_inner_corner_three_tile() -> TerrainModule:
	return _build_cliff_tile(
		"res://terrain/scenes/CliffInCornerThree.tscn",
		TagList.new(["cliff", "cliff-inner-corner-three", "24x24x4"])
	)


static func load_cliff_inner_corner_all_tile() -> TerrainModule:
	return _build_cliff_tile(
		"res://terrain/scenes/CliffInCornerAll.tscn",
		TagList.new(["cliff", "cliff-inner-corner-all", "24x24x4"])
	)


static func load_cliff_inner_corner_edge1_tile() -> TerrainModule:
	return _build_cliff_tile(
		"res://terrain/scenes/CliffInCornerEdge1.tscn",
		TagList.new(["cliff", "cliff-inner-corner-edge1", "24x24x4"])
	)


static func load_cliff_inner_corner_edge2_tile() -> TerrainModule:
	return _build_cliff_tile(
		"res://terrain/scenes/CliffInCornerEdge2.tscn",
		TagList.new(["cliff", "cliff-inner-corner-edge2", "24x24x4"])
	)


static func load_cliff_inner_corner_edge_both_tile() -> TerrainModule:
	return _build_cliff_tile(
		"res://terrain/scenes/CliffInCornerEdgeBoth.tscn",
		TagList.new(["cliff", "cliff-inner-corner-edge-both", "24x24x4"])
	)


static func load_cliff_inner_corner_side_edge_tile() -> TerrainModule:
	return _build_cliff_tile(
		"res://terrain/scenes/CliffInCornerSideEdge.tscn",
		TagList.new(["cliff", "cliff-inner-corner-side-edge", "24x24x4"])
	)
```

- [ ] **Step 2: Update the comment in `load_cliff_interior_tile`**

In the comment block inside `load_cliff_interior_tile` (the next function after the cliff loaders), replace the two occurrences of "cliff-edges" with "cliff-sides":

Find:
```gdscript
	# cliff-edges' required-tag filters remain satisfied. Lateral cardinals are
	# non-expandable because the plateau perimeter is covered by cliff-edges.
```

Replace with:
```gdscript
	# cliff-sides' required-tag filters remain satisfied. Lateral cardinals are
	# non-expandable because the plateau perimeter is covered by cliff-sides.
```

- [ ] **Step 3: Commit**

```bash
git add scripts/terrain/TerrainModuleDefinitions.gd
git commit -m "refactor(terrain): rename cliff-edge/outer-corner tags and add 10 cliff variant loaders"
```

---

## Task 16: Update TerrainModuleLibrary.gd to register the new modules

**Files:**
- Modify: `scripts/terrain/TerrainModuleLibrary.gd:19-33` (load_terrain_modules)

- [ ] **Step 1: Replace the cliff registration lines in `load_terrain_modules`**

Replace lines 29-33 (the existing cliff block):

```gdscript
		terrain_modules.append(TerrainModuleDefinitions.load_cliff_edge_tile())
		terrain_modules.append(TerrainModuleDefinitions.load_cliff_outer_corner_tile())
		terrain_modules.append(TerrainModuleDefinitions.load_cliff_inner_corner_tile())
		terrain_modules.append(TerrainModuleDefinitions.load_cliff_inner_corner_diag_tile())
		terrain_modules.append(TerrainModuleDefinitions.load_cliff_interior_tile())
```

with:

```gdscript
		terrain_modules.append(TerrainModuleDefinitions.load_cliff_side_tile())
		terrain_modules.append(TerrainModuleDefinitions.load_cliff_corner_tile())
		terrain_modules.append(TerrainModuleDefinitions.load_cliff_line_tile())
		terrain_modules.append(TerrainModuleDefinitions.load_cliff_peninsula_tile())
		terrain_modules.append(TerrainModuleDefinitions.load_cliff_island_tile())
		terrain_modules.append(TerrainModuleDefinitions.load_cliff_inner_corner_tile())
		terrain_modules.append(TerrainModuleDefinitions.load_cliff_inner_corner_diag_tile())
		terrain_modules.append(TerrainModuleDefinitions.load_cliff_inner_corner_side_tile())
		terrain_modules.append(TerrainModuleDefinitions.load_cliff_inner_corner_three_tile())
		terrain_modules.append(TerrainModuleDefinitions.load_cliff_inner_corner_all_tile())
		terrain_modules.append(TerrainModuleDefinitions.load_cliff_inner_corner_edge1_tile())
		terrain_modules.append(TerrainModuleDefinitions.load_cliff_inner_corner_edge2_tile())
		terrain_modules.append(TerrainModuleDefinitions.load_cliff_inner_corner_edge_both_tile())
		terrain_modules.append(TerrainModuleDefinitions.load_cliff_inner_corner_side_edge_tile())
		terrain_modules.append(TerrainModuleDefinitions.load_cliff_interior_tile())
```

- [ ] **Step 2: Commit**

```bash
git add scripts/terrain/TerrainModuleLibrary.gd
git commit -m "feat(terrain): register 10 new cliff variants in module library"
```

---

## Task 17: Update CliffEdgeRule.gd (canonical mappings, ordering, module mapping)

**Files:**
- Modify: `scripts/terrain/rules/CliffEdgeRule.gd:22-39` (CANONICAL_MISSING_BY_TAG + CLIFF_TAG_ORDER)
- Modify: `scripts/terrain/rules/CliffEdgeRule.gd:436-445` (_get_module_for_cliff_tag)

- [ ] **Step 1: Replace `CANONICAL_MISSING_BY_TAG` and `CLIFF_TAG_ORDER`**

Replace lines 22-39 with:

```gdscript
# Canonical missing-socket patterns for each cliff variant. Drop faces in the
# authored scenes sit on -Z ("front") and -X ("left"), matching the level-tile
# convention — getting these wrong rotates every retiled piece 180° off its
# intended orientation.
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
# Order checked: most-constrained first. Variants with more missing sockets
# are matched before variants with fewer; within a missing-count, hybrid
# (cardinal + diagonal) patterns are matched before pure-cardinal or
# pure-diagonal patterns of the same count.
const CLIFF_TAG_ORDER: Array[String] = [
	"cliff-island",
	"cliff-inner-corner-all",
	"cliff-inner-corner-edge-both",
	"cliff-inner-corner-side-edge",
	"cliff-inner-corner-three",
	"cliff-peninsula",
	"cliff-inner-corner-edge1",
	"cliff-inner-corner-edge2",
	"cliff-inner-corner-diag",
	"cliff-inner-corner-side",
	"cliff-line",
	"cliff-corner",
	"cliff-inner-corner",
	"cliff-side",
]
```

- [ ] **Step 2: Update `_spawn_one_cliff_neighbour` reference**

Inside `_spawn_one_cliff_neighbour` (around line 182 in the pre-edit file; will have shifted after Step 1), find the line:

```gdscript
	var module: TerrainModule = TerrainModuleDefinitions.load_cliff_edge_tile()
```

and replace it with:

```gdscript
	var module: TerrainModule = TerrainModuleDefinitions.load_cliff_side_tile()
```

- [ ] **Step 3: Replace `_get_module_for_cliff_tag`**

Find the entire `_get_module_for_cliff_tag` function (originally around lines 436–446 in the pre-edit file; will have shifted after Step 1). The existing version uses `module_by_cliff_tag = { ... }` with 4 entries. Replace the whole function with:

```gdscript
func _get_module_for_cliff_tag(cliff_tag: String) -> TerrainModule:
	if module_by_cliff_tag.is_empty():
		module_by_cliff_tag = {
			"cliff-side":                   TerrainModuleDefinitions.load_cliff_side_tile(),
			"cliff-corner":                 TerrainModuleDefinitions.load_cliff_corner_tile(),
			"cliff-line":                   TerrainModuleDefinitions.load_cliff_line_tile(),
			"cliff-peninsula":              TerrainModuleDefinitions.load_cliff_peninsula_tile(),
			"cliff-island":                 TerrainModuleDefinitions.load_cliff_island_tile(),
			"cliff-inner-corner":           TerrainModuleDefinitions.load_cliff_inner_corner_tile(),
			"cliff-inner-corner-diag":      TerrainModuleDefinitions.load_cliff_inner_corner_diag_tile(),
			"cliff-inner-corner-side":      TerrainModuleDefinitions.load_cliff_inner_corner_side_tile(),
			"cliff-inner-corner-three":     TerrainModuleDefinitions.load_cliff_inner_corner_three_tile(),
			"cliff-inner-corner-all":       TerrainModuleDefinitions.load_cliff_inner_corner_all_tile(),
			"cliff-inner-corner-edge1":     TerrainModuleDefinitions.load_cliff_inner_corner_edge1_tile(),
			"cliff-inner-corner-edge2":     TerrainModuleDefinitions.load_cliff_inner_corner_edge2_tile(),
			"cliff-inner-corner-edge-both": TerrainModuleDefinitions.load_cliff_inner_corner_edge_both_tile(),
			"cliff-inner-corner-side-edge": TerrainModuleDefinitions.load_cliff_inner_corner_side_edge_tile(),
			"cliff-interior":               TerrainModuleDefinitions.load_cliff_interior_tile(),
		}
	return module_by_cliff_tag.get(cliff_tag, null)
```

- [ ] **Step 4: Commit**

```bash
git add scripts/terrain/rules/CliffEdgeRule.gd
git commit -m "feat(terrain): teach CliffEdgeRule about all 14 cliff variants"
```

---

## Task 18: Update tests/test_terrain_generator.gd

**Files:**
- Modify: `tests/test_terrain_generator.gd:743-790` (test_cliff_scenes_have_correct_socket_layout)
- Modify: `tests/test_terrain_generator.gd:1329` (cliff-edge → cliff-side)
- Modify: `tests/test_terrain_generator.gd:2303-2329` (test_cliff_edge_tile_has_correct_tags_and_socket_config)
- Modify: `tests/test_terrain_generator.gd:2332-2344` (test_all_cliff_edge_variants_load)
- Modify: `tests/test_terrain_generator.gd:2357` (comment cliff-edges → cliff-sides)
- Modify: `tests/test_terrain_generator.gd:2388-2421` (cliff-outer-corner / cliff-edge tag refs)

- [ ] **Step 1: Update `test_cliff_scenes_have_correct_socket_layout` to list all 14 scene paths**

Replace the `scene_paths` array (lines 756-761) with:

```gdscript
	var scene_paths: Array[String] = [
		"res://terrain/scenes/CliffSide.tscn",
		"res://terrain/scenes/CliffCorner.tscn",
		"res://terrain/scenes/CliffLine.tscn",
		"res://terrain/scenes/CliffPeninsula.tscn",
		"res://terrain/scenes/CliffIsland.tscn",
		"res://terrain/scenes/CliffInCorner.tscn",
		"res://terrain/scenes/CliffInCornerDiag.tscn",
		"res://terrain/scenes/CliffInCornerSide.tscn",
		"res://terrain/scenes/CliffInCornerThree.tscn",
		"res://terrain/scenes/CliffInCornerAll.tscn",
		"res://terrain/scenes/CliffInCornerEdge1.tscn",
		"res://terrain/scenes/CliffInCornerEdge2.tscn",
		"res://terrain/scenes/CliffInCornerEdgeBoth.tscn",
		"res://terrain/scenes/CliffInCornerSideEdge.tscn",
	]
```

- [ ] **Step 2: Update the ground-tile cliff seeding assertion**

Change line 1329 from:
```gdscript
	assert_true(topcenter_dist.dist.has("cliff-edge"), "Ground topcenter must seed cliff-edge")
```
to:
```gdscript
	assert_true(topcenter_dist.dist.has("cliff-side"), "Ground topcenter must seed cliff-side")
```

- [ ] **Step 3: Rename `test_cliff_edge_tile_has_correct_tags_and_socket_config` and update its body**

Rename the function and update tag/loader references. Replace lines 2303-2329 with:

```gdscript
func test_cliff_side_tile_has_correct_tags_and_socket_config() -> void:
	var module: TerrainModule = TerrainModuleDefinitions.load_cliff_side_tile()
	assert_not_null(module)
	assert_true(module.tags.has("cliff"))
	assert_true(module.tags.has("cliff-side"))
	assert_true(module.tags.has("24x24x4"))
	assert_true(module.replace_existing)

	# Cardinal sockets must require cliff and have high fill prob.
	for socket_name in ["front", "back", "left", "right"]:
		assert_true(
			module.socket_required.has(socket_name),
			"Missing socket_required for %s" % socket_name
		)
		assert_true(
			module.socket_required[socket_name].has("cliff"),
			"Cardinal %s must require cliff" % socket_name
		)
		assert_almost_eq(
			float(module.socket_fill_prob[socket_name]),
			TerrainModuleDefinitions.CLIFF_LATERAL_FILL_PROB,
			0.001,
			"Cardinal %s must use CLIFF_LATERAL_FILL_PROB" % socket_name
		)

	# Bottom is non-expandable (attaches to ground, doesn't seek neighbors).
	assert_eq(module.socket_fill_prob["bottom"], null)
```

- [ ] **Step 4: Update `test_all_cliff_edge_variants_load` to cover all 13 non-interior variants**

Rename to `test_all_cliff_variants_load` and replace the `variants` dictionary. Replace lines 2332-2344 with:

```gdscript
func test_all_cliff_variants_load() -> void:
	var variants: Dictionary[String, Callable] = {
		"cliff-corner":                 TerrainModuleDefinitions.load_cliff_corner_tile,
		"cliff-line":                   TerrainModuleDefinitions.load_cliff_line_tile,
		"cliff-peninsula":              TerrainModuleDefinitions.load_cliff_peninsula_tile,
		"cliff-island":                 TerrainModuleDefinitions.load_cliff_island_tile,
		"cliff-inner-corner":           TerrainModuleDefinitions.load_cliff_inner_corner_tile,
		"cliff-inner-corner-diag":      TerrainModuleDefinitions.load_cliff_inner_corner_diag_tile,
		"cliff-inner-corner-side":      TerrainModuleDefinitions.load_cliff_inner_corner_side_tile,
		"cliff-inner-corner-three":     TerrainModuleDefinitions.load_cliff_inner_corner_three_tile,
		"cliff-inner-corner-all":       TerrainModuleDefinitions.load_cliff_inner_corner_all_tile,
		"cliff-inner-corner-edge1":     TerrainModuleDefinitions.load_cliff_inner_corner_edge1_tile,
		"cliff-inner-corner-edge2":     TerrainModuleDefinitions.load_cliff_inner_corner_edge2_tile,
		"cliff-inner-corner-edge-both": TerrainModuleDefinitions.load_cliff_inner_corner_edge_both_tile,
		"cliff-inner-corner-side-edge": TerrainModuleDefinitions.load_cliff_inner_corner_side_edge_tile,
	}
	for variant_tag in variants.keys():
		var module: TerrainModule = variants[variant_tag].call()
		assert_not_null(module, "Module loader failed for %s" % variant_tag)
		assert_true(module.tags.has("cliff"), "%s missing 'cliff' tag" % variant_tag)
		assert_true(module.tags.has(variant_tag), "%s missing '%s' tag" % [variant_tag, variant_tag])
		assert_true(module.tags.has("24x24x4"), "%s missing '24x24x4' tag" % variant_tag)
		assert_true(module.replace_existing, "%s must have replace_existing" % variant_tag)
```

- [ ] **Step 5: Update comment in `test_cliff_interior_tile_uses_ground_scene_with_cliff_tag`**

Line 2357 — change "cliff-edges" → "cliff-sides":

```gdscript
	# Lateral cardinals are NON-expandable (the perimeter is covered by cliff-sides).
```

- [ ] **Step 6: Find and update remaining `cliff-edge` / `cliff-outer-corner` references**

Run:
```bash
grep -n 'cliff-edge\|cliff-outer-corner\|load_cliff_edge_tile\|load_cliff_outer_corner_tile' tests/test_terrain_generator.gd
```

For each match outside of comments already handled, swap `cliff-edge` → `cliff-side`, `cliff-outer-corner` → `cliff-corner`, `load_cliff_edge_tile` → `load_cliff_side_tile`, `load_cliff_outer_corner_tile` → `load_cliff_corner_tile`. Then re-run the grep to confirm no leftover hits.

- [ ] **Step 7: Commit**

```bash
git add tests/test_terrain_generator.gd
git commit -m "test: update terrain generator tests for renamed cliff tags"
```

---

## Task 19: Update tests/test_terrain_module_library.gd

**Files:**
- Modify: `tests/test_terrain_module_library.gd:156-159` (cliff tag list)

- [ ] **Step 1: Replace the cliff tag list**

Replace lines 156-159:

```gdscript
		"cliff-edge",
		"cliff-outer-corner",
		"cliff-inner-corner",
		"cliff-inner-corner-diag",
```

with:

```gdscript
		"cliff-side",
		"cliff-corner",
		"cliff-line",
		"cliff-peninsula",
		"cliff-island",
		"cliff-inner-corner",
		"cliff-inner-corner-diag",
		"cliff-inner-corner-side",
		"cliff-inner-corner-three",
		"cliff-inner-corner-all",
		"cliff-inner-corner-edge1",
		"cliff-inner-corner-edge2",
		"cliff-inner-corner-edge-both",
		"cliff-inner-corner-side-edge",
```

- [ ] **Step 2: Confirm no other stale references in this file**

Run:
```bash
grep -n 'cliff-edge\|cliff-outer-corner' tests/test_terrain_module_library.gd
```
Expected: no matches.

- [ ] **Step 3: Commit**

```bash
git add tests/test_terrain_module_library.gd
git commit -m "test: update terrain module library test for renamed cliff tags"
```

---

## Task 20: Delete the old cliff scene files

**Files:**
- Delete: `terrain/scenes/CliffOuterCorner.tscn`
- Delete: `terrain/scenes/CliffInnerCorner.tscn`
- Delete: `terrain/scenes/CliffInnerCornerDiag.tscn`

- [ ] **Step 1: Verify nothing still references the old paths**

Run:
```bash
grep -rn 'CliffOuterCorner\|CliffInnerCorner' \
  scripts/ tests/ terrain/ \
  | grep -v '\.uid:'
```
Expected: only the three doomed files themselves; no `.gd` or other `.tscn` matches.

- [ ] **Step 2: Delete the files**

```bash
git rm terrain/scenes/CliffOuterCorner.tscn
git rm terrain/scenes/CliffInnerCorner.tscn
git rm terrain/scenes/CliffInnerCornerDiag.tscn
```

- [ ] **Step 3: Commit**

```bash
git commit -m "chore(terrain): remove old CliffOuterCorner/InnerCorner[Diag] scenes"
```

---

## Task 21: Run the full test suite and fix any regressions

**Files:**
- No file modifications expected unless tests reveal them.

- [ ] **Step 1: Run the terrain generator and module library test suites**

```bash
godot --headless --path /Users/ryko/story \
  -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/test_terrain_generator.gd,res://tests/test_terrain_module_library.gd \
  -gexit
```

Expected: all assertions pass. Specifically `test_cliff_scenes_have_correct_socket_layout` should iterate over 14 paths and find the canonical socket positions in every one.

- [ ] **Step 2: If a test fails, diagnose and fix**

Common failure modes:
- "Scene X missing socket 'name'" — the Sockets block in scene X is incomplete; re-check against the canonical Sockets template at the top of this plan.
- "Scene X socket 'name' position mismatch" — the Marker3D transform has a wrong origin; expected `Vector3(x, y, z)` values per the canonical Sockets template.
- "scene_paths must contain ..." or loader-callable failures — a tag string or function name was mistyped; check it against Task 15 and Task 17.

Fix the scene or test file, re-run, and commit each fix as its own commit:

```bash
git add <fixed file>
git commit -m "fix(terrain): <one-line description>"
```

- [ ] **Step 3: Final sanity check — run all tests once more**

```bash
godot --headless --path /Users/ryko/story \
  -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests \
  -gexit
```

Expected: zero failures across the full suite.

---

## Done

Every level-tile variant now has a matching cliff-tile variant under the level-orientation convention. The `_recursively_validate_via_spawning` loop in `CliffEdgeRule` remains in place as defense-in-depth but should never need to spawn anything because every cliff configuration now has a valid module.
