extends GutTest
const CORNER = preload("res://docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-terrace-tower-datums/candidate.gd")

func terraced_house() -> BuildingMass:
	var host := BuildingMass.new()
	host.stable_id = &"kit.terraced.corner"
	host.ground_band = 0
	for band in [0, 2]:
		host.add_storey(band, BuildingMass.rect_cells(Rect2i(0, 0, 4, 3)), BuildingMass.MATERIAL_TIMBER)
	for band in [4, 6, 8]:
		host.add_storey(band, BuildingMass.rect_cells(Rect2i(4, 0, 4, 3)), BuildingMass.MATERIAL_TIMBER)
	host.add_roof(Rect2i(4, 0, 4, 3), 0, 10, &"blue")
	return host

func proposal(host: BuildingMass, support: bool, air: Array[Dictionary] = []) -> Dictionary:
	return CORNER.propose(host, SuntailBuildingKit.create(), EnvironmentCatalog.load_default(),
		air, [], [], Callable(), func(_cell: Vector2i, band: int) -> bool: return support and band == 4)

func test_corner_tower_stands_at_its_wings_real_terrace_datum() -> void:
	var host := terraced_house()
	var before := host.storeys.duplicate(true)
	var candidate := proposal(host, true)
	assert_false(candidate.is_empty(), "Compound minimum ground must not hide the higher wing's real bearing")
	if candidate.is_empty(): return
	assert_eq(candidate.pose.origin.y, 6.0)
	assert_eq(candidate.storeys, 3)
	assert_eq(host.ground_band, 0, "Admission does not rewrite the compound datum")
	assert_eq(host.storeys, before)

func test_a_higher_floor_is_not_itself_evidence_of_bearing() -> void:
	assert_true(proposal(terraced_house(), false).is_empty())
	var air: Array[Dictionary] = [{"bounds": AABB(Vector3(-20,-20,-20),Vector3(80,80,80))}]
	assert_true(proposal(terraced_house(), true, air).is_empty())
