extends GutTest
const CORNER := preload("res://scripts/terrain/features/villages/kit/KitCornerTowers.gd")
const TOWER := preload("res://scripts/terrain/features/villages/kit/KitTowerAssembly.gd")


func test_tower_bearing_requires_ground_or_the_exposed_top_of_retained_stone() -> void:
	var envelope := WarrenVolumeEnvelope.new()
	var podium := {Vector3i(0, 3, 0): true}
	assert_true(KitVillageBuildings._tower_bearing(envelope, {}, Vector2i.ZERO, 0))
	assert_true(KitVillageBuildings._tower_bearing(envelope, podium, Vector2i.ZERO, 4))
	assert_false(KitVillageBuildings._tower_bearing(envelope, {}, Vector2i.ZERO, 4))
	assert_false(KitVillageBuildings._tower_bearing(envelope, podium, Vector2i.RIGHT, 4))
	podium[Vector3i(0, 4, 0)] = true
	assert_false(
		KitVillageBuildings._tower_bearing(envelope, podium, Vector2i.ZERO, 4),
		"A base buried in the retaining wall is not its top"
	)


func test_native_footing_can_embed_in_its_proven_stone_but_cannot_overhang_it() -> void:
	var kit := SuntailBuildingKit.create()
	var catalog := EnvironmentCatalog.load_default()
	var envelope := WarrenVolumeEnvelope.new()
	var podium := {}
	for x in range(-2, 7):
		for z in range(-2, 6):
			podium[Vector3i(x, 3, z)] = true
	var house := BuildingMass.new()
	house.stable_id = &"kit.terrace"
	house.seed = 10
	house.ground_band = 4
	for band in [4, 6, 8]:
		house.add_storey(
			band, BuildingMass.rect_cells(Rect2i(0, 0, 4, 3)), BuildingMass.MATERIAL_TIMBER
		)
	house.add_roof(Rect2i(0, 0, 4, 3), 0, 10, &"blue")
	var bearing := func(cell: Vector2i, band: int) -> bool:
		return KitVillageBuildings._tower_bearing(envelope, podium, cell, band)
	var blocked := func(_cell: Vector2i, band: int) -> bool: return band < 4
	var candidate := CORNER.propose(house, kit, catalog, [], [], [], blocked, bearing)
	assert_false(candidate.is_empty())
	if candidate.is_empty():
		return
	assert_eq(candidate.pose.origin.y, 6.0)
	var foot: AABB = (
		candidate.pose
		* candidate.parts[0].transform
		* catalog.descriptor(candidate.parts[0].asset_id).measured_aabb
	)
	foot.size.y = .01
	var cells := TOWER._cells(foot, kit)
	assert_gt(cells.size(), 1)
	var hole: Vector3i = cells[0]
	podium.erase(Vector3i(hole.x, 3, hole.z))
	assert_true(
		(
			TOWER
			. fit(
				house,
				kit,
				catalog,
				candidate.pose,
				3,
				TOWER.Form.ROUND,
				blocked,
				bearing,
				CORNER.narrow_parts(3)
			)
			. is_empty()
		),
		"Every part of the native base must be borne"
	)
