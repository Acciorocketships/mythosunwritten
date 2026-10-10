extends GutTest
const FIXTURE := preload("res://tests/fixtures/growing_house.gd")
const GROWTH := preload("res://scripts/terrain/features/villages/kit/KitGrowingFronts.gd")


func test_house_exactly_at_the_cap() -> void:
	var f := FIXTURE.build({"storeys": 5, "lone": true})
	assert_eq(FIXTURE.leans_on(f.front, 3), [-2.0, -1.0, 0.0, 0.0, 0.0] as Array[float],
		"two kit jetties below the first upper storey, then every storey on the line")
	for wing: Dictionary in f.front.roofs:
		assert_false(wing.has("lean_min") or wing.has("lean_max"))


func test_facing_growing_houses_across_one_cell_lane() -> void:
	# Either roof axis: the roofs never move, so gable and eave fronts step in alike,
	# and the upper storeys keep today's lane (2.0 native) between them.
	for axis: int in [1, 0]:
		var f := FIXTURE.build({"facing": true, "back_grows": true, "lone": true,
			"roof_axis": axis, "back_roof_axis": axis})
		var front := FIXTURE.leans_on(f.front, 3)
		var back := FIXTURE.leans_on(f.back, 1)
		assert_eq(front, [-2.0, -1.0, 0.0, 0.0] as Array[float], "axis %d" % axis)
		for index in 4:
			assert_true(2.0 - front[index] - back[index] >= 2.0 - 1e-6, "storey %d: the lane only widens" % index)


func test_a_skywalk_end_on_the_top_storey_costs_nothing() -> void:
	var f := FIXTURE.build({"lone": true, "prepare": func(front: BuildingMass) -> void:
		var edge := BuildingMass.edge_key(Vector2i(1, 0), 3)
		front.storeys[3].openings[edge] = BuildingMass.OPENING_DOOR
		front.storeys[3]["passage_edges"] = {edge: true}})
	assert_eq(FIXTURE.leans_on(f.front, 3), [-2.0, -1.0, 0.0, 0.0] as Array[float])


func test_merged_compound_house_steps_per_edge_run() -> void:
	# An L of two lots: the front lot's south run (x 0..2, z 0) ends beside the forward
	# lot's own cell (bury); the forward lot's run (x 3..5, z -1) wraps or returns.
	var mass := BuildingMass.new()
	mass.stable_id = &"kit.fixture.front"
	var cells := BuildingMass.rect_cells(Rect2i(0, 0, 3, 2))
	cells.merge(BuildingMass.rect_cells(Rect2i(3, -1, 3, 3)))
	for s in 4:
		mass.add_storey(s * 2, cells.duplicate(), BuildingMass.MATERIAL_TIMBER)
	mass.add_roof(Rect2i(0, 0, 3, 2), 1, 8, &"red")["union_index"] = 0
	mass.add_roof(Rect2i(3, -1, 3, 3), 1, 8, &"red")["union_index"] = 1
	var chains := GROWTH.face_chains(mass, Callable(FIXTURE, "nothing_solid"),
		func(cell: Vector2i, band: int) -> bool: return cell.y <= -1 and cell.y >= -2 and band <= 1)
	assert_eq(chains.filter(func(c: Dictionary) -> bool: return int(c.dir) == 3).size(), 2, "one chain per edge run")
	var f := FIXTURE.build({"replace_front": mass, "lane": 2})
	var south := (f.leans as Array).filter(func(l: Dictionary) -> bool: return int(l.dir) == 3)
	assert_gt(south.size(), 0)
	for lean: Dictionary in south:
		for kind: StringName in lean.closures:
			assert_true(kind in [&"return", &"bury", &"wrap"], str(lean.closures))
	assert_true(south.any(func(l: Dictionary) -> bool: return (l.closures as Array).has(&"bury")),
		"the front lot's run closes its recess against the forward lot")


func test_top_storey_smaller_than_the_one_below() -> void:
	# Storey 3 is set back to the back row: the face's chain is storeys 1-2, whose top
	# (storey 2) stays on the line; the set-back storey and its roof are untouched.
	var f := FIXTURE.build({"storeys": 4, "lone": true, "prepare": func(front: BuildingMass) -> void:
		front.storeys[3].cells = BuildingMass.rect_cells(Rect2i(0, 1, 3, 1))
		front.roofs.clear()
		front.add_roof(Rect2i(0, 0, 3, 1), 0, 6, &"red")["union_index"] = 0
		front.add_roof(Rect2i(0, 1, 3, 1), 0, 8, &"red")["union_index"] = 1})
	assert_eq(FIXTURE.leans_on(f.front, 3), [-2.0, -1.0, 0.0, 0.0] as Array[float])
	assert_false(f.front.storeys[3].has("wall_offsets"))


func test_row_with_a_shorter_neighbour_holds_at_its_top() -> void:
	# A two-storey neighbour (one storey above its ground): the row steps only up to the
	# shorter member's top storey, so both stand one jetty in at the ground and every
	# shared storey stays equal (spec Amendment 2; supersedes the Task 6 ruling).
	var side := FIXTURE.roofed(&"kit.fixture.side", Rect2i(3, 0, 2, 2), 2, 3)
	var f := FIXTURE.build({"extra": [side], "block": [2]})
	assert_eq(FIXTURE.leans_on(f.front, 3), [-1.0, 0.0, 0.0, 0.0] as Array[float])
	assert_eq(FIXTURE.leans_on(side, 3), [-1.0, 0.0] as Array[float])


func test_a_wrapped_front_holds_at_its_shortest_face() -> void:
	# A 3 x 3 house whose top storey lacks its back-west cell: the west face's chain is
	# one storey shorter than the south face's. With light steps the front stops at the
	# west chain's top, so the wrapped corner stays equal at every shared storey.
	var mass := FIXTURE.house(&"kit.fixture.front", Rect2i(0, 0, 3, 3), 4, 1)
	mass.storeys[3].cells.erase(Vector2i(0, 2))
	mass.add_roof(Rect2i(0, 0, 3, 3), 1, 8, &"red")["union_index"] = 0
	var f := FIXTURE.build({"replace_front": mass, "block": [0],
		"character": FIXTURE.character({}, &"0.5")})
	assert_eq(FIXTURE.leans_on(f.front, 3), [-1.0, -0.5, 0.0, 0.0] as Array[float])
	assert_eq(FIXTURE.leans_on(f.front, 2), [-1.0, -0.5, 0.0, 0.0] as Array[float])


func test_every_recorded_end_closes_by_one_rule() -> void:
	for options: Dictionary in [{}, {"character": FIXTURE.character({&"growth_other_face_chance": 1.0})},
			{"lone": true}]:
		var f := FIXTURE.build(options)
		for lean: Dictionary in f.leans:
			for kind: StringName in lean.closures:
				assert_true(kind in [&"return", &"wrap", &"joint", &"bury"], "%s %s" % [str(options), kind])
