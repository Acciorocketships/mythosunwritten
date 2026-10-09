extends GutTest

const Support = preload("res://tests/harness/october9_water_support_candidate.gd")


func test_lowered_channel_cannot_supply_a_higher_bank() -> void:
	var levels := PackedFloat32Array([5, 3, 4, 4])
	var ground := PackedFloat32Array([0, 0, 3.5, 0])
	var actual := Support.constrain(levels, ground, 4, PackedInt32Array([0]))
	assert_eq(actual, PackedFloat32Array([5, 3, -INF, -INF]))


func test_surface_hump_over_submerged_ground_lowers_instead_of_drying() -> void:
	var actual := Support.constrain(
		PackedFloat32Array([5, 3, 4, 2]), PackedFloat32Array([0, 0, 0, 0]), 4, PackedInt32Array([0])
	)
	assert_eq(actual, PackedFloat32Array([5, 3, 3, 2]))


func test_independent_higher_source_keeps_its_basin() -> void:
	var actual := Support.constrain(
		PackedFloat32Array([5, 3, 4, 4]),
		PackedFloat32Array([0, 0, 3.5, 0]),
		4,
		PackedInt32Array([0, 3])
	)
	assert_eq(actual, PackedFloat32Array([5, 3, 4, 4]))


func test_best_route_wins_independent_of_source_order() -> void:
	var levels := PackedFloat32Array([5, 5, 5, 3, 4, 4, 6, 6, 6])
	var ground := PackedFloat32Array([0, 0, 0, 0, 0, 0, 0, 0, 0])
	var a := Support.constrain(levels, ground, 3, PackedInt32Array([0, 6]))
	var b := Support.constrain(levels, ground, 3, PackedInt32Array([6, 0]))
	assert_eq(a, levels)
	assert_eq(a, b)


func test_dry_sources_and_row_wrap_cannot_supply_water() -> void:
	var levels := PackedFloat32Array([-INF, -INF, 3, 3, -INF, 3])
	var ground := PackedFloat32Array([0, 0, 0, 0, 0, 4])
	var actual := Support.constrain(levels, ground, 3, PackedInt32Array([0, 2, 5]))
	assert_eq(actual, PackedFloat32Array([-INF, -INF, 3, -INF, -INF, -INF]))


func test_photographed_branch_loses_supply_even_with_external_and_pond_roots() -> void:
	var file := FileAccess.open(
		"res://tests/fixtures/october9/water-support-branch.bin", FileAccess.READ
	)
	var grid: Dictionary = file.get_var()
	var actual := Support.constrain(grid.levels, grid.ground, grid.size, grid.conservative_roots)
	for point: Vector2 in [Vector2(-27, 1143), Vector2(-27, 1137), Vector2(-24, 1146)]:
		var cell: Vector2 = (point - grid.origin) / grid.step
		var index: int = roundi(cell.y) * int(grid.size) + roundi(cell.x)
		assert_false(
			is_finite(actual[index]), "unsupported photographed side branch at " + str(point)
		)
	var main_cell: Vector2 = (Vector2(-39, 1143) - grid.origin) / grid.step
	var main_index: int = roundi(main_cell.y) * int(grid.size) + roundi(main_cell.x)
	assert_eq(
		actual[main_index], grid.levels[main_index], "the supplied main channel retains its water"
	)
