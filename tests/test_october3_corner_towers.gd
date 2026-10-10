extends GutTest
const CORNER := preload("res://scripts/terrain/features/villages/kit/KitCornerTowers.gd")
const HOST := preload("res://scripts/terrain/features/villages/kit/KitTowerHostFit.gd")
const TOWER := preload("res://scripts/terrain/features/villages/kit/KitTowerAssembly.gd")


func _house() -> BuildingMass:
	var house := BuildingMass.new()
	house.stable_id = &"kit.corner"
	house.seed = 10
	for band in [0, 2, 4]:
		house.add_storey(
			band, BuildingMass.rect_cells(Rect2i(0, 0, 4, 3)), BuildingMass.MATERIAL_TIMBER
		)
	house.add_roof(Rect2i(0, 0, 4, 3), 0, 6, &"blue")
	return house


func _proposal(
	house: BuildingMass, kit: BuildingKit, air: Array[Dictionary] = [], bearing := true
) -> Dictionary:
	return CORNER.propose(
		house,
		kit,
		EnvironmentCatalog.load_default(),
		air,
		[],
		[],
		Callable(),
		func(_column: Vector2i, band: int) -> bool: return bearing and band == 0
	)


func test_full_native_shaft_joins_both_faces_of_an_actual_corner() -> void:
	for kit: BuildingKit in [
		SuntailBuildingKit.create(),
		(
			preload("res://scripts/terrain/features/villages/kit/PureVillageBuildingKit.gd")
			. roof_study()
		)
	]:
		var house := _house()
		var before := house.storeys.duplicate(true)
		var candidate := _proposal(house, kit)
		assert_false(candidate.is_empty())
		if candidate.is_empty():
			continue
		assert_eq(
			house.storeys, before, "Proposal leaves host unchanged until complete fitting succeeds"
		)
		assert_eq(candidate.attachment, &"corner")
		assert_eq(candidate.form, TOWER.Form.ROUND)
		assert_eq(candidate.parts[0].asset_id, &"pure_village.roof_turret.middle")
		assert_eq(candidate.pose.origin.y, 0.0)
		assert_true(candidate.pose.origin.x in [0.0, 8.0])
		assert_true(candidate.pose.origin.z in [0.0, 6.0])
		var faces := {}
		for opening: Dictionary in candidate.host_plan.openings:
			faces[opening.dir] = true
		assert_eq(faces.size(), 2, "Both adjoining wall faces participate in the junction")
		assert_eq(candidate.pose, _proposal(house, kit).pose)
		HOST.apply(house, candidate.host_plan)
		for opening: Dictionary in candidate.host_plan.openings:
			assert_eq(
				house.storeys[opening.storey].openings[opening.edge], BuildingMass.OPENING_PLAIN
			)


func test_corner_tower_cannot_float_or_enter_public_air() -> void:
	var kit := SuntailBuildingKit.create()
	assert_true(_proposal(_house(), kit, [], false).is_empty())
	var air: Array[Dictionary] = [{"bounds": AABB(Vector3(-20, -1, -20), Vector3(60, 50, 60))}]
	assert_true(_proposal(_house(), kit, air).is_empty())
	var stepped := _house()
	stepped.storeys[-1].cells = BuildingMass.rect_cells(Rect2i(1, 1, 4, 3))
	stepped.roofs[0].rect = Rect2i(1, 1, 4, 3)
	assert_true(
		_proposal(stepped, kit).is_empty(),
		"A shifted upper corner cannot invent a supporting shaft junction below"
	)


func test_lower_wing_gets_a_complete_window_course_not_a_roof_ornament() -> void:
	var house := _house()
	house.storeys.resize(1)
	house.roofs[0].eave_band = 2
	var candidate := _proposal(house, SuntailBuildingKit.create())
	assert_false(candidate.is_empty())
	if candidate.is_empty():
		return
	assert_eq(candidate.storeys, 1)
	assert_eq(candidate.pose.origin.y, 0.0)
	assert_eq(candidate.parts.size(), 2)
	assert_eq(candidate.parts[0].asset_id, &"pure_village.roof_turret.window")
	assert_eq(candidate.parts[1].role, &"tower.roof")
	assert_eq(candidate.parts[1].transform.origin.y, 2.75)
	assert_true(_proposal(house, SuntailBuildingKit.create(), [], false).is_empty())
