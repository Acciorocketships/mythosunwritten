extends GutTest
## Outer-corner wrap (spec amendment Decision 5).
const FIXTURE := preload("res://tests/fixtures/growing_house.gd")
const GROWTH := preload("res://scripts/terrain/features/villages/kit/KitGrowingFronts.gd")


func _all_faces() -> TownCharacter:
	return FIXTURE.character({&"growth_other_face_chance": 1.0})


func _closures(f: Dictionary, dir: int) -> Array:
	for lean: Dictionary in f.leans:
		if lean.host == f.front.stable_id and int(lean.dir) == dir and int(lean.band) == 2:
			return lean.closures
	return []


func test_a_growing_face_pulls_its_corner_neighbours_one_hop() -> void:
	var f := FIXTURE.build() # only the south (street) face is rolled
	for dir: int in [3, 0, 2]:
		assert_eq(FIXTURE.leans_on(f.front, dir), [0.0, 1.0, 2.0, 2.0] as Array[float], "face %d" % dir)
	assert_eq(FIXTURE.leans_on(f.front, 1), [0.0, 0.0, 0.0, 0.0] as Array[float],
		"the north face is two hops away and was not rolled")
	assert_eq(_closures(f, 3), [&"wrap", &"wrap"])
	assert_eq(_closures(f, 0), [&"return", &"wrap"], "east: north end open, south end wrapped")
	assert_eq(_closures(f, 2), [&"wrap", &"return"], "west: south end wrapped, north end open")


func test_all_four_faces_wrap_into_a_ring() -> void:
	var f := FIXTURE.build({"character": _all_faces()})
	for dir in 4:
		assert_eq(FIXTURE.leans_on(f.front, dir), [0.0, 1.0, 2.0, 2.0] as Array[float], "face %d" % dir)
		assert_eq(_closures(f, dir), [&"wrap", &"wrap"], "face %d" % dir)


func test_a_member_that_cannot_hold_leaves_the_front() -> void:
	var f := FIXTURE.build({"character": _all_faces(), "prepare": func(front: BuildingMass) -> void:
		var edge := BuildingMass.edge_key(Vector2i(2, 0), 0)
		front.storeys[2].openings[edge] = BuildingMass.OPENING_DOOR
		front.storeys[2]["passage_edges"] = {edge: true}})
	assert_eq(FIXTURE.leans_on(f.front, 0), [0.0, 0.0, 0.0, 0.0] as Array[float], "the east portal face leaves")
	for dir: int in [3, 1, 2]:
		assert_eq(FIXTURE.leans_on(f.front, dir), [0.0, 1.0, 2.0, 2.0] as Array[float], "face %d" % dir)
	assert_eq(_closures(f, 3), [&"return", &"wrap"], "south: its east end now closes with a return")
	var causes := (f.result.rejections as Array).map(func(r: Dictionary) -> StringName: return r.cause)
	assert_true(causes.has(&"portal"), str(causes))


## Two faces of one storey that meet at a convex corner step equally or one is flush.
func _corners_consistent(mass: BuildingMass) -> bool:
	for storey: Dictionary in mass.storeys:
		var offsets: Dictionary = storey.get("wall_offsets", {})
		for slot: Dictionary in BuildingKitAssembler.storey_slots(storey):
			if not bool(slot.right_convex):
				continue
			var mine := float(slot.wall_offset)
			var theirs := float(slot.right_extend)
			var side := BuildingMass.DIRS.find(BuildingKitAssembler.right_of(int(slot.dir)))
			var edge: Vector3i = slot.edge
			theirs = float(offsets.get(BuildingMass.edge_key(Vector2i(edge.x, edge.y), side), 0.0))
			if mine > 0.0 and theirs > 0.0 and absf(mine - theirs) > 1e-6:
				return false
	return true


func test_unequal_steps_never_meet_at_a_convex_corner() -> void:
	for options: Dictionary in [{}, {"character": _all_faces()}, {"lone": true}]:
		assert_true(_corners_consistent(FIXTURE.build(options).front), str(options))


## Geometry, independent of guardrails and crowns: two faces written directly.
func _wrapped_pair() -> Dictionary:
	var kit := SuntailBuildingKit.create()
	var mass := FIXTURE.house(&"kit.fixture.front", Rect2i(0, 0, 3, 2), 4, 3)
	var chains := GROWTH.face_chains(mass, Callable(FIXTURE, "nothing_solid"), Callable(FIXTURE, "street"))
	var profile: Array[float] = [1.0, 2.0, 2.0]
	for chain: Dictionary in chains:
		if int(chain.dir) == 3: # south: west end (right) wraps, east end (left) returns
			GROWTH.apply(mass, kit, chain, profile, [[&"return", &"wrap"], [&"return", &"wrap"], [&"return", &"wrap"]])
		elif int(chain.dir) == 2: # west: south end (left) wraps, north end returns
			GROWTH.apply(mass, kit, chain, profile, [[&"wrap", &"return"], [&"wrap", &"return"], [&"wrap", &"return"]])
	return {"kit": kit, "mass": mass, "parts": BuildingKitAssembler.new(kit).assemble(mass)}


## Parts of one storey: their centre lies between its floor and the next floor (the
## storeys above and below drop their walls 0.14 and lay their squares 0.13 from
## the floor plane, so a window on the box bottom would catch theirs too).
func _within(parts: Array, prefix: String, y0: float) -> Array:
	var catalog := EnvironmentCatalog.load_default()
	return parts.filter(func(p: Dictionary) -> bool:
		var box: AABB = p.transform * catalog.descriptor(p.asset_id).measured_aabb
		var y := box.get_center().y
		return String(p.role).begins_with(prefix) and y >= y0 - 0.02 and y <= y0 + 2.98)


func test_a_wrapped_corner_is_closed_by_strips_squares_and_a_post() -> void:
	var w := _wrapped_pair()
	var catalog := EnvironmentCatalog.load_default()
	for index in range(1, 4):
		var lean := minf(float(index), 2.0)
		var suffix := BuildingKitAssembler.lean_suffix(lean)
		var y0 := float((w.mass as BuildingMass).storeys[index].floor_band) * 1.5
		assert_eq(_within(w.parts, "frontage.corner." + suffix, y0).size(), 2,
			"floor and ceiling square at the one wrapped (south-west) corner")
		assert_eq(_within(w.parts, "frontage.return." + suffix, y0).size(), 4,
			"two side returns (the open ends) and two extension strips (the wrapped ends)")
		var posts := _within(w.parts, "post.timber", y0).filter(func(p: Dictionary) -> bool:
			var c: Vector3 = (p.transform * catalog.descriptor(p.asset_id).measured_aabb).get_center()
			return absf(c.x + lean) < 0.3 and absf(c.z + lean) < 0.3)
		assert_eq(posts.size(), 1, "one post at the moved south-west corner (-lean, -lean)")
		for square: Dictionary in _within(w.parts, "frontage.corner." + suffix, y0):
			var box: AABB = square.transform * catalog.descriptor(square.asset_id).measured_aabb
			assert_almost_eq(box.position.x, -lean, 0.01)
			assert_almost_eq(box.end.x, 0.0, 0.01)
			assert_almost_eq(box.position.z, -lean, 0.01)
			assert_almost_eq(box.end.z, 0.0, 0.01)


func test_extension_strips_are_flush_with_their_face() -> void:
	var w := _wrapped_pair()
	var catalog := EnvironmentCatalog.load_default()
	var y0 := float((w.mass as BuildingMass).storeys[1].floor_band) * 1.5
	var south_face := INF
	for part: Dictionary in _within(w.parts, "wall.timber.", y0):
		var box: AABB = part.transform * catalog.descriptor(part.asset_id).measured_aabb
		if box.get_center().z < -0.5 and box.size.x > box.size.z:
			south_face = minf(south_face, box.position.z)
	assert_lt(south_face, 0.0, "found the stepped south wall panels")
	var strips := _within(w.parts, "frontage.return.d100", y0).filter(func(p: Dictionary) -> bool:
		var box: AABB = p.transform * catalog.descriptor(p.asset_id).measured_aabb
		return box.size.x > box.size.z and box.get_center().x < 0.0 and box.get_center().z < 0.0)
	assert_eq(strips.size(), 1, "the south face's strip running on past the west corner")
	var strip: AABB = strips[0].transform * catalog.descriptor(strips[0].asset_id).measured_aabb
	assert_almost_eq(strip.position.z, south_face, 0.01, "outer faces coplanar")
	assert_almost_eq(strip.position.x, -1.0, 0.02, "it runs the step's depth past the old corner")


func test_right_extend_is_zero_without_growth() -> void:
	var mass := FIXTURE.house(&"kit.plain", Rect2i(0, 0, 3, 2), 3, 3)
	for storey: Dictionary in mass.storeys:
		for slot: Dictionary in BuildingKitAssembler.storey_slots(storey):
			assert_eq(float(slot.right_extend), 0.0)
