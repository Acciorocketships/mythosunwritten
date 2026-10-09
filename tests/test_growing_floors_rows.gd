extends GutTest
## Terrace rows under step-in (spec amendment Decision 4a, Amendment 2).
const FIXTURE := preload("res://tests/fixtures/growing_house.gd")
const GROWTH := preload("res://scripts/terrain/features/villages/kit/KitGrowingFronts.gd")


func _record(f: Dictionary, host: StringName, band: int) -> Dictionary:
	for lean: Dictionary in f.leans:
		if lean.host == host and int(lean.dir) == 3 and int(lean.band) == band:
			return lean
	return {}


func _row() -> Dictionary:
	# front (x 0..2) and side (x 3..4) share the south line z = 0; the front's west face
	# is kept out of the front, so the row is just the two south faces.
	var side := FIXTURE.roofed(&"kit.fixture.side", Rect2i(3, 0, 2, 2), 4, 3)
	var f := FIXTURE.build({"extra": [side], "block": [2]})
	f["side"] = side
	return f


func test_a_terrace_row_steps_in_as_one() -> void:
	var f := _row()
	assert_false(f.side.grows, "the neighbour did not roll growth: the row pulled it")
	assert_eq(FIXTURE.leans_on(f.front, 3), [-2.0, -1.0, 0.0, 0.0] as Array[float])
	assert_eq(FIXTURE.leans_on(f.side, 3), [-2.0, -1.0, 0.0, 0.0] as Array[float])
	for band: int in [0, 2, 4]:
		assert_eq(_record(f, &"kit.fixture.front", band).closures, [&"joint", &"return"],
			"front: east end joined, west end open (band %d)" % band)
		assert_eq(_record(f, &"kit.fixture.side", band).closures, [&"return", &"joint"],
			"side: east end open, west end joined (band %d)" % band)


func test_row_ends_close_only_at_the_open_ends() -> void:
	var f := _row()
	var catalog := EnvironmentCatalog.load_default()
	var assembler := BuildingKitAssembler.new(f.kit)
	assembler.external_blocked = func(cell: Vector2i, band: int) -> bool:
		return bool(f.solid.call(&"fixture.side", cell, band))
	var parts: Array = (f.parts as Array) + assembler.assemble(f.side)
	for part: Dictionary in parts:
		var role := String(part.role)
		if not (role.begins_with("frontage.") or role.begins_with("bracket.")):
			continue
		var box: AABB = part.transform * catalog.descriptor(part.asset_id).measured_aabb
		assert_false(absf(box.get_center().x - 6.0) < 0.3 and box.get_center().z > 0.0
			and String(part.role).begins_with("frontage.return"), "no return piece at the shared joint x = 6")
	var strips := parts.filter(func(p: Dictionary) -> bool: return String(p.role) == "frontage.return.d100")
	assert_eq(strips.size(), 2, "the two open row ends' corner panels on storey 1 (the ground's are dropped)")
	var joint_braces := parts.filter(func(p: Dictionary) -> bool:
		var box: AABB = p.transform * catalog.descriptor(p.asset_id).measured_aabb
		return p.role == &"bracket.jetty" and absf(box.get_center().x - 6.0) < 0.3 and box.end.y < 3.1)
	assert_eq(joint_braces.size(), 1, "one brace at the row joint under storey 1, not one per house")


func test_a_row_member_with_a_portal_holds_the_row_below_it() -> void:
	# The neighbour's second upper storey carries a portal: it may not overhang, so the
	# whole row holds one jetty (both houses step in one jetty at the ground).
	var side := FIXTURE.roofed(&"kit.fixture.side", Rect2i(3, 0, 2, 2), 4, 3)
	var edge := BuildingMass.edge_key(Vector2i(3, 0), 3)
	side.storeys[2].openings[edge] = BuildingMass.OPENING_DOOR
	side.storeys[2]["passage_edges"] = {edge: true}
	var f := FIXTURE.build({"extra": [side], "block": [2]})
	assert_eq(FIXTURE.leans_on(f.front, 3), [-1.0, 0.0, 0.0, 0.0] as Array[float])
	assert_eq(FIXTURE.leans_on(side, 3), [-1.0, 0.0, 0.0, 0.0] as Array[float])


## Ruling (a): an end beside a touching neighbour that does not step with it (here the
## neighbour's ground storey carries a passage and leaves the row) closes with the
## front's own baked return strip on the party plane; the neighbour's facade is left
## whole. Both houses still build.
func test_an_end_beside_a_touching_neighbour_closes_on_the_party_plane() -> void:
	var side := FIXTURE.roofed(&"kit.fixture.side", Rect2i(3, 0, 2, 2), 4, 1)
	var edge := BuildingMass.edge_key(Vector2i(3, 0), 3)
	side.storeys[0].openings[edge] = BuildingMass.OPENING_DOOR
	side.storeys[0]["passage_edges"] = {edge: true}
	var catalog := EnvironmentCatalog.load_default()
	var box := func(p: Dictionary) -> AABB: return p.transform * catalog.descriptor(p.asset_id).measured_aabb
	var plain := BuildingKitAssembler.new(SuntailBuildingKit.create())
	var facade := func(parts: Array) -> Array:
		var out := (parts.filter(func(p: Dictionary) -> bool:
			var b: AABB = box.call(p)
			return String(p.role).begins_with("wall.") and b.get_center().x > 6.0 and b.get_center().z < 0.5)
			).map(func(p: Dictionary) -> String: return "%s %s" % [p.asset_id, p.transform])
		out.sort()
		return out
	var before: Array = facade.call(plain.assemble(side))
	var f := FIXTURE.build({"extra": [side], "block": [2]})
	assert_eq(FIXTURE.leans_on(f.front, 3), [-2.0, -1.0, 0.0, 0.0] as Array[float])
	assert_eq(FIXTURE.leans_on(side, 3), [0.0, 0.0, 0.0, 0.0] as Array[float])
	for band: int in [0, 2]:
		assert_eq(_record(f, &"kit.fixture.front", band).closures[0], &"abut", "east end, band %d" % band)
	for depth: float in [2.0, 1.0]:
		var strips := (f.parts as Array).filter(func(p: Dictionary) -> bool:
			return String(p.role) == "frontage.return.%s" % BuildingKitAssembler.lean_suffix(depth) \
				and absf((box.call(p) as AABB).get_center().x - 6.0) < 0.3)
		assert_eq(strips.size(), 1, "one strip of depth %.1f on the party plane x = 6" % depth)
		assert_lt((box.call(strips[0]) as AABB).end.x, 6.0 + f.kit.wall_face + FIXTURE.GROWTH.TOUCH,
			"it stands on our side of the party plane (within a wall face)")
	assert_eq(facade.call(plain.assemble(side)), before, "the neighbour's facade is not cut")
	assert_false((f.parts as Array).is_empty(), "the house still builds")


func test_rows_join_only_on_the_same_first_upper_storey() -> void:
	var side := FIXTURE.roofed(&"kit.fixture.side", Rect2i(3, 0, 2, 2), 4, 3)
	for storey: Dictionary in side.storeys:
		storey.floor_band = int(storey.floor_band) + 1 # the neighbour stands half a storey up
	side.ground_band = 1
	var none := Callable(FIXTURE, "nothing_solid")
	var street := Callable(FIXTURE, "street")
	var members: Array[Dictionary] = []
	for mass: BuildingMass in [FIXTURE.house(&"kit.fixture.front", Rect2i(0, 0, 3, 2), 4, 3), side]:
		for chain: Dictionary in GROWTH.face_chains(mass, none, street):
			if int(chain.dir) == 3:
				members.append({"mass": mass, "chain": chain, "kit": null, "seed": true})
	assert_eq(GROWTH.fronts(members).size(), 2, "different first bands: two fronts, no joint")
