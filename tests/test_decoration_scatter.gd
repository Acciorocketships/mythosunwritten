extends GutTest
const Scatter := preload("res://scripts/terrain/field/DecorationScatter.gd")

func test_deterministic():
	var a := Scatter.cell_decorations(Vector2i(3, 7), 0, 4.0)
	var b := Scatter.cell_decorations(Vector2i(3, 7), 0, 4.0)
	assert_eq(a, b, "scatter is a pure function of (cell, seed, surface_y)")

func test_points_on_surface_within_cell():
	var ds := Scatter.cell_decorations(Vector2i(0, 0), 0, 12.5)
	for d in ds:
		assert_almost_eq(d["pos"].y, 12.5, 0.001, "decoration sits on the cell surface height")
		assert_lte(absf(d["pos"].x), 12.0)
		assert_lte(absf(d["pos"].z), 12.0)
		assert_true(d["tag"] in ["grass", "rock", "bush", "tree"])
