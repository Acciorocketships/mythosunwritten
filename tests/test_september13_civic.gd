extends GutTest

func _town(seed_value: int, direction: Vector2 = Vector2.DOWN) -> VillageUrbanFabricPlan:
	var program := VillageProgram.compile({}, EnvironmentCatalog.load_default())
	var heights: Dictionary = {}
	for z in range(-12,13):
		for x in range(-12,13): heights[Vector2i(x,z)] = 0
	return VillageHamletConstruction.solve(VillageTerrainView.from_region(
		HeightfieldRegion.new(heights, heights)), seed_value, &"civic", Vector2.ZERO,
		direction, &"orange", program, null)

func test_well_is_proportioned_as_a_civic_focus_and_keeps_ground_contact() -> void:
	var town := _town(2)
	assert_true(town.accepted)
	var catalog := EnvironmentCatalog.load_default()
	for entry: Dictionary in town.entries:
		if entry.asset_id != &"sfv.well.001": continue
		var box: AABB = entry.transform * catalog.descriptor(entry.asset_id).measured_aabb
		assert_gte(box.size.y, 6.0, "the photographed well needs a larger complete silhouette")
		assert_almost_eq(box.position.y, 0.0, 0.001)
	assert_true(VillageOccupancy.new().first_conflict(town.volumes).is_empty())

func test_campfire_clearing_has_no_paved_square_or_internal_square_paths() -> void:
	var town := _town(1)
	assert_true(town.accepted)
	assert_eq(town.fabric_audit.focal_asset, &"sfbp.campfire.001")
	var paved := 0
	for shape: FeatureGroundShape in town.surfaces:
		if shape.surface_id == FeatureGroundField.WORN_PATH: paved += 1
	assert_eq(paved, 0, "without external roads the campfire village is a grassy clearing")
	assert_true(VillageOccupancy.new().first_conflict(town.volumes).is_empty())

func test_clearing_preserves_canonical_road_ends_in_all_directions() -> void:
	var program := VillageProgram.compile({}, EnvironmentCatalog.load_default())
	var heights: Dictionary = {}
	for z in range(-12,13):
		for x in range(-12,13): heights[Vector2i(x,z)] = 0
	var ground := FeatureGroundField.new([], [], 0.0)
	ground._connection_masks[Vector2i.ZERO] = 15
	ground._connection_masks[Vector2i.RIGHT] = 2
	ground._connection_masks[Vector2i.LEFT] = 1
	ground._connection_masks[Vector2i.DOWN] = 8
	ground._connection_masks[Vector2i.UP] = 4
	for direction: Vector2 in [Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP]:
		var town := VillageHamletConstruction.solve(VillageTerrainView.from_region(
			HeightfieldRegion.new(heights,heights)), 1, &"civic.crossroads", Vector2.ZERO,
			direction, &"blue", program, ground)
		assert_true(town.accepted)
		var field := FeatureGroundField.new(town.surfaces, [], 0.0)
		for outward: Vector2 in [Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP]:
			assert_eq(field.surface_at(outward*22),FeatureGroundField.WORN_PATH)
			assert_eq(field.surface_at(outward*12),FeatureGroundField.NATURAL)
		assert_true(VillageOccupancy.new().first_conflict(town.volumes).is_empty())
