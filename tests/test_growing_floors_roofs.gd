extends GutTest
## Growing floors follow their roof (spec amendment "Roofs" + controller ruling on
## amendment conflict 1): a gable end moves out with the top storey; under an eave
## the house's ground storey steps in by the kit jetty instead (storey-wide, the
## kit's own inset), falling back to the light step or flush only where that inset
## is blocked.
const FIXTURE := preload("res://tests/fixtures/growing_house.gd")
const GROWTH := preload("res://scripts/terrain/features/villages/kit/KitGrowingFronts.gd")
const UNION := preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd")


func _causes(f: Dictionary) -> Array:
	return (f.result.rejections as Array).map(func(r: Dictionary) -> StringName: return r.cause)


func test_gable_end_moves_out_with_the_top_storey_and_the_gap_is_filled() -> void:
	var f := FIXTURE.build({"roof_axis": 1, "lone": true})
	var wing: Dictionary = f.front.roofs[0]
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 1.0, 2.0, 2.0] as Array[float])
	assert_almost_eq(float(wing.get("lean_min", 0.0)), 2.0, 1e-6, "front face is the min end")
	var shifted := (f.parts as Array).filter(func(p: Dictionary) -> bool: return bool(p.get("lean_end", false)))
	var fillers := (f.parts as Array).filter(func(p: Dictionary) -> bool: return bool(p.get("lean_filler", false)))
	assert_gt(shifted.size(), 0)
	assert_gt(fillers.size(), 0)
	assert_true(shifted.any(func(p: Dictionary) -> bool: return String(p.role).begins_with("gable.")))
	# Fillers keep only the 2.0 m strip between the last middle piece and the moved end.
	# (A Suntail roof piece spans exactly one module, so a filler the strip holds
	# whole is left untrimmed: realize returns {} and the instance is its skin.)
	var ctx := UNION.prepare(f.front.roofs, [], f.kit)
	var geometry := GROWTH.roof_geometry([f.kit])
	var seam := (0.0 + 0.5) * 2.0
	for filler: Dictionary in fillers:
		assert_true(geometry.has(filler.asset_id), "every filler has a baked skin to clip")
		var realized := UNION.realize(filler, ctx)
		var meshes: Array = realized.get("meshes", (geometry[filler.asset_id] as Array).map(
			func(surface: Dictionary) -> Dictionary:
				return {"vertices": (filler.transform as Transform3D) * (surface.vertices as PackedVector3Array)}))
		for mesh: Dictionary in meshes:
			for v: Vector3 in mesh.vertices:
				assert_between(v.z, seam - 2.0 - 0.002, seam + 0.002)


func test_eave_face_top_step_stays_under_the_measured_cornice() -> void:
	# The fixture's ground door is on this face: the ground cannot step in under
	# it (and a two-module plan cannot be inset), so the leader falls back.
	var f := FIXTURE.build({"roof_axis": 0, "lone": true})
	var wing: Dictionary = f.front.roofs[0]
	var allowance := GROWTH.eave_allowance(f.kit, EnvironmentCatalog.load_default(),
		GROWTH.roof_geometry([f.kit]), wing, 1)
	assert_lt(allowance, 0.986 - f.kit.wall_face)
	assert_lt(allowance, 1.0, "no kit jetty passes under the Suntail cornice")
	# The leader falls back to the light step; the top storey is capped under the
	# eave and, with no inward step allowed, every storey holds that cap.
	var q := 0.5 * floorf(allowance / 0.5 + 0.0001)
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, q, q, q] as Array[float])
	assert_false(wing.has("lean_min"), "an eave never moves")
	assert_true((f.result.insets as Array).is_empty(), "its ground door keeps the run on its line")
	if q == 0.0:
		assert_true(_causes(f).has(&"crown"), str(_causes(f)))


static func _block_gable(front: BuildingMass, blocker: String) -> void:
	var wing: Dictionary = front.roofs[0]
	match blocker:
		"open": wing.open_min = true
		"verge": wing["verge_min"] = 0.3
		"tight": wing["tight_eave"] = true
		"dormer": (wing.dormers as Dictionary)[Vector2i(0, 0)] = true


func test_unshiftable_gable_end_keeps_the_face_flush() -> void:
	for blocker: String in ["open", "verge", "tight", "dormer", "caps"]:
		var options := {"roof_axis": 1, "lone": true, "prepare": _block_gable.bind(blocker)}
		if blocker == "caps":
			options["kit"] = preload("res://scripts/terrain/features/villages/kit/PureVillageBuildingKit.gd").roof_study(0)
		var f := FIXTURE.build(options)
		assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 0.0, 0.0, 0.0] as Array[float], blocker)


func test_a_wrapped_front_keeps_only_the_faces_its_roof_covers() -> void:
	# Ridge along z: south and north are gable ends (they move), east and west are
	# eaves (a kit jetty cannot pass under them, and a two-module plan cannot step
	# its ground storey in): those two leave the front.
	var f := FIXTURE.build({"character": FIXTURE.character({&"growth_other_face_chance": 1.0})})
	for dir: int in [3, 1]:
		assert_eq(FIXTURE.leans_on(f.front, dir), [0.0, 1.0, 2.0, 2.0] as Array[float], "gable face %d" % dir)
	for dir: int in [0, 2]:
		assert_eq(FIXTURE.leans_on(f.front, dir), [0.0, 0.0, 0.0, 0.0] as Array[float], "eave face %d" % dir)
	assert_true(_causes(f).has(&"crown"), str(_causes(f)))


func test_terrace_row_gables_move_together() -> void:
	var side := FIXTURE.roofed(&"kit.fixture.side", Rect2i(3, 0, 2, 2), 4, 3)
	var f := FIXTURE.build({"extra": [side], "reserved_x": [-1, 5]})
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 1.0, 2.0, 2.0] as Array[float])
	assert_eq(FIXTURE.leans_on(side, 3), [0.0, 1.0, 2.0, 2.0] as Array[float])
	assert_almost_eq(float(f.front.roofs[0].get("lean_min", 0.0)), 2.0, 1e-6)
	assert_almost_eq(float(side.roofs[0].get("lean_min", 0.0)), 2.0, 1e-6)


func test_growing_houses_prefer_a_gable_to_the_street() -> void:
	var kit := SuntailBuildingKit.create()
	var counts := [0, 0]
	for boosted in 2:
		for seed_value in 400:
			var mass := FIXTURE.house(StringName("kit.g%d" % seed_value), Rect2i(0, 0, 3, 3), 2, 3)
			var designer := BuildingDesigner.new(kit)
			designer.gable_front_boost = 2.0 if boosted == 1 else 1.0
			if designer._square_axis(mass) == 1:
				counts[boosted] += 1
	assert_between(counts[0], 150, 250, "even mix without growth")
	assert_eq(counts[1], 400, "share 0.5 x 2 = 1: every square growing crown faces the lane with a gable")


func test_articulate_reads_the_boost_only_for_growing_houses() -> void:
	var kit := SuntailBuildingKit.create()
	var designer := BuildingDesigner.new(kit)
	designer.articulate(FIXTURE.house(&"kit.b1", Rect2i(0, 0, 3, 3), 3, 3), {"gable_boost": 2.0})
	assert_eq(designer.gable_front_boost, 1.0)
	designer.articulate(FIXTURE.house(&"kit.b2", Rect2i(0, 0, 3, 3), 3, 3), {"grows": true, "gable_boost": 2.0})
	assert_eq(designer.gable_front_boost, 2.0)


# --- eave faces: the ground run steps in (controller ruling, fix round 1) -------

## A 3 x `depth` house with its door on the back (north) face and its eave to the
## lane (south).
func _square(storeys: int, door_dir := 1, depth := 3) -> BuildingMass:
	var mass := FIXTURE.house(&"kit.fixture.front", Rect2i(0, 0, 3, depth), storeys, door_dir)
	mass.add_roof(Rect2i(0, 0, 3, depth), 0, storeys * 2, &"red")["union_index"] = 0
	return mass


func _box(part: Dictionary) -> AABB:
	return part.transform * EnvironmentCatalog.load_default().descriptor(part.asset_id).measured_aabb


## Kit jetty braces under storey `index` on the south face (their top meets its floor line).
func _south_braces(f: Dictionary, index: int) -> Array:
	var y0 := float(f.front.storeys[index].floor_band) * 1.5
	return (f.parts as Array).filter(func(p: Dictionary) -> bool:
		var box := _box(p)
		return p.role == &"bracket.jetty" and box.get_center().z < 1.5 and box.size.z > box.size.x \
			and box.end.y >= y0 - 0.3 and box.end.y <= y0 + 0.01)


func _ground_parts(f: Dictionary, prefix: String) -> Array:
	return (f.parts as Array).filter(func(p: Dictionary) -> bool:
		return String(p.role).begins_with(prefix) and float(p.transform.origin.y) < 1.0 \
			and float(p.transform.origin.y) > -0.5)


func _south_inset(f: Dictionary) -> Array:
	var ground: Dictionary = f.front.storeys[0]
	var out := []
	for x in 3:
		out.append(float((ground.get("wall_offsets", {}) as Dictionary).get(BuildingMass.edge_key(Vector2i(x, 0), 3), 0.0)))
	return out


func test_an_eave_face_steps_its_ground_run_in_instead() -> void:
	var f := FIXTURE.build({"lone": true, "replace_front": _square(2)})
	assert_eq(_south_inset(f), [-0.5, -0.5, -0.5], "the south ground run steps in one kit jetty")
	assert_false(bool(f.front.storeys[0].get("inset", false)), "one face, not the kit's storey-wide inset")
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 0.0] as Array[float],
		"the top storey stands on the footprint, under its eave")
	assert_false(f.front.roofs[0].has("lean_min"))
	assert_eq(_south_braces(f, 1).size(), 4, "one kit jetty brace per module joint")
	assert_eq((f.result.insets as Array).size(), 1)
	# The south ground walls stand one jetty in; the east and west corner panels
	# give way to one d100 strip each, on the inner half (z 1..2), facing out.
	for part: Dictionary in _ground_parts(f, "wall."):
		var box := _box(part)
		if box.size.x > box.size.z:
			assert_true(box.get_center().z > 0.5, "south ground wall at z %.2f" % box.get_center().z)
	var strips := _ground_parts(f, "frontage.return.d100")
	assert_eq(strips.size(), 2)
	for strip: Dictionary in strips:
		var box := _box(strip)
		assert_almost_eq(box.position.z, 1.0, 0.02, "the strip starts at the stepped-in face")
		assert_almost_eq(box.end.z, 2.0, 0.02, "and meets the next panel")
		assert_true(absf(box.get_center().x) < 0.4 or absf(box.get_center().x - 6.0) < 0.4)
	# One post at each new corner (x 0 and 6, z 1).
	var posts := _ground_parts(f, "post.timber").filter(func(p: Dictionary) -> bool:
		var c := _box(p).get_center()
		return absf(c.z - 1.0) < 0.3 and (absf(c.x) < 0.3 or absf(c.x - 6.0) < 0.3))
	assert_eq(posts.size(), 2)
	# The other faces' upper storeys are untouched.
	assert_eq(FIXTURE.leans_on(f.front, 0), [0.0, 0.0] as Array[float])


func test_a_tall_eave_face_keeps_one_step_at_the_ground() -> void:
	var f := FIXTURE.build({"lone": true, "replace_front": _square(4)})
	assert_eq(_south_inset(f), [-0.5, -0.5, -0.5])
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 0.0, 0.0, 0.0] as Array[float],
		"a step above would stand past the cornice: the face keeps the ground step")
	assert_true(_causes(f).has(&"crown"), str(_causes(f)))
	assert_eq(_south_braces(f, 1).size(), 4, "one kit jetty brace per module joint")


func test_a_two_module_deep_house_steps_its_ground_run_in() -> void:
	var f := FIXTURE.build({"lone": true, "replace_front": _square(2, 1, 2)})
	assert_eq(_south_inset(f), [-0.5, -0.5, -0.5], "1.5 modules stay behind the step")


func test_a_ground_storey_wider_than_the_one_above_steps_in_where_covered() -> void:
	var mass := _square(2)
	(mass.storeys[0].cells as Dictionary)[Vector2i(3, 2)] = true # a ground-only room at the back
	var f := FIXTURE.build({"lone": true, "replace_front": mass})
	assert_eq(_south_inset(f), [-0.5, -0.5, -0.5])


func test_a_door_on_the_eave_face_blocks_the_inset() -> void:
	var f := FIXTURE.build({"lone": true, "replace_front": _square(2, 3)})
	assert_eq(_south_inset(f), [0.0, 0.0, 0.0])
	assert_true((f.result.insets as Array).is_empty())
	assert_true(_causes(f).has(&"inset.portal"), str(_causes(f)))
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 0.0] as Array[float], "flush")


func test_a_party_wall_blocks_the_inset() -> void:
	# A one-storey shed against the east end of the run: its corner panel cannot
	# give way (party walls never step in).
	var mass := _square(2)
	mass.grows = true
	var chain: Dictionary = GROWTH.face_chains(mass, Callable(FIXTURE, "nothing_solid"), Callable(FIXTURE, "street")).filter(
		func(c: Dictionary) -> bool: return int(c.dir) == 3)[0]
	var shed := func(_own: StringName, cell: Vector2i, band: int) -> bool: return cell == Vector2i(3, 0) and band <= 1
	var ctx := {"solid": shed, "catalog": EnvironmentCatalog.load_default(), "air": [] as Array[Dictionary], "obstacles": []}
	var kit := SuntailBuildingKit.create()
	assert_eq(GROWTH._inset_cause(mass, kit, chain, ctx), &"inset.party")
	ctx.solid = Callable(FIXTURE, "nothing_solid")
	assert_eq(GROWTH._inset_cause(mass, kit, chain, ctx), &"")


func test_a_stone_ground_storey_keeps_its_line() -> void:
	var mass := _square(2)
	mass.storeys[0].material = BuildingMass.MATERIAL_STONE
	var f := FIXTURE.build({"lone": true, "replace_front": mass})
	assert_eq(_south_inset(f), [0.0, 0.0, 0.0], "no baked stone strip closes a stone corner")
	assert_true(_causes(f).has(&"inset.course"), str(_causes(f)))


func test_gable_faces_beside_a_stepped_in_eave_face_keep_their_steps() -> void:
	# Ridge along x: east and west are gable ends, south an eave (north has the door).
	var f := FIXTURE.build({"replace_front": _square(4),
		"character": FIXTURE.character({&"growth_other_face_chance": 1.0})})
	assert_eq(_south_inset(f), [-0.5, -0.5, -0.5])
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 0.0, 0.0, 0.0] as Array[float])
	for dir: int in [0, 2]:
		assert_eq(FIXTURE.leans_on(f.front, dir), [0.0, 1.0, 2.0, 2.0] as Array[float], "face %d" % dir)
	var wing: Dictionary = f.front.roofs[0]
	assert_almost_eq(float(wing.get("lean_max", 0.0)), 2.0, 1e-6)
	assert_almost_eq(float(wing.get("lean_min", 0.0)), 2.0, 1e-6)


static func _bay_on_top(front: BuildingMass) -> void:
	for x in 3:
		front.storeys[3].openings[BuildingMass.edge_key(Vector2i(x, 0), 3)] = BuildingMass.OPENING_BAY


func test_a_bay_on_the_stepping_face_rides_out_under_the_moved_gable() -> void:
	# The bay's recorded box stands where the face stood; it steps with the face,
	# so the moved gable end does not meet it (corpus: 4 gable crowns were this).
	var f := FIXTURE.build({"roof_axis": 1, "lone": true, "prepare": _bay_on_top})
	assert_true((f.parts as Array).any(func(p: Dictionary) -> bool: return String(p.role).begins_with("bay.")))
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 1.0, 2.0, 2.0] as Array[float])
	assert_almost_eq(float(f.front.roofs[0].get("lean_min", 0.0)), 2.0, 1e-6)
