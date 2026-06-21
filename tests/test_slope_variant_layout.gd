# tests/test_slope_variant_layout.gd
extends GutTest

func _kinds(name: String) -> Dictionary:
	var counts := {"top": 0, "edge": 0, "outer": 0, "inner": 0}
	for cell in SlopeVariantLayout.layout(name):
		counts[cell.component] += 1
	return counts

func test_all_variants_have_4_cells() -> void:
	for name in SlopeVariantLayout.VARIANT_MASKS.keys():
		assert_eq(SlopeVariantLayout.layout(name).size(), 4, name)

func test_side_one_edge_row() -> void:
	var k := _kinds("CliffSide")
	assert_eq(k.edge, 2)
	assert_eq(k.outer, 0)
	assert_eq(k.inner, 0)
	assert_eq(k.top, 2)

func test_corner_has_outer() -> void:
	# front+left slope -> FL outer corner, front/left edges, back-right top.
	var k := _kinds("CliffCorner")
	assert_eq(k.outer, 1)
	assert_eq(k.edge, 2)
	assert_eq(k.top, 1)

func test_island_full_ring() -> void:
	var k := _kinds("CliffIsland")
	assert_eq(k.outer, 4)
	assert_eq(k.edge, 0)
	assert_eq(k.top, 0)
	assert_eq(k.inner, 0)

func test_incorner_single_inner() -> void:
	var k := _kinds("CliffInCorner")
	assert_eq(k.inner, 1)
	assert_eq(k.edge, 0)
	assert_eq(k.outer, 0)
	assert_eq(k.top, 3)

func test_incorner_edge_both() -> void:
	# back+right slope (outer at BR) + inner corner at FL -> 1 outer/1 inner/2 edge.
	var k := _kinds("CliffInCornerEdgeBoth")
	assert_eq(k.outer, 1)
	assert_eq(k.inner, 1)
	assert_eq(k.edge, 2)
	assert_eq(k.top, 0)

func test_inner_corner_cell_position() -> void:
	var inner_cell := {}
	for cell in SlopeVariantLayout.layout("CliffInCorner"):
		if cell.component == "inner":
			inner_cell = cell
	assert_almost_eq(inner_cell.x, -6.0, 1e-6)
	assert_almost_eq(inner_cell.z, -6.0, 1e-6)

func test_component_angles() -> void:
	for cell in SlopeVariantLayout.layout("CliffSide"):
		if cell.component == "edge":
			assert_almost_eq(cell.angle_deg, 0.0, 1e-6)
	for cell in SlopeVariantLayout.layout("CliffInCornerEdge2"):
		if cell.component == "edge":
			assert_almost_eq(cell.angle_deg, 270.0, 1e-6)
	for cell in SlopeVariantLayout.layout("CliffCorner"):
		if cell.component == "outer":
			assert_almost_eq(cell.angle_deg, 0.0, 1e-6)
