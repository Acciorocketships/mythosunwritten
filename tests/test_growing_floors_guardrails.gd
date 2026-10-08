extends GutTest
## Growing-floor guardrails 1-6 (spec docs/superpowers/specs/2026-10-08-growing-upper-floors-design.md).
## Each guardrail withdraws only the failing step, never a house.
const FIXTURE := preload("res://tests/fixtures/growing_house.gd")
const UNION := preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd")


func _open(box: AABB) -> Dictionary:
	var volume := UNION.box_volume(box)
	volume["open"] = true
	return volume


func test_walking_air_withdraws_only_the_storey_it_reaches() -> void:
	# A landing's headroom in front of the second upper storey (band 4, y 6..9),
	# between the 1.0 and 2.0 planes.
	var air: Array[Dictionary] = [_open(AABB(Vector3(-1, 6.2, -1.9), Vector3(8, 0.8, 0.45)))]
	var f := FIXTURE.build({"air": air})
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 1.0, 1.0, 1.0] as Array[float],
		"the 2.0 step is withdrawn; storeys above keep 1.0")


func test_sky_gap_withdraws_only_the_later_houses_failing_step() -> void:
	# A three-cell (6.0 native m) lane with a 2.75 m sky gap.
	var f := FIXTURE.build({"facing": true, "back_grows": true, "lane": 3,
		"character": FIXTURE.character({&"lane_sky_gap": 2.75})})
	assert_eq(FIXTURE.leans_on(f.back, 1), [0.0, 1.0, 2.0, 2.0] as Array[float],
		"the earlier house in sorted order sees an unleaned facade (6 - 2 = 4)")
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 1.0, 1.0, 1.0] as Array[float],
		"6 - 2 - 2 < 2.75 withdraws the second step; 6 - 1 - 2 = 3 holds")
	for index in range(1, 4):
		var gap := 6.0 - FIXTURE.leans_on(f.front, 3)[index] - FIXTURE.leans_on(f.back, 1)[index]
		assert_true(gap >= 2.75 - 1e-4, "storey %d keeps the lane's sky slot" % index)


func test_gap_ok_measures_to_the_facing_lean() -> void:
	var kit := SuntailBuildingKit.create()
	var edges: Array[Vector3i] = [BuildingMass.edge_key(Vector2i(0, 0), 3)]
	var solid := func(_own: StringName, cell: Vector2i, _band: int) -> bool: return cell.y == -3
	var registry := {Vector4i(0, -3, 1, 4): 0.75}
	assert_true(FIXTURE.GROWTH.gap_ok(registry, solid, &"a", edges, 3, 4, 0.5, kit, 2.75))
	assert_false(FIXTURE.GROWTH.gap_ok(registry, solid, &"a", edges, 3, 4, 0.75, kit, 2.75))
	assert_true(FIXTURE.GROWTH.gap_ok({}, solid, &"a", edges, 3, 4, 0.75, kit, 2.75),
		"an unleaned facing facade leaves 4.0 - 0.75")


func test_neighbouring_feature_withdraws_only_the_storey_it_reaches() -> void:
	var towers: Array[Dictionary] = [{"bounds": AABB(Vector3(-1, 6.2, -1.9), Vector3(8, 0.8, 0.45))}]
	var f := FIXTURE.build({"towers": towers})
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 1.0, 1.0, 1.0] as Array[float])


func test_reserved_column_keeps_the_face_flush() -> void:
	var f := FIXTURE.build({"reserved": func(_own: StringName, cell: Vector2i, band: int) -> bool:
		return cell.y == -1 and band >= 6})
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 0.0, 0.0, 0.0] as Array[float],
		"a storey that cannot lean at all pins the face (no inward ledge below it)")


func test_neighbour_at_a_face_end_keeps_the_face_flush() -> void:
	var neighbour := FIXTURE.house(&"kit.fixture.side", Rect2i(3, 0, 1, 2), 4, 0)
	var f := FIXTURE.build({"extra": [neighbour]})
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 0.0, 0.0, 0.0] as Array[float],
		"the face run is not wholly exposed, so its returns would meet the neighbour")


# Guardrail 5 is the face-chain walk itself (Task 1), so this test passes before
# the other guardrails exist: it pins the footprint rule, it is not red-first.
func test_footprint_change_ends_the_face_chain() -> void:
	var mass := FIXTURE.house(&"kit.fixture.front", Rect2i(0, 0, 3, 2), 4, 3)
	mass.add_roof(Rect2i(0, 0, 3, 2), 1, 8, &"red")["union_index"] = 0
	mass.storeys[2].cells.erase(Vector2i(2, 0))
	var chains := FIXTURE.GROWTH.face_chains(mass, Callable(FIXTURE, "nothing_solid"), Callable(FIXTURE, "street"))
	var south := chains.filter(func(c: Dictionary) -> bool: return int(c.dir) == 3 and int(c.line) == 0)
	assert_eq(south.size(), 1)
	assert_eq((south[0].storeys as Array).size(), 1, "storey 2's run differs from storey 1's")
	var f := FIXTURE.build({"replace_front": mass})
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 1.0, 0.0, 0.0] as Array[float],
		"only the storey whose footprint matches the one below leans")


func _portal(front: BuildingMass) -> void:
	var edge := BuildingMass.edge_key(Vector2i(1, 0), 3)
	front.storeys[2].openings[edge] = BuildingMass.OPENING_DOOR
	front.storeys[2]["passage_edges"] = {edge: true}


func test_skywalk_portal_face_never_leans_but_other_face_does() -> void:
	# Only the street face is a candidate: the portal alone keeps it flush.
	var f := FIXTURE.build({"prepare": _portal})
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 0.0, 0.0, 0.0] as Array[float])
	# The house itself is not withdrawn: with every face a candidate another face
	# grows. Faces fit in key order, so the east face (0:...) grows first and,
	# by guardrail 4, keeps its perpendicular neighbours flush.
	var g := FIXTURE.build({"prepare": _portal,
		"character": FIXTURE.character({&"growth_other_face_chance": 1.0})})
	assert_gt(FIXTURE.leans_on(g.front, 0)[1], 0.0, "another face of the house still grows")
	assert_eq(FIXTURE.leans_on(g.front, 3), [0.0, 0.0, 0.0, 0.0] as Array[float])


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


func test_own_bay_on_the_stepping_face_moves_with_it() -> void:
	# Light steps: a 0.5 face passes through the bay's old plane, which used to block.
	var f := FIXTURE.build({"character": FIXTURE.character({}, &"0.5"),
		"prepare": func(front: BuildingMass) -> void:
			front.storeys[1].openings[BuildingMass.edge_key(Vector2i(1, 0), 3)] = BuildingMass.OPENING_BAY})
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 0.5, 1.0, 1.5] as Array[float])
	var catalog := EnvironmentCatalog.load_default()
	var bays := (f.parts as Array).filter(func(p: Dictionary) -> bool: return String(p.role).begins_with("bay."))
	assert_eq(bays.size(), 1)
	assert_lt((bays[0].transform * catalog.descriptor(bays[0].asset_id).measured_aabb).get_center().z, -0.5,
		"the bay stands on the stepped face (0.5 out), not the old plane")


func test_own_ornaments_under_the_new_braces_yield() -> void:
	var f := FIXTURE.build({"prepare": func(front: BuildingMass) -> void:
		front.decor.append({"kind": &"ivy", "centre": Vector2(1.5, 0.0), "dir": 3, "y": 0.0,
			"proud": 0.0})})
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 1.0, 2.0, 2.0] as Array[float])
	assert_false(f.front.decor.any(func(d: Dictionary) -> bool: return d.kind == &"ivy"),
		"the ground-storey ivy under the first brace is removed, not a blocker")


func test_withdrawn_steps_name_their_guardrail() -> void:
	var f := FIXTURE.build({"reserved": func(_own: StringName, cell: Vector2i, band: int) -> bool:
		return cell.y == -1 and band >= 6})
	var causes := (f.result.rejections as Array).map(func(r: Dictionary) -> StringName: return r.cause)
	assert_true(causes.has(&"columns"), str(causes))
