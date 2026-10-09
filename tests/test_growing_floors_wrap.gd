extends GutTest
## Outer-corner wrap under step-in (spec amendment Decision 5, Amendment 2).
const FIXTURE := preload("res://tests/fixtures/growing_house.gd")
const GROWTH := preload("res://scripts/terrain/features/villages/kit/KitGrowingFronts.gd")


func _all_faces() -> TownCharacter:
	return FIXTURE.character({&"growth_other_face_chance": 1.0})


func _closures(f: Dictionary, dir: int, band: int) -> Array:
	for lean: Dictionary in f.leans:
		if lean.host == f.front.stable_id and int(lean.dir) == dir and int(lean.band) == band:
			return lean.closures
	return []


func test_a_growing_face_pulls_its_corner_neighbours_one_hop() -> void:
	var f := FIXTURE.build() # only the south face is rolled; east and west are pulled
	# East and west step in from both sides of a three-module plan: at the two-jetty cap
	# they would leave a one-module stalk (bearing), so the front holds at one jetty.
	for dir: int in [3, 0, 2]:
		assert_eq(FIXTURE.leans_on(f.front, dir), [-1.0, 0.0, 0.0, 0.0] as Array[float], "face %d" % dir)
	assert_eq(FIXTURE.leans_on(f.front, 1), [0.0, 0.0, 0.0, 0.0] as Array[float], "north: not pulled")
	assert_eq(_closures(f, 3, 0), [&"wrap", &"wrap"])
	var causes := (f.result.rejections as Array).map(func(r: Dictionary) -> StringName: return r.cause)
	assert_true(causes.has(&"bearing"), str(causes))


func test_a_member_that_cannot_hold_leaves_the_front() -> void:
	# The east face's ground storey carries a passage: it cannot stand in at any cap, so
	# it leaves; south and west refit without it and reach the cap.
	var f := FIXTURE.build({"prepare": func(front: BuildingMass) -> void:
		var edge := BuildingMass.edge_key(Vector2i(2, 1), 0)
		front.storeys[0].openings[edge] = BuildingMass.OPENING_DOOR
		front.storeys[0]["passage_edges"] = {edge: true}})
	assert_eq(FIXTURE.leans_on(f.front, 0), [0.0, 0.0, 0.0, 0.0] as Array[float], "east left the front")
	for dir: int in [3, 2]:
		assert_eq(FIXTURE.leans_on(f.front, dir), [-2.0, -1.0, 0.0, 0.0] as Array[float], "face %d" % dir)
	assert_eq(_closures(f, 3, 0), [&"return", &"wrap"], "south: east end returns, west end wraps")
	var causes := (f.result.rejections as Array).map(func(r: Dictionary) -> StringName: return r.cause)
	assert_true(causes.has(&"portal"), str(causes))


## Two faces of one storey that meet at a convex corner stand in equally or one is on its line.
func _corners_consistent(mass: BuildingMass) -> bool:
	for storey: Dictionary in mass.storeys:
		var offsets: Dictionary = storey.get("wall_offsets", {})
		for slot: Dictionary in BuildingKitAssembler.storey_slots(storey):
			if not bool(slot.right_convex):
				continue
			var edge: Vector3i = slot.edge
			var side := BuildingMass.DIRS.find(BuildingKitAssembler.right_of(int(slot.dir)))
			var mine := float(offsets.get(edge, 0.0))
			var theirs := float(offsets.get(BuildingMass.edge_key(Vector2i(edge.x, edge.y), side), 0.0))
			if mine < 0.0 and theirs < 0.0 and absf(mine - theirs) > 1e-6:
				return false
	return true


func test_unequal_steps_never_meet_at_a_convex_corner() -> void:
	for options: Dictionary in [{}, {"character": _all_faces()}, {"lone": true}]:
		assert_true(_corners_consistent(FIXTURE.build(options).front), str(options))


func test_right_extend_is_zero_without_growth() -> void:
	var mass := FIXTURE.house(&"kit.plain", Rect2i(0, 0, 3, 2), 3, 3)
	for storey: Dictionary in mass.storeys:
		for slot: Dictionary in BuildingKitAssembler.storey_slots(storey):
			assert_eq(float(slot.right_extend), 0.0)
