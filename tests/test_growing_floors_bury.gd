extends GutTest
## Inside-corner run-into (spec amendment Decision 4b).
const FIXTURE := preload("res://tests/fixtures/growing_house.gd")
const GROWTH := preload("res://scripts/terrain/features/villages/kit/KitGrowingFronts.gd")


## A five-storey neighbour standing in the lane beyond the front's east end
## (cells x 3..4, z -2..-1): its west wall meets the front's south face line at x 3.
func _corner(plain: bool) -> BuildingMass:
	var corner := FIXTURE.roofed(&"kit.fixture.corner", Rect2i(3, -2, 2, 2), 5, 0)
	if plain:
		for storey: Dictionary in corner.storeys:
			for z: int in [-1, -2]:
				storey.openings[BuildingMass.edge_key(Vector2i(3, z), 2)] = BuildingMass.OPENING_PLAIN
	return corner


func _east_closure(f: Dictionary, band: int) -> StringName:
	for lean: Dictionary in f.leans:
		if lean.host == f.front.stable_id and int(lean.dir) == 3 and int(lean.band) == band:
			return lean.closures[0] # dir 3: left = the east end
	return &""


func test_inside_corner_end_is_buried_in_a_plain_wall() -> void:
	var f := FIXTURE.build({"extra": [_corner(true)], "lone": true})
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 1.0, 2.0, 2.0] as Array[float])
	for band: int in [2, 4, 6]:
		assert_eq(_east_closure(f, band), &"bury", "band %d" % band)
	var catalog := EnvironmentCatalog.load_default()
	for part: Dictionary in f.parts:
		if not String(part.role).begins_with("frontage.return"):
			continue
		var box: AABB = part.transform * catalog.descriptor(part.asset_id).measured_aabb
		assert_false(absf(box.get_center().x - 6.0) < 0.3 and box.get_center().z < 0.0,
			"no return piece at the buried end")


func test_inside_corner_against_a_window_withdraws_the_step() -> void:
	var f := FIXTURE.build({"extra": [_corner(false)], "lone": true})
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 0.0, 0.0, 0.0] as Array[float])
	var causes := (f.result.rejections as Array).map(func(r: Dictionary) -> StringName: return r.cause)
	assert_true(causes.has(&"ends"), str(causes))


func test_a_buried_end_meets_the_wall_without_a_slit() -> void:
	var f := FIXTURE.build({"extra": [_corner(true)], "lone": true})
	var catalog := EnvironmentCatalog.load_default()
	var y0 := float(f.front.storeys[1].floor_band) * 1.5
	var panel_end := -INF
	for part: Dictionary in f.parts:
		var box: AABB = part.transform * catalog.descriptor(part.asset_id).measured_aabb
		if String(part.role).begins_with("wall.timber.") and box.get_center().z < -0.5 \
				and box.position.y >= y0 - 1.0 and box.position.y <= y0 + 1.0:
			panel_end = maxf(panel_end, box.end.x)
	var assembler := BuildingKitAssembler.new(f.kit)
	var wall_start := INF
	for part: Dictionary in assembler.assemble(f.masses.back()):
		var box: AABB = part.transform * catalog.descriptor(part.asset_id).measured_aabb
		if String(part.role).begins_with("wall.") and box.get_center().x < 7.0 \
				and box.position.y >= y0 - 1.0 and box.position.y <= y0 + 1.0:
			wall_start = minf(wall_start, box.position.x)
	print("GROWTH_ABUT_GAP %.4f" % (wall_start - panel_end))
	assert_true(wall_start - panel_end <= 0.01, "the stepped wall reaches the plain wall it runs into")


## An L-shaped house: a three-storey body (x 0..2) and a five-storey wing (x 3,
## z -1..1) standing out in front of the body's south face, plain on its west side.
func _own_wing() -> BuildingMass:
	var mass := BuildingMass.new()
	mass.stable_id = &"kit.fixture.front"
	mass.seed = hash("kit.fixture.front")
	var cells := BuildingMass.rect_cells(Rect2i(0, 0, 3, 2))
	var wing := {Vector2i(3, -1): true, Vector2i(3, 0): true, Vector2i(3, 1): true}
	cells.merge(wing)
	for s in 5:
		var storey := mass.add_storey(s * 2, (cells if s < 4 else wing).duplicate(), BuildingMass.MATERIAL_TIMBER)
		storey.openings[BuildingMass.edge_key(Vector2i(3, -1), 2)] = BuildingMass.OPENING_PLAIN
	mass.storeys[0].openings[BuildingMass.edge_key(Vector2i(1, 0), 3)] = BuildingMass.OPENING_DOOR
	mass.add_roof(Rect2i(0, 0, 3, 2), 1, 8, &"red")["union_index"] = 0
	mass.add_roof(Rect2i(3, -1, 1, 3), 1, 10, &"red")["union_index"] = 1
	return mass


func test_a_concave_end_is_buried_in_its_own_plain_wing() -> void:
	var mass := _own_wing()
	var f := FIXTURE.build({"replace_front": mass, "lone": true})
	# 2.0 would put the step on the wing's own south face plane (a coplanar skin):
	# the end stays blocked there, so the face holds at the kit jetty.
	assert_eq(FIXTURE.leans_on(mass, 3), [0.0, 1.0, 1.0, 1.0, 0.0] as Array[float])
	for band: int in [2, 4, 6]:
		assert_eq(_east_closure(f, band), &"bury", "band %d" % band)
	for lean: Dictionary in f.leans:
		assert_eq(lean.buried_into, ["kit.fixture.front"] as Array[String], "own wing")


func test_a_concave_end_against_a_windowed_wing_withdraws_the_step() -> void:
	var mass := _own_wing()
	for storey: Dictionary in mass.storeys:
		storey.openings.erase(BuildingMass.edge_key(Vector2i(3, -1), 2))
	var f := FIXTURE.build({"replace_front": mass, "lone": true})
	assert_eq(FIXTURE.leans_on(mass, 3), [0.0, 0.0, 0.0, 0.0, 0.0] as Array[float])


func test_an_end_whose_own_wall_continues_behind_the_neighbour_is_buried() -> void:
	# The house runs on (x 3) behind the neighbour standing in the lane: the exposed
	# run still ends at x 3, against the neighbour's plain west wall. Since Task 8
	# the face's top storey must be closed above its step: its gable spans all four
	# modules and cannot move with a three-module step, so the face stays flush
	# (crown). (A separate gable wing over the run alone meets the fourth module's
	# own roof: a real collision, so that variant stays flush too.) The bury end
	# itself is still pinned by test_inside_corner_end_is_buried_in_a_plain_wall.
	var mass := FIXTURE.roofed(&"kit.fixture.front", Rect2i(0, 0, 4, 2), 4, 3, 1, 0)
	var f := FIXTURE.build({"replace_front": mass, "extra": [_corner(true)], "lone": true})
	assert_eq(FIXTURE.leans_on(mass, 3), [0.0, 0.0, 0.0, 0.0] as Array[float])
	assert_true((f.result.rejections as Array).any(func(r: Dictionary) -> bool:
		return r.cause == &"crown" and r.get("crown", &"") == &"gable"), str(f.result.rejections))
