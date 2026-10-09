extends GutTest
const FIXTURE := preload("res://tests/fixtures/growing_house.gd")
const GROWTH := preload("res://scripts/terrain/features/villages/kit/KitGrowingFronts.gd")
const PROJECTIONS := preload("res://scripts/terrain/features/villages/kit/KitRoomProjections.gd")
const BAYS := preload("res://scripts/terrain/features/villages/kit/KitTownFacadeBays.gd")


func test_each_lower_storey_steps_in_one_jetty_further() -> void:
	var f := FIXTURE.build({"lone": true})
	assert_eq(FIXTURE.leans_on(f.front, 3), [-2.0, -1.0, 0.0, 0.0] as Array[float],
		"the ground two kit jetties in, the first upper storey one, the top two on the lot line")
	assert_eq(FIXTURE.leans_on(f.front, 1), [0.0, 0.0, 0.0, 0.0] as Array[float],
		"the back face is not rolled (other-face chance 0 in the fixture)")
	for index in 4:
		for slot: Dictionary in BuildingKitAssembler.storey_slots(f.front.storeys[index]):
			if int(slot.dir) == 3:
				assert_almost_eq(float(slot.centre.y), -FIXTURE.leans_on(f.front, 3)[index] / 2.0, 1e-5,
					"offset in module units, storey %d" % index)
	assert_false(f.front.storeys[3].has("wall_offsets"), "the top storey stays on the lot line")


func test_cap_floors_to_whole_steps() -> void:
	var f := FIXTURE.build({"lone": true, "storeys": 5, "character": FIXTURE.character({&"growth_max_lean": 1.5})})
	assert_eq(FIXTURE.leans_on(f.front, 3), [-1.0, 0.0, 0.0, 0.0, 0.0] as Array[float])
	var g := FIXTURE.build({"lone": true, "storeys": 5, "character": FIXTURE.character({&"growth_max_lean": 2.0}, &"0.5")})
	assert_eq(FIXTURE.leans_on(g.front, 3), [-2.0, -1.5, -1.0, -0.5, 0.0] as Array[float])


## A storey's own front pieces: they start at its floor line (beams and floor strip a
## little under it) and stop under the next storey's (held storeys share a suffix).
func _parts_in(f: Dictionary, role: StringName, y0: float) -> Array:
	var catalog := EnvironmentCatalog.load_default()
	return (f.parts as Array).filter(func(part: Dictionary) -> bool:
		var box: AABB = part.transform * catalog.descriptor(part.asset_id).measured_aabb
		return part.role == role and box.position.y >= y0 - 0.15 and box.position.y <= y0 + 2.85)


## Braces under the storey whose floor line is y0 (their top meets its floor beam).
func _braces_under(f: Dictionary, role: StringName, y0: float) -> Array:
	var catalog := EnvironmentCatalog.load_default()
	return (f.parts as Array).filter(func(part: Dictionary) -> bool:
		var box: AABB = part.transform * catalog.descriptor(part.asset_id).measured_aabb
		return part.role == role and box.end.y >= y0 - 0.3 and box.end.y <= y0 + 0.01)


func test_every_overhang_rides_the_kit_jetty_on_the_joints() -> void:
	var f := FIXTURE.build({"lone": true})
	var catalog := EnvironmentCatalog.load_default()
	for index: int in [1, 2]:
		var y0 := float(f.front.storeys[index].floor_band) * 1.5
		var braces := _braces_under(f, &"bracket.jetty", y0).filter(func(p: Dictionary) -> bool:
			var box: AABB = p.transform * catalog.descriptor(p.asset_id).measured_aabb
			return box.size.z > box.size.x) # the south face's braces
		var xs := braces.map(func(p: Dictionary) -> float:
			return snappedf((p.transform * catalog.descriptor(p.asset_id).measured_aabb).get_center().x, 0.5))
		xs.sort()
		assert_eq(xs, [0.0, 2.0, 4.0, 6.0], "one kit jetty brace per module joint (storey %d)" % index)
		assert_eq(_parts_in(f, &"trim.floor_beam", y0).size() + _parts_in(f, &"trim.floor_beam_corner", y0).size(), 3,
			"the floor beam on the overhanging face (the corner variant at its left convex end)")
	assert_eq(_braces_under(f, &"bracket.jetty", 9.0).size(), 0, "a held storey adds no overhang")
	assert_eq(_braces_under(f, &"bracket.small", 3.0).size(), 0, "a kit step never takes small brackets")


func test_half_step_keeps_the_small_brackets() -> void:
	var f := FIXTURE.build({"lone": true, "character": FIXTURE.character({}, &"0.5")})
	assert_eq(FIXTURE.leans_on(f.front, 3), [-1.5, -1.0, -0.5, 0.0] as Array[float])
	var y0 := float(f.front.storeys[1].floor_band) * 1.5
	assert_eq(_braces_under(f, &"bracket.small", y0).size(), 4, "a bracket at every module joint")
	assert_eq(_braces_under(f, &"bracket.jetty", y0).size(), 0)


func test_growth_result_lists_each_stepped_storey() -> void:
	var f := FIXTURE.build({"lone": true})
	# The ground (stands in), storey 1 (stands in and overhangs), storey 2 (overhangs).
	assert_eq(f.leans.size(), 3)
	for lean: Dictionary in f.leans:
		assert_eq(int(lean.dir), 3)
		assert_true((lean.bounds as AABB).has_volume())
		assert_true(float(lean.lean) <= 0.0)
	assert_true((f.result.registry as Dictionary).is_empty(), "growth never steps outward")


## Removing the jetty must not reshuffle the house's other rolls: the jetty
## draw is still made, and the porch-canopy test still draws its 0.9.
func test_growing_house_takes_no_jetty_and_no_flush_canopy_but_keeps_its_rolls() -> void:
	var kit := SuntailBuildingKit.create()
	var jettied := 0
	var flush := 0
	var canopies := 0
	for seed_value in 60:
		var plain := FIXTURE.house(StringName("kit.j%d" % seed_value), Rect2i(0, 0, 4, 3), 3, 3)
		var grown := FIXTURE.house(StringName("kit.j%d" % seed_value), Rect2i(0, 0, 4, 3), 3, 3)
		BuildingDesigner.new(kit).articulate(plain, {"terrain_storey": 0})
		BuildingDesigner.new(kit).articulate(grown, {"terrain_storey": 0, "grows": true})
		assert_false(grown.storeys.any(func(s: Dictionary) -> bool: return bool(s.inset)))
		assert_false(grown.decor.any(func(d: Dictionary) -> bool:
			return d.kind == &"awning" and not bool(d.get("sheltered", false))))
		# Finish and roof design come after the jetty roll in articulate().
		for index in plain.storeys.size():
			assert_eq(grown.storeys[index].tint, plain.storeys[index].tint, "finish roll unchanged")
		assert_eq(grown.roofs, plain.roofs, "roof design unchanged")
		if plain.storeys.any(func(s: Dictionary) -> bool: return bool(s.inset)):
			jettied += 1
			continue
		# Without a jetty to remove, the wall slots are identical, so every facade
		# and dressing roll matches except the flush porch canopy itself.
		flush += 1
		for index in plain.storeys.size():
			assert_eq(grown.storeys[index].openings, plain.storeys[index].openings, "facade rolls unchanged")
		var kept := plain.decor.filter(func(d: Dictionary) -> bool:
			return not (d.kind == &"awning" and not bool(d.get("sheltered", false))))
		canopies += plain.decor.size() - kept.size()
		assert_eq(grown.decor, kept, "dressing rolls unchanged")
	assert_gt(jettied, 0, "some seed jetties the plain house")
	assert_gt(flush, 0, "some seed keeps the plain house flush")
	assert_gt(canopies, 0, "some flush house had a porch canopy to drop")


func test_projections_and_bays_skip_leaning_faces() -> void:
	var none := Callable(FIXTURE, "nothing_solid")
	var anything := func(_o: StringName, _c: Vector2i, _b: int) -> bool: return true
	var catalog := EnvironmentCatalog.load_default()
	var f := FIXTURE.build({"lone": true})
	var masses: Array[BuildingMass] = [f.front]
	var kits := {&"fixture.front": f.kit}
	var projections := PROJECTIONS.fit(masses, kits, f.kit, catalog, [], [], none, anything)
	assert_gt(projections.size(), 0, "the back face still takes a projection")
	for projection: Dictionary in projections:
		assert_ne(int(projection.dir), 3)
		assert_ne(int(projection.dir) % 2, 0, "no perpendicular front on a leaning storey")
	# A five-module house: both long faces are long enough for a bay.
	var wide := FIXTURE.house(&"kit.fixture.front", Rect2i(0, 0, 5, 2), 4, 3)
	wide.add_roof(Rect2i(0, 0, 5, 2), 1, 8, &"red")["union_index"] = 0
	var g := FIXTURE.build({"block": [0, 2], "replace_front": wide})
	assert_eq(FIXTURE.leans_on(g.front, 3), [-2.0, -1.0, 0.0, 0.0] as Array[float])
	var wide_masses: Array[BuildingMass] = [g.front]
	var bays := BAYS.fit(wide_masses, kits, g.kit, catalog, [], [], none)
	assert_gt(bays.size(), 0, "the back face still takes bays")
	for bay: Dictionary in bays:
		assert_ne((bay.edge as Vector3i).z, 3)


func test_a_ground_door_is_a_recessed_shopfront() -> void:
	# The fixture's ground door (x 2..4) is on the stepping face, with a doorstep.
	var f := FIXTURE.build({"lone": true, "prepare": func(front: BuildingMass) -> void:
		front.decor.append({"kind": &"doorstep", "centre": Vector2(1.5, 0.0), "dir": 3, "y": 0.0,
			"side": 1.0, "proud": 0.0, "count": 2})})
	assert_eq(FIXTURE.leans_on(f.front, 3), [-2.0, -1.0, 0.0, 0.0] as Array[float], "the door no longer blocks")
	var catalog := EnvironmentCatalog.load_default()
	var box := func(p: Dictionary) -> AABB: return p.transform * catalog.descriptor(p.asset_id).measured_aabb
	var doors := (f.parts as Array).filter(func(p: Dictionary) -> bool: return String(p.role) == "wall.timber.door")
	assert_eq(doors.size(), 1)
	var threshold := (box.call(doors[0]) as AABB).get_center()
	assert_almost_eq(threshold.z, 2.0, 0.3, "the door stands in its stepped-in wall")
	# The walk reaches it: the ground storey's boards cover the strip from the lot line
	# to the threshold at the floor level (the lane surface ends at the lot line).
	var strip := (f.parts as Array).filter(func(p: Dictionary) -> bool:
		var b: AABB = box.call(p)
		return p.role == &"deck.board" and b.position.y < 0.3 and b.has_point(Vector3(threshold.x, b.get_center().y, 1.0)))
	assert_eq(strip.size(), 1, "one ground board under the overhang in front of the door")
	assert_lt((box.call(strip[0]) as AABB).position.z, 0.05, "it starts at the lot line")
	for item: Dictionary in f.front.decor:
		if item.kind == &"doorstep":
			assert_almost_eq((item.centre as Vector2).y, 1.0, 1e-6, "the doorstep moved in with the door")


func test_a_door_on_a_stepped_in_upper_storey_withdraws_the_step() -> void:
	# A door on storey 1 opens onto an upper walk at the lot line; storey 1 keeps the line.
	var f := FIXTURE.build({"lone": true, "prepare": func(front: BuildingMass) -> void:
		front.storeys[1].openings[BuildingMass.edge_key(Vector2i(1, 0), 3)] = BuildingMass.OPENING_DOOR})
	assert_eq(FIXTURE.leans_on(f.front, 3), [-1.0, 0.0, 0.0, 0.0] as Array[float])


func test_roofs_and_the_top_storey_never_move() -> void:
	var f := FIXTURE.build({"lone": true})
	for wing: Dictionary in f.front.roofs:
		assert_false(wing.has("lean_min") or wing.has("lean_max"))
	var plain := FIXTURE.house(&"kit.fixture.front", Rect2i(0, 0, 3, 2), 4, 3)
	plain.add_roof(Rect2i(0, 0, 3, 2), 1, 8, &"red")["union_index"] = 0
	var roof := func(parts: Array) -> Array:
		var out := parts.filter(func(p: Dictionary) -> bool:
			var role := String(p.role)
			return role.begins_with("roof.") or role.begins_with("gable.") or role.begins_with("trim.ridge") \
				or role.begins_with("trim.barge") or role.begins_with("chimney.")).map(
				func(p: Dictionary) -> String: return "%s %s" % [p.asset_id, p.transform])
		out.sort()
		return out
	FIXTURE.block_faces(plain, [0, 2])
	assert_eq(roof.call(f.parts), roof.call(BuildingKitAssembler.new(f.kit).assemble(plain)), "the roof is untouched")
	for slot: Dictionary in BuildingKitAssembler.storey_slots(f.front.storeys[3]):
		assert_eq(float(slot.wall_offset), 0.0, "the top storey stands on its line")
