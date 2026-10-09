extends GutTest
## Growing-floor guardrails under step-in (spec docs/superpowers/specs/2026-10-08-growing-upper-floors-design.md, Amendment 2).
## Each guardrail withdraws only the failing step, never a house.
const FIXTURE := preload("res://tests/fixtures/growing_house.gd")
const UNION := preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd")


func _open(box: AABB) -> Dictionary:
	var volume := UNION.box_volume(box)
	volume["open"] = true
	return volume


func test_walking_air_withdraws_only_the_step_it_reaches() -> void:
	# A passage's headroom inside the house, where the braces under storey 2 would hang
	# (y 5..6, between storey 1's stepped-in face z 1 and the lot line).
	var air: Array[Dictionary] = [_open(AABB(Vector3(-1, 5.2, 0.2), Vector3(8, 0.6, 0.6)))]
	var f := FIXTURE.build({"lone": true, "air": air})
	assert_eq(FIXTURE.leans_on(f.front, 3), [-1.0, 0.0, 0.0, 0.0] as Array[float],
		"the second step is withdrawn (the cap drops one step)")


func test_insets_never_narrow_the_lane() -> void:
	# Two growing houses facing across a one-cell lane, with a sky gap larger than the
	# lane: under step-in the upper storeys stay on their lot lines, so G2 cannot fire.
	for gap: float in [0.75, 2.75]:
		var f := FIXTURE.build({"lone": true, "facing": true, "back_grows": true,
			"character": FIXTURE.character({&"lane_sky_gap": gap})})
		assert_eq(FIXTURE.leans_on(f.front, 3), [-2.0, -1.0, 0.0, 0.0] as Array[float], "gap %.2f" % gap)
		# The facing house is not kept lone: its pulled east and west faces may hold it
		# at one jetty (bearing), but it only ever steps in, and its top stays on its line.
		var back := FIXTURE.leans_on(f.back, 1)
		assert_lt(back[0], 0.0, "the facing house steps in too")
		assert_eq(back[3], 0.0, "its top storey stays on the lot line")
		for value: float in back:
			assert_true(value <= 0.0)
		assert_false((f.result.rejections as Array).any(func(r: Dictionary) -> bool: return r.cause == &"gap"))


func test_neighbouring_feature_withdraws_only_the_step_it_reaches() -> void:
	var towers: Array[Dictionary] = [{"bounds": AABB(Vector3(-1, 5.2, 0.2), Vector3(8, 0.6, 0.6))}]
	var f := FIXTURE.build({"lone": true, "towers": towers})
	assert_eq(FIXTURE.leans_on(f.front, 3), [-1.0, 0.0, 0.0, 0.0] as Array[float])


func test_a_reserved_recess_keeps_the_face_flush() -> void:
	# A passage claim through the ground storey's front row: it cannot step in at all.
	var f := FIXTURE.build({"lone": true, "reserved": func(_own: StringName, cell: Vector2i, band: int) -> bool:
		return cell.y == 0 and band <= 1})
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 0.0, 0.0, 0.0] as Array[float],
		"the ground cannot stand in, so no storey above may overhang it")


func test_footprint_change_ends_the_face_chain() -> void:
	var mass := FIXTURE.house(&"kit.fixture.front", Rect2i(0, 0, 3, 2), 4, 3)
	mass.add_roof(Rect2i(0, 0, 3, 2), 1, 8, &"red")["union_index"] = 0
	mass.storeys[2].cells.erase(Vector2i(2, 0))
	var chains := FIXTURE.GROWTH.face_chains(mass, Callable(FIXTURE, "nothing_solid"), Callable(FIXTURE, "street"))
	var south := chains.filter(func(c: Dictionary) -> bool: return int(c.dir) == 3 and int(c.line) == 0)
	assert_eq(south.size(), 1)
	assert_eq((south[0].storeys as Array).size(), 1, "storey 2's run differs from storey 1's")
	var f := FIXTURE.build({"lone": true, "replace_front": mass})
	assert_eq(FIXTURE.leans_on(f.front, 3), [-1.0, 0.0, 0.0, 0.0] as Array[float],
		"one storey in the chain: its top (storey 1) stays on the line, the ground steps one jetty in")


func _portal(front: BuildingMass) -> void:
	var edge := BuildingMass.edge_key(Vector2i(1, 0), 3)
	front.storeys[2].openings[edge] = BuildingMass.OPENING_DOOR
	front.storeys[2]["passage_edges"] = {edge: true}


func test_skywalk_portal_storey_stays_on_the_lot_line() -> void:
	# Storey 2 carries a skywalk passage: it neither stands in nor overhangs, so the
	# cap drops until it stands on the line over a storey on the line; below it the
	# face still steps in.
	var f := FIXTURE.build({"lone": true, "prepare": _portal})
	assert_eq(FIXTURE.leans_on(f.front, 3), [-1.0, 0.0, 0.0, 0.0] as Array[float])
	var causes := (f.result.rejections as Array).map(func(r: Dictionary) -> StringName: return r.cause)
	assert_true(causes.has(&"portal"), str(causes))
	# A skywalk on the top storey costs nothing: the top never moves.
	var g := FIXTURE.build({"lone": true, "prepare": func(front: BuildingMass) -> void:
		var edge := BuildingMass.edge_key(Vector2i(1, 0), 3)
		front.storeys[3].openings[edge] = BuildingMass.OPENING_DOOR
		front.storeys[3]["passage_edges"] = {edge: true}})
	assert_eq(FIXTURE.leans_on(g.front, 3), [-2.0, -1.0, 0.0, 0.0] as Array[float])


func test_a_ground_storey_against_a_lower_neighbour_keeps_the_face_flush() -> void:
	# A one-storey neighbour touches the ground storey's south face: a party wall never
	# steps in, so no storey above may overhang it.
	var low := FIXTURE.house(&"kit.fixture.low", Rect2i(0, -1, 3, 1), 1, 3)
	var f := FIXTURE.build({"lone": true, "extra": [low]})
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 0.0, 0.0, 0.0] as Array[float])
	var causes := (f.result.rejections as Array).map(func(r: Dictionary) -> StringName: return r.cause)
	assert_true(causes.has(&"party"), str(causes))


func test_a_bay_keeps_its_storey_on_the_lot_line() -> void:
	# A bay on a stepped-in run would stand under the overhang's braces: storey 1 keeps
	# the line (the cap drops to one light step), the ground still steps in under it.
	var f := FIXTURE.build({"lone": true, "character": FIXTURE.character({}, &"0.5"),
		"prepare": func(front: BuildingMass) -> void:
			front.storeys[1].openings[BuildingMass.edge_key(Vector2i(1, 0), 3)] = BuildingMass.OPENING_BAY})
	assert_eq(FIXTURE.leans_on(f.front, 3), [-0.5, 0.0, 0.0, 0.0] as Array[float])
	var catalog := EnvironmentCatalog.load_default()
	var bays := (f.parts as Array).filter(func(p: Dictionary) -> bool: return String(p.role).begins_with("bay."))
	assert_eq(bays.size(), 1)
	assert_lt((bays[0].transform * catalog.descriptor(bays[0].asset_id).measured_aabb).get_center().z, 0.0,
		"the bay stands on the lot-line face")


func test_dressing_on_a_stepped_in_run_moves_in_or_yields() -> void:
	var f := FIXTURE.build({"lone": true, "prepare": func(front: BuildingMass) -> void:
		front.decor.append({"kind": &"ivy", "centre": Vector2(1.5, 0.0), "dir": 3, "y": 0.0, "proud": 0.0})
		front.decor.append({"kind": &"window_box", "centre": Vector2(0.5, 0.0), "dir": 3, "y": 3.0})})
	assert_eq(FIXTURE.leans_on(f.front, 3), [-2.0, -1.0, 0.0, 0.0] as Array[float])
	for item: Dictionary in f.front.decor:
		if int(item.get("dir", -1)) == 3 and item.kind in [&"ivy", &"window_box"]:
			var expected := 1.0 if float(item.y) < 3.0 else 0.5 # its storey's offset / -2, cells
			assert_almost_eq((item.centre as Vector2).y, expected, 1e-6,
				"%s moved in with its wall (or yielded)" % item.kind)


func test_withdrawn_steps_name_their_guardrail() -> void:
	var f := FIXTURE.build({"lone": true, "reserved": func(_own: StringName, cell: Vector2i, band: int) -> bool:
		return cell.y == 0 and band <= 1})
	var columns := (f.result.rejections as Array).filter(func(r: Dictionary) -> bool: return r.cause == &"columns")
	assert_gt(columns.size(), 0, str(f.result.rejections))
	for record: Dictionary in columns:
		assert_eq(int(record.storey), -1, "the ground storey")
		assert_true(float(record.lean) in [-2.0, -1.0], "at its offset for the cap tried: %s" % record)


## Moved dressing stands somewhere else: its obstacle records are replaced, so a later
## step (another face of the house) tests against where it now is.
func test_moved_decor_refreshes_its_obstacles() -> void:
	var kit := SuntailBuildingKit.create()
	var catalog := EnvironmentCatalog.load_default()
	var mass := FIXTURE.house(&"kit.fixture.front", Rect2i(0, 0, 3, 2), 3, 1)
	var box := {"kind": &"window_box", "centre": Vector2(1.5, 0.0), "dir": 3, "y": 3.0}
	mass.decor.append(box)
	var none := Callable(FIXTURE, "nothing_solid")
	var masses: Array[BuildingMass] = [mass]
	var chain: Dictionary = FIXTURE.GROWTH.face_chains(mass, none, Callable(FIXTURE, "street")).filter(
		func(c: Dictionary) -> bool: return int(c.dir) == 3)[0]
	var member := {"mass": mass, "chain": chain, "kit": kit, "seed": true}
	var ctx := {"catalog": catalog, "air": [] as Array[Dictionary], "towers": [] as Array[Dictionary],
		"reserved": none, "solid": none, "kit": kit, "rejections": [], "yields": {}, "planned": {},
		"front": {"members": [member], "joins": []}, "active": [0] as Array[int],
		"obstacles": FIXTURE.GROWTH._obstacles(masses, {&"fixture.front": kit}, kit, catalog, [], none)}
	var out: Array[Dictionary] = []
	var closures := [[&"return", &"return"], [&"return", &"return"], [&"return", &"return"]]
	FIXTURE.GROWTH._commit(member, [1.0, 2.0] as Array[float], closures, ctx, out)
	assert_almost_eq((box.centre as Vector2).y, 0.5, 1e-6, "the window box moved in with storey 1 (-1.0)")
	var live := (ctx.obstacles as Array).filter(func(o: Dictionary) -> bool:
		return o.has("decor") and is_same(o.decor, box) and not bool(o.get("gone", false)))
	assert_gt(live.size(), 0)
	for obstacle: Dictionary in live:
		assert_gt((obstacle.bounds as AABB).get_center().z, 0.0, "obstacle at the moved box")


func test_gap_ok_measures_to_the_facing_lean() -> void:
	var kit := SuntailBuildingKit.create()
	var edges: Array[Vector3i] = [BuildingMass.edge_key(Vector2i(0, 0), 3)]
	var solid := func(_own: StringName, cell: Vector2i, _band: int) -> bool: return cell.y == -3
	var registry := {Vector4i(0, -3, 1, 4): 0.75}
	assert_true(FIXTURE.GROWTH.gap_ok(registry, solid, &"a", edges, 3, 4, 0.5, kit, 2.75))
	assert_false(FIXTURE.GROWTH.gap_ok(registry, solid, &"a", edges, 3, 4, 0.75, kit, 2.75))
	assert_true(FIXTURE.GROWTH.gap_ok({}, solid, &"a", edges, 3, 4, 0.75, kit, 2.75),
		"an unleaned facing facade leaves 4.0 - 0.75")


func test_face_over_a_lower_neighbour_is_a_candidate() -> void:
	# A one-storey neighbour covers the ground storey's south edges; the first upper
	# storey's south face is exposed and its edges are still boundary edges below.
	var mass := FIXTURE.house(&"kit.fixture.front", Rect2i(0, 0, 3, 2), 3, 1)
	var low := func(_own: StringName, cell: Vector2i, band: int) -> bool:
		return cell.y == -1 and band <= 1
	var south := FIXTURE.GROWTH.face_chains(mass, low, Callable(FIXTURE, "street")).filter(
		func(c: Dictionary) -> bool: return int(c.dir) == 3)
	assert_eq(south.size(), 1)
	assert_eq((south[0].storeys as Array).size(), 2)
	assert_eq(int(south[0].first_band), 2)


func test_contact_under_five_centimetres_is_touching() -> void:
	var a := AABB(Vector3.ZERO, Vector3.ONE)
	assert_true(FIXTURE.GROWTH.contact_clear(a, AABB(Vector3(0.97, 0, 0), Vector3.ONE)), "3 cm")
	assert_false(FIXTURE.GROWTH.contact_clear(a, AABB(Vector3(0.94, 0, 0), Vector3.ONE)), "6 cm")
	assert_true(FIXTURE.GROWTH.contact_clear(a, AABB(Vector3(2, 0, 0), Vector3.ONE)), "apart")
