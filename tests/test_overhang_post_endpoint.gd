extends GutTest


func test_overhang_posts_end_at_the_supported_floor_not_its_ceiling() -> void:
	var grid := WarrenSpatialGrid.new(Vector3i(-4, 0, -4), Vector3i(12, 12, 12))
	var feature := WarrenFeatureReservation.new(&"fixture.overhang", &"room_overhang_support")
	var cells: Array[Vector3i] = []
	for x in 2:
		for z in 2:
			for y in [4, 5]:
				cells.append(Vector3i(x, y, z))
	assert_true(feature.add_reserved_cells(cells))
	var mass := KitVillageBuildings._support_mass(feature, grid, 7)
	assert_eq(mass.decor.size(), 4, "Keep every supported corner")
	for post: Dictionary in mass.decor:
		assert_eq(
			post.to_band, 4, "The feature reserves room volume; its bottom is the supported floor"
		)
	var kit := SuntailBuildingKit.create()
	var catalog := EnvironmentCatalog.load_default()
	var count := 0
	for part: Dictionary in BuildingKitAssembler.new(kit).assemble(mass):
		if part.role != &"post.timber":
			continue
		count += 1
		var bounds: AABB = part.transform * catalog.descriptor(part.asset_id).measured_aabb
		assert_lte(
			bounds.end.y, 4 * kit.band_height(), "No visible timber extends into the supported room"
		)
		assert_gte(
			bounds.end.y, 4 * kit.band_height() - 0.11, "Support still reaches the floor beam"
		)
	assert_eq(count, 4)
