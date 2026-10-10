extends GutTest
## Inside-corner ends under step-in (spec Amendment 2): an end beside the house's own
## cell closes its recess with a strip (bury); a building standing in front of an end
## no longer matters (nothing moves outward).
const FIXTURE := preload("res://tests/fixtures/growing_house.gd")


## A five-storey neighbour standing in the lane beyond the front's east end (cells
## x 3..4, z -2..-1), windowed on its west wall.
func _corner() -> BuildingMass:
	return FIXTURE.roofed(&"kit.fixture.corner", Rect2i(3, -2, 2, 2), 5, 0)


func _east_closure(f: Dictionary, band: int) -> StringName:
	for lean: Dictionary in f.leans:
		if lean.host == f.front.stable_id and int(lean.dir) == 3 and int(lean.band) == band:
			return lean.closures[0] # dir 3: left = the east end
	return &""


func test_a_neighbour_in_front_of_an_end_no_longer_blocks_it() -> void:
	var f := FIXTURE.build({"extra": [_corner()], "lone": true})
	assert_eq(FIXTURE.leans_on(f.front, 3), [-2.0, -1.0, 0.0, 0.0] as Array[float])
	for band: int in [0, 2]:
		assert_eq(_east_closure(f, band), &"return", "band %d" % band)


## An L-shaped house: a four-storey body (x 0..2) and a five-storey wing (x 3,
## z -1..1) standing out in front of the body's south face.
func _own_wing() -> BuildingMass:
	var mass := BuildingMass.new()
	mass.stable_id = &"kit.fixture.front"
	mass.seed = hash("kit.fixture.front")
	var cells := BuildingMass.rect_cells(Rect2i(0, 0, 3, 2))
	var wing := {Vector2i(3, -1): true, Vector2i(3, 0): true, Vector2i(3, 1): true}
	cells.merge(wing)
	for s in 5:
		mass.add_storey(s * 2, (cells if s < 4 else wing).duplicate(), BuildingMass.MATERIAL_TIMBER)
	mass.storeys[0].openings[BuildingMass.edge_key(Vector2i(1, 0), 3)] = BuildingMass.OPENING_DOOR
	mass.add_roof(Rect2i(0, 0, 3, 2), 1, 8, &"red")["union_index"] = 0
	mass.add_roof(Rect2i(3, -1, 1, 3), 1, 10, &"red")["union_index"] = 1
	return mass


func test_a_concave_end_closes_its_recess_against_the_own_wing() -> void:
	var mass := _own_wing()
	var f := FIXTURE.build({"replace_front": mass, "lone": true})
	assert_eq(FIXTURE.leans_on(mass, 3), [-2.0, -1.0, 0.0, 0.0, 0.0] as Array[float])
	for band: int in [0, 2]:
		assert_eq(_east_closure(f, band), &"bury", "band %d" % band)
	var catalog := EnvironmentCatalog.load_default()
	for depth: float in [2.0, 1.0]:
		var strips := (f.parts as Array).filter(func(p: Dictionary) -> bool:
			var box: AABB = p.transform * catalog.descriptor(p.asset_id).measured_aabb
			return String(p.role) == "frontage.return.%s" % BuildingKitAssembler.lean_suffix(depth) \
				and absf(box.get_center().x - 6.0) < 0.3)
		assert_eq(strips.size(), 1, "one recess strip of depth %.1f on the wing's line" % depth)


func test_an_end_whose_own_wall_continues_behind_the_neighbour_is_buried() -> void:
	# The house runs on (x 3) behind the neighbour standing in the lane: the exposed
	# run ends at x 3 beside the house's own cell, so its recess is closed by a strip.
	var mass := FIXTURE.roofed(&"kit.fixture.front", Rect2i(0, 0, 4, 2), 4, 3, 1, 0)
	var f := FIXTURE.build({"replace_front": mass, "extra": [_corner()], "lone": true})
	assert_eq(FIXTURE.leans_on(mass, 3), [-2.0, -1.0, 0.0, 0.0] as Array[float])
	assert_eq(_east_closure(f, 0), &"bury")
