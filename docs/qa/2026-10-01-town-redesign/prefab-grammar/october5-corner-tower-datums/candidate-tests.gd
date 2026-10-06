extends GutTest
const CORNER = preload("res://scripts/terrain/features/villages/kit/KitCornerTowers.gd")


func test_split_level_corner_tries_actual_upper_floor_datums():
	var house := BuildingMass.new()
	house.ground_band = 0
	for band in [0, 3, 5, 7]:
		house.add_storey(
			band, BuildingMass.rect_cells(Rect2i(0, 0, 3, 3)), BuildingMass.MATERIAL_TIMBER
		)
	assert_eq(
		CORNER.base_bands(house, 9),
		[3, 5],
		"Two complete supported storeys, aligned to the raised wing"
	)


func test_no_invented_datums_or_one_storey_fallback():
	var house := BuildingMass.new()
	house.ground_band = 0
	for band in [0, 2, 4]:
		house.add_storey(
			band, BuildingMass.rect_cells(Rect2i(0, 0, 3, 3)), BuildingMass.MATERIAL_TIMBER
		)
	assert_eq(CORNER.base_bands(house, 6), [0, 2])
	assert_eq(CORNER.base_bands(house, 15), [])
