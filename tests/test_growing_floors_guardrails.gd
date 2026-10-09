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


## Ruling (e, fix round 2): grade(cell, dir, band) -> 2 = the ground outside the face
## stands at the floor (whole boards: the walk to the door); 1 = off grade, but the strip
## the step vacates stands on solid bearing (retained stone / massif top): the boards are
## trimmed to the wall and a stone cap closes the strip (the plinth's top); 0 = air or a
## public walk below the strip: the face stays flush (cause grade).
func test_a_ground_storey_over_air_keeps_the_face_flush() -> void:
	var f := FIXTURE.build({"lone": true, "grade": func(_cell: Vector2i, _dir: int, _band: int) -> int: return 0})
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 0.0, 0.0, 0.0] as Array[float])
	var causes := (f.result.rejections as Array).map(func(r: Dictionary) -> StringName: return r.cause)
	assert_true(causes.has(&"grade"), str(causes))
	var g := FIXTURE.build({"lone": true, "grade": func(_cell: Vector2i, _dir: int, _band: int) -> int: return 2})
	assert_eq(FIXTURE.leans_on(g.front, 3), [-2.0, -1.0, 0.0, 0.0] as Array[float], "the lane at its floor")
	assert_eq(_ground_boards(g, 0).size(), 3, "at grade the ground keeps its whole boards on the south row")


## The whole ground-storey boards of the cells in row z = `row`.
func _ground_boards(f: Dictionary, row: int) -> Array:
	var catalog := EnvironmentCatalog.load_default()
	return (f.parts as Array).filter(func(p: Dictionary) -> bool:
		var box: AABB = p.transform * catalog.descriptor(p.asset_id).measured_aabb
		return p.role == &"deck.board" and box.get_center().y < 0.5 and floori(box.get_center().z / 2.0) == row)


func test_a_ground_storey_over_solid_bearing_steps_onto_a_stone_plinth_top() -> void:
	var f := FIXTURE.build({"lone": true, "grade": func(_cell: Vector2i, _dir: int, _band: int) -> int: return 1})
	assert_eq(FIXTURE.leans_on(f.front, 3), [-2.0, -1.0, 0.0, 0.0] as Array[float])
	assert_eq(_ground_boards(f, 0).size(), 0, "no whole board on the stepped-in row: no board ledge")
	var catalog := EnvironmentCatalog.load_default()
	var caps := (f.parts as Array).filter(func(p: Dictionary) -> bool: return p.role == &"plinth.cap")
	assert_gt(caps.size(), 0, "the vacated strip is capped in stone")
	for x: float in [1.0, 3.0, 5.0]:
		# The caps standing on this module's strip cover it from the lot line to the wall.
		var spans := caps.map(func(p: Dictionary) -> AABB: return p.transform * catalog.descriptor(p.asset_id).measured_aabb
			).filter(func(b: AABB) -> bool: return absf(b.get_center().x - x) < 0.5)
		assert_gt(spans.size(), 0, "x %.0f" % x)
		var reach := 0.0
		var sorted := spans.duplicate()
		sorted.sort_custom(func(a: AABB, b: AABB) -> bool: return a.position.z < b.position.z)
		for b: AABB in sorted:
			assert_almost_eq(b.end.y, 0.128, 0.02, "its top is level with the floor boards (just under them)")
			# (the first row stands a centimetre or two inside the lot line: the podium skin's plane)
			assert_true(b.position.z <= reach + 0.02, "no gap in the cap at z %.2f (x %.0f)" % [reach, x])
			assert_true(b.position.z >= -0.01, "the cap stays inside the lot")
			reach = maxf(reach, b.end.z)
		assert_true(reach >= 2.0 - 0.01, "the cap reaches the stepped-in wall (x %.0f)" % x)


## Ruling (b): a designer bay on the corner panel a growing house's step cuts yields
## (it is dropped for that storey); the step is not withdrawn.
func test_a_bay_on_a_cut_corner_panel_yields_to_growth() -> void:
	var edge := BuildingMass.edge_key(Vector2i(2, 0), 0) # the east face's south panel, ground storey
	var f := FIXTURE.build({"lone": true, "prepare": func(front: BuildingMass) -> void:
		front.storeys[0].openings[edge] = BuildingMass.OPENING_BAY})
	assert_eq(FIXTURE.leans_on(f.front, 3), [-2.0, -1.0, 0.0, 0.0] as Array[float])
	assert_ne(StringName(f.front.storeys[0].openings.get(edge, f.front.storeys[0].default_opening)),
		BuildingMass.OPENING_BAY, "the bay is dropped")
	var catalog := EnvironmentCatalog.load_default()
	assert_false((f.parts as Array).any(func(p: Dictionary) -> bool:
		return String(p.role).begins_with("bay.") and (p.transform * catalog.descriptor(p.asset_id).measured_aabb).get_center().y < 3.0),
		"no bay left on the ground storey")
	# A door there still blocks the end (and so the step).
	var g := FIXTURE.build({"lone": true, "prepare": func(front: BuildingMass) -> void:
		front.storeys[0].openings[edge] = BuildingMass.OPENING_DOOR})
	assert_eq(FIXTURE.leans_on(g.front, 3), [0.0, 0.0, 0.0, 0.0] as Array[float])


## A dropped bay's obstacle records go with it (a later step must not meet a bay that
## is no longer built).
func test_a_dropped_bay_leaves_no_obstacle() -> void:
	var kit := SuntailBuildingKit.create()
	var catalog := EnvironmentCatalog.load_default()
	var mass := FIXTURE.house(&"kit.fixture.front", Rect2i(0, 0, 3, 2), 3, 1)
	mass.grows = true
	var edge := BuildingMass.edge_key(Vector2i(2, 0), 0)
	mass.storeys[0].openings[edge] = BuildingMass.OPENING_BAY
	# Another bay one module away on the east face: the step does not cut it.
	mass.storeys[0].openings[BuildingMass.edge_key(Vector2i(2, 1), 0)] = BuildingMass.OPENING_BAY
	var none := Callable(FIXTURE, "nothing_solid")
	var masses: Array[BuildingMass] = [mass]
	var chain: Dictionary = FIXTURE.GROWTH.face_chains(mass, none, Callable(FIXTURE, "street")).filter(
		func(c: Dictionary) -> bool: return int(c.dir) == 3)[0]
	var member := {"mass": mass, "chain": chain, "kit": kit, "seed": true}
	var ctx := {"catalog": catalog, "air": [] as Array[Dictionary], "towers": [] as Array[Dictionary],
		"reserved": none, "solid": none, "kit": kit, "rejections": [], "yields": {}, "planned": {},
		"front": {"members": [member], "joins": []}, "active": [0] as Array[int],
		"obstacles": FIXTURE.GROWTH._obstacles(masses, {&"fixture.front": kit}, kit, catalog, [], none)}
	var bays := func() -> Array: return (ctx.obstacles as Array).filter(func(o: Dictionary) -> bool:
		return String(o.role).begins_with("bay.") and not bool(o.get("gone", false)))
	var first: Array = bays.call()
	assert_true(first.any(func(o: Dictionary) -> bool: return (o.bounds as AABB).get_center().z < 2.0),
		"the cut designer bay is an obstacle before the step")
	var out: Array[Dictionary] = []
	var closures := [[&"return", &"return"], [&"return", &"return"], [&"return", &"return"]]
	FIXTURE.GROWTH._commit(member, [1.0, 2.0] as Array[float], closures, ctx, out)
	assert_ne(StringName(mass.storeys[0].openings.get(edge, mass.storeys[0].default_opening)), BuildingMass.OPENING_BAY)
	var live: Array = bays.call()
	assert_gt(live.size(), 0, "the other bay is still an obstacle")
	for obstacle: Dictionary in live:
		assert_gt((obstacle.bounds as AABB).get_center().z, 2.0, "only the north bay (z 2..4) is left: %s" % obstacle.bounds)


func _caps(f: Dictionary) -> Array:
	var catalog := EnvironmentCatalog.load_default()
	return (f.parts as Array).filter(func(p: Dictionary) -> bool: return p.role == &"plinth.cap").map(
		func(p: Dictionary) -> AABB: return p.transform * catalog.descriptor(p.asset_id).measured_aabb)


## Two boxes share a face plane facing the same way with an overlapping patch.
static func _coplanar(a: AABB, b: AABB) -> String:
	for axis in 3:
		var others: Array[int] = [(axis + 1) % 3, (axis + 2) % 3]
		var patch := true
		for o: int in others:
			patch = patch and minf(a.end[o], b.end[o]) - maxf(a.position[o], b.position[o]) > 0.001
		if not patch:
			continue
		if absf(a.position[axis] - b.position[axis]) < 0.001:
			return "min %d" % axis
		if absf(a.end[axis] - b.end[axis]) < 0.001:
			return "max %d" % axis
	return ""


## Review fix 3: no cap face shares a plane, facing the same way, with another stone
## face: the podium skin standing on the lot lines (x 0 / 6, z 0 / 4 here) or another
## cap row (the two faces' rows at a wrapped corner, a run's end rows and their
## neighbours). The front stays plinth-capped all round the wrapped corner.
func test_plinth_caps_share_no_face_plane_with_other_stone() -> void:
	var f := FIXTURE.build({"grade": func(_cell: Vector2i, _dir: int, _band: int) -> int: return 1})
	assert_eq(FIXTURE.leans_on(f.front, 3), [-1.0, 0.0, 0.0, 0.0] as Array[float])
	assert_eq(FIXTURE.leans_on(f.front, 2), [-1.0, 0.0, 0.0, 0.0] as Array[float], "west wraps")
	var caps := _caps(f)
	assert_gt(caps.size(), 0)
	for box: AABB in caps:
		for value: float in [box.position.x, box.end.x]:
			for line: float in [0.0, 6.0]:
				assert_true(absf(value - line) > 0.001, "a cap face on the lot line x %.0f: %s" % [line, box])
		for value: float in [box.position.z, box.end.z]:
			for line: float in [0.0, 4.0]:
				assert_true(absf(value - line) > 0.001, "a cap face on the lot line z %.0f: %s" % [line, box])
	for i in caps.size():
		for j in range(i + 1, caps.size()):
			var why := _coplanar(caps[i], caps[j])
			assert_eq(why, "", "coplanar cap faces (%s): %s / %s" % [why, caps[i], caps[j]])
	# The corner square (x, z 0..1) is capped.
	assert_true(caps.any(func(b: AABB) -> bool: return b.has_point(Vector3(0.5, b.get_center().y, 0.5))))


## Review fix 3: a kit without the stone cap cannot close an off-grade strip.
func test_a_kit_without_the_plinth_cap_withdraws_off_grade_steps() -> void:
	var kit := SuntailBuildingKit.create()
	kit.roles.erase(&"plinth.cap")
	var f := FIXTURE.build({"lone": true, "kit": kit,
		"grade": func(_cell: Vector2i, _dir: int, _band: int) -> int: return 1})
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 0.0, 0.0, 0.0] as Array[float])
	var causes := (f.result.rejections as Array).map(func(r: Dictionary) -> StringName: return r.cause)
	assert_true(causes.has(&"grade"), str(causes))


## Review fix 3: the plinth caps are stone below the floor; the shared floor placements
## (opening and walk fitting) never list them as floor.
func test_plinth_caps_are_not_inhabited_floor() -> void:
	var f := FIXTURE.build({"lone": true, "grade": func(_cell: Vector2i, _dir: int, _band: int) -> int: return 1})
	assert_gt(_caps(f).size(), 0)
	var floors := BuildingKitAssembler.new(f.kit).inhabited_floors(f.front)
	assert_gt(floors.size(), 0)
	assert_false(floors.any(func(p: Dictionary) -> bool: return p.role == &"plinth.cap"))

