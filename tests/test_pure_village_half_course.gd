extends GutTest

func test_short_house_course_uses_native_matching_masonry():
	var kit := preload("res://scripts/terrain/features/villages/kit/PureVillageBuildingKit.gd").create()
	var mass := BuildingMass.new()
	mass.stable_id = &"short.course"
	var half := mass.add_storey(0, BuildingMass.rect_cells(Rect2i(0,0,2,2)), &"stone")
	half.bands = 1
	mass.add_storey(1, half.cells, &"stone")
	var parts := BuildingKitAssembler.new(kit).assemble(mass)
	var catalog := EnvironmentCatalog.load_default()
	var count := 0
	for part: Dictionary in parts:
		if part.role != &"wall.stone.course": continue
		count += 1
		assert_eq(part.asset_id, &"pure_village.stone.retaining_half")
		assert_almost_eq(part.transform.basis.get_scale().y, 1.0, 0.001, "Keep authored stone proportions")
		var box: AABB = part.transform * catalog.descriptor(part.asset_id).measured_aabb
		assert_almost_eq(box.end.y, kit.band_height(), 0.02, "Half course meets the full storey")
	assert_eq(count, 8)
	assert_almost_eq(kit.anchors[&"wall.stone.course"].origin.z, kit.anchors[&"wall.stone.plain"].origin.z, 0.001)

func test_native_plinth_meets_wall_without_deepening_foundation():
	var kit := preload("res://scripts/terrain/features/villages/kit/PureVillageBuildingKit.gd").create()
	var mass := BuildingMass.new()
	mass.stable_id = &"plinth.control"
	mass.add_storey(0, BuildingMass.rect_cells(Rect2i(0,0,2,2)), &"stone", false, true)
	var catalog := EnvironmentCatalog.load_default()
	var count := 0
	for part: Dictionary in BuildingKitAssembler.new(kit).assemble(mass):
		if part.role != &"plinth.stone": continue
		count += 1
		assert_eq(part.asset_id, &"pure_village.stone.plinth")
		assert_eq(part.transform.basis.get_scale(), Vector3.ONE)
		var box: AABB = part.transform * catalog.descriptor(part.asset_id).measured_aabb
		assert_almost_eq(box.end.y, 0.0, 0.001)
		assert_almost_eq(box.position.y, -kit.plinth_height, 0.001)
	assert_eq(count, 8)
