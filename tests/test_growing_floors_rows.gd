extends GutTest
## Terrace rows (spec amendment Decision 4a).
const FIXTURE := preload("res://tests/fixtures/growing_house.gd")
const GROWTH := preload("res://scripts/terrain/features/villages/kit/KitGrowingFronts.gd")


func _record(f: Dictionary, host: StringName, band: int) -> Dictionary:
	for lean: Dictionary in f.leans:
		if lean.host == host and int(lean.dir) == 3 and int(lean.band) == band:
			return lean
	return {}


func _row() -> Dictionary:
	# front (x 0..2) and side (x 3..4) share the south line z = 0; the columns west of
	# the row (x -1) and east of it (x 5) are reserved, so the row is just the two faces.
	var side := FIXTURE.roofed(&"kit.fixture.side", Rect2i(3, 0, 2, 2), 4, 3)
	var f := FIXTURE.build({"extra": [side], "reserved_x": [-1, 5]})
	f["side"] = side
	return f


func test_a_terrace_row_steps_out_as_one() -> void:
	var f := _row()
	assert_false(f.side.grows, "the neighbour did not roll growth: the row pulled it")
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 1.0, 2.0, 2.0] as Array[float])
	assert_eq(FIXTURE.leans_on(f.side, 3), [0.0, 1.0, 2.0, 2.0] as Array[float])
	for band: int in [2, 4, 6]:
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
		if not String(part.role).begins_with("frontage.return."):
			continue
		var box: AABB = part.transform * catalog.descriptor(part.asset_id).measured_aabb
		assert_false(absf(box.get_center().x - 6.0) < 0.3, "no return at the shared joint x = 6")
	var returns := parts.filter(func(p: Dictionary) -> bool:
		return String(p.role).begins_with("frontage.return.") and not String(p.role).begins_with("frontage.return_beam"))
	assert_eq(returns.size(), 6, "two open row ends x three stepped storeys")


func test_a_row_member_that_cannot_step_withdraws_the_joint_not_the_town() -> void:
	# The neighbour's second upper storey carries a portal: it cannot step, so the row
	# cannot either (the front's end would return into the neighbour's flush facade).
	var side := FIXTURE.roofed(&"kit.fixture.side", Rect2i(3, 0, 2, 2), 4, 3)
	var edge := BuildingMass.edge_key(Vector2i(3, 0), 3)
	side.storeys[2].openings[edge] = BuildingMass.OPENING_DOOR
	side.storeys[2]["passage_edges"] = {edge: true}
	var f := FIXTURE.build({"extra": [side], "reserved_x": [-1, 5]})
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 0.0, 0.0, 0.0] as Array[float])
	assert_eq(FIXTURE.leans_on(side, 3), [0.0, 0.0, 0.0, 0.0] as Array[float])
	assert_false((f.parts as Array).is_empty(), "the house still builds")
	var causes := (f.result.rejections as Array).map(func(r: Dictionary) -> StringName: return r.cause)
	assert_true(causes.has(&"portal") and causes.has(&"ends"), str(causes))


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
